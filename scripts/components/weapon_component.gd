class_name WeaponComponent
extends Node2D
## Reusable, Configurable Sci-Fi Weapon & Tool Component for BioSphere-X.
## Handles firing rates, cooldowns, resource costs (suit energy), ballistics,
## projectile instantiation, and decoupled combat signals.

signal weapon_fired(projectile: Node2D, direction: Vector2)
signal cooldown_started(duration: float)
signal cooldown_finished()
signal energy_insufficient(required: float, available: float)

@export_group("Identity & Stats")
@export var weapon_name: String = "Plasma Pulse Blaster"
@export var damage: float = 25.0
@export var attack_range: float = 420.0
@export var projectile_speed: float = 520.0
@export var attack_cooldown: float = 0.32
@export var energy_cost: float = 8.0
@export var knockback_force: float = 120.0
@export var max_pierce: int = 1

@export_group("Visuals")
@export var projectile_color: Color = Color(0.12, 0.88, 1.0)
@export var muzzle_flash_color: Color = Color(0.5, 0.95, 1.0)
@export var projectile_scene: PackedScene = preload("res://scenes/items/energy_projectile.tscn")

@export_group("Energy Consumption")
@export var use_global_energy: bool = true
@export var local_energy: float = 100.0
@export var max_local_energy: float = 100.0
@export var local_energy_recharge_rate: float = 20.0

var _cooldown_timer: float = 0.0
var _was_on_cooldown: bool = false


func _process(delta: float) -> void:
	if not use_global_energy and local_energy < max_local_energy:
		local_energy = minf(max_local_energy, local_energy + local_energy_recharge_rate * delta)
		
	if _cooldown_timer > 0.0:
		_cooldown_timer = maxf(0.0, _cooldown_timer - delta)
		if _cooldown_timer <= 0.0 and _was_on_cooldown:
			_was_on_cooldown = false
			cooldown_finished.emit()


func can_attack() -> bool:
	if _cooldown_timer > 0.0:
		return false
	
	if energy_cost > 0.0:
		if use_global_energy:
			var gs := get_node_or_null("/root/GameState")
			if gs and gs.has_method("get_energy"):
				var cur_energy: float = gs.call("get_energy")
				if cur_energy < energy_cost:
					return false
		else:
			if local_energy < energy_cost:
				return false
	
	return true


func attack(direction: Vector2, spawn_pos: Vector2 = Vector2.ZERO, attacker: Node = null) -> Node2D:
	if not can_attack():
		# Trigger insufficient energy signal if cooldown is ready but energy is low
		if _cooldown_timer <= 0.0 and energy_cost > 0.0:
			if use_global_energy:
				var gs := get_node_or_null("/root/GameState")
				if gs and gs.has_method("get_energy"):
					energy_insufficient.emit(energy_cost, gs.call("get_energy"))
			else:
				energy_insufficient.emit(energy_cost, local_energy)
		return null
	
	# Consume resource cost if appropriate
	if energy_cost > 0.0:
		if use_global_energy:
			var gs := get_node_or_null("/root/GameState")
			if gs and gs.has_method("use_energy"):
				var success: bool = gs.call("use_energy", energy_cost)
				if not success:
					return null
		else:
			if local_energy < energy_cost:
				return null
			local_energy -= energy_cost
	
	var dir := direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	var fire_origin := spawn_pos if spawn_pos != Vector2.ZERO else global_position
	
	# Instantiate and initialize projectile
	var proj_inst: Node2D = null
	if projectile_scene:
		proj_inst = projectile_scene.instantiate() as Node2D
	else:
		var proj_script: Script = load("res://scenes/items/energy_projectile.gd")
		proj_inst = proj_script.new()
	
	if proj_inst and proj_inst.has_method("setup"):
		proj_inst.call("setup", dir, attacker, damage, projectile_speed, attack_range, projectile_color)
		proj_inst.set("knockback_force", knockback_force)
		proj_inst.set("pierce_count", max_pierce)
	
	proj_inst.global_position = fire_origin
	
	# Determine target container: world parent or tree root
	var world_container: Node = null
	if attacker and attacker.get_parent():
		world_container = attacker.get_parent()
	elif get_parent():
		world_container = get_parent()
	else:
		world_container = get_tree().current_scene
	
	if world_container:
		world_container.add_child(proj_inst)
	else:
		get_tree().root.add_child(proj_inst)
	
	# Start cooldown
	_cooldown_timer = attack_cooldown
	_was_on_cooldown = true
	cooldown_started.emit(attack_cooldown)
	weapon_fired.emit(proj_inst, dir)
	
	return proj_inst


func get_cooldown_ratio() -> float:
	return clampf(_cooldown_timer / attack_cooldown, 0.0, 1.0) if attack_cooldown > 0.0 else 0.0


func reset_cooldown() -> void:
	_cooldown_timer = 0.0
	_was_on_cooldown = false
