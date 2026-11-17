extends Node
## Smoke test: opens both game modes and checks that they run.
## Works with or without the Python backend (offline the AIs use a fallback rule).
## Run: godot --headless --path . res://tests/test_game_modes.tscn

const GameScene = preload("res://scenes/star_brawl/star_brawl.tscn")

var game: Node2D
var failures := 0


func _ready() -> void:
	game = GameScene.instantiate()
	game.progress_path = "user://test_progress.cfg"
	add_child(game)
	await get_tree().process_frame
	_check(game.phase == "home" and game.home_screen.visible, "Home screen opens first")

	# ---- Player vs AI -------------------------------------------------------
	game.unlocked_planet = 1
	game.start_run()
	_check(game.phase == "map" and game.mode == "pva", "PLAYER vs AI opens the planet map")
	game._select_planet(0)
	game._on_campaign_action("start")
	_check(game.phase == "fight" and game.segment == "explore", "Planet 1 starts with exploration")
	game.player.position = Vector2(game.PORTAL_X, 585)
	game._check_portal()
	await get_tree().process_frame
	_check(game.segment == "boss" and is_instance_valid(game.rival) and game.grid != null, "Portal opens the boss arena and its grid")
	_check(game.boss_brain.search_algorithm == "dfs" and game.boss_brain.decision_algorithm == "minimax", "Planet 1 boss uses DFS + Minimax")
	_check(game.boss_decision_algorithm(1) == "mcts" and game.boss_decision_algorithm(2) == "minimax", "Even planets use MCTS, odd planets Minimax")
	await _run_seconds(2.0)
	_check(game.boss_brain.searches > 0 and game.boss_brain.last_nodes > 0, "Boss searched a path (%d searches)" % game.boss_brain.searches)
	_check("DFS + MINIMAX" in game.right_name.text and "nodes" in game.right_info.text, "HUD shows boss algorithm, action and stats")
	game._unhandled_key_input(_key(KEY_P))
	_check(game.show_paths, "P shows the AI path")
	game._unhandled_key_input(_key(KEY_P))
	game.rival.invulnerable = 0.0
	game.rival.take_damage(5000.0, 1)
	var wait_start := Time.get_ticks_msec()
	while game.phase == "fight" and Time.get_ticks_msec() - wait_start < 5000:
		await get_tree().process_frame
	_check(game.phase == "clear", "Defeating the boss clears the planet")

	# ---- AI vs AI -----------------------------------------------------------
	game._show_home()
	game.open_ai_setup()
	_check(game.phase == "ai_setup" and game.ai_screen.visible, "AI vs AI opens the setup screen")
	var config := {"blue_search": "astar", "blue_decision": "minimax", "red_search": "bidirectional", "red_decision": "mcts", "planet": 3}
	game.start_ai_match(config)
	_check(game.phase == "fight" and game.mode == "ava" and game.blue_brain != null and game.red_brain != null, "AI vs AI match starts")
	_check("A* + MINIMAX" in game.left_name.text and "Bidirectional + MCTS" in game.right_name.text, "HUD shows both AIs' algorithms")
	# Let a full match play at high speed; it must end by knockout or time limit.
	Engine.time_scale = 6.0
	var start_ms := Time.get_ticks_msec()
	while game.phase == "fight" and Time.get_ticks_msec() - start_ms < 30000:
		await get_tree().process_frame
	Engine.time_scale = 1.0
	_check(game.phase == "ai_result" and game.ai_screen.result_panel.visible, "Match finishes and shows the result panel")
	_check(game.ai_screen.result_title.text != "", "Result: %s" % game.ai_screen.result_title.text)
	print("  blue: searches %d, avg nodes %.1f, damage %.0f  |  red: searches %d, avg nodes %.1f, damage %.0f" % [
		game.blue_brain.searches, game.blue_brain.average_nodes(), game.blue_brain.damage_dealt,
		game.red_brain.searches, game.red_brain.average_nodes(), game.red_brain.damage_dealt])
	print("  decisions came from: %s" % game.blue_brain.source)
	_check(game.blue_brain.searches > 10 and game.red_brain.searches > 10, "Both AIs kept searching during the match")

	# "Run N matches": force quick knockouts to step through a 2-match batch.
	game.start_ai_batch(config, 2)
	for match_number in 2:
		await get_tree().process_frame
		game.rival.take_damage(5000.0, 1)
		await get_tree().process_frame
		await get_tree().process_frame
	_check(game.phase == "ai_result" and game.batch_results.size() == 2 and "AI 1  2  -  0  AI 2" in game.ai_screen.result_title.text, "Batch run shows the win table")
	_check(Engine.time_scale == 1.0, "Speed is reset after the batch")
	game._unhandled_key_input(_key(KEY_ESCAPE))
	_check(game.phase == "ai_setup", "Esc returns to the AI vs AI setup")

	print("Game modes: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	game.queue_free()
	await get_tree().create_timer(2.5).timeout      # let pending HTTP requests finish
	get_tree().quit(0 if failures == 0 else 1)


func _run_seconds(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await get_tree().physics_frame


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  [PASS] %s" % label)
	else:
		failures += 1
		push_error("  [FAIL] %s" % label)
