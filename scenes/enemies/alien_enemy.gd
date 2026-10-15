extends CharacterBody2D
class_name AlienEnemy
## Reusable Alien Enemy Controller for BioSphere-X.
## Implements a robust state machine (Idle, Patrol, Investigate, Chase, Attack, Dead)
## with configurable perception rules, line-of-sight checks, wall obstruction blocking,
## reaction delays, attack cooldowns, and deterministic seeded RNG variation.

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

@export_group("Perception & Detection")
@export var detection_range: float = 240.0
@export var lose_interest_range: float = 340.0
@export var requires_line_of_sight: bool = true
@export var can_see_through_walls: bool = false # Allow specific ghostly/phasing variants to override
@export var can_attack_through_walls: bool = false # Prevent physical strikes through solid barriers
@export var reaction_delay: float = 0.2 # Small delay upon spotting player before chasing so combat feels fair
@export var patrol_radius: float = 160.0
@export var investigate_duration: float = 3.0

@export_group("Combat")
@export var attack_range: float = 36.0
@export var attack_damage: float = 15.0
@export var attack_cooldown: float = 1.2
@export var attack_windup_time: float = 0.35

@export_group("Determinism & Seeding")
@export var use_custom_seed: bool = false:
	set(val):
		use_custom_seed = val
		_init_rng()
@export var rng_seed: int = 0:
	set(val):
		rng_seed = val
		_init_rng()

# State Variables
var current_state: State = State.IDLE
var spawn_position: Vector2 = Vector2.ZERO
var patrol_target: Vector2 = Vector2.ZERO
var last_known_player_pos: Vector2 = Vector2.ZERO

var _idle_timer: float = 0.0
var _investigate_timer: float = 0.0
var _attack_timer: float = 0.0
var _cooldown_timer: float = 0.0
var _reaction_timer: float = 0.0
var _is_reacting: bool = false
var _target_player: Node2D = null

# Navigation Path Execution State
var _nav_path: PackedVector2Array = PackedVector2Array()
var _nav_path_index: int = 0
var _nav_refresh_timer: float = 0.0
var _nav_goal_pos: Vector2 = Vector2.ZERO
var _is_recalculating_nav: bool = false

# Internal deterministic RNG generator
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var visual: Node2D = $Visual
@onready var health_component: Node = $HealthComponent
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 1 # Physical body on layer 1
	collision_mask = 1  # Blocks with walls, boundaries, and obstacles
	
	_init_rng()
	
	spawn_position = global_position
	patrol_target = spawn_position
	_idle_timer = _randf_range(1.5, 3.0)
	
	_connect_health_signals()


func _init_rng() -> void:
	if not _rng:
		_rng = RandomNumberGenerator.new()
	if use_custom_seed:
		_rng.seed = rng_seed
	else:
		_rng.randomize()


func set_rng_seed(seed_val: int) -> void:
	use_custom_seed = true
	rng_seed = seed_val
	_init_rng()


func _randf_range(min_val: float, max_val: float) -> float:
	return _rng.randf_range(min_val, max_val)


func _randf() -> float:
	return _rng.randf()


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
	
	# Update cooldown timer
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
	
	# Check detection & perception rules
	if _can_detect_player():
		if reaction_delay <= 0.0:
			_reaction_timer = 0.0
			_is_reacting = false
			change_state(State.CHASE)
			return
		
		_is_reacting = true
		_reaction_timer += delta
		if _reaction_timer >= reaction_delay:
			_is_reacting = false
			_reaction_timer = 0.0
			change_state(State.CHASE)
			return
	else:
		_is_reacting = false
		_reaction_timer = 0.0
	
	_idle_timer -= delta
	if _idle_timer <= 0.0:
		_pick_next_patrol_target()
		change_state(State.PATROL)


func _process_patrol(delta: float) -> void:
	# Check detection & perception rules
	if _can_detect_player():
		if reaction_delay <= 0.0:
			_reaction_timer = 0.0
			_is_reacting = false
			change_state(State.CHASE)
			return
		
		_is_reacting = true
		_reaction_timer += delta
		if _reaction_timer >= reaction_delay:
			_is_reacting = false
			_reaction_timer = 0.0
			change_state(State.CHASE)
			return
	else:
		_is_reacting = false
		_reaction_timer = 0.0
	
	var to_target := patrol_target - global_position
	var dist := to_target.length()
	
	if dist <= 16.0:
		_idle_timer = _randf_range(1.5, 3.0)
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
	
	# Verify continuous perception: distance and line-of-sight
	var player_in_sight := true
	if requires_line_of_sight and not has_line_of_sight_to(_target_player.global_position):
		player_in_sight = false
	
	if player_in_sight and dist <= lose_interest_range:
		last_known_player_pos = _target_player.global_position
	else:
		# Lost sight of player or exceeded chase boundary -> investigate last known position
		change_state(State.INVESTIGATE)
		return
	
	# Transition to Attack when in range
	if dist <= attack_range:
		if _cooldown_timer <= 0.0:
			change_state(State.ATTACK)
			return
		else:
			# Close-in circling while waiting for cooldown
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
			return
	
	# Chase movement with navigation waypoints
	_nav_refresh_timer -= delta
	var target_shifted := _target_player.global_position.distance_squared_to(_nav_goal_pos) > 64.0 * 64.0
	var needs_path := _nav_path.is_empty() or (_nav_path_index >= _nav_path.size()) or target_shifted
	
	if needs_path and _nav_refresh_timer <= 0.0 and not _is_recalculating_nav:
		_nav_refresh_timer = 0.6
		_request_navigation_path(_target_player.global_position)
	
	var steer_target := _target_player.global_position
	if _nav_path.size() > 0 and _nav_path_index < _nav_path.size():
		var waypoint := _nav_path[_nav_path_index]
		if global_position.distance_to(waypoint) <= 24.0:
			_nav_path_index += 1
			if _nav_path_index < _nav_path.size():
				waypoint = _nav_path[_nav_path_index]
		steer_target = waypoint
	
	var target_dir := (steer_target - global_position).normalized()
	var target_vel := target_dir * chase_speed
	velocity = velocity.move_toward(target_vel, acceleration * delta)


func _process_investigate(delta: float) -> void:
	# If player re-detected with clear perception, resume chase immediately
	if _can_detect_player():
		change_state(State.CHASE)
		return
	
	var to_last_known := last_known_player_pos - global_position
	var dist := to_last_known.length()
	
	if dist > 20.0:
		# Move towards the last known position
		var target_vel := to_last_known.normalized() * patrol_speed
		velocity = velocity.move_toward(target_vel, acceleration * delta)
	else:
		# Arrived at last known position: slow down and investigate area
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		_investigate_timer -= delta
		if _investigate_timer <= 0.0:
			# Finished investigating -> return to patrol
			patrol_target = spawn_position
			_idle_timer = _randf_range(1.0, 2.5)
			change_state(State.PATROL)


func _process_attack(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, friction * delta * 2.0)
	_attack_timer += delta
	
	# Update visual windup telegraph so combat feels fair
	if visual and "attack_windup_ratio" in visual:
		visual.set("attack_windup_ratio", clampf(_attack_timer / attack_windup_time, 0.0, 1.0))
	
	if _attack_timer >= attack_windup_time:
		_execute_attack_strike()
		_cooldown_timer = attack_cooldown
		_attack_timer = 0.0
		if visual and "attack_windup_ratio" in visual:
			visual.set("attack_windup_ratio", 0.0)
		
		# Return to chase or investigate based on perception
		if _can_detect_player():
			change_state(State.CHASE)
		else:
			change_state(State.INVESTIGATE)


func _execute_attack_strike() -> void:
	if not _is_target_valid():
		return
	
	var dist := global_position.distance_to(_target_player.global_position)
	if dist <= attack_range * 1.4:
		# Ensure enemies cannot attack through solid walls unless explicitly configured
		if not can_attack_through_walls and not has_line_of_sight_to(_target_player.global_position):
			return
		
		# Apply damage to player
		if _target_player.has_method("take_damage"):
			_target_player.call("take_damage", attack_damage, self)
		elif _target_player.has_node("HealthComponent"):
			var p_hc = _target_player.get_node("HealthComponent")
			if p_hc.has_method("damage"):
				p_hc.call("damage", attack_damage, self)
		
		enemy_attacked.emit(_target_player, attack_damage)


# ---------------------------------------------------------------------------
# Perception & Line of Sight Implementation
# ---------------------------------------------------------------------------
func has_line_of_sight_to(target_pos: Vector2) -> bool:
	if can_see_through_walls:
		return true
	
	# 1. Check against MapData grid obstruction if available
	var nav_mgr = get_node_or_null("/root/NavigationManager")
	if nav_mgr and nav_mgr.has_method("get_map_data"):
		var md = nav_mgr.call("get_map_data")
		if md and md.has_method("has_line_of_sight"):
			if not md.call("has_line_of_sight", global_position, target_pos):
				return false
	
	# 2. Check 2D Physics direct space state raycast if inside scene tree
	if is_inside_tree() and get_world_2d():
		var space_state := get_world_2d().direct_space_state
		if space_state:
			var query := PhysicsRayQueryParameters2D.create(global_position, target_pos)
			query.collision_mask = collision_mask
			query.exclude = [get_rid()]
			var hit := space_state.intersect_ray(query)
			if not hit.is_empty():
				var col = hit.get("collider")
				if col != _target_player and not (col and col.is_in_group("player")):
					return false
					
	return true


func _can_detect_player() -> bool:
	if not _is_target_valid():
		return false
	var dist := global_position.distance_to(_target_player.global_position)
	if dist > detection_range:
		return false
	if requires_line_of_sight and not has_line_of_sight_to(_target_player.global_position):
		return false
	return true


# ---------------------------------------------------------------------------
# State Transitions & Helpers
# ---------------------------------------------------------------------------
func change_state(new_state: State) -> void:
	if current_state == new_state or current_state == State.DEAD:
		return
	
	var old_state := current_state
	current_state = new_state
	
	_reaction_timer = 0.0
	_is_reacting = false
	
	# Clear active path on state departure
	if old_state == State.CHASE and new_state != State.CHASE:
		_nav_path.clear()
		_nav_path_index = 0
		var nav_mgr = get_node_or_null("/root/NavigationManager")
		if nav_mgr and nav_mgr.has_method("unregister_active_path"):
			nav_mgr.call("unregister_active_path", get_instance_id())
	
	match new_state:
		State.IDLE:
			_idle_timer = _randf_range(1.5, 3.0)
		State.PATROL:
			_reaction_timer = 0.0
		State.INVESTIGATE:
			_investigate_timer = investigate_duration
		State.ATTACK:
			_attack_timer = 0.0
		State.DEAD:
			velocity = Vector2.ZERO
			_nav_path.clear()
			var nav_mgr = get_node_or_null("/root/NavigationManager")
			if nav_mgr and nav_mgr.has_method("unregister_active_path"):
				nav_mgr.call("unregister_active_path", get_instance_id())
			if collision_shape:
				collision_shape.disabled = true
				collision_shape.set_deferred("disabled", true)
			if visual and visual.has_method("play_death"):
				visual.call("play_death")
	
	state_changed.emit(old_state, new_state)


func _pick_next_patrol_target() -> void:
	var angle := _randf_range(0, TAU)
	var dist := _randf_range(32.0, patrol_radius)
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


func _request_navigation_path(target_pos: Vector2) -> void:
	var nav_mgr = get_node_or_null("/root/NavigationManager")
	if nav_mgr and nav_mgr.has_method("request_path"):
		_is_recalculating_nav = true
		nav_mgr.call("request_path", global_position, target_pos, null, func(path: PackedVector2Array, metrics: Dictionary) -> void:
			if not is_instance_valid(self):
				return
			_is_recalculating_nav = false
			if path.size() > 0:
				_nav_path = path
				_nav_path_index = 0
				_nav_goal_pos = target_pos
				nav_mgr.call("register_active_path", get_instance_id(), path, Color(1.0, 0.4, 0.2, 0.9))
			else:
				_handle_unreachable_navigation(target_pos, metrics)
		)


func _handle_unreachable_navigation(target_pos: Vector2, _metrics: Dictionary) -> void:
	_nav_path.clear()
	_nav_path_index = 0
	_nav_refresh_timer = 1.0 # Back off recalculation for 1s
	if current_state == State.CHASE:
		var dist := global_position.distance_to(target_pos)
		if dist > attack_range * 1.5:
			last_known_player_pos = target_pos
			change_state(State.INVESTIGATE)


func _exit_tree() -> void:
	var nav_mgr = get_node_or_null("/root/NavigationManager")
	if nav_mgr and nav_mgr.has_method("unregister_active_path"):
		nav_mgr.call("unregister_active_path", get_instance_id())


# ---------------------------------------------------------------------------
# Combat & Public Health API
# ---------------------------------------------------------------------------
func apply_damage(damage_data: DamageData) -> bool:
	if not damage_data or current_state == State.DEAD:
		return false
	if damage_data.knockback_force > 0.0:
		velocity += damage_data.knockback_direction * damage_data.knockback_force
	return take_damage(damage_data.amount, damage_data.source)


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
