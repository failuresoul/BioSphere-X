extends Node
class_name TutorialManager
## Introductory Tutorial System for BioSphere-X.
## Teaches movement, monitoring oxygen/life-support, harvesting resources with [E],
## and navigating North-East to the Research Outpost terminal.
## Guides the player through a complete beginning-to-end introductory mission.

signal step_advanced(step_index: int, title: String, description: String)
signal tutorial_completed()

enum TutorialStep {
	MOVEMENT = 0,
	OXYGEN = 1,
	COLLECT = 2,
	REACH_STATION = 3,
	COMPLETE = 4
}

var current_step: TutorialStep = TutorialStep.MOVEMENT
var is_tutorial_complete: bool = false

var _move_timer: float = 0.0
var _oxygen_timer: float = 0.0
var _player_ref: Node2D = null

const STEP_DATA: Dictionary = {
	TutorialStep.MOVEMENT: {
		"title": "STEP 1/4: LOCOMOTION",
		"desc": "Calibrate EVA suit thrusters: Use [W, A, S, D] or Arrow Keys to move."
	},
	TutorialStep.OXYGEN: {
		"title": "STEP 2/4: LIFE SUPPORT",
		"desc": "Atmosphere hostile! Check O2 gauge (top-left). Safe zone domes recharge O2."
	},
	TutorialStep.COLLECT: {
		"title": "STEP 3/4: RESOURCE RECOVERY",
		"desc": "Approach a glowing collectable item nearby and Press [E] to collect."
	},
	TutorialStep.REACH_STATION: {
		"title": "STEP 4/4: PLANETARY EXPEDITION",
		"desc": "Travel North-East across the canyon to the Research Outpost and access the Terminal."
	},
	TutorialStep.COMPLETE: {
		"title": "PROTOCOL ACCOMPLISHED // ALL SYSTEMS OPERATIONAL",
		"desc": "Research Outpost accessed! Exoplanet BioSphere-X surveyed. Free exploration unlocked."
	}
}


func _ready() -> void:
	_connect_signals()
	# Delay 0.1s to allow scene hierarchy to settle before publishing
	get_tree().create_timer(0.1).timeout.connect(_publish_current_step)


func _connect_signals() -> void:
	var gs := get_node_or_null("/root/GameState")
	if gs:
		if gs.has_signal("resource_changed") and not gs.is_connected("resource_changed", _on_resource_changed):
			gs.connect("resource_changed", _on_resource_changed)


func set_player(player: Node2D) -> void:
	_player_ref = player


func _process(delta: float) -> void:
	if is_tutorial_complete:
		return
	
	match current_step:
		TutorialStep.MOVEMENT:
			if _player_ref and _player_ref.get("velocity"):
				var vel: Vector2 = _player_ref.get("velocity")
				if vel.length() > 20.0:
					_move_timer += delta
					if _move_timer >= 1.2:
						advance_step()
			else:
				# Fallback timer if player reference not set
				_move_timer += delta
				if _move_timer >= 2.0:
					advance_step()
					
		TutorialStep.OXYGEN:
			_oxygen_timer += delta
			if _oxygen_timer >= 4.0:
				advance_step()


func _on_resource_changed(_resource_id: String, count: int) -> void:
	if current_step == TutorialStep.COLLECT and count > 0:
		advance_step()


func notify_terminal_scanned() -> void:
	if current_step == TutorialStep.REACH_STATION or current_step < TutorialStep.COMPLETE:
		current_step = TutorialStep.REACH_STATION
		advance_step()


func advance_step() -> void:
	if is_tutorial_complete:
		return
	
	if current_step < TutorialStep.COMPLETE:
		current_step = (current_step + 1) as TutorialStep
	
	if current_step == TutorialStep.COMPLETE:
		is_tutorial_complete = true
		tutorial_completed.emit()
	
	_publish_current_step()


func _publish_current_step() -> void:
	var data: Dictionary = STEP_DATA.get(current_step, {})
	var title: String = data.get("title", "")
	var desc: String = data.get("desc", "")
	
	step_advanced.emit(current_step, title, desc)
	
	var gs := get_node_or_null("/root/GameState")
	if gs:
		if gs.has_method("set_objective"):
			gs.call("set_objective", "%s // %s" % [title, desc])
		if gs.has_signal("tutorial_step_changed"):
			gs.emit_signal("tutorial_step_changed", current_step, title, desc, is_tutorial_complete)
