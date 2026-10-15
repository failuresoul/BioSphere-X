extends CanvasLayer
## Core Survival HUD for BioSphere-X.
## Displays real-time player health, oxygen, harvested resources, mission objectives,
## damage screen flash effects, procedural audio cues, pause, and game-over overlays.

# Node References
@onready var health_bar: ProgressBar = %HealthBar
@onready var health_label: Label = %HealthLabel
@onready var oxygen_bar: ProgressBar = %OxygenBar
@onready var oxygen_label: Label = %OxygenLabel

@onready var crystal_count_label: Label = %CrystalCount
@onready var titanium_count_label: Label = %TitaniumCount
@onready var biomass_count_label: Label = %BiomassCount
@onready var oxygen_cell_count_label: Label = %OxygenCellCount

@onready var objective_label: Label = %ObjectiveLabel
@onready var pause_overlay: Control = %PauseOverlay
@onready var resume_button: Button = %ResumeButton

@onready var game_over_overlay: Control = %GameOverOverlay
@onready var restart_button: Button = %RestartButton
@onready var damage_vignette: ColorRect = %DamageVignette
@onready var audio_player: AudioStreamPlayer = %AudioPlayer

@onready var oxygen_status_label: Label = %OxygenStatusLabel

@onready var contextual_prompt: PanelContainer = %ContextualPrompt
@onready var prompt_label: Label = %PromptLabel

@onready var tutorial_banner: PanelContainer = %TutorialBanner
@onready var tutorial_step_label: Label = %TutorialStepLabel
@onready var tutorial_progress_label: Label = %TutorialProgressLabel
@onready var tutorial_desc_label: Label = %TutorialDescLabel

@onready var dev_nav_button: Button = %DevNavButton
@onready var dev_nav_menu: PanelContainer = %DevNavigationMenu

# Warning & Feedback State
var _low_hp_alert: bool = false
var _low_o2_alert: bool = false
var _is_refilling_o2: bool = false
var _pulse_timer: float = 0.0
var _damage_flash_alpha: float = 0.0
var _last_health: float = 100.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_procedural_audio()
	_connect_game_state_signals()
	_initialize_hud_values()
	
	if resume_button:
		resume_button.pressed.connect(_on_resume_pressed)
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)
	if dev_nav_button and dev_nav_menu:
		dev_nav_button.pressed.connect(func():
			if dev_nav_menu.has_method("toggle_visibility"):
				dev_nav_menu.call("toggle_visibility")
			else:
				dev_nav_menu.visible = not dev_nav_menu.visible
		)


func _setup_procedural_audio() -> void:
	if not audio_player:
		audio_player = AudioStreamPlayer.new()
		audio_player.name = "AudioPlayer"
		add_child(audio_player)
	
	# Generate procedural synthetic alert tone (sample sine pulse)
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050
	gen.buffer_length = 0.1
	audio_player.stream = gen


func _process(delta: float) -> void:
	_pulse_timer += delta * 4.0
	
	# Fade screen damage vignette
	if _damage_flash_alpha > 0.0:
		_damage_flash_alpha = maxf(0.0, _damage_flash_alpha - delta * 2.5)
		if damage_vignette:
			damage_vignette.color = Color(0.95, 0.15, 0.20, _damage_flash_alpha)
	
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
	
	# Oxygen Status Badge (Recharging or Critical Warning)
	if oxygen_status_label:
		if _is_refilling_o2:
			oxygen_status_label.visible = true
			oxygen_status_label.text = "▲ LIFE SUPPORT RECHARGING"
			oxygen_status_label.modulate = Color(0.15, 1.0, 0.75)
		elif _low_o2_alert:
			oxygen_status_label.visible = true
			var p := (sin(_pulse_timer * 2.0) + 1.0) * 0.5
			oxygen_status_label.text = "⚠ O2 CRITICAL // SEEK STATION"
			oxygen_status_label.modulate = Color(1.0, 0.35 + p * 0.35, 0.35 + p * 0.35)
		else:
			oxygen_status_label.visible = false


func _connect_game_state_signals() -> void:
	var gs := get_node_or_null("/root/GameState")
	if not gs:
		return
	
	if gs.has_signal("health_changed") and not gs.is_connected("health_changed", _on_health_changed):
		gs.connect("health_changed", _on_health_changed)
	if gs.has_signal("oxygen_changed") and not gs.is_connected("oxygen_changed", _on_oxygen_changed):
		gs.connect("oxygen_changed", _on_oxygen_changed)
	if gs.has_signal("oxygen_low_warning") and not gs.is_connected("oxygen_low_warning", _on_oxygen_low_warning):
		gs.connect("oxygen_low_warning", _on_oxygen_low_warning)
	if gs.has_signal("oxygen_refill_status_changed") and not gs.is_connected("oxygen_refill_status_changed", _on_oxygen_refill_status_changed):
		gs.connect("oxygen_refill_status_changed", _on_oxygen_refill_status_changed)
	if gs.has_signal("resource_changed") and not gs.is_connected("resource_changed", _on_resource_changed):
		gs.connect("resource_changed", _on_resource_changed)
	if gs.has_signal("objective_changed") and not gs.is_connected("objective_changed", _on_objective_changed):
		gs.connect("objective_changed", _on_objective_changed)
	if gs.has_signal("game_paused") and not gs.is_connected("game_paused", _on_game_paused):
		gs.connect("game_paused", _on_game_paused)
	if gs.has_signal("game_over_triggered") and not gs.is_connected("game_over_triggered", _on_game_over):
		gs.connect("game_over_triggered", _on_game_over)
	if gs.has_signal("interaction_prompt_changed") and not gs.is_connected("interaction_prompt_changed", _on_interaction_prompt_changed):
		gs.connect("interaction_prompt_changed", _on_interaction_prompt_changed)
	if gs.has_signal("tutorial_step_changed") and not gs.is_connected("tutorial_step_changed", _on_tutorial_step_changed):
		gs.connect("tutorial_step_changed", _on_tutorial_step_changed)


func _initialize_hud_values() -> void:
	var gs := get_node_or_null("/root/GameState")
	if not gs:
		return
	
	_last_health = gs.get("health")
	_on_health_changed(gs.get("health"), gs.get("max_health"))
	_on_oxygen_changed(gs.get("oxygen"), gs.get("max_oxygen"))
	_on_objective_changed(gs.get("current_objective"))
	_on_game_paused(gs.get("is_paused"))
	
	var res: Dictionary = gs.get("resources")
	_on_resource_changed("crystals", res.get("crystals", 0))
	_on_resource_changed("titanium", res.get("titanium", 0))
	_on_resource_changed("biomass", res.get("biomass", 0))
	_on_resource_changed("oxygen_cells", res.get("oxygen_cells", 0))


# ---------------------------------------------------------------------------
# Signal Event Callbacks & Damage Feedback
# ---------------------------------------------------------------------------
func _on_health_changed(current: float, max_hp: float) -> void:
	if current < _last_health and _last_health > 0.0:
		# Trigger Screen-Space Red Damage Vignette & Audio Cue
		_damage_flash_alpha = 0.45
		_play_damage_sound()
	_last_health = current
	
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = current
	if health_label:
		health_label.text = "%d / %d" % [int(ceil(current)), int(max_hp)]
	_low_hp_alert = current < (max_hp * 0.25) and current > 0.0


func _play_damage_sound() -> void:
	if not audio_player or not audio_player.stream is AudioStreamGenerator:
		return
	
	if not audio_player.playing:
		audio_player.play()
	
	var playback = audio_player.get_stream_playback()
	if playback:
		var frames: int = playback.get_frames_available()
		for i in mini(frames, 300):
			var sample: float = sin(float(i) * 0.25) * 0.35
			playback.push_frame(Vector2(sample, sample))



func _on_oxygen_changed(current: float, max_o2: float) -> void:
	if oxygen_bar:
		oxygen_bar.max_value = max_o2
		oxygen_bar.value = current
	if oxygen_label:
		oxygen_label.text = "%d%%" % int(ceil((current / max_o2) * 100.0))
	_low_o2_alert = current < (max_o2 * 0.25) and current > 0.0


func _on_oxygen_low_warning(is_low: bool) -> void:
	if is_low and not _low_o2_alert:
		_play_low_oxygen_sound()
	_low_o2_alert = is_low


func _on_oxygen_refill_status_changed(is_refilling: bool) -> void:
	_is_refilling_o2 = is_refilling


func _play_low_oxygen_sound() -> void:
	if not audio_player or not audio_player.stream is AudioStreamGenerator:
		return
	if not audio_player.playing:
		audio_player.play()
	var playback = audio_player.get_stream_playback()
	if playback:
		var frames: int = playback.get_frames_available()
		for i in mini(frames, 400):
			var sample: float = sin(float(i) * 0.5) * 0.25
			playback.push_frame(Vector2(sample, sample))



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
		"oxygen_cells":
			if oxygen_cell_count_label:
				oxygen_cell_count_label.text = "%d" % count


func _on_objective_changed(new_text: String) -> void:
	if objective_label:
		objective_label.text = new_text


func _on_interaction_prompt_changed(prompt_text: String) -> void:
	if not contextual_prompt:
		return
	if prompt_text.is_empty():
		contextual_prompt.visible = false
	else:
		contextual_prompt.visible = true
		if prompt_label:
			prompt_label.text = prompt_text


func _on_tutorial_step_changed(step: int, title: String, desc: String, is_complete: bool) -> void:
	if tutorial_step_label:
		tutorial_step_label.text = title
	if tutorial_desc_label:
		tutorial_desc_label.text = desc
	if tutorial_progress_label:
		var p_str := ""
		for i in 4:
			p_str += "● " if i <= step else "○ "
		tutorial_progress_label.text = p_str.strip_edges()
	
	if is_complete and tutorial_banner:
		tutorial_banner.modulate = Color(0.3, 1.0, 0.6)


func _on_game_paused(paused: bool) -> void:
	if pause_overlay and not (game_over_overlay and game_over_overlay.visible):
		pause_overlay.visible = paused
		if paused and resume_button:
			resume_button.grab_focus()


func _on_game_over() -> void:
	if pause_overlay:
		pause_overlay.visible = false
	if game_over_overlay:
		game_over_overlay.visible = true
		if restart_button:
			restart_button.grab_focus()


func _on_resume_pressed() -> void:
	var gs := get_node_or_null("/root/GameState")
	if gs and gs.has_method("set_paused"):
		gs.call("set_paused", false)


func _on_restart_pressed() -> void:
	if game_over_overlay:
		game_over_overlay.visible = false
	var gs := get_node_or_null("/root/GameState")
	if gs and gs.has_method("restart_game"):
		gs.call("restart_game")
