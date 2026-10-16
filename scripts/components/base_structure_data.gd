extends RefCounted
class_name BaseStructureData
## Data model for constructible base structures in BioSphere-X.
## Corresponds with the Python CSP solver catalog and rules.

var id: String = ""
var name: String = ""
var description: String = ""
var icon: String = "🏗️"
var width: int = 1
var height: int = 1
var cost: Dictionary = {} # res_name: String -> amount: int
var min_spacing: int = 1
var color: Color = Color(0.2, 0.8, 1.0)


func _init(
	p_id: String = "",
	p_name: String = "",
	p_desc: String = "",
	p_icon: String = "🏗️",
	p_width: int = 1,
	p_height: int = 1,
	p_cost: Dictionary = {},
	p_min_spacing: int = 1,
	p_color: Color = Color(0.2, 0.8, 1.0)
) -> void:
	id = p_id
	name = p_name
	description = p_desc
	icon = p_icon
	width = maxi(1, p_width)
	height = maxi(1, p_height)
	cost = p_cost.duplicate(true)
	min_spacing = maxi(0, p_min_spacing)
	color = p_color


static func create(
	p_id: String,
	p_name: String,
	p_desc: String,
	p_icon: String,
	p_width: int,
	p_height: int,
	p_cost: Dictionary,
	p_min_spacing: int = 1,
	p_color: Color = Color(0.2, 0.8, 1.0)
) -> RefCounted:
	var script: GDScript = load("res://scripts/components/base_structure_data.gd")
	return script.new(p_id, p_name, p_desc, p_icon, p_width, p_height, p_cost, p_min_spacing, p_color)


static func get_default_catalog() -> Dictionary:
	var cat: Dictionary = {}
	
	cat["oxygen_generator"] = create(
		"oxygen_generator", "Life-Support Pod", "Atmospheric oxygen generator establishing safe zone.",
		"🫧", 2, 2, {"titanium": 4, "crystals": 2}, 1, Color(0.15, 0.9, 1.0)
	)
	cat["defense_turret"] = create(
		"defense_turret", "Automated Sentry", "Automated perimeter defense turret targeting predators.",
		"🛡️", 1, 1, {"titanium": 3, "crystals": 3}, 2, Color(1.0, 0.35, 0.35)
	)
	cat["solar_array"] = create(
		"solar_array", "Photovoltaic Array", "Auxiliary solar array recharging suit combat energy.",
		"⚡", 2, 1, {"titanium": 2, "crystals": 2}, 1, Color(1.0, 0.85, 0.2)
	)
	cat["storage_depot"] = create(
		"storage_depot", "Resource Depot", "Reinforced field vault for securing surface harvest specimens.",
		"📦", 2, 2, {"titanium": 5, "biomass": 2}, 1, Color(0.95, 0.65, 0.2)
	)
	cat["bio_dome"] = create(
		"bio_dome", "Biosphere Hab Dome", "Controlled atmospheric habitat module for long-term survival.",
		"🌱", 3, 3, {"titanium": 8, "biomass": 6, "crystals": 4}, 2, Color(0.25, 0.95, 0.6)
	)
	cat["radar_beacon"] = create(
		"radar_beacon", "Telemetry Beacon", "Tactical telemetry sensor revealing planetary map hazards.",
		"📡", 1, 1, {"titanium": 2, "crystals": 1}, 1, Color(0.7, 0.45, 1.0)
	)
	return cat


func get_footprint(pos: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for dy in height:
		for dx in width:
			cells.append(Vector2i(pos.x + dx, pos.y + dy))
	return cells


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"description": description,
		"icon": icon,
		"width": width,
		"height": height,
		"cost": cost,
		"min_spacing": min_spacing
	}
