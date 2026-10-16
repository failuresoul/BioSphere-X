extends "res://scripts/components/base_station_component.gd"
class_name StorageTerminal
## Reusable Resource Storage and Vault Terminal for BioSphere-X.
## Secures field-collected materials (Crystals, Titanium, Biomass, Oxygen Cells)
## into base storage, preventing loss during subsequent planetary expeditions.

signal storage_accessed(deposited_summary: Dictionary)

@export var auto_deposit_on_interact: bool = true


func _init() -> void:
	station_name = "Cargo Storage & Vault"
	station_tag = "INVENTORY"
	interaction_prompt = "Press E to Secure Field Cargo into Storage"
	accent_color = Color(0.95, 0.65, 0.18) # Amber Industrial Glow
	icon_symbol = "📦"
	interaction_radius = 42.0


func on_station_interacted(_user: Node2D) -> bool:
	var gs := get_node_or_null("/root/GameState")
	if not gs:
		return false
	
	if auto_deposit_on_interact:
		var deposited: Dictionary = gs.call("deposit_all_resources")
		var total_deposited: int = 0
		var desc_parts: Array[String] = []
		
		for res_key in deposited:
			var qty: int = int(deposited[res_key])
			total_deposited += qty
			desc_parts.append("+%d %s" % [qty, res_key.capitalize()])
		
		if total_deposited > 0:
			var msg := "✓ SECURED: %s" % (", ".join(desc_parts))
			set_floating_feedback(msg, 3.2)
			print("[StorageTerminal] Secured cargo into base vault: ", deposited)
		else:
			set_floating_feedback("VAULT SYNCED // NO FIELD CARGO TO DEPOSIT", 2.2)
		
		storage_accessed.emit(deposited)
		
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("open_storage_modal"):
			hud.call("open_storage_modal")
			
		return true
	
	return true


func deposit_specific(resource_id: String, amount: int = -1) -> int:
	var gs := get_node_or_null("/root/GameState")
	if gs:
		return int(gs.call("deposit_resource", resource_id, amount))
	return 0


func withdraw_specific(resource_id: String, amount: int = 1) -> int:
	var gs := get_node_or_null("/root/GameState")
	if gs:
		return int(gs.call("withdraw_resource", resource_id, amount))
	return 0


func get_stored_summary() -> Dictionary:
	var gs := get_node_or_null("/root/GameState")
	if gs:
		return gs.call("get_all_stored_resources")
	return {}
