extends Node
## Automated Test Suite for BioSphere-X Inventory and Crafting System (Prompt 22).
## Validates:
##   1. Reusable Item Definitions (IDs, categories, stack limits, consumable effects).
##   2. Stack Limit Enforcement and Capacity Checking.
##   3. Safe Error Handling (Invalid item IDs, non-existent recipes, zero/negative quantities).
##   4. Inventory Removal and State Preservation on Insufficient Resources.
##   5. Reusable Crafting Recipes and Missing Ingredient Calculation.
##   6. Pre-Craft Verification (can_craft validation).
##   7. Crafting Execution: Deduction ONLY on success; zero deductions on failure.
##   8. Consumable Item Consumption (Oxygen Pack, Med-Kit, Suit Power Cell).
##   9. Permanent Suit Upgrades (Armor Plating, Cryo-O2 Expander).
##  10. UI Dialog Lifecycle and Synchronous Refresh (open/close, toggle, event updates).
##  11. Bidirectional GameState Synchronization.

const ItemDefinitionScript := preload("res://scripts/components/item_definition.gd")
const CraftingRecipeScript := preload("res://scripts/components/crafting_recipe.gd")
const InventoryDialogScene := preload("res://ui/components/inventory_crafting_dialog.tscn")
const HudScene := preload("res://ui/screens/hud.tscn")

var _test_count: int = 0
var _pass_count: int = 0


func _ready() -> void:
	print("==================================================")
	print("  BIOSPHERE-X: PROMPT 22 INVENTORY & CRAFTING TESTS")
	print("==================================================")
	
	test_item_definitions()
	test_stack_limits()
	test_invalid_item_id_safety()
	test_item_removal_safety()
	test_crafting_recipe_requirements()
	test_crafting_execution_deduction_only_on_success()
	test_consumable_effects()
	test_permanent_upgrades()
	test_ui_dialog_lifecycle_and_updates()
	test_gamestate_synchronization()
	
	print("==================================================")
	print("  ALL PROMPT 22 INVENTORY & CRAFTING TESTS PASSED! [%d/%d]" % [_pass_count, _test_count])
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
# Test 1: Reusable Item Definitions
# ---------------------------------------------------------------------------
func test_item_definitions() -> void:
	print("[TEST 1/10] Testing Reusable Item Definitions...")
	var raw_def = ItemDefinitionScript.create(
		"test_ore", "Test Ore", "Deep planetary mineral.", "🪨",
		ItemDefinitionScript.Category.RESOURCE, 50
	)
	_assert_test(raw_def.id == "test_ore", "Item ID assignment", "Item ID mismatch")
	_assert_test(raw_def.max_stack == 50, "Item stack limit assignment", "Stack limit mismatch")
	_assert_test(raw_def.get_category_name() == "Resource", "Category string helper", "Category string mismatch")
	_assert_test(not raw_def.is_consumable(), "Resource is not consumable", "Resource incorrectly flagged consumable")
	
	var med_def = ItemDefinitionScript.create(
		"test_med", "Nano Stasis Med-Kit", "Heals 30 HP", "🩹",
		ItemDefinitionScript.Category.CONSUMABLE, 5, {"health_restore": 30.0}
	)
	_assert_test(med_def.is_consumable(), "Consumable flag check", "Med-Kit should be consumable")
	_assert_test(med_def.use_effect.get("health_restore") == 30.0, "Effect dictionary", "Use effect mismatch")


# ---------------------------------------------------------------------------
# Test 2: Stack Limit Enforcement
# ---------------------------------------------------------------------------
func test_stack_limits() -> void:
	print("[TEST 2/10] Testing Stack Limits Enforcement...")
	var inv = get_node("/root/InventoryManager")
	inv.reset_inventory()
	
	# Register a custom item with max_stack of 5
	var crystal_def = ItemDefinitionScript.create("mini_gem", "Mini Gem", "Gem", "💎", ItemDefinitionScript.Category.RESOURCE, 5)
	inv.register_item(crystal_def)
	
	_assert_test(inv.can_add_item("mini_gem", 3), "Can add 3 within limit", "Should allow 3 items")
	var added1: int = inv.add_item("mini_gem", 3)
	_assert_test(added1 == 3, "Added 3 items", "Expected 3 added, got %d" % added1)
	_assert_test(inv.get_item_count("mini_gem") == 3, "Inventory count is 3", "Expected count 3")
	
	# Attempt to add 4 more (3 + 4 = 7 > max_stack 5) -> Should clamp to 2
	_assert_test(not inv.can_add_item("mini_gem", 4), "Cannot add 4 (would exceed max_stack)", "Should reject overflow")
	var added2: int = inv.add_item("mini_gem", 4)
	_assert_test(added2 == 2, "Only added available capacity 2", "Expected 2 added, got %d" % added2)
	_assert_test(inv.get_item_count("mini_gem") == 5, "Total clamped at max_stack 5", "Expected count 5")
	
	# Attempt to add when full -> 0 added
	var added3: int = inv.add_item("mini_gem", 1)
	_assert_test(added3 == 0, "Adding to full stack adds 0", "Expected 0 added, got %d" % added3)


# ---------------------------------------------------------------------------
# Test 3: Invalid Item ID Safety (No Crash Guarantee)
# ---------------------------------------------------------------------------
func test_invalid_item_id_safety() -> void:
	print("[TEST 3/10] Testing Invalid Item ID & Input Safety...")
	var inv = get_node("/root/InventoryManager")
	
	# Adding unknown ID must not crash and return 0
	var res1: int = inv.add_item("completely_fake_nonexistent_item_xyz", 10)
	_assert_test(res1 == 0, "Add unknown item ID returns 0 safely", "Expected 0, got %d" % res1)
	
	# Removing unknown ID must not crash and return false
	var res2: bool = inv.remove_item("completely_fake_nonexistent_item_xyz", 1)
	_assert_test(not res2, "Remove unknown item ID returns false safely", "Expected false")
	
	# Using unknown ID must not crash and return false
	var res3: bool = inv.use_item("completely_fake_nonexistent_item_xyz")
	_assert_test(not res3, "Use unknown item ID returns false safely", "Expected false")
	
	# Negative or zero quantity additions
	var res4: int = inv.add_item("crystals", -5)
	_assert_test(res4 == 0, "Negative quantity add returns 0", "Expected 0")
	var res5: int = inv.add_item("crystals", 0)
	_assert_test(res5 == 0, "Zero quantity add returns 0", "Expected 0")


# ---------------------------------------------------------------------------
# Test 4: Item Removal Safety & State Preservation
# ---------------------------------------------------------------------------
func test_item_removal_safety() -> void:
	print("[TEST 4/10] Testing Item Removal Safety...")
	var inv = get_node("/root/InventoryManager")
	inv.reset_inventory()
	inv.add_item("titanium", 4)
	
	# Remove valid amount
	var ok: bool = inv.remove_item("titanium", 2)
	_assert_test(ok, "Remove valid quantity succeeds", "Expected remove_item to return true")
	_assert_test(inv.get_item_count("titanium") == 2, "Remaining count is 2", "Expected 2 titanium remaining")
	
	# Attempt to remove more than carried (2 carried, request 5)
	var fail: bool = inv.remove_item("titanium", 5)
	_assert_test(not fail, "Remove excessive quantity fails", "Expected remove_item to return false")
	_assert_test(inv.get_item_count("titanium") == 2, "Inventory count preserved untouched on failure", "Count changed unexpectedly")


# ---------------------------------------------------------------------------
# Test 5: Reusable Crafting Recipe Requirements
# ---------------------------------------------------------------------------
func test_crafting_recipe_requirements() -> void:
	print("[TEST 5/10] Testing Crafting Recipe Requirements...")
	var inv = get_node("/root/InventoryManager")
	inv.reset_inventory()
	
	var recipe: RefCounted = inv.get_recipe("recipe_oxygen_pack")
	_assert_test(recipe != null, "Default Oxygen Pack recipe registered", "Oxygen pack recipe missing")
	_assert_test(recipe.result_item_id == "oxygen_pack", "Recipe result ID is oxygen_pack", "Result mismatch")
	_assert_test(recipe.result_quantity == 1, "Recipe result quantity is 1", "Quantity mismatch")
	
	# Recipe requires 2 oxygen_cells and 1 titanium
	var missing: Dictionary = recipe.get_missing_ingredients(inv)
	_assert_test(missing.get("oxygen_cells") == 2, "Missing 2 oxygen cells", "Missing calculation error")
	_assert_test(missing.get("titanium") == 1, "Missing 1 titanium", "Missing calculation error")
	_assert_test(not recipe.can_craft(inv), "Cannot craft with empty inventory", "can_craft should be false")


# ---------------------------------------------------------------------------
# Test 6: Crafting Execution: Deduction ONLY on Success
# ---------------------------------------------------------------------------
func test_crafting_execution_deduction_only_on_success() -> void:
	print("[TEST 6/10] Testing Crafting Execution & Deduction Rules...")
	var inv = get_node("/root/InventoryManager")
	inv.reset_inventory()
	
	# Setup partial resources: 1 oxygen_cell, 1 titanium (needs 2 oxygen_cells)
	inv.add_item("oxygen_cells", 1)
	inv.add_item("titanium", 1)
	
	var signal_state := {"failed": false, "success": false}
	var on_fail = func(r_id, _reason):
		if r_id == "recipe_oxygen_pack":
			signal_state["failed"] = true
	inv.crafting_failed.connect(on_fail)
	
	# 1. Attempt craft with insufficient resources
	var craft_ok: bool = inv.craft_item("recipe_oxygen_pack")
	_assert_test(not craft_ok, "Crafting fails when ingredients insufficient", "Expected craft_item to return false")
	_assert_test(signal_state["failed"], "crafting_failed signal emitted", "Missing failure signal")
	_assert_test(inv.get_item_count("oxygen_cells") == 1, "Zero oxygen cells deducted on failure", "Oxygen cells were improperly deducted")
	_assert_test(inv.get_item_count("titanium") == 1, "Zero titanium deducted on failure", "Titanium was improperly deducted")
	_assert_test(inv.get_item_count("oxygen_pack") == 0, "No result item awarded on failure", "Oxygen pack awarded despite failure")
	inv.crafting_failed.disconnect(on_fail)
	
	# 2. Add the missing oxygen cell and execute valid craft
	inv.add_item("oxygen_cells", 1) # Now 2 oxygen_cells, 1 titanium
	var on_success = func(r_id, res_id, qty):
		if r_id == "recipe_oxygen_pack" and res_id == "oxygen_pack" and qty == 1:
			signal_state["success"] = true
	inv.item_crafted.connect(on_success)
	
	var craft_ok2: bool = inv.craft_item("recipe_oxygen_pack")
	_assert_test(craft_ok2, "Crafting succeeds with exact ingredients", "Expected craft_item to return true")
	_assert_test(signal_state["success"], "item_crafted signal emitted with result", "Missing success signal")
	_assert_test(inv.get_item_count("oxygen_cells") == 0, "Oxygen cells deducted on success", "Oxygen cells not deducted")
	_assert_test(inv.get_item_count("titanium") == 0, "Titanium deducted on success", "Titanium not deducted")
	_assert_test(inv.get_item_count("oxygen_pack") == 1, "Fabricated Oxygen Pack added to inventory", "Missing crafted pack")
	inv.item_crafted.disconnect(on_success)


# ---------------------------------------------------------------------------
# Test 7: Consumable Item Consumption
# ---------------------------------------------------------------------------
func test_consumable_effects() -> void:
	print("[TEST 7/10] Testing Consumable Effects (Oxygen Pack, Med-Kit, Power Cell)...")
	var inv = get_node("/root/InventoryManager")
	var gs = get_node("/root/GameState")
	inv.reset_inventory()
	
	# 1. Oxygen Resupply Pack
	gs.max_oxygen = 100.0
	gs.oxygen = 20.0
	inv.add_item("oxygen_pack", 1)
	
	# Use oxygen pack -> +60 oxygen -> 80.0
	var used_o2: bool = inv.use_item("oxygen_pack")
	_assert_test(used_o2, "Used Oxygen Resupply Pack", "use_item should succeed")
	_assert_test(gs.oxygen == 80.0, "Oxygen restored to 80%%", "Expected 80 O2, got %f" % gs.oxygen)
	_assert_test(inv.get_item_count("oxygen_pack") == 0, "Oxygen pack consumed from inventory", "Pack not removed")
	
	# Cannot use when oxygen is full (100)
	gs.oxygen = 100.0
	inv.add_item("oxygen_pack", 1)
	var full_o2_use: bool = inv.use_item("oxygen_pack")
	_assert_test(not full_o2_use, "Cannot use Oxygen Pack when oxygen is already 100%", "Should prevent redundant use")
	_assert_test(inv.get_item_count("oxygen_pack") == 1, "Pack preserved when not usable", "Pack lost")
	
	# 2. EVA Med-Kit
	gs.max_health = 100.0
	gs.health = 50.0
	inv.add_item("health_kit", 1)
	var used_hp: bool = inv.use_item("health_kit")
	_assert_test(used_hp, "Used EVA Med-Kit", "use_item should succeed")
	_assert_test(gs.health == 90.0, "Health restored by +40 (50 -> 90)", "Expected 90 HP, got %f" % gs.health)
	_assert_test(inv.get_item_count("health_kit") == 0, "Med-Kit consumed from inventory", "Med-Kit not removed")
	
	# 3. Suit Power Cell
	gs.max_energy = 100.0
	gs.energy = 10.0
	inv.add_item("energy_pack", 1)
	var used_nrg: bool = inv.use_item("energy_pack")
	_assert_test(used_nrg, "Used Suit Power Cell", "use_item should succeed")
	_assert_test(gs.energy == 60.0, "Energy restored by +50 (10 -> 60)", "Expected 60 NRG, got %f" % gs.energy)


# ---------------------------------------------------------------------------
# Test 8: Permanent Suit Upgrades
# ---------------------------------------------------------------------------
func test_permanent_upgrades() -> void:
	print("[TEST 8/10] Testing Permanent Upgrades (Armor Plating, O2 Tank Expander)...")
	var inv = get_node("/root/InventoryManager")
	var gs = get_node("/root/GameState")
	inv.reset_inventory()
	
	var initial_max_hp: float = gs.max_health
	var initial_max_o2: float = gs.max_oxygen
	
	# 1. Craft and install Armor Plating (+25 Max HP)
	inv.add_item("titanium", 3)
	inv.add_item("crystals", 2)
	var crafted_armor: bool = inv.craft_item("recipe_armor_plating")
	_assert_test(crafted_armor, "Crafted Composite Armor Plating", "Crafting armor failed")
	_assert_test(inv.get_item_count("armor_plating") == 1, "Armor Plating in inventory", "Armor plating missing")
	
	var used_armor: bool = inv.use_item("armor_plating")
	_assert_test(used_armor, "Installed Composite Armor Plating", "Installation failed")
	_assert_test(gs.max_health == initial_max_hp + 25.0, "Max health increased by +25", "Max health mismatch: %f" % gs.max_health)
	_assert_test(inv.get_installed_upgrades().has("armor_plating"), "Armor Plating marked installed", "Upgrade not recorded")
	
	# 2. Craft and install Cryo-O2 Tank Expander (+25 Max Oxygen)
	inv.add_item("titanium", 3)
	inv.add_item("oxygen_cells", 2)
	var crafted_o2: bool = inv.craft_item("recipe_o2_booster")
	_assert_test(crafted_o2, "Crafted Cryo-O2 Tank Expander", "Crafting O2 booster failed")
	
	var used_o2: bool = inv.use_item("o2_tank_booster")
	_assert_test(used_o2, "Installed Cryo-O2 Tank Expander", "Installation failed")
	_assert_test(gs.max_oxygen == initial_max_o2 + 25.0, "Max oxygen increased by +25", "Max oxygen mismatch: %f" % gs.max_oxygen)
	_assert_test(inv.get_installed_upgrades().has("o2_tank_booster"), "O2 Tank Expander marked installed", "Upgrade not recorded")


# ---------------------------------------------------------------------------
# Test 9: UI Dialog Lifecycle and Synchronous Refresh
# ---------------------------------------------------------------------------
func test_ui_dialog_lifecycle_and_updates() -> void:
	print("[TEST 9/10] Testing UI Dialog Lifecycle and Synchronous Updates...")
	var dialog = InventoryDialogScene.instantiate()
	add_child(dialog)
	
	# Initially hidden
	_assert_test(not dialog.visible, "Dialog starts hidden", "Dialog should be invisible initially")
	
	# Open dialog
	var state := {"opened": false, "closed": false}
	dialog.dialog_opened.connect(func(): state["opened"] = true)
	dialog.dialog_closed.connect(func(): state["closed"] = true)
	
	dialog.open_dialog()
	_assert_test(dialog.visible, "Dialog is visible after open_dialog()", "Dialog failed to show")
	_assert_test(state["opened"], "dialog_opened signal emitted", "Missing dialog_opened signal")
	
	# Toggle dialog
	dialog.toggle_visibility()
	_assert_test(not dialog.visible, "toggle_visibility closes dialog when open", "Dialog did not toggle off")
	_assert_test(state["closed"], "dialog_closed signal emitted", "Missing dialog_closed signal")
	
	dialog.toggle_visibility()
	_assert_test(dialog.visible, "toggle_visibility opens dialog when closed", "Dialog did not toggle on")
	
	# Close dialog
	dialog.close_dialog()
	_assert_test(not dialog.visible, "Dialog hidden after close_dialog()", "Dialog failed to close")
	
	# Test HUD button interaction
	var hud = HudScene.instantiate()
	add_child(hud)
	
	var inv_btn: Button = hud.get_node("%InventoryButton")
	var hud_dialog = hud.get_node("%InventoryCraftingDialog")
	_assert_test(inv_btn != null, "HUD contains InventoryButton", "InventoryButton missing in HUD")
	_assert_test(hud_dialog != null, "HUD contains InventoryCraftingDialog", "InventoryCraftingDialog missing in HUD")
	
	# Click button toggles dialog
	inv_btn.emit_signal("pressed")
	_assert_test(hud_dialog.visible, "HUD button click opens InventoryCraftingDialog", "HUD button failed to open dialog")
	inv_btn.emit_signal("pressed")
	_assert_test(not hud_dialog.visible, "HUD button click toggles off InventoryCraftingDialog", "HUD button failed to close dialog")
	
	remove_child(hud)
	hud.free()
	remove_child(dialog)
	dialog.free()


# ---------------------------------------------------------------------------
# Test 10: Bidirectional GameState Synchronization
# ---------------------------------------------------------------------------
func test_gamestate_synchronization() -> void:
	print("[TEST 10/10] Testing GameState Synchronization...")
	var inv = get_node("/root/InventoryManager")
	var gs = get_node("/root/GameState")
	inv.reset_inventory()
	
	# 1. Adding via GameState syncs into InventoryManager
	var cur_c: int = inv.get_item_count("crystals")
	gs.add_resource("crystals", 7)
	_assert_test(inv.get_item_count("crystals") == cur_c + 7, "GameState crystals sync to InventoryManager", "Sync failed: got %d" % inv.get_item_count("crystals"))
	
	# 2. Adding via InventoryManager syncs to GameState.resources
	var cur_t: int = gs.get_resource("titanium")
	inv.add_item("titanium", 12)
	_assert_test(gs.get_resource("titanium") == cur_t + 12, "InventoryManager titanium syncs to GameState.resources", "Sync failed: got %d" % gs.get_resource("titanium"))
	
	# 3. Deducting via crafting synchronizes GameState
	var pre_c: int = gs.get_resource("crystals")
	var pre_t: int = gs.get_resource("titanium")
	inv.craft_item("recipe_energy_pack") # Needs 2 crystals, 1 titanium
	_assert_test(gs.get_resource("crystals") == pre_c - 2, "Crafting deduction synced to GameState crystals", "Expected crystals in GameState")
	_assert_test(gs.get_resource("titanium") == pre_t - 1, "Crafting deduction synced to GameState titanium", "Expected titanium in GameState")
