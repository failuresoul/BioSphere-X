class_name BossAlphaBetaDecision
extends "res://scenes/boss/decision/boss_decision_module.gd"
## Minimax search with Alpha-Beta pruning for BioSphere-X turn-based combat model.
## Evaluates tactical action sequences up to depth limit with aggressive branch cutoffs.
## Gathers performance statistics including evaluated nodes, pruned branches, and runtime.

const BossCombatStateScript := preload("res://scenes/boss/decision/boss_combat_state.gd")

@export var max_depth: int = 3

var nodes_evaluated: int = 0
var pruned_branches: int = 0
var max_depth_reached: int = 0

const ACTION_PRIORITY: Dictionary = {
	"TREMOR_SLAM": 10,
	"CHARGE_RUSH": 8,
	"PLASMA_BARRAGE": 7,
	"PURSUE_ADVANCE": 5,
	"TACTICAL_RETREAT": 4,
	"GUARD_STANCE": 3,
	"RECOVER_WAIT": 1,
	"PLAYER_SHOOT": 10,
	"PLAYER_DODGE": 7,
	"PLAYER_CLOSE_IN": 5,
	"PLAYER_FALL_BACK": 4,
	"PLAYER_REST": 2,
}


func get_module_name() -> String:
	return "MinimaxAlphaBeta"


func choose_action(context: Dictionary) -> Dictionary:
	var start_usec := Time.get_ticks_usec()
	nodes_evaluated = 0
	pruned_branches = 0
	max_depth_reached = 0
	
	var state = _build_state_from_context(context)
	var legal_actions: Array[String] = state.get_legal_actions()
	
	if legal_actions.is_empty():
		return {
			"action": BossCombatStateScript.ACTION_GUARD_STANCE,
			"score": 0.0,
			"statistics": _build_stats(start_usec, 0.0, legal_actions)
		}
		
	if legal_actions.size() == 1:
		var score: float = state.evaluate()
		return {
			"action": legal_actions[0],
			"score": score,
			"statistics": _build_stats(start_usec, score, legal_actions)
		}
		
	# Move ordering to maximize early alpha-beta cutoffs
	var sorted_actions: Array[String] = _sort_actions(legal_actions)
	
	var alpha := -INF
	var beta := INF
	var best_score := -INF
	var best_action: String = sorted_actions[0]
	var action_scores: Dictionary = {}
	
	for action in sorted_actions:
		var next_state = state.apply_action(action)
		var score: float = _min_value(next_state, 1, alpha, beta)
		action_scores[action] = snappedf(score, 0.01)
		
		if score > best_score:
			best_score = score
			best_action = action
			
		alpha = maxf(alpha, best_score)
		if beta <= alpha:
			pruned_branches += 1
			break
			
	var stats := _build_stats(start_usec, best_score, sorted_actions)
	stats["action_scores"] = action_scores
	
	return {
		"action": best_action,
		"score": snappedf(best_score, 0.01),
		"statistics": stats
	}


func _max_value(state: RefCounted, current_depth: int, alpha: float, beta: float) -> float:
	nodes_evaluated += 1
	if current_depth > max_depth_reached:
		max_depth_reached = current_depth
		
	if current_depth >= max_depth or state.is_terminal():
		return state.evaluate()
		
	var legal_actions: Array[String] = state.get_legal_actions()
	if legal_actions.is_empty():
		return state.evaluate()
		
	var sorted_actions: Array[String] = _sort_actions(legal_actions)
	var v := -INF
	for action in sorted_actions:
		var next_state = state.apply_action(action)
		v = maxf(v, _min_value(next_state, current_depth + 1, alpha, beta))
		if v >= beta:
			pruned_branches += 1
			return v # Beta cutoff
		alpha = maxf(alpha, v)
	return v


func _min_value(state: RefCounted, current_depth: int, alpha: float, beta: float) -> float:
	nodes_evaluated += 1
	if current_depth > max_depth_reached:
		max_depth_reached = current_depth
		
	if current_depth >= max_depth or state.is_terminal():
		return state.evaluate()
		
	var legal_actions: Array[String] = state.get_legal_actions()
	if legal_actions.is_empty():
		return state.evaluate()
		
	var sorted_actions: Array[String] = _sort_actions(legal_actions)
	var v := INF
	for action in sorted_actions:
		var next_state = state.apply_action(action)
		v = minf(v, _max_value(next_state, current_depth + 1, alpha, beta))
		if v <= alpha:
			pruned_branches += 1
			return v # Alpha cutoff
		beta = minf(beta, v)
	return v


func _sort_actions(actions: Array[String]) -> Array[String]:
	var copy: Array[String] = actions.duplicate()
	copy.sort_custom(func(a: String, b: String) -> bool:
		return int(ACTION_PRIORITY.get(a, 0)) > int(ACTION_PRIORITY.get(b, 0))
	)
	return copy


func _build_state_from_context(ctx: Dictionary) -> RefCounted:
	var s = BossCombatStateScript.new()
	s.turn = "boss"
	s.boss_hp = float(ctx.get("boss_hp", 500.0))
	s.boss_max_hp = float(ctx.get("boss_max_hp", 500.0))
	s.boss_phase = int(ctx.get("boss_phase", 1))
	s.slam_cooldown = float(ctx.get("slam_cooldown", 0.0))
	s.barrage_cooldown = float(ctx.get("barrage_cooldown", 0.0))
	s.charge_cooldown = float(ctx.get("charge_cooldown", 0.0))
	s.is_recovering = bool(ctx.get("is_recovering", false))
	s.recover_timer = float(ctx.get("recover_timer", 0.0))
	s.is_guarding = bool(ctx.get("is_guarding", false))
	s.player_hp = float(ctx.get("player_hp", 100.0))
	s.player_max_hp = float(ctx.get("player_max_hp", 100.0))
	s.player_energy = float(ctx.get("player_energy", 100.0))
	s.distance = float(ctx.get("distance", 200.0))
	s.max_steps = max_depth * 2
	return s


func _build_stats(start_usec: int, score: float, legal_actions: Array) -> Dictionary:
	var elapsed_usec := Time.get_ticks_usec() - start_usec
	return {
		"algorithm": "alpha_beta_minimax",
		"nodes_evaluated": nodes_evaluated,
		"pruned_branches": pruned_branches,
		"max_depth_reached": max_depth_reached,
		"configured_depth": max_depth,
		"execution_time_usec": elapsed_usec,
		"execution_time_ms": snappedf(float(elapsed_usec) / 1000.0, 0.001),
		"score": score,
		"legal_actions_count": legal_actions.size()
	}
