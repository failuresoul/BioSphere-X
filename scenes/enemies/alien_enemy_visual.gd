extends Node2D
class_name AlienEnemyVisual
## Procedural Animated Visuals for BioSphere-X Alien Enemies.
## Supports distinct procedural appearances for Scout, Armored Brute, and Spitter.
## Features animated chitinous body segments, multi-leg scuttle walk cycles,
## dynamic predatory eye glow reflecting state, attack lunges/slams/spits,
## damage flashes, and death poses.

enum VisualEnemyType { SCOUT, ARMORED_BRUTE, SPITTER, CUSTOM }
enum VisualState { IDLE, PATROL, CHASE, ATTACK, INVESTIGATE, DEAD }

@export var enemy_type: VisualEnemyType = VisualEnemyType.SCOUT:
	set(val):
		enemy_type = val
		_apply_type_palette()
		queue_redraw()

@export_group("Carapace Colors")
@export var chitin_color: Color = Color(0.18, 0.22, 0.12)
@export var chitin_highlight: Color = Color(0.50, 0.65, 0.25)
@export var bio_glow_color: Color = Color(0.85, 0.95, 0.15)
@export var eye_color_idle: Color = Color(0.95, 0.85, 0.20)
@export var eye_color_chase: Color = Color(1.00, 0.35, 0.10)
@export var eye_color_investigate: Color = Color(0.40, 0.95, 0.30)

var current_state: VisualState = VisualState.IDLE
var facing_angle: float = 0.0
var walk_speed_factor: float = 0.0
var attack_windup_ratio: float = 0.0
var is_dead: bool = false

var _walk_cycle: float = 0.0
var _anim_time: float = 0.0
var _damage_flash_timer: float = 0.0


func _ready() -> void:
	_apply_type_palette()


func set_enemy_type(p_type: int) -> void:
	enemy_type = p_type as VisualEnemyType
	_apply_type_palette()
	queue_redraw()


func _apply_type_palette() -> void:
	match enemy_type:
		VisualEnemyType.SCOUT:
			scale = Vector2(0.85, 0.85)
			chitin_color = Color(0.18, 0.22, 0.12)
			chitin_highlight = Color(0.55, 0.70, 0.26)
			bio_glow_color = Color(0.85, 0.95, 0.15)
			eye_color_idle = Color(0.95, 0.85, 0.20)
			eye_color_chase = Color(1.00, 0.35, 0.10)
			eye_color_investigate = Color(0.45, 0.95, 0.30)
		VisualEnemyType.ARMORED_BRUTE:
			scale = Vector2(1.35, 1.35)
			chitin_color = Color(0.13, 0.08, 0.10)
			chitin_highlight = Color(0.44, 0.16, 0.20)
			bio_glow_color = Color(1.00, 0.26, 0.08)
			eye_color_idle = Color(1.00, 0.42, 0.15)
			eye_color_chase = Color(1.00, 0.05, 0.05)
			eye_color_investigate = Color(0.90, 0.50, 0.18)
		VisualEnemyType.SPITTER:
			scale = Vector2(1.05, 1.05)
			chitin_color = Color(0.08, 0.16, 0.16)
			chitin_highlight = Color(0.18, 0.45, 0.40)
			bio_glow_color = Color(0.15, 0.95, 0.65)
			eye_color_idle = Color(0.20, 0.90, 0.75)
			eye_color_chase = Color(0.10, 1.00, 0.35)
			eye_color_investigate = Color(0.25, 0.80, 0.95)


func _process(delta: float) -> void:
	_anim_time += delta
	if _damage_flash_timer > 0.0:
		_damage_flash_timer = maxf(0.0, _damage_flash_timer - delta)
	
	if walk_speed_factor > 0.0:
		var cycle_rate: float = 14.0 if enemy_type == VisualEnemyType.SCOUT else (8.0 if enemy_type == VisualEnemyType.ARMORED_BRUTE else 11.0)
		_walk_cycle += delta * walk_speed_factor * cycle_rate
	
	queue_redraw()


func update_motion(velocity: Vector2, state: int, delta: float) -> void:
	current_state = state as VisualState
	var speed := velocity.length()
	var base_speed := 160.0
	if enemy_type == VisualEnemyType.SCOUT:
		base_speed = 210.0
	elif enemy_type == VisualEnemyType.ARMORED_BRUTE:
		base_speed = 85.0
	walk_speed_factor = clampf(speed / base_speed, 0.0, 1.5)
	
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
	var shadow_r: float = 16.0
	if enemy_type == VisualEnemyType.SCOUT:
		shadow_r = 12.0
	elif enemy_type == VisualEnemyType.ARMORED_BRUTE:
		shadow_r = 24.0
	elif enemy_type == VisualEnemyType.SPITTER:
		shadow_r = 17.0
	
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
	var c_chitin := Color(1.0, 0.4, 0.4) if is_flash else chitin_color
	var c_sheen := Color(1.0, 0.75, 0.75) if is_flash else chitin_highlight
	var c_bio := Color(1.0, 0.95, 0.95) if is_flash else bio_glow_color
	
	# Eye color based on state
	var c_eyes: Color = eye_color_idle
	match current_state:
		VisualState.CHASE, VisualState.ATTACK:
			c_eyes = eye_color_chase
		VisualState.INVESTIGATE:
			c_eyes = eye_color_investigate
	
	match enemy_type:
		VisualEnemyType.SCOUT:
			_draw_scout(c_chitin, c_sheen, c_bio, c_eyes)
		VisualEnemyType.ARMORED_BRUTE:
			_draw_armored_brute(c_chitin, c_sheen, c_bio, c_eyes)
		VisualEnemyType.SPITTER:
			_draw_spitter(c_chitin, c_sheen, c_bio, c_eyes)
		_:
			_draw_scout(c_chitin, c_sheen, c_bio, c_eyes)


# ---------------------------------------------------------------------------
# Scout Drawing: Lean, agile, needle mandibles, rapid 6 legs
# ---------------------------------------------------------------------------
func _draw_scout(c_chitin: Color, c_sheen: Color, c_bio: Color, c_eyes: Color) -> void:
	# Legs (Long spindly needle legs)
	for i in 3:
		var leg_phase: float = _walk_cycle + float(i) * 1.15
		var swing: float = sin(leg_phase) * 8.0 * walk_speed_factor
		var base_x: float = -6.0 + float(i) * 6.0
		
		# Left leg
		draw_line(Vector2(base_x, -3), Vector2(base_x - 3, -13), c_chitin, 1.8)
		draw_line(Vector2(base_x - 3, -13), Vector2(base_x + swing, -20), c_sheen, 1.2)
		# Right leg
		draw_line(Vector2(base_x, 3), Vector2(base_x - 3, 13), c_chitin, 1.8)
		draw_line(Vector2(base_x - 3, 13), Vector2(base_x - swing, 20), c_sheen, 1.2)
	
	# Slender abdomen
	var breath := sin(_anim_time * 5.0) * 1.2
	var abdomen_pts: PackedVector2Array = [
		Vector2(-17 + breath * 0.4, 0),
		Vector2(-10, -6),
		Vector2(-2, -5),
		Vector2(-2, 5),
		Vector2(-10, 6)
	]
	draw_colored_polygon(abdomen_pts, c_chitin)
	draw_polyline(abdomen_pts, c_sheen, 1.2)
	draw_circle(Vector2(-10, 0), 2.2, c_bio)
	draw_circle(Vector2(-5, 0), 1.6, c_bio)
	
	# Thorax
	var thorax_pts: PackedVector2Array = [
		Vector2(-4, -6),
		Vector2(6, -5),
		Vector2(10, 0),
		Vector2(6, 5),
		Vector2(-4, 6)
	]
	draw_colored_polygon(thorax_pts, c_chitin.lightened(0.1))
	draw_polyline(thorax_pts, c_sheen, 1.4)
	
	# Head with aerodynamic crest
	var head_pos := Vector2(10, 0)
	draw_circle(head_pos, 5.0, c_chitin)
	draw_arc(head_pos, 5.0, 0, TAU, 16, c_sheen, 1.2)
	# Needle mandibles
	var snap: float = attack_windup_ratio * 5.0
	draw_line(head_pos + Vector2(3, -2), head_pos + Vector2(10 - snap, -5 + snap), c_sheen, 1.8)
	draw_line(head_pos + Vector2(3, 2), head_pos + Vector2(10 - snap, 5 - snap), c_sheen, 1.8)
	
	# Glowing eyes
	draw_circle(head_pos + Vector2(3, -2), 1.5, c_eyes)
	draw_circle(head_pos + Vector2(3, 2), 1.5, c_eyes)


# ---------------------------------------------------------------------------
# Armored Brute Drawing: Bulky, layered plates, heavy tusks, slam wave
# ---------------------------------------------------------------------------
func _draw_armored_brute(c_chitin: Color, c_sheen: Color, c_bio: Color, c_eyes: Color) -> void:
	# Heavy Legs (Thick, stomp-heavy)
	for i in 3:
		var leg_phase: float = _walk_cycle + float(i) * 1.05
		var swing: float = sin(leg_phase) * 5.0 * walk_speed_factor
		var base_x: float = -8.0 + float(i) * 8.0
		
		# Left heavy leg
		draw_line(Vector2(base_x, -5), Vector2(base_x - 5, -15), c_chitin, 3.5)
		draw_line(Vector2(base_x - 5, -15), Vector2(base_x + swing, -23), c_sheen, 2.4)
		# Foot pad
		draw_circle(Vector2(base_x + swing, -23), 2.2, c_chitin)
		
		# Right heavy leg
		draw_line(Vector2(base_x, 5), Vector2(base_x - 5, 15), c_chitin, 3.5)
		draw_line(Vector2(base_x - 5, 15), Vector2(base_x - swing, 23), c_sheen, 2.4)
		draw_circle(Vector2(base_x - swing, 23), 2.2, c_chitin)
	
	# Heavy segmented abdomen with protective dorsal spikes
	var breath := sin(_anim_time * 2.5) * 1.5
	var abdomen_pts: PackedVector2Array = [
		Vector2(-20 + breath * 0.3, 0),
		Vector2(-12, -12),
		Vector2(-2, -10),
		Vector2(-2, 10),
		Vector2(-12, 12)
	]
	draw_colored_polygon(abdomen_pts, c_chitin)
	draw_polyline(abdomen_pts, c_sheen, 1.8)
	
	# Molten bio-gland fissures along spine
	draw_line(Vector2(-14, 0), Vector2(-4, 0), c_bio, 2.5)
	draw_circle(Vector2(-12, -4), 2.2, c_bio)
	draw_circle(Vector2(-12, 4), 2.2, c_bio)
	
	# Massive armored thorax plates (shoulder pauldrons)
	var thorax_pts: PackedVector2Array = [
		Vector2(-4, -12),
		Vector2(8, -10),
		Vector2(14, 0),
		Vector2(8, 10),
		Vector2(-4, 12)
	]
	draw_colored_polygon(thorax_pts, c_chitin.lightened(0.12))
	draw_polyline(thorax_pts, c_sheen, 2.0)
	
	# Shoulder Carapace Horns
	draw_line(Vector2(2, -10), Vector2(-2, -16), c_sheen, 2.5)
	draw_line(Vector2(2, 10), Vector2(-2, 16), c_sheen, 2.5)
	
	# Armored head & heavy tusks
	var head_pos := Vector2(13, 0)
	draw_circle(head_pos, 8.0, c_chitin)
	draw_arc(head_pos, 8.0, 0, TAU, 16, c_sheen, 1.8)
	
	# Heavy crushing tusks (clench during attack windup)
	var crush: float = attack_windup_ratio * 6.0
	draw_line(head_pos + Vector2(4, -5), head_pos + Vector2(14 - crush, -8 + crush), c_sheen, 3.0)
	draw_line(head_pos + Vector2(4, 5), head_pos + Vector2(14 - crush, 8 - crush), c_sheen, 3.0)
	
	# Eyes
	draw_circle(head_pos + Vector2(4, -3), 2.2, c_eyes)
	draw_circle(head_pos + Vector2(4, 3), 2.2, c_eyes)
	
	# Heavy slam windup ground shockwave ring
	if attack_windup_ratio > 0.0:
		var ring_r := 10.0 + attack_windup_ratio * 26.0
		var ring_col := Color(c_bio.r, c_bio.g, c_bio.b, 0.45 * (1.0 - attack_windup_ratio * 0.3))
		draw_arc(Vector2(10, 0), ring_r, 0, TAU, 24, ring_col, 2.0)


# ---------------------------------------------------------------------------
# Spitter Drawing: Translucent pulsing venom sac, chemical nozzles
# ---------------------------------------------------------------------------
func _draw_spitter(c_chitin: Color, c_sheen: Color, c_bio: Color, c_eyes: Color) -> void:
	# Medium agile legs
	for i in 3:
		var leg_phase: float = _walk_cycle + float(i) * 1.10
		var swing: float = sin(leg_phase) * 6.0 * walk_speed_factor
		var base_x: float = -6.0 + float(i) * 6.0
		
		# Left leg
		draw_line(Vector2(base_x, -4), Vector2(base_x - 4, -13), c_chitin, 2.0)
		draw_line(Vector2(base_x - 4, -13), Vector2(base_x + swing, -19), c_sheen, 1.4)
		# Right leg
		draw_line(Vector2(base_x, 4), Vector2(base_x - 4, 13), c_chitin, 2.0)
		draw_line(Vector2(base_x - 4, 13), Vector2(base_x - swing, 19), c_sheen, 1.4)
	
	# Bulbous glowing chemical venom sac on rear abdomen
	var sac_pulse := sin(_anim_time * 6.0) * 1.8
	var sac_scale := 1.0 + attack_windup_ratio * 0.35
	var sac_center := Vector2(-12, 0)
	var sac_r := (10.0 + sac_pulse * 0.5) * sac_scale
	
	# Outer sac membrane
	draw_circle(sac_center, sac_r, Color(c_chitin.r, c_chitin.g + 0.05, c_chitin.b + 0.05, 0.9))
	# Inner glowing toxic chemical core
	draw_circle(sac_center, sac_r * 0.72, Color(c_bio.r, c_bio.g, c_bio.b, 0.85))
	draw_circle(sac_center + Vector2(2, -2), sac_r * 0.35, Color(1.0, 1.0, 1.0, 0.7))
	draw_arc(sac_center, sac_r, 0, TAU, 20, c_sheen, 1.4)
	
	# Thorax
	var thorax_pts: PackedVector2Array = [
		Vector2(-4, -8),
		Vector2(6, -6),
		Vector2(10, 0),
		Vector2(6, 6),
		Vector2(-4, 8)
	]
	draw_colored_polygon(thorax_pts, c_chitin.lightened(0.08))
	draw_polyline(thorax_pts, c_sheen, 1.4)
	
	# Head with twin chemical spitting nozzles
	var head_pos := Vector2(10, 0)
	draw_circle(head_pos, 6.0, c_chitin)
	draw_arc(head_pos, 6.0, 0, TAU, 16, c_sheen, 1.2)
	
	# Spitter nozzles
	var nozzle_glow := c_bio if attack_windup_ratio > 0.1 else c_sheen
	draw_line(head_pos + Vector2(3, -3), head_pos + Vector2(10, -4), nozzle_glow, 2.2)
	draw_line(head_pos + Vector2(3, 3), head_pos + Vector2(10, 4), nozzle_glow, 2.2)
	
	# Chemical spark during spitting windup
	if attack_windup_ratio > 0.2:
		var spark_r := attack_windup_ratio * 4.5
		draw_circle(head_pos + Vector2(11, 0), spark_r, c_bio)
		draw_circle(head_pos + Vector2(11, 0), spark_r * 0.5, Color(1.0, 1.0, 1.0, 0.9))
	
	# Eyes
	draw_circle(head_pos + Vector2(3, -2), 1.6, c_eyes)
	draw_circle(head_pos + Vector2(3, 2), 1.6, c_eyes)


# ---------------------------------------------------------------------------
# Dead Pose
# ---------------------------------------------------------------------------
func _draw_dead_pose() -> void:
	draw_set_transform(Vector2(0, 2), facing_angle, Vector2(0.9, 0.6))
	var c := chitin_color.darkened(0.4)
	draw_circle(Vector2(-4, 0), 10.0, c)
	draw_circle(Vector2(6, 0), 6.0, c)
	draw_arc(Vector2(-4, 0), 10.0, 0, TAU, 16, Color(0.2, 0.22, 0.26), 1.2)
