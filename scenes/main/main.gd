extends Control
## Main Menu & Game Mode Selector for BioSphere-X.
## Provides New Game, Continue, Settings, Quit, and AI Arena simulation.
## Features comprehensive settings for Audio, Display/Resolution, Difficulty, and Key Remapping.

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
@onready var ambient_vol_slider: HSlider = %AmbientVolSlider
@onready var ambient_vol_val: Label = %AmbientVolVal

@onready var resolution_option: OptionButton = %ResolutionOption
@onready var fullscreen_check: CheckBox = %FullscreenCheck
@onready var screen_shake_check: CheckBox = %ScreenShakeCheck
@onready var camera_smooth_check: CheckBox = %CameraSmoothCheck

@onready var difficulty_option: OptionButton = %DifficultyOption

# Key Remapping Buttons
@onready var move_up_key_btn: Button = %MoveUpKeyBtn
@onready var move_down_key_btn: Button = %MoveDownKeyBtn
@onready var move_left_key_btn: Button = %MoveLeftKeyBtn
@onready var move_right_key_btn: Button = %MoveRightKeyBtn
@onready var interact_key_btn: Button = %InteractKeyBtn
@onready var attack_key_btn: Button = %AttackKeyBtn
@onready var terminal_key_btn: Button = %TerminalKeyBtn
@onready var reset_controls_btn: Button = %ResetControlsBtn

@onready var delete_save_btn: Button = %DeleteSaveBtn
@onready var settings_feedback_label: Label = %SettingsFeedbackLabel
@onready var close_settings_btn: Button = %CloseSettingsBtn

# Key Rebinding State
var _active_rebind_action: String = ""
var _active_rebind_btn: Button = null

const RESOLUTION_OPTIONS: Array[String] = ["1280x720", "1600x900", "1920x1080"]
const DIFFICULTY_OPTIONS: Array[String] = [
	"adaptive_fuzzy",
	"adaptive_simple",
	"easy",
	"normal",
	"hard",
	"nightmare"
]


func _ready() -> void:
	Engine.time_scale = 1.0
	_refresh_save_status()
	_setup_button_events()
	_setup_settings_modal()
	_check_backend_status()
	
	# Hide quit button on platforms that don't support quitting (e.g. Web)
	if OS.has_feature("web") and quit_button:
		quit_button.visible = false


func _play_click() -> void:
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sfx"):
		am.call("play_sfx", "ui_click")


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
			var mission: String = str(meta.get("active_mission", "Survey Surface"))
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

	# Volume Sliders
	if master_vol_slider:
		master_vol_slider.value = float(cfg.get("master_volume", 1.0))
		master_vol_slider.value_changed.connect(_on_master_vol_changed)
		_update_master_label(master_vol_slider.value)

	if sfx_vol_slider:
		sfx_vol_slider.value = float(cfg.get("sfx_volume", 0.8))
		sfx_vol_slider.value_changed.connect(_on_sfx_vol_changed)
		_update_sfx_label(sfx_vol_slider.value)

	if ambient_vol_slider:
		ambient_vol_slider.value = float(cfg.get("ambient_volume", 0.6))
		ambient_vol_slider.value_changed.connect(_on_ambient_vol_changed)
		_update_ambient_label(ambient_vol_slider.value)

	# Display Settings
	if fullscreen_check:
		fullscreen_check.button_pressed = bool(cfg.get("fullscreen", false))
		fullscreen_check.toggled.connect(_on_fullscreen_toggled)

	if resolution_option:
		var cur_res: String = str(cfg.get("resolution", "1280x720"))
		var res_idx := RESOLUTION_OPTIONS.find(cur_res)
		if res_idx >= 0:
			resolution_option.selected = res_idx
		resolution_option.item_selected.connect(_on_resolution_selected)

	if screen_shake_check:
		screen_shake_check.button_pressed = bool(cfg.get("screen_shake", true))

	if camera_smooth_check:
		camera_smooth_check.button_pressed = bool(cfg.get("camera_smoothing", true))

	# Difficulty Settings
	if difficulty_option:
		var cur_diff: String = str(cfg.get("difficulty_mode", "adaptive_fuzzy"))
		var diff_idx := DIFFICULTY_OPTIONS.find(cur_diff)
		if diff_idx >= 0:
			difficulty_option.selected = diff_idx
		difficulty_option.item_selected.connect(_on_difficulty_selected)

	# Key Rebinding Buttons
	_setup_key_rebind_buttons()

	if delete_save_btn:
		delete_save_btn.pressed.connect(_on_delete_save_pressed)

	if close_settings_btn:
		close_settings_btn.pressed.connect(_on_close_settings_pressed)


func _setup_key_rebind_buttons() -> void:
	var sm = get_node_or_null("/root/SaveManager")
	var bindings: Dictionary = sm.current_settings.get("keybindings", {}) if sm else {}
	
	_bind_key_btn(move_up_key_btn, "move_up", bindings.get("move_up", KEY_W))
	_bind_key_btn(move_down_key_btn, "move_down", bindings.get("move_down", KEY_S))
	_bind_key_btn(move_left_key_btn, "move_left", bindings.get("move_left", KEY_A))
	_bind_key_btn(move_right_key_btn, "move_right", bindings.get("move_right", KEY_D))
	_bind_key_btn(interact_key_btn, "interact", bindings.get("interact", KEY_E))
	_bind_key_btn(attack_key_btn, "attack", bindings.get("attack", KEY_SPACE))
	_bind_key_btn(terminal_key_btn, "terminal", bindings.get("terminal", KEY_QUOTELEFT))
	
	if reset_controls_btn:
		reset_controls_btn.pressed.connect(_on_reset_controls_pressed)


func _bind_key_btn(btn: Button, action_name: String, keycode: int) -> void:
	if not btn:
		return
	btn.text = "[ %s ]" % OS.get_keycode_string(keycode as Key)
	if not btn.is_connected("pressed", _on_rebind_btn_pressed.bind(action_name, btn)):
		btn.pressed.connect(_on_rebind_btn_pressed.bind(action_name, btn))


func _on_rebind_btn_pressed(action_name: String, btn: Button) -> void:
	_play_click()
	_active_rebind_action = action_name
	_active_rebind_btn = btn
	btn.text = "PRESS ANY KEY..."
	btn.modulate = Color(1.0, 0.85, 0.2)


func _input(event: InputEvent) -> void:
	if _active_rebind_action.is_empty():
		return
		
	if event is InputEventKey and event.pressed and not event.echo:
		var sm = get_node_or_null("/root/SaveManager")
		if sm and "current_settings" in sm:
			var bindings: Dictionary = sm.current_settings.get("keybindings", {})
			bindings[_active_rebind_action] = event.keycode
			sm.apply_keybindings(bindings)
			
		if _active_rebind_btn:
			_active_rebind_btn.text = "[ %s ]" % OS.get_keycode_string(event.keycode)
			_active_rebind_btn.modulate = Color.WHITE
			
		_play_click()
		_active_rebind_action = ""
		_active_rebind_btn = null
		get_viewport().set_input_as_handled()


func _on_reset_controls_pressed() -> void:
	_play_click()
	var default_keys := {
		"move_up": KEY_W,
		"move_down": KEY_S,
		"move_left": KEY_A,
		"move_right": KEY_D,
		"interact": KEY_E,
		"attack": KEY_SPACE,
		"terminal": KEY_QUOTELEFT,
		"inventory": KEY_TAB,
		"build": KEY_B
	}
	var sm = get_node_or_null("/root/SaveManager")
	if sm and "current_settings" in sm:
		sm.current_settings["keybindings"] = default_keys.duplicate()
		sm.apply_keybindings(default_keys)
	_setup_key_rebind_buttons()
	if settings_feedback_label:
		settings_feedback_label.text = "✓ Keybindings restored to defaults."
		settings_feedback_label.modulate = Color(0.3, 1.0, 0.6)
		settings_feedback_label.visible = true


func _on_continue_pressed() -> void:
	_play_click()
	var sm = get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("load_game"):
		print("BioSphere-X: Resuming Expedition Campaign...")
		sm.call("load_game")
		get_tree().change_scene_to_file("res://scenes/world/game_world.tscn")


func _on_new_game_pressed() -> void:
	_play_click()
	var sm = get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("start_new_game"):
		print("BioSphere-X: Initializing Fresh Expedition Campaign...")
		sm.call("start_new_game")
	get_tree().change_scene_to_file("res://scenes/world/game_world.tscn")


func _on_ai_arena_pressed() -> void:
	_play_click()
	print("BioSphere-X: Launching AI vs AI Simulation Arena...")
	get_tree().change_scene_to_file("res://scenes/ai_vs_ai/ai_arena.tscn")


func _on_settings_pressed() -> void:
	_play_click()
	if settings_feedback_label:
		settings_feedback_label.visible = false
	if settings_modal:
		settings_modal.visible = true


func _on_close_settings_pressed() -> void:
	_play_click()
	var sm = get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("save_settings"):
		var cur_res := "1280x720"
		if resolution_option and resolution_option.selected >= 0 and resolution_option.selected < RESOLUTION_OPTIONS.size():
			cur_res = RESOLUTION_OPTIONS[resolution_option.selected]
			
		var cur_diff := "adaptive_fuzzy"
		if difficulty_option and difficulty_option.selected >= 0 and difficulty_option.selected < DIFFICULTY_OPTIONS.size():
			cur_diff = DIFFICULTY_OPTIONS[difficulty_option.selected]

		var updated_cfg := {
			"master_volume": master_vol_slider.value if master_vol_slider else 1.0,
			"sfx_volume": sfx_vol_slider.value if sfx_vol_slider else 0.8,
			"ambient_volume": ambient_vol_slider.value if ambient_vol_slider else 0.6,
			"resolution": cur_res,
			"fullscreen": fullscreen_check.button_pressed if fullscreen_check else false,
			"screen_shake": screen_shake_check.button_pressed if screen_shake_check else true,
			"camera_smoothing": camera_smooth_check.button_pressed if camera_smooth_check else true,
			"difficulty_mode": cur_diff
		}
		sm.call("save_settings", updated_cfg)
	if settings_modal:
		settings_modal.visible = false


func _on_delete_save_pressed() -> void:
	_play_click()
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
	_play_click()
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


func _on_ambient_vol_changed(value: float) -> void:
	_update_ambient_label(value)
	var sm = get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("apply_settings"):
		sm.call("apply_settings", {"ambient_volume": value})


func _on_resolution_selected(index: int) -> void:
	if index >= 0 and index < RESOLUTION_OPTIONS.size():
		var res_str := RESOLUTION_OPTIONS[index]
		var sm = get_node_or_null("/root/SaveManager")
		if sm and sm.has_method("apply_settings"):
			sm.call("apply_settings", {"resolution": res_str})


func _on_difficulty_selected(index: int) -> void:
	if index >= 0 and index < DIFFICULTY_OPTIONS.size():
		var diff_str := DIFFICULTY_OPTIONS[index]
		var sm = get_node_or_null("/root/SaveManager")
		if sm and sm.has_method("apply_settings"):
			sm.call("apply_settings", {"difficulty_mode": diff_str})


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


func _update_ambient_label(val: float) -> void:
	if ambient_vol_val:
		ambient_vol_val.text = "%d%%" % int(round(val * 100.0))


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
