extends Control
## AI vs AI setup screen.
##   AI 1 (Blue) / AI 2 (Red): decision algorithm + search (Rotate all 7 or one fixed)
##   Arena: planet
##   [Start Match]  [Run 10 Matches]  [Back]

signal start_requested(config: Dictionary)
signal batch_requested(config: Dictionary, count: int)
signal back_requested

const Pathfinder = preload("res://scripts/utils/modular_pathfinder.gd")
const DECISIONS := ["minimax_ab", "minimax", "mcts"]
const DECISION_LABELS := ["Minimax + alpha-beta", "Minimax", "MCTS"]
const BLUE := Color("5fb4ff")
const RED := Color("ff6f7d")

var dropdowns := {}
var backend_label: Label


func _ready() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_title("AI  vs  AI", Vector2(0, 34), 54, Color("f5fbff"))
	_title("Every algorithm is used in every match. Choose how each AI decides and searches.", Vector2(0, 104), 18, Color("9be7e7"))
	_side(Vector2(150, 160), "AI 1  (BLUE)", BLUE, "blue", 0)   # default Minimax + alpha-beta
	_side(Vector2(690, 160), "AI 2  (RED)", RED, "red", 2)      # default MCTS
	_title("ARENA / PLANET", Vector2(0, 440), 18, Color("e0f9ff"))
	dropdowns["planet"] = _dropdown(self, Vector2(440, 470), [])
	backend_label = _title("", Vector2(0, 527), 16, Color("f6da88"))
	_button("START MATCH", Vector2(250, 575), Vector2(240, 62), Color("087f96"), func() -> void: start_requested.emit(get_config()))
	_button("RUN 10 MATCHES", Vector2(505, 575), Vector2(260, 62), Color("3b4f9a"), func() -> void: batch_requested.emit(get_config(), 10))
	_button("BACK", Vector2(780, 575), Vector2(240, 62), Color("202d56"), func() -> void: back_requested.emit())


func _draw() -> void:
	for row in 36:
		draw_rect(Rect2(0, row * 20, 1280, 21), Color("111b43").lerp(Color("080b22"), row / 35.0))


func set_planets(planets: Array) -> void:
	var box: OptionButton = dropdowns["planet"]
	box.clear()
	for index in planets.size():
		box.add_item("%02d  %s" % [index + 1, planets[index]["name"]])


func set_backend(online: bool) -> void:
	backend_label.text = "Python AI server: ONLINE" if online else "Python AI server: OFFLINE  (start launch_game_with_ai.bat; the AIs will use simple fallbacks)"


## The choices on this screen.
func get_config() -> Dictionary:
	var config := {"planet": maxi(0, (dropdowns["planet"] as OptionButton).selected)}
	for side in ["blue", "red"]:
		config[side + "_decision"] = DECISIONS[(dropdowns[side + "_decision"] as OptionButton).selected]
		var search_index := (dropdowns[side + "_search"] as OptionButton).selected
		config[side + "_search"] = "rotate" if search_index == 0 else Pathfinder.ORDER[search_index - 1]
	return config


func _side(at: Vector2, title: String, color: Color, key: String, default_decision: int) -> void:
	var panel := Panel.new()
	panel.position = at
	panel.size = Vector2(440, 250)
	panel.add_theme_stylebox_override("panel", _style(Color("0c193a"), color, 3))
	add_child(panel)
	var heading := _label(panel, title, Vector2(0, 16), Vector2(440, 36), 26, color)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(panel, "Decision algorithm (combat)", Vector2(40, 66), Vector2(360, 24), 16, Color("cce0f4"))
	dropdowns[key + "_decision"] = _dropdown(panel, Vector2(40, 94), DECISION_LABELS)
	(dropdowns[key + "_decision"] as OptionButton).select(default_decision)
	_label(panel, "Search algorithm (movement)", Vector2(40, 146), Vector2(360, 24), 16, Color("cce0f4"))
	var searches: Array = ["Rotate all 7 (every 10 s)"]
	for algorithm in Pathfinder.ORDER:
		searches.append(Pathfinder.NAMES[algorithm])
	dropdowns[key + "_search"] = _dropdown(panel, Vector2(40, 174), searches)


func _title(text: String, at: Vector2, font_size: int, color: Color) -> Label:
	var label := _label(self, text, at, Vector2(1280, font_size + 16), font_size, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _label(parent: Node, text: String, at: Vector2, dimensions: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = dimensions
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
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


func _button(text: String, at: Vector2, dimensions: Vector2, color: Color, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.position = at
	button.size = dimensions
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_stylebox_override("normal", _style(color, color.lightened(0.4)))
	button.add_theme_stylebox_override("hover", _style(color.lightened(0.2), Color.WHITE))
	button.add_theme_stylebox_override("pressed", _style(color.darkened(0.2), Color.WHITE))
	button.pressed.connect(action)
	add_child(button)


func _style(background: Color, border: Color, width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(10)
	return style
