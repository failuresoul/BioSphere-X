extends Area2D
class_name CollectableResource
## Reusable collectable resource item for BioSphere-X.
## Supports Oxygen Cells, Metal, Energy Crystals, and Scientific Samples.
## Features configurable quantities, collision detection, proximity visual prompt,
## instant collection prevention against double-pickup, and collection feedback.

enum ResourceType {
	OXYGEN_CELL,
	METAL,
	ENERGY_CRYSTAL,
	SCIENTIFIC_SAMPLE
}

signal collected(player: Node2D, resource_type: ResourceType, amount: int)

@export var resource_type: ResourceType = ResourceType.ENERGY_CRYSTAL:
	set(val):
		resource_type = val
		_update_type_visuals()
		queue_redraw()

@export var quantity: int = 1:
	set(val):
		quantity = maxi(1, val)
		_update_prompt_text()

@export var interaction_radius: float = 48.0:
	set(val):
		interaction_radius = maxf(16.0, val)
		_update_collision_shape()

@export var oxygen_restore_amount: float = 30.0 # Restored O2 if type is OXYGEN_CELL
@export var bobbing_amplitude: float = 3.5
@export var bobbing_speed: float = 3.2

var is_collected: bool = false

# Internal Visual State
var _anim_time: float = 0.0
var _bob_y: float = 0.0
var _is_player_near: bool = false
var _prompt_label: Label = null
var _collision_shape: CollisionShape2D = null
var _particles: Array[Dictionary] = []

# Color Palettes per Resource Type
var _core_color: Color = Color(0.85, 0.35, 1.0)
var _glow_color: Color = Color(0.85, 0.40, 1.0, 0.35)
var _accent_color: Color = Color(1.0, 1.0, 1.0, 0.9)


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("collectable")
	
	collision_layer = 2 # Layer 2 (Interactable)
	collision_mask = 1  # Layer 1 (Player)
	
	_setup_collision()
	_setup_prompt_ui()
	_update_type_visuals()
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _setup_collision() -> void:
	if not _collision_shape:
		_collision_shape = CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = interaction_radius
		_collision_shape.shape = circle
		add_child(_collision_shape)


func _update_collision_shape() -> void:
	if _collision_shape and _collision_shape.shape is CircleShape2D:
		(_collision_shape.shape as CircleShape2D).radius = interaction_radius


func _setup_prompt_ui() -> void:
	if not _prompt_label:
		_prompt_label = Label.new()
		_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_prompt_label.add_theme_font_size_override("font_size", 10)
		_prompt_label.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
		_prompt_label.position = Vector2(-75, -34)
		_prompt_label.custom_minimum_size = Vector2(150, 20)
		_prompt_label.visible = false
		add_child(_prompt_label)
		_update_prompt_text()


func _update_type_visuals() -> void:
	match resource_type:
		ResourceType.OXYGEN_CELL:
			_core_color = Color(0.12, 0.85, 1.00)
			_glow_color = Color(0.15, 0.90, 1.00, 0.35)
			_accent_color = Color(0.80, 1.00, 1.00)
		ResourceType.METAL:
			_core_color = Color(0.95, 0.65, 0.20)
			_glow_color = Color(1.00, 0.70, 0.25, 0.35)
			_accent_color = Color(1.00, 0.92, 0.70)
		ResourceType.ENERGY_CRYSTAL:
			_core_color = Color(0.85, 0.35, 1.00)
			_glow_color = Color(0.85, 0.40, 1.00, 0.35)
			_accent_color = Color(1.00, 0.85, 1.00)
		ResourceType.SCIENTIFIC_SAMPLE:
			_core_color = Color(0.15, 0.95, 0.55)
			_glow_color = Color(0.20, 1.00, 0.60, 0.35)
			_accent_color = Color(0.85, 1.00, 0.90)
	
	_update_prompt_text()


func _update_prompt_text() -> void:
	if not _prompt_label:
		return
	var type_title := get_display_name()
	_prompt_label.text = "[E] Collect %s (+%d)" % [type_title, quantity]


func get_display_name() -> String:
	match resource_type:
		ResourceType.OXYGEN_CELL: return "Oxygen Cell"
		ResourceType.METAL: return "Metal Alloy"
		ResourceType.ENERGY_CRYSTAL: return "Energy Crystal"
		ResourceType.SCIENTIFIC_SAMPLE: return "Scientific Sample"
	return "Resource"


func get_resource_id_name() -> String:
	match resource_type:
		ResourceType.OXYGEN_CELL: return "oxygen_cells"
		ResourceType.METAL: return "titanium"
		ResourceType.ENERGY_CRYSTAL: return "crystals"
		ResourceType.SCIENTIFIC_SAMPLE: return "biomass"
	return "crystals"


func _on_body_entered(body: Node2D) -> void:
	if is_collected:
		return
	if body.is_in_group("player") or body is CharacterBody2D:
		_is_player_near = true
		if _prompt_label:
			_prompt_label.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body is CharacterBody2D:
		_is_player_near = false
		if _prompt_label:
			_prompt_label.visible = false


func _process(delta: float) -> void:
	_anim_time += delta
	_bob_y = sin(_anim_time * bobbing_speed) * bobbing_amplitude
	
	if _prompt_label and _is_player_near and not is_collected:
		_prompt_label.position.y = -34.0 + _bob_y * 0.5
	
	_update_particles(delta)
	queue_redraw()


## Player interaction hook (E key / Spacebar)
func interact(user: Node2D = null) -> bool:
	if is_collected:
		return false
	
	# Prevent repeated collection immediately
	is_collected = true
	_is_player_near = false
	if _prompt_label:
		_prompt_label.visible = false
	if _collision_shape:
		_collision_shape.set_deferred("disabled", true)
	monitoring = false
	monitorable = false
	
	# Update GameState & Inventory
	var id_name := get_resource_id_name()
	var gs := get_node_or_null("/root/GameState")
	if gs:
		if gs.has_method("add_resource"):
			gs.call("add_resource", id_name, quantity)
		if resource_type == ResourceType.OXYGEN_CELL and gs.has_method("refill_oxygen"):
			gs.call("refill_oxygen", oxygen_restore_amount)
	
	collected.emit(user, resource_type, quantity)
	_play_collection_feedback()
	return true


# ---------------------------------------------------------------------------
# Feedback & Collection Animation
# ---------------------------------------------------------------------------
func _play_collection_feedback() -> void:
	# Spawn bursting sparkles
	for i in 16:
		var ang: float = (float(i) / 16.0) * TAU
		_particles.append({
			"pos": Vector2(0, _bob_y),
			"vel": Vector2.from_angle(ang) * randf_range(30.0, 75.0),
			"radius": randf_range(2.0, 4.0),
			"color": _core_color,
			"life": 0.0,
			"max_life": 0.45
		})
	
	# Tween upward floating and scaling fade
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 28.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.15)
	tween.chain().tween_property(self, "scale", Vector2.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.chain().tween_callback(queue_free)


func _update_particles(delta: float) -> void:
	for i in range(_particles.size() - 1, -1, -1):
		var p: Dictionary = _particles[i]
		p["life"] += delta
		if p["life"] >= p["max_life"]:
			_particles.remove_at(i)
		else:
			p["pos"] += p["vel"] * delta
			p["vel"] = p["vel"].move_toward(Vector2.ZERO, delta * 40.0)


# ---------------------------------------------------------------------------
# Procedural Sci-Fi Graphics
# ---------------------------------------------------------------------------
func _draw() -> void:
	# 1. Ground Drop Shadow (Fixed at base, squashes slightly with bobbing)
	var shadow_scale := 1.0 - (_bob_y / bobbing_amplitude) * 0.15
	draw_set_transform(Vector2(1, 10), 0.0, Vector2(1.2 * shadow_scale, 0.6 * shadow_scale))
	draw_circle(Vector2.ZERO, 10.0, Color(0.02, 0.03, 0.06, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	
	# 2. Draw Collection Sparkles
	for p in _particles:
		var t: float = p["life"] / p["max_life"]
		var c: Color = p["color"]
		c.a = 1.0 - t
		draw_circle(p["pos"], p["radius"] * (1.0 - t * 0.5), c)
	
	if is_collected:
		return
	
	# 3. Ambient Pulsing Interaction Aura
	var pulse := (sin(_anim_time * 4.0) + 1.0) * 0.5
	var halo_color := _glow_color
	halo_color.a = 0.25 + pulse * (0.3 if _is_player_near else 0.15)
	draw_circle(Vector2(0, _bob_y), 16.0 + pulse * 3.0, halo_color)
	
	if _is_player_near:
		# Draw glowing targeting bracket ring
		draw_arc(Vector2(0, _bob_y), 19.0, 0.0, TAU, 24, Color(_core_color, 0.8), 1.5)
	
	# 4. Draw Specific Resource Mesh
	draw_set_transform(Vector2(0, _bob_y), 0.0, Vector2.ONE)
	match resource_type:
		ResourceType.OXYGEN_CELL:
			_draw_oxygen_cell(pulse)
		ResourceType.METAL:
			_draw_metal_ingot(pulse)
		ResourceType.ENERGY_CRYSTAL:
			_draw_energy_crystal(pulse)
		ResourceType.SCIENTIFIC_SAMPLE:
			_draw_scientific_sample(pulse)


func _draw_oxygen_cell(pulse: float) -> void:
	# Pressurized canister body
	var body_rect := Rect2(-6, -11, 12, 22)
	draw_rect(body_rect, Color(0.85, 0.90, 0.95))
	draw_rect(body_rect, Color(0.10, 0.15, 0.22), false, 1.2)
	
	# Cyan liquid oxygen viewport
	var tank_rect := Rect2(-4, -6, 8, 12)
	draw_rect(tank_rect, Color(0.05, 0.15, 0.25))
	draw_rect(Rect2(-3, -5 + pulse, 6, 10), _core_color)
	
	# Metallic valve caps
	draw_rect(Rect2(-4, -13, 8, 3), Color(0.3, 0.35, 0.45))
	draw_rect(Rect2(-4, 10, 8, 3), Color(0.3, 0.35, 0.45))


func _draw_metal_ingot(_pulse: float) -> void:
	# Hexagonal / Trapezoidal Titanium Ingot
	var ingot_pts: PackedVector2Array = [
		Vector2(-10, -5), Vector2(-6, -10), Vector2(6, -10), Vector2(10, -5),
		Vector2(8, 7), Vector2(-8, 7)
	]
	draw_colored_polygon(ingot_pts, _core_color)
	draw_polyline(ingot_pts, Color(0.15, 0.12, 0.08), 1.2)
	
	# Bevel Sheen Highlight
	draw_line(Vector2(-6, -8), Vector2(4, -8), _accent_color, 1.5)
	draw_line(Vector2(-7, 0), Vector2(7, 0), Color(_core_color.darkened(0.2)), 1.2)


func _draw_energy_crystal(_pulse: float) -> void:
	# Prismatic Crystal Shard
	var crystal_pts: PackedVector2Array = [
		Vector2(0, -14), Vector2(8, -4), Vector2(6, 9),
		Vector2(0, 13), Vector2(-6, 9), Vector2(-8, -4)
	]
	draw_colored_polygon(crystal_pts, _core_color)
	draw_polyline(crystal_pts, Color(0.15, 0.05, 0.25), 1.2)
	
	# Facet Highlight Lines
	draw_line(Vector2(0, -14), Vector2(0, 13), _accent_color, 1.2)
	draw_line(Vector2(-8, -4), Vector2(0, 0), _accent_color, 1.0)
	draw_line(Vector2(8, -4), Vector2(0, 0), _accent_color, 1.0)


func _draw_scientific_sample(pulse: float) -> void:
	# Specimen Flask / Cryo-Vial
	var vial_rect := Rect2(-6, -10, 12, 20)
	draw_rect(vial_rect, Color(0.85, 0.95, 0.90, 0.4))
	draw_rect(vial_rect, Color(0.15, 0.25, 0.20), false, 1.2)
	
	# Bio-Specimen Organic Swirl inside
	draw_circle(Vector2(0, -1), 4.0 + pulse * 1.0, _core_color)
	draw_circle(Vector2(0, -1), 2.0, _accent_color)
	
	# Vial Cap
	draw_rect(Rect2(-4, -13, 8, 4), Color(0.15, 0.35, 0.25))
