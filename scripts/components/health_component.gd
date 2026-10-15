extends Node
class_name HealthComponent
## Reusable health and vitality component for entities (Player, Enemies, Bosses).
## Manages health values, damage mitigation, healing, and life/death signals.

signal health_changed(current: float, max_health: float)
signal damaged(amount: float, source: Node)
signal healed(amount: float)
signal died()

@export var max_health: float = 100.0:
	set(value):
		max_health = maxf(1.0, value)
		current_health = clampf(current_health, 0.0, max_health)
		health_changed.emit(current_health, max_health)

@export var invulnerability_time: float = 0.4
@export var is_invulnerable: bool = false

var current_health: float = 100.0
var _invuln_timer: float = 0.0


func _ready() -> void:
	current_health = max_health


func _process(delta: float) -> void:
	if _invuln_timer > 0.0:
		_invuln_timer = maxf(0.0, _invuln_timer - delta)


func is_alive() -> bool:
	return current_health > 0.0


func is_dead() -> bool:
	return current_health <= 0.0


func get_health_ratio() -> float:
	return current_health / max_health if max_health > 0.0 else 0.0


func damage(amount: float, source: Node = null) -> bool:
	if not is_alive() or is_invulnerable or _invuln_timer > 0.0:
		return false
	
	var actual_damage: float = maxf(0.0, amount)
	if actual_damage <= 0.0:
		return false
	
	# Clamp strictly between 0 and max_health
	current_health = clampf(current_health - actual_damage, 0.0, max_health)
	_invuln_timer = invulnerability_time
	
	damaged.emit(actual_damage, source)
	health_changed.emit(current_health, max_health)
	
	if current_health <= 0.0:
		died.emit()
	
	return true


func heal(amount: float) -> void:
	if not is_alive():
		return
	
	var actual_heal: float = maxf(0.0, amount)
	if actual_heal <= 0.0:
		return
	
	var old_health := current_health
	current_health = clampf(current_health + actual_heal, 0.0, max_health)
	var diff: float = current_health - old_health
	if diff > 0.0:
		healed.emit(diff)
		health_changed.emit(current_health, max_health)


func set_health_percentage(pct: float) -> void:
	var target: float = clampf(pct, 0.0, 1.0) * max_health
	current_health = target
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		died.emit()


func reset() -> void:
	current_health = max_health
	_invuln_timer = 0.0
	health_changed.emit(current_health, max_health)
