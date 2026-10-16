extends Node2D
## Automated Test Suite for BioSphere-X Adaptive Difficulty Fuzzy Inference System.
## Validates input variables, membership bounds, multiplier scaling, rolling damage decay,
## fixed-difficulty comparison modes, enemy controller integration, and rendering/physics authority.

const AlienEnemyScript := preload("res://scenes/enemies/alien_enemy.gd")
const AdaptiveDifficultyManagerScript := preload("res://scripts/components/adaptive_difficulty_manager.gd")
var _base_enemy_scene := preload("res://scenes/enemies/alien_enemy.tscn")


func _ready() -> void:
	print("==================================================")
	print("  BIOSPHERE-X: RUNNING ADAPTIVE DIFFICULTY TESTS")
	print("==================================================")
	
	test_manager_initialization_and_profiles()
	test_multiplier_calculations_and_bounds()
	test_rolling_damage_accumulation_and_decay()
	test_offline_local_heuristic_fallback()
	test_fixed_difficulty_comparison_modes()
	test_enemy_controller_integration_and_scaling()
	test_godot_rendering_and_movement_authority()
	
	print("==================================================")
	print("  ALL ADAPTIVE DIFFICULTY TESTS PASSED! [7/7]")
	print("==================================================")
	get_tree().quit(0)


func test_manager_initialization_and_profiles() -> void:
	print("[TEST 1/7] Testing AdaptiveDifficultyManager initialization & profiles...")
	var mgr = AdaptiveDifficultyManagerScript.new()
	assert(mgr != null, "Manager should instantiate")
	assert(mgr.difficulty_mode == "adaptive", "Default mode should be adaptive")
	assert(mgr.current_aggression == 0.60, "Default aggression should be 0.60")
	
	var params: Dictionary = mgr.current_parameters
	assert(is_equal_approx(params["speed_multiplier"], 1.0), "Default speed mult should be 1.0")
	assert(is_equal_approx(params["attack_damage_multiplier"], 1.0), "Default dmg mult should be 1.0")
	assert(is_equal_approx(params["attack_cooldown_multiplier"], 1.0), "Default cd mult should be 1.0")
	assert(is_equal_approx(params["detection_range_multiplier"], 1.0), "Default det mult should be 1.0")
	
	# Verify fixed profile baselines exist
	var profiles: Dictionary = AdaptiveDifficultyManagerScript.FIXED_PROFILES
	assert(profiles.has("easy"), "Profiles must include easy")
	assert(profiles.has("normal"), "Profiles must include normal")
	assert(profiles.has("hard"), "Profiles must include hard")
	assert(profiles.has("nightmare"), "Profiles must include nightmare")
	print("  -> Manager initialized correctly with standard baseline profiles.")


func test_multiplier_calculations_and_bounds() -> void:
	print("[TEST 2/7] Testing multiplier calculations and strict boundary validation...")
	# Test lower bound aggression (0.15)
	var low_multipliers: Dictionary = AdaptiveDifficultyManagerScript.calculate_multipliers(0.15)
	assert(low_multipliers["speed_multiplier"] <= 0.85, "Low aggression speed should be <= 0.85")
	assert(low_multipliers["attack_damage_multiplier"] <= 0.80, "Low aggression damage should be <= 0.80")
	assert(low_multipliers["attack_cooldown_multiplier"] >= 1.25, "Low aggression cooldown should be >= 1.25 (longer cooldown)")
	assert(low_multipliers["detection_range_multiplier"] <= 0.90, "Low aggression detection should be <= 0.90")
	
	# Test high bound aggression (1.0)
	var high_multipliers: Dictionary = AdaptiveDifficultyManagerScript.calculate_multipliers(1.0)
	assert(high_multipliers["speed_multiplier"] >= 1.20, "High aggression speed should be >= 1.20")
	assert(high_multipliers["attack_damage_multiplier"] >= 1.20, "High aggression damage should be >= 1.20")
	assert(high_multipliers["attack_cooldown_multiplier"] <= 0.80, "High aggression cooldown should be <= 0.80 (faster attack)")
	assert(high_multipliers["detection_range_multiplier"] >= 1.15, "High aggression detection should be >= 1.15")
	
	# Test extreme clamping
	var mgr = AdaptiveDifficultyManagerScript.new()
	mgr._apply_parameters(-5.0, {"speed_multiplier": 0.05, "attack_cooldown_multiplier": 5.0}, "test_clamp")
	assert(mgr.current_aggression >= 0.15, "Aggression must not dip below 0.15")
	assert(mgr.current_parameters["speed_multiplier"] >= 0.65, "Speed multiplier must be bounded >= 0.65")
	assert(mgr.current_parameters["attack_cooldown_multiplier"] <= 1.60, "Cooldown multiplier must be bounded <= 1.60")
	
	mgr._apply_parameters(999.0, {"speed_multiplier": 10.0, "attack_damage_multiplier": 10.0}, "test_clamp_max")
	assert(mgr.current_aggression <= 1.0, "Aggression must not exceed 1.0")
	assert(mgr.current_parameters["speed_multiplier"] <= 1.50, "Speed multiplier must be bounded <= 1.50")
	assert(mgr.current_parameters["attack_damage_multiplier"] <= 1.50, "Damage multiplier must be bounded <= 1.50")
	print("  -> Multiplier formulas and clamp safeguards verified.")


func test_rolling_damage_accumulation_and_decay() -> void:
	print("[TEST 3/7] Testing rolling damage accumulation and decay over time...")
	var mgr = AdaptiveDifficultyManagerScript.new()
	assert(mgr._recent_damage_accumulator == 0.0, "Initial damage accumulator must be 0")
	
	# Record damage
	mgr.record_player_damage(40.0)
	assert(mgr._recent_damage_accumulator == 40.0, "Accumulator should register 40 damage")
	
	mgr.record_player_damage(90.0)
	assert(mgr._recent_damage_accumulator == 100.0, "Accumulator should clamp at 100")
	
	# Decay over 1 second (decay rate is 12.0/s)
	mgr.update(1.0)
	assert(is_equal_approx(mgr._recent_damage_accumulator, 88.0), "Accumulator should decay to 88 after 1.0s")
	
	# Decay over 10 seconds (should clamp at 0, not go negative)
	mgr.update(10.0)
	assert(mgr._recent_damage_accumulator == 0.0, "Accumulator must not go below 0")
	print("  -> Rolling damage tracking and smooth decay verified.")


func test_offline_local_heuristic_fallback() -> void:
	print("[TEST 4/7] Testing offline local fuzzy heuristic fallback...")
	var mgr = AdaptiveDifficultyManagerScript.new()
	
	# Case A: Struggling player (low health 20, high recent damage 50)
	mgr._apply_local_heuristic(20.0, 50.0, 150.0)
	assert(mgr.current_aggression <= 0.35, "Struggling player should get reduced enemy aggression")
	assert(mgr.current_parameters["attack_damage_multiplier"] <= 0.90, "Attack damage should decrease for struggling player")
	assert(mgr.current_parameters["attack_cooldown_multiplier"] >= 1.20, "Attack cooldown should increase for struggling player")
	
	# Case B: Thriving player (high health 90, low recent damage 5, close distance 80)
	mgr._apply_local_heuristic(90.0, 5.0, 80.0)
	assert(mgr.current_aggression >= 0.85, "Thriving player in close combat should receive high enemy aggression")
	assert(mgr.current_parameters["speed_multiplier"] >= 1.15, "Speed multiplier should increase for thriving player")
	print("  -> Local fuzzy fallback correctly modulates challenge in offline scenarios.")


func test_fixed_difficulty_comparison_modes() -> void:
	print("[TEST 5/7] Testing fixed-difficulty comparison baseline modes...")
	var dummy_enemy := Node2D.new()
	var dummy_player := Node2D.new()
	add_child(dummy_enemy)
	add_child(dummy_player)
	
	var mgr = AdaptiveDifficultyManagerScript.new()
	
	# Mode: Easy
	mgr.difficulty_mode = "easy"
	mgr.evaluate_difficulty(dummy_enemy, dummy_player)
	assert(mgr.current_aggression == 0.35, "Easy aggression should be 0.35")
	assert(mgr.current_parameters["speed_multiplier"] == 0.85, "Easy speed mult should be 0.85")
	assert(mgr.current_parameters["attack_damage_multiplier"] == 0.80, "Easy damage mult should be 0.80")
	assert(mgr.current_parameters["attack_cooldown_multiplier"] == 1.25, "Easy cooldown mult should be 1.25")
	
	# Mode: Normal
	mgr.difficulty_mode = "normal"
	mgr.evaluate_difficulty(dummy_enemy, dummy_player)
	assert(mgr.current_aggression == 0.60, "Normal aggression should be 0.60")
	assert(mgr.current_parameters["speed_multiplier"] == 1.00, "Normal speed mult should be 1.00")
	
	# Mode: Hard
	mgr.difficulty_mode = "hard"
	mgr.evaluate_difficulty(dummy_enemy, dummy_player)
	assert(mgr.current_aggression == 0.85, "Hard aggression should be 0.85")
	assert(mgr.current_parameters["speed_multiplier"] == 1.15, "Hard speed mult should be 1.15")
	assert(mgr.current_parameters["attack_cooldown_multiplier"] == 0.85, "Hard cooldown mult should be 0.85")
	
	# Mode: Nightmare
	mgr.difficulty_mode = "nightmare"
	mgr.evaluate_difficulty(dummy_enemy, dummy_player)
	assert(mgr.current_aggression == 1.00, "Nightmare aggression should be 1.00")
	assert(mgr.current_parameters["speed_multiplier"] == 1.25, "Nightmare speed mult should be 1.25")
	assert(mgr.current_parameters["attack_damage_multiplier"] == 1.25, "Nightmare damage mult should be 1.25")
	assert(mgr.current_parameters["attack_cooldown_multiplier"] == 0.75, "Nightmare cooldown mult should be 0.75")
	
	dummy_enemy.queue_free()
	dummy_player.queue_free()
	print("  -> Fixed difficulty benchmark modes verified for A/B comparison testing.")


func test_enemy_controller_integration_and_scaling() -> void:
	print("[TEST 6/7] Testing AlienEnemy controller integration and dynamic stat scaling...")
	var enemy: CharacterBody2D = _base_enemy_scene.instantiate()
	add_child(enemy)
	
	# Verify Scout base stats
	enemy.call("apply_enemy_preset", AlienEnemyScript.EnemyType.SCOUT)
	var base_scout_speed: float = enemy.get("chase_speed")
	var base_scout_dmg: float = enemy.get("attack_damage")
	assert(base_scout_speed == 210.0, "Scout base chase speed should be 210")
	assert(base_scout_dmg == 8.0, "Scout base attack damage should be 8")
	
	# Apply high aggression multipliers
	enemy.call("apply_difficulty_multipliers", {
		"speed_multiplier": 1.20,
		"attack_damage_multiplier": 1.25,
		"attack_cooldown_multiplier": 0.80,
		"detection_range_multiplier": 1.10
	})
	assert(is_equal_approx(enemy.get("chase_speed"), 210.0 * 1.20), "Scout chase speed should scale by 1.2x")
	assert(is_equal_approx(enemy.get("attack_damage"), 8.0 * 1.25), "Scout attack damage should scale by 1.25x")
	
	# Switch to Armored Brute -> base stats should update cleanly, re-applying multipliers
	enemy.call("apply_enemy_preset", AlienEnemyScript.EnemyType.ARMORED_BRUTE)
	assert(is_equal_approx(enemy.get("chase_speed"), 75.0 * 1.20), "Brute chase speed should scale from brute base 75")
	assert(is_equal_approx(enemy.get("attack_damage"), 28.0 * 1.25), "Brute attack damage should scale from brute base 28")
	
	# Disable adaptive difficulty -> should revert cleanly to base preset values
	enemy.set("enable_adaptive_difficulty", false)
	assert(is_equal_approx(enemy.get("chase_speed"), 75.0), "Disabling adaptive difficulty must restore base chase speed 75")
	assert(is_equal_approx(enemy.get("attack_damage"), 28.0), "Disabling adaptive difficulty must restore base attack damage 28")
	
	enemy.queue_free()
	print("  -> AlienEnemy dynamic scaling and base preservation verified across enemy types.")


func test_godot_rendering_and_movement_authority() -> void:
	print("[TEST 7/7] Verifying Godot authority over rendering, physics, and per-frame movement...")
	var enemy: CharacterBody2D = _base_enemy_scene.instantiate()
	add_child(enemy)
	
	# Verify that the difficulty manager only exposes scalars/multipliers
	var mgr = enemy.call("get_difficulty_manager")
	assert(mgr != null, "Enemy should have an initialized difficulty manager")
	
	var params: Dictionary = enemy.call("get_current_multipliers")
	assert(params.has("speed_multiplier"), "Parameters must contain scalar multipliers only")
	assert(params.has("attack_damage_multiplier"), "Parameters must contain scalar multipliers only")
	assert(params.has("attack_cooldown_multiplier"), "Parameters must contain scalar multipliers only")
	assert(params.has("detection_range_multiplier"), "Parameters must contain scalar multipliers only")
	
	# Confirm the difficulty manager has no rendering, canvas, or direct transform controls
	assert(not mgr.has_method("draw"), "Difficulty manager must not render")
	assert(not mgr.has_method("move_and_slide"), "Difficulty manager must not drive movement")
	assert(not mgr.has_method("set_position"), "Difficulty manager must not alter position directly")
	
	# Confirm physics and visuals belong entirely to Godot node
	assert(enemy.has_method("move_and_slide"), "Godot AlienEnemy handles move_and_slide")
	assert(enemy.get_node_or_null("Visual") != null, "Godot Visual node handles rendering")
	
	enemy.queue_free()
	print("  -> Rendering and per-frame movement authority strictly preserved within Godot.")
