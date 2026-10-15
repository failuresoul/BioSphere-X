extends Node
## Central Game State & Event Bus for BioSphere-X.
## Manages player vitality (health, oxygen), resource inventory, mission objectives,
## and pause states without directly coupling UI to game world objects.

signal health_changed(current: float, max_health: float)
signal oxygen_changed(current: float, max_oxygen: float)
signal resource_changed(resource_id: String, count: int)
signal objective_changed(text: String)
signal game_paused(paused: bool)

# Player Vitality Stats
var max_health: float = 100.0
var health: float = 100.0

var max_oxygen: float = 100.0
var oxygen: float = 100.0
var oxygen_depletion_rate: float = 1.0 # Units per second in harsh alien atmosphere
var is_oxygen_depleted: bool = false

# Resource Inventory
var resources: Dictionary = {
	"crystals": 0,
	"titanium": 0,
	"biomass": 0
}

# Mission Objectives
var current_objective: String = "SURVEY SURFACE // Gather 3 Energy Crystals from alien deposits."

# Pause State
var is_paused: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if is_paused:
		return
	
	# Deplete oxygen in alien environment
	if oxygen > 0.0:
		oxygen = maxf(0.0, oxygen - oxygen_depletion_rate * delta)
		oxygen_changed.emit(oxygen, max_oxygen)
		if oxygen <= 0.0 and not is_oxygen_depleted:
			is_oxygen_depleted = true
			objective_changed.emit("CRITICAL WARNING // Oxygen depleted! Seek shelter or life support.")
	else:
		# Suffocation damage when out of oxygen (1 damage every 2 seconds)
		damage_player(2.5 * delta)


func _unhandled_input(event: InputEvent) -> void:
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


func damage_player(amount: float) -> void:
	if amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	health_changed.emit(health, max_health)


func heal_player(amount: float) -> void:
	if amount <= 0.0:
		return
	health = minf(max_health, health + amount)
	health_changed.emit(health, max_health)


func set_oxygen(amount: float, max_o2: float = -1.0) -> void:
	if max_o2 > 0.0:
		max_oxygen = max_o2
	oxygen = clampf(amount, 0.0, max_oxygen)
	is_oxygen_depleted = oxygen <= 0.0
	oxygen_changed.emit(oxygen, max_oxygen)


func refill_oxygen(amount: float = -1.0) -> void:
	if amount < 0.0:
		oxygen = max_oxygen
	else:
		oxygen = minf(max_oxygen, oxygen + amount)
	is_oxygen_depleted = oxygen <= 0.0
	oxygen_changed.emit(oxygen, max_oxygen)


# ---------------------------------------------------------------------------
# Resource Inventory API
# ---------------------------------------------------------------------------
func add_resource(resource_id: String, amount: int = 1) -> void:
	if not resources.has(resource_id):
		resources[resource_id] = 0
	resources[resource_id] += amount
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
# Pause System API
# ---------------------------------------------------------------------------
func toggle_pause() -> void:
	set_paused(not is_paused)


func set_paused(paused: bool) -> void:
	if is_paused == paused:
		return
	is_paused = paused
	get_tree().paused = is_paused
	game_paused.emit(is_paused)
