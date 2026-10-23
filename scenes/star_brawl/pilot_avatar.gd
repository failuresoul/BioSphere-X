extends Node2D

const PILOTS := [
	{"name": "COMMANDER ARIA", "role": "THE PATHFINDER", "armor": Color("edf7f3"), "shadow": Color("8eb9c1"), "accent": Color("46ded2"), "skin": Color("d7a47c"), "hair": Color("2b3045")},
	{"name": "CAPTAIN SOL", "role": "THE VANGUARD", "armor": Color("fff0dc"), "shadow": Color("bf9f88"), "accent": Color("ffae67"), "skin": Color("b97455"), "hair": Color("2c2634")},
	{"name": "SCOUT NYX", "role": "THE SHADOW", "armor": Color("eceafa"), "shadow": Color("9d9abb"), "accent": Color("b99cf4"), "skin": Color("8d5c4b"), "hair": Color("1d2637")}
]

var variant := 0
var motion := "idle"
var facing := 1
var clock := 0.0


func set_visual(next_variant: int, next_motion: String = "idle", next_facing: int = 1, next_clock: float = 0.0) -> void:
	variant = clampi(next_variant, 0, PILOTS.size() - 1)
	motion = next_motion
	facing = next_facing
	clock = next_clock
	queue_redraw()


func _draw() -> void:
	var colors: Dictionary = PILOTS[variant]
	var armor: Color = colors["armor"]
	var shade: Color = colors["shadow"]
	var accent: Color = colors["accent"]
	var skin: Color = colors["skin"]
	var hair: Color = colors["hair"]
	var step := sin(clock * 15.0) * 6.0 if motion == "run" else 0.0
	var breath := sin(clock * 3.2) * 0.8 if motion == "idle" else 0.0
	var crouch := 4.0 if motion == "land" else 0.0
	var tuck := 6.0 if motion in ["jump", "fall"] else 0.0
	var lean := 4.0 * facing if motion == "dash" else 0.0
	var body_y := breath + crouch
	# Backpack and legs sit behind the chest plate.
	draw_rect(Rect2(-23 + lean, -11 + body_y, 10, 29), Color("344c68"))
	draw_rect(Rect2(-23 + lean, -8 + body_y, 4, 20), accent)
	for side in [-1, 1]:
		var leg_swing: float = step * float(side)
		var hip := Vector2(side * 7 + lean, 13 + body_y)
		var knee := Vector2(side * 8 + leg_swing * 0.5 + lean, 23 + body_y - tuck * 0.5)
		var boot := Vector2(side * 8 + leg_swing + lean, 30 + body_y - tuck)
		draw_line(hip, knee, shade, 10)
		draw_line(knee, boot, armor, 9)
		draw_rect(Rect2(boot.x - 7, boot.y - 2, 14, 6), Color("2a4059"))
	# One arm swings with the run; the other extends for attacks.
	var back_hand := Vector2(-facing * 18 + lean, 12 + body_y + step * 0.6)
	draw_line(Vector2(-facing * 13 + lean, -3 + body_y), back_hand, shade, 8)
	draw_circle(back_hand, 5, Color("344b67"))
	var hand := Vector2(facing * 20 + lean, 12 + body_y - step * 0.6)
	if motion == "attack":
		hand = Vector2(facing * 35 + lean, -8 + body_y)
	elif motion == "blast":
		hand = Vector2(facing * 28 + lean, -6 + body_y)
	elif motion == "dash":
		hand = Vector2(facing * 6 + lean, 15 + body_y)
	draw_line(Vector2(facing * 13 + lean, -3 + body_y), hand, armor, 9)
	draw_circle(hand, 5, Color("344b67"))
	if motion == "blast":
		draw_rect(Rect2(minf(hand.x - 3, hand.x + 10 * facing), hand.y - 3, 13, 7), Color("263f5c"))
		draw_circle(hand + Vector2(13 * facing, 0), 3, accent)
	# Armored torso, belt and chest light.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14 + lean, -8 + body_y), Vector2(14 + lean, -8 + body_y),
		Vector2(17 + lean, 13 + body_y), Vector2(-17 + lean, 13 + body_y)
	]), Color("304862"))
	draw_rect(Rect2(-12 + lean, -7 + body_y, 24, 17), armor)
	draw_rect(Rect2(-12 + lean, 9 + body_y, 24, 5), shade)
	draw_rect(Rect2(-5 + lean, -2 + body_y, 10, 6), accent)
	draw_rect(Rect2(-3 + lean, 10 + body_y, 6, 3), Color("f9feff"))
	# Transparent helmet visor reveals an unmistakably human face.
	var head := Vector2(lean * 0.6, -23 + body_y)
	draw_circle(head, 20, Color("263d58"))
	draw_circle(head, 17, armor)
	draw_circle(head + Vector2(0, 2), 13, Color("315578"))
	draw_circle(head + Vector2(0, 3), 10, skin)
	draw_arc(head + Vector2(0, -4), 11, PI * 1.1, PI * 1.9, 14, hair, 5)
	if variant == 1:
		draw_line(head + Vector2(-9, -8), head + Vector2(5, -11), hair, 5)
	elif variant == 2:
		draw_line(head + Vector2(-11, -6), head + Vector2(11, -6), hair, 4)
	draw_circle(head + Vector2(-4, 3), 1.4, Color("1a293c"))
	draw_circle(head + Vector2(4, 3), 1.4, Color("1a293c"))
	draw_line(head + Vector2(-2, 8), head + Vector2(2, 8), Color("793f44"), 1.3)
	draw_arc(head, 17, 0.1, PI - 0.1, 20, accent, 3)
	draw_circle(head + Vector2(-7, -10), 2.2, Color(1, 1, 1, 0.75))
	if motion == "hurt":
		draw_circle(head, 19, Color(1, 1, 1, 0.28))
