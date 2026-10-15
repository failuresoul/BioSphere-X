extends StaticBody2D
class_name ResourceDeposit
## Harvestable alien resource deposit and mineral formations.
## Blocks pathfinding and entity movement while allowing player interaction.

enum ResourceType { ENERGY_CRYSTAL, TITANIUM_ORE, ALIEN_BIOMASS }

signal resource_harvested(resource_type: ResourceType, amount: int)

var resource_type: ResourceType = ResourceType.ENERGY_CRYSTAL
var remaining_units: int = 5
var radius: float = 24.0

# Visual palettes
const CRYSTAL_CORE := Color(0.70, 0.20, 1.00)      # Neon alien violet
const CRYSTAL_GLOW := Color(0.85, 0.40, 1.00, 0.3)
const CRYSTAL_HIGHLIGHT := Color(0.95, 0.80, 1.00)

const ORE_ROCK := Color(0.24, 0.26, 0.30)
const ORE_VEIN := Color(0.95, 0.60, 0.15)          # Metallic copper/titanium
const ORE_SPARK := Color(1.00, 0.88, 0.50)

const BIOMASS_CORE := Color(0.10, 0.85, 0.45)      # Fluorescent bioluminescent green
const BIOMASS_GLOW := Color(0.15, 0.95, 0.55, 0.35)

var _pulse_timer: float = 0.0


func setup(p_type: ResourceType, p_radius: float = 24.0) -> void:
	resource_type = p_type
	radius = p_radius
	collision_layer = 1
	collision_mask = 1
	add_to_group("interactable")
	add_to_group("resource")
	
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius * 0.85
	col.shape = shape
	add_child(col)
	queue_redraw()


func _process(delta: float) -> void:
	_pulse_timer += delta
	queue_redraw()


func interact(user: Node2D) -> void:
	if remaining_units <= 0:
		return
	
	remaining_units -= 1
	var type_name := "crystals"
	match resource_type:
		ResourceType.ENERGY_CRYSTAL: type_name = "crystals"
		ResourceType.TITANIUM_ORE: type_name = "titanium"
		ResourceType.ALIEN_BIOMASS: type_name = "biomass"
	
	print("BioSphere-X: Harvested resource from %s (Type: %s, Remaining: %d)" % [name, type_name, remaining_units])
	resource_harvested.emit(resource_type, 1)
	
	var gs := get_node_or_null("/root/GameState")
	if gs and gs.has_method("add_resource"):
		gs.call("add_resource", type_name, 1)
	
	if remaining_units <= 0:
		queue_redraw()


func _draw() -> void:
	# 1. Ground Drop Shadow
	draw_circle(Vector2(2, 4), radius * 0.95, Color(0.02, 0.03, 0.06, 0.45))
	
	match resource_type:
		ResourceType.ENERGY_CRYSTAL:
			_draw_energy_crystal()
		ResourceType.TITANIUM_ORE:
			_draw_titanium_ore()
		ResourceType.ALIEN_BIOMASS:
			_draw_alien_biomass()


func _draw_energy_crystal() -> void:
	var pulse := sin(_pulse_timer * 3.0) * 0.15
	var glow_radius := radius * (1.3 + pulse)
	
	# Atmospheric aura
	draw_circle(Vector2.ZERO, glow_radius, CRYSTAL_GLOW)
	
	# Sharp crystalline shard polygon
	var pts: PackedVector2Array = [
		Vector2(0, -radius * 1.1),
		Vector2(radius * 0.7, -radius * 0.3),
		Vector2(radius * 0.55, radius * 0.7),
		Vector2(0, radius * 0.9),
		Vector2(-radius * 0.55, radius * 0.7),
		Vector2(-radius * 0.7, -radius * 0.3)
	]
	draw_colored_polygon(pts, CRYSTAL_CORE)
	draw_polyline(pts, Color(0.08, 0.04, 0.14), 1.5)
	
	# Internal facets & specular shards
	draw_line(Vector2(0, -radius * 1.1), Vector2(0, radius * 0.9), CRYSTAL_HIGHLIGHT, 1.2)
	draw_line(Vector2(-radius * 0.7, -radius * 0.3), Vector2(radius * 0.7, -radius * 0.3), CRYSTAL_HIGHLIGHT, 1.0)


func _draw_titanium_ore() -> void:
	# Rugged rocky boulder base
	draw_circle(Vector2.ZERO, radius, ORE_ROCK)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 24, Color(0.08, 0.08, 0.10), 1.5)
	
	# Embedded metallic ore veins
	var vein_pts: PackedVector2Array = [
		Vector2(-radius * 0.6, -radius * 0.3),
		Vector2(-radius * 0.1, -radius * 0.5),
		Vector2(radius * 0.4, -radius * 0.2),
		Vector2(radius * 0.2, radius * 0.4),
		Vector2(-radius * 0.3, radius * 0.5)
	]
	draw_polyline(vein_pts, ORE_VEIN, 3.5)
	draw_polyline(vein_pts, ORE_SPARK, 1.5)


func _draw_alien_biomass() -> void:
	var pulse := sin(_pulse_timer * 2.2) * 0.10
	draw_circle(Vector2.ZERO, radius * (1.2 + pulse), BIOMASS_GLOW)
	
	# Bulbous biomass pods
	draw_circle(Vector2(-radius * 0.25, -radius * 0.2), radius * 0.65, BIOMASS_CORE.darkened(0.15))
	draw_circle(Vector2(radius * 0.3, radius * 0.15), radius * 0.55, BIOMASS_CORE)
	draw_circle(Vector2(-radius * 0.15, radius * 0.35), radius * 0.50, BIOMASS_CORE.lightened(0.2))
	draw_arc(Vector2.ZERO, radius * 0.85, 0, TAU, 20, Color(0.04, 0.14, 0.08), 1.2)
