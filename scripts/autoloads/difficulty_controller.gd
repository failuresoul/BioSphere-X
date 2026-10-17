extends Node
## Central Configurable Difficulty Controller for BioSphere-X.
## Regulates enemy aggression and encounter intensity based on observable gameplay signals:
##   - player_health (0-100)
##   - recent_damage (0-100, decaying over time)
##   - enemy_distance (0-600 px)
##   - repeated_failures (death / failed attempt count)
##
## Implements:
##   1. Simple rule-based step evaluation ("adaptive_simple")
##   2. Pure GDScript Mamdani Fuzzy Inference System with centroid defuzzification ("adaptive_fuzzy")
##   3. Fixed benchmark difficulty modes ("easy", "normal", "hard", "nightmare")
##   4. Async backend evaluation failover via AIClient
##
## Fairness Guarantee:
##   - NEVER secretly modifies player health or grants artificial godmode.
##   - Bounded enemy multipliers strictly govern enemy speeds, damage, cooldowns, detection, and encounter intensity.

signal difficulty_updated(aggression: float, intensity: float, parameters: Dictionary)
signal mode_changed(new_mode: String)

# Mode Identifiers
const MODE_ADAPTIVE_FUZZY: String = "adaptive_fuzzy"
const MODE_ADAPTIVE_SIMPLE: String = "adaptive_simple"
const MODE_EASY: String = "easy"
const MODE_NORMAL: String = "normal"
const MODE_HARD: String = "hard"
const MODE_NIGHTMARE: String = "nightmare"

# Fixed Baseline Benchmark Profiles
const FIXED_PROFILES: Dictionary = {
	"easy": {
		"aggression": 0.35,
		"intensity": 0.88,
		"parameters": {
			"speed_multiplier": 0.85,
			"attack_damage_multiplier": 0.80,
			"attack_cooldown_multiplier": 1.25,
			"detection_range_multiplier": 0.90,
			"encounter_intensity": 0.88
		},
		"description": "Exploration-friendly: lenient enemy reactions, slower strikes, and modest encounter pacing."
	},
	"normal": {
		"aggression": 0.60,
		"intensity": 1.08,
		"parameters": {
			"speed_multiplier": 1.00,
			"attack_damage_multiplier": 1.00,
			"attack_cooldown_multiplier": 1.00,
			"detection_range_multiplier": 1.00,
			"encounter_intensity": 1.08
		},
		"description": "Standard expedition baseline: balanced creature speeds and predictable combat intervals."
	},
	"hard": {
		"aggression": 0.85,
		"intensity": 1.28,
		"parameters": {
			"speed_multiplier": 1.15,
			"attack_damage_multiplier": 1.15,
			"attack_cooldown_multiplier": 0.85,
			"detection_range_multiplier": 1.12,
			"encounter_intensity": 1.28
		},
		"description": "Survival challenge: heightened alien reflexes, shorter attack intervals, and vigilant patrols."
	},
	"nightmare": {
		"aggression": 1.00,
		"intensity": 1.40,
		"parameters": {
			"speed_multiplier": 1.25,
			"attack_damage_multiplier": 1.25,
			"attack_cooldown_multiplier": 0.75,
			"detection_range_multiplier": 1.20,
			"encounter_intensity": 1.40
		},
		"description": "Maximum planetary hostility: relentless alien pursuit with rapid, punishing assaults."
	}
}

# Fuzzy Rule Base Configuration
const FUZZY_RULES: Array[Dictionary] = [
	# Distress & Failure Relief Rules
	{
		"ante": {"health": "critical", "damage": "high"},
		"cons": "passive",
		"weight": 1.0,
		"desc": "Critical health under heavy damage receives relief"
	},
	{
		"ante": {"failures": "many"},
		"cons": "passive",
		"weight": 1.0,
		"desc": "Repeated failures reduce enemy hostility to prevent frustration"
	},
	{
		"ante": {"failures": "some", "health": "critical"},
		"cons": "passive",
		"weight": 1.0,
		"desc": "Consecutive failures with critical health grants substantial breathing room"
	},
	{
		"ante": {"health": "critical", "distance": "close"},
		"cons": "passive",
		"weight": 1.0,
		"desc": "Enemies ease close-quarters pressure when player is critical"
	},
	{
		"ante": {"failures": "some"},
		"cons": "cautious",
		"weight": 0.8,
		"desc": "Moderate failures ease pressure"
	},
	{
		"ante": {"damage": "high"},
		"cons": "cautious",
		"weight": 0.85,
		"desc": "High damage taken dampens aggression"
	},
	# Balanced Pacing Rules
	{
		"ante": {"health": "moderate", "damage": "medium"},
		"cons": "standard",
		"weight": 1.0,
		"desc": "Moderate combat pacing maintains standard engagement"
	},
	{
		"ante": {"health": "moderate", "damage": "low"},
		"cons": "standard",
		"weight": 0.9,
		"desc": "Moderate health with low damage delivers standard challenge"
	},
	# High Skill / Dominant Player Challenge Rules
	{
		"ante": {"health": "healthy", "damage": "low", "distance": "close", "failures": "few"},
		"cons": "furious",
		"weight": 1.0,
		"desc": "Healthy dominant player at close range meets maximum hostility"
	},
	{
		"ante": {"health": "healthy", "damage": "low"},
		"cons": "aggressive",
		"weight": 0.9,
		"desc": "Healthy unharmed player meets high aggression"
	},
	{
		"ante": {"distance": "far", "damage": "low"},
		"cons": "aggressive",
		"weight": 0.75,
		"desc": "Creatures actively press healthy disengaged players"
	}
]

# State Variables
@export var difficulty_mode: String = MODE_ADAPTIVE_FUZZY:
	set(val):
		difficulty_mode = val
		mode_changed.emit(val)

@export var enable_backend_ai: bool = true
@export var damage_decay_rate: float = 12.0 # Decays damage accumulator by 12 HP per second
@export var evaluate_interval: float = 0.5   # Periodic difficulty evaluation cadence

# Observable Signal State
var player_health: float = 100.0
var recent_damage_accumulator: float = 0.0
var enemy_distance: float = 250.0
var repeated_failures: int = 0

# Evaluated Output State
var current_aggression: float = 0.60
var current_encounter_intensity: float = 1.08
var current_parameters: Dictionary = {
	"speed_multiplier": 1.0,
	"attack_damage_multiplier": 1.0,
	"attack_cooldown_multiplier": 1.0,
	"detection_range_multiplier": 1.0,
	"encounter_intensity": 1.0
}
var last_evaluation_source: String = "init"
var last_evaluation_explanation: String = "Initialized to standard baseline."

var _evaluate_timer: float = 0.0
var _is_backend_pending: bool = false
var _last_logged_aggression: float = -1.0

# ---------------------------------------------------------------------------
# Benchmark Performance Metrics & Comparative Session Tracking
# ---------------------------------------------------------------------------
var benchmark_session: Dictionary = {
	"mode": "adaptive_fuzzy",
	"deaths": 0,
	"total_damage_sustained": 0.0,
	"total_damage_dealt": 0.0,
	"missions_completed": 0,
	"missions_failed": 0,
	"aggression_samples": [],
	"aggression_changes_count": 0,
	"min_aggression": 1.0,
	"max_aggression": 0.0,
	"start_time": ""
}
var benchmark_history: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	benchmark_session["start_time"] = Time.get_datetime_string_from_system()
	_sync_signals()
	_connect_event_sources()
	evaluate_now()


func _process(delta: float) -> void:
	# 1. Decay rolling damage accumulator
	if recent_damage_accumulator > 0.0:
		recent_damage_accumulator = maxf(0.0, recent_damage_accumulator - (damage_decay_rate * delta))
	
	# 2. Periodic evaluation timer
	_evaluate_timer -= delta
	if _evaluate_timer <= 0.0:
		_evaluate_timer = evaluate_interval
		_sync_signals()
		evaluate_now()


# ---------------------------------------------------------------------------
# Observable Signal Ingestion & Tracking
# ---------------------------------------------------------------------------
func _sync_signals() -> void:
	var gs = get_node_or_null("/root/GameState")
	if gs:
		player_health = float(gs.get("health"))
		repeated_failures = int(gs.get("failure_count"))
	
	# Sample distance to nearest active player
	var players = get_tree().get_nodes_in_group("player")
	var enemies = get_tree().get_nodes_in_group("enemies")
	if not players.is_empty() and not enemies.is_empty():
		var p: Node2D = players[0] as Node2D
		var min_d := 9999.0
		for e in enemies:
			if is_instance_valid(e) and e is Node2D and e.is_inside_tree() and not e.is_queued_for_deletion():
				var d = (e as Node2D).global_position.distance_to(p.global_position)
				if d < min_d:
					min_d = d
		if min_d < 9000.0:
			enemy_distance = clampf(min_d, 0.0, 600.0)


## Record damage sustained by player to feed short-term combat pressure.
func record_player_damage(amount: float) -> void:
	recent_damage_accumulator = clampf(recent_damage_accumulator + amount, 0.0, 100.0)
	benchmark_session["total_damage_sustained"] = float(benchmark_session["total_damage_sustained"]) + amount


## Record damage dealt by player to enemies.
func record_damage_dealt(amount: float) -> void:
	benchmark_session["total_damage_dealt"] = float(benchmark_session["total_damage_dealt"]) + amount


## Record encounter failure (player eliminated).
func record_failure() -> void:
	repeated_failures += 1
	benchmark_session["deaths"] = int(benchmark_session["deaths"]) + 1
	benchmark_session["missions_failed"] = int(benchmark_session["missions_failed"]) + 1
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.has_method("record_failure"):
		gs.call("record_failure")


## Record mission / expedition objective completion.
func record_mission_completed(_mission_name: String = "") -> void:
	benchmark_session["missions_completed"] = int(benchmark_session["missions_completed"]) + 1


func _connect_event_sources() -> void:
	var gs = get_node_or_null("/root/GameState")
	if gs:
		if gs.has_signal("player_died"):
			gs.player_died.connect(func():
				record_failure()
			)
		if gs.has_signal("player_damaged"):
			gs.player_damaged.connect(func(dmg):
				record_player_damage(float(dmg))
			)

	var mm = get_node_or_null("/root/MissionManager")
	if mm:
		if mm.has_signal("mission_completed"):
			mm.mission_completed.connect(func(_m, _r):
				record_mission_completed()
			)
		if mm.has_signal("mission_failed"):
			mm.mission_failed.connect(func(_m, _r):
				benchmark_session["missions_failed"] = int(benchmark_session["missions_failed"]) + 1
			)


# ---------------------------------------------------------------------------
# Evaluation Pipeline
# ---------------------------------------------------------------------------
func evaluate_now(callback: Callable = Callable()) -> void:
	# 1. Check fixed baseline profiles
	if difficulty_mode in FIXED_PROFILES:
		var profile: Dictionary = FIXED_PROFILES[difficulty_mode]
		_apply_evaluation(
			float(profile["aggression"]),
			profile["parameters"],
			"fixed_" + difficulty_mode,
			profile["description"]
		)
		if callback.is_valid():
			callback.call(current_parameters)
		return
	
	# 2. Simple Rule-Based Mode
	if difficulty_mode == MODE_ADAPTIVE_SIMPLE:
		var res: Dictionary = evaluate_simple_rules(player_health, recent_damage_accumulator, enemy_distance, repeated_failures)
		_apply_evaluation(res["aggression"], res["parameters"], "adaptive_simple", res["explanation"])
		if callback.is_valid():
			callback.call(current_parameters)
		return
	
	# 3. Adaptive Fuzzy Mode: Optional backend evaluation with in-engine fallback
	var ai_client = get_node_or_null("/root/AIClient")
	if enable_backend_ai and ai_client and ai_client.has_method("request_adaptive_difficulty") and not _is_backend_pending:
		_is_backend_pending = true
		var inputs := {
			"player_health": player_health,
			"recent_damage": recent_damage_accumulator,
			"enemy_distance": enemy_distance,
			"repeated_failures": float(repeated_failures)
		}
		ai_client.call("request_adaptive_difficulty", inputs, difficulty_mode, func(res: Dictionary) -> void:
			_is_backend_pending = false
			if res.get("success", false) and "data" in res:
				var data = res["data"]
				var agg: float = float(data.get("enemy_aggression", 0.60))
				var params: Dictionary = data.get("parameters", {})
				_apply_evaluation(agg, params, "backend_python_fuzzy", "Evaluated via Python Mamdani Fuzzy Backend.")
			else:
				# In-engine fuzzy fallback
				var in_engine = evaluate_fuzzy(player_health, recent_damage_accumulator, enemy_distance, repeated_failures)
				_apply_evaluation(in_engine["aggression"], in_engine["parameters"], "in_engine_fuzzy", in_engine["explanation"])
			
			if callback.is_valid():
				callback.call(current_parameters)
		)
		return
	
	# Standard in-engine Fuzzy Inference System
	var in_engine = evaluate_fuzzy(player_health, recent_damage_accumulator, enemy_distance, repeated_failures)
	_apply_evaluation(in_engine["aggression"], in_engine["parameters"], "in_engine_fuzzy", in_engine["explanation"])
	if callback.is_valid():
		callback.call(current_parameters)


# ---------------------------------------------------------------------------
# Simple Rules Algorithm
# ---------------------------------------------------------------------------
static func evaluate_simple_rules(hp: float, dmg: float, dist: float, failures: int) -> Dictionary:
	var agg: float = 0.60
	var explanation: String = ""
	
	# Rule 1: High distress or repeated failures -> Relief
	if failures >= 3 or hp <= 20.0 or (hp <= 35.0 and dmg >= 35.0):
		agg = 0.28
		explanation = "Simple Rule [Distress Relief]: Critical health or >= 3 failures triggered enemy aggression reduction."
	# Rule 2: Heavy damage strain or repeated failures -> Cautious
	elif hp <= 40.0 or dmg >= 45.0 or failures >= 2:
		agg = 0.42
		explanation = "Simple Rule [Caution]: Player under combat strain; enemy aggression dialed down."
	# Rule 3: Dominant healthy player in close proximity -> High challenge
	elif hp >= 85.0 and dmg <= 10.0 and dist <= 140.0 and failures == 0:
		agg = 0.90
		explanation = "Simple Rule [Peak Challenge]: Healthy uninjured player in close quarters met with high aggression."
	# Rule 4: Healthy player -> Elevated pressure
	elif hp >= 75.0 and dmg <= 20.0:
		agg = 0.75
		explanation = "Simple Rule [Pressure]: Healthy player engaged with standard heightened pressure."
	# Rule 5: Default baseline
	else:
		agg = 0.60
		explanation = "Simple Rule [Baseline]: Standard balanced parameters."
	
	agg = clampf(agg, 0.15, 1.0)
	var params := calculate_multipliers(agg)
	return {
		"aggression": agg,
		"parameters": params,
		"explanation": explanation
	}


# ---------------------------------------------------------------------------
# In-Engine Mamdani Fuzzy Inference System
# ---------------------------------------------------------------------------
static func evaluate_fuzzy(hp: float, dmg: float, dist: float, failures: int) -> Dictionary:
	# 1. Fuzzification
	var mu_hp := {
		"critical": _trapezoidal(hp, -10.0, 0.0, 25.0, 45.0),
		"moderate": _triangular(hp, 30.0, 50.0, 75.0),
		"healthy": _trapezoidal(hp, 60.0, 80.0, 100.0, 110.0)
	}
	var mu_dmg := {
		"low": _trapezoidal(dmg, -10.0, 0.0, 15.0, 30.0),
		"medium": _triangular(dmg, 20.0, 45.0, 70.0),
		"high": _trapezoidal(dmg, 35.0, 55.0, 100.0, 110.0)
	}
	var mu_dist := {
		"close": _trapezoidal(dist, -10.0, 0.0, 90.0, 170.0),
		"medium": _triangular(dist, 130.0, 260.0, 400.0),
		"far": _trapezoidal(dist, 340.0, 460.0, 600.0, 650.0)
	}
	var mu_fail := {
		"few": _trapezoidal(float(failures), -1.0, 0.0, 1.0, 2.5),
		"some": _triangular(float(failures), 1.5, 3.0, 4.5),
		"many": _trapezoidal(float(failures), 3.0, 5.0, 10.0, 15.0)
	}
	
	# 2. Rule Evaluation with Min T-Norm
	var activations: Dictionary = {
		"passive": 0.0,
		"cautious": 0.0,
		"standard": 0.0,
		"aggressive": 0.0,
		"furious": 0.0
	}
	var firing_descriptions: Array[String] = []
	
	for rule in FUZZY_RULES:
		var ante: Dictionary = rule["ante"]
		var cons: String = rule["cons"]
		var weight: float = float(rule["weight"])
		
		var degs: Array[float] = []
		if ante.has("health"): degs.append(mu_hp.get(ante["health"], 0.0))
		if ante.has("damage"): degs.append(mu_dmg.get(ante["damage"], 0.0))
		if ante.has("distance"): degs.append(mu_dist.get(ante["distance"], 0.0))
		if ante.has("failures"): degs.append(mu_fail.get(ante["failures"], 0.0))
		
		var strength: float = 1.0
		for d in degs:
			strength = minf(strength, d)
		strength = strength * weight
		
		if strength > 0.0:
			activations[cons] = maxf(activations[cons], strength)
			firing_descriptions.append("%s (%.2f)" % [rule.get("desc", cons), strength])
	
	# 3. Centroid Defuzzification
	var numerator := 0.0
	var denominator := 0.0
	var samples := 85
	var z_min := 0.15
	var z_max := 1.00
	var step := (z_max - z_min) / float(samples - 1)
	
	for i in samples:
		var z := z_min + (float(i) * step)
		var mu_z := 0.0
		
		# Consequent term membership evaluation
		var m_passive := _trapezoidal(z, 0.05, 0.15, 0.25, 0.40)
		var m_cautious := _triangular(z, 0.30, 0.45, 0.60)
		var m_standard := _triangular(z, 0.50, 0.65, 0.80)
		var m_aggressive := _triangular(z, 0.70, 0.85, 0.95)
		var m_furious := _trapezoidal(z, 0.85, 0.95, 1.00, 1.05)
		
		mu_z = maxf(mu_z, minf(activations["passive"], m_passive))
		mu_z = maxf(mu_z, minf(activations["cautious"], m_cautious))
		mu_z = maxf(mu_z, minf(activations["standard"], m_standard))
		mu_z = maxf(mu_z, minf(activations["aggressive"], m_aggressive))
		mu_z = maxf(mu_z, minf(activations["furious"], m_furious))
		
		numerator += z * mu_z
		denominator += mu_z
	
	var defuzz_agg := 0.60
	if denominator > 1e-5:
		defuzz_agg = numerator / denominator
	
	defuzz_agg = clampf(defuzz_agg, 0.15, 1.00)
	var params := calculate_multipliers(defuzz_agg)
	var explanation := "Fuzzy Rules Fired: " + (", ".join(firing_descriptions) if not firing_descriptions.is_empty() else "Standard Baseline")
	
	return {
		"aggression": snappedf(defuzz_agg, 0.01),
		"parameters": params,
		"explanation": explanation
	}


# ---------------------------------------------------------------------------
# Membership Functions
# ---------------------------------------------------------------------------
static func _triangular(x: float, a: float, b: float, c: float) -> float:
	if x <= a or x >= c:
		return 0.0
	elif x == b:
		return 1.0
	elif x < b:
		return (x - a) / (b - a)
	else:
		return (c - x) / (c - b)


static func _trapezoidal(x: float, a: float, b: float, c: float, d: float) -> float:
	if x <= a or x >= d:
		return 0.0
	elif x >= b and x <= c:
		return 1.0
	elif x < b:
		return (x - a) / (b - a) if b > a else 1.0
	else:
		return (d - x) / (d - c) if d > c else 1.0


# ---------------------------------------------------------------------------
# Multiplier Calculation & Boundary Clamping
# ---------------------------------------------------------------------------
static func calculate_multipliers(aggression: float) -> Dictionary:
	var agg := clampf(aggression, 0.15, 1.0)
	var intensity := snappedf(0.60 + (0.80 * agg), 0.01)
	
	return {
		"speed_multiplier": clampf(snappedf(0.75 + (0.50 * agg), 0.01), 0.65, 1.50),
		"attack_damage_multiplier": clampf(snappedf(0.70 + (0.55 * agg), 0.01), 0.65, 1.50),
		"attack_cooldown_multiplier": clampf(snappedf(1.40 - (0.65 * agg), 0.01), 0.60, 1.60),
		"detection_range_multiplier": clampf(snappedf(0.80 + (0.40 * agg), 0.01), 0.75, 1.40),
		"encounter_intensity": clampf(intensity, 0.50, 1.50)
	}


func _apply_evaluation(aggression: float, params: Dictionary, source: String, explanation: String) -> void:
	current_aggression = clampf(aggression, 0.15, 1.0)
	
	var validated := {
		"speed_multiplier": clampf(float(params.get("speed_multiplier", 1.0)), 0.65, 1.50),
		"attack_damage_multiplier": clampf(float(params.get("attack_damage_multiplier", 1.0)), 0.65, 1.50),
		"attack_cooldown_multiplier": clampf(float(params.get("attack_cooldown_multiplier", 1.0)), 0.60, 1.60),
		"detection_range_multiplier": clampf(float(params.get("detection_range_multiplier", 1.0)), 0.75, 1.40),
		"encounter_intensity": clampf(float(params.get("encounter_intensity", 1.0)), 0.50, 1.50)
	}
	current_parameters = validated
	current_encounter_intensity = validated["encounter_intensity"]
	last_evaluation_source = source
	last_evaluation_explanation = explanation
	
	# Transparent console logging upon notable shifts
	# Track aggression dynamics in benchmark session
	var samples: Array = benchmark_session["aggression_samples"]
	if samples.is_empty():
		benchmark_session["aggression_changes_count"] = int(benchmark_session["aggression_changes_count"]) + 1
	elif absf(current_aggression - float(samples[-1].get("aggression", current_aggression))) >= 0.02:
		benchmark_session["aggression_changes_count"] = int(benchmark_session["aggression_changes_count"]) + 1

	benchmark_session["min_aggression"] = minf(float(benchmark_session["min_aggression"]), current_aggression)
	benchmark_session["max_aggression"] = maxf(float(benchmark_session["max_aggression"]), current_aggression)
	samples.append({
		"time_ms": Time.get_ticks_msec(),
		"aggression": current_aggression,
		"intensity": current_encounter_intensity,
		"health": player_health,
		"damage": recent_damage_accumulator
	})
	if samples.size() > 100:
		samples.pop_front()

	difficulty_updated.emit(current_aggression, current_encounter_intensity, current_parameters)


# ---------------------------------------------------------------------------
# Public Telemetry & Control API
# ---------------------------------------------------------------------------
func set_difficulty_mode(mode: String) -> void:
	if mode != difficulty_mode:
		reset_benchmark_session(mode)
	difficulty_mode = mode
	evaluate_now()


func get_current_multipliers() -> Dictionary:
	return current_parameters


func get_encounter_intensity() -> float:
	return current_encounter_intensity


func get_telemetry() -> Dictionary:
	return {
		"mode": difficulty_mode,
		"source": last_evaluation_source,
		"aggression": current_aggression,
		"encounter_intensity": current_encounter_intensity,
		"parameters": current_parameters,
		"signals": {
			"player_health": player_health,
			"recent_damage": recent_damage_accumulator,
			"enemy_distance": enemy_distance,
			"repeated_failures": repeated_failures
		},
		"explanation": last_evaluation_explanation,
		"benchmark": get_benchmark_metrics()
	}


# ---------------------------------------------------------------------------
# Benchmark & Comparative Analysis Methods
# ---------------------------------------------------------------------------
func get_benchmark_metrics() -> Dictionary:
	var deaths: int = int(benchmark_session.get("deaths", 0))
	var m_comp: int = int(benchmark_session.get("missions_completed", 0))
	var m_fail: int = int(benchmark_session.get("missions_failed", 0))
	var total_m: int = m_comp + m_fail
	var comp_rate: float = (float(m_comp) / float(maxi(1, total_m))) * 100.0 if total_m > 0 else 0.0

	var samples: Array = benchmark_session.get("aggression_samples", [])
	var avg_agg: float = current_aggression
	if not samples.is_empty():
		var sum_a: float = 0.0
		for s in samples:
			sum_a += float(s.get("aggression", 0.60))
		avg_agg = sum_a / float(samples.size())

	var min_a: float = float(benchmark_session.get("min_aggression", current_aggression))
	var max_a: float = float(benchmark_session.get("max_aggression", current_aggression))
	if min_a > max_a:
		min_a = current_aggression
		max_a = current_aggression

	return {
		"mode": difficulty_mode,
		"deaths": deaths,
		"damage_sustained": snappedf(float(benchmark_session.get("total_damage_sustained", 0.0)), 0.1),
		"damage_dealt": snappedf(float(benchmark_session.get("total_damage_dealt", 0.0)), 0.1),
		"missions_completed": m_comp,
		"missions_failed": m_fail,
		"total_missions": total_m,
		"completion_rate_pct": snappedf(comp_rate, 0.1),
		"aggression_changes_count": int(benchmark_session.get("aggression_changes_count", 0)),
		"min_aggression": snappedf(min_a, 0.02),
		"max_aggression": snappedf(max_a, 0.02),
		"avg_aggression": snappedf(avg_agg, 0.02),
		"current_aggression": snappedf(current_aggression, 0.02)
	}


func reset_benchmark_session(new_mode: String = "") -> void:
	if not benchmark_session.is_empty() and (int(benchmark_session.get("deaths", 0)) > 0 or int(benchmark_session.get("missions_completed", 0)) > 0):
		benchmark_history.append(benchmark_session.duplicate(true))

	var target_mode: String = new_mode if not new_mode.is_empty() else difficulty_mode
	benchmark_session = {
		"mode": target_mode,
		"deaths": 0,
		"total_damage_sustained": 0.0,
		"total_damage_dealt": 0.0,
		"missions_completed": 0,
		"missions_failed": 0,
		"aggression_samples": [],
		"aggression_changes_count": 0,
		"min_aggression": 1.0,
		"max_aggression": 0.0,
		"start_time": Time.get_datetime_string_from_system()
	}


## Simulates a controlled encounter sequence to test comparative metrics between controllers.
func simulate_encounter_scenario(mode: String, profile: String, steps: int = 20) -> Dictionary:
	var saved_mode: String = difficulty_mode
	var saved_hp: float = player_health
	var saved_dmg: float = recent_damage_accumulator
	var saved_dist: float = enemy_distance
	var saved_fails: int = repeated_failures

	difficulty_mode = mode

	var deaths: int = 0
	var damage_sustained: float = 0.0
	var damage_dealt: float = 0.0
	var sim_hp: float = 100.0
	var sim_dmg_accum: float = 0.0
	var sim_fails: int = 0
	var agg_history: Array[float] = []

	for s in range(steps):
		var incoming_threat: float = 0.0
		var outgoing_damage: float = 0.0
		var current_dist: float = 200.0

		match profile:
			"struggling":
				incoming_threat = 24.0 if (s % 3 == 0) else 14.0
				outgoing_damage = 8.0
				current_dist = 110.0
			"dominant":
				incoming_threat = 4.0 if (s % 4 == 0) else 0.0
				outgoing_damage = 28.0
				current_dist = 180.0
			"variable":
				incoming_threat = 22.0 if (s < 10 and s % 2 == 0) else (4.0 if s >= 10 else 0.0)
				outgoing_damage = 18.0
				current_dist = 140.0 if s < 10 else 320.0

		var cur_agg: float = 0.60
		var multipliers: Dictionary = {}

		if mode in FIXED_PROFILES:
			var p: Dictionary = FIXED_PROFILES[mode]
			cur_agg = float(p["aggression"])
			multipliers = p["parameters"]
		else:
			var in_engine = evaluate_fuzzy(sim_hp, sim_dmg_accum, current_dist, sim_fails)
			cur_agg = float(in_engine["aggression"])
			multipliers = in_engine["parameters"]

		agg_history.append(cur_agg)

		var dmg_mult: float = float(multipliers.get("attack_damage_multiplier", 1.0))
		var cd_mult: float = float(multipliers.get("attack_cooldown_multiplier", 1.0))
		var actual_incoming: float = incoming_threat * dmg_mult * (1.0 / maxf(0.5, cd_mult))

		sim_hp -= actual_incoming
		damage_sustained += actual_incoming
		damage_dealt += outgoing_damage
		sim_dmg_accum = clampf(sim_dmg_accum + actual_incoming - 5.0, 0.0, 100.0)

		if sim_hp <= 0.0:
			deaths += 1
			sim_fails += 1
			sim_hp = 50.0
			sim_dmg_accum = 40.0

	var mission_completed: bool = (deaths < 2 and damage_dealt >= float(steps) * 10.0)

	var min_a: float = 1.0
	var max_a: float = 0.0
	var sum_a: float = 0.0
	var changes: int = 0
	for i in agg_history.size():
		var a: float = agg_history[i]
		min_a = minf(min_a, a)
		max_a = maxf(max_a, a)
		sum_a += a
		if i > 0 and absf(a - agg_history[i - 1]) >= 0.02:
			changes += 1

	var res: Dictionary = {
		"mode": mode,
		"profile": profile,
		"steps": steps,
		"deaths": deaths,
		"damage_sustained": snappedf(damage_sustained, 0.1),
		"damage_dealt": snappedf(damage_dealt, 0.1),
		"mission_completed": mission_completed,
		"aggression_history": agg_history,
		"aggression_changes_count": changes,
		"min_aggression": snappedf(min_a, 0.02),
		"max_aggression": snappedf(max_a, 0.02),
		"avg_aggression": snappedf(sum_a / float(maxi(1, agg_history.size())), 0.02)
	}

	difficulty_mode = saved_mode
	player_health = saved_hp
	recent_damage_accumulator = saved_dmg
	enemy_distance = saved_dist
	repeated_failures = saved_fails

	return res


## Runs a comprehensive multi-profile comparison comparing Adaptive Fuzzy vs Fixed Normal vs Fixed Hard.
func run_full_benchmark_comparison() -> Dictionary:
	var modes: Array[String] = [MODE_ADAPTIVE_FUZZY, MODE_NORMAL, MODE_HARD]
	var profiles: Array[String] = ["struggling", "dominant", "variable"]
	var results: Dictionary = {}

	for m in modes:
		results[m] = {}
		for p in profiles:
			results[m][p] = simulate_encounter_scenario(m, p, 20)

	return results


func export_benchmark_report_json() -> String:
	var data := {
		"timestamp": Time.get_datetime_string_from_system(),
		"current_session": get_benchmark_metrics(),
		"full_comparison_matrix": run_full_benchmark_comparison(),
		"history": benchmark_history
	}
	var json_str := JSON.stringify(data, "\t")
	var dir_path := "user://experiments"
	DirAccess.make_dir_absolute(dir_path)
	var timestamp := Time.get_datetime_string_from_system().replace(":", "-")
	var file_path := "%s/difficulty_benchmark_%s.json" % [dir_path, timestamp]
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(json_str)
		file.close()
		return file_path
	return ""


func export_benchmark_report_csv() -> String:
	var dir_path := "user://experiments"
	DirAccess.make_dir_absolute(dir_path)
	var timestamp := Time.get_datetime_string_from_system().replace(":", "-")
	var file_path := "%s/difficulty_benchmark_%s.csv" % [dir_path, timestamp]
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		return ""

	var headers := [
		"ControllerMode", "PlayerProfile", "Deaths", "DamageSustained", "DamageDealt",
		"MissionCompleted", "AggressionChangesCount", "MinAggression", "MaxAggression", "AvgAggression"
	]
	file.store_line(",".join(headers))

	var matrix := run_full_benchmark_comparison()
	for m in matrix.keys():
		for p in matrix[m].keys():
			var r: Dictionary = matrix[m][p]
			var row := [
				str(m),
				str(p),
				str(r.get("deaths", 0)),
				str(r.get("damage_sustained", 0.0)),
				str(r.get("damage_dealt", 0.0)),
				str(r.get("mission_completed", false)),
				str(r.get("aggression_changes_count", 0)),
				str(r.get("min_aggression", 0.0)),
				str(r.get("max_aggression", 0.0)),
				str(r.get("avg_aggression", 0.0))
			]
			file.store_line(",".join(row))

	file.close()
	return file_path
