class_name AutonomousAgent
extends CharacterBody2D

const FloatingCombatTextScript := preload("res://scripts/components/floating_combat_text.gd")
const AstronautVisualScript := preload("res://scenes/player/astronaut_visual.gd")
## Operates without human input, executing pathfinding through the Python AI backend,
## avoiding obstacles, pursuing opponents or objectives, and engaging in decoupled combat.

signal agent_damaged(agent: CharacterBody2D, damage: float, current_hp: float)
signal agent_died(agent: CharacterBody2D)
signal path_updated(agent: CharacterBody2D, path: PackedVector2Array, metrics: Dictionary)
signal weapon_fired(agent: CharacterBody2D, projectile: Node2D)

enum AgentState {
	IDLE,
	NAVIGATING,
	ATTACKING,
	DEAD
}

@export_group("Identity & Visuals")
@export var agent_name: String = "Agent A"
@export var team_group: String = "team_a"
@export var accent_color: Color = Color(0.12, 0.88, 1.0)
@export var algorithm: String = "astar"
@export var scenario: String = "combat" # "combat" or "race"
@export var tactical_role: String = "adaptive" # "adaptive", "assault", "sniper", "flanker"

const ROLES: Array[String] = [
	"adaptive",
	"assault",
	"sniper",
	"flanker"
]

const ROLE_LABELS: Dictionary = {
	"adaptive": "Adaptive Tactician",
	"assault": "Aggressive Assault",
	"sniper": "Long-Range Marksman",
	"flanker": "Evasive Skirmisher"
}

@export_group("Movement & Combat")
@export var move_speed: float = 175.0
@export var acceleration: float = 900.0
@export var friction: float = 950.0
@export var attack_range: float = 340.0
@export var repath_interval: float = 0.8

# Runtime State
var current_state: AgentState = AgentState.IDLE
var target_node: Node2D = null
var spawn_position: Vector2 = Vector2.ZERO
var facing_direction: Vector2 = Vector2.RIGHT
var current_tactic_status: String = "ENGAGING"

# Dynamic Tactical & Combat Behavior
var _strafe_direction: float = 1.0
var _strafe_timer: float = 0.0
var _evasion_burst_timer: float = 0.0
var _overcharge_timer: float = 0.0
var _base_move_speed: float = 175.0
var _base_attack_cooldown: float = 0.45
var _min_standoff: float = 150.0
var _max_standoff: float = 260.0
var _lead_aim_factor: float = 0.90
# Dynamic behavior randomization
var _tactic_reassess_timer: float = 0.0
var _repositioning_timer: float = 0.0
var _aggressive_push: bool = false
var _flanker_phase: int = 0  # Rotation phase for flanker arc movement

# Navigation State
var _nav_path: PackedVector2Array = PackedVector2Array()
var _nav_path_index: int = 0
var _repath_timer: float = 0.0
var _is_requesting_path: bool = false
var _last_target_grid_pos: Vector2i = Vector2i(-999, -999)
var _map_data_ref: RefCounted = null
# Arena reference for pickup awareness
var _arena_ref: Node = null
var _seeking_pickup: String = ""       # "" | "repair" | "overcharge"
var _pickup_seek_timer: float = 0.0    # Re-evaluates every N seconds
var _pickup_cooldown_a: float = 0.0   # personal cooldown after collecting repair
var _pickup_cooldown_b: float = 0.0   # personal cooldown after collecting overcharge

# Metrics Tracking
var total_requests: int = 0
var total_nodes_expanded: int = 0
var total_algo_time_ms: float = 0.0
var total_distance_traveled: float = 0.0
var damage_dealt: float = 0.0
var damage_taken: float = 0.0
var last_metrics: Dictionary = {}

# Feedback & Animation State
var _hit_flash_timer: float = 0.0
var _recoil_offset: Vector2 = Vector2.ZERO
var _death_fade: float = 1.0

# Node References
@onready var visual: Node2D = get_node_or_null("Visual")
@onready var health_component: Node = $HealthComponent
@onready var weapon_component: Node2D = $WeaponComponent
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("autonomous_agents")
	if not team_group.is_empty():
		add_to_group(team_group)
	
	collision_layer = 1
	collision_mask = 1
	
	spawn_position = global_position
	_setup_components()
	_ensure_visual()
	_apply_visual_styling()


func _ensure_visual() -> void:
	if visual == null:
		visual = get_node_or_null("Visual")
	if visual == null:
		visual = AstronautVisualScript.new()
		visual.name = "Visual"
		add_child(visual)
		move_child(visual, 0)


func _apply_visual_styling() -> void:
	if not visual:
		return
	if team_group == "team_a":
		# Team A: Vanguard Operative (White EVA suit, Cyan trim & emerald visor)
		visual.set("suit_color", Color(0.93, 0.95, 0.98))
		visual.set("suit_shadow", Color(0.68, 0.72, 0.80))
		visual.set("accent_color", accent_color)
		visual.set("visor_color", Color(0.05, 0.92, 0.65))
		visual.set("pack_color", Color(0.18, 0.22, 0.28))
		visual.set("thruster_glow", Color(0.20, 0.85, 1.00, 0.85))
	else:
		# Team B: Rival Operative (Sleek dark carbon stealth suit, Amber trim & gold visor)
		visual.set("suit_color", Color(0.28, 0.29, 0.35))
		visual.set("suit_shadow", Color(0.16, 0.17, 0.22))
		visual.set("accent_color", accent_color)
		visual.set("visor_color", Color(1.00, 0.70, 0.15))
		visual.set("pack_color", Color(0.14, 0.14, 0.18))
		visual.set("thruster_glow", Color(1.00, 0.60, 0.15, 0.85))


func _setup_components() -> void:
	if not health_component:
		health_component = get_node_or_null("HealthComponent")
	if health_component:
		health_component.max_health = 100.0
		health_component.current_health = 100.0
		if not health_component.died.is_connected(_on_health_depleted):
			health_component.died.connect(_on_health_depleted)
		if not health_component.damage_received.is_connected(_on_damage_data_received):
			health_component.damage_received.connect(_on_damage_data_received)

	if not weapon_component:
		weapon_component = get_node_or_null("WeaponComponent")
	if weapon_component:
		weapon_component.set("use_global_energy", false)
		weapon_component.set("attack_range", attack_range)
		weapon_component.set("energy_cost", 0.0)
		weapon_component.set("projectile_color", accent_color)
		weapon_component.set("muzzle_flash_color", accent_color.lightened(0.3))
		if weapon_component.has_signal("weapon_fired") and not weapon_component.weapon_fired.is_connected(_on_weapon_fired):
			weapon_component.weapon_fired.connect(_on_weapon_fired)

	_apply_role_tuning()


func _apply_role_tuning() -> void:
	match tactical_role.to_lower():
		"assault":
			_base_move_speed = 205.0
			attack_range = 330.0
			_min_standoff = 70.0
			_max_standoff = 160.0
			_lead_aim_factor = 0.78
			if weapon_component:
				weapon_component.set("damage", 14.0)
				weapon_component.set("attack_cooldown", 0.32)
				weapon_component.set("projectile_speed", 580.0)
				_base_attack_cooldown = 0.32
		"sniper":
			_base_move_speed = 150.0
			attack_range = 440.0
			_min_standoff = 260.0
			_max_standoff = 380.0
			_lead_aim_factor = 1.05
			if weapon_component:
				weapon_component.set("damage", 29.0)
				weapon_component.set("attack_cooldown", 0.74)
				weapon_component.set("projectile_speed", 750.0)
				_base_attack_cooldown = 0.74
		"flanker":
			_base_move_speed = 190.0
			attack_range = 360.0
			_min_standoff = 150.0
			_max_standoff = 240.0
			_lead_aim_factor = 0.88
			if weapon_component:
				weapon_component.set("damage", 16.0)
				weapon_component.set("attack_cooldown", 0.38)
				weapon_component.set("projectile_speed", 620.0)
				_base_attack_cooldown = 0.38
		"adaptive", _:
			tactical_role = "adaptive"
			_base_move_speed = 175.0
			attack_range = 340.0
			_min_standoff = 150.0
			_max_standoff = 260.0
			_lead_aim_factor = 0.92
			if weapon_component:
				weapon_component.set("damage", 18.0)
				weapon_component.set("attack_cooldown", 0.45)
				weapon_component.set("projectile_speed", 540.0)
				_base_attack_cooldown = 0.45
	move_speed = _base_move_speed


func setup_agent(p_name: String, p_team: String, p_color: Color, p_algo: String, p_scenario: String = "combat", p_role: String = "adaptive") -> void:
	# Update team group
	if is_in_group(team_group):
		remove_from_group(team_group)
	
	agent_name = p_name
	team_group = p_team
	accent_color = p_color
	algorithm = p_algo.to_lower().strip_edges()
	scenario = p_scenario
	tactical_role = p_role.to_lower().strip_edges()
	
	add_to_group(team_group)
	
	_apply_role_tuning()
	
	if weapon_component:
		weapon_component.set("projectile_color", accent_color)
		weapon_component.set("muzzle_flash_color", accent_color.lightened(0.3))
	
	_ensure_visual()
	_apply_visual_styling()
	queue_redraw()


func set_target(target: Node2D) -> void:
	target_node = target
	_repath_timer = 0.0 # Force immediate path search


func set_map_data(m_data: RefCounted) -> void:
	_map_data_ref = m_data


func set_arena_ref(arena: Node) -> void:
	_arena_ref = arena


func set_tactical_role(p_role: String) -> void:
	tactical_role = p_role.to_lower().strip_edges()
	_apply_role_tuning()


func get_tactical_role() -> String:
	return tactical_role


func reset_agent(p_spawn_pos: Vector2 = Vector2.ZERO) -> void:
	if p_spawn_pos != Vector2.ZERO:
		spawn_position = p_spawn_pos
		global_position = p_spawn_pos
	else:
		global_position = spawn_position

	velocity = Vector2.ZERO
	current_state = AgentState.IDLE
	_nav_path.clear()
	_nav_path_index = 0
	_repath_timer = 0.0
	_is_requesting_path = false
	_last_target_grid_pos = Vector2i(-999, -999)
	_hit_flash_timer = 0.0
	_recoil_offset = Vector2.ZERO
	_death_fade = 1.0
	_strafe_timer = randf_range(0.3, 1.5)  # Stagger strafe timers so agents don't sync
	_evasion_burst_timer = 0.0
	_overcharge_timer = 0.0
	_tactic_reassess_timer = randf_range(0.5, 3.0)  # Stagger initial reassessment
	_repositioning_timer = randf_range(1.0, 5.0)
	_aggressive_push = randf() > 0.5
	_flanker_phase = randi() % 3
	current_tactic_status = "DEPLOYING"
	_seeking_pickup = ""
	_pickup_seek_timer = randf_range(0.5, 2.0)
	_pickup_cooldown_a = 0.0
	_pickup_cooldown_b = 0.0
	_apply_role_tuning()

	total_requests = 0
	total_nodes_expanded = 0
	total_algo_time_ms = 0.0
	total_distance_traveled = 0.0
	damage_dealt = 0.0
	damage_taken = 0.0
	last_metrics = {}

	if collision_shape:
		collision_shape.disabled = false
		collision_shape.set_deferred("disabled", false)

	if health_component:
		health_component.current_health = health_component.max_health

	if weapon_component and weapon_component.has_method("reset_cooldown"):
		weapon_component.call("reset_cooldown")

	if visual and visual.has_method("reset_visual"):
		visual.call("reset_visual")

	queue_redraw()


func _physics_process(delta: float) -> void:
	if current_state == AgentState.DEAD:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		move_and_slide()
		if visual and visual.has_method("update_motion"):
			visual.call("update_motion", velocity, delta)
		return

	# Handle visual and tactical timers
	if _hit_flash_timer > 0.0:
		_hit_flash_timer = maxf(0.0, _hit_flash_timer - delta * 5.0)
	if _recoil_offset.length_squared() > 0.01:
		_recoil_offset = _recoil_offset.move_toward(Vector2.ZERO, delta * 80.0)

	if _evasion_burst_timer > 0.0:
		_evasion_burst_timer = maxf(0.0, _evasion_burst_timer - delta)
	if _overcharge_timer > 0.0:
		_overcharge_timer = maxf(0.0, _overcharge_timer - delta)

	# Dynamic move speed with tactical bursts & overcharge buffs
	var effective_speed := _base_move_speed
	if _overcharge_timer > 0.0:
		effective_speed *= 1.35
	if _evasion_burst_timer > 0.0:
		effective_speed *= 1.25
	move_speed = effective_speed

	_update_autonomous_behavior(delta)
	move_and_slide()
	
	if visual and visual.has_method("update_motion"):
		visual.call("update_motion", velocity, delta)
	
	# Track physical distance traversed
	var moved := velocity.length() * delta
	total_distance_traveled += moved

	queue_redraw()


func _update_autonomous_behavior(delta: float) -> void:
	if not is_instance_valid(target_node) or not target_node.is_inside_tree():
		current_state = AgentState.IDLE
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		return

	# In combat scenario, stop if opponent is dead
	if scenario == "combat" and "current_state" in target_node and target_node.current_state == AgentState.DEAD:
		current_state = AgentState.IDLE
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		return

	# ── PICKUP SEEKING EVALUATION ──────────────────────────────────────────
	# Tick personal pickup cooldowns
	if _pickup_cooldown_a > 0.0:
		_pickup_cooldown_a -= delta
	if _pickup_cooldown_b > 0.0:
		_pickup_cooldown_b -= delta

	# Periodically re-evaluate whether to seek a pickup
	_pickup_seek_timer -= delta
	if _pickup_seek_timer <= 0.0:
		_pickup_seek_timer = randf_range(0.6, 1.4)  # Re-check ~every second
		var best_pickup := _evaluate_best_pickup()
		if best_pickup != "":
			if _seeking_pickup != best_pickup:
				_seeking_pickup = best_pickup
				_repath_timer = 0.0  # Force immediate repath toward pickup
				_last_target_grid_pos = Vector2i(-999, -999)
		else:
			if _seeking_pickup != "":
				_seeking_pickup = ""
				_repath_timer = 0.0  # Force repath back to real target
				_last_target_grid_pos = Vector2i(-999, -999)

	# If actively seeking a pickup, check if we've collected it (pickup gone or reached)
	if _seeking_pickup != "" and is_instance_valid(_arena_ref):
		var still_available := false
		if _seeking_pickup == "repair":
			still_available = bool(_arena_ref.get("pickup_repair_active"))
		elif _seeking_pickup == "overcharge":
			still_available = bool(_arena_ref.get("pickup_overcharge_active"))
		if not still_available:
			# Someone already collected it — abort and return to normal
			if _seeking_pickup == "repair":
				_pickup_cooldown_a = 3.0
			elif _seeking_pickup == "overcharge":
				_pickup_cooldown_b = 3.0
			_seeking_pickup = ""
			_repath_timer = 0.0
			_last_target_grid_pos = Vector2i(-999, -999)
	# ───────────────────────────────────────────────────────────────────────

	# Resolve effective target position — pickup overrides real target
	var effective_target_pos := target_node.global_position
	if _seeking_pickup != "" and is_instance_valid(_arena_ref):
		if _seeking_pickup == "repair":
			effective_target_pos = _arena_ref.get("PICKUP_REPAIR_POS")
		elif _seeking_pickup == "overcharge":
			effective_target_pos = _arena_ref.get("PICKUP_OVERCHARGE_POS")

	var dist_to_target := global_position.distance_to(effective_target_pos)

	# Aim facing direction toward effective target
	if dist_to_target > 1.0:
		facing_direction = (effective_target_pos - global_position).normalized()

	# Repath timing logic
	_repath_timer -= delta
	var target_grid := _get_grid_coord(effective_target_pos)
	var needs_repath := _repath_timer <= 0.0 or target_grid != _last_target_grid_pos or _nav_path.is_empty()

	if needs_repath and not _is_requesting_path:
		_request_path_to(effective_target_pos)

	# Scenario-specific behavior
	if _seeking_pickup != "":
		# While seeking pickup: just navigate, no combat
		current_state = AgentState.NAVIGATING
		var pickup_label := "SEEKING REPAIR CORE" if _seeking_pickup == "repair" else "SEEKING OVERCHARGE"
		current_tactic_status = pickup_label
		_follow_nav_path(delta)
		# Still fire at enemies we happen to see while running to pickup (opportunistic)
		var real_target_pos := target_node.global_position
		var real_dist := global_position.distance_to(real_target_pos)
		if real_dist <= attack_range and has_line_of_sight_to(real_target_pos):
			current_state = AgentState.ATTACKING
			var fire_dir := _calculate_lead_aim_direction(real_target_pos, real_dist)
			_try_fire_weapon(fire_dir)
	elif scenario == "combat":
		_process_combat_scenario(effective_target_pos, dist_to_target, delta)
	else:
		_process_race_scenario(effective_target_pos, delta)


func _process_combat_scenario(target_pos: Vector2, dist: float, delta: float) -> void:
	var can_see := has_line_of_sight_to(target_pos)
	var in_range := dist <= attack_range
	var my_hp_ratio := 1.0
	var opp_hp_ratio := 1.0

	if health_component and health_component.max_health > 0.0:
		my_hp_ratio = health_component.current_health / health_component.max_health
	if is_instance_valid(target_node):
		var opp_hc = target_node.get_node_or_null("HealthComponent")
		if opp_hc and opp_hc.max_health > 0.0:
			opp_hp_ratio = opp_hc.current_health / opp_hc.max_health

	# Dynamic lateral strafe flipping timer
	_strafe_timer -= delta
	if _strafe_timer <= 0.0:
		_strafe_timer = randf_range(1.0, 2.2)
		_strafe_direction = -_strafe_direction

	# Periodic tactic reassessment — creates non-deterministic behavior variety
	_tactic_reassess_timer -= delta
	if _tactic_reassess_timer <= 0.0:
		_tactic_reassess_timer = randf_range(2.5, 5.5)
		_aggressive_push = randf() > 0.55  # 45% chance to go aggressive

	# Dynamic tactical role state evaluation
	var desired_min_standoff := _min_standoff
	var desired_max_standoff := _max_standoff
	var current_tactic := "ENGAGING"

	match tactical_role.to_lower():
		"assault":
			# Assault: sometimes goes berserk, sometimes controlled burst
			if _aggressive_push and my_hp_ratio > 0.3:
				current_tactic = "BERSERK CHARGE"
				desired_min_standoff = 30.0
				desired_max_standoff = 90.0
			else:
				current_tactic = "CQB RUSH"
				desired_min_standoff = 70.0
				desired_max_standoff = 160.0
		"sniper":
			# Sniper: occasionally repositions to a new angle
			_repositioning_timer -= delta
			if _repositioning_timer <= 0.0:
				_repositioning_timer = randf_range(6.0, 12.0)
				# Brief reposition phase
				current_tactic = "REPOSITIONING"
				desired_min_standoff = 140.0
				desired_max_standoff = 200.0
			elif _aggressive_push and opp_hp_ratio < 0.4:
				current_tactic = "EXECUTE SHOT"
				desired_min_standoff = 200.0
				desired_max_standoff = 320.0
			else:
				current_tactic = "OVERWATCH"
				desired_min_standoff = 260.0
				desired_max_standoff = 380.0
		"flanker":
			# Flanker: cycles through phases — approach, strafe, withdraw
			_repositioning_timer -= delta
			if _repositioning_timer <= 0.0:
				_repositioning_timer = randf_range(2.0, 4.5)
				_flanker_phase = (_flanker_phase + 1) % 3
				_evasion_burst_timer = randf_range(0.4, 0.9)  # Random evasion on phase change
			match _flanker_phase:
				0:
					current_tactic = "EVASIVE FLANK"
					desired_min_standoff = 120.0
					desired_max_standoff = 200.0
				1:
					current_tactic = "AGGRESSIVE RUSH"
					desired_min_standoff = 60.0
					desired_max_standoff = 130.0
				2:
					current_tactic = "WITHDRAW & CIRCLE"
					desired_min_standoff = 220.0
					desired_max_standoff = 310.0
				_:
					current_tactic = "EVASIVE FLANK"
		"adaptive", _:
			if my_hp_ratio < 0.30:
				current_tactic = "EMERGENCY RETREAT"
				desired_min_standoff = 320.0
				desired_max_standoff = 460.0
			elif my_hp_ratio < 0.50:
				current_tactic = "RETREAT & RECOVER"
				desired_min_standoff = 230.0
				desired_max_standoff = 340.0
			elif opp_hp_ratio < 0.25 and my_hp_ratio > 0.50:
				current_tactic = "FINISH THEM"
				desired_min_standoff = 50.0
				desired_max_standoff = 130.0
			elif opp_hp_ratio < 0.45 and my_hp_ratio > 0.45:
				current_tactic = "PRESSING ADVANTAGE"
				desired_min_standoff = 90.0
				desired_max_standoff = 180.0
			elif _aggressive_push:
				current_tactic = "HUNTING"
				desired_min_standoff = 110.0
				desired_max_standoff = 200.0
			else:
				current_tactic = "BALANCED TACTICS"

	if _overcharge_timer > 0.0:
		current_tactic += " [OVERCHARGED]"

	current_tactic_status = current_tactic

	if in_range and can_see:
		current_state = AgentState.ATTACKING
		var to_target := (target_pos - global_position).normalized()
		var perp := to_target.orthogonal() * _strafe_direction

		if dist < desired_min_standoff:
			# Too close: kite/backpedal away, blended with lateral strafing
			var retreat_dir := (-to_target * 0.75 + perp * 0.45).normalized()
			velocity = velocity.move_toward(retreat_dir * move_speed, acceleration * delta)
		elif dist > desired_max_standoff:
			# Too far: close distance, blended with lateral strafing
			var advance_dir := (to_target * 0.85 + perp * 0.25).normalized()
			velocity = velocity.move_toward(advance_dir * move_speed, acceleration * delta)
		else:
			# In the tactical sweet spot: active dynamic strafing
			var strafe_speed := move_speed * 0.75
			if tactical_role == "flanker" or _evasion_burst_timer > 0.0:
				strafe_speed = move_speed * 0.95
			velocity = velocity.move_toward(perp * strafe_speed, acceleration * delta)

		var fire_dir := _calculate_lead_aim_direction(target_pos, dist)
		_try_fire_weapon(fire_dir)
	else:
		current_state = AgentState.NAVIGATING
		_follow_nav_path(delta)


func _calculate_lead_aim_direction(target_pos: Vector2, dist: float) -> Vector2:
	var proj_speed := 540.0
	if weapon_component and weapon_component.get("projectile_speed"):
		proj_speed = float(weapon_component.get("projectile_speed"))
	var time_to_impact := dist / maxf(proj_speed, 100.0)
	var target_vel := Vector2.ZERO
	if is_instance_valid(target_node) and "velocity" in target_node:
		target_vel = target_node.velocity
	
	var predicted_pos := target_pos + (target_vel * time_to_impact * _lead_aim_factor)
	return (predicted_pos - global_position).normalized()


func _process_race_scenario(_target_pos: Vector2, delta: float) -> void:
	current_state = AgentState.NAVIGATING
	_follow_nav_path(delta)


# ---------------------------------------------------------------------------
# Pickup Utility Evaluation System
# ---------------------------------------------------------------------------
func _evaluate_best_pickup() -> String:
	## Returns "repair", "overcharge", or "" based on tactical need and pickup availability.
	if not is_instance_valid(_arena_ref):
		return ""

	var my_hp_ratio := 1.0
	if health_component and health_component.max_health > 0.0:
		my_hp_ratio = health_component.current_health / health_component.max_health

	var repair_active: bool = bool(_arena_ref.get("pickup_repair_active"))
	var overcharge_active: bool = bool(_arena_ref.get("pickup_overcharge_active"))
	var repair_pos: Vector2 = _arena_ref.get("PICKUP_REPAIR_POS")
	var overcharge_pos: Vector2 = _arena_ref.get("PICKUP_OVERCHARGE_POS")

	var dist_repair := global_position.distance_to(repair_pos) if repair_active else INF
	var dist_overcharge := global_position.distance_to(overcharge_pos) if overcharge_active else INF

	# Distance thresholds per scenario: race agents detour more freely, combat agents only go when needed
	var repair_threshold := 550.0 if scenario == "race" else 420.0
	var overcharge_threshold := 420.0 if scenario == "race" else 320.0

	# ── Repair Core Utility ────────────────────────────────────────────────
	var repair_utility := 0.0
	if repair_active and _pickup_cooldown_a <= 0.0 and dist_repair < repair_threshold:
		# Urgent need: more valuable the lower HP is
		var hp_deficit := 1.0 - my_hp_ratio  # 0 = full HP, 1 = dead
		repair_utility = hp_deficit * 2.5

		# In race: also seek repair if we're ahead and can afford the detour
		if scenario == "race" and my_hp_ratio > 0.75:
			repair_utility = 0.0  # Don't bother if healthy in a race

		# Distance penalty: farther = less useful
		repair_utility -= (dist_repair / repair_threshold) * 0.6

		# Role bonus: adaptive heavily values healing when retreating
		if tactical_role == "adaptive" and my_hp_ratio < 0.5:
			repair_utility += 0.5

	# ── Overcharge Cell Utility ────────────────────────────────────────────
	var overcharge_utility := 0.0
	if overcharge_active and _pickup_cooldown_b <= 0.0 and dist_overcharge < overcharge_threshold and _overcharge_timer <= 0.0:
		# Base opportunistic value
		overcharge_utility = 0.6

		# Distance penalty
		overcharge_utility -= (dist_overcharge / overcharge_threshold) * 0.5

		# Role bonuses: aggressive roles love overcharge
		match tactical_role:
			"assault":
				overcharge_utility += 0.8  # Assault ALWAYS wants overcharge
			"flanker":
				overcharge_utility += 0.5  # Flanker loves speed burst
			"adaptive":
				if _aggressive_push:
					overcharge_utility += 0.4
			"sniper":
				overcharge_utility += 0.1  # Snipers care less (they stay still)

		# In race: overcharge is very valuable (speed boost helps reach objective)
		if scenario == "race":
			overcharge_utility += 0.5

	# ── Decision: pick highest utility above threshold 0.4 ─────────────────
	var pick_repair := repair_utility > 0.4
	var pick_overcharge := overcharge_utility > 0.4

	if pick_repair and pick_overcharge:
		# Both available: pick whichever is more urgent
		return "repair" if repair_utility >= overcharge_utility else "overcharge"
	elif pick_repair:
		return "repair"
	elif pick_overcharge:
		return "overcharge"
	return ""


func _follow_nav_path(delta: float) -> void:
	if _nav_path.is_empty() or _nav_path_index >= _nav_path.size():
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		return

	var next_point := _nav_path[_nav_path_index]
	var dist_to_pt := global_position.distance_to(next_point)

	# Advance waypoint if reached
	if dist_to_pt < 24.0:
		_nav_path_index += 1
		if _nav_path_index >= _nav_path.size():
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
			return
		next_point = _nav_path[_nav_path_index]

	var move_dir := (next_point - global_position).normalized()
	velocity = velocity.move_toward(move_dir * move_speed, acceleration * delta)


func _request_path_to(dest_pos: Vector2) -> void:
	_is_requesting_path = true
	_repath_timer = repath_interval
	_last_target_grid_pos = _get_grid_coord(dest_pos)

	var nav_mgr = get_node_or_null("/root/NavigationManager")
	if not nav_mgr or not nav_mgr.has_method("request_path"):
		_is_requesting_path = false
		return

	total_requests += 1

	nav_mgr.call(
		"request_path",
		global_position,
		dest_pos,
		_map_data_ref,
		func(path: PackedVector2Array, metrics: Dictionary) -> void:
			if not is_instance_valid(self):
				return
			_is_requesting_path = false
			last_metrics = metrics
			
			if metrics.has("nodes_expanded"):
				total_nodes_expanded += int(metrics["nodes_expanded"])
			if metrics.has("execution_time_ms"):
				total_algo_time_ms += float(metrics["execution_time_ms"])

			if path.size() > 0:
				_nav_path = path
				_nav_path_index = 0
				# Skip the first waypoint if it's right on top of us
				if _nav_path.size() > 1 and global_position.distance_to(_nav_path[0]) < 20.0:
					_nav_path_index = 1
				
				# Register with debug visualizer if available
				if nav_mgr.has_method("register_active_path"):
					nav_mgr.call("register_active_path", get_instance_id(), path, accent_color)
			
			path_updated.emit(self, path, metrics),
		algorithm
	)


func _try_fire_weapon(fire_dir: Vector2) -> void:
	if not weapon_component:
		return
	# Adjust firing rate if overcharged
	if _overcharge_timer > 0.0:
		weapon_component.set("attack_cooldown", _base_attack_cooldown * 0.70)
	else:
		weapon_component.set("attack_cooldown", _base_attack_cooldown)

	if weapon_component.can_attack():
		_recoil_offset = -fire_dir * 4.0
		if visual and visual.has_method("play_attack_recoil"):
			visual.call("play_attack_recoil", fire_dir)
		var spawn_pos := global_position + fire_dir * 18.0
		weapon_component.attack(fire_dir, spawn_pos, self)
		var audio = get_node_or_null("/root/AudioManager")
		if audio and audio.has_method("play_sfx"):
			audio.call("play_sfx", "laser_fire", randf_range(0.95, 1.05))


func _on_weapon_fired(proj: Node2D, _dir: Vector2) -> void:
	if proj and proj.has_signal("projectile_hit"):
		proj.connect("projectile_hit", func(target: Node, _pos: Vector2):
			if target != self and target != null:
				damage_dealt += weapon_component.damage
		)
	weapon_fired.emit(self, proj)


func has_line_of_sight_to(target_pos: Vector2) -> bool:
	var space_state := get_world_2d().direct_space_state
	if not space_state:
		return true

	var excl: Array[RID] = [get_rid()]
	if is_instance_valid(target_node) and target_node is CollisionObject2D:
		excl.append(target_node.get_rid())

	var query := PhysicsRayQueryParameters2D.create(global_position, target_pos)
	query.collision_mask = 1
	query.exclude = excl

	var result := space_state.intersect_ray(query)
	return result.is_empty()


func _get_grid_coord(pos: Vector2) -> Vector2i:
	if _map_data_ref and _map_data_ref.has_method("world_to_grid"):
		return _map_data_ref.call("world_to_grid", pos)
	return Vector2i(int(floor(pos.x / 32.0)), int(floor(pos.y / 32.0)))


func get_current_nav_path() -> PackedVector2Array:
	return _nav_path


func get_nav_path_index() -> int:
	return _nav_path_index


func get_remaining_path_points() -> PackedVector2Array:
	if _nav_path.is_empty() or _nav_path_index >= _nav_path.size():
		return PackedVector2Array()
	var res := PackedVector2Array()
	res.append(global_position)
	for i in range(_nav_path_index, _nav_path.size()):
		res.append(_nav_path[i])
	return res


# ---------------------------------------------------------------------------
# Damage & Defeat Handling
# ---------------------------------------------------------------------------
func apply_damage(damage_data: RefCounted) -> bool:
	if not damage_data or current_state == AgentState.DEAD:
		return false
	var force: float = float(damage_data.get("knockback_force"))
	if force > 0.0:
		var dir: Vector2 = damage_data.get("knockback_direction")
		velocity += dir * force
	return take_damage(float(damage_data.get("amount")), damage_data.get("source"))


func take_damage(amount: float, source: Node = null) -> bool:
	if current_state == AgentState.DEAD:
		return false

	var res := false
	if health_component and health_component.has_method("damage"):
		res = health_component.call("damage", amount, source)
	
	if res:
		damage_taken += amount
		_hit_flash_timer = 1.0
		# Dynamic reflex evasion: speed burst and strafe reversal
		_evasion_burst_timer = 0.45
		_strafe_direction = -_strafe_direction
		if visual and visual.has_method("play_damage_flash"):
			visual.call("play_damage_flash")
		agent_damaged.emit(self, amount, health_component.current_health)
		FloatingCombatTextScript.spawn(self, global_position, "-%d" % int(amount), Color(1.0, 0.4, 0.4))
		var audio = get_node_or_null("/root/AudioManager")
		if audio and audio.has_method("play_sfx"):
			audio.call("play_sfx", "laser_hit", randf_range(0.95, 1.1))

	return res


func heal(amount: float) -> void:
	if current_state == AgentState.DEAD:
		return
	if health_component and health_component.has_method("heal"):
		health_component.call("heal", amount)
	elif health_component:
		health_component.current_health = minf(health_component.max_health, health_component.current_health + amount)
	FloatingCombatTextScript.spawn(self, global_position, "+%d HP" % int(amount), Color(0.2, 1.0, 0.4))
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_sfx"):
		audio.call("play_sfx", "pickup", 1.15)
	queue_redraw()


func apply_overcharge_boost(duration: float = 8.0) -> void:
	if current_state == AgentState.DEAD:
		return
	_overcharge_timer = duration
	FloatingCombatTextScript.spawn(self, global_position, "OVERCHARGED!", Color(1.0, 0.85, 0.2))
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_sfx"):
		audio.call("play_sfx", "powerup", 1.25)
	queue_redraw()


func _on_damage_data_received(data: RefCounted) -> void:
	if data:
		var force: float = float(data.get("knockback_force"))
		if force > 0.0:
			var dir: Vector2 = data.get("knockback_direction")
			velocity += dir * force


func _on_health_depleted() -> void:
	if current_state == AgentState.DEAD:
		return
	current_state = AgentState.DEAD
	velocity = Vector2.ZERO
	_nav_path.clear()
	
	var nav_mgr = get_node_or_null("/root/NavigationManager")
	if nav_mgr and nav_mgr.has_method("unregister_active_path"):
		nav_mgr.call("unregister_active_path", get_instance_id())

	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	if visual and visual.has_method("play_death"):
		visual.call("play_death")

	agent_died.emit(self)
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_sfx"):
		audio.call("play_sfx", "enemy_death", randf_range(0.9, 1.05))


func get_metrics() -> Dictionary:
	var cur_hp := 0.0
	var max_hp := 100.0
	if health_component:
		cur_hp = health_component.current_health
		max_hp = health_component.max_health

	return {
		"agent_name": agent_name,
		"team": team_group,
		"algorithm": algorithm,
		"tactical_role": tactical_role,
		"current_tactic": current_tactic_status,
		"overcharged": _overcharge_timer > 0.0,
		"scenario": scenario,
		"is_alive": current_state != AgentState.DEAD,
		"current_health": cur_hp,
		"max_health": max_hp,
		"health_percentage": (cur_hp / max_hp) * 100.0 if max_hp > 0.0 else 0.0,
		"damage_dealt": damage_dealt,
		"damage_taken": damage_taken,
		"total_requests": total_requests,
		"total_nodes_expanded": total_nodes_expanded,
		"total_algo_time_ms": total_algo_time_ms,
		"avg_time_per_request_ms": (total_algo_time_ms / float(total_requests)) if total_requests > 0 else 0.0,
		"total_distance_traveled": total_distance_traveled,
		"last_metrics": last_metrics
	}


func _exit_tree() -> void:
	var nav_mgr = get_node_or_null("/root/NavigationManager")
	if nav_mgr and nav_mgr.has_method("unregister_active_path"):
		nav_mgr.call("unregister_active_path", get_instance_id())


# ---------------------------------------------------------------------------
# Procedural Drawing & Mini HUD
# ---------------------------------------------------------------------------
func _draw() -> void:
	# If dead, don't draw overhead telemetry
	if current_state == AgentState.DEAD:
		return

	# Overcharge dynamic aura
	if _overcharge_timer > 0.0:
		var pulse := 1.0 + 0.12 * sin(Time.get_ticks_msec() * 0.012)
		draw_arc(Vector2.ZERO, 20.0 * pulse, 0.0, TAU, 24, Color(1.0, 0.85, 0.2, 0.7), 2.0)

	# Overhead Floating Team Marker & Mini Health Pip (Clean, No text overlap)
	var hud_y := -24.0
	var hp_pct := 1.0
	if health_component and health_component.max_health > 0.0:
		hp_pct = clampf(health_component.current_health / health_component.max_health, 0.0, 1.0)

	var bar_w := 28.0
	var bar_h := 3.5
	var bar_x := -bar_w * 0.5

	# Team indicator diamond
	var diamond_center := Vector2(0.0, hud_y - 6.0)
	var pts := PackedVector2Array([
		diamond_center + Vector2(0, -4),
		diamond_center + Vector2(4, 0),
		diamond_center + Vector2(0, 4),
		diamond_center + Vector2(-4, 0)
	])
	draw_colored_polygon(pts, accent_color)

	# Mini health bar background
	draw_rect(Rect2(bar_x - 1, hud_y - 1, bar_w + 2, bar_h + 2), Color(0.04, 0.05, 0.08, 0.9))
	draw_rect(Rect2(bar_x, hud_y, bar_w, bar_h), Color(0.12, 0.14, 0.18, 0.95))

	# Dynamic Health Fill
	var fill_color := accent_color.lerp(Color(1.0, 0.25, 0.25), 1.0 - hp_pct)
	draw_rect(Rect2(bar_x, hud_y, bar_w * hp_pct, bar_h), fill_color)
