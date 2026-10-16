extends Node
## BioSphere-X Central Save & Load Management Subsystem.
## Provides versioned, validated game-state persistence, graceful error handling for missing
## or corrupted files, settings persistence, and safe object/mission restoration without duplication.

signal game_saved(path: String, metadata: Dictionary)
signal game_loaded(path: String, metadata: Dictionary)
signal save_failed(reason: String)
signal load_failed(reason: String)
signal settings_updated(settings: Dictionary)

const DEFAULT_SAVE_PATH: String = "user://biosphere_x_save.json"
const SETTINGS_SAVE_PATH: String = "user://biosphere_x_settings.json"
const CURRENT_SAVE_VERSION: int = 1
const SAVE_FORMAT_TAG: String = "BioSphere-X-Save"

# Pending save load flag for level initialization
var is_pending_load: bool = false
var _cached_save_data: Dictionary = {}
var _last_error: String = ""


func get_last_error() -> String:
	return _last_error

# User Settings Dictionary
var current_settings: Dictionary = {
	"master_volume": 1.0,
	"sfx_volume": 0.8,
	"ambient_volume": 0.6,
	"screen_shake": true,
	"camera_smoothing": true,
	"fullscreen": false,
	"resolution": "1280x720",
	"difficulty_mode": "adaptive_fuzzy",
	"keybindings": {
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
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()


# ---------------------------------------------------------------------------
# Save File Existence & Metadata Inspection
# ---------------------------------------------------------------------------
func has_save_file(path: String = DEFAULT_SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return false
	var content := file.get_as_text()
	file.close()
	if content.strip_edges().is_empty():
		return false
	var json := JSON.new()
	if json.parse(content) != OK or not (json.data is Dictionary):
		return false
	return bool(json.data.get("format_tag") == SAVE_FORMAT_TAG)


func get_save_metadata(path: String = DEFAULT_SAVE_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var content := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(content) != OK or not (json.data is Dictionary):
		return {}
	return json.data.get("meta", {})


# ---------------------------------------------------------------------------
# Validation Engine (Schema & Integrity Check)
# ---------------------------------------------------------------------------
func validate_save_data(save_dict: Variant) -> Dictionary:
	if not (save_dict is Dictionary):
		return {"valid": false, "reason": "Root save content is not a Dictionary."}
		
	if save_dict.get("format_tag") != SAVE_FORMAT_TAG:
		return {"valid": false, "reason": "Invalid or missing format tag (expected '%s')." % SAVE_FORMAT_TAG}
		
	var ver: int = int(save_dict.get("version", 0))
	if ver < 1 or ver > CURRENT_SAVE_VERSION:
		return {"valid": false, "reason": "Unsupported save version: %d (Current: %d)." % [ver, CURRENT_SAVE_VERSION]}
		
	var required_sections := ["meta", "player", "inventory", "missions", "progression", "construction"]
	for section in required_sections:
		if not save_dict.has(section) or not (save_dict[section] is Dictionary or save_dict[section] is Array):
			return {"valid": false, "reason": "Corrupted or missing required section: '%s'." % section}
			
	# Validate player section
	var player_sec: Dictionary = save_dict.get("player", {})
	if not player_sec.has("health") or not player_sec.has("oxygen"):
		return {"valid": false, "reason": "Incomplete player vitality data in save."}
		
	# Validate inventory section
	var inv_sec: Dictionary = save_dict.get("inventory", {})
	if not inv_sec.has("carried_resources") or not inv_sec.has("items"):
		return {"valid": false, "reason": "Incomplete inventory payload in save."}
		
	return {"valid": true, "reason": "Validation passed."}


# ---------------------------------------------------------------------------
# Core Save Operations
# ---------------------------------------------------------------------------
func save_game(path: String = DEFAULT_SAVE_PATH) -> bool:
	var gs = get_node_or_null("/root/GameState")
	var inv = get_node_or_null("/root/InventoryManager")
	var mm = get_node_or_null("/root/MissionManager")
	var ppm = get_node_or_null("/root/PlanetProgressionManager")
	var cm = get_node_or_null("/root/ConstructionManager")
	var player = get_tree().get_first_node_in_group("player") as Node2D
	
	var active_mission_title := ""
	if mm and mm.has_method("get_active_mission"):
		var m = mm.call("get_active_mission")
		if m and "title" in m:
			active_mission_title = str(m.title)
			
	var current_planet: String = "trappist_1_e"
	var planet_name: String = "TRAPPIST-1 e"
	if ppm and "current_planet_id" in ppm:
		current_planet = str(ppm.current_planet_id)
	if gs and "selected_planet" in gs:
		planet_name = str(gs.selected_planet)
		
	var p_pos := {"x": 0.0, "y": 0.0}
	if player and is_instance_valid(player):
		p_pos["x"] = player.global_position.x
		p_pos["y"] = player.global_position.y
		
	var items_payload: Dictionary = inv.call("get_all_items") if inv and inv.has_method("get_all_items") else {}
	if gs and "resources" in gs:
		for rk in gs.resources:
			items_payload[rk] = int(gs.resources[rk])
		
	var save_data: Dictionary = {
		"format_tag": SAVE_FORMAT_TAG,
		"version": CURRENT_SAVE_VERSION,
		"meta": {
			"timestamp": Time.get_datetime_string_from_system(),
			"planet_id": current_planet,
			"planet_name": planet_name,
			"active_mission": active_mission_title,
			"save_version": CURRENT_SAVE_VERSION,
			"format_version": CURRENT_SAVE_VERSION
		},
		"player": {
			"health": gs.health if gs else 100.0,
			"max_health": gs.max_health if gs else 100.0,
			"oxygen": gs.oxygen if gs else 100.0,
			"max_oxygen": gs.max_oxygen if gs else 100.0,
			"energy": gs.energy if gs else 100.0,
			"max_energy": gs.max_energy if gs else 100.0,
			"position": p_pos
		},
		"inventory": {
			"carried_resources": gs.resources.duplicate() if gs else {},
			"base_storage": gs.base_storage.duplicate() if gs else {},
			"items": items_payload,
			"upgrades": inv.call("get_installed_upgrades") if inv and inv.has_method("get_installed_upgrades") else []
		},
		"missions": mm.call("get_missions_save_data") if mm and mm.has_method("get_missions_save_data") else {},
		"progression": {
			"current_planet_id": current_planet,
			"unlocked_planets": ppm.unlocked_planets.duplicate() if ppm and "unlocked_planets" in ppm else ["trappist_1_e"],
			"completed_missions": ppm.completed_missions.duplicate() if ppm and "completed_missions" in ppm else []
		},
		"construction": cm.call("get_placed_structures_save_data") if cm and cm.has_method("get_placed_structures_save_data") else [],
		"settings": current_settings.duplicate()
	}
	
	var json_str := JSON.stringify(save_data, "  ")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		var err := "Failed to open save file '%s' for writing (Error: %s)." % [path, str(FileAccess.get_open_error())]
		_last_error = err
		push_error("[SaveManager] %s" % err)
		save_failed.emit(err)
		return false
		
	file.store_string(json_str)
	file.close()
	
	_last_error = ""
	print("[SaveManager] Game state successfully saved to '%s' (Meta: %s)" % [path, str(save_data["meta"])])
	game_saved.emit(path, save_data["meta"])
	return true


# ---------------------------------------------------------------------------
# Core Load Operations
# ---------------------------------------------------------------------------
func load_game(path: String = DEFAULT_SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path):
		var err := "Save file does not exist at '%s'." % path
		_last_error = err
		push_warning("[SaveManager] %s" % err)
		load_failed.emit(err)
		return false
		
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		var err := "Failed to open save file '%s' for reading." % path
		_last_error = err
		push_error("[SaveManager] %s" % err)
		load_failed.emit(err)
		return false
		
	var content := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var parse_err := json.parse(content)
	if parse_err != OK:
		var err := "Corrupted save file: JSON parse error '%s' at line %d." % [json.get_error_message(), json.get_error_line()]
		_last_error = err
		push_error("[SaveManager] %s" % err)
		load_failed.emit(err)
		return false
		
	var validation := validate_save_data(json.data)
	if not validation["valid"]:
		var err: String = str(validation["reason"])
		_last_error = err
		push_error("[SaveManager] Save file validation failed: %s" % err)
		load_failed.emit(err)
		return false
		
	_last_error = ""
	var save_dict: Dictionary = json.data
	_cached_save_data = save_dict
	return apply_save_data(save_dict, path)


func apply_save_data(save_dict: Dictionary, path: String = DEFAULT_SAVE_PATH) -> bool:
	var gs = get_node_or_null("/root/GameState")
	var inv = get_node_or_null("/root/InventoryManager")
	var mm = get_node_or_null("/root/MissionManager")
	var ppm = get_node_or_null("/root/PlanetProgressionManager")
	var cm = get_node_or_null("/root/ConstructionManager")
	
	# 1. Restore Player Vitality
	var p_sec: Dictionary = save_dict.get("player", {})
	if gs:
		gs.health = float(p_sec.get("health", gs.max_health))
		gs.oxygen = float(p_sec.get("oxygen", gs.max_oxygen))
		gs.energy = float(p_sec.get("energy", gs.max_energy))
		gs.is_oxygen_depleted = gs.oxygen <= 0.0
		gs.is_low_oxygen = (gs.oxygen / gs.max_oxygen) <= 0.25
		gs.health_changed.emit(gs.health, gs.max_health)
		gs.oxygen_changed.emit(gs.oxygen, gs.max_oxygen)
		gs.energy_changed.emit(gs.energy, gs.max_energy)
		
	# Reposition player node if active in scene
	var player = get_tree().get_first_node_in_group("player") as Node2D
	if player and is_instance_valid(player) and p_sec.has("position"):
		var pos_dict: Dictionary = p_sec.get("position", {})
		player.global_position = Vector2(float(pos_dict.get("x", 0.0)), float(pos_dict.get("y", 0.0)))
		
	# 2. Restore Inventory & Vault Storage
	var inv_sec: Dictionary = save_dict.get("inventory", {})
	var c_res: Dictionary = inv_sec.get("carried_resources", {})
	if gs:
		for k in c_res:
			gs.resources[k] = int(c_res[k])
			if gs.has_signal("resource_changed"):
				gs.resource_changed.emit(k, gs.resources[k])
				
	if inv and inv.has_method("restore_inventory_data"):
		var items_dict: Dictionary = inv_sec.get("items", {}).duplicate()
		for k in c_res:
			if not items_dict.has(k) or items_dict[k] == 0:
				items_dict[k] = int(c_res[k])
		var upg_arr: Array = inv_sec.get("upgrades", [])
		inv.call("restore_inventory_data", items_dict, upg_arr)
				
	if gs and inv_sec.has("base_storage"):
		var b_st: Dictionary = inv_sec.get("base_storage", {})
		for k in b_st:
			gs.base_storage[k] = int(b_st[k])
			if gs.has_signal("storage_changed"):
				gs.storage_changed.emit(k, gs.base_storage[k], gs.resources.get(k, 0))
				
	# 3. Restore Mission Progress (Prevent duplication / false completions)
	var m_sec: Dictionary = save_dict.get("missions", {})
	if mm and mm.has_method("restore_missions_save_data"):
		mm.call("restore_missions_save_data", m_sec)
		
	# 4. Restore Planet Progression
	var prog_sec: Dictionary = save_dict.get("progression", {})
	if ppm:
		var p_id: String = str(prog_sec.get("current_planet_id", "trappist_1_e"))
		ppm.set("current_planet_id", p_id)
		if prog_sec.has("unlocked_planets") and "unlocked_planets" in ppm:
			ppm.unlocked_planets.clear()
			for u in prog_sec["unlocked_planets"]:
				ppm.unlocked_planets.append(str(u))
		if prog_sec.has("completed_missions") and "completed_missions" in ppm:
			if prog_sec["completed_missions"] is Dictionary:
				ppm.completed_missions = prog_sec["completed_missions"].duplicate(true)
			elif prog_sec["completed_missions"] is Array:
				var c_dict: Dictionary = {}
				var cur_p: String = ppm.current_planet_id
				c_dict[cur_p] = []
				for c in prog_sec["completed_missions"]:
					c_dict[cur_p].append(str(c))
				ppm.completed_missions = c_dict
		if gs and "selected_planet" in gs and save_dict.has("meta"):
			gs.selected_planet = str(save_dict["meta"].get("planet_name", "TRAPPIST-1 e"))
			
	# 5. Restore Construction Structures (Clears existing to prevent duplicates)
	var c_sec: Array = save_dict.get("construction", [])
	if cm and cm.has_method("restore_placed_structures"):
		cm.call("restore_placed_structures", c_sec)
		
	# 6. Apply Saved Settings
	if save_dict.has("settings") and save_dict["settings"] is Dictionary:
		apply_settings(save_dict["settings"])
		
	print("[SaveManager] Game state successfully restored from '%s'." % path)
	game_loaded.emit(path, save_dict.get("meta", {}))
	return true


func prepare_continue_game() -> void:
	is_pending_load = true


func apply_pending_save_if_any() -> void:
	if not is_pending_load:
		return
	is_pending_load = false
	if not _cached_save_data.is_empty():
		apply_save_data(_cached_save_data)
	else:
		load_game(DEFAULT_SAVE_PATH)


func create_new_game() -> void:
	is_pending_load = false
	_cached_save_data.clear()
	
	# Reset GameState
	var gs = get_node_or_null("/root/GameState")
	if gs:
		gs.health = gs.max_health
		gs.oxygen = gs.max_oxygen
		gs.energy = gs.max_energy
		gs.is_oxygen_depleted = false
		gs.is_low_oxygen = false
		gs.is_paused = false
		gs.is_game_over = false
		gs.resources = {"crystals": 0, "titanium": 0, "biomass": 0, "oxygen_cells": 0}
		gs.base_storage = {"crystals": 0, "titanium": 0, "biomass": 0, "oxygen_cells": 0}
		gs.selected_planet = "TRAPPIST-1 e"
		
	# Reset Inventory
	var inv = get_node_or_null("/root/InventoryManager")
	if inv and inv.has_method("reset_inventory"):
		inv.call("reset_inventory")
		
	# Reset Missions
	var mm = get_node_or_null("/root/MissionManager")
	if mm and mm.has_method("reset_campaign"):
		mm.call("reset_campaign")
	elif mm and mm.has_method("start_mission"):
		mm.call("start_mission", "mission_01_oxygen")
		
	# Reset Progression
	var ppm = get_node_or_null("/root/PlanetProgressionManager")
	if ppm:
		ppm.set("current_planet_id", "trappist_1_e")
		if "unlocked_planets" in ppm:
			ppm.unlocked_planets = ["trappist_1_e"]
		if "completed_missions" in ppm:
			ppm.completed_missions = []
			
	# Reset Construction
	var cm = get_node_or_null("/root/ConstructionManager")
	if cm and cm.has_method("clear_all_structures"):
		cm.call("clear_all_structures")
		
	print("[SaveManager] New Game state initialized.")


func delete_save(path: String = DEFAULT_SAVE_PATH) -> bool:
	if FileAccess.file_exists(path):
		var err := DirAccess.remove_absolute(path)
		if err == OK:
			print("[SaveManager] Save file '%s' deleted." % path)
			return true
		else:
			push_warning("[SaveManager] Failed to delete save file '%s' (Error: %d)." % [path, err])
			return false
	return true


# ---------------------------------------------------------------------------
# User Settings Management
# ---------------------------------------------------------------------------
func load_settings(path: String = SETTINGS_SAVE_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return current_settings
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return current_settings
	var content := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(content) == OK and json.data is Dictionary:
		for k in json.data:
			current_settings[k] = json.data[k]
	apply_settings(current_settings)
	return current_settings


func save_settings(new_settings: Dictionary = {}, path: String = SETTINGS_SAVE_PATH) -> bool:
	for k in new_settings:
		current_settings[k] = new_settings[k]
	apply_settings(current_settings)
	
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return false
	file.store_string(JSON.stringify(current_settings, "  "))
	file.close()
	settings_updated.emit(current_settings)
	return true


func apply_settings(settings_dict: Dictionary) -> void:
	for k in settings_dict:
		current_settings[k] = settings_dict[k]
		
	# Apply Audio Volumes
	var m_vol: float = clampf(float(current_settings.get("master_volume", 1.0)), 0.0, 1.0)
	var s_vol: float = clampf(float(current_settings.get("sfx_volume", 0.8)), 0.0, 1.0)
	var a_vol: float = clampf(float(current_settings.get("ambient_volume", 0.6)), 0.0, 1.0)
	
	if AudioServer.get_bus_count() > 0:
		var master_idx := AudioServer.get_bus_index("Master")
		if master_idx >= 0:
			AudioServer.set_bus_volume_db(master_idx, linear_to_db(m_vol) if m_vol > 0.001 else -80.0)
			
	var am = get_node_or_null("/root/AudioManager")
	if am:
		if am.has_method("set_master_volume"):
			am.call("set_master_volume", m_vol)
		if am.has_method("set_sfx_volume"):
			am.call("set_sfx_volume", s_vol)
		if am.has_method("set_ambient_volume"):
			am.call("set_ambient_volume", a_vol)
			
	# Apply Display Mode & Resolution
	if current_settings.get("fullscreen", false):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var res_str: String = str(current_settings.get("resolution", "1280x720"))
		var parts = res_str.split("x")
		if parts.size() == 2:
			var w := int(parts[0])
			var h := int(parts[1])
			if w >= 800 and h >= 600:
				DisplayServer.window_set_size(Vector2i(w, h))
				
	# Apply Difficulty Mode
	var diff: String = str(current_settings.get("difficulty_mode", "adaptive_fuzzy"))
	var dc = get_node_or_null("/root/DifficultyController")
	if dc and dc.has_method("set_difficulty_mode"):
		dc.call("set_difficulty_mode", diff)
		
	# Apply Keybindings
	if current_settings.has("keybindings") and current_settings["keybindings"] is Dictionary:
		apply_keybindings(current_settings["keybindings"])


func apply_keybindings(bindings: Dictionary) -> void:
	for action_name in bindings:
		var keycode: int = int(bindings[action_name])
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		else:
			var events = InputMap.action_get_events(action_name)
			for ev in events:
				if ev is InputEventKey:
					InputMap.action_erase_event(action_name, ev)
		var key_ev := InputEventKey.new()
		key_ev.physical_keycode = keycode as Key
		key_ev.keycode = keycode as Key
		InputMap.action_add_event(action_name, key_ev)


func get_key_name(keycode: int) -> String:
	return OS.get_keycode_string(keycode as Key)
