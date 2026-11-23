extends Node
## AI vs AI: runs the matches.
##
## REUSES the Player vs AI game (star_brawl.gd): the same boss arena, fighters,
## punches, shots, projectiles and walls. Both fighters are 100% AI, with the
## same HP, damage and speed, and they swap sides every match.
##
## Every algorithm is used in every match:
##   path finding   7 algorithms, rotating every 10 s       (ai_fighter_controller.gd)
##   Minimax / MCTS each fighter's move every 0.5 s           (fighter_brain.gd)
##   fuzzy logic    each fighter's aggression                 (fighter_brain.gd)
##   forward chain  defensive / finisher modes every 1 s, and the referee at the end
##   CSP            places the pickups at the start and again after each pickup
##   FSM            fighter modes (CHASE/ATTACK/DEFEND/PICKUP) + two Alien Patrols
##
## For the fighters' brains this node is the "arena": it provides grid,
## energy_of(), perform_special(), record_search(), recent_damage_taken(),
## pickups(), record_rules() and log_event().

const FighterScript = preload("res://scenes/star_brawl/space_fighter.gd")
const AlienScript = preload("res://scenes/star_brawl/alien_enemy.gd")
const ControllerScript = preload("res://scenes/ai_vs_ai_mode/ai_fighter_controller.gd")
const SetupScript = preload("res://scenes/ai_vs_ai_mode/ai_vs_ai_setup.gd")
const ResultScript = preload("res://scenes/ai_vs_ai_mode/ai_vs_ai_result.gd")
const Pathfinder = preload("res://scripts/utils/modular_pathfinder.gd")

const AI_HEALTH := 300.0          # same for both fighters
const PUNCH_DAMAGE := 10.0
const MOVE_SPEED := 250.0
const MATCH_SECONDS := 90.0       # then the higher HP % wins
const BATCH_SPEED := 4.0          # "Run 10 matches" plays at 4x
const RED_OFFSET := 3             # red starts 3 algorithms later, so they differ
const DOME_HEAL := 2.0            # HP per second inside the safe dome
const CSV_PATH := "user://ai_vs_ai_results.csv"
const DECISION_NAMES := {"minimax_ab": "Minimax+αβ", "minimax": "Minimax", "mcts": "MCTS"}
const BLUE := Color("5fb4ff")
const RED := Color("ff6f7d")

var game                          # star_brawl.gd
var setup: Control
var result_screen: Control
var config: Dictionary = {}
var match_number := 0             # odd = blue starts left, even = blue starts right
var batch_total := 0              # > 0 while "Run 10 matches" is running
var results: Array[Dictionary] = []
var last_result: Dictionary = {}   # the most recent match result

# The current match
var grid                          # arena tile grid (used by the brains)
var blue                          # ai_fighter_controller.gd for AI 1
var red                           # ai_fighter_controller.gd for AI 2
var blue_fighter: SpaceFighter
var red_fighter: SpaceFighter
var time := 0.0
var running := false
var search_stats := {}            # algorithm -> {count, nodes, ms, path}
var side_stats := {}              # "blue"/"red" -> {count, nodes, ms}
var rules_fired := {}             # rule name -> times fired
var csp_solves := 0
var csp_backtracks := 0
var alien_searches := 0
var hits := {}                    # fighter -> [[time, damage], ...]
var log_lines: Array[String] = []
var _csp_busy := false
var _hud_timer := 0.0

# HUD
var hud: Control
var panels := {}                  # side -> {"name", "bar", "text"}
var timer_label: Label
var info_label: Label
var log_label: Label
var pause_label: Label


func init(p_game) -> void:
	game = p_game
	setup = SetupScript.new()
	game.ui_layer.add_child(setup)
	setup.set_planets(game.PLANETS)
	setup.start_requested.connect(start_match)
	setup.batch_requested.connect(start_batch)
	setup.back_requested.connect(func() -> void: game._show_home())
	result_screen = ResultScript.new()
	game.ui_layer.add_child(result_screen)
	result_screen.rematch_requested.connect(func() -> void: start_match(config))
	result_screen.setup_requested.connect(open_setup)
	result_screen.home_requested.connect(func() -> void: game._show_home())
	_build_hud()
	on_phase("home")


## Called by star_brawl._set_screen(): show the right AI vs AI screen.
func on_phase(phase: String) -> void:
	setup.visible = phase == "ai_setup"
	result_screen.visible = phase == "ai_result"
	hud.visible = game.mode == "ava" and phase in ["fight", "ai_paused", "ai_judging"]
	pause_label.visible = phase == "ai_paused"


func open_setup() -> void:
	running = false
	batch_total = 0
	set_speed(1.0)
	game.mode = "ava"
	game._set_screen("ai_setup")
	setup.set_backend(AIClient.is_backend_available)
	AIClient.check_health(func(response: Dictionary) -> void: setup.set_backend(bool(response.get("success", false))))


func start_match(p_config: Dictionary) -> void:
	config = p_config
	batch_total = 0
	results.clear()
	set_speed(1.0)
	_begin()


## "Run 10 matches": back to back at 4x, then the table + CSV.
func start_batch(p_config: Dictionary, count: int) -> void:
	config = p_config
	batch_total = count
	results.clear()
	set_speed(BATCH_SPEED)
	_begin()


func set_speed(value: float) -> void:
	Engine.time_scale = value


# ---------------------------------------------------------------------------
# Start of a match
# ---------------------------------------------------------------------------
func _begin() -> void:
	game.mode = "ava"
	game.planet_index = int(config.get("planet", 0))
	game._clear_level()
	game.segment = "boss"
	game._set_screen("fight")
	game._build_boss_arena()             # the same arena as the Player vs AI boss fight
	grid = game.grid
	match_number += 1
	var swap := match_number % 2 == 0     # sides swap every match
	var left := Vector2(210, 585)
	var right := Vector2(game.BOSS_WIDTH - 210, 585)
	blue_fighter = _make_fighter("purple", Color(0.62, 0.8, 1.0), "AI 1", BLUE, right if swap else left)
	red_fighter = _make_fighter("pink", Color(1.0, 0.62, 0.62), "AI 2", RED, left if swap else right)
	game.player = blue_fighter
	game.rival = red_fighter
	blue = _make_controller("blue", blue_fighter, str(config["blue_decision"]), str(config["blue_search"]), 0)
	red = _make_controller("red", red_fighter, str(config["red_decision"]), str(config["red_search"]), RED_OFFSET)
	_spawn_aliens()
	time = 0.0
	search_stats = {}
	side_stats = {"blue": {"count": 0, "nodes": 0, "ms": 0.0}, "red": {"count": 0, "nodes": 0, "ms": 0.0}}
	rules_fired = {}
	csp_solves = 0
	csp_backtracks = 0
	alien_searches = 0
	hits = {blue_fighter: [], red_fighter: []}
	log_lines.clear()
	_csp_busy = false
	running = true
	log_event("Match %d starts: AI 1 on the %s" % [match_number, "right" if swap else "left"])
	_solve_csp()
	game.queue_redraw()
	_refresh_hud()


func _make_fighter(color_name: String, tint: Color, tag: String, tag_color: Color, at: Vector2) -> SpaceFighter:
	var fighter := FighterScript.new() as SpaceFighter
	fighter.configure(game, false, color_name, AI_HEALTH)
	fighter.punch_damage = PUNCH_DAMAGE
	fighter.move_speed = MOVE_SPEED
	fighter.gravity_scale = float(game.PLANETS[game.planet_index]["gravity"])
	fighter.position = at
	fighter.facing = 1 if at.x < game.BOSS_WIDTH * 0.5 else -1
	fighter.strike_requested.connect(game._on_strike)
	fighter.knocked_out.connect(game._on_knockout)
	game.world_layer.add_child(fighter)
	fighter.sprite.modulate = tint
	var name_label: Label = game._label(fighter, tag, Vector2(-40, -112), Vector2(80, 22), 16, tag_color)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return fighter


func _make_controller(side: String, fighter: SpaceFighter, decision: String, search: String, start_index: int):
	var controller = ControllerScript.new()
	controller.setup(side, decision, search, start_index)
	controller.use_fuzzy = true                      # fuzzy aggression for both fighters
	controller.base_speed = MOVE_SPEED
	controller.base_attack_interval = fighter.attack_interval
	controller.head_label = game._label(fighter, "", Vector2(-80, -92), Vector2(160, 20), 13, Color("f2f6ff"))
	controller.head_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return controller


## Two Alien Patrols (FSM + A*) that attack whichever fighter is closer.
func _spawn_aliens() -> void:
	for spot in [Vector2(520, 590), Vector2(1080, 590)]:
		var alien := AlienScript.new() as SpaceFighter
		alien.set("species", game.aliens.size())
		alien.configure(game, false, "pink", 45.0)
		alien.position = spot
		alien.facing = -1 if spot.x > game.BOSS_WIDTH * 0.5 else 1
		alien.strike_requested.connect(game._on_strike)
		alien.knocked_out.connect(game._on_knockout)
		game.world_layer.add_child(alien)
		alien.get("state_label").visible = game.show_states
		game.aliens.append(alien)


# ---------------------------------------------------------------------------
# Every frame
# ---------------------------------------------------------------------------
func update(delta: float) -> void:
	if not running:
		return
	time += delta
	var middle := (blue_fighter.position.x + red_fighter.position.x) * 0.5
	game.camera.position = game.camera.position.lerp(Vector2(clampf(middle, 640.0, game.BOSS_WIDTH - 640.0), 360.0), minf(1.0, delta * 3.0))
	blue.update(delta, blue_fighter, red_fighter, self)
	red.update(delta, red_fighter, blue_fighter, self)
	for alien in game.aliens:
		if is_instance_valid(alien) and not alien.knocked_out_state:
			alien.call("think", delta, _closer_fighter(alien), grid)
	_update_pickups(delta)
	if time >= MATCH_SECONDS:
		_finish("time limit")
	_hud_timer -= delta
	if _hud_timer <= 0.0:
		_hud_timer = 0.1
		_refresh_hud()


func _closer_fighter(alien: SpaceFighter) -> SpaceFighter:
	var blue_distance := alien.position.distance_to(blue_fighter.position)
	var red_distance := alien.position.distance_to(red_fighter.position)
	return blue_fighter if blue_distance <= red_distance else red_fighter


# ---------------------------------------------------------------------------
# CSP pickups: placed at the start and placed again after each pickup
# ---------------------------------------------------------------------------
func _solve_csp() -> void:
	if _csp_busy:
		return
	_csp_busy = true
	var candidates: Array = []
	for cell in grid.floor_cells():
		candidates.append([cell.x, cell.y])
	var walls: Array = []
	for cell in grid.solid:
		walls.append([cell.x, cell.y])
	var enemies: Array = []                          # keep items away from every fighter
	var everyone: Array = [blue_fighter, red_fighter]
	everyone.append_array(game.aliens)
	for fighter in everyone:
		if is_instance_valid(fighter):
			var tile: Vector2i = grid.to_cell(fighter.position)
			enemies.append([tile.x, tile.y])
	var request := {"candidates": candidates, "walls": walls, "enemies": enemies, "boss_spawn": [-100, -100],
		"level_width": grid.size.x, "min_enemy_distance": 3, "min_spacing": 4, "seed": randi() % 100000}
	AIClient.request_items(request, _on_csp.bind(match_number))


func _on_csp(response: Dictionary, number: int) -> void:
	_csp_busy = false
	if not running or number != match_number:
		return
	var data: Dictionary = response.get("data", {})
	var spots := {}
	if bool(response.get("success", false)) and bool(data.get("success", false)):
		csp_solves += 1
		csp_backtracks += int(data.get("backtracks", 0))
		for item in data["positions"]:
			spots[item] = grid.to_world(Vector2i(int(data["positions"][item][0]), int(data["positions"][item][1])))
		log_event("CSP placed 5 items (%d backtracks)" % int(data.get("backtracks", 0)))
	else:                                            # fallback: fixed spots, oxygen in each third
		spots = {"oxygen_tank_1": Vector2(300, 600), "safe_dome": Vector2(640, 600), "oxygen_tank_2": Vector2(1300, 600),
			"health_pickup": Vector2(448, 430), "energy_pickup": Vector2(1152, 430)}
		log_event("CSP fallback: fixed item spots")
	game._place_level_items(spots)


func pickups() -> Array:
	var nodes: Array = []
	for item in game.pickups:
		if is_instance_valid(item["node"]):
			nodes.append(item["node"])
	return nodes


## Health +30 HP, energy +40, oxygen tank +15 HP and +20 energy. The dome heals slowly.
func _update_pickups(delta: float) -> void:
	for index in range(game.pickups.size() - 1, -1, -1):
		var item: Dictionary = game.pickups[index]
		var sprite: Node2D = item["node"]
		for fighter in [blue_fighter, red_fighter]:
			if fighter.knocked_out_state or sprite.position.distance_to(fighter.position) > 53.0:
				continue
			match str(item["kind"]):
				"health":
					fighter.health = minf(fighter.max_health, fighter.health + 30.0)
				"energy":
					fighter.energy = minf(100.0, fighter.energy + 40.0)
				_:
					fighter.health = minf(fighter.max_health, fighter.health + 15.0)
					fighter.energy = minf(100.0, fighter.energy + 20.0)
			log_event("%s took the %s pickup -> CSP solves again" % ["BLUE" if fighter == blue_fighter else "RED", item["kind"]])
			game.play_sound("gem")
			sprite.queue_free()
			game.pickups.remove_at(index)
			_solve_csp()
			break
	if game.dome_center != Vector2.INF:
		for fighter in [blue_fighter, red_fighter]:
			if fighter.position.distance_to(game.dome_center) < game.DOME_RADIUS and not fighter.knocked_out_state:
				fighter.health = minf(fighter.max_health, fighter.health + DOME_HEAL * delta)


# ---------------------------------------------------------------------------
# The "arena" interface used by the brains
# ---------------------------------------------------------------------------
func energy_of(fighter: SpaceFighter) -> float:
	return fighter.energy


## Special move: a 3-shot volley (50 energy). The brain then rests 1.5 s.
func perform_special(fighter: SpaceFighter, foe: SpaceFighter) -> bool:
	if fighter.special_cooldown > 0.0 or fighter.energy < 50.0:
		return false
	fighter.energy -= 50.0
	fighter.special_cooldown = 4.0
	var toward := 1 if foe.position.x >= fighter.position.x else -1
	fighter.facing = toward
	for lane in [-30.0, -8.0, 14.0]:
		game._spawn_projectile(fighter.position + Vector2(toward * 40.0, lane), toward, fighter == blue_fighter, fighter.punch_damage, fighter)
	game.play_sound("magic")
	return true


func record_search(planner) -> void:
	for pair in [["blue", blue], ["red", red]]:
		if pair[1] != null and pair[1].planner == planner:
			var s: Dictionary = search_stats.get(planner.used, {"count": 0, "nodes": 0, "ms": 0.0, "path": 0})
			s["count"] += 1
			s["nodes"] += planner.nodes
			s["ms"] += planner.time_ms
			s["path"] += planner.path.size()
			search_stats[planner.used] = s
			side_stats[pair[0]]["count"] += 1
			side_stats[pair[0]]["nodes"] += planner.nodes
			side_stats[pair[0]]["ms"] += planner.time_ms
	if game.show_paths:
		game.queue_redraw()


func record_rules(fired: Array) -> void:
	for name in fired:
		rules_fired[name] = int(rules_fired.get(name, 0)) + 1


## Damage this fighter took in the last 5 s (fuzzy logic input).
func recent_damage_taken(fighter) -> float:
	var total := 0.0
	for hit in hits.get(fighter, []):
		if time - float(hit[0]) < 5.0:
			total += float(hit[1])
	return total


## Called by star_brawl._deal_damage().
func on_damage(attacker, target, dealt: float) -> void:
	if hits.has(target):
		hits[target].append([time, dealt])
	if attacker == blue_fighter:
		blue.damage_dealt += dealt
		blue_fighter.energy = minf(100.0, blue_fighter.energy + 12.0)
	elif attacker == red_fighter:
		red.damage_dealt += dealt
		red_fighter.energy = minf(100.0, red_fighter.energy + 12.0)


## Called by star_brawl._on_knockout() for the two AI fighters.
func on_knockout(fighter) -> void:
	if fighter == blue_fighter or fighter == red_fighter:
		call_deferred("_finish", "knockout")


func log_event(text: String) -> void:
	log_lines.append("%5.1f s   %s" % [time, text])
	while log_lines.size() > 5:
		log_lines.pop_front()
	if is_instance_valid(log_label):
		log_label.text = "\n".join(log_lines)


## Lines for the P key: [path, colour] for each fighter.
func path_lines() -> Array:
	var lines: Array = []
	if blue != null and blue.active:
		lines.append([blue.planner.path, BLUE])
	if red != null and red.active:
		lines.append([red.planner.path, RED])
	return lines


func deactivate() -> void:
	running = false
	for controller in [blue, red]:
		if controller != null:
			controller.active = false


# ---------------------------------------------------------------------------
# End of a match: the referee (forward chaining) decides
#   IF blue_hp <= 0 THEN red_wins ; IF red_hp <= 0 THEN blue_wins ; IF time_up THEN compare_hp
# ---------------------------------------------------------------------------
func _finish(reason: String) -> void:
	if not running:
		return
	running = false
	blue.active = false
	red.active = false
	game._set_screen("ai_judging")                    # freeze the fighters while the referee answers
	var facts := {"blue_hp": _hp(blue_fighter), "red_hp": _hp(red_fighter), "time_up": reason == "time limit"}
	AIClient.request_rules(facts, _on_referee.bind(facts, reason, match_number))


func _on_referee(response: Dictionary, facts: Dictionary, reason: String, number: int) -> void:
	if number != match_number or game.mode != "ava":
		return
	var new_facts: Dictionary = {}
	var fired: Array = []
	if response.get("success", false):
		new_facts = response["data"].get("new_facts", {})
		fired = response["data"].get("fired_rules", [])
	else:                                            # fallback: the same rules, checked here
		if facts["blue_hp"] <= 0.0:
			new_facts["red_wins"] = true
			fired.append("blue_down")
		if facts["red_hp"] <= 0.0:
			new_facts["blue_wins"] = true
			fired.append("red_down")
		if facts["time_up"]:
			new_facts["compare_hp"] = true
			fired.append("time_up")
	record_rules(fired)
	var winner := "draw"
	var deciding := "none"
	if new_facts.get("red_wins", false) and not new_facts.get("blue_wins", false):
		winner = "red"
		deciding = "blue_hp <= 0 -> red_wins"
	elif new_facts.get("blue_wins", false) and not new_facts.get("red_wins", false):
		winner = "blue"
		deciding = "red_hp <= 0 -> blue_wins"
	elif new_facts.get("compare_hp", false):
		deciding = "time_up -> compare_hp"
		if facts["blue_hp"] > facts["red_hp"]:
			winner = "blue"
		elif facts["red_hp"] > facts["blue_hp"]:
			winner = "red"
	var result := _result(winner, reason, deciding)
	last_result = result
	if batch_total > 0:
		results.append(result)
		if results.size() < batch_total:
			call_deferred("_begin")                  # next match of the batch
			return
		set_speed(1.0)
		var saved := _save_csv()
		game._set_screen("ai_result")
		result_screen.show_batch(results, saved)
		return
	set_speed(1.0)
	game._set_screen("ai_result")
	result_screen.show_match(result)


func _hp(fighter: SpaceFighter) -> float:
	return fighter.health / fighter.max_health * 100.0


func _result(winner: String, reason: String, deciding: String) -> Dictionary:
	var r := {"winner": winner, "reason": reason, "deciding_rule": deciding, "time": time,
		"search": search_stats.duplicate(true), "rules": rules_fired.duplicate(),
		"csp": {"solves": csp_solves, "backtracks": csp_backtracks}, "alien_searches": alien_searches}
	for pair in [["blue", blue, blue_fighter], ["red", red, red_fighter]]:
		var c = pair[1]
		var s: Dictionary = side_stats[pair[0]]
		r[pair[0]] = {
			"decision": c.decision_algorithm, "damage": c.damage_dealt, "health": _hp(pair[2]),
			"decisions": c.decisions, "avg_decision_ms": c.decision_ms / maxf(1.0, c.decisions),
			"nodes_evaluated": c.nodes_evaluated, "nodes_pruned": c.nodes_pruned,
			"fuzzy_updates": c.fuzzy_updates, "modes": c.mode_counts.duplicate(),
			"searches": s["count"], "avg_nodes": float(s["nodes"]) / maxf(1.0, s["count"]), "avg_ms": s["ms"] / maxf(1.0, s["count"]),
		}
	return r


## Writes the 10-match results to user://ai_vs_ai_results.csv. Returns the full path.
func _save_csv() -> String:
	var file := FileAccess.open(CSV_PATH, FileAccess.WRITE)
	if file == null:
		return "(could not save CSV)"
	file.store_line("match,winner,time_s,how,blue_decision,red_decision,blue_damage,red_damage,blue_avg_nodes,red_avg_nodes,blue_avg_search_ms,red_avg_search_ms")
	for i in results.size():
		var r: Dictionary = results[i]
		file.store_line("%d,%s,%.1f,%s,%s,%s,%.0f,%.0f,%.1f,%.1f,%.3f,%.3f" % [i + 1, r["winner"], r["time"], r["reason"],
			r["blue"]["decision"], r["red"]["decision"], r["blue"]["damage"], r["red"]["damage"],
			r["blue"]["avg_nodes"], r["red"]["avg_nodes"], r["blue"]["avg_ms"], r["red"]["avg_ms"]])
	file.close()
	return ProjectSettings.globalize_path(CSV_PATH)


# ---------------------------------------------------------------------------
# Keys: P paths (handled by star_brawl), 1 / 2 / 4 speed, Esc pause, Q quit when paused
# ---------------------------------------------------------------------------
func handle_key(keycode: int) -> void:
	match keycode:
		KEY_1:
			set_speed(1.0)
		KEY_2:
			set_speed(2.0)
		KEY_4:
			set_speed(4.0)
		KEY_ESCAPE:
			if game.phase == "fight":
				game._set_screen("ai_paused")
			elif game.phase == "ai_paused":
				game._set_screen("fight")
			elif game.phase == "ai_result":
				open_setup()
			elif game.phase == "ai_setup":
				game._show_home()
		KEY_Q:
			if game.phase == "ai_paused":
				deactivate()
				game._clear_level()
				open_setup()
	_refresh_hud()


# ---------------------------------------------------------------------------
# HUD: blue panel left, red panel right, timer on top, rule log at the bottom
# ---------------------------------------------------------------------------
func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.ui_layer.add_child(hud)
	for side in ["blue", "red"]:
		var x := 12.0 if side == "blue" else 848.0
		var color := BLUE if side == "blue" else RED
		var back := ColorRect.new()
		back.position = Vector2(x, 8)
		back.size = Vector2(420, 158)
		back.color = Color(0.03, 0.07, 0.16, 0.86)
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud.add_child(back)
		var bar_back := ColorRect.new()
		bar_back.position = Vector2(x + 10, 38)
		bar_back.size = Vector2(400, 12)
		bar_back.color = Color("152c43")
		hud.add_child(bar_back)
		var bar := ColorRect.new()
		bar.position = Vector2(x + 12, 40)
		bar.size = Vector2(396, 8)
		bar.color = color
		hud.add_child(bar)
		var energy_back := ColorRect.new()
		energy_back.position = Vector2(x + 10, 52)
		energy_back.size = Vector2(400, 6)
		energy_back.color = Color("152c43")
		hud.add_child(energy_back)
		var energy_bar := ColorRect.new()
		energy_bar.position = Vector2(x + 12, 53)
		energy_bar.size = Vector2(396, 4)
		energy_bar.color = Color("44edcf")
		hud.add_child(energy_bar)
		panels[side] = {
			"name": game._label(hud, "", Vector2(x + 10, 12), Vector2(400, 24), 17, color),
			"bar": bar,
			"energy_bar": energy_bar,
			"text": game._label(hud, "", Vector2(x + 10, 61), Vector2(400, 100), 14, Color("e4efff")),
		}
	timer_label = game._label(hud, "", Vector2(440, 8), Vector2(400, 44), 34, Color("fff1b5"))
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label = game._label(hud, "", Vector2(440, 52), Vector2(400, 22), 14, Color("a6dce9"))
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var log_back := ColorRect.new()
	log_back.position = Vector2(0, 632)
	log_back.size = Vector2(1280, 88)
	log_back.color = Color(0.02, 0.05, 0.12, 0.86)
	log_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(log_back)
	log_label = game._label(hud, "", Vector2(14, 634), Vector2(860, 86), 13, Color("cfe3ff"))
	game._label(hud, "P paths   F alien states\n1 / 2 / 4 speed\nEsc pause", Vector2(1010, 642), Vector2(260, 70), 14, Color("eff8ff"))
	pause_label = game._label(hud, "PAUSED\nEsc resume   •   Q quit to setup", Vector2(0, 300), Vector2(1280, 90), 30, Color("ffffff"))
	pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _refresh_hud() -> void:
	if not is_instance_valid(blue_fighter) or blue == null:
		return
	var remaining := maxf(0.0, MATCH_SECONDS - time)
	timer_label.text = "%02d:%02d" % [int(remaining) / 60, int(remaining) % 60]
	var where := "MATCH %d / %d" % [results.size() + 1, batch_total] if batch_total > 0 else str(game.PLANETS[game.planet_index]["name"])
	info_label.text = "%s   •   SPEED %dx" % [where, roundi(Engine.time_scale)]
	for pair in [["blue", blue, blue_fighter, "AI 1 (BLUE)"], ["red", red, red_fighter, "AI 2 (RED)"]]:
		var panel: Dictionary = panels[pair[0]]
		panel["name"].text = "%s  •  %s" % [pair[3], DECISION_NAMES[pair[1].decision_algorithm]]
		panel["bar"].size.x = 396.0 * clampf(pair[2].health / pair[2].max_health, 0.0, 1.0)
		panel["energy_bar"].size.x = 396.0 * clampf(pair[2].energy / 100.0, 0.0, 1.0)
		panel["energy_bar"].color = Color("ffd84a") if pair[2].energy >= 50.0 else Color("44edcf")
		panel["text"].text = pair[1].panel_text(pair[2])
