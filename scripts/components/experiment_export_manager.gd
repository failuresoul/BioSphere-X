extends RefCounted
class_name ExperimentExportManager
## BioSphere-X — Automated Experiment & Trial Telemetry Export System
## Automatically records and exports every simulation match, AI-vs-AI trial,
## and player benchmark to structured CSV and JSON files for rigorous scientific analysis.
##
## Schema Coverage:
##   1. Algorithm Settings (Algorithms, Heuristics, Roles, Tactical Profiles)
##   2. Scenario & Map Parameters (Scenario Mode, Map Preset, Obstacle Density, Route Tier)
##   3. Randomness Control (Recorded PRNG Seed, Inverted Spawns for Bias Elimination)
##   4. Outcomes & Victory Determinants (Winner, Reason, Elimination vs Objective)
##   5. Timing & Computation (Duration, Pathfinding Calculation Time, Request Rates)
##   6. Performance Metrics (Nodes Expanded, Traversal Distance, HP Remaining, Damage, Accuracy)

const TRIALS_LOG_CSV_PATH  := "user://experiments/trials_log.csv"
const TRIALS_LOG_JSON_PATH := "user://experiments/trials_log.json"

const CSV_HEADERS: Array[String] = [
	"TrialID",
	"Timestamp",
	"ScenarioID",
	"ScenarioName",
	"MapID",
	"MapName",
	"ObstacleDensityPct",
	"RouteTier",
	"RandomSeed",
	"SwapSpawns",
	"Outcome",
	"Winner",
	"WinReason",
	"DurationSeconds",
	"SimulationSpeed",
	# Agent A Settings & Metrics
	"AgentA_Algo",
	"AgentA_Role",
	"AgentA_Requests",
	"AgentA_NodesExpanded",
	"AgentA_AlgoTimeMs",
	"AgentA_AvgTimePerReqMs",
	"AgentA_DistanceTraveled",
	"AgentA_RemainingHP",
	"AgentA_HealthPct",
	"AgentA_DamageDealt",
	"AgentA_DamageTaken",
	# Agent B Settings & Metrics
	"AgentB_Algo",
	"AgentB_Role",
	"AgentB_Requests",
	"AgentB_NodesExpanded",
	"AgentB_AlgoTimeMs",
	"AgentB_AvgTimePerReqMs",
	"AgentB_DistanceTraveled",
	"AgentB_RemainingHP",
	"AgentB_HealthPct",
	"AgentB_DamageDealt",
	"AgentB_DamageTaken"
]


## Exports a trial match result dictionary to disk, appending to the cumulative CSV and JSON logs,
## and creating a dedicated per-trial standalone JSON file.
static func auto_export_trial(match_data: Dictionary, trial_prefix: String = "trial") -> Dictionary:
	var dir_path := "user://experiments"
	DirAccess.make_dir_absolute(dir_path)

	# Format clean trial record conforming to schema
	var record := build_trial_record(match_data)
	var trial_id: String = record.get("trial_id", "TRIAL_UNKNOWN")
	var timestamp: String = record.get("timestamp_safe", Time.get_datetime_string_from_system().replace(":", "-"))

	# 1. Append to Cumulative CSV Database
	var csv_saved := append_to_cumulative_csv(record)

	# 2. Append to Cumulative JSON Database
	var cumulative_json_saved := append_to_cumulative_json(record)

	# 3. Save Standalone Per-Trial JSON File
	var standalone_json_path := "%s/%s_%s_%s_%s.json" % [
		dir_path, trial_prefix,
		record.get("scenario_id", "sim"),
		record.get("map_id", "arena"),
		timestamp
	]
	var standalone_saved := false
	var file := FileAccess.open(standalone_json_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(record, "\t"))
		file.close()
		standalone_saved = true

	return {
		"trial_id": trial_id,
		"csv_log_path": TRIALS_LOG_CSV_PATH,
		"csv_saved": csv_saved,
		"cumulative_json_path": TRIALS_LOG_JSON_PATH,
		"cumulative_json_saved": cumulative_json_saved,
		"standalone_json_path": standalone_json_path,
		"standalone_saved": standalone_saved,
		"record": record
	}


## Constructs a normalized trial dictionary containing all experimental parameters.
static func build_trial_record(m: Dictionary) -> Dictionary:
	var a_data: Dictionary = m.get("agent_a", {})
	var b_data: Dictionary = m.get("agent_b", {})
	var outcome_str: String = str(m.get("outcome", "Match Completed"))
	var winner_str: String = str(m.get("winner", "None"))
	var scenario_id: String = str(m.get("scenario", "combat"))
	var map_id: String = str(m.get("map_preset", "symmetric"))
	var seed_val: int = int(m.get("random_seed", 0))

	# Determine win reason
	var win_reason := "elimination"
	if "Objective Reached" in outcome_str:
		win_reason = "objective_reached"
	elif "Time Limit" in outcome_str or "Draw" in outcome_str:
		win_reason = "timeout_draw"
	elif "Mutual Elimination" in outcome_str:
		win_reason = "mutual_elimination"

	var now_iso := Time.get_datetime_string_from_system()
	var trial_id := "TR-%s-%s-%d" % [scenario_id.substr(0, 3).to_upper(), map_id.substr(0, 3).to_upper(), Time.get_ticks_msec()]

	# Retrieve map metadata if available from ControlledPlanetScenarios
	var density_pct: float = float(m.get("obstacle_density_pct", 0.0))
	var route_tier: String = str(m.get("route_tier", "STANDARD"))
	var map_name: String = str(m.get("map_name", map_id.capitalize()))

	var scenarios_script = load("res://scripts/components/controlled_planet_scenarios.gd")
	if scenarios_script and scenarios_script.SCENARIOS.has(map_id):
		var scen: Dictionary = scenarios_script.SCENARIOS[map_id]
		var exp_prof: Dictionary = scen.get("experimental_profile", {})
		density_pct = float(exp_prof.get("target_density_pct", density_pct))
		route_tier = str(exp_prof.get("route_tier", route_tier))
		map_name = str(scen.get("name", map_name))

	return {
		"trial_id": trial_id,
		"timestamp": now_iso,
		"timestamp_safe": now_iso.replace(":", "-"),
		"scenario_id": scenario_id,
		"scenario_name": str(m.get("scenario_label", scenario_id.capitalize())),
		"map_id": map_id,
		"map_name": map_name,
		"obstacle_density_pct": density_pct,
		"route_tier": route_tier,
		"random_seed": seed_val,
		"swap_spawns": bool(m.get("swap_spawns", false)),
		"outcome": outcome_str,
		"winner": winner_str,
		"win_reason": win_reason,
		"duration_seconds": float(m.get("match_duration_seconds", 0.0)),
		"simulation_speed": float(m.get("simulation_speed", 1.0)),
		# Agent A
		"agent_a": {
			"algorithm": str(a_data.get("algorithm", "astar")),
			"role": str(a_data.get("tactical_role", "adaptive")),
			"requests": int(a_data.get("total_requests", 0)),
			"nodes_expanded": int(a_data.get("total_nodes_expanded", 0)),
			"algo_time_ms": float(a_data.get("total_algo_time_ms", 0.0)),
			"avg_time_per_request_ms": float(a_data.get("avg_time_per_request_ms", 0.0)),
			"distance_traveled": float(a_data.get("total_distance_traveled", 0.0)),
			"remaining_hp": float(a_data.get("current_health", 0.0)),
			"health_percentage": float(a_data.get("health_percentage", 0.0)),
			"damage_dealt": a_data.get("damage_dealt", 0.0),
			"damage_taken": a_data.get("damage_taken", 0.0)
		},
		# Agent B
		"agent_b": {
			"algorithm": str(b_data.get("algorithm", "greedy")),
			"role": str(b_data.get("tactical_role", "adaptive")),
			"requests": int(b_data.get("total_requests", 0)),
			"nodes_expanded": int(b_data.get("total_nodes_expanded", 0)),
			"algo_time_ms": float(b_data.get("total_algo_time_ms", 0.0)),
			"avg_time_per_request_ms": float(b_data.get("avg_time_per_request_ms", 0.0)),
			"distance_traveled": float(b_data.get("total_distance_traveled", 0.0)),
			"remaining_hp": float(b_data.get("current_health", 0.0)),
			"health_percentage": float(b_data.get("health_percentage", 0.0)),
			"damage_dealt": b_data.get("damage_dealt", 0.0),
			"damage_taken": b_data.get("damage_taken", 0.0)
		}
	}


## Appends a formatted trial row to `trials_log.csv`.
## Automatically generates the header row if the file does not yet exist.
static func append_to_cumulative_csv(record: Dictionary) -> bool:
	var write_headers := not FileAccess.file_exists(TRIALS_LOG_CSV_PATH)
	var file: FileAccess

	if write_headers:
		file = FileAccess.open(TRIALS_LOG_CSV_PATH, FileAccess.WRITE)
		if not file:
			return false
		file.store_line(",".join(CSV_HEADERS))
	else:
		file = FileAccess.open(TRIALS_LOG_CSV_PATH, FileAccess.READ_WRITE)
		if not file:
			return false
		file.seek_end()

	var a: Dictionary = record.get("agent_a", {})
	var b: Dictionary = record.get("agent_b", {})

	var row_values := [
		record.get("trial_id", ""),
		record.get("timestamp", ""),
		record.get("scenario_id", ""),
		"\"" + str(record.get("scenario_name", "")) + "\"",
		record.get("map_id", ""),
		"\"" + str(record.get("map_name", "")) + "\"",
		str(record.get("obstacle_density_pct", 0.0)),
		record.get("route_tier", ""),
		str(record.get("random_seed", 0)),
		str(record.get("swap_spawns", false)),
		"\"" + str(record.get("outcome", "")) + "\"",
		str(record.get("winner", "")),
		str(record.get("win_reason", "")),
		str(record.get("duration_seconds", 0.0)),
		str(record.get("simulation_speed", 1.0)),
		# Agent A
		str(a.get("algorithm", "")),
		str(a.get("role", "")),
		str(a.get("requests", 0)),
		str(a.get("nodes_expanded", 0)),
		str(a.get("algo_time_ms", 0.0)),
		str(a.get("avg_time_per_request_ms", 0.0)),
		str(a.get("distance_traveled", 0.0)),
		str(a.get("remaining_hp", 0.0)),
		str(a.get("health_percentage", 0.0)),
		str(a.get("damage_dealt", 0.0)),
		str(a.get("damage_taken", 0.0)),
		# Agent B
		str(b.get("algorithm", "")),
		str(b.get("role", "")),
		str(b.get("requests", 0)),
		str(b.get("nodes_expanded", 0)),
		str(b.get("algo_time_ms", 0.0)),
		str(b.get("avg_time_per_request_ms", 0.0)),
		str(b.get("distance_traveled", 0.0)),
		str(b.get("remaining_hp", 0.0)),
		str(b.get("health_percentage", 0.0)),
		str(b.get("damage_dealt", 0.0)),
		str(b.get("damage_taken", 0.0))
	]

	file.store_line(",".join(row_values))
	file.close()
	return true


## Appends the trial record to `trials_log.json`.
static func append_to_cumulative_json(record: Dictionary) -> bool:
	var trials: Array = []
	if FileAccess.file_exists(TRIALS_LOG_JSON_PATH):
		var file_read := FileAccess.open(TRIALS_LOG_JSON_PATH, FileAccess.READ)
		if file_read:
			var text := file_read.get_as_text()
			file_read.close()
			var parsed = JSON.parse_string(text)
			if parsed is Array:
				trials = parsed

	trials.append(record)

	var file_write := FileAccess.open(TRIALS_LOG_JSON_PATH, FileAccess.WRITE)
	if file_write:
		file_write.store_string(JSON.stringify(trials, "\t"))
		file_write.close()
		return true
	return false
