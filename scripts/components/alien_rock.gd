extends StaticBody2D
## Procedurally generated alien rock with collision and mineral vein details.

var points: PackedVector2Array = PackedVector2Array()
var rock_color := Color(0.29, 0.25, 0.36)    # Purple-grey
var highlight_color := Color(0.4, 0.35, 0.5)
var vein_color := Color(0.5, 0.2, 0.7, 0.4)  # Glowing purple veins
var rock_size := 20.0


func setup(size: float) -> void:
	rock_size = size
	rock_color = rock_color.lightened(randf_range(-0.05, 0.1))
	_generate_shape()
	_create_collision()
	queue_redraw()


func _generate_shape() -> void:
	points.clear()
	var num_verts := randi_range(5, 8)
	for i in num_verts:
		var angle := (TAU / num_verts) * i + randf_range(-0.3, 0.3)
		var radius := rock_size * randf_range(0.6, 1.0)
		points.append(Vector2(cos(angle), sin(angle)) * radius)


func _create_collision() -> void:
	var col := CollisionPolygon2D.new()
	col.polygon = points
	add_child(col)


func _draw() -> void:
	if points.is_empty():
		return
	# Shadow
	var shadow := PackedVector2Array()
	for p in points:
		shadow.append(p + Vector2(3, 5))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.3))
	# Main body
	draw_colored_polygon(points, rock_color)
	# Top-left highlight
	var highlight := PackedVector2Array()
	for p in points:
		highlight.append(p * 0.65 + Vector2(-2, -3))
	draw_colored_polygon(highlight, highlight_color)
	# Outline
	var outline := PackedVector2Array()
	for p in points:
		outline.append(p)
	outline.append(points[0])
	draw_polyline(outline, rock_color.darkened(0.25), 1.5)
	# Mineral veins
	if points.size() >= 4:
		draw_line(points[0] * 0.2, points[2] * 0.6, vein_color, 1.0)
		draw_line(points[1] * 0.3, points[3] * 0.5, vein_color, 0.8)
