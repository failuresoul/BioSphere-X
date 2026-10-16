class_name MissionData
extends RefCounted
## Standardized mission objective data model for BioSphere-X.
## Encapsulates mission identity, objective criteria, progress, state machine, and completion rewards.

enum ObjectiveType {
	COLLECT_OXYGEN,
	RETRIEVE_SAMPLES,
	ACTIVATE_TERMINAL,
	SURVIVE_ENCOUNTER,
	DEFEAT_BOSS,
	RETURN_TO_BASE
}

enum MissionState {
	LOCKED,
	ACTIVE,
	COMPLETED,
	FAILED
}

var id: String = ""
var title: String = ""
var description: String = ""
var objective_type: ObjectiveType = ObjectiveType.COLLECT_OXYGEN
var state: MissionState = MissionState.LOCKED
var target_amount: float = 1.0
var current_progress: float = 0.0
var rewards: Dictionary = {}
var completion_conditions: Dictionary = {}
var failure_conditions: Dictionary = {}
var progress_unit_label: String = "Units"
var fail_reason: String = ""


func _init(
	p_id: String = "",
	p_title: String = "",
	p_desc: String = "",
	p_type: ObjectiveType = ObjectiveType.COLLECT_OXYGEN,
	p_target: float = 1.0,
	p_rewards: Dictionary = {},
	p_conditions: Dictionary = {},
	p_unit_label: String = "Units"
) -> void:
	id = p_id
	title = p_title
	description = p_desc
	objective_type = p_type
	target_amount = maxf(1.0, p_target)
	current_progress = 0.0
	state = MissionState.LOCKED
	rewards = p_rewards.duplicate(true)
	completion_conditions = p_conditions.duplicate(true)
	progress_unit_label = p_unit_label
	fail_reason = ""


static func create(
	p_id: String,
	p_title: String,
	p_desc: String,
	p_type: ObjectiveType,
	p_target: float,
	p_rewards: Dictionary = {},
	p_conditions: Dictionary = {},
	p_unit_label: String = "Units"
) -> RefCounted:
	var script: GDScript = load("res://scripts/components/mission_data.gd")
	return script.new(p_id, p_title, p_desc, p_type, p_target, p_rewards, p_conditions, p_unit_label)


func is_locked() -> bool:
	return state == MissionState.LOCKED


func is_active() -> bool:
	return state == MissionState.ACTIVE


func is_completed() -> bool:
	return state == MissionState.COMPLETED


func is_failed() -> bool:
	return state == MissionState.FAILED


func start() -> void:
	if state == MissionState.LOCKED:
		state = MissionState.ACTIVE


func add_progress(amount: float) -> bool:
	if state != MissionState.ACTIVE:
		return false
	current_progress = clampf(current_progress + amount, 0.0, target_amount)
	if current_progress >= target_amount:
		complete()
		return true
	return false


func set_progress(value: float) -> bool:
	if state != MissionState.ACTIVE:
		return false
	current_progress = clampf(value, 0.0, target_amount)
	if current_progress >= target_amount:
		complete()
		return true
	return false


func complete() -> void:
	state = MissionState.COMPLETED
	current_progress = target_amount


func fail(reason: String = "Objective condition violated.") -> void:
	state = MissionState.FAILED
	fail_reason = reason


func get_progress_ratio() -> float:
	if target_amount <= 0.0:
		return 1.0 if state == MissionState.COMPLETED else 0.0
	return clampf(current_progress / target_amount, 0.0, 1.0)


func get_progress_text() -> String:
	match objective_type:
		ObjectiveType.ACTIVATE_TERMINAL, ObjectiveType.DEFEAT_BOSS, ObjectiveType.RETURN_TO_BASE:
			if state == MissionState.COMPLETED:
				return "STATUS: COMPLETED"
			elif state == MissionState.FAILED:
				return "STATUS: FAILED"
			return "STATUS: IN PROGRESS"
		_:
			return "%d / %d %s (%.0f%%)" % [
				int(current_progress),
				int(target_amount),
				progress_unit_label,
				get_progress_ratio() * 100.0
			]


func get_objective_type_name() -> String:
	match objective_type:
		ObjectiveType.COLLECT_OXYGEN: return "COLLECT OXYGEN"
		ObjectiveType.RETRIEVE_SAMPLES: return "RETRIEVE RESEARCH SAMPLES"
		ObjectiveType.ACTIVATE_TERMINAL: return "ACTIVATE TERMINAL"
		ObjectiveType.SURVIVE_ENCOUNTER: return "SURVIVE ENCOUNTER"
		ObjectiveType.DEFEAT_BOSS: return "DEFEAT BOSS"
		ObjectiveType.RETURN_TO_BASE: return "RETURN TO BASE"
	return "OBJECTIVE"


func to_dict() -> Dictionary:
	return {
		"id": id,
		"title": title,
		"description": description,
		"objective_type": get_objective_type_name(),
		"state": state,
		"target_amount": target_amount,
		"current_progress": current_progress,
		"progress_ratio": get_progress_ratio(),
		"progress_text": get_progress_text(),
		"rewards": rewards,
		"fail_reason": fail_reason
	}
