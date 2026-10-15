class_name DamageData
extends RefCounted
## Standardized combat damage contract for BioSphere-X.
## Decouples attackers, weapons, projectiles, environmental hazards, and defenders.
## Provides extensible metadata for damage types, knockback, and hit coordinates.

enum DamageType {
	PHYSICAL,
	ENERGY,
	EXPLOSIVE,
	CORROSIVE,
	HAZARD
}

var amount: float = 10.0
var damage_type: DamageType = DamageType.ENERGY
var source: Node = null
var hit_position: Vector2 = Vector2.ZERO
var knockback_direction: Vector2 = Vector2.ZERO
var knockback_force: float = 0.0
var is_critical: bool = false


func _init(
	p_amount: float = 10.0,
	p_source: Node = null,
	p_type: DamageType = DamageType.ENERGY,
	p_dir: Vector2 = Vector2.ZERO,
	p_force: float = 0.0,
	p_pos: Vector2 = Vector2.ZERO,
	p_crit: bool = false
) -> void:
	amount = maxf(0.0, p_amount)
	source = p_source
	damage_type = p_type
	knockback_direction = p_dir.normalized() if p_dir != Vector2.ZERO else Vector2.ZERO
	knockback_force = maxf(0.0, p_force)
	hit_position = p_pos
	is_critical = p_crit


static func create(
	amount: float,
	source: Node = null,
	damage_type: DamageType = DamageType.ENERGY,
	knockback_dir: Vector2 = Vector2.ZERO,
	knockback_force: float = 0.0,
	hit_pos: Vector2 = Vector2.ZERO
) -> DamageData:
	return DamageData.new(amount, source, damage_type, knockback_dir, knockback_force, hit_pos)
