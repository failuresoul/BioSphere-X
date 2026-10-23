extends Control

signal action_requested(action: String)

const PlanetFacts = preload("res://scenes/star_brawl/planet_facts.gd")
const PlanetPortraitScript = preload("res://scenes/star_brawl/planet_portrait.gd")

var eyebrow: Label
var heading: Label
var description: Label
var detail: Label
var planet_art: Node2D
var action_buttons: VBoxContainer


func _ready() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()


func _draw() -> void:
	for row in 9:
		var ratio := float(row) / 8.0
		draw_rect(Rect2(0, row * 80, 1280, 81), Color("1b2858").lerp(Color("354b86"), ratio))
	var rng := RandomNumberGenerator.new()
	rng.seed = 9817
	for index in 66:
		var star := Vector2(rng.randf_range(0, 1280), rng.randf_range(0, 700))
		draw_circle(star, 1.8 if index % 11 == 0 else 1.0, Color(0.88, 0.95, 1.0, 0.62))
	draw_rect(Rect2(110, 76, 1060, 568), Color("0d1b44"))
	draw_rect(Rect2(110, 76, 1060, 568), Color("80dfe9"), false, 2.0)
	draw_rect(Rect2(110, 76, 1060, 9), Color("68dce6"))
	draw_circle(Vector2(365, 355), 213, Color(0.31, 0.73, 0.82, 0.11))
	draw_arc(Vector2(365, 355), 213, -0.65, 4.85, 80, Color("77dbe6"), 2.0)
	draw_line(Vector2(590, 113), Vector2(590, 607), Color("41638d"), 2.0)


func _build_ui() -> void:
	planet_art = PlanetPortraitScript.new() as Node2D
	planet_art.position = Vector2(365, 355)
	add_child(planet_art)
	eyebrow = _text("CHAPTER 01 / 10", Vector2(637, 119), Vector2(490, 32), 18, Color("74e8e9"))
	heading = _text("VERDANT NEBULA", Vector2(633, 162), Vector2(505, 105), 43, Color("f3f9ff"))
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description = _text("", Vector2(637, 277), Vector2(485, 85), 20, Color("cad8f2"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail = _text("", Vector2(637, 365), Vector2(485, 53), 17, Color("ffdea1"))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_buttons = VBoxContainer.new()
	action_buttons.position = Vector2(636, 441)
	action_buttons.custom_minimum_size = Vector2(455, 0)
	action_buttons.add_theme_constant_override("separation", 10)
	add_child(action_buttons)
	_text("BIOSPHERE X  /  CAMPAIGN", Vector2(145, 591), Vector2(422, 25), 15, Color("90accd"))


func present(mode: String, stage: Dictionary, info: Dictionary) -> void:
	planet_art.call("set_planet", int(info.get("stage_index", 0)), 132.0)
	for old_button in action_buttons.get_children():
		action_buttons.remove_child(old_button)
		old_button.queue_free()
	var stage_number := int(info.get("stage_index", 0)) + 1
	var stage_count := int(info.get("stage_count", 10))
	match mode:
		"briefing":
			eyebrow.text = "CHAPTER %02d / %02d  •  %s" % [stage_number, stage_count, stage["chapter"]]
			heading.text = str(stage["name"])
			description.text = str(stage["story"])
			detail.text = "%s\nPORTAL → DEFEAT %s  •  BEST %s" % [PlanetFacts.short_fact(stage_number - 1), stage["rival"], _stars(int(info.get("stars", 0)))]
			_add_action("START LEVEL  ›", "start", true)
			_add_action("BACK TO PLANETS", "map")
		"clear":
			eyebrow.text = "CHAPTER %02d / %02d  •  STORY REVEALED" % [stage_number, stage_count]
			heading.text = "THE ARK AWAKENS" if bool(info.get("final", false)) else "CHAPTER CLEAR"
			description.text = str(stage["outro"])
			detail.text = "%s  •  HEALTH %d%%  •  ALIENS %d" % [_stars(int(info.get("stars", 1))), int(info.get("health", 100)), int(info.get("kills", 0))]
			if bool(info.get("first_clear", false)) and not bool(info.get("final", false)):
				_add_action("CHOOSE UPGRADE  ›", "upgrade", true)
			else:
				_add_action("GALAXY MAP  ›", "map", true)
				_add_action("REPLAY LEVEL", "replay")
				if bool(info.get("final", false)):
					_add_action("HOME", "home")
		"upgrade":
			eyebrow.text = "CHAPTER %02d / %02d  •  REWARD" % [stage_number, stage_count]
			heading.text = "SUIT UPGRADE"
			description.text = "The Ark's signal strengthens. Choose one permanent boost for the next chapter."
			detail.text = "YOUR CAMPAIGN IS SAVED AFTER SELECTION"
			_add_action("+25 MAX HEALTH", "armor", true)
			_add_action("+5 STRIKE POWER", "power")
			_add_action("+35 SPEED & PULSE", "flux")
		"defeat":
			eyebrow.text = "CHAPTER %02d / %02d  •  ATTEMPT ENDED" % [stage_number, stage_count]
			heading.text = "TRY AGAIN"
			description.text = "The Ark is still waiting. Return to the portal and face %s." % stage["rival"]
			detail.text = "YOUR UNLOCKED PLANETS AND UPGRADES ARE SAFE"
			_add_action("RETRY LEVEL  ›", "retry", true)
			_add_action("GALAXY MAP", "map")
			_add_action("HOME", "home")
	queue_redraw()


func _stars(count: int) -> String:
	return "★".repeat(clampi(count, 0, 3)) + "☆".repeat(clampi(3 - count, 0, 3))


func _add_action(value: String, action: String, primary: bool = false) -> void:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(455, 52)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color("f4ffff"))
	button.add_theme_stylebox_override("normal", _style(Color("14758c") if primary else Color("263962"), Color("7ce9ee") if primary else Color("7e9ac5")))
	button.add_theme_stylebox_override("hover", _style(Color("2195aa") if primary else Color("405889"), Color.WHITE))
	button.add_theme_stylebox_override("pressed", _style(Color("0f596c") if primary else Color("1b2b4e"), Color.WHITE))
	action_buttons.add_child(button)
	button.pressed.connect(func() -> void: action_requested.emit(action))


func _text(value: String, at: Vector2, dimensions: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.position = at
	label.size = dimensions
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.54))
	label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(label)
	return label


func _style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	return style
