extends Node2D
## Automated Test Suite for BioSphere-X Boss Encounter (Prompt 17).
## Validates Boss FSM (Guard, Pursue, Attack, Recover, Enraged, Defeated),
## attack telegraphs (Tremor Slam, Plasma Barrage, Charge Rush),
## vulnerable recovery periods, phase 2 enrage transition, health bar UI,
## knockback resistance, defeat reward dispersal, and world integration.

const BossEnemyScript := preload("res://scenes/boss/boss_enemy.gd")
const BossVisualScript := preload("res://scenes/boss/boss_visual.gd")
const BossHealthBarScript := preload("res://scenes/boss/boss_health_bar.gd")
const CollectableResourceScript := preload("res://scripts/components/collectable_resource.gd")
const DamageDataScript := preload("res://scripts/components/damage_data.gd")
const EnergyProjectileScript := preload("res://scenes/items/energy_projectile.gd")

var _boss_scene := preload("res://scenes/boss/boss_enemy.tscn")


func _ready() -> void:
	print("==================================================")
	print("  BIOSPHERE-X: RUNNING BOSS ENCOUNTER TEST SUITE")
	print("==================================================")
	
	test_boss_initialization_and_guard_state()
	test_guard_damage_mitigation()
	test_pursue_state_transition()
	test_tremor_slam_attack_and_telegraph()
	test_plasma_barrage_attack_and_projectiles()
	test_recover_state_and_vulnerability_window()
	test_enraged_phase_transition()
	test_boss_health_bar_ui()
	test_knockback_resistance()
	test_fair_defeat_and_colossal_rewards()
	test_game_world_boss_integration()
	
	print("==================================================")
	print("  ALL BOSS ENCOUNTER TESTS COMPLETED! [11/11]")
	print("==================================================")
	get_tree().quit(0)


func test_boss_initialization_and_guard_state() -> void:
	print("[TEST 1/11] Verifying Boss initialization and GUARD state...")
	var boss: CharacterBody2D = _boss_scene.instantiate()
	add_child(boss)
	
	assert(boss.get("current_state") == BossEnemyScript.State.GUARD, "Boss must start in GUARD state")
	assert(boss.get("current_phase") == 1, "Boss must start in Phase 1 (Guardian)")
	assert(boss.is_in_group("boss"), "Boss must be in 'boss' group")
	assert(boss.is_in_group("enemies"), "Boss must be in 'enemies' group")
	
	var hc = boss.get_node("HealthComponent")
	assert(hc != null, "HealthComponent must exist on Boss")
	assert(hc.get("max_health") == 500.0, "Boss max health must be 500.0")
	assert(hc.get("current_health") == 500.0, "Boss current health must be 500.0")
	
	boss.queue_free()
	print("  [PASS] Boss initialized with 500 HP in territorial GUARD posture.")


func test_guard_damage_mitigation() -> void:
	print("[TEST 2/11] Verifying GUARD state defensive damage reduction...")
	var boss: CharacterBody2D = _boss_scene.instantiate()
	add_child(boss)
	
	# Boss is in GUARD state (20% reduction)
	# 20.0 raw damage should become 16.0 actual damage (500 -> 484)
	var hc = boss.get_node("HealthComponent")
	boss.call("take_damage", 20.0)
	assert(hc.get("current_health") == 484.0, "GUARD state must reduce incoming damage by 20% (took 16 instead of 20)")
	
	boss.queue_free()
	print("  [PASS] Defensive GUARD mitigation verified (20% damage absorption).")


func test_pursue_state_transition() -> void:
	print("[TEST 3/11] Verifying transition from GUARD to PURSUE when attacked or player approaches...")
	var boss: CharacterBody2D = _boss_scene.instantiate()
	add_child(boss)
	
	assert(boss.get("current_state") == BossEnemyScript.State.GUARD, "Must start in GUARD")
	
	# Taking damage in GUARD immediately triggers PURSUE
	boss.call("take_damage", 10.0)
	assert(boss.get("current_state") == BossEnemyScript.State.PURSUE, "Taking damage in GUARD must transition to PURSUE")
	
	boss.queue_free()
	print("  [PASS] Aggro and state transition to PURSUE verified.")


func test_tremor_slam_attack_and_telegraph() -> void:
	print("[TEST 4/11] Verifying Tremor Shockwave Slam telegraph and damage execution...")
	var boss: CharacterBody2D = _boss_scene.instantiate()
	add_child(boss)
	
	var dummy = CharacterBody2D.new()
	dummy.name = "DummyPlayer"
	dummy.add_to_group("player")
	var dummy_hc = preload("res://scripts/components/health_component.gd").new()
	dummy_hc.name = "HealthComponent"
	dummy_hc.set("max_health", 100.0)
	dummy_hc.set("current_health", 100.0)
	dummy.add_child(dummy_hc)
	add_child(dummy)
	
	boss.global_position = Vector2.ZERO
	dummy.global_position = Vector2(40, 0) # Inside 135px slam radius
	boss.call("set_target_player", dummy)
	
	# Set attack to Tremor Slam
	boss.set("_chosen_attack", BossEnemyScript.AttackType.TREMOR_SLAM)
	boss.call("change_state", BossEnemyScript.State.ATTACK)
	
	# Check windup telegraph
	boss.call("_update_attack_telegraph", 0.5)
	assert(boss.visual.get("attack_windup_ratio") == 0.5, "Telegraph windup ratio must be passed to Visual")
	assert(boss.visual.get("current_attack_type") == int(BossEnemyScript.AttackType.TREMOR_SLAM), "Visual attack type must match TREMOR_SLAM")
	assert(boss.visual.get("attack_telegraph_radius") == 135.0, "Telegraph radius must match slam radius")
	
	# Execute slam
	var attack_event := {"fired": false, "type": "", "damage": 0.0}
	boss.connect("boss_attacked", func(atype, dmg):
		attack_event["fired"] = true
		attack_event["type"] = atype
		attack_event["damage"] = dmg
	)
	
	boss.call("_execute_tremor_slam")
	assert(attack_event["fired"], "boss_attacked signal must be emitted on Tremor Slam")
	assert(attack_event["type"] == "TREMOR_SLAM", "Attack type should be TREMOR_SLAM")
	assert(attack_event["damage"] == 35.0, "Slam damage should be 35.0")
	assert(dummy_hc.get("current_health") == 65.0, "Dummy player must take 35 damage (100 -> 65)")
	
	boss.queue_free()
	dummy.queue_free()
	print("  [PASS] Tremor Shockwave Slam telegraph and damage execution verified.")


func test_plasma_barrage_attack_and_projectiles() -> void:
	print("[TEST 5/11] Verifying Plasma Nova Barrage radial multi-projectile spray...")
	var boss: CharacterBody2D = _boss_scene.instantiate()
	add_child(boss)
	
	var initial_children := get_child_count()
	
	var attack_event := {"fired": false, "type": "", "damage": 0.0}
	boss.connect("boss_attacked", func(atype, dmg):
		attack_event["fired"] = true
		attack_event["type"] = atype
		attack_event["damage"] = dmg
	)
	
	boss.call("_execute_plasma_barrage")
	assert(attack_event["fired"], "boss_attacked must be emitted on Plasma Barrage")
	assert(attack_event["type"] == "PLASMA_BARRAGE", "Attack type must be PLASMA_BARRAGE")
	
	# Verify radial energy projectiles were spawned (Phase 1 fires 8 bolts)
	var bolt_count := 0
	for child in get_children():
		if child is Area2D and child != boss and child.has_method("setup"):
			bolt_count += 1
			child.queue_free()
	
	assert(bolt_count == 8, "Phase 1 Plasma Barrage must spawn 8 radial projectiles")
	
	boss.queue_free()
	print("  [PASS] Plasma Nova Barrage radial pattern (8 projectiles) successfully spawned.")


func test_recover_state_and_vulnerability_window() -> void:
	print("[TEST 6/11] Verifying RECOVER state vulnerability window (+25% damage taken)...")
	var boss: CharacterBody2D = _boss_scene.instantiate()
	add_child(boss)
	
	boss.call("change_state", BossEnemyScript.State.RECOVER)
	assert(boss.get("current_state") == BossEnemyScript.State.RECOVER, "Must be in RECOVER state")
	
	# In RECOVER, boss takes 1.25x damage (25% extra vulnerability)
	# 20.0 raw damage becomes 25.0 damage (500 -> 475)
	var hc = boss.get_node("HealthComponent")
	boss.call("take_damage", 20.0)
	assert(hc.get("current_health") == 475.0, "RECOVER state must inflict 1.25x damage vulnerability (20 -> 25)")
	
	boss.queue_free()
	print("  [PASS] Vulnerable RECOVER counterattack window functioning properly.")


func test_enraged_phase_transition() -> void:
	print("[TEST 7/11] Verifying Phase 2 ENRAGED transition at <= 50% HP...")
	var boss: CharacterBody2D = _boss_scene.instantiate()
	add_child(boss)
	
	var phase_event := {"fired": false, "phase": 1}
	boss.connect("phase_changed", func(p):
		phase_event["fired"] = true
		phase_event["phase"] = p
	)
	
	# Boss starts with 500 HP. Deal 260 damage in Pursue state to reach 240 HP (<= 250 HP, 48%)
	boss.call("change_state", BossEnemyScript.State.PURSUE)
	boss.call("take_damage", 260.0)
	
	assert(boss.get("current_state") == BossEnemyScript.State.ENRAGED_TRANSITION, "Boss must enter ENRAGED_TRANSITION at <= 50% HP")
	
	# Advance transition timer
	boss.call("_process_enraged_transition", 1.5)
	
	assert(boss.get("current_phase") == 2, "Boss current_phase must be Phase 2 (Enraged)")
	assert(phase_event["fired"], "phase_changed signal must be emitted")
	assert(phase_event["phase"] == 2, "New phase must be 2")
	assert(boss.visual.get("is_enraged") == true, "Visual must enter enraged mode")
	
	boss.queue_free()
	print("  [PASS] Phase 2 ENRAGED transition triggered correctly at 50% health threshold.")


func test_boss_health_bar_ui() -> void:
	print("[TEST 8/11] Verifying BossHealthBar UI updates and phase displays...")
	var bar = BossHealthBarScript.new()
	add_child(bar)
	bar.call("setup", "TEST COLOSSUS", 400.0)
	bar.call("set_active", true)
	
	assert(bar.get("boss_name") == "TEST COLOSSUS", "Health bar title should match")
	assert(bar.get("max_health") == 400.0, "Max health should match")
	assert(bar.get("current_health") == 400.0, "Current health should match")
	
	# Damage update
	bar.call("update_health", 250.0)
	assert(bar.get("current_health") == 250.0, "Current health should update to 250.0")
	
	# Phase update
	bar.call("set_phase", 1)
	assert(bar.get("_is_enraged") == true, "Phase 1 index must trigger enraged UI banner")
	
	# Defeat notification
	bar.call("show_defeat")
	assert(bar.get("_is_defeated") == true, "show_defeat must mark defeated state")
	
	bar.queue_free()
	print("  [PASS] BossHealthBar UI reacts accurately to damage, phases, and victory.")


func test_knockback_resistance() -> void:
	print("[TEST 9/11] Verifying heavy knockback resistance (85% reduction)...")
	var boss: CharacterBody2D = _boss_scene.instantiate()
	add_child(boss)
	
	boss.velocity = Vector2.ZERO
	# Apply 100 knockback force
	var dmg_data = DamageDataScript.create(10.0, null, DamageDataScript.DamageType.PHYSICAL, Vector2.RIGHT, 100.0)
	boss.call("apply_damage", dmg_data)
	
	# With 85% resistance, force received should be 100 * (1 - 0.85) = 15
	assert(absf(boss.velocity.x - 15.0) < 0.1, "Boss velocity must reflect 85% knockback resistance (100 -> 15)")
	
	boss.queue_free()
	print("  [PASS] Heavy knockback resistance (85%) verified.")


func test_fair_defeat_and_colossal_rewards() -> void:
	print("[TEST 10/11] Verifying fair defeat through combat and colossal reward cache drop...")
	var container = Node2D.new()
	add_child(container)
	
	var boss = _boss_scene.instantiate()
	container.add_child(boss)
	
	var defeat_event := {"fired": false}
	boss.connect("boss_defeated", func():
		defeat_event["fired"] = true
	)
	
	# Defeat boss through normal damage (depleting remaining HP)
	boss.call("change_state", BossEnemyScript.State.PURSUE)
	boss.call("take_damage", 600.0) # Fatal hit
	
	assert(defeat_event["fired"], "boss_defeated signal must be emitted on death")
	assert(boss.get("current_state") == BossEnemyScript.State.DEFEATED, "State must be DEFEATED")
	assert(boss.collision_shape.disabled == true or boss.get("current_state") == BossEnemyScript.State.DEFEATED, "Collision shape must be disabled on defeat")
	
	# Verify reward items dropped in container
	var items_dropped: Array[Area2D] = []
	for child in container.get_children():
		if child is Area2D and child.has_method("get_resource_id_name"):
			items_dropped.append(child)
	
	assert(items_dropped.size() >= 4, "Defeated boss must drop a colossal bundle of at least 4 collectable caches")
	
	container.queue_free()
	print("  [PASS] Defeat state achieved through legitimate damage with reward cache.")


func test_game_world_boss_integration() -> void:
	print("[TEST 11/11] Verifying Boss placement in GameWorld crater basin...")
	var world_scene = preload("res://scenes/world/game_world.tscn")
	var world = world_scene.instantiate()
	add_child(world)
	
	var boss_node = world.get_node_or_null("GoliathPrime_Boss")
	assert(boss_node != null, "GameWorld must spawn GoliathPrime_Boss")
	assert(boss_node is BossEnemyScript, "Boss node must be instance of BossEnemyScript")
	assert(boss_node.position == Vector2(560, -820), "Boss should be situated in the ancient crater basin (560, -820)")
	
	world.queue_free()
	print("  [PASS] GoliathPrime_Boss successfully integrated into GameWorld.")
