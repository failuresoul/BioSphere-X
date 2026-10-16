extends StaticBody2D
class_name CanyonWall
## Solid canyon wall ridge forming natural corridors and narrow passages.
## Features distinct cliff-top rim highlights, stratified rock coloring, and ground shadows.

var size: Vector2 = Vector2(128, 64)

# Geological rock strata palette
const WALL_BASE := Color(0.24, 0.20, 0.26)       # Deep alien slate
const WALL_STRATA := Color(0.32, 0.27, 0.35)     # Lighter mineral vein
const WALL_RIM := Color(0.55, 0.48, 0.60)        # Elevated illuminated cliff rim
const WALL_SHADOW := Color(0.04, 0.03, 0.06, 0.60)
const OUTLINE_COLOR := Color(0.08, 0.06, 0.10)


var wall_base_color: Variant = null


func setup(p_size: Vector2, p_color: Variant = null) -> void:
	size = p_size
	if p_color is Color:
		wall_base_color = p_color
	collision_layer = 1
	collision_mask = 1
	
	var col := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = size
	col.shape = rect_shape
	add_child(col)
	queue_redraw()


func _draw() -> void:
	# 1. Base Ground Shadow (projected below wall)
	var shadow_rect := Rect2(-size.x * 0.5 + 4, -size.y * 0.5 + 6, size.x, size.y)
	draw_rect(shadow_rect, WALL_SHADOW)
	
	# 2. Main Wall Body
	var r := Rect2(-size.x * 0.5, -size.y * 0.5, size.x, size.y)
	var base_c: Color = wall_base_color if wall_base_color is Color else WALL_BASE
	draw_rect(r, base_c)
	draw_rect(r, OUTLINE_COLOR, false, 2.0)
	
	# 3. Horizontal Geological Strata Bands
	var band_h := maxf(4.0, size.y * 0.18)
	var band_y := r.position.y + size.y * 0.4
	draw_rect(Rect2(r.position.x + 2, band_y, size.x - 4, band_h), base_c.lightened(0.25))
	
	# 4. Elevated Cliff-Top Rim Highlight (Top edge)
	var rim_h := maxf(3.0, size.y * 0.12)
	draw_rect(Rect2(r.position.x + 2, r.position.y + 2, size.x - 4, rim_h), WALL_RIM)
	
	# Vertical cliff fissures
	var step_x := 40.0
	for x in range(int(r.position.x + 20), int(r.end.x - 20), int(step_x)):
		draw_line(Vector2(x, r.position.y + rim_h), Vector2(x + 4, r.end.y - 4), OUTLINE_COLOR, 1.2)
