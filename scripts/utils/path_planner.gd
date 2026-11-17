extends RefCounted
## Gets a path for ONE agent without ever freezing the game.
##
##  1. request() sends the grid, start and goal to the Python server (async).
##  2. While waiting, the agent keeps following its LAST path.
##  3. When the answer arrives, the new path replaces the old one.
##  4. If the server does not answer within SERVER_TIMEOUT (or is offline),
##     the local A* in modular_pathfinder.gd is used instead.

const Pathfinder = preload("res://scripts/utils/modular_pathfinder.gd")
const SERVER_TIMEOUT := 0.4        # seconds

var algorithm := "astar"           # which server algorithm to ask for
var path: Array = []               # current path (Array of Vector2i tiles)
var found := false
var nodes := 0                     # nodes expanded by the last search
var time_ms := 0.0                 # time of the last search
var used := "astar"                # algorithm that produced the current path
var source := "-"                  # "server" or "local"
var busy := false                  # a request is on its way

# Totals for averages (AI vs AI result panel).
var searches := 0
var total_nodes := 0
var total_time_ms := 0.0


func _init(p_algorithm: String = "astar") -> void:
	algorithm = p_algorithm


## Ask for a new path. Does nothing if the previous request has not come back yet.
## `on_done` is called (with no arguments) when the new path is stored.
func request(grid, start: Vector2i, goal: Vector2i, on_done: Callable = Callable()) -> void:
	if busy:
		return
	busy = true
	AIClient.request_path(algorithm, grid.rows, start, goal, SERVER_TIMEOUT, _on_answer.bind(grid, start, goal, on_done))


func _on_answer(response: Dictionary, grid, start: Vector2i, goal: Vector2i, on_done: Callable) -> void:
	busy = false
	if response.get("success", false):
		# Server answer: convert [[x, y], ...] into Vector2i tiles.
		var data: Dictionary = response["data"]
		var tiles: Array = []
		for pair in data.get("path", []):
			tiles.append(Vector2i(int(pair[0]), int(pair[1])))
		_store(tiles, bool(data.get("found", false)), int(data.get("nodes_expanded", 0)), float(data.get("time_ms", 0.0)), algorithm, "server")
	else:
		# No answer in time: local A* backup.
		var local: Dictionary = Pathfinder.astar(start, goal, grid.blocked, grid.size)
		_store(local["path"], local["found"], local["nodes_expanded"], local["time_ms"], "astar", "local")
	if on_done.is_valid():
		on_done.call()


func _store(p_path: Array, p_found: bool, p_nodes: int, p_time_ms: float, p_used: String, p_source: String) -> void:
	path = p_path
	found = p_found
	nodes = p_nodes
	time_ms = p_time_ms
	used = p_used
	source = p_source
	searches += 1
	total_nodes += nodes
	total_time_ms += time_ms


## HUD text, e.g. "Search: A* | Nodes: 34 | 0.4 ms".
func hud_text() -> String:
	var shown: String = Pathfinder.NAMES.get(used, used)
	if source == "local":
		shown += " (local)"
	return "Search: %s | Nodes: %d | %.1f ms" % [shown, nodes, time_ms]


## Moves `fighter` one step along the path: walk toward the next tile and
## jump if that tile is higher. Returns false if there is no usable path.
static func follow(fighter, tiles: Array, grid) -> bool:
	if tiles.size() < 2:
		return false
	var here: Vector2i = grid.to_cell(fighter.position)
	var index := tiles.find(here)
	var next: Vector2i = tiles[mini(index + 1, tiles.size() - 1)] if index >= 0 else tiles[1]
	var dx: float = grid.to_world(next).x - fighter.position.x
	fighter.desired_direction = signf(dx) if absf(dx) > 10.0 else 0.0
	if next.y < here.y and (fighter.is_on_floor() or fighter.velocity.y > 0.0):
		fighter.jump()                     # next tile is higher: jump (or double jump)
	return true
