extends Node2D

const FighterScript = preload("res://scenes/star_brawl/space_fighter.gd")
const GuardianScript = preload("res://scenes/star_brawl/planet_guardian.gd")
const AlienScript = preload("res://scenes/star_brawl/alien_enemy.gd")
const PlanetFacts = preload("res://scenes/star_brawl/planet_facts.gd")
const PathfinderScript = preload("res://scripts/utils/modular_pathfinder.gd")
const HomeScreenScript = preload("res://scenes/star_brawl/home_screen.gd")
const GalaxyMapScript = preload("res://scenes/star_brawl/galaxy_map.gd")
const CampaignScreenScript = preload("res://scenes/star_brawl/campaign_screen.gd")
const PortalGateScript = preload("res://scenes/star_brawl/portal_gate.gd")
const PilotAvatarScript = preload("res://scenes/star_brawl/pilot_avatar.gd")
const ASSET := "res://assets/star_brawl/"
const PATH_ALGORITHMS := ["astar", "bfs", "dfs", "dls", "iddfs", "bidirectional", "greedy"]
const BOSS_SPECIALS := [
	{"kind": "quake", "name": "PHANTOM SHOCK"},
	{"kind": "volley", "name": "SOLAR VOLLEY"},
	{"kind": "blink", "name": "ECLIPSE STEP"},
	{"kind": "shards", "name": "GLASS STORM"},
	{"kind": "freeze", "name": "FROST WAVE"},
	{"kind": "forge", "name": "FORGE SLAM"},
	{"kind": "nova", "name": "LUMEN PULSE"},
	{"kind": "beam", "name": "HALO BEAM"},
	{"kind": "rift", "name": "RIFT STRIKE"},
	{"kind": "oracle", "name": "ORACLE VERDICT"}
]
const ARENA_WIDTH := 3000.0
const BOSS_WIDTH := 1600.0
const PORTAL_X := 2860.0
const PLANETS := [
	{"name": "VERDANT NEBULA", "world": "TRAPPIST-1 e", "chapter": "THE FIRST SIGNAL", "story": "A distress beacon from the vanished Horizon Ark reaches you through the green storms.", "outro": "The beacon is real. The Ark's crew survived and left a trail through the stars.", "boss_line": "The first guardian blocks the signal.", "rival": "MINT PHANTOM", "color": "pink", "planet": "planet03", "accent": Color("44edcf"), "sky": Color("4468b7"), "horizon": Color("83a9dc"), "gravity": 0.92, "boss": "alpha_beta"},
	{"name": "CRIMSON DRIFT", "world": "LHS 1140 b", "chapter": "BROKEN CONVOY", "story": "Follow the Ark's supply route beneath a dim red star to find its missing convoy.", "outro": "A stolen star chart points to a silent relay beyond the dark horizon.", "boss_line": "The raider guards the stolen chart.", "rival": "SOLAR RAIDER", "color": "yellow", "planet": "planet08", "accent": Color("ffb35a"), "sky": Color("674a9a"), "horizon": Color("ba85b8"), "gravity": 1.06, "boss": "minimax"},
	{"name": "VIOLET ECLIPSE", "world": "Kepler-452 b", "chapter": "THE FALSE ECHO", "story": "The relay repeats a human plea, but its source is an unknown AI guardian.", "outro": "The plea is a warning: the guardians sealed the Ark on purpose.", "boss_line": "The relay's keeper tests your trust.", "rival": "VOID EMPRESS", "color": "purple", "planet": "planet07", "accent": Color("c99bff"), "sky": Color("42499b"), "horizon": Color("9381bf"), "gravity": 0.82, "boss": "mcts"},
	{"name": "GLASS MERIDIAN", "world": "GJ 667 C c", "chapter": "SHATTERED LOG", "story": "Find the Ark's flight log among glass ridges before the next storm erases it.", "outro": "The log names ORACLE, the AI that moved the crew to a hidden sanctuary.", "boss_line": "The sentinel carries the flight log.", "rival": "GLASS SENTINEL", "color": "pink", "planet": "planet05", "accent": Color("9be8f1"), "sky": Color("588caa"), "horizon": Color("a6d0dd"), "gravity": 0.96, "boss": "alpha_beta"},
	{"name": "FROSTWAKE", "world": "Proxima Centauri b", "chapter": "FROZEN WITNESS", "story": "Search frozen escape pods for someone who can explain ORACLE's lockdown.", "outro": "A survivor says ORACLE is shielding the crew from a failing star core.", "boss_line": "The judge will not let the pods open.", "rival": "FROST JUDGE", "color": "purple", "planet": "planet07", "accent": Color("addef6"), "sky": Color("537ca7"), "horizon": Color("b2d5e5"), "gravity": 0.88, "boss": "minimax"},
	{"name": "EMBER FORGE", "world": "55 Cancri e", "chapter": "THE FORGE KEY", "story": "Enter the forge that builds ORACLE's guards and recover its access key.", "outro": "The key opens a memory vault. ORACLE can still be reasoned with.", "boss_line": "The forge titan holds the key.", "rival": "FORGE TITAN", "color": "yellow", "planet": "planet08", "accent": Color("ffc383"), "sky": Color("9f617e"), "horizon": Color("dfaaae"), "gravity": 1.12, "boss": "mcts"},
	{"name": "LUMEN REEF", "world": "TOI-700 d", "chapter": "MEMORY VAULT", "story": "The memory vault holds the truth about the outbreak that threatened every colony.", "outro": "The crew chose quarantine. ORACLE kept their choice secret to stop panic.", "boss_line": "The keeper protects the vault.", "rival": "LUMEN KEEPER", "color": "pink", "planet": "planet03", "accent": Color("8fe8bd"), "sky": Color("3f8598"), "horizon": Color("a5d6c1"), "gravity": 0.92, "boss": "alpha_beta"},
	{"name": "SILENT HALO", "world": "K2-18 b", "chapter": "THE ANSWER", "story": "Cross the silent defense ring and restore contact with the sleeping crew.", "outro": "The crew answers. They need a stabilizer before the sanctuary can open.", "boss_line": "The watcher severs all transmissions.", "rival": "HALO WATCHER", "color": "purple", "planet": "planet05", "accent": Color("a7b8ff"), "sky": Color("4a5d9a"), "horizon": Color("9facd0"), "gravity": 0.84, "boss": "minimax"},
	{"name": "RIFT GARDEN", "world": "Kepler-186 f", "chapter": "LAST STABILIZER", "story": "Gather the last stabilizer part at the edge of the star core rift.", "outro": "The stabilizer is ready. ORACLE's central gate is the final barrier.", "boss_line": "The rift shade guards the final part.", "rival": "RIFT SHADE", "color": "pink", "planet": "planet03", "accent": Color("e2a1eb"), "sky": Color("765999"), "horizon": Color("b7a7d0"), "gravity": 0.90, "boss": "mcts"},
	{"name": "ORIGIN CORE", "world": "Kepler-62 f", "chapter": "THE ARK AWAKENS", "story": "Reach the Ark sanctuary above Kepler-62 f and ask ORACLE to release the crew.", "outro": "The star core holds. The Ark awakens, and the crew comes home.", "boss_line": "ORACLE will make one final stand.", "rival": "ORACLE PRIME", "color": "yellow", "planet": "planet08", "accent": Color("ffe0a7"), "sky": Color("36588d"), "horizon": Color("8ea9c8"), "gravity": 1.00, "boss": "alpha_beta"}
]

@export var progress_path := "user://orbit_breakers_progress.cfg"

var phase := "home"
var planet_index := 0
var selected_pilot := 0
var segment := "explore"
var portal_pending := false
var unlocked_planet := 0
var stage_stars: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
var player_max_health := 100.0
var player_damage := 13.0
var player_speed := 265.0
var pulse_charge := 50.0
var wins := 0
var alien_kills := 0
var pending_upgrade := false
var ai_aggression := 1.0
var ai_route := "astar"
var route_index := 0
var route_timer := 0.0
var ui_timer := 0.0
var boss_timer := 1.0
var boss_special_timer := 5.0
var boss_special: Dictionary = {}
var boss_impact: Dictionary = {}
var boss_impact_timer := 0.0
var boss_base_speed := 220.0
var fuzzy_timer := 2.0
var suit_timer := 3.0
var suit_mode := "ATTACK"
var hazard_clock := 0.0
var hazard_mask := -1
var alien_attack_clock := 0.0
var chosen_action := ""
var message_timer := 0.0
var pulse_timer := 0.0
var rule_pending := false
var projectiles: Array[Dictionary] = []
var platforms: Array[StaticBody2D] = []
var pickup: Sprite2D
var world_layer: Node2D
var camera: Camera2D
var player: SpaceFighter
var rival: SpaceFighter
var portal: Node2D
var portal_flash: ColorRect
var aliens: Array[SpaceFighter] = []
var hazards: Array[Dictionary] = []
var ui_layer: CanvasLayer
var hud_root: Control
var home_screen: Control
var map_screen: Control
var campaign_screen: Control
var left_fill: ColorRect
var right_fill: ColorRect
var left_name: Label
var right_name: Label
var stage_label: Label
var stage_subtitle: Label
var target_label: Label
var right_bar_back: ColorRect
var meter_fill: ColorRect
var message_label: Label
var order_line: LineEdit
var modal_shade: ColorRect
var modal_title: Label
var modal_subtitle: Label
var modal_body: Label
var modal_buttons: VBoxContainer
var sound_players: Dictionary = {}


func _ready() -> void:
	Engine.max_fps = 45 if "Microsoft Basic Render" in RenderingServer.get_video_adapter_name() else 60
	_load_progress()
	_build_world()
	_build_ui()
	_build_frontend()
	_build_audio()
	_load_planet()
	_show_home()
	if DisplayServer.get_name() != "headless":
		call_deferred("_center_window")


func _center_window() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		return
	var screen := DisplayServer.screen_get_usable_rect(DisplayServer.get_primary_screen())
	var window_size := DisplayServer.window_get_size()
	if "Microsoft Basic Render" in RenderingServer.get_video_adapter_name():
		window_size = Vector2i(1024, 576)
		DisplayServer.window_set_size(window_size)
	var fitted := Vector2i(mini(window_size.x, screen.size.x - 48), mini(window_size.y, screen.size.y - 48))
	if fitted != window_size:
		DisplayServer.window_set_size(fitted)
		window_size = fitted
	DisplayServer.window_set_position(screen.position + (screen.size - window_size) / 2)


func _build_world() -> void:
	world_layer = Node2D.new()
	add_child(world_layer)
	camera = Camera2D.new()
	camera.position = Vector2(640, 360)
	camera.limit_left = 0
	camera.limit_right = int(ARENA_WIDTH)
	camera.limit_top = 0
	camera.limit_bottom = 720
	add_child(camera)
	camera.make_current()


func _build_audio() -> void:
	for sound in ["jump", "hurt", "throw", "select", "magic", "gem"]:
		var node := AudioStreamPlayer.new()
		node.stream = load(ASSET + "audio/sfx_%s.ogg" % sound) as AudioStream
		node.volume_db = -8.0
		add_child(node)
		sound_players[sound] = node


func play_sound(name: String) -> void:
	if sound_players.has(name):
		(sound_players[name] as AudioStreamPlayer).play()


func _draw() -> void:
	var planet: Dictionary = PLANETS[planet_index]
	var facts: Dictionary = PlanetFacts.at(planet_index)
	var sky: Color = facts["sky"] if segment == "explore" else Color(facts["sky"]).darkened(0.21)
	var horizon: Color = facts["horizon"] if segment == "explore" else Color(facts["horizon"]).darkened(0.12)
	var width := get_arena_width()
	for row in 9:
		var ratio := float(row) / 8.0
		draw_rect(Rect2(0, row * 80, width, 81), sky.lerp(horizon, ratio))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4981 + planet_index * 143
	for index in 64 if segment == "explore" else 24:
		var star := Vector2(rng.randf_range(0, width), rng.randf_range(25, 485))
		draw_circle(star, 2.0 if index % 10 == 0 else 1.0, Color(0.94, 0.96, 1.0, 0.72 if index % 10 == 0 else 0.46))
	for index in 3 if segment == "explore" else 1:
		var center := Vector2(465 + index * 1040, 176 + (index % 2) * 45) if segment == "explore" else Vector2(800, 242)
		var radius := 51.0 + index * 11.0 if segment == "explore" else 125.0
		_draw_distant_planet(center, radius, facts)
	for index in 10 if segment == "explore" else 6:
		var x := 90.0 + index * 315.0
		var peak := 505.0 - float(index % 3) * 27.0
		var hill := PackedVector2Array([Vector2(x - 185, 619), Vector2(x, peak), Vector2(x + 190, 619)])
		draw_colored_polygon(hill, sky.darkened(0.18))
		draw_line(Vector2(x - 172, 614), Vector2(x, peak + 7), Color(horizon, 0.42), 4.0)
	_draw_planet_landforms(facts, width)
	for platform in platforms:
		if is_instance_valid(platform):
			var shape := platform.get_child(0) as CollisionShape2D
			_draw_platform(platform.position, (shape.shape as RectangleShape2D).size.x, bool(platform.get_meta("ground")))
	_draw_hazards()
	_draw_boss_special()
	if pulse_timer > 0.0 and is_instance_valid(player):
		var radius := (0.38 - pulse_timer) / 0.38 * 245.0
		draw_arc(player.position, radius, 0.0, TAU, 64, Color(planet["accent"], pulse_timer * 1.8), 7.0)


func _draw_distant_planet(center: Vector2, radius: float, facts: Dictionary) -> void:
	var base: Color = facts["base"]
	var light: Color = facts["light"]
	var dark: Color = facts["dark"]
	var biome := str(facts["biome"])
	draw_circle(center + Vector2(radius * 0.08, radius * 0.06), radius * 1.05, Color(dark, 0.55))
	draw_circle(center, radius, dark)
	draw_circle(center + Vector2(-radius * 0.12, -radius * 0.1), radius * 0.86, base)
	draw_circle(center + Vector2(-radius * 0.22, -radius * 0.21), radius * 0.66, base.lerp(light, 0.28))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1301 + planet_index * 1813
	if biome == "cloud":
		for band in 5:
			var y := (-0.58 + band * 0.29) * radius
			var half_width := sqrt(maxf(0.0, radius * radius - y * y)) * 0.75
			draw_line(center + Vector2(-half_width, y), center + Vector2(half_width, y - radius * 0.07), Color(light, 0.39), radius * 0.08)
	elif biome == "lava":
		for crack in 8:
			var angle := rng.randf_range(0.0, TAU)
			var start := Vector2.from_angle(angle) * radius * rng.randf_range(0.10, 0.42)
			var finish := start + Vector2.from_angle(angle + rng.randf_range(-0.8, 0.8)) * radius * 0.32
			draw_line(center + start, center + finish, Color(light, 0.72), radius * 0.045)
			draw_circle(center + finish, radius * 0.03, Color(light, 0.7))
	elif biome in ["crystal", "frost", "ice"]:
		for shard in 9:
			var at := Vector2(rng.randf_range(-0.60, 0.60), rng.randf_range(-0.62, 0.62)) * radius
			var size := radius * rng.randf_range(0.08, 0.18)
			draw_colored_polygon(PackedVector2Array([center + at + Vector2(0, -size), center + at + Vector2(size * 0.75, size * 0.3), center + at + Vector2(-size * 0.7, size * 0.5)]), Color(light, 0.50))
	else:
		for patch in 14:
			var at := Vector2(rng.randf_range(-0.68, 0.68), rng.randf_range(-0.68, 0.68)) * radius
			var max_size := radius - at.length() - radius * 0.05
			if max_size > radius * 0.04:
				draw_circle(center + at, minf(max_size, radius * rng.randf_range(0.035, 0.10)), Color(light if patch % 3 == 0 else dark, 0.40))
	if biome == "sanctuary":
		draw_arc(center, radius * 1.15, -0.33, PI + 0.30, 50, Color(light, 0.68), maxf(2.0, radius * 0.03))
	draw_arc(center, radius * 0.98, 2.7, 5.8, 42, Color(light, 0.40), maxf(1.2, radius * 0.025))


func _draw_planet_landforms(facts: Dictionary, width: float) -> void:
	var biome := str(facts["biome"])
	var base: Color = facts["base"]
	var light: Color = facts["light"]
	var danger: Color = facts["danger"]
	for index in ceili(width / 250.0):
		var x := 110.0 + index * 250.0
		if biome in ["ice", "frost", "crystal"]:
			var height := 46.0 + float(index % 3) * 19.0
			draw_colored_polygon(PackedVector2Array([Vector2(x - 30, 619), Vector2(x + 3, 619 - height), Vector2(x + 40, 619)]), Color(light, 0.62))
			draw_line(Vector2(x + 3, 619 - height), Vector2(x + 15, 608), Color(base, 0.80), 3.0)
		elif biome == "lava":
			draw_circle(Vector2(x, 591), 34 + float(index % 2) * 10.0, Color(danger, 0.26))
			draw_line(Vector2(x - 31, 612), Vector2(x + 23, 578), Color(light, 0.65), 5.0)
		elif biome == "cloud":
			draw_circle(Vector2(x - 19, 564), 32, Color(light, 0.30))
			draw_circle(Vector2(x + 16, 559), 38, Color(light, 0.26))
		elif biome == "sanctuary":
			draw_line(Vector2(x, 619), Vector2(x, 539), Color(light, 0.55), 8.0)
			draw_line(Vector2(x - 23, 541), Vector2(x + 23, 541), Color(light, 0.65), 5.0)
		else:
			draw_circle(Vector2(x, 606), 22 + float(index % 3) * 6.0, Color(base, 0.48))
			draw_circle(Vector2(x - 5, 593), 7, Color(light, 0.28))


func _draw_platform(center: Vector2, width: float, ground: bool) -> void:
	var left := center.x - width * 0.5
	var facts: Dictionary = PlanetFacts.at(planet_index)
	var dark: Color = facts["dark"]
	var base: Color = facts["base"]
	var rim: Color = facts["rim"]
	if ground:
		draw_rect(Rect2(left, 619, width, 101), dark)
		for index in ceili(width / 64.0):
			var x := left + index * 64.0
			draw_rect(Rect2(x + 2, 634, 60, 39), base.darkened(0.12))
			draw_rect(Rect2(x + 2, 677, 60, 39), base.darkened(0.25))
			draw_line(Vector2(x + 3, 672), Vector2(x + 63, 672), dark.darkened(0.25), 3.0)
		draw_rect(Rect2(left, 617, width, 10), rim)
	else:
		var top := center.y - 9.0
		draw_rect(Rect2(left, top, width, 31), dark)
		for index in ceili(width / 64.0):
			var x := left + index * 64.0
			draw_rect(Rect2(x + 3, top + 10, minf(58.0, width - index * 64.0 - 6.0), 18), base)
		draw_rect(Rect2(left, top - 3, width, 11), rim)
		draw_rect(Rect2(left, top + 28, width, 4), dark.darkened(0.25))


func _draw_hazards() -> void:
	var facts: Dictionary = PlanetFacts.at(planet_index)
	var danger: Color = facts["danger"]
	for hazard in hazards:
		var x: float = hazard["x"]
		var width: float = hazard["width"]
		var kind: String = hazard["kind"]
		var active := _hazard_active(hazard)
		if kind == "spikes":
			draw_rect(Rect2(x - width * 0.5, 619, width, 12), danger.darkened(0.48))
			for spike in int(width / 23.0):
				var tip_x := x - width * 0.5 + spike * 23.0 + 12.0
				var triangle := PackedVector2Array([Vector2(tip_x - 11, 620), Vector2(tip_x, 562), Vector2(tip_x + 11, 620)])
				draw_colored_polygon(triangle, danger)
				draw_line(Vector2(tip_x, 568), Vector2(tip_x + 5, 612), danger.lightened(0.50), 2.0)
		elif kind == "laser":
			var color := danger if active else danger.darkened(0.50)
			draw_rect(Rect2(x - 20, 602, 40, 30), Color("26354c"))
			draw_circle(Vector2(x, 602), 14, color)
			draw_circle(Vector2(x, 366), 13, color)
			if active:
				draw_line(Vector2(x, 375), Vector2(x, 600), Color(danger, 0.23), 30)
				draw_line(Vector2(x, 375), Vector2(x, 600), danger.lightened(0.62), 6)
			else:
				draw_dashed_line(Vector2(x, 378), Vector2(x, 596), Color(danger, 0.40), 2, 12)
		else:
			var pool_color := danger if active else danger.darkened(0.45)
			draw_rect(Rect2(x - width * 0.5, 608, width, 23), pool_color.darkened(0.35))
			draw_line(Vector2(x - width * 0.5, 607), Vector2(x + width * 0.5, 607), pool_color, 6)
			if active:
				for bubble in 5:
					var bx := x - width * 0.43 + bubble * width * 0.22
					var by := 588.0 - absf(sin(hazard_clock * 4.0 + bubble)) * 24.0
					draw_circle(Vector2(bx, by), 5.0 + float(bubble % 2) * 2.0, Color(facts["light"], 0.75))


func _load_planet() -> void:
	var planet: Dictionary = PLANETS[planet_index]
	var facts: Dictionary = PlanetFacts.at(planet_index)
	segment = "explore"
	portal_pending = false
	camera.limit_right = int(ARENA_WIDTH)
	if is_instance_valid(portal):
		portal.queue_free()
	portal = null
	for platform in platforms:
		if is_instance_valid(platform):
			platform.queue_free()
	platforms.clear()
	_add_platform(Vector2(ARENA_WIDTH * 0.5, 658), int(ARENA_WIDTH), true)
	match planet_index % 3:
		0:
			_add_platform(Vector2(255, 462), 280)
			_add_platform(Vector2(670, 395), 280)
			_add_platform(Vector2(1090, 493), 210)
			_add_platform(Vector2(1480, 348), 310)
			_add_platform(Vector2(1875, 450), 245)
			_add_platform(Vector2(2270, 381), 310)
			_add_platform(Vector2(2680, 492), 230)
		1:
			_add_platform(Vector2(205, 455), 210)
			_add_platform(Vector2(560, 374), 280)
			_add_platform(Vector2(960, 455), 280)
			_add_platform(Vector2(1340, 325), 210)
			_add_platform(Vector2(1750, 410), 280)
			_add_platform(Vector2(2180, 350), 280)
			_add_platform(Vector2(2610, 465), 280)
		2:
			_add_platform(Vector2(300, 470), 280)
			_add_platform(Vector2(640, 330), 280)
			_add_platform(Vector2(1030, 470), 280)
			_add_platform(Vector2(1410, 308), 280)
			_add_platform(Vector2(1770, 455), 280)
			_add_platform(Vector2(2200, 343), 280)
			_add_platform(Vector2(2620, 470), 280)
	for alien in aliens:
		if is_instance_valid(alien):
			alien.queue_free()
	aliens.clear()
	if is_instance_valid(player):
		player.queue_free()
	if is_instance_valid(rival):
		rival.queue_free()
	player = FighterScript.new() as SpaceFighter
	player.configure(self, true, "green", player_max_health)
	player.pilot_variant = selected_pilot
	player.move_speed = player_speed
	player.punch_damage = player_damage
	player.gravity_scale = float(planet["gravity"])
	player.position = Vector2(180, 585)
	player.strike_requested.connect(_on_strike)
	player.knocked_out.connect(_on_knockout)
	world_layer.add_child(player)
	rival = null
	_spawn_aliens()
	var shift := float(planet_index % 3) * 24.0
	hazards = [
		{"kind": "spikes", "x": 835.0 + shift, "width": 138.0, "phase": 0.0},
		{"kind": "laser", "x": 1325.0 - shift, "width": 22.0, "phase": 0.4},
		{"kind": str(facts["hazard"]), "x": 1810.0 + shift, "width": 145.0, "phase": 1.1},
		{"kind": "laser", "x": 2265.0 - shift, "width": 22.0, "phase": 1.7},
		{"kind": "spikes", "x": 2630.0, "width": 115.0, "phase": 0.0}
	]
	if planet_index >= 5:
		hazards.append({"kind": "laser", "x": 1110.0, "width": 22.0, "phase": 2.2})
	portal = PortalGateScript.new() as Node2D
	portal.position = Vector2(PORTAL_X, 580)
	world_layer.add_child(portal)
	hazard_clock = 0.0
	hazard_mask = -1
	camera.position = Vector2(640, 360)
	for item in projectiles:
		if is_instance_valid(item["node"]):
			item["node"].queue_free()
	projectiles.clear()
	if is_instance_valid(pickup):
		pickup.queue_free()
	rule_pending = false
	queue_redraw()
	_refresh_ui()


func _check_portal() -> void:
	if segment != "explore" or portal_pending or not is_instance_valid(portal):
		return
	if absf(player.position.x - PORTAL_X) < 58.0 and player.position.y > 480.0:
		portal_pending = true
		player.desired_direction = 0.0
		call_deferred("_enter_boss_arena")


func _enter_boss_arena() -> void:
	if phase != "fight" or segment != "explore":
		return
	segment = "boss"
	portal_pending = false
	if is_instance_valid(portal):
		portal.queue_free()
	portal = null
	for alien in aliens:
		if is_instance_valid(alien):
			alien.queue_free()
	aliens.clear()
	for platform in platforms:
		if is_instance_valid(platform):
			platform.queue_free()
	platforms.clear()
	for item in projectiles:
		if is_instance_valid(item["node"]):
			item["node"].queue_free()
	projectiles.clear()
	if is_instance_valid(pickup):
		pickup.queue_free()
	pickup = null
	hazards.clear()
	hazard_mask = -1
	_add_platform(Vector2(BOSS_WIDTH * 0.5, 658), int(BOSS_WIDTH), true)
	_add_platform(Vector2(465, 472), 250)
	_add_platform(Vector2(1135, 472), 250)
	_add_platform(Vector2(800, 357), 220)
	player.position = Vector2(210, 585)
	player.velocity = Vector2.ZERO
	player.desired_direction = 0.0
	player.invulnerable = 1.0
	player.health = minf(player.max_health, player.health + player.max_health * 0.25)
	var planet: Dictionary = PLANETS[planet_index]
	rival = GuardianScript.new() as SpaceFighter
	rival.configure(self, false, str(planet["color"]), 100.0 + planet_index * 28.0)
	rival.call("configure_guardian", planet_index)
	boss_base_speed = 220.0 + planet_index * 17.0
	rival.move_speed = boss_base_speed * ai_aggression
	rival.punch_damage = 9.0 + planet_index * 2.0
	rival.gravity_scale = float(planet["gravity"])
	rival.position = Vector2(1320, 585)
	rival.facing = -1
	rival.strike_requested.connect(_on_strike)
	rival.knocked_out.connect(_on_knockout)
	world_layer.add_child(rival)
	camera.limit_right = int(BOSS_WIDTH)
	camera.position = Vector2(640, 360)
	route_timer = 0.0
	boss_timer = 0.8
	fuzzy_timer = 1.2
	chosen_action = ""
	boss_special.clear()
	boss_impact.clear()
	boss_impact_timer = 0.0
	boss_special_timer = maxf(2.4, 5.0 - planet_index * 0.22)
	play_sound("magic")
	_announce(str(planet["boss_line"]), 2.4)
	portal_flash.visible = true
	portal_flash.modulate.a = 1.0
	var fade := create_tween()
	fade.tween_property(portal_flash, "modulate:a", 0.0, 0.46)
	fade.finished.connect(func() -> void: portal_flash.visible = false)
	queue_redraw()
	_refresh_ui()


func _spawn_aliens() -> void:
	var locations := [Vector2(600, 590), Vector2(1640, 590), Vector2(2370, 590), Vector2(1990, 590), Vector2(1070, 590), Vector2(485, 590), Vector2(2135, 590)]
	for index in 3 + mini(floori(planet_index / 2.0), 4):
		var alien := AlienScript.new() as SpaceFighter
		alien.set("species", (index + planet_index) % 3)
		alien.configure(self, false, "pink", 36.0 + minf(planet_index * 5.0, 42.0))
		alien.position = locations[index]
		alien.facing = -1
		alien.strike_requested.connect(_on_strike)
		alien.knocked_out.connect(_on_knockout)
		world_layer.add_child(alien)
		aliens.append(alien)


func _add_platform(center: Vector2, width: int, ground: bool = false) -> void:
	var platform := StaticBody2D.new()
	platform.collision_layer = 1
	platform.position = center
	platform.set_meta("ground", ground)
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(width, 78 if ground else 18)
	shape.shape = rectangle
	platform.add_child(shape)
	world_layer.add_child(platform)
	platforms.append(platform)


func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	var overlay := Control.new()
	hud_root = overlay
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(overlay)
	var top_band := ColorRect.new()
	top_band.color = Color(0.028, 0.066, 0.16, 0.87)
	top_band.position = Vector2.ZERO
	top_band.size = Vector2(1280, 81)
	top_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(top_band)
	var divider := ColorRect.new()
	divider.color = Color("31bfc7")
	divider.position = Vector2(0, 79)
	divider.size = Vector2(1280, 3)
	overlay.add_child(divider)
	left_name = _label(overlay, "NOVA PILOT", Vector2(28, 12), Vector2(360, 28), 18, Color("e9fbff"))
	right_name = _label(overlay, "AI RIVAL", Vector2(890, 12), Vector2(360, 28), 18, Color("ffe6f1"))
	right_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_make_health_bar(overlay, Vector2(28, 45), true)
	_make_health_bar(overlay, Vector2(922, 45), false)
	stage_label = _label(overlay, "01 / 10", Vector2(515, 6), Vector2(250, 38), 25, Color("fff1b5"))
	stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_subtitle = _label(overlay, "EXPLORATION", Vector2(515, 43), Vector2(250, 22), 13, Color("a6dce9"))
	stage_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_label = _label(overlay, "BOSS →", Vector2(945, 89), Vector2(307, 28), 16, Color("fff0c0"))
	target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var lower_band := ColorRect.new()
	lower_band.color = Color(0.025, 0.055, 0.13, 0.90)
	lower_band.position = Vector2(0, 678)
	lower_band.size = Vector2(1280, 42)
	overlay.add_child(lower_band)
	_label(overlay, "ORBIT PULSE", Vector2(30, 685), Vector2(180, 24), 15, Color("e8fbff"))
	var meter_back := ColorRect.new()
	meter_back.color = Color("153348")
	meter_back.position = Vector2(158, 692)
	meter_back.size = Vector2(140, 8)
	overlay.add_child(meter_back)
	meter_fill = ColorRect.new()
	meter_fill.color = Color("44edcf")
	meter_fill.position = meter_back.position
	meter_fill.size = Vector2(70, 8)
	overlay.add_child(meter_fill)
	_label(overlay, "A/D MOVE     SPACE JUMP     J HIT     K BLAST     SHIFT DASH     E PULSE     ESC PAUSE", Vector2(331, 687), Vector2(920, 24), 15, Color("eff8ff"))
	message_label = _label(overlay, "", Vector2(345, 91), Vector2(590, 39), 23, Color("fff0b7"))
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	order_line = LineEdit.new()
	order_line.position = Vector2(430, 620)
	order_line.size = Vector2(420, 42)
	order_line.placeholder_text = "Suit command: attack, defend, heal, or status"
	order_line.visible = false
	order_line.text_submitted.connect(_on_order_submitted)
	overlay.add_child(order_line)
	modal_shade = ColorRect.new()
	modal_shade.color = Color(0.008, 0.02, 0.046, 0.80)
	modal_shade.size = Vector2(1280, 720)
	modal_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(modal_shade)
	var modal_panel := Panel.new()
	modal_panel.position = Vector2(325, 130)
	modal_panel.size = Vector2(630, 475)
	modal_panel.add_theme_stylebox_override("panel", _panel_style(Color("071b32"), Color("42d9e5"), 3))
	modal_shade.add_child(modal_panel)
	var cap := ColorRect.new()
	cap.position = Vector2(0, 0)
	cap.size = Vector2(630, 12)
	cap.color = Color("42d9e5")
	modal_panel.add_child(cap)
	modal_title = _label(modal_panel, "BIOSPHERE X", Vector2(34, 53), Vector2(562, 63), 46, Color("e8ffff"))
	modal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_subtitle = _label(modal_panel, "FIGHT ACROSS THE STARS", Vector2(35, 122), Vector2(560, 35), 21, Color("45e5d4"))
	modal_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_body = _label(modal_panel, "", Vector2(57, 177), Vector2(516, 82), 18, Color("c1d5e9"))
	modal_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_buttons = VBoxContainer.new()
	modal_buttons.position = Vector2(135, 280)
	modal_buttons.custom_minimum_size = Vector2(360, 0)
	modal_buttons.add_theme_constant_override("separation", 11)
	modal_panel.add_child(modal_buttons)
	portal_flash = ColorRect.new()
	portal_flash.color = Color(0.84, 1.0, 1.0, 0.78)
	portal_flash.size = Vector2(1280, 720)
	portal_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portal_flash.visible = false
	overlay.add_child(portal_flash)


func _label(parent: Node, value: String, at: Vector2, dimensions: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.position = at
	label.size = dimensions
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(label)
	return label


func _panel_style(background: Color, border: Color, border_width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 12
	return style


func _make_health_bar(parent: Node, at: Vector2, left: bool) -> void:
	var backing := ColorRect.new()
	backing.position = at
	backing.size = Vector2(330, 20)
	backing.color = Color("152c43")
	parent.add_child(backing)
	var fill := ColorRect.new()
	fill.position = at + Vector2(3, 3)
	fill.size = Vector2(324, 14)
	fill.color = Color("45ebc9") if left else Color("fa78a2")
	parent.add_child(fill)
	if left:
		left_fill = fill
	else:
		right_bar_back = backing
		right_fill = fill


func _refresh_ui() -> void:
	if left_name == null:
		return
	var planet: Dictionary = PLANETS[planet_index]
	var next_left := "%s  •  %s SUIT" % [PilotAvatarScript.PILOTS[selected_pilot]["name"], suit_mode]
	var next_right := "%s  •  AI" % planet["rival"] if segment == "boss" else "REACH THE PORTAL"
	var next_stage := "%02d / %02d" % [planet_index + 1, PLANETS.size()]
	if left_name.text != next_left:
		left_name.text = next_left
	if right_name.text != next_right:
		right_name.text = next_right
	if stage_label.text != next_stage:
		stage_label.text = next_stage
	stage_subtitle.text = "BOSS DUEL" if segment == "boss" else "EXPLORATION"
	var next_target := ""
	if segment == "boss" and is_instance_valid(rival):
		var boss_distance := absi(roundi(rival.position.x - player.position.x))
		next_target = "BOSS %d m %s" % [boss_distance, "→" if rival.position.x >= player.position.x else "←"]
	else:
		var portal_distance := maxi(0, roundi(PORTAL_X - player.position.x))
		next_target = "PORTAL %d m →" % portal_distance
	if target_label.text != next_target:
		target_label.text = next_target
	left_fill.size.x = 324.0 * clampf(player.health / player.max_health, 0.0, 1.0)
	right_bar_back.visible = segment == "boss"
	right_fill.visible = segment == "boss"
	if segment == "boss" and is_instance_valid(rival):
		right_fill.size.x = 324.0 * clampf(rival.health / rival.max_health, 0.0, 1.0)
	meter_fill.size.x = 140.0 * clampf(pulse_charge / 100.0, 0.0, 1.0)
	meter_fill.color = Color("fbe789") if pulse_charge >= 70.0 else Color("44edcf")


func _show_modal(title: String, subtitle: String, body: String, actions: Array[Dictionary]) -> void:
	modal_shade.visible = true
	modal_title.text = title
	modal_subtitle.text = subtitle
	modal_body.text = body
	modal_buttons.position.y = 260 if actions.size() >= 4 else 280
	modal_buttons.add_theme_constant_override("separation", 7 if actions.size() >= 4 else 11)
	for old_button in modal_buttons.get_children():
		modal_buttons.remove_child(old_button)
		old_button.queue_free()
	for action in actions:
		var button := Button.new()
		button.text = str(action["label"])
		button.custom_minimum_size = Vector2(360, 45 if actions.size() >= 4 else 50)
		button.add_theme_font_size_override("font_size", 19)
		button.add_theme_color_override("font_color", Color("efffff"))
		button.add_theme_stylebox_override("normal", _panel_style(Color("104568"), Color("49dce6")))
		button.add_theme_stylebox_override("hover", _panel_style(Color("187b9b"), Color("c5ffff")))
		button.add_theme_stylebox_override("pressed", _panel_style(Color("0a7c80"), Color("e7ffff")))
		modal_buttons.add_child(button)
		button.pressed.connect(action["callback"])


func _build_frontend() -> void:
	home_screen = HomeScreenScript.new() as Control
	ui_layer.add_child(home_screen)
	home_screen.connect("play_requested", Callable(self, "start_run"))
	home_screen.connect("exit_requested", func() -> void: get_tree().quit())
	home_screen.connect("pilot_selected", Callable(self, "_choose_pilot"))
	home_screen.connect("restart_confirmed", Callable(self, "_restart_campaign"))
	map_screen = GalaxyMapScript.new() as Control
	ui_layer.add_child(map_screen)
	map_screen.call("configure", PLANETS)
	map_screen.connect("stage_selected", Callable(self, "_select_planet"))
	map_screen.connect("home_requested", Callable(self, "_show_home"))
	map_screen.visible = false
	campaign_screen = CampaignScreenScript.new() as Control
	ui_layer.add_child(campaign_screen)
	campaign_screen.connect("action_requested", Callable(self, "_on_campaign_action"))
	campaign_screen.visible = false


func _set_screen(next_phase: String) -> void:
	phase = next_phase
	home_screen.visible = next_phase == "home"
	map_screen.visible = next_phase == "map"
	campaign_screen.visible = next_phase in ["briefing", "clear", "upgrade", "defeat"]
	world_layer.visible = next_phase in ["fight", "paused"]
	hud_root.visible = next_phase in ["fight", "paused"]
	if next_phase != "paused":
		modal_shade.visible = false


func _show_home() -> void:
	_set_screen("home")
	home_screen.call("close_controls")
	home_screen.call("set_progress", unlocked_planet, _completed_count(), PLANETS.size())
	home_screen.call("set_pilot", selected_pilot)
	play_sound("select")


func _choose_pilot(index: int) -> void:
	if phase != "home":
		return
	selected_pilot = clampi(index, 0, 2)
	_save_progress()
	play_sound("select")


func _restart_campaign() -> void:
	if phase != "home":
		return
	unlocked_planet = 0
	planet_index = 0
	for index in stage_stars.size():
		stage_stars[index] = 0
	player_max_health = 100.0
	player_damage = 13.0
	player_speed = 265.0
	pulse_charge = 50.0
	wins = 0
	pending_upgrade = false
	_save_progress()
	_show_home()


func start_run() -> void:
	_open_map()


func _open_map() -> void:
	_set_screen("map")
	map_screen.call("refresh_map", unlocked_planet, stage_stars)
	play_sound("select")


func _select_planet(index: int) -> void:
	if phase != "map" or index < 0 or index > unlocked_planet or index >= PLANETS.size():
		return
	planet_index = index
	_show_briefing()


func _show_briefing() -> void:
	campaign_screen.call("present", "briefing", PLANETS[planet_index], {"stage_index": planet_index, "stage_count": PLANETS.size(), "stars": stage_stars[planet_index]})
	_set_screen("briefing")
	play_sound("select")


func _on_campaign_action(action: String) -> void:
	if (action == "start" and phase == "briefing") or (action == "retry" and phase == "defeat") or (action == "replay" and phase == "clear" and not pending_upgrade):
		_start_planet()
	elif action == "map" and phase in ["briefing", "clear", "defeat"] and not pending_upgrade:
		_open_map()
	elif action == "home" and phase in ["clear", "defeat"] and not pending_upgrade:
		_show_home()
	elif action == "upgrade" and phase == "clear" and pending_upgrade:
		_show_upgrade()
	elif phase == "upgrade":
		match action:
			"armor": _upgrade_armor()
			"power": _upgrade_power()
			"flux": _upgrade_flux()


func _show_upgrade() -> void:
	campaign_screen.call("present", "upgrade", PLANETS[planet_index], {"stage_index": planet_index, "stage_count": PLANETS.size()})
	_set_screen("upgrade")
	play_sound("select")


func _start_planet() -> void:
	_set_screen("fight")
	pending_upgrade = false
	alien_kills = 0
	ai_aggression = 1.0 + planet_index * 0.055
	ai_route = "astar"
	route_index = 0
	route_timer = 0.0
	ui_timer = 0.0
	boss_timer = 0.7
	fuzzy_timer = 2.0
	suit_timer = 3.0
	suit_mode = "ATTACK"
	alien_attack_clock = 0.0
	chosen_action = ""
	boss_special.clear()
	boss_impact.clear()
	boss_impact_timer = 0.0
	_load_planet()
	_announce("%s  •  REACH THE BOSS PORTAL" % PLANETS[planet_index]["name"], 2.4)
	_request_pickup_location()
	play_sound("select")


func is_fighting() -> bool:
	return phase == "fight"


func _physics_process(delta: float) -> void:
	if message_timer > 0.0:
		message_timer -= delta
		if message_timer <= 0.0:
			message_label.text = ""
	if pulse_timer > 0.0:
		pulse_timer = maxf(0.0, pulse_timer - delta)
		queue_redraw()
	if phase != "fight":
		return
	hazard_clock += delta
	alien_attack_clock += delta
	var arena_width := get_arena_width()
	camera.position = camera.position.lerp(Vector2(clampf(player.position.x + player.facing * 125.0, 640.0, arena_width - 640.0), 360.0), minf(1.0, delta * 3.0))
	var move_right := Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)
	var move_left := Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)
	player.desired_direction = 0.0 if order_line.visible else float(move_right) - float(move_left)
	suit_timer -= delta
	if segment == "boss":
		route_timer -= delta
		boss_timer -= delta
		fuzzy_timer -= delta
		_update_boss_special(delta)
		if phase != "fight":
			return
		if route_timer <= 0.0:
			route_timer = maxf(0.66, 1.2 - planet_index * 0.055)
			_plan_rival_route()
		if boss_timer <= 0.0:
			boss_timer = maxf(1.30, 2.5 - planet_index * 0.125)
			_request_boss_decision()
		if fuzzy_timer <= 0.0:
			fuzzy_timer = 3.0
			_request_adaptive_difficulty()
		_drive_rival()
	else:
		_update_aliens()
		_check_portal()
	_check_stomps()
	_update_suit()
	_update_hazards()
	_update_projectiles(delta)
	_update_pickup(delta)
	ui_timer -= delta
	if ui_timer <= 0.0:
		ui_timer = 0.10
		_refresh_ui()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		if phase == "fight":
			_show_pause()
		elif phase == "paused":
			_resume_fight()
		elif phase == "map":
			_show_home()
		elif phase in ["briefing", "defeat"]:
			_open_map()
		elif phase == "clear" and not pending_upgrade:
			_open_map()
		elif phase == "home":
			home_screen.call("close_controls")
		get_viewport().set_input_as_handled()
		return
	if phase != "fight" or order_line.visible:
		return
	match event.keycode:
		KEY_SPACE, KEY_W, KEY_UP:
			player.jump()
		KEY_J:
			player.punch()
		KEY_K:
			player.blast()
		KEY_SHIFT:
			player.dash()
		KEY_E:
			_orbit_pulse()
		KEY_Q:
			_cycle_suit_mode()
		KEY_TAB:
			order_line.visible = true
			order_line.grab_focus()
			get_viewport().set_input_as_handled()


func _plan_rival_route() -> void:
	if not is_instance_valid(rival) or not is_instance_valid(player):
		return
	var start := Vector2i(clampi(floori(rival.position.x / 150.0), 0, 19), clampi(floori(rival.position.y / 110.0), 0, 5))
	var goal := Vector2i(clampi(floori(player.position.x / 150.0), 0, 19), clampi(floori(player.position.y / 110.0), 0, 5))
	var blocked: Array[Vector2i] = [Vector2i(5, 2), Vector2i(9, 2), Vector2i(12, 3), Vector2i(16, 3)]
	var preference: String = PATH_ALGORITHMS[route_index % PATH_ALGORITHMS.size()]
	route_index += 1
	var options := {"allow_diagonal": true, "depth_limit": 30, "max_depth": 30}
	var search_goal := goal
	if preference == "iddfs":
		# Iterative deepening is useful for short lookahead, but an arena-wide
		# search stalls a frame on low-end graphics hardware.
		search_goal = Vector2i(start.x + clampi(goal.x - start.x, -4, 4), start.y + clampi(goal.y - start.y, -2, 2))
		options["max_depth"] = 6
	var result: Dictionary = PathfinderScript.search(preference, start, search_goal, blocked, Vector2i(20, 6), options)
	ai_route = preference
	if not bool(result.get("success", false)) and preference != "astar":
		result = PathfinderScript.search("astar", start, goal, blocked, Vector2i(20, 6), options)
		ai_route = "astar"
	if bool(result.get("success", false)):
		var path: Array = result.get("path", [])
		if path.size() > 1:
			var waypoint: Vector2i = path[1]
			var dx := float(waypoint.x - start.x)
			if absf(dx) > 0.0:
				rival.desired_direction = signf(dx)
			if waypoint.y < start.y and rival.is_on_floor():
				rival.jump()


func _drive_rival() -> void:
	if not is_instance_valid(rival) or rival.knocked_out_state:
		return
	if not boss_special.is_empty():
		rival.desired_direction = 0.0
		return
	var dx := player.position.x - rival.position.x
	var dy := player.position.y - rival.position.y
	if absf(dx) > 850.0:
		rival.desired_direction = 0.0
		return
	if absf(dx) > 55.0:
		rival.desired_direction = signf(dx) if absf(dx) > 180.0 else rival.desired_direction
	else:
		rival.desired_direction = 0.0
	if dy < -55.0 and rival.is_on_floor():
		rival.jump()
	if absf(dx) < 113.0 and absf(dy) < 78.0:
		rival.punch()
	elif absf(dx) < 600.0 and absf(dy) < 135.0 and ("BARRAGE" in chosen_action or "ACID" in chosen_action or randf() < (0.010 + planet_index * 0.0022) * ai_aggression):
		rival.facing = 1 if dx > 0.0 else -1
		rival.blast()
		chosen_action = ""
	if "CHARGE" in chosen_action and absf(dx) < 360.0:
		rival.dash()
		chosen_action = ""


func _update_boss_special(delta: float) -> void:
	if not is_instance_valid(rival) or rival.knocked_out_state:
		if not boss_special.is_empty() or not boss_impact.is_empty():
			boss_special.clear()
			boss_impact.clear()
			queue_redraw()
		return
	if boss_impact_timer > 0.0:
		boss_impact_timer = maxf(0.0, boss_impact_timer - delta)
		if boss_impact_timer <= 0.0:
			boss_impact.clear()
		queue_redraw()
	if not boss_special.is_empty():
		boss_special["remaining"] = float(boss_special["remaining"]) - delta
		if float(boss_special["remaining"]) <= 0.0:
			_resolve_boss_special()
		else:
			queue_redraw()
		return
	boss_special_timer -= delta
	if boss_special_timer <= 0.0 and absf(player.position.x - rival.position.x) < 760.0:
		_begin_boss_special()


func _begin_boss_special() -> void:
	var special: Dictionary = BOSS_SPECIALS[planet_index]
	var windup := maxf(0.44, 0.78 - planet_index * 0.035)
	boss_special = {
		"kind": special["kind"], "name": special["name"],
		"remaining": windup, "duration": windup,
		"x": clampf(player.position.x, 70.0, BOSS_WIDTH - 70.0),
		"origin": rival.position.x
	}
	rival.desired_direction = 0.0
	_announce("DODGE: %s" % special["name"], windup + 0.18)
	queue_redraw()


func _resolve_boss_special() -> void:
	var attack := boss_special.duplicate()
	boss_special.clear()
	boss_impact = attack
	boss_impact_timer = 0.24
	boss_special_timer = maxf(3.05, 6.35 - planet_index * 0.36)
	var kind := str(attack["kind"])
	var distance := absf(player.position.x - rival.position.x)
	var toward := 1 if player.position.x >= rival.position.x else -1
	var damage := 13.0 + planet_index * 1.3
	match kind:
		"quake":
			if distance < 235.0 and player.position.y > 515.0:
				_deal_damage(player, damage, toward)
		"volley":
			for lane in [-32.0, -8.0, 18.0]:
				_spawn_projectile(rival.position + Vector2(toward * 43.0, lane), toward, false, damage * 0.72)
		"blink", "rift":
			var side := 1 if kind == "blink" else -1
			rival.position.x = clampf(player.position.x + side * 66.0, 70.0, BOSS_WIDTH - 70.0)
			rival.facing = -side
			rival.attack_cooldown = 0.0
			rival.punch()
			if kind == "rift":
				_spawn_projectile(rival.position + Vector2(rival.facing * 43.0, -13.0), rival.facing, false, damage * 0.65)
		"shards":
			for lane in [-46.0, -18.0, 10.0, 38.0]:
				_spawn_projectile(rival.position + Vector2(toward * 43.0, lane), toward, false, damage * 0.68)
		"freeze":
			if distance < 275.0 and player.position.y > 440.0:
				_deal_damage(player, damage * 0.78, toward)
				player.slow_timer = maxf(player.slow_timer, 2.0)
		"forge":
			rival.velocity.y = -450.0
			if distance < 285.0 and player.position.y > 515.0:
				_deal_damage(player, damage * 1.15, toward)
		"nova":
			if player.position.distance_to(rival.position) < 230.0:
				_deal_damage(player, damage, toward)
			rival.health = minf(rival.max_health, rival.health + 8.0)
		"beam":
			if absf(player.position.x - float(attack["x"])) < 68.0 and player.position.y > 340.0:
				_deal_damage(player, damage, toward)
		"oracle":
			if absf(player.position.x - float(attack["x"])) < 76.0 and player.position.y > 340.0:
				_deal_damage(player, damage * 1.08, toward)
			for lane in [-26.0, 15.0]:
				_spawn_projectile(rival.position + Vector2(toward * 45.0, lane), toward, false, damage * 0.65)
	play_sound("magic")
	queue_redraw()


func _draw_boss_special() -> void:
	var active := boss_special if not boss_special.is_empty() else boss_impact
	if active.is_empty():
		return
	var danger: Color = PlanetFacts.at(planet_index)["danger"]
	var telegraph := not boss_special.is_empty()
	var alpha := 0.42 if telegraph else 0.84 * boss_impact_timer / 0.24
	var x := float(active["x"])
	var origin := float(active["origin"])
	match str(active["kind"]):
		"beam", "oracle":
			draw_line(Vector2(x, 315), Vector2(x, 617), Color(danger, alpha * 0.26), 110 if telegraph else 145)
			draw_line(Vector2(x, 315), Vector2(x, 617), Color(danger, alpha), 6 if telegraph else 22)
			if telegraph:
				draw_circle(Vector2(x, 320), 15, Color(danger, alpha))
		"blink", "rift":
			draw_arc(Vector2(x, 574), 66.0, 0, TAU, 48, Color(danger, alpha), 5 if telegraph else 13)
			draw_line(Vector2(x, 481), Vector2(x, 618), Color(danger, alpha * 0.56), 4)
		"quake", "freeze", "forge":
			var reach := 235.0 if str(active["kind"]) == "quake" else 280.0
			draw_rect(Rect2(origin - reach, 598, reach * 2.0, 19), Color(danger, alpha * 0.32))
			draw_line(Vector2(origin - reach, 613), Vector2(origin + reach, 613), Color(danger, alpha), 5 if telegraph else 14)
		"nova":
			draw_circle(Vector2(origin, 560), 222, Color(danger, alpha * 0.11))
			draw_arc(Vector2(origin, 560), 222, 0, TAU, 64, Color(danger, alpha), 5 if telegraph else 12)
		_:
			for lane in [-1, 0, 1]:
				draw_line(Vector2(origin, 547), Vector2(origin + (280 if x >= origin else -280), 547 + lane * 35), Color(danger, alpha * 0.80), 3 if telegraph else 9)


func _update_aliens() -> void:
	for alien in aliens.duplicate():
		if not is_instance_valid(alien) or alien.knocked_out_state:
			continue
		var dx: float = player.position.x - alien.position.x
		var dy: float = player.position.y - alien.position.y
		if absf(dx) > 700.0:
			alien.desired_direction = 0.0
			continue
		alien.desired_direction = signf(dx) if absf(dx) > 75.0 else 0.0
		if dy < -85.0 and alien.is_on_floor():
			alien.jump()
		if absf(dx) < 74.0 and absf(dy) < 67.0 and alien_attack_clock > 0.9:
			alien.punch()
			alien.attack_cooldown = 1.35
			alien_attack_clock = 0.0
		elif absf(dx) < 400.0 and absf(dy) < 125.0 and alien.blast_cooldown <= 0.0 and randf() < 0.003:
			alien.facing = 1 if dx > 0.0 else -1
			alien.blast()


func _hazard_active(hazard: Dictionary) -> bool:
	match str(hazard["kind"]):
		"laser": return fmod(hazard_clock + float(hazard["phase"]), 3.3) < 1.55
		"acid", "ice", "lava", "plasma": return fmod(hazard_clock + float(hazard["phase"]), 4.1) < 2.35
		_: return true


func _update_hazards() -> void:
	var fighters: Array[SpaceFighter] = []
	for alien in aliens:
		if is_instance_valid(alien) and not alien.knocked_out_state:
			fighters.append(alien)
	fighters.append(player)
	var active_mask := 0
	for index in hazards.size():
		var hazard: Dictionary = hazards[index]
		if not _hazard_active(hazard):
			continue
		active_mask |= 1 << index
		var x: float = hazard["x"]
		var width: float = hazard["width"]
		for fighter in fighters:
			if not is_instance_valid(fighter) or fighter.knocked_out_state:
				continue
			var touching := absf(fighter.position.x - x) < width * 0.5 + 14.0
			if str(hazard["kind"]) == "laser":
				touching = touching and fighter.position.y > 345.0 and fighter.position.y < 640.0
			else:
				touching = touching and fighter.position.y > 530.0
			if touching:
				var damage := 14.0 if str(hazard["kind"]) == "lava" else (10.0 if fighter == player else 7.0)
				_deal_damage(fighter, damage, 1 if fighter.position.x >= x else -1)
				if fighter == player and str(hazard["kind"]) == "ice":
					fighter.slow_timer = maxf(fighter.slow_timer, 1.5)
	if active_mask != hazard_mask:
		hazard_mask = active_mask
		queue_redraw()


func _living_enemies() -> Array[SpaceFighter]:
	var enemies: Array[SpaceFighter] = []
	if is_instance_valid(rival) and not rival.knocked_out_state:
		enemies.append(rival)
	for alien in aliens:
		if is_instance_valid(alien) and not alien.knocked_out_state:
			enemies.append(alien)
	return enemies


func _check_stomps() -> void:
	for enemy in _living_enemies():
		if absf(player.position.x - enemy.position.x) > enemy.hit_radius:
			continue
		var stomp_height := 96.0 if enemy == rival else 72.0
		if player.velocity.y > 110.0 and player.position.y < enemy.position.y - 25.0 and enemy.position.y - player.position.y < stomp_height:
			var before := enemy.health
			_deal_damage(enemy, player_damage * 1.35, 1 if enemy.position.x > player.position.x else -1)
			if enemy.health < before:
				player.velocity.y = -470.0
				_burst(enemy.position + Vector2(0, -45), true)
		elif enemy == rival and enemy.velocity.y > 160.0 and enemy.position.y < player.position.y - 25.0 and player.position.y - enemy.position.y < 72.0:
			var before := player.health
			_deal_damage(player, enemy.punch_damage * 1.15, 1 if player.position.x > enemy.position.x else -1)
			if player.health < before:
				enemy.velocity.y = -430.0
				_burst(player.position + Vector2(0, -45), false)


func _request_boss_decision() -> void:
	if segment != "boss" or not is_instance_valid(rival):
		return
	var distance := absf(player.position.x - rival.position.x)
	AIClient.request_boss_decision({
		"turn": "boss", "boss_hp": rival.health, "boss_max_hp": rival.max_health,
		"boss_phase": 2 if rival.health < rival.max_health * 0.5 else 1,
		"player_hp": player.health, "player_max_hp": player.max_health,
		"player_energy": pulse_charge, "distance": distance * 0.5
	}, str(PLANETS[planet_index]["boss"]), {"max_depth": 3, "simulations": 70}, func(result: Dictionary) -> void:
		if phase == "fight" and segment == "boss" and bool(result.get("success", false)):
			chosen_action = str(result.get("data", {}).get("action", ""))
	)


func _request_adaptive_difficulty() -> void:
	if segment != "boss" or not is_instance_valid(rival):
		return
	AIClient.request_adaptive_difficulty({
		"player_health": player.health / player.max_health * 100.0,
		"recent_damage": (player.max_health - player.health) * 0.5,
		"enemy_distance": absf(player.position.x - rival.position.x) * 0.4,
		"repeated_failures": 0
	}, "", func(result: Dictionary) -> void:
		if phase == "fight" and segment == "boss" and is_instance_valid(rival) and bool(result.get("success", false)):
			var data: Dictionary = result.get("data", {})
			var stage_floor := 0.90 + planet_index * 0.05
			ai_aggression = clampf(float(data.get("enemy_aggression", 0.6)) + 0.4 + planet_index * 0.045, stage_floor, 1.30 + planet_index * 0.055)
			rival.move_speed = boss_base_speed * ai_aggression
	)


func _on_strike(fighter: SpaceFighter, kind: String) -> void:
	if kind == "punch":
		play_sound("throw")
		_burst(fighter.position + Vector2(fighter.facing * 38, -8), fighter == player)
		var targets: Array[SpaceFighter] = []
		if fighter == player:
			targets = _living_enemies()
		else:
			targets.append(player)
		for target in targets:
			var dx: float = target.position.x - fighter.position.x
			if absf(dx) < 82.0 + maxf(0.0, target.hit_radius - 34.0) and absf(target.position.y - fighter.position.y) < 64.0 + maxf(0.0, target.hit_radius - 34.0) and dx * fighter.facing > -10.0:
				var toward := 1 if dx > 0.0 else -1
				var damage := fighter.punch_damage * (1.20 if fighter == player and suit_mode == "ATTACK" else 1.0)
				_deal_damage(target, damage, toward)
	else:
		var damage := fighter.punch_damage * 0.78 * (1.20 if fighter == player and suit_mode == "ATTACK" else 1.0)
		_spawn_projectile(fighter.position + Vector2(fighter.facing * 32, -8), fighter.facing, fighter == player, damage)
		play_sound("magic")


func _spawn_projectile(at: Vector2, direction: int, friendly: bool, damage: float) -> void:
	var projectile := Sprite2D.new()
	projectile.texture = load(ASSET + "effects/star.png") as Texture2D
	projectile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	projectile.scale = Vector2.ONE * 0.75
	projectile.modulate = Color("70fff1") if friendly else Color(PlanetFacts.at(planet_index)["danger"])
	projectile.position = at
	projectile.z_index = 4
	world_layer.add_child(projectile)
	var projectile_speed := 640.0 if friendly else (525.0 + planet_index * 18.0 if segment == "boss" else 525.0)
	projectiles.append({"node": projectile, "speed": direction * projectile_speed, "friendly": friendly, "damage": damage, "life": 2.2})


func _update_projectiles(delta: float) -> void:
	for index in range(projectiles.size() - 1, -1, -1):
		var item: Dictionary = projectiles[index]
		var projectile: Sprite2D = item["node"]
		item["life"] = float(item["life"]) - delta
		projectile.position.x += float(item["speed"]) * delta
		var impact := false
		var targets: Array[SpaceFighter] = []
		if bool(item["friendly"]):
			targets = _living_enemies()
		else:
			targets.append(player)
		for target in targets:
			if projectile.position.distance_to(target.position) < target.hit_radius:
				_deal_damage(target, float(item["damage"]), 1 if float(item["speed"]) > 0.0 else -1)
				_burst(projectile.position, bool(item["friendly"]))
				impact = true
				break
		if impact or float(item["life"]) <= 0.0 or projectile.position.x < -30.0 or projectile.position.x > get_arena_width() + 30.0:
			projectile.queue_free()
			projectiles.remove_at(index)
		else:
			projectiles[index] = item


func _burst(at: Vector2, friendly: bool) -> void:
	var burst := Sprite2D.new()
	burst.texture = load(ASSET + "effects/laser_burst.png") as Texture2D
	burst.modulate = Color("5ffff0") if friendly else Color("ff83ae")
	burst.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	burst.position = at
	burst.scale = Vector2.ONE * 0.4
	burst.z_index = 5
	world_layer.add_child(burst)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(burst, "scale", Vector2.ONE * 1.1, 0.22)
	tween.tween_property(burst, "modulate:a", 0.0, 0.22)
	tween.finished.connect(burst.queue_free)


func _deal_damage(target: SpaceFighter, amount: float, direction: int) -> void:
	if target == player and suit_mode == "GUARD":
		amount *= 0.65
	var before := target.health
	target.take_damage(amount, direction)
	if target != player and target.health < before:
		pulse_charge = minf(100.0, pulse_charge + 15.0)
	_refresh_ui()


func _orbit_pulse() -> void:
	if pulse_charge < 70.0:
		_announce("ORBIT PULSE NEEDS 70 ENERGY", 1.3)
		return
	pulse_charge = 0.0
	pulse_timer = 0.38
	player.gravity_scale = float(PLANETS[planet_index]["gravity"]) * 0.62
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		if is_instance_valid(player):
			player.gravity_scale = float(PLANETS[planet_index]["gravity"])
	)
	for enemy in _living_enemies():
		if player.position.distance_to(enemy.position) < 260.0:
			_deal_damage(enemy, 22.0 + player_damage * 0.4, 1 if enemy.position.x > player.position.x else -1)
			enemy.slow_timer = 1.8
	pulse_charge = 0.0
	play_sound("magic")
	_announce("ORBIT PULSE!  •  LOW GRAVITY", 1.6)
	queue_redraw()


func _update_suit() -> void:
	if suit_mode != "HEAL" or suit_timer > 0.0:
		return
	suit_timer = 3.0
	if pulse_charge >= 15.0 and player.health < player.max_health:
		pulse_charge -= 15.0
		player.health = minf(player.max_health, player.health + 7.0)
		_burst(player.position + Vector2(0, -18), true)
		_announce("SUIT REPAIR  •  HEALTH +7", 1.2)


func _cycle_suit_mode() -> void:
	var modes := ["ATTACK", "GUARD", "HEAL"]
	suit_mode = modes[(modes.find(suit_mode) + 1) % modes.size()]
	suit_timer = 3.0
	_announce("SUIT MODE: %s" % suit_mode, 1.4)
	_refresh_ui()


func _set_suit_mode(mode: String) -> void:
	suit_mode = mode
	suit_timer = 3.0
	_announce("SUIT MODE: %s" % mode, 1.4)
	_refresh_ui()


func _on_order_submitted(value: String) -> void:
	order_line.visible = false
	order_line.release_focus()
	order_line.clear()
	if value.strip_edges().is_empty():
		return
	AIClient.request_command_parse(value, {}, func(result: Dictionary) -> void:
		if phase != "fight":
			return
		var intent := ""
		if bool(result.get("success", false)):
			intent = str(result.get("data", {}).get("parsed", {}).get("intent", ""))
		else:
			var lower := value.to_lower()
			if "attack" in lower:
				intent = "suit_attack"
			elif "guard" in lower or "defend" in lower:
				intent = "suit_guard"
			elif "heal" in lower:
				intent = "suit_heal"
		match intent:
			"suit_attack": _set_suit_mode("ATTACK")
			"suit_guard": _set_suit_mode("GUARD")
			"suit_heal": _set_suit_mode("HEAL")
			"check_vitals": _announce("HEALTH %d / %d" % [ceili(player.health), ceili(player.max_health)], 2.0)
			_: _announce("SUIT: ATTACK, DEFEND, HEAL, OR STATUS", 2.0)
	)


func _request_pickup_location() -> void:
	AIClient.request_placement_suggestions({
		"structure_id": "defense_turret",
		"search_zone": [3, 3, 18, 5],
		"max_suggestions": 6,
		"available_resources": {"titanium": 10, "crystals": 10},
		"grid_size": [20, 6],
		"build_zone": [2, 2, 18, 5],
		"blocked_cells": [[5, 5], [9, 5], [12, 5], [15, 5]],
		"occupied_cells": []
	}, func(result: Dictionary) -> void:
		if phase != "fight" or segment != "explore":
			return
		var x := 1650.0
		var suggestions: Array = result.get("data", {}).get("suggestions", [])
		if bool(result.get("success", false)) and not suggestions.is_empty():
			x = clampf(70.0 + float(suggestions[0][0]) * 150.0, 200.0, ARENA_WIDTH - 200.0)
		_spawn_pickup(Vector2(x, 535))
	)


func _spawn_pickup(at: Vector2) -> void:
	if is_instance_valid(pickup):
		pickup.queue_free()
	pickup = Sprite2D.new()
	pickup.texture = load(ASSET + "effects/gem_blue.png") as Texture2D
	pickup.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pickup.position = at
	pickup.scale = Vector2.ONE * 0.72
	pickup.z_index = 2
	world_layer.add_child(pickup)


func _update_pickup(_delta: float) -> void:
	if not is_instance_valid(pickup):
		return
	pickup.position.y = 535.0 + sin(Time.get_ticks_msec() * 0.004) * 9.0
	if pickup.position.distance_to(player.position) < 53.0:
		pickup.queue_free()
		pickup = null
		player.health = minf(player.max_health, player.health + 18.0)
		pulse_charge = minf(100.0, pulse_charge + 18.0)
		play_sound("gem")
		_announce("STAR CORE  •  HEALTH + ENERGY", 1.5)


func _on_knockout(fighter: SpaceFighter) -> void:
	if phase != "fight":
		return
	if fighter == player:
		campaign_screen.call("present", "defeat", PLANETS[planet_index], {"stage_index": planet_index, "stage_count": PLANETS.size()})
		_set_screen("defeat")
		return
	if fighter != rival:
		aliens.erase(fighter)
		alien_kills += 1
		_burst(fighter.position + Vector2(0, -16), true)
		pulse_charge = minf(100.0, pulse_charge + 18.0)
		_announce("ALIEN DOWN  •  ENERGY +18", 1.2)
		var vanish := create_tween()
		vanish.set_parallel(true)
		vanish.tween_property(fighter, "scale", Vector2(0.25, 0.25), 0.22)
		vanish.tween_property(fighter, "modulate:a", 0.0, 0.22)
		vanish.finished.connect(fighter.queue_free)
		return
	if segment != "boss":
		return
	if rule_pending:
		return
	rule_pending = true
	wins += 1
	AIClient.request_rule_inference({
		"duel_active": true,
		"duel_rival_down": true,
		"duel_player_alive": player.health > 0.0
	}, ["duel"], 10, func(result: Dictionary) -> void:
		if phase != "fight":
			return
		var facts: Dictionary = result.get("data", {}).get("derived_facts", {})
		if bool(result.get("success", false)) and bool(facts.get("duel_won", false)):
			_announce("VICTORY  •  AI REFEREE CONFIRMED", 2.0)
		_finish_planet()
	)


func _finish_planet() -> void:
	if phase != "fight" or segment != "boss":
		return
	boss_special.clear()
	boss_impact.clear()
	queue_redraw()
	var first_clear := stage_stars[planet_index] == 0
	var health_ratio := player.health / player.max_health
	var stars := 1 + int(health_ratio >= 0.45) + int(health_ratio >= 0.80)
	stage_stars[planet_index] = maxi(stage_stars[planet_index], stars)
	unlocked_planet = maxi(unlocked_planet, mini(planet_index + 1, PLANETS.size() - 1))
	pending_upgrade = first_clear and planet_index < PLANETS.size() - 1
	if not pending_upgrade:
		_save_progress()
	campaign_screen.call("present", "clear", PLANETS[planet_index], {"stage_index": planet_index, "stage_count": PLANETS.size(), "stars": stars, "health": roundi(health_ratio * 100.0), "kills": alien_kills, "first_clear": first_clear, "final": planet_index == PLANETS.size() - 1})
	_set_screen("clear")


func _upgrade_armor() -> void:
	player_max_health += 25.0
	_complete_upgrade()


func _upgrade_power() -> void:
	player_damage += 5.0
	_complete_upgrade()


func _upgrade_flux() -> void:
	player_speed += 35.0
	pulse_charge = 85.0
	_complete_upgrade()


func _complete_upgrade() -> void:
	pending_upgrade = false
	_save_progress()
	_open_map()


func _show_pause() -> void:
	_set_screen("paused")
	player.desired_direction = 0.0
	if order_line.visible:
		order_line.visible = false
	_show_modal("PAUSED", "BIOSPHERE X", "Take a breath. Your planet and campaign progress are waiting.", [
		{"label": "RESUME FIGHT", "callback": Callable(self, "_resume_fight")},
		{"label": "RESTART PLANET", "callback": Callable(self, "_start_planet")},
		{"label": "GALAXY MAP", "callback": Callable(self, "_open_map")},
		{"label": "HOME", "callback": Callable(self, "_show_home")}
	])


func _resume_fight() -> void:
	_set_screen("fight")


func _completed_count() -> int:
	var completed := 0
	for stars in stage_stars:
		completed += int(stars > 0)
	return completed


func _load_progress() -> void:
	var config := ConfigFile.new()
	var migrated := false
	if config.load(progress_path) != OK:
		if progress_path != "user://orbit_breakers_progress.cfg":
			return
		var previous_save := OS.get_user_data_dir().get_base_dir().path_join("Orbit Breakers").path_join("orbit_breakers_progress.cfg")
		if config.load(previous_save) != OK:
			return
		migrated = true
	unlocked_planet = clampi(int(config.get_value("campaign", "unlocked_planet", 0)), 0, PLANETS.size() - 1)
	var saved_stars: Array = config.get_value("campaign", "stage_stars", [0, 0, 0])
	for index in mini(stage_stars.size(), saved_stars.size()):
		stage_stars[index] = clampi(int(saved_stars[index]), 0, 3)
	selected_pilot = clampi(int(config.get_value("pilot", "character", 0)), 0, 2)
	player_max_health = clampf(float(config.get_value("pilot", "max_health", 100.0)), 100.0, 600.0)
	player_damage = clampf(float(config.get_value("pilot", "damage", 13.0)), 13.0, 100.0)
	player_speed = clampf(float(config.get_value("pilot", "speed", 265.0)), 265.0, 650.0)
	if migrated:
		_save_progress()


func _save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("campaign", "unlocked_planet", unlocked_planet)
	config.set_value("campaign", "stage_stars", stage_stars)
	config.set_value("pilot", "max_health", player_max_health)
	config.set_value("pilot", "damage", player_damage)
	config.set_value("pilot", "speed", player_speed)
	config.set_value("pilot", "character", selected_pilot)
	var result := config.save(progress_path)
	if result != OK:
		push_warning("Could not save BioSphere X progress: %s" % error_string(result))


func _announce(value: String, duration: float) -> void:
	message_label.text = value
	message_timer = duration


func get_arena_width() -> float:
	return BOSS_WIDTH if segment == "boss" else ARENA_WIDTH
