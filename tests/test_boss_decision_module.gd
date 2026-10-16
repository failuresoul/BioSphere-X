extends Node2D
## Comprehensive Automated Test Suite for BioSphere-X Boss Decision-Making Module (Prompt 18).
## Validates:
## 1. BossDecisionModule interface contract.
## 2. BossCombatState: turn-based state representation, legal actions, transition rules,
##    terminal conditions, and heuristic evaluation.
## 3. BossAlphaBetaDecision: Minimax search with Alpha-Beta pruning, depth limits, and pruning statistics.
## 4. BossActionAdapter: action validation, controller command translation, and safe fallback handling.
## 5. BossEnemy integration: seamless real-time execution, custom module injection, and disabled safety.

const BossEnemyScript := preload("res://scenes/boss/boss_enemy.gd")
const BossDecisionModuleScript := preload("res://scenes/boss/decision/boss_decision_module.gd")
const BossCombatStateScript := preload("res://scenes/boss/decision/boss_combat_state.gd")
const BossAlphaBetaDecisionScript := preload("res://scenes/boss/decision/boss_alpha_beta_decision.gd")
const BossActionAdapterScript := preload("res://scenes/boss/decision/boss_action_adapter.gd")
const HealthComponentScript := preload("res://scripts/components/health_component.gd")

var _boss_scene := preload("res://scenes/boss/boss_enemy.tscn")


func _ready() -> void:
	print("==================================================")
	print("  BIOSPHERE-X: BOSS DECISION MODULE TEST SUITE")
	print("==================================================")
	
	test_decision_module_interface_contract()
	test_combat_state_representation_and_cloning()
	test_combat_state_legal_actions_and_cooldowns()
	test_combat_state_transition_rules_and_enrage()
	test_combat_state_terminal_conditions_and_evaluation()
	test_alpha_beta_decision_algorithm_and_pruning()
	test_action_adapter_real_time_validation()
	test_action_adapter_safe_fallback_on_invalid_action()
	test_action_adapter_safe_fallback_when_disabled()
	test_boss_enemy_controller_decision_integration()
	
	print("==================================================")
	print("  ALL PROMPT 18 TESTS COMPLETED! [10/10]")
	print("==================================================")
	get_tree().quit(0)


func test_decision_module_interface_contract() -> void:
	print("[TEST 1/10] Verifying BossDecisionModule base interface contract...")
	var base_module = BossDecisionModuleScript.new()
	assert(base_module.has_method("choose_action"), "Base module must declare choose_action")
	assert(base_module.has_method("get_module_name"), "Base module must declare get_module_name")
	
	var default_res = base_module.choose_action({})
	assert(default_res.has("action"), "Response must contain 'action'")
	assert(default_res.has("score"), "Response must contain 'score'")
	assert(default_res.has("statistics"), "Response must contain 'statistics'")
	assert(base_module.get_module_name() == "BaseDecisionModule", "Module name should match base")
	print("  [PASS] Base decision module interface contract verified.")


func test_combat_state_representation_and_cloning() -> void:
	print("[TEST 2/10] Verifying BossCombatState variables and deep cloning...")
	var state = BossCombatStateScript.new()
	state.boss_hp = 420.0
	state.boss_phase = 1
	state.distance = 180.0
	state.slam_cooldown = 1.5
	state.player_hp = 85.0
	state.player_energy = 60.0
	
	var clone = state.clone()
	assert(clone != state, "Clone must be a distinct object reference")
	assert(clone.boss_hp == 420.0, "Cloned boss HP must match")
	assert(clone.distance == 180.0, "Cloned distance must match")
	assert(clone.player_hp == 85.0, "Cloned player HP must match")
	
	# Modify clone and verify original is unaffected
	clone.boss_hp = 100.0
	assert(state.boss_hp == 420.0, "Modifying clone must not alter original state")
	print("  [PASS] Combat state variables and deep cloning verified.")


func test_combat_state_legal_actions_and_cooldowns() -> void:
	print("[TEST 3/10] Verifying legal actions under range and cooldown constraints...")
	var state = BossCombatStateScript.new()
	state.distance = 100.0
	state.slam_cooldown = 0.0
	state.barrage_cooldown = 0.0
	state.charge_cooldown = 0.0
	
	var actions = state.get_legal_actions()
	assert(BossCombatStateScript.ACTION_TREMOR_SLAM in actions, "Tremor Slam should be legal at dist 100 with cd 0")
	assert(BossCombatStateScript.ACTION_PLASMA_BARRAGE in actions, "Plasma Barrage should be legal")
	assert(BossCombatStateScript.ACTION_CHARGE_RUSH in actions, "Charge Rush should be legal")
	assert(BossCombatStateScript.ACTION_GUARD_STANCE in actions, "Guard Stance should be legal")
	
	# Put Tremor Slam on cooldown
	state.slam_cooldown = 3.0
	var no_slam_actions = state.get_legal_actions()
	assert(not (BossCombatStateScript.ACTION_TREMOR_SLAM in no_slam_actions), "Tremor Slam should be illegal on cooldown")
	
	# Move far away (> 145px)
	state.slam_cooldown = 0.0
	state.distance = 250.0
	var far_actions = state.get_legal_actions()
	assert(not (BossCombatStateScript.ACTION_TREMOR_SLAM in far_actions), "Tremor Slam should be illegal beyond 145px")
	
	# Recovery lock
	state.is_recovering = true
	state.recover_timer = 1.0
	var recover_actions = state.get_legal_actions()
	assert(recover_actions == [BossCombatStateScript.ACTION_RECOVER_WAIT], "Recovery state should only allow RECOVER_WAIT")
	print("  [PASS] Legal actions correctly governed by cooldowns, ranges, and recovery status.")


func test_combat_state_transition_rules_and_enrage() -> void:
	print("[TEST 4/10] Verifying transition rules, damage calculation, and Phase 2 enrage...")
	var state = BossCombatStateScript.new()
	state.boss_hp = 265.0
	state.boss_max_hp = 500.0
	state.boss_phase = 1
	state.distance = 120.0
	state.slam_cooldown = 0.0
	state.player_hp = 100.0
	
	# Boss performs Tremor Slam
	var next = state.apply_action(BossCombatStateScript.ACTION_TREMOR_SLAM)
	assert(next.turn == "player", "Turn must switch to player after boss action")
	assert(next.player_hp == 65.0, "Player HP should drop by 35 (100 -> 65)")
	assert(next.slam_cooldown > 0.0, "Slam cooldown must be reset")
	assert(next.is_recovering == true, "Boss must enter recovery after slam")
	
	# Player shoots boss
	var p_next = next.apply_action(BossCombatStateScript.ACTION_PLAYER_SHOOT)
	assert(p_next.turn == "boss", "Turn must switch back to boss after player action")
	# 265 - (18 * 1.25 recovery vulnerability = 22.5) = 242.5 <= 250 (50% max hp)
	assert(p_next.boss_hp < 250.0, "Boss should take vulnerable damage")
	assert(p_next.boss_phase == 2, "Boss must automatically enrage to Phase 2 at <= 50% HP")
	print("  [PASS] State transition rules, damage multipliers, and enrage transitions verified.")


func test_combat_state_terminal_conditions_and_evaluation() -> void:
	print("[TEST 5/10] Verifying terminal condition checks and heuristic evaluation...")
	var win_state = BossCombatStateScript.new()
	win_state.boss_hp = 300.0
	win_state.player_hp = 0.0
	assert(win_state.is_terminal() == true, "Player HP 0 must trigger terminal state")
	assert(win_state.evaluate() > 5000.0, "Boss victory must produce a strongly positive score")
	
	var loss_state = BossCombatStateScript.new()
	loss_state.boss_hp = 0.0
	loss_state.player_hp = 80.0
	assert(loss_state.is_terminal() == true, "Boss HP 0 must trigger terminal state")
	assert(loss_state.evaluate() < -5000.0, "Boss defeat must produce a strongly negative score")
	
	var ready_state = BossCombatStateScript.new()
	ready_state.distance = 100.0
	ready_state.slam_cooldown = 0.0
	var unready_state = BossCombatStateScript.new()
	unready_state.distance = 100.0
	unready_state.slam_cooldown = 4.0
	assert(ready_state.evaluate() > unready_state.evaluate(), "Ready high-damage cooldowns must evaluate higher")
	print("  [PASS] Terminal states and heuristic evaluation function verified.")


func test_alpha_beta_decision_algorithm_and_pruning() -> void:
	print("[TEST 6/10] Verifying Minimax search with Alpha-Beta pruning...")
	var ab = BossAlphaBetaDecisionScript.new()
	ab.max_depth = 3
	assert(ab.get_module_name() == "MinimaxAlphaBeta", "Module name must identify as MinimaxAlphaBeta")
	
	var ctx := {
		"boss_hp": 480.0,
		"boss_max_hp": 500.0,
		"boss_phase": 1,
		"slam_cooldown": 0.0,
		"barrage_cooldown": 1.0,
		"charge_cooldown": 2.0,
		"distance": 110.0,
		"player_hp": 90.0,
		"player_max_hp": 100.0,
		"player_energy": 80.0
	}
	
	var result = ab.choose_action(ctx)
	assert(result.has("action"), "Decision result must contain action")
	assert(result["action"] in [BossCombatStateScript.ACTION_TREMOR_SLAM, BossCombatStateScript.ACTION_GUARD_STANCE, BossCombatStateScript.ACTION_PURSUE_ADVANCE], "Action must be valid")
	
	var stats: Dictionary = result.get("statistics", {})
	assert(stats["nodes_evaluated"] > 0, "Nodes evaluated must be > 0")
	assert(stats["max_depth_reached"] > 0, "Depth reached must be > 0")
	assert(stats["configured_depth"] == 3, "Configured depth must match 3")
	assert(stats["execution_time_usec"] >= 0, "Execution runtime must be tracked")
	print("  [PASS] Alpha-Beta pruning minimax search successfully selects action with telemetry.")


func test_action_adapter_real_time_validation() -> void:
	print("[TEST 7/10] Verifying BossActionAdapter real-time validation...")
	var boss: CharacterBody2D = _boss_scene.instantiate()
	add_child(boss)
	
	boss.set("_slam_cooldown_timer", 0.0)
	# Distance 100 <= slam radius 135 * 1.15
	assert(BossActionAdapterScript.validate_action(boss, "TREMOR_SLAM", 100.0) == true, "Tremor Slam should validate when ready and in range")
	
	# Distance 200 > slam radius
	assert(BossActionAdapterScript.validate_action(boss, "TREMOR_SLAM", 200.0) == false, "Tremor Slam should reject when out of range")
	
	# Slam on cooldown
	boss.set("_slam_cooldown_timer", 3.0)
	assert(BossActionAdapterScript.validate_action(boss, "TREMOR_SLAM", 100.0) == false, "Tremor Slam should reject when on cooldown")
	
	# Invalid action string
	assert(BossActionAdapterScript.validate_action(boss, "SUPER_LASER_NUKE", 100.0) == false, "Unknown actions must be rejected")
	assert(BossActionAdapterScript.validate_action(boss, "", 100.0) == false, "Empty action must be rejected")
	
	boss.queue_free()
	print("  [PASS] Real-time action validation accurately enforces physics and cooldowns.")


func test_action_adapter_safe_fallback_on_invalid_action() -> void:
	print("[TEST 8/10] Verifying safe fallback when decision module returns invalid action...")
	var boss: CharacterBody2D = _boss_scene.instantiate()
	add_child(boss)
	
	var dummy = CharacterBody2D.new()
	dummy.name = "DummyPlayer"
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
	boss.set("_slam_cooldown_timer", 0.0)
	
	var invalid_decision := {"action": "NON_EXISTENT_UNKNOWN_ACTION"}
	var to_player: Vector2 = dummy.global_position - boss.global_position
	
	# Applying invalid decision should return false (indicating fallback used) and safely trigger local fallback
	var applied: bool = BossActionAdapterScript.apply_decision(
		boss,
		invalid_decision,
		80.0,
		0.016,
		to_player,
		true
	)
	assert(applied == false, "Adapter must return false when fallback is triggered")
	assert(boss.get("current_state") == BossEnemyScript.State.ATTACK, "Safe fallback must transition boss to valid attack state")
	assert(boss.get("_chosen_attack") == BossEnemyScript.AttackType.TREMOR_SLAM, "Safe fallback should engage Tremor Slam at 80px")
	
	boss.queue_free()
	dummy.queue_free()
	print("  [PASS] Safe fallback flawlessly handles invalid decision actions without interruption.")


func test_action_adapter_safe_fallback_when_disabled() -> void:
	print("[TEST 9/10] Verifying safe fallback when decision module is disabled...")
	var boss: CharacterBody2D = _boss_scene.instantiate()
	add_child(boss)
	
	var dummy = CharacterBody2D.new()
	dummy.name = "DummyPlayer"
	dummy.add_to_group("player")
	var dummy_hc = HealthComponentScript.new()
	dummy_hc.name = "HealthComponent"
	dummy.add_child(dummy_hc)
	add_child(dummy)
	
	boss.global_position = Vector2.ZERO
	dummy.global_position = Vector2(250, 0)
	boss.call("set_target_player", dummy)
	boss.call("change_state", BossEnemyScript.State.PURSUE)
	boss.set("_barrage_cooldown_timer", 3.0) # Barrage on cd
	boss.set("_slam_cooldown_timer", 3.0)
	boss.set("_charge_cooldown_timer", 5.0)
	
	var to_player: Vector2 = dummy.global_position - boss.global_position
	
	# Call adapter with is_module_enabled = false
	var applied: bool = BossActionAdapterScript.apply_decision(
		boss,
		{"action": "TREMOR_SLAM"},
		250.0,
		0.016,
		to_player,
		false # Module explicitly disabled
	)
	assert(applied == false, "Adapter must return false when module is disabled")
	# Movement toward player must continue smoothly
	assert(boss.velocity.x > 0.0, "Boss must continue smooth pursuit movement when decision module is disabled")
	
	boss.queue_free()
	dummy.queue_free()
	print("  [PASS] Game remains completely playable when decision module is disabled.")


func test_boss_enemy_controller_decision_integration() -> void:
	print("[TEST 10/10] Verifying full BossEnemy controller decision-making loop...")
	var boss: CharacterBody2D = _boss_scene.instantiate()
	add_child(boss)
	
	assert(boss.get("decision_module") != null, "BossEnemy must instantiate decision_module on ready")
	assert(boss.call("get_decision_module") != null, "get_decision_module must return active module")
	
	var dummy = CharacterBody2D.new()
	dummy.name = "DummyPlayer"
	dummy.add_to_group("player")
	var dummy_hc = HealthComponentScript.new()
	dummy_hc.name = "HealthComponent"
	dummy_hc.set("max_health", 100.0)
	dummy_hc.set("current_health", 100.0)
	dummy.add_child(dummy_hc)
	add_child(dummy)
	
	boss.global_position = Vector2.ZERO
	dummy.global_position = Vector2(75, 0)
	boss.call("set_target_player", dummy)
	boss.call("change_state", BossEnemyScript.State.PURSUE)
	boss.set("_slam_cooldown_timer", 0.0)
	boss.set("_barrage_cooldown_timer", 2.0)
	boss.set("_charge_cooldown_timer", 3.0)
	
	boss.set("_decision_poll_timer", 0.0) # Force decision evaluation
	boss.call("_process_pursue", 0.016)
	
	assert(boss.get("current_state") == BossEnemyScript.State.ATTACK, "Decision module must trigger ATTACK state")
	assert(boss.get("_chosen_attack") == BossEnemyScript.AttackType.TREMOR_SLAM, "Decision module should choose TREMOR_SLAM at close range")
	assert(not boss.get("last_decision_stats").is_empty(), "last_decision_stats must be populated with search metrics")
	
	boss.queue_free()
	dummy.queue_free()
	print("  [PASS] Full BossEnemy controller decision-making loop fully operational.")
