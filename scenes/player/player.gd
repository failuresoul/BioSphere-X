extends CharacterBody2D
## Player character — sci-fi explorer on an alien exoplanet.
## Supports arrow keys and WASD for top-down movement.

const SPEED := 220.0

# Visual palette
var body_color := Color(0.0, 0.83, 1.0)        # Cyan suit
var visor_color := Color(0.22, 1.0, 0.08)       # Green visor
var pack_color := Color(0.0, 0.45, 0.6)         # Darker cyan backpack
var outline_color := Color(0.75, 0.9, 1.0, 0.8) # Light outline


func _physics_process(_delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		dir.x -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		dir.x += 1.0
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		dir.y -= 1.0
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		dir.y += 1.0
	velocity = dir.normalized() * SPEED if dir != Vector2.ZERO else Vector2.ZERO
	move_and_slide()


func _draw() -> void:
	# Drop shadow
	draw_circle(Vector2(2, 3), 13.0, Color(0, 0, 0, 0.35))
	# Backpack
	draw_rect(Rect2(-6, 3, 12, 9), pack_color)
	# Main body
	draw_circle(Vector2.ZERO, 11.0, body_color)
	# Shoulder pads
	draw_circle(Vector2(-9, -1), 4.0, pack_color)
	draw_circle(Vector2(9, -1), 4.0, pack_color)
	# Helmet visor glow (outer)
	draw_circle(Vector2(0, -2), 7.0, Color(visor_color, 0.15))
	# Helmet visor (inner)
	draw_circle(Vector2(0, -2), 4.0, visor_color)
	# Visor shine
	draw_circle(Vector2(-1.5, -3.5), 1.5, Color(1, 1, 1, 0.6))
	# Body outline
	draw_arc(Vector2.ZERO, 11.0, 0, TAU, 32, outline_color, 1.5)
