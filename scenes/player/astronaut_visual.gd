extends Node2D
class_name AstronautVisual
## Attractive procedural sci-fi astronaut visual placeholder.
## Designed to be completely modular so it can be swapped with a Sprite2D
## or AnimatedSprite2D in the future without modifying any gameplay code.

@export var suit_color: Color = Color(0.92, 0.94, 0.96)        # Clean titanium white EVA suit
@export var accent_color: Color = Color(0.12, 0.65, 0.95)     # Sci-fi electric cyan trim
@export var visor_color: Color = Color(0.10, 0.88, 0.60)      # Bioluminescent emerald/cyan visor
@export var pack_color: Color = Color(0.20, 0.24, 0.30)       # Dark carbon composite backpack
@export var outline_color: Color = Color(0.08, 0.10, 0.14, 0.9) # Clean dark contrast outline

var _facing_angle: float = 0.0
var _walk_cycle: float = 0.0
var _is_moving: bool = false
var _damage_flash_timer: float = 0.0


func _process(delta: float) -> void:
	if _damage_flash_timer > 0.0:
		_damage_flash_timer = max(0.0, _damage_flash_timer - delta)
		queue_redraw()


func update_motion(velocity: Vector2, delta: float) -> void:
	var speed := velocity.length()
	_is_moving = speed > 5.0
	
	if _is_moving:
		var target_angle := velocity.angle()
		_facing_angle = lerp_angle(_facing_angle, target_angle, delta * 14.0)
		_walk_cycle += delta * speed * 0.06
	
	queue_redraw()


func play_damage_flash() -> void:
	_damage_flash_timer = 0.2
	queue_redraw()


func _draw() -> void:
	# Subtle walk bobbing
	var bob := sin(_walk_cycle) * 1.5 if _is_moving else 0.0
	
	# 1. Ground Drop Shadow
	draw_set_transform(Vector2(2, 6), 0, Vector2(1.2, 0.7))
	draw_circle(Vector2.ZERO, 13.0, Color(0.02, 0.03, 0.05, 0.45))
	
	# Transform for astronaut body rotated in facing direction
	draw_set_transform(Vector2(0, bob), _facing_angle, Vector2.ONE)
	
	var is_flashing := _damage_flash_timer > 0.0
	var current_suit := Color(1, 0.3, 0.3) if is_flashing else suit_color
	var current_accent := Color(1, 0.8, 0.8) if is_flashing else accent_color
	
	# 2. Oxygen & Thruster Backpack (behind body, at -X relative to facing angle)
	var pack_rect := Rect2(-14, -7, 6, 14)
	draw_rect(pack_rect, pack_color)
	draw_rect(pack_rect, outline_color, false, 1.2)
	# Pack status LED
	draw_circle(Vector2(-11, 0), 1.5, visor_color)
	
	# Thruster exhaust trail if moving
	if _is_moving:
		var flicker := randf_range(3.0, 7.0)
		draw_line(Vector2(-14, -3), Vector2(-14 - flicker, -3), Color(0.2, 0.8, 1.0, 0.7), 2.0)
		draw_line(Vector2(-14, 3), Vector2(-14 - flicker, 3), Color(0.2, 0.8, 1.0, 0.7), 2.0)
	
	# 3. Main Torso Suit
	# Shoulders / arms
	var left_hand_offset := sin(_walk_cycle) * 2.5 if _is_moving else 0.0
	var right_hand_offset := -sin(_walk_cycle) * 2.5 if _is_moving else 0.0
	draw_circle(Vector2(-1 + left_hand_offset, -10), 4.5, current_accent)
	draw_circle(Vector2(-1 + right_hand_offset, 10), 4.5, current_accent)
	draw_arc(Vector2(-1 + left_hand_offset, -10), 4.5, 0, TAU, 16, outline_color, 1.0)
	draw_arc(Vector2(-1 + right_hand_offset, 10), 4.5, 0, TAU, 16, outline_color, 1.0)
	
	# Torso pod
	draw_circle(Vector2(-2, 0), 11.5, current_suit)
	draw_arc(Vector2(-2, 0), 11.5, 0, TAU, 24, outline_color, 1.5)
	
	# Chest life-support module plate
	draw_rect(Rect2(-4, -4, 5, 8), current_accent)
	
	# 4. Helmet & Visor
	var helmet_pos := Vector2(2, 0)
	draw_circle(helmet_pos, 8.5, current_suit)
	draw_arc(helmet_pos, 8.5, 0, TAU, 20, outline_color, 1.2)
	
	# Visor Outer Glow
	var visor_center := helmet_pos + Vector2(3, 0)
	draw_circle(visor_center, 6.0, Color(visor_color.r, visor_color.g, visor_color.b, 0.25))
	
	# Curved Visor Glass
	var visor_points: PackedVector2Array = [
		visor_center + Vector2(1, -4.5),
		visor_center + Vector2(4, -2.5),
		visor_center + Vector2(5, 0),
		visor_center + Vector2(4, 2.5),
		visor_center + Vector2(1, 4.5),
		visor_center + Vector2(-1, 2.5),
		visor_center + Vector2(-1, -2.5)
	]
	draw_colored_polygon(visor_points, visor_color)
	draw_polyline(visor_points, outline_color, 1.2)
	
	# Glass Glare Specular Highlight
	draw_line(visor_center + Vector2(2, -2.5), visor_center + Vector2(3.5, -0.5), Color(1, 1, 1, 0.85), 1.2)
