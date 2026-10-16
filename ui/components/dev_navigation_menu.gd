extends PanelContainer
## Developer Menu & Configuration Panel for BioSphere-X Pathfinding.
## Allows selecting the active AI algorithm (BFS, DFS, DLS, IDDFS, Bidirectional, Greedy, A*),
## monitoring backend health, viewing nodes expanded, execution time, and testing fallback failover.

signal algorithm_selected(algorithm: String)
signal fallback_toggled(force_fallback: bool)

const ModularPathfinderScript := preload("res://scripts/utils/modular_pathfinder.gd")

@onready var algo_dropdown: OptionButton = %AlgoDropdown
@onready var depth_spin: SpinBox = %DepthSpin
@onready var diagonal_check: CheckBox = %DiagonalCheck
@onready var force_fallback_check: CheckBox = %ForceFallbackCheck
@onready var debug_display_check: CheckBox = %DebugDisplayCheck
@onready var ping_button: Button = %PingButton
@onready var test_query_button: Button = %TestQueryButton
@onready var close_button: Button = %CloseButton
@onready var launch_ai_arena_button: Button = %LaunchAIArenaButton
@onready var difficulty_dropdown: OptionButton = %DifficultyDropdown
@onready var difficulty_telemetry: Label = %DifficultyTelemetry

@onready var status_badge: Label = %StatusBadge
@onready var error_banner: Label = %ErrorBanner
@onready var metrics_algo_label: Label = %MetricsAlgo
@onready var metrics_source_label: Label = %MetricsSource
@onready var metrics_nodes_label: Label = %MetricsNodes
@onready var metrics_time_label: Label = %MetricsTime
@onready var metrics_length_label: Label = %MetricsLength

const ALGO_KEYS: Array[String] = [
	"astar",
	"bfs",
	"dfs",
	"dls",
	"iddfs",
	"bidirectional",
	"greedy"
]

const ALGO_LABELS: Array[String] = [
	"A* Search (Optimal)",
	"Breadth-First Search (BFS)",
	"Depth-First Search (DFS)",
	"Depth-Limited Search (DLS)",
	"Iterative Deepening DFS (IDDFS)",
	"Bidirectional Search",
	"Greedy Best-First Search"
]

const DIFF_KEYS: Array[String] = [
	"adaptive_fuzzy",
	"adaptive_simple",
	"easy",
	"normal",
	"hard",
	"nightmare"
]

const DIFF_LABELS: Array[String] = [
	"Adaptive: Fuzzy Inference System (Mamdani)",
	"Adaptive: Simple Step Rules",
	"Fixed: Easy (0.35 Aggression)",
	"Fixed: Normal (0.60 Aggression)",
	"Fixed: Hard (0.85 Aggression)",
	"Fixed: Nightmare (1.00 Aggression)"
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_populate_dropdown()
	_connect_signals()
	_refresh_display()
	
	# Start hidden by default; toggled via F1 or HUD button
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			toggle_visibility()
			get_viewport().set_input_as_handled()


func toggle_visibility() -> void:
	visible = not visible
	if visible:
		_refresh_display()


func _populate_dropdown() -> void:
	if algo_dropdown:
		algo_dropdown.clear()
		for i in range(ALGO_LABELS.size()):
			algo_dropdown.add_item(ALGO_LABELS[i], i)
	
	if difficulty_dropdown:
		difficulty_dropdown.clear()
		for i in range(DIFF_LABELS.size()):
			difficulty_dropdown.add_item(DIFF_LABELS[i], i)
		var dc = get_node_or_null("/root/DifficultyController")
		if dc:
			var cur_mode: String = dc.get("difficulty_mode")
			var idx = DIFF_KEYS.find(cur_mode)
			if idx >= 0:
				difficulty_dropdown.selected = idx
			var params: Dictionary = dc.call("get_current_multipliers")
			var agg: float = float(dc.get("current_aggression"))
			var intensity: float = float(dc.get("current_encounter_intensity"))
			_on_difficulty_updated(agg, intensity, params)


func _connect_signals() -> void:
	if algo_dropdown:
		algo_dropdown.item_selected.connect(_on_algo_selected)
	if depth_spin:
		depth_spin.value_changed.connect(_on_depth_changed)
	if diagonal_check:
		diagonal_check.toggled.connect(_on_diagonal_toggled)
	if force_fallback_check:
		force_fallback_check.toggled.connect(_on_force_fallback_toggled)
	if debug_display_check:
		debug_display_check.toggled.connect(_on_debug_display_toggled)
	if ping_button:
		ping_button.pressed.connect(_on_ping_pressed)
	if test_query_button:
		test_query_button.pressed.connect(_on_test_query_pressed)
	if close_button:
		close_button.pressed.connect(func(): visible = false)
	if launch_ai_arena_button:
		launch_ai_arena_button.pressed.connect(func():
			Engine.time_scale = 1.0
			get_tree().change_scene_to_file("res://scenes/ai_vs_ai/ai_arena.tscn")
		)
	if difficulty_dropdown:
		difficulty_dropdown.item_selected.connect(_on_difficulty_selected)
		
	var dc = get_node_or_null("/root/DifficultyController")
	if dc and dc.has_signal("difficulty_updated"):
		dc.connect("difficulty_updated", _on_difficulty_updated)
		
	var nav_mgr = get_node_or_null("/root/NavigationManager")
	if nav_mgr:
		if nav_mgr.has_signal("metrics_updated"):
			nav_mgr.connect("metrics_updated", _on_metrics_updated)
		if nav_mgr.has_signal("backend_status_changed"):
			nav_mgr.connect("backend_status_changed", _on_backend_status_changed)
		if nav_mgr.has_signal("fallback_triggered"):
			nav_mgr.connect("fallback_triggered", _on_fallback_triggered)
		if nav_mgr.has_signal("debug_display_changed"):
			nav_mgr.connect("debug_display_changed", func(enabled):
				if debug_display_check:
					debug_display_check.button_pressed = enabled
			)


func _refresh_display() -> void:
	var nav_mgr = get_node_or_null("/root/NavigationManager")
	if not nav_mgr:
		return
		
	var current_algo: String = nav_mgr.get("current_algorithm") if "current_algorithm" in nav_mgr else "astar"
	var idx = ALGO_KEYS.find(current_algo)
	if idx >= 0 and algo_dropdown:
		algo_dropdown.select(idx)
		
	if depth_spin and "dls_depth_limit" in nav_mgr:
		depth_spin.value = nav_mgr.get("dls_depth_limit")
		
	if diagonal_check and "allow_diagonal" in nav_mgr:
		diagonal_check.button_pressed = nav_mgr.get("allow_diagonal")
		
	if force_fallback_check and "force_fallback" in nav_mgr:
		force_fallback_check.button_pressed = nav_mgr.get("force_fallback")
		
	if debug_display_check and "debug_display_enabled" in nav_mgr:
		debug_display_check.button_pressed = nav_mgr.get("debug_display_enabled")
		
	var is_online: bool = nav_mgr.get("is_backend_online") if "is_backend_online" in nav_mgr else false
	var last_err: String = nav_mgr.get("last_error_message") if "last_error_message" in nav_mgr else ""
	_update_backend_ui(is_online, last_err)
	
	if "last_metrics" in nav_mgr and not nav_mgr.last_metrics.is_empty():
		_on_metrics_updated(nav_mgr.last_metrics)


func _on_algo_selected(index: int) -> void:
	if index >= 0 and index < ALGO_KEYS.size():
		var chosen_key = ALGO_KEYS[index]
		var nav_mgr = get_node_or_null("/root/NavigationManager")
		if nav_mgr and nav_mgr.has_method("set_algorithm"):
			nav_mgr.call("set_algorithm", chosen_key)
		algorithm_selected.emit(chosen_key)
		
		# Update suitability profile notice
		var profile: Dictionary = ModularPathfinderScript.get_algorithm_profile(chosen_key)
		if error_banner:
			if not profile.get("gameplay_suitable", true):
				error_banner.visible = true
				error_banner.text = "⚠️ %s CAVEAT: %s" % [profile.get("name", chosen_key), profile.get("caveats", "")]
			else:
				var is_online: bool = nav_mgr.get("is_backend_online") if nav_mgr and "is_backend_online" in nav_mgr else false
				var last_err: String = nav_mgr.get("last_error_message") if nav_mgr and "last_error_message" in nav_mgr else ""
				_update_backend_ui(is_online, last_err)


func _on_depth_changed(val: float) -> void:
	var nav_mgr = get_node_or_null("/root/NavigationManager")
	if nav_mgr:
		nav_mgr.set("dls_depth_limit", int(val))


func _on_diagonal_toggled(toggled: bool) -> void:
	var nav_mgr = get_node_or_null("/root/NavigationManager")
	if nav_mgr:
		nav_mgr.set("allow_diagonal", toggled)


func _on_debug_display_toggled(toggled: bool) -> void:
	var nav_mgr = get_node_or_null("/root/NavigationManager")
	if nav_mgr and nav_mgr.has_method("set_debug_display"):
		nav_mgr.call("set_debug_display", toggled)


func _on_force_fallback_toggled(toggled: bool) -> void:
	var nav_mgr = get_node_or_null("/root/NavigationManager")
	if nav_mgr:
		nav_mgr.set("force_fallback", toggled)
	fallback_toggled.emit(toggled)
	if toggled:
		_update_backend_ui(false, "Simulated Fallback Mode Enabled by Developer")
	else:
		_on_ping_pressed()


func _on_ping_pressed() -> void:
	var client = get_node_or_null("/root/AIClient")
	if client and client.has_method("check_health"):
		status_badge.text = "CONNECTING..."
		status_badge.modulate = Color(1.0, 0.8, 0.2)
		client.call("check_health", func(res: Dictionary):
			var online = bool(res.get("success", false))
			var err = str(res.get("error", ""))
			_update_backend_ui(online, err if not online else "")
		)
	else:
		_update_backend_ui(false, "AIClient autoload unavailable")


func _on_test_query_pressed() -> void:
	var nav_mgr = get_node_or_null("/root/NavigationManager")
	if not nav_mgr:
		return
		
	# Sample test query across map from (0, 0) to (300, 300)
	test_query_button.disabled = true
	test_query_button.text = "RUNNING..."
	nav_mgr.call("request_path", Vector2.ZERO, Vector2(300.0, 300.0), null, func(path: PackedVector2Array, metrics: Dictionary):
		if is_instance_valid(test_query_button):
			test_query_button.disabled = false
			test_query_button.text = "TEST NAVIGATION QUERY"
		_on_metrics_updated(metrics)
	)


func _update_backend_ui(is_online: bool, err_msg: String) -> void:
	if not status_badge:
		return
		
	if is_online:
		status_badge.text = "● BACKEND ONLINE (FastAPI :8000)"
		status_badge.modulate = Color(0.2, 1.0, 0.4)
		if error_banner:
			error_banner.visible = false
	else:
		status_badge.text = "▲ OFFLINE: [FALLBACK_ASTAR2D] ACTIVE"
		status_badge.modulate = Color(1.0, 0.6, 0.1)
		if error_banner:
			error_banner.visible = true
			error_banner.text = "FALLBACK NOTICE: " + (err_msg if err_msg != "" else "Backend unreachable. Native Godot AStarGrid2D active.")


func _on_backend_status_changed(is_online: bool, msg: String) -> void:
	_update_backend_ui(is_online, msg if not is_online else "")


func _on_fallback_triggered(reason: String) -> void:
	_update_backend_ui(false, reason)


func _on_metrics_updated(metrics: Dictionary) -> void:
	if metrics_algo_label:
		metrics_algo_label.text = str(metrics.get("algorithm", "—"))
	if metrics_source_label:
		var src: String = str(metrics.get("source", "—"))
		metrics_source_label.text = src
		if src == "PYTHON_AI_BACKEND":
			metrics_source_label.modulate = Color(0.2, 1.0, 0.5)
		else:
			metrics_source_label.modulate = Color(1.0, 0.7, 0.2)
	if metrics_nodes_label:
		metrics_nodes_label.text = str(metrics.get("nodes_expanded", 0))
	if metrics_time_label:
		metrics_time_label.text = "%.3f ms" % float(metrics.get("execution_time_ms", 0.0))
	if metrics_length_label:
		metrics_length_label.text = "%d points" % int(metrics.get("path_length", 0))


func _on_difficulty_selected(index: int) -> void:
	if index < 0 or index >= DIFF_KEYS.size():
		return
	var chosen_mode := DIFF_KEYS[index]
	var dc = get_node_or_null("/root/DifficultyController")
	if dc and dc.has_method("set_difficulty_mode"):
		dc.call("set_difficulty_mode", chosen_mode)


func _on_difficulty_updated(agg: float, intensity: float, params: Dictionary) -> void:
	if difficulty_telemetry:
		var spd: float = float(params.get("speed_multiplier", 1.0))
		var dmg: float = float(params.get("attack_damage_multiplier", 1.0))
		var cd: float = float(params.get("attack_cooldown_multiplier", 1.0))
		difficulty_telemetry.text = "Aggression: %.2f | Intensity: %.2fx | Speed: %.2fx | Dmg: %.2fx | CD: %.2fx" % [
			agg, intensity, spd, dmg, cd
		]
