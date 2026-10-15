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
	assert(enemy.patrol_speed == 75.0, "Patrol speed matches default")
	assert(enemy.chase_speed == 160.0, "Chase speed matches default")
	assert(enemy.detection_range == 240.0, "Detection range matches default")
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
	# 3. State Transition: PATROL -> CHASE (Player Detection)
	# -----------------------------------------------------------------------
	var player = PlayerScene.instantiate()
	player.position = Vector2(580, 500) # 80 pixels away (within 240 detection range)
	add_child(player)
	
	var state_history: Array[int] = []
	enemy.state_changed.connect(func(_old, new_s: int):
		state_history.append(new_s)
	)
	
	enemy._physics_process(0.016)
	assert(enemy.current_state == EnemyClass.State.CHASE, "Enemy must detect player and transition to CHASE")
	enemy._physics_process(0.016)
	assert(enemy.velocity.x > 0.0, "Enemy chase velocity should point toward player")
	print("  [PASS] PATROL -> CHASE transition verified")
	
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
	
	print("--- All BioSphere-X Alien Enemy Tests Passed Successfully! ---")
	get_tree().quit(0)
