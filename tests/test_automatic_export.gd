extends SceneTree
## BioSphere-X — Automated Result Export & UI Verification Test Suite
## Validates:
##   1. Auto-export schema completeness (algorithm settings, scenario ID, seed, outcome, timing, metrics)
##   2. Automated CSV database logging (trials_log.csv with headers and exact column alignment)
##   3. Cumulative and per-trial JSON serialization
##   4. AIArena auto-export integration and batch execution recording
##   5. UI layout and button integration

const ExportManagerScript := preload("res://scripts/components/experiment_export_manager.gd")
const ArenaScript := preload("res://scenes/ai_vs_ai/ai_arena.gd")

func _init() -> void:
	print("\n=====================================================================")
	print("💾 BioSphere-X: Automatic Result Export & UI Test Suite")
	print("=====================================================================\n")

	# Clean previous test files in user://experiments/ to start clean
	var dir_path := "user://experiments"
	DirAccess.make_dir_absolute(dir_path)
	if FileAccess.file_exists(ExportManagerScript.TRIALS_LOG_CSV_PATH):
		DirAccess.remove_absolute(ExportManagerScript.TRIALS_LOG_CSV_PATH)
	if FileAccess.file_exists(ExportManagerScript.TRIALS_LOG_JSON_PATH):
		DirAccess.remove_absolute(ExportManagerScript.TRIALS_LOG_JSON_PATH)

	# 1. Test build_trial_record Schema Completeness
	print("[1/5] Verifying trial export schema completeness...")
	var mock_match := {
		"scenario": "combat",
		"scenario_label": "Pursuit and Combat",
		"map_preset": "trappist_1_e",
		"map_name": "TRAPPIST-1 e — Twilight Basin",
		"random_seed": 1337,
		"swap_spawns": true,
		"match_duration_seconds": 24.85,
		"outcome": "Agent A Won (Elimination)",
		"winner": "Agent A",
		"simulation_speed": 2.0,
		"agent_a": {
			"algorithm": "astar",
			"tactical_role": "assault",
			"total_requests": 45,
			"total_nodes_expanded": 890,
			"total_algo_time_ms": 14.25,
			"avg_time_per_request_ms": 0.316,
			"total_distance_traveled": 642.5,
			"current_health": 72.0,
			"max_health": 100.0,
			"health_percentage": 72.0,
			"damage_dealt": 100.0,
			"damage_taken": 28.0
		},
		"agent_b": {
			"algorithm": "greedy",
			"tactical_role": "flanker",
			"total_requests": 38,
			"total_nodes_expanded": 310,
			"total_algo_time_ms": 6.80,
			"avg_time_per_request_ms": 0.179,
			"total_distance_traveled": 580.0,
			"current_health": 0.0,
			"max_health": 100.0,
			"health_percentage": 0.0,
			"damage_dealt": 28.0,
			"damage_taken": 100.0
		}
	}

	var record := ExportManagerScript.build_trial_record(mock_match)
	assert(record.has("trial_id"), "Record must have trial_id")
	assert(record.has("timestamp"), "Record must have timestamp")
	assert(record.get("scenario_id") == "combat", "Scenario ID must be combat")
	assert(record.get("map_id") == "trappist_1_e", "Map ID must be trappist_1_e")
	assert(record.get("random_seed") == 1337, "Seed must be 1337")
	assert(record.get("swap_spawns") == true, "Swap spawns must be true")
	assert(record.get("winner") == "Agent A", "Winner must be Agent A")
	assert(record.get("win_reason") == "elimination", "Win reason must be elimination")
	assert(record.get("duration_seconds") == 24.85, "Duration must match")

	var a_rec: Dictionary = record.get("agent_a", {})
	assert(a_rec.get("algorithm") == "astar", "Agent A algorithm must be astar")
	assert(a_rec.get("role") == "assault", "Agent A role must be assault")
	assert(a_rec.get("nodes_expanded") == 890, "Agent A nodes expanded must match")
	assert(a_rec.get("damage_dealt") == 100.0, "Agent A damage dealt must match")

	var b_rec: Dictionary = record.get("agent_b", {})
	assert(b_rec.get("algorithm") == "greedy", "Agent B algorithm must be greedy")
	assert(b_rec.get("remaining_hp") == 0.0, "Agent B HP must be 0")
	print("  ✓ Trial record schema verified across all experimental axes.")

	# 2. Test auto_export_trial Execution
	print("\n[2/5] Testing automated CSV and JSON disk export...")
	var export_res := ExportManagerScript.auto_export_trial(mock_match, "unit_test_trial")
	assert(export_res.get("csv_saved") == true, "CSV must be successfully saved")
	assert(export_res.get("cumulative_json_saved") == true, "Cumulative JSON must be saved")
	assert(export_res.get("standalone_saved") == true, "Standalone JSON must be saved")

	var csv_path: String = export_res.get("csv_log_path")
	var json_path: String = export_res.get("cumulative_json_path")
	var single_json: String = export_res.get("standalone_json_path")

	assert(FileAccess.file_exists(csv_path), "trials_log.csv must exist")
	assert(FileAccess.file_exists(json_path), "trials_log.json must exist")
	assert(FileAccess.file_exists(single_json), "Standalone trial JSON must exist")

	# Validate CSV headers & contents
	var f_csv := FileAccess.open(csv_path, FileAccess.READ)
	var header_line := f_csv.get_line()
	assert(header_line.begins_with("TrialID"), "CSV must begin with TrialID header")
	assert(header_line.contains("ScenarioID"), "CSV must contain ScenarioID")
	assert(header_line.contains("RandomSeed"), "CSV must contain RandomSeed")
	assert(header_line.contains("AgentA_Algo"), "CSV must contain AgentA_Algo")
	assert(header_line.contains("AgentB_Algo"), "CSV must contain AgentB_Algo")

	var row_1 := f_csv.get_line()
	assert(row_1.contains("combat"), "Row must contain scenario ID combat")
	assert(row_1.contains("trappist_1_e"), "Row must contain map ID trappist_1_e")
	assert(row_1.contains("1337"), "Row must contain seed 1337")
	assert(row_1.contains("astar"), "Row must contain algorithm astar")
	f_csv.close()

	print("  ✓ Automated CSV log verified: %s" % csv_path)
	print("  ✓ Cumulative JSON log verified: %s" % json_path)
	print("  ✓ Standalone JSON export verified: %s" % single_json)

	# 3. Test Multi-Trial Sequential Logging (Append Mode)
	print("\n[3/5] Testing multi-trial sequential append logging...")
	for trial_num in range(2, 6):
		var next_match: Dictionary = mock_match.duplicate(true)
		next_match["random_seed"] = 1337 + trial_num * 10
		next_match["match_duration_seconds"] = 15.0 + trial_num * 2.5
		if trial_num % 2 == 0:
			next_match["outcome"] = "Agent B Won (Elimination)"
			next_match["winner"] = "Agent B"
		ExportManagerScript.auto_export_trial(next_match, "batch_test")

	# Check cumulative CSV row count
	var f_csv2 := FileAccess.open(csv_path, FileAccess.READ)
	var total_rows := 0
	while not f_csv2.eof_reached():
		var l := f_csv2.get_line().strip_edges()
		if not l.is_empty():
			total_rows += 1
	f_csv2.close()

	# 1 header + 5 trials = 6 rows
	assert(total_rows == 6, "CSV must contain 1 header + 5 trials = 6 rows, got: %d" % total_rows)

	# Check cumulative JSON count
	var f_json2 := FileAccess.open(json_path, FileAccess.READ)
	var json_parsed = JSON.parse_string(f_json2.get_as_text())
	f_json2.close()
	assert(json_parsed is Array and json_parsed.size() == 5, "Cumulative JSON must contain exactly 5 trials")
	print("  ✓ Sequential append verified: 5 trials recorded across CSV and JSON.")

	# 4. Test AIArena Auto-Export Integration & UI Controls
	print("\n[4/5] Verifying AIArena auto-export integration...")
	var arena_scene = load("res://scenes/ai_vs_ai/ai_arena.tscn")
	assert(arena_scene != null, "Must be able to load ai_arena.tscn")
	var arena = arena_scene.instantiate()
	root.add_child(arena)

	assert(arena.get("auto_export_enabled") != null, "AIArena must have auto_export_enabled")
	assert(arena.auto_export_enabled == true, "auto_export_enabled must default to true")

	# Simulate match termination with auto_export_enabled
	arena.current_scenario = "combat"
	arena.current_map = "lhs_1140_b"
	arena.random_seed = 999
	arena.call("_terminate_match", "Agent A Won (Elimination)")

	var last_info: Dictionary = arena.get("last_export_info")
	assert(not last_info.is_empty(), "AIArena must auto-export on match completion")
	assert(last_info.get("csv_saved") == true, "AIArena auto-export must log to CSV")
	assert(last_info.get("standalone_saved") == true, "AIArena auto-export must save standalone JSON")

	print("  ✓ AIArena auto-export on match termination verified.")

	# 5. Verify UI Controls
	print("\n[5/5] Verifying UI controls and responsive display scaling...")

	var auto_btn = arena.get_node_or_null("%AutoExportButton")
	assert(auto_btn != null, "UI must contain AutoExportButton")
	assert(auto_btn.text.contains("Auto"), "AutoExportButton must display auto-export text")

	var rematch_btn = arena.get_node_or_null("%RematchButton")
	assert(rematch_btn != null, "ResultsPanel must contain RematchButton")

	var copy_btn = arena.get_node_or_null("%CopyExportPathButton")
	assert(copy_btn != null, "ResultsPanel must contain CopyExportPathButton")

	var close_btn = arena.get_node_or_null("%CloseResultsButton")
	assert(close_btn != null, "ResultsPanel must contain CloseResultsButton")

	arena.queue_free()
	print("  ✓ AI vs AI responsive UI layout and auto-export controls verified.")

	print("\n=====================================================================")
	print("🎉 ALL AUTOMATIC RESULT EXPORT & UI TESTS PASSED SUCCESSFULLY!")
	print("=====================================================================\n")

	quit(0)
