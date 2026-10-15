extends SceneTree
## Automated verification for BioSphere-X expanded map generation,
## MapData obstacle tracking, and AStar pathfinding navigation.

func _init() -> void:
	print("--- Running BioSphere-X Map & Navigation Tests ---")
	
	var world_scene: PackedScene = load("res://scenes/world/game_world.tscn")
	assert(world_scene != null, "GameWorld scene must load")
	
	var world: Node2D = world_scene.instantiate()
	root.add_child(world)
	if world.get("map_data") == null:
		world.call("_ready")
	
	# 1. MapData Inspection
	var map_data = world.get("map_data")
	assert(map_data != null, "MapData must be initialized")
	
	var summary: Dictionary = map_data.call("get_obstacle_summary")
	assert(summary["walkable"] > 4000, "Should have extensive walkable area for exploration")
	assert(summary["wall"] > 0, "Should contain canyon wall obstacles")
	assert(summary["debris"] > 0, "Should contain research outpost debris")
	assert(summary["resource"] > 0, "Should contain resource deposits")
	print("  [PASS] MapData obstacle distribution verified: ", summary)
	
	# 2. Coordinate Transformation Tests
	var origin: Vector2 = map_data.get("world_origin")
	var cell_size: float = map_data.get("cell_size")
	var g_center: Vector2i = map_data.call("world_to_grid", Vector2.ZERO)
	var w_center: Vector2 = map_data.call("grid_to_world", g_center)
	assert(w_center.distance_to(Vector2.ZERO) < cell_size, "Grid/World conversion roundtrip must be within one cell")
	print("  [PASS] Coordinate transformation verified")
	
	# 3. Walkable Spawn & Blocked Obstacles Tests
	assert(not map_data.call("is_world_blocked", Vector2.ZERO), "Central landing zone (0,0) must be walkable")
	
	# Known wall position: Vector2(-420, -320)
	assert(map_data.call("is_world_blocked", Vector2(-420, -320)), "Canyon wall must be blocked")
	
	# Known research debris position: Vector2(540, -520)
	assert(map_data.call("is_world_blocked", Vector2(540, -520)), "Habitat module debris must be blocked")
	
	# Known resource deposit position: Vector2(-680, 520)
	assert(map_data.call("is_world_blocked", Vector2(-680, 520)), "Energy crystal deposit must be blocked")
	print("  [PASS] Walkable areas vs blocked obstacles verified")
	
	# 4. AStar Pathfinding Integration Tests
	var path: PackedVector2Array = map_data.call("get_path_points", Vector2.ZERO, Vector2(0, 160))
	assert(path.size() >= 2, "Path from (0,0) to (0,160) must have at least start and end points")
	
	# Verify that no point in the calculated path is on a blocked cell
	for pt in path:
		assert(not map_data.call("is_world_blocked", pt), "Calculated path points must be on walkable cells")
	print("  [PASS] AStar navigation pathfinding verified (path length: %d points)" % path.size())
	
	# 5. Collision Layer Verification
	var player: Node2D = world.call("get_player")
	assert(player != null, "Player must be spawned in world")
	assert(player.get("collision_layer") == 1, "Player must be on collision layer 1")
	assert(player.get("collision_mask") == 1, "Player must collide with layer 1 obstacles")
	print("  [PASS] Player and obstacle collision layers verified")
	
	root.remove_child(world)
	world.free()
	print("--- All BioSphere-X Map & Navigation Tests Passed! ---")
	quit(0)
