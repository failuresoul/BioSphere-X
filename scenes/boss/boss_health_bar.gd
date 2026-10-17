extends CanvasLayer
class_name BossHealthBar
## Cinematic Top-Center Boss Health Display for BioSphere-X.
## Features health bar with lag/decay meter, phase and enrage indicators,
## state banner updates, smooth damage transitions, and victory notification.

@export var boss_name: String = "GOLIATH PRIME — EXOPLANET MATRIARCH"
@export var max_health: float = 500.0
@export var current_health: float = 500.0

var _decay_health: float = 500.0
var _is_enraged: bool = false
var _is_defeated: bool = false
var _is_active: bool = false

# UI Elements
var _container: Control = null
var _name_label: Label = null
var _phase_label: Label = null
var _health_bar_bg: ColorRect = null
var _health_bar_decay: ColorRect = null
var _health_bar_fill: ColorRect = null
var _health_label: Label = null
var _enrage_badge: Label = null
var _victory_banner: PanelContainer = null
var _victory_label: Label = null

const BAR_WIDTH: float = 340.0
const BAR_HEIGHT: float = 8.0


func _ready() -> void:
	layer = 15
	_build_ui()
	set_active(false)


func _build_ui() -> void:
	_container = Control.new()
	_container.name = "BossHealthContainer"
	_container.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_container)
	
	# Centered Panel Ribbon (Compact & Responsive)
	var panel := PanelContainer.new()
	panel.name = "BossPanel"
	panel.custom_minimum_size = Vector2(360, 44)
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.offset_left = -180.0
	panel.offset_top = 8.0
	panel.offset_right = 180.0
	panel.offset_bottom = 52.0
	
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.03, 0.07, 0.90)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.65, 0.25, 0.75, 0.70)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_right = 6
	sb.corner_radius_bottom_left = 6
	sb.content_margin_left = 10
	sb.content_margin_top = 4
	sb.content_margin_right = 10
	sb.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", sb)
	_container.add_child(panel)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)
	
	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(header_hbox)
	
	_name_label = Label.new()
	_name_label.text = boss_name
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.add_theme_font_size_override("font_size", 10)
	_name_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.95))
	header_hbox.add_child(_name_label)
	
	_phase_label = Label.new()
	_phase_label.text = "PHASE I: GUARDIAN"
	_phase_label.add_theme_font_size_override("font_size", 8)
	_phase_label.add_theme_color_override("font_color", Color(0.85, 0.60, 0.35))
	header_hbox.add_child(_phase_label)
	
	_enrage_badge = Label.new()
	_enrage_badge.text = "⚡ ENRAGED"
	_enrage_badge.add_theme_font_size_override("font_size", 8)
	_enrage_badge.add_theme_color_override("font_color", Color(1.0, 0.2, 0.1))
	_enrage_badge.visible = false
	header_hbox.add_child(_enrage_badge)
	
	# Bar container
	var bar_frame := Control.new()
	bar_frame.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	vbox.add_child(bar_frame)
	
	_health_bar_bg = ColorRect.new()
	_health_bar_bg.color = Color(0.10, 0.08, 0.14, 0.95)
	_health_bar_bg.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	bar_frame.add_child(_health_bar_bg)
	
	_health_bar_decay = ColorRect.new()
	_health_bar_decay.color = Color(0.95, 0.75, 0.25, 0.85)
	_health_bar_decay.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	bar_frame.add_child(_health_bar_decay)
	
	_health_bar_fill = ColorRect.new()
	_health_bar_fill.color = Color(0.90, 0.20, 0.25, 0.95)
	_health_bar_fill.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	bar_frame.add_child(_health_bar_fill)
	
	_health_label = Label.new()
	_health_label.text = "%d / %d HP" % [int(current_health), int(max_health)]
	_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_health_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_health_label.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_health_label.add_theme_font_size_override("font_size", 8)
	_health_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	bar_frame.add_child(_health_label)
	
	# Victory Banner
	_victory_banner = PanelContainer.new()
	_victory_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_victory_banner.offset_left = -160.0
	_victory_banner.offset_top = 60.0
	_victory_banner.offset_right = 160.0
	_victory_banner.offset_bottom = 96.0
	_victory_banner.custom_minimum_size = Vector2(320, 36)
	_victory_banner.visible = false
	_container.add_child(_victory_banner)
	
	_victory_label = Label.new()
	_victory_label.text = "★ ENCOUNTER CLEARED — BOSS DEFEATED ★"
	_victory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_victory_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_victory_label.add_theme_font_size_override("font_size", 13)
	_victory_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.6))
	_victory_banner.add_child(_victory_label)
	_container.add_child(_victory_banner)


func set_active(active: bool) -> void:
	_is_active = active
	if _container:
		_container.visible = active


func setup(p_name: String, p_max_hp: float) -> void:
	boss_name = p_name
	max_health = maxf(1.0, p_max_hp)
	current_health = max_health
	_decay_health = max_health
	if _name_label:
		_name_label.text = boss_name
	_update_bar_widths()


func update_health(new_health: float, new_max: float = -1.0) -> void:
	if new_max > 0.0:
		max_health = new_max
	current_health = clampf(new_health, 0.0, max_health)
	_update_bar_widths()


func set_phase(phase_index: int) -> void:
	if phase_index == 1:
		_is_enraged = true
		if _phase_label:
			_phase_label.text = "PHASE II: ENRAGED TITAN"
			_phase_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.15))
		if _health_bar_fill:
			_health_bar_fill.color = Color(1.0, 0.10, 0.10, 0.95)
		if _enrage_badge:
			_enrage_badge.visible = true
	else:
		_is_enraged = false
		if _phase_label:
			_phase_label.text = "PHASE I: COLOSSAL GUARDIAN"
			_phase_label.add_theme_color_override("font_color", Color(0.85, 0.60, 0.35))
		if _enrage_badge:
			_enrage_badge.visible = false


func show_defeat() -> void:
	_is_defeated = true
	current_health = 0.0
	_decay_health = 0.0
	_update_bar_widths()
	
	if _phase_label:
		_phase_label.text = "STATUS: ANNIHILATED"
		_phase_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.7))
	if _victory_banner:
		_victory_banner.visible = true
	
	# Slowly fade out after 6 seconds
	var tween := create_tween()
	tween.tween_interval(5.0)
	tween.tween_property(_container, "modulate:a", 0.0, 1.5)
	tween.tween_callback(func(): set_active(false))


func _process(delta: float) -> void:
	if not _is_active:
		return
	
	# Smoothly interpolate decay bar toward current health
	if _decay_health > current_health:
		_decay_health = move_toward(_decay_health, current_health, delta * (max_health * 0.35))
		if _health_bar_decay:
			var ratio: float = clampf(_decay_health / max_health, 0.0, 1.0)
			_health_bar_decay.size.x = BAR_WIDTH * ratio
	
	# Enraged badge flash pulse
	if _is_enraged and _enrage_badge and not _is_defeated:
		var pulse := (sin(Time.get_ticks_msec() * 0.008) + 1.0) * 0.5
		_enrage_badge.modulate = Color(1.0, 0.4 + pulse * 0.6, 0.4 + pulse * 0.6)


func _update_bar_widths() -> void:
	var ratio := clampf(current_health / max_health, 0.0, 1.0) if max_health > 0.0 else 0.0
	if _health_bar_fill:
		_health_bar_fill.size.x = BAR_WIDTH * ratio
	if _health_label:
		_health_label.text = "%d / %d HP (%d%%)" % [int(current_health), int(max_health), int(ratio * 100.0)]
