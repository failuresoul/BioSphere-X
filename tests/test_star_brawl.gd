extends Node

const GameScene = preload("res://scenes/star_brawl/star_brawl.tscn")
const PathfinderScript = preload("res://scripts/utils/modular_pathfinder.gd")
const PlanetFacts = preload("res://scenes/star_brawl/planet_facts.gd")
const GuardianScript = preload("res://scenes/star_brawl/planet_guardian.gd")

var game: Node2D
var failures := 0


func _ready() -> void:
	game = GameScene.instantiate()
	game.progress_path = "user://orbit_breakers_test_progress.cfg"
	add_child(game)
	await get_tree().process_frame
	game.unlocked_planet = 0
	for index in game.stage_stars.size():
		game.stage_stars[index] = 0
	game.selected_pilot = 0
	game.home_screen.set_pilot(0)
	game.player_max_health = 100.0
	game.player_damage = 13.0
	game.player_speed = 265.0
	_check(game.phase == "home" and game.home_screen.visible, "Home screen loads first")
	game.home_screen.settings_path = "user://biosphere_x_settings_test.cfg"
	game.home_screen._show_settings()
	game.home_screen.volume_slider.value = 45
	var settings_progress := ConfigFile.new()
	_check(game.home_screen.settings_panel.visible and settings_progress.load(game.home_screen.settings_path) == OK and int(settings_progress.get_value("audio", "volume", -1)) == 45, "Home settings opens and saves the sound level")
	game.home_screen.fullscreen_toggle.button_pressed = true
	settings_progress.load(game.home_screen.settings_path)
	_check(bool(settings_progress.get_value("display", "fullscreen", false)), "Fullscreen preference saves")
	game.home_screen.fullscreen_toggle.button_pressed = false
	game.home_screen.close_controls()
	_check(not game.home_screen.settings_panel.visible, "Home settings closes")
	game.home_screen.volume_slider.value = 80
	_check(game.PLANETS.size() == 10 and game.stage_stars.size() == 10 and game.map_screen.planet_buttons.size() == 10, "Campaign has ten selectable planet chapters")
	_check(PlanetFacts.DATA.size() == 10 and PlanetFacts.at(5)["name"] == "55 Cancri e" and is_equal_approx(float(PlanetFacts.at(5)["year"]), 0.7), "NASA catalog data covers all ten planets")
	var special_kinds: Array[String] = []
	for special in game.BOSS_SPECIALS:
		var kind := str(special["kind"])
		if not special_kinds.has(kind):
			special_kinds.append(kind)
	_check(special_kinds.size() == 10, "Every guardian has a different special attack")
	var body_designs: Array[String] = []
	for design in GuardianScript.DESIGNS:
		var body_name := str(design["body"])
		if not body_designs.has(body_name):
			body_designs.append(body_name)
	_check(body_designs.size() == 10, "Every guardian has a different downloaded body design")
	for chapter in game.PLANETS.size():
		_check(str(game.PLANETS[chapter]["world"]) == str(PlanetFacts.at(chapter)["name"]), "Chapter %d matches its catalogued planet" % (chapter + 1))
	game.home_screen._choose_pilot(1)
	_check(game.selected_pilot == 1 and game.home_screen.pilot_name.text == "CAPTAIN SOL", "Home character selector changes the human pilot")
	var character_progress := ConfigFile.new()
	_check(character_progress.load(game.progress_path) == OK and int(character_progress.get_value("pilot", "character", -1)) == 1, "Pilot choice saves immediately")
	game.start_run()
	_check(game.phase == "map" and game.map_screen.visible, "Play opens the galaxy map")
	game._select_planet(1)
	_check(game.phase == "map", "Locked planets cannot launch")
	game._select_planet(0)
	_check(game.phase == "briefing" and game.campaign_screen.visible and game.planet_index == 0, "Planet selection opens a level preview")
	game._on_campaign_action("start")
	_check(game.phase == "fight" and game.planet_index == 0 and game.segment == "explore", "Start level begins exploration")
	_check(game.get_arena_width() == 3000.0 and game.camera.limit_right == 3000, "Arena spans 3,000 pixels and scrolls")
	_check(game.aliens.size() == 3 and game.hazards.size() == 5 and is_instance_valid(game.portal), "First planet has patrols, traps and an exit portal")
	_check(not is_instance_valid(game.rival), "Boss is absent during exploration")
	var has_wingmate := false
	for actor in game.world_layer.get_children():
		if actor is Sprite2D and actor.texture != null and "robot_blue" in actor.texture.resource_path:
			has_wingmate = true
	_check(not has_wingmate, "No wingmate actor is present")
	game._show_pause()
	_check(game.phase == "paused", "Fight can be paused")
	game._resume_fight()
	_check(game.phase == "fight", "Fight can resume")
	_check(is_instance_valid(game.player.pilot_art) and not game.player.sprite.visible and game.player.pilot_variant == 1 and game.aliens[0].scale.x < 0.8, "Selected human astronaut replaces the pilot sprite")
	for algorithm in game.PATH_ALGORITHMS:
		var path: Dictionary = PathfinderScript.search(algorithm, Vector2i(1, 5), Vector2i(10, 5), [], Vector2i(13, 6), {
			"allow_diagonal": true, "depth_limit": 78, "max_depth": 78
		})
		_check(bool(path.get("success", false)), "%s can guide the rival" % algorithm)
	game.player.position = Vector2(1520, 585)
	game._physics_process(0.2)
	_check(game.camera.position.x > 640.0, "Camera follows the pilot into the larger arena")
	game.player.position = Vector2(180, 585)
	game.camera.position = Vector2(640, 360)
	var alien: SpaceFighter = game.aliens[0]
	alien.position = game.player.position + Vector2(80, 0)
	var alien_before := alien.health
	game._on_strike(game.player, "punch")
	_check(alien.health < alien_before, "Pilot can damage alien patrols")
	game.player.invulnerable = 0.0
	alien.facing = -1
	var melee_before: float = game.player.health
	game._on_strike(alien, "punch")
	_check(game.player.health < melee_before, "Alien melee attacks the pilot")
	game.player.health = game.player.max_health
	game.player.invulnerable = 0.0
	alien.invulnerable = 0.0
	var blast_before: float = alien.health
	game._spawn_projectile(alien.position, 1, true, 5.0)
	game._update_projectiles(0.0)
	_check(alien.health < blast_before, "Pilot blaster can hit a patrol")
	game._spawn_projectile(game.player.position, -1, false, 5.0)
	game._update_projectiles(0.0)
	_check(game.player.health < game.player.max_health, "Enemy blaster can hit the pilot")
	game.player.health = game.player.max_health
	game.player.invulnerable = 0.0
	alien.position = Vector2(600, 590)
	game.player.position = Vector2(835, 590)
	game.player.invulnerable = 0.0
	var health_before: float = game.player.health
	game._update_hazards()
	_check(game.player.health < health_before, "Spike field damages the pilot")
	game.player.health = game.player.max_health
	game.player.invulnerable = 0.0
	game.player.position = Vector2(180, 585)
	alien.invulnerable = 0.0
	alien.take_damage(1000.0, 1)
	_check(game.phase == "fight" and not game.aliens.has(alien), "Defeating a patrol does not end exploration")
	game._finish_planet()
	_check(game.phase == "fight" and game.unlocked_planet == 0, "Planet cannot be cleared before its boss portal")
	game.player.position = Vector2(game.PORTAL_X, 585)
	game._check_portal()
	await get_tree().process_frame
	_check(game.segment == "boss" and game.get_arena_width() == game.BOSS_WIDTH and game.camera.limit_right == int(game.BOSS_WIDTH), "Portal opens a separate boss arena")
	_check(is_instance_valid(game.rival) and game.rival.sprite.texture != null and game.aliens.is_empty() and game.hazards.is_empty(), "Boss appears after patrols and traps clear")
	_check_guardian(0)
	var planning_start := Time.get_ticks_usec()
	game._plan_rival_route()
	print("  Rival route planning: %.1f ms" % ((Time.get_ticks_usec() - planning_start) / 1000.0))
	game.route_index = 0
	var slowest_route_ms := 0.0
	for index in game.PATH_ALGORITHMS.size():
		var route_start := Time.get_ticks_usec()
		game._plan_rival_route()
		var route_ms := (Time.get_ticks_usec() - route_start) / 1000.0
		slowest_route_ms = maxf(slowest_route_ms, route_ms)
	print("  Slowest rival route: %.1f ms" % slowest_route_ms)
	_check(game.route_index == game.PATH_ALGORITHMS.size(), "Boss route planning cycles through every pathfinder")
	game.rival.position = Vector2(1320, 585)
	game.rival.desired_direction = 0.0
	game._drive_rival()
	_check(game.rival.desired_direction == 0.0, "Champion waits until the pilot approaches")
	game.rival.position = game.player.position + Vector2(60, 0)
	game.player.facing = 1
	game._on_strike(game.player, "punch")
	_check(game.rival.health < game.rival.max_health, "Close strike damages the rival")
	game.player.attack_cooldown = 0.0
	game.player.punch()
	_check(game.player.attack_anim > 0.0, "Close strike plays a dedicated attack animation")
	game.rival.invulnerable = 0.0
	var before: float = game.rival.health
	game.pulse_charge = 100.0
	game._orbit_pulse()
	_check(game.rival.health < before and game.pulse_charge == 0.0, "Orbit Pulse hits and consumes energy")
	game.rival.invulnerable = 0.0
	game.rival.take_damage(1000.0, 1)
	for frame in 240:
		if game.phase != "fight":
			break
		await get_tree().process_frame
	_check(game.phase == "clear" and game.campaign_screen.visible and game.pending_upgrade, "AI referee opens the level result")
	_check(game.unlocked_planet == 1 and game.stage_stars[0] > 0, "Victory unlocks the next planet and saves a rating")
	game._on_campaign_action("upgrade")
	_check(game.phase == "upgrade", "First clear leads to the upgrade screen")
	game._on_campaign_action("power")
	_check(game.phase == "map" and game.player_damage == 18.0, "Upgrade returns to the galaxy map")
	var saved_progress := ConfigFile.new()
	_check(saved_progress.load(game.progress_path) == OK and int(saved_progress.get_value("campaign", "unlocked_planet", -1)) == 1 and float(saved_progress.get_value("pilot", "damage", 0.0)) == 18.0, "Unlocked planet and upgrade persist together")
	game._select_planet(1)
	_check(game.phase == "briefing" and game.planet_index == 1, "Second planet has a preview")
	game._on_campaign_action("start")
	_check(game.phase == "fight" and game.segment == "explore" and game.player_damage == 18.0, "Upgrade carries into planet two")
	_check(game.PLANETS[1]["boss"] == "minimax", "Second rival uses minimax")
	game.player.position = Vector2(game.PORTAL_X, 585)
	game._check_portal()
	await get_tree().process_frame
	_check(game.segment == "boss" and is_instance_valid(game.rival), "Second planet portal opens its boss duel")
	_check_guardian(1)
	game._finish_planet()
	_check(game.phase == "clear", "Second planet opens its result screen")
	game._on_campaign_action("upgrade")
	game._on_campaign_action("armor")
	_check(game.phase == "map" and game.unlocked_planet == 2, "Second victory unlocks the third planet")
	game._select_planet(2)
	game._on_campaign_action("start")
	_check(game.planet_index == 2 and game.player.max_health == 125.0, "Armor upgrade carries into planet three")
	_check(game.PLANETS[2]["boss"] == "mcts", "Third rival uses MCTS")
	game.player.position = Vector2(game.PORTAL_X, 585)
	game._check_portal()
	await get_tree().process_frame
	_check(game.segment == "boss" and is_instance_valid(game.rival), "Third planet portal opens its boss duel")
	_check_guardian(2)
	game._finish_planet()
	_check(game.phase == "clear" and game.pending_upgrade, "Third chapter continues the story")
	game._on_campaign_action("upgrade")
	game._on_campaign_action("flux")
	for chapter in range(3, game.PLANETS.size()):
		game._select_planet(chapter)
		_check(game.phase == "briefing" and game.planet_index == chapter and game.campaign_screen.description.text == game.PLANETS[chapter]["story"], "Chapter %d previews its story" % (chapter + 1))
		game._on_campaign_action("start")
		_check(game.phase == "fight" and game.segment == "explore" and game.player.pilot_variant == 1 and is_instance_valid(game.portal), "Chapter %d starts with the selected astronaut and a portal" % (chapter + 1))
		game.player.position = Vector2(game.PORTAL_X, 585)
		game._check_portal()
		await get_tree().process_frame
		_check(game.segment == "boss" and is_instance_valid(game.rival), "Chapter %d portal opens its boss duel" % (chapter + 1))
		_check_guardian(chapter)
		if chapter == 5:
			game.player.position = game.rival.position + Vector2(180, 0)
			game.player.invulnerable = 0.0
			var health_before_forge: float = game.player.health
			game._begin_boss_special()
			_check(game.boss_special["kind"] == "forge" and float(game.boss_special["remaining"]) < 0.78, "Forge Titan telegraphs its faster special attack")
			game._resolve_boss_special()
			_check(game.player.health < health_before_forge and game.boss_special.is_empty(), "Forge Slam lands after its telegraph")
			game.player.health = game.player.max_health
		game._finish_planet()
		_check(game.phase == "clear" and game.campaign_screen.description.text == game.PLANETS[chapter]["outro"], "Chapter %d reveals the next story beat" % (chapter + 1))
		if chapter < game.PLANETS.size() - 1:
			game._on_campaign_action("upgrade")
			game._on_campaign_action("armor")
			_check(game.phase == "map" and game.unlocked_planet == chapter + 1, "Chapter %d unlocks the next world" % (chapter + 1))
	_check(not game.pending_upgrade and game.campaign_screen.heading.text == "THE ARK AWAKENS", "Tenth chapter completes the Ark storyline")
	game._on_campaign_action("map")
	_check(game.phase == "map" and game.stage_stars[9] > 0, "Completed campaign returns to a rated ten-planet map")
	game._show_home()
	_check(game.phase == "home", "Map can return home")
	game.home_screen._show_restart_confirmation()
	_check(game.home_screen.restart_panel.visible and game.stage_stars[9] > 0, "Restart asks before clearing progress")
	game.home_screen.close_controls()
	_check(not game.home_screen.restart_panel.visible and game.stage_stars[9] > 0, "Cancel keeps campaign progress")
	game.home_screen._show_restart_confirmation()
	game.home_screen._confirm_restart()
	var restarted_progress := ConfigFile.new()
	_check(game.unlocked_planet == 0 and game._completed_count() == 0 and game.player_max_health == 100.0 and game.player_damage == 13.0 and game.player_speed == 265.0 and game.selected_pilot == 1, "Confirmed restart resets campaign and keeps pilot")
	_check(restarted_progress.load(game.progress_path) == OK and int(restarted_progress.get_value("campaign", "unlocked_planet", -1)) == 0, "Confirmed restart saves the new campaign")
	print("BioSphere X: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	game.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(3.1).timeout
	get_tree().quit(0 if failures == 0 else 1)


func _check_guardian(chapter: int) -> void:
	var guardian: SpaceFighter = game.rival as SpaceFighter
	_check(guardian != null and guardian.get_script() == GuardianScript and int(guardian.get("guardian_index")) == chapter, "Chapter %d summons its own guardian design" % (chapter + 1))
	if guardian == null:
		return
	var art_root := guardian.get("character_root") as Node2D
	_check(is_instance_valid(art_root) and _has_loaded_parts(art_root), "Chapter %d boss uses downloaded character artwork" % (chapter + 1))
	_check(is_equal_approx(guardian.scale.x, 1.25 + chapter * 0.045) and guardian.hit_radius >= 75.0 + chapter * 2.3, "Chapter %d guardian grows with the journey" % (chapter + 1))
	_check(guardian.attack_interval <= 0.56 - chapter * 0.03 and game.BOSS_SPECIALS[chapter]["kind"] != "", "Chapter %d guardian gains a faster attack rhythm and distinct move" % (chapter + 1))
	_check(is_equal_approx(guardian.max_health, 100.0 + chapter * 28.0) and is_equal_approx(guardian.punch_damage, 9.0 + chapter * 2.0) and game.boss_base_speed >= 220.0 + chapter * 17.0, "Chapter %d guardian gains health, damage and movement speed" % (chapter + 1))


func _has_loaded_parts(root: Node) -> bool:
	if root == null:
		return false
	var sprite_count := 0
	for node in root.get_children():
		if node is Sprite2D:
			sprite_count += 1
			if node.texture == null:
				return false
		elif node is Node2D:
			if not _has_loaded_parts(node):
				return false
	return sprite_count > 0 or root.get_child_count() > 0


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  [PASS] %s" % label)
	else:
		failures += 1
		push_error("  [FAIL] %s" % label)
