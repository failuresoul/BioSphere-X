extends Node
## AI vs AI test: one full match at 4x (Minimax+alpha-beta vs MCTS, "Rotate all 7").
## It must end with a winner, and the result must show that EVERY algorithm was used:
## all 7 search algorithms, both decision algorithms, fuzzy logic, forward chaining,
## CSP and the FSMs. Then a short 2-match batch checks the table and the CSV file.
## Run: godot --headless --path . res://tests/test_ai_vs_ai.tscn   (the Python server is started automatically)

const GameScene = preload("res://scenes/star_brawl/star_brawl.tscn")
const Pathfinder = preload("res://scripts/utils/modular_pathfinder.gd")

var game: Node2D
var failures := 0


func _ready() -> void:
	game = GameScene.instantiate()
	game.progress_path = "user://test_ai_vs_ai_progress.cfg"
	add_child(game)
	await _wait_for_server()
	var ai = game.ai_match

	# Setup screen
	game.open_ai_setup()
	_check(game.phase == "ai_setup" and ai.setup.visible, "AI vs AI setup screen opens")
	var defaults: Dictionary = ai.setup.get_config()
	_check(defaults["blue_decision"] == "minimax_ab" and defaults["red_decision"] == "mcts" and defaults["blue_search"] == "rotate" and defaults["red_search"] == "rotate",
		"Defaults: Minimax+alpha-beta vs MCTS, Rotate all 7")

	# One full match at 4x
	ai.start_match(defaults)
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
		var wait_start := Time.get_ticks_msec()
		while ai.results.size() <= match_index and Time.get_ticks_msec() - wait_start < 3000:
			await get_tree().process_frame
	await get_tree().process_frame
	_check(game.phase == "ai_result" and ai.results.size() == 2 and "AI 1  2  -  0  AI 2" in ai.result_screen.title_label.text, "Batch table: %s" % ai.result_screen.title_label.text)
	var csv := FileAccess.open(ai.CSV_PATH, FileAccess.READ)
	_check(csv != null and csv.get_as_text().strip_edges().split("\n").size() == 3, "Results saved to %s" % ai.CSV_PATH)

	# Back to Player vs AI
	game._show_home()
	game.start_run()
	game._select_planet(0)
	game._on_campaign_action("start")
	_check(game.phase == "fight" and game.mode == "pva" and game.hud_root.visible and not ai.hud.visible, "Player vs AI still starts after AI vs AI")

	print("AI vs AI: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	game.queue_free()
	await get_tree().create_timer(2.5).timeout
	get_tree().quit(0 if failures == 0 else 1)


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
