extends SpaceFighter

var species := 0
var hover_clock := 0.0
var redraw_timer := 0.0


func _ready() -> void:
	super._ready()
	sprite.visible = false
	scale = Vector2.ONE * 0.72
	move_speed = 150.0 + species * 18.0
	punch_damage = 6.0 + species


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	hover_clock += delta
	redraw_timer -= delta
	if redraw_timer <= 0.0:
		redraw_timer = 0.10
		queue_redraw()


func _update_pose() -> void:
	pass


func _draw() -> void:
	var bob := sin(hover_clock * 5.0) * 3.0
	var body := Color("bb6dff") if species == 0 else (Color("ff9b65") if species == 1 else Color("9be884"))
	var dark := body.darkened(0.48)
	var eye := Color("8af8ff") if species != 1 else Color("fff2a1")
	draw_circle(Vector2(0, 33), 36, Color(0.02, 0.03, 0.10, 0.35))
	if species == 0:
		# Four-legged crawler with antennae.
		for side in [-1, 1]:
			draw_line(Vector2(side * 20, 6 + bob), Vector2(side * 37, 28), dark, 9)
			draw_line(Vector2(side * 8, 16 + bob), Vector2(side * 24, 34), dark, 8)
			draw_line(Vector2(side * 15, -24 + bob), Vector2(side * 27, -44 + bob), body, 5)
			draw_circle(Vector2(side * 27, -44 + bob), 5, eye)
		draw_circle(Vector2(0, -4 + bob), 34, dark)
		draw_circle(Vector2(0, -10 + bob), 29, body)
		draw_circle(Vector2(-11, -14 + bob), 7, eye)
		draw_circle(Vector2(11, -14 + bob), 7, eye)
		draw_circle(Vector2(-10, -13 + bob), 3, Color("123555"))
		draw_circle(Vector2(12, -13 + bob), 3, Color("123555"))
	elif species == 1:
		# Floating crystalline sentinel.
		var shell := PackedVector2Array([Vector2(0, -50 + bob), Vector2(32, -18 + bob), Vector2(27, 18 + bob), Vector2(0, 31 + bob), Vector2(-27, 18 + bob), Vector2(-32, -18 + bob)])
		draw_colored_polygon(shell, dark)
		var core := PackedVector2Array([Vector2(0, -42 + bob), Vector2(23, -15 + bob), Vector2(18, 13 + bob), Vector2(0, 25 + bob), Vector2(-18, 13 + bob), Vector2(-23, -15 + bob)])
		draw_colored_polygon(core, body)
		draw_circle(Vector2(0, -10 + bob), 12, eye)
		draw_circle(Vector2(0, -10 + bob), 6, Color("2b304e"))
		draw_line(Vector2(-27, -5 + bob), Vector2(-48, 9 + bob), body, 8)
		draw_line(Vector2(27, -5 + bob), Vector2(48, 9 + bob), body, 8)
	else:
		# Green sporeling with three glowing eyes and soft tendrils.
		for side in [-1, 0, 1]:
			draw_line(Vector2(side * 18, 8 + bob), Vector2(side * 23, 34), dark, 8)
		draw_circle(Vector2(0, -7 + bob), 34, dark)
		draw_circle(Vector2(0, -13 + bob), 29, body)
		for side in [-1, 0, 1]:
			draw_circle(Vector2(side * 15, -17 + bob), 6, eye)
			draw_circle(Vector2(side * 15, -16 + bob), 2, Color("284b55"))
		draw_circle(Vector2(-24, -36 + bob), 9, body.lightened(0.18))
		draw_circle(Vector2(22, -39 + bob), 7, body.lightened(0.18))
	if invulnerable > 0.0:
		draw_arc(Vector2(0, -9 + bob), 42, 0, TAU, 36, Color(1, 1, 1, 0.65), 2.0)
	draw_rect(Rect2(-30, -59, 60, 5), Color("192c45"))
	draw_rect(Rect2(-30, -59, 60.0 * health / max_health, 5), Color("8df7be"))
