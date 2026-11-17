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
	await _test_oxygen_and_items()
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
	# Step 3 ADJUST: fuzzy aggression changes speed SLOWLY.
	_check(game.boss_brain.use_fuzzy and "Aggression 0." in game.right_info.text, "HUD shows the fuzzy aggression")
	game.boss_brain.aggression = 0.5
	game.boss_brain.aggression_target = 1.0
	game.boss_brain._fuzzy_timer = 10.0           # keep the server from changing the target during the check
	await _run_seconds(1.0)
	var after_one_second: float = game.boss_brain.aggression
	_check(after_one_second > 0.5 and after_one_second <= 0.62, "Aggression moves slowly toward the fuzzy target (%.2f after 1 s)" % after_one_second)
	_check(game.rival.move_speed > game.boss_brain.base_speed, "Higher aggression -> faster boss")
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


## Oxygen survival + CSP item placement + forward-chaining warnings.
func _test_oxygen_and_items() -> void:
	# CSP placed 2 oxygen tanks, a health and an energy pickup, and the safe dome.
	var spots: Dictionary = game.level_item_spots
	var names: Array = spots.keys()
	names.sort()
	_check(names == ["energy_pickup", "health_pickup", "oxygen_tank_1", "oxygen_tank_2", "safe_dome"] and game.dome_center != Vector2.INF, "CSP placed: %s" % str(names))
	var oxygen_x: Array = [spots["oxygen_tank_1"].x, spots["oxygen_tank_2"].x, spots["safe_dome"].x]
	var thirds := {}
	for x in oxygen_x:
		thirds[mini(2, int(x * 3.0 / game.ARENA_WIDTH))] = true
	_check(thirds.size() == 3, "One oxygen item in each third of the level")
	# Oxygen goes down while exploring (player stands somewhere safe and empty).
	for alien in game.aliens:
		alien.queue_free()
	game.aliens.clear()
	game.player.position = _safe_spot()
	game.oxygen = 100.0
	await _run_seconds(2.0)
	_check(game.oxygen < 98.5 and game.oxygen > 95.0, "Oxygen drains about 1.5 per second (%.1f after 2 s)" % game.oxygen)
	_check(game.oxygen_fill.visible, "Oxygen bar is on the HUD")
	# Safe dome refills slowly.
	game.oxygen = 50.0
	game.player.position = game.dome_center
	await _run_seconds(1.0)
	_check(game.oxygen > 55.0, "Standing in the safe dome refills oxygen (%.1f)" % game.oxygen)
	# An oxygen tank gives +40.
	var tank_spot := _safe_spot() + Vector2(0, -20)
	game._spawn_pickup("oxygen", tank_spot)
	game.oxygen = 30.0
	game.player.position = tank_spot
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(game.oxygen >= 69.0, "Oxygen tank refills +40 (%.1f)" % game.oxygen)
	# Oxygen 0 -> health drains slowly; forward chaining shows the warning.
	game.player.position = _safe_spot()
	game.oxygen = 0.0
	var health_before: float = game.player.health
	await _run_seconds(1.5)
	_check(game.player.health < health_before and game.player.health > health_before - 10.0, "No oxygen: health drains slowly (%.1f -> %.1f)" % [health_before, game.player.health])
	_check("LOW OXYGEN" in game.warning_label.text, "Forward chaining: oxygen_warning shown")
	game.oxygen = 100.0
	game.player.health = game.player.max_health
	await _run_seconds(1.2)
	_check(game.warning_label.text == "", "Warning disappears when oxygen is back")


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


## A ground spot away from items, the safe dome, hazards and the portal.
func _safe_spot() -> Vector2:
	for x in range(150, 2700, 40):
		var ok: bool = absf(x - game.dome_center.x) > game.DOME_RADIUS + 80.0
		for item in game.pickups:
			ok = ok and absf(x - item["node"].position.x) > 120.0
		for hazard in game.hazards:
			ok = ok and absf(x - float(hazard["x"])) > float(hazard["width"]) * 0.5 + 60.0
		if ok:
			return Vector2(x, 585)
	return Vector2(150, 585)


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
