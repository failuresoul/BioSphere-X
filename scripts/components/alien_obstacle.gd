extends StaticBody2D
## Large alien structure obstacle — collision + procedural visuals.

var structure_width := 50.0
var structure_height := 40.0
var base_color := Color(0.16, 0.16, 0.29)      # Dark blue-grey
var accent_color := Color(0.4, 0.2, 0.8, 0.6)  # Purple glow accents
var edge_color := Color(0.3, 0.25, 0.45)


func setup(w: float, h: float) -> void:
	structure_width = w
	structure_height = h
	base_color = base_color.lightened(randf_range(-0.03, 0.05))
	_create_collision()
	queue_redraw()


func _create_collision() -> void:
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(structure_width, structure_height)
	col.shape = shape
	add_child(col)


func _draw() -> void:
	var hw := structure_width / 2.0
	var hh := structure_height / 2.0
	# Shadow
	draw_rect(Rect2(-hw + 4, -hh + 5, structure_width, structure_height), Color(0, 0, 0, 0.3))
	# Main structure
	draw_rect(Rect2(-hw, -hh, structure_width, structure_height), base_color)
	# Edge highlights (top + left)
	draw_rect(Rect2(-hw, -hh, structure_width, 3), edge_color)
	draw_rect(Rect2(-hw, -hh, 3, structure_height), edge_color)
	# Interior detail lines
	draw_line(Vector2(-hw + 8, -hh + 8), Vector2(hw - 8, -hh + 8), accent_color, 1.0)
	draw_line(Vector2(-hw + 8, hh - 8), Vector2(hw - 8, hh - 8), accent_color, 1.0)
	# Accent dots
	draw_circle(Vector2(-hw * 0.5, 0), 3.0, accent_color)
	draw_circle(Vector2(hw * 0.5, 0), 3.0, accent_color)
	# Center glow
	draw_circle(Vector2.ZERO, 4.0, Color(accent_color, 0.15))
	draw_circle(Vector2.ZERO, 2.0, accent_color)
