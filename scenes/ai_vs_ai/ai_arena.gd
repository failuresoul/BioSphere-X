class_name AIArena
extends Node2D
## AI vs AI Simulation Arena & Controller for BioSphere-X.
## Manages autonomous agents, match lifecycle, scenario rules (Pursuit & Combat, Race to Objective),
## independent algorithm selection, simulation speed, fair trial reproducibility, and experimental metrics export.

signal match_started()
signal match_paused(is_paused: bool)
signal match_finished(outcome: Dictionary)
signal match_reset()
signal batch_started(total_trials: int)
signal batch_trial_completed(trial_index: int, total_trials: int, trial_result: Dictionary)
signal batch_finished(summary: Dictionary)

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

const ROLES: Array[String] = [
	"adaptive",
	"assault",
	"sniper",
	"flanker"
]

const ROLE_LABELS: Array[String] = [
	"Adaptive Tactician (Dynamic Decision)",
	"Aggressive Assault (CQB Rapid Burst)",
	"Long-Range Marksman (Sniper Standoff)",
	"Evasive Skirmisher (Agile Flanker)"
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
@export var agent_a_role: String = "adaptive"
@export var agent_b_role: String = "flanker"
@export var swap_spawns: bool = false
@export var match_time_limit: float = 120.0
@export var simulation_speed: float = 1.0
@export var random_seed: int = 42
@export var dynamic_camera_enabled: bool = true
@export var show_ai_paths: bool = true

# Dynamic Battlefield Pickups
const PICKUP_REPAIR_POS := Vector2(0.0, -145.0)
const PICKUP_OVERCHARGE_POS := Vector2(0.0, 145.0)
const PICKUP_RADIUS := 28.0
var pickup_repair_active: bool = true
var pickup_repair_cooldown: float = 0.0
var pickup_overcharge_active: bool = true
var pickup_overcharge_cooldown: float = 0.0

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
# Live match event log (rolling last 5 events)
var _event_log: Array[String] = []
var _event_log_timer: float = 0.0

# Node References
var agent_a: CharacterBody2D = null
var agent_b: CharacterBody2D = null
var objective_beacon: Area2D = null

# UI References
@onready var scenario_dropdown: OptionButton = %ScenarioDropdown
@onready var map_dropdown: OptionButton = get_node_or_null("%MapDropdown")
@onready var algo_a_dropdown: OptionButton = %AlgoADropdown
@onready var algo_b_dropdown: OptionButton = %AlgoBDropdown
@onready var role_a_dropdown: OptionButton = get_node_or_null("%RoleADropdown")
@onready var role_b_dropdown: OptionButton = get_node_or_null("%RoleBDropdown")
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

# Batch Experiment System
var is_batch_running: bool = false
var batch_total_trials: int = 4
var batch_current_trial: int = 0
var batch_alternate_spawns: bool = true
var batch_pair_seeds: bool = true
var batch_base_seed: int = 42
var batch_seed_sequence: Array[int] = []
var batch_results_history: Array[Dictionary] = []
var batch_saved_simulation_speed: float = 1.0

# Batch Experiment UI Reference
@onready var batch_button: Button = get_node_or_null("%BatchButton")
var batch_experiment_modal: PanelContainer = null

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
@onready var a_role_label: Label = get_node_or_null("%A_RoleLabel")
@onready var a_nodes_label: Label = %A_NodesLabel
@onready var a_time_label: Label = %A_TimeLabel
@onready var b_hp_bar: ProgressBar = %B_HpBar
@onready var b_hp_label: Label = %B_HpLabel
@onready var b_role_label: Label = get_node_or_null("%B_RoleLabel")
@onready var b_nodes_label: Label = %B_NodesLabel
@onready var b_time_label: Label = %B_TimeLabel
@onready var event_log_label: Label = get_node_or_null("%EventLogLabel")


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
	agent_a.call("setup_agent", "Agent A", "team_a", Color(0.12, 0.88, 1.0), agent_a_algorithm, current_scenario, agent_a_role)
	agent_a.global_position = pos_a
	agent_a.call("set_map_data", map_data)
	agent_a.call("set_arena_ref", self)
	agent_a.connect("agent_died", _on_agent_died)

	agent_b = _agent_scene.instantiate()
	agent_b.name = "AgentB"
	add_child(agent_b)
	agent_b.call("setup_agent", "Agent B", "team_b", Color(1.0, 0.55, 0.15), agent_b_algorithm, current_scenario, agent_b_role)
	agent_b.global_position = pos_b
	agent_b.call("set_map_data", map_data)
	agent_b.call("set_arena_ref", self)
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

	# Tactical Role Dropdowns
	if role_a_dropdown:
		role_a_dropdown.clear()
		for i in range(ROLE_LABELS.size()):
			role_a_dropdown.add_item(ROLE_LABELS[i], i)
		role_a_dropdown.selected = max(0, ROLES.find(agent_a_role))
		role_a_dropdown.item_selected.connect(func(idx: int):
			agent_a_role = ROLES[idx]
			if agent_a and agent_a.has_method("set_tactical_role"):
				agent_a.call("set_tactical_role", agent_a_role)
			_update_telemetry()
		)

	if role_b_dropdown:
		role_b_dropdown.clear()
		for i in range(ROLE_LABELS.size()):
			role_b_dropdown.add_item(ROLE_LABELS[i], i)
		role_b_dropdown.selected = max(0, ROLES.find(agent_b_role))
		role_b_dropdown.item_selected.connect(func(idx: int):
			agent_b_role = ROLES[idx]
			if agent_b and agent_b.has_method("set_tactical_role"):
				agent_b.call("set_tactical_role", agent_b_role)
			_update_telemetry()
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

	# Batch Experiment Modal Initialisation
	if not batch_experiment_modal:
		var modal_script = load("res://ui/components/batch_experiment_modal.gd")
		if modal_script:
			batch_experiment_modal = modal_script.new()
			var ui_layer = get_node_or_null("UI")
			if ui_layer:
				ui_layer.add_child(batch_experiment_modal)
				batch_experiment_modal.setup(self)

	if batch_button:
		batch_button.pressed.connect(toggle_batch_modal)

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
			var m: int = int(match_elapsed_time) / 60
			var s: float = fmod(match_elapsed_time, 60.0)
			var total_m: int = int(match_time_limit) / 60
			timer_label.text = "⏱ %02d:%04.1f / %02d:00" % [m, s, total_m]

		if match_elapsed_time >= match_time_limit:
			_terminate_match("Time Limit Exceeded (Draw)")

		_update_arena_pickups(delta)

	_update_telemetry()
	_update_camera(delta)

	if match_state == MatchState.RUNNING or show_ai_paths:
		queue_redraw()


# ---------------------------------------------------------------------------
# Live Event Log (Match Commentary)
# ---------------------------------------------------------------------------
func _push_event(msg: String) -> void:
	_event_log.append(msg)
	if _event_log.size() > 4:
		_event_log.pop_front()
	if event_log_label:
		event_log_label.text = "\n".join(_event_log)



func _update_arena_pickups(delta: float) -> void:
	# Nanite Repair Core cooldown
	if not pickup_repair_active:
		pickup_repair_cooldown = maxf(0.0, pickup_repair_cooldown - delta)
		if pickup_repair_cooldown <= 0.0:
			pickup_repair_active = true
	else:
		_check_pickup_collection(PICKUP_REPAIR_POS, "repair")

	# Plasma Overcharge Cell cooldown
	if not pickup_overcharge_active:
		pickup_overcharge_cooldown = maxf(0.0, pickup_overcharge_cooldown - delta)
		if pickup_overcharge_cooldown <= 0.0:
			pickup_overcharge_active = true
	else:
		_check_pickup_collection(PICKUP_OVERCHARGE_POS, "overcharge")


func _check_pickup_collection(pos: Vector2, type: String) -> void:
	var agents := [agent_a, agent_b]
	for ag in agents:
		if is_instance_valid(ag) and ag.get("current_state") != AutonomousAgentScript.AgentState.DEAD:
			if ag.global_position.distance_to(pos) <= PICKUP_RADIUS:
				var ag_name: String = str(ag.get("agent_name"))
				if type == "repair":
					pickup_repair_active = false
					pickup_repair_cooldown = 15.0
					if ag.has_method("heal"):
						ag.call("heal", 35.0)
					_push_event("💊 %s collected Nanite Repair Core (+35 HP)" % ag_name)
				elif type == "overcharge":
					pickup_overcharge_active = false
					pickup_overcharge_cooldown = 18.0
					if ag.has_method("apply_overcharge_boost"):
						ag.call("apply_overcharge_boost", 8.0)
					_push_event("⚡ %s OVERCHARGED! (+35%% speed & fire rate)" % ag_name)
				break


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
			a_hp_bar.value = lerpf(a_hp_bar.value, cur_a, 0.35) if absf(a_hp_bar.value - cur_a) > 0.1 else cur_a
		if a_hp_label:
			a_hp_label.text = "%d HP" % int(cur_a)
		if a_role_label:
			var r_a: String = String(agent_a.get("tactical_role")).capitalize()
			var t_a: String = String(agent_a.get("current_tactic_status"))
			var over_a: bool = bool(agent_a.get("_overcharge_timer") > 0.0)
			var seeking_a: String = String(agent_a.get("_seeking_pickup"))
			if over_a:
				a_role_label.text = "[ %s | ⚡ OVERCHARGED ]" % r_a
				a_role_label.modulate = Color(1.0, 0.85, 0.2)
			elif seeking_a == "repair":
				a_role_label.text = "[ %s | 💊 SEEKING REPAIR ]" % r_a
				a_role_label.modulate = Color(0.25, 1.0, 0.5)
			elif seeking_a == "overcharge":
				a_role_label.text = "[ %s | ⚡ SEEKING OVERCHARGE ]" % r_a
				a_role_label.modulate = Color(1.0, 0.95, 0.35)
			else:
				a_role_label.text = "[ %s | %s ]" % [r_a, t_a]
				a_role_label.modulate = Color(0.3, 0.9, 1.0)
		if a_nodes_label:
			a_nodes_label.text = "Nodes: %d" % int(agent_a.get("total_nodes_expanded"))
		if a_time_label:
			var t_ms: float = float(agent_a.get("total_algo_time_ms"))
			a_time_label.text = "⚡ %.1fms" % t_ms

	if agent_b and agent_b.get("health_component"):
		var cur_b: float = float(agent_b.health_component.current_health)
		var max_b: float = float(agent_b.health_component.max_health)
		if b_hp_bar:
			b_hp_bar.max_value = max_b
			b_hp_bar.value = lerpf(b_hp_bar.value, cur_b, 0.35) if absf(b_hp_bar.value - cur_b) > 0.1 else cur_b
		if b_hp_label:
			b_hp_label.text = "%d HP" % int(cur_b)
		if b_role_label:
			var r_b: String = String(agent_b.get("tactical_role")).capitalize()
			var t_b: String = String(agent_b.get("current_tactic_status"))
			var over_b: bool = bool(agent_b.get("_overcharge_timer") > 0.0)
			var seeking_b: String = String(agent_b.get("_seeking_pickup"))
			if over_b:
				b_role_label.text = "[ %s | ⚡ OVERCHARGED ]" % r_b
				b_role_label.modulate = Color(1.0, 0.85, 0.2)
			elif seeking_b == "repair":
				b_role_label.text = "[ %s | 💊 SEEKING REPAIR ]" % r_b
				b_role_label.modulate = Color(0.25, 1.0, 0.5)
			elif seeking_b == "overcharge":
				b_role_label.text = "[ %s | ⚡ SEEKING OVERCHARGE ]" % r_b
				b_role_label.modulate = Color(1.0, 0.95, 0.35)
			else:
				b_role_label.text = "[ %s | %s ]" % [r_b, t_b]
				b_role_label.modulate = Color(1.0, 0.75, 0.3)
		if b_nodes_label:
			b_nodes_label.text = "Nodes: %d" % int(agent_b.get("total_nodes_expanded"))
		if b_time_label:
			var t_ms: float = float(agent_b.get("total_algo_time_ms"))
			b_time_label.text = "⚡ %.1fms" % t_ms


# ---------------------------------------------------------------------------
# Simulation Lifecycle Controls
# ---------------------------------------------------------------------------
func start_match() -> void:
	if match_state == MatchState.RUNNING:
		return

	if match_state == MatchState.FINISHED:
		reset_match()

	seed(random_seed)
	match_state = MatchState.RUNNING
	_set_agents_active(true)
	_push_event("🟢 MATCH STARTED — %s vs %s" % [agent_a_algorithm.to_upper(), agent_b_algorithm.to_upper()])

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
	seed(random_seed)

	var pos_a := SPAWN_B_DEFAULT if swap_spawns else SPAWN_A_DEFAULT
	var pos_b := SPAWN_A_DEFAULT if swap_spawns else SPAWN_B_DEFAULT

	pickup_repair_active = true
	pickup_repair_cooldown = 0.0
	pickup_overcharge_active = true
	pickup_overcharge_cooldown = 0.0

	if agent_a:
		agent_a.reset_agent(pos_a)
		agent_a.setup_agent("Agent A", "team_a", Color(0.12, 0.88, 1.0), agent_a_algorithm, current_scenario, agent_a_role)
		agent_a.call("set_arena_ref", self)
	if agent_b:
		agent_b.reset_agent(pos_b)
		agent_b.setup_agent("Agent B", "team_b", Color(1.0, 0.55, 0.15), agent_b_algorithm, current_scenario, agent_b_role)
		agent_b.call("set_arena_ref", self)

	_configure_scenario_targets()
	_set_agents_active(false)

	if timer_label:
		var total_m: int = int(match_time_limit) / 60
		var total_s: float = fmod(match_time_limit, 60.0)
		timer_label.text = "⏱ 00:00.0 / %02d:%04.1f" % [total_m, total_s]
	if match_status_label:
		match_status_label.text = "STATUS: READY"
		match_status_label.modulate = Color(0.7, 0.8, 1.0)
	if pause_button:
		pause_button.text = "Pause"
	if results_panel:
		results_panel.visible = false
	if export_status_label:
		export_status_label.text = ""
	_event_log.clear()
	_push_event("🚀 Match Ready — Agents deployed to spawn positions")

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

	_push_event("🏆 MATCH OVER — %s" % outcome_str)

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

	if is_batch_running:
		batch_results_history.append(match_results.duplicate(true))
		batch_trial_completed.emit(batch_current_trial, batch_total_trials, match_results)
		batch_current_trial += 1
		if batch_current_trial < batch_total_trials:
			get_tree().create_timer(0.25).timeout.connect(_run_next_batch_trial)
		else:
			_finish_batch_experiment()


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

	# 7. Dynamic Battlefield Pickup Stations
	_draw_arena_pickups()


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


func _draw_arena_pickups() -> void:
	var time_ms := Time.get_ticks_msec()
	var pulse := 1.0 + 0.12 * sin(time_ms * 0.006)

	# 1. Dynamic Pickup: Nanite Repair Core (+35 HP)
	var rep_color := Color(0.15, 0.95, 0.45) if pickup_repair_active else Color(0.25, 0.35, 0.3, 0.4)
	draw_arc(PICKUP_REPAIR_POS, 24.0, 0.0, TAU, 28, rep_color.lerp(Color.BLACK, 0.45), 3.0)
	draw_circle(PICKUP_REPAIR_POS, 20.0, Color(0.04, 0.12, 0.08, 0.65 if pickup_repair_active else 0.2))

	if pickup_repair_active:
		draw_arc(PICKUP_REPAIR_POS, 24.0 * pulse, 0.0, TAU, 32, rep_color, 2.0)
		var cw := 4.5
		var cl := 14.0
		draw_rect(Rect2(PICKUP_REPAIR_POS.x - cw * 0.5, PICKUP_REPAIR_POS.y - cl * 0.5, cw, cl), rep_color)
		draw_rect(Rect2(PICKUP_REPAIR_POS.x - cl * 0.5, PICKUP_REPAIR_POS.y - cw * 0.5, cl, cw), rep_color)
	else:
		var pct := 1.0 - (pickup_repair_cooldown / 15.0)
		draw_arc(PICKUP_REPAIR_POS, 24.0, -PI * 0.5, -PI * 0.5 + TAU * pct, 28, Color(0.2, 0.85, 0.4, 0.75), 2.5)

	# 2. Dynamic Pickup: Plasma Overcharge Cell (+35% Speed & Fire-rate)
	var ovr_color := Color(1.0, 0.75, 0.15) if pickup_overcharge_active else Color(0.35, 0.3, 0.2, 0.4)
	draw_arc(PICKUP_OVERCHARGE_POS, 24.0, 0.0, TAU, 28, ovr_color.lerp(Color.BLACK, 0.45), 3.0)
	draw_circle(PICKUP_OVERCHARGE_POS, 20.0, Color(0.18, 0.10, 0.03, 0.65 if pickup_overcharge_active else 0.2))

	if pickup_overcharge_active:
		draw_arc(PICKUP_OVERCHARGE_POS, 24.0 * pulse, 0.0, TAU, 32, ovr_color, 2.0)
		var pts := PackedVector2Array([
			PICKUP_OVERCHARGE_POS + Vector2(-2, -9),
			PICKUP_OVERCHARGE_POS + Vector2(5, -2),
			PICKUP_OVERCHARGE_POS + Vector2(1, -2),
			PICKUP_OVERCHARGE_POS + Vector2(3, 9),
			PICKUP_OVERCHARGE_POS + Vector2(-5, 1),
			PICKUP_OVERCHARGE_POS + Vector2(-1, 1)
		])
		draw_colored_polygon(pts, ovr_color)
	else:
		var pct := 1.0 - (pickup_overcharge_cooldown / 18.0)
		draw_arc(PICKUP_OVERCHARGE_POS, 24.0, -PI * 0.5, -PI * 0.5 + TAU * pct, 28, Color(1.0, 0.75, 0.2, 0.75), 2.5)


# ---------------------------------------------------------------------------
# Repeatable Batch Experiments Controller API
# ---------------------------------------------------------------------------
func toggle_batch_modal() -> void:
	if not batch_experiment_modal:
		return
	if batch_experiment_modal.visible:
		batch_experiment_modal.close_modal()
	else:
		batch_experiment_modal.open_modal()


func open_batch_modal() -> void:
	if batch_experiment_modal:
		batch_experiment_modal.open_modal()


func close_batch_modal() -> void:
	if batch_experiment_modal:
		batch_experiment_modal.close_modal()


func start_batch_experiment(num_trials: int = 4, alternate_spawns: bool = true, base_seed: int = 42, pair_seeds: bool = true, fast_speed: bool = true) -> void:
	batch_total_trials = maxi(2, num_trials)
	batch_alternate_spawns = alternate_spawns
	batch_pair_seeds = pair_seeds
	batch_base_seed = base_seed
	batch_results_history.clear()
	batch_seed_sequence.clear()

	# Build deterministic recorded seed sequence
	for i in range(batch_total_trials):
		if pair_seeds and alternate_spawns:
			# Every pair shares the identical seed across inverted starting positions
			var pair_idx: int = i / 2
			batch_seed_sequence.append(base_seed + pair_idx * 17)
		else:
			batch_seed_sequence.append(base_seed + i * 13)

	is_batch_running = true
	batch_current_trial = 0
	batch_saved_simulation_speed = simulation_speed

	if fast_speed:
		_apply_simulation_speed(4.0)

	batch_started.emit(batch_total_trials)
	_push_event("🧪 STARTING BATCH EXPERIMENT — %d Trials | Map: %s | Base Seed: %d" % [
		batch_total_trials, current_map.capitalize(), base_seed
	])

	_run_next_batch_trial()


func _run_next_batch_trial() -> void:
	if not is_batch_running:
		return

	if batch_current_trial >= batch_total_trials:
		_finish_batch_experiment()
		return

	random_seed = batch_seed_sequence[batch_current_trial]
	if batch_alternate_spawns:
		swap_spawns = (batch_current_trial % 2 == 1)
	else:
		swap_spawns = false

	if seed_spin:
		seed_spin.value = float(random_seed)
	if swap_button:
		swap_button.button_pressed = swap_spawns

	_push_event("▶ Trial %d/%d — Seed: %d | Spawns: %s" % [
		batch_current_trial + 1,
		batch_total_trials,
		random_seed,
		"A=Right, B=Left" if swap_spawns else "A=Left, B=Right"
	])

	reset_match()
	start_match()


func stop_batch_experiment() -> void:
	is_batch_running = false
	_apply_simulation_speed(batch_saved_simulation_speed)
	pause_match()
	_push_event("⏹ Batch experiment stopped by user.")


func _finish_batch_experiment() -> void:
	is_batch_running = false
	_apply_simulation_speed(batch_saved_simulation_speed)
	var summary := get_batch_summary()
	batch_finished.emit(summary)
	_push_event("🏆 BATCH COMPLETED — %d Trials | A Wins: %d (%.1f%%) | B Wins: %d (%.1f%%)" % [
		batch_total_trials,
		int(summary.get("agent_a_wins", 0)),
		float(summary.get("agent_a_winrate", 0.0)),
		int(summary.get("agent_b_wins", 0)),
		float(summary.get("agent_b_winrate", 0.0))
	])


func get_batch_summary() -> Dictionary:
	if batch_results_history.is_empty():
		return {}

	var total: int = batch_results_history.size()
	var a_wins: int = 0
	var b_wins: int = 0
	var draws: int = 0
	var left_spawn_wins: int = 0
	var right_spawn_wins: int = 0
	var total_dur: float = 0.0
	var total_nodes_a: int = 0
	var total_nodes_b: int = 0
	var total_dist_a: float = 0.0
	var total_dist_b: float = 0.0

	for r in batch_results_history:
		var w: String = r.get("winner", "")
		var swapped: bool = r.get("swap_spawns", false)

		if w == "Agent A":
			a_wins += 1
			if not swapped: left_spawn_wins += 1
			else: right_spawn_wins += 1
		elif w == "Agent B":
			b_wins += 1
			if not swapped: right_spawn_wins += 1
			else: left_spawn_wins += 1
		else:
			draws += 1

		total_dur += float(r.get("match_duration_seconds", 0.0))
		var a_metrics: Dictionary = r.get("agent_a", {})
		var b_metrics: Dictionary = r.get("agent_b", {})
		total_nodes_a += int(a_metrics.get("total_nodes_expanded", 0))
		total_nodes_b += int(b_metrics.get("total_nodes_expanded", 0))
		total_dist_a += float(a_metrics.get("total_distance_traveled", 0.0))
		total_dist_b += float(b_metrics.get("total_distance_traveled", 0.0))

	var decided: int = maxi(1, a_wins + b_wins)
	var left_pct: float = (float(left_spawn_wins) / float(decided)) * 100.0
	var right_pct: float = (float(right_spawn_wins) / float(decided)) * 100.0

	return {
		"total_trials": total,
		"agent_a_wins": a_wins,
		"agent_b_wins": b_wins,
		"draws": draws,
		"agent_a_winrate": (float(a_wins) / float(total)) * 100.0,
		"agent_b_winrate": (float(b_wins) / float(total)) * 100.0,
		"draw_rate": (float(draws) / float(total)) * 100.0,
		"left_spawn_wins": left_spawn_wins,
		"right_spawn_wins": right_spawn_wins,
		"left_spawn_pct": left_pct,
		"right_spawn_pct": right_pct,
		"spawn_bias_delta": left_pct - right_pct,
		"avg_duration": total_dur / float(total),
		"avg_nodes_a": float(total_nodes_a) / float(total),
		"avg_nodes_b": float(total_nodes_b) / float(total),
		"avg_dist_a": total_dist_a / float(total),
		"avg_dist_b": total_dist_b / float(total),
		"map": current_map,
		"scenario": current_scenario,
		"algorithm_a": agent_a_algorithm,
		"algorithm_b": agent_b_algorithm,
		"trials": batch_results_history
	}


func export_batch_json() -> String:
	var summary := get_batch_summary()
	if summary.is_empty():
		return ""
	var json_str := JSON.stringify(summary, "\t")
	var dir_path := "user://experiments"
	DirAccess.make_dir_absolute(dir_path)
	var timestamp := Time.get_datetime_string_from_system().replace(":", "-")
	var file_path := "%s/batch_%s_%s_%s.json" % [dir_path, current_map, current_scenario, timestamp]
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(json_str)
		file.close()
		var msg := "Saved Batch JSON: %s" % ProjectSettings.globalize_path(file_path)
		print(msg)
		return file_path
	return ""


func export_batch_csv() -> String:
	if batch_results_history.is_empty():
		return ""
	var dir_path := "user://experiments"
	DirAccess.make_dir_absolute(dir_path)
	var timestamp := Time.get_datetime_string_from_system().replace(":", "-")
	var file_path := "%s/batch_%s_%s_%s.csv" % [dir_path, current_map, current_scenario, timestamp]
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		return ""

	var headers := [
		"Trial", "Seed", "Map", "Scenario", "SpawnsSwapped", "Winner", "DurationSeconds", "OutcomeReason",
		"AgentA_Algo", "AgentA_Nodes", "AgentA_Dist", "AgentA_HP", "AgentA_Dmg",
		"AgentB_Algo", "AgentB_Nodes", "AgentB_Dist", "AgentB_HP", "AgentB_Dmg"
	]
	file.store_line(",".join(headers))

	for i in batch_results_history.size():
		var r: Dictionary = batch_results_history[i]
		var a_d: Dictionary = r.get("agent_a", {})
		var b_d: Dictionary = r.get("agent_b", {})
		var row := [
			str(i + 1),
			str(r.get("random_seed", 0)),
			str(r.get("map_preset", current_map)),
			str(r.get("scenario", current_scenario)),
			str(r.get("swap_spawns", false)),
			str(r.get("winner", "")),
			str(r.get("match_duration_seconds", 0.0)),
			"\"" + str(r.get("outcome", "")).replace("\"", "'") + "\"",
			str(a_d.get("algorithm", "")),
			str(a_d.get("total_nodes_expanded", 0)),
			str(a_d.get("total_distance_traveled", 0.0)),
			str(a_d.get("remaining_health", 0.0)),
			str(a_d.get("damage_dealt", 0.0)),
			str(b_d.get("algorithm", "")),
			str(b_d.get("total_nodes_expanded", 0)),
			str(b_d.get("total_distance_traveled", 0.0)),
			str(b_d.get("remaining_health", 0.0)),
			str(b_d.get("damage_dealt", 0.0))
		]
		file.store_line(",".join(row))

	file.close()
	var msg := "Saved Batch CSV: %s" % ProjectSettings.globalize_path(file_path)
	print(msg)
	return file_path
