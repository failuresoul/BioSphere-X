extends StaticBody2D
class_name PlacedStructure
## Visual and physical in-world representation of a committed base structure in BioSphere-X.
## Supports area illumination (lights), status pulsing, and safe deconstruction.

@export var structure_id: String = ""
var structure_name: String = "Base Facility"
var structure_icon: String = "🏗️"
var grid_position: Vector2i = Vector2i.ZERO
var cell_width: int = 1
var cell_height: int = 1
var base_color: Color = Color(0.18, 0.75, 0.95)
var cell_size: float = 32.0
var structure_cost: Dictionary = {}
var light_radius: float = 0.0
var is_hovered_for_demolish: bool = false

var _pulse_timer: float = 0.0
var _collision_shape: CollisionShape2D = null


func _ready() -> void:
	add_to_group("base_structures")
	_setup_collision()
	queue_redraw()


func configure(data: RefCounted, grid_pos: Vector2i, p_cell_size: float = 32.0) -> void:
	structure_id = str(data.get("id"))
	structure_name = str(data.get("name"))
	structure_icon = str(data.get("icon"))
	cell_width = int(data.get("width"))
	cell_height = int(data.get("height"))
	cell_size = p_cell_size
	grid_position = grid_pos
	
	if "cost" in data:
		structure_cost = data.get("cost").duplicate()
	if "color" in data:
		base_color = data.get("color")
	if "light_radius" in data:
		light_radius = float(data.get("light_radius"))
	
	_setup_collision()
	queue_redraw()


func _setup_collision() -> void:
	if not _collision_shape:
		_collision_shape = CollisionShape2D.new()
		add_child(_collision_shape)
	
	var w: float = float(cell_width) * cell_size
	var h: float = float(cell_height) * cell_size
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = Vector2(w - 4.0, h - 4.0)
	_collision_shape.shape = rect_shape
	_collision_shape.position = Vector2(w * 0.5, h * 0.5)


func set_demolish_highlight(enable: bool) -> void:
	if is_hovered_for_demolish != enable:
		is_hovered_for_demolish = enable
		queue_redraw()


func get_refund_resources(ratio: float = 0.5) -> Dictionary:
	var refund := {}
	for res_k in structure_cost:
		var cost_val: int = int(structure_cost[res_k])
		var ref_amt: int = maxi(1, int(floor(float(cost_val) * ratio)))
		refund[res_k] = ref_amt
	return refund


func _process(delta: float) -> void:
	_pulse_timer += delta * 2.5
	queue_redraw()


func _draw() -> void:
	var w: float = float(cell_width) * cell_size
	var h: float = float(cell_height) * cell_size
	var center := Vector2(w * 0.5, h * 0.5)
	
	# 1. Area Light Illumination Aura (if structure is a light/illuminator)
	if light_radius > 0.0:
		var light_pulse := (sin(_pulse_timer * 1.5) + 1.0) * 0.1
		# Outer soft ambient light disc
		draw_circle(center, light_radius + light_pulse * 10.0, Color(1.0, 0.95, 0.6, 0.08))
		draw_circle(center, light_radius * 0.5, Color(1.0, 0.95, 0.6, 0.14))
		draw_arc(center, light_radius, 0.0, TAU, 32, Color(1.0, 0.9, 0.4, 0.25), 1.0)
	
	var rect := Rect2(2.0, 2.0, w - 4.0, h - 4.0)
	
	# 2. Foundation shadow
	draw_rect(Rect2(4.0, 4.0, w - 4.0, h - 4.0), Color(0.0, 0.0, 0.0, 0.5), true)
	
	# 3. Primary metallic foundation slab
	draw_rect(rect, Color(0.06, 0.09, 0.14, 0.95), true)
	
	# 4. Demolish Warning Highlight vs Glowing Accent Border
	var pulse := (sin(_pulse_timer) + 1.0) * 0.5
	if is_hovered_for_demolish:
		var warn_col := Color(1.0, 0.2, 0.2, 0.8 + pulse * 0.2)
		draw_rect(rect, warn_col, false, 3.0)
		# Diagonal hazard stripes
		draw_line(Vector2(2, 2), Vector2(w - 2, h - 2), Color(1.0, 0.2, 0.2, 0.4), 2.0)
		draw_line(Vector2(w - 2, 2), Vector2(2, h - 2), Color(1.0, 0.2, 0.2, 0.4), 2.0)
	else:
		var edge_col := Color(base_color.r, base_color.g, base_color.b, 0.7 + pulse * 0.3)
		draw_rect(rect, edge_col, false, 2.0)
		
		# Corner tech brackets
		var b_len := mini(int(w * 0.25), 8)
		draw_line(Vector2(2, 2), Vector2(2 + b_len, 2), edge_col, 2.5)
		draw_line(Vector2(2, 2), Vector2(2, 2 + b_len), edge_col, 2.5)
		draw_line(Vector2(w - 2, 2), Vector2(w - 2 - b_len, 2), edge_col, 2.5)
		draw_line(Vector2(w - 2, 2), Vector2(w - 2, 2 + b_len), edge_col, 2.5)
		draw_line(Vector2(2, h - 2), Vector2(2 + b_len, h - 2), edge_col, 2.5)
		draw_line(Vector2(2, h - 2), Vector2(2, h - 2 - b_len), edge_col, 2.5)
		draw_line(Vector2(w - 2, h - 2), Vector2(w - 2 - b_len, h - 2), edge_col, 2.5)
		draw_line(Vector2(w - 2, h - 2), Vector2(w - 2, h - 2 - b_len), edge_col, 2.5)
		
		# Center status indicator
		if light_radius > 0.0:
			draw_circle(center, 5.0 + pulse * 2.0, Color(1.0, 0.95, 0.4, 0.9))
		else:
			draw_circle(center, 3.0 + pulse * 1.5, edge_col)
