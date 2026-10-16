extends Node
## Automated Integration Test Suite for BioSphere-X Command Parser & Tactical Terminal.
##
## Verifies:
##   1. Python / offline NLP parser structured intent & parameters contract.
##   2. Separation of concerns: parser NEVER modifies game state directly.
##   3. Authoritative Godot game-state validation & execution for supported commands:
##      - collect oxygen (with tank full, with cells, at station, with no cells)
##      - show inventory (category filters, manifest retrieval, UI toggle)
##      - return to base (hostile lockdown rejection, waypoint plotting)
##      - find research station (station discovery, proximity, waypoint setting)
##      - check vitals & telemetry
##      - help & command catalog
##   4. Ambiguous command handling with clarification & suggestions.
##   5. Unknown & impossible command graceful rejection.
##   6. Offline resilience without paid models or internet access.

const CommandTerminalScene := preload("res://ui/components/command_terminal.tscn")

var _passed_tests: int = 0
var _failed_tests: int = 0
var _terminal: PanelContainer = null


func _ready() -> void:
	print("=================================================================")
	print("🧪 Starting BioSphere-X Natural Language Command Parser Test Suite")
	print("=================================================================")
	
	_terminal = CommandTerminalScene.instantiate()
	_terminal.call("set_force_offline_mode", true) # Guarantee deterministic offline testing
	add_child(_terminal)
	
	_run_all_tests()
	
	print("=================================================================")
	print("Test Results: %d Passed, %d Failed" % [_passed_tests, _failed_tests])
	print("=================================================================")
	
	if _failed_tests > 0:
		push_error("Command parser tests failed!")
	else:
		print("✅ ALL COMMAND PARSER & TERMINAL TESTS COMPLETED SUCCESSFULLY!")
		
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
	_test_parser_structured_intent_contract()
	_test_parser_does_not_mutate_state()
	_test_ambiguous_command_handling()
	_test_unknown_command_handling()
	_test_collect_oxygen_impossible_when_full()
	_test_collect_oxygen_impossible_when_empty_and_no_canisters()
	_test_collect_oxygen_valid_with_inventory_cells()
	_test_collect_oxygen_valid_at_atmospheric_station()
	_test_return_to_base_impossible_under_hostile_lockdown()
	_test_return_to_base_valid_when_safe()
	_test_find_research_station_execution()
	_test_show_inventory_execution()
	_test_check_vitals_execution()
	_test_help_command_execution()
	_test_terminal_ui_history_and_events()


# ---------------------------------------------------------------------------
# Test 1: Parser Structured Intent & Parameter Contract
# ---------------------------------------------------------------------------
func _test_parser_structured_intent_contract() -> void:
	print("\n--- Test 1: Parser Structured Intent & Parameters Contract ---")
	
	# 1. Collect Oxygen
	var p_oxy: Dictionary = _terminal.call("_parse_command_locally", "refill 50 oxygen")
	_assert_eq(p_oxy.get("intent"), "collect_oxygen", "Parser identifies 'collect_oxygen' intent")
	_assert_true(p_oxy.get("is_valid"), "Parser marks oxygen command as valid")
	var oxy_params: Dictionary = p_oxy.get("parameters", {})
	_assert_eq(oxy_params.get("requested_amount"), 50.0, "Parser extracts requested amount: 50.0")
	_assert_eq(oxy_params.get("unit"), "percent", "Parser extracts unit: percent")
	
	# 2. Show Inventory
	var p_inv: Dictionary = _terminal.call("_parse_command_locally", "show inventory")
	_assert_eq(p_inv.get("intent"), "show_inventory", "Parser identifies 'show_inventory' intent")
	_assert_true(p_inv.get("is_valid"), "Parser marks inventory command as valid")
	var inv_params: Dictionary = p_inv.get("parameters", {})
	_assert_eq(inv_params.get("open_ui"), true, "Parser sets open_ui parameter to true")
	
	# 3. Return to Base
	var p_ret: Dictionary = _terminal.call("_parse_command_locally", "return to base")
	_assert_eq(p_ret.get("intent"), "return_to_base", "Parser identifies 'return_to_base' intent")
	_assert_true(p_ret.get("is_valid"), "Parser marks return command as valid")
	var ret_params: Dictionary = p_ret.get("parameters", {})
	_assert_eq(ret_params.get("destination"), "habitat_airlock", "Parser sets destination to habitat_airlock")
	
	# 4. Find Research Station
	var p_st: Dictionary = _terminal.call("_parse_command_locally", "find research station")
	_assert_eq(p_st.get("intent"), "find_station", "Parser identifies 'find_station' intent")
	_assert_true(p_st.get("is_valid"), "Parser marks station finder as valid")
	var st_params: Dictionary = p_st.get("parameters", {})
	_assert_eq(st_params.get("station_type"), "research_terminal", "Parser extracts station_type: research_terminal")
	_assert_eq(st_params.get("set_waypoint"), true, "Parser sets set_waypoint: true")
	
	# 5. Check Vitals
	var p_vit: Dictionary = _terminal.call("_parse_command_locally", "check vitals")
	_assert_eq(p_vit.get("intent"), "check_vitals", "Parser identifies 'check_vitals' intent")
	_assert_true(p_vit.get("is_valid"), "Parser marks vitals check as valid")
	
	# 6. Help
	var p_hlp: Dictionary = _terminal.call("_parse_command_locally", "help")
	_assert_eq(p_hlp.get("intent"), "help", "Parser identifies 'help' intent")
	_assert_true(p_hlp.get("is_valid"), "Parser marks help as valid")


# ---------------------------------------------------------------------------
# Test 2: Separation of Concerns (Parser Never Modifies Game State)
# ---------------------------------------------------------------------------
func _test_parser_does_not_mutate_state() -> void:
	print("\n--- Test 2: Parser Does Not Directly Mutate Game State ---")
	var gs = get_node_or_null("/root/GameState")
	if not gs:
		push_error("GameState not available")
		return
		
	var orig_hp: float = gs.health
	var orig_o2: float = 40.0
	gs.oxygen = orig_o2
	var orig_crystals: int = gs.get_resource("crystals")
	
	# Call parser on multiple commands
	var _r1: Dictionary = _terminal.call("_parse_command_locally", "collect 100 oxygen")
	var _r2: Dictionary = _terminal.call("_parse_command_locally", "return to base")
	var _r3: Dictionary = _terminal.call("_parse_command_locally", "show inventory")
	
	# Assert zero state mutation
	_assert_eq(gs.health, orig_hp, "Parser did not mutate player health")
	_assert_eq(gs.oxygen, orig_o2, "Parser did not mutate suit oxygen")
	_assert_eq(gs.get_resource("crystals"), orig_crystals, "Parser did not mutate crystal inventory")


# ---------------------------------------------------------------------------
# Test 3: Ambiguous Command Handling
# ---------------------------------------------------------------------------
func _test_ambiguous_command_handling() -> void:
	print("\n--- Test 3: Ambiguous Command Handling ---")
	
	for amb_word in ["find", "get", "open", "go"]:
		var p: Dictionary = _terminal.call("_parse_command_locally", amb_word)
		_assert_eq(p.get("status"), "ambiguous", "Word '%s' parsed as ambiguous" % amb_word)
		_assert_eq(p.get("is_valid"), false, "Ambiguous command marked is_valid = false")
		_assert_true(not str(p.get("clarification")).is_empty(), "Clarification provided for '%s'" % amb_word)
		var suggestions: Array = p.get("suggested_actions", [])
		_assert_true(suggestions.size() >= 2, "Suggestions provided for '%s'" % amb_word)


# ---------------------------------------------------------------------------
# Test 4: Unknown Command Handling
# ---------------------------------------------------------------------------
func _test_unknown_command_handling() -> void:
	print("\n--- Test 4: Unknown Command Handling ---")
	
	var p: Dictionary = _terminal.call("_parse_command_locally", "engage warp hyperdrive xyz")
	_assert_eq(p.get("status"), "unknown", "Unrecognized command parsed as unknown status")
	_assert_eq(p.get("is_valid"), false, "Unknown command marked is_valid = false")
	_assert_true(not str(p.get("clarification")).is_empty(), "Clarification provided for unknown command")
	_assert_true(p.get("suggested_actions", []).size() > 0, "Suggested valid fallbacks provided")


# ---------------------------------------------------------------------------
# Test 5: Collect Oxygen Impossible When Tank Full
# ---------------------------------------------------------------------------
func _test_collect_oxygen_impossible_when_full() -> void:
	print("\n--- Test 5: Collect Oxygen Impossible When Tank Full ---")
	var gs = get_node_or_null("/root/GameState")
	gs.oxygen = 100.0
	gs.max_oxygen = 100.0
	
	var parsed := {
		"intent": "collect_oxygen",
		"parameters": {"requested_amount": 50.0, "target": "tank"},
		"is_valid": true,
		"status": "ok"
	}
	
	var result: Dictionary = _terminal.call("validate_and_execute", parsed)
	_assert_eq(result["success"], false, "Validation rejected: tank already full")
	_assert_true("100%" in result["reason"], "Reason clearly explains 100% capacity limitation")
	_assert_eq(gs.oxygen, 100.0, "Oxygen remains at 100.0 without overflow")


# ---------------------------------------------------------------------------
# Test 6: Collect Oxygen Impossible When Empty and No Canisters
# ---------------------------------------------------------------------------
func _test_collect_oxygen_impossible_when_empty_and_no_canisters() -> void:
	print("\n--- Test 6: Collect Oxygen Impossible When Empty and No Canisters ---")
	var gs = get_node_or_null("/root/GameState")
	var inv = get_node_or_null("/root/InventoryManager")
	
	gs.oxygen = 25.0
	gs.is_oxygen_refilling = false
	gs.resources["oxygen_cells"] = 0
	if inv:
		inv.remove_item("oxygen_cells", 99)
		inv.remove_item("oxygen_pack", 99)
		
	var parsed := {
		"intent": "collect_oxygen",
		"parameters": {"requested_amount": 50.0, "target": "tank"},
		"is_valid": true,
		"status": "ok"
	}
	
	var result: Dictionary = _terminal.call("validate_and_execute", parsed)
	_assert_eq(result["success"], false, "Validation rejected: no oxygen cells and not in base")
	_assert_true("Impossible action" in result["reason"], "Reason identifies impossible wilderness action")
	_assert_eq(gs.oxygen, 25.0, "Oxygen level remains unmutated (25.0)")


# ---------------------------------------------------------------------------
# Test 7: Collect Oxygen Valid With Inventory Canisters
# ---------------------------------------------------------------------------
func _test_collect_oxygen_valid_with_inventory_cells() -> void:
	print("\n--- Test 7: Collect Oxygen Valid With Inventory Canisters ---")
	var gs = get_node_or_null("/root/GameState")
	var inv = get_node_or_null("/root/InventoryManager")
	
	gs.oxygen = 40.0
	gs.is_oxygen_refilling = false
	if inv:
		inv.add_item("oxygen_cells", 2)
	else:
		gs.resources["oxygen_cells"] = 2
		
	var parsed := {
		"intent": "collect_oxygen",
		"parameters": {"requested_amount": 30.0, "target": "oxygen_cells"},
		"is_valid": true,
		"status": "ok"
	}
	
	var executed_event := {"fired": false, "source": ""}
	var callable = func(act: String, det: Dictionary):
		if act == "collect_oxygen":
			executed_event["fired"] = true
			executed_event["source"] = det.get("source", "")
	_terminal.connect("action_executed", callable)
	
	var result: Dictionary = _terminal.call("validate_and_execute", parsed)
	_assert_eq(result["success"], true, "Validation approved: consumable canister available")
	_assert_true(gs.oxygen > 40.0, "Suit oxygen replenished (Now: %.1f)" % gs.oxygen)
	_assert_true(executed_event["fired"], "action_executed signal fired")
	_assert_eq(executed_event["source"], "oxygen_cells", "Execution source correctly identified as oxygen_cells")
	
	_terminal.disconnect("action_executed", callable)


# ---------------------------------------------------------------------------
# Test 8: Collect Oxygen Valid At Atmospheric Station
# ---------------------------------------------------------------------------
func _test_collect_oxygen_valid_at_atmospheric_station() -> void:
	print("\n--- Test 8: Collect Oxygen Valid At Atmospheric Station ---")
	var gs = get_node_or_null("/root/GameState")
	gs.oxygen = 20.0
	gs.is_oxygen_refilling = true
	
	var parsed := {
		"intent": "collect_oxygen",
		"parameters": {"requested_amount": 100.0, "target": "tank"},
		"is_valid": true,
		"status": "ok"
	}
	
	var result: Dictionary = _terminal.call("validate_and_execute", parsed)
	_assert_eq(result["success"], true, "Validation approved: inside atmospheric zone")
	_assert_eq(gs.oxygen, 100.0, "Suit oxygen fully recharged to 100.0")
	_assert_true("Atmospheric core" in result["reason"], "Reason confirms atmospheric core lock")
	gs.is_oxygen_refilling = false


# ---------------------------------------------------------------------------
# Test 9: Return To Base Impossible Under Hostile Lockdown
# ---------------------------------------------------------------------------
func _test_return_to_base_impossible_under_hostile_lockdown() -> void:
	print("\n--- Test 9: Return to Base Impossible Under Hostile Lockdown ---")
	var gre = get_node_or_null("/root/GameRuleEngine")
	if not gre:
		push_error("GameRuleEngine not available")
		return
		
	gre.combat_threat_active = true
	gre.is_extraction_blocked = true
	gre.extraction_block_reason = "Hostile pursuit active: Airlock security lockdown prevents return sequence until threat is neutralized!"
	
	var parsed := {
		"intent": "return_to_base",
		"parameters": {"destination": "habitat_airlock", "dock_airlock": true},
		"is_valid": true,
		"status": "ok"
	}
	
	var result: Dictionary = _terminal.call("validate_and_execute", parsed)
	_assert_eq(result["success"], false, "Return to base rejected during hostile threat")
	_assert_true("Hostile pursuit" in result["reason"] or "lockdown" in result["reason"], "Reason cites combat threat lockdown")
	
	# Clear combat alert
	gre.combat_threat_active = false
	gre.is_extraction_blocked = false


# ---------------------------------------------------------------------------
# Test 10: Return To Base Valid When Safe
# ---------------------------------------------------------------------------
func _test_return_to_base_valid_when_safe() -> void:
	print("\n--- Test 10: Return to Base Valid When Safe ---")
	var gre = get_node_or_null("/root/GameRuleEngine")
	if gre:
		gre.combat_threat_active = false
		gre.is_extraction_blocked = false
		
	var parsed := {
		"intent": "return_to_base",
		"parameters": {"destination": "habitat_airlock", "dock_airlock": true},
		"is_valid": true,
		"status": "ok"
	}
	
	var result: Dictionary = _terminal.call("validate_and_execute", parsed)
	_assert_eq(result["success"], true, "Return to base approved when safe")
	_assert_true("trajectory" in result["reason"] or "perimeter" in result["reason"], "Reason provides trajectory or docking status")


# ---------------------------------------------------------------------------
# Test 11: Find Research Station Execution
# ---------------------------------------------------------------------------
func _test_find_research_station_execution() -> void:
	print("\n--- Test 11: Find Research Station Execution ---")
	
	# Create mock research terminal node in scene
	var mock_term := Node2D.new()
	mock_term.name = "TestResearchTerminal"
	mock_term.set("terminal_name", "Epsilon-9 Science Console")
	mock_term.position = Vector2(400.0, 300.0)
	mock_term.add_to_group("terminals")
	add_child(mock_term)
	
	var parsed := {
		"intent": "find_station",
		"parameters": {"station_type": "research_terminal", "set_waypoint": true},
		"is_valid": true,
		"status": "ok"
	}
	
	var result: Dictionary = _terminal.call("validate_and_execute", parsed)
	_assert_eq(result["success"], true, "Research station successfully discovered")
	_assert_true("Epsilon-9" in result["reason"] or "TestResearchTerminal" in result["reason"], "Reason identifies terminal name")
	_assert_true("Range:" in result["reason"] or "coordinates" in result["reason"], "Reason gives distance and coordinates")
	
	mock_term.queue_free()


# ---------------------------------------------------------------------------
# Test 12: Show Inventory Execution
# ---------------------------------------------------------------------------
func _test_show_inventory_execution() -> void:
	print("\n--- Test 12: Show Inventory Execution ---")
	var gs = get_node_or_null("/root/GameState")
	gs.resources["crystals"] = 4
	gs.resources["titanium"] = 7
	
	var parsed := {
		"intent": "show_inventory",
		"parameters": {"filter_category": "all", "open_ui": true},
		"is_valid": true,
		"status": "ok"
	}
	
	var result: Dictionary = _terminal.call("validate_and_execute", parsed)
	_assert_eq(result["success"], true, "Inventory manifest retrieved")
	_assert_true("Crystals: 4" in result["reason"], "Manifest includes crystals count")
	_assert_true("Titanium: 7" in result["reason"], "Manifest includes titanium count")


# ---------------------------------------------------------------------------
# Test 13: Check Vitals Execution
# ---------------------------------------------------------------------------
func _test_check_vitals_execution() -> void:
	print("\n--- Test 13: Check Vitals Execution ---")
	var gs = get_node_or_null("/root/GameState")
	gs.health = 88.0
	gs.oxygen = 75.0
	
	var parsed := {
		"intent": "check_vitals",
		"parameters": {"scope": "all"},
		"is_valid": true,
		"status": "ok"
	}
	
	var result: Dictionary = _terminal.call("validate_and_execute", parsed)
	_assert_eq(result["success"], true, "Vitals telemetry retrieved")
	_assert_true("88" in result["reason"], "Telemetry reports accurate health")
	_assert_true("75" in result["reason"], "Telemetry reports accurate oxygen")


# ---------------------------------------------------------------------------
# Test 14: Help Command Execution
# ---------------------------------------------------------------------------
func _test_help_command_execution() -> void:
	print("\n--- Test 14: Help Command Execution ---")
	var parsed := {
		"intent": "help",
		"parameters": {},
		"is_valid": true,
		"status": "ok"
	}
	
	var result: Dictionary = _terminal.call("validate_and_execute", parsed)
	_assert_eq(result["success"], true, "Help command prints command catalog")


# ---------------------------------------------------------------------------
# Test 15: Terminal UI History & Event Handling
# ---------------------------------------------------------------------------
func _test_terminal_ui_history_and_events() -> void:
	print("\n--- Test 15: Terminal UI History & Navigation Events ---")
	
	_terminal.call("open_terminal")
	_assert_eq(_terminal.visible, true, "Terminal opened and visible")
	
	# Submit commands and verify history
	_terminal.call("submit_command", "check vitals")
	_terminal.call("submit_command", "show inventory")
	
	var hist: Array = _terminal.get("_command_history")
	_assert_eq(hist.size(), 2, "Command history recorded 2 entries")
	_terminal.call("_navigate_history", -1)
	var input_node = _terminal.get("input_line")
	_assert_eq(input_node.text, "show inventory", "History navigated to last command")
	_terminal.call("_navigate_history", -1)
	_assert_eq(input_node.text, "check vitals", "History navigated to previous command")
	
	_terminal.call("close_terminal")
	_assert_eq(_terminal.visible, false, "Terminal closed and hidden")
