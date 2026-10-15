extends CharacterBody2D
class_name AlienEnemy
## Reusable Alien Enemy Controller for BioSphere-X.
## Implements a robust state machine (Idle, Patrol, Investigate, Chase, Attack, Dead)
## with distance-based behavior, modular combat, and extensible AI hooks.

signal state_changed(old_state: State, new_state: State)
signal enemy_damaged(amount: float, current_hp: float, max_hp: float)
signal enemy_died(enemy: AlienEnemy)
signal enemy_attacked(target: Node2D, damage: float)

enum State {
	IDLE,
	PATROL,
	INVESTIGATE,
	CHASE,
	ATTACK,
	DEAD
}

@export_group("Identity & Movement")
@export var enemy_name: String = "Xenomorph Stalker"
@export var patrol_speed: float = 75.0
@export var chase_speed: float = 160.0
@export var acceleration: float = 850.0
@export var friction: float = 900.0

@export_group("Detection & Ranges")
@export var detection_range: float = 240.0
@export var lose_interest_range: float = 340.0
@export var attack_range: float = 36.0
@export var patrol_radius: float = 160.0
@export var investigate_duration: float = 3.0

@export_group("Combat")
@export var attack_damage: float = 15.0
@export var attack_cooldown: float = 1.2
@export var attack_windup_time: float = 0.35

# State Variables
var current_state: State = State.IDLE
var spawn_position: Vector2 = Vector2.ZERO
var patrol_target: Vector2 = Vector2.ZERO
var last_known_player_pos: Vector2 = Vector2.ZERO

var _idle_timer: float = 0.0
var _investigate_timer: float = 0.0
var _attack_timer: float = 0.0
var _cooldown_timer: float = 0.0
var _target_player: Node2D = null

@onready var visual: Node2D = $Visual
@onready var health_component: Node = $HealthComponent
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 1 # Physical body on layer 1
	collision_mask = 1  # Blocks with walls, boundaries, and obstacles
	
	spawn_position = global_position
	patrol_target = spawn_position
	_idle_timer = randf_range(1.5, 3.0)
	
	_connect_health_signals()


func _connect_health_signals() -> void:
	if not health_component:
		health_component = get_node_or_null("HealthComponent")
	if health_component:
		if health_component.has_signal("damaged") and not health_component.is_connected("damaged", _on_health_damaged):
			health_component.connect("damaged", _on_health_damaged)
		if health_component.has_signal("died") and not health_component.is_connected("died", _on_health_died):
			health_component.connect("died", _on_health_died)


func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		velocity = Vector2.ZERO
		return
	
	# Update timers
	if _cooldown_timer > 0.0:
		_cooldown_timer = maxf(0.0, _cooldown_timer - delta)
	
	# Locate / validate target player
	_update_target_player()
	
	# Execute state machine behavior
	match current_state:
		State.IDLE:
			_process_idle(delta)
		State.PATROL:
			_process_patrol(delta)
		State.CHASE:
			_process_chase(delta)
		State.INVESTIGATE:
			_process_investigate(delta)
		State.ATTACK:
			_process_attack(delta)
	
	move_and_slide()
	
	# Update visuals
	if visual and visual.has_method("update_motion"):
		visual.call("update_motion", velocity, current_state, delta)


# ---------------------------------------------------------------------------
# State Process Implementations
# ---------------------------------------------------------------------------
func _process_idle(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	
	# Check detection
	if _can_detect_player():
		change_state(State.CHASE)
		return
	
	_idle_timer -= delta
	if _idle_timer <= 0.0:
		_pick_next_patrol_target()
		change_state(State.PATROL)


func _process_patrol(delta: float) -> void:
	# Check detection
	if _can_detect_player():
		change_state(State.CHASE)
		return
	
	var to_target := patrol_target - global_position
	var dist := to_target.length()
	
	if dist <= 16.0:
		_idle_timer = randf_range(1.5, 3.0)
		change_state(State.IDLE)
	else:
		var target_vel := to_target.normalized() * patrol_speed
		velocity = velocity.move_toward(target_vel, acceleration * delta)


func _process_chase(delta: float) -> void:
	if not _is_target_valid():
		change_state(State.INVESTIGATE)
		return
	
	var to_player := _target_player.global_position - global_position
	var dist := to_player.length()
	last_known_player_pos = _target_player.global_position
	
	# Transition to Attack
	if dist <= attack_range:
		if _cooldown_timer <= 0.0:
			change_state(State.ATTACK)
			return
		else:
			# Close-in circling while waiting for cooldown
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
			return
	
	# Check escape / lose interest
	if dist > lose_interest_range:
		change_state(State.INVESTIGATE)
		return
	
	# Chase movement
	var target_vel := to_player.normalized() * chase_speed
	velocity = velocity.move_toward(target_vel, acceleration * delta)


func _process_investigate(delta: float) -> void:
	# If player re-detected, resume chase immediately
	if _can_detect_player():
		change_state(State.CHASE)
		return
	
	var to_last_known := last_known_player_pos - global_position
	var dist := to_last_known.length()
	
	if dist > 16.0:
		var target_vel := to_last_known.normalized() * patrol_speed
		velocity = velocity.move_toward(target_vel, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	
	_investigate_timer -= delta
	if _investigate_timer <= 0.0:
		# Return to patrol or spawn base
		patrol_target = spawn_position
		_idle_timer = randf_range(1.0, 2.5)
		change_state(State.IDLE)


func _process_attack(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, friction * delta * 2.0)
	_attack_timer += delta
	
	# Update visual windup telegraph
	if visual and "attack_windup_ratio" in visual:
		visual.set("attack_windup_ratio", clampf(_attack_timer / attack_windup_time, 0.0, 1.0))
	
	if _attack_timer >= attack_windup_time:
		_execute_attack_strike()
		_cooldown_timer = attack_cooldown
		_attack_timer = 0.0
		if visual and "attack_windup_ratio" in visual:
			visual.set("attack_windup_ratio", 0.0)
		
		# Return to chase or investigate
		if _can_detect_player():
			change_state(State.CHASE)
		else:
			change_state(State.INVESTIGATE)


func _execute_attack_strike() -> void:
	if not _is_target_valid():
		return
	
	var dist := global_position.distance_to(_target_player.global_position)
	if dist <= attack_range * 1.4:
		# Apply damage to player
		if _target_player.has_method("take_damage"):
			_target_player.call("take_damage", attack_damage, self)
		elif _target_player.has_node("HealthComponent"):
			var p_hc = _target_player.get_node("HealthComponent")
			if p_hc.has_method("damage"):
				p_hc.call("damage", attack_damage, self)
		
		enemy_attacked.emit(_target_player, attack_damage)


# ---------------------------------------------------------------------------
# State Transitions & Helpers
# ---------------------------------------------------------------------------
func change_state(new_state: State) -> void:
	if current_state == new_state or current_state == State.DEAD:
		return
	
	var old_state := current_state
	current_state = new_state
	
	match new_state:
		State.IDLE:
			_idle_timer = randf_range(1.5, 3.0)
		State.INVESTIGATE:
			_investigate_timer = investigate_duration
		State.ATTACK:
			_attack_timer = 0.0
		State.DEAD:
			velocity = Vector2.ZERO
			if collision_shape:
				collision_shape.disabled = true
				collision_shape.set_deferred("disabled", true)
			if visual and visual.has_method("play_death"):
				visual.call("play_death")
	
	state_changed.emit(old_state, new_state)


func _pick_next_patrol_target() -> void:
	var angle := randf_range(0, TAU)
	var dist := randf_range(32.0, patrol_radius)
	patrol_target = spawn_position + Vector2.from_angle(angle) * dist


func _update_target_player() -> void:
	if not is_instance_valid(_target_player) or not _target_player.is_inside_tree():
		var players := get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			_target_player = players[0] as Node2D
		else:
			_target_player = null


func _is_target_valid() -> bool:
	if not is_instance_valid(_target_player) or not _target_player.is_inside_tree():
		return false
	if "is_dead" in _target_player and _target_player.get("is_dead"):
		return false
	return true


func _can_detect_player() -> bool:
	if not _is_target_valid():
		return false
	var dist := global_position.distance_to(_target_player.global_position)
	return dist <= detection_range


# ---------------------------------------------------------------------------
# Combat & Public Health API
# ---------------------------------------------------------------------------
func take_damage(amount: float, source: Node = null) -> bool:
	if current_state == State.DEAD:
		return false
	
	if not health_component:
		health_component = get_node_or_null("HealthComponent")
	
	var result := false
	if health_component and health_component.has_method("damage"):
		result = health_component.call("damage", amount, source)
	
	if result:
		# If attacked while idle or patrolling, retaliate / investigate source
		if current_state == State.IDLE or current_state == State.PATROL:
			if source and source is Node2D:
				last_known_player_pos = source.global_position
				change_state(State.CHASE)
			else:
				change_state(State.INVESTIGATE)
				
	return result


func _on_health_damaged(amount: float, _source: Node = null) -> void:
	if visual and visual.has_method("play_damage_flash"):
		visual.call("play_damage_flash")
	
	var cur: float = health_component.get("current_health") if health_component and "current_health" in health_component else 0.0
	var mx: float = health_component.get("max_health") if health_component and "max_health" in health_component else 100.0
	enemy_damaged.emit(amount, cur, mx)


func _on_health_died() -> void:
	if current_state == State.DEAD:
		return
	change_state(State.DEAD)
	enemy_died.emit(self)


func get_state_name() -> String:
	match current_state:
		State.IDLE: return "IDLE"
		State.PATROL: return "PATROL"
		State.INVESTIGATE: return "INVESTIGATE"
		State.CHASE: return "CHASE"
		State.ATTACK: return "ATTACK"
		State.DEAD: return "DEAD"
	return "UNKNOWN"
