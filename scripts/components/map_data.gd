extends RefCounted
class_name MapData
## Reusable structure storing alien map dimensions, cell types, and obstacle grids.
## Integrates Godot 4's native AStarGrid2D for instant, high-performance AI navigation.

enum CellType {
	WALKABLE = 0,
	BOUNDARY = 1,
	WALL = 2,
	ROCK = 3,
	DEBRIS = 4,
	RESOURCE = 5
}

var cell_size: float = 32.0
var grid_size: Vector2i = Vector2i(80, 80)
var world_origin: Vector2 = Vector2(-1280.0, -1280.0)
var world_size: Vector2 = Vector2(2560.0, 2560.0)

var _cells: PackedByteArray = PackedByteArray()
var _astar: AStarGrid2D = AStarGrid2D.new()


func _init(p_grid_size: Vector2i = Vector2i(80, 80), p_cell_size: float = 32.0, p_origin: Vector2 = Vector2(-1280.0, -1280.0)) -> void:
	setup(p_grid_size, p_cell_size, p_origin)


func setup(p_grid_size: Vector2i, p_cell_size: float, p_origin: Vector2) -> void:
	grid_size = p_grid_size
	cell_size = p_cell_size
	world_origin = p_origin
	world_size = Vector2(grid_size.x * cell_size, grid_size.y * cell_size)
	
	# Initialize cell grid buffer
	var total_cells: int = grid_size.x * grid_size.y
	_cells.resize(total_cells)
	_cells.fill(CellType.WALKABLE)
	
	# Configure Godot 4 native AStarGrid2D
	_astar.region = Rect2i(0, 0, grid_size.x, grid_size.y)
	_astar.cell_size = Vector2(cell_size, cell_size)
	_astar.offset = world_origin + Vector2(cell_size * 0.5, cell_size * 0.5)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_AT_LEAST_ONE_WALKABLE
	_astar.jumping_enabled = true
	_astar.update()


# ---------------------------------------------------------------------------
# Coordinate Conversion
# ---------------------------------------------------------------------------
func world_to_grid(world_pos: Vector2) -> Vector2i:
	var local: Vector2 = world_pos - world_origin
	var gx: int = int(floor(local.x / cell_size))
	var gy: int = int(floor(local.y / cell_size))
	return Vector2i(gx, gy)


func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return world_origin + Vector2(
		(float(grid_pos.x) + 0.5) * cell_size,
		(float(grid_pos.y) + 0.5) * cell_size
	)


func is_in_bounds(grid_pos: Vector2i) -> bool:
	return grid_pos.x >= 0 and grid_pos.x < grid_size.x and grid_pos.y >= 0 and grid_pos.y < grid_size.y


# ---------------------------------------------------------------------------
# Obstacle Blocking & Inspection
# ---------------------------------------------------------------------------
func set_cell_blocked(grid_pos: Vector2i, blocked: bool = true, type: int = CellType.WALL) -> void:
	if not is_in_bounds(grid_pos):
		return
	
	var idx: int = grid_pos.y * grid_size.x + grid_pos.x
	_cells[idx] = type if blocked else CellType.WALKABLE
	_astar.set_point_solid(grid_pos, blocked)


func set_world_rect_blocked(rect: Rect2, blocked: bool = true, type: int = CellType.WALL) -> void:
	var min_grid: Vector2i = world_to_grid(rect.position)
	var max_grid: Vector2i = world_to_grid(rect.end)
	
	for y in range(maxi(0, min_grid.y), mini(grid_size.y, max_grid.y + 1)):
		for x in range(maxi(0, min_grid.x), mini(grid_size.x, max_grid.x + 1)):
			set_cell_blocked(Vector2i(x, y), blocked, type)


func set_world_circle_blocked(center: Vector2, radius: float, blocked: bool = true, type: int = CellType.ROCK) -> void:
	var min_grid: Vector2i = world_to_grid(center - Vector2(radius, radius))
	var max_grid: Vector2i = world_to_grid(center + Vector2(radius, radius))
	var r_sq: float = radius * radius
	
	for y in range(maxi(0, min_grid.y), mini(grid_size.y, max_grid.y + 1)):
		for x in range(maxi(0, min_grid.x), mini(grid_size.x, max_grid.x + 1)):
			var cell_world := grid_to_world(Vector2i(x, y))
			if cell_world.distance_squared_to(center) <= r_sq:
				set_cell_blocked(Vector2i(x, y), blocked, type)


func is_cell_blocked(grid_pos: Vector2i) -> bool:
	if not is_in_bounds(grid_pos):
		return true # Out of bounds is blocked
	var idx: int = grid_pos.y * grid_size.x + grid_pos.x
	return _cells[idx] != CellType.WALKABLE


func is_world_blocked(world_pos: Vector2) -> bool:
	return is_cell_blocked(world_to_grid(world_pos))


func get_cell_type(grid_pos: Vector2i) -> int:
	if not is_in_bounds(grid_pos):
		return CellType.BOUNDARY
	var idx: int = grid_pos.y * grid_size.x + grid_pos.x
	return int(_cells[idx])


# ---------------------------------------------------------------------------
# Pathfinding Integration for AI
# ---------------------------------------------------------------------------
func get_path_points(from_world: Vector2, to_world: Vector2) -> PackedVector2Array:
	var start_grid := world_to_grid(from_world)
	var end_grid := world_to_grid(to_world)
	
	if not is_in_bounds(start_grid) or not is_in_bounds(end_grid):
		return PackedVector2Array()
	
	# Use native AStarGrid2D point path
	return _astar.get_point_path(start_grid, end_grid)


func get_fallback_path_points(from_world: Vector2, to_world: Vector2) -> PackedVector2Array:
	## Explicit fallback using Godot's built-in AStarGrid2D when Python backend is offline
	return get_path_points(from_world, to_world)


func get_blocked_cells() -> Array[Vector2i]:
	var blocked: Array[Vector2i] = []
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var idx: int = y * grid_size.x + x
			if _cells[idx] != CellType.WALKABLE:
				blocked.append(Vector2i(x, y))
	return blocked


func grid_to_world_path(grid_path: Array) -> PackedVector2Array:
	var world_path := PackedVector2Array()
	for pt in grid_path:
		if pt is Array and pt.size() >= 2:
			world_path.append(grid_to_world(Vector2i(int(pt[0]), int(pt[1]))))
		elif pt is Vector2i:
			world_path.append(grid_to_world(pt))
		elif pt is Vector2:
			world_path.append(pt)
	return world_path


func get_nearest_walkable_grid_pos(grid_pos: Vector2i, max_radius: int = 5) -> Vector2i:
	if is_in_bounds(grid_pos) and not is_cell_blocked(grid_pos):
		return grid_pos
	
	for r in range(1, max_radius + 1):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if abs(dx) != r and abs(dy) != r:
					continue
				var candidate := Vector2i(grid_pos.x + dx, grid_pos.y + dy)
				if is_in_bounds(candidate) and not is_cell_blocked(candidate):
					return candidate
	return grid_pos


func get_nearest_walkable_world_pos(world_pos: Vector2, max_radius: int = 5) -> Vector2:
	var g_pos := world_to_grid(world_pos)
	var walkable_g := get_nearest_walkable_grid_pos(g_pos, max_radius)
	return grid_to_world(walkable_g)


func get_astar() -> AStarGrid2D:
	return _astar


func get_obstacle_summary() -> Dictionary:
	var counts := {
		"walkable": 0,
		"boundary": 0,
		"wall": 0,
		"rock": 0,
		"debris": 0,
		"resource": 0
	}
	for b in _cells:
		match b:
			CellType.WALKABLE: counts["walkable"] += 1
			CellType.BOUNDARY: counts["boundary"] += 1
			CellType.WALL: counts["wall"] += 1
			CellType.ROCK: counts["rock"] += 1
			CellType.DEBRIS: counts["debris"] += 1
			CellType.RESOURCE: counts["resource"] += 1
	return counts
