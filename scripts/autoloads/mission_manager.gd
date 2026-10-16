extends Node
## Central Mission Manager for BioSphere-X.
## Manages expedition objectives, tracks event-driven progress, evaluates completion/failure criteria,
## awards resources and survival upgrades, and synchronizes real-time objective telemetry with the HUD.
##
## Supported Objectives:
##   1. COLLECT_OXYGEN     - Gather required oxygen cells or atmospheric refill units.
##   2. RETRIEVE_SAMPLES   - Salvage alien scientific samples / biomass canisters.
##   3. ACTIVATE_TERMINAL  - Access and override scientific outpost consoles.
##   4. SURVIVE_ENCOUNTER  - Endure alien pressure waves or withstand combat encounters.
##   5. DEFEAT_BOSS        - Defeat apex territorial threat (Goliath Prime).
##   6. RETURN_TO_BASE     - Extract safely back to habitat module airlock.

signal mission_started(mission: RefCounted)
signal mission_progress_updated(mission: RefCounted)
signal mission_completed(mission: RefCounted, rewards: Dictionary)
signal mission_failed(mission: RefCounted, reason: String)
signal campaign_completed()

const MissionDataScript := preload("res://scripts/components/mission_data.gd")

# Event Identifiers
const EVENT_OXYGEN_GAINED: String = "oxygen_gained"
const EVENT_RESOURCE_COLLECTED: String = "resource_collected"
const EVENT_TERMINAL_ACTIVATED: String = "terminal_activated"
const EVENT_ENCOUNTER_TICK: String = "encounter_tick"
const EVENT_ENEMY_DEFEATED: String = "enemy_defeated"
const EVENT_BOSS_DEFEATED: String = "boss_defeated"
const EVENT_BASE_REACHED: String = "base_reached"
const EVENT_PLAYER_DIED: String = "player_died"

# Mission Repository
var _missions: Dictionary = {}
var _mission_order: Array[String] = []
var _active_mission_id: String = ""
var _auto_advance_campaign: bool = true

# Encounter survival timer state
var _encounter_timer: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_default_campaign()
	_connect_event_sources()


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	# Tick survive encounter objectives if active
	var active = get_active_mission()
	if active and active.get("objective_type") == MissionDataScript.ObjectiveType.SURVIVE_ENCOUNTER:
		notify_event(EVENT_ENCOUNTER_TICK, {"delta": delta})


# ---------------------------------------------------------------------------
# Default Campaign Definition
# ---------------------------------------------------------------------------
func _setup_default_campaign() -> void:
	_missions.clear()
	_mission_order.clear()
	
	# Mission 1: Atmospheric Survival (Collect Oxygen)
	var m1 = MissionDataScript.create(
		"mission_01_oxygen",
		"LIFE SUPPORT RECOVERY",
		"Atmosphere toxic. Recover 3 Oxygen Cells from fallen crates or canisters.",
		MissionDataScript.ObjectiveType.COLLECT_OXYGEN,
		3.0,
		{"oxygen_refill": 100.0, "biomass": 1},
		{"required_resource": "oxygen_cells"},
		"Cells"
	)
	register_mission(m1)
	
	# Mission 2: Specimen Acquisition (Retrieve Research Samples)
	var m2 = MissionDataScript.create(
		"mission_02_samples",
		"FIELD SPECIMENS",
		"Harvest 3 Alien Biomass specimens from flora or xenomorph organisms.",
		MissionDataScript.ObjectiveType.RETRIEVE_SAMPLES,
		3.0,
		{"crystals": 3, "titanium": 2},
		{"required_resource": "biomass"},
		"Samples"
	)
	register_mission(m2)
	
	# Mission 3: Terminal Override (Activate Terminal)
	var m3 = MissionDataScript.create(
		"mission_03_terminal",
		"OUTPOST OVERRIDE",
		"Navigate North-East across the canyon and scan the Alpha-7 Research Terminal.",
		MissionDataScript.ObjectiveType.ACTIVATE_TERMINAL,
		1.0,
		{"crystals": 5, "energy_refill": 100.0},
		{"terminal_id": "Alpha-7 Research Terminal"},
		"Terminal"
	)
	register_mission(m3)
	
	# Mission 4: Hostile Encounter (Survive Encounter)
	var m4 = MissionDataScript.create(
		"mission_04_survive",
		"SURVIVE ALIEN ENCOUNTER",
		"Aggressive xenomorphs detected. Survive combat encounter for 12 seconds or neutralize 3 hostiles.",
		MissionDataScript.ObjectiveType.SURVIVE_ENCOUNTER,
		12.0,
		{"titanium": 4, "oxygen_cells": 2},
		{"duration": 12.0, "fail_on_death": true},
		"Seconds"
	)
	register_mission(m4)
	
	# Mission 5: Boss Protocol (Defeat Boss)
	var m5 = MissionDataScript.create(
		"mission_05_boss",
		"GOLIATH PROTOCOL",
		"Track Goliath Prime to the crater basin and neutralize the apex alien creature.",
		MissionDataScript.ObjectiveType.DEFEAT_BOSS,
		1.0,
		{"crystals": 10, "titanium": 10, "biomass": 10},
		{"boss_id": "GoliathPrime"},
		"Apex Threat"
	)
	register_mission(m5)
	
	# Mission 6: Extraction Protocol (Return to Base)
	var m6 = MissionDataScript.create(
		"mission_06_extraction",
		"EXPEDITION EXTRACTION",
		"Surface objectives complete. Return to the Habitat Module Airlock to secure telemetry.",
		MissionDataScript.ObjectiveType.RETURN_TO_BASE,
		1.0,
		{"mission_rating": "EXEMPLARY"},
		{"target_zone": "habitat_airlock"},
		"Airlock"
	)
	register_mission(m6)
	
	# Start first mission by default
	if not _mission_order.is_empty():
		start_mission(_mission_order[0])


func register_mission(mission: RefCounted) -> void:
	if not mission:
		return
	var mid: String = mission.get("id")
	_missions[mid] = mission
	if not _mission_order.has(mid):
		_mission_order.append(mid)


# ---------------------------------------------------------------------------
# Decoupled Event Ingestion Pipeline
# ---------------------------------------------------------------------------
func _connect_event_sources() -> void:
	var gs := get_node_or_null("/root/GameState")
	if gs:
		if gs.has_signal("resource_changed") and not gs.is_connected("resource_changed", _on_game_state_resource_changed):
			gs.connect("resource_changed", _on_game_state_resource_changed)
		if gs.has_signal("game_over_triggered") and not gs.is_connected("game_over_triggered", _on_game_state_game_over):
			gs.connect("game_over_triggered", _on_game_state_game_over)


## Public decoupled event pipeline — gameplay entities notify the MissionManager
## without needing knowledge of specific mission instances or scripts.
func notify_event(event_type: String, event_data: Dictionary = {}) -> void:
	var active: RefCounted = get_active_mission()
	if not active or not active.call("is_active"):
		return
	
	var obj_type: int = active.get("objective_type")
	var completed := false
	
	match event_type:
		EVENT_OXYGEN_GAINED:
			if obj_type == MissionDataScript.ObjectiveType.COLLECT_OXYGEN:
				var amount: float = float(event_data.get("amount", 1.0))
				completed = active.call("add_progress", amount)
				mission_progress_updated.emit(active)
				
		EVENT_RESOURCE_COLLECTED:
			var res_type: String = str(event_data.get("resource_type", "")).to_lower()
			var qty: float = float(event_data.get("quantity", 1.0))
			
			if obj_type == MissionDataScript.ObjectiveType.COLLECT_OXYGEN and (res_type == "oxygen_cells" or res_type == "oxygen"):
				completed = active.call("add_progress", qty)
				mission_progress_updated.emit(active)
			elif obj_type == MissionDataScript.ObjectiveType.RETRIEVE_SAMPLES and (res_type == "biomass" or res_type == "scientific_sample" or res_type == "crystals"):
				completed = active.call("add_progress", qty)
				mission_progress_updated.emit(active)
				
		EVENT_TERMINAL_ACTIVATED:
			if obj_type == MissionDataScript.ObjectiveType.ACTIVATE_TERMINAL:
				completed = active.call("add_progress", 1.0)
				mission_progress_updated.emit(active)
				
		EVENT_ENCOUNTER_TICK:
			if obj_type == MissionDataScript.ObjectiveType.SURVIVE_ENCOUNTER:
				var dt: float = float(event_data.get("delta", 0.0))
				completed = active.call("add_progress", dt)
				mission_progress_updated.emit(active)
				
		EVENT_ENEMY_DEFEATED:
			if obj_type == MissionDataScript.ObjectiveType.SURVIVE_ENCOUNTER:
				# Hostile neutralization adds 3.0s progress toward survival duration
				completed = active.call("add_progress", 3.0)
				mission_progress_updated.emit(active)
				
		EVENT_BOSS_DEFEATED:
			if obj_type == MissionDataScript.ObjectiveType.DEFEAT_BOSS:
				completed = active.call("add_progress", 1.0)
				mission_progress_updated.emit(active)
				
		EVENT_BASE_REACHED:
			if obj_type == MissionDataScript.ObjectiveType.RETURN_TO_BASE:
				completed = active.call("add_progress", 1.0)
				mission_progress_updated.emit(active)
				
		EVENT_PLAYER_DIED:
			# Check fail-on-death condition
			var conds: Dictionary = active.get("completion_conditions")
			if conds.get("fail_on_death", true):
				fail_mission(active.get("id"), "Astronaut eliminated during mission execution.")
				return
	
	if completed:
		_handle_mission_completion(active)


# ---------------------------------------------------------------------------
# Autoload Event Handlers
# ---------------------------------------------------------------------------
func _on_game_state_resource_changed(resource_id: String, count: int) -> void:
	notify_event(EVENT_RESOURCE_COLLECTED, {
		"resource_type": resource_id,
		"quantity": 1,
		"total": count
	})


func _on_game_state_game_over() -> void:
	notify_event(EVENT_PLAYER_DIED)


# ---------------------------------------------------------------------------
# Mission Lifecycle Management
# ---------------------------------------------------------------------------
func start_mission(mission_id: String) -> bool:
	if not _missions.has(mission_id):
		return false
	
	var mission: RefCounted = _missions[mission_id]
	mission.call("start")
	_active_mission_id = mission_id
	
	# Publish objective text to GameState for legacy compatibility
	var gs := get_node_or_null("/root/GameState")
	if gs:
		gs.call("set_objective", "%s // %s" % [mission.get("title"), mission.get("description")])
		
	mission_started.emit(mission)
	mission_progress_updated.emit(mission)
	return true


func complete_mission(mission_id: String) -> void:
	if not _missions.has(mission_id):
		return
	var mission: RefCounted = _missions[mission_id]
	if not mission.call("is_completed"):
		mission.call("complete")
	_handle_mission_completion(mission)


func fail_mission(mission_id: String, reason: String = "Objective Failed.") -> void:
	if not _missions.has(mission_id):
		return
	var mission: RefCounted = _missions[mission_id]
	mission.call("fail", reason)
	
	print("[MissionManager] FAILED: %s — %s" % [mission.get("title"), reason])
	mission_failed.emit(mission, reason)


func restart_mission(mission_id: String) -> bool:
	if not _missions.has(mission_id):
		return false
	var m: RefCounted = _missions[mission_id]
	m.set("state", MissionDataScript.MissionState.LOCKED)
	m.set("current_progress", 0.0)
	m.set("fail_reason", "")
	return start_mission(mission_id)


func _handle_mission_completion(mission: RefCounted) -> void:
	var mid: String = mission.get("id")
	var rewards: Dictionary = mission.get("rewards")
	
	# Grant rewards to GameState
	_grant_rewards(rewards)
	
	print("[MissionManager] COMPLETED: %s! Rewards: %s" % [mission.get("title"), str(rewards)])
	mission_completed.emit(mission, rewards)
	
	# Advance campaign
	if _auto_advance_campaign:
		var curr_idx := _mission_order.find(mid)
		if curr_idx >= 0 and curr_idx < _mission_order.size() - 1:
			var next_id := _mission_order[curr_idx + 1]
			start_mission(next_id)
		else:
			campaign_completed.emit()
			print("[MissionManager] ALL CAMPAIGN EXPEDITION MISSIONS ACCOMPLISHED!")


func _grant_rewards(rewards: Dictionary) -> void:
	var gs := get_node_or_null("/root/GameState")
	if not gs:
		return
	
	for res_key in ["crystals", "titanium", "biomass", "oxygen_cells"]:
		if rewards.has(res_key):
			gs.call("add_resource", res_key, int(rewards[res_key]))
	
	if rewards.has("oxygen_refill"):
		gs.call("refill_oxygen", float(rewards["oxygen_refill"]))
	if rewards.has("energy_refill"):
		gs.call("refill_energy", float(rewards["energy_refill"]))


# ---------------------------------------------------------------------------
# Public Query API
# ---------------------------------------------------------------------------
func get_active_mission() -> RefCounted:
	if _active_mission_id != "" and _missions.has(_active_mission_id):
		return _missions[_active_mission_id]
	return null


func get_mission(mission_id: String) -> RefCounted:
	return _missions.get(mission_id, null)


func get_all_missions() -> Array:
	var list := []
	for mid in _mission_order:
		list.append(_missions[mid])
	return list


func get_active_mission_dict() -> Dictionary:
	var active = get_active_mission()
	return active.call("to_dict") if active else {}


func reset_campaign() -> void:
	_setup_default_campaign()


# ---------------------------------------------------------------------------
# Save & Load Persistence Integration
# ---------------------------------------------------------------------------
func get_missions_save_data() -> Dictionary:
	var m_states := {}
	for mid in _missions:
		var m: RefCounted = _missions[mid]
		m_states[mid] = {
			"state": int(m.get("state")),
			"current_progress": float(m.get("current_progress")),
			"fail_reason": str(m.get("fail_reason"))
		}
	return {
		"active_mission_id": _active_mission_id,
		"mission_order": _mission_order.duplicate(),
		"missions": m_states
	}


func restore_missions_save_data(data: Dictionary) -> void:
	var m_states: Dictionary = {}
	if data.has("missions") and data["missions"] is Dictionary:
		m_states = data["missions"]
	else:
		if data.has("active_mission_id"):
			var act_id: String = str(data.get("active_mission_id"))
			m_states[act_id] = {
				"state": int(data.get("active_mission_state", 1)),
				"current_progress": float(data.get("active_mission_progress", 0.0)),
				"fail_reason": ""
			}
		if data.has("completed_mission_ids") and data["completed_mission_ids"] is Array:
			for c_id in data["completed_mission_ids"]:
				m_states[str(c_id)] = {
					"state": int(MissionDataScript.MissionState.COMPLETED),
					"current_progress": 1.0,
					"fail_reason": ""
				}

	for mid in m_states:
		if not _missions.has(mid):
			# Dynamically register if missing
			var placeholder = MissionDataScript.create(
				mid, mid.capitalize(), "Restored mission objective",
				MissionDataScript.ObjectiveType.COLLECT_OXYGEN, 1.0
			)
			register_mission(placeholder)
			
		var m: RefCounted = _missions[mid]
		var st_dict: Dictionary = m_states[mid]
		m.set("state", int(st_dict.get("state", 0)))
		m.set("current_progress", float(st_dict.get("current_progress", 0.0)))
		m.set("fail_reason", str(st_dict.get("fail_reason", "")))
	
	var new_active: String = str(data.get("active_mission_id", ""))
	if _missions.has(new_active):
		_active_mission_id = new_active
		var active_m: RefCounted = _missions[_active_mission_id]
		var gs := get_node_or_null("/root/GameState")
		if gs:
			gs.call("set_objective", "%s // %s" % [active_m.get("title"), active_m.get("description")])
		mission_progress_updated.emit(active_m)


func get_completed_mission_ids() -> Array[String]:
	var completed: Array[String] = []
	for mid in _mission_order:
		if _missions.has(mid):
			var m = _missions[mid]
			if int(m.get("state")) == int(MissionDataScript.MissionState.COMPLETED):
				completed.append(mid)
	return completed


func reset_missions() -> void:
	_missions.clear()
	_mission_order.clear()
	_active_mission_id = ""


func load_mission_sequence(sequence: Array) -> void:
	reset_missions()
	for m_spec in sequence:
		var m = MissionDataScript.create(
			str(m_spec.get("id")),
			str(m_spec.get("title")),
			str(m_spec.get("desc")),
			int(m_spec.get("type")),
			float(m_spec.get("target")),
			m_spec.get("rewards", {}),
			m_spec.get("params", {}),
			str(m_spec.get("unit", ""))
		)
		register_mission(m)
		
	if not _mission_order.is_empty():
		start_mission(_mission_order[0])
