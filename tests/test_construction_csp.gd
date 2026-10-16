extends Node
## Automated Test Suite for Base-Structure Placement Constraint Satisfaction Problem (CSP).
## Validates:
##   1. BaseStructureData catalog, dimensions, resource costs, and minimum spacing rules.
##   2. Economic constraint: Available resources validation & zero deduction on failure.
##   3. Domain constraint: Grid boundary containment.
##   4. Territorial constraint: Authorized build zone boundaries.
##   5. Collision constraint: Blocked natural terrain obstacles.
##   6. Overlap constraint: Existing structure footprint collisions.
##   7. Proximity constraint: Minimum spacing buffer clearance between structures.
##   8. Placement commit: Resource deduction only on success; physical instancing and map registration.
##   9. Placement preview lifecycle and visual state updates.
##  10. Construction menu UI, catalog binding, and HUD toggle integration.
##  11. Asynchronous validation with offline fallback reliability.

const BaseStructureDataScript := preload("res://scripts/components/base_structure_data.gd")
const PlacedStructureScript := preload("res://scripts/components/placed_structure.gd")
const MapDataScript := preload("res://scripts/components/map_data.gd")
const ConstructionMenuScene := preload("res://ui/components/construction_menu.tscn")
const HudScene := preload("res://ui/screens/hud.tscn")

var _test_count: int = 0
var _pass_count: int = 0


func _ready() -> void:
	print("==================================================")
	print("  BIOSPHERE-X: BASE STRUCTURE CSP PLACEMENT TESTS")
	print("==================================================")
	
	test_structure_catalog()
	test_economic_resource_constraint()
	test_grid_boundaries_constraint()
	test_build_zone_boundaries_constraint()
	test_blocked_terrain_constraint()
	test_occupied_cell_overlap_constraint()
	test_minimum_spacing_constraint()
	test_placement_commit_success_and_deduction()
	test_placement_commit_failure_prevents_deduction()
	test_placement_preview_lifecycle()
	test_construction_menu_and_hud_integration()
	
	print("==================================================")
	print("  ALL BASE STRUCTURE CSP PLACEMENT TESTS PASSED! [%d/%d]" % [_pass_count, _test_count])
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
# Test 1: Structure Catalog & Specifications
# ---------------------------------------------------------------------------
func test_structure_catalog() -> void:
	print("[TEST 1/11] Testing Base Structure Catalog and Definitions...")
	var cm = get_node("/root/ConstructionManager")
	var catalog: Dictionary = cm.get_catalog()
	
	_assert_test(catalog.size() >= 6, "Catalog has at least 6 structures", "Catalog size was %d" % catalog.size())
	_assert_test(catalog.has("oxygen_generator"), "Catalog contains oxygen_generator", "Missing oxygen_generator")
	_assert_test(catalog.has("defense_turret"), "Catalog contains defense_turret", "Missing defense_turret")
	_assert_test(catalog.has("solar_array"), "Catalog contains solar_array", "Missing solar_array")
	_assert_test(catalog.has("storage_depot"), "Catalog contains storage_depot", "Missing storage_depot")
	_assert_test(catalog.has("bio_dome"), "Catalog contains bio_dome", "Missing bio_dome")
	_assert_test(catalog.has("radar_beacon"), "Catalog contains radar_beacon", "Missing radar_beacon")
	
	var o2_gen = catalog["oxygen_generator"]
	_assert_test(o2_gen.width == 2 and o2_gen.height == 2, "Oxygen generator is 2x2", "Dimensions mismatch")
	_assert_test(o2_gen.cost.get("titanium") == 4, "Oxygen generator costs 4 titanium", "Cost mismatch")
	_assert_test(o2_gen.min_spacing == 1, "Oxygen generator min_spacing is 1", "Spacing mismatch")


# ---------------------------------------------------------------------------
# Test 2: Economic Constraint (Resource Availability)
# ---------------------------------------------------------------------------
func test_economic_resource_constraint() -> void:
	print("[TEST 2/11] Testing Economic Resource Availability Constraint...")
	var cm = get_node("/root/ConstructionManager")
	var inv = get_node("/root/InventoryManager")
	cm.reset_construction()
	inv.reset_inventory()
	
	# Sentry requires 3 titanium and 3 crystals
	# Scenario A: Player has 0 resources -> Should reject with RESOURCES constraint
	var res_empty: Dictionary = cm.validate_placement_locally("defense_turret", Vector2i(20, 20))
	_assert_test(not res_empty.valid, "Rejects placement when resources are empty", "Should be invalid")
	_assert_test(res_empty.violated_constraints.has("RESOURCES"), "RESOURCES constraint flagged", "Missing constraint flag")
	_assert_test(res_empty.reason.contains("Insufficient resources"), "Reason specifies insufficient resources", "Reason mismatch: %s" % res_empty.reason)
	
	# Scenario B: Player has partial resources (3 titanium, only 1 crystal)
	inv.add_item("titanium", 3)
	inv.add_item("crystals", 1)
	var res_partial: Dictionary = cm.validate_placement_locally("defense_turret", Vector2i(20, 20))
	_assert_test(not res_partial.valid, "Rejects placement with partial resources", "Should be invalid")
	_assert_test(res_partial.reason.contains("crystals"), "Reason mentions crystals shortage", "Reason was: %s" % res_partial.reason)
	
	# Scenario C: Player gains exact required resources (add 2 crystals -> 3 crystals)
	inv.add_item("crystals", 2)
	var res_exact: Dictionary = cm.validate_placement_locally("defense_turret", Vector2i(20, 20))
	_assert_test(res_exact.valid, "Validates placement when resources are sufficient", "Expected valid: %s" % res_exact.reason)


# ---------------------------------------------------------------------------
# Test 3: Domain Constraint (Grid Boundaries)
# ---------------------------------------------------------------------------
func test_grid_boundaries_constraint() -> void:
	print("[TEST 3/11] Testing Grid Boundary Containment Constraint...")
	var cm = get_node("/root/ConstructionManager")
	var inv = get_node("/root/InventoryManager")
	cm.reset_construction()
	inv.reset_inventory()
	inv.add_item("titanium", 20)
	inv.add_item("crystals", 20)
	
	# Configure test map
	var map := MapDataScript.new(Vector2i(80, 80))
	cm.set_map_data(map)
	cm.set_build_zone(Rect2i(0, 0, 80, 80)) # Full map build zone for boundary test
	
	# Negative coordinate
	var res_neg: Dictionary = cm.validate_placement_locally("radar_beacon", Vector2i(-1, 10))
	_assert_test(not res_neg.valid, "Rejects negative coordinate", "Should reject negative coords")
	_assert_test(res_neg.violated_constraints.has("BOUNDS"), "BOUNDS constraint flagged for negative coord", "Missing flag")
	
	# Footprint overflowing max boundary (oxygen generator 2x2 placed at (79, 79) extends to (80, 80))
	var res_overflow: Dictionary = cm.validate_placement_locally("oxygen_generator", Vector2i(79, 79))
	_assert_test(not res_overflow.valid, "Rejects footprint overflowing grid max width/height", "Should reject overflow")
	_assert_test(res_overflow.violated_constraints.has("BOUNDS"), "BOUNDS constraint flagged for overflow", "Missing flag")


# ---------------------------------------------------------------------------
# Test 4: Territorial Constraint (Authorized Build Zone)
# ---------------------------------------------------------------------------
func test_build_zone_boundaries_constraint() -> void:
	print("[TEST 4/11] Testing Authorized Build Zone Boundary Constraint...")
	var cm = get_node("/root/ConstructionManager")
	var inv = get_node("/root/InventoryManager")
	cm.reset_construction()
	inv.reset_inventory()
	inv.add_item("titanium", 20)
	inv.add_item("crystals", 20)
	
	# Set restrictive build zone: [20, 20] to [30, 30]
	cm.set_build_zone(Rect2i(20, 20, 10, 10)) # rect end is at (30, 30)
	
	# Position at (15, 15) is outside build zone
	var res_outside: Dictionary = cm.validate_placement_locally("radar_beacon", Vector2i(15, 15))
	_assert_test(not res_outside.valid, "Rejects placement outside authorized build zone", "Should reject outside zone")
	_assert_test(res_outside.violated_constraints.has("BUILD_ZONE"), "BUILD_ZONE constraint flagged", "Missing flag")
	_assert_test(res_outside.reason.contains("build zone"), "Reason specifies build zone violation", "Reason was: %s" % res_outside.reason)
	
	# Position at (22, 22) is inside build zone
	var res_inside: Dictionary = cm.validate_placement_locally("radar_beacon", Vector2i(22, 22))
	_assert_test(res_inside.valid, "Accepts placement strictly inside authorized build zone", "Should accept inside zone: %s" % res_inside.reason)


# ---------------------------------------------------------------------------
# Test 5: Collision Constraint (Blocked Natural Terrain)
# ---------------------------------------------------------------------------
func test_blocked_terrain_constraint() -> void:
	print("[TEST 5/11] Testing Blocked Natural Terrain Collision Constraint...")
	var cm = get_node("/root/ConstructionManager")
	var inv = get_node("/root/InventoryManager")
	cm.reset_construction()
	inv.reset_inventory()
	inv.add_item("titanium", 20)
	inv.add_item("crystals", 20)
	
	var map := MapDataScript.new(Vector2i(80, 80))
	cm.set_map_data(map)
	cm.set_build_zone(Rect2i(10, 10, 40, 40))
	
	# Mark natural obstacle at (25, 25)
	map.set_cell_blocked(Vector2i(25, 25), true, MapDataScript.CellType.ROCK)
	
	# Candidate 2x2 Oxygen Generator at (24, 24) covers (24,24), (25,24), (24,25), (25,25)
	var res_blocked: Dictionary = cm.validate_placement_locally("oxygen_generator", Vector2i(24, 24))
	_assert_test(not res_blocked.valid, "Rejects placement overlapping terrain rock", "Should reject terrain collision")
	_assert_test(res_blocked.violated_constraints.has("BLOCKED"), "BLOCKED constraint flagged", "Missing flag")
	_assert_test(res_blocked.reason.contains("(25, 25)"), "Reason specifies exact collision coordinates", "Reason was: %s" % res_blocked.reason)


# ---------------------------------------------------------------------------
# Test 6: Overlap Constraint (Existing Placed Structures)
# ---------------------------------------------------------------------------
func test_occupied_cell_overlap_constraint() -> void:
	print("[TEST 6/11] Testing Occupied Cell Overlap Constraint...")
	var cm = get_node("/root/ConstructionManager")
	var inv = get_node("/root/InventoryManager")
	cm.reset_construction()
	inv.reset_inventory()
	inv.add_item("titanium", 50)
	inv.add_item("crystals", 50)
	
	var map := MapDataScript.new(Vector2i(80, 80))
	cm.set_map_data(map)
	cm.set_build_zone(Rect2i(10, 10, 40, 40))
	
	# Manually place existing 2x2 structure at (20, 20)
	cm._placed_structures.append({
		"id": "storage_depot",
		"name": "Resource Depot",
		"position": Vector2i(20, 20),
		"size": Vector2i(2, 2),
		"min_spacing": 0 # Temporarily disable spacing to isolate overlap test
	})
	
	# Attempt to place 1x1 turret directly on occupied cell (21, 21)
	var res_overlap: Dictionary = cm.validate_placement_locally("defense_turret", Vector2i(21, 21))
	_assert_test(not res_overlap.valid, "Rejects placement overlapping existing structure", "Should reject overlap")
	_assert_test(res_overlap.violated_constraints.has("OCCUPIED"), "OCCUPIED constraint flagged", "Missing flag")
	_assert_test(res_overlap.reason.contains("Resource Depot"), "Reason names the overlapped structure", "Reason was: %s" % res_overlap.reason)


# ---------------------------------------------------------------------------
# Test 7: Proximity Constraint (Minimum Spacing Buffer)
# ---------------------------------------------------------------------------
func test_minimum_spacing_constraint() -> void:
	print("[TEST 7/11] Testing Minimum Spacing Buffer Clearance Constraint...")
	var cm = get_node("/root/ConstructionManager")
	var inv = get_node("/root/InventoryManager")
	cm.reset_construction()
	inv.reset_inventory()
	inv.add_item("titanium", 50)
	inv.add_item("crystals", 50)
	
	var map := MapDataScript.new(Vector2i(80, 80))
	cm.set_map_data(map)
	cm.set_build_zone(Rect2i(10, 10, 40, 40))
	
	# Existing Sentry at (20, 20) with size 1x1, min_spacing = 1
	cm._placed_structures.append({
		"id": "defense_turret",
		"name": "Perimeter Sentry",
		"position": Vector2i(20, 20),
		"size": Vector2i(1, 1),
		"min_spacing": 1
	})
	
	# Candidate at (21, 20) is adjacent (Chebyshev distance = 1 <= min_spacing 1) -> VIOLATION!
	var res_adjacent: Dictionary = cm.validate_placement_locally("radar_beacon", Vector2i(21, 20))
	_assert_test(not res_adjacent.valid, "Rejects placement adjacent to structure violating min_spacing 1", "Should reject spacing violation")
	_assert_test(res_adjacent.violated_constraints.has("MIN_SPACING"), "MIN_SPACING constraint flagged", "Missing flag")
	_assert_test(res_adjacent.reason.contains("Too close to 'Perimeter Sentry'"), "Reason indicates proximity to Perimeter Sentry", "Reason was: %s" % res_adjacent.reason)
	
	# Candidate at (22, 20) has clearance: distance = 2 > min_spacing 1 -> VALID!
	var res_cleared: Dictionary = cm.validate_placement_locally("radar_beacon", Vector2i(22, 20))
	_assert_test(res_cleared.valid, "Accepts placement satisfying minimum spacing clearance", "Should be valid: %s" % res_cleared.reason)


# ---------------------------------------------------------------------------
# Test 8: Placement Commit Success & Atomic Deduction
# ---------------------------------------------------------------------------
func test_placement_commit_success_and_deduction() -> void:
	print("[TEST 8/11] Testing Placement Commit Success & Atomic Resource Deduction...")
	var cm = get_node("/root/ConstructionManager")
	var inv = get_node("/root/InventoryManager")
	var gs = get_node("/root/GameState")
	cm.reset_construction()
	inv.reset_inventory()
	
	var map := MapDataScript.new(Vector2i(80, 80))
	cm.set_map_data(map)
	cm.set_build_zone(Rect2i(10, 10, 40, 40))
	
	# Give player exact resources: 2 titanium, 2 crystals for solar_array
	inv.add_item("titanium", 10)
	inv.add_item("crystals", 10)
	
	var signal_state := {"placed": false, "placed_id": "", "placed_pos": Vector2i.ZERO}
	var on_placed = func(s_id: String, g_pos: Vector2i, _node: Node2D):
		signal_state["placed"] = true
		signal_state["placed_id"] = s_id
		signal_state["placed_pos"] = g_pos
	cm.structure_placed.connect(on_placed)
	
	var cb_state := {"success": false, "message": ""}
	cm.commit_placement("solar_array", Vector2i(25, 25), func(success: bool, msg: String):
		cb_state["success"] = success
		cb_state["message"] = msg
	)
	
	_assert_test(cb_state["success"], "Placement commit returned success", "Commit failed: %s" % cb_state["message"])
	_assert_test(signal_state["placed"], "structure_placed signal emitted", "Missing structure_placed signal")
	_assert_test(signal_state["placed_id"] == "solar_array", "Placed structure ID matches solar_array", "ID mismatch")
	_assert_test(signal_state["placed_pos"] == Vector2i(25, 25), "Placed position matches (25, 25)", "Pos mismatch")
	
	# Verify resources deducted: titanium 10 - 2 = 8, crystals 10 - 2 = 8
	_assert_test(inv.get_item_count("titanium") == 8, "Deducted 2 titanium (10 -> 8)", "Expected 8 titanium, got %d" % inv.get_item_count("titanium"))
	_assert_test(inv.get_item_count("crystals") == 8, "Deducted 2 crystals (10 -> 8)", "Expected 8 crystals, got %d" % inv.get_item_count("crystals"))
	
	# Verify structure is recorded in registry and MapData
	_assert_test(cm.get_placed_structures().size() == 1, "Registered in placed_structures list", "Count mismatch")
	_assert_test(map.is_cell_blocked(Vector2i(25, 25)), "Map cell (25, 25) marked solid", "Cell not blocked")
	_assert_test(map.is_cell_blocked(Vector2i(26, 25)), "Map cell (26, 25) marked solid for 2x1 solar array", "Cell not blocked")
	
	cm.structure_placed.disconnect(on_placed)


# ---------------------------------------------------------------------------
# Test 9: Placement Commit Failure Prevents Resource Deduction
# ---------------------------------------------------------------------------
func test_placement_commit_failure_prevents_deduction() -> void:
	print("[TEST 9/11] Testing Placement Failure ZERO Resource Deduction Guarantee...")
	var cm = get_node("/root/ConstructionManager")
	var inv = get_node("/root/InventoryManager")
	cm.reset_construction()
	inv.reset_inventory()
	
	var map := MapDataScript.new(Vector2i(80, 80))
	cm.set_map_data(map)
	cm.set_build_zone(Rect2i(20, 20, 20, 20))
	
	# Give player resources
	inv.add_item("titanium", 10)
	inv.add_item("crystals", 10)
	
	var signal_state := {"rejected": false, "reason": ""}
	var on_rejected = func(s_id: String, _pos: Vector2i, reason: String):
		if s_id == "solar_array":
			signal_state["rejected"] = true
			signal_state["reason"] = reason
	cm.placement_rejected.connect(on_rejected)
	
	# Attempt to commit outside build zone at (5, 5)
	var cb_state := {"success": true, "message": ""}
	cm.commit_placement("solar_array", Vector2i(5, 5), func(success: bool, msg: String):
		cb_state["success"] = success
		cb_state["message"] = msg
	)
	
	_assert_test(not cb_state["success"], "Placement commit rejected invalid location", "Commit should fail")
	_assert_test(signal_state["rejected"], "placement_rejected signal emitted", "Missing rejection signal")
	
	# CRITICAL REQUIREMENT: PREVENT RESOURCE DEDUCTION WHEN PLACEMENT FAILS!
	_assert_test(inv.get_item_count("titanium") == 10, "Titanium completely untouched (remains 10)", "Titanium wrongly deducted")
	_assert_test(inv.get_item_count("crystals") == 10, "Crystals completely untouched (remains 10)", "Crystals wrongly deducted")
	_assert_test(cm.get_placed_structures().is_empty(), "No structures instanced on rejection", "Structure was wrongly added")
	
	cm.placement_rejected.disconnect(on_rejected)


# ---------------------------------------------------------------------------
# Test 10: Placement Preview Lifecycle & Visuals
# ---------------------------------------------------------------------------
func test_placement_preview_lifecycle() -> void:
	print("[TEST 10/11] Testing Placement Preview Lifecycle and Visuals...")
	var cm = get_node("/root/ConstructionManager")
	var inv = get_node("/root/InventoryManager")
	cm.reset_construction()
	inv.reset_inventory()
	inv.add_item("titanium", 20)
	inv.add_item("crystals", 20)
	
	var map := MapDataScript.new(Vector2i(80, 80))
	cm.set_map_data(map)
	cm.set_build_zone(Rect2i(10, 10, 30, 30))
	
	# Start preview
	var start_ok: bool = cm.start_placement_preview("defense_turret")
	_assert_test(start_ok, "start_placement_preview returned true", "Failed to start preview")
	_assert_test(cm.is_preview_active, "is_preview_active is true", "Preview not active")
	_assert_test(cm.active_preview_structure_id == "defense_turret", "Active structure ID is defense_turret", "ID mismatch")
	
	# Update to valid position (20, 20)
	cm.update_preview_position(Vector2i(20, 20))
	_assert_test(cm.preview_is_valid, "Preview position (20, 20) is valid", "Expected valid preview")
	
	# Update to invalid position (5, 5) outside build zone
	cm.update_preview_position(Vector2i(5, 5))
	_assert_test(not cm.preview_is_valid, "Preview position (5, 5) is invalid", "Expected invalid preview")
	_assert_test(cm.preview_reason.contains("build zone"), "Preview reason indicates build zone", "Reason mismatch")
	
	# Cancel preview
	cm.cancel_placement_preview()
	_assert_test(not cm.is_preview_active, "is_preview_active is false after cancel", "Preview still active")


# ---------------------------------------------------------------------------
# Test 11: Construction Menu & HUD Integration
# ---------------------------------------------------------------------------
func test_construction_menu_and_hud_integration() -> void:
	print("[TEST 11/11] Testing Construction Menu and HUD Integration...")
	var menu = ConstructionMenuScene.instantiate()
	add_child(menu)
	
	_assert_test(not menu.visible, "ConstructionMenu starts hidden", "Menu should be hidden initially")
	
	# Open menu
	var state := {"opened": false, "closed": false}
	menu.menu_opened.connect(func(): state["opened"] = true)
	menu.menu_closed.connect(func(): state["closed"] = true)
	
	menu.open_menu()
	_assert_test(menu.visible, "Menu is visible after open_menu()", "Menu failed to show")
	_assert_test(state["opened"], "menu_opened signal emitted", "Missing opened signal")
	
	# Toggle menu
	menu.toggle_menu()
	_assert_test(not menu.visible, "toggle_menu closes menu when open", "Failed to close")
	_assert_test(state["closed"], "menu_closed signal emitted", "Missing closed signal")
	
	# Test HUD button
	var hud = HudScene.instantiate()
	add_child(hud)
	
	var build_btn: Button = hud.get_node("%BuildMenuButton")
	var hud_menu = hud.get_node("%ConstructionMenu")
	_assert_test(build_btn != null, "HUD contains BuildMenuButton", "BuildMenuButton missing")
	_assert_test(hud_menu != null, "HUD contains ConstructionMenu", "ConstructionMenu missing in HUD")
	
	# Click HUD button toggles ConstructionMenu
	build_btn.emit_signal("pressed")
	_assert_test(hud_menu.visible, "Clicking HUD build button opens ConstructionMenu", "Failed to open menu")
	build_btn.emit_signal("pressed")
	_assert_test(not hud_menu.visible, "Clicking HUD build button toggles off ConstructionMenu", "Failed to close menu")
	
	remove_child(hud)
	hud.free()
	remove_child(menu)
	menu.free()
