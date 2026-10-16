extends Node2D
## Central Base-Structure Construction and Placement Subsystem for BioSphere-X.
## Integrates with Python CSP Constraint Solver API with full local fallback.
## Manages placement previews, grid constraints, structure instancing, and resource transactions.

signal placement_preview_started(structure_id: String)
signal placement_preview_updated(grid_pos: Vector2i, is_valid: bool, reason: String)
signal placement_preview_ended()
signal structure_placed(structure_id: String, grid_pos: Vector2i, structure_node: Node2D)
signal placement_rejected(structure_id: String, grid_pos: Vector2i, reason: String)
signal structure_removed(structure_id: String, grid_pos: Vector2i, refund: Dictionary)
signal demolish_mode_changed(is_active: bool)

const BaseStructureDataScript := preload("res://scripts/components/base_structure_data.gd")
const PlacedStructureScript := preload("res://scripts/components/placed_structure.gd")
const PlacementConstraintValidatorScript := preload("res://scripts/components/placement_constraint_validator.gd")

# Structure Catalog
var _catalog: Dictionary = {}

# Constraint Validator Engine (Pluggable Rules Module)
var _validator: RefCounted = null

# Active Construction State
var is_preview_active: bool = false
var active_preview_structure_id: String = ""
var preview_grid_position: Vector2i = Vector2i.ZERO
var preview_is_valid: bool = false
var preview_reason: String = ""

# Demolish Mode State
var is_demolish_active: bool = false
var hovered_demolish_structure: Dictionary = {}

# Build Zone: authorized region for base structures [min_x, min_y, max_x, max_y]
# Defaults to central base quadrant (approx 20 to 60 in an 80x80 map)
var build_zone_bounds: Rect2i = Rect2i(15, 15, 50, 50)

# Placed structures registry (Array of Dictionaries: {id, instance_id, name, position, size, min_spacing, node})
var _placed_structures: Array[Dictionary] = []

# Map Reference
var _map_data: RefCounted = null

# Preview Visual Node
var _preview_canvas: Node2D = null
var _feedback_label: Label = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 20
	_catalog = BaseStructureDataScript.get_default_catalog()
	_validator = PlacementConstraintValidatorScript.new()
	_setup_preview_canvas()


func _setup_preview_canvas() -> void:
	if not _preview_canvas:
		_preview_canvas = Node2D.new()
		_preview_canvas.name = "PlacementPreviewCanvas"
		_preview_canvas.visible = false
		add_child(_preview_canvas)
		_preview_canvas.draw.connect(_on_preview_draw)
	
	if not _feedback_label:
		_feedback_label = Label.new()
		_feedback_label.name = "PlacementFeedbackLabel"
		_feedback_label.add_theme_font_size_override("font_size", 11)
		_feedback_label.visible = false
		add_child(_feedback_label)


# ---------------------------------------------------------------------------
# Map & Zone Configuration API
# ---------------------------------------------------------------------------
func set_map_data(map: RefCounted) -> void:
	_map_data = map


func get_map_data() -> RefCounted:
	return _map_data


func set_build_zone(zone: Rect2i) -> void:
	build_zone_bounds = zone


func get_build_zone() -> Rect2i:
	return build_zone_bounds


func get_catalog() -> Dictionary:
	return _catalog


func get_structure_data(structure_id: String) -> RefCounted:
	return _catalog.get(structure_id, null)


func get_validator() -> RefCounted:
	return _validator


func set_validator(v: RefCounted) -> void:
	_validator = v


func get_placed_structures() -> Array[Dictionary]:
	return _placed_structures.duplicate()


func get_structure_at(grid_pos: Vector2i) -> Dictionary:
	for st in _placed_structures:
		var pos: Vector2i = st.get("position", Vector2i.ZERO)
		var sz: Vector2i = st.get("size", Vector2i.ONE)
		var r := Rect2i(pos, sz)
		if r.has_point(grid_pos):
			return st
	return {}


## Safely remove and dismantle a structure at grid position with resource refund and unblocking
func remove_structure_at(grid_pos: Vector2i, refund_ratio: float = 0.5) -> bool:
	var st := get_structure_at(grid_pos)
	if st.is_empty():
		return false
	return remove_structure_by_id(str(st.get("instance_id")), refund_ratio)


## Safely remove and dismantle a structure by unique instance ID
func remove_structure_by_id(instance_id: String, refund_ratio: float = 0.5) -> bool:
	var index := -1
	for i in _placed_structures.size():
		if str(_placed_structures[i].get("instance_id")) == instance_id:
			index = i
			break
	
	if index == -1:
		return false
		
	var st: Dictionary = _placed_structures[index]
	var s_id: String = str(st.get("id"))
	var s_pos: Vector2i = st.get("position", Vector2i.ZERO)
	var s_sz: Vector2i = st.get("size", Vector2i.ONE)
	var s_node: Node = st.get("node")
	
	# Compute refund materials
	var s_data: RefCounted = _catalog.get(s_id, null)
	var cost: Dictionary = s_data.get("cost") if s_data else {}
	var refund: Dictionary = {}
	for k in cost:
		var refunded_amt := int(floor(float(cost[k]) * refund_ratio))
		if refunded_amt > 0:
			refund[k] = refunded_amt
			
	# Refund to InventoryManager / GameState
	var inv = get_node_or_null("/root/InventoryManager")
	var gs = get_node_or_null("/root/GameState")
	for k in refund:
		var amt: int = int(refund[k])
		if inv and inv.has_method("add_item"):
			inv.call("add_item", k, amt)
		elif gs and "resources" in gs and gs.resources.has(k):
			gs.resources[k] += amt
			if gs.has_signal("resource_changed"):
				gs.resource_changed.emit(k, gs.resources[k])
	
	# Safely unblock MapData navigation cells
	if _map_data and _map_data.has_method("set_cell_blocked"):
		for dy in s_sz.y:
			for dx in s_sz.x:
				_map_data.call("set_cell_blocked", Vector2i(s_pos.x + dx, s_pos.y + dy), false, 0)
	
	# Free in-world node
	if is_instance_valid(s_node):
		s_node.queue_free()
		
	_placed_structures.remove_at(index)
	print("[ConstructionManager] REMOVED: '%s' (%s) at (%d, %d). Refunded: %s" % [
		st.get("name"), instance_id, s_pos.x, s_pos.y, str(refund)
	])
	structure_removed.emit(s_id, s_pos, refund)
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_sfx"):
		audio.call("play_sfx", "demolish")
	return true


# ---------------------------------------------------------------------------
# Demolish Mode API
# ---------------------------------------------------------------------------
func start_demolish_mode() -> void:
	if is_preview_active:
		cancel_placement_preview()
	is_demolish_active = true
	hovered_demolish_structure.clear()
	if _feedback_label:
		_feedback_label.visible = true
		_feedback_label.text = "DEMOLISH MODE: Click structure to dismantle (ESC/RMB to cancel)"
		_feedback_label.modulate = Color(1.0, 0.5, 0.2)
	demolish_mode_changed.emit(true)


func cancel_demolish_mode() -> void:
	if not is_demolish_active:
		return
	is_demolish_active = false
	hovered_demolish_structure.clear()
	if _feedback_label:
		_feedback_label.visible = false
	if _preview_canvas:
		_preview_canvas.visible = false
		_preview_canvas.queue_redraw()
	demolish_mode_changed.emit(false)


func toggle_demolish_mode() -> void:
	if is_demolish_active:
		cancel_demolish_mode()
	else:
		start_demolish_mode()


func reset_construction() -> void:
	cancel_placement_preview()
	cancel_demolish_mode()
	for s in _placed_structures:
		var node: Node = s.get("node")
		if is_instance_valid(node):
			node.queue_free()
	_placed_structures.clear()


# ---------------------------------------------------------------------------
# Placement Preview Lifecycle
# ---------------------------------------------------------------------------
func start_placement_preview(structure_id: String) -> bool:
	if not _catalog.has(structure_id):
		push_warning("[ConstructionManager] Unknown structure ID: %s" % structure_id)
		return false
	
	if is_demolish_active:
		cancel_demolish_mode()
	
	is_preview_active = true
	active_preview_structure_id = structure_id
	
	if _preview_canvas:
		_preview_canvas.visible = true
	if _feedback_label:
		_feedback_label.visible = true
	
	# Initial validation at current position
	update_preview_position(preview_grid_position)
	placement_preview_started.emit(structure_id)
	return true


func cancel_placement_preview() -> void:
	if not is_preview_active:
		return
	is_preview_active = false
	active_preview_structure_id = ""
	
	if _preview_canvas:
		_preview_canvas.visible = false
	if _feedback_label:
		_feedback_label.visible = false
	
	placement_preview_ended.emit()


func update_preview_position(grid_pos: Vector2i) -> void:
	preview_grid_position = grid_pos
	
	# Validate position synchronously for immediate responsive visual feedback
	var val_res := validate_placement_locally(active_preview_structure_id, grid_pos)
	preview_is_valid = bool(val_res.get("valid", false))
	preview_reason = str(val_res.get("reason", ""))
	
	# Update visual position
	var cell_sz: float = 32.0
	if _map_data and "cell_size" in _map_data:
		cell_sz = float(_map_data.cell_size)
	
	var world_pos := Vector2(float(grid_pos.x) * cell_sz, float(grid_pos.y) * cell_sz)
	if _map_data and _map_data.has_method("grid_to_world"):
		world_pos = _map_data.call("grid_to_world", grid_pos) - Vector2(cell_sz * 0.5, cell_sz * 0.5)
	
	if _preview_canvas:
		_preview_canvas.position = world_pos
		_preview_canvas.queue_redraw()
	
	if _feedback_label:
		_feedback_label.position = world_pos + Vector2(0, -22)
		if preview_is_valid:
			_feedback_label.text = "✓ Valid Placement [Click to Build]"
			_feedback_label.modulate = Color(0.2, 1.0, 0.6)
		else:
			_feedback_label.text = "✕ %s" % preview_reason
			_feedback_label.modulate = Color(1.0, 0.35, 0.35)
	
	placement_preview_updated.emit(grid_pos, preview_is_valid, preview_reason)


func _on_preview_draw() -> void:
	if is_demolish_active:
		if not hovered_demolish_structure.is_empty():
			var s_sz: Vector2i = hovered_demolish_structure.get("size", Vector2i.ONE)
			var cell_sz: float = 32.0
			if _map_data and "cell_size" in _map_data:
				cell_sz = float(_map_data.cell_size)
			var w_px := float(s_sz.x) * cell_sz
			var h_px := float(s_sz.y) * cell_sz
			var rect := Rect2(0, 0, w_px, h_px)
			# Hazard red demolition highlight
			_preview_canvas.draw_rect(rect, Color(0.95, 0.15, 0.15, 0.35), true)
			_preview_canvas.draw_rect(rect, Color(1.0, 0.2, 0.2, 0.95), false, 2.5)
			_preview_canvas.draw_line(Vector2(0, 0), Vector2(w_px, h_px), Color(1.0, 0.3, 0.3, 0.7), 2.0)
			_preview_canvas.draw_line(Vector2(0, h_px), Vector2(w_px, 0), Color(1.0, 0.3, 0.3, 0.7), 2.0)
		return
		
	if not is_preview_active or not _catalog.has(active_preview_structure_id):
		return
	
	var s_data: RefCounted = _catalog[active_preview_structure_id]
	var w: int = int(s_data.get("width"))
	var h: int = int(s_data.get("height"))
	var spacing: int = int(s_data.get("min_spacing"))
	var cell_sz: float = 32.0
	if _map_data and "cell_size" in _map_data:
		cell_sz = float(_map_data.cell_size)
	
	var full_w := float(w) * cell_sz
	var full_h := float(h) * cell_sz
	
	# 1. Spacing Buffer Halo (Clearance Zone)
	if spacing > 0:
		var sp_pixels := float(spacing) * cell_sz
		var halo_rect := Rect2(-sp_pixels, -sp_pixels, full_w + sp_pixels * 2.0, full_h + sp_pixels * 2.0)
		_preview_canvas.draw_rect(halo_rect, Color(0.9, 0.8, 0.2, 0.12), true)
		_preview_canvas.draw_rect(halo_rect, Color(0.9, 0.8, 0.2, 0.45), false, 1.0)
	
	# 2. Main Candidate Footprint
	var foot_rect := Rect2(0, 0, full_w, full_h)
	var tint := Color(0.15, 0.95, 0.5, 0.45) if preview_is_valid else Color(0.95, 0.2, 0.25, 0.45)
	var border := Color(0.2, 1.0, 0.6, 0.95) if preview_is_valid else Color(1.0, 0.3, 0.35, 0.95)
	
	_preview_canvas.draw_rect(foot_rect, tint, true)
	_preview_canvas.draw_rect(foot_rect, border, false, 2.5)


func _unhandled_input(event: InputEvent) -> void:
	if is_demolish_active:
		if event is InputEventMouseMotion:
			var m_pos := get_global_mouse_position()
			var g_pos := Vector2i(int(floor(m_pos.x / 32.0)), int(floor(m_pos.y / 32.0)))
			if _map_data and _map_data.has_method("world_to_grid"):
				g_pos = _map_data.call("world_to_grid", m_pos)
			var found := get_structure_at(g_pos)
			if found != hovered_demolish_structure:
				hovered_demolish_structure = found
				if not hovered_demolish_structure.is_empty():
					var s_pos: Vector2i = hovered_demolish_structure.get("position", Vector2i.ZERO)
					var cell_sz: float = 32.0
					if _map_data and "cell_size" in _map_data:
						cell_sz = float(_map_data.cell_size)
					var world_pos := Vector2(float(s_pos.x) * cell_sz, float(s_pos.y) * cell_sz)
					if _map_data and _map_data.has_method("grid_to_world"):
						world_pos = _map_data.call("grid_to_world", s_pos) - Vector2(cell_sz * 0.5, cell_sz * 0.5)
					if _preview_canvas:
						_preview_canvas.position = world_pos
						_preview_canvas.visible = true
						_preview_canvas.queue_redraw()
					if _feedback_label:
						_feedback_label.position = world_pos + Vector2(0, -22)
						_feedback_label.text = "DEMOLISH: %s [Click to dismantle (50%% refund)]" % hovered_demolish_structure.get("name")
						_feedback_label.modulate = Color(1.0, 0.3, 0.3)
				else:
					if _preview_canvas:
						_preview_canvas.visible = false
					if _feedback_label:
						_feedback_label.text = "DEMOLISH MODE: Hover over structure to dismantle (ESC/RMB to cancel)"
						_feedback_label.modulate = Color(1.0, 0.5, 0.2)
		elif event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if not hovered_demolish_structure.is_empty():
					remove_structure_by_id(str(hovered_demolish_structure.get("instance_id")), 0.5)
					hovered_demolish_structure.clear()
					if _preview_canvas:
						_preview_canvas.visible = false
					get_viewport().set_input_as_handled()
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				cancel_demolish_mode()
				get_viewport().set_input_as_handled()
		elif event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				cancel_demolish_mode()
				get_viewport().set_input_as_handled()
		return
		
	if not is_preview_active:
		return
	
	if event is InputEventMouseMotion:
		var m_pos := get_global_mouse_position()
		var g_pos := Vector2i(int(floor(m_pos.x / 32.0)), int(floor(m_pos.y / 32.0)))
		if _map_data and _map_data.has_method("world_to_grid"):
			g_pos = _map_data.call("world_to_grid", m_pos)
		if g_pos != preview_grid_position:
			update_preview_position(g_pos)
			
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			commit_placement(active_preview_structure_id, preview_grid_position)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_placement_preview()
			get_viewport().set_input_as_handled()
			
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			cancel_placement_preview()
			get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# Validation Pipeline (Python CSP Async + Full Local Fallback)
# ---------------------------------------------------------------------------
func validate_placement_async(structure_id: String, grid_pos: Vector2i, callback: Callable) -> void:
	var ai = get_node_or_null("/root/AIClient")
	
	# If AIClient is available and backend is reachable, invoke Python CSP
	if ai and ai.get("is_backend_available") and ai.has_method("request_placement_validation"):
		var payload := _build_placement_request_dict(structure_id, grid_pos)
		ai.call("request_placement_validation", payload, func(res: Dictionary):
			if bool(res.get("success", false)) and res.has("data"):
				var data: Dictionary = res.get("data")
				callback.call(data)
			else:
				# Graceful degradation fallback to local CSP engine
				var local_res := validate_placement_locally(structure_id, grid_pos)
				callback.call(local_res)
		)
	else:
		# Immediate local CSP evaluation
		var local_res := validate_placement_locally(structure_id, grid_pos)
		callback.call(local_res)


func _build_placement_request_dict(structure_id: String, grid_pos: Vector2i) -> Dictionary:
	var s_data: RefCounted = _catalog.get(structure_id, null)
	var w: int = int(s_data.get("width")) if s_data else 1
	var h: int = int(s_data.get("height")) if s_data else 1
	var cost: Dictionary = s_data.get("cost") if s_data else {}
	var min_spacing: int = int(s_data.get("min_spacing")) if s_data else 1
	
	var gw := 80
	var gh := 80
	if _map_data and "grid_size" in _map_data:
		gw = int(_map_data.grid_size.x)
		gh = int(_map_data.grid_size.y)
	
	# Blocked terrain cells
	var blocked_list: Array = []
	if _map_data and _map_data.has_method("get_blocked_cells"):
		var b_arr: Array = _map_data.call("get_blocked_cells")
		for b in b_arr:
			blocked_list.append([int(b.x), int(b.y)])
	
	# Existing placed structures
	var existing_list: Array = []
	for st in _placed_structures:
		var p: Vector2i = st.get("position", Vector2i.ZERO)
		var sz: Vector2i = st.get("size", Vector2i.ONE)
		existing_list.append({
			"id": str(st.get("id")),
			"name": str(st.get("name")),
			"position": [p.x, p.y],
			"size": [sz.x, sz.y],
			"min_spacing": int(st.get("min_spacing", 1))
		})
	
	# Available resources
	var avail_res := get_available_resources()
	
	return {
		"structure_id": structure_id,
		"position": [grid_pos.x, grid_pos.y],
		"structure_size": [w, h],
		"structure_cost": cost,
		"min_spacing": min_spacing,
		"available_resources": avail_res,
		"grid_size": [gw, gh],
		"build_zone": [build_zone_bounds.position.x, build_zone_bounds.position.y, build_zone_bounds.end.x, build_zone_bounds.end.y],
		"blocked_cells": blocked_list,
		"existing_structures": existing_list
	}


# ---------------------------------------------------------------------------
# In-Engine Local CSP Constraint Solver (Fallback & Immediate Feedback)
# ---------------------------------------------------------------------------
func validate_placement_locally(structure_id: String, grid_pos: Vector2i) -> Dictionary:
	var s_data: RefCounted = _catalog.get(structure_id, null)
	if not s_data:
		return {
			"valid": false,
			"reason": "Unknown structure ID: '%s'" % structure_id,
			"violated_constraints": ["UNKNOWN_STRUCTURE"],
			"structure_id": structure_id,
			"cost": {},
			"footprint": []
		}
	
	var w: int = int(s_data.get("width"))
	var h: int = int(s_data.get("height"))
	var cost: Dictionary = s_data.get("cost")
	var min_spacing: int = int(s_data.get("min_spacing"))
	
	var footprint: Array[Vector2i] = []
	for dy in h:
		for dx in w:
			footprint.append(Vector2i(grid_pos.x + dx, grid_pos.y + dy))
	
	if not _validator:
		_validator = PlacementConstraintValidatorScript.new()
	
	var gw := 80
	var gh := 80
	if _map_data and "grid_size" in _map_data:
		gw = int(_map_data.grid_size.x)
		gh = int(_map_data.grid_size.y)
	
	var candidate := {
		"structure_id": structure_id,
		"position": grid_pos,
		"size": Vector2i(w, h),
		"cost": cost,
		"min_spacing": min_spacing,
		"footprint": footprint
	}
	
	var context := {
		"map_data": _map_data,
		"grid_size": Vector2i(gw, gh),
		"build_zones": [build_zone_bounds],
		"build_zone_bounds": build_zone_bounds,
		"placed_structures": _placed_structures,
		"available_resources": get_available_resources()
	}
	
	var val_res: Dictionary = _validator.validate(candidate, context)
	val_res["structure_id"] = structure_id
	val_res["structure_name"] = str(s_data.get("name"))
	val_res["cost"] = cost
	val_res["footprint"] = footprint
	return val_res


# ---------------------------------------------------------------------------
# Commit Placement (Validation + Deduction-on-Success + Instancing)
# ---------------------------------------------------------------------------
func commit_placement(structure_id: String, grid_pos: Vector2i, callback: Callable = Callable()) -> void:
	validate_placement_async(structure_id, grid_pos, func(result: Dictionary):
		var is_valid := bool(result.get("valid", false))
		var reason := str(result.get("reason", "Placement rejected."))
		
		if not is_valid:
			# Prevent resource deduction when placement fails!
			placement_rejected.emit(structure_id, grid_pos, reason)
			if callback.is_valid():
				callback.call(false, reason)
			return
		
		# Deduct resources only upon successful validation
		var s_data: RefCounted = _catalog.get(structure_id, null)
		var cost: Dictionary = s_data.get("cost") if s_data else {}
		var deducted := _deduct_resources(cost)
		if not deducted:
			placement_rejected.emit(structure_id, grid_pos, "Resource deduction failed at execution.")
			if callback.is_valid():
				callback.call(false, "Resource deduction failed.")
			return
		
		# Spawn in-world structure node
		var struct_node := _spawn_structure_instance(s_data, grid_pos)
		
		# Register in placed structures
		var entry := {
			"id": structure_id,
			"instance_id": "%s_%d" % [structure_id, _placed_structures.size() + 1],
			"name": str(s_data.get("name")),
			"position": grid_pos,
			"size": Vector2i(int(s_data.get("width")), int(s_data.get("height"))),
			"min_spacing": int(s_data.get("min_spacing")),
			"node": struct_node
		}
		_placed_structures.append(entry)
		
		# Mark cells as solid in MapData
		if _map_data and _map_data.has_method("set_cell_blocked"):
			for dy in int(s_data.get("height")):
				for dx in int(s_data.get("width")):
					_map_data.call("set_cell_blocked", Vector2i(grid_pos.x + dx, grid_pos.y + dy), true, 2)
		
		print("[ConstructionManager] COMMITTED: '%s' placed at (%d, %d)." % [s_data.get("name"), grid_pos.x, grid_pos.y])
		structure_placed.emit(structure_id, grid_pos, struct_node)
		
		var audio = get_node_or_null("/root/AudioManager")
		if audio and audio.has_method("play_sfx"):
			audio.call("play_sfx", "build")
		
		# End preview upon successful build
		cancel_placement_preview()
		
		if callback.is_valid():
			callback.call(true, "Structure successfully constructed.")
	)


func _spawn_structure_instance(data: RefCounted, grid_pos: Vector2i) -> Node2D:
	var structure: Node2D = PlacedStructureScript.new()
	var cell_sz: float = 32.0
	if _map_data and "cell_size" in _map_data:
		cell_sz = float(_map_data.cell_size)
	
	structure.configure(data, grid_pos, cell_sz)
	
	var world_pos := Vector2(float(grid_pos.x) * cell_sz, float(grid_pos.y) * cell_sz)
	if _map_data and _map_data.has_method("grid_to_world"):
		world_pos = _map_data.call("grid_to_world", grid_pos) - Vector2(cell_sz * 0.5, cell_sz * 0.5)
	
	structure.position = world_pos
	
	# Add to world tree or as child
	var world = get_tree().current_scene
	if world:
		world.add_child(structure)
	else:
		add_child(structure)
		
	return structure


# ---------------------------------------------------------------------------
# Resource Handling & Synchronization Helpers
# ---------------------------------------------------------------------------
func get_available_resources() -> Dictionary:
	var res := {"crystals": 0, "titanium": 0, "biomass": 0, "oxygen_cells": 0}
	
	var inv = get_node_or_null("/root/InventoryManager")
	if inv and inv.has_method("get_all_items"):
		var items: Dictionary = inv.call("get_all_items")
		for k in res:
			res[k] = int(items.get(k, 0))
		return res
	
	var gs = get_node_or_null("/root/GameState")
	if gs and "resources" in gs:
		for k in res:
			res[k] = int(gs.resources.get(k, 0))
	return res


func _deduct_resources(cost: Dictionary) -> bool:
	var inv = get_node_or_null("/root/InventoryManager")
	var gs = get_node_or_null("/root/GameState")
	
	# Verify first
	var current := get_available_resources()
	for k in cost:
		if current.get(k, 0) < int(cost[k]):
			return false
	
	# Deduct
	for k in cost:
		var amt: int = int(cost[k])
		if inv and inv.has_method("remove_item"):
			inv.call("remove_item", k, amt)
		elif gs and "resources" in gs and gs.resources.has(k):
			gs.resources[k] = maxi(0, gs.resources[k] - amt)
			if gs.has_signal("resource_changed"):
				gs.resource_changed.emit(k, gs.resources[k])
	return true


# ---------------------------------------------------------------------------
# Save & Load Persistence Integration
# ---------------------------------------------------------------------------
func get_placed_structures_save_data() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for entry in _placed_structures:
		var pos: Vector2i = entry.get("position", Vector2i.ZERO)
		list.append({
			"id": str(entry.get("id")),
			"instance_id": str(entry.get("instance_id")),
			"grid_pos": [pos.x, pos.y]
		})
	return list


func clear_all_structures() -> void:
	for entry in _placed_structures:
		var node = entry.get("node")
		if is_instance_valid(node):
			node.queue_free()
	_placed_structures.clear()


func restore_placed_structures(structures_data: Array) -> void:
	clear_all_structures()
	for item in structures_data:
		if not (item is Dictionary):
			continue
		var s_id: String = ""
		if item.has("structure_id") and _catalog.has(str(item["structure_id"])):
			s_id = str(item["structure_id"])
		elif item.has("id") and _catalog.has(str(item["id"])):
			s_id = str(item["id"])
		elif item.has("structure_id"):
			s_id = str(item["structure_id"])
		elif item.has("id"):
			s_id = str(item["id"])
			
		# Compatibility aliases
		if s_id == "area_light":
			s_id = "light_tower"
			
		var g_pos := Vector2i.ZERO
		if item.has("grid_pos") and item["grid_pos"] is Array:
			var pos_arr: Array = item["grid_pos"]
			if pos_arr.size() >= 2:
				g_pos = Vector2i(int(pos_arr[0]), int(pos_arr[1]))
		elif item.has("grid_x") and item.has("grid_y"):
			g_pos = Vector2i(int(item["grid_x"]), int(item["grid_y"]))

		var s_data: RefCounted = _catalog.get(s_id, null)
		if s_data:
			var node := _spawn_structure_instance(s_data, g_pos)
			var entry := {
				"id": s_id,
				"instance_id": str(item.get("instance_id", item.get("id", "%s_%d" % [s_id, _placed_structures.size() + 1]))),
				"name": str(s_data.get("name")),
				"position": g_pos,
				"size": Vector2i(int(s_data.get("width")), int(s_data.get("height"))),
				"min_spacing": int(s_data.get("min_spacing")),
				"node": node
			}
			_placed_structures.append(entry)
			
			if _map_data and _map_data.has_method("set_cell_blocked"):
				for dy in int(s_data.get("height")):
					for dx in int(s_data.get("width")):
						_map_data.call("set_cell_blocked", Vector2i(g_pos.x + dx, g_pos.y + dy), true, 2)
