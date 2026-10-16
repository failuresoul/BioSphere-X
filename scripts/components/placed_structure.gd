extends StaticBody2D
class_name PlacedStructure
## Visual and physical in-world representation of a committed base structure in BioSphere-X.

@export var structure_id: String = ""
var structure_name: String = "Base Facility"
var structure_icon: String = "🏗️"
var grid_position: Vector2i = Vector2i.ZERO
var cell_width: int = 1
var cell_height: int = 1
var base_color: Color = Color(0.18, 0.75, 0.95)
var cell_size: float = 32.0

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
	
	if "color" in data:
		base_color = data.get("color")
	
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


func _process(delta: float) -> void:
	_pulse_timer += delta * 2.5
	queue_redraw()


func _draw() -> void:
	var w: float = float(cell_width) * cell_size
	var h: float = float(cell_height) * cell_size
	var rect := Rect2(2.0, 2.0, w - 4.0, h - 4.0)
	
	# Foundation shadow
	draw_rect(Rect2(4.0, 4.0, w - 4.0, h - 4.0), Color(0.0, 0.0, 0.0, 0.5), true)
	
	# Primary metallic foundation slab
	draw_rect(rect, Color(0.06, 0.09, 0.14, 0.95), true)
	
	# Glowing accent border
	var pulse := (sin(_pulse_timer) + 1.0) * 0.5
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
	
	# Center status indicator dot
	draw_circle(Vector2(w * 0.5, h * 0.5), 3.0 + pulse * 1.5, edge_col)
