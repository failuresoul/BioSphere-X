extends CanvasLayer
## Core Survival HUD for BioSphere-X.
## Displays real-time player health, oxygen, harvested resources, mission objectives,
## damage screen flash effects, procedural audio cues, pause, and game-over overlays.

# Node References
@onready var health_bar: ProgressBar = %HealthBar
@onready var health_label: Label = %HealthLabel
@onready var oxygen_bar: ProgressBar = %OxygenBar
@onready var oxygen_label: Label = %OxygenLabel
@onready var energy_bar: ProgressBar = %EnergyBar
@onready var energy_label: Label = %EnergyLabel

@onready var crystal_count_label: Label = %CrystalCount
@onready var titanium_count_label: Label = %TitaniumCount
@onready var biomass_count_label: Label = %BiomassCount
@onready var oxygen_cell_count_label: Label = %OxygenCellCount

@onready var objective_label: Label = %ObjectiveLabel
@onready var pause_overlay: Control = %PauseOverlay
@onready var resume_button: Button = %ResumeButton
@onready var save_game_button: Button = %SaveGameButton
@onready var pause_restart_button: Button = %PauseRestartButton
@onready var return_menu_button: Button = %ReturnMenuButton
@onready var save_feedback_label: Label = %SaveFeedbackLabel

@onready var game_over_overlay: Control = %GameOverOverlay
@onready var restart_button: Button = %RestartButton
@onready var game_over_menu_button: Button = %GameOverMenuButton
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
@onready var inventory_button: Button = %InventoryButton
@onready var inventory_dialog: PanelContainer = %InventoryCraftingDialog
@onready var build_menu_button: Button = %BuildMenuButton
@onready var construction_menu: PanelContainer = %ConstructionMenu
@onready var terminal_button: Button = %TerminalButton
@onready var help_button: Button = %HelpButton
@onready var command_terminal: PanelContainer = %CommandTerminal
@onready var planet_selection_screen: Control = %PlanetSelectionScreen

# Waypoint Compass & Survival Field Guide UI
@onready var waypoint_label: Label = %WaypointLabel
@onready var biome_telemetry_label: Label = get_node_or_null("%BiomeTelemetryLabel")
@onready var help_modal_overlay: Control = %HelpModalOverlay
@onready var help_content_label: RichTextLabel = %HelpContentLabel
@onready var help_close_btn: Button = %HelpCloseBtn
var _waypoint_update_timer: float = 0.0

# AI Story & Narrative Transmission UI
@onready var respawn_base_button: Button = get_node_or_null("%RespawnBaseButton")
@onready var story_log_button: Button = get_node_or_null("%StoryLogButton")
@onready var story_modal_overlay: Control = get_node_or_null("%StoryModalOverlay")
@onready var story_header: Label = get_node_or_null("%StoryHeader")
@onready var story_sub_header: Label = get_node_or_null("%StorySubHeader")
@onready var story_content_label: RichTextLabel = get_node_or_null("%StoryContentLabel")
@onready var story_accept_btn: Button = get_node_or_null("%StoryAcceptBtn")
@onready var story_guide_btn: Button = get_node_or_null("%StoryGuideBtn")
@onready var story_close_btn: Button = get_node_or_null("%StoryCloseBtn")

# Mission Telemetry & Feedback UI
@onready var mission_title_tag: Label = %MissionTitleTag
@onready var objective_type_badge: Label = %ObjectiveTypeBadge
@onready var mission_state_badge: Label = %MissionStateBadge
@onready var mission_progress_bar: ProgressBar = %MissionProgressBar
@onready var mission_progress_label: Label = %MissionProgressLabel

@onready var feedback_banner: PanelContainer = %MissionFeedbackBanner
@onready var feedback_title_label: Label = %FeedbackTitleLabel
@onready var feedback_desc_label: Label = %FeedbackDescLabel
@onready var feedback_rewards_label: Label = %FeedbackRewardsLabel

# Research Base Terminal Modal UI
@onready var terminal_modal_overlay: Control = %TerminalModalOverlay
@onready var terminal_header: Label = %TerminalHeader
@onready var terminal_sub_header: Label = %TerminalSubHeader
@onready var terminal_content_label: RichTextLabel = %TerminalContentLabel
@onready var terminal_action_btn1: Button = %TerminalActionBtn1
@onready var terminal_action_btn2: Button = %TerminalActionBtn2
@onready var terminal_close_btn: Button = %TerminalCloseBtn
var _current_terminal_mode: String = ""

# Warning & Feedback State
var _low_hp_alert: bool = false
var _low_o2_alert: bool = false
var _is_refilling_o2: bool = false
var _pulse_timer: float = 0.0
var _damage_flash_alpha: float = 0.0
var _last_health: float = 100.0
var _feedback_banner_timer: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("hud")
	_setup_procedural_audio()
	_connect_game_state_signals()
	_connect_mission_manager_signals()
	_connect_rule_engine_signals()
	_initialize_hud_values()
	
	if resume_button:
		resume_button.pressed.connect(_on_resume_pressed)
	if save_game_button:
		save_game_button.pressed.connect(_on_save_game_pressed)
	if pause_restart_button:
		pause_restart_button.pressed.connect(_on_restart_pressed)
	if return_menu_button:
		return_menu_button.pressed.connect(_on_return_menu_pressed)
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)
	if game_over_menu_button:
		game_over_menu_button.pressed.connect(_on_return_menu_pressed)
	if terminal_close_btn:
		terminal_close_btn.pressed.connect(close_terminal_modal)
	if terminal_action_btn1:
		terminal_action_btn1.pressed.connect(_on_terminal_action1_pressed)
	if terminal_action_btn2:
		terminal_action_btn2.pressed.connect(_on_terminal_action2_pressed)
	if dev_nav_button and dev_nav_menu:
		dev_nav_button.pressed.connect(func():
			if dev_nav_menu.has_method("toggle_visibility"):
				dev_nav_menu.call("toggle_visibility")
			else:
				dev_nav_menu.visible = not dev_nav_menu.visible
		)
	if inventory_button and inventory_dialog:
		inventory_button.pressed.connect(func():
			if inventory_dialog.has_method("toggle_visibility"):
				inventory_dialog.call("toggle_visibility")
			else:
				inventory_dialog.visible = not inventory_dialog.visible
		)
	if build_menu_button and construction_menu:
		build_menu_button.pressed.connect(func():
			if construction_menu.has_method("toggle_menu"):
				construction_menu.call("toggle_menu")
			else:
				construction_menu.visible = not construction_menu.visible
		)
	if terminal_button and command_terminal:
		terminal_button.pressed.connect(func():
			if command_terminal.has_method("toggle_terminal"):
				command_terminal.call("toggle_terminal")
			else:
				command_terminal.visible = not command_terminal.visible
		)
	if help_button:
		help_button.pressed.connect(toggle_help_manual)
	if help_close_btn:
		help_close_btn.pressed.connect(close_help_manual)
	if respawn_base_button:
		respawn_base_button.pressed.connect(_on_respawn_base_pressed)
	if story_log_button:
		story_log_button.pressed.connect(open_story_modal)
	if story_close_btn:
		story_close_btn.pressed.connect(close_story_modal)
	if story_accept_btn:
		story_accept_btn.pressed.connect(close_story_modal)
	if story_guide_btn:
		story_guide_btn.pressed.connect(func():
			close_story_modal()
			open_help_manual()
		)
	_setup_help_content()
	
	# Initial AURA-7 AI Mission Transmission on fresh session launch
	get_tree().create_timer(0.4).timeout.connect(func():
		var gs = get_node_or_null("/root/GameState")
		if gs and not gs.has_meta("intro_story_shown"):
			gs.set_meta("intro_story_shown", true)
			open_story_modal()
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
	
	# Animated pulse glow on active mission badge
	if mission_state_badge and mission_state_badge.visible:
		var p_badge := (sin(_pulse_timer * 0.8) + 1.0) * 0.5
		mission_state_badge.modulate.a = 0.70 + p_badge * 0.30
	
	# Update Waypoint Compass tracker
	_waypoint_update_timer += delta
	if _waypoint_update_timer >= 0.1:
		_waypoint_update_timer = 0.0
		_update_waypoint_tracker()
	
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
	
	# Animate Mission Feedback Banner
	if _feedback_banner_timer > 0.0:
		_feedback_banner_timer = maxf(0.0, _feedback_banner_timer - delta)
		if feedback_banner:
			if _feedback_banner_timer < 0.5:
				feedback_banner.modulate.a = _feedback_banner_timer / 0.5
			else:
				feedback_banner.modulate.a = 1.0
			if _feedback_banner_timer <= 0.0:
				feedback_banner.visible = false


func _connect_game_state_signals() -> void:
	var gs := get_node_or_null("/root/GameState")
	if not gs:
		return
	
	if gs.has_signal("health_changed") and not gs.is_connected("health_changed", _on_health_changed):
		gs.connect("health_changed", _on_health_changed)
	if gs.has_signal("oxygen_changed") and not gs.is_connected("oxygen_changed", _on_oxygen_changed):
		gs.connect("oxygen_changed", _on_oxygen_changed)
	if gs.has_signal("energy_changed") and not gs.is_connected("energy_changed", _on_energy_changed):
		gs.connect("energy_changed", _on_energy_changed)
	if gs.has_signal("oxygen_low_warning") and not gs.is_connected("oxygen_low_warning", _on_oxygen_low_warning):
		gs.connect("oxygen_low_warning", _on_oxygen_low_warning)
	if gs.has_signal("oxygen_refill_status_changed") and not gs.is_connected("oxygen_refill_status_changed", _on_oxygen_refill_status_changed):
		gs.connect("oxygen_refill_status_changed", _on_oxygen_refill_status_changed)
	if gs.has_signal("resource_changed") and not gs.is_connected("resource_changed", _on_resource_changed):
		gs.connect("resource_changed", _on_resource_changed)
	if gs.has_signal("storage_changed") and not gs.is_connected("storage_changed", _on_storage_changed):
		gs.connect("storage_changed", _on_storage_changed)
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


func _connect_rule_engine_signals() -> void:
	if Engine.has_singleton("GameRuleEngine") or has_node("/root/GameRuleEngine"):
		var gre = get_node("/root/GameRuleEngine")
		if gre.has_signal("warning_issued") and not gre.is_connected("warning_issued", _on_rule_warning_issued):
			gre.warning_issued.connect(_on_rule_warning_issued)
		if gre.has_signal("extraction_objective_unlocked") and not gre.is_connected("extraction_objective_unlocked", _on_extraction_objective_unlocked):
			gre.extraction_objective_unlocked.connect(_on_extraction_objective_unlocked)
		if gre.has_signal("return_terminal_state_changed") and not gre.is_connected("return_terminal_state_changed", _on_return_terminal_state_changed):
			gre.return_terminal_state_changed.connect(_on_return_terminal_state_changed)


func _on_rule_warning_issued(warning_type: String, message: String, priority: int) -> void:
	if warning_type == "low_oxygen":
		_low_o2_alert = true
		_play_low_oxygen_sound()
	elif warning_type in ["critical_hypoxia", "suffocation_breach"]:
		_low_o2_alert = true
		_play_low_oxygen_sound()
	show_system_alert("⚠️ SYSTEM ALERT: " + warning_type.to_upper(), message, "PRIORITY %d WARNING" % priority, Color(1.0, 0.4, 0.3))


func _on_extraction_objective_unlocked() -> void:
	show_system_alert("✓ OBJECTIVE UNLOCKED", "Required sample quota gathered. Extraction authorized!", "EXPEDITION EXTRACTION", Color(0.2, 0.95, 0.5))


func _on_return_terminal_state_changed(is_enabled: bool, reason: String) -> void:
	if is_enabled:
		show_system_alert("🚀 RETURN TERMINAL ONLINE", "Base return terminal energized. Airlock extraction portal ready.", "DIRECTIVE ACTIVE", Color(0.2, 0.85, 1.0))
	else:
		show_system_alert("🔒 RETURN TERMINAL LOCKED", reason, "SECURITY RESTRICTION", Color(1.0, 0.4, 0.35))


func show_system_alert(title: String, description: String, subtext: String = "", alert_color: Color = Color(0.2, 0.9, 1.0)) -> void:
	if not feedback_banner:
		return
	feedback_banner.visible = true
	feedback_banner.modulate = Color.WHITE
	_feedback_banner_timer = 4.0
	
	if feedback_title_label:
		feedback_title_label.text = title
		feedback_title_label.modulate = alert_color
	if feedback_desc_label:
		feedback_desc_label.text = description
	if feedback_rewards_label:
		feedback_rewards_label.text = subtext
		feedback_rewards_label.modulate = alert_color


func _initialize_hud_values() -> void:
	var gs := get_node_or_null("/root/GameState")
	if not gs:
		return
	
	_last_health = gs.get("health")
	_on_health_changed(gs.get("health"), gs.get("max_health"))
	_on_oxygen_changed(gs.get("oxygen"), gs.get("max_oxygen"))
	if gs.get("max_energy") != null:
		_on_energy_changed(gs.get("energy"), gs.get("max_energy"))
	_on_objective_changed(gs.get("current_objective"))
	_on_game_paused(gs.get("is_paused"))
	
	var res: Dictionary = gs.get("resources")
	_on_resource_changed("crystals", res.get("crystals", 0))
	_on_resource_changed("titanium", res.get("titanium", 0))
	_on_resource_changed("biomass", res.get("biomass", 0))
	_on_resource_changed("oxygen_cells", res.get("oxygen_cells", 0))
	
	if biome_telemetry_label:
		var p_name: String = str(gs.get("selected_planet")) if "selected_planet" in gs and not str(gs.get("selected_planet")).is_empty() else "TRAPPIST-1 e"
		var rate: float = float(gs.get("oxygen_depletion_rate")) if "oxygen_depletion_rate" in gs else 1.5
		biome_telemetry_label.text = "%s // SECTOR ALPHA • O2 DRAIN: %.1f/s" % [p_name.to_upper(), rate]


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


func _on_energy_changed(current: float, max_nrg: float) -> void:
	if energy_bar:
		energy_bar.max_value = max_nrg
		energy_bar.value = current
	if energy_label:
		if max_nrg > 0.0:
			energy_label.text = "%d%%" % int(ceil((current / max_nrg) * 100.0))
		else:
			energy_label.text = "0%"


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
	var mm = get_node_or_null("/root/MissionManager")
	var active = mm.call("get_active_mission") if mm and mm.has_method("get_active_mission") else null
	if active and "description" in active and not str(active.description).is_empty():
		if objective_label:
			objective_label.text = str(active.description)
		return
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
			var cleaned_text := prompt_text
			if cleaned_text.begins_with("Press E to "):
				cleaned_text = cleaned_text.substr(11)
			elif cleaned_text.begins_with("Press [E] to "):
				cleaned_text = cleaned_text.substr(13)
			prompt_label.text = cleaned_text


func _on_tutorial_step_changed(step: int, title: String, desc: String, is_complete: bool) -> void:
	if not tutorial_banner:
		return
		
	if is_complete:
		tutorial_banner.visible = true
		tutorial_banner.modulate = Color(0.3, 1.0, 0.6)
		if tutorial_step_label:
			tutorial_step_label.text = title
		if tutorial_desc_label:
			tutorial_desc_label.text = desc
		if tutorial_progress_label:
			tutorial_progress_label.text = "● ● ● ●"
		# Smoothly fade out the tutorial banner after 3 seconds so the screen stays clean
		var tw := create_tween()
		tw.tween_interval(3.0)
		tw.tween_property(tutorial_banner, "modulate:a", 0.0, 0.6)
		tw.tween_callback(func(): 
			if tutorial_banner: 
				tutorial_banner.visible = false
		)
	else:
		tutorial_banner.visible = true
		tutorial_banner.modulate = Color(1.0, 1.0, 1.0, 1.0)
		if tutorial_step_label:
			tutorial_step_label.text = title
		if tutorial_desc_label:
			tutorial_desc_label.text = desc
		if tutorial_progress_label:
			var p_str := ""
			for i in 4:
				p_str += "● " if i <= step else "○ "
			tutorial_progress_label.text = p_str.strip_edges()
		
		# Auto-fade out after 4 seconds to maintain a pristine, clean screen
		var tw_step := create_tween()
		tw_step.tween_interval(4.0)
		tw_step.tween_property(tutorial_banner, "modulate:a", 0.0, 0.6)
		tw_step.tween_callback(func():
			if tutorial_banner:
				tutorial_banner.visible = false
		)


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
		if respawn_base_button:
			respawn_base_button.grab_focus()
		elif restart_button:
			restart_button.grab_focus()


func _on_respawn_base_pressed() -> void:
	if game_over_overlay:
		game_over_overlay.visible = false
	if pause_overlay:
		pause_overlay.visible = false
	
	var gs := get_node_or_null("/root/GameState")
	if gs:
		gs.is_game_over = false
		gs.is_paused = false
		gs.call("refill_oxygen", 100.0)
		gs.call("heal_player", 100.0)
	
	get_tree().paused = false
	
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		player = get_node_or_null("/root/GameWorld/Player")
	if player:
		player.global_position = Vector2.ZERO
		player.velocity = Vector2.ZERO
		player.set("is_dead", false)
		if player.has_node("CollisionShape2D"):
			player.get_node("CollisionShape2D").set_deferred("disabled", false)
		var vis = player.get_node_or_null("Visual")
		if vis:
			vis.modulate = Color.WHITE
	
	_play_mission_success_sound()


func toggle_story_modal() -> void:
	if story_modal_overlay:
		if story_modal_overlay.visible:
			close_story_modal()
		else:
			open_story_modal()


func open_story_modal(custom_text: String = "") -> void:
	if not story_modal_overlay:
		return
	
	var content := custom_text
	if content.is_empty():
		var mm = get_node_or_null("/root/MissionManager")
		var active = mm.call("get_active_mission") if mm else null
		if active and "story_log" in active and not str(active.story_log).is_empty():
			content = str(active.story_log)
		else:
			content = "[b]AURA-7 EXPEDITION OS // MISSION LOGS[/b]\n\n"
			content += "Welcome to Trappist-1 e, Sector Alpha.\n"
			content += "Atmosphere is hostile with continuous O2 consumption outside sanctuary zones.\n"
			content += "The Bio-Hab Alpha dome provides 100% life-support recharge.\n\n"
			content += "Primary Objectives:\n"
			content += "  1. Recover 3 emergency Oxygen Cells along the south canyon corridor.\n"
			content += "  2. Harvest biological tissue samples from alien flora/fauna.\n"
			content += "  3. Interface with the Alpha-7 Outpost terminal.\n"
			content += "  4. Survive xenomorphic bio-swarm ambush.\n"
			content += "  5. Track and neutralize Goliath Prime (Apex Predator).\n"
			content += "  6. Return to Habitat Airlock to initialize orbital star transit."
	
	if story_content_label:
		story_content_label.text = content
	
	story_modal_overlay.visible = true
	_play_mission_success_sound()


func close_story_modal() -> void:
	if story_modal_overlay:
		story_modal_overlay.visible = false


func _on_resume_pressed() -> void:
	var gs := get_node_or_null("/root/GameState")
	if gs and gs.has_method("set_paused"):
		gs.call("set_paused", false)
	else:
		get_tree().paused = false
		if pause_overlay:
			pause_overlay.visible = false


func _on_save_game_pressed() -> void:
	var sm = get_node_or_null("/root/SaveManager")
	if not sm:
		if save_feedback_label:
			save_feedback_label.text = "✕ SAVE SYSTEM UNAVAILABLE"
			save_feedback_label.modulate = Color(1.0, 0.4, 0.4)
			save_feedback_label.visible = true
		return
	
	var ok: bool = sm.call("save_game")
	if save_feedback_label:
		if ok:
			save_feedback_label.text = "✓ MISSION STATE SAVED AT %s" % Time.get_time_string_from_system()
			save_feedback_label.modulate = Color(0.3, 1.0, 0.6)
		else:
			save_feedback_label.text = "✕ SAVE FAILED: %s" % sm.call("get_last_error")
			save_feedback_label.modulate = Color(1.0, 0.4, 0.4)
		save_feedback_label.visible = true


func _on_restart_pressed() -> void:
	if pause_overlay:
		pause_overlay.visible = false
	if game_over_overlay:
		game_over_overlay.visible = false
	var gs := get_node_or_null("/root/GameState")
	if gs and gs.has_method("restart_game"):
		gs.call("restart_game")
	else:
		get_tree().paused = false
	get_tree().reload_current_scene()


func _on_return_menu_pressed() -> void:
	var gs := get_node_or_null("/root/GameState")
	if gs and gs.has_method("set_paused"):
		gs.call("set_paused", false)
	else:
		get_tree().paused = false
	if pause_overlay:
		pause_overlay.visible = false
	if game_over_overlay:
		game_over_overlay.visible = false
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")


# ---------------------------------------------------------------------------
# Mission Manager Integration & HUD Telemetry
# ---------------------------------------------------------------------------
func _connect_mission_manager_signals() -> void:
	var mm := get_node_or_null("/root/MissionManager")
	if not mm:
		return
	
	if mm.has_signal("mission_started") and not mm.is_connected("mission_started", _on_mission_started):
		mm.connect("mission_started", _on_mission_started)
	if mm.has_signal("mission_progress_updated") and not mm.is_connected("mission_progress_updated", _on_mission_progress_updated):
		mm.connect("mission_progress_updated", _on_mission_progress_updated)
	if mm.has_signal("mission_completed") and not mm.is_connected("mission_completed", _on_mission_completed):
		mm.connect("mission_completed", _on_mission_completed)
	if mm.has_signal("mission_failed") and not mm.is_connected("mission_failed", _on_mission_failed):
		mm.connect("mission_failed", _on_mission_failed)
	if mm.has_signal("campaign_completed") and not mm.is_connected("campaign_completed", _on_campaign_completed):
		mm.connect("campaign_completed", _on_campaign_completed)
	
	var active = mm.call("get_active_mission")
	if active:
		_update_mission_display(active)


func _on_mission_started(mission: RefCounted) -> void:
	_update_mission_display(mission)
	if mission:
		if feedback_banner:
			feedback_banner.visible = true
			feedback_banner.modulate = Color.WHITE
			_feedback_banner_timer = 4.5
			if feedback_title_label:
				feedback_title_label.text = "◈ AURA-7 TRANSMISSION // %s" % str(mission.get("title"))
				feedback_title_label.modulate = Color(0.15, 0.9, 1.0)
			if feedback_desc_label:
				feedback_desc_label.text = str(mission.get("description"))
			if feedback_rewards_label:
				feedback_rewards_label.text = "Press [L] for Full Encrypted Comms Log"
				feedback_rewards_label.modulate = Color(0.25, 0.95, 0.75)
		_play_mission_success_sound()


func _on_mission_progress_updated(mission: RefCounted) -> void:
	_update_mission_display(mission)


func _on_mission_completed(mission: RefCounted, rewards: Dictionary) -> void:
	_update_mission_display(mission)
	show_mission_success(mission, rewards)


func _on_mission_failed(mission: RefCounted, reason: String) -> void:
	_update_mission_display(mission)
	show_mission_failure(mission, reason)


func _on_campaign_completed() -> void:
	if feedback_banner:
		feedback_banner.visible = true
		feedback_banner.modulate = Color.WHITE
		_feedback_banner_timer = 8.0
	if feedback_title_label:
		feedback_title_label.text = "★ EXPEDITION CAMPAIGN ACCOMPLISHED ★"
		feedback_title_label.modulate = Color(0.2, 1.0, 0.8)
	if feedback_desc_label:
		feedback_desc_label.text = "ALL BIOSPHERE-X SURFACE DIRECTIVES COMPLETE"
	if feedback_rewards_label:
		feedback_rewards_label.text = "EXPEDITION RATING: EXEMPLAR // TELEMETRY SECURED"
	_play_mission_success_sound()


func _update_mission_display(mission: RefCounted) -> void:
	if not mission:
		return
	
	if mission_title_tag:
		mission_title_tag.text = "[MISSION: %s]" % str(mission.get("title"))
		
	if objective_type_badge:
		var obj_type: int = int(mission.get("objective_type"))
		match obj_type:
			0: objective_type_badge.text = "[COLLECT OXYGEN]"
			1: objective_type_badge.text = "[RETRIEVE SAMPLES]"
			2: objective_type_badge.text = "[ACTIVATE TERMINAL]"
			3: objective_type_badge.text = "[SURVIVE ENCOUNTER]"
			4: objective_type_badge.text = "[DEFEAT BOSS]"
			5: objective_type_badge.text = "[RETURN TO BASE]"
			_: objective_type_badge.text = "[OBJECTIVE]"
			
	if mission_state_badge:
		var st: int = int(mission.get("state"))
		match st:
			0:
				mission_state_badge.text = "[LOCKED]"
				mission_state_badge.modulate = Color(0.6, 0.6, 0.6)
			1:
				mission_state_badge.text = "[ACTIVE]"
				mission_state_badge.modulate = Color(0.2, 0.9, 0.5)
			2:
				mission_state_badge.text = "[COMPLETED]"
				mission_state_badge.modulate = Color(0.2, 0.85, 1.0)
			3:
				mission_state_badge.text = "[FAILED]"
				mission_state_badge.modulate = Color(1.0, 0.3, 0.3)
	
	if objective_label:
		objective_label.text = str(mission.get("description"))
		
	var ratio: float = float(mission.call("get_progress_ratio")) if mission.has_method("get_progress_ratio") else 0.0
	if mission_progress_bar:
		mission_progress_bar.step = 0.0
		mission_progress_bar.max_value = 1.0
		mission_progress_bar.value = ratio
		
	if mission_progress_label:
		if mission.has_method("get_progress_text"):
			mission_progress_label.text = str(mission.call("get_progress_text"))
		else:
			mission_progress_label.text = "%.0f%%" % (ratio * 100.0)


func show_mission_success(mission: RefCounted, rewards: Dictionary) -> void:
	if not feedback_banner:
		return
	feedback_banner.visible = true
	feedback_banner.modulate = Color.WHITE
	_feedback_banner_timer = 4.0
	
	if feedback_title_label:
		feedback_title_label.text = "✓ MISSION ACCOMPLISHED"
		feedback_title_label.modulate = Color(0.2, 1.0, 0.6)
	if feedback_desc_label:
		feedback_desc_label.text = "%s // OBJECTIVE COMPLETED" % str(mission.get("title"))
	if feedback_rewards_label:
		var rew_parts := []
		for k in rewards:
			rew_parts.append("+%s %s" % [str(rewards[k]), str(k).replace("_", " ").capitalize()])
		feedback_rewards_label.text = "REWARDS: " + (", ".join(rew_parts) if not rew_parts.is_empty() else "Telemetry Registered")
		feedback_rewards_label.modulate = Color(0.95, 0.8, 0.25)
	
	_play_mission_success_sound()


func show_mission_failure(mission: RefCounted, reason: String) -> void:
	if not feedback_banner:
		return
	feedback_banner.visible = true
	feedback_banner.modulate = Color.WHITE
	_feedback_banner_timer = 5.0
	
	if feedback_title_label:
		feedback_title_label.text = "✕ MISSION FAILED"
		feedback_title_label.modulate = Color(1.0, 0.3, 0.35)
	if feedback_desc_label:
		feedback_desc_label.text = "%s // CRITERIA VIOLATED" % str(mission.get("title"))
	if feedback_rewards_label:
		feedback_rewards_label.text = "CAUSE: %s" % reason
		feedback_rewards_label.modulate = Color(1.0, 0.65, 0.65)
		
	_play_mission_fail_sound()


func _play_mission_success_sound() -> void:
	if not audio_player or not audio_player.stream is AudioStreamGenerator:
		return
	if not audio_player.playing:
		audio_player.play()
	var pb = audio_player.get_stream_playback()
	if pb:
		var frames: int = pb.get_frames_available()
		var n := mini(frames, 700)
		for i in n:
			var freq := 0.25 if i < 230 else (0.33 if i < 460 else 0.44)
			var env := 1.0 - (float(i) / float(n))
			var s := sin(float(i) * freq) * 0.20 * env
			pb.push_frame(Vector2(s, s))


func _play_mission_fail_sound() -> void:
	if not audio_player or not audio_player.stream is AudioStreamGenerator:
		return
	if not audio_player.playing:
		audio_player.play()
	var pb = audio_player.get_stream_playback()
	if pb:
		var frames: int = pb.get_frames_available()
		var n := mini(frames, 700)
		for i in n:
			var freq := 0.32 - (float(i) / float(n)) * 0.16
			var env := 1.0 - (float(i) / float(n))
			var s := sin(float(i) * freq) * 0.22 * env
			pb.push_frame(Vector2(s, s))


# ---------------------------------------------------------------------------
# Research Base Terminal Modals (Storage, Mission Ops, Planet Gate)
# ---------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if story_modal_overlay and story_modal_overlay.visible:
			if event.keycode == KEY_ESCAPE or event.keycode == KEY_L:
				close_story_modal()
				get_viewport().set_input_as_handled()
				return
		if help_modal_overlay and help_modal_overlay.visible:
			if event.keycode == KEY_ESCAPE or event.keycode == KEY_H:
				close_help_manual()
				get_viewport().set_input_as_handled()
				return
		elif terminal_modal_overlay and terminal_modal_overlay.visible:
			if event.keycode == KEY_ESCAPE or event.keycode == KEY_E:
				close_terminal_modal()
				get_viewport().set_input_as_handled()
				return
		elif event.keycode == KEY_L:
			toggle_story_modal()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_H:
			toggle_help_manual()
			get_viewport().set_input_as_handled()
			return
		elif (event.keycode == KEY_I or event.keycode == KEY_TAB) and inventory_dialog:
			if inventory_dialog.has_method("toggle_visibility"):
				inventory_dialog.call("toggle_visibility")
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_B and construction_menu:
			if construction_menu.has_method("toggle_menu"):
				construction_menu.call("toggle_menu")
				get_viewport().set_input_as_handled()
		elif (event.keycode == KEY_QUOTELEFT or event.keycode == KEY_SLASH) and command_terminal:
			if command_terminal.has_method("toggle_terminal"):
				command_terminal.call("toggle_terminal")
			else:
				command_terminal.visible = not command_terminal.visible
			get_viewport().set_input_as_handled()


func _on_storage_changed(_res_id: String, _stored: int, _carried: int) -> void:
	if terminal_modal_overlay and terminal_modal_overlay.visible and _current_terminal_mode == "storage":
		_refresh_storage_modal_content()


func open_storage_modal() -> void:
	_current_terminal_mode = "storage"
	if terminal_header:
		terminal_header.text = "// CARGO STORAGE & BASE VAULT //"
	if terminal_sub_header:
		terminal_sub_header.text = "SECURE SPECIMENS & PERMANENT RESOURCE DEPOT"
	if terminal_action_btn1:
		terminal_action_btn1.text = "DEPOSIT ALL CARGO"
		terminal_action_btn1.visible = true
	if terminal_action_btn2:
		terminal_action_btn2.text = "WITHDRAW 1 O2 CELL"
		terminal_action_btn2.visible = true
	_refresh_storage_modal_content()
	if terminal_modal_overlay:
		terminal_modal_overlay.visible = true


func _refresh_storage_modal_content() -> void:
	var gs := get_node_or_null("/root/GameState")
	if not gs or not terminal_content_label:
		return
	
	var res: Dictionary = gs.get("resources")
	var st: Dictionary = gs.get("base_storage") if "base_storage" in gs else {}
	
	var text := "[b]SUIT-CARRIED FIELD INVENTORY:[/b]\n"
	text += "  ⚡ Energy Crystals: %d\n" % res.get("crystals", 0)
	text += "  ⛏ Titanium Metal: %d\n" % res.get("titanium", 0)
	text += "  🧬 Alien Biomass: %d\n" % res.get("biomass", 0)
	text += "  🫧 Oxygen Cells: %d\n\n" % res.get("oxygen_cells", 0)
	
	text += "[b]SECURE BASE VAULT INVENTORY:[/b]\n"
	text += "  ⚡ Stored Crystals: %d\n" % st.get("crystals", 0)
	text += "  ⛏ Stored Titanium: %d\n" % st.get("titanium", 0)
	text += "  🧬 Stored Biomass: %d\n" % st.get("biomass", 0)
	text += "  🫧 Stored O2 Cells: %d" % st.get("oxygen_cells", 0)
	
	terminal_content_label.text = text


func open_mission_modal() -> void:
	_current_terminal_mode = "mission"
	if terminal_header:
		terminal_header.text = "// MISSION OPERATIONS //"
	if terminal_sub_header:
		terminal_sub_header.text = "EXPEDITION CAMPAIGN DIRECTIVES & TELEMETRY"
	if terminal_action_btn1:
		terminal_action_btn1.text = "REBOOT / RETRY DIRECTIVE"
		terminal_action_btn1.visible = true
	if terminal_action_btn2:
		terminal_action_btn2.visible = false
	_refresh_mission_modal_content()
	if terminal_modal_overlay:
		terminal_modal_overlay.visible = true


func _refresh_mission_modal_content() -> void:
	var mm := get_node_or_null("/root/MissionManager")
	if not mm or not terminal_content_label:
		return
	var active = mm.call("get_active_mission")
	var text := ""
	if active:
		var st_str := "ACTIVE"
		if active.call("is_completed"): st_str = "COMPLETED"
		elif active.call("is_failed"): st_str = "FAILED"
		
		text += "[b]CURRENT ACTIVE DIRECTIVE:[/b]\n"
		text += "  [b]%s[/b] [%s]\n" % [active.get("title"), st_str]
		text += "  %s\n\n" % active.get("description")
		text += "  Target Progress: %s\n\n" % active.call("get_progress_text")
	else:
		text += "[b]ALL EXPEDITION DIRECTIVES ACCOMPLISHED![/b]\n\n"
	
	text += "[b]CAMPAIGN DIRECTIVES ROSTER:[/b]\n"
	var all_m = mm.call("get_all_missions")
	for m in all_m:
		var tag := "○ LOCKED"
		if m.call("is_completed"): tag = "● COMPLETED"
		elif m.call("is_active"): tag = "▶ ACTIVE"
		elif m.call("is_failed"): tag = "✕ FAILED"
		text += "  [%s] %s\n" % [tag, m.get("title")]
	
	terminal_content_label.text = text


func open_planet_gate_modal() -> void:
	_current_terminal_mode = "planet_gate"
	if terminal_header:
		terminal_header.text = "// EXPEDITION GATE //"
	if terminal_sub_header:
		terminal_sub_header.text = "PLANETARY SECTOR SELECTION & AIRLOCK"
	if terminal_action_btn1:
		terminal_action_btn1.text = "EXOPLANET ARCHIVE [P]"
		terminal_action_btn1.visible = true
	if terminal_action_btn2:
		terminal_action_btn2.text = "TOGGLE AIRLOCK DOOR"
		terminal_action_btn2.visible = true
	_refresh_planet_gate_modal_content()
	if terminal_modal_overlay:
		terminal_modal_overlay.visible = true


func open_planet_selection_screen() -> void:
	if planet_selection_screen:
		if planet_selection_screen.has_method("open_screen"):
			planet_selection_screen.call("open_screen")
		else:
			planet_selection_screen.visible = true


func _refresh_planet_gate_modal_content() -> void:
	if not terminal_content_label:
		return
	var text := "[b]AVAILABLE EXPEDITION SECTORS:[/b]\n\n"
	text += "  1. [b]BioSphere-X Surface Clearing[/b] [Threat: MODERATE]\n"
	text += "     Primary drop zone. Abundant mineral and oxygen deposits.\n\n"
	text += "  2. [b]South-West Crystal Valleys[/b] [Threat: ELEVATED]\n"
	text += "     High crystal density guarded by armored brutes.\n\n"
	text += "  3. [b]Ancient Crater Basin[/b] [Threat: EXTREME]\n"
	text += "     Colossal alien nesting basin. Goliath Prime encounter.\n\n"
	text += "  4. [b]Base Habitat Sanctuary[/b] [Threat: SAFE]\n"
	text += "     Atmospheric safe zone and cargo storage vault."
	terminal_content_label.text = text


func close_terminal_modal() -> void:
	if terminal_modal_overlay:
		terminal_modal_overlay.visible = false
	_current_terminal_mode = ""


func _on_terminal_action1_pressed() -> void:
	match _current_terminal_mode:
		"storage":
			var gs := get_node_or_null("/root/GameState")
			if gs:
				gs.call("deposit_all_resources")
				_refresh_storage_modal_content()
				_play_mission_success_sound()
		"mission":
			var mm := get_node_or_null("/root/MissionManager")
			if mm:
				var active = mm.call("get_active_mission")
				if active:
					mm.call("restart_mission", active.get("id"))
					_refresh_mission_modal_content()
					_play_mission_success_sound()
		"planet_gate":
			close_terminal_modal()
			open_planet_selection_screen()
			_play_mission_success_sound()


func _on_terminal_action2_pressed() -> void:
	match _current_terminal_mode:
		"storage":
			var gs := get_node_or_null("/root/GameState")
			if gs:
				gs.call("withdraw_resource", "oxygen_cells", 1)
				_refresh_storage_modal_content()
				_play_mission_success_sound()
		"planet_gate":
			var base = get_tree().get_first_node_in_group("research_base")
			if base and base.has_method("get_airlock_door"):
				var door = base.call("get_airlock_door")
				if door and door.has_method("interact"):
					door.call("interact")
					_play_mission_success_sound()



# ---------------------------------------------------------------------------
# Survival Field Guide Manual & Waypoint Compass Navigation
# ---------------------------------------------------------------------------
func toggle_help_manual() -> void:
	if help_modal_overlay:
		if help_modal_overlay.visible:
			close_help_manual()
		else:
			open_help_manual()


func open_help_manual() -> void:
	if help_modal_overlay:
		help_modal_overlay.visible = true
	_play_mission_success_sound()


func close_help_manual() -> void:
	if help_modal_overlay:
		help_modal_overlay.visible = false


func _setup_help_content() -> void:
	if not help_content_label:
		return
	
	var manual := ""
	manual += "[b][color=#38bdf8]1. MISSION DIRECTIVES & WAYPOINT TRACKER[/color][/b]\n"
	manual += "• Look at the [b]Waypoint Compass[/b] docked at the bottom of the screen. The glowing arrow points directly toward your active target!\n"
	manual += "• Real-time distance and cardinal bearings (e.g. 18m North) update as you explore.\n"
	manual += "• Directives: Recover Oxygen ➔ Harvest Biomass ➔ Outpost Override ➔ Defend Swarms ➔ Defeat Goliath Prime.\n\n"
	
	manual += "[b][color=#38bdf8]2. OXYGEN & VITALITY MANAGEMENT[/color][/b]\n"
	manual += "• The atmosphere of Trappist-1e is toxic. Your [b]O2 Suit Gauge[/b] drains continuously.\n"
	manual += "• [b]Refill Sources:[/b] Pick up blue glowing Oxygen Cells, enter green atmospheric shields at Oxygen Stations, or retreat inside the Base Habitat.\n"
	manual += "• If Oxygen depletes to 0%, rapid hypoxia inflicts lethal health damage!\n\n"
	
	manual += "[b][color=#38bdf8]3. ESSENTIAL CONTROLS & SHORTCUTS[/color][/b]\n"
	manual += "• [b][W, A, S, D][/b] : Suit Thruster Movement\n"
	manual += "• [b][Mouse Wheel][/b] : Dynamic Camera Zoom (0.9x tactical overview to 2.2x detail)\n"
	manual += "• [b][Left Mouse Button][/b] : Pulse Mining Blaster (harvests resources & damages aliens)\n"
	manual += "• [b][E][/b] : Contextual Interact (airlocks, research consoles, dropped crates)\n"
	manual += "• [b][I] / [TAB][/b] : Inventory & Backpack Crafting (Oxygen Kits, Armor Plates, Ammo)\n"
	manual += "• [b][B][/b] : Base Construction Menu (Solar Panels, Dome Habitats, Storage Vaults)\n"
	manual += "• [b][H][/b] : Toggle this Survival Field Guide anytime\n"
	manual += "• [b][ESC] / [P][/b] : Pause simulation & Save Mission Progress\n\n"
	
	manual += "[b][color=#38bdf8]4. ALIEN BESTIARY & COMBAT COUNTERS[/color][/b]\n"
	manual += "• [color=#f87171]Scouts:[/color] Agile ambushers. Backpedal with thrusters while firing continuously.\n"
	manual += "• [color=#fb923c]Spitters:[/color] Acid artillery. Strafe laterally to dodge corrosive slime pools.\n"
	manual += "• [color=#e879f9]Brutes & Goliath Prime:[/color] Heavy armored horrors. Kite through canyon chokepoints and construct defensive perimeter bases.\n\n"
	
	manual += "[b][color=#38bdf8]5. ACADEMIC AI ARCHITECTURE & LAB EVALUATION GUIDE[/color][/b]\n"
	manual += "• [b]Multi-Algorithm Search Suite:[/b] 7 Graph Algorithms (A*, Dijkstra/BFS, DFS, DLS, IDDFS, Bidirectional, Greedy) with AStarGrid2D fallback.\n"
	manual += "• [b]Mamdani Fuzzy Inference System:[/b] Real-time Dynamic Difficulty Adjustment balancing combat pressure, player vitals, and oxygen into speed/aggression multipliers.\n"
	manual += "• [b]Adversarial Minimax / Alpha-Beta Pruning:[/b] Powers Goliath Prime Boss decision-making up to depth 4 with predictive heuristic state valuation.\n"
	manual += "• [b]Constraint Satisfaction Problem (CSP) Engine:[/b] Solves multi-tier spatial, clearance, and inventory constraints for holographic base construction [B].\n"
	manual += "• [b]Propositional Rule Engine:[/b] Forward-chaining expert system for atmospheric domes, hazard transitions, and mission protocols.\n"
	manual += "• [b]AI vs AI Autonomous Arena:[/b] Side-by-side benchmarking proving ground with JSON/CSV export, available from Main Menu or [F1] Dev Menu."
	
	help_content_label.text = manual


func _update_waypoint_tracker() -> void:
	if not waypoint_label:
		return
	
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		player = get_node_or_null("/root/GameWorld/Player")
	if not player:
		waypoint_label.text = "🧭 Standby..."
		return
	
	var p_pos: Vector2 = player.global_position
	var target_info = _find_active_objective_target(p_pos)
	if target_info.is_empty():
		waypoint_label.text = "🧭 Area Clear • Exploring Surface"
		return
	
	var t_pos: Vector2 = target_info.get("pos", Vector2.ZERO)
	var t_name: String = target_info.get("name", "Objective Target")
	var diff: Vector2 = t_pos - p_pos
	var dist_m: float = diff.length() / 32.0 # 32 pixels per meter
	
	if dist_m < 2.0:
		waypoint_label.text = "🧭 ★ REACHED: %s" % t_name
		waypoint_label.modulate = Color(0.3, 1.0, 0.6)
	else:
		var arrow: String = _get_compass_arrow(diff.angle())
		var bearing: String = _get_compass_bearing(diff.angle())
		waypoint_label.text = "🧭 %s %s (%.0fm %s)" % [arrow, t_name, dist_m, bearing]
		waypoint_label.modulate = Color(0.2, 0.95, 0.9)


func _find_active_objective_target(p_pos: Vector2) -> Dictionary:
	var mm = get_node_or_null("/root/MissionManager")
	var active = mm.call("get_active_mission") if mm and mm.has_method("get_active_mission") else null
	var obj_type: int = int(active.get("objective_type")) if active else -1
	
	match obj_type:
		0: # COLLECT_OXYGEN
			var item = _find_nearest_collectable(p_pos, 0, "Oxygen Canister")
			if not item.is_empty():
				return item
			return _find_nearest_oxygen_station(p_pos)
		1: # RETRIEVE_SAMPLES
			var sample = _find_nearest_collectable(p_pos, 3, "Alien Biomass Specimen")
			if not sample.is_empty():
				return sample
			return _find_nearest_node_in_container(p_pos, "Plants", "Alien Flora Specimen")
		2: # ACTIVATE_TERMINAL
			var term = get_tree().get_first_node_in_group("research_terminal")
			if not term:
				term = get_node_or_null("/root/GameWorld/StationInteractiveObjects/ResearchTerminal")
			if term:
				return {"pos": term.global_position, "name": "Alpha-7 Research Terminal"}
			return {"pos": Vector2(420, -450), "name": "Outpost Terminal Clearing"}
		3: # SURVIVE_ENCOUNTER
			var enemy = _find_nearest_enemy(p_pos)
			if not enemy.is_empty():
				return enemy
			return {"pos": p_pos, "name": "Combat Zone (Survive Wave)"}
		4: # DEFEAT_BOSS
			var boss = get_tree().get_first_node_in_group("boss")
			if not boss:
				boss = get_node_or_null("/root/GameWorld/GoliathPrime_Boss")
			if boss:
				return {"pos": boss.global_position, "name": "Goliath Prime (Apex Threat)"}
			return {"pos": Vector2(0, 750), "name": "Colossal Crater Basin"}
		5: # RETURN_TO_BASE
			var base = get_tree().get_first_node_in_group("research_base")
			if not base:
				base = get_node_or_null("/root/GameWorld/ResearchBase")
			if base:
				return {"pos": base.global_position, "name": "Base Habitat Airlock"}
			return {"pos": Vector2.ZERO, "name": "Base Habitat Module"}
		_:
			var gs = get_node_or_null("/root/GameState")
			if gs and float(gs.get("oxygen")) < 40.0:
				var st = _find_nearest_oxygen_station(p_pos)
				if not st.is_empty():
					return st
			return {"pos": Vector2.ZERO, "name": "Base Habitat Sanctuary"}


func _find_nearest_collectable(p_pos: Vector2, target_type: int, default_name: String) -> Dictionary:
	var collectables_node = get_node_or_null("/root/GameWorld/Collectables")
	if not collectables_node:
		var root = get_tree().current_scene
		if root:
			collectables_node = root.get_node_or_null("Collectables")
	if not collectables_node:
		return {}
	
	var best_pos := Vector2.ZERO
	var best_dist := INF
	for item in collectables_node.get_children():
		if is_instance_valid(item) and item.visible:
			var res_type = item.get("resource_type")
			if res_type == null or int(res_type) == target_type:
				var d: float = p_pos.distance_squared_to(item.global_position)
				if d < best_dist:
					best_dist = d
					best_pos = item.global_position
	
	if best_dist < INF:
		return {"pos": best_pos, "name": default_name}
	return {}


func _find_nearest_enemy(p_pos: Vector2) -> Dictionary:
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		var alien_node = get_node_or_null("/root/GameWorld/AlienEnemies")
		if alien_node:
			enemies = alien_node.get_children()
	
	var best_pos := Vector2.ZERO
	var best_dist := INF
	for e in enemies:
		if is_instance_valid(e) and e.is_inside_tree() and e.visible:
			var d: float = p_pos.distance_squared_to(e.global_position)
			if d < best_dist:
				best_dist = d
				best_pos = e.global_position
				
	if best_dist < INF:
		return {"pos": best_pos, "name": "Alien Hostile"}
	return {}


func _find_nearest_oxygen_station(p_pos: Vector2) -> Dictionary:
	var stations_node = get_node_or_null("/root/GameWorld/OxygenStations")
	if not stations_node:
		return {}
	var best_pos := Vector2.ZERO
	var best_name := "O2 Refill Station"
	var best_dist := INF
	for st in stations_node.get_children():
		if is_instance_valid(st) and st.is_inside_tree():
			var d: float = p_pos.distance_squared_to(st.global_position)
			if d < best_dist:
				best_dist = d
				best_pos = st.global_position
				best_name = str(st.get("station_name")) if "station_name" in st else "O2 Refill Station"
	if best_dist < INF:
		return {"pos": best_pos, "name": best_name}
	return {}


func _find_nearest_node_in_container(p_pos: Vector2, container_name: String, item_name: String) -> Dictionary:
	var container = get_node_or_null("/root/GameWorld/" + container_name)
	if not container:
		return {}
	var best_pos := Vector2.ZERO
	var best_dist := INF
	for child in container.get_children():
		if is_instance_valid(child) and child.is_inside_tree():
			var d: float = p_pos.distance_squared_to(child.global_position)
			if d < best_dist:
				best_dist = d
				best_pos = child.global_position
	if best_dist < INF:
		return {"pos": best_pos, "name": item_name}
	return {}


func _get_compass_arrow(angle: float) -> String:
	var deg := rad_to_deg(angle)
	if deg < 0.0:
		deg += 360.0
	if deg >= 337.5 or deg < 22.5:
		return "▶"
	elif deg >= 22.5 and deg < 67.5:
		return "↘"
	elif deg >= 67.5 and deg < 112.5:
		return "▼"
	elif deg >= 112.5 and deg < 157.5:
		return "↙"
	elif deg >= 157.5 and deg < 202.5:
		return "◀"
	elif deg >= 202.5 and deg < 247.5:
		return "↖"
	elif deg >= 247.5 and deg < 292.5:
		return "▲"
	else:
		return "↗"


func _get_compass_bearing(angle: float) -> String:
	var deg := rad_to_deg(angle)
	if deg < 0.0:
		deg += 360.0
	if deg >= 337.5 or deg < 22.5:
		return "East"
	elif deg >= 22.5 and deg < 67.5:
		return "South-East"
	elif deg >= 67.5 and deg < 112.5:
		return "South"
	elif deg >= 112.5 and deg < 157.5:
		return "South-West"
	elif deg >= 157.5 and deg < 202.5:
		return "West"
	elif deg >= 202.5 and deg < 247.5:
		return "North-West"
	elif deg >= 247.5 and deg < 292.5:
		return "North"
	else:
		return "North-East"


