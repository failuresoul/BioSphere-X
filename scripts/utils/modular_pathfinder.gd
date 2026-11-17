class_name ModularPathfinder
extends RefCounted
## All search algorithms used by the game, in one place.
##
## The arena is a grid of cells (Vector2i). `blocked` holds the cells that
## cannot be entered (walls, platforms, ground, air that is out of jump reach).
## Moves are 4-directional (left, right, up, down) and every move costs 1.
##
## Every algorithm has the SAME signature so they are easy to swap:
##     func name(start, goal, blocked, size, depth_limit) -> Dictionary
## and returns the same result:
##     {"found": bool, "path": Array[Vector2i], "nodes_expanded": int, "time_ms": float}

## Algorithm key -> name shown on screen.
const NAMES := {
	"dfs": "DFS",
	"dls": "DLS",
	"iddfs": "IDDFS",
	"bidirectional": "Bidirectional",
	"greedy": "Best-First",
	"astar": "A*",
}
const ORDER: Array[String] = ["dfs", "dls", "iddfs", "bidirectional", "greedy", "astar"]
const DIRECTIONS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]


## Runs the algorithm called `algorithm` (a key of NAMES).
static func search(algorithm: String, start: Vector2i, goal: Vector2i, blocked: Dictionary, size: Vector2i, depth_limit: int = 30) -> Dictionary:
	match algorithm:
		"dfs": return dfs(start, goal, blocked, size, depth_limit)
		"dls": return dls(start, goal, blocked, size, depth_limit)
		"iddfs": return iddfs(start, goal, blocked, size, depth_limit)
		"bidirectional": return bidirectional(start, goal, blocked, size, depth_limit)
		"greedy": return greedy_best_first(start, goal, blocked, size, depth_limit)
		_: return astar(start, goal, blocked, size, depth_limit)


# ---------------------------------------------------------------------------
# UNINFORMED SEARCH (no knowledge of where the goal is)
# ---------------------------------------------------------------------------

## Depth-First Search: always expands the newest cell (a stack).
## Finds A path, usually not the shortest one.
static func dfs(start: Vector2i, goal: Vector2i, blocked: Dictionary, size: Vector2i, _depth_limit: int = 30) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var stack: Array[Vector2i] = [start]
	var came_from := {start: start}
	var expanded := 0
	while not stack.is_empty():
		var cell: Vector2i = stack.pop_back()
		expanded += 1
		if cell == goal:
			return _result(true, _make_path(came_from, goal), expanded, t0)
		for next in _neighbors(cell, blocked, size):
			if not came_from.has(next):
				came_from[next] = cell
				stack.push_back(next)
	return _result(false, [], expanded, t0)


## Depth-Limited Search: DFS that never goes deeper than `depth_limit` moves.
## Fails if the goal is further away than the limit.
static func dls(start: Vector2i, goal: Vector2i, blocked: Dictionary, size: Vector2i, depth_limit: int = 30) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var run := _depth_limited(start, goal, blocked, size, depth_limit)
	var path: Array = _make_path(run["came_from"], goal) if run["found"] else []
	return _result(run["found"], path, run["expanded"], t0)


## Iterative Deepening DFS: runs DLS with limit 0, 1, 2, ... until the goal is found.
## Finds the shortest path like BFS but uses little memory like DFS.
static func iddfs(start: Vector2i, goal: Vector2i, blocked: Dictionary, size: Vector2i, depth_limit: int = 30) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var expanded := 0
	for limit in range(depth_limit + 1):
		var run := _depth_limited(start, goal, blocked, size, limit)
		expanded += run["expanded"]
		if run["found"]:
			return _result(true, _make_path(run["came_from"], goal), expanded, t0)
	return _result(false, [], expanded, t0)


## Bidirectional Search: a BFS from the start and a BFS from the goal at the
## same time. Stops when the two searches meet in the middle.
static func bidirectional(start: Vector2i, goal: Vector2i, blocked: Dictionary, size: Vector2i, _depth_limit: int = 30) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	if start == goal:
		return _result(true, [start], 1, t0)
	var queues: Array = [[start], [goal]]          # [forward queue, backward queue]
	var parents: Array = [{start: start}, {goal: goal}]
	var expanded := 0
	while not queues[0].is_empty() and not queues[1].is_empty():
		for side in 2:                              # 0 = forward step, 1 = backward step
			var cell: Vector2i = queues[side].pop_front()
			expanded += 1
			for next in _neighbors(cell, blocked, size):
				if parents[side].has(next):
					continue
				parents[side][next] = cell
				queues[side].push_back(next)
				if parents[1 - side].has(next):     # the two searches met at `next`
					var path := _make_path(parents[0], next)
					var back := _make_path(parents[1], next)   # goal ... next
					back.reverse()
					path.append_array(back.slice(1))           # next ... goal
					return _result(true, path, expanded, t0)
			if queues[side].is_empty():
				break
	return _result(false, [], expanded, t0)


# ---------------------------------------------------------------------------
# INFORMED SEARCH (uses the Manhattan distance heuristic h(n))
# ---------------------------------------------------------------------------

## Greedy Best-First Search: always expands the cell that LOOKS closest to the
## goal, f(n) = h(n). Fast, but the path is not always the shortest.
static func greedy_best_first(start: Vector2i, goal: Vector2i, blocked: Dictionary, size: Vector2i, _depth_limit: int = 30) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var open: Array[Vector2i] = [start]
	var came_from := {start: start}
	var expanded := 0
	while not open.is_empty():
		var best := 0
		for i in open.size():                       # pick the lowest h(n)
			if manhattan(open[i], goal) < manhattan(open[best], goal):
				best = i
		var cell: Vector2i = open.pop_at(best)
		expanded += 1
		if cell == goal:
			return _result(true, _make_path(came_from, goal), expanded, t0)
		for next in _neighbors(cell, blocked, size):
			if not came_from.has(next):
				came_from[next] = cell
				open.push_back(next)
	return _result(false, [], expanded, t0)


## A* Search: expands the cell with the lowest f(n) = g(n) + h(n), where g is
## the cost so far. With Manhattan distance it always finds the shortest path.
static func astar(start: Vector2i, goal: Vector2i, blocked: Dictionary, size: Vector2i, _depth_limit: int = 30) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var open: Array[Vector2i] = [start]
	var came_from := {start: start}
	var g := {start: 0}
	var closed := {}
	var expanded := 0
	while not open.is_empty():
		var best := 0
		for i in open.size():                       # pick the lowest f(n) = g(n) + h(n)
			if g[open[i]] + manhattan(open[i], goal) < g[open[best]] + manhattan(open[best], goal):
				best = i
		var cell: Vector2i = open.pop_at(best)
		if closed.has(cell):
			continue
		closed[cell] = true
		expanded += 1
		if cell == goal:
			return _result(true, _make_path(came_from, goal), expanded, t0)
		for next in _neighbors(cell, blocked, size):
			var cost: int = g[cell] + 1
			if not g.has(next) or cost < g[next]:
				g[next] = cost
				came_from[next] = cell
				open.push_back(next)
	return _result(false, [], expanded, t0)


# ---------------------------------------------------------------------------
# Helpers shared by all algorithms
# ---------------------------------------------------------------------------

## Manhattan distance heuristic: |dx| + |dy|.
static func manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## Free cells next to `cell` (inside the grid and not blocked).
static func _neighbors(cell: Vector2i, blocked: Dictionary, size: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for direction in DIRECTIONS:
		var next := cell + direction
		if next.x >= 0 and next.y >= 0 and next.x < size.x and next.y < size.y and not blocked.has(next):
			result.append(next)
	return result


## DFS with a depth limit (used by DLS and IDDFS). A cell is visited again
## only if we reach it with fewer moves than before.
static func _depth_limited(start: Vector2i, goal: Vector2i, blocked: Dictionary, size: Vector2i, limit: int) -> Dictionary:
	var stack: Array = [[start, 0]]                 # [cell, depth]
	var came_from := {start: start}
	var best_depth := {start: 0}
	var expanded := 0
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		var cell: Vector2i = item[0]
		var depth: int = item[1]
		expanded += 1
		if cell == goal:
			return {"found": true, "came_from": came_from, "expanded": expanded}
		if depth >= limit:
			continue                                # depth limit reached: do not go deeper
		for next in _neighbors(cell, blocked, size):
			if not best_depth.has(next) or depth + 1 < best_depth[next]:
				best_depth[next] = depth + 1
				came_from[next] = cell
				stack.push_back([next, depth + 1])
	return {"found": false, "came_from": came_from, "expanded": expanded}


## Follows the came_from links back from `goal` to the start.
static func _make_path(came_from: Dictionary, goal: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [goal]
	var cell := goal
	while came_from[cell] != cell:
		cell = came_from[cell]
		path.push_front(cell)
	return path


static func _result(found: bool, path: Array, expanded: int, t0: int) -> Dictionary:
	return {
		"found": found,
		"path": path,
		"nodes_expanded": expanded,
		"time_ms": (Time.get_ticks_usec() - t0) / 1000.0,
	}
