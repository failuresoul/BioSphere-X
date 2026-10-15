extends Node2D
class_name BossVisual
## Procedural Animated Visuals and Telegraph Display for BioSphere-X Boss Encounter.
## Renders massive segmented chitin armor, animated 8-leg stomping walk cycle,
## dynamic magma fissures, attack telegraph warning zones (slam danger radius,
## charge vectors, radial aim lines), damage flashes, enrage aura, and death collapse.

enum VisualPhase { PHASE_1_GUARDIAN, PHASE_2_ENRAGED }
enum VisualState { GUARD, PURSUE, ATTACK, RECOVER, ENRAGED_TRANSITION, DEFEATED }
enum AttackType { NONE, TREMOR_SLAM, PLASMA_BARRAGE, CHARGE_RUSH }

@export_group("Carapace Colors")
@export var base_chitin: Color = Color(0.10, 0.07, 0.12)
@export var armor_plate_color: Color = Color(0.20, 0.12, 0.22)
@export var plate_highlight: Color = Color(0.48, 0.26, 0.52)
@export var magma_vein_normal: Color = Color(1.00, 0.42, 0.10)
@export var magma_vein_enraged: Color = Color(1.00, 0.15, 0.05)
@export var eye_color_normal: Color = Color(1.00, 0.80, 0.15)
@export var eye_color_enraged: Color = Color(1.00, 0.10, 0.10)
@export var steam_color: Color = Color(0.55, 0.75, 0.90, 0.60)

var current_phase: VisualPhase = VisualPhase.PHASE_1_GUARDIAN
var current_state: VisualState = VisualState.GUARD
var current_attack_type: AttackType = AttackType.NONE

var facing_angle: float = 0.0
var walk_speed_factor: float = 0.0
var attack_windup_ratio: float = 0.0
var attack_telegraph_radius: float = 0.0
var attack_telegraph_direction: Vector2 = Vector2.ZERO
var attack_telegraph_length: float = 0.0
var recover_ratio: float = 0.0
var is_enraged: bool = false
var is_defeated: bool = false

var _walk_cycle: float = 0.0
var _anim_time: float = 0.0
var _damage_flash_timer: float = 0.0
var _vent_particles: Array[Dictionary] = []
var _ember_particles: Array[Dictionary] = []


func _ready() -> void:
	scale = Vector2(1.85, 1.85)


func set_phase(phase: int) -> void:
	current_phase = phase as VisualPhase
	is_enraged = (current_phase == VisualPhase.PHASE_2_ENRAGED)
	queue_redraw()


func update_motion(velocity: Vector2, state: int, delta: float) -> void:
	current_state = state as VisualState
	var speed := velocity.length()
	walk_speed_factor = clampf(speed / 130.0, 0.0, 1.5)
	
	if speed > 6.0:
		var target_angle := velocity.angle()
		facing_angle = lerp_angle(facing_angle, target_angle, delta * 8.0)


func play_damage_flash() -> void:
	_damage_flash_timer = 0.25
	queue_redraw()


func play_death() -> void:
	is_defeated = true
	queue_redraw()


func _process(delta: float) -> void:
	_anim_time += delta
	if _damage_flash_timer > 0.0:
		_damage_flash_timer = maxf(0.0, _damage_flash_timer - delta)
	
	if walk_speed_factor > 0.0:
		var cycle_rate: float = 9.0 if not is_enraged else 13.0
		_walk_cycle += delta * walk_speed_factor * cycle_rate
	
	_update_particles(delta)
	queue_redraw()


func _update_particles(delta: float) -> void:
	# Enraged magma embers
	if is_enraged and not is_defeated:
		if randf() < 0.45:
			_ember_particles.append({
				"pos": Vector2(randf_range(-18.0, 10.0), randf_range(-12.0, 12.0)),
				"vel": Vector2(-cos(facing_angle), -sin(facing_angle)) * randf_range(20.0, 60.0) + Vector2(randf_range(-15, 15), randf_range(-15, 15)),
				"radius": randf_range(1.5, 3.5),
				"life": 0.0,
				"max_life": randf_range(0.3, 0.7)
			})
	
	for i in range(_ember_particles.size() - 1, -1, -1):
		var p: Dictionary = _ember_particles[i]
		p["life"] += delta
		if p["life"] >= p["max_life"]:
			_ember_particles.remove_at(i)
		else:
			p["pos"] += p["vel"] * delta
	
	# Steam venting during recover
	if current_state == VisualState.RECOVER and not is_defeated:
		if randf() < 0.35:
			_vent_particles.append({
				"pos": Vector2(randf_range(-12, -4), randf_range(-10, 10)),
				"vel": Vector2(randf_range(-20, 20), randf_range(-30, -50)),
				"radius": randf_range(2.0, 4.5),
				"life": 0.0,
				"max_life": randf_range(0.4, 0.8)
			})
	
	for i in range(_vent_particles.size() - 1, -1, -1):
		var p: Dictionary = _vent_particles[i]
		p["life"] += delta
		if p["life"] >= p["max_life"]:
			_vent_particles.remove_at(i)
		else:
			p["pos"] += p["vel"] * delta
			p["radius"] += delta * 3.0


func _draw() -> void:
	# 1. Ground Telegraph Warnings (Drawn unrotated in local space)
	_draw_attack_telegraphs()
	
	# 2. Heavy Ground Shadow
	var shadow_r: float = 34.0 if not is_defeated else 38.0
	draw_set_transform(Vector2(2, 6), 0.0, Vector2(1.3, 0.65))
	draw_circle(Vector2.ZERO, shadow_r, Color(0.02, 0.02, 0.04, 0.55))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	
	if is_defeated:
		_draw_defeated_pose()
		return
	
	# 3. Rotate entity body to facing angle
	draw_set_transform(Vector2.ZERO, facing_angle, Vector2.ONE)
	
	# Damage Flash Colors
	var is_flash := _damage_flash_timer > 0.0
	var c_chitin := Color(1.0, 0.45, 0.45) if is_flash else (base_chitin.lightened(0.08) if is_enraged else base_chitin)
	var c_plates := Color(1.0, 0.70, 0.70) if is_flash else armor_plate_color
	var c_sheen := Color(1.0, 0.90, 0.90) if is_flash else plate_highlight
	var c_magma := magma_vein_enraged if is_enraged else magma_vein_normal
	var c_eyes := eye_color_enraged if is_enraged else eye_color_normal
	
	# Enraged Aura Glow under body
	if is_enraged:
		var aura_pulse := (sin(_anim_time * 8.0) + 1.0) * 0.5
		var aura_col := Color(c_magma.r, c_magma.g, c_magma.b, 0.22 + aura_pulse * 0.18)
		draw_circle(Vector2.ZERO, 38.0 + aura_pulse * 6.0, aura_col)
	
	# 4. Animated Heavy Multi-Legs (8 Legs)
	_draw_heavy_legs(c_chitin, c_sheen)
	
	# 5. Rear Segment & Spined Tail Carapace
	_draw_rear_carapace(c_chitin, c_plates, c_sheen, c_magma)
	
	# 6. Main Dorsal Thorax (Heavy Armor Plates & Glowing Magma Veins)
	_draw_thorax_armor(c_chitin, c_plates, c_sheen, c_magma)
	
	# 7. Head, Massive Horns & Predatory Mandibles
	_draw_head_and_horns(c_chitin, c_sheen, c_eyes, c_magma)
	
	# 8. Render Recover Steam / Embers
	_draw_particle_overlays()


# ---------------------------------------------------------------------------
# Attack Telegraphs
# ---------------------------------------------------------------------------
func _draw_attack_telegraphs() -> void:
	if attack_windup_ratio <= 0.0:
		return
	
	match current_attack_type:
		AttackType.TREMOR_SLAM:
			# Expanding circular ground shockwave danger zone
			var max_r := attack_telegraph_radius
			var cur_r := max_r * attack_windup_ratio
			var col_fill := Color(1.0, 0.25, 0.10, 0.18 + attack_windup_ratio * 0.22)
			var col_ring := Color(1.0, 0.35, 0.15, 0.85)
			
			draw_circle(Vector2.ZERO, cur_r, col_fill)
			draw_arc(Vector2.ZERO, max_r, 0, TAU, 36, Color(1.0, 0.2, 0.1, 0.5), 1.5)
			draw_arc(Vector2.ZERO, cur_r, 0, TAU, 36, col_ring, 2.5)
			
			# Cardinal crosshairs
			var cross_len := cur_r * 0.95
			draw_line(Vector2(-cross_len, 0), Vector2(cross_len, 0), Color(col_ring, 0.4), 1.5)
			draw_line(Vector2(0, -cross_len), Vector2(0, cross_len), Color(col_ring, 0.4), 1.5)
			
		AttackType.PLASMA_BARRAGE:
			# Radiating warning aim rays
			var ray_len := 160.0
			var num_rays := 8
			var pulse := sin(_anim_time * 16.0) * 0.5 + 0.5
			var ray_col := Color(0.15, 0.95, 0.85, 0.45 + pulse * 0.40)
			for i in num_rays:
				var ang := (float(i) / float(num_rays)) * TAU + (facing_angle * 0.5)
				var dir := Vector2.from_angle(ang)
				draw_line(dir * 20.0, dir * (20.0 + ray_len * attack_windup_ratio), ray_col, 2.0)
				draw_circle(dir * (20.0 + ray_len * attack_windup_ratio), 3.0, Color(1.0, 1.0, 1.0, 0.85))
				
		AttackType.CHARGE_RUSH:
			# Directional danger corridor rect pointing along charge direction
			var c_dir := attack_telegraph_direction if attack_telegraph_direction != Vector2.ZERO else Vector2.from_angle(facing_angle)
			var c_len := attack_telegraph_length if attack_telegraph_length > 0.0 else 220.0
			var c_width := 48.0
			var perp := Vector2(-c_dir.y, c_dir.x) * (c_width * 0.5)
			
			var pts: PackedVector2Array = [
				-perp,
				perp,
				c_dir * c_len + perp,
				c_dir * c_len - perp
			]
			var col_rect := Color(1.0, 0.15, 0.10, 0.15 + attack_windup_ratio * 0.25)
			var col_edge := Color(1.0, 0.25, 0.15, 0.85)
			draw_colored_polygon(pts, col_rect)
			draw_polyline(pts, col_edge, 2.0)
			draw_line(pts[3], pts[0], col_edge, 2.0)
			
			# Moving directional charge arrows inside corridor
			var flow := fmod(_anim_time * 300.0, c_len)
			var arrow_pos := c_dir * flow
			draw_line(arrow_pos - perp * 0.6, arrow_pos + c_dir * 18.0, col_edge, 2.5)
			draw_line(arrow_pos + perp * 0.6, arrow_pos + c_dir * 18.0, col_edge, 2.5)


# ---------------------------------------------------------------------------
# Procedural Mesh Drawing: Carapace, Horns, Magma, Legs
# ---------------------------------------------------------------------------
func _draw_heavy_legs(c_chitin: Color, c_sheen: Color) -> void:
	# 8 heavy legs (4 pairs)
	for i in 4:
		var leg_phase: float = _walk_cycle + float(i) * 0.85
		var swing: float = sin(leg_phase) * 6.5 * walk_speed_factor
		var base_x: float = -14.0 + float(i) * 9.0
		
		# Left heavy leg
		var knee_l := Vector2(base_x - 6, -18)
		var foot_l := Vector2(base_x + swing - 2, -28)
		draw_line(Vector2(base_x, -8), knee_l, c_chitin, 4.2)
		draw_line(knee_l, foot_l, c_sheen, 3.0)
		draw_circle(foot_l, 3.0, c_chitin)
		
		# Right heavy leg
		var knee_r := Vector2(base_x - 6, 18)
		var foot_r := Vector2(base_x - swing - 2, 28)
		draw_line(Vector2(base_x, 8), knee_r, c_chitin, 4.2)
		draw_line(knee_r, foot_r, c_sheen, 3.0)
		draw_circle(foot_r, 3.0, c_chitin)


func _draw_rear_carapace(c_chitin: Color, c_plates: Color, c_sheen: Color, c_magma: Color) -> void:
	var breath := sin(_anim_time * 2.5) * 1.5
	var rear_pts: PackedVector2Array = [
		Vector2(-28 + breath * 0.4, 0),
		Vector2(-18, -16),
		Vector2(-6, -15),
		Vector2(-6, 15),
		Vector2(-18, 16)
	]
	draw_colored_polygon(rear_pts, c_chitin)
	draw_polyline(rear_pts, c_sheen, 2.2)
	
	# Magma fissure vents on abdomen
	var pulse := (sin(_anim_time * 6.0) + 1.0) * 0.5
	var glow_c := Color(c_magma.r, c_magma.g, c_magma.b, 0.75 + pulse * 0.25)
	draw_circle(Vector2(-18, 0), 4.5, glow_c)
	draw_circle(Vector2(-12, -7), 3.0, glow_c)
	draw_circle(Vector2(-12, 7), 3.0, glow_c)


func _draw_thorax_armor(c_chitin: Color, c_plates: Color, c_sheen: Color, c_magma: Color) -> void:
	# Main Thorax Outer Carapace
	var thorax_pts: PackedVector2Array = [
		Vector2(-8, -17),
		Vector2(10, -15),
		Vector2(18, 0),
		Vector2(10, 15),
		Vector2(-8, 17)
	]
	draw_colored_polygon(thorax_pts, c_plates)
	draw_polyline(thorax_pts, c_sheen, 2.5)
	
	# Heavy dorsal armor ridges
	draw_line(Vector2(-4, -14), Vector2(6, -11), c_sheen, 3.0)
	draw_line(Vector2(-4, 14), Vector2(6, 11), c_sheen, 3.0)
	
	# Central glowing spinal magma trench
	draw_line(Vector2(-10, 0), Vector2(12, 0), c_magma, 3.8)
	draw_line(Vector2(-6, 0), Vector2(10, 0), Color.WHITE, 1.4)


func _draw_head_and_horns(c_chitin: Color, c_sheen: Color, c_eyes: Color, c_magma: Color) -> void:
	var head_pos := Vector2(17, 0)
	draw_circle(head_pos, 10.0, c_chitin)
	draw_arc(head_pos, 10.0, 0, TAU, 18, c_sheen, 2.2)
	
	# Massive Swept Heavy Horns
	draw_line(head_pos + Vector2(2, -8), head_pos + Vector2(14, -18), c_sheen, 3.8)
	draw_line(head_pos + Vector2(14, -18), head_pos + Vector2(20, -14), c_magma, 2.5)
	
	draw_line(head_pos + Vector2(2, 8), head_pos + Vector2(14, 18), c_sheen, 3.8)
	draw_line(head_pos + Vector2(14, 18), head_pos + Vector2(20, 14), c_magma, 2.5)
	
	# Crushing Mandibles
	var snap := attack_windup_ratio * 7.0
	draw_line(head_pos + Vector2(6, -5), head_pos + Vector2(18 - snap, -8 + snap), c_sheen, 3.2)
	draw_line(head_pos + Vector2(6, 5), head_pos + Vector2(18 - snap, 8 - snap), c_sheen, 3.2)
	
	# Predatory Multi-Eye Cluster (6 eyes)
	draw_circle(head_pos + Vector2(4, -4), 2.4, c_eyes)
	draw_circle(head_pos + Vector2(4, 4), 2.4, c_eyes)
	draw_circle(head_pos + Vector2(1, -7), 1.8, c_eyes)
	draw_circle(head_pos + Vector2(1, 7), 1.8, c_eyes)
	draw_circle(head_pos + Vector2(7, -2), 1.6, c_eyes)
	draw_circle(head_pos + Vector2(7, 2), 1.6, c_eyes)


func _draw_particle_overlays() -> void:
	# Steam venting during recover state
	for p in _vent_particles:
		var t: float = p["life"] / p["max_life"]
		var c := steam_color
		c.a = (1.0 - t) * 0.65
		draw_circle(p["pos"], p["radius"], c)
	
	# Enraged flying embers
	for p in _ember_particles:
		var t: float = p["life"] / p["max_life"]
		var c := magma_vein_enraged
		c.a = 1.0 - t
		draw_circle(p["pos"], p["radius"] * (1.0 - t * 0.4), c)


func _draw_defeated_pose() -> void:
	# Collapsed, dimmed, broken carapace pose
	draw_set_transform(Vector2(0, 3), facing_angle, Vector2(0.9, 0.6))
	var c_dead := base_chitin.darkened(0.5)
	draw_circle(Vector2(-10, 0), 18.0, c_dead)
	draw_circle(Vector2(8, 0), 12.0, c_dead)
	draw_arc(Vector2(-10, 0), 18.0, 0, TAU, 18, Color(0.2, 0.15, 0.22), 1.8)
	# Broken smoking fissure
	draw_line(Vector2(-12, 0), Vector2(8, 0), Color(0.4, 0.15, 0.1, 0.6), 2.5)
