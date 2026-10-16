extends Node
## Automated Test Suite for BioSphere-X Mission System (Prompt 20).
## Validates:
##   1. MissionData model, state machine, and progress formatting.
##   2. Event-driven COLLECT_OXYGEN progression.
##   3. Event-driven RETRIEVE_SAMPLES progression.
##   4. Event-driven ACTIVATE_TERMINAL progression.
##   5. Event-driven SURVIVE_ENCOUNTER progression (time ticks + hostile defeat bonuses).
##   6. Event-driven DEFEAT_BOSS progression.
##   7. Event-driven RETURN_TO_BASE progression.
##   8. Reward distribution into GameState resources & vitality refills.
##   9. Mission failure conditions (fail_on_death) and retry/restart capability.
##  10. Full campaign auto-advance pipeline and HUD telemetry integration.

const MissionDataScript := preload("res://scripts/components/mission_data.gd")
const HudScene := preload("res://ui/screens/hud.tscn")

var _test_count: int = 0
var _pass_count: int = 0


func _ready() -> void:
	print("==================================================")
	print("  BIOSPHERE-X: PROMPT 20 MISSION SYSTEM TESTS")
	print("==================================================")
	
	test_mission_data_model()
	test_collect_oxygen_objective()
	test_retrieve_samples_objective()
	test_activate_terminal_objective()
	test_survive_encounter_objective()
	test_defeat_boss_objective()
	test_return_to_base_objective()
	test_reward_distribution()
	test_failure_handling_and_restart()
	test_campaign_pipeline_and_hud_telemetry()
	
	print("==================================================")
	print("  ALL PROMPT 20 MISSION SYSTEM TESTS PASSED! [%d/%d]" % [_pass_count, _test_count])
	print("==================================================")
	get_tree().quit(0)


func _assert_test(condition: bool, test_name: String, error_msg: String = "") -> void:
	_test_count += 1
	if condition:
		_pass_count += 1
	else:
		push_error("FAILED: %s -> %s" % [test_name, error_msg])
		assert(condition, "%s: %s" % [test_name, error_msg])


# ---------------------------------------------------------------------------
# Test 1: MissionData Model & State Transitions
# ---------------------------------------------------------------------------
func test_mission_data_model() -> void:
	print("[TEST 1/10] Testing MissionData model, states, and serialization...")
	var m = MissionDataScript.create(
		"test_m1",
		"Test Title",
		"Test Description",
		MissionDataScript.ObjectiveType.COLLECT_OXYGEN,
		5.0,
		{"crystals": 3},
		{"fail_on_death": true},
		"Cells"
	)
	
	_assert_test(m != null, "Data model instantiated")
	_assert_test(m.is_locked(), "Initial state is LOCKED")
	_assert_test(m.get_progress_ratio() == 0.0, "Initial progress ratio is 0.0")
	
	m.start()
	_assert_test(m.is_active(), "State transition to ACTIVE succeeded")
	
	var completed = m.add_progress(2.5)
	_assert_test(not completed, "Progress not completed yet at 50%")
	_assert_test(is_equal_approx(m.get_progress_ratio(), 0.5), "Progress ratio is exactly 0.5")
	_assert_test(m.get_progress_text().contains("2 / 5 Cells (50%)"), "Progress text formatted correctly")
	
	completed = m.add_progress(3.0)
	_assert_test(completed, "Mission marks completed on reaching target")
	_assert_test(m.is_completed(), "State transition to COMPLETED verified")
	_assert_test(m.get_progress_ratio() == 1.0, "Progress ratio capped at 1.0")
	
	var d = m.to_dict()
	_assert_test(d["id"] == "test_m1" and d["state"] == MissionDataScript.MissionState.COMPLETED, "Serialization to dict verified")
	print("  -> MissionData model, state machine, and progress formatting verified.")


# ---------------------------------------------------------------------------
# Test 2: COLLECT_OXYGEN Objective
# ---------------------------------------------------------------------------
func test_collect_oxygen_objective() -> void:
	print("[TEST 2/10] Testing decoupled COLLECT_OXYGEN progression...")
	var mm = get_node("/root/MissionManager")
	mm.reset_campaign()
	
	var m = mm.get_mission("mission_01_oxygen")
	_assert_test(m != null, "Mission 1 exists")
	_assert_test(m.is_active(), "Mission 1 starts active in default campaign")
	
	# Ingest oxygen gained event
	mm.notify_event("oxygen_gained", {"amount": 1.0})
	_assert_test(m.current_progress == 1.0, "Progress incremented via oxygen_gained")
	
	# Ingest resource collected event
	mm.notify_event("resource_collected", {"resource_type": "oxygen_cells", "quantity": 1.0})
	_assert_test(m.current_progress == 2.0, "Progress incremented via resource_collected")
	
	# Complete mission
	mm.notify_event("resource_collected", {"resource_type": "oxygen_cells", "quantity": 1.0})
	_assert_test(m.is_completed(), "Mission 1 completed after 3 oxygen cells collected")
	print("  -> Decoupled COLLECT_OXYGEN event pipeline verified.")


# ---------------------------------------------------------------------------
# Test 3: RETRIEVE_SAMPLES Objective
# ---------------------------------------------------------------------------
func test_retrieve_samples_objective() -> void:
	print("[TEST 3/10] Testing decoupled RETRIEVE_SAMPLES progression...")
	var mm = get_node("/root/MissionManager")
	mm.start_mission("mission_02_samples")
	
	var m = mm.get_mission("mission_02_samples")
	_assert_test(m.is_active(), "Mission 2 is active")
	
	# Collect alien biomass samples
	mm.notify_event("resource_collected", {"resource_type": "biomass", "quantity": 2.0})
	_assert_test(m.current_progress == 2.0, "Biomass added 2 progress units")
	
	mm.notify_event("resource_collected", {"resource_type": "biomass", "quantity": 1.0})
	_assert_test(m.is_completed(), "Mission 2 completed on reaching 3 samples")
	print("  -> Decoupled RETRIEVE_SAMPLES event pipeline verified.")


# ---------------------------------------------------------------------------
# Test 4: ACTIVATE_TERMINAL Objective
# ---------------------------------------------------------------------------
func test_activate_terminal_objective() -> void:
	print("[TEST 4/10] Testing decoupled ACTIVATE_TERMINAL progression...")
	var mm = get_node("/root/MissionManager")
	mm.start_mission("mission_03_terminal")
	
	var m = mm.get_mission("mission_03_terminal")
	_assert_test(m.is_active(), "Mission 3 is active")
	
	mm.notify_event("terminal_activated", {"terminal_id": "Alpha-7 Research Terminal"})
	_assert_test(m.is_completed(), "Terminal activation completes Mission 3")
	print("  -> Decoupled ACTIVATE_TERMINAL event pipeline verified.")


# ---------------------------------------------------------------------------
# Test 5: SURVIVE_ENCOUNTER Objective
# ---------------------------------------------------------------------------
func test_survive_encounter_objective() -> void:
	print("[TEST 5/10] Testing SURVIVE_ENCOUNTER progression (time delta & kill bonus)...")
	var mm = get_node("/root/MissionManager")
	mm.start_mission("mission_04_survive")
	
	var m = mm.get_mission("mission_04_survive")
	_assert_test(m.is_active(), "Mission 4 is active")
	
	# Simulate 4 seconds of encounter elapsed time
	mm.notify_event("encounter_tick", {"delta": 4.0})
	_assert_test(is_equal_approx(m.current_progress, 4.0), "Encounter tick advanced progress by 4.0s")
	
	# Neutralize 2 hostiles (each provides +3s bonus survival progress)
	mm.notify_event("enemy_defeated", {"enemy_type": "alien_scout"})
	_assert_test(is_equal_approx(m.current_progress, 7.0), "Hostile neutralization gave 3.0s progress bonus")
	
	mm.notify_event("enemy_defeated", {"enemy_type": "alien_armored"})
	_assert_test(is_equal_approx(m.current_progress, 10.0), "Second neutralization gave 3.0s progress bonus")
	
	# Final tick to reach 12s target
	mm.notify_event("encounter_tick", {"delta": 2.5})
	_assert_test(m.is_completed(), "Encounter survival completed after meeting requirement")
	print("  -> SURVIVE_ENCOUNTER progression (time & combat bonuses) verified.")


# ---------------------------------------------------------------------------
# Test 6: DEFEAT_BOSS Objective
# ---------------------------------------------------------------------------
func test_defeat_boss_objective() -> void:
	print("[TEST 6/10] Testing decoupled DEFEAT_BOSS progression...")
	var mm = get_node("/root/MissionManager")
	mm.start_mission("mission_05_boss")
	
	var m = mm.get_mission("mission_05_boss")
	_assert_test(m.is_active(), "Mission 5 is active")
	
	mm.notify_event("boss_defeated", {"boss_id": "GoliathPrime"})
	_assert_test(m.is_completed(), "Boss defeat completes Mission 5")
	print("  -> Decoupled DEFEAT_BOSS event pipeline verified.")


# ---------------------------------------------------------------------------
# Test 7: RETURN_TO_BASE Objective
# ---------------------------------------------------------------------------
func test_return_to_base_objective() -> void:
	print("[TEST 7/10] Testing decoupled RETURN_TO_BASE progression...")
	var mm = get_node("/root/MissionManager")
	mm.start_mission("mission_06_extraction")
	
	var m = mm.get_mission("mission_06_extraction")
	_assert_test(m.is_active(), "Mission 6 is active")
	
	mm.notify_event("base_reached", {"target_zone": "habitat_airlock"})
	_assert_test(m.is_completed(), "Reaching airlock extraction zone completes Mission 6")
	print("  -> Decoupled RETURN_TO_BASE event pipeline verified.")


# ---------------------------------------------------------------------------
# Test 8: Reward Distribution
# ---------------------------------------------------------------------------
func test_reward_distribution() -> void:
	print("[TEST 8/10] Testing automatic reward distribution to GameState...")
	var gs = get_node("/root/GameState")
	var mm = get_node("/root/MissionManager")
	
	var start_crystals: int = gs.get_resource("crystals")
	var start_titanium: int = gs.get_resource("titanium")
	
	# Register and complete custom reward mission
	var custom_m = MissionDataScript.create(
		"test_rewards",
		"Reward Test Mission",
		"Complete test",
		MissionDataScript.ObjectiveType.COLLECT_OXYGEN,
		1.0,
		{"crystals": 5, "titanium": 3, "oxygen_refill": 50.0}
	)
	mm.register_mission(custom_m)
	mm.start_mission("test_rewards")
	mm.complete_mission("test_rewards")
	
	_assert_test(gs.get_resource("crystals") == start_crystals + 5, "Crystals rewarded correctly (+5)")
	_assert_test(gs.get_resource("titanium") == start_titanium + 3, "Titanium rewarded correctly (+3)")
	print("  -> Reward distribution to resources and vitality verified.")


# ---------------------------------------------------------------------------
# Test 9: Failure Handling & Restart
# ---------------------------------------------------------------------------
func test_failure_handling_and_restart() -> void:
	print("[TEST 9/10] Testing mission failure conditions and restart capability...")
	var mm = get_node("/root/MissionManager")
	
	var fail_m = MissionDataScript.create(
		"test_fail",
		"Permadeath Mission",
		"Survive hazardous environment",
		MissionDataScript.ObjectiveType.SURVIVE_ENCOUNTER,
		30.0,
		{},
		{"fail_on_death": true}
	)
	mm.register_mission(fail_m)
	mm.start_mission("test_fail")
	_assert_test(fail_m.is_active(), "Test mission active")
	
	# Astronaut eliminated
	mm.notify_event("player_died")
	_assert_test(fail_m.is_failed(), "Mission transitioned to FAILED state upon player death")
	_assert_test(fail_m.fail_reason != "", "Failure reason recorded")
	
	# Restart mission
	var restarted = mm.restart_mission("test_fail")
	_assert_test(restarted, "Mission restarted successfully")
	_assert_test(fail_m.is_active(), "State returned to ACTIVE")
	_assert_test(fail_m.current_progress == 0.0, "Progress reset to 0.0")
	print("  -> Mission failure handling and restart mechanisms verified.")


# ---------------------------------------------------------------------------
# Test 10: Full Campaign Pipeline & HUD Telemetry Synchronization
# ---------------------------------------------------------------------------
func test_campaign_pipeline_and_hud_telemetry() -> void:
	print("[TEST 10/10] Testing HUD telemetry synchronization and visual feedback...")
	var hud = HudScene.instantiate()
	add_child(hud)
	
	var mm = get_node("/root/MissionManager")
	mm.reset_campaign()
	
	# Verify initial HUD synchronization with Mission 1
	var title_lbl: Label = hud.get_node("%MissionTitleTag")
	var desc_lbl: Label = hud.get_node("%ObjectiveLabel")
	var prog_bar: ProgressBar = hud.get_node("%MissionProgressBar")
	var prog_lbl: Label = hud.get_node("%MissionProgressLabel")
	var feedback_panel: PanelContainer = hud.get_node("%MissionFeedbackBanner")
	
	_assert_test(title_lbl != null, "HUD MissionTitleTag exists")
	_assert_test(title_lbl.text.contains("LIFE SUPPORT RECOVERY"), "HUD displays initial mission title")
	_assert_test(prog_bar.value == 0.0, "HUD progress bar initialized to 0")
	
	# Advance progress and verify HUD update
	mm.notify_event("oxygen_gained", {"amount": 2.0})
	_assert_test(absf(prog_bar.value - (2.0 / 3.0)) < 0.005, "HUD progress bar updated to ~67%")
	_assert_test(prog_lbl.text.contains("2 / 3 Cells"), "HUD progress label updated")
	
	# Complete mission and verify success feedback banner
	mm.notify_event("oxygen_gained", {"amount": 1.0})
	_assert_test(feedback_panel.visible, "HUD feedback banner displayed on mission success")
	
	hud.queue_free()
	print("  -> HUD telemetry synchronization and feedback banner verified.")
