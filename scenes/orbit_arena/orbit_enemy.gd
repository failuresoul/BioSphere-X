extends CharacterBody3D
class_name OrbitEnemy

signal eliminated(enemy: OrbitEnemy)

const WALK: int = 0
const CHASE: int = 1
const ATTACK: int = 2
const DEAD: int = 3
const ALIEN_MODEL = preload("res://assets/kenney/space/alien.glb")
const BOSS_ARMOR_MODEL = preload("res://assets/kenney/space/machine_generatorLarge.glb")

var arena: Node3D
var algorithm: String = "astar"
var is_boss: bool = false
var boss_algorithm: String = "alpha_beta"
var max_health: float = 28.0
var health: float = 28.0
var speed: float = 3.5
var damage: float = 8.0
var state: int = WALK
var attack_cooldown: float = 0.0
var path_cooldown: float = 0.0
var decision_cooldown: float = 0.0
var chosen_action: String = ""
var path_points: Array[Vector3] = []
var visual: Node3D


func configure(p_arena: Node3D, p_algorithm: String, p_boss: bool, planet_index: int) -> void:
	arena = p_arena
	algorithm = p_algorithm
	is_boss = p_boss
	if is_boss:
		boss_algorithm = ["alpha_beta", "minimax", "mcts"][planet_index]
		max_health = 125.0 + planet_index * 60.0
		speed = 2.7 + planet_index * 0.25
		damage = 16.0 + planet_index * 3.0
	else:
		max_health = 28.0 + planet_index * 8.0
		speed = 3.0 + planet_index * 0.3
		damage = 7.0 + planet_index * 2.0
	health = max_health


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.65 if is_boss else 0.4
	capsule.height = 2.3 if is_boss else 1.5
	shape.shape = capsule
	shape.position.y = 1.15 if is_boss else 0.75
	add_child(shape)

	visual = Node3D.new()
	var alien := ALIEN_MODEL.instantiate() as Node3D
	alien.position.y = 0.43 if is_boss else 0.34
	alien.scale = Vector3.ONE * (1.8 if is_boss else 0.95)
	visual.add_child(alien)
	var material := StandardMaterial3D.new()
	var colors := {
		"astar": Color(1.0, 0.42, 0.27),
		"bfs": Color(1.0, 0.72, 0.28),
		"dfs": Color(0.85, 0.48, 1.0),
		"dls": Color(0.98, 0.37, 0.68),
		"iddfs": Color(0.59, 0.71, 1.0),
		"bidirectional": Color(0.36, 0.97, 0.54),
		"greedy": Color(1.0, 0.87, 0.51)
	}
	material.albedo_color = Color(0.95, 0.25, 0.27) if is_boss else colors.get(algorithm, Color(1.0, 0.48, 0.25))
	material.emission_enabled = true
	material.emission = material.albedo_color * 0.3
	var aura := MeshInstance3D.new()
	var aura_mesh := CylinderMesh.new()
	aura_mesh.top_radius = 0.95 if is_boss else 0.54
	aura_mesh.bottom_radius = aura_mesh.top_radius
	aura_mesh.height = 0.07
	aura.mesh = aura_mesh
	aura.position.y = 0.055
	aura.material_override = material
	visual.add_child(aura)
	add_child(visual)

	if is_boss:
		var armor := BOSS_ARMOR_MODEL.instantiate() as Node3D
		armor.position.y = 1.6
		armor.scale = Vector3.ONE * 1.5
		visual.add_child(armor)


func _physics_process(delta: float) -> void:
	if state == DEAD or not is_instance_valid(arena) or not arena.is_combat_active():
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	path_cooldown -= delta
	decision_cooldown -= delta
	var player_pos: Vector3 = arena.get_player_position()
	var distance := Vector2(global_position.x - player_pos.x, global_position.z - player_pos.z).length()
	var reach := 2.0 if is_boss else 1.35
	if distance <= reach:
		state = ATTACK
		velocity = Vector3.ZERO
		if attack_cooldown <= 0.0:
			_perform_attack(player_pos)
	else:
		state = CHASE
		if path_cooldown <= 0.0:
			path_cooldown = 1.2 + randf_range(0.0, 0.35)
			path_points = arena.arena_path(global_position, player_pos, algorithm)
		var destination := player_pos
		if not path_points.is_empty():
			if global_position.distance_to(path_points[0]) < 0.65:
				path_points.remove_at(0)
			if not path_points.is_empty():
				destination = path_points[0]
		var heading := destination - global_position
		heading.y = 0.0
		velocity = heading.normalized() * speed * arena.get_enemy_speed_multiplier()
		move_and_slide()
		if heading.length() > 0.1:
			visual.rotation.y = atan2(heading.x, heading.z)
		if is_boss and attack_cooldown <= 0.0 and distance < 11.0 and ("BARRAGE" in chosen_action or "ACID" in chosen_action):
			arena.spawn_enemy_shot(global_position + Vector3.UP * 1.1, player_pos + Vector3.UP * 0.8, damage)
			attack_cooldown = 1.6
			chosen_action = ""

	if is_boss and decision_cooldown <= 0.0:
		decision_cooldown = 2.4
		_request_decision(distance)


func _request_decision(distance: float) -> void:
	var state_data := {
		"turn": "boss",
		"boss_hp": health,
		"boss_max_hp": max_health,
		"boss_phase": 2 if health < max_health * 0.5 else 1,
		"player_hp": arena.get_player_health(),
		"player_max_hp": arena.get_player_max_health(),
		"player_energy": 100.0,
		"distance": distance * 25.0
	}
	AIClient.request_boss_decision(state_data, boss_algorithm, {"max_depth": 3, "simulations": 70}, func(result: Dictionary) -> void:
		if not is_instance_valid(self) or state == DEAD:
			return
		if bool(result.get("success", false)):
			chosen_action = str(result.get("data", {}).get("action", ""))
	)


func _perform_attack(player_pos: Vector3) -> void:
	attack_cooldown = (1.3 if is_boss else 1.15) / arena.get_enemy_speed_multiplier()
	if is_boss and ("BARRAGE" in chosen_action or "ACID" in chosen_action):
		arena.spawn_enemy_shot(global_position + Vector3.UP * 1.1, player_pos + Vector3.UP * 0.8, damage)
	elif is_boss and ("SLAM" in chosen_action or "CHARGE" in chosen_action):
		arena.damage_player(damage * 1.25)
	else:
		arena.damage_player(damage)
	chosen_action = ""


func take_hit(amount: float) -> void:
	if state == DEAD:
		return
	health = maxf(0.0, health - amount)
	visual.scale = Vector3.ONE * (1.18 if health > 0.0 else 0.8)
	if health <= 0.0:
		state = DEAD
		eliminated.emit(self)
		queue_free()
	else:
		var tween := create_tween()
		tween.tween_property(visual, "scale", Vector3.ONE, 0.12)
