extends Control

signal stage_selected(stage_index: int)
signal home_requested

const PlanetFacts = preload("res://scenes/star_brawl/planet_facts.gd")
const PlanetPortraitScript = preload("res://scenes/star_brawl/planet_portrait.gd")
const CENTERS := [
	Vector2(145, 215), Vector2(390, 215), Vector2(635, 215), Vector2(880, 215), Vector2(1125, 215),
	Vector2(1125, 420), Vector2(880, 420), Vector2(635, 420), Vector2(390, 420), Vector2(145, 420)
]

var stages: Array[Dictionary] = []
var unlocked_stage := 0
var stage_stars: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
var selected_stage := 0
var planet_buttons: Array[Button] = []
var planet_titles: Array[Label] = []
var badges: Array[Label] = []
var star_labels: Array[Label] = []
var detail_title: Label
var detail_body: Label
var enter_button: Button
var progress_label: Label


func _ready() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_controls()
	refresh_map(0, stage_stars)


func configure(stage_data: Array) -> void:
	stages.clear()
	for stage in stage_data:
		stages.append(stage)
	if is_node_ready():
		_build_planets()
		refresh_map(unlocked_stage, stage_stars)


func _draw() -> void:
	for row in 36:
		var t := float(row) / 35.0
		draw_rect(Rect2(0, row * 20, 1280, 21), Color("1b123b").lerp(Color("080f2a"), t))
	for glow in 5:
		var center := Vector2(160 + glow * 240, 310 + sin(float(glow) * 1.3) * 70)
		draw_circle(center, 150, Color(0.27, 0.47, 0.70, 0.055))
	var rng := RandomNumberGenerator.new()
	rng.seed = 223760
	for index in 125:
		var star := Vector2(rng.randf_range(0, 1280), rng.randf_range(0, 690))
		var bright := index % 13 == 0
		draw_circle(star, 1.8 if bright else 0.8, Color(0.68, 0.84, 1.0, 0.68 if bright else 0.34))
		if bright:
			draw_line(star + Vector2(-5, 0), star + Vector2(5, 0), Color(0.55, 0.76, 1.0, 0.16), 1)
	for index in CENTERS.size() - 1:
		_draw_route(CENTERS[index], CENTERS[index + 1], unlocked_stage >= index + 1)
	for index in CENTERS.size():
		var center: Vector2 = CENTERS[index]
		var active := index == selected_stage and index <= unlocked_stage
		var unlocked := index <= unlocked_stage
		var accent: Color = stages[index]["accent"] if index < stages.size() else Color("67dbea")
		var glow := 0.75 if active else 0.34
		draw_circle(center, 68.0, Color(accent, glow * 0.13))
		draw_arc(center, 65.0, 0, TAU, 48, Color(accent if unlocked else Color("667091"), glow), 2.5 if active else 1.5)
		draw_arc(center, 74.0, 0.35, 2.9, 30, Color(accent, 0.28 if unlocked else 0.11), 1.3)
	# Footer shelf creates a clear separation between map and stage details.
	draw_rect(Rect2(0, 557, 1280, 163), Color(0.016, 0.025, 0.075, 0.90))
	draw_line(Vector2(0, 557), Vector2(1280, 557), Color("4c8cae"), 2.0)
	draw_rect(Rect2(0, 0, 1280, 5), Color("48c8dc"))


func _draw_route(start: Vector2, finish: Vector2, lit: bool) -> void:
	for step in 16:
		if step % 2 == 0:
			var point := start.lerp(finish, float(step) / 15.0)
			draw_circle(point, 2.5 if lit else 1.8, Color("f9db83") if lit else Color("706f98"))


func _build_controls() -> void:
	_text("HORIZON ARK // STAR ROUTE", Vector2(53, 27), Vector2(760, 65), 39, Color("f4f5ff"))
	_text("FOLLOW THE DISTRESS SIGNAL  •  TEN CHAPTERS  •  ONE CREW TO SAVE", Vector2(57, 91), Vector2(900, 30), 16, Color("adbbdf"))
	progress_label = _text("", Vector2(724, 34), Vector2(275, 36), 18, Color("90e9e9"))
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var home_button := _button("⌂  HOME", Vector2(1054, 31), Vector2(170, 50), Color("233554"), Color("65d6ea"))
	home_button.pressed.connect(func() -> void: home_requested.emit())
	detail_title = _text("", Vector2(55, 572), Vector2(850, 46), 30, Color("f3f6ff"))
	detail_body = _text("", Vector2(57, 617), Vector2(865, 65), 16, Color("b7c9e8"))
	enter_button = _button("VIEW LEVEL  ›", Vector2(972, 596), Vector2(250, 70), Color("116b86"), Color("61ecf4"))
	enter_button.pressed.connect(func() -> void: stage_selected.emit(selected_stage))
	_build_planets()


func _build_planets() -> void:
	for button in planet_buttons:
		button.queue_free()
	for label in planet_titles + badges + star_labels:
		label.queue_free()
	planet_buttons.clear()
	planet_titles.clear()
	badges.clear()
	star_labels.clear()
	for index in mini(stages.size(), CENTERS.size()):
		var center: Vector2 = CENTERS[index]
		var stage: Dictionary = stages[index]
		var button := Button.new()
		button.position = center - Vector2(59, 59)
		button.size = Vector2(118, 118)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		button.pressed.connect(_select_stage.bind(index))
		add_child(button)
		planet_buttons.append(button)
		var planet := PlanetPortraitScript.new() as Node2D
		planet.position = Vector2(59, 59)
		planet.call("set_planet", index, 49.0)
		button.add_child(planet)
		var title := _text(stage["name"], center + Vector2(-100, 67), Vector2(200, 25), 15, Color("f1eeff"))
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		planet_titles.append(title)
		var badge := _text(str(index + 1), center + Vector2(-52, 35), Vector2(35, 35), 17, Color("ecffff"))
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_theme_stylebox_override("normal", _style(Color("087797"), Color("c0faff"), 2, 18))
		badges.append(badge)
		var stars := _text("☆☆☆", center + Vector2(-53, 92), Vector2(106, 26), 18, Color("ffe692"))
		stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		star_labels.append(stars)


func refresh_map(unlocked: int, ratings: Array[int]) -> void:
	unlocked_stage = clampi(unlocked, 0, maxi(0, stages.size() - 1))
	stage_stars = ratings.duplicate()
	selected_stage = mini(selected_stage, unlocked_stage)
	progress_label.text = "%d / %d ORBITS OPEN" % [unlocked_stage + 1, stages.size()]
	for index in planet_buttons.size():
		var open := index <= unlocked_stage
		planet_buttons[index].disabled = not open
		planet_buttons[index].modulate = Color.WHITE if open else Color(0.45, 0.48, 0.65, 0.77)
		planet_titles[index].text = str(stages[index]["name"]) if open else "LOCKED ORBIT"
		planet_titles[index].modulate.a = 1.0 if open else 0.55
		star_labels[index].text = "★".repeat(stage_stars[index]) + "☆".repeat(3 - stage_stars[index]) if open else "···"
		star_labels[index].add_theme_font_size_override("font_size", 18 if open else 15)
	_update_details()
	queue_redraw()


func _select_stage(index: int) -> void:
	if index > unlocked_stage:
		return
	selected_stage = index
	_update_details()
	queue_redraw()


func _update_details() -> void:
	if stages.is_empty():
		return
	var stage: Dictionary = stages[selected_stage]
	detail_title.text = "%02d  /  %s" % [selected_stage + 1, stage["chapter"]]
	detail_body.text = "%s  •  %s\n%s" % [stage["world"], PlanetFacts.short_fact(selected_stage), stage["story"]]
	enter_button.text = "VIEW REPLAY  ›" if stage_stars[selected_stage] > 0 else "VIEW LEVEL  ›"


func _text(value: String, at: Vector2, dimensions: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.position = at
	label.size = dimensions
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(label)
	return label


func _button(value: String, at: Vector2, dimensions: Vector2, background: Color, border: Color) -> Button:
	var button := Button.new()
	button.text = value
	button.position = at
	button.size = dimensions
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color("effdff"))
	button.add_theme_stylebox_override("normal", _style(background, border))
	button.add_theme_stylebox_override("hover", _style(background.lightened(0.22), Color.WHITE))
	button.add_theme_stylebox_override("pressed", _style(background.darkened(0.18), Color.WHITE))
	add_child(button)
	return button


func _style(background: Color, border: Color, width: int = 2, radius: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 8
	return style
