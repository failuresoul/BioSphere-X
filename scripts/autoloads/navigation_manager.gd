extends Node
## BioSphere-X Navigation Manager.
## Bridges Godot path requests with the Python AI Backend pathfinding API
## (BFS, DFS, DLS, IDDFS, Bidirectional, Greedy, A*).
## Provides automatic failover to native AStarGrid2D if backend is offline.

signal algorithm_changed(new_algorithm: String)
signal metrics_updated(metrics: Dictionary)
signal backend_status_changed(is_online: bool, message: String)
signal fallback_triggered(reason: String)
signal debug_display_changed(enabled: bool)
signal active_paths_changed()

const ALGORITHMS: Array[String] = [
	"astar",
	"bfs",
	"dfs",
	"dls",
	"iddfs",
	"bidirectional",
	"greedy"
]

@export var current_algorithm: String = "astar"
@export var dls_depth_limit: int = 100
@export var allow_diagonal: bool = true
@export var force_fallback: bool = false
@export var debug_display_enabled: bool = false

var is_backend_online: bool = false
var last_metrics: Dictionary = {}
var last_error_message: String = ""
var active_paths: Dictionary = {}

# Keep reference to active world MapData
var _map_data_ref: RefCounted = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_init_client_listeners()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F2:
			toggle_debug_display()
			get_viewport().set_input_as_handled()


func _init_client_listeners() -> void:
	var client = get_node_or_null("/root/AIClient")
	if client:
		client.backend_availability_changed.connect(func(online: bool):
			is_backend_online = online
			backend_status_changed.emit(online, "Backend online" if online else "Backend offline")
		)


func set_debug_display(enabled: bool) -> void:
	debug_display_enabled = enabled
	debug_display_changed.emit(debug_display_enabled)


func toggle_debug_display() -> bool:
	debug_display_enabled = not debug_display_enabled
	debug_display_changed.emit(debug_display_enabled)
	return debug_display_enabled


func register_active_path(source_id: int, path: PackedVector2Array, color: Color = Color(0, 0.95, 1, 0.85)) -> void:
	active_paths[source_id] = {
		"path": path,
		"color": color
	}
	active_paths_changed.emit()


func unregister_active_path(source_id: int) -> void:
	if active_paths.has(source_id):
		active_paths.erase(source_id)
		active_paths_changed.emit()


func set_algorithm(algo_name: String) -> void:
	var lower = algo_name.strip_edges().to_lower()
	if lower in ALGORITHMS:
		current_algorithm = lower
		algorithm_changed.emit(current_algorithm)


func set_map_data(map_data: RefCounted) -> void:
	_map_data_ref = map_data


func get_map_data() -> RefCounted:
	return _map_data_ref


# ---------------------------------------------------------------------------
# Asynchronous Path Request Pipeline
# ---------------------------------------------------------------------------
func request_path(
	from_world: Vector2,
	to_world: Vector2,
	map_data: RefCounted = null,
	callback: Callable = Callable(),
	override_algorithm: String = ""
) -> void:
	var m_data = map_data if map_data != null else _map_data_ref
	if m_data == null:
		var direct_path := PackedVector2Array([from_world, to_world])
		var direct_metrics := {
			"success": true,
			"algorithm": "DirectLine",
			"source": "[DIRECT_FALLBACK]",
			"nodes_expanded": 2,
			"execution_time_ms": 0.0,
			"path_length": 2,
			"is_fallback": true,
			"message": "Direct line navigation fallback (No MapData mounted)"
		}
		_finish_path_request(direct_path, direct_metrics, callback)
		return

	var start_grid: Vector2i = m_data.call("world_to_grid", from_world)
	var goal_grid: Vector2i = m_data.call("world_to_grid", to_world)
	
	# If goal or start is on a blocked obstacle edge, snap to nearest walkable cell
	if m_data.has_method("get_nearest_walkable_grid_pos"):
		if m_data.call("is_cell_blocked", goal_grid):
			goal_grid = m_data.call("get_nearest_walkable_grid_pos", goal_grid, 4)
		if m_data.call("is_cell_blocked", start_grid):
			start_grid = m_data.call("get_nearest_walkable_grid_pos", start_grid, 4)
	
	var algo: String = override_algorithm if override_algorithm != "" else current_algorithm

	# If forced fallback is enabled, immediately route to Godot native fallback
	if force_fallback:
		_execute_fallback(from_world, to_world, m_data, "Forced fallback enabled in settings", callback, algo)
		return

	var client = get_node_or_null("/root/AIClient")
	if client == null:
		_execute_fallback(from_world, to_world, m_data, "AIClient autoload not found", callback, algo)
		return

	# Gather blocked cells
	var blocked_cells: Array[Vector2i] = []
	if m_data.has_method("get_blocked_cells"):
		blocked_cells = m_data.call("get_blocked_cells")

	var grid_size: Vector2i = m_data.get("grid_size") if "grid_size" in m_data else Vector2i(80, 80)

	# Dispatch asynchronous HTTP request to Python AI backend
	client.call(
		"request_pathfinding",
		start_grid,
		goal_grid,
		algo,
		blocked_cells,
		grid_size.x,
		grid_size.y,
		allow_diagonal,
		dls_depth_limit,
		func(res: Dictionary) -> void:
			if res.get("success", false) and res.has("data"):
				var data: Dictionary = res.get("data", {})
				var raw_path: Array = data.get("path", [])
				var world_path := PackedVector2Array()
				if m_data.has_method("grid_to_world_path"):
					world_path = m_data.call("grid_to_world_path", raw_path)

				is_backend_online = true
				last_error_message = ""
				var metrics := {
					"success": bool(data.get("success", true)),
					"algorithm": str(data.get("algorithm", algo)),
					"nodes_expanded": int(data.get("nodes_expanded", 0)),
					"execution_time_ms": float(data.get("execution_time_ms", 0.0)),
					"path_length": world_path.size(),
					"source": "PYTHON_AI_BACKEND",
					"is_fallback": false,
					"message": str(data.get("message", "OK")),
					"suitability": ModularPathfinder.get_algorithm_profile(algo)
				}
				_finish_path_request(world_path, metrics, callback)
			else:
				var err: String = str(res.get("error", "Failed to communicate with AI Backend"))
				_execute_fallback(from_world, to_world, m_data, err, callback, algo)
	)


func _execute_fallback(
	from_world: Vector2,
	to_world: Vector2,
	m_data: RefCounted,
	reason: String,
	callback: Callable,
	intended_algo: String
) -> void:
	is_backend_online = false
	last_error_message = reason
	fallback_triggered.emit(reason)
	backend_status_changed.emit(false, reason)

	var t_start := Time.get_ticks_usec()
	var fallback_path := PackedVector2Array()
	var nodes_expanded: int = 0
	var source_tag: String = "[FALLBACK_ASTAR2D]"
	var algo_display_name: String = "AStarGrid2D (Fallback)"

	var start_grid: Vector2i = m_data.call("world_to_grid", from_world) if m_data.has_method("world_to_grid") else Vector2i.ZERO
	var goal_grid: Vector2i = m_data.call("world_to_grid", to_world) if m_data.has_method("world_to_grid") else Vector2i.ZERO
	var grid_size: Vector2i = m_data.get("grid_size") if "grid_size" in m_data else Vector2i(80, 80)
	var blocked_cells: Array[Vector2i] = m_data.call("get_blocked_cells") if m_data.has_method("get_blocked_cells") else []

	if intended_algo != "astar":
		# Execute selected algorithm locally via ModularPathfinder
		var local_res := ModularPathfinder.search(
			intended_algo,
			start_grid,
			goal_grid,
			blocked_cells,
			grid_size,
			{
				"allow_diagonal": allow_diagonal,
				"depth_limit": dls_depth_limit,
				"max_depth": grid_size.x * grid_size.y
			}
		)
		var raw_path: Array = local_res.get("path", [])
		if m_data.has_method("grid_to_world_path"):
			fallback_path = m_data.call("grid_to_world_path", raw_path)
		nodes_expanded = int(local_res.get("nodes_expanded", 0))
		source_tag = "[LOCAL_MODULAR_ENGINE]"
		algo_display_name = "%s (Local Modular)" % intended_algo.to_upper()
	else:
		if m_data.has_method("get_fallback_path_points"):
			fallback_path = m_data.call("get_fallback_path_points", from_world, to_world)
		elif m_data.has_method("get_path_points"):
			fallback_path = m_data.call("get_path_points", from_world, to_world)
		nodes_expanded = fallback_path.size()
		source_tag = "[FALLBACK_ASTAR2D]"
		algo_display_name = "AStarGrid2D (Fallback)"

	var t_elapsed_ms := float(Time.get_ticks_usec() - t_start) / 1000.0

	var metrics := {
		"success": fallback_path.size() > 0,
		"algorithm": algo_display_name,
		"requested_algorithm": intended_algo,
		"nodes_expanded": nodes_expanded,
		"execution_time_ms": t_elapsed_ms,
		"path_length": fallback_path.size(),
		"source": source_tag,
		"is_fallback": true,
		"fallback_reason": reason,
		"message": "Used %s (%s)" % [algo_display_name, reason],
		"suitability": ModularPathfinder.get_algorithm_profile(intended_algo)
	}
	_finish_path_request(fallback_path, metrics, callback)


func _finish_path_request(path: PackedVector2Array, metrics: Dictionary, callback: Callable) -> void:
	last_metrics = metrics
	metrics_updated.emit(metrics)
	if callback.is_valid():
		callback.call(path, metrics)


# Synchronous fallback convenience method for tests or immediate rendering
func get_synchronous_path(from_world: Vector2, to_world: Vector2, m_data: RefCounted = null) -> PackedVector2Array:
	var md = m_data if m_data != null else _map_data_ref
	if md and md.has_method("get_fallback_path_points"):
		return md.call("get_fallback_path_points", from_world, to_world)
	return PackedVector2Array()
