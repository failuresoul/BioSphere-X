extends CharacterBody2D
class_name AlienEnemy

const FloatingCombatTextScript := preload("res://scripts/components/floating_combat_text.gd")
## Features configurable perception, line-of-sight checks, wall obstruction blocking,
## melee and ranged attack styles, configurable defeat rewards, and clean corpse cleanup.

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

enum EnemyType {
	SCOUT,
	ARMORED_BRUTE,
	SPITTER,
	CUSTOM
}

enum AttackStyle {
	MELEE_SWIPE,
	HEAVY_SLAM,
	RANGED_SPIT
}

const DamageDataScript := preload("res://scripts/components/damage_data.gd")
const AdaptiveDifficultyManagerScript := preload("res://scripts/components/adaptive_difficulty_manager.gd")
const _projectile_scene := preload("res://scenes/items/energy_projectile.tscn")
const _collectable_scene := preload("res://scenes/items/collectable_resource.tscn")

var _is_applying_preset: bool = false

@export_group("Type Preset")
@export var enemy_type: EnemyType = EnemyType.SCOUT:
	set(val):
		enemy_type = val
		if not _is_applying_preset and val != EnemyType.CUSTOM and is_inside_tree():
			apply_enemy_preset(val)

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
@export var can_see_through_walls: bool = false
@export var can_attack_through_walls: bool = false
@export var reaction_delay: float = 0.2
@export var patrol_radius: float = 160.0
@export var investigate_duration: float = 3.0

@export_group("Combat & Attack")
@export var attack_style: AttackStyle = AttackStyle.MELEE_SWIPE
@export var attack_range: float = 36.0
@export var attack_damage: float = 15.0
@export var attack_cooldown: float = 1.2
@export var attack_windup_time: float = 0.35
@export var projectile_speed: float = 340.0
@export var projectile_color: Color = Color(0.2, 1.0, 0.4)

@export_group("Defeat Rewards & Cleanup")
@export var drops_reward: bool = true
@export var reward_drop_chance: float = 0.85
@export var primary_resource_type: int = 3 # 3 = SCIENTIFIC_SAMPLE (Biomass)
@export var primary_resource_min: int = 1
@export var primary_resource_max: int = 2
@export var secondary_drop_chance: float = 0.30
@export var secondary_resource_type: int = 2 # 2 = ENERGY_CRYSTAL
@export var secondary_resource_amount: int = 1
@export var disappear_on_death: bool = true
@export var corpse_linger_time: float = 2.0

@export_group("Adaptive Difficulty")
@export var enable_adaptive_difficulty: bool = true:
	set(val):
		enable_adaptive_difficulty = val
		if not val and _difficulty_mgr:
			apply_difficulty_multipliers({
				"speed_multiplier": 1.0,
				"attack_damage_multiplier": 1.0,
				"attack_cooldown_multiplier": 1.0,
				"detection_range_multiplier": 1.0
			})
@export var difficulty_mode: String = "adaptive":
	set(val):
		difficulty_mode = val
		if _difficulty_mgr:
			_difficulty_mgr.set("difficulty_mode", val)
			if is_inside_tree() and _target_player:
				_difficulty_mgr.call("evaluate_difficulty", self, _target_player, _on_difficulty_updated)
@export var difficulty_poll_interval: float = 1.0

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

# Adaptive Difficulty Management
var _difficulty_mgr: RefCounted = null
var _difficulty_timer: float = 0.0
var _base_chase_speed: float = 160.0
var _base_attack_damage: float = 15.0
var _base_attack_cooldown: float = 1.2
var _base_detection_range: float = 240.0

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
	collision_layer = 1
	collision_mask = 1
	
	_init_rng()
	
	spawn_position = global_position
	patrol_target = spawn_position
	_idle_timer = _randf_range(1.5, 3.0)
	
	_connect_health_signals()
	
	_base_chase_speed = chase_speed
	_base_attack_damage = attack_damage
	_base_attack_cooldown = attack_cooldown
	_base_detection_range = detection_range
	
	if enemy_type != EnemyType.CUSTOM:
		apply_enemy_preset(enemy_type)
	
	_init_adaptive_difficulty()


func apply_enemy_preset(type: EnemyType) -> void:
	_is_applying_preset = true
	enemy_type = type
	_is_applying_preset = false
	match type:
		EnemyType.SCOUT:
			enemy_name = "Xeno Scout"
			patrol_speed = 110.0
			chase_speed = 210.0
			acceleration = 1100.0
			friction = 950.0
			detection_range = 320.0
			lose_interest_range = 420.0
			reaction_delay = 0.10
			attack_style = AttackStyle.MELEE_SWIPE
			attack_range = 32.0
			attack_damage = 8.0
			attack_cooldown = 0.75
			attack_windup_time = 0.18
			drops_reward = true
			reward_drop_chance = 0.90
			primary_resource_type = 3 # Biomass (Scientific Sample)
			primary_resource_min = 1
			primary_resource_max = 1
			secondary_drop_chance = 0.25
			secondary_resource_type = 2 # Energy Crystal
			secondary_resource_amount = 1
			_set_max_health(35.0)
			_update_collision_radius(10.0)
			_update_visual_type(0)
			
		EnemyType.ARMORED_BRUTE:
			enemy_name = "Armored Goliath"
			patrol_speed = 45.0
			chase_speed = 75.0
			acceleration = 600.0
			friction = 800.0
			detection_range = 190.0
			lose_interest_range = 280.0
			reaction_delay = 0.35
			attack_style = AttackStyle.HEAVY_SLAM
			attack_range = 48.0
			attack_damage = 28.0
			attack_cooldown = 1.80
			attack_windup_time = 0.50
			drops_reward = true
			reward_drop_chance = 1.00 # Guaranteed drop
			primary_resource_type = 1 # Titanium Metal
			primary_resource_min = 2
			primary_resource_max = 3
			secondary_drop_chance = 0.50
			secondary_resource_type = 0 # Oxygen Cell
			secondary_resource_amount = 1
			_set_max_health(180.0)
			_update_collision_radius(18.0)
			_update_visual_type(1)
			
		EnemyType.SPITTER:
			enemy_name = "Acid Spitter"
			patrol_speed = 70.0
			chase_speed = 115.0
			acceleration = 800.0
			friction = 900.0
			detection_range = 270.0
			lose_interest_range = 380.0
			reaction_delay = 0.20
			attack_style = AttackStyle.RANGED_SPIT
			attack_range = 220.0
			attack_damage = 14.0
			attack_cooldown = 1.50
			attack_windup_time = 0.40
			projectile_speed = 340.0
			projectile_color = Color(0.20, 1.00, 0.40)
			drops_reward = true
			reward_drop_chance = 0.85
			primary_resource_type = 2 # Energy Crystal
			primary_resource_min = 1
			primary_resource_max = 2
			secondary_drop_chance = 0.40
			secondary_resource_type = 3 # Biomass
			secondary_resource_amount = 1
			_set_max_health(65.0)
			_update_collision_radius(13.0)
			_update_visual_type(2)
	
	_base_chase_speed = chase_speed
	_base_attack_damage = attack_damage
	_base_attack_cooldown = attack_cooldown
	_base_detection_range = detection_range
	
	if _difficulty_mgr:
		apply_difficulty_multipliers(_difficulty_mgr.get("current_parameters"))


func _set_max_health(val: float) -> void:
	if not health_component:
		health_component = get_node_or_null("HealthComponent")
	if health_component:
		health_component.set("max_health", val)
		health_component.set("current_health", val)


func _update_collision_radius(r: float) -> void:
	if not collision_shape:
		collision_shape = get_node_or_null("CollisionShape2D")
	if collision_shape and collision_shape.shape is CircleShape2D:
		if not collision_shape.shape.is_local_to_scene():
			collision_shape.shape = collision_shape.shape.duplicate()
		(collision_shape.shape as CircleShape2D).radius = r


func _update_visual_type(type_index: int) -> void:
	if not visual:
		visual = get_node_or_null("Visual")
	if visual and visual.has_method("set_enemy_type"):
		visual.call("set_enemy_type", type_index)


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
	
	# Update adaptive difficulty parameters
	if enable_adaptive_difficulty and _difficulty_mgr:
		_difficulty_mgr.call("update", delta)
		_difficulty_timer -= delta
		if _difficulty_timer <= 0.0:
			_difficulty_timer = difficulty_poll_interval
			if _is_target_valid():
				_difficulty_mgr.call("evaluate_difficulty", self, _target_player, _on_difficulty_updated)
	
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
	
	# Verify continuous perception
	var player_in_sight := true
	if requires_line_of_sight and not has_line_of_sight_to(_target_player.global_position):
		player_in_sight = false
	
	if player_in_sight and dist <= lose_interest_range:
		last_known_player_pos = _target_player.global_position
	else:
		change_state(State.INVESTIGATE)
		return
	
	# Transition to Attack when in range
	if dist <= attack_range:
		if player_in_sight or not requires_line_of_sight:
			if _cooldown_timer <= 0.0:
				change_state(State.ATTACK)
				return
			else:
				# Ranged enemy kiting: maintain comfortable distance instead of hugging
				if attack_style == AttackStyle.RANGED_SPIT:
					if dist < attack_range * 0.45:
						var retreat_dir := -to_player.normalized()
						velocity = velocity.move_toward(retreat_dir * chase_speed * 0.55, acceleration * delta)
						return
					else:
						velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
						return
				else:
					# Melee circling
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
	if _can_detect_player():
		change_state(State.CHASE)
		return
	
	_investigate_timer -= delta
	if _investigate_timer <= 0.0:
		patrol_target = spawn_position
		_idle_timer = _randf_range(1.0, 2.5)
		change_state(State.PATROL)
		return
	
	var to_last_known := last_known_player_pos - global_position
	var dist := to_last_known.length()
	
	if dist > 20.0:
		var target_vel := to_last_known.normalized() * patrol_speed
		velocity = velocity.move_toward(target_vel, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)


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
		
		if _can_detect_player():
			change_state(State.CHASE)
		else:
			change_state(State.INVESTIGATE)


func _execute_attack_strike() -> void:
	if not _is_target_valid():
		return
	
	var to_target := _target_player.global_position - global_position
	var dist := to_target.length()
	
	# Ensure enemies cannot attack through solid walls unless configured
	if not can_attack_through_walls and not has_line_of_sight_to(_target_player.global_position):
		return
	
	match attack_style:
		AttackStyle.RANGED_SPIT:
			var shoot_dir := to_target.normalized() if dist > 0.0 else Vector2.RIGHT
			_spawn_ranged_projectile(shoot_dir)
			enemy_attacked.emit(_target_player, attack_damage)
			
		AttackStyle.HEAVY_SLAM:
			if dist <= attack_range * 1.5:
				var slam_dir := to_target.normalized()
				var slam_data = DamageDataScript.create(
					attack_damage,
					self,
					DamageDataScript.DamageType.PHYSICAL,
					slam_dir,
					180.0,
					global_position
				)
				if _target_player.has_method("apply_damage"):
					_target_player.call("apply_damage", slam_data)
				elif _target_player.has_method("take_damage"):
					_target_player.call("take_damage", attack_damage, self)
				elif _target_player.has_node("HealthComponent"):
					_target_player.get_node("HealthComponent").call("damage", attack_damage, self)
				
				enemy_attacked.emit(_target_player, attack_damage)
				if _difficulty_mgr:
					_difficulty_mgr.call("record_player_damage", attack_damage)
				
		AttackStyle.MELEE_SWIPE:
			if dist <= attack_range * 1.4:
				var swipe_dir := to_target.normalized()
				var swipe_data = DamageDataScript.create(
					attack_damage,
					self,
					DamageDataScript.DamageType.PHYSICAL,
					swipe_dir,
					60.0,
					global_position
				)
				if _target_player.has_method("apply_damage"):
					_target_player.call("apply_damage", swipe_data)
				elif _target_player.has_method("take_damage"):
					_target_player.call("take_damage", attack_damage, self)
				elif _target_player.has_node("HealthComponent"):
					_target_player.get_node("HealthComponent").call("damage", attack_damage, self)
				
				enemy_attacked.emit(_target_player, attack_damage)
				if _difficulty_mgr:
					_difficulty_mgr.call("record_player_damage", attack_damage)


func _spawn_ranged_projectile(shoot_dir: Vector2) -> void:
	if not _projectile_scene:
		return
	
	var proj: Area2D = _projectile_scene.instantiate()
	var spawn_dist: float = 16.0
	if collision_shape and collision_shape.shape is CircleShape2D:
		spawn_dist = (collision_shape.shape as CircleShape2D).radius + 6.0
	
	var parent: Node = get_parent()
	if parent:
		parent.add_child(proj)
	else:
		add_child(proj)
	
	proj.global_position = global_position + shoot_dir * spawn_dist
	
	if proj.has_method("setup"):
		proj.call(
			"setup",
			shoot_dir,
			self,
			attack_damage,
			projectile_speed,
			attack_range * 1.35,
			projectile_color
		)


# ---------------------------------------------------------------------------
# Perception & Line of Sight Implementation
# ---------------------------------------------------------------------------
func has_line_of_sight_to(target_pos: Vector2) -> bool:
	if can_see_through_walls:
		return true
	
	var nav_mgr = get_node_or_null("/root/NavigationManager")
	if nav_mgr and nav_mgr.has_method("get_map_data"):
		var md = nav_mgr.call("get_map_data")
		if md and md.has_method("has_line_of_sight"):
			if not md.call("has_line_of_sight", global_position, target_pos):
				return false
	
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
		_update_target_player()
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
				collision_shape.set_deferred("disabled", true)
			set_deferred("collision_layer", 0)
			set_deferred("collision_mask", 0)
			if visual and visual.has_method("play_death"):
				visual.call("play_death")
	
	state_changed.emit(old_state, new_state)


func _pick_next_patrol_target() -> void:
	var angle := _randf_range(0, TAU)
	var dist := _randf_range(32.0, patrol_radius)
	patrol_target = spawn_position + Vector2.from_angle(angle) * dist


func set_target_player(node: Node2D) -> void:
	_target_player = node


func get_target_player() -> Node2D:
	return _target_player


func _update_target_player() -> void:
	if not _is_target_valid():
		var players := get_tree().get_nodes_in_group("player")
		for p in players:
			if is_instance_valid(p) and p.is_inside_tree() and not p.is_queued_for_deletion():
				if not ("is_dead" in p and p.get("is_dead")):
					_target_player = p as Node2D
					return
		_target_player = null


func _is_target_valid() -> bool:
	if not is_instance_valid(_target_player) or not _target_player.is_inside_tree() or _target_player.is_queued_for_deletion():
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
	_nav_refresh_timer = 1.0
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
# Defeat Rewards & Corpse Clean Up
# ---------------------------------------------------------------------------
func _spawn_defeat_rewards() -> void:
	if not drops_reward or _collectable_scene == null:
		return
	
	var parent := get_parent()
	if not parent:
		return
	
	# Roll primary drop
	if _randf() <= reward_drop_chance:
		var qty := int(_randf_range(float(primary_resource_min), float(primary_resource_max) + 0.99))
		qty = maxi(1, qty)
		_spawn_resource_item(primary_resource_type, qty, Vector2.ZERO)
	
	# Roll secondary drop
	if _randf() <= secondary_drop_chance:
		var offset := Vector2.from_angle(_randf_range(0.0, TAU)) * _randf_range(14.0, 26.0)
		_spawn_resource_item(secondary_resource_type, secondary_resource_amount, offset)


func _spawn_resource_item(type: int, qty: int, offset: Vector2) -> void:
	var parent := get_parent()
	if not parent:
		return
	var item: Area2D = _collectable_scene.instantiate()
	item.set("resource_type", type)
	item.set("quantity", qty)
	parent.add_child(item)
	item.global_position = global_position + offset


func _cleanup_corpse() -> void:
	if corpse_linger_time <= 0.0:
		queue_free()
		return
	
	var tween := create_tween()
	if tween:
		tween.tween_interval(corpse_linger_time * 0.6)
		tween.tween_property(self, "modulate:a", 0.0, corpse_linger_time * 0.4)
		tween.tween_callback(queue_free)


# ---------------------------------------------------------------------------
# Combat & Public Health API
# ---------------------------------------------------------------------------
func apply_damage(damage_data: RefCounted) -> bool:
	if not damage_data or current_state == State.DEAD:
		return false
	var force: float = float(damage_data.get("knockback_force"))
	var dir: Vector2 = damage_data.get("knockback_direction")
	var result: bool = take_damage(float(damage_data.get("amount")), damage_data.get("source"))
	if force > 0.0:
		velocity += dir * force
	return result


func take_damage(amount: float, source: Node = null) -> bool:
	if current_state == State.DEAD:
		return false
	
	if not health_component:
		health_component = get_node_or_null("HealthComponent")
	
	var result := false
	if health_component and health_component.has_method("damage"):
		result = health_component.call("damage", amount, source)
	
	if result:
		if current_state == State.IDLE or current_state == State.PATROL:
			if source and source is Node2D:
				last_known_player_pos = source.global_position
			change_state(State.CHASE)
				
	return result


func _on_health_damaged(amount: float, _source: Node = null) -> void:
	if visual and visual.has_method("play_damage_flash"):
		visual.call("play_damage_flash")
	
	var cur: float = health_component.get("current_health") if health_component and "current_health" in health_component else 0.0
	var mx: float = health_component.get("max_health") if health_component and "max_health" in health_component else 100.0
	enemy_damaged.emit(amount, cur, mx)
	
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_sfx"):
		audio.call("play_sfx", "laser_hit", randf_range(0.95, 1.1))
	FloatingCombatTextScript.spawn(self, global_position, "-%d" % int(amount), Color(1.0, 0.45, 0.2))


func _on_health_died() -> void:
	if current_state == State.DEAD:
		return
	change_state(State.DEAD)
	
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_sfx"):
		audio.call("play_sfx", "enemy_death", randf_range(0.9, 1.05))
		
	_spawn_defeat_rewards()
	
	enemy_died.emit(self)
	
	var mm := get_node_or_null("/root/MissionManager")
	if mm:
		mm.call("notify_event", "enemy_defeated", {"enemy_type": enemy_type, "enemy": self})
	
	if disappear_on_death:
		_cleanup_corpse()


func get_state_name() -> String:
	match current_state:
		State.IDLE: return "IDLE"
		State.PATROL: return "PATROL"
		State.INVESTIGATE: return "INVESTIGATE"
		State.CHASE: return "CHASE"
		State.ATTACK: return "ATTACK"
		State.DEAD: return "DEAD"
	return "UNKNOWN"


# ---------------------------------------------------------------------------
# Adaptive Difficulty API
# ---------------------------------------------------------------------------
func _init_adaptive_difficulty() -> void:
	if not enable_adaptive_difficulty:
		return
	if not _difficulty_mgr and AdaptiveDifficultyManagerScript:
		_difficulty_mgr = AdaptiveDifficultyManagerScript.new()
		_difficulty_mgr.set("difficulty_mode", difficulty_mode)


func _on_difficulty_updated(params: Dictionary) -> void:
	apply_difficulty_multipliers(params)


func apply_difficulty_multipliers(multipliers: Dictionary) -> void:
	if multipliers == null or multipliers.is_empty():
		return
	var spd_mult: float = float(multipliers.get("speed_multiplier", 1.0))
	var dmg_mult: float = float(multipliers.get("attack_damage_multiplier", 1.0))
	var cd_mult: float = float(multipliers.get("attack_cooldown_multiplier", 1.0))
	var det_mult: float = float(multipliers.get("detection_range_multiplier", 1.0))
	
	if _difficulty_mgr:
		var curr: Dictionary = _difficulty_mgr.get("current_parameters")
		curr["speed_multiplier"] = spd_mult
		curr["attack_damage_multiplier"] = dmg_mult
		curr["attack_cooldown_multiplier"] = cd_mult
		curr["detection_range_multiplier"] = det_mult
	
	chase_speed = _base_chase_speed * spd_mult
	attack_damage = _base_attack_damage * dmg_mult
	attack_cooldown = _base_attack_cooldown * cd_mult
	detection_range = _base_detection_range * det_mult


func get_difficulty_manager() -> RefCounted:
	return _difficulty_mgr


func set_difficulty_mode(mode: String) -> void:
	difficulty_mode = mode
	if _difficulty_mgr:
		_difficulty_mgr.set("difficulty_mode", mode)
		if is_inside_tree() and _target_player:
			_difficulty_mgr.call("evaluate_difficulty", self, _target_player, _on_difficulty_updated)


func get_current_multipliers() -> Dictionary:
	if _difficulty_mgr:
		return _difficulty_mgr.get("current_parameters")
	return {
		"speed_multiplier": 1.0,
		"attack_damage_multiplier": 1.0,
		"attack_cooldown_multiplier": 1.0,
		"detection_range_multiplier": 1.0
	}

