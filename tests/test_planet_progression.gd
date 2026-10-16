extends Node
## Automated Integration Test Suite for Planet Progression & Level Transitions (Prompt 25).

var _passed_tests: int = 0
var _failed_tests: int = 0
var _test_save_path := "user://test_planet_progression_save.json"


func _ready() -> void:
	print("=================================================================")
	print("🧪 Starting BioSphere-X Planet Progression & Level Transition Test Suite")
	print("=================================================================")
	
	_run_all_tests()
	
	print("=================================================================")
	print("Test Results: %d Passed, %d Failed" % [_passed_tests, _failed_tests])
	print("=================================================================")
	
	if _failed_tests > 0:
		push_error("Planet Progression & Level Transition tests failed!")
	else:
		print("✅ ALL PLANET PROGRESSION & LEVEL TRANSITION TESTS COMPLETED SUCCESSFULLY!")
		
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
	_test_planet_level_config_models()
	_test_progression_manager_initial_state()
	_test_locked_destination_feedback()
	_test_mission_unlock_flow()
	_test_zero_duplication_level_transition()
	_test_save_load_persistence()


func _test_planet_level_config_models() -> void:
	print("\n--- TEST: Planet Level Config Models ---")
	var cfg_script = preload("res://scripts/components/planet_level_config.gd")
	
	# TRAPPIST-1 e config
	var trappist = cfg_script.create_trappist_1_e()
	_assert_true(trappist != null, "TRAPPIST-1 e config generated")
	_assert_eq(trappist.get("planet_id"), "trappist_1_e", "TRAPPIST-1 e planet_id")
	_assert_eq(trappist.get("oxygen_depletion_rate"), 1.5, "TRAPPIST-1 e O2 depletion rate 1.5")
	_assert_true(trappist.get("has_boss"), "TRAPPIST-1 e has boss encounter")
	_assert_true(trappist.get("deposit_specs").size() > 0, "TRAPPIST-1 e has resource deposits")
	_assert_true(trappist.get("mission_sequence").size() >= 3, "TRAPPIST-1 e has mission sequence")
	
	# LHS 1140 b config
	var lhs = cfg_script.create_lhs_1140_b()
	_assert_true(lhs != null, "LHS 1140 b config generated")
	_assert_eq(lhs.get("planet_id"), "lhs_1140_b", "LHS 1140 b planet_id")
	_assert_eq(lhs.get("unlock_required_planet_id"), "trappist_1_e", "LHS 1140 b requires trappist_1_e")
	_assert_eq(lhs.get("unlock_required_mission_id"), "mission_01_oxygen", "LHS 1140 b requires mission_01_oxygen")
	_assert_eq(lhs.get("oxygen_depletion_rate"), 2.2, "LHS 1140 b O2 depletion rate 2.2 (high gravity)")
	_assert_eq(lhs.get("enemy_brutes_count"), 4, "LHS 1140 b heavy brute count")
	_assert_true(lhs.get("mission_sequence").size() >= 3, "LHS 1140 b has dedicated mission sequence")


func _test_progression_manager_initial_state() -> void:
	print("\n--- TEST: Progression Manager Initial State ---")
	var ppm = get_node_or_null("/root/PlanetProgressionManager")
	_assert_true(ppm != null, "PlanetProgressionManager autoload singleton exists")
	
	ppm.call("reset_progression")
	_assert_true(ppm.call("is_planet_unlocked", "trappist_1_e"), "Starter planet TRAPPIST-1 e unlocked by default")
	_assert_true(not ppm.call("is_planet_unlocked", "lhs_1140_b"), "Super-Earth LHS 1140 b locked initially")
	_assert_eq(ppm.get("current_planet_id"), "trappist_1_e", "Current planet is trappist_1_e")


func _test_locked_destination_feedback() -> void:
	print("\n--- TEST: Locked Destination Feedback ---")
	var ppm = get_node_or_null("/root/PlanetProgressionManager")
	ppm.call("reset_progression")
	
	var reason: String = ppm.call("get_planet_lock_reason", "lhs_1140_b")
	_assert_true(reason.begins_with("🔒 LOCKED:"), "Clear locked prefix in reason: " + reason)
	_assert_true(reason.contains("LIFE SUPPORT RECOVERY") or reason.contains("mission_01_oxygen"), "Reason mentions required mission")
	
	var res_rejected := {"rejected": false, "reason": ""}
	var on_rejected := func(pid, p_reason):
		if pid == "lhs_1140_b":
			res_rejected["rejected"] = true
			res_rejected["reason"] = p_reason
	ppm.transition_rejected.connect(on_rejected)
	
	var transition_success: bool = ppm.call("transition_to_planet", "lhs_1140_b", true)
	ppm.transition_rejected.disconnect(on_rejected)
	
	_assert_true(not transition_success, "Transition to locked planet rejected")
	_assert_true(res_rejected["rejected"], "transition_rejected signal emitted")
	_assert_true(not res_rejected["reason"].is_empty(), "Reject reason provided: " + res_rejected["reason"])


func _test_mission_unlock_flow() -> void:
	print("\n--- TEST: Mission Completion Unlocks Destination ---")
	var ppm = get_node_or_null("/root/PlanetProgressionManager")
	ppm.call("reset_progression")
	_assert_true(not ppm.call("is_planet_unlocked", "lhs_1140_b"), "LHS 1140 b starts locked")
	
	var res_unlocked := {"received": false, "id": ""}
	var on_unlocked := func(p_id, _p_name):
		res_unlocked["received"] = true
		res_unlocked["id"] = p_id
	ppm.planet_unlocked.connect(on_unlocked)
	
	# Notify completion of required mission
	ppm.call("notify_mission_completed", "mission_01_oxygen", "trappist_1_e")
	ppm.planet_unlocked.disconnect(on_unlocked)
	
	_assert_true(res_unlocked["received"], "planet_unlocked signal emitted")
	_assert_eq(res_unlocked["id"], "lhs_1140_b", "Unlocked target is lhs_1140_b")
	_assert_true(ppm.call("is_planet_unlocked", "lhs_1140_b"), "LHS 1140 b is now marked unlocked")


func _test_zero_duplication_level_transition() -> void:
	print("\n--- TEST: Zero-Duplication Level Reloading & State Preservation ---")
	var ppm = get_node_or_null("/root/PlanetProgressionManager")
	var inv = get_node_or_null("/root/InventoryManager")
	var gs = get_node_or_null("/root/GameState")
	var mm = get_node_or_null("/root/MissionManager")
	
	# Instantiate GameWorld
	var world_scene := preload("res://scenes/world/game_world.tscn")
	var world = world_scene.instantiate()
	add_child(world)
	
	# Verify single instances in initial TRAPPIST-1 e state
	var player_nodes = []
	var hud_nodes = []
	for child in world.get_children():
		if child.name == "Player":
			player_nodes.append(child)
		elif child.name == "HUD":
			hud_nodes.append(child)
			
	_assert_eq(player_nodes.size(), 1, "Exactly one Player node in GameWorld")
	_assert_eq(hud_nodes.size(), 1, "Exactly one HUD node in GameWorld")
	_assert_eq(gs.oxygen_depletion_rate, 1.5, "TRAPPIST-1 e O2 depletion rate is 1.5")
	
	# Add items to Inventory to test preservation
	if inv:
		inv.call("add_item", "titanium", 5)
		inv.call("add_item", "crystals", 3)
		_assert_eq(inv.call("get_item_count", "titanium"), 5, "Added 5 Titanium before transition")
		_assert_eq(inv.call("get_item_count", "crystals"), 3, "Added 3 Crystals before transition")
		
	# Unlock LHS 1140 b and perform level transition
	ppm.call("unlock_planet", "lhs_1140_b")
	var transition_ok = ppm.call("transition_to_planet", "lhs_1140_b", true) # Instant load
	_assert_true(transition_ok, "Transition to LHS 1140 b executed")
	
	# Re-verify node counts: MUST NOT DUPLICATE PLAYER OR HUD!
	player_nodes.clear()
	hud_nodes.clear()
	for child in world.get_children():
		if child.name == "Player":
			player_nodes.append(child)
		elif child.name == "HUD":
			hud_nodes.append(child)
			
	_assert_eq(player_nodes.size(), 1, "Still exactly one Player node after transition (NO DUPLICATION)")
	_assert_eq(hud_nodes.size(), 1, "Still exactly one HUD node after transition (NO DUPLICATION)")
	
	# Verify inventory was NOT wiped or duplicated
	if inv:
		_assert_eq(inv.call("get_item_count", "titanium"), 5, "Inventory titanium preserved after transition")
		_assert_eq(inv.call("get_item_count", "crystals"), 3, "Inventory crystals preserved after transition")
		
	# Verify environmental settings updated
	_assert_eq(gs.oxygen_depletion_rate, 2.2, "Oxygen depletion rate updated to 2.2 on LHS 1140 b")
	_assert_eq(gs.selected_planet, "LHS 1140 b", "GameState selected planet updated to LHS 1140 b")
	
	# Verify new mission sequence loaded
	if mm:
		var active = mm.call("get_active_mission")
		_assert_true(active != null, "Active mission present on LHS 1140 b")
		_assert_eq(active.get("id"), "lhs_01_minerals", "Active mission is LHS 1140 b mission 1")
		
	# Clean up instantiated test world
	world.queue_free()


func _test_save_load_persistence() -> void:
	print("\n--- TEST: Progression Persistence (Save/Load) ---")
	var ppm = get_node_or_null("/root/PlanetProgressionManager")
	ppm.call("reset_progression")
	
	# Unlock LHS 1140 b and mark mission complete
	ppm.call("unlock_planet", "lhs_1140_b")
	ppm.call("notify_mission_completed", "mission_01_oxygen", "trappist_1_e")
	ppm.current_planet_id = "lhs_1140_b"
	
	# Save to test save file
	var saved: bool = ppm.call("save_progression", _test_save_path)
	_assert_true(saved, "Progression saved to disk")
	_assert_true(FileAccess.file_exists(_test_save_path), "Save file exists on disk")
	
	# Reset state to default
	ppm.unlocked_planets.clear()
	ppm.unlocked_planets.append("trappist_1_e")
	ppm.current_planet_id = "trappist_1_e"
	ppm.completed_missions = {"trappist_1_e": [], "lhs_1140_b": []}
	_assert_true(not ppm.call("is_planet_unlocked", "lhs_1140_b"), "State reset before load")
	
	# Load from test save file
	var loaded: bool = ppm.call("load_progression", _test_save_path)
	_assert_true(loaded, "Progression loaded from disk")
	_assert_true(ppm.call("is_planet_unlocked", "lhs_1140_b"), "LHS 1140 b restored to unlocked state")
	_assert_eq(ppm.current_planet_id, "lhs_1140_b", "Current planet restored to lhs_1140_b")
	_assert_true(ppm.completed_missions.get("trappist_1_e", []).has("mission_01_oxygen"), "Completed mission restored")
	
	# Cleanup test file
	if FileAccess.file_exists(_test_save_path):
		DirAccess.remove_absolute(_test_save_path)
	ppm.call("reset_progression")
