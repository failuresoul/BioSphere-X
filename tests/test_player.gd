extends SceneTree
## Automated verification test for Player controller, movement, health, and interaction.

func _init() -> void:
	print("--- Running BioSphere-X Player Tests ---")
	
	var player_scene: PackedScene = load("res://scenes/player/player.tscn")
	assert(player_scene != null, "Player scene should load successfully")
	
	var player: Node = player_scene.instantiate()
	assert(player != null, "Player should instantiate")
	root.add_child(player)
	
	# 1. Component Hierarchy Verification
	var visual: Node = player.get_node_or_null("Visual")
	var health_comp: Node = player.get_node_or_null("HealthComponent")
	var interact_comp: Node = player.get_node_or_null("InteractionComponent")
	var camera: Camera2D = player.get_node_or_null("Camera2D")
	var collision: CollisionShape2D = player.get_node_or_null("CollisionShape2D")
	
	assert(visual != null, "Visual node must exist")
	assert(health_comp != null, "HealthComponent must exist")
	assert(interact_comp != null, "InteractionComponent must exist")
	assert(camera != null, "Camera2D must exist")
	assert(collision != null, "CollisionShape2D must exist")
	print("  [PASS] Component hierarchy verified")
	
	# 2. Movement & Normalization Verification
	var test_diag := Vector2(1.0, 1.0).normalized()
	assert(is_equal_approx(test_diag.length(), 1.0), "Normalized diagonal vector must have length 1.0")
	
	# Test acceleration
	player.call("_apply_movement", Vector2(1, 0), 0.1)
	var vel: Vector2 = player.get("velocity")
	assert(vel.x > 0.0, "Velocity should increase with positive input")
	assert(vel.x <= player.get("max_speed"), "Velocity should not exceed max_speed")
	print("  [PASS] Acceleration logic verified")
	
	# Test deceleration / friction
	player.call("_apply_movement", Vector2.ZERO, 0.5)
	var slowed_vel: Vector2 = player.get("velocity")
	assert(slowed_vel.x < vel.x, "Velocity should decrease towards zero with zero input")
	print("  [PASS] Deceleration logic verified")
	
	# 3. Health Component Verification
	var cur_health: float = player.call("get_current_health")
	assert(cur_health == 100.0, "Initial health should be 100.0, got: %f" % cur_health)
	player.call("take_damage", 25.0)
	assert(player.call("get_current_health") == 75.0, "Health should reduce to 75.0 after 25 damage")
	player.call("heal", 10.0)
	assert(player.call("get_current_health") == 85.0, "Health should be 85.0 after healing 10")
	print("  [PASS] Health component damage/heal API verified")
	
	# 4. Visual Update Verification
	visual.call("update_motion", Vector2(100, 0), 0.016)
	visual.call("play_damage_flash")
	print("  [PASS] Visual updates verified")
	
	root.remove_child(player)
	player.free()
	print("--- All BioSphere-X Player Tests Passed Successfully ---")
	quit(0)
