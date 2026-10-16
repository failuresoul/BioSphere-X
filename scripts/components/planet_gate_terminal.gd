extends "res://scripts/components/base_station_component.gd"
class_name PlanetGateTerminal
## Reusable Expedition Exit & Sector / Planet-Selection Terminal for BioSphere-X.
## Allows the astronaut to deploy to specific planetary sectors, toggle the base
## airlock barrier, and register safe return telemetry with the MissionManager.

signal sector_selected(sector_id: String, target_coordinates: Vector2)
signal airlock_toggled(is_open: bool)

@export var linked_airlock_door: Node2D = null
@export var current_sector_index: int = 0

const SECTORS: Array[Dictionary] = [
	{
		"id": "surface_basin",
		"name": "BioSphere-X Surface Clearing",
		"desc": "Primary landing zone. Rich in alien flora and mineral deposits.",
		"coords": Vector2(0.0, 180.0),
		"threat_level": "MODERATE"
	},
	{
		"id": "crystal_valley",
		"name": "South-West Crystal Valleys",
		"desc": "High concentration of piezoelectric energy crystals and armored brutes.",
		"coords": Vector2(-600.0, 560.0),
		"threat_level": "ELEVATED"
	},
	{
		"id": "ancient_crater",
		"name": "Ancient Crater Basin",
		"desc": "Territorial nesting ground of apex creature Goliath Prime.",
		"coords": Vector2(540.0, -720.0),
		"threat_level": "EXTREME"
	},
	{
		"id": "habitat_core",
		"name": "Base Habitat Sanctuary",
		"desc": "Return to safe life-support dome and inventory storage.",
		"coords": Vector2(0.0, 0.0),
		"threat_level": "SAFE"
	}
]


func _init() -> void:
	station_name = "Expedition Gate"
	station_tag = "DEPLOY"
	interaction_prompt = "Press E to Deploy Expedition / Select Sector"
	accent_color = Color(0.9, 0.35, 0.85) # Plasma Violet Glow
	icon_symbol = "🚀"
	interaction_radius = 46.0


func on_station_interacted(user: Node2D) -> bool:
	# Advance to next sector in sequence
	current_sector_index = (current_sector_index + 1) % SECTORS.size()
	var sector: Dictionary = SECTORS[current_sector_index]
	
	# If an airlock door is physically linked, toggle it
	if linked_airlock_door and linked_airlock_door.has_method("interact"):
		linked_airlock_door.call("interact", user)
		var is_open: bool = linked_airlock_door.get("is_open")
		airlock_toggled.emit(is_open)
	
	# Notify MissionManager that base/airlock has been accessed (Return to Base objective)
	var mm := get_node_or_null("/root/MissionManager")
	if mm:
		mm.call("notify_event", "base_reached", {
			"target_zone": "habitat_airlock",
			"sector": sector["id"]
		})
	
	var msg := "► SECTOR: %s [%s]" % [sector["name"], sector["threat_level"]]
	set_floating_feedback(msg, 3.5)
	print("[PlanetGateTerminal] Sector selected: ", sector["name"], " at ", sector["coords"])
	
	sector_selected.emit(sector["id"], sector["coords"])
	
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("open_planet_gate_modal"):
		hud.call("open_planet_gate_modal")
		
	return true


func deploy_to_sector(sector_id: String, user: Node2D = null) -> bool:
	for s in SECTORS:
		if s["id"] == sector_id:
			var target_pos: Vector2 = s["coords"]
			if user and user is CharacterBody2D:
				user.global_position = target_pos
			
			var mm := get_node_or_null("/root/MissionManager")
			if mm and sector_id == "habitat_core":
				mm.call("notify_event", "base_reached", {"target_zone": "habitat_airlock"})
				
			sector_selected.emit(sector_id, target_pos)
			return true
	return false


func get_current_sector() -> Dictionary:
	return SECTORS[current_sector_index]
