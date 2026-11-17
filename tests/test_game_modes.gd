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
	await _test_alien_fsm()
	game.player.position = Vector2(game.PORTAL_X, 585)
	game._check_portal()
	await get_tree().process_frame
	_check(game.segment == "boss" and is_instance_valid(game.rival) and game.grid != null, "Portal opens the boss arena and its grid")
	_check(game.boss_brain.search_algorithm == "astar" and game.boss_brain.decision_algorithm == "minimax_ab", "Planet 1 boss: A* + Minimax with alpha-beta")
	var mapping: Array = []
	for index in 10:
		mapping.append(game.boss_decision_algorithm(index))
	_check(mapping == ["minimax_ab", "minimax", "mcts", "minimax_ab", "minimax", "mcts", "minimax_ab", "minimax", "mcts", "minimax_ab"], "Planets 1,4,7,10 alpha-beta; 2,5,8 minimax; 3,6,9 MCTS")
	_check(game.boss_brain.fallback_action({"distance": 100.0}) == "attack" and game.boss_brain.fallback_action({"distance": 900.0}) == "move_closer", "Fallback: attack if near, else move closer")
	await _run_seconds(2.0)
	_check(game.boss_brain.planner.searches > 0 and game.boss_brain.planner.nodes > 0, "Boss got paths asynchronously (%d searches, from %s)" % [game.boss_brain.planner.searches, game.boss_brain.planner.source])
	_check("Boss: Minimax+αβ → " in game.right_info.text and "Search: A*" in game.right_info.text, "HUD shows: %s" % game.right_info.text.replace("
", "  //  "))
	_check(game.boss_brain.source == "server" and "pruned" in game.right_info.text, "Boss decision came from the server (nodes and pruned shown)")
	# ATTACK AND REST: after a special the boss rests 1.5 s.
	game.rival.energy = 100.0
	game.rival.special_cooldown = 0.0
	game.boss_special.clear()
	game.rival.position.x = game.player.position.x + 200.0
	game.boss_brain._set_action("special", game.rival, game.player, game)
	_check(is_equal_approx(game.boss_brain.rest_timer, 1.5) and "rest" in game.boss_brain.decision_text(), "Boss rests 1.5 s after a big attack")
	await _run_seconds(2.8)          # special wind-up (about 0.8 s) + 1.5 s rest
	_check(game.boss_brain.rest_timer <= 0.0, "Boss stops resting after the rest time")
	game.player.health = game.player.max_health
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
	var config := {"blue_search": "astar", "blue_decision": "minimax_ab", "red_search": "bidirectional", "red_decision": "mcts", "planet": 3}
	game.start_ai_match(config)
	_check(game.phase == "fight" and game.mode == "ava" and game.blue_brain != null and game.red_brain != null, "AI vs AI match starts")
	_check("A* + Minimax+αβ" in game.left_name.text and "Bidirectional + MCTS" in game.right_name.text, "HUD shows both AIs' algorithms")
	# Let a full match play at high speed; it must end by knockout or time limit.
	Engine.time_scale = 6.0
	var start_ms := Time.get_ticks_msec()
	while game.phase == "fight" and Time.get_ticks_msec() - start_ms < 30000:
		await get_tree().process_frame
	Engine.time_scale = 1.0
	_check(game.phase == "ai_result" and game.ai_screen.result_panel.visible, "Match finishes and shows the result panel")
	_check(game.ai_screen.result_title.text != "", "Result: %s" % game.ai_screen.result_title.text)
	print("  blue: searches %d, avg nodes %.1f, damage %.0f  |  red: searches %d, avg nodes %.1f, damage %.0f" % [
		game.blue_brain.planner.searches, game.blue_brain.average_nodes(), game.blue_brain.damage_dealt,
		game.red_brain.planner.searches, game.red_brain.average_nodes(), game.red_brain.damage_dealt])
	print("  decisions came from: %s" % game.blue_brain.source)
	_check(game.blue_brain.planner.searches > 10 and game.red_brain.planner.searches > 10, "Both AIs kept searching during the match")

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


## Agent 1: the alien Finite State Machine.
func _test_alien_fsm() -> void:
	var alien = game.aliens[0]
	var States = alien.State
	_check(alien.state == States.IDLE and alien.state_label.text == "IDLE", "Alien starts in IDLE with a state label")
	# Player in front of the alien (it faces left) -> CHASE with an A* path.
	game.player.position = alien.position + Vector2(-300, 0)
	await _run_seconds(0.8)
	_check(alien.state == States.CHASE, "Alien sees the player in front -> CHASE (state %s)" % alien.STATE_NAMES[alien.state])
	_check(alien.planner.searches > 0 and alien.planner.used == "astar", "CHASE uses A* (%s)" % alien.planner.hud_text())
	_check("Search: A*" in game.right_info.text, "HUD top-right shows: %s" % game.right_info.text)
	# Close enough -> ATTACK.
	game.player.position = alien.position + Vector2(-50, 0)
	await _run_seconds(0.3)
	_check(alien.state == States.ATTACK, "Close to the player -> ATTACK")
	# Player behind the alien -> it cannot see it.
	alien.facing = -1
	game.player.position = alien.position + Vector2(250, 0)
	_check(not alien.can_see(game.player), "Alien does not see a player behind it")
	# A wall between them blocks the view (raycast).
	game.player.position = alien.position + Vector2(-300, 0)
	game._add_wall(Rect2(alien.position.x - 160, alien.position.y - 80, 40, 130))
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(not alien.can_see(game.player), "Alien does not see through a wall")
	# Lost the player -> SEARCH, then gives up -> PATROL.
	alien._change_state(States.CHASE)
	await _run_seconds(0.3)
	_check(alien.state == States.SEARCH, "Loses the player -> SEARCH")
	game.player.position = Vector2(150, 585)
	await _run_seconds(alien.SEARCH_TIME + 0.5)
	_check(alien.state == States.PATROL, "Gives up searching -> PATROL")
	# F hides / shows the state labels.
	game._unhandled_key_input(_key(KEY_F))
	_check(not alien.state_label.visible, "F hides the state labels")
	game._unhandled_key_input(_key(KEY_F))
	# Health 0 -> DEAD.
	alien.invulnerable = 0.0
	alien.take_damage(5000.0, 1)
	_check(alien.state == States.DEAD, "Health 0 -> DEAD")
	game.player.health = game.player.max_health


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
