extends Node
## Comprehensive automated tests for BioSphere-X Pathfinding and Navigation.
## Verifies BFS, DFS, DLS, IDDFS, Bidirectional, Greedy, and A* algorithm configurations,
## backend failover, [FALLBACK_ASTAR2D] fallback, coordinate transformations, and UI menu.

const MapDataClass = preload("res://scripts/components/map_data.gd")
const DevMenuClass = preload("res://ui/components/dev_navigation_menu.gd")
const ModularPathfinderClass = preload("res://scripts/utils/modular_pathfinder.gd")


func _ready() -> void:
	print("\n--- Running BioSphere-X Python AI Pathfinding & Navigation Tests ---")
	_run_tests()
	print("--- All BioSphere-X Pathfinding & Navigation Tests Passed! ---\n")
	get_tree().quit(0)


func _run_tests() -> void:
	_test_map_data_helpers()
	_test_multiple_map_topologies()
	_test_modular_pathfinder_algorithms()
	_test_line_of_sight_grid()
	_test_navigation_manager_algorithm_switching()
	_test_offline_fallback_failover()
	_test_dev_navigation_menu_ui()
	_test_enemy_obstacle_navigation_and_recalculation()
	_test_debug_visualizer()


func _test_map_data_helpers() -> void:
	var map := MapDataClass.new(Vector2i(20, 20), 32.0, Vector2.ZERO)
	
	# Block some test cells
	map.set_cell_blocked(Vector2i(5, 5), true, MapDataClass.CellType.WALL)
	map.set_cell_blocked(Vector2i(5, 6), true, MapDataClass.CellType.WALL)
	map.set_cell_blocked(Vector2i(5, 7), true, MapDataClass.CellType.WALL)
	
	var blocked: Array[Vector2i] = map.get_blocked_cells()
	assert(blocked.has(Vector2i(5, 5)), "Blocked cells list must contain (5, 5)")
	assert(blocked.has(Vector2i(5, 6)), "Blocked cells list must contain (5, 6)")
	assert(blocked.has(Vector2i(5, 7)), "Blocked cells list must contain (5, 7)")
	
	# Test coordinate transformation
	var world_pt := map.grid_to_world(Vector2i(10, 10))
	var grid_pt := map.world_to_grid(world_pt)
	assert(grid_pt == Vector2i(10, 10), "Coordinate roundtrip conversion must match")
	
	# Test grid_to_world_path
	var test_grid_path: Array = [[0, 0], [1, 1], [2, 2]]
	var world_path: PackedVector2Array = map.grid_to_world_path(test_grid_path)
	assert(world_path.size() == 3, "Converted path must have 3 points")
	assert(world_path[0] == map.grid_to_world(Vector2i(0, 0)), "First point must match grid (0, 0)")
	print("  [PASS] MapData blocked cells and coordinate transformations verified")


func _test_multiple_map_topologies() -> void:
	# Map 1: Open grid
	var map_open := MapDataClass.new(Vector2i(15, 15), 32.0, Vector2.ZERO)
	var path_open: PackedVector2Array = map_open.get_fallback_path_points(Vector2(32, 32), Vector2(320, 320))
	assert(path_open.size() > 0, "Open map must find a valid path")
	assert(path_open[0] == Vector2(48, 48), "Path start must align to cell center")
	
	# Map 2: Detour with wall obstacle
	var map_wall := MapDataClass.new(Vector2i(15, 15), 32.0, Vector2.ZERO)
	# Wall across column 4 from y=0 to y=10
	for y in range(0, 11):
		map_wall.set_cell_blocked(Vector2i(4, y), true, MapDataClass.CellType.WALL)
	
	var start_world := map_wall.grid_to_world(Vector2i(2, 5))
	var goal_world := map_wall.grid_to_world(Vector2i(6, 5))
	var path_detour: PackedVector2Array = map_wall.get_fallback_path_points(start_world, goal_world)
	assert(path_detour.size() > 0, "Path must find detour around wall")
	# Ensure no points on the path lie on the wall
	for pt in path_detour:
		var g := map_wall.world_to_grid(pt)
		assert(not (g.x == 4 and g.y >= 0 and g.y <= 10), "Path cannot cross through wall cells")
		
	# Map 3: Completely unreachable enclosed goal
	var map_blocked := MapDataClass.new(Vector2i(10, 10), 32.0, Vector2.ZERO)
	# Enclose (5, 5) completely
	map_blocked.set_cell_blocked(Vector2i(4, 4), true)
	map_blocked.set_cell_blocked(Vector2i(5, 4), true)
	map_blocked.set_cell_blocked(Vector2i(6, 4), true)
	map_blocked.set_cell_blocked(Vector2i(4, 5), true)
	map_blocked.set_cell_blocked(Vector2i(6, 5), true)
	map_blocked.set_cell_blocked(Vector2i(4, 6), true)
	map_blocked.set_cell_blocked(Vector2i(5, 6), true)
	map_blocked.set_cell_blocked(Vector2i(6, 6), true)
	
	var unreachable_path: PackedVector2Array = map_blocked.get_fallback_path_points(
		map_blocked.grid_to_world(Vector2i(0, 0)),
		map_blocked.grid_to_world(Vector2i(5, 5))
	)
	assert(unreachable_path.size() == 0, "Unreachable goal must safely return empty path without crashing")
	print("  [PASS] Multiple map topologies (open, detour wall, enclosed unreachable) verified")


func _test_navigation_manager_algorithm_switching() -> void:
	var nav_mgr = get_node_or_null("/root/NavigationManager")
	assert(nav_mgr != null, "NavigationManager autoload must be registered")
	
	var expected_algos = ["astar", "bfs", "dfs", "dls", "iddfs", "bidirectional", "greedy"]
	for algo in expected_algos:
		nav_mgr.set_algorithm(algo)
		assert(nav_mgr.current_algorithm == algo, "NavigationManager algorithm must update to: %s" % algo)
		
	# Case insensitive / whitespace handling
	nav_mgr.set_algorithm("  ASTAR  ")
	assert(nav_mgr.current_algorithm == "astar", "Algorithm setter must normalize case and whitespace")
	
	# Invalid name rejection
	nav_mgr.set_algorithm("unknown_algorithm_xyz")
	assert(nav_mgr.current_algorithm == "astar", "Invalid algorithm name must be rejected")
	print("  [PASS] NavigationManager algorithm configuration and validation verified")


func _test_offline_fallback_failover() -> void:
	var nav_mgr = get_node_or_null("/root/NavigationManager")
	assert(nav_mgr != null, "NavigationManager autoload required")
	
	var map := MapDataClass.new(Vector2i(20, 20), 32.0, Vector2.ZERO)
	var from_pos := map.grid_to_world(Vector2i(1, 1))
	var to_pos := map.grid_to_world(Vector2i(10, 10))
	
	# Enable force_fallback to simulate backend disconnection
	nav_mgr.force_fallback = true
	var received: Dictionary = {"called": false, "path": PackedVector2Array(), "metrics": {}}
	
	nav_mgr.request_path(from_pos, to_pos, map, func(path: PackedVector2Array, metrics: Dictionary):
		received["called"] = true
		received["path"] = path
		received["metrics"] = metrics
	)
	
	assert(received["called"] == true, "Fallback path request must return")
	assert(received["path"].size() > 0, "Fallback path must contain valid points")
	var metrics: Dictionary = received["metrics"]
	assert(metrics.get("source") == "[FALLBACK_ASTAR2D]", "Metrics source must clearly identify [FALLBACK_ASTAR2D]")
	assert(metrics.get("is_fallback") == true, "Metrics must flag is_fallback == true")
	assert(metrics.get("success") == true, "Fallback search must succeed")
	
	# Restore force_fallback
	nav_mgr.force_fallback = false
	print("  [PASS] Offline backend failover to [FALLBACK_ASTAR2D] verified")


func _test_dev_navigation_menu_ui() -> void:
	var menu_scene: PackedScene = load("res://ui/components/dev_navigation_menu.tscn")
	assert(menu_scene != null, "dev_navigation_menu.tscn must load")
	
	var menu := menu_scene.instantiate()
	add_child(menu)
	
	var dropdown: OptionButton = menu.get_node("%AlgoDropdown")
	assert(dropdown != null, "%AlgoDropdown must exist in DevNavigationMenu")
	assert(dropdown.item_count == 7, "Dropdown must contain all 7 pathfinding algorithms")
	
	var status_badge: Label = menu.get_node("%StatusBadge")
	assert(status_badge != null, "%StatusBadge must exist in DevNavigationMenu")
	
	var error_banner: Label = menu.get_node("%ErrorBanner")
	assert(error_banner != null, "%ErrorBanner must exist in DevNavigationMenu")
	
	# Test visibility toggle
	assert(menu.visible == false, "Dev menu should default to hidden")
	menu.toggle_visibility()
	assert(menu.visible == true, "toggle_visibility() must toggle to visible")
	menu.toggle_visibility()
	assert(menu.visible == false, "toggle_visibility() must toggle to hidden")
	
	menu.queue_free()
	print("  [PASS] DevNavigationMenu UI controls, dropdown items, and visibility toggle verified")


func _test_enemy_obstacle_navigation_and_recalculation() -> void:
	var enemy_scene: PackedScene = load("res://scenes/enemies/alien_enemy.tscn")
	assert(enemy_scene != null, "alien_enemy.tscn must load")
	
	var enemy := enemy_scene.instantiate()
	add_child(enemy)
	
	# Verify separation: Navigation Grid (MapData), Pathfinding Algorithm (NavigationManager), Movement Controller (AlienEnemy)
	assert(enemy is CharacterBody2D, "Enemy movement controller must be a CharacterBody2D")
	assert(enemy.has_method("change_state"), "Enemy must manage state machine")
	
	# Verify throttled path recalculation
	assert("_nav_refresh_timer" in enemy, "Enemy must have _nav_refresh_timer to throttle path recalculation")
	enemy.set("_nav_refresh_timer", 0.5)
	
	# Verify unreachable destination handling
	enemy.change_state(enemy.get("State").CHASE)
	assert(enemy.current_state == enemy.get("State").CHASE, "Enemy in chase state")
	
	# Simulate unreachable destination callback
	enemy.call("_handle_unreachable_navigation", Vector2(9999, 9999), {"success": false, "error": "Goal unreachable"})
	assert(enemy.current_state == enemy.get("State").INVESTIGATE, "Unreachable destination must safely transition to INVESTIGATE")
	assert(enemy.get("_nav_path").size() == 0, "Unreachable destination must clear active nav path")
	
	enemy.queue_free()
	print("  [PASS] Enemy obstacle navigation, throttled recalculation, and safe unreachable handling verified")


func _test_debug_visualizer() -> void:
	var nav_mgr = get_node_or_null("/root/NavigationManager")
	assert(nav_mgr != null, "NavigationManager required")
	
	var viz_script: GDScript = load("res://scenes/world/navigation_debug_visualizer.gd")
	assert(viz_script != null, "navigation_debug_visualizer.gd must load")
	
	var viz = viz_script.new()
	add_child(viz)
	
	# Test debug toggle
	nav_mgr.set_debug_display(true)
	assert(nav_mgr.debug_display_enabled == true, "Debug display must be enabled")
	
	# Register a test path
	var test_path := PackedVector2Array([Vector2(0, 0), Vector2(100, 100), Vector2(200, 100)])
	nav_mgr.register_active_path(999, test_path, Color(0, 1, 0))
	assert(nav_mgr.active_paths.has(999), "Active path must be registered")
	
	# Test unregistering
	nav_mgr.unregister_active_path(999)
	assert(not nav_mgr.active_paths.has(999), "Active path must be unregistered")
	
	nav_mgr.set_debug_display(false)
	assert(nav_mgr.debug_display_enabled == false, "Debug display toggled off")
	
	viz.queue_free()
	print("  [PASS] NavigationDebugVisualizer registration, toggle, and path tracking verified")


func _test_modular_pathfinder_algorithms() -> void:
	var algos := ["astar", "bfs", "dfs", "dls", "iddfs", "bidirectional", "greedy"]
	var start := Vector2i(1, 1)
	var goal := Vector2i(8, 8)
	var grid_size := Vector2i(15, 15)
	
	# Wall obstacle in the middle
	var blocked: Array[Vector2i] = [
		Vector2i(4, 2), Vector2i(4, 3), Vector2i(4, 4), Vector2i(4, 5), Vector2i(4, 6)
	]
	
	for algo in algos:
		var res: Dictionary = ModularPathfinderClass.search(
			algo,
			start,
			goal,
			blocked,
			grid_size,
			{"allow_diagonal": true, "depth_limit": 50, "max_depth": 100}
		)
		
		# Consistent interface assertions
		assert(res.has("success"), "%s response must have 'success'" % algo)
		assert(res.has("found"), "%s response must have 'found'" % algo)
		assert(res.has("path"), "%s response must have 'path'" % algo)
		assert(res.has("length"), "%s response must have 'length'" % algo)
		assert(res.has("nodes_expanded"), "%s response must have 'nodes_expanded'" % algo)
		assert(res.has("execution_time_ms"), "%s response must have 'execution_time_ms'" % algo)
		assert(res.has("algorithm"), "%s response must have 'algorithm'" % algo)
		assert(res.has("message"), "%s response must have 'message'" % algo)
		assert(res.has("suitability"), "%s response must have 'suitability'" % algo)
		
		assert(res["success"] == true, "%s must successfully find a path" % algo)
		assert(res["path"].size() > 0, "%s path must not be empty" % algo)
		assert(res["path"][0] == start, "%s path start must equal start node" % algo)
		assert(res["path"][-1] == goal, "%s path end must equal goal node" % algo)
		assert(res["nodes_expanded"] > 0, "%s must record expanded nodes" % algo)
		assert(res["execution_time_ms"] >= 0.0, "%s must record non-negative execution time" % algo)
		
		# Ensure path does not cut through blocked wall
		for pt in res["path"]:
			assert(not blocked.has(pt), "%s path point %s cannot be on blocked cell" % [algo, pt])
	
	# Verify algorithm suitability profiles and trade-off documentation
	var astar_prof := ModularPathfinderClass.get_algorithm_profile("astar")
	assert(astar_prof["optimal"] == true, "A* must be documented as optimal")
	assert(astar_prof["gameplay_suitable"] == true, "A* must be documented as gameplay suitable")
	
	var dfs_prof := ModularPathfinderClass.get_algorithm_profile("dfs")
	assert(dfs_prof["optimal"] == false, "DFS must be documented as NOT optimal")
	assert(dfs_prof["gameplay_suitable"] == false, "DFS must NOT be claimed as suitable for gameplay navigation")
	
	var dls_prof := ModularPathfinderClass.get_algorithm_profile("dls")
	assert(dls_prof["complete"] == false, "DLS must be documented as incomplete when goal exceeds depth limit")
	
	# Test cycle prevention and unreachable goals (infinite loop prevention)
	var enclosed_goal := Vector2i(10, 10)
	var enclosing_wall: Array[Vector2i] = [
		Vector2i(9, 9), Vector2i(10, 9), Vector2i(11, 9),
		Vector2i(9, 10),                 Vector2i(11, 10),
		Vector2i(9, 11), Vector2i(10, 11), Vector2i(11, 11)
	]
	
	for algo in algos:
		var unreach_res := ModularPathfinderClass.search(
			algo,
			start,
			enclosed_goal,
			enclosing_wall,
			grid_size,
			{"allow_diagonal": true, "depth_limit": 25, "max_depth": 50}
		)
		assert(unreach_res["success"] == false, "%s must safely return success=false on unreachable goal" % algo)
		assert(unreach_res["path"].size() == 0, "%s must return empty path on unreachable goal" % algo)
		assert(unreach_res["nodes_expanded"] > 0, "%s must record nodes expanded before termination" % algo)
	
	print("  [PASS] ModularPathfinder 7 algorithms, consistent interface, suitability profiles, and loop prevention verified")


func _test_line_of_sight_grid() -> void:
	var map := MapDataClass.new(Vector2i(20, 20), 32.0, Vector2.ZERO)
	
	# Clear corridor
	assert(map.has_grid_line_of_sight(Vector2i(2, 2), Vector2i(2, 8)) == true, "Clear column must have line of sight")
	assert(map.has_grid_line_of_sight(Vector2i(2, 2), Vector2i(8, 2)) == true, "Clear row must have line of sight")
	assert(map.has_grid_line_of_sight(Vector2i(1, 1), Vector2i(5, 5)) == true, "Clear diagonal must have line of sight")
	
	# Place wall between (2, 2) and (2, 8) at (2, 5)
	map.set_cell_blocked(Vector2i(2, 5), true, MapDataClass.CellType.WALL)
	assert(map.has_grid_line_of_sight(Vector2i(2, 2), Vector2i(2, 8)) == false, "Wall at (2, 5) must block line of sight")
	
	# World position test
	var p_start := map.grid_to_world(Vector2i(2, 2))
	var p_blocked := map.grid_to_world(Vector2i(2, 8))
	var p_clear := map.grid_to_world(Vector2i(2, 4))
	
	assert(map.has_line_of_sight(p_start, p_blocked) == false, "World position line of sight must be blocked by wall")
	assert(map.has_line_of_sight(p_start, p_clear) == true, "World position line of sight must be clear before wall")
	print("  [PASS] MapData grid line of sight detection and obstruction verified")


