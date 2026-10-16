extends Node
## Automated test suite for BioSphere-X Alien Enemy Characters and State Machine.
## Validates States (Idle, Patrol, Investigate, Chase, Attack, Dead), detection ranges,
## player tracking, combat strikes, and death freeze.

const EnemyClass = preload("res://scenes/enemies/alien_enemy.gd")
const EnemyScene = preload("res://scenes/enemies/alien_enemy.tscn")
const PlayerScene = preload("res://scenes/player/player.tscn")

func _ready() -> void:
	print("--- Running BioSphere-X Alien Enemy & State Machine Tests ---")
	_run_tests()


func _run_tests() -> void:
	var gs := get_node("/root/GameState")
	assert(gs != null, "GameState autoload must exist")
	gs.call("restart_game")
	
	# -----------------------------------------------------------------------
	# 1. Instantiation and Component Hierarchy
	# -----------------------------------------------------------------------
	var enemy = EnemyScene.instantiate()
	enemy.position = Vector2(500, 500)
	add_child(enemy)
	
	var col: CollisionShape2D = enemy.get_node("CollisionShape2D")
	var visual: Node2D = enemy.get_node("Visual")
	var health_comp = enemy.get_node("HealthComponent")
	
	assert(col != null, "Enemy must have CollisionShape2D")
	assert(visual != null, "Enemy must have Visual node")
	assert(health_comp != null, "Enemy must have HealthComponent")
	health_comp.set("invulnerability_time", 0.0)
	assert(enemy.current_state == EnemyClass.State.IDLE, "Enemy must initially spawn in State.IDLE")
	assert(enemy.patrol_speed == 75.0 or enemy.patrol_speed == 110.0, "Patrol speed matches default")
	assert(enemy.chase_speed == 160.0 or enemy.chase_speed == 210.0, "Chase speed matches default")
	assert(enemy.detection_range == 240.0 or enemy.detection_range == 320.0, "Detection range matches default")
	print("  [PASS] Enemy component hierarchy and initial state verified")
	
	# -----------------------------------------------------------------------
	# 2. State Transition: IDLE -> PATROL
	# -----------------------------------------------------------------------
	enemy._idle_timer = 0.05
	enemy._physics_process(0.1) # Simulate idle timer expiration
	assert(enemy.current_state == EnemyClass.State.PATROL, "Enemy must transition from IDLE to PATROL")
	assert(enemy.velocity.length() > 0.0 or enemy.patrol_target != Vector2.ZERO, "Patrol target must be active")
	print("  [PASS] IDLE -> PATROL transition verified")
	
	# -----------------------------------------------------------------------
	# 3. State Transition: PATROL -> CHASE (Player Detection & Reaction Delay)
	# -----------------------------------------------------------------------
	var player = PlayerScene.instantiate()
	player.position = Vector2(580, 500) # 80 pixels away (within 240 detection range)
	add_child(player)
	
	var state_history: Array[int] = []
	enemy.state_changed.connect(func(_old, new_s: int):
		state_history.append(new_s)
	)
	
	# Simulate spotting player and verify fair reaction delay
	enemy._physics_process(0.016)
	if enemy.reaction_delay > 0.016:
		assert(enemy.current_state == EnemyClass.State.PATROL or enemy.current_state == EnemyClass.State.IDLE, "Enemy must honor reaction delay before initiating chase")
		# Advance past reaction delay
		enemy._physics_process(enemy.reaction_delay + 0.05)
	
	assert(enemy.current_state == EnemyClass.State.CHASE, "Enemy must detect player and transition to CHASE after reaction delay")
	enemy._physics_process(0.016)
	assert(enemy.velocity.x > 0.0, "Enemy chase velocity should point toward player")
	print("  [PASS] PATROL -> CHASE transition and reaction delay verified")

	
	# -----------------------------------------------------------------------
	# 4. State Transition: CHASE -> ATTACK & Combat Strike
	# -----------------------------------------------------------------------
	# Move player directly within attack range (30 pixels away)
	player.position = Vector2(525, 500)
	enemy._cooldown_timer = 0.0
	enemy._physics_process(0.016)
	assert(enemy.current_state == EnemyClass.State.ATTACK, "Enemy must transition to ATTACK when in attack range")
	
	var initial_player_hp: float = player.get_current_health()
	var attack_fired: Dictionary = {"called": false, "damage": 0.0}
	enemy.enemy_attacked.connect(func(_target, dmg: float):
		attack_fired["called"] = true
		attack_fired["damage"] = dmg
	)
	
	# Process attack windup time
	enemy._physics_process(enemy.attack_windup_time + 0.05)
	assert(attack_fired["called"] == true, "enemy_attacked signal must fire on strike")
	assert(attack_fired["damage"] == enemy.attack_damage, "Attack damage matches configured stat")
	assert(player.get_current_health() < initial_player_hp, "Player must take damage from enemy attack")
	assert(enemy._cooldown_timer > 0.0, "Attack cooldown timer must be active")
	print("  [PASS] CHASE -> ATTACK and combat strike damage verified")
	
	# -----------------------------------------------------------------------
	# 5. State Transition: CHASE -> INVESTIGATE (Player Escapes)
	# -----------------------------------------------------------------------
	# Move player far beyond lose_interest_range (500 pixels away)
	player.position = Vector2(1200, 500)
	enemy.change_state(EnemyClass.State.CHASE)
	enemy._physics_process(0.016)
	assert(enemy.current_state == EnemyClass.State.INVESTIGATE, "Enemy must transition to INVESTIGATE when player escapes")
	assert(enemy.last_known_player_pos != Vector2.ZERO, "Enemy must remember last known player position")
	print("  [PASS] CHASE -> INVESTIGATE upon player escape verified")
	
	# -----------------------------------------------------------------------
	# 6. State Transition: INVESTIGATE -> IDLE/PATROL (Timer Expiry)
	# -----------------------------------------------------------------------
	enemy._investigate_timer = 0.05
	enemy._physics_process(0.1)
	assert(enemy.current_state == EnemyClass.State.IDLE or enemy.current_state == EnemyClass.State.PATROL, "Enemy must return to IDLE/PATROL after investigation")
	print("  [PASS] INVESTIGATE -> IDLE/PATROL return verified")
	
	# -----------------------------------------------------------------------
	# 7. Health, Damage & DEAD State
	# -----------------------------------------------------------------------
	var enemy_hit_called: Dictionary = {"called": false}
	enemy.enemy_damaged.connect(func(_amt, _cur, _mx):
		enemy_hit_called["called"] = true
	)
	
	# Take non-lethal damage
	var damaged: bool = enemy.take_damage(20.0, player)
	assert(damaged == true, "take_damage should succeed")
	assert(enemy_hit_called["called"] == true, "enemy_damaged signal emitted")
	assert(enemy.current_state == EnemyClass.State.CHASE, "Taking damage must alert enemy into CHASE state")
	
	# Lethal damage
	var enemy_died_called: Dictionary = {"called": false}
	enemy.enemy_died.connect(func(_e):
		enemy_died_called["called"] = true
	)
	
	enemy.take_damage(100.0, player)
	assert(enemy.current_state == EnemyClass.State.DEAD, "Enemy must transition to DEAD state upon lethal damage")
	assert(enemy_died_called["called"] == true, "enemy_died signal emitted")
	assert(col.disabled == true, "Collision shape must be disabled on death")
	
	# Verify dead enemy is frozen
	enemy.velocity = Vector2(200, 200)
	enemy._physics_process(0.016)
	assert(enemy.velocity == Vector2.ZERO, "Dead enemy velocity must remain Vector2.ZERO")
	
	# Subsequent damage should return false
	assert(enemy.take_damage(10.0) == false, "Dead enemy cannot take further damage")
	print("  [PASS] Health damage, retaliation alert, and DEAD freeze verified")
	
	enemy.queue_free()
	player.queue_free()
	
	# -----------------------------------------------------------------------
	# 8. Perception Rules & Line of Sight Obstruction
	# -----------------------------------------------------------------------
	var MapDataClass = preload("res://scripts/components/map_data.gd")
	var test_map = MapDataClass.new(Vector2i(20, 20), 32.0, Vector2.ZERO)
	var nav_mgr = get_node_or_null("/root/NavigationManager")
	if nav_mgr and nav_mgr.has_method("set_map_data"):
		nav_mgr.call("set_map_data", test_map)
	
	var sight_enemy = EnemyScene.instantiate()
	sight_enemy.position = test_map.grid_to_world(Vector2i(2, 2))
	add_child(sight_enemy)
	
	var sight_player = PlayerScene.instantiate()
	sight_player.position = test_map.grid_to_world(Vector2i(6, 2)) # 128 px away (within 240 detection range)
	add_child(sight_player)
	
	# Open line of sight
	assert(sight_enemy.has_line_of_sight_to(sight_player.global_position) == true, "Open corridor must provide clear line of sight")
	assert(sight_enemy._can_detect_player() == true, "Player in open corridor must be detectable")
	
	# Place wall obstacle in between at (4, 2)
	test_map.set_cell_blocked(Vector2i(4, 2), true, MapDataClass.CellType.WALL)
	assert(sight_enemy.has_line_of_sight_to(sight_player.global_position) == false, "Wall obstacle must block line of sight")
	assert(sight_enemy._can_detect_player() == false, "Enemy must not detect player through solid wall when requires_line_of_sight is true")
	
	# Test wall-penetrating enemy variant (can_see_through_walls = true)
	sight_enemy.can_see_through_walls = true
	assert(sight_enemy.has_line_of_sight_to(sight_player.global_position) == true, "can_see_through_walls=true must see through walls")
	assert(sight_enemy._can_detect_player() == true, "Wall-penetrating enemy variant must detect player through walls")
	print("  [PASS] Line of sight perception and wall obstruction verified")
	
	# -----------------------------------------------------------------------
	# 9. Attack Wall Obstruction
	# -----------------------------------------------------------------------
	# Position player on other side of a 1-tile wall within attack range
	sight_enemy.can_see_through_walls = false
	sight_enemy.can_attack_through_walls = false
	sight_enemy.position = test_map.grid_to_world(Vector2i(3, 2)) # Adjacent to wall at (4, 2)
	sight_player.position = test_map.grid_to_world(Vector2i(5, 2)) # Adjacent to other side of wall (64px away)
	sight_enemy.attack_range = 70.0 # Force within attack range
	
	var hp_before: float = float(sight_player.get_current_health())
	sight_enemy._execute_attack_strike()
	assert(sight_player.get_current_health() == hp_before, "Enemy cannot attack or deal damage through solid wall")
	
	# Allow wall-phase attacks for ethereal enemy variants
	sight_enemy.can_attack_through_walls = true
	sight_enemy._execute_attack_strike()
	assert(sight_player.get_current_health() < hp_before, "can_attack_through_walls=true permits striking through walls")
	print("  [PASS] Attack strike wall blocking and phasing override verified")
	
	sight_enemy.queue_free()
	sight_player.queue_free()
	
	# -----------------------------------------------------------------------
	# 10. Deterministic Seeded Random Number Generator
	# -----------------------------------------------------------------------
	var enemy_a = EnemyScene.instantiate()
	var enemy_b = EnemyScene.instantiate()
	add_child(enemy_a)
	add_child(enemy_b)
	
	enemy_a.set_rng_seed(98765)
	enemy_b.set_rng_seed(98765)
	
	var seq_a: Array[float] = []
	var seq_b: Array[float] = []
	for i in 10:
		seq_a.append(enemy_a._randf_range(1.0, 100.0))
		seq_b.append(enemy_b._randf_range(1.0, 100.0))
	
	assert(seq_a == seq_b, "Enemies sharing the same seed must produce identical deterministic sequences")
	
	# Divergent seed
	enemy_b.set_rng_seed(11111)
	var div_b: float = enemy_b._randf_range(1.0, 100.0)
	var next_a: float = enemy_a._randf_range(1.0, 100.0)
	assert(next_a != div_b, "Enemies with different seeds must produce different sequences")
	print("  [PASS] Deterministic seeded RNG variation verified")
	
	enemy_a.queue_free()
	enemy_b.queue_free()
	
	print("--- All BioSphere-X Alien Enemy Tests Passed Successfully! ---")
	get_tree().quit(0)

