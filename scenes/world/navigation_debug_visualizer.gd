extends Node2D
## Visualizer for Navigation Grid and Real-time Pathfinding Trajectories.
## Toggled on/off via F2 or Developer Navigation Menu.
## Renders blocked cells, walkable grid boundaries, active enemy paths, and waypoints.

func _ready() -> void:
	z_index = 10 # Draw on top of world terrain and obstacles
	var nav_mgr = get_node_or_null("/root/NavigationManager")
	if nav_mgr:
		if nav_mgr.has_signal("debug_display_changed"):
			nav_mgr.connect("debug_display_changed", func(_enabled): queue_redraw())
		if nav_mgr.has_signal("active_paths_changed"):
			nav_mgr.connect("active_paths_changed", func(): queue_redraw())


func _process(_delta: float) -> void:
	var nav_mgr = get_node_or_null("/root/NavigationManager")
	if nav_mgr and nav_mgr.get("debug_display_enabled"):
		queue_redraw()


func _draw() -> void:
	var nav_mgr = get_node_or_null("/root/NavigationManager")
	if not nav_mgr or not nav_mgr.get("debug_display_enabled"):
		return
		
	var map_data = nav_mgr.call("get_map_data")
	if not map_data:
		return
		
	var cell_size: float = map_data.get("cell_size") if "cell_size" in map_data else 32.0
	var grid_size: Vector2i = map_data.get("grid_size") if "grid_size" in map_data else Vector2i(80, 80)
	var world_origin: Vector2 = map_data.get("world_origin") if "world_origin" in map_data else Vector2(-1280, -1280)
	
	# -----------------------------------------------------------------------
	# 1. Draw Grid Outline & Blocked Cells
	# -----------------------------------------------------------------------
	var grid_world_size := Vector2(float(grid_size.x) * cell_size, float(grid_size.y) * cell_size)
	draw_rect(Rect2(world_origin, grid_world_size), Color(0.1, 0.4, 0.6, 0.3), false, 2.0)
	
	if map_data.has_method("get_blocked_cells"):
		var blocked: Array[Vector2i] = map_data.call("get_blocked_cells")
		var blocked_color := Color(0.9, 0.2, 0.25, 0.28)
		var outline_color := Color(1.0, 0.35, 0.4, 0.55)
		var c_size := Vector2(cell_size, cell_size)
		
		for b in blocked:
			var cell_pos := world_origin + Vector2(float(b.x) * cell_size, float(b.y) * cell_size)
			draw_rect(Rect2(cell_pos, c_size), blocked_color, true)
			draw_rect(Rect2(cell_pos, c_size), outline_color, false, 1.0)
			
	# -----------------------------------------------------------------------
	# 2. Draw Active Navigation Trajectories & Waypoints
	# -----------------------------------------------------------------------
	var paths: Dictionary = nav_mgr.get("active_paths") if "active_paths" in nav_mgr else {}
	for source_id in paths:
		var info: Dictionary = paths[source_id]
		var path: PackedVector2Array = info.get("path", PackedVector2Array())
		var col: Color = info.get("color", Color(0, 0.95, 1, 0.85))
		
		if path.size() >= 2:
			# Draw polyline connecting path waypoints
			draw_polyline(path, col, 3.0, true)
			
			# Draw waypoints along the route
			for i in range(path.size()):
				var pt := path[i]
				draw_circle(pt, 3.5, Color(1, 1, 1, 0.9))
				draw_circle(pt, 5.0, col)
				
			# Draw start node indicator
			draw_circle(path[0], 7.0, Color(0.2, 1.0, 0.4, 0.95))
			
			# Draw goal node target ring
			draw_arc(path[-1], 10.0, 0.0, TAU, 16, Color(1.0, 0.5, 0.1, 0.95), 2.5)
		elif path.size() == 1:
			draw_circle(path[0], 6.0, col)
