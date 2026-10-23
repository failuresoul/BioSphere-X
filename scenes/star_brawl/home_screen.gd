extends Control

signal play_requested
signal exit_requested
signal pilot_selected(index: int)
signal restart_confirmed

const ASSET := "res://assets/star_brawl/"
const PilotAvatarScript = preload("res://scenes/star_brawl/pilot_avatar.gd")

var controls_panel: Panel
var settings_panel: Panel
var restart_panel: Panel
var menu_scrim: ColorRect
var play_button: Button
var progress_text: Label
var volume_slider: HSlider
var volume_label: Label
var fullscreen_toggle: CheckButton
var planet_texture: Texture2D
var pilot_preview: Node2D
var pilot_name: Label
var pilot_role: Label
var selected_pilot := 0
var preview_clock := 0.0
var preview_timer := 0.0
var settings_path := "user://biosphere_x_settings.cfg"


func _ready() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	planet_texture = load(ASSET + "planets/planet05.png") as Texture2D
	_build_controls()
	_load_settings()
	set_pilot(0)


func _process(delta: float) -> void:
	if not visible:
		return
	preview_clock += delta
	preview_timer -= delta
	if preview_timer <= 0.0:
		preview_timer = 0.05
		pilot_preview.call("set_visual", selected_pilot, "idle", 1, preview_clock)


func _draw() -> void:
	for row in 36:
		var ratio := float(row) / 35.0
		draw_rect(Rect2(0, row * 20, 1280, 21), Color("111b43").lerp(Color("080b22"), ratio))
	for index in 10:
		var center := Vector2(960 + cos(float(index) * 0.9) * 95, 335 + sin(float(index) * 0.9) * 70)
		draw_circle(center, 180 + index * 14, Color(0.14, 0.47, 0.64, 0.014))
	var rng := RandomNumberGenerator.new()
	rng.seed = 991235
	for index in 175:
		var at := Vector2(rng.randf_range(0, 1280), rng.randf_range(0, 720))
		draw_circle(at, 1.8 if index % 13 == 0 else 0.8, Color(0.75, 0.87, 1.0, 0.72 if index % 13 == 0 else 0.32))
	draw_arc(Vector2(953, 355), 272, -0.55, 4.65, 120, Color(0.40, 0.86, 0.96, 0.46), 3.0)
	draw_arc(Vector2(953, 355), 296, 1.75, 5.8, 90, Color(0.69, 0.42, 0.98, 0.24), 2.0)
	draw_circle(Vector2(953, 355), 242, Color(0.26, 0.76, 0.89, 0.08))
	if planet_texture:
		draw_texture_rect(planet_texture, Rect2(743, 145, 422, 422), false)
	draw_circle(Vector2(952, 455), 97, Color(0.02, 0.07, 0.17, 0.62))
	draw_arc(Vector2(952, 455), 98, 0.2, TAU - 0.2, 56, Color("77e7e7", 0.6), 2.0)
	draw_rect(Rect2(0, 685, 1280, 35), Color(0.02, 0.04, 0.11, 0.85))
	draw_line(Vector2(0, 684), Vector2(1280, 684), Color(0.30, 0.69, 0.77, 0.35), 1.0)


func _build_controls() -> void:
	_text("NOVA COMMAND // SECTOR 07", Vector2(68, 60), Vector2(650, 32), 18, Color("65e6eb"))
	_text("BIOSPHERE", Vector2(64, 124), Vector2(650, 103), 82, Color("f5fbff"))
	_text("X", Vector2(548, 124), Vector2(105, 103), 82, Color("72eae8"))
	play_button = _button("PLAY  ›", Vector2(126, 294), Vector2(390, 60), Color("087f96"), Color("69f1f1"))
	play_button.add_theme_font_size_override("font_size", 26)
	play_button.pressed.connect(func() -> void: play_requested.emit())
	var help_button := _button("GUIDE", Vector2(126, 370), Vector2(390, 60), Color("202d56"), Color("829bd8"))
	help_button.add_theme_font_size_override("font_size", 25)
	help_button.pressed.connect(_show_controls)
	var settings_button := _button("SETTINGS", Vector2(126, 446), Vector2(390, 60), Color("202d56"), Color("829bd8"))
	settings_button.add_theme_font_size_override("font_size", 25)
	settings_button.pressed.connect(_show_settings)
	var restart_button := _button("RESTART", Vector2(126, 522), Vector2(390, 60), Color("202d56"), Color("829bd8"))
	restart_button.add_theme_font_size_override("font_size", 25)
	restart_button.pressed.connect(_show_restart_confirmation)
	progress_text = _text("", Vector2(127, 605), Vector2(390, 28), 16, Color("f6da88"))
	progress_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pilot_preview = PilotAvatarScript.new() as Node2D
	pilot_preview.position = Vector2(952, 457)
	pilot_preview.scale = Vector2.ONE * 3.0
	add_child(pilot_preview)
	_text("CHOOSE YOUR PILOT", Vector2(786, 552), Vector2(335, 28), 18, Color("e0f9ff")).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var previous := _button("‹", Vector2(753, 586), Vector2(48, 48), Color("173152"), Color("6adfe5"))
	previous.pressed.connect(func() -> void: _choose_pilot(-1))
	var next := _button("›", Vector2(1105, 586), Vector2(48, 48), Color("173152"), Color("6adfe5"))
	next.pressed.connect(func() -> void: _choose_pilot(1))
	pilot_name = _text("", Vector2(811, 582), Vector2(286, 28), 21, Color("f4ffff"))
	pilot_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pilot_role = _text("", Vector2(811, 612), Vector2(286, 25), 14, Color("9be7e7"))
	pilot_role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var quit_button := _button("EXIT GAME", Vector2(1084, 28), Vector2(153, 43), Color("111c3c"), Color("52738e"))
	quit_button.add_theme_font_size_override("font_size", 15)
	quit_button.pressed.connect(func() -> void: exit_requested.emit())
	_text("© BIOSPHERE X  /  GALACTIC ARENA", Vector2(26, 690), Vector2(620, 22), 12, Color("7795b9"))
	menu_scrim = ColorRect.new()
	menu_scrim.size = Vector2(1280, 720)
	menu_scrim.color = Color(0.01, 0.03, 0.10, 0.70)
	menu_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_scrim.visible = false
	add_child(menu_scrim)
	controls_panel = Panel.new()
	controls_panel.position = Vector2(335, 113)
	controls_panel.size = Vector2(610, 499)
	controls_panel.add_theme_stylebox_override("panel", _style(Color("0c193a"), Color("66dfe9"), 3))
	controls_panel.visible = false
	menu_scrim.add_child(controls_panel)
	var heading := _panel_text("PILOT CONTROLS", Vector2(36, 32), Vector2(540, 52), 36, Color("e9fbff"))
	controls_panel.add_child(heading)
	var body := _panel_text("A / D or arrows       Move through the arena\nSpace or W              Double jump and stomp\nJ                                 Close strike\nK                                Star blaster\nShift                          Dash past traps\nE                                Orbit Pulse at 70 energy\nQ                               Cycle suit modes\nTab                            Type a suit command\nEsc                            Pause the fight", Vector2(53, 103), Vector2(520, 313), 20, Color("cce0f4"))
	controls_panel.add_child(body)
	var close_button := _button("BACK TO HOME", Vector2(178, 420), Vector2(254, 55), Color("12637d"), Color("71e9f1"))
	close_button.reparent(controls_panel)
	close_button.position = Vector2(178, 420)
	close_button.pressed.connect(close_controls)
	_build_settings_panel()
	_build_restart_panel()


func _build_settings_panel() -> void:
	settings_panel = Panel.new()
	settings_panel.position = Vector2(350, 151)
	settings_panel.size = Vector2(580, 418)
	settings_panel.add_theme_stylebox_override("panel", _style(Color("0c193a"), Color("66dfe9"), 3))
	settings_panel.visible = false
	menu_scrim.add_child(settings_panel)
	settings_panel.add_child(_panel_text("SETTINGS", Vector2(40, 31), Vector2(500, 52), 36, Color("e9fbff")))
	volume_label = _panel_text("SOUND VOLUME", Vector2(49, 115), Vector2(480, 32), 21, Color("cce0f4"))
	settings_panel.add_child(volume_label)
	volume_slider = HSlider.new()
	volume_slider.position = Vector2(51, 166)
	volume_slider.size = Vector2(478, 36)
	volume_slider.min_value = 0
	volume_slider.max_value = 100
	volume_slider.step = 5
	settings_panel.add_child(volume_slider)
	volume_slider.value_changed.connect(_on_volume_changed)
	fullscreen_toggle = CheckButton.new()
	fullscreen_toggle.text = "FULLSCREEN"
	fullscreen_toggle.position = Vector2(47, 229)
	fullscreen_toggle.size = Vector2(480, 52)
	fullscreen_toggle.add_theme_font_size_override("font_size", 21)
	fullscreen_toggle.add_theme_color_override("font_color", Color("cce0f4"))
	settings_panel.add_child(fullscreen_toggle)
	fullscreen_toggle.toggled.connect(_on_fullscreen_changed)
	var back_button := _button("BACK TO HOME", Vector2(161, 331), Vector2(258, 55), Color("12637d"), Color("71e9f1"))
	back_button.reparent(settings_panel)
	back_button.position = Vector2(161, 331)
	back_button.pressed.connect(close_controls)


func _build_restart_panel() -> void:
	restart_panel = Panel.new()
	restart_panel.position = Vector2(350, 179)
	restart_panel.size = Vector2(580, 362)
	restart_panel.add_theme_stylebox_override("panel", _style(Color("0c193a"), Color("66dfe9"), 3))
	restart_panel.visible = false
	menu_scrim.add_child(restart_panel)
	restart_panel.add_child(_panel_text("RESTART CAMPAIGN?", Vector2(40, 32), Vector2(500, 54), 34, Color("e9fbff")))
	var warning := _panel_text("All chapter progress and suit upgrades\nwill be cleared.\nYour selected pilot stays.", Vector2(45, 110), Vector2(500, 120), 21, Color("cce0f4"))
	restart_panel.add_child(warning)
	var confirm_button := _button("RESET PROGRESS", Vector2(43, 259), Vector2(237, 59), Color("90465c"), Color("ffb5bd"))
	confirm_button.reparent(restart_panel)
	confirm_button.position = Vector2(43, 259)
	confirm_button.pressed.connect(_confirm_restart)
	var cancel_button := _button("CANCEL", Vector2(300, 259), Vector2(237, 59), Color("12637d"), Color("71e9f1"))
	cancel_button.reparent(restart_panel)
	cancel_button.position = Vector2(300, 259)
	cancel_button.pressed.connect(close_controls)


func _load_settings() -> void:
	var config := ConfigFile.new()
	config.load(settings_path)
	volume_slider.set_value_no_signal(clampf(float(config.get_value("audio", "volume", 80.0)), 0.0, 100.0))
	fullscreen_toggle.set_pressed_no_signal(bool(config.get_value("display", "fullscreen", false)))
	fullscreen_toggle.text = "FULLSCREEN  •  %s" % ("ON" if fullscreen_toggle.button_pressed else "OFF")
	_apply_volume()
	if DisplayServer.get_name() != "headless" and fullscreen_toggle.button_pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "volume", volume_slider.value)
	config.set_value("display", "fullscreen", fullscreen_toggle.button_pressed)
	config.save(settings_path)


func _apply_volume() -> void:
	var level := volume_slider.value / 100.0
	AudioServer.set_bus_mute(0, level <= 0.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(level, 0.001)))
	volume_label.text = "SOUND VOLUME  %d%%" % roundi(volume_slider.value)


func _on_volume_changed(_value: float) -> void:
	_apply_volume()
	_save_settings()


func _on_fullscreen_changed(enabled: bool) -> void:
	fullscreen_toggle.text = "FULLSCREEN  •  %s" % ("ON" if enabled else "OFF")
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)
	_save_settings()


func set_progress(unlocked_stage: int, completed: int, total_stages: int = 10) -> void:
	play_button.text = "CONTINUE  ›" if completed > 0 else "PLAY  ›"
	progress_text.text = "%d / %d CHAPTERS  •  %d WORLDS OPEN" % [completed, total_stages, unlocked_stage + 1]


func set_pilot(index: int) -> void:
	selected_pilot = clampi(index, 0, PilotAvatarScript.PILOTS.size() - 1)
	if not is_instance_valid(pilot_preview):
		return
	var choice: Dictionary = PilotAvatarScript.PILOTS[selected_pilot]
	pilot_name.text = str(choice["name"])
	pilot_role.text = str(choice["role"])
	pilot_preview.call("set_visual", selected_pilot, "idle", 1, preview_clock)


func _choose_pilot(step: int) -> void:
	set_pilot(posmod(selected_pilot + step, PilotAvatarScript.PILOTS.size()))
	pilot_selected.emit(selected_pilot)


func _show_controls() -> void:
	menu_scrim.visible = true
	settings_panel.visible = false
	restart_panel.visible = false
	controls_panel.visible = true


func _show_settings() -> void:
	menu_scrim.visible = true
	controls_panel.visible = false
	restart_panel.visible = false
	settings_panel.visible = true


func _show_restart_confirmation() -> void:
	menu_scrim.visible = true
	controls_panel.visible = false
	settings_panel.visible = false
	restart_panel.visible = true


func _confirm_restart() -> void:
	close_controls()
	restart_confirmed.emit()


func close_controls() -> bool:
	if controls_panel.visible:
		controls_panel.visible = false
		menu_scrim.visible = false
		return true
	if settings_panel.visible:
		settings_panel.visible = false
		menu_scrim.visible = false
		return true
	if restart_panel.visible:
		restart_panel.visible = false
		menu_scrim.visible = false
		return true
	return false


func _text(value: String, at: Vector2, dimensions: Vector2, font_size: int, color: Color) -> Label:
	var label := _panel_text(value, at, dimensions, font_size, color)
	add_child(label)
	return label


func _panel_text(value: String, at: Vector2, dimensions: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.position = at
	label.size = dimensions
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label


func _button(value: String, at: Vector2, dimensions: Vector2, background: Color, border: Color) -> Button:
	var button := Button.new()
	button.text = value
	button.position = at
	button.size = dimensions
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color("efffff"))
	button.add_theme_stylebox_override("normal", _style(background, border))
	button.add_theme_stylebox_override("hover", _style(background.lightened(0.22), Color.WHITE))
	button.add_theme_stylebox_override("pressed", _style(background.darkened(0.20), Color.WHITE))
	add_child(button)
	return button


func _style(background: Color, border: Color, width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0, 0, 0, 0.48)
	style.shadow_size = 9
	return style
