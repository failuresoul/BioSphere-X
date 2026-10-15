extends CharacterBody2D
class_name Player
## Astronaut Player Controller for BioSphere-X.
## Handles physics movement with normalized diagonal motion, acceleration/deceleration,
## and maintains clean separation between movement, health, interaction, and visuals.

signal player_died()
signal player_damaged(amount: float, current_health: float, max_health: float)
signal player_healed(amount: float, current_health: float, max_health: float)
signal player_attacked(projectile: Node2D, direction: Vector2)

@export_group("Movement")
@export var max_speed: float = 240.0
@export var acceleration: float = 1400.0
@export var friction: float = 1600.0

@export_group("Combat")
@export var attack_enabled: bool = true

@export_group("Camera")
@export var camera_zoom: Vector2 = Vector2(2.5, 2.5)
@export var camera_smoothing_enabled: bool = true
@export var camera_smoothing_speed: float = 6.0

@onready var visual: Node2D = $Visual
@onready var health_component: Node = $HealthComponent
@onready var interaction_component: Area2D = $InteractionComponent
@onready var weapon_component: Node2D = $WeaponComponent
@onready var camera: Camera2D = $Camera2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D



func _ready() -> void:
	add_to_group("player")
	_setup_camera()
	_connect_component_signals()


func _setup_camera() -> void:
	if camera:
		camera.zoom = camera_zoom
		camera.position_smoothing_enabled = camera_smoothing_enabled
		camera.position_smoothing_speed = camera_smoothing_speed


func _connect_component_signals() -> void:
	var hc := _get_health_component()
	if hc:
		if hc.has_signal("damaged") and not hc.is_connected("damaged", _on_health_damaged):
			hc.connect("damaged", _on_health_damaged)
		if hc.has_signal("healed") and not hc.is_connected("healed", _on_health_healed):
			hc.connect("healed", _on_health_healed)
		if hc.has_signal("died") and not hc.is_connected("died", _on_health_died):
			hc.connect("died", _on_health_died)
	
	var gs := get_node_or_null("/root/GameState")
	if gs:
		gs.call("set_health", get_current_health(), get_max_health())
		if gs.has_signal("health_changed") and not gs.is_connected("health_changed", _on_game_state_health_changed):
			gs.connect("health_changed", _on_game_state_health_changed)


var is_dead: bool = false


func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		return
	
	var input_vector := _get_input_vector()
	_apply_movement(input_vector, delta)
	move_and_slide()
	
	var vis := _get_visual()
	if vis and vis.has_method("update_motion"):
		vis.call("update_motion", velocity, delta)


func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return
	
	# Primary attack input: Mouse Left Click or Attack Key (J, F, Ctrl, or 'attack' action)
	if attack_enabled:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var mouse_pos := get_global_mouse_position()
			var aim_dir := (mouse_pos - global_position).normalized()
			attack(aim_dir)
			get_viewport().set_input_as_handled()
			return
		elif event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_J or event.keycode == KEY_F or event.keycode == KEY_CTRL:
				attack()
				get_viewport().set_input_as_handled()
				return
		elif InputMap.has_action("attack") and event.is_action_pressed("attack"):
			attack()
			get_viewport().set_input_as_handled()
			return
	
	# Interaction input: E, Space, or 'interact' action
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E or event.keycode == KEY_SPACE:
			try_interact()
	elif InputMap.has_action("interact") and event.is_action_pressed("interact"):
		try_interact()



# ---------------------------------------------------------------------------
# Movement Logic
# ---------------------------------------------------------------------------
func _get_input_vector() -> Vector2:
	var dir := Vector2.ZERO
	
	# Primary checks: standard UI actions (built-in Godot) and direct keys (WASD + Arrows)
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT) or Input.is_action_pressed("ui_left"):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT) or Input.is_action_pressed("ui_right"):
		dir.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) or Input.is_action_pressed("ui_up"):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN) or Input.is_action_pressed("ui_down"):
		dir.y += 1.0
	
	# Optional custom mapped actions if defined
	if InputMap.has_action("move_left") and Input.is_action_pressed("move_left"):
		dir.x -= 1.0
	if InputMap.has_action("move_right") and Input.is_action_pressed("move_right"):
		dir.x += 1.0
	if InputMap.has_action("move_up") and Input.is_action_pressed("move_up"):
		dir.y -= 1.0
	if InputMap.has_action("move_down") and Input.is_action_pressed("move_down"):
		dir.y += 1.0
	
	# Strict normalization guarantees diagonal movement is not faster than straight movement
	return dir.normalized()


func _apply_movement(input_vector: Vector2, delta: float) -> void:
	if input_vector != Vector2.ZERO:
		var target_velocity := input_vector * max_speed
		velocity = velocity.move_toward(target_velocity, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)


# ---------------------------------------------------------------------------
# Component Helper Getters
# ---------------------------------------------------------------------------
func _get_health_component() -> Node:
	if not health_component:
		health_component = get_node_or_null("HealthComponent")
	return health_component


func _get_interaction_component() -> Area2D:
	if not interaction_component:
		interaction_component = get_node_or_null("InteractionComponent") as Area2D
	return interaction_component


func _get_visual() -> Node2D:
	if not visual:
		visual = get_node_or_null("Visual") as Node2D
	return visual


func _get_weapon_component() -> Node2D:
	if not weapon_component:
		weapon_component = get_node_or_null("WeaponComponent") as Node2D
	return weapon_component


# ---------------------------------------------------------------------------
# Public Combat API
# ---------------------------------------------------------------------------
func attack(direction: Vector2 = Vector2.ZERO) -> bool:
	if is_dead or not attack_enabled:
		return false
	
	var aim_dir := direction
	if aim_dir == Vector2.ZERO:
		var mouse_pos := get_global_mouse_position()
		var to_mouse := mouse_pos - global_position
		if to_mouse.length() > 8.0:
			aim_dir = to_mouse.normalized()
		else:
			aim_dir = get_facing_vector()
	
	var wc: Node2D = _get_weapon_component()
	if not wc:
		return false
	
	var spawn_pos := global_position + aim_dir * 14.0
	var proj: Node2D = wc.attack(aim_dir, spawn_pos, self)
	if proj:
		var vis := _get_visual()
		if vis and vis.has_method("play_attack_recoil"):
			vis.call("play_attack_recoil", aim_dir)
		player_attacked.emit(proj, aim_dir)
		return true
	
	return false



# ---------------------------------------------------------------------------
# Public Health & Interaction API
# ---------------------------------------------------------------------------
func apply_damage(damage_data: RefCounted) -> bool:
	if not damage_data or is_dead:
		return false
	var force: float = float(damage_data.get("knockback_force"))
	if force > 0.0:
		var dir: Vector2 = damage_data.get("knockback_direction")
		velocity += dir * force
	return take_damage(float(damage_data.get("amount")), damage_data.get("source"))


func take_damage(amount: float, source: Node = null) -> bool:
	var hc := _get_health_component()
	if hc and hc.has_method("damage"):
		return hc.call("damage", amount, source)
	return false


func heal(amount: float) -> void:
	var hc := _get_health_component()
	if hc and hc.has_method("heal"):
		hc.call("heal", amount)


func get_current_health() -> float:
	var hc := _get_health_component()
	if hc and "current_health" in hc:
		return hc.get("current_health")
	return 0.0


func get_max_health() -> float:
	var hc := _get_health_component()
	if hc and "max_health" in hc:
		return hc.get("max_health")
	return 0.0


func try_interact() -> bool:
	var ic := _get_interaction_component()
	if ic and ic.has_method("try_interact"):
		return ic.call("try_interact", self)
	return false


func get_animation_state() -> String:
	var vis := _get_visual()
	if vis and vis.has_method("get_animation_state"):
		return vis.call("get_animation_state")
	return "idle"


func get_facing_direction() -> String:
	var vis := _get_visual()
	if vis and vis.has_method("get_direction_name"):
		return vis.call("get_direction_name")
	return "down"


func get_facing_vector() -> Vector2:
	var vis := _get_visual()
	if vis and "facing_vector" in vis:
		return vis.get("facing_vector")
	return Vector2.DOWN


# ---------------------------------------------------------------------------
# Component Event Callbacks
# ---------------------------------------------------------------------------
func _on_health_damaged(amount: float, _source: Node = null) -> void:
	var vis := _get_visual()
	if vis and vis.has_method("play_damage_flash"):
		vis.call("play_damage_flash")
	var cur := get_current_health()
	var mx := get_max_health()
	player_damaged.emit(amount, cur, mx)


func _on_health_healed(amount: float) -> void:
	var cur := get_current_health()
	var mx := get_max_health()
	player_healed.emit(amount, cur, mx)


func _on_health_died() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	print("BioSphere-X: Astronaut perished.")
	
	var vis := _get_visual()
	if vis and vis.has_method("play_death"):
		vis.call("play_death")
	
	var gs := get_node_or_null("/root/GameState")
	if gs and gs.has_method("trigger_game_over"):
		gs.call("trigger_game_over")
	
	player_died.emit()


func _on_game_state_health_changed(current: float, _max_hp: float) -> void:
	var hc := _get_health_component()
	if hc and "current_health" in hc:
		if absf(float(hc.get("current_health")) - current) > 0.5:
			hc.set("current_health", current)
			if current <= 0.0 and hc.has_signal("died"):
				hc.emit_signal("died")
