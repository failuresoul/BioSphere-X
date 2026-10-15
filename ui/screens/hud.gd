extends CanvasLayer
## Core Survival HUD for BioSphere-X.
## Displays real-time player health, oxygen, harvested resources, mission objectives,
## and pause overlay. Fully decoupled from world scripts via GameState event bus.

# Node References
@onready var health_bar: ProgressBar = %HealthBar
@onready var health_label: Label = %HealthLabel
@onready var oxygen_bar: ProgressBar = %OxygenBar
@onready var oxygen_label: Label = %OxygenLabel

@onready var crystal_count_label: Label = %CrystalCount
@onready var titanium_count_label: Label = %TitaniumCount
@onready var biomass_count_label: Label = %BiomassCount

@onready var objective_label: Label = %ObjectiveLabel
@onready var pause_overlay: Control = %PauseOverlay
@onready var resume_button: Button = %ResumeButton

# Warning Alert State
var _low_hp_alert: bool = false
var _low_o2_alert: bool = false
var _pulse_timer: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_connect_game_state_signals()
	_initialize_hud_values()
	
	if resume_button:
		resume_button.pressed.connect(_on_resume_pressed)


func _process(delta: float) -> void:
	_pulse_timer += delta * 4.0
	
	# Visual pulsing alerts for critical health or oxygen
	if _low_hp_alert and health_bar:
		var pulse := (sin(_pulse_timer) + 1.0) * 0.5
		health_bar.modulate = Color(1.0, 0.4 + pulse * 0.6, 0.4 + pulse * 0.6)
	elif health_bar:
		health_bar.modulate = Color.WHITE
		
	if _low_o2_alert and oxygen_bar:
		var pulse := (sin(_pulse_timer) + 1.0) * 0.5
		oxygen_bar.modulate = Color(0.4 + pulse * 0.6, 1.0, 1.0)
	elif oxygen_bar:
		oxygen_bar.modulate = Color.WHITE


func _connect_game_state_signals() -> void:
	var gs := get_node_or_null("/root/GameState")
	if not gs:
		return
	
	if gs.has_signal("health_changed") and not gs.is_connected("health_changed", _on_health_changed):
		gs.connect("health_changed", _on_health_changed)
	if gs.has_signal("oxygen_changed") and not gs.is_connected("oxygen_changed", _on_oxygen_changed):
		gs.connect("oxygen_changed", _on_oxygen_changed)
	if gs.has_signal("resource_changed") and not gs.is_connected("resource_changed", _on_resource_changed):
		gs.connect("resource_changed", _on_resource_changed)
	if gs.has_signal("objective_changed") and not gs.is_connected("objective_changed", _on_objective_changed):
		gs.connect("objective_changed", _on_objective_changed)
	if gs.has_signal("game_paused") and not gs.is_connected("game_paused", _on_game_paused):
		gs.connect("game_paused", _on_game_paused)


func _initialize_hud_values() -> void:
	var gs := get_node_or_null("/root/GameState")
	if not gs:
		return
	
	_on_health_changed(gs.get("health"), gs.get("max_health"))
	_on_oxygen_changed(gs.get("oxygen"), gs.get("max_oxygen"))
	_on_objective_changed(gs.get("current_objective"))
	_on_game_paused(gs.get("is_paused"))
	
	var res: Dictionary = gs.get("resources")
	_on_resource_changed("crystals", res.get("crystals", 0))
	_on_resource_changed("titanium", res.get("titanium", 0))
	_on_resource_changed("biomass", res.get("biomass", 0))


# ---------------------------------------------------------------------------
# Signal Event Callbacks
# ---------------------------------------------------------------------------
func _on_health_changed(current: float, max_hp: float) -> void:
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = current
	if health_label:
		health_label.text = "%d / %d" % [int(ceil(current)), int(max_hp)]
	_low_hp_alert = current < (max_hp * 0.25)


func _on_oxygen_changed(current: float, max_o2: float) -> void:
	if oxygen_bar:
		oxygen_bar.max_value = max_o2
		oxygen_bar.value = current
	if oxygen_label:
		oxygen_label.text = "%d%%" % int(ceil((current / max_o2) * 100.0))
	_low_o2_alert = current < (max_o2 * 0.20)


func _on_resource_changed(resource_id: String, count: int) -> void:
	match resource_id:
		"crystals":
			if crystal_count_label:
				crystal_count_label.text = "%d" % count
		"titanium":
			if titanium_count_label:
				titanium_count_label.text = "%d" % count
		"biomass":
			if biomass_count_label:
				biomass_count_label.text = "%d" % count


func _on_objective_changed(new_text: String) -> void:
	if objective_label:
		objective_label.text = new_text


func _on_game_paused(paused: bool) -> void:
	if pause_overlay:
		pause_overlay.visible = paused
		if paused and resume_button:
			resume_button.grab_focus()


func _on_resume_pressed() -> void:
	var gs := get_node_or_null("/root/GameState")
	if gs and gs.has_method("set_paused"):
		gs.call("set_paused", false)
