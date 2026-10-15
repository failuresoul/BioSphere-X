extends Node2D
class_name AlienEnemyVisual
## Procedural Animated Visuals for BioSphere-X Alien Crawler / Stalker.
## Features animated chitinous body segments, multi-leg scuttle walk cycle,
## dynamic predatory eye glow reflecting state, attack lunges, damage flash, and death pose.

enum VisualState { IDLE, PATROL, CHASE, ATTACK, INVESTIGATE, DEAD }

@export var chitin_color: Color = Color(0.12, 0.14, 0.18)        # Dark biomechanical carapace
@export var chitin_highlight: Color = Color(0.24, 0.28, 0.36)    # Edge sheen
@export var bio_glow_color: Color = Color(0.85, 0.25, 0.95)       # Acid violet bioluminescence
@export var eye_color_idle: Color = Color(1.00, 0.70, 0.15)      # Amber ambient eyes
@export var eye_color_chase: Color = Color(1.00, 0.20, 0.25)     # Aggressive crimson eyes
@export var eye_color_investigate: Color = Color(0.20, 0.85, 1.0) # Inquisitive cyan eyes

var current_state: VisualState = VisualState.IDLE
var facing_angle: float = 0.0
var walk_speed_factor: float = 0.0
var attack_windup_ratio: float = 0.0
var is_dead: bool = false

var _walk_cycle: float = 0.0
var _anim_time: float = 0.0
var _damage_flash_timer: float = 0.0


func _process(delta: float) -> void:
	_anim_time += delta
	if _damage_flash_timer > 0.0:
		_damage_flash_timer = maxf(0.0, _damage_flash_timer - delta)
	
	if walk_speed_factor > 0.0:
		_walk_cycle += delta * walk_speed_factor * 12.0
	
	queue_redraw()


func update_motion(velocity: Vector2, state: int, delta: float) -> void:
	current_state = state as VisualState
	var speed := velocity.length()
	walk_speed_factor = clampf(speed / 160.0, 0.0, 1.5)
	
	if speed > 8.0:
		var target_angle := velocity.angle()
		facing_angle = lerp_angle(facing_angle, target_angle, delta * 12.0)


func play_damage_flash() -> void:
	_damage_flash_timer = 0.25
	queue_redraw()


func play_death() -> void:
	is_dead = true
	queue_redraw()


func _draw() -> void:
	# 1. Ground Drop Shadow
	var shadow_r: float = 16.0 if not is_dead else 20.0
	draw_set_transform(Vector2(2, 4), 0.0, Vector2(1.2, 0.65))
	draw_circle(Vector2.ZERO, shadow_r, Color(0.02, 0.03, 0.05, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	
	if is_dead:
		_draw_dead_pose()
		return
	
	# Root entity rotation
	draw_set_transform(Vector2.ZERO, facing_angle, Vector2.ONE)
	
	# Palette adjustments during damage flash
	var is_flash := _damage_flash_timer > 0.0
	var c_chitin := Color(1.0, 0.35, 0.35) if is_flash else chitin_color
	var c_sheen := Color(1.0, 0.7, 0.7) if is_flash else chitin_highlight
	var c_bio := Color(1.0, 0.9, 0.9) if is_flash else bio_glow_color
	
	# Eye color based on state
	var c_eyes: Color = eye_color_idle
	match current_state:
		VisualState.CHASE, VisualState.ATTACK:
			c_eyes = eye_color_chase
		VisualState.INVESTIGATE:
			c_eyes = eye_color_investigate
	
	# 2. Animated Articulated Legs (6 Legs)
	_draw_legs(c_chitin)
	
	# 3. Abdomen / Tail Segment
	var breath := sin(_anim_time * 3.5) * 1.5
	var abdomen_pts: PackedVector2Array = [
		Vector2(-16 + breath * 0.5, 0),
		Vector2(-8, -9),
		Vector2(-2, -7),
		Vector2(-2, 7),
		Vector2(-8, 9)
	]
	draw_colored_polygon(abdomen_pts, c_chitin)
	draw_polyline(abdomen_pts, c_sheen, 1.2)
	
	# Bioluminescent abdomen nodes
	draw_circle(Vector2(-10, 0), 3.0, c_bio)
	draw_circle(Vector2(-5, -3), 1.5, c_bio)
	draw_circle(Vector2(-5, 3), 1.5, c_bio)
	
	# 4. Main Thorax Carapace
	var thorax_pts: PackedVector2Array = [
		Vector2(-4, -8),
		Vector2(6, -6),
		Vector2(10, 0),
		Vector2(6, 6),
		Vector2(-4, 8)
	]
	draw_colored_polygon(thorax_pts, c_chitin.lightened(0.08))
	draw_polyline(thorax_pts, c_sheen, 1.3)
	
	# 5. Head & Predatory Mandibles
	var head_pos := Vector2(10, 0)
	draw_circle(head_pos, 6.0, c_chitin)
	draw_arc(head_pos, 6.0, 0, TAU, 16, c_sheen, 1.2)
	
	# Mandibles (pincers that snap forward during attack)
	var snap := attack_windup_ratio * 4.0
	# Upper mandible
	draw_line(head_pos + Vector2(4, -3), head_pos + Vector2(10 - snap, -6 + snap), c_sheen, 2.0)
	# Lower mandible
	draw_line(head_pos + Vector2(4, 3), head_pos + Vector2(10 - snap, 6 - snap), c_sheen, 2.0)
	
	# Multi-cluster Predatory Eyes
	draw_circle(head_pos + Vector2(3, -2.5), 1.6, c_eyes)
	draw_circle(head_pos + Vector2(3, 2.5), 1.6, c_eyes)
	draw_circle(head_pos + Vector2(1.5, -4.5), 1.2, c_eyes)
	draw_circle(head_pos + Vector2(1.5, 4.5), 1.2, c_eyes)


func _draw_legs(leg_color: Color) -> void:
	# 6 legs: 3 on left (local -Y), 3 on right (local +Y)
	var leg_angles := [-0.5, 0.0, 0.5]
	for i in 3:
		var leg_phase: float = _walk_cycle + float(i) * 1.05
		var foot_swing: float = sin(leg_phase) * 6.0 * walk_speed_factor
		var base_x := -6.0 + float(i) * 6.0
		
		# Left leg
		var knee_l := Vector2(base_x - 4, -13)
		var foot_l := Vector2(base_x + foot_swing, -19)
		draw_line(Vector2(base_x, -4), knee_l, leg_color, 2.0)
		draw_line(knee_l, foot_l, leg_color, 1.4)
		
		# Right leg (opposite phase)
		var knee_r := Vector2(base_x - 4, 13)
		var foot_r := Vector2(base_x - foot_swing, 19)
		draw_line(Vector2(base_x, 4), knee_r, leg_color, 2.0)
		draw_line(knee_r, foot_r, leg_color, 1.4)


func _draw_dead_pose() -> void:
	# Curled collapsed legs and dimmed carapace
	draw_set_transform(Vector2(0, 2), facing_angle, Vector2(0.9, 0.6))
	draw_circle(Vector2(-4, 0), 10.0, chitin_color.darkened(0.4))
	draw_circle(Vector2(6, 0), 6.0, chitin_color.darkened(0.4))
	draw_arc(Vector2(-4, 0), 10.0, 0, TAU, 16, Color(0.2, 0.22, 0.26), 1.2)
