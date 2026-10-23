extends Node3D

const EnemyScript = preload("res://scenes/orbit_arena/orbit_enemy.gd")
const PathfinderScript = preload("res://scripts/utils/modular_pathfinder.gd")
const PILOT_MODEL = preload("res://assets/kenney/space/astronautA.glb")
const DRONE_MODEL = preload("res://assets/kenney/space/machine_wireless.glb")
const FLOOR_MODEL = preload("res://assets/kenney/modular/template-floor.glb")
const WALL_MODEL = preload("res://assets/kenney/modular/template-wall.glb")
const CORNER_MODEL = preload("res://assets/kenney/modular/template-wall-corner.glb")
const GATE_MODEL = preload("res://assets/kenney/modular/gate.glb")
const ROCK_MODEL = preload("res://assets/kenney/space/rock_largeA.glb")
const CRYSTAL_MODEL = preload("res://assets/kenney/space/rock_crystalsLargeA.glb")
const METEOR_MODEL = preload("res://assets/kenney/space/meteor_detailed.glb")
const GENERATOR_MODEL = preload("res://assets/kenney/space/machine_generatorLarge.glb")
const DISH_MODEL = preload("res://assets/kenney/space/satelliteDish_large.glb")
const CRAFT_MODEL = preload("res://assets/kenney/space/craft_miner.glb")
const TURRET_MODEL = preload("res://assets/kenney/space/turret_double.glb")
const BLASTER_MODEL = preload("res://assets/kenney/blaster/blaster-a.glb")
const GRID_SIZE := Vector2i(14, 14)
const PATH_ALGORITHMS := ["astar", "bfs", "dfs", "dls", "iddfs", "bidirectional", "greedy"]
const PLANETS := [
	{"name": "TRAPPIST-1 e", "subtitle": "The Emerald Ruins", "ground": Color(0.12, 0.25, 0.23), "accent": Color(0.22, 0.95, 0.74), "sky": Color(0.025, 0.08, 0.10)},
	{"name": "LHS 1140 b", "subtitle": "The Rust Basin", "ground": Color(0.34, 0.18, 0.13), "accent": Color(1.0, 0.53, 0.26), "sky": Color(0.12, 0.055, 0.055)},
	{"name": "Kepler-452 b", "subtitle": "The Violet Storm", "ground": Color(0.20, 0.16, 0.32), "accent": Color(0.70, 0.48, 1.0), "sky": Color(0.065, 0.045, 0.13)}
]
const UPGRADE_NAMES := ["POWER SHOT", "EXTRA ARMOR", "RAPID FIRE", "DRONE BOOST", "DASH DRIVE", "SUPPORT CHARGE"]
const UPGRADE_DESCRIPTIONS := [
	"+6 blaster damage",
	"+25 maximum health and heal 25",
	"20% faster firing",
	"+5 drone damage",
	"Shorter dodge cooldown",
	"+2 support turret charges"
]

var phase: String = "menu"
var planet_index: int = 0
var wave_index: int = 0
var algorithm_cursor: int = 0
var kills: int = 0
var failures: int = 0
var player_health: float = 100.0
var player_max_health: float = 100.0
var player_damage: float = 16.0
var fire_delay: float = 0.32
var fire_cooldown: float = 0.0
var dodge_cooldown: float = 0.0
var dodge_recharge: float = 2.8
var hurt_cooldown: float = 0.0
var recent_damage: float = 0.0
var drone_damage: float = 6.0
var drone_cooldown: float = 0.0
var drone_heal_cooldown: float = 0.0
var drone_mode: String = "ATTACK"
var support_charges: int = 1
var enemy_speed_multiplier: float = 1.0
var fuzzy_timer: float = 1.0
var hazard_timer: float = 7.0
var rule_pending: bool = false
var message_timer: float = 0.0
var current_message: String = ""

var player: CharacterBody3D
var player_visual: Node3D
var companion: Node3D
var companion_visual: MeshInstance3D
var camera: Camera3D
var world_environment: WorldEnvironment
var world_root: Node3D
var enemy_root: Node3D
var projectile_root: Node3D
var turret_root: Node3D
var enemies: Array[OrbitEnemy] = []
var projectiles: Array[Dictionary] = []
var turrets: Array[Dictionary] = []
var blocked_cells: Array[Vector2i] = []
var hud_label: Label
var hint_label: Label
var message_label: Label
var modal: PanelContainer
var modal_title: Label
var modal_body: Label
var modal_buttons: VBoxContainer
var command_line: LineEdit


func _ready() -> void:
	_build_scene()
	_build_interface()
	_build_planet()
	_show_menu()
	if DisplayServer.get_name() != "headless":
		call_deferred("_center_window")


func _center_window() -> void:
	var usable := DisplayServer.screen_get_usable_rect(DisplayServer.get_primary_screen())
	var window_size := DisplayServer.window_get_size()
	var offset := Vector2i(
		maxi(0, floori((usable.size.x - window_size.x) / 2.0)),
		maxi(0, floori((usable.size.y - window_size.y) / 2.0))
	)
	DisplayServer.window_set_position(usable.position + offset)


func _build_scene() -> void:
	world_root = Node3D.new()
	world_root.name = "Planet"
	add_child(world_root)
	enemy_root = Node3D.new()
	enemy_root.name = "Enemies"
	add_child(enemy_root)
	projectile_root = Node3D.new()
	projectile_root.name = "Projectiles"
	add_child(projectile_root)
	turret_root = Node3D.new()
	turret_root.name = "SupportTurrets"
	add_child(turret_root)

	world_environment = WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.025, 0.08, 0.10)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.68, 0.8)
	environment.ambient_light_energy = 0.42
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.28
	world_environment.environment = environment
	add_child(world_environment)

	var sunlight := DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-55, -25, 0)
	sunlight.light_energy = 0.9
	sunlight.shadow_enabled = true
	add_child(sunlight)
	var fill_light := DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(-35, 145, 0)
	fill_light.light_color = Color(0.42, 0.65, 1.0)
	fill_light.light_energy = 0.24
	add_child(fill_light)

	player = CharacterBody3D.new()
	player.name = "Pilot"
	player.collision_layer = 4
	player.collision_mask = 1
	var player_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.7
	player_shape.shape = capsule
	player_shape.position.y = 0.85
	player.add_child(player_shape)
	player_visual = Node3D.new()
	player_visual.name = "Astronaut"
	var pilot := PILOT_MODEL.instantiate() as Node3D
	pilot.position.y = 0.47
	pilot.scale = Vector3.ONE * 1.1
	player_visual.add_child(pilot)
	player.add_child(player_visual)
	var blaster := BLASTER_MODEL.instantiate() as Node3D
	blaster.position = Vector3(0.5, 0.85, 0.48)
	blaster.rotation_degrees = Vector3(0, 90, -12)
	blaster.scale = Vector3.ONE * 0.8
	player_visual.add_child(blaster)
	_add_disc(player_visual, Vector3(0, 0.045, 0), 0.72, Color(0.16, 0.8, 1.0), 0.055)
	add_child(player)

	companion = Node3D.new()
	companion.name = "AI Wingmate"
	companion_visual = MeshInstance3D.new()
	var drone_mesh := SphereMesh.new()
	drone_mesh.radius = 0.29
	drone_mesh.height = 0.58
	companion_visual.mesh = drone_mesh
	companion_visual.material_override = _material(Color(0.10, 0.7, 1.0), true)
	companion.add_child(companion_visual)
	var drone_shell := DRONE_MODEL.instantiate() as Node3D
	drone_shell.scale = Vector3.ONE * 1.05
	drone_shell.position.y = -0.24
	companion.add_child(drone_shell)
	var eye := MeshInstance3D.new()
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.12
	eye.mesh = eye_mesh
	eye.position = Vector3(0, 0, 0.35)
	eye.material_override = _material(Color.WHITE, true)
	companion.add_child(eye)
	add_child(companion)

	camera = Camera3D.new()
	camera.name = "ArenaCamera"
	camera.current = true
	camera.fov = 48.0
	camera.position = Vector3(0, 19, 19)
	add_child(camera)
	camera.look_at(Vector3.ZERO)


func _material(color: Color, glow: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.18
	material.roughness = 0.56
	if glow:
		material.emission_enabled = true
		material.emission = color * 0.5
	return material


func _static_box(parent: Node3D, box_position: Vector3, size: Vector3, color: Color, visible_mesh: bool = true) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = box_position
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	if visible_mesh:
		var visual := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = size
		visual.mesh = mesh
		visual.material_override = _material(color)
		body.add_child(visual)
	parent.add_child(body)


func _add_model(parent: Node3D, scene: PackedScene, at: Vector3, size: float = 1.0, yaw: float = 0.0) -> Node3D:
	var model := scene.instantiate() as Node3D
	model.position = at
	model.scale = Vector3.ONE * size
	model.rotation.y = yaw
	parent.add_child(model)
	return model


func _add_disc(parent: Node3D, at: Vector3, radius: float, color: Color, height: float = 0.08) -> void:
	var disc := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius * 0.82
	mesh.outer_radius = radius
	disc.mesh = mesh
	disc.position = at
	disc.material_override = _material(color, true)
	parent.add_child(disc)


func _build_planet() -> void:
	for node in world_root.get_children():
		node.queue_free()
	blocked_cells.clear()
	var planet: Dictionary = PLANETS[planet_index]
	world_environment.environment.background_color = planet["sky"]
	_static_box(world_root, Vector3(0, -0.38, 0), Vector3(29, 0.76, 29), planet["ground"])
	for x in range(-12, 13, 4):
		for z in range(-12, 13, 4):
			_add_model(world_root, FLOOR_MODEL, Vector3(x, 0.01, z))
			if (x + z) % 12 == 0:
				_add_disc(world_root, Vector3(x, 0.025, z), 0.16, planet["accent"], 0.035)
	var wall_color: Color = planet["accent"].darkened(0.55)
	_static_box(world_root, Vector3(-14.5, 1.2, 0), Vector3(0.7, 2.4, 29), wall_color, false)
	_static_box(world_root, Vector3(14.5, 1.2, 0), Vector3(0.7, 2.4, 29), wall_color, false)
	_static_box(world_root, Vector3(0, 1.2, -14.5), Vector3(29, 2.4, 0.7), wall_color, false)
	_static_box(world_root, Vector3(0, 1.2, 14.5), Vector3(29, 2.4, 0.7), wall_color, false)
	for offset in range(-12, 13, 4):
		var north := _add_model(world_root, WALL_MODEL, Vector3(offset, 0, -14.0))
		north.scale.y = 0.58
		var south := _add_model(world_root, WALL_MODEL, Vector3(offset, 0, 14.0), 1.0, PI)
		south.scale.y = 0.58
		var west := _add_model(world_root, WALL_MODEL, Vector3(-14.0, 0, offset), 1.0, PI * 0.5)
		west.scale.y = 0.58
		var east := _add_model(world_root, WALL_MODEL, Vector3(14.0, 0, offset), 1.0, -PI * 0.5)
		east.scale.y = 0.58
	for x_sign in [-1, 1]:
		for z_sign in [-1, 1]:
			var corner := _add_model(world_root, CORNER_MODEL, Vector3(x_sign * 14.0, 0, z_sign * 14.0), 1.0, PI * 0.5 * float(x_sign + z_sign + 2))
			corner.scale.y = 0.58
	_add_model(world_root, GATE_MODEL, Vector3(0, 0, -14.15), 0.6)
	_add_model(world_root, CRAFT_MODEL, Vector3(-10.5, 0, -10.5), 2.0, PI * 0.25)
	_add_model(world_root, DISH_MODEL, Vector3(10.7, 0, -10.3), 2.1, PI * 0.7)
	_add_model(world_root, GENERATOR_MODEL, Vector3(-11.5, 0, 10.5), 2.4, PI * 0.35)
	_add_model(world_root, GENERATOR_MODEL, Vector3(11.5, 0, 10.5), 2.4, -PI * 0.3)
	var rock_positions := [
		Vector3(-5, 0, -4), Vector3(5, 0, -3),
		Vector3(-4, 0, 5), Vector3(5, 0, 5)
	]
	if planet_index >= 1:
		rock_positions.append(Vector3(0, 0, -7))
	if planet_index >= 2:
		rock_positions.append(Vector3(0, 0, 8))
	for rock_position in rock_positions:
		_static_box(world_root, rock_position + Vector3.UP, Vector3(2.0, 2.0, 2.0), wall_color, false)
		var rock_scene: PackedScene = [ROCK_MODEL, CRYSTAL_MODEL, METEOR_MODEL][(int(blocked_cells.size() / 5.0) + planet_index) % 3]
		_add_model(world_root, rock_scene, rock_position, 2.5, randf_range(0.0, TAU))
		_add_disc(world_root, rock_position + Vector3(0, 0.05, 0), 1.3, planet["accent"].darkened(0.35), 0.05)
		blocked_cells.append(_world_to_cell(rock_position))
		var cell := _world_to_cell(rock_position)
		for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			if not blocked_cells.has(cell + offset):
				blocked_cells.append(cell + offset)
	for i in 12:
		var angle := TAU * float(i) / 12.0
		var light_pos := Vector3(cos(angle) * 12.5, 0.07, sin(angle) * 12.5)
		_add_disc(world_root, light_pos, 0.2, planet["accent"])
	for i in 16:
		var angle := TAU * float(i) / 16.0
		var distance := 19.0 + float(i % 4) * 3.5
		var debris_pos := Vector3(cos(angle) * distance, -0.8, sin(angle) * distance)
		_add_model(world_root, METEOR_MODEL if i % 3 == 0 else ROCK_MODEL, debris_pos, 2.0 + float(i % 3), angle)
	var distant_ground := MeshInstance3D.new()
	var distant_mesh := PlaneMesh.new()
	distant_mesh.size = Vector2(120, 120)
	distant_ground.mesh = distant_mesh
	distant_ground.position.y = -1.0
	distant_ground.material_override = _material(planet["ground"].darkened(0.45))
	world_root.add_child(distant_ground)
	var accent_light := OmniLight3D.new()
	accent_light.position = Vector3(0, 8, 0)
	accent_light.light_color = planet["accent"]
	accent_light.light_energy = 0.24
	accent_light.omni_range = 35.0
	world_root.add_child(accent_light)
	player.position = Vector3.ZERO
	companion.position = Vector3(-1.5, 1.6, 1.5)


func _build_interface() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(overlay)

	var hud_panel := PanelContainer.new()
	hud_panel.position = Vector2(22, 20)
	hud_panel.custom_minimum_size = Vector2(270, 118)
	hud_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.05, 0.09, 0.85)))
	overlay.add_child(hud_panel)
	hud_label = Label.new()
	hud_label.add_theme_font_size_override("font_size", 18)
	hud_label.add_theme_color_override("font_color", Color(0.88, 0.97, 1.0))
	hud_panel.add_child(hud_label)

	message_label = Label.new()
	message_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	message_label.position = Vector2(-300, 24)
	message_label.custom_minimum_size = Vector2(600, 38)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 22)
	message_label.add_theme_color_override("font_color", Color(1.0, 0.93, 0.60))
	overlay.add_child(message_label)

	hint_label = Label.new()
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint_label.position = Vector2(-420, -46)
	hint_label.custom_minimum_size = Vector2(840, 34)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 16)
	hint_label.text = "WASD MOVE   •   MOUSE AIM + LEFT CLICK FIRE   •   SHIFT DODGE   •   Q DRONE MODE   •   F TURRET   •   TAB COMMAND"
	overlay.add_child(hint_label)

	modal = PanelContainer.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	modal.position = Vector2(-270, -190)
	modal.custom_minimum_size = Vector2(540, 380)
	modal.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.06, 0.12, 0.97)))
	overlay.add_child(modal)
	var modal_content := VBoxContainer.new()
	modal_content.add_theme_constant_override("separation", 16)
	modal.add_child(modal_content)
	modal_title = Label.new()
	modal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_title.add_theme_font_size_override("font_size", 34)
	modal_title.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
	modal_content.add_child(modal_title)
	modal_body = Label.new()
	modal_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_body.custom_minimum_size = Vector2(500, 70)
	modal_body.add_theme_font_size_override("font_size", 17)
	modal_content.add_child(modal_body)
	modal_buttons = VBoxContainer.new()
	modal_buttons.add_theme_constant_override("separation", 10)
	modal_content.add_child(modal_buttons)

	command_line = LineEdit.new()
	command_line.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	command_line.position = Vector2(-280, -92)
	command_line.custom_minimum_size = Vector2(560, 40)
	command_line.placeholder_text = "Tell your drone: attack, defend, or heal"
	command_line.visible = false
	command_line.text_submitted.connect(_on_command_submitted)
	overlay.add_child(command_line)


func _panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.27, 0.75, 0.94, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(13)
	style.set_content_margin_all(18)
	return style


func _show_modal(title: String, body: String, actions: Array[Dictionary]) -> void:
	modal.visible = true
	modal_title.text = title
	modal_body.text = body
	for child in modal_buttons.get_children():
		child.queue_free()
	for action in actions:
		var button := Button.new()
		button.text = str(action.get("label", "Continue"))
		button.custom_minimum_size.y = 47
		button.add_theme_font_size_override("font_size", 18)
		modal_buttons.add_child(button)
		button.pressed.connect(action["callback"])


func _show_menu() -> void:
	phase = "menu"
	hud_label.text = ""
	_show_modal("ORBIT ARENA", "Three planets. Three waves each. Pick upgrades and fight alongside your AI wingmate.", [
		{"label": "START EXPEDITION", "callback": Callable(self, "start_run")}
	])


func start_run() -> void:
	planet_index = 0
	wave_index = 0
	algorithm_cursor = 0
	kills = 0
	player_max_health = 100.0
	player_health = 100.0
	player_damage = 16.0
	fire_delay = 0.32
	dodge_recharge = 2.8
	drone_damage = 6.0
	drone_mode = "ATTACK"
	support_charges = 1
	enemy_speed_multiplier = 1.0
	_clear_combat_objects()
	_build_planet()
	_start_wave()


func _clear_combat_objects() -> void:
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	enemies.clear()
	for item in projectiles:
		if is_instance_valid(item.get("node")):
			item["node"].queue_free()
	projectiles.clear()
	for turret in turrets:
		if is_instance_valid(turret.get("node")):
			turret["node"].queue_free()
	turrets.clear()


func _start_wave() -> void:
	phase = "combat"
	modal.visible = false
	rule_pending = false
	hazard_timer = 7.0
	var spawn_positions := [
		Vector3(-10, 0, -9), Vector3(10, 0, -9), Vector3(-10, 0, 9),
		Vector3(10, 0, 9), Vector3(0, 0, -11), Vector3(0, 0, 11)
	]
	if wave_index == 2:
		_spawn_enemy(Vector3(0, 0, -10), "astar", true)
		_announce("BOSS WAVE — %s" % PLANETS[planet_index]["name"], 3.0)
	else:
		var count := 3 if wave_index == 0 else 4
		for i in count:
			var algorithm: String = PATH_ALGORITHMS[algorithm_cursor % PATH_ALGORITHMS.size()]
			algorithm_cursor += 1
			_spawn_enemy(spawn_positions[i], algorithm, false)
		_announce("WAVE %d — CLEAR THE ARENA" % (wave_index + 1), 2.5)


func _spawn_enemy(spawn_position: Vector3, algorithm: String, boss: bool) -> void:
	var enemy: OrbitEnemy = EnemyScript.new()
	enemy.configure(self, algorithm, boss, planet_index)
	enemy.position = spawn_position
	enemy.eliminated.connect(_on_enemy_eliminated)
	enemy_root.add_child(enemy)
	enemies.append(enemy)


func _on_enemy_eliminated(enemy: OrbitEnemy) -> void:
	enemies.erase(enemy)
	kills += 1
	if enemies.is_empty() and phase == "combat" and not rule_pending:
		rule_pending = true
		AIClient.request_rule_inference({
			"arena_wave_active": true,
			"arena_enemies_remaining": 0,
			"arena_player_alive": player_health > 0.0
		}, ["arena"], 10, func(result: Dictionary) -> void:
			if phase != "combat" or not enemies.is_empty():
				return
			var derived: Dictionary = result.get("data", {}).get("derived_facts", {})
			if bool(result.get("success", false)) and bool(derived.get("arena_wave_cleared", false)):
				_announce("WAVE CLEARED • RULE ENGINE CONFIRMED", 2.0)
			_finish_wave()
		)


func _finish_wave() -> void:
	if wave_index == 2:
		phase = "victory" if planet_index == PLANETS.size() - 1 else "planet_clear"
		if phase == "victory":
			_show_modal("GALAXY CLEARED", "You and your wingmate survived all three planets. Total enemies defeated: %d." % kills, [
				{"label": "PLAY AGAIN", "callback": Callable(self, "start_run")}
			])
		else:
			_show_modal("PLANET CLEARED", "%s secured. Your upgrades and AI wingmate carry forward." % PLANETS[planet_index]["name"], [
				{"label": "NEXT PLANET", "callback": Callable(self, "_next_planet")}
			])
	else:
		phase = "upgrade"
		support_charges += 1
		var first := (planet_index * 2 + wave_index * 2) % UPGRADE_NAMES.size()
		var actions: Array[Dictionary] = []
		for i in 3:
			var index := (first + i) % UPGRADE_NAMES.size()
			actions.append({
				"label": "%s  —  %s" % [UPGRADE_NAMES[index], UPGRADE_DESCRIPTIONS[index]],
				"callback": Callable(self, "_choose_upgrade").bind(index)
			})
		_show_modal("CHOOSE AN UPGRADE", "Wave cleared. Pick one upgrade before the next fight.", actions)


func _choose_upgrade(index: int) -> void:
	match index:
		0:
			player_damage += 6.0
		1:
			player_max_health += 25.0
			player_health = minf(player_max_health, player_health + 25.0)
		2:
			fire_delay = maxf(0.12, fire_delay * 0.8)
		3:
			drone_damage += 5.0
		4:
			dodge_recharge = maxf(0.9, dodge_recharge - 0.5)
		5:
			support_charges += 2
	wave_index += 1
	_start_wave()


func _next_planet() -> void:
	planet_index += 1
	wave_index = 0
	player_health = minf(player_max_health, player_health + 35.0)
	_clear_combat_objects()
	_build_planet()
	_start_wave()


func _physics_process(delta: float) -> void:
	if phase != "combat":
		return
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	dodge_cooldown = maxf(0.0, dodge_cooldown - delta)
	hurt_cooldown = maxf(0.0, hurt_cooldown - delta)
	recent_damage = maxf(0.0, recent_damage - delta * 5.0)
	_update_player(delta)
	_update_companion(delta)
	_update_turrets(delta)
	_update_projectiles(delta)
	_update_hazard(delta)
	fuzzy_timer -= delta
	if fuzzy_timer <= 0.0:
		fuzzy_timer = 3.5
		_refresh_difficulty()


func _process(delta: float) -> void:
	var target := player.global_position + Vector3(0, 21, 19)
	camera.global_position = camera.global_position.lerp(target, minf(1.0, delta * 4.0))
	camera.look_at(player.global_position + Vector3.UP * 0.5)
	if message_timer > 0.0:
		message_timer -= delta
		message_label.text = current_message
	else:
		message_label.text = ""
	var planet: Dictionary = PLANETS[planet_index]
	var boss_label := "BOSS" if wave_index == 2 else str(wave_index + 1)
	hud_label.text = "%s  •  %s\nWAVE %s / 3     ENEMIES %d\nHP %d / %d     KILLS %d\nDRONE %s     CHARGES %d" % [
		planet["name"], planet["subtitle"], boss_label, enemies.size(),
		ceili(player_health), ceili(player_max_health), kills, drone_mode, support_charges
	]
	if wave_index == 2 and not enemies.is_empty() and is_instance_valid(enemies[0]):
		hud_label.text += "\nBOSS HP %d / %d" % [ceili(enemies[0].health), ceili(enemies[0].max_health)]


func _update_player(_delta: float) -> void:
	if command_line.visible:
		player.velocity = Vector3.ZERO
		return
	var move_input := Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	).normalized()
	player.velocity = Vector3(move_input.x, 0, move_input.y) * 7.0
	player.move_and_slide()
	player.position.x = clampf(player.position.x, -12.5, 12.5)
	player.position.z = clampf(player.position.z, -12.5, 12.5)
	var aim := _aim_point() - player.global_position
	aim.y = 0.0
	if aim.length() > 0.2:
		player_visual.rotation.y = atan2(aim.x, aim.z)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and fire_cooldown <= 0.0:
		_fire_player()


func _aim_point() -> Vector3:
	var mouse := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse)
	var direction := camera.project_ray_normal(mouse)
	if absf(direction.y) < 0.001:
		return player.global_position + Vector3(0, 0, -5)
	var distance := (0.8 - origin.y) / direction.y
	return origin + direction * distance


func _fire_player() -> void:
	fire_cooldown = fire_delay
	var origin := player.global_position + Vector3.UP * 1.0
	var aim := _aim_point()
	var heading := aim - origin
	heading.y = 0.0
	if heading.length() < 0.1:
		heading = Vector3.FORWARD
	_spawn_projectile(origin, heading.normalized(), player_damage, true, Color(0.24, 0.88, 1.0))


func _spawn_projectile(origin: Vector3, direction: Vector3, damage: float, friendly: bool, color: Color) -> void:
	var visual := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.17 if friendly else 0.24
	mesh.height = mesh.radius * 2.0
	visual.mesh = mesh
	visual.material_override = _material(color, true)
	visual.position = origin
	projectile_root.add_child(visual)
	projectiles.append({
		"node": visual, "direction": direction.normalized(), "damage": damage,
		"friendly": friendly, "life": 2.0
	})


func spawn_enemy_shot(origin: Vector3, target: Vector3, damage: float) -> void:
	_spawn_projectile(origin, target - origin, damage, false, Color(1.0, 0.28, 0.24))


func _update_projectiles(delta: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var item: Dictionary = projectiles[i]
		var visual: MeshInstance3D = item["node"]
		item["life"] = float(item["life"]) - delta
		visual.position += item["direction"] * (18.0 if item["friendly"] else 10.0) * delta
		var hit := false
		if item["friendly"]:
			for enemy in enemies.duplicate():
				if is_instance_valid(enemy) and visual.global_position.distance_to(enemy.global_position + Vector3.UP) < (1.1 if enemy.is_boss else 0.72):
					enemy.take_hit(float(item["damage"]))
					hit = true
					break
		elif visual.global_position.distance_to(player.global_position + Vector3.UP) < 0.75:
			damage_player(float(item["damage"]))
			hit = true
		if hit or float(item["life"]) <= 0.0 or absf(visual.position.x) > 14.0 or absf(visual.position.z) > 14.0:
			projectiles.remove_at(i)
			visual.queue_free()
		else:
			projectiles[i] = item


func _update_companion(delta: float) -> void:
	var offset := Vector3(-1.8, 1.7, 1.7)
	companion.global_position = companion.global_position.lerp(player.global_position + offset, minf(1.0, delta * 5.0))
	companion.position.y += sin(Time.get_ticks_msec() * 0.004) * 0.002
	drone_cooldown = maxf(0.0, drone_cooldown - delta)
	drone_heal_cooldown = maxf(0.0, drone_heal_cooldown - delta)
	if drone_mode == "HEAL" and drone_heal_cooldown <= 0.0:
		drone_heal_cooldown = 3.0
		player_health = minf(player_max_health, player_health + 5.0)
	if drone_cooldown > 0.0 or enemies.is_empty():
		return
	var target := _nearest_enemy(companion.global_position, 14.0)
	if target == null:
		return
	drone_cooldown = 1.2 if drone_mode == "ATTACK" else 1.8
	_spawn_projectile(companion.global_position, target.global_position + Vector3.UP - companion.global_position, drone_damage, true, Color(0.3, 1.0, 0.8))


func _nearest_enemy(origin: Vector3, max_distance: float) -> OrbitEnemy:
	var best: OrbitEnemy = null
	var best_distance := max_distance
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var distance := origin.distance_to(enemy.global_position)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	return best


func _update_turrets(delta: float) -> void:
	for index in turrets.size():
		var turret: Dictionary = turrets[index]
		turret["cooldown"] = maxf(0.0, float(turret["cooldown"]) - delta)
		if float(turret["cooldown"]) <= 0.0:
			var node: Node3D = turret["node"]
			var target := _nearest_enemy(node.global_position, 10.0)
			if target != null:
				_spawn_projectile(node.global_position + Vector3.UP, target.global_position + Vector3.UP - node.global_position - Vector3.UP, 10.0, true, Color(1.0, 0.87, 0.35))
				turret["cooldown"] = 1.15
		turrets[index] = turret


func _update_hazard(delta: float) -> void:
	if planet_index == 0:
		return
	hazard_timer -= delta
	if hazard_timer <= 0.0:
		hazard_timer = 7.0 if planet_index == 1 else 5.5
		if absf(player.position.x) > 8.0 or absf(player.position.z) > 8.0:
			damage_player(6.0 if planet_index == 1 else 9.0)
			_announce("PLANET HAZARD — STAY NEAR THE CENTER", 2.0)
		else:
			_announce("HAZARD PULSE AVOIDED", 1.4)


func _refresh_difficulty() -> void:
	var nearest := _nearest_enemy(player.global_position, 100.0)
	var distance := 300.0 if nearest == null else player.global_position.distance_to(nearest.global_position) * 25.0
	AIClient.request_adaptive_difficulty({
		"player_health": player_health / player_max_health * 100.0,
		"recent_damage": recent_damage,
		"enemy_distance": distance,
		"repeated_failures": failures
	}, "", func(result: Dictionary) -> void:
		if phase == "combat" and bool(result.get("success", false)):
			var data: Dictionary = result.get("data", {})
			enemy_speed_multiplier = clampf(float(data.get("enemy_aggression", 0.6)) + 0.4, 0.75, 1.35)
	)


func damage_player(amount: float) -> void:
	if phase != "combat" or hurt_cooldown > 0.0:
		return
	hurt_cooldown = 0.55
	var applied := amount * (0.65 if drone_mode == "GUARD" else 1.0)
	player_health = maxf(0.0, player_health - applied)
	recent_damage = minf(100.0, recent_damage + applied)
	if player_health <= 0.0:
		failures += 1
		phase = "game_over"
		_show_modal("MISSION FAILED", "Your wingmate recovered the escape pod. Try the expedition again.", [
			{"label": "RESTART EXPEDITION", "callback": Callable(self, "start_run")}
		])


func _cycle_drone_mode() -> void:
	var modes := ["ATTACK", "GUARD", "HEAL"]
	drone_mode = modes[(modes.find(drone_mode) + 1) % modes.size()]
	var color := Color(0.2, 0.95, 1.0)
	if drone_mode == "GUARD":
		color = Color(1.0, 0.85, 0.3)
	elif drone_mode == "HEAL":
		color = Color(0.42, 1.0, 0.45)
	companion_visual.material_override = _material(color, true)
	_announce("WINGMATE: %s MODE" % drone_mode, 1.6)


func _deploy_turret() -> void:
	if support_charges <= 0:
		_announce("NO SUPPORT CHARGES", 1.5)
		return
	var player_cell := _world_to_cell(player.global_position)
	var min_x := maxi(1, player_cell.x - 2)
	var min_y := maxi(1, player_cell.y - 2)
	var max_x := mini(12, player_cell.x + 2)
	var max_y := mini(12, player_cell.y + 2)
	var blocked: Array = []
	for cell in blocked_cells:
		blocked.append([cell.x, cell.y])
	var occupied: Array = []
	for turret in turrets:
		var cell: Vector2i = turret["cell"]
		occupied.append([cell.x, cell.y])
	AIClient.request_placement_suggestions({
		"structure_id": "defense_turret",
		"search_zone": [min_x, min_y, max_x, max_y],
		"max_suggestions": 8,
		"available_resources": {"titanium": 10, "crystals": 10},
		"grid_size": [GRID_SIZE.x, GRID_SIZE.y],
		"build_zone": [1, 1, 12, 12],
		"blocked_cells": blocked,
		"occupied_cells": occupied
	}, func(result: Dictionary) -> void:
		if phase != "combat" or support_charges <= 0:
			return
		var suggestions: Array = result.get("data", {}).get("suggestions", [])
		if bool(result.get("success", false)) and not suggestions.is_empty():
			var point: Array = suggestions[0]
			_place_turret(Vector2i(int(point[0]), int(point[1])))
		else:
			for x in range(min_x, max_x + 1):
				for y in range(min_y, max_y + 1):
					var cell := Vector2i(x, y)
					if not blocked_cells.has(cell) and not _turret_at_cell(cell):
						_place_turret(cell)
						return
			_announce("NO SAFE TURRET LOCATION", 1.5)
	)


func _turret_at_cell(cell: Vector2i) -> bool:
	for turret in turrets:
		if turret["cell"] == cell:
			return true
	return false


func _place_turret(cell: Vector2i) -> void:
	var node := Node3D.new()
	node.position = _cell_to_world(cell)
	_add_model(node, TURRET_MODEL, Vector3.ZERO, 2.0)
	_add_disc(node, Vector3(0, 0.05, 0), 0.7, Color(1.0, 0.81, 0.24))
	turret_root.add_child(node)
	turrets.append({"node": node, "cell": cell, "cooldown": 0.3})
	support_charges -= 1
	_announce("SUPPORT TURRET DEPLOYED", 1.5)


func _world_to_cell(world_position: Vector3) -> Vector2i:
	return Vector2i(
		clampi(floori((world_position.x + 14.0) / 2.0), 0, GRID_SIZE.x - 1),
		clampi(floori((world_position.z + 14.0) / 2.0), 0, GRID_SIZE.y - 1)
	)


func _cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(-13.0 + cell.x * 2.0, 0.0, -13.0 + cell.y * 2.0)


func _nearest_free_cell(cell: Vector2i) -> Vector2i:
	if not blocked_cells.has(cell):
		return cell
	for radius in range(1, 4):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				var candidate := cell + Vector2i(dx, dy)
				if candidate.x >= 0 and candidate.y >= 0 and candidate.x < GRID_SIZE.x and candidate.y < GRID_SIZE.y and not blocked_cells.has(candidate):
					return candidate
	return cell


func arena_path(origin: Vector3, destination: Vector3, algorithm: String) -> Array[Vector3]:
	var start := _nearest_free_cell(_world_to_cell(origin))
	var goal := _nearest_free_cell(_world_to_cell(destination))
	var result: Dictionary = PathfinderScript.search(algorithm, start, goal, blocked_cells, GRID_SIZE, {
		"allow_diagonal": true,
		"depth_limit": 28,
		"max_depth": 28
	})
	var output: Array[Vector3] = []
	if bool(result.get("success", false)):
		var cells: Array = result.get("path", [])
		for index in range(1, cells.size()):
			output.append(_cell_to_world(cells[index]))
	return output


func _on_command_submitted(value: String) -> void:
	command_line.visible = false
	command_line.release_focus()
	command_line.clear()
	if value.strip_edges().is_empty():
		return
	AIClient.request_command_parse(value, {}, func(result: Dictionary) -> void:
		var intent := ""
		if bool(result.get("success", false)):
			intent = str(result.get("data", {}).get("parsed", {}).get("intent", ""))
		else:
			var lower := value.to_lower()
			if "attack" in lower:
				intent = "companion_attack"
			elif "defend" in lower or "guard" in lower:
				intent = "companion_guard"
			elif "heal" in lower:
				intent = "companion_heal"
		match intent:
			"companion_attack":
				_set_drone_mode("ATTACK")
			"companion_guard":
				_set_drone_mode("GUARD")
			"companion_heal":
				_set_drone_mode("HEAL")
			"check_vitals":
				_announce("HEALTH %d / %d" % [ceili(player_health), ceili(player_max_health)], 2.0)
			"help":
				_announce("COMMANDS: ATTACK, DEFEND, HEAL", 3.0)
			_:
				_announce("TRY: ATTACK, DEFEND, OR HEAL", 2.0)
	)


func _set_drone_mode(value: String) -> void:
	drone_mode = value
	var colors := {"ATTACK": Color(0.2, 0.95, 1.0), "GUARD": Color(1.0, 0.85, 0.3), "HEAL": Color(0.42, 1.0, 0.45)}
	companion_visual.material_override = _material(colors.get(value, Color.WHITE), true)
	_announce("WINGMATE: %s MODE" % value, 1.6)


func _announce(value: String, duration: float) -> void:
	current_message = value
	message_timer = duration


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB and phase == "combat":
			command_line.visible = not command_line.visible
			if command_line.visible:
				command_line.grab_focus()
			else:
				command_line.release_focus()
			get_viewport().set_input_as_handled()
			return
		if command_line.visible:
			if event.keycode == KEY_ESCAPE:
				command_line.visible = false
				command_line.release_focus()
			return
		if phase == "combat":
			match event.keycode:
				KEY_SHIFT, KEY_SPACE:
					if dodge_cooldown <= 0.0:
						var move_direction := player.velocity.normalized()
						if move_direction.length() < 0.1:
							move_direction = Vector3.FORWARD
						player.global_position += move_direction * 2.5
						player.position.x = clampf(player.position.x, -12.0, 12.0)
						player.position.z = clampf(player.position.z, -12.0, 12.0)
						dodge_cooldown = dodge_recharge
						hurt_cooldown = 0.35
				KEY_Q:
					_cycle_drone_mode()
				KEY_F:
					_deploy_turret()


func is_combat_active() -> bool:
	return phase == "combat"


func get_player_position() -> Vector3:
	return player.global_position


func get_player_health() -> float:
	return player_health


func get_player_max_health() -> float:
	return player_max_health


func get_enemy_speed_multiplier() -> float:
	return enemy_speed_multiplier
