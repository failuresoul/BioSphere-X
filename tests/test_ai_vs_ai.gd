extends Node2D
## Automated Test Suite for BioSphere-X AI vs AI Simulation Mode.
## Validates autonomous agent behavior, independent algorithm assignment,
## combat & damage exchange, race objective detection, simulation controls, and data export.

const AutonomousAgentScript := preload("res://scenes/ai_vs_ai/autonomous_agent.gd")
const AIArenaScript := preload("res://scenes/ai_vs_ai/ai_arena.gd")
const ObjectiveBeaconScript := preload("res://scenes/ai_vs_ai/objective_beacon.gd")
const DamageDataScript := preload("res://scripts/components/damage_data.gd")

var _agent_scene := preload("res://scenes/ai_vs_ai/autonomous_agent.tscn")
var _arena_scene := preload("res://scenes/ai_vs_ai/ai_arena.tscn")
var _beacon_scene := preload("res://scenes/ai_vs_ai/objective_beacon.tscn")


func _ready() -> void:
	print("==================================================")
	print("  BIOSPHERE-X: RUNNING AI vs AI TEST SUITE")
	print("==================================================")
	
	test_agent_initialization()
	test_independent_algorithm_selection()
	test_agent_combat_and_damage()
	test_friendly_fire_prevention()
	test_race_objective_detection()
	test_simulation_lifecycle_and_speed()
	test_spawn_swapping_fairness()
	test_experimental_metrics_and_export()
	
	print("==================================================")
	print("  ALL AI vs AI TESTS COMPLETED SUCCESSFULLY! [8/8]")
	print("==================================================")


func test_agent_initialization() -> void:
	print("[TEST 1/8] Verifying AutonomousAgent initialization...")
	var agent = _agent_scene.instantiate()
	add_child(agent)

	agent.call("setup_agent", "Test Agent Alpha", "team_a", Color(0.1, 0.8, 1.0), "astar", "combat")
	assert(agent.get("agent_name") == "Test Agent Alpha", "Agent name should match")
	assert(agent.get("team_group") == "team_a", "Team group should be team_a")
	assert(agent.is_in_group("team_a"), "Agent should be in team_a group")
	assert(agent.get("algorithm") == "astar", "Algorithm should be astar")
	assert(agent.get("scenario") == "combat", "Scenario should be combat")
	assert(agent.get("health_component") != null, "HealthComponent must be initialized")
	assert(agent.get("weapon_component") != null, "WeaponComponent must be initialized")
	assert(agent.weapon_component.use_global_energy == false, "Agent weapon should use local energy, not player global energy")

	agent.queue_free()
	print("  [PASS] AutonomousAgent components and identity initialized successfully.")


func test_independent_algorithm_selection() -> void:
	print("[TEST 2/8] Verifying independent algorithm selection for Agent A & B...")
	var agent_a = _agent_scene.instantiate()
	var agent_b = _agent_scene.instantiate()
	add_child(agent_a)
	add_child(agent_b)

	agent_a.call("setup_agent", "Agent A", "team_a", Color.CYAN, "astar", "combat")
	agent_b.call("setup_agent", "Agent B", "team_b", Color.ORANGE, "greedy", "combat")

	assert(agent_a.get("algorithm") == "astar", "Agent A should be configured with astar")
	assert(agent_b.get("algorithm") == "greedy", "Agent B should be configured with greedy")

	# Swap algorithms
	agent_a.set("algorithm", "bfs")
	agent_b.set("algorithm", "bidirectional")
	assert(agent_a.get("algorithm") == "bfs", "Agent A algorithm should update independently to bfs")
	assert(agent_b.get("algorithm") == "bidirectional", "Agent B algorithm should update independently to bidirectional")

	agent_a.queue_free()
	agent_b.queue_free()
	print("  [PASS] Agent A and Agent B algorithms operate completely independently.")


func test_agent_combat_and_damage() -> void:
	print("[TEST 3/8] Verifying agent-vs-agent damage, knockback, and defeat...")
	var agent_a = _agent_scene.instantiate()
	var agent_b = _agent_scene.instantiate()
	add_child(agent_a)
	add_child(agent_b)

	agent_a.call("setup_agent", "Agent A", "team_a", Color.CYAN, "astar", "combat")
	agent_b.call("setup_agent", "Agent B", "team_b", Color.ORANGE, "greedy", "combat")
	agent_a.global_position = Vector2(0, 0)
	agent_b.global_position = Vector2(100, 0)
	agent_b.health_component.invulnerability_time = 0.0
	agent_b.health_component._invuln_timer = 0.0

	var initial_hp_b: float = float(agent_b.health_component.current_health)
	assert(initial_hp_b == 100.0, "Initial HP should be 100.0")

	# Fire weapon from Agent A at Agent B
	var proj = agent_a.weapon_component.attack(Vector2.RIGHT, agent_a.global_position, agent_a)
	assert(proj != null, "WeaponComponent must instantiate projectile")
	assert(proj.get("source_node") == agent_a, "Projectile source must be Agent A")

	# Apply damage directly using DamageData contract
	var dmg_data = DamageDataScript.create(25.0, agent_a, DamageDataScript.DamageType.ENERGY, Vector2.RIGHT, 50.0, agent_b.global_position)
	var damaged: bool = agent_b.call("apply_damage", dmg_data)
	assert(damaged == true, "apply_damage should return true on living agent")
	assert(agent_b.health_component.current_health == 75.0, "Agent B health should decrease to 75.0")
	assert(agent_b.get("damage_taken") == 25.0, "Agent B damage_taken metric should record 25.0")

	# Inflict lethal damage
	agent_b.health_component._invuln_timer = 0.0
	var lethal_data = DamageDataScript.create(80.0, agent_a, DamageDataScript.DamageType.ENERGY, Vector2.RIGHT, 10.0, agent_b.global_position)
	agent_b.call("apply_damage", lethal_data)
	assert(agent_b.get("current_state") == AutonomousAgentScript.AgentState.DEAD, "Agent B state should be DEAD")
	assert(agent_b.health_component.is_dead() == true, "HealthComponent is_dead() should be true")

	if is_instance_valid(proj):
		proj.queue_free()
	agent_a.queue_free()
	agent_b.queue_free()
	print("  [PASS] Agent combat, damage deduction, and death transition verified.")


func test_friendly_fire_prevention() -> void:
	print("[TEST 4/8] Verifying friendly fire prevention for same team...")
	var agent_a1 = _agent_scene.instantiate()
	var agent_a2 = _agent_scene.instantiate()
	add_child(agent_a1)
	add_child(agent_a2)

	agent_a1.call("setup_agent", "Agent A1", "team_a", Color.CYAN, "astar", "combat")
	agent_a2.call("setup_agent", "Agent A2", "team_a", Color.CYAN, "astar", "combat")

	# Fire projectile from A1 toward A2
	var proj = agent_a1.weapon_component.attack(Vector2.RIGHT, agent_a1.global_position, agent_a1)
	assert(proj != null, "Projectile created")

	# Manually test collision handling against teammate
	var initial_hp: float = float(agent_a2.health_component.current_health)
	proj.call("_handle_collision", agent_a2)
	assert(agent_a2.health_component.current_health == initial_hp, "Teammate in team_a should not receive damage from team_a projectile")

	if is_instance_valid(proj):
		proj.queue_free()
	agent_a1.queue_free()
	agent_a2.queue_free()
	print("  [PASS] Team friendly-fire exclusion confirmed.")


func test_race_objective_detection() -> void:
	print("[TEST 5/8] Verifying ObjectiveBeacon detection in Race scenario...")
	var beacon = _beacon_scene.instantiate()
	var agent = _agent_scene.instantiate()
	beacon.global_position = Vector2(1000, 1000)
	agent.global_position = Vector2(2000, 2000)
	add_child(beacon)
	add_child(agent)
	agent.call("setup_agent", "Racer", "team_a", Color.CYAN, "astar", "race")
	beacon.call("reset_beacon")

	var race_res := {"signal_emitted": false, "winner": null}
	beacon.connect("objective_reached", func(winner: Node2D):
		race_res["signal_emitted"] = true
		race_res["winner"] = winner
	)

	beacon.call("_on_body_entered", agent)
	assert(race_res["signal_emitted"] == true, "objective_reached signal must be emitted")
	assert(race_res["winner"] == agent, "Winner should be the racer agent")
	assert(beacon.get("winner_agent") == agent, "Winner agent recorded on beacon")
	assert(beacon.get("is_active") == false, "Beacon becomes inactive after being claimed")

	beacon.queue_free()
	agent.queue_free()
	print("  [PASS] ObjectiveBeacon detects arrival and announces winner.")


func test_simulation_lifecycle_and_speed() -> void:
	print("[TEST 6/8] Verifying match lifecycle and simulation speed scaling...")
	var arena = _arena_scene.instantiate()
	add_child(arena)

	assert(arena.get("match_state") == AIArenaScript.MatchState.WAITING, "Initial state should be WAITING")
	
	arena.call("start_match")
	assert(arena.get("match_state") == AIArenaScript.MatchState.RUNNING, "State after start should be RUNNING")

	arena.call("pause_match")
	assert(arena.get("match_state") == AIArenaScript.MatchState.PAUSED, "State after pause should be PAUSED")

	arena.call("resume_match")
	assert(arena.get("match_state") == AIArenaScript.MatchState.RUNNING, "State after resume should be RUNNING")

	# Test speed scaling
	arena.call("_apply_simulation_speed", 2.0)
	assert(is_equal_approx(Engine.time_scale, 2.0), "Engine.time_scale should be 2.0")
	arena.call("_apply_simulation_speed", 1.0)
	assert(is_equal_approx(Engine.time_scale, 1.0), "Engine.time_scale should restore to 1.0")

	arena.call("reset_match")
	assert(arena.get("match_state") == AIArenaScript.MatchState.WAITING, "State after reset should be WAITING")
	assert(arena.get("match_elapsed_time") == 0.0, "Elapsed time should be reset to 0.0")

	arena.queue_free()
	Engine.time_scale = 1.0
	print("  [PASS] Simulation lifecycle controls and speed scaling function correctly.")


func test_spawn_swapping_fairness() -> void:
	print("[TEST 7/8] Verifying spawn swapping for fair comparison trials...")
	var arena = _arena_scene.instantiate()
	add_child(arena)

	# Trial 1: Normal Spawns
	arena.set("swap_spawns", false)
	arena.call("reset_match")
	assert(arena.agent_a.global_position.x < 0.0, "Agent A should spawn on Left (negative X)")
	assert(arena.agent_b.global_position.x > 0.0, "Agent B should spawn on Right (positive X)")

	# Trial 2: Swapped Spawns
	arena.set("swap_spawns", true)
	arena.call("reset_match")
	assert(arena.agent_a.global_position.x > 0.0, "Agent A should spawn on Right (positive X) when swapped")
	assert(arena.agent_b.global_position.x < 0.0, "Agent B should spawn on Left (negative X) when swapped")

	arena.queue_free()
	print("  [PASS] Spawn position swapping facilitates fair, symmetrical trials.")


func test_experimental_metrics_and_export() -> void:
	print("[TEST 8/8] Verifying experimental metrics collection and export to JSON/CSV...")
	var arena = _arena_scene.instantiate()
	add_child(arena)

	arena.set("current_scenario", "combat")
	arena.call("start_match")
	
	# Simulate match termination
	arena.call("_terminate_match", "Agent A Won (Elimination)")
	assert(arena.get("match_state") == AIArenaScript.MatchState.FINISHED, "Match should be FINISHED")
	assert(arena.match_results.has("scenario"), "Results must contain scenario")
	assert(arena.match_results.has("agent_a"), "Results must contain agent_a")
	assert(arena.match_results.has("agent_b"), "Results must contain agent_b")
	assert(arena.match_results.has("winner"), "Results must contain winner")
	assert(arena.match_results["winner"] == "Agent A", "Winner should be Agent A")

	# Test JSON Export
	var json_path: String = arena.call("export_json_results")
	assert(not json_path.is_empty(), "JSON export should produce valid file path")
	assert(FileAccess.file_exists(json_path), "JSON export file must exist on disk")

	# Test CSV Export
	var csv_path: String = arena.call("export_csv_results")
	assert(not csv_path.is_empty(), "CSV export should produce valid file path")
	assert(FileAccess.file_exists(csv_path), "CSV export file must exist on disk")

	# Verify Race Scenario marks unmeasured combat metrics as unavailable
	arena.set("current_scenario", "race")
	arena.call("reset_match")
	arena.call("start_match")
	arena.call("_terminate_match", "Agent B Won (Objective Reached)")
	assert(arena.match_results["agent_a"]["damage_dealt"] == "unavailable", "Race scenario must record unmeasured damage as 'unavailable'")
	assert(arena.match_results["agent_b"]["damage_dealt"] == "unavailable", "Race scenario must record unmeasured damage as 'unavailable'")

	arena.queue_free()
	print("  [PASS] Experimental metrics collection and JSON/CSV data export verified.")
