extends "res://scripts/components/base_station_component.gd"
class_name MissionTerminal
## Reusable Mission Operations Terminal for BioSphere-X.
## Links the research base directly to the MissionManager, allowing the astronaut
## to review objectives, track expedition directives, and restart failed missions.

signal mission_terminal_accessed(active_mission_data: Dictionary)


func _init() -> void:
	station_name = "Mission Operations"
	station_tag = "OPS"
	interaction_prompt = "Press E to Review Expedition Objectives"
	accent_color = Color(0.2, 0.92, 0.65) # Operations Emerald Glow
	icon_symbol = "📋"
	interaction_radius = 42.0


func on_station_interacted(_user: Node2D) -> bool:
	var mm := get_node_or_null("/root/MissionManager")
	if not mm:
		set_floating_feedback("MISSION SUBSYSTEM OFFLINE", 2.0)
		return false
	
	var active = mm.call("get_active_mission")
	if not active:
		set_floating_feedback("ALL EXPEDITION DIRECTIVES ACCOMPLISHED", 3.0)
		mission_terminal_accessed.emit({})
		return true
	
	var title: String = str(active.get("title"))
	var is_failed: bool = bool(active.call("is_failed")) if active.has_method("is_failed") else false
	var prog_text: String = str(active.call("get_progress_text")) if active.has_method("get_progress_text") else ""
	
	if is_failed:
		# Automatically reboot failed directive on console access
		var mid: String = str(active.get("id"))
		mm.call("restart_mission", mid)
		set_floating_feedback("⚠ DIRECTIVE REBOOTED: %s" % title, 3.2)
		print("[MissionTerminal] Rebooted failed directive: ", title)
	else:
		set_floating_feedback("► DIRECTIVE: %s (%s)" % [title, prog_text], 3.5)
		print("[MissionTerminal] Active mission reviewed: ", title, " -> ", prog_text)
	
	mission_terminal_accessed.emit(active.call("to_dict") if active.has_method("to_dict") else {})
	
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("open_mission_modal"):
		hud.call("open_mission_modal")
		
	return true


func get_active_mission_info() -> Dictionary:
	var mm := get_node_or_null("/root/MissionManager")
	if mm:
		return mm.call("get_active_mission_dict")
	return {}
