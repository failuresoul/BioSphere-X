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
	_initialize_hud_values()
	
	if resume_button:
		resume_button.pressed.connect(_on_resume_pressed)
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)
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
		if terminal_modal_overlay and terminal_modal_overlay.visible:
			if event.keycode == KEY_ESCAPE or event.keycode == KEY_E:
				close_terminal_modal()
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
		terminal_action_btn1.text = "CYCLE NEXT SECTOR"
		terminal_action_btn1.visible = true
	if terminal_action_btn2:
		terminal_action_btn2.text = "TOGGLE AIRLOCK DOOR"
		terminal_action_btn2.visible = true
	_refresh_planet_gate_modal_content()
	if terminal_modal_overlay:
		terminal_modal_overlay.visible = true


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
