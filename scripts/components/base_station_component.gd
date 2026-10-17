extends Area2D
class_name BaseStationComponent
## Reusable Base Station Component for BioSphere-X.
## Foundation for all interactive facilities (Refill, Storage, Mission Ops, Planet Gate).
## Provides standardized interaction detection, collision, holographic rendering,
## floating sci-fi signage, and procedural audio cues.

signal station_interacted(station: BaseStationComponent, user: Node2D)
signal player_proximity_changed(is_near: bool)

@export var station_name: String = "Base Service Console"
@export var station_tag: String = "TERMINAL"
@export var interaction_prompt: String = "Press E to Access Station"
@export var accent_color: Color = Color(0.2, 0.85, 1.0)
@export var icon_symbol: String = "⚡"
@export var interaction_radius: float = 38.0

# Visual Styling
@export var console_base_color: Color = Color(0.10, 0.14, 0.20)
@export var console_border_color: Color = Color(0.25, 0.35, 0.45)
@export var screen_color: Color = Color(0.04, 0.12, 0.16)

var is_player_nearby: bool = false
var _pulse_timer: float = 0.0
var _interaction_burst: float = 0.0
var _collision_shape: CollisionShape2D
var _audio_player: AudioStreamPlayer
var _feedback_text: String = ""
var _feedback_timer: float = 0.0


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("base_stations")
	collision_layer = 2 # Layer 2 (Interactable)
	collision_mask = 1  # Layer 1 (Player)
	
	_setup_collision()
	_setup_audio()
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _setup_collision() -> void:
	_collision_shape = CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = interaction_radius
	_collision_shape.shape = circle
	add_child(_collision_shape)


func _setup_audio() -> void:
	_audio_player = AudioStreamPlayer.new()
	_audio_player.name = "StationAudio"
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050
	gen.buffer_length = 0.1
	_audio_player.stream = gen
	add_child(_audio_player)


func _process(delta: float) -> void:
	_pulse_timer += delta * 3.0
	if _interaction_burst > 0.0:
		_interaction_burst = maxf(0.0, _interaction_burst - delta * 2.0)
	if _feedback_timer > 0.0:
		_feedback_timer = maxf(0.0, _feedback_timer - delta)
		if _feedback_timer <= 0.0:
			_feedback_text = ""
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body is CharacterBody2D:
		is_player_nearby = true
		player_proximity_changed.emit(true)


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body is CharacterBody2D:
		is_player_nearby = false
		player_proximity_changed.emit(false)


func get_interaction_prompt() -> String:
	return interaction_prompt


func can_interact(_user: Node2D = null) -> bool:
	return true


func interact(user: Node2D = null) -> bool:
	_interaction_burst = 1.0
	_play_access_sound()
	station_interacted.emit(self, user)
	return on_station_interacted(user)


## Overrideable hook for specialized station logic
func on_station_interacted(_user: Node2D) -> bool:
	return true


func set_floating_feedback(text: String, duration: float = 2.5) -> void:
	_feedback_text = text
	_feedback_timer = duration


func _play_access_sound() -> void:
	if not _audio_player or not _audio_player.stream is AudioStreamGenerator:
		return
	if not _audio_player.playing:
		_audio_player.play()
	var pb = _audio_player.get_stream_playback()
	if pb:
		var frames: int = pb.get_frames_available()
		var n := mini(frames, 400)
		for i in n:
			var s := sin(float(i) * 0.4) * 0.25 * (1.0 - float(i) / float(n))
			pb.push_frame(Vector2(s, s))


# ---------------------------------------------------------------------------
# Procedural Station Visuals & Holographic Signage
# ---------------------------------------------------------------------------
func _draw() -> void:
	var pulse := (sin(_pulse_timer) + 1.0) * 0.5
	
	# 1. Base Pedestal Drop Shadow
	draw_set_transform(Vector2(2, 5), 0.0, Vector2(1.15, 0.6))
	draw_circle(Vector2.ZERO, 15.0, Color(0.02, 0.03, 0.05, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	
	# 2. Interactive Proximity Aura
	if is_player_nearby:
		var aura_col := Color(accent_color, 0.12 + pulse * 0.1)
		draw_circle(Vector2.ZERO, interaction_radius * 0.85, aura_col)
		draw_arc(Vector2.ZERO, interaction_radius * 0.85, 0.0, TAU, 28, Color(accent_color, 0.4 + pulse * 0.3), 1.2)
	
	# 3. Metallic Pedestal Body
	var body_rect := Rect2(-16, -12, 32, 24)
	draw_rect(body_rect, console_base_color)
	draw_rect(body_rect, accent_color if is_player_nearby else console_border_color, false, 1.4)
	
	# 4. Angled Holographic Monitor Screen
	var scr_rect := Rect2(-12, -9, 24, 18)
	draw_rect(scr_rect, screen_color)
	
	# Scanlines on screen
	var scan_col := Color(accent_color, 0.5 + pulse * 0.35)
	draw_line(Vector2(-10, -5), Vector2(10, -5), scan_col, 1.0)
	draw_line(Vector2(-10, 0), Vector2(6, 0), scan_col, 1.0)
	draw_line(Vector2(-10, 5), Vector2(8, 5), scan_col, 1.0)
	
	# 5. Status Indicator Light
	var led_color := Color(0.2, 1.0, 0.5) if is_player_nearby else accent_color
	draw_circle(Vector2(10, 5), 2.2, led_color)
	
	# 6. Interaction Burst Ripple
	if _interaction_burst > 0.0:
		var r := 40.0 * (1.0 - _interaction_burst)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, Color(accent_color, _interaction_burst * 0.6), 2.0)
	
	# 7. Holographic Floating Label & Signage (Clean & Contextual)
	if is_player_nearby:
		var label_str := "[%s] %s" % [station_tag, station_name.to_upper()]
		var pill_w := 140.0
		var pill_h := 16.0
		draw_rect(Rect2(-pill_w * 0.5, -28, pill_w, pill_h), Color(0.02, 0.05, 0.10, 0.88))
		draw_rect(Rect2(-pill_w * 0.5, -28, pill_w, pill_h), Color(accent_color, 0.65 + pulse * 0.25), false, 1.0)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(-pill_w * 0.5, -16),
			label_str,
			HORIZONTAL_ALIGNMENT_CENTER,
			pill_w,
			9,
			accent_color
		)
	else:
		# Subtle, sleek holographic tag badge when idle (prevents screen clutter)
		var badge_str := "[%s]" % station_tag
		var badge_w := 46.0
		draw_rect(Rect2(-badge_w * 0.5, -22, badge_w, 12), Color(0.02, 0.05, 0.10, 0.55))
		draw_rect(Rect2(-badge_w * 0.5, -22, badge_w, 12), Color(accent_color, 0.35), false, 0.8)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(-badge_w * 0.5, -13),
			badge_str,
			HORIZONTAL_ALIGNMENT_CENTER,
			badge_w,
			8,
			Color(accent_color, 0.70)
		)
	
	# Floating Feedback Notification
	if not _feedback_text.is_empty():
		draw_string(
			ThemeDB.fallback_font,
			Vector2(-90, -32),
			_feedback_text,
			HORIZONTAL_ALIGNMENT_CENTER,
			180.0,
			10,
			Color(0.25, 1.0, 0.6)
		)
