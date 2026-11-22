extends Node
## Tests for the LOCAL backup A* (scripts/utils/modular_pathfinder.gd) and the
## arena grid. The 7 server algorithms are tested with pytest
## (ai_backend/tests/test_pathfinding.py).
## Run: godot --headless --path . res://tests/test_search.tscn

const Pathfinder = preload("res://scripts/utils/modular_pathfinder.gd")
const GridScript = preload("res://scenes/star_brawl/arena_grid.gd")

var failures := 0


func _ready() -> void:
	var size := Vector2i(10, 6)
	# A wall at x = 4 with one gap at the top (y = 0).
	var walls := {}
	for y in range(1, 6):
		walls[Vector2i(4, y)] = true
	var start := Vector2i(0, 5)
	var goal := Vector2i(9, 5)
	var shortest := 20               # 19 moves -> 20 tiles

	var result: Dictionary = Pathfinder.astar(start, goal, walls, size)
	_check(result["found"] and result["algorithm"] == "astar", "A* finds a path around the wall")
	_check(_valid_path(result["path"], start, goal, walls, size), "A* path is connected and avoids walls")
	_check(result["path"].size() == shortest, "A* path is the shortest (%d tiles)" % result["path"].size())
	_check(result["nodes_expanded"] > 0 and result["time_ms"] >= 0.0, "A* reports nodes expanded and time")
	var closed := walls.duplicate()
	closed[Vector2i(4, 0)] = true
	_check(not Pathfinder.astar(start, goal, closed, size)["found"], "A* reports no path when the wall is closed")
	_check(Pathfinder.astar(start, start, walls, size)["path"].size() == 1, "A* handles start == goal")
	_check(Pathfinder.manhattan(Vector2i(1, 2), Vector2i(4, 6)) == 7, "Manhattan distance heuristic")
	_check(Pathfinder.ORDER.size() == 7 and Pathfinder.ORDER.has("bfs"), "7 server algorithms are listed")

	# The boss arena grid.
	var grid := GridScript.new()
	var solids: Array[Rect2] = [
		Rect2(0, 619, 1600, 78),            # ground
		Rect2(320, 463, 256, 18),           # left platform
		Rect2(1024, 463, 256, 18),          # right platform
		Rect2(704, 335, 192, 18),           # top platform
		Rect2(768, 555, 64, 64),            # wall
	]
	grid.build(Vector2(1600, 720), solids)
	var ground := grid.to_cell(Vector2(210, 585))
	var top := grid.to_cell(Vector2(800, 320))
	_check(not grid.blocked.has(ground) and not grid.blocked.has(top), "Fighter positions map to walkable tiles")
	_check(grid.solid.has(Vector2i(12, 9)) and grid.rows[9][12] == 1, "Wall tile is blocked (1) in the grid rows")
	_check(grid.rows.size() == grid.size.y and grid.rows[0].size() == grid.size.x, "Grid rows match the grid size")
	var arena_path: Dictionary = Pathfinder.astar(ground, top, grid.blocked, grid.size)
	_check(arena_path["found"] and _valid_path(arena_path["path"], ground, top, grid.blocked, grid.size), "A* reaches the top platform in the arena")

	print("Search tests: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	get_tree().quit(0 if failures == 0 else 1)


func _valid_path(path: Array, start: Vector2i, goal: Vector2i, blocked: Dictionary, size: Vector2i) -> bool:
	if path.is_empty() or path[0] != start or path[-1] != goal:
		return false
	for i in path.size():
		var cell: Vector2i = path[i]
		if blocked.has(cell) or cell.x < 0 or cell.y < 0 or cell.x >= size.x or cell.y >= size.y:
			return false
		if i > 0 and Pathfinder.manhattan(cell, path[i - 1]) != 1:
			return false
	return true


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  [PASS] %s" % label)
	else:
		failures += 1
		push_error("  [FAIL] %s" % label)
