extends Node
## BioSphere-X Python AI Backend HTTP Client.
## Handles asynchronous HTTP communication, health checks, error handling,
## timeouts, and offline-backend graceful degradation.

signal backend_availability_changed(is_available: bool)
signal response_received(endpoint: String, success: bool, data: Dictionary)

@export var base_url: String = "http://127.0.0.1:8000"
@export var timeout_seconds: float = 2.0
@export var auto_check_on_ready: bool = false

var is_backend_available: bool = false


func _ready() -> void:
	if auto_check_on_ready:
		check_health()


# ---------------------------------------------------------------------------
# High-Level API Methods
# ---------------------------------------------------------------------------
func check_health(callback: Callable = Callable()) -> void:
	send_request("/health", HTTPClient.METHOD_GET, {}, func(res: Dictionary) -> void:
		var available := bool(res.get("success", false))
		if available != is_backend_available:
			is_backend_available = available
			backend_availability_changed.emit(is_backend_available)
		if callback.is_valid():
			callback.call(res)
	)


func send_test(callback: Callable = Callable()) -> void:
	send_request("/api/test", HTTPClient.METHOD_GET, {}, callback)


func send_test_echo(message: String, payload: Dictionary = {}, callback: Callable = Callable()) -> void:
	var body := {
		"message": message,
		"payload": payload
	}
	send_request("/api/test-echo", HTTPClient.METHOD_POST, body, callback)


func request_path(start_grid: Vector2i, goal_grid: Vector2i, blocked: Array[Vector2i] = [], callback: Callable = Callable()) -> void:
	request_pathfinding(start_grid, goal_grid, "astar", blocked, 80, 80, true, 100, callback)


func request_pathfinding(
	start_grid: Vector2i,
	goal_grid: Vector2i,
	algorithm: String = "astar",
	blocked: Array[Vector2i] = [],
	grid_width: int = 80,
	grid_height: int = 80,
	allow_diagonal: bool = true,
	depth_limit: int = 100,
	callback: Callable = Callable()
) -> void:
	var blocked_list: Array = []
	for b in blocked:
		blocked_list.append([b.x, b.y])
	
	var body := {
		"start": [start_grid.x, start_grid.y],
		"goal": [goal_grid.x, goal_grid.y],
		"algorithm": algorithm,
		"grid_width": grid_width,
		"grid_height": grid_height,
		"blocked_cells": blocked_list,
		"allow_diagonal": allow_diagonal,
		"depth_limit": depth_limit
	}
	send_request("/api/ai/pathfinding/find-path", HTTPClient.METHOD_POST, body, callback)


func request_boss_decision(
	state_data: Dictionary,
	algorithm: String = "alpha_beta",
	options: Dictionary = {},
	callback: Callable = Callable()
) -> void:
	var body := {
		"state": state_data,
		"algorithm": algorithm,
		"max_depth": options.get("max_depth", 4),
		"simulations": options.get("simulations", 150),
		"exploration_c": options.get("exploration_c", 1.414)
	}
	send_request("/api/ai/boss/decision", HTTPClient.METHOD_POST, body, callback)


func request_boss_algorithms(callback: Callable = Callable()) -> void:
	send_request("/api/ai/boss/algorithms", HTTPClient.METHOD_GET, {}, callback)


func request_adaptive_difficulty(inputs: Dictionary, fixed_mode: String = "", callback: Callable = Callable()) -> void:
	var body := {
		"player_health": float(inputs.get("player_health", 100.0)),
		"recent_damage": float(inputs.get("recent_damage", 0.0)),
		"enemy_distance": float(inputs.get("enemy_distance", 200.0)),
		"fixed_mode": (fixed_mode if not fixed_mode.is_empty() and fixed_mode != "adaptive" else null)
	}
	send_request("/api/ai/fuzzy/difficulty", HTTPClient.METHOD_POST, body, callback)


func request_fuzzy_profiles(callback: Callable = Callable()) -> void:
	send_request("/api/ai/fuzzy/profiles", HTTPClient.METHOD_GET, {}, callback)


# ---------------------------------------------------------------------------
# Core Asynchronous HTTP Request Pipeline
# ---------------------------------------------------------------------------
func send_request(endpoint: String, method: int = HTTPClient.METHOD_GET, json_data: Dictionary = {}, callback: Callable = Callable()) -> void:
	if not is_inside_tree():
		var not_in_tree_res := {
			"success": false,
			"error": "AIClient is not inside SceneTree",
			"response_code": 0,
			"data": {}
		}
		_notify_result(endpoint, not_in_tree_res, callback)
		return
	
	var http := HTTPRequest.new()
	http.timeout = timeout_seconds
	add_child(http)
	
	var url := base_url + endpoint
	var headers := PackedStringArray(["Content-Type: application/json"])
	var body_str := JSON.stringify(json_data) if method != HTTPClient.METHOD_GET and not json_data.is_empty() else ""
	
	var is_done := false
	
	http.request_completed.connect(func(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		if not is_done:
			is_done = true
			_on_request_finished(http, endpoint, result, response_code, body, callback)
	)
	
	# Explicit timeout timer safeguard to avoid hanging on OS socket SYN timeouts
	if timeout_seconds > 0.0:
		var tree := get_tree()
		if tree:
			var watchdog := tree.create_timer(timeout_seconds)
			watchdog.timeout.connect(func() -> void:
				if not is_done and is_instance_valid(http):
					is_done = true
					http.cancel_request()
					_on_request_finished(http, endpoint, HTTPRequest.RESULT_TIMEOUT, 0, PackedByteArray(), callback)
			)
	
	var err := http.request(url, headers, method, body_str)
	if err != OK:
		is_done = true
		_cleanup_http(http)
		var fail_res := {
			"success": false,
			"error": "Failed to dispatch HTTP request (Error code: %d)" % err,
			"response_code": 0,
			"data": {}
		}
		_notify_result(endpoint, fail_res, callback)


func _on_request_finished(http: HTTPRequest, endpoint: String, result: int, response_code: int, body: PackedByteArray, callback: Callable) -> void:
	_cleanup_http(http)
	
	var res := {
		"success": false,
		"response_code": response_code,
		"error": "",
		"data": {}
	}
	
	if result != HTTPRequest.RESULT_SUCCESS:
		res["error"] = _get_result_error_message(result)
		_notify_result(endpoint, res, callback)
		return
	
	if response_code < 200 or response_code >= 300:
		res["error"] = "HTTP Server returned status %d" % response_code
		_notify_result(endpoint, res, callback)
		return
	
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if parsed == null:
		res["error"] = "Failed to parse JSON response from backend"
		_notify_result(endpoint, res, callback)
		return
	
	res["success"] = true
	res["data"] = parsed if parsed is Dictionary else {"result": parsed}
	_notify_result(endpoint, res, callback)


func _notify_result(endpoint: String, res: Dictionary, callback: Callable) -> void:
	response_received.emit(endpoint, res["success"], res)
	if callback.is_valid():
		callback.call(res)


func _cleanup_http(http: HTTPRequest) -> void:
	if is_instance_valid(http):
		http.queue_free()


func _get_result_error_message(res_code: int) -> String:
	match res_code:
		HTTPRequest.RESULT_CANT_CONNECT:
			return "Cannot connect to Python AI backend (Backend server offline)"
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "Cannot resolve AI backend host address"
		HTTPRequest.RESULT_CONNECTION_ERROR:
			return "Connection error while reaching AI backend"
		HTTPRequest.RESULT_TIMEOUT:
			return "AI backend request timed out"
		_:
			return "HTTPRequest error code: %d" % res_code
