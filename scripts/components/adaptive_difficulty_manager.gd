class_name AdaptiveDifficultyManager
extends RefCounted
## Adaptive Difficulty Manager for BioSphere-X Enemies.
## Interfaces with the Python Fuzzy Logic Inference Backend to modulate combat pressure.
## Tracks player health, rolling recent damage, and distance to regulate enemy aggression.
## Features input validation, logging, fixed-difficulty modes for A/B testing, and safe fallback.

signal difficulty_changed(aggression: float, parameters: Dictionary)

# Fixed difficulty benchmark baselines
const FIXED_PROFILES: Dictionary = {
	"easy": {
		"aggression": 0.35,
		"parameters": {
			"speed_multiplier": 0.85,
			"attack_damage_multiplier": 0.80,
			"attack_cooldown_multiplier": 1.25,
			"detection_range_multiplier": 0.90
		}
	},
	"normal": {
		"aggression": 0.60,
		"parameters": {
			"speed_multiplier": 1.00,
			"attack_damage_multiplier": 1.00,
			"attack_cooldown_multiplier": 1.00,
			"detection_range_multiplier": 1.00
		}
	},
	"hard": {
		"aggression": 0.85,
		"parameters": {
			"speed_multiplier": 1.15,
			"attack_damage_multiplier": 1.15,
			"attack_cooldown_multiplier": 0.85,
			"detection_range_multiplier": 1.12
		}
	},
	"nightmare": {
		"aggression": 1.00,
		"parameters": {
			"speed_multiplier": 1.25,
			"attack_damage_multiplier": 1.25,
			"attack_cooldown_multiplier": 0.75,
			"detection_range_multiplier": 1.20
		}
	}
}

var difficulty_mode: String = "adaptive" # "adaptive", "easy", "normal", "hard", "nightmare"
var current_aggression: float = 0.60
var current_parameters: Dictionary = {
	"speed_multiplier": 1.0,
	"attack_damage_multiplier": 1.0,
	"attack_cooldown_multiplier": 1.0,
	"detection_range_multiplier": 1.0
}

# Rolling recent damage tracker
var _recent_damage_accumulator: float = 0.0
var _recent_damage_decay_rate: float = 12.0 # Decays damage memory by 12 HP per second
var _is_request_pending: bool = false
var _last_logged_aggression: float = -1.0


func update(delta: float) -> void:
	# Gradually decay recent damage accumulation over time
	if _recent_damage_accumulator > 0.0:
		_recent_damage_accumulator = maxf(0.0, _recent_damage_accumulator - (_recent_damage_decay_rate * delta))


## Registers damage sustained by the player to track short-term combat intensity.
func record_player_damage(amount: float) -> void:
	_recent_damage_accumulator = clampf(_recent_damage_accumulator + amount, 0.0, 100.0)


## Evaluates and updates difficulty parameters. Dispatches to Python if in adaptive mode,
## or immediately applies fixed preset if in fixed difficulty mode.
func evaluate_difficulty(enemy: Node2D, player: Node2D, callback: Callable = Callable()) -> void:
	if difficulty_mode in FIXED_PROFILES:
		var profile = FIXED_PROFILES[difficulty_mode]
		_apply_parameters(float(profile["aggression"]), profile["parameters"], "fixed_" + difficulty_mode)
		if callback.is_valid():
			callback.call(current_parameters)
		return

	# Adaptive Mode: Gather real-time context
	var player_hp := 100.0
	if is_instance_valid(player) and "current_health" in player:
		player_hp = float(player.get("current_health"))
	elif is_instance_valid(player) and player.has_node("HealthComponent"):
		player_hp = float(player.get_node("HealthComponent").get("current_health"))

	var dist := 250.0
	if is_instance_valid(enemy) and is_instance_valid(player):
		dist = enemy.global_position.distance_to(player.global_position)

	var inputs := {
		"player_health": clampf(player_hp, 0.0, 100.0),
		"recent_damage": clampf(_recent_damage_accumulator, 0.0, 100.0),
		"enemy_distance": clampf(dist, 0.0, 600.0)
	}

	var ai_node = enemy.get_node_or_null("/root/AIClient") if is_instance_valid(enemy) else null
	if not ai_node or not ai_node.has_method("request_adaptive_difficulty") or _is_request_pending:
		# Offline fallback: evaluate locally
		_apply_local_heuristic(inputs["player_health"], inputs["recent_damage"], inputs["enemy_distance"])
		if callback.is_valid():
			callback.call(current_parameters)
		return

	_is_request_pending = true
	ai_node.call("request_adaptive_difficulty", inputs, difficulty_mode, func(res: Dictionary) -> void:
		_is_request_pending = false
		if res.get("success", false) and "data" in res:
			var data = res["data"]
			var agg: float = float(data.get("enemy_aggression", 0.60))
			var params: Dictionary = data.get("parameters", {})
			_apply_parameters(agg, params, "adaptive_python")
		else:
			# Seamless offline fallback
			_apply_local_heuristic(inputs["player_health"], inputs["recent_damage"], inputs["enemy_distance"])
			
		if callback.is_valid():
			callback.call(current_parameters)
	)


## Local fuzzy heuristic fallback when Python backend is offline or unreachable.
func _apply_local_heuristic(hp: float, dmg: float, dist: float) -> void:
	var base_agg := 0.60
	# Critical player under damage gets relief
	if hp <= 30.0 and dmg >= 40.0:
		base_agg = 0.30
	elif hp <= 30.0:
		base_agg = 0.45
	# Healthy player facing close enemy gets high challenge
	elif hp >= 75.0 and dmg <= 15.0 and dist <= 120.0:
		base_agg = 0.88
	elif hp >= 75.0 and dmg <= 20.0:
		base_agg = 0.75
	elif dmg >= 60.0:
		base_agg = 0.40
		
	var params := calculate_multipliers(base_agg)
	_apply_parameters(base_agg, params, "local_fallback")


func _apply_parameters(aggression: float, params: Dictionary, source_mode: String) -> void:
	current_aggression = clampf(aggression, 0.15, 1.0)
	
	# Strict validation on all multipliers to ensure continuous game stability
	var validated := {
		"speed_multiplier": clampf(float(params.get("speed_multiplier", 1.0)), 0.65, 1.50),
		"attack_damage_multiplier": clampf(float(params.get("attack_damage_multiplier", 1.0)), 0.65, 1.50),
		"attack_cooldown_multiplier": clampf(float(params.get("attack_cooldown_multiplier", 1.0)), 0.60, 1.60),
		"detection_range_multiplier": clampf(float(params.get("detection_range_multiplier", 1.0)), 0.75, 1.40),
		"encounter_intensity": clampf(float(params.get("encounter_intensity", 1.0)), 0.50, 1.50)
	}
	
	current_parameters = validated
	
	# Log adjustments if aggression shifted meaningfully (> 0.05)
	if absf(current_aggression - _last_logged_aggression) >= 0.05:
		_last_logged_aggression = current_aggression
		print("[AdaptiveDifficulty] %s -> Aggression: %.2f (Speed: %.2fx, Dmg: %.2fx, Cooldown: %.2fx)" % [
			source_mode, current_aggression, validated["speed_multiplier"],
			validated["attack_damage_multiplier"], validated["attack_cooldown_multiplier"]
		])
	
	difficulty_changed.emit(current_aggression, current_parameters)


static func calculate_multipliers(aggression: float) -> Dictionary:
	var agg := clampf(aggression, 0.15, 1.0)
	return {
		"speed_multiplier": snappedf(0.75 + (0.50 * agg), 0.01),
		"attack_damage_multiplier": snappedf(0.70 + (0.55 * agg), 0.01),
		"attack_cooldown_multiplier": snappedf(1.40 - (0.65 * agg), 0.01),
		"detection_range_multiplier": snappedf(0.80 + (0.40 * agg), 0.01),
		"encounter_intensity": snappedf(0.60 + (0.80 * agg), 0.01)
	}
