extends Control
## Main Menu & Game Mode Selector for BioSphere-X.
## Provides New Game, Continue, Settings, Quit, and AI Arena simulation.

@onready var continue_button: Button = %ContinueButton
@onready var continue_meta_label: Label = %ContinueMetaLabel
@onready var new_game_button: Button = %NewGameButton
@onready var ai_arena_button: Button = %AIArenaButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton

@onready var backend_status_label: Label = %BackendStatusLabel
@onready var refresh_backend_btn: Button = %RefreshBackendButton

# Settings Modal
@onready var settings_modal: Control = %SettingsModal
@onready var master_vol_slider: HSlider = %MasterVolSlider
@onready var master_vol_val: Label = %MasterVolVal
@onready var sfx_vol_slider: HSlider = %SFXVolSlider
@onready var sfx_vol_val: Label = %SFXVolVal
@onready var fullscreen_check: CheckBox = %FullscreenCheck
@onready var screen_shake_check: CheckBox = %ScreenShakeCheck
@onready var camera_smooth_check: CheckBox = %CameraSmoothCheck
@onready var delete_save_btn: Button = %DeleteSaveBtn
@onready var settings_feedback_label: Label = %SettingsFeedbackLabel
@onready var close_settings_btn: Button = %CloseSettingsBtn


func _ready() -> void:
	Engine.time_scale = 1.0
	_refresh_save_status()
	_setup_button_events()
	_setup_settings_modal()
	_check_backend_status()
	
	# Hide quit button on platforms that don't support quitting (e.g. Web)
	if OS.has_feature("web") and quit_button:
		quit_button.visible = false


func _refresh_save_status() -> void:
	var sm = get_node_or_null("/root/SaveManager")
	if not sm:
		if continue_button:
			continue_button.disabled = true
		if continue_meta_label:
			continue_meta_label.text = "Save system offline"
		return

	var has_save: bool = bool(sm.call("has_save_file"))
	if continue_button:
		continue_button.disabled = not has_save
		
	if continue_meta_label:
		if has_save:
			var meta: Dictionary = sm.call("get_save_metadata")
			var planet: String = str(meta.get("planet_name", "TRAPPIST-1 e"))
			var mission: String = str(meta.get("active_mission_title", "Survey Surface"))
			var time_str: String = str(meta.get("timestamp", ""))
			if time_str.is_empty():
				time_str = "Recent"
			continue_meta_label.text = "Sector: %s • Directive: %s • %s" % [planet, mission, time_str]
			continue_meta_label.modulate = Color(0.3, 0.9, 0.6)
		else:
			continue_meta_label.text = "No prior expedition telemetry found. Start a new campaign."
			continue_meta_label.modulate = Color(0.6, 0.7, 0.8, 0.7)


func _setup_button_events() -> void:
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)
	if new_game_button:
		new_game_button.pressed.connect(_on_new_game_pressed)
	if ai_arena_button:
		ai_arena_button.pressed.connect(_on_ai_arena_pressed)
	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)
	if refresh_backend_btn:
		refresh_backend_btn.pressed.connect(_check_backend_status)


func _setup_settings_modal() -> void:
	var sm = get_node_or_null("/root/SaveManager")
	var cfg: Dictionary = sm.current_settings if sm else {}

	if master_vol_slider:
		master_vol_slider.value = float(cfg.get("master_volume", 1.0))
		master_vol_slider.value_changed.connect(_on_master_vol_changed)
		_update_master_label(master_vol_slider.value)

	if sfx_vol_slider:
		sfx_vol_slider.value = float(cfg.get("sfx_volume", 0.8))
		sfx_vol_slider.value_changed.connect(_on_sfx_vol_changed)
		_update_sfx_label(sfx_vol_slider.value)

	if fullscreen_check:
		fullscreen_check.button_pressed = bool(cfg.get("fullscreen", false))
		fullscreen_check.toggled.connect(_on_fullscreen_toggled)

	if screen_shake_check:
		screen_shake_check.button_pressed = bool(cfg.get("screen_shake", true))

	if camera_smooth_check:
		camera_smooth_check.button_pressed = bool(cfg.get("camera_smoothing", true))

	if delete_save_btn:
		delete_save_btn.pressed.connect(_on_delete_save_pressed)

	if close_settings_btn:
		close_settings_btn.pressed.connect(_on_close_settings_pressed)


func _on_continue_pressed() -> void:
	var sm = get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("load_game"):
		print("BioSphere-X: Resuming Expedition Campaign...")
		sm.call("load_game")
		get_tree().change_scene_to_file("res://scenes/world/game_world.tscn")


func _on_new_game_pressed() -> void:
	var sm = get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("start_new_game"):
		print("BioSphere-X: Initializing Fresh Expedition Campaign...")
		sm.call("start_new_game")
	get_tree().change_scene_to_file("res://scenes/world/game_world.tscn")


func _on_ai_arena_pressed() -> void:
	print("BioSphere-X: Launching AI vs AI Simulation Arena...")
	get_tree().change_scene_to_file("res://scenes/ai_vs_ai/ai_arena.tscn")


func _on_settings_pressed() -> void:
	if settings_feedback_label:
		settings_feedback_label.visible = false
	if settings_modal:
		settings_modal.visible = true


func _on_close_settings_pressed() -> void:
	var sm = get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("save_settings"):
		var updated_cfg := {
			"master_volume": master_vol_slider.value if master_vol_slider else 1.0,
			"sfx_volume": sfx_vol_slider.value if sfx_vol_slider else 0.8,
			"fullscreen": fullscreen_check.button_pressed if fullscreen_check else false,
			"screen_shake": screen_shake_check.button_pressed if screen_shake_check else true,
			"camera_smoothing": camera_smooth_check.button_pressed if camera_smooth_check else true
		}
		sm.call("save_settings", updated_cfg)
	if settings_modal:
		settings_modal.visible = false


func _on_delete_save_pressed() -> void:
	var sm = get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("delete_save"):
		var ok: bool = sm.call("delete_save")
		if ok:
			if settings_feedback_label:
				settings_feedback_label.text = "✓ Save file wiped successfully."
				settings_feedback_label.modulate = Color(0.3, 1.0, 0.5)
				settings_feedback_label.visible = true
			_refresh_save_status()
		else:
			if settings_feedback_label:
				settings_feedback_label.text = "✕ Failed to delete save file."
				settings_feedback_label.modulate = Color(1.0, 0.4, 0.4)
				settings_feedback_label.visible = true


func _on_quit_pressed() -> void:
	print("BioSphere-X: Terminating application on user request.")
	get_tree().quit()


func _on_master_vol_changed(value: float) -> void:
	_update_master_label(value)
	var sm = get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("apply_settings"):
		sm.call("apply_settings", {"master_volume": value})


func _on_sfx_vol_changed(value: float) -> void:
	_update_sfx_label(value)
	var sm = get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("apply_settings"):
		sm.call("apply_settings", {"sfx_volume": value})


func _on_fullscreen_toggled(toggled_on: bool) -> void:
	var sm = get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("apply_settings"):
		sm.call("apply_settings", {"fullscreen": toggled_on})


func _update_master_label(val: float) -> void:
	if master_vol_val:
		master_vol_val.text = "%d%%" % int(round(val * 100.0))


func _update_sfx_label(val: float) -> void:
	if sfx_vol_val:
		sfx_vol_val.text = "%d%%" % int(round(val * 100.0))


func _check_backend_status() -> void:
	if backend_status_label:
		backend_status_label.text = "Checking Python AI Backend..."
		backend_status_label.modulate = Color(0.7, 0.7, 0.7)

	var ai_client = get_node_or_null("/root/AIClient")
	if ai_client and ai_client.has_method("check_health"):
		ai_client.call("check_health", _on_backend_health_checked)
	elif backend_status_label:
		backend_status_label.text = "○ AIClient Autoload not detected"


func _on_backend_health_checked(res: Dictionary) -> void:
	if not is_instance_valid(self):
		return
	var online := bool(res.get("success", false))
	if backend_status_label:
		if online:
			backend_status_label.text = "● PYTHON AI BACKEND: ONLINE (127.0.0.1:8000)"
			backend_status_label.modulate = Color(0.2, 1.0, 0.5)
		else:
			backend_status_label.text = "○ PYTHON AI BACKEND: OFFLINE (Fallback Mode Active)"
			backend_status_label.modulate = Color(1.0, 0.6, 0.2)
