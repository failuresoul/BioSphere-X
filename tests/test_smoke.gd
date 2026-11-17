extends Node
## Smoke test for the whole game (the Python server is started automatically).
##   Home -> Player vs AI: exploration (Alien Patrol FSM, oxygen, CSP items, suit modes)
##        -> boss fight (A*, Minimax+alpha-beta, fuzzy, 1.5 s rest) -> planet cleared
##   Home -> AI vs AI: one full match at 4x -> result panel shows EVERY algorithm used
##        -> "Run matches" table + CSV -> Esc / Q back to the setup -> Home
## Run: godot --headless --path . res://tests/test_smoke.tscn

const GameScene = preload("res://scenes/star_brawl/star_brawl.tscn")
const Pathfinder = preload("res://scripts/utils/modular_pathfinder.gd")

var game: Node2D
var failures := 0


func _ready() -> void:
	game = GameScene.instantiate()
	game.progress_path = "user://test_progress.cfg"
	add_child(game)
	await _wait_for_server()
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
	_test_suit_modes()
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

	# ---- Home -> AI vs AI ---------------------------------------------------
	game._show_home()
	_check(game.phase == "home" and game.mode == "pva", "Back to the home screen")
	var ai = game.ai_match
	# Setup screen
	game.open_ai_setup()
	_check(game.phase == "ai_setup" and ai.setup.visible, "AI vs AI setup screen opens")
	var defaults: Dictionary = ai.setup.get_config()
	_check(defaults["blue_decision"] == "minimax_ab" and defaults["red_decision"] == "mcts" and defaults["blue_search"] == "rotate" and defaults["red_search"] == "rotate",
		"Defaults: Minimax+alpha-beta vs MCTS, Rotate all 7")

	# One full match at 4x
	ai.start_match(defaults)
	game._unhandled_key_input(_key(KEY_2))
	_check(Engine.time_scale == 2.0, "Key 2 = speed 2x")
	game._unhandled_key_input(_key(KEY_ESCAPE))
	_check(game.phase == "ai_paused" and ai.pause_label.visible, "Esc pauses the match")
	var paused_time: float = ai.time
	await _run_seconds(0.3)
	_check(is_equal_approx(ai.time, paused_time), "Time stops while paused")
	game._unhandled_key_input(_key(KEY_ESCAPE))
	_check(game.phase == "fight", "Esc resumes")
	ai.set_speed(4.0)
	_check(game.phase == "fight" and ai.hud.visible and game.aliens.size() == 2, "Match starts with its HUD and two Alien Patrols")
	_check(ai.blue_fighter.max_health == ai.red_fighter.max_health and ai.blue_fighter.punch_damage == ai.red_fighter.punch_damage, "Both fighters have the same HP and damage")
	_check(ai.blue.search_algorithm == "bfs" and ai.red.search_algorithm == "iddfs", "Blue starts with BFS, red 3 steps later (IDDFS)")
	var start_ms := Time.get_ticks_msec()
	var saw_paths := false
	while game.phase != "ai_result" and Time.get_ticks_msec() - start_ms < 60000:
		await get_tree().process_frame
		if game.phase == "fight" and not saw_paths and not ai.path_lines().is_empty() and ai.blue.planner.path.size() > 1:
			saw_paths = true
	var r: Dictionary = ai.last_result
	_check(game.phase == "ai_result" and ai.result_screen.visible, "Match ends and the result panel opens")
	_check(r.get("winner", "") in ["blue", "red"], "There is a winner: %s after %.1f s (%s, rule: %s)" % [r.get("winner"), r.get("time", 0.0), r.get("reason"), r.get("deciding_rule")])
	_check(saw_paths, "P-key path lines are available during the match")

	# Every algorithm was used
	var used: Array = []
	for algorithm in Pathfinder.ORDER:
		if int(r["search"].get(algorithm, {}).get("count", 0)) > 0:
			used.append(algorithm)
	_check(used.size() == 7, "All 7 search algorithms used: %s" % str(used))
	_check(r["blue"]["decision"] == "minimax_ab" and r["blue"]["decisions"] > 0 and r["blue"]["nodes_pruned"] > 0,
		"Blue: Minimax+alpha-beta made %d decisions, pruned %d nodes" % [r["blue"]["decisions"], r["blue"]["nodes_pruned"]])
	_check(r["red"]["decision"] == "mcts" and r["red"]["decisions"] > 0, "Red: MCTS made %d decisions" % r["red"]["decisions"])
	_check(r["blue"]["fuzzy_updates"] > 0 and r["red"]["fuzzy_updates"] > 0, "Fuzzy logic updated both (%d / %d)" % [r["blue"]["fuzzy_updates"], r["red"]["fuzzy_updates"]])
	_check(not r["rules"].is_empty() and (r["rules"].has("blue_down") or r["rules"].has("red_down") or r["rules"].has("time_up")), "Forward chaining fired: %s" % str(r["rules"]))
	_check(r["csp"]["solves"] > 0, "CSP solved %d times (%d backtracks)" % [r["csp"]["solves"], r["csp"]["backtracks"]])
	var transitions: int = 0
	for side in ["blue", "red"]:
		for mode_name in r[side]["modes"]:
			transitions += int(r[side]["modes"][mode_name])
	_check(transitions > 2 and r["alien_searches"] > 0, "FSMs used: fighter modes %s / %s, alien A* searches %d" % [str(r["blue"]["modes"]), str(r["red"]["modes"]), r["alien_searches"]])
	var text: String = ai.result_screen.body.get_parsed_text()
	text += ai.result_screen.body_right.get_parsed_text()
	_check("ALGORITHMS USED" in text and "Bidirectional" in text and "Fuzzy logic" in text and "CSP" in text and "FSM" in text and not ("not reached" in text), "Result panel lists the algorithms used")
	_check(Engine.time_scale == 1.0, "Speed back to 1x after the match")
	if OS.has_environment("SHOT_DIR"):                # optional screenshot of the result panel
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_DIR") + "/16_ava_result_full.png")

	# Run N matches (2 here, with quick knockouts): table + CSV, sides swap.
	var first_blue_x: float = 0.0
	ai.start_batch(defaults, 2)
	for match_index in 2:
		await get_tree().process_frame
		if match_index == 0:
			first_blue_x = ai.blue_fighter.position.x
		else:
			_check(signf(ai.blue_fighter.position.x - 800.0) != signf(first_blue_x - 800.0), "Sides swap between matches")
		ai.red_fighter.invulnerable = 0.0
		ai.red_fighter.take_damage(5000.0, 1)
		var batch_wait := Time.get_ticks_msec()
		while ai.results.size() <= match_index and Time.get_ticks_msec() - batch_wait < 3000:
			await get_tree().process_frame
	await get_tree().process_frame
	_check(game.phase == "ai_result" and ai.results.size() == 2 and "AI 1  2  -  0  AI 2" in ai.result_screen.title_label.text, "Batch table: %s" % ai.result_screen.title_label.text)
	var csv := FileAccess.open(ai.CSV_PATH, FileAccess.READ)
	_check(csv != null and csv.get_as_text().strip_edges().split("\n").size() == 3, "Results saved to %s" % ai.CSV_PATH)

	# Esc pauses, Q quits to the setup, Esc goes home.
	ai.start_match(defaults)
	game._unhandled_key_input(_key(KEY_ESCAPE))
	game._unhandled_key_input(_key(KEY_Q))
	_check(game.phase == "ai_setup" and Engine.time_scale == 1.0, "Q (while paused) quits to the setup screen")
	game._unhandled_key_input(_key(KEY_ESCAPE))
	_check(game.phase == "home", "Esc on the setup screen goes home")

	print("Smoke test: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	game.queue_free()
	await get_tree().create_timer(2.5).timeout      # let pending HTTP requests finish
	get_tree().quit(0 if failures == 0 else 1)


## Keyboard suit modes (Q): ATTACK -> GUARD -> HEAL.
func _test_suit_modes() -> void:
	_check(game.suit_mode == "ATTACK" and "ATTACK SUIT" in game.left_name.text, "Suit starts in ATTACK mode")
	game._unhandled_key_input(_key(KEY_Q))
	_check(game.suit_mode == "GUARD", "Q switches to GUARD")
	game.player.invulnerable = 0.0
	var before: float = game.player.health
	game._deal_damage(game.player, 10.0, 1)
	_check(is_equal_approx(before - game.player.health, 6.5), "GUARD takes 35% less damage")
	game._unhandled_key_input(_key(KEY_Q))
	game._unhandled_key_input(_key(KEY_Q))
	_check(game.suit_mode == "ATTACK", "Q cycles back to ATTACK")
	game.player.health = game.player.max_health
	game.player.invulnerable = 0.0


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


func _wait_for_server() -> void:
	for attempt in 30:
		var answer := {"done": false, "ok": false}
		AIClient.check_health(func(response: Dictionary) -> void:
			answer["ok"] = bool(response.get("success", false))
			answer["done"] = true)
		while not answer["done"]:
			await get_tree().process_frame
		if answer["ok"]:
			return
		await get_tree().create_timer(0.5).timeout
	push_warning("Python server not reachable: the test runs with fallbacks")


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  [PASS] %s" % label)
	else:
		failures += 1
		push_error("  [FAIL] %s" % label)
