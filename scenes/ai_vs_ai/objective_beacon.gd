class_name ObjectiveBeacon
extends Area2D
## Reusable Objective Beacon / Crystal for "Race to Objective" AI vs AI Scenario.
## Detects when an autonomous agent reaches the goal cell and triggers match victory.

signal objective_reached(agent: Node2D)

@export var beacon_radius: float = 24.0
@export var glow_color: Color = Color(0.2, 1.0, 0.6, 0.85)

var is_active: bool = true
var winner_agent: Node2D = null
var _pulse_timer: float = 0.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	z_index = 2
	collision_layer = 1
	collision_mask = 1
	body_entered.connect(_on_body_entered)


func reset_beacon() -> void:
	is_active = true
	winner_agent = null
	_pulse_timer = 0.0
	queue_redraw()


func _physics_process(delta: float) -> void:
	_pulse_timer += delta * 3.0
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if not is_active:
		return
	
	if body and (body.is_in_group("autonomous_agents") or body.has_method("setup_agent")):
		is_active = false
		winner_agent = body
		objective_reached.emit(body)
		var audio = get_node_or_null("/root/AudioManager")
		if audio and audio.has_method("play_sfx"):
			audio.call("play_sfx", "mission_complete")
		queue_redraw()


func _draw() -> void:
	var pulse := (sin(_pulse_timer) + 1.0) * 0.5
	var cur_color := glow_color
	if winner_agent:
		cur_color = winner_agent.accent_color

	# Base landing pad ring
	draw_arc(Vector2.ZERO, beacon_radius + 6.0, 0, TAU, 32, cur_color.darkened(0.5), 2.0)
	
	# Pulsing inner ring
	var pulse_radius := beacon_radius + pulse * 4.0
	draw_arc(Vector2.ZERO, pulse_radius, 0, TAU, 32, cur_color, 2.0)

	# Central beacon crystal (diamond polygon)
	var pts := PackedVector2Array([
		Vector2(0, -16),
		Vector2(12, 0),
		Vector2(0, 16),
		Vector2(-12, 0)
	])
	draw_colored_polygon(pts, cur_color)
	draw_polyline(pts, Color.WHITE, 1.5)

	# Center glowing dot
	draw_circle(Vector2.ZERO, 3.5, Color.WHITE)

	# Label
	var font := ThemeDB.fallback_font
	var a_name: String = str(winner_agent.get("agent_name")) if winner_agent and winner_agent.get("agent_name") != null else "AGENT"
	var text := "OBJECTIVE TARGET" if is_active else ("CLAIMED BY " + a_name.to_upper())
	draw_string(font, Vector2(-50, -24), text, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, cur_color.lightened(0.3))
