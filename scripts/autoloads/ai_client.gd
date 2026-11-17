extends Node
## HTTP client for the Python AI backend (autoload "AIClient").
## Sends JSON requests asynchronously, times out after 2 s, and reports
## {"success": false} when the backend is offline so the game keeps running.

signal backend_availability_changed(is_available: bool)
signal response_received(endpoint: String, success: bool, data: Dictionary)

@export var base_url: String = "http://127.0.0.1:8000"
@export var timeout_seconds: float = 2.0
@export var auto_check_on_ready: bool = true
@export var auto_start_backend: bool = true

var is_backend_available: bool = false
var _spawned_backend_pid: int = 0
var _has_attempted_autostart: bool = false


func _ready() -> void:
	if auto_check_on_ready:
		check_health()


func _exit_tree() -> void:
	if _spawned_backend_pid > 0:
		OS.kill(_spawned_backend_pid)
		_spawned_backend_pid = 0


# ---------------------------------------------------------------------------
# Backend Process Lifecycle
# ---------------------------------------------------------------------------
func try_start_backend() -> bool:
	if is_backend_available or _spawned_backend_pid > 0:
		return true

	var project_path := ProjectSettings.globalize_path("res://")
	var venv_python := project_path.path_join("ai_backend/.venv/Scripts/python.exe")
	var python_bin := ""

	if FileAccess.file_exists(venv_python):
		python_bin = venv_python
	else:
		python_bin = "python"

	var args := PackedStringArray([
		"-m", "uvicorn", "ai_backend.main:app",
		"--host", "127.0.0.1",
		"--port", "8000"
	])

	var pid := OS.create_process(python_bin, args, false)
	if pid > 0:
		_spawned_backend_pid = pid
		print("[AIClient] Successfully spawned Python AI Backend process (PID: %d)" % pid)
		return true
	else:
		print("[AIClient] Unable to spawn Python AI Backend process.")
		return false


# ---------------------------------------------------------------------------
# High-Level API Methods
# ---------------------------------------------------------------------------
func check_health(callback: Callable = Callable()) -> void:
	send_request("/health", HTTPClient.METHOD_GET, {}, func(res: Dictionary) -> void:
		var available := bool(res.get("success", false))
		if available != is_backend_available:
			is_backend_available = available
			backend_availability_changed.emit(is_backend_available)
		
		# If offline and autostart enabled, attempt background spawn once
		if not available and auto_start_backend and not _has_attempted_autostart:
			_has_attempted_autostart = true
			if try_start_backend():
				var tree := get_tree()
				if tree:
					var timer := tree.create_timer(1.8)
					timer.timeout.connect(func():
						check_health(callback)
					)
					return

		if callback.is_valid():
			callback.call(res)
	)


## Path finding on the server (BFS, DFS, DLS, IDDFS, Bidirectional, Greedy, A*).
## grid = rows of 0 (walkable) / 1 (wall). Uses a short timeout: if the server is
## too slow the caller falls back to the local A*.
func request_path(algorithm: String, grid: Array, start: Vector2i, goal: Vector2i, timeout: float, callback: Callable = Callable()) -> void:
	var body := {"algorithm": algorithm, "grid": grid, "start": [start.x, start.y], "goal": [goal.x, goal.y]}
	send_request("/pathfinding/find", HTTPClient.METHOD_POST, body, callback, timeout)


## Minimax / MCTS picks a combat action. state = my_hp, enemy_hp, distance, energies, cooldowns.
func request_decision(state: Dictionary, algorithm: String, callback: Callable = Callable()) -> void:
	send_request("/api/ai/decision", HTTPClient.METHOD_POST, {"state": state, "algorithm": algorithm, "depth": 3, "simulations": 200}, callback)


## Fuzzy logic: player health (percent) + distance (pixels) -> boss aggression.
func request_fuzzy(player_health: float, distance: float, callback: Callable = Callable()) -> void:
	send_request("/api/ai/fuzzy", HTTPClient.METHOD_POST, {"player_health": player_health, "distance": distance}, callback)


## CSP: place pickups. body = candidates, walls, enemy, items.
func request_pickups(body: Dictionary, callback: Callable = Callable()) -> void:
	send_request("/api/ai/csp", HTTPClient.METHOD_POST, body, callback)


## Forward chaining over the IF-THEN rules, e.g. facts = {"boss_hp": 0, "player_hp": 40, "planet": 2}.
func request_rules(facts: Dictionary, callback: Callable = Callable()) -> void:
	send_request("/api/ai/rules", HTTPClient.METHOD_POST, {"facts": facts}, callback)


# ---------------------------------------------------------------------------
# Core Asynchronous HTTP Request Pipeline
# ---------------------------------------------------------------------------
func send_request(endpoint: String, method: int = HTTPClient.METHOD_GET, json_data: Dictionary = {}, callback: Callable = Callable(), timeout: float = -1.0) -> void:
	if timeout <= 0.0:
		timeout = timeout_seconds
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
	http.timeout = timeout
	add_child(http)
	
	var url := base_url + endpoint
	var headers := PackedStringArray(["Content-Type: application/json"])
	var body_str := JSON.stringify(json_data) if method != HTTPClient.METHOD_GET and not json_data.is_empty() else ""
	
	http.set_meta("_is_done", false)
	http.request_completed.connect(_on_http_request_completed.bind(http, endpoint, callback))
	
	# Explicit timeout timer safeguard to avoid hanging on OS socket SYN timeouts
	if timeout > 0.0:
		var watchdog := Timer.new()
		watchdog.name = "TimeoutWatchdog"
		watchdog.one_shot = true
		watchdog.wait_time = timeout
		watchdog.ignore_time_scale = true      # real seconds, even when the game runs at 3x
		http.add_child(watchdog)
		watchdog.timeout.connect(_on_watchdog_timeout.bind(http, endpoint, callback))
		watchdog.start()
	
	var err := http.request(url, headers, method, body_str)
	if err != OK:
		http.set_meta("_is_done", true)
		_cleanup_http(http)
		var fail_res := {
			"success": false,
			"error": "Failed to dispatch HTTP request (Error code: %d)" % err,
			"response_code": 0,
			"data": {}
		}
		_notify_result(endpoint, fail_res, callback)


func _on_http_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest, endpoint: String, callback: Callable) -> void:
	if not is_instance_valid(http) or http.get_meta("_is_done", false):
		return
	http.set_meta("_is_done", true)
	_on_request_finished(http, endpoint, result, response_code, body, callback)


func _on_watchdog_timeout(http: HTTPRequest, endpoint: String, callback: Callable) -> void:
	if not is_instance_valid(http) or http.get_meta("_is_done", false):
		return
	http.set_meta("_is_done", true)
	http.cancel_request()
	_on_request_finished(http, endpoint, HTTPRequest.RESULT_TIMEOUT, 0, PackedByteArray(), callback)


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
		if http.has_node("TimeoutWatchdog"):
			var watchdog = http.get_node("TimeoutWatchdog")
			if is_instance_valid(watchdog) and watchdog is Timer:
				watchdog.stop()
		if http.is_inside_tree():
			http.get_parent().remove_child(http)
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
