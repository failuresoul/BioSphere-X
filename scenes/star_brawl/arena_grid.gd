class_name ArenaGrid
extends RefCounted
## Turns the boss arena into a simple tile grid for the search algorithms.
##
## Each tile is CELL x CELL pixels. A tile is:
##   - SOLID  if it is inside the ground, a platform or a wall
##   - FREE   if it is empty and a fighter can reach it (a floor is at most
##            JUMP_TILES below it, in its own column or a neighbouring one)
##   - otherwise it is air that is too high to reach.
## Only FREE tiles can be used by a path; everything else is "blocked".

const CELL := 64
const JUMP_TILES := 4

var size := Vector2i.ZERO
var blocked := {}                    # Vector2i -> true (solid or unreachable)
var solid := {}                      # Vector2i -> true (ground / platforms / walls)


func build(arena_size: Vector2, solid_rects: Array[Rect2]) -> void:
	size = Vector2i(ceili(arena_size.x / CELL), ceili(arena_size.y / CELL))
	solid.clear()
	blocked.clear()
	for x in size.x:
		for y in size.y:
			var center := to_world(Vector2i(x, y))
			for rect in solid_rects:
				if rect.has_point(center):
					solid[Vector2i(x, y)] = true
	for x in size.x:
		for y in size.y:
			var cell := Vector2i(x, y)
			if solid.has(cell) or not _floor_below(cell):
				blocked[cell] = true


## True if a solid tile is within JUMP_TILES below this tile (same or next column).
func _floor_below(cell: Vector2i) -> bool:
	for dx in [-1, 0, 1]:
		for dy in range(1, JUMP_TILES + 1):
			if solid.has(cell + Vector2i(dx, dy)):
				return true
	return false


## World position (pixels) -> nearest FREE tile.
func to_cell(world: Vector2) -> Vector2i:
	# Use a point slightly above the fighter's centre so standing fighters map to the tile they stand in.
	var cell := Vector2i(clampi(floori(world.x / CELL), 0, size.x - 1), clampi(floori((world.y - 10.0) / CELL), 0, size.y - 1))
	if not blocked.has(cell):
		return cell
	var best := cell
	var best_distance := INF
	for other in free_cells():
		var distance := Vector2(other - cell).length()
		if distance < best_distance:
			best = other
			best_distance = distance
	return best


## Tile -> world position of its centre (pixels).
func to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * CELL + CELL * 0.5, cell.y * CELL + CELL * 0.5)


func free_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in size.x:
		for y in size.y:
			if not blocked.has(Vector2i(x, y)):
				cells.append(Vector2i(x, y))
	return cells


func all_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in size.x:
		for y in size.y:
			cells.append(Vector2i(x, y))
	return cells
