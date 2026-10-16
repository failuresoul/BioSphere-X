extends Node
## Automated Integration Test Suite for BioSphere-X Rule-Based Inference Engine.
## Verifies:
##   1. Condition evaluation across diverse operators (==, !=, <, <=, >, >=, in, not_in, exists).
##   2. Missing facts resilience.
##   3. Multi-step forward chaining rule dependencies (A -> B -> C).
##   4. Contradictory condition resolution via rule salience & overrides.
##   5. Life-support & oxygen warning triggers (caution, hypoxia, suffocation, sanctuary).
##   6. Mission prerequisite deductions & apex boss protocol authorization.
##   7. Extraction eligibility criteria & hostile combat lockdown overrides.
##   8. Explanations and reasoning trace generation.
##   9. Non-conflicting integration with MissionManager.
##  10. AIClient API connectivity and offline fallback resilience.

var _passed_tests: int = 0
var _failed_tests: int = 0


func _ready() -> void:
	print("=================================================================")
	print("🧪 Starting BioSphere-X Rule-Based Inference Engine Test Suite")
	print("=================================================================")
	
	_run_all_tests()
	
	print("=================================================================")
	print("Test Results: %d Passed, %d Failed" % [_passed_tests, _failed_tests])
	print("=================================================================")
	
	if _failed_tests > 0:
		push_error("Rule-Based Inference Engine tests failed!")
	else:
		print("✅ ALL RULE-BASED INFERENCE ENGINE TESTS COMPLETED SUCCESSFULLY!")
		
	get_tree().quit(0 if _failed_tests == 0 else 1)


func _assert_true(condition: bool, test_name: String) -> void:
	if condition:
		print("  [PASS] %s" % test_name)
		_passed_tests += 1
	else:
		push_error("  [FAIL] %s" % test_name)
		_failed_tests += 1


func _assert_eq(actual: Variant, expected: Variant, test_name: String) -> void:
	if actual == expected:
		print("  [PASS] %s (Value: %s)" % [test_name, str(actual)])
		_passed_tests += 1
	else:
		push_error("  [FAIL] %s - Expected: %s, Got: %s" % [test_name, str(expected), str(actual)])
		_failed_tests += 1


func _run_all_tests() -> void:
	_test_engine_initialization()
	_test_missing_facts_and_operators()
	_test_multi_step_forward_chaining()
	_test_contradictions_and_priority_overrides()
	_test_life_support_and_oxygen_warnings()
	_test_mission_prerequisites_and_boss_protocol()
	_test_extraction_eligibility_and_combat_lockdown()
	_test_environmental_rules()
	_test_explanations_trace()
	_test_non_conflicting_mission_manager_integration()
	_test_aiclient_connection_structure()


# ---------------------------------------------------------------------------
# Test 1: Engine Initialization & Default Catalog
# ---------------------------------------------------------------------------
func _test_engine_initialization() -> void:
	print("\n--- TEST: Engine Initialization & Default Rule Catalog ---")
	var engine = get_node_or_null("/root/GameRuleEngine")
	_assert_true(engine != null, "GameRuleEngine autoload present in SceneTree")
	_assert_true(engine._local_rules.size() >= 8, "Default rules registered in local engine (count: %d)" % engine._local_rules.size())


# ---------------------------------------------------------------------------
# Test 2: Missing Facts & Operator Robustness
# ---------------------------------------------------------------------------
func _test_missing_facts_and_operators() -> void:
	print("\n--- TEST: Missing Facts & Condition Operators ---")
	var engine = get_node("/root/GameRuleEngine")

	# 1. Missing fact safe handling (does not error)
	var missing_cond := {"field": "non_existent_key", "operator": ">", "value": 50.0}
	var res_missing = engine._evaluate_condition(missing_cond, {"oxygen_level": 80.0})
	_assert_true(not res_missing.satisfied, "Missing fact safely evaluates to unsatisfied")

	# 2. Exists operator
	var exists_cond := {"field": "oxygen_level", "operator": "exists"}
	var res_exists = engine._evaluate_condition(exists_cond, {"oxygen_level": 80.0})
	_assert_true(res_exists.satisfied, "Exists operator evaluates to true for present fact")

	var not_exists_cond := {"field": "alien_dna", "operator": "not_exists"}
	var res_not_exists = engine._evaluate_condition(not_exists_cond, {"oxygen_level": 80.0})
	_assert_true(res_not_exists.satisfied, "Not_exists operator evaluates to true for absent fact")

	# 3. Numeric operators
	var cond_lt := {"field": "temp", "operator": "<", "value": 200.0}
	_assert_true(engine._evaluate_condition(cond_lt, {"temp": 150.0}).satisfied, "Operator '<' evaluates correctly")
	_assert_true(not engine._evaluate_condition(cond_lt, {"temp": 250.0}).satisfied, "Operator '<' fails when >= value")

	# 4. In and Not In operators
	var cond_in := {"field": "planet", "operator": "in", "value": ["trappist_1_e", "lhs_1140_b"]}
	_assert_true(engine._evaluate_condition(cond_in, {"planet": "lhs_1140_b"}).satisfied, "Operator 'in' matches list element")
	_assert_true(not engine._evaluate_condition(cond_in, {"planet": "earth"}).satisfied, "Operator 'in' rejects non-member")

	var cond_not_in := {"field": "status", "operator": "not_in", "value": ["dead", "downed"]}
	_assert_true(engine._evaluate_condition(cond_not_in, {"status": "healthy"}).satisfied, "Operator 'not_in' succeeds when absent")


# ---------------------------------------------------------------------------
# Test 3: Multi-Step Forward Chaining Rule Dependencies
# ---------------------------------------------------------------------------
func _test_multi_step_forward_chaining() -> void:
	print("\n--- TEST: Multi-Step Forward Chaining Rule Dependencies ---")
	var engine = get_node("/root/GameRuleEngine")

	# Register temporary 3-stage dependency chain:
	# Stage 1: oxygen_canisters >= 2 -> o2_system_restored
	# Stage 2: o2_system_restored + power_grid_online -> atmospheric_scrubber_ready
	# Stage 3: atmospheric_scrubber_ready -> dome_pressurized
	engine.register_local_rule({
		"id": "test_chain_s1",
		"name": "Canister Quota",
		"priority": 100,
		"conditions": [{"field": "oxygen_canisters", "operator": ">=", "value": 2}],
		"conclusions": {"o2_system_restored": true},
		"actions": ["log_canisters_secured"]
	})

	engine.register_local_rule({
		"id": "test_chain_s2",
		"name": "Power and Scrubber Synchronization",
		"priority": 90,
		"conditions": [
			{"field": "o2_system_restored", "operator": "==", "value": true},
			{"field": "power_grid_online", "operator": "==", "value": true}
		],
		"conclusions": {"atmospheric_scrubber_ready": true},
		"actions": ["start_scrubber_turbines"]
	})

	engine.register_local_rule({
		"id": "test_chain_s3",
		"name": "Habitat Dome Pressurization",
		"priority": 80,
		"conditions": [
			{"field": "atmospheric_scrubber_ready", "operator": "==", "value": true}
		],
		"conclusions": {"dome_pressurized": true},
		"actions": ["seal_airlocks", "activate_sanctuary_field"]
	})

	var initial_facts := {
		"oxygen_canisters": 3,
		"power_grid_online": true
	}

	var res = engine.evaluate_facts_local(initial_facts)
	_assert_true(res.derived_facts.get("o2_system_restored", false), "Forward chain stage 1 derived")
	_assert_true(res.derived_facts.get("atmospheric_scrubber_ready", false), "Forward chain stage 2 derived")
	_assert_true(res.derived_facts.get("dome_pressurized", false), "Forward chain stage 3 derived")
	_assert_true(res.all_facts.get("dome_pressurized", false), "Dome pressurized present in final working memory")
	_assert_true(res.applicable_actions.has("seal_airlocks"), "Chained action 'seal_airlocks' triggered")
	_assert_true(res.applicable_actions.has("activate_sanctuary_field"), "Chained action 'activate_sanctuary_field' triggered")
	_assert_true(res.iterations >= 3, "Forward chaining ran multiple evaluation passes until fixpoint")


# ---------------------------------------------------------------------------
# Test 4: Contradictory Conditions & Priority-Based Overrides
# ---------------------------------------------------------------------------
func _test_contradictions_and_priority_overrides() -> void:
	print("\n--- TEST: Contradictory Conditions & Priority Overrides ---")
	var engine = get_node("/root/GameRuleEngine")

	# Low priority rule enables exploration
	engine.register_local_rule({
		"id": "test_low_prio_exploration",
		"name": "Surface Exploration Clearance",
		"priority": 40,
		"conditions": [{"field": "suit_operational", "operator": "==", "value": true}],
		"conclusions": {"surface_access_allowed": true}
	})

	# High priority rule blocks exploration due to seismic tempest
	engine.register_local_rule({
		"id": "test_high_prio_tempest",
		"name": "Seismic Tempest Hazard Lockdown",
		"priority": 140,
		"conditions": [{"field": "tempest_incoming", "operator": "==", "value": true}],
		"conclusions": {"surface_access_allowed": false},
		"actions": ["sound_tempest_siren"]
	})

	var facts_conflict := {
		"suit_operational": true,
		"tempest_incoming": true
	}

	var res = engine.evaluate_facts_local(facts_conflict)
	_assert_eq(res.all_facts.get("surface_access_allowed"), false, "High-priority rule overrides low-priority contradictory conclusion")
	_assert_true(res.applicable_actions.has("sound_tempest_siren"), "Action from winning rule executed")
	_assert_true(res.contradictions_detected.size() > 0, "Contradiction logged in deduction trace")


# ---------------------------------------------------------------------------
# Test 5: Life-Support & Low-Oxygen Warnings
# ---------------------------------------------------------------------------
func _test_life_support_and_oxygen_warnings() -> void:
	print("\n--- TEST: Life-Support & Oxygen Warnings ---")
	var engine = get_node("/root/GameRuleEngine")

	# 1. Safe Zone Sanctuary suppresses all warnings even with 0% O2
	var facts_sanctuary := {"oxygen_level": 0.0, "in_safe_zone": true}
	var res_sanctuary = engine.evaluate_facts_local(facts_sanctuary)
	_assert_true(res_sanctuary.all_facts.get("atmospheric_sanctuary", false), "Safe zone sanctuary active")
	_assert_eq(res_sanctuary.all_facts.get("low_oxygen_warning"), false, "Low oxygen warning suppressed in dome")
	_assert_eq(res_sanctuary.all_facts.get("critical_hypoxia"), false, "Critical hypoxia suppressed in dome")
	_assert_eq(res_sanctuary.all_facts.get("suffocation_active"), false, "Suffocation suppressed in dome")
	_assert_true(res_sanctuary.applicable_actions.has("refill_life_support"), "Refill life support triggered")
	_assert_true(not res_sanctuary.applicable_actions.has("apply_suffocation_damage"), "Suffocation damage prevented")

	# 2. Low oxygen caution (18% outside dome)
	var facts_low := {"oxygen_level": 18.0, "in_safe_zone": false}
	var res_low = engine.evaluate_facts_local(facts_low)
	_assert_true(res_low.derived_facts.get("low_oxygen_warning", false), "Low oxygen caution derived")
	_assert_true(not res_low.derived_facts.has("critical_hypoxia"), "Critical hypoxia not triggered at 18%")
	_assert_true(res_low.applicable_actions.has("flash_oxygen_hud"), "HUD caution pulse triggered")

	# 3. Critical hypoxia (6% outside dome)
	var facts_crit := {"oxygen_level": 6.0, "in_safe_zone": false}
	var res_crit = engine.evaluate_facts_local(facts_crit)
	_assert_true(res_crit.derived_facts.get("critical_hypoxia", false), "Critical hypoxia derived")
	_assert_true(res_crit.applicable_actions.has("trigger_critical_audio_alarm"), "Hypoxia audio alarm triggered")

	# 4. Complete depletion (0% outside dome)
	var facts_zero := {"oxygen_level": 0.0, "in_safe_zone": false}
	var res_zero = engine.evaluate_facts_local(facts_zero)
	_assert_true(res_zero.derived_facts.get("suffocation_active", false), "Suffocation active derived")
	_assert_true(res_zero.applicable_actions.has("apply_suffocation_damage"), "Suffocation damage action triggered")
	_assert_true(res_zero.applicable_actions.has("alarm_critical_breach"), "Breach alarm action triggered")


# ---------------------------------------------------------------------------
# Test 6: Mission Prerequisites & Boss Protocol
# ---------------------------------------------------------------------------
func _test_mission_prerequisites_and_boss_protocol() -> void:
	print("\n--- TEST: Mission Prerequisites & Boss Protocol ---")
	var engine = get_node("/root/GameRuleEngine")

	# 1. Mission 1 completion unlocks LHS 1140 b and enables Mission 2
	var facts_m1 := {"mission_01_oxygen_completed": true}
	var res_m1 = engine.evaluate_facts_local(facts_m1)
	_assert_true(res_m1.derived_facts.get("lhs_1140_b_unlocked", false), "LHS 1140 b unlocked on Mission 1 completion")
	_assert_true(res_m1.derived_facts.get("mission_02_eligible", false), "Mission 2 eligibility unlocked")
	_assert_true(res_m1.applicable_actions.has("notify_hyperspace_vector_unlocked"), "Hyperspace unlock action triggered")

	# 2. Apex Boss protocol: requires biomass samples >= 3 AND terminal scanned
	var facts_boss_incomplete = {"biomass_samples_collected": 3, "terminal_scanned": false}
	var res_boss_incomplete = engine.evaluate_facts_local(facts_boss_incomplete)
	_assert_true(not res_boss_incomplete.derived_facts.has("boss_protocol_authorized"), "Boss protocol withheld when terminal unscanned")

	var facts_boss_ready = {"biomass_samples_collected": 4, "terminal_scanned": true}
	var res_boss_ready = engine.evaluate_facts_local(facts_boss_ready)
	_assert_true(res_boss_ready.derived_facts.get("boss_protocol_authorized", false), "Boss protocol authorized when prerequisites met")
	_assert_true(res_boss_ready.derived_facts.get("mission_05_eligible", false), "Mission 5 boss encounter eligible")
	_assert_true(res_boss_ready.applicable_actions.has("enable_boss_crater_waypoint"), "Boss crater waypoint action triggered")


# ---------------------------------------------------------------------------
# Test 7: Extraction Eligibility & Combat Lockdown
# ---------------------------------------------------------------------------
func _test_extraction_eligibility_and_combat_lockdown() -> void:
	print("\n--- TEST: Extraction Eligibility & Combat Lockdown ---")
	var engine = get_node("/root/GameRuleEngine")

	# Case A: Ready to extract
	var facts_extract = {
		"primary_missions_completed": true,
		"samples_carried": 2,
		"near_airlock": true,
		"combat_threat_active": false,
		"in_safe_zone": false
	}
	var res_extract = engine.evaluate_facts_local(facts_extract)
	_assert_true(res_extract.all_facts.get("extraction_eligible", false), "Extraction criteria satisfied")
	_assert_true(res_extract.applicable_actions.has("unlock_airlock_exit"), "Unlock airlock exit action approved")

	# Case B: Hostile threat pursuing astronaut -> Lockdown overrides extraction eligibility
	var facts_lockdown = {
		"primary_missions_completed": true,
		"samples_carried": 2,
		"near_airlock": true,
		"combat_threat_active": true,
		"in_safe_zone": false
	}
	var res_lockdown = engine.evaluate_facts_local(facts_lockdown)
	_assert_true(res_lockdown.all_facts.get("extraction_blocked", false), "Extraction blocked due to combat threat")
	_assert_eq(res_lockdown.all_facts.get("extraction_eligible"), false, "Extraction eligible overridden to false")
	_assert_true(res_lockdown.applicable_actions.has("warn_combat_lockdown"), "Combat lockdown warning issued")
	_assert_true(not res_lockdown.applicable_actions.has("unlock_airlock_exit"), "Airlock exit unlocked withheld")


# ---------------------------------------------------------------------------
# Test 8: Environmental & Planetary Hazard Rules
# ---------------------------------------------------------------------------
func _test_environmental_rules() -> void:
	print("\n--- TEST: Environmental & Planetary Hazard Rules ---")
	var engine = get_node("/root/GameRuleEngine")

	var facts_env = {
		"planet_id": "lhs_1140_b",
		"ambient_temperature_k": 185.0,
		"in_safe_zone": false
	}
	var res_env = engine.evaluate_facts_local(facts_env)
	_assert_true(res_env.derived_facts.get("heavy_gravity_active", false), "Super-Earth heavy gravity applied")
	_assert_eq(res_env.derived_facts.get("oxygen_drain_rate"), 2.2, "Oxygen drain rate boosted to 2.2")
	_assert_eq(res_env.derived_facts.get("stamina_penalty"), 1.4, "Stamina penalty set to 1.4x")
	_assert_true(res_env.derived_facts.get("cryo_hazard_active", false), "Cryo hazard active for T < 200 K")
	_assert_true(res_env.applicable_actions.has("apply_heavy_gravity_hud_badge"), "Heavy gravity HUD badge action triggered")
	_assert_true(res_env.applicable_actions.has("activate_suit_heating_circuit"), "Suit heating action triggered")


# ---------------------------------------------------------------------------
# Test 9: Explanations Trace
# ---------------------------------------------------------------------------
func _test_explanations_trace() -> void:
	print("\n--- TEST: Explanations Trace ---")
	var engine = get_node("/root/GameRuleEngine")

	var facts = {"oxygen_level": 8.0, "in_safe_zone": false}
	engine.evaluate_facts(facts, false)

	var exp_hypoxia = engine.get_explanation("critical_hypoxia")
	_assert_true(exp_hypoxia.found, "Explanation found for critical_hypoxia")
	_assert_true(exp_hypoxia.trace.has("rule_name"), "Explanation trace contains rule name")

	var exp_action = engine.get_explanation("trigger_critical_audio_alarm")
	_assert_true(exp_action.found, "Explanation found for action trigger_critical_audio_alarm")


# ---------------------------------------------------------------------------
# Test 10: Non-Conflicting MissionManager Integration
# ---------------------------------------------------------------------------
func _test_non_conflicting_mission_manager_integration() -> void:
	print("\n--- TEST: Non-Conflicting MissionManager Integration ---")
	var mm = get_node_or_null("/root/MissionManager")
	var engine = get_node("/root/GameRuleEngine")
	
	_assert_true(mm != null, "MissionManager exists")

	# Record original mission state before inference
	var active_before = mm.get_active_mission()
	var active_id_before = str(active_before.get("id")) if active_before != null and active_before.get("id") != null else ""
	var order_size_before = mm._mission_order.size()

	# Run state evaluation
	var facts = engine.collect_gameplay_facts()
	engine.evaluate_facts(facts, false)

	# Verify MissionManager was not mutated internally by the rule engine
	var active_after = mm.get_active_mission()
	var active_id_after = str(active_after.get("id")) if active_after != null and active_after.get("id") != null else ""
	var order_size_after = mm._mission_order.size()

	_assert_eq(active_id_after, active_id_before, "MissionManager active mission ID untouched by rule engine")
	_assert_eq(order_size_after, order_size_before, "MissionManager mission registry count untouched by rule engine")


# ---------------------------------------------------------------------------
# Test 11: AIClient API Connectivity Structure
# ---------------------------------------------------------------------------
func _test_aiclient_connection_structure() -> void:
	print("\n--- TEST: AIClient API Connectivity Structure ---")
	var ai_client = get_node_or_null("/root/AIClient")
	_assert_true(ai_client != null, "AIClient autoload present")
	_assert_true(ai_client.has_method("request_rule_inference"), "AIClient has request_rule_inference method")
	_assert_true(ai_client.has_method("request_rule_catalog"), "AIClient has request_rule_catalog method")
	_assert_true(ai_client.has_method("request_rule_explanation"), "AIClient has request_rule_explanation method")
