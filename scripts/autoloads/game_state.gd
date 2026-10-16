extends Node
## Central Game State & Event Bus for BioSphere-X.
## Manages player vitality (health, oxygen), resource inventory, mission objectives,
## pause states, and game-over transitions.

signal health_changed(current: float, max_health: float)
signal oxygen_changed(current: float, max_oxygen: float)
signal oxygen_low_warning(is_low: bool)
signal oxygen_refill_status_changed(is_refilling: bool)
signal energy_changed(current: float, max_energy: float)
signal energy_depleted()
signal resource_changed(resource_id: String, count: int)
signal objective_changed(text: String)
signal game_paused(paused: bool)
signal game_over_triggered()
signal interaction_prompt_changed(prompt: String)
signal tutorial_step_changed(step_index: int, title: String, description: String, is_complete: bool)

# Player Vitality Stats
var max_health: float = 100.0
var health: float = 100.0

var max_oxygen: float = 100.0
var oxygen: float = 100.0

var max_energy: float = 100.0
var energy: float = 100.0

# Configurable Survival & Atmosphere Parameters
@export var oxygen_depletion_rate: float = 1.5      # Units consumed per second during surface exploration
@export var suffocation_damage_rate: float = 4.0    # Gradual health damage per second when oxygen == 0
@export var oxygen_refill_rate: float = 25.0        # Units replenished per second inside safe zones or stations
@export var low_oxygen_threshold: float = 25.0      # Percentage threshold that triggers audio/visual warning
@export var energy_recharge_rate: float = 24.0      # Energy points restored per second
@export var energy_recharge_delay: float = 0.35     # Pause before recharge begins after firing

var _energy_recharge_timer: float = 0.0

var is_oxygen_depleted: bool = false
var is_low_oxygen: bool = false
var is_oxygen_refilling: bool = false

# Resource Inventory
var resources: Dictionary = {
	"crystals": 0,
	"titanium": 0,
	"biomass": 0,
	"oxygen_cells": 0
}

# Mission Objectives
var current_objective: String = "SURVEY SURFACE // Gather 3 Energy Crystals from alien deposits."

# State Flags
var is_paused: bool = false
var is_game_over: bool = false
var failure_count: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	# Oxygen timer and depletion strictly freeze when paused or in game-over state
	if is_paused or is_game_over:
		return
	
	if is_oxygen_refilling:
		# Replenish life support atmosphere smoothly inside safe zones or stations
		refill_oxygen(oxygen_refill_rate * delta)
	elif oxygen > 0.0:
		# Gradual consumption in harsh alien atmosphere
		oxygen = maxf(0.0, oxygen - oxygen_depletion_rate * delta)
		oxygen_changed.emit(oxygen, max_oxygen)
		_check_oxygen_warnings()
	else:
		# Configurable suffocation damage over time (prevents arbitrary instant death)
		damage_player(suffocation_damage_rate * delta)
	
	# Suit energy recharge
	if _energy_recharge_timer > 0.0:
		_energy_recharge_timer = maxf(0.0, _energy_recharge_timer - delta)
	elif energy < max_energy:
		energy = minf(max_energy, energy + energy_recharge_rate * delta)
		energy_changed.emit(energy, max_energy)



func _check_oxygen_warnings() -> void:
	var pct: float = (oxygen / max_oxygen) * 100.0 if max_oxygen > 0.0 else 0.0
	var low: bool = pct <= low_oxygen_threshold and pct > 0.0
	
	if low != is_low_oxygen:
		is_low_oxygen = low
		oxygen_low_warning.emit(is_low_oxygen)
		if is_low_oxygen:
			objective_changed.emit("WARNING // Oxygen levels low! Return to Safe Zone or Life Support Station.")
	
	if oxygen <= 0.0 and not is_oxygen_depleted:
		is_oxygen_depleted = true
		objective_changed.emit("CRITICAL HAZARD // Oxygen depleted! Taking suffocation damage.")


func _unhandled_input(event: InputEvent) -> void:
	if is_game_over:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_P:
			toggle_pause()


# ---------------------------------------------------------------------------
# Vitality Management API
# ---------------------------------------------------------------------------
func set_health(cur: float, max_hp: float = -1.0) -> void:
	if max_hp > 0.0:
		max_health = max_hp
	health = clampf(cur, 0.0, max_health)
	health_changed.emit(health, max_health)
	if health <= 0.0 and not is_game_over:
		trigger_game_over()


func damage_player(amount: float) -> void:
	if amount <= 0.0 or is_game_over:
		return
	health = maxf(0.0, health - amount)
	health_changed.emit(health, max_health)
	if health <= 0.0 and not is_game_over:
		trigger_game_over()


func heal_player(amount: float) -> void:
	if amount <= 0.0 or is_game_over:
		return
	health = minf(max_health, health + amount)
	health_changed.emit(health, max_health)


func set_oxygen(amount: float, max_o2: float = -1.0) -> void:
	if max_o2 > 0.0:
		max_oxygen = max_o2
	oxygen = clampf(amount, 0.0, max_oxygen)
	is_oxygen_depleted = oxygen <= 0.0
	var pct: float = (oxygen / max_oxygen) * 100.0 if max_oxygen > 0.0 else 0.0
	var low: bool = pct <= low_oxygen_threshold and pct > 0.0
	if low != is_low_oxygen:
		is_low_oxygen = low
		oxygen_low_warning.emit(is_low_oxygen)
	oxygen_changed.emit(oxygen, max_oxygen)


func refill_oxygen(amount: float = -1.0) -> void:
	if amount < 0.0:
		oxygen = max_oxygen
	else:
		oxygen = minf(max_oxygen, oxygen + amount)
	
	if oxygen > 0.0:
		is_oxygen_depleted = false
	var pct: float = (oxygen / max_oxygen) * 100.0 if max_oxygen > 0.0 else 0.0
	if pct > low_oxygen_threshold and is_low_oxygen:
		is_low_oxygen = false
		oxygen_low_warning.emit(false)
	
	oxygen_changed.emit(oxygen, max_oxygen)


func set_oxygen_refilling(refilling: bool, rate: float = -1.0) -> void:
	if rate > 0.0:
		oxygen_refill_rate = rate
	if is_oxygen_refilling != refilling:
		is_oxygen_refilling = refilling
		oxygen_refill_status_changed.emit(is_oxygen_refilling)


# ---------------------------------------------------------------------------
# Suit Energy Management API
# ---------------------------------------------------------------------------
func use_energy(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if energy <= 0.0:
		energy_depleted.emit()
		return false
	
	var actual_use: float = minf(energy, amount)
	energy = maxf(0.0, energy - actual_use)
	_energy_recharge_timer = energy_recharge_delay
	energy_changed.emit(energy, max_energy)
	if energy <= 0.0:
		energy_depleted.emit()
	return true


func refill_energy(amount: float = -1.0) -> void:
	if amount < 0.0:
		energy = max_energy
	else:
		energy = minf(max_energy, energy + amount)
	energy_changed.emit(energy, max_energy)


func get_energy() -> float:
	return energy


func get_max_energy() -> float:
	return max_energy


# ---------------------------------------------------------------------------
# Resource Inventory API

# ---------------------------------------------------------------------------
func add_resource(resource_id: String, amount: int = 1) -> void:
	if is_game_over:
		return
	if not resources.has(resource_id):
		resources[resource_id] = 0
	resources[resource_id] += amount
	
	# Handle aliases for backwards compatibility
	if resource_id == "metal":
		resources["titanium"] = resources.get("titanium", 0) + amount
		resource_changed.emit("titanium", resources["titanium"])
	elif resource_id == "titanium":
		resources["metal"] = resources["titanium"]
	elif resource_id == "samples":
		resources["biomass"] = resources.get("biomass", 0) + amount
		resource_changed.emit("biomass", resources["biomass"])
	elif resource_id == "biomass":
		resources["samples"] = resources["biomass"]
		
	resource_changed.emit(resource_id, resources[resource_id])
	_check_objective_progress()


func get_resource(resource_id: String) -> int:
	return resources.get(resource_id, 0)


func _check_objective_progress() -> void:
	if resources.get("crystals", 0) >= 3 and not "Scan" in current_objective:
		set_objective("PRIMARY GOAL COMPLETE // Scan Research Debris in North-East quadrant.")


# ---------------------------------------------------------------------------
# Objective API
# ---------------------------------------------------------------------------
func set_objective(text: String) -> void:
	current_objective = text
	objective_changed.emit(current_objective)


# ---------------------------------------------------------------------------
# Pause & Game Over Lifecycle
# ---------------------------------------------------------------------------
func toggle_pause() -> void:
	if is_game_over:
		return
	set_paused(not is_paused)


func set_paused(paused: bool) -> void:
	if is_game_over or is_paused == paused:
		return
	is_paused = paused
	get_tree().paused = is_paused
	game_paused.emit(is_paused)


func trigger_game_over() -> void:
	if is_game_over:
		return
	is_game_over = true
	failure_count += 1
	is_paused = false
	get_tree().paused = false
	print("BioSphere-X: Game Over — Astronaut eliminated. Total failures: %d" % failure_count)
	game_over_triggered.emit()


func get_failure_count() -> int:
	return failure_count


func record_failure() -> void:
	failure_count += 1


func reset_failure_count() -> void:
	failure_count = 0


func restart_game() -> void:
	is_game_over = false
	is_paused = false
	get_tree().paused = false
	
	health = max_health
	oxygen = max_oxygen
	energy = max_energy
	is_oxygen_depleted = false
	is_low_oxygen = false
	is_oxygen_refilling = false
	resources = {"crystals": 0, "titanium": 0, "biomass": 0, "oxygen_cells": 0}
	current_objective = "SURVEY SURFACE // Gather 3 Energy Crystals from alien deposits."
	
	health_changed.emit(health, max_health)
	oxygen_changed.emit(oxygen, max_oxygen)
	energy_changed.emit(energy, max_energy)

	resource_changed.emit("crystals", 0)
	resource_changed.emit("titanium", 0)
	resource_changed.emit("biomass", 0)
	resource_changed.emit("oxygen_cells", 0)
	objective_changed.emit(current_objective)
	
	get_tree().change_scene_to_file.call_deferred("res://scenes/world/game_world.tscn")
