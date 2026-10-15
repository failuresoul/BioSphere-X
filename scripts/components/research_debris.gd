extends StaticBody2D
class_name ResearchDebris
## Abandoned research outpost debris, cargo containers, and shattered solar modules.
## Provides solid cover, blocks movement, and offers high visual sci-fi contrast.

enum DebrisType { HABITAT_MODULE, CARGO_CRATE, SOLAR_ARRAY, COMM_DISH }

var debris_type: DebrisType = DebrisType.HABITAT_MODULE
var size: Vector2 = Vector2(64, 48)

# Palette: Industrial metallic salvage
const METAL_DARK := Color(0.18, 0.20, 0.24)
const METAL_BASE := Color(0.32, 0.35, 0.40)
const METAL_LIGHT := Color(0.48, 0.52, 0.58)
const HAZARD_YELLOW := Color(0.95, 0.72, 0.12)
const HAZARD_DARK := Color(0.12, 0.12, 0.14)
const SOLAR_BLUE := Color(0.12, 0.42, 0.78)
const SOLAR_GLINT := Color(0.40, 0.75, 1.0, 0.8)
const BEACON_RED := Color(0.95, 0.18, 0.22)
const OUTLINE_COLOR := Color(0.06, 0.08, 0.10)


func setup(p_type: DebrisType, p_size: Vector2 = Vector2.ZERO) -> void:
	debris_type = p_type
	collision_layer = 1
	collision_mask = 1
	
	if p_size != Vector2.ZERO:
		size = p_size
	else:
		match debris_type:
			DebrisType.HABITAT_MODULE: size = Vector2(72, 54)
			DebrisType.CARGO_CRATE: size = Vector2(36, 36)
			DebrisType.SOLAR_ARRAY: size = Vector2(80, 32)
			DebrisType.COMM_DISH: size = Vector2(44, 44)
	
	var col := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = size - Vector2(4, 4)
	col.shape = rect_shape
	add_child(col)
	queue_redraw()


func _draw() -> void:
	# 1. Cast Drop Shadow
	var shadow_rect := Rect2(-size.x * 0.5 + 4, -size.y * 0.5 + 6, size.x, size.y)
	draw_rect(shadow_rect, Color(0.02, 0.03, 0.06, 0.5))
	
	match debris_type:
		DebrisType.HABITAT_MODULE:
			_draw_habitat_module()
		DebrisType.CARGO_CRATE:
			_draw_cargo_crate()
		DebrisType.SOLAR_ARRAY:
			_draw_solar_array()
		DebrisType.COMM_DISH:
			_draw_comm_dish()


func _draw_habitat_module() -> void:
	var r := Rect2(-size.x * 0.5, -size.y * 0.5, size.x, size.y)
	# Main hull body
	draw_rect(r, METAL_BASE)
	draw_rect(r, OUTLINE_COLOR, false, 2.0)
	
	# Top reinforced armor panel
	var top_panel := Rect2(r.position + Vector2(4, 4), r.size - Vector2(8, 8))
	draw_rect(top_panel, METAL_DARK)
	
	# Yellow hazard warning stripes along front lip
	var stripe_w: float = 6.0
	for i in range(0, int(size.x - 12), int(stripe_w * 2.0)):
		var sx := r.position.x + 6.0 + float(i)
		draw_line(Vector2(sx, r.end.y - 6), Vector2(sx + stripe_w, r.end.y - 6), HAZARD_YELLOW, 3.0)
	
	# Emergency telemetry beacon (blinking red)
	draw_circle(r.position + Vector2(10, 10), 3.5, BEACON_RED)
	draw_circle(r.position + Vector2(10, 10), 6.0, Color(BEACON_RED.r, BEACON_RED.g, BEACON_RED.b, 0.3))


func _draw_cargo_crate() -> void:
	var r := Rect2(-size.x * 0.5, -size.y * 0.5, size.x, size.y)
	draw_rect(r, METAL_DARK)
	draw_rect(r, OUTLINE_COLOR, false, 2.0)
	
	# Structural X brace
	draw_line(r.position + Vector2(4, 4), r.end - Vector2(4, 4), METAL_LIGHT, 2.0)
	draw_line(Vector2(r.position.x + 4, r.end.y - 4), Vector2(r.end.x - 4, r.position.y + 4), METAL_LIGHT, 2.0)
	
	# Center locking clamp
	draw_rect(Rect2(-5, -5, 10, 10), HAZARD_YELLOW)
	draw_rect(Rect2(-5, -5, 10, 10), OUTLINE_COLOR, false, 1.2)


func _draw_solar_array() -> void:
	var r := Rect2(-size.x * 0.5, -size.y * 0.5, size.x, size.y)
	# Metal mount frame
	draw_rect(r, METAL_DARK)
	draw_rect(r, OUTLINE_COLOR, false, 2.0)
	
	# Photovoltaic grid segments
	var cell_w := (size.x - 12.0) / 4.0
	var cell_h := size.y - 8.0
	for i in 4:
		var cx := r.position.x + 4.0 + float(i) * (cell_w + 1.0)
		var cell_rect := Rect2(cx, r.position.y + 4.0, cell_w, cell_h)
		draw_rect(cell_rect, SOLAR_BLUE)
		draw_rect(cell_rect, OUTLINE_COLOR, false, 1.0)
		# Diagonal specular glint
		draw_line(cell_rect.position + Vector2(2, cell_h - 2), cell_rect.position + Vector2(cell_w - 2, 2), SOLAR_GLINT, 1.2)


func _draw_comm_dish() -> void:
	var radius := size.x * 0.45
	draw_circle(Vector2.ZERO, radius, METAL_BASE)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 24, OUTLINE_COLOR, 2.0)
	# Concentric dish receivers
	draw_arc(Vector2.ZERO, radius * 0.65, 0, TAU, 20, METAL_LIGHT, 1.5)
	draw_circle(Vector2.ZERO, 4.0, BEACON_RED)
	draw_line(Vector2.ZERO, Vector2(radius * 0.7, -radius * 0.5), METAL_LIGHT, 2.0)
