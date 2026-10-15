extends Node2D
## Draws the alien planet ground — dark terrain with craters and a subtle grid overlay.

var world_origin := Vector2(-1500, -1500)
var world_size := Vector2(3000, 3000)
var base_color := Color(0.078, 0.063, 0.165)     # Deep indigo
var grid_color := Color(0.15, 0.12, 0.28, 0.18)  # Faint grid lines
var craters: Array = []


func setup(origin: Vector2, size: Vector2) -> void:
	world_origin = origin
	world_size = size
	_generate_craters()
	queue_redraw()


func _generate_craters() -> void:
	craters.clear()
	for i in 80:
		craters.append({
			"pos": Vector2(
				randf_range(world_origin.x + 20, world_origin.x + world_size.x - 20),
				randf_range(world_origin.y + 20, world_origin.y + world_size.y - 20)
			),
			"radius": randf_range(4.0, 22.0),
			"shade": randf_range(0.02, 0.07),
		})


func _draw() -> void:
	# Solid base
	draw_rect(Rect2(world_origin, world_size), base_color)

	# Grid overlay
	var step := 120
	var x0 := int(world_origin.x)
	var y0 := int(world_origin.y)
	var x1 := int(world_origin.x + world_size.x)
	var y1 := int(world_origin.y + world_size.y)
	for x in range(x0, x1 + 1, step):
		draw_line(Vector2(x, y0), Vector2(x, y1), grid_color, 0.5)
	for y in range(y0, y1 + 1, step):
		draw_line(Vector2(x0, y), Vector2(x1, y), grid_color, 0.5)

	# Craters / terrain variation
	for c in craters:
		var col := base_color.lightened(c.shade)
		draw_circle(c.pos, c.radius, col)
		draw_arc(c.pos, c.radius * 0.85, 0.4, 3.2, 12, base_color.darkened(0.04), 1.0)
