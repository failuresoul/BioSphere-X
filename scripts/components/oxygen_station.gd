extends Area2D
class_name OxygenStation
## Exoplanet Life-Support Oxygen Station & Atmospheric Safe Zone for BioSphere-X.
## Provides continuous oxygen replenishment while inside the perimeter,
## instant supercharge upon interaction, and distinct sci-fi atmospheric visual effects.

signal player_entered_station(station: OxygenStation)
signal player_exited_station(station: OxygenStation)
signal station_refilled_instant()

@export var station_name: String = "O2 Life Support Station"
@export_enum("station", "safe_zone_dome") var station_type: String = "station"
@export var radius: float = 90.0:
	set(value):
		radius = maxf(24.0, value)
		_update_collision_shape()
		queue_redraw()

@export var refill_rate: float = 30.0
@export var instant_interact_refill: bool = true

# Visual Palette
@export var shield_color: Color = Color(0.12, 0.80, 1.00, 0.14)
@export var border_color: Color = Color(0.20, 0.88, 1.00, 0.70)
@export var pod_base_color: Color = Color(0.12, 0.15, 0.22, 1.0)
@export var pod_trim_color: Color = Color(0.35, 0.75, 0.95, 0.9)
@export var gas_glow_color: Color = Color(0.25, 0.95, 0.90, 0.85)

var _player_inside: bool = false
var _pulse_time: float = 0.0
var _collision_shape: CollisionShape2D = null
var _bubbles: Array[Dictionary] = []


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("oxygen_stations")
	collision_layer = 6 # Layer 2 (Interactable) and Layer 3/4 (Zone detection)
	collision_mask = 1  # Detect Player on Layer 1
	
	_setup_collision()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _setup_collision() -> void:
	if not _collision_shape:
		_collision_shape = CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = radius
		_collision_shape.shape = circle
		add_child(_collision_shape)


func _update_collision_shape() -> void:
	if _collision_shape and _collision_shape.shape is CircleShape2D:
		(_collision_shape.shape as CircleShape2D).radius = radius


func _process(delta: float) -> void:
	_pulse_time += delta * 2.5
	_update_ambient_bubbles(delta)
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body is CharacterBody2D:
		_player_inside = true
		player_entered_station.emit(self)
		var gs := get_node_or_null("/root/GameState")
		if gs and gs.has_method("set_oxygen_refilling"):
			gs.call("set_oxygen_refilling", true, refill_rate)


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body is CharacterBody2D:
		_player_inside = false
		player_exited_station.emit(self)
		var gs := get_node_or_null("/root/GameState")
		if gs and gs.has_method("set_oxygen_refilling"):
			gs.call("set_oxygen_refilling", false)


## Interactive component interface (E / Spacebar)
func interact(_player: Node2D = null) -> bool:
	if not instant_interact_refill:
		return false
	
	var gs := get_node_or_null("/root/GameState")
	if gs and gs.has_method("refill_oxygen"):
		gs.call("refill_oxygen", -1.0) # -1.0 = full instant replenishment
		_spawn_burst_effect()
		station_refilled_instant.emit()
		return true
	return false


# ---------------------------------------------------------------------------
# Ambient Oxygen Bubble Particles
# ---------------------------------------------------------------------------
func _update_ambient_bubbles(delta: float) -> void:
	if _bubbles.size() < 12 and randf() < 0.25:
		var angle: float = randf_range(0, TAU)
		var dist: float = randf_range(4.0, radius * 0.85)
		_bubbles.append({
			"pos": Vector2.from_angle(angle) * dist,
			"vel": Vector2(randf_range(-4, 4), randf_range(-18, -32)),
			"alpha": randf_range(0.3, 0.8),
			"radius": randf_range(1.5, 3.5),
			"life": 0.0,
			"max_life": randf_range(1.2, 2.2)
		})
	
	for i in range(_bubbles.size() - 1, -1, -1):
		var b: Dictionary = _bubbles[i]
		b["life"] += delta
		if b["life"] >= b["max_life"]:
			_bubbles.remove_at(i)
		else:
			b["pos"] += b["vel"] * delta


func _spawn_burst_effect() -> void:
	for i in 20:
		var angle: float = (float(i) / 20.0) * TAU
		_bubbles.append({
			"pos": Vector2.ZERO,
			"vel": Vector2.from_angle(angle) * randf_range(40, 90),
			"alpha": 1.0,
			"radius": randf_range(3.0, 5.0),
			"life": 0.0,
			"max_life": 0.8
		})


# ---------------------------------------------------------------------------
# Procedural Rendering
# ---------------------------------------------------------------------------
func _draw() -> void:
	var pulse: float = sin(_pulse_time) * 0.5 + 0.5
	var current_radius: float = radius + (pulse * 2.0 if _player_inside else 0.0)
	
	# 1. Atmospheric Protective Field / Dome Fill
	var fill_color := shield_color
	if _player_inside:
		fill_color.a = minf(0.35, shield_color.a + 0.08 + pulse * 0.05)
	draw_circle(Vector2.ZERO, current_radius, fill_color)
	
	# 2. Glowing Hexagonal / Perimeter Ring
	var perimeter_color := border_color
	perimeter_color.a = 0.5 + pulse * 0.35
	draw_arc(Vector2.ZERO, current_radius, 0.0, TAU, 36, perimeter_color, 2.0)
	
	# Dashed inner resonance boundary
	var step_count := 16
	for i in step_count:
		var start_a: float = (float(i) / float(step_count)) * TAU
		var end_a: float = start_a + (TAU / float(step_count)) * 0.55
		draw_arc(Vector2.ZERO, current_radius - 8.0, start_a, end_a, 4, Color(border_color, 0.3), 1.0)
	
	# 3. Ambient Floating Oxygen Nano-Bubbles
	for b in _bubbles:
		var t: float = b["life"] / b["max_life"]
		var c := gas_glow_color
		c.a = b["alpha"] * (1.0 - t)
		draw_circle(b["pos"], b["radius"] * (1.0 - t * 0.3), c)
	
	# 4. Central Life-Support Pod Structure
	if station_type == "station":
		_draw_station_pylon(pulse)
	else:
		_draw_safe_zone_hub(pulse)


func _draw_station_pylon(pulse: float) -> void:
	# Pod Ground Shadow
	draw_set_transform(Vector2(2, 4), 0.0, Vector2(1.2, 0.7))
	draw_circle(Vector2.ZERO, 16.0, Color(0.02, 0.04, 0.06, 0.5))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	
	# Octagonal Metallic Platform Base
	var base_pts: PackedVector2Array = [
		Vector2(-14, -6), Vector2(-6, -14), Vector2(6, -14), Vector2(14, -6),
		Vector2(14, 6), Vector2(6, 14), Vector2(-6, 14), Vector2(-14, 6)
	]
	draw_colored_polygon(base_pts, pod_base_color)
	draw_polyline(base_pts, pod_trim_color, 1.5)
	
	# Cryogenic Oxygen Tanks (Twin pressurized glass columns)
	draw_rect(Rect2(-8, -10, 6, 16), Color(0.08, 0.12, 0.18))
	draw_rect(Rect2(2, -10, 6, 16), Color(0.08, 0.12, 0.18))
	
	# Liquid O2 glow inside tanks
	var liquid_glow := Color(gas_glow_color, 0.7 + pulse * 0.25)
	draw_rect(Rect2(-7, -8 + pulse * 1.5, 4, 12), liquid_glow)
	draw_rect(Rect2(3, -8 + pulse * 1.5, 4, 12), liquid_glow)
	
	# Status Emitter Beacon / Top Dome
	var beacon_color := Color(0.1, 1.0, 0.75) if _player_inside else Color(0.2, 0.85, 1.0)
	draw_circle(Vector2(0, -1), 4.5, beacon_color)
	draw_circle(Vector2(0, -1), 2.0, Color.WHITE)


func _draw_safe_zone_hub(pulse: float) -> void:
	# Habitat Landing Module Hub
	draw_circle(Vector2(2, 6), 26.0, Color(0.02, 0.03, 0.05, 0.45))
	draw_circle(Vector2.ZERO, 22.0, pod_base_color)
	draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 32, pod_trim_color, 2.0)
	
	# Pressure Air-Lock Ports
	draw_rect(Rect2(-4, 18, 8, 6), pod_trim_color)
	draw_rect(Rect2(-4, -24, 8, 6), pod_trim_color)
	
	# Central Life-Support Core
	var core_color := Color(gas_glow_color, 0.8 + pulse * 0.2)
	draw_circle(Vector2.ZERO, 10.0, core_color)
	draw_circle(Vector2.ZERO, 5.0, Color.WHITE)
