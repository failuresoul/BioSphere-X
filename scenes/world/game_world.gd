extends Node2D
## Game world — procedurally generates the alien exoplanet environment.
## Creates ground, boundaries, rocks, plants, obstacles, and spawns the player.

const WORLD_SIZE := Vector2(3000, 3000)
const WORLD_ORIGIN := Vector2(-1500, -1500)
const BOUNDARY_THICKNESS := 16.0

const NUM_ROCKS := 25
const NUM_PLANTS := 40
const NUM_OBSTACLES := 6
const MIN_SPACING := 60.0
const PLAYER_SAFE_RADIUS := 120.0

var _player_scene := preload("res://scenes/player/player.tscn")
var _rock_script := preload("res://scripts/components/alien_rock.gd")
var _plant_script := preload("res://scripts/components/alien_plant.gd")
var _ground_script := preload("res://scripts/components/ground_layer.gd")
var _obstacle_script := preload("res://scripts/components/alien_obstacle.gd")

var _occupied: Array[Vector2] = []


func _ready() -> void:
	_build_ground()
	_build_boundaries()
	_build_rocks()
	_build_plants()
	_build_obstacles()
	_spawn_player()
	print("BioSphere-X: Game world generated.")


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
# Boundaries  (energy-barrier walls around the map)
# ---------------------------------------------------------------------------
func _build_boundaries() -> void:
	var container := Node2D.new()
	container.name = "Boundaries"
	add_child(container)
	var edge_x := WORLD_ORIGIN.x + WORLD_SIZE.x  # 1500
	var edge_y := WORLD_ORIGIN.y + WORLD_SIZE.y   # 1500
	# Top, Bottom, Left, Right
	_add_wall(container, Vector2(0, WORLD_ORIGIN.y),
		Vector2(WORLD_SIZE.x + BOUNDARY_THICKNESS * 2, BOUNDARY_THICKNESS))
	_add_wall(container, Vector2(0, edge_y),
		Vector2(WORLD_SIZE.x + BOUNDARY_THICKNESS * 2, BOUNDARY_THICKNESS))
	_add_wall(container, Vector2(WORLD_ORIGIN.x, 0),
		Vector2(BOUNDARY_THICKNESS, WORLD_SIZE.y))
	_add_wall(container, Vector2(edge_x, 0),
		Vector2(BOUNDARY_THICKNESS, WORLD_SIZE.y))


func _add_wall(parent: Node, pos: Vector2, size: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.position = pos
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	wall.add_child(col)
	# Energy barrier visual
	var vis := ColorRect.new()
	vis.color = Color(0.91, 0.27, 0.37, 0.65)
	vis.size = size
	vis.position = -size / 2
	wall.add_child(vis)
	parent.add_child(wall)


# ---------------------------------------------------------------------------
# Rocks
# ---------------------------------------------------------------------------
func _build_rocks() -> void:
	var container := Node2D.new()
	container.name = "Rocks"
	add_child(container)
	for i in NUM_ROCKS:
		var rock := StaticBody2D.new()
		rock.name = "Rock_%d" % i
		rock.set_script(_rock_script)
		rock.position = _safe_position(80.0)
		container.add_child(rock)
		rock.setup(randf_range(15.0, 35.0))


# ---------------------------------------------------------------------------
# Plants
# ---------------------------------------------------------------------------
func _build_plants() -> void:
	var container := Node2D.new()
	container.name = "Plants"
	container.z_index = -1
	add_child(container)
	for i in NUM_PLANTS:
		var plant := Node2D.new()
		plant.name = "Plant_%d" % i
		plant.set_script(_plant_script)
		plant.position = _safe_position(30.0)
		container.add_child(plant)
		plant.setup()


# ---------------------------------------------------------------------------
# Large obstacles
# ---------------------------------------------------------------------------
func _build_obstacles() -> void:
	var container := Node2D.new()
	container.name = "Obstacles"
	add_child(container)
	for i in NUM_OBSTACLES:
		var obs := StaticBody2D.new()
		obs.name = "Obstacle_%d" % i
		obs.set_script(_obstacle_script)
		obs.position = _safe_position(120.0)
		obs.rotation = randf_range(-0.3, 0.3)
		container.add_child(obs)
		obs.setup(randf_range(40.0, 80.0), randf_range(30.0, 60.0))


# ---------------------------------------------------------------------------
# Player
# ---------------------------------------------------------------------------
func _spawn_player() -> void:
	var player := _player_scene.instantiate()
	player.name = "Player"
	player.position = Vector2.ZERO
	add_child(player)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
func _safe_position(margin: float) -> Vector2:
	for attempt in 50:
		var pos := Vector2(
			randf_range(WORLD_ORIGIN.x + margin, WORLD_ORIGIN.x + WORLD_SIZE.x - margin),
			randf_range(WORLD_ORIGIN.y + margin, WORLD_ORIGIN.y + WORLD_SIZE.y - margin)
		)
		if pos.length() < PLAYER_SAFE_RADIUS:
			continue
		var too_close := false
		for occ in _occupied:
			if pos.distance_to(occ) < MIN_SPACING:
				too_close = true
				break
		if not too_close:
			_occupied.append(pos)
			return pos
	# Fallback — just pick something
	var fb := Vector2(randf_range(-1200, 1200), randf_range(-1200, 1200))
	_occupied.append(fb)
	return fb
