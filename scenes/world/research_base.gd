extends Node2D
class_name ResearchBase
## Complete Functional Research Base Compound for BioSphere-X (Prompt 21).
## Serves as the player's primary spawn habitat and safe return sanctuary.
## Incorporates:
##   1. Life-Support Oxygen Refill Core & Atmospheric Safe Dome.
##   2. Cargo Storage & Vault Inventory Terminal.
##   3. Mission Operations Directives Terminal.
##   4. Planet-Selection & Expedition Airlock Gate.
##   5. Perimeter Blast Shielding, Sci-Fi Deck Graphics, and Lighting Beacons.

const OxygenStationScript := preload("res://scripts/components/oxygen_station.gd")
const StorageTerminalScript := preload("res://scripts/components/storage_terminal.gd")
const MissionTerminalScript := preload("res://scripts/components/mission_terminal.gd")
const PlanetGateTerminalScript := preload("res://scripts/components/planet_gate_terminal.gd")
const AirlockDoorScript := preload("res://scripts/components/airlock_door.gd")

@export var base_name: String = "Bio-Hab Alpha Research Base"
@export var base_radius: float = 145.0
@export var deck_size: Vector2 = Vector2(280.0, 220.0)

# Station References
var oxygen_station: Area2D
var storage_terminal: Area2D
var mission_terminal: Area2D
var planet_gate: Area2D
var airlock_door: StaticBody2D

var _light_pulse: float = 0.0


func _ready() -> void:
	add_to_group("research_base")
	add_to_group("safe_zones")
	
	_build_base_stations()
	_build_perimeter_walls()


func _process(delta: float) -> void:
	_light_pulse += delta * 2.0
	queue_redraw()


# ---------------------------------------------------------------------------
# Station Assembly
# ---------------------------------------------------------------------------
func _build_base_stations() -> void:
	# 1. Central Life-Support & Oxygen Refill Dome
	oxygen_station = Area2D.new()
	oxygen_station.name = "BaseCampAtmosphericDome"
	oxygen_station.set_script(OxygenStationScript)
	oxygen_station.position = Vector2(-65.0, -35.0)
	add_child(oxygen_station)
	oxygen_station.set("station_name", "Habitat Life Support Core")
	oxygen_station.set("station_type", "station")
	oxygen_station.set("radius", base_radius)
	oxygen_station.set("refill_rate", 35.0)
	
	# 2. Cargo Storage & Inventory Terminal
	storage_terminal = StorageTerminalScript.new()
	storage_terminal.name = "StorageTerminal"
	storage_terminal.position = Vector2(65.0, -35.0)
	add_child(storage_terminal)
	
	# 3. Mission Operations Terminal
	mission_terminal = MissionTerminalScript.new()
	mission_terminal.name = "MissionTerminal"
	mission_terminal.position = Vector2(0.0, -65.0)
	add_child(mission_terminal)
	
	# 4. Expedition Airlock Door (South Portal)
	airlock_door = AirlockDoorScript.new()
	airlock_door.name = "HabitatAirlockDoor"
	airlock_door.position = Vector2(0.0, 95.0)
	airlock_door.set("door_size", Vector2(56.0, 16.0))
	add_child(airlock_door)
	
	# 5. Planet-Selection & Expedition Gate Console
	planet_gate = PlanetGateTerminalScript.new()
	planet_gate.name = "PlanetGateTerminal"
	planet_gate.position = Vector2(48.0, 65.0)
	planet_gate.set("linked_airlock_door", airlock_door)
	add_child(planet_gate)


# ---------------------------------------------------------------------------
# Perimeter Physical Barrier
# ---------------------------------------------------------------------------
func _build_perimeter_walls() -> void:
	var walls_body := StaticBody2D.new()
	walls_body.name = "BasePerimeterWalls"
	walls_body.collision_layer = 1
	walls_body.collision_mask = 1
	add_child(walls_body)
	
	var half_w := deck_size.x * 0.5
	var half_h := deck_size.y * 0.5
	
	# North Wall
	_add_wall_segment(walls_body, Vector2(0, -half_h), Vector2(deck_size.x, 14.0))
	# West Wall
	_add_wall_segment(walls_body, Vector2(-half_w, 0), Vector2(14.0, deck_size.y))
	# East Wall
	_add_wall_segment(walls_body, Vector2(half_w, 0), Vector2(14.0, deck_size.y))
	# South Wall Left Section (up to airlock door)
	_add_wall_segment(walls_body, Vector2(-half_w * 0.60, half_h), Vector2(half_w * 0.80, 14.0))
	# South Wall Right Section (up to airlock door)
	_add_wall_segment(walls_body, Vector2(half_w * 0.60, half_h), Vector2(half_w * 0.80, 14.0))


func _add_wall_segment(parent: StaticBody2D, pos: Vector2, size: Vector2) -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = pos
	parent.add_child(shape)


# ---------------------------------------------------------------------------
# Queries & Accessors
# ---------------------------------------------------------------------------
func get_oxygen_station() -> Area2D:
	return oxygen_station


func get_storage_terminal() -> Area2D:
	return storage_terminal


func get_mission_terminal() -> Area2D:
	return mission_terminal


func get_planet_gate() -> Area2D:
	return planet_gate


func get_airlock_door() -> StaticBody2D:
	return airlock_door


func is_point_inside_base(pos: Vector2) -> bool:
	var local_pos := pos - global_position
	return absf(local_pos.x) <= deck_size.x * 0.5 and absf(local_pos.y) <= deck_size.y * 0.5


# ---------------------------------------------------------------------------
# Procedural Deck Graphics & Illumination
# ---------------------------------------------------------------------------
func _draw() -> void:
	var pulse := (sin(_light_pulse) + 1.0) * 0.5
	var half_w := deck_size.x * 0.5
	var half_h := deck_size.y * 0.5
	var deck_rect := Rect2(-half_w, -half_h, deck_size.x, deck_size.y)
	
	# 1. Base Ground Foundation Drop Shadow
	draw_rect(Rect2(-half_w - 4, -half_h - 4, deck_size.x + 8, deck_size.y + 12), Color(0.02, 0.03, 0.05, 0.6))
	
	# 2. Heavy Titanium Deck Plates
	draw_rect(deck_rect, Color(0.08, 0.11, 0.16))
	draw_rect(deck_rect, Color(0.18, 0.28, 0.40), false, 2.0)
	
	# Modular Floor Grid Lines
	var cols := 6
	for c in range(1, cols):
		var x := -half_w + (deck_size.x / cols) * c
		draw_line(Vector2(x, -half_h + 8), Vector2(x, half_h - 8), Color(0.12, 0.18, 0.26, 0.65), 1.0)
	var rows := 5
	for r in range(1, rows):
		var y := -half_h + (deck_size.y / rows) * r
		draw_line(Vector2(-half_w + 8, y), Vector2(half_w - 8, y), Color(0.12, 0.18, 0.26, 0.65), 1.0)
	
	# 3. Central Hexagonal Airlock / Landing Pad Inlay
	var pad_pts: PackedVector2Array = [
		Vector2(0, -32), Vector2(28, -16), Vector2(28, 16),
		Vector2(0, 32), Vector2(-28, 16), Vector2(-28, -16)
	]
	draw_colored_polygon(pad_pts, Color(0.12, 0.16, 0.24, 0.9))
	draw_polyline(pad_pts, Color(0.2, 0.85, 1.0, 0.8), 1.5)
	
	# Central BioSphere-X Decal
	draw_circle(Vector2.ZERO, 8.0, Color(0.15, 0.9, 0.7, 0.8 + pulse * 0.2))
	draw_circle(Vector2.ZERO, 4.0, Color.WHITE)
	
	# 4. Perimeter Yellow/Black Hazard Stripes near Airlock Portal
	var hazard_w := 60.0
	draw_line(Vector2(-hazard_w * 0.5, half_h - 10), Vector2(hazard_w * 0.5, half_h - 10), Color(0.95, 0.75, 0.15, 0.8), 2.5)
	
	# 5. Ambient Deck Illumination Beacons (Corner Lights)
	var corner_beacon_color := Color(0.2, 0.9, 1.0, 0.6 + pulse * 0.35)
	var corners: Array[Vector2] = [
		Vector2(-half_w + 14, -half_h + 14),
		Vector2(half_w - 14, -half_h + 14),
		Vector2(-half_w + 14, half_h - 18),
		Vector2(half_w - 14, half_h - 18)
	]
	for cpt in corners:
		draw_circle(cpt, 4.0, corner_beacon_color)
		draw_circle(cpt, 1.8, Color.WHITE)
	
	# 6. Overhead Base Header Signage
	var sign_color := Color(0.2, 0.88, 1.0, 0.9)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-140, -half_h + 20),
		"// %s // SECTOR-01 //" % base_name.to_upper(),
		HORIZONTAL_ALIGNMENT_CENTER,
		280.0,
		10,
		sign_color
	)
