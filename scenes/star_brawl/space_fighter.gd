extends CharacterBody2D
class_name SpaceFighter

signal strike_requested(fighter: SpaceFighter, kind: String)
signal knocked_out(fighter: SpaceFighter)

const SPRITES := "res://assets/star_brawl/fighters/character_%s_%s.png"
const PilotAvatarScript = preload("res://scenes/star_brawl/pilot_avatar.gd")

var arena: Node2D
var is_player := false
var color_name := "green"
var pilot_variant := 0
var max_health := 100.0
var health := 100.0
var punch_damage := 12.0
var move_speed := 260.0
var hit_radius := 34.0
var attack_interval := 0.42
var blast_interval := 0.85
var dash_interval := 2.1
var gravity_scale := 1.0
var facing := 1
var desired_direction := 0.0
var jumps_left := 2
var attack_cooldown := 0.0
var blast_cooldown := 0.0
var dash_cooldown := 0.0
var dash_timer := 0.0
var invulnerable := 0.0
var slow_timer := 0.0
var knocked_out_state := false
var sprite: Sprite2D
var pilot_art: Node2D
var pose := ""
var animation_clock := 0.0
var pose_textures: Dictionary = {}
var attack_anim := 0.0
var blast_anim := 0.0
var land_anim := 0.0
var effect_visible := false


func configure(p_arena: Node2D, p_is_player: bool, p_color: String, p_health: float) -> void:
	arena = p_arena
	is_player = p_is_player
	color_name = p_color
	max_health = p_health
	health = p_health


func _ready() -> void:
	collision_layer = 4 if is_player else 2
	collision_mask = 1
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(38, 56)
	collision.shape = rectangle
	add_child(collision)
	sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * 0.64
	add_child(sprite)
	_set_pose("idle")
	if is_player:
		sprite.visible = false
		pilot_art = PilotAvatarScript.new() as Node2D
		pilot_art.scale = Vector2.ONE * 0.9
		add_child(pilot_art)
		pilot_art.call("set_visual", pilot_variant, "idle", facing, 0.0)


func _physics_process(delta: float) -> void:
	if knocked_out_state:
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	blast_cooldown = maxf(0.0, blast_cooldown - delta)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	dash_timer = maxf(0.0, dash_timer - delta)
	attack_anim = maxf(0.0, attack_anim - delta)
	blast_anim = maxf(0.0, blast_anim - delta)
	land_anim = maxf(0.0, land_anim - delta)
	invulnerable = maxf(0.0, invulnerable - delta)
	slow_timer = maxf(0.0, slow_timer - delta)
	animation_clock += delta
	if is_on_floor():
		jumps_left = 2
	velocity.y += 1400.0 * gravity_scale * delta
	if dash_timer > 0.0:
		velocity.x = facing * 780.0
	elif arena != null and arena.is_fighting():
		var speed_factor := 0.45 if slow_timer > 0.0 else 1.0
		velocity.x = move_toward(velocity.x, desired_direction * move_speed * speed_factor, 2200.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 2200.0 * delta)
	if absf(desired_direction) > 0.15:
		facing = 1 if desired_direction > 0.0 else -1
	var airborne := not is_on_floor()
	move_and_slide()
	if airborne and is_on_floor():
		land_anim = 0.17
		queue_redraw()
	position.x = clampf(position.x, 42.0, arena.get_arena_width() - 42.0)
	if position.y > 770.0:
		position = Vector2(180, 580) if is_player else Vector2(arena.get_arena_width() - 230.0, 580)
		velocity = Vector2.ZERO
		take_damage(14.0, -facing)
	_update_pose()


func _update_pose() -> void:
	if invulnerable > 0.32:
		_set_pose("hit")
	elif attack_anim > 0.0 or blast_anim > 0.0:
		_set_pose("walk_b")
	elif not is_on_floor():
		_set_pose("jump")
	elif absf(velocity.x) > 35.0:
		_set_pose("walk_a" if int(animation_clock * 11.0) % 2 == 0 else "walk_b")
	else:
		_set_pose("idle")
	sprite.flip_h = facing < 0
	sprite.modulate.a = 0.5 if invulnerable > 0.0 and int(animation_clock * 18.0) % 2 == 0 else 1.0
	var stretch := Vector2.ONE
	var lean := 0.0
	var offset := Vector2.ZERO
	if dash_timer > 0.0:
		stretch = Vector2(1.22, 0.82)
		lean = facing * 0.16
		offset.x = facing * 6.0
	elif attack_anim > 0.0:
		stretch = Vector2(1.14, 0.92)
		lean = facing * 0.12
		offset.x = facing * 5.0
	elif blast_anim > 0.0:
		stretch = Vector2(0.92, 1.07)
		offset.x = -facing * 4.0
	elif land_anim > 0.0:
		stretch = Vector2(1.12, 0.83)
		offset.y = 3.0
	elif not is_on_floor():
		stretch = Vector2(0.94, 1.08) if velocity.y < 0.0 else Vector2(1.08, 0.94)
		lean = facing * 0.06
	elif absf(velocity.x) > 35.0:
		offset.y = absf(sin(animation_clock * 18.0)) * -2.5
		lean = facing * 0.035
	else:
		offset.y = sin(animation_clock * 3.1) * 1.5
		stretch = Vector2.ONE * (1.0 + sin(animation_clock * 3.1) * 0.016)
	sprite.scale = Vector2(0.64 * stretch.x, 0.64 * stretch.y)
	sprite.position = offset
	sprite.rotation = lean
	if is_instance_valid(pilot_art):
		var motion := "idle"
		if invulnerable > 0.32:
			motion = "hurt"
		elif dash_timer > 0.0:
			motion = "dash"
		elif attack_anim > 0.0:
			motion = "attack"
		elif blast_anim > 0.0:
			motion = "blast"
		elif land_anim > 0.0:
			motion = "land"
		elif not is_on_floor():
			motion = "jump" if velocity.y < 0.0 else "fall"
		elif absf(velocity.x) > 35.0:
			motion = "run"
		pilot_art.call("set_visual", pilot_variant, motion, facing, animation_clock)
		pilot_art.position = offset
		pilot_art.modulate.a = sprite.modulate.a
	var effect_active := attack_anim > 0.0 or blast_anim > 0.0 or dash_timer > 0.0
	if effect_active or effect_visible != effect_active:
		queue_redraw()
	effect_visible = effect_active


func _draw() -> void:
	if dash_timer > 0.0:
		for streak in 3:
			var x := -facing * (21.0 + streak * 15.0)
			draw_line(Vector2(x, -17 + streak * 10), Vector2(x - facing * 22, -17 + streak * 10), Color("d4fbff", 0.65 - streak * 0.14), 3.0)
	if attack_anim > 0.0:
		draw_arc(Vector2(facing * 28, -5), 24, -1.1 if facing > 0 else 2.0, 1.1 if facing > 0 else 4.2, 16, Color("efffff", attack_anim * 3.0), 4.0)
	if blast_anim > 0.0:
		draw_circle(Vector2(facing * 44, -7), 7.0 + (0.22 - blast_anim) * 25.0, Color("83fff1", blast_anim * 2.8))


func _set_pose(next_pose: String) -> void:
	if pose == next_pose:
		return
	pose = next_pose
	if not pose_textures.has(next_pose):
		pose_textures[next_pose] = load(SPRITES % [color_name, next_pose]) as Texture2D
	sprite.texture = pose_textures[next_pose]


func jump() -> void:
	if not arena.is_fighting() or jumps_left <= 0 or knocked_out_state:
		return
	velocity.y = -710.0
	jumps_left -= 1
	arena.play_sound("jump")


func punch() -> void:
	if not arena.is_fighting() or attack_cooldown > 0.0 or knocked_out_state:
		return
	attack_cooldown = attack_interval
	attack_anim = 0.20
	strike_requested.emit(self, "punch")


func blast() -> void:
	if not arena.is_fighting() or blast_cooldown > 0.0 or knocked_out_state:
		return
	blast_cooldown = blast_interval
	blast_anim = 0.22
	strike_requested.emit(self, "blast")


func dash() -> void:
	if not arena.is_fighting() or dash_cooldown > 0.0 or knocked_out_state:
		return
	dash_cooldown = dash_interval
	dash_timer = 0.18
	invulnerable = maxf(invulnerable, 0.18)
	arena.play_sound("magic")


func take_damage(amount: float, push_direction: int) -> void:
	if invulnerable > 0.0 or knocked_out_state:
		return
	health = maxf(0.0, health - amount)
	invulnerable = 0.4
	velocity = Vector2(push_direction * 300.0, -220.0)
	arena.play_sound("hurt")
	if health <= 0.0:
		knocked_out_state = true
		_set_pose("hit")
		knocked_out.emit(self)
