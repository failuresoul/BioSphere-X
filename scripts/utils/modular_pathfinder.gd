class_name ModularPathfinder
extends RefCounted
## LOCAL BACKUP path finder: A* only.
##
## The 7 search algorithms (BFS, DFS, DLS, IDDFS, Bidirectional, Greedy, A*)
## run on the Python server: ai_backend/algorithms/pathfinding/.
## If the server does not answer in time, path_planner.gd calls astar() below
## so the game keeps working.
##
## Grid: `blocked` holds the tiles that cannot be entered (walls, platforms,
## ground, unreachable air). Moves are 4-directional and every move costs 1.

## Algorithms offered by the server (key -> name shown on screen).
const NAMES := {
	"bfs": "BFS",
	"dfs": "DFS",
	"dls": "DLS",
	"iddfs": "IDDFS",
	"bidirectional": "Bidirectional",
	"greedy": "Greedy",
	"astar": "A*",
}
const ORDER: Array[String] = ["bfs", "dfs", "dls", "iddfs", "bidirectional", "greedy", "astar"]
const DIRECTIONS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]


## A* Search: always expands the tile with the lowest f(n) = g(n) + h(n).
##   g(n) = number of moves from the start so far
##   h(n) = Manhattan distance to the goal (never over-estimates)
## So the first time the goal is expanded, the path is the shortest one.
## Returns {"found", "path", "nodes_expanded", "time_ms", "algorithm"}.
static func astar(start: Vector2i, goal: Vector2i, blocked: Dictionary, size: Vector2i) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var open: Array[Vector2i] = [start]      # tiles waiting to be expanded
	var came_from := {start: start}          # parent of each tile (to rebuild the path)
	var g := {start: 0}                      # cost so far
	var closed := {}                         # tiles already expanded
	var expanded := 0
	while not open.is_empty():
		# Pick the open tile with the lowest f = g + h (on a tie: the larger g).
		var best := 0
		for i in open.size():
			var f_i: int = g[open[i]] + manhattan(open[i], goal)
			var f_best: int = g[open[best]] + manhattan(open[best], goal)
			if f_i < f_best or (f_i == f_best and g[open[i]] > g[open[best]]):
				best = i
		var cell: Vector2i = open.pop_at(best)
		if closed.has(cell):
			continue
		closed[cell] = true
		expanded += 1
		if cell == goal:
			return _result(true, _make_path(came_from, goal), expanded, t0)
		for next in neighbors(cell, blocked, size):
			var cost: int = g[cell] + 1
			if not g.has(next) or cost < g[next]:
				g[next] = cost
				came_from[next] = cell
				open.push_back(next)
	return _result(false, [], expanded, t0)


## Manhattan distance heuristic: |dx| + |dy|.
static func manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## Walkable tiles next to `cell` (inside the grid and not blocked).
static func neighbors(cell: Vector2i, blocked: Dictionary, size: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for direction in DIRECTIONS:
		var next := cell + direction
		if next.x >= 0 and next.y >= 0 and next.x < size.x and next.y < size.y and not blocked.has(next):
			result.append(next)
	return result


## Follows the parent links back from the goal to the start.
static func _make_path(came_from: Dictionary, goal: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [goal]
	var cell := goal
	while came_from[cell] != cell:
		cell = came_from[cell]
		path.push_front(cell)
	return path


static func _result(found: bool, path: Array, expanded: int, t0: int) -> Dictionary:
	return {
		"algorithm": "astar",
		"found": found,
		"path": path,
		"nodes_expanded": expanded,
		"time_ms": (Time.get_ticks_usec() - t0) / 1000.0,
	}
