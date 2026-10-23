extends SpaceFighter
class_name PlanetGuardian

const PlanetFacts = preload("res://scenes/star_brawl/planet_facts.gd")
const PARTS := "res://assets/star_brawl/bosses/parts/%s.png"

# Kenney Monster Builder parts are assembled into a different alien for each orbit.
# The bodies, limbs, faces and head details are downloaded CC0 artwork.
const DESIGNS := [
	{"body": "greenC", "arms": "greenA", "legs": "greenA", "eye": "eye_angry_green", "eyes": 1, "mouth": "mouthG", "detail": "detail_green_antenna_large"},
	{"body": "redF", "arms": "yellowC", "legs": "redD", "eye": "eye_angry_red", "eyes": 2, "mouth": "mouthJ", "detail": "detail_red_horn_large"},
	{"body": "blueE", "arms": "blueB", "legs": "blueC", "eye": "eye_psycho_light", "eyes": 3, "mouth": "mouthH", "detail": "detail_blue_horn_small"},
	{"body": "whiteD", "arms": "blueD", "legs": "whiteB", "eye": "eye_human_blue", "eyes": 2, "mouth": "mouthF", "detail": "detail_white_horn_large"},
	{"body": "blueF", "arms": "whiteE", "legs": "blueD", "eye": "eye_angry_blue", "eyes": 1, "mouth": "mouthF", "detail": "detail_white_ear_round"},
	{"body": "redB", "arms": "redD", "legs": "yellowE", "eye": "eye_angry_red", "eyes": 2, "mouth": "mouthJ", "detail": "detail_yellow_horn_large"},
	{"body": "greenA", "arms": "greenE", "legs": "blueE", "eye": "eye_angry_green", "eyes": 2, "mouth": "mouthF", "detail": "detail_green_antenna_small"},
	{"body": "whiteB", "arms": "blueC", "legs": "whiteC", "eye": "eye_psycho_light", "eyes": 1, "mouth": "mouthD", "detail": "detail_blue_antenna_large"},
	{"body": "darkE", "arms": "darkB", "legs": "darkE", "eye": "eye_red", "eyes": 2, "mouth": "mouthF", "detail": "detail_dark_horn_large"},
	{"body": "yellowF", "arms": "whiteD", "legs": "yellowC", "eye": "eye_angry_red", "eyes": 3, "mouth": "mouthJ", "detail": "detail_yellow_antenna_large"}
]

var guardian_index := 0
var character_root: Node2D
var left_arm: Node2D
var right_arm: Node2D
var left_leg: Node2D
var right_leg: Node2D
var draw_timer := 0.0


func configure_guardian(index: int) -> void:
	guardian_index = clampi(index, 0, PlanetFacts.DATA.size() - 1)
	scale = Vector2.ONE * (1.25 + guardian_index * 0.045)
	hit_radius = 75.0 + guardian_index * 2.3
	attack_interval = maxf(0.23, 0.56 - guardian_index * 0.035)
	blast_interval = maxf(0.50, 1.05 - guardian_index * 0.058)
	dash_interval = maxf(1.30, 2.25 - guardian_index * 0.10)
	if is_inside_tree() and is_instance_valid(character_root):
		_build_character()


func _ready() -> void:
	super._ready()
	sprite.visible = false
	var collision := get_child(0) as CollisionShape2D
	(collision.shape as RectangleShape2D).size = Vector2(48, 70)
	character_root = Node2D.new()
	character_root.name = "DownloadedBossCharacter"
	add_child(character_root)
	_build_character()


func _build_character() -> void:
	for child in character_root.get_children():
		child.queue_free()
	var design: Dictionary = DESIGNS[guardian_index]
	var body_name := "body_%s" % design["body"]
	var body_texture := load(PARTS % body_name) as Texture2D
	var body_size := body_texture.get_size()
	var body_center := Vector2(0, -144)
	character_root.scale = Vector2.ONE * 0.50
	var shoulder_x := body_size.x * 0.43
	var hip_x := body_size.x * 0.23
	left_leg = _limb("leg_%s" % design["legs"], Vector2(-hip_x, -44), true)
	right_leg = _limb("leg_%s" % design["legs"], Vector2(hip_x, -44), false)
	left_arm = _limb("arm_%s" % design["arms"], Vector2(-shoulder_x, -160), true)
	right_arm = _limb("arm_%s" % design["arms"], Vector2(shoulder_x, -160), false)
	_make_part(body_name, body_center, character_root)
	var eye_y := body_center.y - minf(34.0, body_size.y * 0.14)
	var eye_count := int(design["eyes"])
	var eye_gap := minf(44.0, body_size.x * (0.30 if eye_count == 3 else 0.22))
	for index in eye_count:
		var eye_x := (index - (eye_count - 1) * 0.5) * eye_gap * (1.40 if eye_count == 2 else 1.0)
		var eye := _make_part(str(design["eye"]), Vector2(eye_x, eye_y - (9.0 if eye_count == 3 and index == 1 else 0.0)), character_root)
		eye.scale = Vector2.ONE * (0.55 if eye_count == 3 else 0.88)
	var mouth := _make_part(str(design["mouth"]), body_center + Vector2(0, minf(46.0, body_size.y * 0.22)), character_root)
	mouth.scale = Vector2.ONE * (0.83 if eye_count == 3 else 1.0)
	for side in [-1, 1]:
		var detail := _make_part(str(design["detail"]), body_center + Vector2(side * body_size.x * 0.31, -body_size.y * 0.47), character_root)
		detail.flip_h = side > 0
	if guardian_index == 9:
		var crown := _make_part("detail_white_horn_small", body_center + Vector2(0, -body_size.y * 0.52), character_root)
		crown.scale = Vector2.ONE * 1.15


func _limb(part_name: String, at: Vector2, mirrored: bool) -> Node2D:
	var pivot := Node2D.new()
	pivot.position = at
	character_root.add_child(pivot)
	var art := _make_part(part_name, Vector2(-12 if mirrored else 12, 44), pivot)
	art.flip_h = mirrored
	return pivot


func _make_part(part_name: String, at: Vector2, parent: Node2D) -> Sprite2D:
	var art := Sprite2D.new()
	art.name = part_name
	art.texture = load(PARTS % part_name) as Texture2D
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	art.position = at
	parent.add_child(art)
	return art


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not is_instance_valid(character_root):
		return
	var stride := clampf(absf(velocity.x) / maxf(1.0, move_speed), 0.0, 1.0)
	var step := sin(animation_clock * 12.0) * stride
	character_root.scale.x = 0.50 * facing
	character_root.position.y = sin(animation_clock * 3.2) * 1.5 - (3.0 if not is_on_floor() else 0.0)
	character_root.rotation = facing * 0.10 if dash_timer > 0.0 else facing * 0.055 if attack_anim > 0.0 else 0.0
	left_leg.rotation = step * 0.22
	right_leg.rotation = -step * 0.22
	left_arm.rotation = -step * 0.10
	right_arm.rotation = step * 0.10 - (0.55 if attack_anim > 0.0 or blast_anim > 0.0 else 0.0)
	character_root.modulate.a = 0.55 if invulnerable > 0.0 and int(animation_clock * 18.0) % 2 == 0 else 1.0
	draw_timer -= delta
	if draw_timer <= 0.0:
		draw_timer = 0.12
		queue_redraw()


func _draw() -> void:
	var fact: Dictionary = PlanetFacts.at(guardian_index)
	var danger: Color = fact["danger"]
	draw_circle(Vector2(0, 35), 42, Color(0.02, 0.03, 0.10, 0.28))
	if health < max_health * 0.45:
		draw_arc(Vector2(0, -49), 59, -PI * 0.4, PI * 0.5, 34, Color(danger, 0.75), 4)
	if invulnerable > 0.0:
		draw_arc(Vector2(0, -49), 60, 0, TAU, 48, Color(1, 1, 1, 0.30), 2)
	super._draw()
