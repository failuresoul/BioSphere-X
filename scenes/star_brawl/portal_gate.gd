extends Node2D

var clock := 0.0
var redraw_timer := 0.0


func _ready() -> void:
	z_index = 2
	var label := Label.new()
	label.text = "BOSS PORTAL"
	label.position = Vector2(-78, -139)
	label.size = Vector2(156, 27)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color("efffff"))
	label.add_theme_color_override("font_shadow_color", Color("102856"))
	label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(label)


func _physics_process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	clock += delta
	redraw_timer -= delta
	if redraw_timer <= 0.0:
		redraw_timer = 0.08
		queue_redraw()


func _draw() -> void:
	var center := Vector2(0, -39)
	var pulse := sin(clock * 3.4) * 3.0
	draw_circle(center, 66, Color("3663a4", 0.24))
	draw_circle(center, 53, Color("122a63"))
	draw_circle(center, 44 + pulse, Color("59c8dc", 0.29))
	draw_circle(center, 34 + pulse * 0.5, Color("aee6f0", 0.37))
	draw_arc(center, 59, 0, TAU, 48, Color("b7f9f5"), 5.0)
	draw_arc(center, 69, clock, clock + PI * 1.2, 36, Color("63d8e5", 0.65), 3.0)
	for index in 4:
		var angle := clock * (0.8 if index % 2 == 0 else -0.8) + index * TAU / 4.0
		var sparkle := center + Vector2(cos(angle), sin(angle)) * 50.0
		draw_circle(sparkle, 3.5, Color("f3ffff"))
	draw_rect(Rect2(-55, 24, 110, 16), Color("243b6a"))
	draw_rect(Rect2(-44, 24, 88, 5), Color("a8f4ed"))
