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

const MAP_PRESETS: Array[String] = [
	"symmetric",
	"chokepoints",
	"open_basin",
	"labyrinth"
]

const MAP_PRESET_LABELS: Array[String] = [
	"Symmetric Proving Grounds",
	"Canyon Chokepoints & U-Traps",
	"Open Crater Basin",
	"The Labyrinth"
]

const ALGO_THEORY: Dictionary = {
	"astar": {
		"name": "A* Search",
		"category": "Informed / Heuristic Best-First",
		"cost_function": "f(n) = g(n) + h(n)",
		"admissibility": "Admissible & Consistent (Euclidean h(n) <= h*(n))",
		"optimality": "Guaranteed Optimal",
		"completeness": "Complete",
		"time_complexity": "O(b^d)",
		"space_complexity": "O(b^d) (Stores all expanded nodes in RAM)",
		"academic_description": "A* combines the exact cumulative path cost g(n) with an admissible Euclidean heuristic h(n). Because Euclidean distance never overestimates actual distance on a 2D plane (h(n) <= h*(n)), A* is mathematically guaranteed to find the shortest path while exploring the minimum necessary search space."
	},
	"greedy": {
		"name": "Greedy Best-First Search",
		"category": "Informed / Pure Heuristic",
		"cost_function": "f(n) = h(n)",
		"admissibility": "Non-admissible evaluation (ignores g(n))",
		"optimality": "Not Guaranteed (Highly Suboptimal)",
		"completeness": "Incomplete in infinite spaces / graph loops",
		"time_complexity": "O(b^m) (m = maximum depth)",
		"space_complexity": "O(b^m)",
		"academic_description": "Greedy Best-First expands nodes solely based on estimated distance to goal h(n). While blazing fast across open fields, it is vulnerable to local minima and concave dead-ends (such as canyon U-traps) because it cannot account for accumulated path cost."
	},
	"bfs": {
		"name": "Breadth-First Search (BFS)",
		"category": "Uninformed / FIFO Queue Exhaustive",
		"cost_function": "f(n) = depth(n)",
		"admissibility": "N/A (Uninformed)",
		"optimality": "Guaranteed Optimal for Uniform Step Costs",
		"completeness": "Complete (with finite branching factor b)",
		"time_complexity": "O(b^d)",
		"space_complexity": "O(b^d) (Exhaustive RAM footprint)",
		"academic_description": "Breadth-First Search systematically expands all shallow nodes at depth d before advancing to d+1. On uniform-cost grids, it guarantees the minimum-step path, but its exponential memory footprint O(b^d) causes substantial overhead in large search environments."
	},
	"dfs": {
		"name": "Depth-First Search (DFS)",
		"category": "Uninformed / LIFO Stack Deep-Dive",
		"cost_function": "f(n) = -depth(n)",
		"admissibility": "N/A (Uninformed)",
		"optimality": "Not Optimal (Arbitrary path based on tie-breaking)",
		"completeness": "Incomplete (Can loop in cycles or infinite trees)",
		"time_complexity": "O(b^m)",
		"space_complexity": "O(b * m) (Linear memory footprint)",
		"academic_description": "Depth-First Search explores deeply along a single branch before backtracking. It maintains a modest linear memory footprint O(b*m), but typically produces jagged, meandering paths and can wander far away from the target."
	},
	"dls": {
		"name": "Depth-Limited Search (DLS)",
		"category": "Uninformed / Depth-Bounded DFS",
		"cost_function": "DFS with depth cutoff limit l",
		"admissibility": "N/A (Uninformed)",
		"optimality": "Not Optimal",
		"completeness": "Incomplete if target depth d > l",
		"time_complexity": "O(b^l)",
		"space_complexity": "O(b * l)",
		"academic_description": "Depth-Limited Search mitigates DFS infinite recursion by establishing a hard depth bound l. However, if the goal node lies beyond depth l, the algorithm terminates with a failure."
	},
	"iddfs": {
		"name": "Iterative Deepening DFS (IDDFS)",
		"category": "Uninformed / Iterative Depth-Bound",
		"cost_function": "Repeated DLS with bounds l = 0, 1, 2... d",
		"admissibility": "N/A (Uninformed)",
		"optimality": "Guaranteed Optimal (Uniform step cost)",
		"completeness": "Complete",
		"time_complexity": "O(b^d)",
		"space_complexity": "O(b * d) (Linear memory with BFS optimality)",
		"academic_description": "Iterative Deepening DFS merges the completeness and optimality of BFS with the modest O(b*d) linear memory of DFS. By repeatedly performing depth-limited searches with increasing bounds, it finds the shortest path with negligible regeneration overhead ~ b/(b-1)."
	},
	"bidirectional": {
		"name": "Bidirectional Search",
		"category": "Simultaneous Dual-Frontier Search",
		"cost_function": "Forward frontier from Start + Backward frontier from Goal",
		"admissibility": "Preserved when component heuristics are admissible",
		"optimality": "Optimal when search frontiers intersect",
		"completeness": "Complete",
		"time_complexity": "O(b^(d/2) + b^(d/2)) << O(b^d)",
		"space_complexity": "O(b^(d/2))",
		"academic_description": "Bidirectional Search grows two simultaneous search frontiers—one from the starting position and one backward from the destination. When the frontiers intersect, an optimal path is stitched together, cutting search space from O(b^d) down to O(b^(d/2))."
	}
}

# Configurable Parameters
@export var current_scenario: String = "combat"
@export var current_map: String = "symmetric"
@export var agent_a_algorithm: String = "astar"
@export var agent_b_algorithm: String = "greedy"
@export var swap_spawns: bool = false
@export var match_time_limit: float = 120.0
@export var simulation_speed: float = 1.0
@export var random_seed: int = 42
@export var dynamic_camera_enabled: bool = true
@export var show_ai_paths: bool = true

# Preloads
const AutonomousAgentScript := preload("res://scenes/ai_vs_ai/autonomous_agent.gd")
const ObjectiveBeaconScript := preload("res://scenes/ai_vs_ai/objective_beacon.gd")
const MapDataScript := preload("res://scripts/components/map_data.gd")
const CanyonWallScript := preload("res://scripts/components/canyon_wall.gd")
const AlienRockScript := preload("res://scripts/components/alien_rock.gd")

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
@onready var map_dropdown: OptionButton = get_node_or_null("%MapDropdown")
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

# Enhanced Sci-Fi & Academic UI References
@onready var control_panel: Control = get_node_or_null("%ControlPanel")
@onready var config_button: Button = get_node_or_null("%ConfigButton")
@onready var close_config_btn: Button = get_node_or_null("%CloseConfigButton")
@onready var cam_button: Button = get_node_or_null("%CamButton")
@onready var path_viz_button: Button = get_node_or_null("%PathVizButton")
@onready var inspector_button: Button = get_node_or_null("%InspectorButton")
@onready var view_inspector_btn: Button = get_node_or_null("%ViewInspectorBtn")
@onready var a_algo_badge: Label = get_node_or_null("%A_AlgoBadge")
@onready var b_algo_badge: Label = get_node_or_null("%B_AlgoBadge")
@onready var scenario_badge: Label = get_node_or_null("%ScenarioBadge")
@onready var camera: Camera2D = $Camera2D

# Academic Inspector Modal References
@onready var academic_inspector_modal: PanelContainer = get_node_or_null("%AcademicInspectorModal")
@onready var card_a_title: Label = get_node_or_null("%CardATitle")
@onready var card_a_details: RichTextLabel = get_node_or_null("%CardA_Details")
@onready var card_b_title: Label = get_node_or_null("%CardBTitle")
@onready var card_b_details: RichTextLabel = get_node_or_null("%CardB_Details")
@onready var academic_summary_label: RichTextLabel = get_node_or_null("%AcademicSummaryLabel")
@onready var copy_defense_btn: Button = get_node_or_null("%CopyDefenseBtn")
@onready var copy_status_label: Label = get_node_or_null("%CopyStatusLabel")
@onready var close_inspector_btn: Button = get_node_or_null("%CloseInspectorBtn")

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


func change_map(preset_key: String) -> void:
	if preset_key not in MAP_PRESETS:
		return
	current_map = preset_key
	_setup_map_data()
	_build_arena_obstacles()

	var nav_mgr = get_node_or_null("/root/NavigationManager")
	if nav_mgr and nav_mgr.has_method("set_map_data"):
		nav_mgr.call("set_map_data", map_data)

	if agent_a:
		agent_a.call("set_map_data", map_data)
	if agent_b:
		agent_b.call("set_map_data", map_data)

	reset_match()


func _build_arena_obstacles() -> void:
	var old_obstacles := get_node_or_null("ArenaObstacles")
	if old_obstacles:
		old_obstacles.name = "ArenaObstacles_Old"
		old_obstacles.queue_free()

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

	match current_map:
		"chokepoints":
			_build_map_chokepoints(container)
		"open_basin":
			_build_map_open_basin(container)
		"labyrinth":
			_build_map_labyrinth(container)
		_:
			_build_map_symmetric(container)


func _build_map_symmetric(container: Node2D) -> void:
	# 2. Symmetric Central Pillars & Chokepoints
	# Creates a balanced tournament arena with central plaza and flanking routes
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


func _build_map_chokepoints(container: Node2D) -> void:
	# Academic Feature: Concave U-Traps designed to demonstrate Greedy Best-First Search local minima vs A*
	# Concave U-Trap 1 facing left towards Agent A
	_add_wall_box(container, Vector2(-90.0, 0.0), Vector2(32.0, 220.0)) # Back wall
	_add_wall_box(container, Vector2(-160.0, -110.0), Vector2(140.0, 32.0)) # Top lip
	_add_wall_box(container, Vector2(-160.0, 110.0), Vector2(140.0, 32.0)) # Bottom lip

	# Concave U-Trap 2 facing right towards Agent B
	_add_wall_box(container, Vector2(90.0, 0.0), Vector2(32.0, 220.0)) # Back wall
	_add_wall_box(container, Vector2(160.0, -110.0), Vector2(140.0, 32.0)) # Top lip
	_add_wall_box(container, Vector2(160.0, 110.0), Vector2(140.0, 32.0)) # Bottom lip

	# Center vertical aperture baffles
	_add_wall_box(container, Vector2(0.0, -320.0), Vector2(48.0, 260.0))
	_add_wall_box(container, Vector2(0.0, 320.0), Vector2(48.0, 260.0))

	# Outskirt defensive rock clusters
	_add_rock_cluster(container, Vector2(-320.0, -260.0), 40.0)
	_add_rock_cluster(container, Vector2(-320.0, 260.0), 40.0)
	_add_rock_cluster(container, Vector2(320.0, -260.0), 40.0)
	_add_rock_cluster(container, Vector2(320.0, 260.0), 40.0)


func _build_map_open_basin(container: Node2D) -> void:
	# Academic Feature: Open terrain demonstrating raw heuristic speedup (A*/Greedy prune into a narrow beam vs BFS expanding radial circles)
	_add_rock_cluster(container, Vector2(-240.0, -160.0), 42.0)
	_add_rock_cluster(container, Vector2(240.0, 160.0), 42.0)
	_add_rock_cluster(container, Vector2(-140.0, 220.0), 36.0)
	_add_rock_cluster(container, Vector2(140.0, -220.0), 36.0)
	_add_rock_cluster(container, Vector2(0.0, -150.0), 34.0)
	_add_rock_cluster(container, Vector2(0.0, 150.0), 34.0)


func _build_map_labyrinth(container: Node2D) -> void:
	# Academic Feature: Dense maze corridors demonstrating depth complexity, IDDFS bounded memory, and Bidirectional Search speedup
	_add_wall_box(container, Vector2(-240.0, -110.0), Vector2(40.0, 500.0)) # Left wall leaving south exit
	_add_wall_box(container, Vector2(240.0, 110.0), Vector2(40.0, 500.0)) # Right wall leaving north exit
	_add_wall_box(container, Vector2(0.0, -220.0), Vector2(280.0, 40.0)) # Center top baffle
	_add_wall_box(container, Vector2(0.0, 220.0), Vector2(280.0, 40.0)) # Center bottom baffle
	_add_wall_box(container, Vector2(0.0, 0.0), Vector2(48.0, 180.0)) # Center pillar

	_add_rock_cluster(container, Vector2(-380.0, 260.0), 36.0)
	_add_rock_cluster(container, Vector2(380.0, -260.0), 36.0)


func _add_wall_box(parent: Node2D, pos: Vector2, size: Vector2) -> void:
	var wall := CanyonWallScript.new()
	wall.position = pos
	wall.setup(size, Color(0.20, 0.17, 0.24))

	var rect := Rect2(pos - size * 0.5, size)
	if map_data:
		map_data.set_world_rect_blocked(rect, true, MapDataScript.CellType.WALL)

	parent.add_child(wall)


func _add_rock_cluster(parent: Node2D, center: Vector2, radius: float) -> void:
	var rock := AlienRockScript.new()
	rock.position = center
	rock.setup(radius)

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
			objective_beacon.set_deferred("monitoring", false)
			objective_beacon.set_deferred("monitorable", false)
	else:
		agent_a.scenario = "race"
		agent_b.scenario = "race"
		if objective_beacon:
			objective_beacon.visible = true
			objective_beacon.set_deferred("monitoring", true)
			objective_beacon.set_deferred("monitorable", true)
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
			_update_badges()
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
			_update_badges()
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
	# Map Preset Dropdown
	if map_dropdown:
		map_dropdown.clear()
		for i in range(MAP_PRESET_LABELS.size()):
			map_dropdown.add_item(MAP_PRESET_LABELS[i], i)
		map_dropdown.selected = MAP_PRESETS.find(current_map)
		map_dropdown.item_selected.connect(func(idx: int):
			change_map(MAP_PRESETS[idx])
		)

	if exit_button:
		exit_button.pressed.connect(_on_exit_pressed)

	if config_button:
		config_button.pressed.connect(func():
			if control_panel:
				control_panel.visible = not control_panel.visible
		)
	if close_config_btn:
		close_config_btn.pressed.connect(func():
			if control_panel:
				control_panel.visible = false
		)

	if cam_button:
		cam_button.pressed.connect(func():
			dynamic_camera_enabled = not dynamic_camera_enabled
			_update_cam_button_text()
		)
		_update_cam_button_text()

	if path_viz_button:
		path_viz_button.pressed.connect(toggle_path_visualizer)
		_update_path_viz_button_text()

	if inspector_button:
		inspector_button.pressed.connect(toggle_academic_inspector)
	if view_inspector_btn:
		view_inspector_btn.pressed.connect(open_academic_inspector)
	if close_inspector_btn:
		close_inspector_btn.pressed.connect(close_academic_inspector)
	if copy_defense_btn:
		copy_defense_btn.pressed.connect(copy_defense_summary)

	if results_panel:
		results_panel.visible = false
	if academic_inspector_modal:
		academic_inspector_modal.visible = false

	_update_badges()


func _update_cam_button_text() -> void:
	if cam_button:
		cam_button.text = "🎥 Cam: Dynamic" if dynamic_camera_enabled else "🎥 Cam: Overview"


func _update_path_viz_button_text() -> void:
	if path_viz_button:
		path_viz_button.text = "👁 Paths: ON" if show_ai_paths else "👁 Paths: OFF"
		path_viz_button.modulate = Color(1.0, 1.0, 1.0, 1.0) if show_ai_paths else Color(0.7, 0.7, 0.7, 0.8)


func _update_badges() -> void:
	if a_algo_badge:
		a_algo_badge.text = "[ %s ]" % agent_a_algorithm.to_upper()
	if b_algo_badge:
		b_algo_badge.text = "[ %s ]" % agent_b_algorithm.to_upper()
	if scenario_badge:
		scenario_badge.text = "[ %s ]" % current_scenario.to_upper()


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
	_update_camera(delta)

	if match_state == MatchState.RUNNING or show_ai_paths:
		queue_redraw()


func _update_camera(delta: float) -> void:
	if not camera:
		return

	if not dynamic_camera_enabled:
		camera.position = camera.position.lerp(Vector2.ZERO, delta * 4.0)
		camera.zoom = camera.zoom.lerp(Vector2(0.55, 0.55), delta * 4.0)
		return

	if is_instance_valid(agent_a) and is_instance_valid(agent_b):
		var pos_a := agent_a.global_position
		var pos_b := agent_b.global_position
		var target_pos := (pos_a + pos_b) * 0.5
		var dist := pos_a.distance_to(pos_b)

		# Scale zoom dynamically: close-up 1.35x when fighting, 0.70x when far apart
		var target_zoom_val := clampf(remap(dist, 160.0, 850.0, 1.35, 0.70), 0.70, 1.35)

		# Keep camera inside the arena bounds
		var max_extent := ARENA_SIZE.x * 0.32
		target_pos.x = clampf(target_pos.x, -max_extent, max_extent)
		target_pos.y = clampf(target_pos.y, -max_extent, max_extent)

		camera.position = camera.position.lerp(target_pos, delta * 3.5)
		camera.zoom = camera.zoom.lerp(Vector2(target_zoom_val, target_zoom_val), delta * 3.0)


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

	if control_panel:
		control_panel.visible = false

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
	_update_badges()
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
	if current_scenario != "race":
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

	var map_label_str: String = MAP_PRESET_LABELS[MAP_PRESETS.find(current_map)] if current_map in MAP_PRESETS else "Alien Proving Grounds"

	match_results = {
		"scenario": current_scenario,
		"scenario_label": SCENARIO_LABELS[SCENARIOS.find(current_scenario)],
		"map_preset": current_map,
		"map_name": map_label_str,
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

	# Refresh Academic Inspector if currently open
	if academic_inspector_modal and academic_inspector_modal.visible:
		open_academic_inspector()

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
		"Timestamp", "Scenario", "Map", "RandomSeed", "SwapSpawns", "DurationSeconds", "Outcome", "Winner",
		"AgentA_Algo", "AgentA_Requests", "AgentA_NodesExpanded", "AgentA_AlgoTimeMs", "AgentA_DistanceTraveled", "AgentA_RemainingHP", "AgentA_DamageDealt",
		"AgentB_Algo", "AgentB_Requests", "AgentB_NodesExpanded", "AgentB_AlgoTimeMs", "AgentB_DistanceTraveled", "AgentB_RemainingHP", "AgentB_DamageDealt"
	]

	var a_data: Dictionary = match_results.get("agent_a", {})
	var b_data: Dictionary = match_results.get("agent_b", {})

	var values := [
		str(match_results.get("timestamp", "")),
		str(match_results.get("scenario", "")),
		str(match_results.get("map_preset", current_map)),
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
	# 1. Base Alien Planetary Bedrock Ground (Deep alien slate with warm basalt undertones)
	var floor_rect := Rect2(ARENA_ORIGIN, ARENA_SIZE)
	draw_rect(floor_rect, Color(0.11, 0.09, 0.15, 1.0))

	# 2. Ambient Geological Craters & Contours
	var crater_centers: Array[Vector2] = [
		Vector2(-280.0, -80.0),
		Vector2(260.0, 110.0),
		Vector2(50.0, -320.0),
		Vector2(-70.0, 290.0)
	]
	var crater_radii: Array[float] = [75.0, 90.0, 60.0, 80.0]
	for i in range(crater_centers.size()):
		var c_pos: Vector2 = crater_centers[i]
		var c_rad: float = crater_radii[i]
		draw_circle(c_pos, c_rad, Color(0.08, 0.07, 0.12, 0.7))
		draw_arc(c_pos, c_rad, 0, TAU, 32, Color(0.18, 0.14, 0.24, 0.6), 2.0)
		draw_arc(c_pos, c_rad * 0.6, 0, TAU, 24, Color(0.06, 0.05, 0.09, 0.5), 1.5)

	# 3. Tactical Coordinate Grid (Subtle sci-fi overlay)
	var grid_color := Color(0.18, 0.24, 0.35, 0.20)
	var major_grid_color := Color(0.22, 0.38, 0.55, 0.35)
	for x in range(ARENA_GRID_SIZE.x + 1):
		var wx := ARENA_ORIGIN.x + float(x) * ARENA_CELL_SIZE
		var col_line := major_grid_color if (x % 5 == 0) else grid_color
		var width := 1.5 if (x % 5 == 0) else 1.0
		draw_line(Vector2(wx, ARENA_ORIGIN.y), Vector2(wx, ARENA_ORIGIN.y + ARENA_SIZE.y), col_line, width)
	for y in range(ARENA_GRID_SIZE.y + 1):
		var wy := ARENA_ORIGIN.y + float(y) * ARENA_CELL_SIZE
		var col_line := major_grid_color if (y % 5 == 0) else grid_color
		var width := 1.5 if (y % 5 == 0) else 1.0
		draw_line(Vector2(ARENA_ORIGIN.x, wy), Vector2(ARENA_ORIGIN.x + ARENA_SIZE.x, wy), col_line, width)

	# 4. Containment Perimeter Forcefield
	draw_rect(floor_rect, Color(0.12, 0.65, 0.95, 0.65), false, 3.0)
	draw_rect(floor_rect.grow(-4.0), Color(0.12, 0.88, 1.0, 0.2), false, 1.0)

	# Corner Forcefield Pylons & Containment Nodes
	var corner_offsets: Array[Vector2] = [
		ARENA_ORIGIN,
		Vector2(ARENA_ORIGIN.x + ARENA_SIZE.x, ARENA_ORIGIN.y),
		Vector2(ARENA_ORIGIN.x, ARENA_ORIGIN.y + ARENA_SIZE.y),
		ARENA_ORIGIN + ARENA_SIZE
	]
	for cp in corner_offsets:
		draw_circle(cp, 18.0, Color(0.10, 0.20, 0.30, 0.8))
		draw_circle(cp, 8.0, Color(0.12, 0.88, 1.0, 0.8))
		draw_arc(cp, 24.0, 0, TAU, 16, Color(0.2, 0.9, 1.0, 0.6), 1.5)

	# 5. Agent Landing / Spawn Platforms
	var pos_a := SPAWN_B_DEFAULT if swap_spawns else SPAWN_A_DEFAULT
	var pos_b := SPAWN_A_DEFAULT if swap_spawns else SPAWN_B_DEFAULT

	# Agent A Drop Zone (Cyan Vanguard Operative)
	draw_circle(pos_a, 48.0, Color(0.08, 0.16, 0.24, 0.85))
	draw_arc(pos_a, 48.0, 0, TAU, 32, Color(0.12, 0.88, 1.0, 0.8), 2.5)
	draw_arc(pos_a, 32.0, 0, TAU, 32, Color(0.12, 0.88, 1.0, 0.45), 1.5)
	draw_line(pos_a + Vector2(-48, 0), pos_a + Vector2(48, 0), Color(0.12, 0.88, 1.0, 0.35), 1.0)
	draw_line(pos_a + Vector2(0, -48), pos_a + Vector2(0, 48), Color(0.12, 0.88, 1.0, 0.35), 1.0)

	# Agent B Drop Zone (Amber Rival Operative)
	draw_circle(pos_b, 48.0, Color(0.24, 0.14, 0.08, 0.85))
	draw_arc(pos_b, 48.0, 0, TAU, 32, Color(1.0, 0.55, 0.15, 0.8), 2.5)
	draw_arc(pos_b, 32.0, 0, TAU, 32, Color(1.0, 0.55, 0.15, 0.45), 1.5)
	draw_line(pos_b + Vector2(-48, 0), pos_b + Vector2(48, 0), Color(1.0, 0.55, 0.15, 0.35), 1.0)
	draw_line(pos_b + Vector2(0, -48), pos_b + Vector2(0, 48), Color(1.0, 0.55, 0.15, 0.35), 1.0)

	# Central Tactical Ring / Dais
	if current_scenario == "combat":
		draw_arc(Vector2.ZERO, 72.0, 0, TAU, 48, Color(0.4, 0.5, 0.7, 0.3), 1.5)
		draw_arc(Vector2.ZERO, 160.0, 0, TAU, 64, Color(0.3, 0.4, 0.6, 0.18), 1.0)

	# 6. Live AI Path & Search Visualizer (Academic Demonstration)
	if show_ai_paths:
		_draw_agent_path_viz(agent_a, Color(0.12, 0.88, 1.0))
		_draw_agent_path_viz(agent_b, Color(1.0, 0.55, 0.15))

		# Targeting line in combat
		if current_scenario == "combat" and is_instance_valid(agent_a) and is_instance_valid(agent_b):
			if agent_a.get("current_state") != 4 and agent_b.get("current_state") != 4:
				if agent_a.has_method("has_line_of_sight_to") and agent_a.has_line_of_sight_to(agent_b.global_position):
					draw_dashed_line(agent_a.global_position, agent_b.global_position, Color(1.0, 0.3, 0.3, 0.3), 1.5, 10.0)


# ---------------------------------------------------------------------------
# Visualizer & Academic Inspector Controls
# ---------------------------------------------------------------------------
func toggle_path_visualizer() -> void:
	show_ai_paths = not show_ai_paths
	_update_path_viz_button_text()
	queue_redraw()


func _draw_agent_path_viz(agent: CharacterBody2D, color: Color) -> void:
	if not is_instance_valid(agent) or not agent.has_method("get_remaining_path_points"):
		return
	if agent.get("current_state") == 4: # AgentState.DEAD
		return

	var pts: PackedVector2Array = agent.call("get_remaining_path_points")
	if pts.size() < 2:
		return

	# Draw glowing route polyline
	var line_color := Color(color.r, color.g, color.b, 0.70)
	var glow_color := Color(color.r, color.g, color.b, 0.22)
	draw_polyline(pts, glow_color, 6.0)
	draw_polyline(pts, line_color, 2.5)

	# Draw pulsing waypoint nodes along the route
	var pulse := (sin(Time.get_ticks_msec() * 0.008) + 1.0) * 0.5 # 0.0 to 1.0
	for i in range(1, pts.size()):
		var pt := pts[i]
		var is_goal: bool = (i == pts.size() - 1)
		var rad := 6.0 if is_goal else 3.5
		draw_circle(pt, rad, color)
		if is_goal:
			draw_arc(pt, 10.0 + pulse * 4.0, 0, TAU, 24, Color(color.r, color.g, color.b, 0.85 - pulse * 0.5), 1.5)
		else:
			draw_arc(pt, rad + 2.0 + pulse * 2.0, 0, TAU, 16, Color(color.r, color.g, color.b, 0.45), 1.0)


func toggle_academic_inspector() -> void:
	if academic_inspector_modal:
		if academic_inspector_modal.visible:
			close_academic_inspector()
		else:
			open_academic_inspector()


func open_academic_inspector() -> void:
	if not academic_inspector_modal:
		return

	academic_inspector_modal.visible = true
	if copy_status_label:
		copy_status_label.text = ""

	var theory_a: Dictionary = ALGO_THEORY.get(agent_a_algorithm, {})
	var theory_b: Dictionary = ALGO_THEORY.get(agent_b_algorithm, {})
	var metrics_a: Dictionary = agent_a.call("get_metrics") if agent_a and agent_a.has_method("get_metrics") else {}
	var metrics_b: Dictionary = agent_b.call("get_metrics") if agent_b and agent_b.has_method("get_metrics") else {}

	var dist_a := float(metrics_a.get("total_distance_traveled", 0.0))
	var dist_b := float(metrics_b.get("total_distance_traveled", 0.0))
	var straight_dist := SPAWN_A_DEFAULT.distance_to(SPAWN_B_DEFAULT)
	var eff_a := (straight_dist / dist_a * 100.0) if dist_a > 10.0 else 100.0
	var eff_b := (straight_dist / dist_b * 100.0) if dist_b > 10.0 else 100.0

	if card_a_title:
		card_a_title.text = "AGENT A (CYAN) — %s" % str(theory_a.get("name", agent_a_algorithm.to_upper())).to_upper()
	if card_b_title:
		card_b_title.text = "AGENT B (AMBER) — %s" % str(theory_b.get("name", agent_b_algorithm.to_upper())).to_upper()

	if card_a_details:
		var text_a := "[b]Category:[/b] %s\n" % theory_a.get("category", "N/A")
		text_a += "[b]Evaluation:[/b] [color=#66ddff]%s[/color]\n" % theory_a.get("cost_function", "N/A")
		text_a += "[b]Admissibility:[/b] %s\n" % theory_a.get("admissibility", "N/A")
		text_a += "[b]Optimality:[/b] %s | [b]Complete:[/b] %s\n" % [theory_a.get("optimality", "N/A"), theory_a.get("completeness", "N/A")]
		text_a += "[b]Time Complexity:[/b] [color=#ffe066]%s[/color]\n" % theory_a.get("time_complexity", "N/A")
		text_a += "[b]Space Complexity:[/b] [color=#ffe066]%s[/color]\n" % theory_a.get("space_complexity", "N/A")
		text_a += "[color=#44ff88]──────────────────────────────────────[/color]\n"
		text_a += "[b]Nodes Expanded:[/b] %d nodes\n" % int(metrics_a.get("total_nodes_expanded", 0))
		text_a += "[b]Compute Time:[/b] %.1f ms (%d requests)\n" % [float(metrics_a.get("total_algo_time_ms", 0.0)), int(metrics_a.get("total_requests", 0))]
		text_a += "[b]Distance Traveled:[/b] %.1f px\n" % dist_a
		text_a += "[b]Path Efficiency:[/b] %.1f%% (Euclidean / Traveled)\n" % eff_a
		if current_scenario == "combat":
			text_a += "[b]Combat Status:[/b] %.0f HP | %d Damage Dealt" % [float(metrics_a.get("current_health", 0.0)), int(metrics_a.get("damage_dealt", 0))]
		else:
			text_a += "[b]Race Status:[/b] %s" % ("Claimed Beacon" if match_results.get("winner") == "Agent A" else "Active")
		card_a_details.text = text_a

	if card_b_details:
		var text_b := "[b]Category:[/b] %s\n" % theory_b.get("category", "N/A")
		text_b += "[b]Evaluation:[/b] [color=#ffbb66]%s[/color]\n" % theory_b.get("cost_function", "N/A")
		text_b += "[b]Admissibility:[/b] %s\n" % theory_b.get("admissibility", "N/A")
		text_b += "[b]Optimality:[/b] %s | [b]Complete:[/b] %s\n" % [theory_b.get("optimality", "N/A"), theory_b.get("completeness", "N/A")]
		text_b += "[b]Time Complexity:[/b] [color=#ffe066]%s[/color]\n" % theory_b.get("time_complexity", "N/A")
		text_b += "[b]Space Complexity:[/b] [color=#ffe066]%s[/color]\n" % theory_b.get("space_complexity", "N/A")
		text_b += "[color=#ff8844]──────────────────────────────────────[/color]\n"
		text_b += "[b]Nodes Expanded:[/b] %d nodes\n" % int(metrics_b.get("total_nodes_expanded", 0))
		text_b += "[b]Compute Time:[/b] %.1f ms (%d requests)\n" % [float(metrics_b.get("total_algo_time_ms", 0.0)), int(metrics_b.get("total_requests", 0))]
		text_b += "[b]Distance Traveled:[/b] %.1f px\n" % dist_b
		text_b += "[b]Path Efficiency:[/b] %.1f%% (Euclidean / Traveled)\n" % eff_b
		if current_scenario == "combat":
			text_b += "[b]Combat Status:[/b] %.0f HP | %d Damage Dealt" % [float(metrics_b.get("current_health", 0.0)), int(metrics_b.get("damage_dealt", 0))]
		else:
			text_b += "[b]Race Status:[/b] %s" % ("Claimed Beacon" if match_results.get("winner") == "Agent B" else "Active")
		card_b_details.text = text_b

	if academic_summary_label:
		academic_summary_label.text = generate_academic_defense_report()


func close_academic_inspector() -> void:
	if academic_inspector_modal:
		academic_inspector_modal.visible = false


func generate_academic_defense_report() -> String:
	var theory_a: Dictionary = ALGO_THEORY.get(agent_a_algorithm, {})
	var theory_b: Dictionary = ALGO_THEORY.get(agent_b_algorithm, {})
	var metrics_a: Dictionary = agent_a.call("get_metrics") if agent_a and agent_a.has_method("get_metrics") else {}
	var metrics_b: Dictionary = agent_b.call("get_metrics") if agent_b and agent_b.has_method("get_metrics") else {}

	var nodes_a := int(metrics_a.get("total_nodes_expanded", 0))
	var nodes_b := int(metrics_b.get("total_nodes_expanded", 0))
	var map_name_str: String = MAP_PRESET_LABELS[MAP_PRESETS.find(current_map)] if current_map in MAP_PRESETS else "Proving Grounds"

	var report := "[b]Experimental Context:[/b] Comparing [color=#22e0ff]%s[/color] vs [color=#ffaa22]%s[/color] on [color=#ffff77]%s[/color] under scenario: [color=#88ffaa]%s[/color].\n" % [theory_a.get("name", "Agent A"), theory_b.get("name", "Agent B"), map_name_str, current_scenario.to_upper()]

	if agent_a_algorithm == agent_b_algorithm:
		report += "• [b]Symmetric Baseline:[/b] Both agents utilized identical cost functions (%s). Variations stem solely from spawn positioning and dynamic tactical spacing.\n" % theory_a.get("cost_function", "")
	else:
		if nodes_a < nodes_b:
			report += "• [b]Frontier Efficiency:[/b] [color=#22e0ff]%s[/color] was more computationally selective, expanding [b]%d[/b] nodes vs [b]%d[/b] nodes for %s (%.1fx fewer expansions).\n" % [theory_a.get("name"), nodes_a, nodes_b, theory_b.get("name"), float(nodes_b) / float(maxi(1, nodes_a))]
		elif nodes_b < nodes_a:
			report += "• [b]Frontier Efficiency:[/b] [color=#ffaa22]%s[/color] was more computationally selective, expanding [b]%d[/b] nodes vs [b]%d[/b] nodes for %s (%.1fx fewer expansions).\n" % [theory_b.get("name"), nodes_b, nodes_a, theory_a.get("name"), float(nodes_a) / float(maxi(1, nodes_b))]
		else:
			report += "• [b]Frontier Parity:[/b] Both algorithms expanded an equivalent number of frontier nodes (%d vs %d).\n" % [nodes_a, nodes_b]

	match current_map:
		"chokepoints":
			report += "• [b]Concave Obstacle Impact:[/b] The U-shaped canyon traps demonstrated the theoretical divergence between pure heuristic search (Greedy f(n)=h(n)) and cost-aware search (A* f(n)=g(n)+h(n)). Greedy rushes directly into local minima because straight-line distance decreases, whereas A* evaluates path cost g(n) and routes around the barrier.\n"
		"labyrinth":
			report += "• [b]Corridor Depth Impact:[/b] In deep maze corridors, DFS-based approaches explore deeply along single branches (potentially straying far from target), whereas BFS and A* maintain level/cost guarantees. IDDFS achieves this optimality while bounding memory to O(bd).\n"
		"open_basin":
			report += "• [b]Open Terrain Pruning:[/b] Across open plains, informed heuristics (A*, Greedy) prune the search tree into a tight directional beam directly toward the target, contrasting with BFS which blindly expands radial circles across the entire grid.\n"
		_:
			report += "• [b]Proving Grounds Geometry:[/b] Symmetrical corridors tested pathfinding recovery under dynamic line-of-sight obstruction and evasive combat maneuvering.\n"

	report += "• [b]Theoretical Conclusion for Presentation:[/b] %s vs %s demonstrates the fundamental Artificial Intelligence trade-off between memory footprint (%s vs %s) and optimality guarantees." % [theory_a.get("name"), theory_b.get("name"), theory_a.get("space_complexity"), theory_b.get("space_complexity")]

	return report


func copy_defense_summary() -> void:
	var bb_text := generate_academic_defense_report()
	var regex := RegEx.new()
	regex.compile("\\[.*?\\]")
	var plain_text: String = regex.sub(bb_text, "", true)
	DisplayServer.clipboard_set(plain_text)
	if copy_status_label:
		copy_status_label.text = "✓ Copied to clipboard! Ready to paste into presentation or lab report."
