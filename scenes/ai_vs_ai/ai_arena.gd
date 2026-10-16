class_name AIArena
extends Node2D
## AI vs AI Simulation Arena & Controller for BioSphere-X.
## Manages autonomous agents, match lifecycle, scenario rules (Pursuit & Combat, Race to Objective),
## independent algorithm selection, simulation speed, fair trial reproducibility, and experimental metrics export.

signal match_started()
signal match_paused(is_paused: bool)
signal match_finished(outcome: Dictionary)
signal match_reset()

enum MatchState {
	WAITING,
	RUNNING,
	PAUSED,
	FINISHED
}

const ARENA_GRID_SIZE := Vector2i(40, 40)
const ARENA_CELL_SIZE := 32.0
const ARENA_ORIGIN := Vector2(-640.0, -640.0)
const ARENA_SIZE := Vector2(1280.0, 1280.0)

const SPAWN_A_DEFAULT := Vector2(-420.0, 0.0)
const SPAWN_B_DEFAULT := Vector2(420.0, 0.0)
const OBJECTIVE_DEFAULT := Vector2(0.0, 0.0)

const ALGORITHMS: Array[String] = [
	"astar",
	"greedy",
	"bfs",
	"dfs",
	"dls",
	"iddfs",
	"bidirectional"
]

const ALGO_LABELS: Array[String] = [
	"A* Search (Optimal)",
	"Greedy Best-First Search",
	"Breadth-First Search (BFS)",
	"Depth-First Search (DFS)",
	"Depth-Limited Search (DLS)",
	"Iterative Deepening DFS (IDDFS)",
	"Bidirectional Search"
]

const SCENARIOS: Array[String] = [
	"combat",
	"race"
]

const SCENARIO_LABELS: Array[String] = [
	"Pursuit and Combat",
	"Race to Objective"
]

# Configurable Parameters
@export var current_scenario: String = "combat"
@export var agent_a_algorithm: String = "astar"
@export var agent_b_algorithm: String = "greedy"
@export var swap_spawns: bool = false
@export var match_time_limit: float = 120.0
@export var simulation_speed: float = 1.0
@export var random_seed: int = 42

# Preloads
const AutonomousAgentScript := preload("res://scenes/ai_vs_ai/autonomous_agent.gd")
const ObjectiveBeaconScript := preload("res://scenes/ai_vs_ai/objective_beacon.gd")
const MapDataScript := preload("res://scripts/components/map_data.gd")

var _agent_scene := preload("res://scenes/ai_vs_ai/autonomous_agent.tscn")
var _beacon_scene := preload("res://scenes/ai_vs_ai/objective_beacon.tscn")

# Runtime State
var match_state: MatchState = MatchState.WAITING
var match_elapsed_time: float = 0.0
var match_results: Dictionary = {}
var map_data: RefCounted = null

# Node References
var agent_a: CharacterBody2D = null
var agent_b: CharacterBody2D = null
var objective_beacon: Area2D = null

# UI References
@onready var scenario_dropdown: OptionButton = %ScenarioDropdown
@onready var algo_a_dropdown: OptionButton = %AlgoADropdown
@onready var algo_b_dropdown: OptionButton = %AlgoBDropdown
@onready var start_button: Button = %StartButton
@onready var pause_button: Button = %PauseButton
@onready var reset_button: Button = %ResetButton
@onready var swap_button: CheckButton = %SwapSpawnsToggle
@onready var speed_slider: HSlider = %SpeedSlider
@onready var speed_label: Label = %SpeedLabel
@onready var seed_spin: SpinBox = %SeedSpin
@onready var match_status_label: Label = %MatchStatusLabel
@onready var timer_label: Label = %TimerLabel
@onready var results_panel: PanelContainer = %ResultsPanel
@onready var winner_banner: Label = %WinnerBanner
@onready var export_json_btn: Button = %ExportJSONButton
@onready var export_csv_btn: Button = %ExportCSVButton
@onready var export_status_label: Label = %ExportStatusLabel
@onready var exit_button: Button = %ExitButton

# Live Telemetry Labels
@onready var a_hp_bar: ProgressBar = %A_HpBar
@onready var a_hp_label: Label = %A_HpLabel
@onready var a_nodes_label: Label = %A_NodesLabel
@onready var a_time_label: Label = %A_TimeLabel
@onready var b_hp_bar: ProgressBar = %B_HpBar
@onready var b_hp_label: Label = %B_HpLabel
@onready var b_nodes_label: Label = %B_NodesLabel
@onready var b_time_label: Label = %B_TimeLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_map_data()
	_build_arena_obstacles()
	_spawn_agents()
	_spawn_objective_beacon()
	_setup_ui()
	_apply_simulation_speed(simulation_speed)
	
	# Register map_data with NavigationManager so backend coordinate transforms match this arena
	var nav_mgr = get_node_or_null("/root/NavigationManager")
	if nav_mgr and nav_mgr.has_method("set_map_data"):
		nav_mgr.call("set_map_data", map_data)

	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_ambient"):
		audio.call("play_ambient", "space_ambient")

	reset_match()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		toggle_pause()
		get_viewport().set_input_as_handled()


func _setup_map_data() -> void:
	map_data = MapDataScript.new(ARENA_GRID_SIZE, ARENA_CELL_SIZE, ARENA_ORIGIN)


func _build_arena_obstacles() -> void:
	var container := Node2D.new()
	container.name = "ArenaObstacles"
	add_child(container)

	# 1. Outer Boundaries
	var min_x := ARENA_ORIGIN.x
	var min_y := ARENA_ORIGIN.y
	var max_x := min_x + ARENA_SIZE.x
	var max_y := min_y + ARENA_SIZE.y

	_add_wall_box(container, Vector2(0, min_y), Vector2(ARENA_SIZE.x + 32, 24))
	_add_wall_box(container, Vector2(0, max_y), Vector2(ARENA_SIZE.x + 32, 24))
	_add_wall_box(container, Vector2(min_x, 0), Vector2(24, ARENA_SIZE.y))
	_add_wall_box(container, Vector2(max_x, 0), Vector2(24, ARENA_SIZE.y))

	# 2. Symmetric Central Pillars & Chokepoints
	# Creates a tactical maze with central plaza and flanking routes
	var pillar_size := Vector2(48.0, 160.0)
	_add_wall_box(container, Vector2(-180.0, -180.0), pillar_size)
	_add_wall_box(container, Vector2(-180.0, 180.0), pillar_size)
	_add_wall_box(container, Vector2(180.0, -180.0), pillar_size)
	_add_wall_box(container, Vector2(180.0, 180.0), pillar_size)

	# Central decorative obstacle blocks (leaving center corridor for Race Objective)
	_add_wall_box(container, Vector2(0.0, -280.0), Vector2(160.0, 48.0))
	_add_wall_box(container, Vector2(0.0, 280.0), Vector2(160.0, 48.0))

	# Flanking corner bastions
	_add_rock_cluster(container, Vector2(-380.0, -280.0), 38.0)
	_add_rock_cluster(container, Vector2(-380.0, 280.0), 38.0)
	_add_rock_cluster(container, Vector2(380.0, -280.0), 38.0)
	_add_rock_cluster(container, Vector2(380.0, 280.0), 38.0)


func _add_wall_box(parent: Node2D, pos: Vector2, size: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.position = pos
	wall.collision_layer = 1
	wall.collision_mask = 1

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	wall.add_child(col)

	var rect := Rect2(pos - size * 0.5, size)
	if map_data:
		map_data.set_world_rect_blocked(rect, true, MapDataScript.CellType.WALL)

	parent.add_child(wall)


func _add_rock_cluster(parent: Node2D, center: Vector2, radius: float) -> void:
	var rock := StaticBody2D.new()
	rock.position = center
	rock.collision_layer = 1
	rock.collision_mask = 1

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	col.shape = shape
	rock.add_child(col)

	if map_data:
		map_data.set_world_circle_blocked(center, radius, true, MapDataScript.CellType.ROCK)

	parent.add_child(rock)


func _spawn_agents() -> void:
	var pos_a := SPAWN_B_DEFAULT if swap_spawns else SPAWN_A_DEFAULT
	var pos_b := SPAWN_A_DEFAULT if swap_spawns else SPAWN_B_DEFAULT

	agent_a = _agent_scene.instantiate()
	agent_a.name = "AgentA"
	add_child(agent_a)
	agent_a.call("setup_agent", "Agent A", "team_a", Color(0.12, 0.88, 1.0), agent_a_algorithm, current_scenario)
	agent_a.global_position = pos_a
	agent_a.call("set_map_data", map_data)
	agent_a.connect("agent_died", _on_agent_died)

	agent_b = _agent_scene.instantiate()
	agent_b.name = "AgentB"
	add_child(agent_b)
	agent_b.call("setup_agent", "Agent B", "team_b", Color(1.0, 0.55, 0.15), agent_b_algorithm, current_scenario)
	agent_b.global_position = pos_b
	agent_b.call("set_map_data", map_data)
	agent_b.connect("agent_died", _on_agent_died)

	_configure_scenario_targets()


func _spawn_objective_beacon() -> void:
	objective_beacon = _beacon_scene.instantiate()
	objective_beacon.name = "ObjectiveBeacon"
	objective_beacon.global_position = OBJECTIVE_DEFAULT
	add_child(objective_beacon)
	objective_beacon.connect("objective_reached", _on_objective_reached)
	objective_beacon.visible = (current_scenario == "race")


func _configure_scenario_targets() -> void:
	if not agent_a or not agent_b:
		return

	if current_scenario == "combat":
		agent_a.scenario = "combat"
		agent_b.scenario = "combat"
		agent_a.set_target(agent_b)
		agent_b.set_target(agent_a)
		if objective_beacon:
			objective_beacon.visible = false
	else:
		agent_a.scenario = "race"
		agent_b.scenario = "race"
		if objective_beacon:
			objective_beacon.visible = true
			objective_beacon.reset_beacon()
			agent_a.set_target(objective_beacon)
			agent_b.set_target(objective_beacon)


func _setup_ui() -> void:
	# Scenario Dropdown
	if scenario_dropdown:
		scenario_dropdown.clear()
		for i in range(SCENARIO_LABELS.size()):
			scenario_dropdown.add_item(SCENARIO_LABELS[i], i)
		scenario_dropdown.selected = SCENARIOS.find(current_scenario)
		scenario_dropdown.item_selected.connect(_on_scenario_selected)

	# Algorithm Dropdowns
	if algo_a_dropdown:
		algo_a_dropdown.clear()
		for i in range(ALGO_LABELS.size()):
			algo_a_dropdown.add_item(ALGO_LABELS[i], i)
		algo_a_dropdown.selected = ALGORITHMS.find(agent_a_algorithm)
		algo_a_dropdown.item_selected.connect(func(idx: int):
			agent_a_algorithm = ALGORITHMS[idx]
			if agent_a:
				agent_a.algorithm = agent_a_algorithm
				agent_a.queue_redraw()
		)

	if algo_b_dropdown:
		algo_b_dropdown.clear()
		for i in range(ALGO_LABELS.size()):
			algo_b_dropdown.add_item(ALGO_LABELS[i], i)
		algo_b_dropdown.selected = ALGORITHMS.find(agent_b_algorithm)
		algo_b_dropdown.item_selected.connect(func(idx: int):
			agent_b_algorithm = ALGORITHMS[idx]
			if agent_b:
				agent_b.algorithm = agent_b_algorithm
				agent_b.queue_redraw()
		)

	# Buttons
	if start_button:
		start_button.pressed.connect(start_match)
	if pause_button:
		pause_button.pressed.connect(toggle_pause)
	if reset_button:
		reset_button.pressed.connect(reset_match)
	if swap_button:
		swap_button.toggled.connect(func(toggled: bool):
			swap_spawns = toggled
			reset_match()
		)
	if seed_spin:
		seed_spin.value = random_seed
		seed_spin.value_changed.connect(func(val: float):
			random_seed = int(val)
		)
	if speed_slider:
		speed_slider.value = simulation_speed
		speed_slider.value_changed.connect(func(val: float):
			_apply_simulation_speed(val)
		)
	if export_json_btn:
		export_json_btn.pressed.connect(export_json_results)
	if export_csv_btn:
		export_csv_btn.pressed.connect(export_csv_results)
	if exit_button:
		exit_button.pressed.connect(_on_exit_pressed)

	if results_panel:
		results_panel.visible = false


func _apply_simulation_speed(speed: float) -> void:
	simulation_speed = clampf(speed, 0.25, 4.0)
	Engine.time_scale = simulation_speed
	if speed_label:
		speed_label.text = "%.2fx" % simulation_speed


func _process(delta: float) -> void:
	# In Godot, delta is scaled by Engine.time_scale during normal process
	if match_state == MatchState.RUNNING:
		match_elapsed_time += (delta / Engine.time_scale) if Engine.time_scale > 0.0 else delta
		if timer_label:
			timer_label.text = "Time: %.1fs / %.0fs" % [match_elapsed_time, match_time_limit]

		if match_elapsed_time >= match_time_limit:
			_terminate_match("Time Limit Exceeded (Draw)")

	_update_telemetry()


func _update_telemetry() -> void:
	if agent_a and agent_a.get("health_component"):
		var cur_a: float = float(agent_a.health_component.current_health)
		var max_a: float = float(agent_a.health_component.max_health)
		if a_hp_bar:
			a_hp_bar.max_value = max_a
			a_hp_bar.value = cur_a
		if a_hp_label:
			a_hp_label.text = "%d HP" % int(cur_a)
		if a_nodes_label:
			a_nodes_label.text = "Nodes: %d" % int(agent_a.get("total_nodes_expanded"))
		if a_time_label:
			a_time_label.text = "Time: %.1fms" % float(agent_a.get("total_algo_time_ms"))

	if agent_b and agent_b.get("health_component"):
		var cur_b: float = float(agent_b.health_component.current_health)
		var max_b: float = float(agent_b.health_component.max_health)
		if b_hp_bar:
			b_hp_bar.max_value = max_b
			b_hp_bar.value = cur_b
		if b_hp_label:
			b_hp_label.text = "%d HP" % int(cur_b)
		if b_nodes_label:
			b_nodes_label.text = "Nodes: %d" % int(agent_b.get("total_nodes_expanded"))
		if b_time_label:
			b_time_label.text = "Time: %.1fms" % float(agent_b.get("total_algo_time_ms"))


# ---------------------------------------------------------------------------
# Simulation Lifecycle Controls
# ---------------------------------------------------------------------------
func start_match() -> void:
	if match_state == MatchState.RUNNING:
		return

	if match_state == MatchState.FINISHED:
		reset_match()

	match_state = MatchState.RUNNING
	_set_agents_active(true)

	if match_status_label:
		match_status_label.text = "STATUS: RUNNING"
		match_status_label.modulate = Color(0.2, 1.0, 0.4)
	if pause_button:
		pause_button.text = "Pause"
	if results_panel:
		results_panel.visible = false

	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_sfx"):
		audio.call("play_sfx", "ui_click")

	match_started.emit()


func pause_match() -> void:
	if match_state != MatchState.RUNNING:
		return
	match_state = MatchState.PAUSED
	_set_agents_active(false)

	if match_status_label:
		match_status_label.text = "STATUS: PAUSED"
		match_status_label.modulate = Color(1.0, 0.8, 0.2)
	if pause_button:
		pause_button.text = "Resume"

	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_sfx"):
		audio.call("play_sfx", "ui_click")

	match_paused.emit(true)


func resume_match() -> void:
	if match_state != MatchState.PAUSED:
		return
	match_state = MatchState.RUNNING
	_set_agents_active(true)

	if match_status_label:
		match_status_label.text = "STATUS: RUNNING"
		match_status_label.modulate = Color(0.2, 1.0, 0.4)
	if pause_button:
		pause_button.text = "Pause"

	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_sfx"):
		audio.call("play_sfx", "ui_click")

	match_paused.emit(false)


func toggle_pause() -> void:
	if match_state == MatchState.RUNNING:
		pause_match()
	elif match_state == MatchState.PAUSED:
		resume_match()


func reset_match() -> void:
	match_state = MatchState.WAITING
	match_elapsed_time = 0.0
	match_results.clear()

	var pos_a := SPAWN_B_DEFAULT if swap_spawns else SPAWN_A_DEFAULT
	var pos_b := SPAWN_A_DEFAULT if swap_spawns else SPAWN_B_DEFAULT

	if agent_a:
		agent_a.reset_agent(pos_a)
		agent_a.setup_agent("Agent A", "team_a", Color(0.12, 0.88, 1.0), agent_a_algorithm, current_scenario)
	if agent_b:
		agent_b.reset_agent(pos_b)
		agent_b.setup_agent("Agent B", "team_b", Color(1.0, 0.55, 0.15), agent_b_algorithm, current_scenario)

	_configure_scenario_targets()
	_set_agents_active(false)

	if timer_label:
		timer_label.text = "Time: 0.0s / %.0fs" % match_time_limit
	if match_status_label:
		match_status_label.text = "STATUS: READY"
		match_status_label.modulate = Color(0.7, 0.8, 1.0)
	if pause_button:
		pause_button.text = "Pause"
	if results_panel:
		results_panel.visible = false
	if export_status_label:
		export_status_label.text = ""

	match_reset.emit()
	queue_redraw()


func _set_agents_active(active: bool) -> void:
	var mode := Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	if agent_a:
		agent_a.process_mode = mode
	if agent_b:
		agent_b.process_mode = mode


func _on_scenario_selected(idx: int) -> void:
	current_scenario = SCENARIOS[idx]
	reset_match()


func _on_agent_died(dead_agent: CharacterBody2D) -> void:
	if match_state != MatchState.RUNNING:
		return

	var winner_str := ""
	if dead_agent == agent_a:
		winner_str = "Agent B Won (Elimination)"
	elif dead_agent == agent_b:
		winner_str = "Agent A Won (Elimination)"
	else:
		winner_str = "Mutual Elimination (Draw)"

	_terminate_match(winner_str)


func _on_objective_reached(winning_agent: CharacterBody2D) -> void:
	if match_state != MatchState.RUNNING:
		return

	var a_name: String = winning_agent.get("agent_name") if winning_agent.get("agent_name") != null else "Agent"
	var winner_str := "%s Won (Objective Reached)" % a_name
	_terminate_match(winner_str)


func _terminate_match(outcome_str: String) -> void:
	match_state = MatchState.FINISHED
	_set_agents_active(false)

	var winner := "None"
	if "Agent A Won" in outcome_str:
		winner = "Agent A"
	elif "Agent B Won" in outcome_str:
		winner = "Agent B"

	var metrics_a: Dictionary = agent_a.call("get_metrics") if agent_a and agent_a.has_method("get_metrics") else {}
	var metrics_b: Dictionary = agent_b.call("get_metrics") if agent_b and agent_b.has_method("get_metrics") else {}

	# If race scenario, mark combat metrics as unavailable instead of fictitious
	if current_scenario == "race":
		metrics_a["damage_dealt"] = "unavailable"
		metrics_a["damage_taken"] = "unavailable"
		metrics_b["damage_dealt"] = "unavailable"
		metrics_b["damage_taken"] = "unavailable"

	match_results = {
		"scenario": current_scenario,
		"scenario_label": SCENARIO_LABELS[SCENARIOS.find(current_scenario)],
		"map_name": "Symmetric Alien Proving Grounds",
		"grid_size": [ARENA_GRID_SIZE.x, ARENA_GRID_SIZE.y],
		"cell_size": ARENA_CELL_SIZE,
		"random_seed": random_seed,
		"swap_spawns": swap_spawns,
		"match_duration_seconds": roundf(match_elapsed_time * 100.0) / 100.0,
		"outcome": outcome_str,
		"winner": winner,
		"simulation_speed": simulation_speed,
		"agent_a": metrics_a,
		"agent_b": metrics_b,
		"timestamp": Time.get_datetime_string_from_system()
	}

	if match_status_label:
		match_status_label.text = "STATUS: %s" % outcome_str.to_upper()
		match_status_label.modulate = Color(1.0, 0.4, 0.8)

	if winner_banner:
		winner_banner.text = "★ %s ★" % outcome_str.to_upper()

	if results_panel:
		results_panel.visible = true

	match_finished.emit(match_results)
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_sfx"):
		audio.call("play_sfx", "mission_complete")
	print("BioSphere-X AI vs AI Match Completed: ", match_results)


# ---------------------------------------------------------------------------
# Experimental Data Export (JSON & CSV)
# ---------------------------------------------------------------------------
func export_json_results() -> String:
	if match_results.is_empty():
		if export_status_label:
			export_status_label.text = "No match results to export."
		return ""

	var json_str := JSON.stringify(match_results, "\t")
	var dir_path := "user://experiments"
	DirAccess.make_dir_absolute(dir_path)

	var timestamp := Time.get_datetime_string_from_system().replace(":", "-")
	var file_path := "%s/match_%s_%s.json" % [dir_path, current_scenario, timestamp]

	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(json_str)
		file.close()
		var msg := "Saved JSON to: %s" % ProjectSettings.globalize_path(file_path)
		if export_status_label:
			export_status_label.text = msg
		print(msg)
		return file_path
	else:
		var err_msg := "Failed to open file for JSON export."
		if export_status_label:
			export_status_label.text = err_msg
		return ""


func export_csv_results() -> String:
	if match_results.is_empty():
		if export_status_label:
			export_status_label.text = "No match results to export."
		return ""

	var dir_path := "user://experiments"
	DirAccess.make_dir_absolute(dir_path)

	var timestamp := Time.get_datetime_string_from_system().replace(":", "-")
	var file_path := "%s/match_%s_%s.csv" % [dir_path, current_scenario, timestamp]

	var headers := [
		"Timestamp", "Scenario", "RandomSeed", "SwapSpawns", "DurationSeconds", "Outcome", "Winner",
		"AgentA_Algo", "AgentA_Requests", "AgentA_NodesExpanded", "AgentA_AlgoTimeMs", "AgentA_DistanceTraveled", "AgentA_RemainingHP", "AgentA_DamageDealt",
		"AgentB_Algo", "AgentB_Requests", "AgentB_NodesExpanded", "AgentB_AlgoTimeMs", "AgentB_DistanceTraveled", "AgentB_RemainingHP", "AgentB_DamageDealt"
	]

	var a_data: Dictionary = match_results.get("agent_a", {})
	var b_data: Dictionary = match_results.get("agent_b", {})

	var values := [
		str(match_results.get("timestamp", "")),
		str(match_results.get("scenario", "")),
		str(match_results.get("random_seed", 0)),
		str(match_results.get("swap_spawns", false)),
		str(match_results.get("match_duration_seconds", 0.0)),
		"\"" + str(match_results.get("outcome", "")) + "\"",
		str(match_results.get("winner", "")),
		str(a_data.get("algorithm", "")),
		str(a_data.get("total_requests", 0)),
		str(a_data.get("total_nodes_expanded", 0)),
		str(a_data.get("total_algo_time_ms", 0.0)),
		str(roundf(float(a_data.get("total_distance_traveled", 0.0)) * 10.0) / 10.0),
		str(a_data.get("current_health", "unavailable")),
		str(a_data.get("damage_dealt", "unavailable")),
		str(b_data.get("algorithm", "")),
		str(b_data.get("total_requests", 0)),
		str(b_data.get("total_nodes_expanded", 0)),
		str(b_data.get("total_algo_time_ms", 0.0)),
		str(roundf(float(b_data.get("total_distance_traveled", 0.0)) * 10.0) / 10.0),
		str(b_data.get("current_health", "unavailable")),
		str(b_data.get("damage_dealt", "unavailable"))
	]

	var csv_text := ",".join(headers) + "\n" + ",".join(values) + "\n"

	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(csv_text)
		file.close()
		var msg := "Saved CSV to: %s" % ProjectSettings.globalize_path(file_path)
		if export_status_label:
			export_status_label.text = msg
		print(msg)
		return file_path
	else:
		var err_msg := "Failed to open file for CSV export."
		if export_status_label:
			export_status_label.text = err_msg
		return ""


func _on_exit_pressed() -> void:
	Engine.time_scale = 1.0 # Guarantee time scale restored to normal
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")


# ---------------------------------------------------------------------------
# Procedural Arena Visual Drawing
# ---------------------------------------------------------------------------
func _draw() -> void:
	# Draw Arena floor grid background
	var floor_rect := Rect2(ARENA_ORIGIN, ARENA_SIZE)
	draw_rect(floor_rect, Color(0.06, 0.07, 0.10, 1.0))

	# Grid lines
	var grid_color := Color(0.12, 0.16, 0.22, 0.5)
	for x in range(ARENA_GRID_SIZE.x + 1):
		var wx := ARENA_ORIGIN.x + float(x) * ARENA_CELL_SIZE
		draw_line(Vector2(wx, ARENA_ORIGIN.y), Vector2(wx, ARENA_ORIGIN.y + ARENA_SIZE.y), grid_color, 1.0)
	for y in range(ARENA_GRID_SIZE.y + 1):
		var wy := ARENA_ORIGIN.y + float(y) * ARENA_CELL_SIZE
		draw_line(Vector2(ARENA_ORIGIN.x, wy), Vector2(ARENA_ORIGIN.x + ARENA_SIZE.x, wy), grid_color, 1.0)

	# Boundary highlight
	draw_rect(floor_rect, Color(0.2, 0.8, 1.0, 0.7), false, 2.0)

	# Draw symmetric spawn rings
	var pos_a := SPAWN_B_DEFAULT if swap_spawns else SPAWN_A_DEFAULT
	var pos_b := SPAWN_A_DEFAULT if swap_spawns else SPAWN_B_DEFAULT
	draw_arc(pos_a, 32.0, 0, TAU, 32, Color(0.12, 0.88, 1.0, 0.4), 2.0)
	draw_arc(pos_b, 32.0, 0, TAU, 32, Color(1.0, 0.55, 0.15, 0.4), 2.0)
