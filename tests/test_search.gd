extends Node
## Tests for the 6 search algorithms in scripts/utils/modular_pathfinder.gd
## and for the arena grid they search on.
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
	var shortest := 9 + 5 + 5 + 1    # go up to y=0, across, and back down (moves + 1 tiles)

	for algorithm in Pathfinder.ORDER:
		var result: Dictionary = Pathfinder.search(algorithm, start, goal, walls, size, 30)
		_check(result["found"], "%s finds a path around the wall" % algorithm)
		_check(_valid_path(result["path"], start, goal, walls, size), "%s path is connected and avoids walls" % algorithm)
		_check(result["nodes_expanded"] > 0 and result["time_ms"] >= 0.0, "%s reports nodes expanded and time" % algorithm)
		var unreachable := walls.duplicate()
		unreachable[Vector2i(4, 0)] = true
		_check(not Pathfinder.search(algorithm, start, goal, unreachable, size, 30)["found"], "%s reports no path when the wall is closed" % algorithm)
		_check(Pathfinder.search(algorithm, start, start, walls, size)["path"].size() == 1, "%s handles start == goal" % algorithm)

	# Optimal algorithms find the shortest path.
	for algorithm in ["iddfs", "bidirectional", "astar"]:
		_check(Pathfinder.search(algorithm, start, goal, walls, size, 30)["path"].size() == shortest, "%s finds the shortest path" % algorithm)
	# A* is guided by the Manhattan heuristic: fewer nodes than blind IDDFS.
	var astar: Dictionary = Pathfinder.astar(start, goal, walls, size)
	var iddfs: Dictionary = Pathfinder.iddfs(start, goal, walls, size, 30)
	_check(astar["nodes_expanded"] < iddfs["nodes_expanded"], "A* expands fewer nodes than IDDFS")
	# DLS stops at its depth limit.
	_check(not Pathfinder.dls(start, goal, walls, size, 5)["found"], "DLS fails when the goal is deeper than the limit")
	_check(Pathfinder.dls(start, goal, walls, size, 30)["found"], "DLS succeeds with a large enough limit")
	_check(Pathfinder.manhattan(Vector2i(1, 2), Vector2i(4, 6)) == 7, "Manhattan distance heuristic")

	# The boss arena grid: every algorithm can reach the top platform from the ground.
	var grid := GridScript.new()
	var solids: Array[Rect2] = [
		Rect2(0, 619, 1600, 78),            # ground
		Rect2(340, 463, 250, 18),           # left platform
		Rect2(1010, 463, 250, 18),          # right platform
		Rect2(690, 348, 220, 18),           # top platform
		Rect2(776, 555, 48, 64),            # wall
	]
	grid.build(Vector2(1600, 720), solids)
	var ground := grid.to_cell(Vector2(210, 585))
	var top := grid.to_cell(Vector2(800, 320))
	_check(not grid.blocked.has(ground) and not grid.blocked.has(top), "Fighter positions map to free tiles")
	_check(grid.solid.has(Vector2i(12, 9)) and grid.blocked.has(Vector2i(12, 9)), "Wall tile is solid and blocked")
	for algorithm in Pathfinder.ORDER:
		var result: Dictionary = Pathfinder.search(algorithm, ground, top, grid.blocked, grid.size, 30)
		_check(result["found"] and _valid_path(result["path"], ground, top, grid.blocked, grid.size), "%s reaches the top platform in the arena" % algorithm)

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
