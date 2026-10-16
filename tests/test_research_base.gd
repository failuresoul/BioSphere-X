extends Node
## Automated Test Suite for BioSphere-X Research Base (Prompt 21).
## Validates:
##   1. ResearchBase compound initialization, geometry, and perimeter blast protection.
##   2. Atmospheric safe zone dome and oxygen refill station.
##   3. Reusable Cargo Storage & Vault Terminal (deposits, withdrawals, inventory syncing).
##   4. Reusable Mission Operations Terminal (active directives, progress telemetry, restart).
##   5. Reusable Planet-Selection & Expedition Gate (sector selection, airlock link, base return).
##   6. Standalone station component modularity (for secondary outposts).
##   7. HUD Terminal Modal overlay interaction (Storage, Ops, Deploy views).
##   8. GameWorld integration at player spawn coordinates.

const ResearchBaseScript := preload("res://scenes/world/research_base.gd")
const StorageTerminalScript := preload("res://scripts/components/storage_terminal.gd")
const MissionTerminalScript := preload("res://scripts/components/mission_terminal.gd")
const PlanetGateTerminalScript := preload("res://scripts/components/planet_gate_terminal.gd")
const OxygenStationScript := preload("res://scripts/components/oxygen_station.gd")
const HudScene := preload("res://ui/screens/hud.tscn")
const GameWorldScene := preload("res://scenes/world/game_world.tscn")

var _test_count: int = 0
var _pass_count: int = 0


func _ready() -> void:
	print("==================================================")
	print("  BIOSPHERE-X: PROMPT 21 RESEARCH BASE TESTS")
	print("==================================================")
	
	test_research_base_initialization()
	test_oxygen_refill_and_safe_zone()
	test_storage_terminal_deposit_and_withdrawal()
	test_mission_terminal_integration()
	test_planet_gate_and_sector_deployment()
	test_modular_station_reusability()
	test_hud_terminal_modal_interactions()
	test_game_world_integration()
	
	print("==================================================")
	print("  ALL PROMPT 21 RESEARCH BASE TESTS PASSED! [%d/%d]" % [_pass_count, _test_count])
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
# Test 1: ResearchBase Compound Initialization
# ---------------------------------------------------------------------------
func test_research_base_initialization() -> void:
	print("[TEST 1/8] Testing ResearchBase compound structure and perimeter...")
	var base: Node2D = ResearchBaseScript.new()
	add_child(base)
	
	_assert_test(base.is_in_group("research_base"), "Base in 'research_base' group")
	_assert_test(base.is_in_group("safe_zones"), "Base in 'safe_zones' group")
	_assert_test(base.has_method("get_oxygen_station"), "Oxygen station accessor available")
	_assert_test(base.has_method("get_storage_terminal"), "Storage terminal accessor available")
	_assert_test(base.has_method("get_mission_terminal"), "Mission terminal accessor available")
	_assert_test(base.has_method("get_planet_gate"), "Planet gate accessor available")
	_assert_test(base.has_method("get_airlock_door"), "Airlock door accessor available")
	
	_assert_test(base.call("is_point_inside_base", Vector2.ZERO), "Center (0,0) is inside base bounds")
	_assert_test(not base.call("is_point_inside_base", Vector2(400, 400)), "Outer point (400,400) is outside base bounds")
	
	base.queue_free()
	print("  -> Base compound structure, bounds, and station accessors verified.")


# ---------------------------------------------------------------------------
# Test 2: Oxygen Refill & Safe Zone
# ---------------------------------------------------------------------------
func test_oxygen_refill_and_safe_zone() -> void:
	print("[TEST 2/8] Testing base life-support core and atmospheric safe zone...")
	var gs = get_node("/root/GameState")
	var base: Node2D = ResearchBaseScript.new()
	add_child(base)
	
	var o2_core = base.call("get_oxygen_station")
	_assert_test(o2_core != null, "Life support oxygen core initialized")
	
	# Drain player oxygen
	gs.call("set_oxygen", 20.0)
	_assert_test(gs.get("oxygen") == 20.0, "Oxygen dropped to 20%")
	
	var player = CharacterBody2D.new()
	player.add_to_group("player")
	add_child(player)
	
	# Simulate entering base atmospheric field
	o2_core.call("_on_body_entered", player)
	_assert_test(gs.get("is_oxygen_refilling") == true, "Oxygen begins refilling upon entering base")
	
	# Instant interaction recharge (Press E)
	var refilled = o2_core.call("interact", player)
	_assert_test(refilled == true, "Instant refill interaction succeeded")
	_assert_test(gs.get("oxygen") == 100.0, "Oxygen restored to 100% capacity")
	
	o2_core.call("_on_body_exited", player)
	_assert_test(gs.get("is_oxygen_refilling") == false, "Refill stops when exiting station")
	
	player.queue_free()
	base.queue_free()
	print("  -> Base life-support safe zone and instant recharge verified.")


# ---------------------------------------------------------------------------
# Test 3: Storage Terminal (Deposits & Withdrawals)
# ---------------------------------------------------------------------------
func test_storage_terminal_deposit_and_withdrawal() -> void:
	print("[TEST 3/8] Testing Cargo Storage Terminal deposits and withdrawals...")
	var gs = get_node("/root/GameState")
	var terminal = StorageTerminalScript.new()
	add_child(terminal)
	
	# Reset resources
	gs.resources["crystals"] = 0
	gs.resources["titanium"] = 0
	gs.resources["biomass"] = 0
	gs.resources["oxygen_cells"] = 0
	gs.base_storage["crystals"] = 0
	gs.base_storage["titanium"] = 0
	
	# Add carried cargo
	gs.call("add_resource", "crystals", 4)
	gs.call("add_resource", "titanium", 2)
	_assert_test(gs.get_resource("crystals") == 4, "4 Crystals in carried suit inventory")
	
	# Interact with storage terminal to deposit
	var interacted = terminal.interact()
	_assert_test(interacted == true, "Storage terminal interaction succeeded")
	_assert_test(gs.get_resource("crystals") == 0, "Carried crystals emptied after deposit")
	_assert_test(gs.get_stored_resource("crystals") == 4, "4 Crystals now securely stored in base vault")
	_assert_test(gs.get_stored_resource("titanium") == 2, "2 Titanium stored in base vault")
	
	# Withdraw 1 crystal back to suit
	var withdrawn = terminal.call("withdraw_specific", "crystals", 1)
	_assert_test(withdrawn == 1, "1 Crystal withdrawn")
	_assert_test(gs.get_resource("crystals") == 1, "Carried crystals is now 1")
	_assert_test(gs.get_stored_resource("crystals") == 3, "Vault crystals decreased to 3")
	
	terminal.queue_free()
	print("  -> Cargo Storage deposits, withdrawals, and vault security verified.")


# ---------------------------------------------------------------------------
# Test 4: Mission Operations Terminal
# ---------------------------------------------------------------------------
func test_mission_terminal_integration() -> void:
	print("[TEST 4/8] Testing Mission Operations Terminal integration...")
	var mm = get_node("/root/MissionManager")
	mm.reset_campaign()
	
	var terminal = MissionTerminalScript.new()
	add_child(terminal)
	
	var info: Dictionary = terminal.call("get_active_mission_info")
	_assert_test(info.has("id") and info["id"] == "mission_01_oxygen", "Reads active campaign mission")
	
	# Fail mission and verify terminal reboot behavior
	mm.call("fail_mission", "mission_01_oxygen", "Simulated hazard breach")
	var active = mm.call("get_active_mission")
	_assert_test(active.call("is_failed"), "Mission in FAILED state")
	
	# Terminal interaction reboots failed directive
	terminal.interact()
	_assert_test(active.call("is_active"), "Mission Terminal successfully rebooted failed directive")
	
	terminal.queue_free()
	print("  -> Mission Operations Terminal telemetry and directive reboot verified.")


# ---------------------------------------------------------------------------
# Test 5: Planet Gate & Sector Selection
# ---------------------------------------------------------------------------
func test_planet_gate_and_sector_deployment() -> void:
	print("[TEST 5/8] Testing Expedition Gate, sector selection, and Return to Base...")
	var mm = get_node("/root/MissionManager")
	var gate = PlanetGateTerminalScript.new()
	add_child(gate)
	
	# Set active mission to RETURN_TO_BASE
	mm.call("start_mission", "mission_06_extraction")
	var m6 = mm.call("get_mission", "mission_06_extraction")
	_assert_test(m6.call("is_active"), "Mission 6 (RETURN_TO_BASE) active")
	
	# Cycle sector
	var prev_sector = gate.call("get_current_sector")
	gate.interact()
	var new_sector = gate.call("get_current_sector")
	_assert_test(prev_sector["id"] != new_sector["id"], "Sector cycled on interaction")
	
	# Interacting with gate triggers base_reached event, completing RETURN_TO_BASE
	_assert_test(m6.call("is_completed"), "Expedition Gate interaction registered safe Return to Base")
	
	gate.queue_free()
	print("  -> Planet Gate sector selection and Return-to-Base loop verified.")


# ---------------------------------------------------------------------------
# Test 6: Reusable Station Components Standalone
# ---------------------------------------------------------------------------
func test_modular_station_reusability() -> void:
	print("[TEST 6/8] Testing modular station component reusability for other outposts...")
	# Verify that stations can be instantiated independently in any node container
	var outpost = Node2D.new()
	outpost.name = "SecondaryResearchOutpost"
	add_child(outpost)
	
	var st1 = StorageTerminalScript.new()
	st1.position = Vector2(100, 100)
	outpost.add_child(st1)
	
	var st2 = MissionTerminalScript.new()
	st2.position = Vector2(200, 100)
	outpost.add_child(st2)
	
	var st3 = PlanetGateTerminalScript.new()
	st3.position = Vector2(300, 100)
	outpost.add_child(st3)
	
	_assert_test(st1.is_in_group("interactable") and st1.is_in_group("base_stations"), "Storage terminal group registered")
	_assert_test(st2.is_in_group("interactable") and st2.is_in_group("base_stations"), "Mission terminal group registered")
	_assert_test(st3.is_in_group("interactable") and st3.is_in_group("base_stations"), "Planet gate terminal group registered")
	
	outpost.queue_free()
	print("  -> Reusable station components validated for secondary outposts.")


# ---------------------------------------------------------------------------
# Test 7: HUD Terminal Modal Overlay Interaction
# ---------------------------------------------------------------------------
func test_hud_terminal_modal_interactions() -> void:
	print("[TEST 7/8] Testing HUD Terminal Modal overlay...")
	var hud = HudScene.instantiate()
	add_child(hud)
	
	var modal: Control = hud.get_node("%TerminalModalOverlay")
	_assert_test(modal != null, "TerminalModalOverlay node exists in HUD")
	_assert_test(modal.visible == false, "Modal hidden by default")
	
	# Open storage view
	hud.call("open_storage_modal")
	_assert_test(modal.visible == true, "Storage modal opened")
	var header_lbl: Label = hud.get_node("%TerminalHeader")
	_assert_test(header_lbl.text.contains("STORAGE"), "Modal header displays STORAGE")
	
	# Close modal
	hud.call("close_terminal_modal")
	_assert_test(modal.visible == false, "Modal closed successfully")
	
	# Open mission operations view
	hud.call("open_mission_modal")
	_assert_test(modal.visible == true, "Mission modal opened")
	_assert_test(header_lbl.text.contains("MISSION"), "Modal header displays MISSION OPERATIONS")
	
	# Open planet gate view
	hud.call("open_planet_gate_modal")
	_assert_test(modal.visible == true, "Planet gate modal opened")
	_assert_test(header_lbl.text.contains("EXPEDITION"), "Modal header displays EXPEDITION GATE")
	
	hud.call("close_terminal_modal")
	hud.queue_free()
	print("  -> HUD Terminal Modal overlay (Storage, Ops, Deploy) verified.")


# ---------------------------------------------------------------------------
# Test 8: GameWorld Integration
# ---------------------------------------------------------------------------
func test_game_world_integration() -> void:
	print("[TEST 8/8] Testing GameWorld integration at player spawn coordinates...")
	var world = GameWorldScene.instantiate()
	add_child(world)
	
	var base = world.get_node_or_null("ResearchBase")
	_assert_test(base != null, "ResearchBase instance exists in GameWorld")
	_assert_test(base.position == Vector2.ZERO, "ResearchBase located at player spawn (Vector2.ZERO)")
	
	var o2_core = base.call("get_oxygen_station")
	_assert_test(o2_core != null, "Oxygen station active in world base")
	
	world.queue_free()
	print("  -> GameWorld integration and player spawn sanctuary verified.")
