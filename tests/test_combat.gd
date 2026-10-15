extends Node
## Automated Test Suite for BioSphere-X Player Combat System.
## Validates WeaponComponent configuration, attack input, projectile ballistics,
## collision with enemies and world obstacles, multi-hit prevention, cooldowns,
## resource costs (suit energy), and reusable DamageData / HealthComponent interfaces.

const PlayerScene = preload("res://scenes/player/player.tscn")
const EnemyScene = preload("res://scenes/enemies/alien_enemy.tscn")
const ProjectileScene = preload("res://scenes/items/energy_projectile.tscn")
const WeaponCompClass = preload("res://scripts/components/weapon_component.gd")
const DamageDataClass = preload("res://scripts/components/damage_data.gd")


func _ready() -> void:
	print("\n--- Running BioSphere-X Player Combat Tests ---")
	_run_tests()
	print("--- All BioSphere-X Player Combat Tests Passed Successfully! ---\n")
	get_tree().quit(0)


func _run_tests() -> void:
	_test_weapon_component_defaults()
	_test_attack_input_and_projectile_spawning()
	_test_cooldown_and_energy_cost()
	_test_projectile_range_and_expiration()
	_test_projectile_enemy_collision_and_damage()
	_test_multi_hit_prevention()
	_test_world_obstacle_collision()
	_test_reusable_damage_data_interface()


func _test_weapon_component_defaults() -> void:
	var weapon = WeaponCompClass.new()
	add_child(weapon)
	
	assert(weapon.weapon_name == "Plasma Pulse Blaster", "Default weapon name matches")
	assert(weapon.damage == 25.0, "Default weapon damage matches")
	assert(weapon.attack_range == 420.0, "Default weapon range matches")
	assert(weapon.projectile_speed == 520.0, "Default weapon projectile speed matches")
	assert(weapon.attack_cooldown == 0.32, "Default weapon cooldown matches")
	assert(weapon.energy_cost == 8.0, "Default weapon energy cost matches")
	assert(weapon.max_pierce == 1, "Default weapon pierce matches 1")
	assert(weapon.can_attack() == true, "Newly instantiated weapon must be ready to attack")
	
	weapon.queue_free()
	print("  [PASS] WeaponComponent default configuration verified")


func _test_attack_input_and_projectile_spawning() -> void:
	var player = PlayerScene.instantiate()
	player.position = Vector2(200, 200)
	add_child(player)
	
	var fired_data: Dictionary = {"fired": false, "dir": Vector2.ZERO}
	player.player_attacked.connect(func(_proj, dir: Vector2):
		fired_data["fired"] = true
		fired_data["dir"] = dir
	)
	
	var success: bool = player.attack(Vector2(1, 0))
	assert(success == true, "Player attack should succeed")
	assert(fired_data["fired"] == true, "player_attacked signal must fire")
	assert(fired_data["dir"] == Vector2(1, 0), "Attack direction must be Vector2(1, 0)")
	
	player.queue_free()
	print("  [PASS] Attack input and projectile spawning verified")


func _test_cooldown_and_energy_cost() -> void:
	var gs := get_node("/root/GameState")
	assert(gs != null, "GameState required")
	gs.call("restart_game")
	
	var player = PlayerScene.instantiate()
	player.position = Vector2(300, 300)
	add_child(player)
	
	var initial_energy: float = gs.call("get_energy")
	assert(initial_energy == 100.0, "Initial energy should be 100.0")
	
	# First attack consumes energy and starts cooldown
	var shot1: bool = player.attack(Vector2(0, 1))
	assert(shot1 == true, "First shot must succeed")
	assert(gs.call("get_energy") < initial_energy, "Firing weapon must consume suit energy")
	
	# Immediate second attack must fail due to cooldown
	var shot2: bool = player.attack(Vector2(0, 1))
	assert(shot2 == false, "Immediate second shot must fail due to attack cooldown")
	
	# Simulate cooldown timer expiration
	var wc: Node = player.get_node("WeaponComponent")
	wc.call("reset_cooldown")
	assert(wc.call("can_attack") == true, "Weapon must be ready after cooldown reset")
	
	# Deplete all energy to test resource constraint
	gs.call("use_energy", 100.0)
	assert(gs.call("get_energy") == 0.0, "Energy should be completely depleted")
	var shot_no_energy: bool = player.attack(Vector2(1, 0))
	assert(shot_no_energy == false, "Attack must fail when suit energy is insufficient")
	
	# Refill energy
	gs.call("refill_energy")
	assert(gs.call("get_energy") == 100.0, "Energy restored")
	var shot_restored: bool = player.attack(Vector2(1, 0))
	assert(shot_restored == true, "Attack must succeed once energy is replenished")
	
	player.queue_free()
	print("  [PASS] Attack cooldowns and suit energy resource costs verified")


func _test_projectile_range_and_expiration() -> void:
	var proj = ProjectileScene.instantiate()
	proj.position = Vector2(0, 0)
	proj.setup(Vector2(1, 0), null, 20.0, 500.0, 100.0) # 100 px range
	add_child(proj)
	
	var expired_called: Dictionary = {"called": false}
	proj.projectile_expired.connect(func(_pos):
		expired_called["called"] = true
	)
	
	# Process movement beyond max_range (0.25s * 500px/s = 125px > 100px range)
	proj._physics_process(0.25)
	assert(expired_called["called"] == true, "Projectile must expire upon exceeding max_range")
	assert(proj.get("_is_expired") == true, "Projectile must flag _is_expired")
	
	proj.queue_free()
	print("  [PASS] Projectile range limitation and graceful expiration verified")


func _test_projectile_enemy_collision_and_damage() -> void:
	var enemy = EnemyScene.instantiate()
	enemy.position = Vector2(100, 100)
	add_child(enemy)
	
	var initial_hp: float = enemy.health_component.current_health
	
	var proj = ProjectileScene.instantiate()
	proj.position = Vector2(80, 100)
	proj.setup(Vector2(1, 0), null, 30.0, 400.0, 200.0)
	add_child(proj)
	
	# Simulate collision with enemy body
	proj._handle_collision(enemy)
	
	assert(enemy.health_component.current_health < initial_hp, "Enemy must take damage from projectile hit")
	assert(enemy.health_component.current_health == initial_hp - 30.0, "Damage dealt must match projectile damage")
	assert(enemy.current_state == enemy.State.CHASE, "Taking projectile damage must alert enemy into CHASE state")
	
	proj.queue_free()
	enemy.queue_free()
	print("  [PASS] Projectile enemy collision and damage application verified")


func _test_multi_hit_prevention() -> void:
	var enemy = EnemyScene.instantiate()
	enemy.position = Vector2(100, 100)
	add_child(enemy)
	
	var initial_hp: float = enemy.health_component.current_health
	
	var proj = ProjectileScene.instantiate()
	proj.position = Vector2(80, 100)
	proj.setup(Vector2(1, 0), null, 25.0, 400.0, 200.0)
	add_child(proj)
	
	# First hit
	proj._handle_collision(enemy)
	assert(enemy.health_component.current_health == initial_hp - 25.0, "First hit applies 25 damage")
	
	# Repeated hit in same or subsequent frame on the same target
	proj._handle_collision(enemy)
	assert(enemy.health_component.current_health == initial_hp - 25.0, "Duplicate hit on same target must be ignored (No double damage)")
	
	proj.queue_free()
	enemy.queue_free()
	print("  [PASS] Multi-hit prevention on single projectile confirmed")


func _test_world_obstacle_collision() -> void:
	# Create static obstacle representing solid canyon rock wall
	var obstacle := StaticBody2D.new()
	obstacle.position = Vector2(250, 250)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(40, 40)
	col.shape = shape
	obstacle.add_child(col)
	obstacle.collision_layer = 1
	add_child(obstacle)
	
	var proj = ProjectileScene.instantiate()
	proj.position = Vector2(230, 250)
	proj.setup(Vector2(1, 0), null, 25.0, 400.0, 200.0)
	add_child(proj)
	
	var hit_called: Dictionary = {"called": false, "target": null}
	proj.projectile_hit.connect(func(target, _pos):
		hit_called["called"] = true
		hit_called["target"] = target
	)
	
	# Simulate hitting obstacle
	proj._handle_collision(obstacle)
	assert(hit_called["called"] == true, "Projectile must register impact on world obstacle")
	assert(hit_called["target"] == obstacle, "Impact target must be the obstacle")
	assert(proj.get("_is_expired") == true, "Projectile must expire upon colliding with solid wall")
	
	proj.queue_free()
	obstacle.queue_free()
	print("  [PASS] World obstacle collision and despawn verified")


func _test_reusable_damage_data_interface() -> void:
	# Verify DamageData object contract
	var damage_data := DamageDataClass.create(
		35.0,
		self,
		DamageDataClass.DamageType.ENERGY,
		Vector2(1, 0),
		80.0,
		Vector2(10, 10)
	)
	assert(damage_data.amount == 35.0, "DamageData amount matches")
	assert(damage_data.damage_type == DamageDataClass.DamageType.ENERGY, "DamageData type is ENERGY")
	assert(damage_data.knockback_force == 80.0, "DamageData knockback force matches")
	assert(damage_data.knockback_direction == Vector2(1, 0), "DamageData knockback direction matches")
	
	# Test apply_damage on enemy
	var enemy = EnemyScene.instantiate()
	enemy.position = Vector2(400, 400)
	add_child(enemy)
	
	var hp_before: float = float(enemy.health_component.current_health)
	var result: bool = enemy.apply_damage(damage_data)
	assert(result == true, "apply_damage must return true")
	assert(enemy.health_component.current_health == hp_before - 35.0, "apply_damage reduces enemy health by 35.0")
	assert(enemy.velocity.x > 0.0, "apply_damage must apply knockback force to enemy velocity")
	
	# Test apply_damage on player
	var player = PlayerScene.instantiate()
	player.position = Vector2(500, 500)
	add_child(player)
	
	var player_hp_before: float = float(player.get_current_health())
	var player_hit: bool = player.health_component.apply_damage(damage_data)
	assert(player_hit == true, "apply_damage must succeed on player HealthComponent")
	assert(player.get_current_health() == player_hp_before - 35.0, "Player health reduced by 35.0")
	
	enemy.queue_free()
	player.queue_free()
	print("  [PASS] Reusable DamageData and HealthComponent interface contracts verified")
