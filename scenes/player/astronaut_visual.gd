extends Node2D
class_name AstronautVisual
## Procedural Sci-Fi Astronaut Animation & Visual Feedback System.
## Features:
## - Idle breathing and life-support HUD pulsing
## - Dynamic 8-way directional facing with top-down 3/4 perspective
## - Walk cycle with limb oscillation, footstep cadence, and torso bobbing
## - Visual feedback for start-of-motion burst, direction change bank/skid, and braking settle
## - Integrated lightweight ground dust and thruster particles
## - Completely modular: Does not interfere with Player collision or movement physics.

enum AnimState { IDLE, WALKING }
enum FacingDir { DOWN, DOWN_RIGHT, RIGHT, UP_RIGHT, UP, UP_LEFT, LEFT, DOWN_LEFT }

# Color Palette (Sci-fi Titanium Suit)
@export var suit_color: Color = Color(0.93, 0.95, 0.98)          # Titanium white EVA suit
@export var suit_shadow: Color = Color(0.68, 0.72, 0.80)         # Suit shading
@export var accent_color: Color = Color(0.10, 0.70, 1.00)        # Electric cyan trim
@export var visor_color: Color = Color(0.05, 0.92, 0.65)         # Bioluminescent emerald visor
@export var pack_color: Color = Color(0.18, 0.22, 0.28)          # Carbon composite life-support pack
@export var thruster_glow: Color = Color(0.20, 0.85, 1.00, 0.85) # Plasma exhaust glow
@export var outline_color: Color = Color(0.08, 0.10, 0.14, 0.95) # Dark contrast outline
@export var dust_color: Color = Color(0.45, 0.38, 0.30, 0.50)    # Exoplanet ground dust

# Animation & Motion Timers
var current_anim: AnimState = AnimState.IDLE
var current_facing: FacingDir = FacingDir.DOWN
var facing_vector: Vector2 = Vector2.DOWN

var _facing_angle: float = PI * 0.5 # Default facing down
var _walk_cycle: float = 0.0
var _idle_time: float = 0.0
var _is_moving: bool = false
var _prev_velocity: Vector2 = Vector2.ZERO

# Feedback triggers
var _start_burst_timer: float = 0.0
var _stop_settle_timer: float = 0.0
var _turn_tilt: float = 0.0
var _damage_flash_timer: float = 0.0
var _recoil_offset: Vector2 = Vector2.ZERO
var _muzzle_flash_timer: float = 0.0
var _muzzle_flash_pos: Vector2 = Vector2.ZERO

# Procedural visual particles (dust and thruster sparks)
var _particles: Array[Dictionary] = []


func _process(delta: float) -> void:
	_idle_time += delta
	
	# Update timers
	if _start_burst_timer > 0.0:
		_start_burst_timer = maxf(0.0, _start_burst_timer - delta)
	if _stop_settle_timer > 0.0:
		_stop_settle_timer = maxf(0.0, _stop_settle_timer - delta)
	if _damage_flash_timer > 0.0:
		_damage_flash_timer = maxf(0.0, _damage_flash_timer - delta)
	if _muzzle_flash_timer > 0.0:
		_muzzle_flash_timer = maxf(0.0, _muzzle_flash_timer - delta)
	
	_recoil_offset = _recoil_offset.move_toward(Vector2.ZERO, delta * 35.0)
	_turn_tilt = lerpf(_turn_tilt, 0.0, delta * 10.0)
	
	_update_particles(delta)
	queue_redraw()


func play_attack_recoil(direction: Vector2) -> void:
	var dir := direction.normalized() if direction != Vector2.ZERO else Vector2.DOWN
	_recoil_offset = -dir * 4.0
	_muzzle_flash_timer = 0.08
	_muzzle_flash_pos = dir * 18.0
	queue_redraw()



func update_motion(velocity: Vector2, delta: float) -> void:
	var speed: float = velocity.length()
	var was_moving := _is_moving
	_is_moving = speed > 8.0
	
	# State Transitions & Movement Feedback
	if _is_moving:
		current_anim = AnimState.WALKING
		var target_angle: float = velocity.angle()
		
		# Detect sharp direction change / banking
		if was_moving and _prev_velocity.length() > 20.0:
			var angle_diff: float = wrapf(target_angle - _prev_velocity.angle(), -PI, PI)
			if absf(angle_diff) > 0.45: # > ~25 degrees
				_turn_tilt = clampf(angle_diff * 0.25, -0.3, 0.3)
				_spawn_dust_burst(velocity.normalized() * -10.0, 3)
		
		# Smooth facing rotation
		_facing_angle = lerp_angle(_facing_angle, target_angle, delta * 15.0)
		facing_vector = Vector2.from_angle(_facing_angle)
		_update_facing_enum(facing_vector)
		
		# Cadence advances with speed
		_walk_cycle += delta * speed * 0.065
		
		# Start of movement burst
		if not was_moving:
			_start_burst_timer = 0.22
			_spawn_dust_burst(facing_vector * -14.0, 5)
		
		# Spawn small thruster/dust trails while moving
		if randf() < 0.35:
			_spawn_thruster_particle(facing_vector * -12.0)
			
	else:
		current_anim = AnimState.IDLE
		# Stop / deceleration settle feedback
		if was_moving:
			_stop_settle_timer = 0.20
			_spawn_dust_burst(facing_vector * 6.0, 4)
	
	_prev_velocity = velocity


var is_dead: bool = false


func play_damage_flash() -> void:
	_damage_flash_timer = 0.25
	_spawn_hit_sparks()
	queue_redraw()


func play_death() -> void:
	is_dead = true
	_spawn_dust_burst(Vector2.ZERO, 8)
	queue_redraw()


func reset_visual() -> void:
	is_dead = false
	_damage_flash_timer = 0.0
	queue_redraw()


# ---------------------------------------------------------------------------
# Procedural Drawing & Transforms
# ---------------------------------------------------------------------------
func _draw() -> void:
	# 1. Render ground particles first (beneath astronaut)
	_draw_particles()
	
	if is_dead:
		# Collapsed suit on exoplanet ground
		draw_set_transform(Vector2(2, 6), 0.0, Vector2(1.3, 0.6))
		draw_circle(Vector2.ZERO, 12.0, Color(0.02, 0.03, 0.05, 0.5))
		draw_set_transform(Vector2(0, 3), PI * 0.42, Vector2(1.0, 0.75))
		draw_circle(Vector2(-2, 0), 10.0, suit_shadow)
		draw_circle(Vector2(4, 0), 7.0, Color(0.18, 0.22, 0.26)) # Depowered helmet
		draw_arc(Vector2(-2, 0), 10.0, 0, TAU, 16, outline_color, 1.2)
		return
	
	# 2. Ground Drop Shadow (adjusts dynamically during idle/walk)
	var shadow_squash: float = 1.0
	if _start_burst_timer > 0.0:
		shadow_squash = 1.2
	elif _stop_settle_timer > 0.0:
		shadow_squash = 0.85
	
	draw_set_transform(Vector2(2, 8), 0.0, Vector2(1.25 * shadow_squash, 0.7))
	draw_circle(Vector2.ZERO, 13.0, Color(0.02, 0.03, 0.06, 0.45))
	
	# 3. Calculate Visual squash/stretch & bobbing
	var bob_y: float = 0.0
	var scale_x: float = 1.0
	var scale_y: float = 1.0
	
	if current_anim == AnimState.WALKING:
		# Walking vertical bounce on every step
		bob_y = -absf(sin(_walk_cycle)) * 2.2
		# Subtle forward dynamic lean
		scale_y = 1.02
		scale_x = 0.98
	else:
		# Idle breathing
		bob_y = sin(_idle_time * 2.8) * 0.8
		scale_y = 1.0 + sin(_idle_time * 2.8) * 0.03
		scale_x = 1.0 - sin(_idle_time * 2.8) * 0.02
	
	# Start-of-motion burst anticipation squash
	if _start_burst_timer > 0.0:
		var t := _start_burst_timer / 0.22
		scale_x += t * 0.15
		scale_y -= t * 0.10
	
	# Stop braking settle squash
	if _stop_settle_timer > 0.0:
		var t := _stop_settle_timer / 0.20
		scale_y -= t * 0.12
		scale_x += t * 0.08
	
	# Apply astronaut root visual transform
	var total_rot: float = _facing_angle + _turn_tilt
	draw_set_transform(Vector2(0, bob_y) + _recoil_offset, total_rot, Vector2(scale_x, scale_y))

	
	# Palette adjustments for damage flash
	var is_flash := _damage_flash_timer > 0.0
	var suit_c := Color(1.0, 0.35, 0.35) if is_flash else suit_color
	var suit_s := Color(0.8, 0.20, 0.20) if is_flash else suit_shadow
	var accent_c := Color(1.0, 0.85, 0.85) if is_flash else accent_color
	
	# Visor breathing pulse in idle
	var visor_pulse_alpha := 0.25
	if current_anim == AnimState.IDLE:
		visor_pulse_alpha = 0.20 + sin(_idle_time * 3.5) * 0.12
	var current_visor_glow := Color(visor_color.r, visor_color.g, visor_color.b, visor_pulse_alpha)
	
	# 4. Life-Support Backpack & Thrusters (positioned at local -X)
	var pack_rect := Rect2(-15, -7.5, 7, 15)
	draw_rect(pack_rect, pack_color)
	draw_rect(pack_rect, outline_color, false, 1.2)
	
	# Thruster vents
	draw_circle(Vector2(-15, -4), 2.0, pack_color.darkened(0.3))
	draw_circle(Vector2(-15, 4), 2.0, pack_color.darkened(0.3))
	
	# Status LED indicator (pulses in idle, solid in walk)
	var led_color := visor_color if current_anim == AnimState.WALKING else Color(visor_color, 0.5 + sin(_idle_time * 4.0) * 0.5)
	draw_circle(Vector2(-12, 0), 1.5, led_color)
	
	# Thruster flame exhaust plumes when walking
	if current_anim == AnimState.WALKING:
		var exhaust_len: float = randf_range(4.0, 9.0)
		# Upper nozzle
		draw_line(Vector2(-15, -4), Vector2(-15 - exhaust_len, -4), thruster_glow, 2.0)
		draw_circle(Vector2(-15, -4), 2.0, Color(1, 1, 1, 0.8))
		# Lower nozzle
		draw_line(Vector2(-15, 4), Vector2(-15 - exhaust_len, 4), thruster_glow, 2.0)
		draw_circle(Vector2(-15, 4), 2.0, Color(1, 1, 1, 0.8))
	
	# 5. Animated Arms / Gloves (swinging during walk cycle)
	var arm_swing: float = sin(_walk_cycle) * 3.5 if current_anim == AnimState.WALKING else 0.0
	
	# Left arm
	draw_circle(Vector2(-1 + arm_swing, -11), 4.5, accent_c)
	draw_arc(Vector2(-1 + arm_swing, -11), 4.5, 0, TAU, 16, outline_color, 1.1)
	
	# Right arm
	draw_circle(Vector2(-1 - arm_swing, 11), 4.5, accent_c)
	draw_arc(Vector2(-1 - arm_swing, 11), 4.5, 0, TAU, 16, outline_color, 1.1)
	
	# 6. Torso & Pressurized Suit
	draw_circle(Vector2(-2, 0), 12.0, suit_s)
	draw_circle(Vector2(-1.5, -0.5), 11.2, suit_c)
	draw_arc(Vector2(-2, 0), 12.0, 0, TAU, 24, outline_color, 1.5)
	
	# Chest Life-Support Harness Plate
	var chest_rect := Rect2(-5, -4.5, 6, 9)
	draw_rect(chest_rect, accent_c)
	draw_rect(chest_rect, outline_color, false, 1.0)
	
	# 7. Helmet & Visor
	var helmet_pos := Vector2(2, 0)
	draw_circle(helmet_pos, 9.0, suit_s)
	draw_circle(helmet_pos + Vector2(0.5, -0.5), 8.5, suit_c)
	draw_arc(helmet_pos, 9.0, 0, TAU, 22, outline_color, 1.3)
	
	# Visor Outer Glow
	var visor_center := helmet_pos + Vector2(3.5, 0)
	draw_circle(visor_center, 6.5, current_visor_glow)
	
	# Curved Visor Shape
	var visor_pts: PackedVector2Array = [
		visor_center + Vector2(1.0, -5.0),
		visor_center + Vector2(4.5, -3.0),
		visor_center + Vector2(5.5, 0.0),
		visor_center + Vector2(4.5, 3.0),
		visor_center + Vector2(1.0, 5.0),
		visor_center + Vector2(-1.2, 3.0),
		visor_center + Vector2(-1.2, -3.0)
	]
	draw_colored_polygon(visor_pts, visor_color)
	draw_polyline(visor_pts, outline_color, 1.2)
	
	# Specular Glare Highlight on Visor Glass
	draw_line(visor_center + Vector2(2.0, -3.0), visor_center + Vector2(4.0, -0.8), Color(1.0, 1.0, 1.0, 0.85), 1.3)
	draw_line(visor_center + Vector2(1.5, -1.0), visor_center + Vector2(2.5, 0.2), Color(1.0, 1.0, 1.0, 0.50), 1.0)
	
	# Muzzle Flash Flare
	if _muzzle_flash_timer > 0.0:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_circle(_muzzle_flash_pos, 5.0, Color(0.2, 0.9, 1.0, 0.85))
		draw_circle(_muzzle_flash_pos, 2.5, Color(1.0, 1.0, 1.0, 0.95))



# ---------------------------------------------------------------------------
# Particle Systems (Procedural, Zero External Assets)
# ---------------------------------------------------------------------------
func _spawn_dust_burst(offset: Vector2, count: int) -> void:
	for i in count:
		var p := {
			"pos": offset + Vector2(randf_range(-4, 4), randf_range(-4, 4)),
			"vel": Vector2(randf_range(-15, 15), randf_range(-15, 15)),
			"radius": randf_range(2.5, 5.0),
			"color": dust_color,
			"life": 0.0,
			"max_life": randf_range(0.25, 0.45)
		}
		_particles.append(p)


func _spawn_hit_sparks() -> void:
	for i in 8:
		var p := {
			"pos": Vector2(randf_range(-6, 6), randf_range(-6, 6)),
			"vel": Vector2(randf_range(-60, 60), randf_range(-60, 60)),
			"radius": randf_range(2.0, 4.0),
			"color": Color(1.0, 0.45, 0.2, 0.95),
			"life": 0.0,
			"max_life": randf_range(0.18, 0.32)
		}
		_particles.append(p)


func _spawn_thruster_particle(offset: Vector2) -> void:
	var p := {
		"pos": offset + Vector2(randf_range(-2, 2), randf_range(-2, 2)),
		"vel": facing_vector * randf_range(-30, -10) + Vector2(randf_range(-5, 5), randf_range(-5, 5)),
		"radius": randf_range(1.5, 3.0),
		"color": thruster_glow,
		"life": 0.0,
		"max_life": randf_range(0.18, 0.30)
	}
	_particles.append(p)


func _update_particles(delta: float) -> void:
	for i in range(_particles.size() - 1, -1, -1):
		var p: Dictionary = _particles[i]
		p["life"] += delta
		if p["life"] >= p["max_life"]:
			_particles.remove_at(i)
		else:
			p["pos"] += p["vel"] * delta
			p["vel"] = p["vel"].move_toward(Vector2.ZERO, delta * 30.0)


func _draw_particles() -> void:
	# Draw without parent rotation
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for p in _particles:
		var alpha_factor: float = 1.0 - (p["life"] / p["max_life"])
		var c: Color = p["color"]
		c.a *= alpha_factor
		var r: float = p["radius"] * alpha_factor
		if r > 0.5:
			draw_circle(p["pos"], r, c)


# ---------------------------------------------------------------------------
# Facing Enum & Direction Helpers (For Testing & State Tracking)
# ---------------------------------------------------------------------------
func _update_facing_enum(dir: Vector2) -> void:
	var angle: float = dir.angle() # [-PI, PI]
	var octant: int = int(round(angle / (PI / 4.0))) % 8
	if octant < 0:
		octant += 8
	
	# Octant 0: Right (0)
	# Octant 1: Down-Right (PI/4)
	# Octant 2: Down (PI/2)
	# Octant 3: Down-Left (3PI/4)
	# Octant 4: Left (PI)
	# Octant 5: Up-Left (-3PI/4)
	# Octant 6: Up (-PI/2)
	# Octant 7: Up-Right (-PI/4)
	match octant:
		0: current_facing = FacingDir.RIGHT
		1: current_facing = FacingDir.DOWN_RIGHT
		2: current_facing = FacingDir.DOWN
		3: current_facing = FacingDir.DOWN_LEFT
		4: current_facing = FacingDir.LEFT
		5: current_facing = FacingDir.UP_LEFT
		6: current_facing = FacingDir.UP
		7: current_facing = FacingDir.UP_RIGHT


func get_animation_state() -> String:
	return "walking" if current_anim == AnimState.WALKING else "idle"


func get_direction_name() -> String:
	match current_facing:
		FacingDir.DOWN: return "down"
		FacingDir.DOWN_RIGHT: return "down_right"
		FacingDir.RIGHT: return "right"
		FacingDir.UP_RIGHT: return "up_right"
		FacingDir.UP: return "up"
		FacingDir.UP_LEFT: return "up_left"
		FacingDir.LEFT: return "left"
		FacingDir.DOWN_LEFT: return "down_left"
	return "down"


func is_animating_movement() -> bool:
	return _is_moving
