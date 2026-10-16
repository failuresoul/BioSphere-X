extends Node
## BioSphere-X Rule-Based Inference Engine Controller.
## Connects to the Python AI rule engine via AIClient and provides an embedded local
## forward-chaining inference fallback for offline resilience.
##
## Responsible for:
##   1. Aggregating observable facts from GameState, MissionManager, and world state.
##   2. Forward chaining deduction for mission prerequisites, life support warnings,
##      extraction eligibility, and planetary hazards.
##   3. Resolving contradictory conditions via rule priority and fact overrides.
##   4. Emitting clear signals so Godot HUD and audio components display warnings.
##   5. Applying approved gameplay changes without altering MissionManager internal state.

signal inference_completed(result: Dictionary)
signal warning_issued(warning_type: String, message: String, priority: int)
signal action_approved(action_name: String, details: Dictionary)
signal extraction_status_changed(is_eligible: bool, reason: String)
signal mission_prerequisite_evaluated(prerequisite_key: String, satisfied: bool)
signal environmental_modifier_applied(modifier_key: String, value: Variant)
signal extraction_objective_unlocked()
signal return_terminal_state_changed(is_enabled: bool, reason: String)

# Current derived state
var current_facts: Dictionary = {}
var derived_facts: Dictionary = {}
var applicable_actions: Array = []
var active_explanations: Dictionary = {}
var detected_contradictions: Array = []

# Extraction & Return Terminal state
var is_extraction_eligible: bool = false
var is_extraction_blocked: bool = false
var extraction_block_reason: String = ""
var is_return_terminal_enabled: bool = false
var return_terminal_status_reason: String = "Return terminal offline: Defeat apex boss and collect mission artifact."
var is_extraction_objective_unlocked: bool = false

# Contextual Facts
var in_safe_zone: bool = false
var near_airlock: bool = false
var combat_threat_active: bool = false
var mission_item_collected: bool = false
var boss_defeated: bool = false

# Local rules repository for offline forward chaining fallback
var _local_rules: Array[Dictionary] = []

# Evaluation tick timer
@export var auto_evaluate: bool = true
@export var evaluation_interval: float = 1.0
var _eval_timer: float = 0.0



func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_initialize_default_rules()


func _process(delta: float) -> void:
	if not auto_evaluate:
		return
	
	_eval_timer += delta
	if _eval_timer >= evaluation_interval:
		_eval_timer = 0.0
		evaluate_current_game_state()


# ---------------------------------------------------------------------------
# Fact Gathering & State Aggregation
# ---------------------------------------------------------------------------
func collect_gameplay_facts() -> Dictionary:
	var facts: Dictionary = {}

	# 1. Vitality facts from GameState
	if Engine.has_singleton("GameState") or has_node("/root/GameState"):
		var gs = get_node("/root/GameState")
		facts["oxygen_level"] = float(gs.oxygen)
		facts["health"] = float(gs.health)
		facts["energy"] = float(gs.energy)
		facts["oxygen_depleted"] = bool(gs.is_oxygen_depleted)
		
		# Resource counts
		if "resources" in gs:
			var b_count = int(gs.resources.get("biomass", 0))
			facts["biomass_samples_collected"] = b_count
			facts["sample_count"] = b_count
			facts["samples_carried"] = b_count
			facts["crystals_collected"] = int(gs.resources.get("crystals", 0))
			facts["titanium_collected"] = int(gs.resources.get("titanium", 0))
			if b_count >= 1:
				facts["mission_item_collected"] = true

	# 2. Contextual spatial facts
	facts["in_safe_zone"] = in_safe_zone
	facts["near_airlock"] = near_airlock
	facts["combat_threat_active"] = combat_threat_active
	facts["mission_item_collected"] = mission_item_collected or facts.get("mission_item_collected", false)
	facts["boss_defeated"] = boss_defeated

	# 3. Mission status from MissionManager (read-only observer)
	if Engine.has_singleton("MissionManager") or has_node("/root/MissionManager"):
		var mm = get_node("/root/MissionManager")
		if mm.has_method("is_mission_completed"):
			facts["mission_01_oxygen_completed"] = mm.is_mission_completed("mission_01_oxygen")
			if mm.is_mission_completed("mission_05_boss"):
				facts["boss_defeated"] = true
			if mm.is_mission_completed("mission_02_samples"):
				facts["mission_item_collected"] = true
		if mm.has_method("get_active_mission"):
			var active = mm.get_active_mission()
			if active != null:
				facts["active_mission_id"] = str(active.get("id")) if active.get("id") != null else ""
		# Check if primary missions completed
		var all_primary_done := true
		for m_id in ["mission_01_oxygen", "mission_02_samples"]:
			if mm.has_method("is_mission_completed"):
				if not mm.is_mission_completed(m_id):
					all_primary_done = false
					break
			else:
				all_primary_done = false
		facts["primary_missions_completed"] = all_primary_done

	# 4. Planetary facts from PlanetProgressionManager
	if Engine.has_singleton("PlanetProgressionManager") or has_node("/root/PlanetProgressionManager"):
		var ppm = get_node("/root/PlanetProgressionManager")
		if "current_planet_id" in ppm:
			facts["planet_id"] = str(ppm.current_planet_id)
		if ppm.has_method("get_current_planet_data"):
			var pdata = ppm.get_current_planet_data()
			if pdata:
				var temp_val = pdata.get("equilibrium_temp_k")
				facts["ambient_temperature_k"] = float(temp_val) if temp_val != null else 280.0
				var haz_val = pdata.get("hazard_rating")
				facts["planet_hazard_rating"] = int(haz_val) if haz_val != null else 1

	return facts


# ---------------------------------------------------------------------------
# High-Level Evaluation & Inference
# ---------------------------------------------------------------------------
func evaluate_current_game_state(callback: Callable = Callable()) -> void:
	var facts := collect_gameplay_facts()
	evaluate_facts(facts, true, callback)


func evaluate_facts(facts: Dictionary, try_backend: bool = true, callback: Callable = Callable()) -> void:
	# If backend is available and requested, call Python AI backend
	var ai_client_node = get_node_or_null("/root/AIClient")
	if try_backend and ai_client_node and ai_client_node.is_backend_available:
		ai_client_node.request_rule_inference(facts, [], 50, func(response: Dictionary) -> void:
			if response.get("success", false) and response.has("data"):
				var data: Dictionary = response["data"]
				_process_inference_result(data)
				if callback.is_valid():
					callback.call(data)
			else:
				# Backend request failed or timed out: fall back to local rule engine
				var local_res := evaluate_facts_local(facts)
				_process_inference_result(local_res)
				if callback.is_valid():
					callback.call(local_res)
		)
	else:
		# Local fast deterministic forward chaining
		var local_res := evaluate_facts_local(facts)
		_process_inference_result(local_res)
		if callback.is_valid():
			callback.call(local_res)


# ---------------------------------------------------------------------------
# Result Processing & Applying Approved Gameplay Changes
# ---------------------------------------------------------------------------
func _process_inference_result(result: Dictionary) -> void:
	derived_facts = result.get("derived_facts", {})
	current_facts = result.get("all_facts", {})
	applicable_actions = result.get("applicable_actions", [])
	active_explanations = result.get("explanations", {})
	detected_contradictions = result.get("contradictions_detected", [])

	# 1. Update Extraction Status
	var eligible: bool = bool(current_facts.get("extraction_eligible", false))
	var blocked: bool = bool(current_facts.get("extraction_blocked", false))
	
	if blocked:
		is_extraction_eligible = false
		is_extraction_blocked = true
		extraction_block_reason = "Hostile threat pursuit detected: Airlock lockdown active."
		extraction_status_changed.emit(false, extraction_block_reason)
	elif eligible != is_extraction_eligible:
		is_extraction_eligible = eligible
		is_extraction_blocked = false
		var reason = "Expedition criteria satisfied. Airlock exit authorized." if eligible else "Extraction requirements unmet."
		extraction_status_changed.emit(eligible, reason)

	# 2. Update Return Terminal & Extraction Objective Status
	var terminal_enabled: bool = bool(current_facts.get("return_terminal_enabled", false))
	if terminal_enabled != is_return_terminal_enabled:
		is_return_terminal_enabled = terminal_enabled
		var term_reason = "Return terminal online: Extraction beacon active." if terminal_enabled else "Return terminal locked."
		return_terminal_status_reason = term_reason
		return_terminal_state_changed.emit(terminal_enabled, term_reason)

	var obj_unlocked: bool = bool(current_facts.get("extraction_objective_unlocked", false))
	if obj_unlocked and not is_extraction_objective_unlocked:
		is_extraction_objective_unlocked = true
		extraction_objective_unlocked.emit()

	# 3. Update Mission Prerequisites
	for fact_key in derived_facts.keys():
		if fact_key.ends_with("_eligible") or fact_key.ends_with("_unlocked") or fact_key.ends_with("_authorized"):
			mission_prerequisite_evaluated.emit(fact_key, bool(derived_facts[fact_key]))

	# 4. Apply Approved Actions
	_apply_approved_actions(applicable_actions, active_explanations)

	# 5. Emit completed signal
	inference_completed.emit(result)


func _apply_approved_actions(actions: Array, explanations: Dictionary) -> void:
	for action in actions:
		var act_str: String = str(action)
		var exp_data = explanations.get("action::" + act_str, {})
		var explanation_text: String = exp_data.get("explanation", "")

		action_approved.emit(act_str, {"explanation": explanation_text})

		match act_str:
			"show_low_oxygen_warning", "flash_oxygen_hud":
				warning_issued.emit("low_oxygen", "Caution: Oxygen reserves low (< 25%).", 100)
			"trigger_critical_audio_alarm":
				warning_issued.emit("critical_hypoxia", "Emergency: Critical hypoxia (< 10%). Return to base immediately!", 120)
			"alarm_critical_breach":
				warning_issued.emit("suffocation_breach", "Fatal Breach: Oxygen depleted! Suffocation damage active!", 150)
			"warn_combat_lockdown":
				warning_issued.emit("combat_lockdown", "Security Lockdown: Cannot extract while hostile threat active!", 160)
				return_terminal_state_changed.emit(false, "Security Lockdown: Cannot extract while hostile threat active!")
			"unlock_extraction_objective", "notify_extraction_unlocked":
				is_extraction_objective_unlocked = true
				extraction_objective_unlocked.emit()
			"enable_return_terminal", "illuminate_return_beacon":
				is_return_terminal_enabled = true
				return_terminal_state_changed.emit(true, "Return terminal online: Extraction authorized.")
			"unlock_airlock_exit":
				# Extraction portal unlocked
				pass
			"notify_hyperspace_vector_unlocked":
				if Engine.has_singleton("PlanetProgressionManager") or has_node("/root/PlanetProgressionManager"):
					var ppm = get_node("/root/PlanetProgressionManager")
					if ppm.has_method("unlock_planet"):
						ppm.unlock_planet("lhs_1140_b")
			"apply_heavy_gravity_hud_badge":
				environmental_modifier_applied.emit("heavy_gravity", 2.2)
			"activate_suit_heating_circuit":
				environmental_modifier_applied.emit("cryo_hazard", 1.3)


# ---------------------------------------------------------------------------
# Local GDScript Forward Chaining Engine (Fallback & Fast Local Testing)
# ---------------------------------------------------------------------------
func evaluate_facts_local(initial_facts: Dictionary, max_iterations: int = 50) -> Dictionary:
	var working_memory: Dictionary = initial_facts.duplicate(true)
	var local_derived: Dictionary = {}
	var local_actions: Array = []
	var fired_rules: Array = []
	var local_explanations: Dictionary = {}
	var contradictions: Array = []
	var fact_priorities: Dictionary = {}
	
	for k in working_memory.keys():
		fact_priorities[k] = 0

	var fired_ids: Dictionary = {}
	var iterations: int = 0

	# Sort rules by priority descending
	var sorted_rules: Array[Dictionary] = _local_rules.duplicate()
	sorted_rules.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("priority", 100)) > int(b.get("priority", 100))
	)

	while iterations < max_iterations:
		iterations += 1
		var rule_fired_this_round := false

		for rule in sorted_rules:
			var rule_id: String = rule.get("id", "")
			if fired_ids.has(rule_id):
				continue

			var conditions: Array = rule.get("conditions", [])
			var satisfied := true
			var diagnostics: Array = []

			for cond in conditions:
				var res := _evaluate_condition(cond, working_memory)
				diagnostics.append(res.diagnostic)
				if not res.satisfied:
					satisfied = false
					break

			if not satisfied:
				continue

			# Rule satisfied: fire!
			fired_ids[rule_id] = true
			fired_rules.append(rule_id)
			rule_fired_this_round = true

			var rule_prio: int = int(rule.get("priority", 100))
			var rule_name: String = str(rule.get("name", rule_id))
			var template: String = str(rule.get("explanation_template", ""))

			# Process overrides (removed facts)
			var overrides: Array = rule.get("overrides", [])
			for ov in overrides:
				var ov_key = str(ov)
				if working_memory.has(ov_key) and not rule.get("conclusions", {}).has(ov_key):
					var old_v = working_memory[ov_key]
					working_memory.erase(ov_key)
					contradictions.append({
						"type": "override",
						"rule_id": rule_id,
						"field": ov_key,
						"removed_value": old_v,
						"reason": "Rule '%s' priority override eliminated fact '%s'." % [rule_name, ov_key]
					})

			# Assert conclusions
			var conclusions: Dictionary = rule.get("conclusions", {})
			for key in conclusions.keys():
				var val = conclusions[key]
				if working_memory.has(key):
					var existing_val = working_memory[key]
					if existing_val != val:
						var existing_prio: int = int(fact_priorities.get(key, 0))
						if rule_prio >= existing_prio:
							contradictions.append({
								"type": "contradiction_resolved",
								"rule_id": rule_id,
								"field": key,
								"prior_value": existing_val,
								"new_value": val,
								"reason": "Contradiction resolved by priority %d >= %d." % [rule_prio, existing_prio]
							})
							working_memory[key] = val
							local_derived[key] = val
							fact_priorities[key] = rule_prio
						else:
							contradictions.append({
								"type": "contradiction_ignored",
								"rule_id": rule_id,
								"field": key,
								"attempted_value": val,
								"retained_value": existing_val,
								"reason": "Attempted update ignored: priority %d < %d." % [rule_prio, existing_prio]
							})
							continue
				else:
					working_memory[key] = val
					local_derived[key] = val
					fact_priorities[key] = rule_prio

				# Store explanation
				local_explanations[key] = {
					"rule_id": rule_id,
					"rule_name": rule_name,
					"explanation": template if not template.is_empty() else ("Rule '%s' fired." % rule_name),
					"priority": rule_prio
				}

			# Assert actions
			var actions: Array = rule.get("actions", [])
			for act in actions:
				if not local_actions.has(act):
					local_actions.append(act)
					local_explanations["action::" + str(act)] = {
						"rule_id": rule_id,
						"rule_name": rule_name,
						"explanation": template if not template.is_empty() else ("Rule '%s' fired." % rule_name)
					}

			# Forward chaining: break to re-evaluate across sorted rules
			break

		if not rule_fired_this_round:
			break

	return {
		"status": "success",
		"initial_facts": initial_facts,
		"derived_facts": local_derived,
		"all_facts": working_memory,
		"applicable_actions": local_actions,
		"fired_rules": fired_rules,
		"explanations": local_explanations,
		"contradictions_detected": contradictions,
		"iterations": iterations
	}


func _evaluate_condition(cond: Dictionary, facts: Dictionary) -> Dictionary:
	var field: String = str(cond.get("field", ""))
	var op: String = str(cond.get("operator", "=="))
	var expected = cond.get("value", null)
	var exists := facts.has(field)

	if op == "exists":
		return {"satisfied": exists, "diagnostic": "Field '%s' exists: %s" % [field, exists]}
	if op == "not_exists":
		return {"satisfied": not exists, "diagnostic": "Field '%s' absent: %s" % [field, not exists]}

	var actual = null
	if not exists:
		if cond.has("default_if_missing"):
			actual = cond["default_if_missing"]
		elif op in ["!=", "neq"]:
			actual = null
		else:
			return {"satisfied": false, "diagnostic": "Missing required fact '%s'" % field}
	else:
		actual = facts[field]

	var sat := false
	match op:
		"==", "eq":
			sat = (actual == expected)
		"!=", "neq":
			sat = (actual != expected)
		"<", "lt":
			sat = (float(actual) < float(expected))
		"<=", "lte":
			sat = (float(actual) <= float(expected))
		">", "gt":
			sat = (float(actual) > float(expected))
		">=", "gte":
			sat = (float(actual) >= float(expected))
		"in":
			if expected is Array or expected is Dictionary or expected is String:
				sat = (actual in expected)
		"not_in":
			if expected is Array or expected is Dictionary or expected is String:
				sat = not (actual in expected)
		_:
			sat = false

	return {
		"satisfied": sat,
		"diagnostic": "%s (%s) %s %s -> %s" % [field, str(actual), op, str(expected), sat]
	}


func get_explanation(target: String) -> Dictionary:
	if active_explanations.has(target):
		return {"target": target, "found": true, "trace": active_explanations[target]}
	var act_key := "action::" + target
	if active_explanations.has(act_key):
		return {"target": target, "found": true, "trace": active_explanations[act_key]}
	return {"target": target, "found": false, "trace": "No explanation trace recorded."}


func register_local_rule(rule_dict: Dictionary) -> void:
	# Replace if exists, else append
	for i in range(_local_rules.size()):
		if _local_rules[i].get("id") == rule_dict.get("id"):
			_local_rules[i] = rule_dict
			return
	_local_rules.append(rule_dict)


# ---------------------------------------------------------------------------
# Default BioSphere-X Rules Registration (Local Mirror)
# ---------------------------------------------------------------------------
func _initialize_default_rules() -> void:
	_local_rules.clear()

	# 1. Safe zone sanctuary (priority 200)
	register_local_rule({
		"id": "rule_safe_zone_sanctuary",
		"name": "Atmospheric Safe Zone Sanctuary",
		"category": "life_support",
		"priority": 200,
		"conditions": [
			{"field": "in_safe_zone", "operator": "==", "value": true}
		],
		"conclusions": {
			"atmospheric_sanctuary": true,
			"low_oxygen_warning": false,
			"critical_hypoxia": false,
			"suffocation_active": false
		},
		"actions": ["refill_life_support"],
		"explanation_template": "Inside atmospheric habitat dome. Hazard warnings suppressed.",
		"overrides": ["low_oxygen_warning", "critical_hypoxia", "suffocation_active"]
	})

	# 2. Complete oxygen depletion (priority 150)
	register_local_rule({
		"id": "rule_oxygen_zero_suffocation",
		"name": "Life Support Complete Depletion",
		"category": "life_support",
		"priority": 150,
		"conditions": [
			{"field": "oxygen_level", "operator": "<=", "value": 0.0},
			{"field": "in_safe_zone", "operator": "!=", "value": true}
		],
		"conclusions": {
			"suffocation_active": true,
			"low_oxygen_warning": true,
			"critical_hypoxia": true
		},
		"actions": ["apply_suffocation_damage", "alarm_critical_breach"],
		"explanation_template": "Oxygen reserves depleted. Immediate suffocation damage active."
	})

	# 3. Critical hypoxia (priority 120)
	register_local_rule({
		"id": "rule_oxygen_critical_hypoxia",
		"name": "Critical Hypoxia Threshold",
		"category": "life_support",
		"priority": 120,
		"conditions": [
			{"field": "oxygen_level", "operator": "<", "value": 10.0},
			{"field": "oxygen_level", "operator": ">", "value": 0.0},
			{"field": "in_safe_zone", "operator": "!=", "value": true}
		],
		"conclusions": {
			"critical_hypoxia": true,
			"low_oxygen_warning": true
		},
		"actions": ["trigger_critical_audio_alarm", "flash_oxygen_hud"],
		"explanation_template": "Suit oxygen reserves critical (< 10%). Audio/visual alarm active."
	})

	# 4. Low oxygen caution (priority 100)
	register_local_rule({
		"id": "rule_oxygen_low_warning",
		"name": "Low Oxygen Caution Warning",
		"category": "life_support",
		"priority": 100,
		"conditions": [
			{"field": "oxygen_level", "operator": "<", "value": 25.0},
			{"field": "oxygen_level", "operator": ">=", "value": 10.0},
			{"field": "in_safe_zone", "operator": "!=", "value": true}
		],
		"conclusions": {
			"low_oxygen_warning": true
		},
		"actions": ["flash_oxygen_hud"],
		"explanation_template": "Suit oxygen level low (< 25%). Caution pulse displayed."
	})

	# 5. Mission 1 completes unlocks LHS 1140 b (priority 110)
	register_local_rule({
		"id": "rule_mission_01_oxygen_unlocks_lhs",
		"name": "Life Support Recovery Authorizes Hyperspace",
		"category": "missions",
		"priority": 110,
		"conditions": [
			{"field": "mission_01_oxygen_completed", "operator": "==", "value": true}
		],
		"conclusions": {
			"lhs_1140_b_unlocked": true,
			"mission_02_eligible": true
		},
		"actions": ["notify_hyperspace_vector_unlocked"],
		"explanation_template": "Mission 1 accomplished. Sector vector to LHS 1140 b authorized."
	})

	# 6. Biomass samples + terminal authorizes boss (priority 105)
	register_local_rule({
		"id": "rule_specimens_and_terminal_boss_ready",
		"name": "Field Intelligence Authorizes Apex Protocol",
		"category": "missions",
		"priority": 105,
		"conditions": [
			{"field": "biomass_samples_collected", "operator": ">=", "value": 3},
			{"field": "terminal_scanned", "operator": "==", "value": true}
		],
		"conclusions": {
			"boss_protocol_authorized": true,
			"mission_05_eligible": true
		},
		"actions": ["enable_boss_crater_waypoint"],
		"explanation_template": "Biomass samples gathered and terminal scanned. Apex boss tracking active."
	})

	# 6b. Required sample count reached unlocks extraction objective (priority 115)
	register_local_rule({
		"id": "rule_sample_count_unlocks_extraction",
		"name": "Sample Count Unlocks Extraction Objective",
		"category": "missions",
		"priority": 115,
		"conditions": [
			{"field": "sample_count", "operator": ">=", "value": 3}
		],
		"conclusions": {
			"extraction_objective_unlocked": true
		},
		"actions": ["unlock_extraction_objective", "notify_extraction_unlocked"],
		"explanation_template": "Required sample quota fulfilled (>= 3). Extraction objective unlocked."
	})

	# 6c. Boss defeated + mission item collected enables return terminal (priority 130)
	register_local_rule({
		"id": "rule_boss_and_item_enables_return_terminal",
		"name": "Apex Neutralization and Mission Artifact Enables Return Terminal",
		"category": "extraction",
		"priority": 130,
		"conditions": [
			{"field": "boss_defeated", "operator": "==", "value": true},
			{"field": "mission_item_collected", "operator": "==", "value": true}
		],
		"conclusions": {
			"return_terminal_enabled": true
		},
		"actions": ["enable_return_terminal", "illuminate_return_beacon"],
		"explanation_template": "Apex boss defeated and mission artifact recovered. Base return terminal enabled."
	})

	# 7. Combat lockdown blocks extraction (priority 160)
	register_local_rule({
		"id": "rule_combat_lockdown_blocks_extraction",
		"name": "Hostile Pursuit Airlock Lockdown",
		"category": "extraction",
		"priority": 160,
		"conditions": [
			{"field": "combat_threat_active", "operator": "==", "value": true},
			{"field": "in_safe_zone", "operator": "!=", "value": true}
		],
		"conclusions": {
			"extraction_blocked": true,
			"extraction_eligible": false,
			"return_terminal_enabled": false
		},
		"actions": ["warn_combat_lockdown"],
		"explanation_template": "Alien hostiles in pursuit. Airlock security lockdown active.",
		"overrides": ["extraction_eligible", "return_terminal_enabled"]
	})

	# 8. Extraction criteria satisfied (priority 120)
	register_local_rule({
		"id": "rule_extraction_criteria_satisfied",
		"name": "Expedition Extraction Authorization",
		"category": "extraction",
		"priority": 120,
		"conditions": [
			{"field": "primary_missions_completed", "operator": "==", "value": true},
			{"field": "samples_carried", "operator": ">=", "value": 1},
			{"field": "near_airlock", "operator": "==", "value": true},
			{"field": "extraction_blocked", "operator": "!=", "value": true}
		],
		"conclusions": {
			"extraction_eligible": true
		},
		"actions": ["unlock_airlock_exit"],
		"explanation_template": "Expedition telemetry verified. Samples carried at habitat airlock portal."
	})

	# 9. Super-Earth heavy gravity (priority 90)
	register_local_rule({
		"id": "rule_lhs_1140_b_super_earth_gravity",
		"name": "Super-Earth Heavy Gravity Atmosphere",
		"category": "environmental",
		"priority": 90,
		"conditions": [
			{"field": "planet_id", "operator": "==", "value": "lhs_1140_b"}
		],
		"conclusions": {
			"heavy_gravity_active": true,
			"oxygen_drain_rate": 2.2,
			"stamina_penalty": 1.4
		},
		"actions": ["apply_heavy_gravity_hud_badge"],
		"explanation_template": "Deployed on LHS 1140 b. Heavy gravity atmosphere active."
	})

	# 10. Sub-zero cryogenic thermal drain (priority 85)
	register_local_rule({
		"id": "rule_cryo_thermal_drain",
		"name": "Sub-Zero Thermal Cryo Drain",
		"category": "environmental",
		"priority": 85,
		"conditions": [
			{"field": "ambient_temperature_k", "operator": "<", "value": 200.0},
			{"field": "in_safe_zone", "operator": "!=", "value": true}
		],
		"conclusions": {
			"cryo_hazard_active": true,
			"suit_thermal_drain": 1.3
		},
		"actions": ["activate_suit_heating_circuit"],
		"explanation_template": "Cryogenic ambient temperature. Suit thermal drain elevated."
	})
