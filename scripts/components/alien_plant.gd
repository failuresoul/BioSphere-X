extends Node2D
## Bioluminescent alien plant — decorative, no collision.

var stem_color := Color(0.1, 0.42, 0.32)   # Dark teal
var glow_color := Color(0.0, 1.0, 0.53)    # Bright bioluminescent green
var branches: Array = []


func setup() -> void:
	_generate_branches()
	# Slight hue variation per plant
	glow_color = glow_color.lerp(
		Color(0.1, 0.7, 1.0),
		clampf(randf_range(0.0, 0.5), 0.0, 1.0)
	)
	queue_redraw()


func _generate_branches() -> void:
	branches.clear()
	var count := randi_range(2, 5)
	for i in count:
		branches.append({
			"angle": randf_range(-0.9, 0.9),
			"length": randf_range(12.0, 35.0),
			"tip_radius": randf_range(2.0, 5.0),
			"glow_alpha": randf_range(0.3, 0.8),
			"curve": randf_range(-0.4, 0.4),
		})


func _draw() -> void:
	# Root bulb
	draw_circle(Vector2.ZERO, 3.5, stem_color.darkened(0.15))
	draw_circle(Vector2.ZERO, 2.0, stem_color)

	for b in branches:
		var mid: Vector2 = Vector2(
			sin(b.angle + b.curve), -cos(b.angle + b.curve)
		) * b.length * 0.5
		var end: Vector2 = Vector2(sin(b.angle), -cos(b.angle)) * b.length
		# Stem segments
		draw_line(Vector2.ZERO, mid, stem_color, 2.0)
		draw_line(mid, end, stem_color.lightened(0.1), 1.5)
		# Outer glow halo
		draw_circle(end, b.tip_radius * 3.0, Color(glow_color, b.glow_alpha * 0.12))
		draw_circle(end, b.tip_radius * 1.8, Color(glow_color, b.glow_alpha * 0.25))
		# Bright tip
		draw_circle(end, b.tip_radius, glow_color)
		draw_circle(end, b.tip_radius * 0.4, Color(1, 1, 1, 0.5))
