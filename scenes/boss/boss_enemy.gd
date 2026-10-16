extends CharacterBody2D
class_name BossEnemy
## Colossal Boss Enemy for BioSphere-X.
## Implements a dedicated multi-phase Finite State Machine:
## GUARD -> PURSUE -> ATTACK -> RECOVER -> ENRAGED -> DEFEATED.
## Features distinct telegraphed attacks (Tremor Shockwave Slam, Plasma Nova Barrage, Hyper Charge Rush),
## clear vulnerable recovery periods, multiple combat phases (<50% HP Enraged),
## top-center cinematic health display, and defeat reward dispersal.

signal state_changed(old_state: State, new_state: State)
signal phase_changed(new_phase: int)
signal boss_damaged(amount: float, current_hp: float, max_hp: float)
signal boss_attacked(attack_type: String, damage: float)
signal boss_defeated()
signal decision_received(algorithm: String, action: String, statistics: Dictionary)

enum State {
	GUARD,
	PURSUE,
	ATTACK,
	RECOVER,
	ENRAGED_TRANSITION,
	DEFEATED
}

enum AttackType {
	NONE,
	TREMOR_SLAM,
	PLASMA_BARRAGE,
	CHARGE_RUSH
}

const DamageDataScript := preload("res://scripts/components/damage_data.gd")
const _projectile_scene := preload("res://scenes/items/energy_projectile.tscn")
const _collectable_scene := preload("res://scenes/items/collectable_resource.tscn")
const _boss_health_bar_script := preload("res://scenes/boss/boss_health_bar.gd")
const BossDecisionModuleScript := preload("res://scenes/boss/decision/boss_decision_module.gd")
const BossCombatStateScript := preload("res://scenes/boss/decision/boss_combat_state.gd")
const BossAlphaBetaDecisionScript := preload("res://scenes/boss/decision/boss_alpha_beta_decision.gd")
const BossActionAdapterScript := preload("res://scenes/boss/decision/boss_action_adapter.gd")

@export_group("Boss Identity & Phases")
@export var boss_name: String = "GOLIATH PRIME — EXOPLANET MATRIARCH"
@export var enrage_health_threshold_ratio: float = 0.50 # Transitions to Phase 2 at 50% HP
@export var guard_radius: float = 180.0
@export var engage_distance: float = 420.0
@export var knockback_resistance: float = 0.85 # Reduces knockback forces to 15%

@export_group("Speeds & Physics")
@export var normal_patrol_speed: float = 55.0
@export var normal_chase_speed: float = 95.0
@export var enraged_chase_speed: float = 135.0
@export var charge_speed: float = 380.0
@export var acceleration: float = 750.0
@export var friction: float = 850.0

@export_group("Attack Attributes")
@export var slam_damage: float = 35.0
@export var slam_radius: float = 135.0
@export var slam_windup_time: float = 0.75
@export var slam_cooldown: float = 3.5

@export_group("Barrage Attributes")
@export var barrage_damage: float = 14.0
@export var barrage_windup_time: float = 0.60
@export var barrage_cooldown: float = 4.0
@export var barrage_projectile_speed: float = 360.0

@export_group("Charge Attributes")
@export var charge_damage: float = 30.0
@export var charge_windup_time: float = 0.65
@export var charge_distance: float = 220.0
@export var charge_cooldown: float = 5.0

@export_group("Recovery & Vulnerability")
@export var recover_duration_normal: float = 1.40
@export var recover_duration_enraged: float = 0.85
@export var guard_damage_reduction: float = 0.20 # 20% reduction during guard
@export var recover_damage_vulnerability: float = 1.25 # 25% extra damage taken during recover

@export_group("AI Decision-Making Engine")
@export var decision_module_enabled: bool = true
@export var in_engine_search_depth: int = 3
@export var use_python_decision: bool = true
@export var decision_algorithm: String = "alpha_beta" # "alpha_beta", "minimax", "mcts", "heuristic"
@export var decision_poll_interval: float = 0.25 # Poll every 250ms during PURSUE
@export var max_search_depth: int = 4
@export var mcts_simulations: int = 150

# In-Engine & Remote AI Decision Tracking
var decision_module: RefCounted = null
var _is_decision_pending: bool = false
var _decision_poll_timer: float = 0.0
var _last_received_action: String = ""
var last_decision_stats: Dictionary = {}

# FSM State Variables
var current_state: State = State.GUARD
var current_phase: int = 1 # 1 = Guardian, 2 = Enraged
var anchor_position: Vector2 = Vector2.ZERO

var _target_player: Node2D = null
var _chosen_attack: AttackType = AttackType.NONE
var _state_timer: float = 0.0
var _attack_timer: float = 0.0
var _slam_cooldown_timer: float = 0.0
var _barrage_cooldown_timer: float = 0.0
var _charge_cooldown_timer: float = 0.0
var _has_enraged: bool = false
var _charge_start_pos: Vector2 = Vector2.ZERO
var _charge_dir: Vector2 = Vector2.ZERO
var _charge_hit_player: bool = false

# Internal deterministic RNG
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Child References
@onready var visual: Node2D = $Visual
@onready var health_component: Node = $HealthComponent
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var health_bar_ui: CanvasLayer = null


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	
	collision_layer = 1
	collision_mask = 1
	
	_rng.randomize()
	anchor_position = global_position
	
	_setup_health_component()
	_setup_health_bar()
	_init_decision_module()
	
	change_state(State.GUARD)


func _setup_health_component() -> void:
	if not health_component:
		health_component = get_node_or_null("HealthComponent")
	if health_component:
		health_component.set("max_health", 500.0)
		health_component.set("current_health", 500.0)
		
		if health_component.has_signal("damaged") and not health_component.is_connected("damaged", _on_health_damaged):
			health_component.connect("damaged", _on_health_damaged)
		if health_component.has_signal("died") and not health_component.is_connected("died", _on_health_died):
			health_component.connect("died", _on_health_died)


func _setup_health_bar() -> void:
	if not health_bar_ui:
		health_bar_ui = _boss_health_bar_script.new()
		add_child(health_bar_ui)
		health_bar_ui.call("setup", boss_name, 500.0)


func _physics_process(delta: float) -> void:
	if current_state == State.DEFEATED:
		velocity = Vector2.ZERO
		return
	
	_update_cooldowns(delta)
	_update_target_player()
	
	# Execute State Machine
	match current_state:
		State.GUARD:
			_process_guard(delta)
		State.PURSUE:
			_process_pursue(delta)
		State.ATTACK:
			_process_attack(delta)
		State.RECOVER:
			_process_recover(delta)
		State.ENRAGED_TRANSITION:
			_process_enraged_transition(delta)
	
	move_and_slide()
	
	# Update visual procedural animations
	if visual and visual.has_method("update_motion"):
		visual.call("update_motion", velocity, int(current_state), delta)


func _update_cooldowns(delta: float) -> void:
	if _slam_cooldown_timer > 0.0:
		_slam_cooldown_timer = maxf(0.0, _slam_cooldown_timer - delta)
	if _barrage_cooldown_timer > 0.0:
		_barrage_cooldown_timer = maxf(0.0, _barrage_cooldown_timer - delta)
	if _charge_cooldown_timer > 0.0:
		_charge_cooldown_timer = maxf(0.0, _charge_cooldown_timer - delta)


# ---------------------------------------------------------------------------
# FSM State Behaviors
# ---------------------------------------------------------------------------
func _process_guard(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	
	if _can_detect_player():
		# Engage player
		if health_bar_ui:
			health_bar_ui.call("set_active", true)
		change_state(State.PURSUE)
		return
	
	# Gentle anchor patrol
	var dist_from_anchor := global_position.distance_to(anchor_position)
	if dist_from_anchor > guard_radius:
		var back_dir := (anchor_position - global_position).normalized()
		velocity = velocity.move_toward(back_dir * normal_patrol_speed, acceleration * delta)


func _process_pursue(delta: float) -> void:
	if not _is_target_valid():
		change_state(State.GUARD)
		return
	
	var to_player := _target_player.global_position - global_position
	var dist := to_player.length()
	
	# Check for Phase 2 Enrage transition
	_check_enrage_threshold()
	if current_state == State.ENRAGED_TRANSITION:
		return
	
	# 1. In-Engine Decision Module (Minimax Alpha-Beta via Safe Action Adapter)
	if decision_module_enabled and decision_module:
		_decision_poll_timer -= delta
		if _decision_poll_timer <= 0.0:
			_decision_poll_timer = decision_poll_interval
			var ctx := _build_combat_context(dist)
			var decision: Dictionary = decision_module.choose_action(ctx)
			_last_received_action = String(decision.get("action", ""))
			last_decision_stats = decision.get("statistics", {})
			decision_received.emit(decision_module.get_module_name(), _last_received_action, last_decision_stats)
		
		# Apply through safe action adapter
		var decision_dict := {"action": _last_received_action}
		var applied: bool = BossActionAdapterScript.apply_decision(
			self,
			decision_dict,
			dist,
			delta,
			to_player,
			decision_module_enabled
		)
		if applied and current_state == State.ATTACK:
			_last_received_action = ""
			return
		return
	
	# 2. Dispatch asynchronous AI decision request if enabled
	if use_python_decision:
		_process_ai_decision_pipeline(delta, dist)
	
	# Check if AI decision provided an actionable attack
	if _try_execute_ai_action(dist):
		return
	
	# Safe Fallback: select appropriate attack based on local rules
	var chosen := _evaluate_attack_choice(dist)
	if chosen != AttackType.NONE:
		_chosen_attack = chosen
		change_state(State.ATTACK)
		return
	
	# Move toward player (or tactical repositioning if suggested by AI)
	_process_pursue_movement(delta, to_player, dist)


func _init_decision_module() -> void:
	if decision_module_enabled and not decision_module:
		var ab = BossAlphaBetaDecisionScript.new()
		ab.max_depth = in_engine_search_depth
		decision_module = ab


func set_decision_module(module: RefCounted) -> void:
	decision_module = module


func get_decision_module() -> RefCounted:
	return decision_module


func _build_combat_context(dist: float) -> Dictionary:
	var cur_hp := 500.0
	var mx_hp := 500.0
	if health_component:
		cur_hp = float(health_component.get("current_health"))
		mx_hp = float(health_component.get("max_health"))
	
	var p_hp := 100.0
	var p_energy := 100.0
	if is_instance_valid(_target_player):
		if "current_health" in _target_player:
			p_hp = float(_target_player.get("current_health"))
		if "energy" in _target_player:
			p_energy = float(_target_player.get("energy"))
			
	return {
		"turn": "boss",
		"boss_hp": cur_hp,
		"boss_max_hp": mx_hp,
		"boss_phase": current_phase,
		"slam_cooldown": _slam_cooldown_timer,
		"barrage_cooldown": _barrage_cooldown_timer,
		"charge_cooldown": _charge_cooldown_timer,
		"is_recovering": current_state == State.RECOVER,
		"recover_timer": _state_timer if current_state == State.RECOVER else 0.0,
		"is_guarding": current_state == State.GUARD,
		"player_hp": p_hp,
		"player_max_hp": 100.0,
		"player_energy": p_energy,
		"distance": dist
	}


func _process_ai_decision_pipeline(delta: float, dist: float) -> void:
	if _is_decision_pending:
		return
	
	_decision_poll_timer -= delta
	if _decision_poll_timer > 0.0:
		return
	
	_decision_poll_timer = decision_poll_interval
	
	var ai_node = get_node_or_null("/root/AIClient")
	if not ai_node or not ai_node.has_method("request_boss_decision"):
		return
	
	var cur_hp := 500.0
	var mx_hp := 500.0
	if health_component:
		cur_hp = float(health_component.get("current_health"))
		mx_hp = float(health_component.get("max_health"))
	
	var p_hp := 100.0
	var p_energy := 100.0
	if is_instance_valid(_target_player):
		if "current_health" in _target_player:
			p_hp = float(_target_player.get("current_health"))
		if "energy" in _target_player:
			p_energy = float(_target_player.get("energy"))
	
	var state_data := {
		"turn": "boss",
		"boss_hp": cur_hp,
		"boss_max_hp": mx_hp,
		"boss_phase": current_phase,
		"slam_cooldown": _slam_cooldown_timer,
		"barrage_cooldown": _barrage_cooldown_timer,
		"charge_cooldown": _charge_cooldown_timer,
		"is_recovering": current_state == State.RECOVER,
		"recover_timer": _state_timer if current_state == State.RECOVER else 0.0,
		"is_guarding": current_state == State.GUARD,
		"player_hp": p_hp,
		"player_max_hp": 100.0,
		"player_energy": p_energy,
		"distance": dist
	}
	
	var opts := {
		"max_depth": max_search_depth,
		"simulations": mcts_simulations
	}
	
	_is_decision_pending = true
	ai_node.call("request_boss_decision", state_data, decision_algorithm, opts, _on_ai_decision_result)


func _on_ai_decision_result(res: Dictionary) -> void:
	_is_decision_pending = false
	if not res.get("success", false):
		return # Graceful fallback; keep local state intact
	
	var data: Dictionary = res.get("data", {})
	var act: String = String(data.get("action", ""))
	if not act.is_empty():
		_last_received_action = act
		last_decision_stats = data.get("statistics", {})
		decision_received.emit(decision_algorithm, _last_received_action, last_decision_stats)


func _try_execute_ai_action(dist: float) -> bool:
	if _last_received_action.is_empty():
		return false
	
	var executed := false
	match _last_received_action:
		"TREMOR_SLAM":
			if dist <= slam_radius * 1.1 and _slam_cooldown_timer <= 0.0:
				_chosen_attack = AttackType.TREMOR_SLAM
				executed = true
		"PLASMA_BARRAGE":
			if dist <= 360.0 and _barrage_cooldown_timer <= 0.0:
				_chosen_attack = AttackType.PLASMA_BARRAGE
				executed = true
		"CHARGE_RUSH":
			if (current_phase == 2 or dist >= 90.0) and _charge_cooldown_timer <= 0.0:
				_chosen_attack = AttackType.CHARGE_RUSH
				executed = true
		"GUARD_STANCE":
			if dist > 200.0:
				change_state(State.GUARD)
				_last_received_action = ""
				return true
	
	if executed:
		_last_received_action = ""
		change_state(State.ATTACK)
		return true
	
	return false


func _process_pursue_movement(delta: float, to_player: Vector2, dist: float) -> void:
	var move_speed := enraged_chase_speed if current_phase == 2 else normal_chase_speed
	var target_vel := to_player.normalized() * move_speed
	
	if _last_received_action == "TACTICAL_RETREAT" and dist < 180.0:
		target_vel = -to_player.normalized() * (normal_patrol_speed * 0.8)
	
	velocity = velocity.move_toward(target_vel, acceleration * delta)


func set_decision_algorithm(algo: String) -> void:
	decision_algorithm = algo


func get_decision_algorithm() -> String:
	return decision_algorithm


func _evaluate_attack_choice(dist_to_player: float) -> AttackType:
	# 1. Tremor Slam if in close range
	if dist_to_player <= slam_radius * 0.95 and _slam_cooldown_timer <= 0.0:
		return AttackType.TREMOR_SLAM
	
	# 2. Hyper Charge Rush in Phase 2 or if player is at medium-long range
	if (current_phase == 2 or dist_to_player > 160.0) and _charge_cooldown_timer <= 0.0:
		if dist_to_player <= charge_distance * 1.3:
			return AttackType.CHARGE_RUSH
	
	# 3. Plasma Barrage if at medium range
	if dist_to_player <= 320.0 and _barrage_cooldown_timer <= 0.0:
		return AttackType.PLASMA_BARRAGE
		
	return AttackType.NONE


func _process_attack(delta: float) -> void:
	_attack_timer += delta
	
	var windup_limit: float = slam_windup_time
	match _chosen_attack:
		AttackType.PLASMA_BARRAGE: windup_limit = barrage_windup_time
		AttackType.CHARGE_RUSH: windup_limit = charge_windup_time
	
	# Windup Telegraph Phase
	if _attack_timer < windup_limit:
		var ratio := clampf(_attack_timer / windup_limit, 0.0, 1.0)
		_update_attack_telegraph(ratio)
		# Slow down and face target during windup
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta * 2.0)
		if _target_player:
			var target_ang := (_target_player.global_position - global_position).angle()
			if visual and "facing_angle" in visual:
				visual.set("facing_angle", lerp_angle(float(visual.get("facing_angle")), target_ang, delta * 12.0))
		return
	
	# Execute the telegraphed attack
	_execute_current_attack(delta)


func _update_attack_telegraph(ratio: float) -> void:
	if not visual:
		return
	visual.set("attack_windup_ratio", ratio)
	visual.set("current_attack_type", int(_chosen_attack))
	
	match _chosen_attack:
		AttackType.TREMOR_SLAM:
			visual.set("attack_telegraph_radius", slam_radius)
		AttackType.CHARGE_RUSH:
			if _target_player:
				var c_dir := (_target_player.global_position - global_position).normalized()
				visual.set("attack_telegraph_direction", c_dir)
				visual.set("attack_telegraph_length", charge_distance)
		AttackType.PLASMA_BARRAGE:
			pass


func _execute_current_attack(delta: float) -> void:
	match _chosen_attack:
		AttackType.TREMOR_SLAM:
			_execute_tremor_slam()
			_slam_cooldown_timer = slam_cooldown
			_finish_attack()
			
		AttackType.PLASMA_BARRAGE:
			_execute_plasma_barrage()
			_barrage_cooldown_timer = barrage_cooldown
			_finish_attack()
			
		AttackType.CHARGE_RUSH:
			# Execute charge burst
			_execute_charge_rush_step(delta)


func _execute_tremor_slam() -> void:
	# Check distance to player
	if _is_target_valid():
		var dist := global_position.distance_to(_target_player.global_position)
		if dist <= slam_radius:
			var slam_dir := (_target_player.global_position - global_position).normalized()
			var slam_data = DamageDataScript.create(
				slam_damage,
				self,
				DamageDataScript.DamageType.PHYSICAL,
				slam_dir,
				240.0,
				global_position
			)
			_apply_damage_to_target(_target_player, slam_data, slam_damage)
			boss_attacked.emit("TREMOR_SLAM", slam_damage)


func _execute_plasma_barrage() -> void:
	# Radial starburst of 8 plasma projectiles
	var num_bolts: int = 8 if current_phase == 1 else 12
	for i in num_bolts:
		var ang: float = (float(i) / float(num_bolts)) * TAU
		if _target_player and current_phase == 2:
			# Targeted fan spread in Phase 2
			var to_player_ang := (_target_player.global_position - global_position).angle()
			ang = to_player_ang + ((float(i) - float(num_bolts) * 0.5) / float(num_bolts)) * 1.4
			
		var bolt_dir := Vector2.from_angle(ang)
		_spawn_plasma_bolt(bolt_dir)
	
	boss_attacked.emit("PLASMA_BARRAGE", barrage_damage)


func _spawn_plasma_bolt(dir: Vector2) -> void:
	if not _projectile_scene:
		return
	
	var proj: Area2D = _projectile_scene.instantiate()
	var spawn_pos := global_position + dir * 26.0
	
	var parent: Node = get_parent()
	if parent:
		parent.add_child(proj)
	else:
		add_child(proj)
		
	proj.global_position = spawn_pos
	
	if proj.has_method("setup"):
		var color := Color(0.2, 1.0, 0.4) if current_phase == 1 else Color(1.0, 0.25, 0.1)
		proj.call(
			"setup",
			dir,
			self,
			barrage_damage,
			barrage_projectile_speed,
			380.0,
			color
		)


func _execute_charge_rush_step(delta: float) -> void:
	if _charge_dir == Vector2.ZERO:
		if _is_target_valid():
			_charge_dir = (_target_player.global_position - global_position).normalized()
		else:
			_charge_dir = Vector2.from_angle(visual.facing_angle if visual else 0.0)
		_charge_start_pos = global_position
		_charge_hit_player = false
	
	# Dash forward
	velocity = _charge_dir * charge_speed
	
	# Collision check with player
	if not _charge_hit_player and _is_target_valid():
		var dist := global_position.distance_to(_target_player.global_position)
		if dist <= 38.0:
			_charge_hit_player = true
			var charge_data = DamageDataScript.create(
				charge_damage,
				self,
				DamageDataScript.DamageType.PHYSICAL,
				_charge_dir,
				220.0,
				global_position
			)
			_apply_damage_to_target(_target_player, charge_data, charge_damage)
			boss_attacked.emit("CHARGE_RUSH", charge_damage)
	
	var dist_traveled := global_position.distance_to(_charge_start_pos)
	if dist_traveled >= charge_distance or is_on_wall():
		_charge_dir = Vector2.ZERO
		_charge_cooldown_timer = charge_cooldown
		_finish_attack()


func _finish_attack() -> void:
	_attack_timer = 0.0
	_chosen_attack = AttackType.NONE
	if visual:
		visual.set("attack_windup_ratio", 0.0)
		visual.set("current_attack_type", 0)
	change_state(State.RECOVER)


func _process_recover(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, friction * delta * 1.5)
	_state_timer -= delta
	
	var total_dur := recover_duration_enraged if current_phase == 2 else recover_duration_normal
	if visual:
		visual.set("recover_ratio", clampf(_state_timer / total_dur, 0.0, 1.0))
	
	if _state_timer <= 0.0:
		if visual:
			visual.set("recover_ratio", 0.0)
		change_state(State.PURSUE)


func _process_enraged_transition(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, friction * delta * 2.0)
	_state_timer -= delta
	
	if _state_timer <= 0.0:
		current_phase = 2
		phase_changed.emit(2)
		if visual and visual.has_method("set_phase"):
			visual.call("set_phase", 1)
		if health_bar_ui:
			health_bar_ui.call("set_phase", 1)
		change_state(State.PURSUE)


func _check_enrage_threshold() -> void:
	if _has_enraged or not health_component:
		return
	
	var cur: float = health_component.get("current_health")
	var mx: float = health_component.get("max_health")
	if (cur / mx) <= enrage_health_threshold_ratio:
		_has_enraged = true
		change_state(State.ENRAGED_TRANSITION)


# ---------------------------------------------------------------------------
# State Transitions & Helpers
# ---------------------------------------------------------------------------
func change_state(new_state: State) -> void:
	if current_state == new_state or current_state == State.DEFEATED:
		return
	
	var old_state := current_state
	current_state = new_state
	
	match new_state:
		State.GUARD:
			_state_timer = 0.0
		State.PURSUE:
			_state_timer = 0.0
		State.ATTACK:
			_attack_timer = 0.0
		State.RECOVER:
			_state_timer = recover_duration_enraged if current_phase == 2 else recover_duration_normal
		State.ENRAGED_TRANSITION:
			_state_timer = 1.20 # Enrage roar pause
			velocity = Vector2.ZERO
		State.DEFEATED:
			velocity = Vector2.ZERO
			if collision_shape:
				collision_shape.disabled = true
				collision_shape.set_deferred("disabled", true)
			if visual and visual.has_method("play_death"):
				visual.call("play_death")
			if health_bar_ui:
				health_bar_ui.call("show_defeat")
	
	state_changed.emit(old_state, new_state)


func _update_target_player() -> void:
	if not is_instance_valid(_target_player) or not _target_player.is_inside_tree():
		var players := get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			_target_player = players[0] as Node2D
		else:
			_target_player = null


func _can_detect_player() -> bool:
	if not _is_target_valid():
		return false
	return global_position.distance_to(_target_player.global_position) <= engage_distance


func _is_target_valid() -> bool:
	if not is_instance_valid(_target_player) or not _target_player.is_inside_tree():
		return false
	if "is_dead" in _target_player and _target_player.get("is_dead"):
		return false
	return true


func set_target_player(player: Node2D) -> void:
	_target_player = player


func get_target_player() -> Node2D:
	return _target_player


# ---------------------------------------------------------------------------
# Public Health & Damage Implementation
# ---------------------------------------------------------------------------
func apply_damage(damage_data: RefCounted) -> bool:
	if not damage_data or current_state == State.DEFEATED:
		return false
	
	var force: float = float(damage_data.get("knockback_force")) * (1.0 - knockback_resistance)
	if force > 0.0:
		var dir: Vector2 = damage_data.get("knockback_direction")
		velocity += dir * force
		
	return take_damage(float(damage_data.get("amount")), damage_data.get("source"))


func take_damage(amount: float, source: Node = null) -> bool:
	if current_state == State.DEFEATED or current_state == State.ENRAGED_TRANSITION:
		return false
	
	# Apply state-based damage multipliers (Fair Tactical Windows)
	var final_dmg := amount
	if current_state == State.GUARD:
		final_dmg *= (1.0 - guard_damage_reduction) # Shielded
	elif current_state == State.RECOVER:
		final_dmg *= recover_damage_vulnerability # Vulnerable counterattack window
	
	if not health_component:
		health_component = get_node_or_null("HealthComponent")
		
	var result := false
	if health_component and health_component.has_method("damage"):
		result = health_component.call("damage", final_dmg, source)
	
	if result:
		if health_bar_ui:
			health_bar_ui.call("set_active", true)
			var cur: float = health_component.get("current_health")
			health_bar_ui.call("update_health", cur)
		
		# If damaged while idling in Guard, immediately pursue attacker
		if current_state == State.GUARD:
			change_state(State.PURSUE)
			
	return result


func _on_health_damaged(amount: float, _source: Node = null) -> void:
	if visual and visual.has_method("play_damage_flash"):
		visual.call("play_damage_flash")
	
	var cur: float = health_component.get("current_health") if health_component else 0.0
	var mx: float = health_component.get("max_health") if health_component else 500.0
	boss_damaged.emit(amount, cur, mx)
	
	if health_bar_ui:
		health_bar_ui.call("update_health", cur, mx)
	
	# Check for Phase 2 Enrage transition
	_check_enrage_threshold()


func _on_health_died() -> void:
	if current_state == State.DEFEATED:
		return
	change_state(State.DEFEATED)
	
	_spawn_colossal_defeat_rewards()
	boss_defeated.emit()


func _spawn_colossal_defeat_rewards() -> void:
	var parent := get_parent()
	if not parent or not _collectable_scene:
		return
	
	# High-value reward bundle:
	# 3x Energy Crystals (Type 2), 3x Titanium Metal (Type 1), 3x Biomass (Type 3), 2x Oxygen Cells (Type 0)
	var drops: Array[Dictionary] = [
		{"type": 2, "qty": 3},
		{"type": 1, "qty": 3},
		{"type": 3, "qty": 3},
		{"type": 0, "qty": 2}
	]
	
	for drop in drops:
		var offset := Vector2.from_angle(_rng.randf_range(0.0, TAU)) * _rng.randf_range(28.0, 56.0)
		var item: Area2D = _collectable_scene.instantiate()
		item.set("resource_type", drop["type"])
		item.set("quantity", drop["qty"])
		parent.add_child(item)
		item.global_position = global_position + offset


func _apply_damage_to_target(target: Node, damage_data: RefCounted, raw_amount: float) -> void:
	if target.has_method("apply_damage"):
		target.call("apply_damage", damage_data)
	elif target.has_method("take_damage"):
		target.call("take_damage", raw_amount, self)
	elif target.has_node("HealthComponent"):
		target.get_node("HealthComponent").call("damage", raw_amount, self)


func get_state_name() -> String:
	match current_state:
		State.GUARD: return "GUARD"
		State.PURSUE: return "PURSUE"
		State.ATTACK: return "ATTACK"
		State.RECOVER: return "RECOVER"
		State.ENRAGED_TRANSITION: return "ENRAGED_TRANSITION"
		State.DEFEATED: return "DEFEATED"
	return "UNKNOWN"
