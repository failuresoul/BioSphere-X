extends Control
## AI vs AI menus: the setup screen (algorithm dropdowns, arena choice) and
## the result panel (single match result or the "Run 10 matches" table).

signal start_requested(config: Dictionary)
signal batch_requested(config: Dictionary, count: int)
signal home_requested

const Pathfinder = preload("res://scripts/utils/modular_pathfinder.gd")
const DECISIONS := ["minimax_ab", "minimax", "mcts"]
const BLUE := Color("5fb4ff")
const RED := Color("ff6f7d")

var dropdowns := {}            # "blue_search", "blue_decision", "red_search", "red_decision", "planet"
var setup_panel: Control
var result_panel: Control
var result_title: Label
var result_subtitle: Label
var result_table: GridContainer
var backend_label: Label


func configure(planets: Array) -> void:
	var planet_box: OptionButton = dropdowns["planet"]
	planet_box.clear()
	for index in planets.size():
		planet_box.add_item("%02d  %s" % [index + 1, planets[index]["name"]])


func _ready() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_setup()
	_build_result()
	show_setup()


func _draw() -> void:
	for row in 36:
		draw_rect(Rect2(0, row * 20, 1280, 21), Color("111b43").lerp(Color("080b22"), row / 35.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7741
	for index in 140:
		draw_circle(Vector2(rng.randf_range(0, 1280), rng.randf_range(0, 720)), 1.0, Color(0.75, 0.87, 1.0, 0.4))


# ---------------------------------------------------------------------------
# Setup screen
# ---------------------------------------------------------------------------
func _build_setup() -> void:
	setup_panel = Control.new()
	setup_panel.size = size
	add_child(setup_panel)
	_label(setup_panel, "AI  vs  AI", Vector2(0, 40), Vector2(1280, 70), 54, Color("f5fbff"), true)
	_label(setup_panel, "Choose how each AI moves (search) and how it fights (decision).", Vector2(0, 112), Vector2(1280, 30), 19, Color("9be7e7"), true)
	_side(Vector2(150, 175), "AI 1  (BLUE)", BLUE, "blue")
	_side(Vector2(690, 175), "AI 2  (RED)", RED, "red")
	(dropdowns["red_search"] as OptionButton).select(Pathfinder.ORDER.find("dfs"))
	(dropdowns["red_decision"] as OptionButton).select(2)       # MCTS
	_label(setup_panel, "ARENA / PLANET", Vector2(390, 445), Vector2(500, 28), 18, Color("e0f9ff"), true)
	dropdowns["planet"] = _dropdown(setup_panel, Vector2(440, 478), [])
	backend_label = _label(setup_panel, "", Vector2(0, 535), Vector2(1280, 26), 16, Color("f6da88"), true)
	_button(setup_panel, "START", Vector2(300, 585), Vector2(220, 62), Color("087f96"), func() -> void: start_requested.emit(get_config()))
	_button(setup_panel, "RUN 10 MATCHES", Vector2(535, 585), Vector2(250, 62), Color("3b4f9a"), func() -> void: batch_requested.emit(get_config(), 10))
	_button(setup_panel, "HOME", Vector2(800, 585), Vector2(180, 62), Color("202d56"), func() -> void: home_requested.emit())


func _side(at: Vector2, title: String, color: Color, key: String) -> void:
	var panel := Panel.new()
	panel.position = at
	panel.size = Vector2(440, 250)
	panel.add_theme_stylebox_override("panel", _style(Color("0c193a"), color, 3))
	setup_panel.add_child(panel)
	_label(panel, title, Vector2(0, 16), Vector2(440, 36), 26, color, true)
	_label(panel, "Search algorithm (movement)", Vector2(40, 66), Vector2(360, 24), 16, Color("cce0f4"))
	var names: Array = []
	for algorithm in Pathfinder.ORDER:
		names.append(Pathfinder.NAMES[algorithm])
	dropdowns[key + "_search"] = _dropdown(panel, Vector2(40, 94), names)
	(dropdowns[key + "_search"] as OptionButton).select(Pathfinder.ORDER.find("astar"))
	_label(panel, "Decision algorithm (combat)", Vector2(40, 146), Vector2(360, 24), 16, Color("cce0f4"))
	dropdowns[key + "_decision"] = _dropdown(panel, Vector2(40, 174), ["Minimax + alpha-beta", "Minimax", "MCTS"])


## The choices on the setup screen as a dictionary.
func get_config() -> Dictionary:
	return {
		"blue_search": Pathfinder.ORDER[(dropdowns["blue_search"] as OptionButton).selected],
		"blue_decision": DECISIONS[(dropdowns["blue_decision"] as OptionButton).selected],
		"red_search": Pathfinder.ORDER[(dropdowns["red_search"] as OptionButton).selected],
		"red_decision": DECISIONS[(dropdowns["red_decision"] as OptionButton).selected],
		"planet": maxi(0, (dropdowns["planet"] as OptionButton).selected),
	}


func show_setup() -> void:
	setup_panel.visible = true
	result_panel.visible = false


func set_backend(online: bool) -> void:
	backend_label.text = "Python AI backend: ONLINE" if online else "Python AI backend: OFFLINE  (run launch_game_with_ai.bat; fighters will use a simple fallback rule)"


# ---------------------------------------------------------------------------
# Result panel (one match, or the 10-match table)
# ---------------------------------------------------------------------------
func _build_result() -> void:
	result_panel = Panel.new()
	result_panel.position = Vector2(190, 70)
	result_panel.size = Vector2(900, 580)
	result_panel.add_theme_stylebox_override("panel", _style(Color("0c193a"), Color("66dfe9"), 3))
	add_child(result_panel)
	result_title = _label(result_panel, "", Vector2(0, 22), Vector2(900, 56), 40, Color("f5fbff"), true)
	result_subtitle = _label(result_panel, "", Vector2(0, 80), Vector2(900, 28), 18, Color("9be7e7"), true)
	result_table = GridContainer.new()
	result_table.columns = 3
	result_table.position = Vector2(90, 130)
	result_table.add_theme_constant_override("h_separation", 40)
	result_table.add_theme_constant_override("v_separation", 8)
	result_panel.add_child(result_table)
	_button(result_panel, "PLAY AGAIN", Vector2(120, 495), Vector2(210, 56), Color("087f96"), func() -> void: start_requested.emit(get_config()))
	_button(result_panel, "SETUP", Vector2(345, 495), Vector2(210, 56), Color("3b4f9a"), show_setup)
	_button(result_panel, "HOME", Vector2(570, 495), Vector2(210, 56), Color("202d56"), func() -> void: home_requested.emit())


## rows: [[label, ai1 value, ai2 value], ...]; the first row is the header.
func show_result(title: String, subtitle: String, rows: Array) -> void:
	setup_panel.visible = false
	result_panel.visible = true
	result_title.text = title
	result_subtitle.text = subtitle
	for child in result_table.get_children():
		result_table.remove_child(child)
		child.queue_free()
	for r in rows.size():
		for c in 3:
			var color := Color("cce0f4") if c == 0 else (BLUE if c == 1 else RED)
			var cell := _label(result_table, str(rows[r][c]), Vector2.ZERO, Vector2(220 if c == 0 else 260, 30), 21 if r == 0 else 18, color)
			cell.custom_minimum_size = Vector2(230 if c == 0 else 250, 30)


# ---------------------------------------------------------------------------
# Small UI helpers
# ---------------------------------------------------------------------------
func _label(parent: Node, text: String, at: Vector2, dimensions: Vector2, font_size: int, color: Color, centered: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = dimensions
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if centered:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label


func _dropdown(parent: Node, at: Vector2, items: Array) -> OptionButton:
	var box := OptionButton.new()
	box.position = at
	box.size = Vector2(360, 40)
	box.add_theme_font_size_override("font_size", 18)
	for item in items:
		box.add_item(str(item))
	parent.add_child(box)
	return box


func _button(parent: Node, text: String, at: Vector2, dimensions: Vector2, color: Color, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = at
	button.size = dimensions
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_stylebox_override("normal", _style(color, color.lightened(0.4)))
	button.add_theme_stylebox_override("hover", _style(color.lightened(0.2), Color.WHITE))
	button.add_theme_stylebox_override("pressed", _style(color.darkened(0.2), Color.WHITE))
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _style(background: Color, border: Color, width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(10)
	return style
