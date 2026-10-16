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
var _collectable_scene := preload("res://scenes/items/collectable_resource.tscn")
var _terminal_script := preload("res://scripts/components/research_terminal.gd")
var _door_script := preload("res://scripts/components/airlock_door.gd")
var _tutorial_script := preload("res://scripts/components/tutorial_manager.gd")
var _enemy_scene := preload("res://scenes/enemies/alien_enemy.tscn")
var _enemy_scout_scene := preload("res://scenes/enemies/enemy_scout.tscn")
var _enemy_brute_scene := preload("res://scenes/enemies/enemy_brute.tscn")
var _enemy_spitter_scene := preload("res://scenes/enemies/enemy_spitter.tscn")
var _boss_scene := preload("res://scenes/boss/boss_enemy.tscn")
var _research_base_script := preload("res://scenes/world/research_base.gd")

var _player_ref: Node2D = null
var _terminal_ref: Node2D = null
var _research_base_ref: Node2D = null


func _ready() -> void:
	add_to_group("world")
	
	var ppm = get_node_or_null("/root/PlanetProgressionManager")
	var initial_cfg: RefCounted = null
	if ppm and ppm.has_method("get_current_planet_config"):
		initial_cfg = ppm.call("get_current_planet_config")
	if not initial_cfg:
		var cfg_script = preload("res://scripts/components/planet_level_config.gd")
		initial_cfg = cfg_script.create_trappist_1_e()
		
	load_planet_level(initial_cfg)
	
	# Navigation & Grid Debug Visualizer (only if not already added)
	if not has_node("NavigationDebugVisualizer"):
		var debug_viz := preload("res://scenes/world/navigation_debug_visualizer.gd").new()
		debug_viz.name = "NavigationDebugVisualizer"
		add_child(debug_viz)


## Dynamically loads and configures an exoplanet level without duplicating
## global UI (HUD), player inventory, or game-state singletons.
func load_planet_level(cfg: RefCounted) -> void:
	if not cfg:
		return
		
	var p_id: String = str(cfg.get("planet_id"))
	var p_name_val = cfg.get("planet_name")
	var p_name: String = str(p_name_val) if p_name_val != null else p_id
	var ground_col: Color = cfg.get("ground_color") if "ground_color" in cfg else Color(0.20, 0.14, 0.22)
	var canyon_col: Color = cfg.get("canyon_wall_color") if "canyon_wall_color" in cfg else Color(0.34, 0.22, 0.32)
	var barrier_col: Color = cfg.get("barrier_color") if "barrier_color" in cfg else Color(0.95, 0.25, 0.40, 0.70)
	var o2_val = cfg.get("oxygen_depletion_rate")
	var o2_rate: float = float(o2_val) if o2_val != null else 1.5
	var hazard_val = cfg.get("hazard_level")
	var hazard_lvl: String = str(hazard_val) if hazard_val != null else "MODERATE"
	var deposit_specs: Array = cfg.get("deposit_specs") if "deposit_specs" in cfg else []
	var collectable_specs: Array = cfg.get("collectable_specs") if "collectable_specs" in cfg else []
	var scouts_val = cfg.get("enemy_scouts_count")
	var scouts_count: int = int(scouts_val) if scouts_val != null else 3
	var spitters_val = cfg.get("enemy_spitters_count")
	var spitters_count: int = int(spitters_val) if spitters_val != null else 2
	var brutes_val = cfg.get("enemy_brutes_count")
	var brutes_count: int = int(brutes_val) if brutes_val != null else 1
	var boss_val = cfg.get("has_boss")
	var has_boss: bool = bool(boss_val) if boss_val != null else true
	var missions: Array = cfg.get("mission_sequence") if "mission_sequence" in cfg else []
	
	# 1. Reset / initialize reusable MapData
	map_data = MapDataScript.new(GRID_SIZE, CELL_SIZE, WORLD_ORIGIN)
	
	# 2. Ground
	_build_ground(ground_col)
	
	# 3. Boundaries
	_build_boundaries(barrier_col)
	
	# 4. Canyon ridges
	_build_canyon_ridges(canyon_col)
	
	# 5. Base & Outposts
	_build_research_base()
	_build_research_outpost()
	
	# 6. Resources & Deposits
	_build_resource_fields(deposit_specs)
	_build_scattered_rocks()
	_build_alien_flora()
	_build_oxygen_stations()
	_build_collectables(collectable_specs)
	_build_research_terminals()
	
	# 7. Player (Preserve single instance, reposition to spawn)
	_spawn_player()
	
	# 8. Enemies & Boss
	_spawn_enemies(scouts_count, spitters_count, brutes_count)
	_spawn_boss(has_boss)
	
	# 9. Tutorial & HUD (Prevent duplicates)
	_build_tutorial_system()
	_build_hud()
	
	# 10. Update NavigationManager
	var nav_mgr = get_node_or_null("/root/NavigationManager")
	if nav_mgr and nav_mgr.has_method("set_map_data"):
		nav_mgr.call("set_map_data", map_data)
		
	# 11. Update GameState environmental rates
	var gs = get_node_or_null("/root/GameState")
	if gs:
		gs.oxygen_depletion_rate = o2_rate
		if "selected_planet" in gs:
			gs.selected_planet = p_name
			
	# 12. Update DifficultyController
	var diff_ctrl = get_node_or_null("/root/DifficultyController")
	if diff_ctrl and "base_aggression" in cfg:
		var base_agg_val = cfg.get("base_aggression")
		var base_agg: float = float(base_agg_val) if base_agg_val != null else 0.5
		if diff_ctrl.has_method("set_baseline_aggression"):
			diff_ctrl.call("set_baseline_aggression", base_agg)
			
	# 13. Load Planet Mission Sequence
	var mm = get_node_or_null("/root/MissionManager")
	if mm and mm.has_method("load_mission_sequence"):
		mm.call("load_mission_sequence", missions)
		
	var summary: Dictionary = map_data.call("get_obstacle_summary")
	print("[GameWorld] Level loaded for %s (Hazard: %s, O2 Drain: %.1f/s, Obstacles: %s)" % [
		p_name, hazard_lvl, o2_rate, str(summary)
	])


func _build_hud() -> void:
	if has_node("HUD") or get_tree().get_first_node_in_group("hud"):
		return
	var hud := _hud_scene.instantiate()
	hud.name = "HUD"
	add_child(hud)


# ---------------------------------------------------------------------------
# Ground
# ---------------------------------------------------------------------------
func _build_ground(p_color: Color = Color.TRANSPARENT) -> void:
	var ground = get_node_or_null("Ground")
	if not ground:
		ground = Node2D.new()
		ground.name = "Ground"
		ground.z_index = -10
		ground.set_script(_ground_script)
		add_child(ground)
	ground.setup(WORLD_ORIGIN, WORLD_SIZE, p_color if p_color != Color.TRANSPARENT else null)


# ---------------------------------------------------------------------------
# Map Boundaries
# ---------------------------------------------------------------------------
func _build_boundaries(barrier_color: Color = Color(0.95, 0.25, 0.40, 0.70)) -> void:
	var container = get_node_or_null("Boundaries")
	if container:
		for child in container.get_children():
			child.queue_free()
	else:
		container = Node2D.new()
		container.name = "Boundaries"
		add_child(container)
	
	var edge_x := WORLD_ORIGIN.x + WORLD_SIZE.x
	var edge_y := WORLD_ORIGIN.y + WORLD_SIZE.y
	
	# Top, Bottom, Left, Right
	_add_boundary_wall(container, Vector2(0, WORLD_ORIGIN.y), Vector2(WORLD_SIZE.x + BOUNDARY_THICKNESS * 2, BOUNDARY_THICKNESS), barrier_color)
	_add_boundary_wall(container, Vector2(0, edge_y), Vector2(WORLD_SIZE.x + BOUNDARY_THICKNESS * 2, BOUNDARY_THICKNESS), barrier_color)
	_add_boundary_wall(container, Vector2(WORLD_ORIGIN.x, 0), Vector2(BOUNDARY_THICKNESS, WORLD_SIZE.y), barrier_color)
	_add_boundary_wall(container, Vector2(edge_x, 0), Vector2(BOUNDARY_THICKNESS, WORLD_SIZE.y), barrier_color)


func _add_boundary_wall(parent: Node, pos: Vector2, size: Vector2, barrier_color: Color = Color(0.95, 0.25, 0.40, 0.70)) -> void:
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
	vis.color = barrier_color
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
func _build_canyon_ridges(wall_color: Color = Color.TRANSPARENT) -> void:
	var container = get_node_or_null("CanyonRidges")
	if container:
		for child in container.get_children():
			child.queue_free()
	else:
		container = Node2D.new()
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
		wall.call("setup", spec["size"], wall_color if wall_color != Color.TRANSPARENT else null)
		
		var rect := Rect2(spec["pos"] - spec["size"] * 0.5, spec["size"])
		map_data.set_world_rect_blocked(rect, true, MapDataScript.CellType.WALL)


# ---------------------------------------------------------------------------
# Research Debris (Abandoned Crash Site Outpost in North-East)
# ---------------------------------------------------------------------------
func _build_research_outpost() -> void:
	var container = get_node_or_null("ResearchOutpost")
	if container:
		# Debris already present, re-register obstacles in map_data
		for deb in container.get_children():
			var sz: Vector2 = deb.get("size") if "size" in deb else Vector2(40, 40)
			var rect := Rect2(deb.position - sz * 0.5, sz)
			map_data.set_world_rect_blocked(rect, true, MapDataScript.CellType.DEBRIS)
		return
	container = Node2D.new()
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
func _build_resource_fields(custom_specs: Array = []) -> void:
	var container = get_node_or_null("ResourceDeposits")
	if container:
		for child in container.get_children():
			child.queue_free()
	else:
		container = Node2D.new()
		container.name = "ResourceDeposits"
		add_child(container)
	
	var deposit_specs: Array = custom_specs
	if deposit_specs.is_empty():
		deposit_specs = [
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
	var container = get_node_or_null("Rocks")
	if container:
		for rock in container.get_children():
			var r = rock.get("radius") if "radius" in rock else 24.0
			map_data.set_world_circle_blocked(rock.position, r, true, MapDataScript.CellType.ROCK)
		return
	container = Node2D.new()
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
	if has_node("Plants"):
		return
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
# Research Base Compound (Spawn Habitat & Safe Sanctuary)
# ---------------------------------------------------------------------------
func _build_research_base() -> void:
	if has_node("ResearchBase"):
		return
	var base := _research_base_script.new()
	base.name = "ResearchBase"
	base.position = PLAYER_SPAWN_POS
	add_child(base)
	_research_base_ref = base


# ---------------------------------------------------------------------------
# Oxygen Stations & Atmospheric Safe Zones
# ---------------------------------------------------------------------------
func _build_oxygen_stations() -> void:
	if has_node("OxygenStations"):
		return
	var container := Node2D.new()
	container.name = "OxygenStations"
	add_child(container)
	
	var station_specs: Array[Dictionary] = [
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
# Collectable Resources (Oxygen Cells, Metal, Energy Crystals, Samples)
# ---------------------------------------------------------------------------
func _build_collectables(custom_specs: Array = []) -> void:
	var container = get_node_or_null("Collectables")
	if container:
		for child in container.get_children():
			child.queue_free()
	else:
		container = Node2D.new()
		container.name = "Collectables"
		add_child(container)
	
	var items: Array = custom_specs
	if items.is_empty():
		items = [
			# Oxygen Cells (Type 0)
			{"pos": Vector2(100, -120), "type": 0, "qty": 1},
			{"pos": Vector2(-320, -320), "type": 0, "qty": 1},
			{"pos": Vector2(460, 200), "type": 0, "qty": 2},
			# Metal / Titanium (Type 1)
			{"pos": Vector2(520, -380), "type": 1, "qty": 2},
			{"pos": Vector2(660, -420), "type": 1, "qty": 3},
			{"pos": Vector2(-220, 260), "type": 1, "qty": 2},
			# Energy Crystals (Type 2)
			{"pos": Vector2(-540, 540), "type": 2, "qty": 1},
			{"pos": Vector2(-600, 620), "type": 2, "qty": 2},
			{"pos": Vector2(160, 220), "type": 2, "qty": 1},
			# Scientific Samples (Type 3)
			{"pos": Vector2(-140, 100), "type": 3, "qty": 1},
			{"pos": Vector2(460, 560), "type": 3, "qty": 2},
			{"pos": Vector2(640, -220), "type": 3, "qty": 1}
		]
	
	for i in items.size():
		var data: Dictionary = items[i]
		var item: Node2D = _collectable_scene.instantiate()
		item.name = "Collectable_%d" % i
		item.position = data["pos"]
		item.set("resource_type", data["type"])
		item.set("quantity", data["qty"])
		container.add_child(item)


# ---------------------------------------------------------------------------
# Research Terminals & Station Interactive Objects
# ---------------------------------------------------------------------------
func _build_research_terminals() -> void:
	if has_node("StationInteractiveObjects"):
		return
	var container := Node2D.new()
	container.name = "StationInteractiveObjects"
	add_child(container)
	
	# 1. Research Terminal inside Outpost clearing
	var terminal: Area2D = Area2D.new()
	terminal.name = "ResearchTerminal"
	terminal.set_script(_terminal_script)
	terminal.position = Vector2(420, -450)
	container.add_child(terminal)
	_terminal_ref = terminal
	
	# 2. Airlock Door guarding the Habitat module
	var door: StaticBody2D = StaticBody2D.new()
	door.name = "AirlockDoor"
	door.set_script(_door_script)
	door.position = Vector2(540, -490)
	container.add_child(door)


# ---------------------------------------------------------------------------
# Tutorial System
# ---------------------------------------------------------------------------
func _build_tutorial_system() -> void:
	if has_node("TutorialManager"):
		return
	var tutorial: Node = Node.new()
	tutorial.name = "TutorialManager"
	tutorial.set_script(_tutorial_script)
	add_child(tutorial)
	if _player_ref:
		tutorial.call("set_player", _player_ref)
	if _terminal_ref and _terminal_ref.has_signal("terminal_scanned"):
		_terminal_ref.connect("terminal_scanned", func(_user):
			tutorial.call("notify_terminal_scanned")
		)


# ---------------------------------------------------------------------------
# Player Spawning
# ---------------------------------------------------------------------------
func _spawn_player() -> void:
	var p = get_node_or_null("Player")
	if p:
		_player_ref = p
		_player_ref.global_position = PLAYER_SPAWN_POS
		_player_ref.velocity = Vector2.ZERO
		return
	var player: Node2D = _player_scene.instantiate()
	player.name = "Player"
	player.position = PLAYER_SPAWN_POS
	add_child(player)
	_player_ref = player


# ---------------------------------------------------------------------------
# Alien Enemy Spawning
# ---------------------------------------------------------------------------
func _spawn_enemies(scouts_count: int = 3, spitters_count: int = 2, brutes_count: int = 1) -> void:
	var container = get_node_or_null("AlienEnemies")
	if container:
		for child in container.get_children():
			child.queue_free()
	else:
		container = Node2D.new()
		container.name = "AlienEnemies"
		add_child(container)
	
	var scout_positions: Array[Vector2] = [
		Vector2(-420, -280), Vector2(180, -320), Vector2(320, 240),
		Vector2(-200, -450), Vector2(500, 150)
	]
	var spitter_positions: Array[Vector2] = [
		Vector2(680, -600), Vector2(720, -50), Vector2(-550, -200),
		Vector2(400, -550)
	]
	var brute_positions: Array[Vector2] = [
		Vector2(-650, 480), Vector2(-450, 600), Vector2(-750, 350),
		Vector2(-350, 700), Vector2(600, 400), Vector2(250, 600)
	]
	
	for i in range(mini(scouts_count, scout_positions.size())):
		var scout: CharacterBody2D = _enemy_scout_scene.instantiate()
		scout.name = "Scout_%d" % i
		scout.position = scout_positions[i]
		container.add_child(scout)
		
	for i in range(mini(spitters_count, spitter_positions.size())):
		var spitter: CharacterBody2D = _enemy_spitter_scene.instantiate()
		spitter.name = "Spitter_%d" % i
		spitter.position = spitter_positions[i]
		container.add_child(spitter)
		
	for i in range(mini(brutes_count, brute_positions.size())):
		var brute: CharacterBody2D = _enemy_brute_scene.instantiate()
		brute.name = "Brute_%d" % i
		brute.position = brute_positions[i]
		container.add_child(brute)


# ---------------------------------------------------------------------------
# Colossal Boss Spawning (Ancient Crater Basin)
# ---------------------------------------------------------------------------
func _spawn_boss(should_spawn: bool = true) -> void:
	var boss = get_node_or_null("GoliathPrime_Boss")
	if boss:
		boss.queue_free()
	
	if not should_spawn or not _boss_scene:
		return
	var new_boss: CharacterBody2D = _boss_scene.instantiate()
	new_boss.name = "GoliathPrime_Boss"
	new_boss.position = Vector2(560, -820) # Ancient Crater Basin North of Outpost
	add_child(new_boss)



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


func request_path_to_player(from_world_pos: Vector2, callback: Callable) -> void:
	if not map_data or not _player_ref:
		if callback.is_valid():
			callback.call(PackedVector2Array(), {"success": false, "error": "MapData or Player missing"})
		return
	var nav_mgr = get_node_or_null("/root/NavigationManager")
	if nav_mgr and nav_mgr.has_method("request_path"):
		nav_mgr.call("request_path", from_world_pos, _player_ref.global_position, map_data, callback)
	else:
		var p = map_data.get_path_points(from_world_pos, _player_ref.global_position)
		if callback.is_valid():
			callback.call(p, {"success": p.size() > 0, "source": "[FALLBACK_ASTAR2D]"})
