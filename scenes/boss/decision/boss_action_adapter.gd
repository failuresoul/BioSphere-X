class_name BossActionAdapter
extends RefCounted
## Safe Action Adapter connecting abstract turn-based decisions to the real-time BossEnemy controller.
## Validates actions against physical constraints (distance, cooldowns, target validity).
## Provides seamless, safe fallback behavior if the decision module is disabled, missing,
## or returns an illegal/unknown action.

# Known action vocabulary
const VALID_ACTIONS := [
	"TREMOR_SLAM",
	"PLASMA_BARRAGE",
	"CHARGE_RUSH",
	"PURSUE_ADVANCE",
	"TACTICAL_RETREAT",
	"GUARD_STANCE",
	"RECOVER_WAIT"
]


## Validates whether an abstract action can physically and legally be executed by the boss right now.
static func validate_action(boss: CharacterBody2D, action_name: String, dist_to_player: float) -> bool:
	if not is_instance_valid(boss) or not (action_name in VALID_ACTIONS):
		return false
		
	# Real-time state check: boss cannot initiate attacks if recovering or defeated
	var current_state = boss.get("current_state")
	if current_state == 3 or current_state == 5: # State.RECOVER or State.DEFEATED
		return action_name == "RECOVER_WAIT"
		
	# Attack-specific real-time validation
	match action_name:
		"TREMOR_SLAM":
			var slam_cd = boss.get("_slam_cooldown_timer")
			var cd: float = float(slam_cd) if typeof(slam_cd) in [TYPE_FLOAT, TYPE_INT] else 0.0
			var slam_rad = boss.get("slam_radius")
			var rad: float = float(slam_rad) if typeof(slam_rad) in [TYPE_FLOAT, TYPE_INT] else 135.0
			return cd <= 0.0 and dist_to_player <= (rad * 1.15)
			
		"PLASMA_BARRAGE":
			var barrage_cd = boss.get("_barrage_cooldown_timer")
			var cd: float = float(barrage_cd) if typeof(barrage_cd) in [TYPE_FLOAT, TYPE_INT] else 0.0
			return cd <= 0.0 and dist_to_player <= 360.0
			
		"CHARGE_RUSH":
			var charge_cd = boss.get("_charge_cooldown_timer")
			var cd: float = float(charge_cd) if typeof(charge_cd) in [TYPE_FLOAT, TYPE_INT] else 0.0
			var phase = boss.get("current_phase")
			var p_val: int = int(phase) if typeof(phase) in [TYPE_FLOAT, TYPE_INT] else 1
			return cd <= 0.0 and (p_val == 2 or dist_to_player >= 85.0) and dist_to_player <= 350.0
			
		"GUARD_STANCE":
			return true
			
		"TACTICAL_RETREAT", "PURSUE_ADVANCE":
			return true
			
		"RECOVER_WAIT":
			return current_state == 3 # State.RECOVER
			
	return false


## Applies the chosen action to the BossEnemy controller.
## If action is invalid or module is disabled, safely applies local rule fallback without throwing errors.
## Returns true if a validated decision action was applied, or false if safe fallback was used.
static func apply_decision(
	boss: CharacterBody2D,
	decision_result: Dictionary,
	dist_to_player: float,
	delta: float,
	to_player: Vector2,
	is_module_enabled: bool = true
) -> bool:
	if not is_instance_valid(boss):
		return false
		
	var action_name: String = String(decision_result.get("action", ""))
	var is_valid := is_module_enabled and validate_action(boss, action_name, dist_to_player)
	
	if is_valid:
		_execute_validated_action(boss, action_name, delta, to_player, dist_to_player)
		return true
	else:
		# Safe local fallback: guaranteed continuous, responsive gameplay
		_execute_safe_fallback(boss, dist_to_player, delta, to_player)
		return false


static func _execute_validated_action(boss: CharacterBody2D, action_name: String, delta: float, to_player: Vector2, dist: float) -> void:
	match action_name:
		"TREMOR_SLAM":
			boss.set("_chosen_attack", 1) # AttackType.TREMOR_SLAM
			boss.call("change_state", 2) # State.ATTACK
		"PLASMA_BARRAGE":
			boss.set("_chosen_attack", 2) # AttackType.PLASMA_BARRAGE
			boss.call("change_state", 2) # State.ATTACK
		"CHARGE_RUSH":
			boss.set("_chosen_attack", 3) # AttackType.CHARGE_RUSH
			boss.call("change_state", 2) # State.ATTACK
		"GUARD_STANCE":
			if dist > 180.0:
				boss.call("change_state", 0) # State.GUARD
			else:
				_apply_movement(boss, to_player, delta, 1.0)
		"TACTICAL_RETREAT":
			if dist < 180.0:
				_apply_movement(boss, -to_player, delta, 0.75)
			else:
				_apply_movement(boss, to_player, delta, 1.0)
		"PURSUE_ADVANCE":
			_apply_movement(boss, to_player, delta, 1.0)
		"RECOVER_WAIT":
			pass


static func _execute_safe_fallback(boss: CharacterBody2D, dist_to_player: float, delta: float, to_player: Vector2) -> void:
	# Local rule-based attack fallback
	var chosen: int = 0
	if boss.has_method("_evaluate_attack_choice"):
		chosen = int(boss.call("_evaluate_attack_choice", dist_to_player))
		
	if chosen != 0: # AttackType.NONE
		boss.set("_chosen_attack", chosen)
		boss.call("change_state", 2) # State.ATTACK
	else:
		# Standard chase movement toward player
		_apply_movement(boss, to_player, delta, 1.0)


static func _apply_movement(boss: CharacterBody2D, dir: Vector2, delta: float, speed_mult: float) -> void:
	var phase: int = boss.get("current_phase") if "current_phase" in boss else 1
	var normal_speed: float = float(boss.get("normal_chase_speed") if "normal_chase_speed" in boss else 95.0)
	var enraged_speed: float = float(boss.get("enraged_chase_speed") if "enraged_chase_speed" in boss else 135.0)
	var accel: float = float(boss.get("acceleration") if "acceleration" in boss else 750.0)
	
	var base_speed := enraged_speed if phase == 2 else normal_speed
	var target_vel := dir.normalized() * (base_speed * speed_mult)
	boss.velocity = boss.velocity.move_toward(target_vel, accel * delta)
