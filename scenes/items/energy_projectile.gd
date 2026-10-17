class_name EnergyProjectile
extends Area2D
## Configurable Sci-Fi Energy / Plasma Projectile for BioSphere-X.
## Handles ballistic trajectory, range limits, collision with enemies and world obstacles,
## multi-hit prevention, knockback application, and procedural visual drawing.

signal projectile_hit(target: Node, hit_pos: Vector2)
signal projectile_expired(hit_pos: Vector2)

@export_group("Ballistics")
@export var speed: float = 520.0
@export var damage: float = 25.0
@export var max_range: float = 420.0
@export var pierce_count: int = 1
@export var knockback_force: float = 120.0

@export_group("Visuals")
@export var core_color: Color = Color(0.95, 1.0, 1.0)
@export var glow_color: Color = Color(0.12, 0.88, 1.0, 0.85)
@export var bolt_length: float = 14.0
@export var bolt_width: float = 5.0

var direction: Vector2 = Vector2.RIGHT
var source_node: Node = null

var _traveled_distance: float = 0.0
var _hit_instances: Dictionary = {}
var _is_expired: bool = false
var _anim_pulse: float = 0.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	z_index = 5
	monitoring = true
	monitorable = false
	
	# Detect Layer 1 (World obstacles, StaticBody2D walls, and Enemies)
	collision_layer = 0
	collision_mask = 1
	
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	# Align visual orientation
	rotation = direction.angle()


func setup(
	p_dir: Vector2,
	p_source: Node = null,
	p_damage: float = -1.0,
	p_speed: float = -1.0,
	p_range: float = -1.0,
	p_color: Color = Color(-1, -1, -1)
) -> void:
	direction = p_dir.normalized() if p_dir != Vector2.ZERO else Vector2.RIGHT
	source_node = p_source
	if p_damage > 0.0:
		damage = p_damage
	if p_speed > 0.0:
		speed = p_speed
	if p_range > 0.0:
		max_range = p_range
	if p_color.r >= 0:
		glow_color = p_color
	rotation = direction.angle()


func _physics_process(delta: float) -> void:
	if _is_expired:
		return
	
	_anim_pulse += delta * 15.0
	var step: float = speed * delta
	global_position += direction * step
	_traveled_distance += step
	
	if _traveled_distance >= max_range:
		_expire(global_position)
		return
	
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	_handle_collision(body)


func _on_area_entered(area: Area2D) -> void:
	_handle_collision(area)


func _handle_collision(target: Node) -> void:
	if _is_expired or target == null:
		return
	
	# Do not collide with the entity that fired this projectile
	if target == source_node or (source_node and target.is_ancestor_of(source_node)):
		return
	if target.is_in_group("player") and source_node and source_node.is_in_group("player"):
		return
	if target.is_in_group("enemies") and source_node and source_node.is_in_group("enemies"):
		return
	if target.is_in_group("team_a") and source_node and source_node.is_in_group("team_a"):
		return
	if target.is_in_group("team_b") and source_node and source_node.is_in_group("team_b"):
		return
	
	# Prevent damage from being applied multiple times by a single hit
	var inst_id := target.get_instance_id()
	if _hit_instances.has(inst_id):
		return
	_hit_instances[inst_id] = true
	
	# Determine if target is an enemy or damageable entity
	var is_enemy: bool = target.is_in_group("enemies")
	var is_damageable: bool = target.has_method("take_damage") or target.has_method("apply_damage") or target.has_node("HealthComponent")
	
	if is_enemy or is_damageable:
		_apply_damage_to_target(target)
		pierce_count -= 1
		projectile_hit.emit(target, global_position)
		_spawn_impact_effect(global_position)
		
		if pierce_count <= 0:
			_expire(global_position)
	else:
		# Target is an impassable world obstacle (StaticBody2D, wall, rock, canyon ridge, debris)
		projectile_hit.emit(target, global_position)
		_spawn_impact_effect(global_position)
		_expire(global_position)


const DamageDataScript := preload("res://scripts/components/damage_data.gd")
const ImpactEffectScript := preload("res://scenes/items/impact_effect.gd")


func _apply_damage_to_target(target: Node) -> void:
	var damage_data = DamageDataScript.create(
		damage,
		source_node,
		DamageDataScript.DamageType.ENERGY,
		direction,
		knockback_force,
		global_position
	)
	
	if target.has_method("apply_damage"):
		target.call("apply_damage", damage_data)
	elif target.has_method("take_damage"):
		target.call("take_damage", damage, source_node)
		if knockback_force > 0.0 and "velocity" in target:
			target.set("velocity", target.get("velocity") + direction * knockback_force)
	elif target.has_node("HealthComponent"):
		var hc = target.get_node("HealthComponent")
		if hc.has_method("apply_damage"):
			hc.call("apply_damage", damage_data)
		elif hc.has_method("damage"):
			hc.call("damage", damage, source_node)


func _spawn_impact_effect(pos: Vector2) -> void:
	var parent := get_parent()
	if parent:
		var effect: Node2D = ImpactEffectScript.new()
		effect.set("color", glow_color)
		effect.global_position = pos
		parent.call_deferred("add_child", effect)


func _expire(pos: Vector2) -> void:
	if _is_expired:
		return
	_is_expired = true
	projectile_expired.emit(pos)
	
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	
	queue_free()


func _draw() -> void:
	if _is_expired:
		return
	
	# Procedural glowing plasma bolt rendered locally along X axis (since node is rotated)
	var half_len := bolt_length * 0.5
	var half_w := bolt_width * 0.5
	var pulse := sin(_anim_pulse) * 0.5 + 0.5
	
	# Outer plasma glow halo
	var halo_color := Color(glow_color.r, glow_color.g, glow_color.b, 0.35 + pulse * 0.15)
	var glow_rect := Rect2(-half_len - 3.0, -half_w - 2.5, bolt_length + 6.0, bolt_width + 5.0)
	draw_rect(glow_rect, halo_color)
	draw_circle(Vector2(half_len + 1.0, 0), half_w + 2.0, halo_color)
	draw_circle(Vector2(-half_len - 1.0, 0), half_w + 1.0, halo_color)
	
	# Main plasma sheath
	draw_rect(Rect2(-half_len, -half_w, bolt_length, bolt_width), glow_color)
	draw_circle(Vector2(half_len, 0), half_w, glow_color)
	
	# Inner white-hot core
	var core_rect := Rect2(-half_len * 0.8, -half_w * 0.5, bolt_length * 0.8, bolt_width * 0.5)
	draw_rect(core_rect, core_color)
	draw_circle(Vector2(half_len * 0.8, 0), half_w * 0.5, core_color)
