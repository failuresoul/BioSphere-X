extends "res://scripts/components/base_station_component.gd"
class_name ReturnTerminal
## Interactive Return & Extraction Terminal for BioSphere-X.
## Logic-gated by the rule-based inference engine:
##   - Disabled/locked by default.
##   - Enabled when world logic conditions are satisfied:
##     (e.g., boss Goliath Prime defeated AND mission item collected).
##   - Blocked during hostile pursuit or airlock lockdown.
## Complements MissionManager by providing physical interaction validation.

signal return_sequence_initiated()
signal interaction_rejected(reason: String)
signal terminal_state_updated(is_enabled: bool)

@export var is_terminal_enabled: bool = false
@export var lock_reason: String = "Return Terminal Locked: Defeat apex boss and collect mission artifact first."
@export var success_message: String = "Expedition extraction confirmed! Telemetry secured."

var _glow_pulse: float = 0.0


func _init() -> void:
	station_name = "Base Extraction Terminal"
	station_tag = "RETURN"
	interaction_prompt = "Return Terminal [LOCKED]"
	accent_color = Color(0.9, 0.3, 0.2) # Locked Red-Amber
	icon_symbol = "🔒"
	interaction_radius = 42.0


func _ready() -> void:
	super._ready()
	add_to_group("return_terminals")
	_connect_to_rule_engine()
	_update_visual_state()


func _process(delta: float) -> void:
	super._process(delta)
	_glow_pulse += delta * (4.0 if is_terminal_enabled else 1.5)
	queue_redraw()


func _connect_to_rule_engine() -> void:
	if Engine.has_singleton("GameRuleEngine") or has_node("/root/GameRuleEngine"):
		var gre = get_node("/root/GameRuleEngine")
		if gre.has_signal("return_terminal_state_changed"):
			gre.return_terminal_state_changed.connect(_on_rule_engine_terminal_state_changed)
		if "is_return_terminal_enabled" in gre:
			set_terminal_enabled(gre.is_return_terminal_enabled)


func _on_rule_engine_terminal_state_changed(p_enabled: bool, p_reason: String) -> void:
	if not p_reason.is_empty() and not p_enabled:
		lock_reason = p_reason
	set_terminal_enabled(p_enabled)


func set_terminal_enabled(p_enabled: bool) -> void:
	if is_terminal_enabled == p_enabled:
		return
	is_terminal_enabled = p_enabled
	_update_visual_state()
	terminal_state_updated.emit(is_terminal_enabled)


func _update_visual_state() -> void:
	if is_terminal_enabled:
		interaction_prompt = "Press E to Return to Base / Extract"
		accent_color = Color(0.2, 0.95, 0.45) # Radiant Emerald
		icon_symbol = "🚀"
	else:
		interaction_prompt = "Return Terminal [LOCKED]"
		accent_color = Color(0.9, 0.25, 0.2) # Security Red
		icon_symbol = "🔒"


func on_station_interacted(user: Node2D) -> bool:
	if not is_terminal_enabled:
		set_floating_feedback("► ACCESS DENIED: %s" % lock_reason, 3.5)
		interaction_rejected.emit(lock_reason)
		_play_buzz_sound()
		return false

	# Terminal is authorized! Trigger extraction telemetry
	set_floating_feedback("► %s" % success_message, 4.0)
	return_sequence_initiated.emit()
	_play_chime_sound()

	# Notify MissionManager of safe return without conflicting with mission rules
	var mm = get_node_or_null("/root/MissionManager")
	if mm and mm.has_method("notify_event"):
		mm.call("notify_event", "base_reached", {
			"target_zone": "habitat_airlock",
			"terminal_id": station_name
		})

	print("[ReturnTerminal] Authorized return sequence initiated by: ", user.name if user else "Astronaut")
	return true


func _play_buzz_sound() -> void:
	if not _audio_player or not _audio_player.stream is AudioStreamGenerator:
		return
	if not _audio_player.playing:
		_audio_player.play()
	var playback = _audio_player.get_stream_playback()
	if playback:
		var frames: int = playback.get_frames_available()
		var n := mini(frames, 300)
		for i in range(n):
			var sample: float = 0.2 if sin(float(i) * 0.1) > 0.0 else -0.2
			playback.push_frame(Vector2(sample, sample))


func _play_chime_sound() -> void:
	if not _audio_player or not _audio_player.stream is AudioStreamGenerator:
		return
	if not _audio_player.playing:
		_audio_player.play()
	var playback = _audio_player.get_stream_playback()
	if playback:
		var frames: int = playback.get_frames_available()
		var n := mini(frames, 500)
		for i in range(n):
			var sample: float = sin(float(i) * 0.45) * 0.3 * (1.0 - float(i) / float(n))
			playback.push_frame(Vector2(sample, sample))


func _draw() -> void:
	super._draw()

	# Holographic extraction beacon rings
	var pulse := sin(_glow_pulse) * 0.5 + 0.5
	var ring_color := accent_color
	ring_color.a = 0.25 + pulse * 0.35

	draw_arc(Vector2.ZERO, interaction_radius * 0.65, 0.0, TAU, 32, ring_color, 2.0)
	draw_arc(Vector2.ZERO, interaction_radius * (0.85 + pulse * 0.15), 0.0, TAU, 32, Color(ring_color.r, ring_color.g, ring_color.b, 0.15), 1.5)

	# Status indicator dot
	var status_color := Color(0.2, 0.9, 0.4) if is_terminal_enabled else Color(0.9, 0.2, 0.2)
	draw_circle(Vector2(0.0, -22.0), 4.0, status_color)
