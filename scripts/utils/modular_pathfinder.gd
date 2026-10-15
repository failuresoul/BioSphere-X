class_name ModularPathfinder
extends RefCounted
## BioSphere-X Modular Pathfinding Engine.
## Implements BFS, DFS, DLS, IDDFS, Greedy Best-First Search, A*, and Bidirectional Search.
## Standardizes inputs (start cell, goal cell, blocked data, grid dimensions)
## and outputs (path, nodes expanded, time, suitability notes) across all algorithms.
## Fully decoupled from enemy animation, physics bodies, and combat logic.

const ALGORITHMS: Array[String] = [
	"astar",
	"bfs",
	"dfs",
	"dls",
	"iddfs",
	"bidirectional",
	"greedy"
]

const ALGORITHM_PROFILES: Dictionary = {
	"astar": {
		"name": "A* Search",
		"optimal": true,
		"complete": true,
		"gameplay_suitable": true,
		"description": "Heuristic-guided optimal search balancing cost g(n) and estimated distance h(n).",
		"suitability": "Ideal default choice for real-time game navigation and enemy tracking.",
		"caveats": "Requires an admissible heuristic. Slightly higher memory than greedy search."
	},
	"bfs": {
		"name": "Breadth-First Search (BFS)",
		"optimal": true,
		"complete": true,
		"gameplay_suitable": false,
		"description": "Exhaustive level-by-level frontier expansion. Guarantees fewest steps on uniform grids.",
		"suitability": "Good for small grids or flood-fill range queries.",
		"caveats": "High memory consumption O(b^d). Expands blindly in all directions regardless of goal direction. Not suitable for large open worlds."
	},
	"dfs": {
		"name": "Depth-First Search (DFS)",
		"optimal": false,
		"complete": true,
		"gameplay_suitable": false,
		"description": "Explores deeply down single paths before backtracking.",
		"suitability": "Useful for maze generation and full connectivity audits.",
		"caveats": "NOT SUITABLE for game navigation! Produces highly erratic, unnatural paths with excessive step counts."
	},
	"dls": {
		"name": "Depth-Limited Search (DLS)",
		"optimal": false,
		"complete": false,
		"gameplay_suitable": false,
		"description": "DFS constrained by a maximum depth limit to prevent infinite runaway search.",
		"suitability": "Useful for horizon-bounded queries (e.g. short-range dashes).",
		"caveats": "Incomplete: Fails to find paths when the goal lies beyond the configured depth limit."
	},
	"iddfs": {
		"name": "Iterative Deepening DFS (IDDFS)",
		"optimal": true,
		"complete": true,
		"gameplay_suitable": false,
		"description": "Combines DFS space efficiency O(bd) with BFS step-count optimality by successively deepening search.",
		"suitability": "Excellent when memory is extremely constrained.",
		"caveats": "Re-expands nodes repeatedly. High CPU overhead makes it unsuited for frequent 60 FPS enemy updates."
	},
	"bidirectional": {
		"name": "Bidirectional Search",
		"optimal": true,
		"complete": true,
		"gameplay_suitable": true,
		"description": "Simultaneously expands frontiers forward from start and backward from goal until they intersect.",
		"suitability": "Very fast for point-to-point pathfinding between two known stationary targets.",
		"caveats": "Requires a known static goal point. Less practical if the target is rapidly moving or non-point."
	},
	"greedy": {
		"name": "Greedy Best-First Search",
		"optimal": false,
		"complete": true,
		"gameplay_suitable": false,
		"description": "Prioritizes frontier nodes solely based on heuristic distance h(n) to the goal.",
		"suitability": "Very fast approximations across open terrain.",
		"caveats": "Not optimal. Easily trapped in concave obstacles / U-shaped walls, leading to large detours."
	}
}


# ---------------------------------------------------------------------------
# Public Unified Interface
# ---------------------------------------------------------------------------
static func search(
	algorithm: String,
	start: Vector2i,
	goal: Vector2i,
	blocked_data: Variant, # Array[Vector2i], Dictionary, or Callable
	grid_size: Vector2i = Vector2i(80, 80),
	options: Dictionary = {}
) -> Dictionary:
	var algo := algorithm.strip_edges().to_lower()
	var allow_diag: bool = bool(options.get("allow_diagonal", true))
	var depth_limit: int = int(options.get("depth_limit", 100))
	var max_depth: int = int(options.get("max_depth", grid_size.x * grid_size.y))
	
	# Blocked lookup map for O(1) checks
	var blocked_set: Dictionary = _normalize_blocked_cells(blocked_data)
	
	# Validation
	var val := _validate_bounds_and_obstacles(start, goal, grid_size, blocked_set)
	if not val["valid"]:
		return _build_response(false, [], 0, 0.0, algo, val["message"])
	
	if start == goal:
		return _build_response(true, [start], 1, 0.0, algo, "Start is goal")
	
	match algo:
		"astar", "a*", "a_star":
			return _search_astar(start, goal, blocked_set, grid_size, allow_diag)
		"bfs", "breadth_first":
			return _search_bfs(start, goal, blocked_set, grid_size, allow_diag)
		"dfs", "depth_first":
			return _search_dfs(start, goal, blocked_set, grid_size, allow_diag)
		"dls", "depth_limited":
			return _search_dls(start, goal, blocked_set, grid_size, allow_diag, depth_limit)
		"iddfs", "iterative_deepening":
			return _search_iddfs(start, goal, blocked_set, grid_size, allow_diag, max_depth)
		"bidirectional", "bibfs":
			return _search_bidirectional(start, goal, blocked_set, grid_size, allow_diag)
		"greedy", "best_first":
			return _search_greedy(start, goal, blocked_set, grid_size, allow_diag)
		_:
			# Default to A* with advisory notice
			var res := _search_astar(start, goal, blocked_set, grid_size, allow_diag)
			res["message"] = "Unknown algorithm '%s', defaulted to A*. %s" % [algorithm, res["message"]]
			return res


static func get_algorithm_profile(algorithm: String) -> Dictionary:
	var key := algorithm.strip_edges().to_lower()
	if ALGORITHM_PROFILES.has(key):
		return ALGORITHM_PROFILES[key]
	return {
		"name": algorithm,
		"optimal": false,
		"complete": false,
		"gameplay_suitable": false,
		"description": "Custom or unknown algorithm.",
		"suitability": "Unknown",
		"caveats": "No profile available."
	}


# ---------------------------------------------------------------------------
# 1. A* Search (Optimal & Heuristic Guided)
# ---------------------------------------------------------------------------
static func _search_astar(
	start: Vector2i,
	goal: Vector2i,
	blocked: Dictionary,
	grid_size: Vector2i,
	allow_diag: bool
) -> Dictionary:
	var t_start := Time.get_ticks_usec()
	var open_set: Array[Dictionary] = [] # Min-heap elements: {f, h, node, seq}
	var seq: int = 0
	
	var start_h := _heuristic(start, goal, allow_diag)
	_heap_push(open_set, {"f": start_h, "h": start_h, "node": start, "seq": seq})
	
	var came_from: Dictionary = {}
	var g_score: Dictionary = {start: 0.0}
	var in_open: Dictionary = {start: true}
	var closed: Dictionary = {}
	var nodes_expanded: int = 0
	
	while open_set.size() > 0:
		var current_item: Dictionary = _heap_pop(open_set)
		var current: Vector2i = current_item["node"]
		in_open.erase(current)
		closed[current] = true
		nodes_expanded += 1
		
		if current == goal:
			var path := _reconstruct_path(came_from, current)
			var elapsed_ms := float(Time.get_ticks_usec() - t_start) / 1000.0
			return _build_response(true, path, nodes_expanded, elapsed_ms, "astar", "Optimal path found (%d steps)" % path.size())
		
		for edge in _get_neighbors(current, grid_size, blocked, allow_diag):
			var neighbor: Vector2i = edge["node"]
			var cost: float = edge["cost"]
			
			if closed.has(neighbor):
				continue
			
			var tentative_g: float = g_score[current] + cost
			var neighbor_g: float = g_score.get(neighbor, INF)
			
			if tentative_g < neighbor_g:
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				var h := _heuristic(neighbor, goal, allow_diag)
				var f := tentative_g + h
				
				if not in_open.has(neighbor):
					seq += 1
					_heap_push(open_set, {"f": f, "h": h, "node": neighbor, "seq": seq})
					in_open[neighbor] = true
	
	var elapsed_ms := float(Time.get_ticks_usec() - t_start) / 1000.0
	return _build_response(false, [], nodes_expanded, elapsed_ms, "astar", "Goal is unreachable (No path exists)")


# ---------------------------------------------------------------------------
# 2. Breadth-First Search (BFS)
# ---------------------------------------------------------------------------
static func _search_bfs(
	start: Vector2i,
	goal: Vector2i,
	blocked: Dictionary,
	grid_size: Vector2i,
	allow_diag: bool
) -> Dictionary:
	var t_start := Time.get_ticks_usec()
	var queue: Array[Vector2i] = [start]
	var head: int = 0
	var visited: Dictionary = {start: true}
	var came_from: Dictionary = {}
	var nodes_expanded: int = 0
	
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		nodes_expanded += 1
		
		if current == goal:
			var path := _reconstruct_path(came_from, current)
			var elapsed_ms := float(Time.get_ticks_usec() - t_start) / 1000.0
			return _build_response(true, path, nodes_expanded, elapsed_ms, "bfs", "BFS path found (%d steps)" % path.size())
		
		for edge in _get_neighbors(current, grid_size, blocked, allow_diag):
			var neighbor: Vector2i = edge["node"]
			if not visited.has(neighbor):
				visited[neighbor] = true
				came_from[neighbor] = current
				queue.append(neighbor)
	
	var elapsed_ms := float(Time.get_ticks_usec() - t_start) / 1000.0
	return _build_response(false, [], nodes_expanded, elapsed_ms, "bfs", "Goal is unreachable (Exhausted connected component)")


# ---------------------------------------------------------------------------
# 3. Depth-First Search (DFS)
# ---------------------------------------------------------------------------
static func _search_dfs(
	start: Vector2i,
	goal: Vector2i,
	blocked: Dictionary,
	grid_size: Vector2i,
	allow_diag: bool
) -> Dictionary:
	var t_start := Time.get_ticks_usec()
	var stack: Array[Vector2i] = [start]
	var visited: Dictionary = {start: true}
	var came_from: Dictionary = {}
	var nodes_expanded: int = 0
	
	while stack.size() > 0:
		var current: Vector2i = stack.pop_back()
		nodes_expanded += 1
		
		if current == goal:
			var path := _reconstruct_path(came_from, current)
			var elapsed_ms := float(Time.get_ticks_usec() - t_start) / 1000.0
			return _build_response(true, path, nodes_expanded, elapsed_ms, "dfs", "DFS path found (%d steps) [Suboptimal by design]" % path.size())
		
		for edge in _get_neighbors(current, grid_size, blocked, allow_diag):
			var neighbor: Vector2i = edge["node"]
			if not visited.has(neighbor):
				visited[neighbor] = true
				came_from[neighbor] = current
				stack.append(neighbor)
	
	var elapsed_ms := float(Time.get_ticks_usec() - t_start) / 1000.0
	return _build_response(false, [], nodes_expanded, elapsed_ms, "dfs", "Goal is unreachable")


# ---------------------------------------------------------------------------
# 4. Depth-Limited Search (DLS)
# ---------------------------------------------------------------------------
static func _search_dls(
	start: Vector2i,
	goal: Vector2i,
	blocked: Dictionary,
	grid_size: Vector2i,
	allow_diag: bool,
	depth_limit: int
) -> Dictionary:
	var t_start := Time.get_ticks_usec()
	# Stack items: {"node": Vector2i, "depth": int}
	var stack: Array[Dictionary] = [{"node": start, "depth": 0}]
	var visited_depth: Dictionary = {start: 0}
	var came_from: Dictionary = {}
	var nodes_expanded: int = 0
	var cutoff_occurred: bool = false
	
	while stack.size() > 0:
		var item: Dictionary = stack.pop_back()
		var current: Vector2i = item["node"]
		var depth: int = item["depth"]
		nodes_expanded += 1
		
		if current == goal:
			var path := _reconstruct_path(came_from, current)
			var elapsed_ms := float(Time.get_ticks_usec() - t_start) / 1000.0
			return _build_response(true, path, nodes_expanded, elapsed_ms, "dls", "DLS path found within limit %d (%d steps)" % [depth_limit, path.size()])
		
		if depth >= depth_limit:
			cutoff_occurred = true
			continue
		
		for edge in _get_neighbors(current, grid_size, blocked, allow_diag):
			var neighbor: Vector2i = edge["node"]
			var next_depth: int = depth + 1
			if not visited_depth.has(neighbor) or next_depth < visited_depth[neighbor]:
				visited_depth[neighbor] = next_depth
				came_from[neighbor] = current
				stack.append({"node": neighbor, "depth": next_depth})
	
	var elapsed_ms := float(Time.get_ticks_usec() - t_start) / 1000.0
	var msg := "Depth limit %d exceeded (Cutoff)" % depth_limit if cutoff_occurred else "Goal is unreachable within bounds"
	return _build_response(false, [], nodes_expanded, elapsed_ms, "dls", msg)


# ---------------------------------------------------------------------------
# 5. Iterative Deepening DFS (IDDFS)
# ---------------------------------------------------------------------------
static func _search_iddfs(
	start: Vector2i,
	goal: Vector2i,
	blocked: Dictionary,
	grid_size: Vector2i,
	allow_diag: bool,
	max_depth: int
) -> Dictionary:
	var t_start := Time.get_ticks_usec()
	var total_expanded: int = 0
	
	for limit in range(0, max_depth + 1):
		var stack: Array[Dictionary] = [{"node": start, "depth": 0}]
		var visited_depth: Dictionary = {start: 0}
		var came_from: Dictionary = {}
		var cutoff: bool = false
		
		while stack.size() > 0:
			var item: Dictionary = stack.pop_back()
			var current: Vector2i = item["node"]
			var depth: int = item["depth"]
			total_expanded += 1
			
			if current == goal:
				var path := _reconstruct_path(came_from, current)
				var elapsed_ms := float(Time.get_ticks_usec() - t_start) / 1000.0
				return _build_response(true, path, total_expanded, elapsed_ms, "iddfs", "IDDFS path found at depth %d (%d steps)" % [limit, path.size()])
			
			if depth >= limit:
				cutoff = true
				continue
			
			for edge in _get_neighbors(current, grid_size, blocked, allow_diag):
				var neighbor: Vector2i = edge["node"]
				var next_depth: int = depth + 1
				if not visited_depth.has(neighbor) or next_depth < visited_depth[neighbor]:
					visited_depth[neighbor] = next_depth
					came_from[neighbor] = current
					stack.append({"node": neighbor, "depth": next_depth})
		
		# If no cutoff occurred in this iteration, search exhausted entire component
		if not cutoff:
			break
	
	var elapsed_ms := float(Time.get_ticks_usec() - t_start) / 1000.0
	return _build_response(false, [], total_expanded, elapsed_ms, "iddfs", "Goal is unreachable (Explored up to max depth %d)" % max_depth)


# ---------------------------------------------------------------------------
# 6. Bidirectional Search
# ---------------------------------------------------------------------------
static func _search_bidirectional(
	start: Vector2i,
	goal: Vector2i,
	blocked: Dictionary,
	grid_size: Vector2i,
	allow_diag: bool
) -> Dictionary:
	var t_start := Time.get_ticks_usec()
	var q_forward: Array[Vector2i] = [start]
	var q_backward: Array[Vector2i] = [goal]
	var head_f: int = 0
	var head_b: int = 0
	
	var forward_visited: Dictionary = {start: true}
	var backward_visited: Dictionary = {goal: true}
	
	var forward_came_from: Dictionary = {}
	var backward_came_from: Dictionary = {}
	
	var nodes_expanded: int = 0
	var meeting_node: Vector2i = Vector2i(-1, -1)
	var found_meeting: bool = false
	
	while head_f < q_forward.size() and head_b < q_backward.size():
		# Forward step
		var curr_f: Vector2i = q_forward[head_f]
		head_f += 1
		nodes_expanded += 1
		
		if backward_visited.has(curr_f):
			meeting_node = curr_f
			found_meeting = true
			break
		
		for edge in _get_neighbors(curr_f, grid_size, blocked, allow_diag):
			var neighbor: Vector2i = edge["node"]
			if not forward_visited.has(neighbor):
				forward_visited[neighbor] = true
				forward_came_from[neighbor] = curr_f
				q_forward.append(neighbor)
				if backward_visited.has(neighbor):
					meeting_node = neighbor
					found_meeting = true
					break
		
		if found_meeting:
			break
		
		# Backward step
		var curr_b: Vector2i = q_backward[head_b]
		head_b += 1
		nodes_expanded += 1
		
		if forward_visited.has(curr_b):
			meeting_node = curr_b
			found_meeting = true
			break
		
		for edge in _get_neighbors(curr_b, grid_size, blocked, allow_diag):
			var neighbor: Vector2i = edge["node"]
			if not backward_visited.has(neighbor):
				backward_visited[neighbor] = true
				backward_came_from[neighbor] = curr_b
				q_backward.append(neighbor)
				if forward_visited.has(neighbor):
					meeting_node = neighbor
					found_meeting = true
					break
		
		if found_meeting:
			break
	
	var elapsed_ms := float(Time.get_ticks_usec() - t_start) / 1000.0
	if found_meeting:
		var path_start := _reconstruct_path(forward_came_from, meeting_node)
		var path_goal: Array[Vector2i] = []
		var curr := meeting_node
		while backward_came_from.has(curr):
			curr = backward_came_from[curr]
			path_goal.append(curr)
		
		var full_path: Array[Vector2i] = path_start + path_goal
		return _build_response(true, full_path, nodes_expanded, elapsed_ms, "bidirectional", "Bidirectional path found meeting at %s (%d steps)" % [meeting_node, full_path.size()])
	
	return _build_response(false, [], nodes_expanded, elapsed_ms, "bidirectional", "Goal is unreachable (Frontiers did not meet)")


# ---------------------------------------------------------------------------
# 7. Greedy Best-First Search
# ---------------------------------------------------------------------------
static func _search_greedy(
	start: Vector2i,
	goal: Vector2i,
	blocked: Dictionary,
	grid_size: Vector2i,
	allow_diag: bool
) -> Dictionary:
	var t_start := Time.get_ticks_usec()
	var open_heap: Array[Dictionary] = []
	var seq: int = 0
	
	var start_h := _heuristic(start, goal, allow_diag)
	_heap_push(open_heap, {"f": start_h, "h": start_h, "node": start, "seq": seq})
	
	var visited: Dictionary = {start: true}
	var came_from: Dictionary = {}
	var nodes_expanded: int = 0
	
	while open_heap.size() > 0:
		var current_item: Dictionary = _heap_pop(open_heap)
		var current: Vector2i = current_item["node"]
		nodes_expanded += 1
		
		if current == goal:
			var path := _reconstruct_path(came_from, current)
			var elapsed_ms := float(Time.get_ticks_usec() - t_start) / 1000.0
			return _build_response(true, path, nodes_expanded, elapsed_ms, "greedy", "Greedy path found (%d steps) [Suboptimal]" % path.size())
		
		for edge in _get_neighbors(current, grid_size, blocked, allow_diag):
			var neighbor: Vector2i = edge["node"]
			if not visited.has(neighbor):
				visited[neighbor] = true
				came_from[neighbor] = current
				seq += 1
				var h := _heuristic(neighbor, goal, allow_diag)
				_heap_push(open_heap, {"f": h, "h": h, "node": neighbor, "seq": seq})
	
	var elapsed_ms := float(Time.get_ticks_usec() - t_start) / 1000.0
	return _build_response(false, [], nodes_expanded, elapsed_ms, "greedy", "Goal unreachable")


# ---------------------------------------------------------------------------
# Common Graph & Math Helpers
# ---------------------------------------------------------------------------
static func _heuristic(a: Vector2i, b: Vector2i, allow_diagonal: bool) -> float:
	var dx: float = absf(float(a.x - b.x))
	var dy: float = absf(float(a.y - b.y))
	if allow_diagonal:
		# Octile distance
		return (dx + dy) + (1.41421356 - 2.0) * minf(dx, dy)
	else:
		# Manhattan distance
		return dx + dy


static func _get_neighbors(
	current: Vector2i,
	grid_size: Vector2i,
	blocked: Dictionary,
	allow_diagonal: bool
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var cardinal_dirs: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1)
	]
	
	for dir in cardinal_dirs:
		var n: Vector2i = current + dir
		if n.x >= 0 and n.x < grid_size.x and n.y >= 0 and n.y < grid_size.y:
			if not blocked.has(n):
				result.append({"node": n, "cost": 1.0})
	
	if allow_diagonal:
		var diagonal_dirs: Array[Vector2i] = [
			Vector2i(1, 1),
			Vector2i(-1, 1),
			Vector2i(1, -1),
			Vector2i(-1, -1)
		]
		for dir in diagonal_dirs:
			var n: Vector2i = current + dir
			if n.x >= 0 and n.x < grid_size.x and n.y >= 0 and n.y < grid_size.y:
				if not blocked.has(n):
					# Prevent corner cutting through adjacent solid diagonal walls
					var c1 := Vector2i(current.x + dir.x, current.y)
					var c2 := Vector2i(current.x, current.y + dir.y)
					if blocked.has(c1) and blocked.has(c2):
						continue
					result.append({"node": n, "cost": 1.4142})
	
	return result


static func _reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [current]
	while came_from.has(current):
		current = came_from[current]
		path.append(current)
	path.reverse()
	return path


static func _normalize_blocked_cells(blocked_data: Variant) -> Dictionary:
	var dict: Dictionary = {}
	if blocked_data is Dictionary:
		return blocked_data
	elif blocked_data is Array:
		for item in blocked_data:
			if item is Vector2i:
				dict[item] = true
			elif item is Array and item.size() >= 2:
				dict[Vector2i(int(item[0]), int(item[1]))] = true
	return dict


static func _validate_bounds_and_obstacles(
	start: Vector2i,
	goal: Vector2i,
	grid_size: Vector2i,
	blocked: Dictionary
) -> Dictionary:
	if start.x < 0 or start.x >= grid_size.x or start.y < 0 or start.y >= grid_size.y:
		return {"valid": false, "message": "Start position %s is out of bounds (Grid %s)" % [start, grid_size]}
	if goal.x < 0 or goal.x >= grid_size.x or goal.y < 0 or goal.y >= grid_size.y:
		return {"valid": false, "message": "Goal position %s is out of bounds (Grid %s)" % [goal, grid_size]}
	if blocked.has(start):
		return {"valid": false, "message": "Start position %s is blocked by an obstacle" % str(start)}
	if blocked.has(goal):
		return {"valid": false, "message": "Goal position %s is blocked by an obstacle" % str(goal)}
	return {"valid": true, "message": ""}


static func _build_response(
	success: bool,
	path: Array[Vector2i],
	nodes_expanded: int,
	time_ms: float,
	algo_key: String,
	message: String
) -> Dictionary:
	return {
		"success": success,
		"found": success,
		"path": path,
		"length": path.size(),
		"nodes_expanded": nodes_expanded,
		"execution_time_ms": time_ms,
		"algorithm": algo_key,
		"message": message,
		"suitability": get_algorithm_profile(algo_key)
	}


# ---------------------------------------------------------------------------
# Min-Heap Priority Queue (GDScript Implementation)
# ---------------------------------------------------------------------------
static func _heap_push(heap: Array[Dictionary], item: Dictionary) -> void:
	heap.append(item)
	var idx := heap.size() - 1
	while idx > 0:
		var parent := (idx - 1) / 2
		if _item_less_than(heap[idx], heap[parent]):
			var tmp := heap[idx]
			heap[idx] = heap[parent]
			heap[parent] = tmp
			idx = parent
		else:
			break


static func _heap_pop(heap: Array[Dictionary]) -> Dictionary:
	var top: Dictionary = heap[0]
	var last: Dictionary = heap.pop_back()
	if heap.size() > 0:
		heap[0] = last
		var idx := 0
		var size := heap.size()
		while true:
			var left := idx * 2 + 1
			var right := idx * 2 + 2
			var smallest := idx
			if left < size and _item_less_than(heap[left], heap[smallest]):
				smallest = left
			if right < size and _item_less_than(heap[right], heap[smallest]):
				smallest = right
			if smallest != idx:
				var tmp := heap[idx]
				heap[idx] = heap[smallest]
				heap[smallest] = tmp
				idx = smallest
			else:
				break
	return top


static func _item_less_than(a: Dictionary, b: Dictionary) -> bool:
	if is_equal_approx(a["f"], b["f"]):
		if a.has("h") and b.has("h") and not is_equal_approx(a["h"], b["h"]):
			return a["h"] < b["h"]
		return a.get("seq", 0) < b.get("seq", 0)
	return a["f"] < b["f"]
