extends Node
## Central Inventory and Crafting Subsystem for BioSphere-X.
## Manages item definitions, stack limits, consumable/upgrade usage,
## crafting recipe requirements validation, and decoupled UI event synchronization.

signal inventory_changed()
signal item_added(item_id: String, quantity_added: int, new_total: int)
signal item_removed(item_id: String, quantity_removed: int, new_total: int)
signal item_used(item_id: String, item_data: Dictionary)
signal item_crafted(recipe_id: String, result_item_id: String, quantity: int)
signal crafting_failed(recipe_id: String, reason: String)

const ItemDefinitionScript := preload("res://scripts/components/item_definition.gd")
const CraftingRecipeScript := preload("res://scripts/components/crafting_recipe.gd")

# Registries
var _item_registry: Dictionary = {}
var _recipes: Dictionary = {}
var _recipe_order: Array[String] = []

# Inventory Storage (item_id -> quantity: int)
var _items: Dictionary = {}
var _installed_upgrades: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_default_items()
	_register_default_recipes()
	_connect_game_state()


# ---------------------------------------------------------------------------
# Default Item & Recipe Registrations
# ---------------------------------------------------------------------------
func _register_default_items() -> void:
	_item_registry.clear()
	
	# 1. Raw Resources (Stack limit 99)
	register_item(ItemDefinitionScript.create(
		"crystals", "Energy Crystals", "Piezoelectric alien mineral used in plasma tech and fabrication.", "⚡",
		ItemDefinitionScript.Category.RESOURCE, 99
	))
	register_item(ItemDefinitionScript.create(
		"titanium", "Titanium Alloy", "Refined structural metal for equipment fabrication and armor reinforcement.", "⛏",
		ItemDefinitionScript.Category.RESOURCE, 99
	))
	register_item(ItemDefinitionScript.create(
		"biomass", "Alien Biomass", "Organic tissue harvested from indigenous flora and fauna for biochemical synthesis.", "🧬",
		ItemDefinitionScript.Category.RESOURCE, 99
	))
	register_item(ItemDefinitionScript.create(
		"oxygen_cells", "Oxygen Cell", "Pressurized atmospheric canister. Can be consumed directly or fabricated into packs.", "🫧",
		ItemDefinitionScript.Category.CONSUMABLE, 20, {"oxygen_restore": 30.0}
	))
	
	# 2. Fabricated Consumables (Stack limit 5)
	register_item(ItemDefinitionScript.create(
		"oxygen_pack", "Oxygen Resupply Pack", "High-capacity emergency life-support scrubber. Restores 60% oxygen reserves.", "🫁",
		ItemDefinitionScript.Category.CONSUMABLE, 5, {"oxygen_restore": 60.0}
	))
	register_item(ItemDefinitionScript.create(
		"health_kit", "EVA Med-Kit", "Synthesized bio-gel and coagulants. Restores 40 vitality points.", "🩹",
		ItemDefinitionScript.Category.CONSUMABLE, 5, {"health_restore": 40.0}
	))
	register_item(ItemDefinitionScript.create(
		"energy_pack", "Suit Power Cell", "High-discharge capacitor cell. Instantly recharges 50% suit combat energy.", "🔋",
		ItemDefinitionScript.Category.CONSUMABLE, 5, {"energy_restore": 50.0}
	))
	
	# 3. Permanent Upgrades (Stack limit 1)
	register_item(ItemDefinitionScript.create(
		"armor_plating", "EVA Composite Plating", "Reinforced ceramic armor insert. Permanently increases max health by +25.", "🛡️",
		ItemDefinitionScript.Category.UPGRADE, 1, {"max_health_bonus": 25.0}
	))
	register_item(ItemDefinitionScript.create(
		"o2_tank_booster", "Cryo-O2 Tank Expander", "Auxiliary cryogenic tank fitting. Permanently increases max oxygen capacity by +25.", "🎽",
		ItemDefinitionScript.Category.UPGRADE, 1, {"max_oxygen_bonus": 25.0}
	))


func _register_default_recipes() -> void:
	_recipes.clear()
	_recipe_order.clear()
	
	# Recipe 1: Oxygen Pack
	register_recipe(CraftingRecipeScript.create(
		"recipe_oxygen_pack",
		"Oxygen Resupply Pack",
		"Fabricate high-capacity life-support pack (Restores 60% O2).",
		"oxygen_pack", 1,
		{"oxygen_cells": 2, "titanium": 1}
	))
	
	# Recipe 2: EVA Med-Kit
	register_recipe(CraftingRecipeScript.create(
		"recipe_health_kit",
		"EVA Med-Kit",
		"Synthesize medical coagulants to restore 40 vitality points.",
		"health_kit", 1,
		{"biomass": 2, "crystals": 1}
	))
	
	# Recipe 3: Suit Power Cell
	register_recipe(CraftingRecipeScript.create(
		"recipe_energy_pack",
		"Suit Power Cell",
		"Fabricate rapid-discharge capacitor cell (Restores 50 PWR).",
		"energy_pack", 1,
		{"crystals": 2, "titanium": 1}
	))
	
	# Recipe 4: Composite Armor Plating (Permanent Upgrade)
	register_recipe(CraftingRecipeScript.create(
		"recipe_armor_plating",
		"EVA Composite Plating",
		"Reinforce suit weave with titanium composite (+25 Max Health).",
		"armor_plating", 1,
		{"titanium": 3, "crystals": 2}
	))
	
	# Recipe 5: Cryo-O2 Tank Expander (Permanent Upgrade)
	register_recipe(CraftingRecipeScript.create(
		"recipe_o2_booster",
		"Cryo-O2 Tank Expander",
		"Expand suit life-support reservoir (+25 Max Oxygen).",
		"o2_tank_booster", 1,
		{"titanium": 3, "oxygen_cells": 2}
	))


func register_item(item_def: RefCounted) -> void:
	if not item_def:
		return
	var item_id: String = item_def.get("id")
	_item_registry[item_id] = item_def


func register_recipe(recipe: RefCounted) -> void:
	if not recipe:
		return
	var r_id: String = recipe.get("recipe_id")
	_recipes[r_id] = recipe
	if not _recipe_order.has(r_id):
		_recipe_order.append(r_id)


# ---------------------------------------------------------------------------
# Bidirectional GameState Synchronization
# ---------------------------------------------------------------------------
func _connect_game_state() -> void:
	var gs := get_node_or_null("/root/GameState")
	if gs and gs.has_signal("resource_changed"):
		if not gs.is_connected("resource_changed", _on_game_state_resource_changed):
			gs.connect("resource_changed", _on_game_state_resource_changed)


func _on_game_state_resource_changed(resource_id: String, count: int) -> void:
	# Synchronize GameState changes without recursive feedback loops
	var current: int = _items.get(resource_id, 0)
	if current != count:
		_items[resource_id] = count
		inventory_changed.emit()


# ---------------------------------------------------------------------------
# Core Inventory Operations API
# ---------------------------------------------------------------------------
func add_item(item_id: String, quantity: int = 1) -> int:
	if quantity <= 0:
		return 0
	
	# Graceful validation: invalid item IDs cannot crash the game
	var item_def: RefCounted = get_item_definition(item_id)
	if not item_def:
		push_warning("[InventoryManager] Unknown item_id: '%s'. Ignored safely." % item_id)
		return 0
	
	var max_stack: int = int(item_def.get("max_stack"))
	var current: int = _items.get(item_id, 0)
	var space_available: int = maxi(0, max_stack - current)
	var added: int = mini(quantity, space_available)
	
	if added > 0:
		_items[item_id] = current + added
		_sync_raw_resource_to_game_state(item_id, _items[item_id])
		item_added.emit(item_id, added, _items[item_id])
		inventory_changed.emit()
		
	return added


func remove_item(item_id: String, quantity: int = 1) -> bool:
	if quantity <= 0:
		return false
	
	var current: int = _items.get(item_id, 0)
	if current < quantity:
		return false # Insufficient quantity; state untouched
	
	_items[item_id] = current - quantity
	if _items[item_id] <= 0:
		_items.erase(item_id)
		
	_sync_raw_resource_to_game_state(item_id, _items.get(item_id, 0))
	item_removed.emit(item_id, quantity, _items.get(item_id, 0))
	inventory_changed.emit()
	return true


func has_item(item_id: String, quantity: int = 1) -> bool:
	return _items.get(item_id, 0) >= quantity


func get_item_count(item_id: String) -> int:
	return _items.get(item_id, 0)


func can_add_item(item_id: String, quantity: int = 1) -> bool:
	var item_def: RefCounted = get_item_definition(item_id)
	if not item_def or quantity <= 0:
		return false
	var max_stack: int = int(item_def.get("max_stack"))
	var current: int = _items.get(item_id, 0)
	return (current + quantity) <= max_stack


func use_item(item_id: String, target_player: Node2D = null) -> bool:
	if not has_item(item_id, 1):
		return false
	
	var item_def: RefCounted = get_item_definition(item_id)
	if not item_def or not bool(item_def.call("is_consumable")):
		return false
	
	if not bool(item_def.call("can_use", target_player)):
		return false
	
	# Apply effect
	var applied: bool = bool(item_def.call("apply_use", target_player))
	if applied:
		remove_item(item_id, 1)
		if item_def.get("category") == ItemDefinitionScript.Category.UPGRADE:
			if not _installed_upgrades.has(item_id):
				_installed_upgrades.append(item_id)
		item_used.emit(item_id, item_def.call("to_dict"))
		print("[InventoryManager] Consumed '%s': Applied %s" % [item_def.get("name"), str(item_def.get("use_effect"))])
		return true
		
	return false


# ---------------------------------------------------------------------------
# Crafting Pipeline API
# ---------------------------------------------------------------------------
func can_craft(recipe_id: String) -> bool:
	var recipe: RefCounted = _recipes.get(recipe_id, null)
	if not recipe:
		return false
	return bool(recipe.call("can_craft", self))


func craft_item(recipe_id: String) -> bool:
	# 1. Validate recipe existence safely without crashing
	var recipe: RefCounted = _recipes.get(recipe_id, null)
	if not recipe:
		crafting_failed.emit(recipe_id, "Unknown recipe ID: %s" % recipe_id)
		return false
	
	# 2. Check requirements BEFORE crafting
	if not bool(recipe.call("can_craft", self)):
		crafting_failed.emit(recipe_id, "Insufficient resources or inventory stack full.")
		return false
	
	# 3. Deduct ingredients only when crafting succeeds
	var ingredients: Dictionary = recipe.get("ingredients")
	for ing_id in ingredients:
		var req_qty: int = int(ingredients[ing_id])
		remove_item(ing_id, req_qty)
	
	# 4. Award crafted item result
	var res_id: String = str(recipe.get("result_item_id"))
	var res_qty: int = int(recipe.get("result_quantity"))
	add_item(res_id, res_qty)
	
	print("[InventoryManager] CRAFTED: %s x%d from recipe '%s'" % [res_id, res_qty, recipe_id])
	item_crafted.emit(recipe_id, res_id, res_qty)
	inventory_changed.emit()
	return true


# ---------------------------------------------------------------------------
# Query & Helper API
# ---------------------------------------------------------------------------
func get_item_definition(item_id: String) -> RefCounted:
	return _item_registry.get(item_id, null)


func get_recipe(recipe_id: String) -> RefCounted:
	return _recipes.get(recipe_id, null)


func get_all_items() -> Dictionary:
	return _items.duplicate()


func get_all_recipes() -> Array:
	var list := []
	for r_id in _recipe_order:
		list.append(_recipes[r_id])
	return list


func get_installed_upgrades() -> Array[String]:
	return _installed_upgrades.duplicate()


func reset_inventory() -> void:
	_items.clear()
	_installed_upgrades.clear()
	var gs := get_node_or_null("/root/GameState")
	if gs and "resources" in gs:
		for k in gs.resources:
			gs.resources[k] = 0
			if gs.has_signal("resource_changed"):
				gs.resource_changed.emit(k, 0)
	inventory_changed.emit()


func _sync_raw_resource_to_game_state(item_id: String, count: int) -> void:
	var gs := get_node_or_null("/root/GameState")
	if gs and "resources" in gs and gs.resources.has(item_id):
		if gs.resources[item_id] != count:
			gs.resources[item_id] = count
			if gs.has_signal("resource_changed"):
				gs.resource_changed.emit(item_id, count)
