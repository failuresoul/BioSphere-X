extends Node2D
## Game world — procedural alien exoplanet environment with explorable zones,
## canyon passages, research ruins, resource deposits, and integrated AStar navigation.

const GRID_SIZE := Vector2i(80, 80)
const CELL_SIZE := 32.0
const WORLD_ORIGIN := Vector2(-1280.0, -1280.0)
const WORLD_SIZE := Vector2(2560.0, 2560.0)
const BOUNDARY_THICKNESS := 24.0
const PLAYER_SPAWN_POS := Vector2.ZERO

const MapDataScript := preload("res://scripts/components/map_data.gd")

var map_data: RefCounted

var _player_scene := preload("res://scenes/player/player.tscn")
var _hud_scene := preload("res://ui/screens/hud.tscn")
var _ground_script := preload("res://scripts/components/ground_layer.gd")
var _canyon_wall_script := preload("res://scripts/components/canyon_wall.gd")
var _debris_script := preload("res://scripts/components/research_debris.gd")
var _resource_script := preload("res://scripts/components/resource_deposit.gd")
var _rock_script := preload("res://scripts/components/alien_rock.gd")
var _plant_script := preload("res://scripts/components/alien_plant.gd")
var _oxygen_station_script := preload("res://scripts/components/oxygen_station.gd")

var _player_ref: Node2D = null


func _ready() -> void:
	add_to_group("world")
	# Initialize reusable MapData structure
	map_data = MapDataScript.new(GRID_SIZE, CELL_SIZE, WORLD_ORIGIN)
	
	_build_ground()
	_build_boundaries()
	_build_canyon_ridges()
	_build_research_outpost()
	_build_resource_fields()
	_build_scattered_rocks()
	_build_alien_flora()
	_build_oxygen_stations()
	_spawn_player()
	_build_hud()
	
	var summary: Dictionary = map_data.call("get_obstacle_summary")
	print("BioSphere-X: Complete alien planet map generated. Obstacles: ", summary)


func _build_hud() -> void:
	var hud := _hud_scene.instantiate()
	hud.name = "HUD"
	add_child(hud)


# ---------------------------------------------------------------------------
# Ground
# ---------------------------------------------------------------------------
func _build_ground() -> void:
	var ground := Node2D.new()
	ground.name = "Ground"
	ground.z_index = -10
	ground.set_script(_ground_script)
	add_child(ground)
	ground.setup(WORLD_ORIGIN, WORLD_SIZE)


# ---------------------------------------------------------------------------
# Map Boundaries
# ---------------------------------------------------------------------------
func _build_boundaries() -> void:
	var container := Node2D.new()
	container.name = "Boundaries"
	add_child(container)
	
	var edge_x := WORLD_ORIGIN.x + WORLD_SIZE.x
	var edge_y := WORLD_ORIGIN.y + WORLD_SIZE.y
	
	# Top, Bottom, Left, Right
	_add_boundary_wall(container, Vector2(0, WORLD_ORIGIN.y), Vector2(WORLD_SIZE.x + BOUNDARY_THICKNESS * 2, BOUNDARY_THICKNESS))
	_add_boundary_wall(container, Vector2(0, edge_y), Vector2(WORLD_SIZE.x + BOUNDARY_THICKNESS * 2, BOUNDARY_THICKNESS))
	_add_boundary_wall(container, Vector2(WORLD_ORIGIN.x, 0), Vector2(BOUNDARY_THICKNESS, WORLD_SIZE.y))
	_add_boundary_wall(container, Vector2(edge_x, 0), Vector2(BOUNDARY_THICKNESS, WORLD_SIZE.y))


func _add_boundary_wall(parent: Node, pos: Vector2, size: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.position = pos
	wall.collision_layer = 1
	wall.collision_mask = 1
	
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	wall.add_child(col)
	
	# Visual energy boundary barrier
	var vis := ColorRect.new()
	vis.color = Color(0.95, 0.25, 0.40, 0.70)
	vis.size = size
	vis.position = -size * 0.5
	wall.add_child(vis)
	parent.add_child(wall)
	
	# Block boundary in MapData
	var rect := Rect2(pos - size * 0.5, size)
	map_data.set_world_rect_blocked(rect, true, MapDataScript.CellType.BOUNDARY)


# ---------------------------------------------------------------------------
# Canyon Walls & Narrow Passages
# ---------------------------------------------------------------------------
func _build_canyon_ridges() -> void:
	var container := Node2D.new()
	container.name = "CanyonRidges"
	add_child(container)
	
	# Strategically placed ridges that carve out canyons, choke points, and corridors
	var ridge_specs: Array[Dictionary] = [
		# North-West Canyon Corridors
		{"pos": Vector2(-420, -320), "size": Vector2(280, 56)},
		{"pos": Vector2(-280, -560), "size": Vector2(56, 320)},
		{"pos": Vector2(-650, -180), "size": Vector2(64, 240)},
		
		# North-East Plateau Passages
		{"pos": Vector2(380, -300), "size": Vector2(260, 56)},
		{"pos": Vector2(250, -520), "size": Vector2(56, 280)},
		
		# South Ridge Wall with Narrow Choke Point Passage (Passage at x=100)
		{"pos": Vector2(-360, 340), "size": Vector2(380, 64)},
		{"pos": Vector2(400, 340), "size": Vector2(360, 64)},
		
		# East Labyrinth Defiles
		{"pos": Vector2(620, -80), "size": Vector2(64, 260)},
		{"pos": Vector2(780, 160), "size": Vector2(220, 56)},
		
		# South-West Crystal Valley Wall
		{"pos": Vector2(-480, 620), "size": Vector2(56, 260)},
		{"pos": Vector2(-280, 780), "size": Vector2(260, 56)}
	]
	
	for spec in ridge_specs:
		var wall: StaticBody2D = StaticBody2D.new()
		wall.set_script(_canyon_wall_script)
		wall.position = spec["pos"]
		container.add_child(wall)
		wall.call("setup", spec["size"])
		
		var rect := Rect2(spec["pos"] - spec["size"] * 0.5, spec["size"])
		map_data.set_world_rect_blocked(rect, true, MapDataScript.CellType.WALL)


# ---------------------------------------------------------------------------
# Research Debris (Abandoned Crash Site Outpost in North-East)
# ---------------------------------------------------------------------------
func _build_research_outpost() -> void:
	var container := Node2D.new()
	container.name = "ResearchOutpost"
	add_child(container)
	
	var debris_specs: Array[Dictionary] = [
		{"pos": Vector2(540, -520), "type": 0, "size": Vector2(84, 58)},  # Habitat Module
		{"pos": Vector2(640, -460), "type": 1, "size": Vector2(40, 40)},  # Cargo Crate
		{"pos": Vector2(680, -510), "type": 1, "size": Vector2(36, 36)},  # Cargo Crate
		{"pos": Vector2(480, -620), "type": 2, "size": Vector2(96, 34)},  # Solar Array
		{"pos": Vector2(620, -640), "type": 2, "size": Vector2(96, 34)},  # Solar Array
		{"pos": Vector2(430, -480), "type": 3, "size": Vector2(48, 48)},  # Comm Dish
		{"pos": Vector2(520, -410), "type": 1, "size": Vector2(38, 38)}   # Cargo Crate
	]
	
	for spec in debris_specs:
		var deb: StaticBody2D = StaticBody2D.new()
		deb.set_script(_debris_script)
		deb.position = spec["pos"]
		container.add_child(deb)
		deb.call("setup", spec["type"], spec["size"])
		
		var rect := Rect2(spec["pos"] - spec["size"] * 0.5, spec["size"])
		map_data.set_world_rect_blocked(rect, true, MapDataScript.CellType.DEBRIS)


# ---------------------------------------------------------------------------
# Resource Deposits (Crystals, Ores, Biomass)
# ---------------------------------------------------------------------------
func _build_resource_fields() -> void:
	var container := Node2D.new()
	container.name = "ResourceDeposits"
	add_child(container)
	
	var deposit_specs: Array[Dictionary] = [
		# South-West Energy Crystal Field
		{"pos": Vector2(-680, 520), "type": 0, "radius": 26.0},
		{"pos": Vector2(-620, 600), "type": 0, "radius": 30.0},
		{"pos": Vector2(-740, 680), "type": 0, "radius": 24.0},
		{"pos": Vector2(-540, 680), "type": 0, "radius": 28.0},
		
		# North-West Titanium / Mineral Ore Ridge
		{"pos": Vector2(-720, -420), "type": 1, "radius": 28.0},
		{"pos": Vector2(-780, -520), "type": 1, "radius": 32.0},
		{"pos": Vector2(-620, -480), "type": 1, "radius": 26.0},
		
		# South-East Alien Biomass Organisms
		{"pos": Vector2(520, 580), "type": 2, "radius": 26.0},
		{"pos": Vector2(620, 640), "type": 2, "radius": 30.0},
		{"pos": Vector2(580, 720), "type": 2, "radius": 28.0}
	]
	
	for spec in deposit_specs:
		var dep: StaticBody2D = StaticBody2D.new()
		dep.set_script(_resource_script)
		dep.position = spec["pos"]
		container.add_child(dep)
		dep.call("setup", spec["type"], spec["radius"])
		
		map_data.set_world_circle_blocked(spec["pos"], spec["radius"], true, MapDataScript.CellType.RESOURCE)


# ---------------------------------------------------------------------------
# Scattered Rocks (Natural Obstacles)
# ---------------------------------------------------------------------------
func _build_scattered_rocks() -> void:
	var container := Node2D.new()
	container.name = "Rocks"
	add_child(container)
	
	var rock_positions: Array[Vector2] = [
		Vector2(-180, 180), Vector2(190, -160), Vector2(-220, -180),
		Vector2(160, 210), Vector2(-120, -420), Vector2(110, -440),
		Vector2(-480, -80), Vector2(460, 120), Vector2(280, 520),
		Vector2(-140, 640), Vector2(740, -260), Vector2(-780, 180),
		Vector2(-320, -780), Vector2(340, -780), Vector2(820, 480)
	]
	
	for i in rock_positions.size():
		var pos: Vector2 = rock_positions[i]
		var radius: float = randf_range(18.0, 32.0)
		
		var rock: StaticBody2D = StaticBody2D.new()
		rock.name = "Rock_%d" % i
		rock.set_script(_rock_script)
		rock.position = pos
		container.add_child(rock)
		rock.call("setup", radius)
		
		map_data.set_world_circle_blocked(pos, radius, true, MapDataScript.CellType.ROCK)


# ---------------------------------------------------------------------------
# Alien Flora & Spores
# ---------------------------------------------------------------------------
func _build_alien_flora() -> void:
	var container := Node2D.new()
	container.name = "Plants"
	container.z_index = -1
	add_child(container)
	
	var plant_positions: Array[Vector2] = [
		Vector2(-120, 90), Vector2(140, 70), Vector2(-90, -120), Vector2(100, -90),
		Vector2(-580, 450), Vector2(-640, 750), Vector2(-460, 720),
		Vector2(460, 520), Vector2(680, 680), Vector2(640, 560),
		Vector2(320, -240), Vector2(460, -240), Vector2(-360, -260),
		Vector2(700, 80), Vector2(-600, -120), Vector2(180, 620)
	]
	
	for i in plant_positions.size():
		var plant: Node2D = Node2D.new()
		plant.name = "Plant_%d" % i
		plant.set_script(_plant_script)
		plant.position = plant_positions[i]
		container.add_child(plant)
		plant.call("setup")


# ---------------------------------------------------------------------------
# Oxygen Stations & Atmospheric Safe Zones
# ---------------------------------------------------------------------------
func _build_oxygen_stations() -> void:
	var container := Node2D.new()
	container.name = "OxygenStations"
	add_child(container)
	
	var station_specs: Array[Dictionary] = [
		# 1. Base Camp Atmospheric Safe Zone Dome (At Player Spawn)
		{
			"pos": Vector2.ZERO,
			"name": "BaseCampAtmosphericDome",
			"display_name": "EVA Base Camp Atmospheric Dome",
			"type": "safe_zone_dome",
			"radius": 115.0,
			"refill_rate": 35.0
		},
		# 2. North-East Research Outpost Life-Support Station
		{
			"pos": Vector2(360, -440),
			"name": "ResearchOutpostO2Station",
			"display_name": "Research Outpost O2 Refill Station",
			"type": "station",
			"radius": 85.0,
			"refill_rate": 30.0
		},
		# 3. South-West Crystal Valley Life-Support Station
		{
			"pos": Vector2(-420, 420),
			"name": "CrystalValleyO2Station",
			"display_name": "Crystal Valley O2 Refill Station",
			"type": "station",
			"radius": 85.0,
			"refill_rate": 30.0
		},
		# 4. East Labyrinth Canyon Life-Support Pylon
		{
			"pos": Vector2(650, 100),
			"name": "EastCanyonO2Station",
			"display_name": "East Canyon O2 Pylon",
			"type": "station",
			"radius": 80.0,
			"refill_rate": 25.0
		}
	]
	
	for spec in station_specs:
		var st := Area2D.new()
		st.name = spec["name"]
		st.set_script(_oxygen_station_script)
		st.position = spec["pos"]
		container.add_child(st)
		st.set("station_name", spec["display_name"])
		st.set("station_type", spec["type"])
		st.set("radius", spec["radius"])
		st.set("refill_rate", spec["refill_rate"])


# ---------------------------------------------------------------------------
# Player Spawning
# ---------------------------------------------------------------------------
func _spawn_player() -> void:
	var player: Node2D = _player_scene.instantiate()
	player.name = "Player"
	player.position = PLAYER_SPAWN_POS
	add_child(player)
	_player_ref = player


# ---------------------------------------------------------------------------
# Public Navigation & Map Inspection API
# ---------------------------------------------------------------------------
func get_map_data() -> RefCounted:
	return map_data


func get_player() -> Node2D:
	return _player_ref


func is_world_blocked(world_pos: Vector2) -> bool:
	return map_data.is_world_blocked(world_pos) if map_data else false


func get_path_to_player(from_world_pos: Vector2) -> PackedVector2Array:
	if not map_data or not _player_ref:
		return PackedVector2Array()
	return map_data.get_path_points(from_world_pos, _player_ref.global_position)
