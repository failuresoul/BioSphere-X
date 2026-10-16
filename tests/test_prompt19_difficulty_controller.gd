extends Node2D
## Automated Test Suite for Prompt 19 — BioSphere-X Configurable Difficulty Controller.
## Validates observable gameplay signals (player health, recent damage, enemy distance, repeated failures),
## simple rules evaluation, in-engine Mamdani fuzzy inference system with centroid defuzzification,
## strict output boundary clamping, fixed-difficulty modes, repeated failure relief, fairness guarantees,
## and transparent telemetry reporting.

const DifficultyControllerScript := preload("res://scripts/autoloads/difficulty_controller.gd")


func _ready() -> void:
	print("==================================================")
	print("  BIOSPHERE-X: PROMPT 19 DIFFICULTY TESTS")
	print("==================================================")
	
	test_observable_signals_and_tracking()
	test_simple_rules_algorithm()
	test_in_engine_mamdani_fuzzy_system()
	test_strict_output_clamping_and_safe_bounds()
	test_repeated_failures_relief_behavior()
	test_fixed_difficulty_benchmark_modes()
	test_fairness_guarantee_no_cheating()
	test_telemetry_and_transparency()
	
	print("==================================================")
	print("  ALL PROMPT 19 DIFFICULTY TESTS PASSED! [8/8]")
	print("==================================================")
	get_tree().quit(0)


func test_observable_signals_and_tracking() -> void:
	print("[TEST 1/8] Testing observable signals ingestion and tracking...")
	var dc := DifficultyControllerScript.new()
	add_child(dc)
	
	assert(dc.player_health == 100.0, "Initial player health should be 100")
	assert(dc.recent_damage_accumulator == 0.0, "Initial damage accumulator should be 0")
	assert(dc.repeated_failures == 0, "Initial repeated failures should be 0")
	
	# Ingest damage
	dc.record_player_damage(35.0)
	assert(dc.recent_damage_accumulator == 35.0, "Damage accumulator should register 35")
	
	# Ingest failure
	dc.record_failure()
	assert(dc.repeated_failures == 1, "Repeated failures should increment to 1")
	
	# Decay damage over 1.0s (decay rate = 12.0/s)
	dc._process(1.0)
	assert(is_equal_approx(dc.recent_damage_accumulator, 23.0), "Accumulator should decay to 23.0 after 1s")
	
	dc.queue_free()
	print("  -> Observable signals ingestion and time-decay tracking verified.")


func test_simple_rules_algorithm() -> void:
	print("[TEST 2/8] Testing simple rule-based difficulty algorithm...")
	# Case 1: Severe distress relief (Critical health <= 20)
	var res1 := DifficultyControllerScript.evaluate_simple_rules(15.0, 50.0, 100.0, 0)
	assert(res1["aggression"] <= 0.35, "Severe distress should trigger low aggression relief")
	assert(res1["parameters"]["speed_multiplier"] <= 0.90, "Speed multiplier should be reduced")
	assert(res1["parameters"]["attack_cooldown_multiplier"] >= 1.20, "Attack cooldown should be extended")
	
	# Case 2: Repeated failures relief (Failures >= 3)
	var res2 := DifficultyControllerScript.evaluate_simple_rules(80.0, 10.0, 200.0, 3)
	assert(res2["aggression"] <= 0.35, "Repeated failures (>=3) must trigger relief even with high health")
	
	# Case 3: Peak challenge (Health >= 85, low damage <= 10, close distance <= 140, 0 failures)
	var res3 := DifficultyControllerScript.evaluate_simple_rules(95.0, 5.0, 80.0, 0)
	assert(res3["aggression"] >= 0.88, "Dominant uninjured player in close quarters meets peak aggression")
	assert(res3["parameters"]["speed_multiplier"] >= 1.15, "Speed multiplier should be heightened")
	assert(res3["parameters"]["encounter_intensity"] >= 1.25, "Encounter intensity should be heightened")
	
	# Case 4: Baseline
	var res4 := DifficultyControllerScript.evaluate_simple_rules(60.0, 15.0, 300.0, 0)
	assert(is_equal_approx(res4["aggression"], 0.60), "Standard conditions should evaluate to baseline 0.60")
	print("  -> Simple rules algorithm reliably evaluates progressive challenge levels.")


func test_in_engine_mamdani_fuzzy_system() -> void:
	print("[TEST 3/8] Testing in-engine Mamdani fuzzy inference system & centroid defuzzification...")
	# Verify triangular and trapezoidal membership evaluations
	assert(DifficultyControllerScript._triangular(50.0, 25.0, 50.0, 75.0) == 1.0, "Triangular peak should equal 1.0")
	assert(DifficultyControllerScript._triangular(25.0, 25.0, 50.0, 75.0) == 0.0, "Triangular boundary should equal 0.0")
	assert(DifficultyControllerScript._trapezoidal(80.0, 60.0, 80.0, 100.0, 110.0) == 1.0, "Trapezoidal plateau should equal 1.0")
	assert(DifficultyControllerScript._trapezoidal(50.0, 60.0, 80.0, 100.0, 110.0) == 0.0, "Trapezoidal outside should equal 0.0")
	
	# Evaluate Fuzzy: Struggling Player (Low Health 20, High Damage 60, Many Failures 5)
	var fuzzy_distress := DifficultyControllerScript.evaluate_fuzzy(20.0, 60.0, 100.0, 5)
	assert(fuzzy_distress["aggression"] <= 0.35, "Fuzzy system must provide relief to struggling player")
	assert(fuzzy_distress["explanation"] != "", "Fuzzy explanation should contain readable fired rules")
	
	# Evaluate Fuzzy: Thriving Player (High Health 95, Low Damage 0, Close Distance 80, 0 Failures)
	var fuzzy_thriving := DifficultyControllerScript.evaluate_fuzzy(95.0, 0.0, 80.0, 0)
	assert(fuzzy_thriving["aggression"] >= 0.80, "Fuzzy system must challenge thriving player in close quarters")
	
	# Defuzzified values must strictly remain within [0.15, 1.00]
	assert(fuzzy_distress["aggression"] >= 0.15 and fuzzy_distress["aggression"] <= 1.0, "Fuzzy aggression bounded")
	assert(fuzzy_thriving["aggression"] >= 0.15 and fuzzy_thriving["aggression"] <= 1.0, "Fuzzy aggression bounded")
	print("  -> In-engine Mamdani fuzzy inference system and centroid defuzzification operational.")


func test_strict_output_clamping_and_safe_bounds() -> void:
	print("[TEST 4/8] Testing strict output boundary clamping across extreme inputs...")
	var extreme_cases = [
		{"hp": -500.0, "dmg": 999.0, "dist": -200.0, "fail": 99},
		{"hp": 9999.0, "dmg": -50.0, "dist": 5000.0, "fail": -10},
		{"hp": 0.0, "dmg": 0.0, "dist": 0.0, "fail": 0}
	]
	
	for c in extreme_cases:
		var simple_res = DifficultyControllerScript.evaluate_simple_rules(c["hp"], c["dmg"], c["dist"], c["fail"])
		assert(simple_res["aggression"] >= 0.15 and simple_res["aggression"] <= 1.0, "Simple aggression strictly clamped")
		var spd: float = simple_res["parameters"]["speed_multiplier"]
		var dmg: float = simple_res["parameters"]["attack_damage_multiplier"]
		var cd: float = simple_res["parameters"]["attack_cooldown_multiplier"]
		var intensity: float = simple_res["parameters"]["encounter_intensity"]
		assert(spd >= 0.65 and spd <= 1.50, "Speed multiplier strictly clamped")
		assert(dmg >= 0.65 and dmg <= 1.50, "Damage multiplier strictly clamped")
		assert(cd >= 0.60 and cd <= 1.60, "Cooldown multiplier strictly clamped")
		assert(intensity >= 0.50 and intensity <= 1.50, "Intensity multiplier strictly clamped")
		
		var fuzzy_res = DifficultyControllerScript.evaluate_fuzzy(c["hp"], c["dmg"], c["dist"], c["fail"])
		assert(fuzzy_res["aggression"] >= 0.15 and fuzzy_res["aggression"] <= 1.0, "Fuzzy aggression strictly clamped")
	print("  -> All output multipliers and intensity scalars stay strictly within safe ranges.")


func test_repeated_failures_relief_behavior() -> void:
	print("[TEST 5/8] Verifying repeated failures adaptive relief behavior...")
	# Identical combat state: 75 HP, 15 Recent Damage, 150 px distance
	var zero_failures := DifficultyControllerScript.evaluate_fuzzy(75.0, 15.0, 150.0, 0)
	var many_failures := DifficultyControllerScript.evaluate_fuzzy(75.0, 15.0, 150.0, 5)
	
	assert(many_failures["aggression"] < zero_failures["aggression"], "Consecutive failures must reduce enemy aggression")
	assert(many_failures["parameters"]["encounter_intensity"] < zero_failures["parameters"]["encounter_intensity"],
		"Consecutive failures must dial back encounter intensity to prevent player softlock")
	print("  -> Repeated failures provide transparent relief, adapting encounter pacing.")


func test_fixed_difficulty_benchmark_modes() -> void:
	print("[TEST 6/8] Testing fixed-difficulty baseline comparison modes...")
	var dc := DifficultyControllerScript.new()
	add_child(dc)
	
	# Easy Mode
	dc.set_difficulty_mode("easy")
	assert(dc.current_aggression == 0.35, "Easy aggression should be 0.35")
	assert(dc.current_encounter_intensity == 0.88, "Easy intensity should be 0.88")
	assert(dc.current_parameters["speed_multiplier"] == 0.85, "Easy speed mult should be 0.85")
	assert(dc.current_parameters["attack_damage_multiplier"] == 0.80, "Easy damage mult should be 0.80")
	assert(dc.current_parameters["attack_cooldown_multiplier"] == 1.25, "Easy cooldown mult should be 1.25")
	
	# Normal Mode
	dc.set_difficulty_mode("normal")
	assert(dc.current_aggression == 0.60, "Normal aggression should be 0.60")
	assert(dc.current_encounter_intensity == 1.08, "Normal intensity should be 1.08")
	
	# Hard Mode
	dc.set_difficulty_mode("hard")
	assert(dc.current_aggression == 0.85, "Hard aggression should be 0.85")
	assert(dc.current_encounter_intensity == 1.28, "Hard intensity should be 1.28")
	
	# Nightmare Mode
	dc.set_difficulty_mode("nightmare")
	assert(dc.current_aggression == 1.00, "Nightmare aggression should be 1.00")
	assert(dc.current_encounter_intensity == 1.40, "Nightmare intensity should be 1.40")
	assert(dc.current_parameters["speed_multiplier"] == 1.25, "Nightmare speed mult should be 1.25")
	
	dc.queue_free()
	print("  -> Fixed difficulty benchmark modes verified for A/B comparison testing.")


func test_fairness_guarantee_no_cheating() -> void:
	print("[TEST 7/8] Verifying fairness guarantee: no player health modification or fake victory...")
	var gs = get_node_or_null("/root/GameState")
	assert(gs != null, "GameState autoload should exist")
	
	var initial_hp: float = float(gs.get("health"))
	var initial_max_hp: float = float(gs.get("max_health"))
	
	var dc := DifficultyControllerScript.new()
	add_child(dc)
	
	# Cycle through all difficulty modes and evaluations
	var modes = ["adaptive_fuzzy", "adaptive_simple", "easy", "normal", "hard", "nightmare"]
	for m in modes:
		dc.set_difficulty_mode(m)
		dc.evaluate_now()
		
		# Fairness Assertion 1: Player health must NEVER be modified by difficulty controller
		assert(gs.get("health") == initial_hp, "Difficulty controller must NEVER secretly alter player health")
		assert(gs.get("max_health") == initial_max_hp, "Difficulty controller must NEVER alter player max health")
		
		# Fairness Assertion 2: Multipliers only scale enemy behavior and encounter rates
		var params = dc.get_current_multipliers()
		assert(params.has("speed_multiplier"), "Parameters must contain enemy multipliers")
		assert(params.has("attack_damage_multiplier"), "Parameters must contain enemy multipliers")
		assert(not params.has("player_godmode"), "Difficulty system must not give artificial godmode")
		assert(not params.has("instant_victory"), "Difficulty system must not script instant victory")
	
	dc.queue_free()
	print("  -> Fairness verified: Player health is untouched; adjustments transparently modulate enemy behaviors.")


func test_telemetry_and_transparency() -> void:
	print("[TEST 8/8] Testing telemetry and transparency reporting...")
	var dc := DifficultyControllerScript.new()
	add_child(dc)
	
	dc.set_difficulty_mode("adaptive_fuzzy")
	dc.player_health = 45.0
	dc.recent_damage_accumulator = 30.0
	dc.enemy_distance = 160.0
	dc.repeated_failures = 2
	dc.evaluate_now()
	
	var telemetry: Dictionary = dc.get_telemetry()
	assert(telemetry.has("mode"), "Telemetry must report active mode")
	assert(telemetry.has("source"), "Telemetry must report evaluation source")
	assert(telemetry.has("aggression"), "Telemetry must report aggression scalar")
	assert(telemetry.has("encounter_intensity"), "Telemetry must report encounter intensity")
	assert(telemetry.has("parameters"), "Telemetry must report parameters")
	assert(telemetry.has("signals"), "Telemetry must report input signals")
	assert(telemetry.has("explanation"), "Telemetry must report human-readable explanation")
	
	var signals: Dictionary = telemetry["signals"]
	assert(signals["player_health"] == 45.0, "Signals should reflect player health")
	assert(signals["recent_damage"] == 30.0, "Signals should reflect recent damage")
	assert(signals["repeated_failures"] == 2, "Signals should reflect repeated failures")
	
	dc.queue_free()
	print("  -> Telemetry exposes transparent, verifiable explanation of difficulty adjustments.")
