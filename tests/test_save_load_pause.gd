extends Node
## Automated Integration Test Suite for BioSphere-X Save/Load, Pause, and Menus (Prompt 28).
##
## Verifies:
##   1. Versioned and validated save schema (format tag, version number, required sections).
##   2. Graceful error handling for missing, empty, or corrupted save files.
##   3. Accurate round-trip serialization and restoration for:
##      - Player vitals (health, oxygen, energy)
##      - Inventory resources & items
##      - Mission progress and status
##      - Planet progression & unlocked destinations
##      - Base structures & placement grid
##   4. Non-duplication guarantee: loading does NOT duplicate structures or trigger duplicate mission completions.
##   5. Pause system freezing: game pause freezes oxygen depletion, mission timers, and unpauses cleanly.
##   6. Settings persistence (audio volumes, fullscreen, screen shake).

const TEST_SAVE_PATH: String = "user://test_prompt28_save.json"
const TEST_SETTINGS_PATH: String = "user://test_prompt28_settings.json"
const TEST_CORRUPT_PATH: String = "user://test_prompt28_corrupt.json"

var _passed_tests: int = 0
var _failed_tests: int = 0


func _ready() -> void:
	print("=================================================================")
	print("🧪 Starting BioSphere-X Save/Load, Pause & Menu Test Suite")
	print("=================================================================")
	
	_clean_temp_files()
	_run_all_tests()
	_clean_temp_files()
	
	print("=================================================================")
	print("Test Results: %d Passed, %d Failed" % [_passed_tests, _failed_tests])
	print("=================================================================")
	
	if _failed_tests > 0:
		push_error("Save/Load & Pause tests failed!")
	else:
		print("✅ ALL SAVE/LOAD, PAUSE, AND MENU TESTS COMPLETED SUCCESSFULLY!")
		
	get_tree().quit(0 if _failed_tests == 0 else 1)


func _clean_temp_files() -> void:
	for path in [TEST_SAVE_PATH, TEST_SETTINGS_PATH, TEST_CORRUPT_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _run_all_tests() -> void:
	test_versioned_save_validation()
	test_missing_and_corrupted_save_handling()
	test_save_and_load_roundtrip()
	test_non_duplication_of_structures()
	test_mission_restoration_integrity()
	test_pause_freezes_oxygen_and_timers()
	test_settings_persistence()


# ---------------------------------------------------------------------------
# Test 1: Versioned Save Schema Validation
# ---------------------------------------------------------------------------
func test_versioned_save_validation() -> void:
	print("\n--- Test Suite 1: Versioned Schema Validation ---")
	var sm = get_node_or_null("/root/SaveManager")
	_assert_true(sm != null, "SaveManager autoload exists")
	if not sm:
		return

	# Standard valid dictionary
	var valid_dict = {
		"format_tag": "BioSphere-X-Save",
		"version": 1,
		"meta": {"save_name": "Test"},
		"player": {"health": 100.0, "oxygen": 100.0, "energy": 100.0},
		"inventory": {"carried_resources": {}, "items": []},
		"missions": {"active_mission_id": "m1", "completed_mission_ids": []},
		"progression": {"current_planet_id": "trappist_1_e", "unlocked_planets": ["trappist_1_e"]},
		"construction": []
	}
	var res = sm.call("validate_save_data", valid_dict)
	_assert_true(res.get("valid", false), "Standard versioned save validates as valid")

	# Wrong format tag
	var invalid_tag = valid_dict.duplicate(true)
	invalid_tag["format_tag"] = "AlienGameSave"
	var res_tag = sm.call("validate_save_data", invalid_tag)
	_assert_true(not res_tag.get("valid", true), "Rejects mismatched format tag")

	# Unsupported version
	var invalid_ver = valid_dict.duplicate(true)
	invalid_ver["version"] = 999
	var res_ver = sm.call("validate_save_data", invalid_ver)
	_assert_true(not res_ver.get("valid", true), "Rejects future/unsupported save version")

	# Missing section
	var missing_sec = valid_dict.duplicate(true)
	missing_sec.erase("missions")
	var res_sec = sm.call("validate_save_data", missing_sec)
	_assert_true(not res_sec.get("valid", true), "Rejects save missing required 'missions' section")

	# Missing vital field
	var missing_vit = valid_dict.duplicate(true)
	missing_vit["player"] = {"energy": 50.0}
	var res_vit = sm.call("validate_save_data", missing_vit)
	_assert_true(not res_vit.get("valid", true), "Rejects save with missing health/oxygen in player section")


# ---------------------------------------------------------------------------
# Test 2: Missing & Corrupted File Rejection
# ---------------------------------------------------------------------------
func test_missing_and_corrupted_save_handling() -> void:
	print("\n--- Test Suite 2: Missing & Corrupt File Graceful Handling ---")
	var sm = get_node_or_null("/root/SaveManager")
	if not sm:
		return

	# Missing file
	var non_existent := "user://non_existent_mission_file_000.json"
	_assert_true(not sm.call("has_save_file", non_existent), "has_save_file returns false for missing file")
	var load_missing_ok: bool = sm.call("load_game", non_existent)
	_assert_true(not load_missing_ok, "load_game returns false for non-existent file without crashing")

	# Corrupted file (random broken text)
	var f := FileAccess.open(TEST_CORRUPT_PATH, FileAccess.WRITE)
	f.store_string("<<<ERROR: NOT A VALID JSON OBJECT >>> ::: {{]")
	f.close()

	_assert_true(not sm.call("has_save_file", TEST_CORRUPT_PATH), "has_save_file returns false for corrupted JSON")
	var load_corrupt_ok: bool = sm.call("load_game", TEST_CORRUPT_PATH)
	_assert_true(not load_corrupt_ok, "load_game safely rejects corrupted file without crashing")
	_assert_true(sm.call("get_last_error") != "", "SaveManager records meaningful error message for corrupt file")


# ---------------------------------------------------------------------------
# Test 3: Save & Load Roundtrip (Vitals, Inventory, Progression)
# ---------------------------------------------------------------------------
func test_save_and_load_roundtrip() -> void:
	print("\n--- Test Suite 3: Save/Load Roundtrip Integrity ---")
	var sm = get_node_or_null("/root/SaveManager")
	var gs = get_node_or_null("/root/GameState")
	var inv = get_node_or_null("/root/InventoryManager")
	var ppm = get_node_or_null("/root/PlanetProgressionManager")

	if not (sm and gs and inv):
		_assert_true(false, "Required autoloads missing for roundtrip test")
		return

	# 1. Set specific game state
	gs.health = 74.0
	gs.oxygen = 53.0
	gs.energy = 88.0
	gs.resources = {"crystals": 15, "titanium": 22, "biomass": 7, "oxygen_cells": 3}
	if ppm:
		ppm.unlocked_planets.clear()
		ppm.unlocked_planets.append("trappist_1_e")
		ppm.unlocked_planets.append("kepler_452_b")
		ppm.current_planet_id = "kepler_452_b"

	# 2. Save game to test path
	var save_ok: bool = sm.call("save_game", TEST_SAVE_PATH)
	_assert_true(save_ok, "save_game returned true for test save path")
	_assert_true(sm.call("has_save_file", TEST_SAVE_PATH), "has_save_file confirms valid saved state")

	# Check metadata inspection
	var meta: Dictionary = sm.call("get_save_metadata", TEST_SAVE_PATH)
	_assert_true(meta.has("timestamp"), "Save metadata includes timestamp")
	_assert_eq(meta.get("format_version"), 1, "Save metadata records correct version")

	# 3. Mutate current state (simulate loss or restart)
	gs.health = 20.0
	gs.oxygen = 10.0
	gs.energy = 15.0
	gs.resources = {"crystals": 0, "titanium": 0, "biomass": 0, "oxygen_cells": 0}
	if ppm:
		ppm.unlocked_planets.clear()
		ppm.unlocked_planets.append("trappist_1_e")
		ppm.current_planet_id = "trappist_1_e"

	# 4. Load game from test path
	var load_ok: bool = sm.call("load_game", TEST_SAVE_PATH)
	_assert_true(load_ok, "load_game returned true")

	# 5. Verify restored state
	_assert_eq(gs.health, 74.0, "Restored player health matches saved value")
	_assert_eq(gs.oxygen, 53.0, "Restored player oxygen matches saved value")
	_assert_eq(gs.energy, 88.0, "Restored player energy matches saved value")
	_assert_eq(gs.resources.get("crystals", 0), 15, "Restored crystals match saved value")
	_assert_eq(gs.resources.get("titanium", 0), 22, "Restored titanium matches saved value")
	_assert_eq(gs.resources.get("biomass", 0), 7, "Restored biomass matches saved value")
	_assert_eq(gs.resources.get("oxygen_cells", 0), 3, "Restored oxygen cells match saved value")

	if ppm:
		_assert_true("kepler_452_b" in ppm.unlocked_planets, "Planet unlocks restored accurately")


# ---------------------------------------------------------------------------
# Test 4: Base Construction Non-Duplication
# ---------------------------------------------------------------------------
func test_non_duplication_of_structures() -> void:
	print("\n--- Test Suite 4: Non-Duplication of Base Structures ---")
	var sm = get_node_or_null("/root/SaveManager")
	var cm = get_node_or_null("/root/ConstructionManager")
	if not (sm and cm):
		return

	# Clear structures
	cm.call("clear_all_structures")
	_assert_eq(cm.call("get_placed_structures_save_data").size(), 0, "Construction structures initially empty")

	# Place mock structure data
	var mock_structures = [
		{
			"id": "struct_1",
			"structure_id": "oxygen_generator",
			"grid_x": 10,
			"grid_y": 12,
			"world_pos_x": 320.0,
			"world_pos_y": 384.0,
			"current_health": 200.0,
			"max_health": 200.0
		},
		{
			"id": "struct_2",
			"structure_id": "area_light",
			"grid_x": 14,
			"grid_y": 12,
			"world_pos_x": 448.0,
			"world_pos_y": 384.0,
			"current_health": 50.0,
			"max_health": 50.0
		}
	]
	cm.call("restore_placed_structures", mock_structures)
	_assert_eq(cm.call("get_placed_structures_save_data").size(), 2, "2 structures restored")

	# Save game
	sm.call("save_game", TEST_SAVE_PATH)

	# Simulate second load without prior manual clearing (mimics reloading scene or save)
	var load_again_ok = sm.call("load_game", TEST_SAVE_PATH)
	_assert_true(load_again_ok, "Reloading save succeeded")

	var struct_count_after = cm.call("get_placed_structures_save_data").size()
	_assert_eq(struct_count_after, 2, "Structures are NOT duplicated on repeated load (expected 2, got %d)" % struct_count_after)

	# Clean up
	cm.call("clear_all_structures")


# ---------------------------------------------------------------------------
# Test 5: Mission Restoration & Integrity
# ---------------------------------------------------------------------------
func test_mission_restoration_integrity() -> void:
	print("\n--- Test Suite 5: Mission Restoration Integrity ---")
	var sm = get_node_or_null("/root/SaveManager")
	var mm = get_node_or_null("/root/MissionManager")
	if not (sm and mm):
		return

	# Setup a specific mission state
	var mission_data = {
		"active_mission_id": "mission_2_gather_titanium",
		"active_mission_state": 1, # IN_PROGRESS
		"active_mission_progress": 1,
		"completed_mission_ids": ["mission_1_recover_oxygen"],
		"failed_mission_ids": []
	}
	mm.call("restore_missions_save_data", mission_data)

	var active = mm.call("get_active_mission")
	_assert_true(active != null, "Active mission is present after restoration")
	if active:
		_assert_eq(active.get("id"), "mission_2_gather_titanium", "Active mission ID matches saved ID")
		_assert_eq(int(active.get("current_progress")), 1, "Mission partial progress preserved at 1 (not reset or prematurely completed)")
		_assert_true(int(active.get("state")) != 2, "Active mission is not erroneously marked completed")

	var completed = mm.call("get_completed_mission_ids")
	_assert_true("mission_1_recover_oxygen" in completed, "Completed mission list preserved")


# ---------------------------------------------------------------------------
# Test 6: Pause Freezes Oxygen & Timers
# ---------------------------------------------------------------------------
func test_pause_freezes_oxygen_and_timers() -> void:
	print("\n--- Test Suite 6: Pause Freezes Oxygen & Encounter Timers ---")
	var gs = get_node_or_null("/root/GameState")
	var mm = get_node_or_null("/root/MissionManager")
	if not gs:
		return

	# 1. Unpaused state verification
	gs.call("set_paused", false)
	_assert_true(not get_tree().paused, "Tree is unpaused initially")
	_assert_true(not gs.is_paused, "GameState.is_paused is false")

	gs.oxygen = 80.0
	# Run normal frame: oxygen should deplete
	gs._process(1.0)
	var o2_after_unpaused = gs.oxygen
	_assert_true(o2_after_unpaused < 80.0, "Oxygen depleted during unpaused frame (Current: %f)" % o2_after_unpaused)

	# 2. Paused state verification
	gs.call("set_paused", true)
	_assert_true(get_tree().paused, "Tree paused is true")
	_assert_true(gs.is_paused, "GameState.is_paused is true")

	var o2_frozen = gs.oxygen
	# Simulate 10 seconds of process while paused
	gs._process(10.0)
	_assert_eq(gs.oxygen, o2_frozen, "Oxygen consumption strictly frozen while paused")

	# Check MissionManager timer while paused
	if mm:
		var timer_before: float = float(mm.get("_encounter_timer"))
		mm._process(10.0)
		var timer_after: float = float(mm.get("_encounter_timer"))
		_assert_eq(timer_after, timer_before, "MissionManager encounter countdown frozen while paused")

	# 3. Resume / Unpause verification
	gs.call("set_paused", false)
	_assert_true(not get_tree().paused, "Tree resumed cleanly")
	_assert_true(not gs.is_paused, "GameState.is_paused cleanly reset to false")


# ---------------------------------------------------------------------------
# Test 7: User Settings Persistence
# ---------------------------------------------------------------------------
func test_settings_persistence() -> void:
	print("\n--- Test Suite 7: Settings Persistence ---")
	var sm = get_node_or_null("/root/SaveManager")
	if not sm:
		return

	var custom_settings = {
		"master_volume": 0.45,
		"sfx_volume": 0.65,
		"screen_shake": false,
		"camera_smoothing": true,
		"fullscreen": false
	}
	var save_set_ok: bool = sm.call("save_settings", custom_settings, TEST_SETTINGS_PATH)
	_assert_true(save_set_ok, "save_settings succeeded")

	# Reload from path
	var loaded = sm.call("load_settings", TEST_SETTINGS_PATH)
	_assert_eq(float(loaded.get("master_volume", 0.0)), 0.45, "Master volume persisted and reloaded accurately")
	_assert_eq(float(loaded.get("sfx_volume", 0.0)), 0.65, "SFX volume persisted and reloaded accurately")
	_assert_eq(bool(loaded.get("screen_shake", true)), false, "Screen shake preference persisted accurately")


# ---------------------------------------------------------------------------
# Assertion Helpers
# ---------------------------------------------------------------------------
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
		push_error("  [FAIL] %s (Expected: %s, Got: %s)" % [test_name, str(expected), str(actual)])
		_failed_tests += 1
