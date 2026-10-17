extends SceneTree

func _init() -> void:
	print("--- Starting Pathfinding Visualizer Tests ---")
	var visualizer_script = load("res://ui/components/pathfinding_visualizer.gd")
	if not visualizer_script:
		push_error("Failed to load pathfinding_visualizer.gd")
		quit(1)
		return

	var visualizer = visualizer_script.new()
	if not visualizer:
		push_error("Failed to instantiate pathfinding_visualizer")
		quit(1)
		return

	root.add_child(visualizer)
	
	# Check initial state
	assert(visualizer.has_method("_instrument_bfs"), "Must have _instrument_bfs")
	assert(visualizer.has_method("_instrument_dfs"), "Must have _instrument_dfs")
	assert(visualizer.has_method("_instrument_greedy"), "Must have _instrument_greedy")
	assert(visualizer.has_method("_instrument_astar"), "Must have _instrument_astar")

	# Test each algorithm runs and produces steps and path
	for algo_idx in range(4):
		visualizer._on_algo_selected(algo_idx)
		var algo_key = visualizer.ALGO_KEYS[algo_idx]
		var path_len = visualizer._final_metrics.get("path_length", 0)
		var steps_cnt = visualizer._search_steps.size()
		var found = visualizer._final_metrics.get("found", false)
		print("Tested algo: %s | steps: %d | path_len: %d | found: %s" % [
			algo_key,
			steps_cnt,
			path_len,
			str(found)
		])
		assert(steps_cnt > 0, "Steps must be generated for " + algo_key)
		assert(found, "Path must be found for " + algo_key)
		assert(path_len > 0, "Path length must be > 0 for " + algo_key)

	visualizer.queue_free()
	print("--- All Pathfinding Visualizer Tests Passed! ---")
	quit(0)
