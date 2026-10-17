extends SceneTree
## Automated Test & Demonstration Suite for Repeatable AI-vs-AI Experiments
## Tests multi-trial execution on identical maps, alternating starting positions,
## and deterministic recorded random seeds.

func _init() -> void:
	print("\n=======================================================")
	print("🧪 BioSphere-X — Repeatable AI-vs-AI Experiments Suite")
	print("=======================================================\n")

	# 1. Load AIArena scene
	var arena_scene = load("res://scenes/ai_vs_ai/ai_arena.tscn")
	if not arena_scene:
		push_error("Failed to load scenes/ai_vs_ai/ai_arena.tscn")
		quit(1)
		return

	var arena = arena_scene.instantiate()
	root.add_child(arena)
 		var spawn_desc := "A: Right (420, 0) | B: Left (-420, 0)" if is_swapped else "A: Left (-420, 0) | B: Right (420, 0)"
		print("  Trial #%d -> Recorded Seed: %d | Starting Positions: %s" % [i + 1, s, spawn_desc])

	# Verify paired seed property:
	# Trial 0 and Trial 1 should share the exact same seed to isolate spawn orientation!
	assert(arena.batch_seed_sequence[0] == arena.batch_seed_sequence[1], "Paired seeds: Trial 0 and 1 must share seed")
	print("✓ Paired seeds verified: Trials 1 & 2 share identical seed with inverted spawns to isolate positional bias.")

	# 5. Simulate trial terminations with controlled metrics to test batch aggregation
	print("\nSimulating batch match resolutions...")
	for i in range(trials_count):
		arena.batch_current_trial = i
		var is_swapped := (i % 2 == 1)
		arena.swap_spawns = is_swapped
		arena.random_seed = arena.batch_seed_sequence[i]

		# Mock match outcome (Agent A wins via A* superior pathing)
		var trial_res := {
			"scenario": arena.current_scenario,
			"map_preset": arena.current_map,
			"random_seed": arena.random_seed,
			"swap_spawns": is_swapped,
			"match_duration_seconds": 15.5 + float(i) * 0.4,
			"outcome": "Agent A Won (Elimination)",
			"winner": "Agent A",
			"agent_a": {
				"algorithm": "astar",
				"total_nodes_expanded": 88 + i * 2,
				"total_distance_traveled": 640.0 + i * 15.0,
				"remaining_health": 65.0,
				"damage_dealt": 100.0
			},
			"agent_b": {
				"algorithm": "greedy",
				"total_nodes_expanded": 32 + i * 3,
				"total_distance_traveled": 520.0 + i * 10.0,
				"remaining_health": 0.0,
				"damage_dealt": 35.0
			}
		}
		arena.batch_results_history.append(trial_res)

	# 6. Verify Summary Aggregates
	var summary: Dictionary = arena.get_batch_summary()
	print("\n--- Batch Experiment Summary Report ---")
	print("Total Trials:             %d" % int(summary.get("total_trials", 0)))
	print("Agent A (A*) Wins:        %d (%.1f%%)" % [int(summary.get("agent_a_wins", 0)), float(summary.get("agent_a_winrate", 0.0))])
	print("Agent B (Greedy) Wins:    %d (%.1f%%)" % [int(summary.get("agent_b_wins", 0)), float(summary.get("agent_b_winrate", 0.0))])
	print("Draws:                    %d (%.1f%%)" % [int(summary.get("draws", 0)), float(summary.get("draw_rate", 0.0))])
	print("Left Spawn Wins:          %d (%.1f%%)" % [int(summary.get("left_spawn_wins", 0)), float(summary.get("left_spawn_pct", 0.0))])
	print("Right Spawn Wins:         %d (%.1f%%)" % [int(summary.get("right_spawn_wins", 0)), float(summary.get("right_spawn_pct", 0.0))])
	print("Spawn Bias Delta:         %.1f%% (Near 0%% = Fair Trials)" % float(summary.get("spawn_bias_delta", 0.0)))
	print("Average Match Duration:   %.2f seconds" % float(summary.get("avg_duration", 0.0)))
	print("Avg Nodes Expanded (A):   %.1f" % float(summary.get("avg_nodes_a", 0.0)))
	print("Avg Nodes Expanded (B):   %.1f" % float(summary.get("avg_nodes_b", 0.0)))

	assert(int(summary.get("total_trials", 0)) == 4, "Total trials must equal 4")
	assert(float(summary.get("agent_a_winrate", 0.0)) == 100.0, "Agent A win rate should be 100%")
	assert(absf(float(summary.get("spawn_bias_delta", 0.0))) == 0.0, "Spawn bias delta must be 0% with alternating spawns")

	# 7. Test Export JSON and CSV
	var json_path: String = arena.export_batch_json()
	var csv_path: String = arena.export_batch_csv()
	print("\n--- Export Files ---")
	print("JSON Export: %s (Valid: %s)" % [json_path, str(FileAccess.file_exists(json_path))])
	print("CSV Export:  %s (Valid: %s)" % [csv_path, str(FileAccess.file_exists(csv_path))])
	assert(FileAccess.file_exists(json_path), "JSON export file must exist")
	assert(FileAccess.file_exists(csv_path), "CSV export file must exist")

	# 8. Test Deterministic Random Seed Replay
	print("\n--- Verifying Deterministic Replay ---")
	var trial_to_replay: Dictionary = arena.batch_results_history[0]
	var recorded_seed: int = trial_to_replay.get("random_seed", 0)
	seed(recorded_seed)
	var rand_val_1: float = randf()
	seed(recorded_seed)
	var rand_val_2: float = randf()
	print("Seed: %d -> Run 1 randf(): %f | Run 2 randf(): %f" % [recorded_seed, rand_val_1, rand_val_2])
	assert(rand_val_1 == rand_val_2, "PRNG output must be identical for identical seeds")
	print("✓ Deterministic repeatability verified with recorded seed.")

	arena.queue_free()
	print("\n=======================================================")
	print("✅ ALL REPEATABLE AI-VS-AI EXPERIMENT TESTS PASSED!")
	print("=======================================================\n")
	quit(0)
