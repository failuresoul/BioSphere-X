class_name CraftingRecipe
extends RefCounted
## Standardized Crafting Recipe Model for BioSphere-X.
## Specifies requirements, output items, and validation logic.

var recipe_id: String = ""
var name: String = ""
var description: String = ""
var result_item_id: String = ""
var result_quantity: int = 1
var ingredients: Dictionary = {} # item_id: String -> required_qty: int


func _init(
	p_recipe_id: String = "",
	p_name: String = "",
	p_desc: String = "",
	p_result_id: String = "",
	p_result_qty: int = 1,
	p_ingredients: Dictionary = {}
) -> void:
	recipe_id = p_recipe_id
	name = p_name
	description = p_desc
	result_item_id = p_result_id
	result_quantity = maxi(1, p_result_qty)
	ingredients = p_ingredients.duplicate(true)


static func create(
	p_recipe_id: String,
	p_name: String,
	p_desc: String,
	p_result_id: String,
	p_result_qty: int,
	p_ingredients: Dictionary
) -> RefCounted:
	var script: GDScript = load("res://scripts/components/crafting_recipe.gd")
	return script.new(p_recipe_id, p_name, p_desc, p_result_id, p_result_qty, p_ingredients)


func can_craft(inventory: Node) -> bool:
	if not inventory:
		return false
	
	for item_id in ingredients:
		var req_qty: int = int(ingredients[item_id])
		var current_qty: int = int(inventory.call("get_item_count", item_id))
		if current_qty < req_qty:
			return false
	
	# Verify inventory can accept result item
	if inventory.has_method("can_add_item"):
		if not bool(inventory.call("can_add_item", result_item_id, result_quantity)):
			return false
			
	return true


func get_missing_ingredients(inventory: Node) -> Dictionary:
	var missing := {}
	if not inventory:
		return ingredients.duplicate()
		
	for item_id in ingredients:
		var req_qty: int = int(ingredients[item_id])
		var current_qty: int = int(inventory.call("get_item_count", item_id))
		if current_qty < req_qty:
			missing[item_id] = req_qty - current_qty
			
	return missing


func to_dict() -> Dictionary:
	return {
		"recipe_id": recipe_id,
		"name": name,
		"description": description,
		"result_item_id": result_item_id,
		"result_quantity": result_quantity,
		"ingredients": ingredients
	}
