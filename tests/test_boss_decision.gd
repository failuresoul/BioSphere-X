extends Node2D
## Automated Test Suite for BioSphere-X Boss Decision-Making Algorithms.
## Validates Godot Boss controller integration with adversarial AI decision modules:
## Minimax, Alpha-Beta pruning, MCTS, and Heuristic evaluation.
## Verifies asynchronous dispatch, action timeouts, safe fallback execution,
## and seamless real-time combat responsiveness.

const BossEnemyScript := preload("res://scenes/boss/boss_enemy.gd")
const HealthComponentScript := preload("res://scripts/components/health_component.gd")
var _boss_scene := preload("res://scenes/boss/boss_enemy.tscn")


func _ready() -> void:
	print("==================================================")
	print("  BIOSPHERE-X: BOSS DECISION-MAKING TEST SUITE")
	print("==================================================")
	
	test_boss_ai_configuration_and_algorithms()
	test_ai_client_boss_api_methods()
	test_decision_payload_handling_and_signals()
	test_ai_action_execution_tremor_slam()
	test_ai_action_execution_plasma_barrage()
	test_ai_action_execution_charge_rush()
	test_ai_action_execution_guard_stance()
	test_tactical_positioning_velocity()
	test_safe_fallback_on_backend_failure()
	test_non_blocking_async_responsiveness()
	
	print("==================================================")
	print("  ALL BOSS DECISION-MAKING TESTS PASSED! [10/10]")
	print("==================================================")
	get_tree().quit(0)


func test_boss_ai_configuration_and_algorithms() -> void:
	print("[TEST 1/10] Verifying Boss AI configuration and algorithm switching...")
	var boss: CharacterBody2D = _boss_scene.instantiate()
	add_child(boss)
	
	assert(boss.get("use_python_decision") == true, "use_python_decision must default to true")
	assert(boss.get("decision_algorithm") == "alpha_beta", "decision_algorithm must default to alpha_beta")
	assert(boss.get("max_search_depth") == 4, "max_search_depth must default to 4")
	assert(boss.get("mcts_simulations") == 150, "mcts_simulations must default to 150")
	
	boss.call("set_decision_algorithm", "minimax")
	assert(boss.call("get_decision_algorithm") == "minimax", "Algorithm should switch to minimax")
	
	boss.call("set_decision_algorithm", "mcts")
	assert(boss.call("get_decision_algorithm") == "mcts", "Algorithm should switch to mcts")
	
	boss.call("set_decision_algorithm", "alpha_beta")
	assert(boss.call("get_decision_algorithm") == "alpha_beta", "Algorithm should switch back to alpha_beta")
	
	boss.queue_free()
	print("  [PASS] Boss AI configuration and hot-swappable algorithms verified.")


func test_ai_client_boss_api_methods() -> void:
	print("[TEST 2/10] Verifying AIClient boss decision request interfaces...")
	var ai_node = get_node_or_null("/root/AIClient")
	assert(ai_node != null, "AIClient autoload must be accessible in SceneTree")
	assert(ai_node.has_method("request_boss_decision"), "AIClient must implement request_boss_decision")
	assert(ai_node.has_method("request_boss_algorithms"), "AIClient must implement request_boss_algorithms")
	print("  [PASS] AIClient boss API interfaces verified.")


func test_decision_payload_handling_and_signals() -> void:
	print("[TEST 3/10] Verifying decision payload reception and signal emission...")
	var boss: CharacterBody2D = _boss_scene.instantiate()
	add_child(boss)
	
	var received := {"fired": false, "algo": "", "action": "", "stats": {}}
	boss.connect("decision_received", func(algo: String, act: String, stats: Dictionary):
		received["fired"] = true
		received["algo"] = algo
		received["action"] = act
		received["stats"] = stats
	)
	
	var mock_response := {
		"success": true,
		"data": {
			"action": "TREMOR_SLAM",
			"algorithm": "alpha_beta",
			"score": 145.2,
			"statistics": {
				"nodes_evaluated": 34,
				"pruned_branches": 12,
				"execution_time_ms": 1.25
			}
		}
	}
	
	boss.call("_on_ai_decision_result", mock_response)
	
	assert(received["fired"] == true, "decision_received signal must be emitted")
	assert(received["algo"] == "alpha_beta", "Algorithm in signal must match")
	assert(received["action"] == "TREMOR_SLAM", "Action in signal must match")
	assert(received["stats"]["nodes_evaluated"] == 34, "Nodes evaluated stat must be preserved")
	assert(boss.get("_last_received_action") == "TREMOR_SLAM", "Boss must store last received action")
	assert(boss.get("last_decision_stats")["pruned_branches"] == 12, "Boss must store decision statistics")
	
	boss.queue_free()
	print("  [PASS] Decision payload reception, statistics caching, and signal emission verified.")


func test_ai_action_execution_tremor_slam() -> void:
	print("[TEST 4/10] Verifying AI action execution: TREMOR_SLAM...")
	var boss: CharacterBody2D = _boss_scene.instantiate()
	add_child(boss)
	
	boss.call("change_state", BossEnemyScript.State.PURSUE)
	boss.set("_last_received_action", "TREMOR_SLAM")
	boss.set("_slam_cooldown_timer", 0.0)
	
	# Execute when in range (100px <= 135px radius * 1.1)
	var handled: bool = boss.call("_try_execute_ai_action", 100.0)
	assert(handled == true, "_try_execute_ai_action must return true for valid TREMOR_SLAM")
	assert(boss.get("current_state") == BossEnemyScript.State.ATTACK, "State must transition to ATTACK")
	assert(boss.get("_chosen_attack") == BossEnemyScript.AttackType.TREMOR_SLAM, "Chosen attack must be TREMOR_SLAM")
	assert(boss.get("_last_received_action") == "", "Last received action must be consumed")
	
	boss.queue_free()
	print("  [PASS] TREMOR_SLAM successfully triggered by AI recommendation.")


func test_ai_action_execution_plasma_barrage() -> void:
	print("[TEST 5/10] Verifying AI action execution: PLASMA_BARRAGE...")
	var boss: CharacterBody2D = _boss_scene.instantiate()
	add_child(boss)
	
	boss.call("change_state", BossEnemyScript.State.PURSUE)
	boss.set("_last_received_action", "PLASMA_BARRAGE")
	boss.set("_barrage_cooldown_timer", 0.0)
	
	# Execute at 240px range
	var handled: bool = boss.call("_try_execute_ai_action", 240.0)
	assert(handled == true, "_try_execute_ai_action must return true for valid PLASMA_BARRAGE")
	assert(boss.get("current_state") == BossEnemyScript.State.ATTACK, "State must transition to ATTACK")
	assert(boss.get("_chosen_attack") == BossEnemyScript.AttackType.PLASMA_BARRAGE, "Chosen attack must be PLASMA_BARRAGE")
	
	boss.queue_free()
	print("  [PASS] PLASMA_BARRAGE successfully triggered by AI recommendation.")


func test_ai_action_execution_charge_rush() -> void:
	print("[TEST 6/10] Verifying AI action execution: CHARGE_RUSH...")
	var boss: CharacterBody2D = _boss_scene.instantiate()
	add_child(boss)
	
	boss.call("change_state", BossEnemyScript.State.PURSUE)
	boss.set("_last_received_action", "CHARGE_RUSH")
	boss.set("_charge_cooldown_timer", 0.0)
	
	# Execute at 180px range
	var handled: bool = boss.call("_try_execute_ai_action", 180.0)
	assert(handled == true, "_try_execute_ai_action must return true for valid CHARGE_RUSH")
	assert(boss.get("current_state") == BossEnemyScript.State.ATTACK, "State must transition to ATTACK")
	assert(boss.get("_chosen_attack") == BossEnemyScript.AttackType.CHARGE_RUSH, "Chosen attack must be CHARGE_RUSH")
	
	boss.queue_free()
	print("  [PASS] CHARGE_RUSH successfully triggered by AI recommendation.")


func test_ai_action_execution_guard_stance() -> void:
	print("[TEST 7/10] Verifying AI action execution: GUARD_STANCE...")
	var boss: CharacterBody2D = _boss_scene.instantiate()
	add_child(boss)
	
	boss.call("change_state", BossEnemyScript.State.PURSUE)
	boss.set("_last_received_action", "GUARD_STANCE")
	
	# Execute at long range (250px)
	var handled: bool = boss.call("_try_execute_ai_action", 250.0)
	assert(handled == true, "_try_execute_ai_action must return true for valid GUARD_STANCE")
	assert(boss.get("current_state") == BossEnemyScript.State.GUARD, "State must transition to GUARD")
	
	boss.queue_free()
	print("  [PASS] GUARD_STANCE successfully triggered by AI recommendation.")


func test_tactical_positioning_velocity() -> void:
	print("[TEST 8/10] Verifying AI tactical positioning and retreat velocity...")
	var boss: CharacterBody2D = _boss_scene.instantiate()
	add_child(boss)
	
	var to_player := Vector2(100, 0)
	boss.set("_last_received_action", "TACTICAL_RETREAT")
	boss.call("_process_pursue_movement", 0.1, to_player, 120.0)
	
	# Retreat moves away from player (-X direction)
	assert(boss.velocity.x < 0.0, "Tactical retreat velocity should point away from player")
	
	# Advance moves toward player (+X direction)
	boss.set("_last_received_action", "PURSUE_ADVANCE")
	boss.call("_process_pursue_movement", 0.1, to_player, 120.0)
	assert(boss.velocity.x > 0.0, "Pursue advance velocity should point toward player")
	
	boss.queue_free()
	print("  [PASS] AI tactical repositioning velocity updates verified.")


func test_safe_fallback_on_backend_failure() -> void:
	print("[TEST 9/10] Verifying safe local fallback on backend timeout/offline...")
	var boss: CharacterBody2D = _boss_scene.instantiate()
	add_child(boss)
	
	var dummy = CharacterBody2D.new()
	dummy.name = "DummyTarget"
	dummy.add_to_group("player")
	var dummy_hc = HealthComponentScript.new()
	dummy_hc.name = "HealthComponent"
	dummy_hc.set("max_health", 100.0)
	dummy_hc.set("current_health", 100.0)
	dummy.add_child(dummy_hc)
	add_child(dummy)
	
	boss.global_position = Vector2.ZERO
	dummy.global_position = Vector2(80, 0)
	boss.call("set_target_player", dummy)
	boss.call("change_state", BossEnemyScript.State.PURSUE)
	
	# Simulate backend failure response
	var fail_response := {
		"success": false,
		"error": "Connection timed out",
		"data": {}
	}
	boss.call("_on_ai_decision_result", fail_response)
	assert(boss.get("_is_decision_pending") == false, "Decision pending flag must be cleared on failure")
	assert(boss.get("_last_received_action") == "", "Last received action must remain empty on failure")
	
	# Step pursue process - must smoothly fall back to local rule-based attack evaluation without throwing errors
	boss.set("_slam_cooldown_timer", 0.0)
	boss.call("_process_pursue", 0.016)
	
	# Boss should have engaged attack via local fallback
	assert(boss.get("current_state") == BossEnemyScript.State.ATTACK, "Boss must smoothly trigger attack via local fallback")
	assert(boss.get("_chosen_attack") == BossEnemyScript.AttackType.TREMOR_SLAM, "Local fallback selected TREMOR_SLAM")
	
	boss.queue_free()
	dummy.queue_free()
	print("  [PASS] Safe local fallback flawlessly handles backend offline/timeout.")


func test_non_blocking_async_responsiveness() -> void:
	print("[TEST 10/10] Verifying non-blocking asynchronous responsiveness...")
	var boss: CharacterBody2D = _boss_scene.instantiate()
	add_child(boss)
	
	var dummy = CharacterBody2D.new()
	dummy.name = "DummyTarget"
	dummy.add_to_group("player")
	var dummy_hc = HealthComponentScript.new()
	dummy_hc.name = "HealthComponent"
	dummy_hc.set("max_health", 100.0)
	dummy_hc.set("current_health", 100.0)
	dummy.add_child(dummy_hc)
	add_child(dummy)
	
	boss.global_position = Vector2.ZERO
	dummy.global_position = Vector2(300, 0)
	boss.call("set_target_player", dummy)
	boss.call("change_state", BossEnemyScript.State.PURSUE)
	boss.set("_barrage_cooldown_timer", 3.0)
	boss.set("_slam_cooldown_timer", 3.0)
	boss.set("_charge_cooldown_timer", 5.0)
	
	# Simulate multiple physics frames while decision request is pending
	boss.set("_is_decision_pending", true)
	for i in range(10):
		boss.call("_process_pursue", 0.016)
		assert(boss.velocity.length() > 0.0, "Boss must continue moving smoothly while AI request is pending")
	
	boss.queue_free()
	dummy.queue_free()
	print("  [PASS] Seamless non-blocking asynchronous movement verified.")
