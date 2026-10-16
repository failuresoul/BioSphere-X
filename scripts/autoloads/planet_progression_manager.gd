extends Node
## Central Planet Progression and Level Transition Subsystem for BioSphere-X.
## Manages planetary unlocks, progression milestones, level configuration mapping,
## persistence (save/load), and loading transitions between planets without duplicating
## global UI, player inventory, or game-state singletons.

signal planet_unlocked(planet_id: String, planet_name: String)
signal planet_changed(planet_id: String, config: RefCounted)
signal transition_started(from_planet: String, to_planet: String)
signal transition_completed(planet_id: String)
signal transition_rejected(planet_id: String, reason: String)
signal progression_saved()
signal progression_loaded()

const DEFAULT_SAVE_PATH := "user://planet_progression_save.json"
const PlanetLevelConfigScript := preload("res://scripts/components/planet_level_config.gd")
const LevelLoadingScreenScene := preload("res://ui/components/level_loading_screen.tscn")

# Registered Planet Level Configurations
var _configs: Dictionary = {}
var _planet_order: Array[String] = []

# Progression State
var unlocked_planets: Array[String] = ["trappist_1_e"]
var current_planet_id: String = "trappist_1_e"
var completed_missions: Dictionary = {
	"trappist_1_e": [],
	"lhs_1140_b": []
}
var planet_expedition_stats: Dictionary = {}

# Loading Screen Overlay Reference
var _loading_screen: CanvasLayer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_default_planets()
	_setup_loading_screen()
	_connect_mission_events()
	load_progression(DEFAULT_SAVE_PATH)


func _register_default_planets() -> void:
	_configs.clear()
	_planet_order.clear()
	
	# Planet 1: TRAPPIST-1 e (Starter habitable world)
	var trappist = PlanetLevelConfigScript.create_trappist_1_e()
	register_planet_config(trappist)
	
	# Planet 2: LHS 1140 b (Super-Earth dense mineral world)
	var lhs = PlanetLevelConfigScript.create_lhs_1140_b()
	register_planet_config(lhs)


func register_planet_config(config: Variant) -> void:
	var id: String = ""
	if "planet_id" in config:
		id = str(config.planet_id)
	elif config.has_method("get"):
		var val = config.get("planet_id")
		if val != null:
			id = str(val)
	if id.is_empty():
		push_warning("[PlanetProgression] Config missing planet_id")
		return
	_configs[id] = config
	if not _planet_order.has(id):
		_planet_order.append(id)
	if not completed_missions.has(id):
		completed_missions[id] = []


func _setup_loading_screen() -> void:
	if not _loading_screen:
		_loading_screen = LevelLoadingScreenScene.instantiate()
		_loading_screen.name = "LevelLoadingScreen"
		add_child(_loading_screen)


func _connect_mission_events() -> void:
	var mm = get_node_or_null("/root/MissionManager")
	if mm and mm.has_signal("mission_completed"):
		mm.mission_completed.connect(_on_mission_completed)


func _on_mission_completed(mission: RefCounted, _rewards: Dictionary) -> void:
	var m_id: String = str(mission.get("id"))
	notify_mission_completed(m_id, current_planet_id)


## Called when a mission finishes; evaluates planetary unlock criteria
func notify_mission_completed(mission_id: String, p_planet_id: String = "") -> void:
	var target_planet = p_planet_id if not p_planet_id.is_empty() else current_planet_id
	if not completed_missions.has(target_planet):
		completed_missions[target_planet] = []
	if not completed_missions[target_planet].has(mission_id):
		completed_missions[target_planet].append(mission_id)
		
	# Check unlock triggers across all configured planets
	for pid in _planet_order:
		if is_planet_unlocked(pid):
			continue
			
		var cfg: RefCounted = _configs.get(pid, null)
		if not cfg:
			continue
			
		var req_planet: String = str(cfg.get("unlock_required_planet_id"))
		var req_mission: String = str(cfg.get("unlock_required_mission_id"))
		
		# If criteria is met, unlock!
		var planet_satisfied = req_planet.is_empty() or req_planet == target_planet
		var mission_satisfied = req_mission.is_empty() or completed_missions.get(req_planet, []).has(req_mission)
		
		if planet_satisfied and mission_satisfied:
			unlock_planet(pid)
			
	save_progression(DEFAULT_SAVE_PATH)


func unlock_planet(planet_id: String) -> bool:
	if not _configs.has(planet_id):
		return false
	if unlocked_planets.has(planet_id):
		return false
		
	unlocked_planets.append(planet_id)
	var cfg_obj = _configs.get(planet_id)
	var p_name: String = str(cfg_obj.get("planet_name")) if cfg_obj else planet_id
	print("[PlanetProgression] ORBITAL DESTINATION UNLOCKED: %s!" % p_name)
	planet_unlocked.emit(planet_id, p_name)
	
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.has_signal("objective_changed"):
		gs.objective_changed.emit("HYPERSPACE UNLOCKED // Sector vector to %s authorized!" % p_name)
		
	return true


func is_planet_unlocked(planet_id: String) -> bool:
	return unlocked_planets.has(planet_id)


func get_planet_lock_reason(planet_id: String) -> String:
	if is_planet_unlocked(planet_id):
		return ""
	if not _configs.has(planet_id):
		return "Unknown planetary coordinates."
		
	var cfg: RefCounted = _configs[planet_id]
	var desc: String = str(cfg.get("unlock_description"))
	if not desc.is_empty():
		return "🔒 LOCKED: %s" % desc
	var req_p: String = str(cfg.get("unlock_required_planet_id"))
	var req_m: String = str(cfg.get("unlock_required_mission_id"))
	return "🔒 LOCKED: Complete mission '%s' on %s to unlock." % [req_m, req_p]


# ---------------------------------------------------------------------------
# Level Transition Execution
# ---------------------------------------------------------------------------
## Transitions to the specified planet without duplicating player, HUD, or singletons
func transition_to_planet(target_planet_id: String, instant: bool = false) -> bool:
	if not _configs.has(target_planet_id):
		var err := "Unknown planet ID '%s'." % target_planet_id
		push_warning("[PlanetProgression] %s" % err)
		transition_rejected.emit(target_planet_id, err)
		return false
		
	if not is_planet_unlocked(target_planet_id):
		var reason := get_planet_lock_reason(target_planet_id)
		print("[PlanetProgression] Transition rejected: %s" % reason)
		transition_rejected.emit(target_planet_id, reason)
		return false
		
	var cfg: RefCounted = _configs[target_planet_id]
	var from_cfg = _configs.get(current_planet_id)
	var from_planet: String = str(from_cfg.get("planet_name")) if from_cfg else current_planet_id
	var to_planet: String = str(cfg.get("planet_name")) if cfg.get("planet_name") != null else target_planet_id
	
	print("[PlanetProgression] Initiating hyperspace jump from %s to %s..." % [from_planet, to_planet])
	transition_started.emit(current_planet_id, target_planet_id)
	
	current_planet_id = target_planet_id
	
	# Update GameState & ExoplanetDatabase destination
	var gs = get_node_or_null("/root/GameState")
	if gs and "selected_planet" in gs:
		gs.selected_planet = to_planet
		
	var db = get_node_or_null("/root/ExoplanetDatabase")
	if db and db.has_method("select_planet"):
		db.call("select_planet", target_planet_id)
		
	# Execute level reconfiguration
	var execute_load := func():
		var world = get_tree().get_first_node_in_group("world")
		if world and world.has_method("load_planet_level"):
			world.call("load_planet_level", cfg)
		planet_changed.emit(target_planet_id, cfg)
		save_progression(DEFAULT_SAVE_PATH)
		transition_completed.emit(target_planet_id)
		
	if instant or not _loading_screen:
		execute_load.call()
	else:
		_loading_screen.call("start_transition", from_planet, to_planet, execute_load)
		
	return true


# ---------------------------------------------------------------------------
# Save & Load Persistence
# ---------------------------------------------------------------------------
func save_progression(save_path: String = DEFAULT_SAVE_PATH) -> bool:
	var data := {
		"version": 1,
		"current_planet_id": current_planet_id,
		"unlocked_planets": unlocked_planets,
		"completed_missions": completed_missions,
		"planet_expedition_stats": planet_expedition_stats,
		"save_timestamp": Time.get_datetime_string_from_system()
	}
	
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if not file:
		push_warning("[PlanetProgression] Failed to open %s for saving." % save_path)
		return false
		
	file.store_string(JSON.stringify(data, "  "))
	file.close()
	print("[PlanetProgression] Progression state saved to %s." % save_path)
	progression_saved.emit()
	return true


func load_progression(save_path: String = DEFAULT_SAVE_PATH) -> bool:
	if not FileAccess.file_exists(save_path):
		return false
		
	var file := FileAccess.open(save_path, FileAccess.READ)
	if not file:
		return false
		
	var content := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var err := json.parse(content)
	if err != OK or not (json.data is Dictionary):
		return false
		
	var data: Dictionary = json.data
	current_planet_id = str(data.get("current_planet_id", "trappist_1_e"))
	
	var unl_arr: Array = data.get("unlocked_planets", ["trappist_1_e"])
	unlocked_planets.clear()
	for u in unl_arr:
		var u_str := str(u)
		if not unlocked_planets.has(u_str):
			unlocked_planets.append(u_str)
			
	var comp_dict: Dictionary = data.get("completed_missions", {})
	completed_missions = comp_dict.duplicate(true)
	planet_expedition_stats = data.get("planet_expedition_stats", {}).duplicate(true)
	
	print("[PlanetProgression] Loaded progression: Current=%s, Unlocked=%s" % [current_planet_id, str(unlocked_planets)])
	progression_loaded.emit()
	return true


func reset_progression() -> void:
	unlocked_planets.clear()
	unlocked_planets.append("trappist_1_e")
	current_planet_id = "trappist_1_e"
	completed_missions = {
		"trappist_1_e": [],
		"lhs_1140_b": []
	}
	planet_expedition_stats.clear()
	save_progression(DEFAULT_SAVE_PATH)


func get_planet_config(planet_id: String) -> RefCounted:
	return _configs.get(planet_id, null)


func get_current_planet_config() -> RefCounted:
	return _configs.get(current_planet_id, null)


func get_all_planet_configs() -> Array:
	var list: Array = []
	for pid in _planet_order:
		list.append(_configs[pid])
	return list
