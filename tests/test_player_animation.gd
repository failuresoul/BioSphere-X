extends SceneTree
## Automated verification for astronaut player animation, 8-way directional facing,
## feedback triggers (start burst, turn bank, stop settle), and collision isolation.

func _init() -> void:
	print("--- Running BioSphere-X Animation & Feedback Tests ---")
	
	var player_scene: PackedScene = load("res://scenes/player/player.tscn")
	assert(player_scene != null, "Player scene must load")
	
	var player: Node = player_scene.instantiate()
	root.add_child(player)
	
	var visual: Node = player.get_node("Visual")
	var collision: CollisionShape2D = player.get_node("CollisionShape2D")
	
	# 1. Idle State Verification
	visual.call("update_motion", Vector2.ZERO, 0.1)
	assert(player.call("get_animation_state") == "idle", "Stationary state should be 'idle'")
	print("  [PASS] Initial Idle state verified")
	
	# 2. Four Cardinal Directions
	var directions: Dictionary = {
		"right": Vector2(200, 0),
		"down": Vector2(0, 200),
		"left": Vector2(-200, 0),
		"up": Vector2(0, -200)
	}
	
	for dir_name in directions.keys():
		var vel: Vector2 = directions[dir_name]
		# Run multiple frames to allow smooth rotation to settle
		for step in 10:
			visual.call("update_motion", vel, 0.033)
		var actual_dir: String = player.call("get_facing_direction")
		var actual_state: String = player.call("get_animation_state")
		assert(actual_dir == dir_name, "Expected facing '%s', got '%s'" % [dir_name, actual_dir])
		assert(actual_state == "walking", "State must be 'walking'")
		print("  [PASS] Cardinal direction '%s' verified" % dir_name)
	
	# 3. Four Diagonal Directions
	var diagonals: Dictionary = {
		"down_right": Vector2(1, 1).normalized() * 200.0,
		"down_left": Vector2(-1, 1).normalized() * 200.0,
		"up_left": Vector2(-1, -1).normalized() * 200.0,
		"up_right": Vector2(1, -1).normalized() * 200.0
	}
	
	for diag_name in diagonals.keys():
		var vel: Vector2 = diagonals[diag_name]
		for step in 10:
			visual.call("update_motion", vel, 0.033)
		var actual_dir: String = player.call("get_facing_direction")
		var actual_state: String = player.call("get_animation_state")
		assert(actual_dir == diag_name, "Expected diagonal facing '%s', got '%s'" % [diag_name, actual_dir])
		assert(actual_state == "walking", "State must be 'walking'")
		print("  [PASS] Diagonal direction '%s' verified" % diag_name)
	
	# 4. Movement Feedback Verification
	# A. Stopping settle feedback
	visual.call("update_motion", Vector2.ZERO, 0.033)
	assert(player.call("get_animation_state") == "idle", "State should return to idle after stopping")
	var stop_timer: float = visual.get("_stop_settle_timer")
	assert(stop_timer > 0.0, "Stopping must trigger stop settle feedback timer")
	print("  [PASS] Stop/Braking settle feedback verified")
	
	# B. Start-of-motion burst feedback
	visual.set("_is_moving", false)
	visual.set("_start_burst_timer", 0.0)
	visual.call("update_motion", Vector2(180, 0), 0.033)
	var start_timer: float = visual.get("_start_burst_timer")
	assert(start_timer > 0.0, "Starting from stop must trigger start burst feedback timer")
	print("  [PASS] Start-of-motion burst feedback verified")
	
	# C. Direction change bank/tilt feedback
	visual.call("update_motion", Vector2(0, 200), 0.033) # Instant 90-degree turn
	var turn_tilt: float = visual.get("_turn_tilt")
	assert(absf(turn_tilt) > 0.0, "Sharp turn must trigger dynamic tilt banking")
	print("  [PASS] Direction change banking feedback verified")
	
	# 5. Collision & Physics Non-Interference Verification
	assert(collision.position == Vector2.ZERO, "CollisionShape position must remain Vector2.ZERO")
	assert(collision.rotation == 0.0, "CollisionShape rotation must remain 0.0")
	assert(collision.scale == Vector2.ONE, "CollisionShape scale must remain Vector2.ONE")
	assert(player.scale == Vector2.ONE, "Player root scale must remain Vector2.ONE")
	print("  [PASS] Collision & physics non-interference verified")
	
	root.remove_child(player)
	player.free()
	print("--- All BioSphere-X Animation & Feedback Tests Passed! ---")
	quit(0)
