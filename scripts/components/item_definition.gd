class_name ItemDefinition
extends RefCounted
## Standardized Item Definition Data Model for BioSphere-X.
## Encapsulates item identity, visual representation, stack limit, category,
## and consumable / upgrade gameplay effects.

enum Category {
	RESOURCE,
	CONSUMABLE,
	UPGRADE
}

var id: String = ""
var name: String = ""
var description: String = ""
var icon: String = "📦"
var category: Category = Category.RESOURCE
var max_stack: int = 99
var use_effect: Dictionary = {}


func _init(
	p_id: String = "",
	p_name: String = "",
	p_desc: String = "",
	p_icon: String = "📦",
	p_category: Category = Category.RESOURCE,
	p_max_stack: int = 99,
	p_effect: Dictionary = {}
) -> void:
	id = p_id
	name = p_name
	description = p_desc
	icon = p_icon
	category = p_category
	max_stack = maxi(1, p_max_stack)
	use_effect = p_effect.duplicate(true)


static func create(
	p_id: String,
	p_name: String,
	p_desc: String,
	p_icon: String,
	p_category: Category,
	p_max_stack: int = 99,
	p_effect: Dictionary = {}
) -> RefCounted:
	var script: GDScript = load("res://scripts/components/item_definition.gd")
	return script.new(p_id, p_name, p_desc, p_icon, p_category, p_max_stack, p_effect)


func is_consumable() -> bool:
	return category == Category.CONSUMABLE or category == Category.UPGRADE


func get_category_name() -> String:
	match category:
		Category.RESOURCE: return "Resource"
		Category.CONSUMABLE: return "Consumable"
		Category.UPGRADE: return "Upgrade"
	return "Item"


func _get_game_state(target_player: Node2D = null) -> Node:
	if target_player:
		var gs = target_player.get_node_or_null("/root/GameState")
		if gs:
			return gs
	var main_loop = Engine.get_main_loop()
	if main_loop is SceneTree and main_loop.root:
		return main_loop.root.get_node_or_null("GameState")
	return null


func can_use(target_player: Node2D = null) -> bool:
	if not is_consumable():
		return false
	
	var gs := _get_game_state(target_player)
	if not gs:
		return true
	
	# If healing pack: only usable if health < max_health
	if use_effect.has("health_restore") and float(use_effect["health_restore"]) > 0.0:
		var cur_hp: float = float(gs.get("health"))
		var max_hp: float = float(gs.get("max_health"))
		if cur_hp >= max_hp:
			return false
	
	# If oxygen pack: only usable if oxygen < max_oxygen
	if use_effect.has("oxygen_restore") and float(use_effect["oxygen_restore"]) > 0.0:
		var cur_o2: float = float(gs.get("oxygen"))
		var max_o2: float = float(gs.get("max_oxygen"))
		if cur_o2 >= max_o2:
			return false
	
	# If energy pack: only usable if energy < max_energy
	if use_effect.has("energy_restore") and float(use_effect["energy_restore"]) > 0.0:
		var cur_nrg: float = float(gs.get("energy"))
		var max_nrg: float = float(gs.get("max_energy"))
		if cur_nrg >= max_nrg:
			return false
	
	return true


func apply_use(target_player: Node2D = null) -> bool:
	if not can_use(target_player):
		return false
	
	var gs := _get_game_state(target_player)
	if not gs:
		return false
	
	# 1. Health Restoration
	if use_effect.has("health_restore"):
		var amt: float = float(use_effect["health_restore"])
		if gs.has_method("heal_player"):
			gs.call("heal_player", amt)
		else:
			var cur: float = float(gs.get("health"))
			var mx: float = float(gs.get("max_health"))
			gs.call("set_health", cur + amt, mx)
	
	# 2. Oxygen Restoration
	if use_effect.has("oxygen_restore"):
		var amt: float = float(use_effect["oxygen_restore"])
		if gs.has_method("refill_oxygen"):
			gs.call("refill_oxygen", amt)
	
	# 3. Energy Restoration
	if use_effect.has("energy_restore"):
		var amt: float = float(use_effect["energy_restore"])
		if gs.has_method("refill_energy"):
			gs.call("refill_energy", amt)
	
	# 4. Permanent Max Health Bonus (Upgrade)
	if use_effect.has("max_health_bonus"):
		var bonus: float = float(use_effect["max_health_bonus"])
		var cur_hp: float = float(gs.get("health"))
		var max_hp: float = float(gs.get("max_health")) + bonus
		gs.call("set_health", cur_hp + bonus, max_hp)
	
	# 5. Permanent Max Oxygen Bonus (Upgrade)
	if use_effect.has("max_oxygen_bonus"):
		var bonus: float = float(use_effect["max_oxygen_bonus"])
		var cur_o2: float = float(gs.get("oxygen"))
		var max_o2: float = float(gs.get("max_oxygen")) + bonus
		gs.call("set_oxygen", cur_o2 + bonus, max_o2)
	
	return true


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"description": description,
		"icon": icon,
		"category": get_category_name(),
		"max_stack": max_stack,
		"use_effect": use_effect
	}
