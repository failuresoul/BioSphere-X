class_name BossCombatState
extends RefCounted
## Simplified discrete, turn-based combat state representation for Goliath Prime.
## Models adversarial interactions between Boss (MAX) and Player (MIN).
## Defines state variables, legal actions, transition rules, terminal conditions, and evaluation.

# Boss Legal Actions
const ACTION_TREMOR_SLAM := "TREMOR_SLAM"
const ACTION_PLASMA_BARRAGE := "PLASMA_BARRAGE"
const ACTION_CHARGE_RUSH := "CHARGE_RUSH"
const ACTION_PURSUE_ADVANCE := "PURSUE_ADVANCE"
const ACTION_TACTICAL_RETREAT := "TACTICAL_RETREAT"
const ACTION_GUARD_STANCE := "GUARD_STANCE"
const ACTION_RECOVER_WAIT := "RECOVER_WAIT"

# Player Legal Actions (for adversarial tree modeling)
const ACTION_PLAYER_SHOOT := "PLAYER_SHOOT"
const ACTION_PLAYER_DODGE := "PLAYER_DODGE"
const ACTION_PLAYER_CLOSE_IN := "PLAYER_CLOSE_IN"
const ACTION_PLAYER_FALL_BACK := "PLAYER_FALL_BACK"
const ACTION_PLAYER_REST := "PLAYER_REST"

# State Variables
var turn: String = "boss" # "boss" or "player"
var boss_hp: float = 500.0
var boss_max_hp: float = 500.0
var boss_phase: int = 1
var slam_cooldown: float = 0.0
var barrage_cooldown: float = 0.0
var charge_cooldown: float = 0.0
var is_recovering: bool = false
var recover_timer: float = 0.0
var is_guarding: bool = false

var player_hp: float = 100.0
var player_max_hp: float = 100.0
var player_energy: float = 100.0

var distance: float = 200.0
var step_count: int = 0
var max_steps: int = 12


## Creates an isolated deep clone of the current combat state.
func clone() -> RefCounted:
	var script: GDScript = get_script()
	var copy = script.new()
	copy.turn = turn
	copy.boss_hp = boss_hp
	copy.boss_max_hp = boss_max_hp
	copy.boss_phase = boss_phase
	copy.slam_cooldown = slam_cooldown
	copy.barrage_cooldown = barrage_cooldown
	copy.charge_cooldown = charge_cooldown
	copy.is_recovering = is_recovering
	copy.recover_timer = recover_timer
	copy.is_guarding = is_guarding
	copy.player_hp = player_hp
	copy.player_max_hp = player_max_hp
	copy.player_energy = player_energy
	copy.distance = distance
	copy.step_count = step_count
	copy.max_steps = max_steps
	return copy


## Checks if the state represents an end condition (victory, defeat, or step limit).
func is_terminal() -> bool:
	if boss_hp <= 0.0 or player_hp <= 0.0:
		return true
	if step_count >= max_steps:
		return true
	return false


## Returns all legal actions for the current actor.
func get_legal_actions() -> Array[String]:
	if is_terminal():
		return []
	if turn == "boss":
		return _get_legal_boss_actions()
	else:
		return _get_legal_player_actions()


func _get_legal_boss_actions() -> Array[String]:
	if is_recovering or recover_timer > 0.0:
		return [ACTION_RECOVER_WAIT]
	
	var actions: Array[String] = []
	
	# 1. Tremor Slam: close-range area shockwave
	if slam_cooldown <= 0.0 and distance <= 145.0:
		actions.append(ACTION_TREMOR_SLAM)
	
	# 2. Plasma Barrage: mid-range projectile starburst
	if barrage_cooldown <= 0.0 and distance <= 360.0:
		actions.append(ACTION_PLASMA_BARRAGE)
		
	# 3. Charge Rush: linear dash across distance
	if charge_cooldown <= 0.0 and distance >= 90.0 and distance <= 320.0:
		actions.append(ACTION_CHARGE_RUSH)
		
	# 4. Pursue Advance: close in on the player
	if distance > 40.0:
		actions.append(ACTION_PURSUE_ADVANCE)
		
	# 5. Tactical Retreat: back up to space out for barrage or charge
	if distance < 380.0:
		actions.append(ACTION_TACTICAL_RETREAT)
		
	# 6. Guard Stance: defensive damage reduction posture
	actions.append(ACTION_GUARD_STANCE)
	
	return actions


func _get_legal_player_actions() -> Array[String]:
	var actions: Array[String] = []
	if player_energy >= 15.0:
		actions.append(ACTION_PLAYER_SHOOT)
	if player_energy >= 20.0:
		actions.append(ACTION_PLAYER_DODGE)
	if distance > 40.0:
		actions.append(ACTION_PLAYER_CLOSE_IN)
	if distance < 450.0:
		actions.append(ACTION_PLAYER_FALL_BACK)
	actions.append(ACTION_PLAYER_REST)
	return actions


## Applies transition rules for the specified action and returns the next CombatState.
func apply_action(action: String) -> RefCounted:
	var next = clone()
	next.step_count += 1
	
	if turn == "boss":
		next._apply_boss_action(action)
		next.turn = "player"
	else:
		next._apply_player_action(action)
		next.turn = "boss"
		
	# Enrage transition at <= 50% max HP
	if next.boss_hp <= (next.boss_max_hp * 0.50) and next.boss_phase == 1:
		next.boss_phase = 2
		
	next.boss_hp = clampf(next.boss_hp, 0.0, next.boss_max_hp)
	next.player_hp = clampf(next.player_hp, 0.0, next.player_max_hp)
	next.player_energy = clampf(next.player_energy, 0.0, 100.0)
	next.distance = clampf(next.distance, 20.0, 500.0)
	return next


func _apply_boss_action(action: String) -> void:
	var tick_time := 0.8
	slam_cooldown = maxf(0.0, slam_cooldown - tick_time)
	barrage_cooldown = maxf(0.0, barrage_cooldown - tick_time)
	charge_cooldown = maxf(0.0, charge_cooldown - tick_time)
	is_guarding = false
	
	match action:
		ACTION_RECOVER_WAIT:
			recover_timer = maxf(0.0, recover_timer - tick_time)
			if recover_timer <= 0.0:
				is_recovering = false
		ACTION_TREMOR_SLAM:
			var dmg := 35.0 if boss_phase == 1 else 45.0
			if distance <= 145.0:
				player_hp -= dmg
			slam_cooldown = 3.5
			is_recovering = true
			recover_timer = 0.8 if boss_phase == 1 else 0.5
		ACTION_PLASMA_BARRAGE:
			var dmg := 24.0 if boss_phase == 1 else 36.0
			var hit_factor := maxf(0.4, 1.0 - (distance / 500.0))
			player_hp -= dmg * hit_factor
			barrage_cooldown = 4.0
			is_recovering = true
			recover_timer = 0.8 if boss_phase == 1 else 0.5
		ACTION_CHARGE_RUSH:
			var dmg := 30.0 if boss_phase == 1 else 40.0
			player_hp -= dmg
			distance = maxf(30.0, distance - 180.0)
			charge_cooldown = 5.0
			is_recovering = true
			recover_timer = 1.2 if boss_phase == 1 else 0.7
		ACTION_PURSUE_ADVANCE:
			var step := 85.0 if boss_phase == 1 else 115.0
			distance = maxf(30.0, distance - step)
		ACTION_TACTICAL_RETREAT:
			distance = minf(450.0, distance + 70.0)
		ACTION_GUARD_STANCE:
			is_guarding = true
			slam_cooldown = maxf(0.0, slam_cooldown - 0.5)
			barrage_cooldown = maxf(0.0, barrage_cooldown - 0.5)
			charge_cooldown = maxf(0.0, charge_cooldown - 0.5)


func _apply_player_action(action: String) -> void:
	match action:
		ACTION_PLAYER_SHOOT:
			var dmg := 18.0
			player_energy = maxf(0.0, player_energy - 15.0)
			if is_guarding:
				dmg *= 0.8 # Guard damage reduction
			elif is_recovering:
				dmg *= 1.25 # Vulnerability counterattack window
			boss_hp -= dmg
		ACTION_PLAYER_DODGE:
			player_energy = maxf(0.0, player_energy - 20.0)
			distance = minf(450.0, distance + 80.0)
		ACTION_PLAYER_CLOSE_IN:
			distance = maxf(30.0, distance - 65.0)
			player_energy = minf(100.0, player_energy + 5.0)
		ACTION_PLAYER_FALL_BACK:
			distance = minf(450.0, distance + 65.0)
			player_energy = minf(100.0, player_energy + 5.0)
		ACTION_PLAYER_REST:
			player_energy = minf(100.0, player_energy + 25.0)


## Heuristic evaluation function from Boss's perspective (MAX player).
## Positive values indicate advantage for the Boss; negative favor the Player.
func evaluate() -> float:
	# 1. Terminal victory / loss states
	if player_hp <= 0.0:
		return 10000.0 - float(step_count * 10)
	if boss_hp <= 0.0:
		return -10000.0 + float(step_count * 10)
		
	var score := 0.0
	
	# 2. Normalized Health Differential (Player HP loss is heavily prioritized)
	var boss_hp_ratio := boss_hp / maxf(1.0, boss_max_hp)
	var player_hp_ratio := player_hp / maxf(1.0, player_max_hp)
	score += (boss_hp_ratio * 250.0) - (player_hp_ratio * 900.0)
	
	# 3. Attack Readiness Bonuses
	if slam_cooldown <= 0.0: score += 25.0
	if barrage_cooldown <= 0.0: score += 20.0
	if charge_cooldown <= 0.0: score += 15.0
	
	# 4. Tactical Distance Alignment
	if distance <= 140.0:
		if slam_cooldown <= 0.0:
			score += 40.0
	elif distance <= 300.0:
		if charge_cooldown <= 0.0 or barrage_cooldown <= 0.0:
			score += 30.0
	else:
		if barrage_cooldown > 0.0:
			score -= 20.0
			
	# 5. Stance & Vulnerability
	if is_recovering: score -= 25.0
	if is_guarding: score += 15.0
	if boss_phase == 2: score += 25.0
	
	var player_energy_ratio := player_energy / 100.0
	score -= (player_energy_ratio * 15.0)
	return score
