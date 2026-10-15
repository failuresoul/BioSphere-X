extends Area2D
class_name ResearchTerminal
## Interactive Research Outpost Terminal for BioSphere-X.
## Allows the astronaut to scan expedition telemetry, unlock scientific data,
## advance the introductory tutorial, and retrieve mission logs.

signal terminal_scanned(player: Node2D)

@export var terminal_name: String = "Alpha-7 Research Terminal"
@export var interaction_prompt: String = "Press E to Access Terminal"
@export var is_scanned: bool = false
@export var data_reward_biomass: int = 5
@export var data_reward_crystals: int = 2

# Visual Palette
@export var console_color: Color = Color(0.12, 0.16, 0.22)
@export var trim_color: Color = Color(0.25, 0.85, 1.0)
@export var screen_color: Color = Color(0.05, 0.20, 0.25)
@export var text_glow: Color = Color(0.20, 0.95, 0.85)

var _pulse_timer: float = 0.0
var _scan_burst_timer: float = 0.0


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("terminals")
	collision_layer = 2 # Layer 2 (Interactable)
	collision_mask = 1  # Layer 1 (Player)
	
	_setup_collision()


func _setup_collision() -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 48.0
	shape.shape = circle
	add_child(shape)


func _process(delta: float) -> void:
	_pulse_timer += delta * 3.0
	if _scan_burst_timer > 0.0:
		_scan_burst_timer = maxf(0.0, _scan_burst_timer - delta)
	queue_redraw()


func get_interaction_prompt() -> String:
	if is_scanned:
		return "Press E to Review Station Telemetry"
	return interaction_prompt


func can_interact(_user: Node2D = null) -> bool:
	return true


func interact(user: Node2D = null) -> bool:
	_scan_burst_timer = 0.5
	var first_scan := not is_scanned
	is_scanned = true
	
	var gs := get_node_or_null("/root/GameState")
	if gs:
		if first_scan:
			gs.call("add_resource", "biomass", data_reward_biomass)
			gs.call("add_resource", "crystals", data_reward_crystals)
			gs.call("set_objective", "RESEARCH OUTPOST ACCESSED // Telemetry decoded. Planet BioSphere-X surveyed.")
	
	terminal_scanned.emit(user)
	return true


func _draw() -> void:
	# 1. Base Console Pedestal Drop Shadow
	draw_set_transform(Vector2(2, 6), 0.0, Vector2(1.2, 0.6))
	draw_circle(Vector2.ZERO, 16.0, Color(0.02, 0.04, 0.06, 0.5))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	
	# 2. Metallic Terminal Pedestal Body
	var body_rect := Rect2(-14, -10, 28, 20)
	draw_rect(body_rect, console_color)
	draw_rect(body_rect, trim_color, false, 1.2)
	
	# 3. Holographic Monitor Screen
	var screen_rect := Rect2(-12, -8, 24, 16)
	draw_rect(screen_rect, screen_color)
	
	# Animated scanlines
	var pulse := (sin(_pulse_timer) + 1.0) * 0.5
	var line_alpha := 0.6 + pulse * 0.35
	var cur_text_color := text_glow if not is_scanned else Color(0.3, 1.0, 0.5)
	cur_text_color.a = line_alpha
	
	draw_line(Vector2(-10, -4), Vector2(10, -4), cur_text_color, 1.2)
	draw_line(Vector2(-10, 0), Vector2(4, 0), cur_text_color, 1.0)
	draw_line(Vector2(-10, 4), Vector2(8, 4), cur_text_color, 1.0)
	
	# Status Indicator Light
	var led_color := Color(0.2, 1.0, 0.5) if is_scanned else Color(1.0, 0.75, 0.2)
	draw_circle(Vector2(9, 4), 2.0, led_color)
	
	# Scan Burst Aura when accessed
	if _scan_burst_timer > 0.0:
		var burst_t := _scan_burst_timer / 0.5
		var burst_radius := 48.0 * (1.0 - burst_t)
		draw_circle(Vector2.ZERO, burst_radius, Color(0.2, 0.9, 1.0, burst_t * 0.4))
