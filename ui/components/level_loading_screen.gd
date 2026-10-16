extends CanvasLayer
## High-tech loading transition curtain for planetary hyperspace jumps.
## Displays orbital trajectory calculation, planet parameters, and warp progress.

signal transition_finished()

@onready var backdrop: ColorRect = %Backdrop
@onready var title_label: Label = %TitleLabel
@onready var destination_label: Label = %DestinationLabel
@onready var status_label: Label = %StatusLabel
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var detail_label: Label = %DetailLabel

var _is_transitioning: bool = false
var _progress: float = 0.0
var _target_planet_name: String = ""


func _ready() -> void:
	visible = false
	layer = 100


func start_transition(from_planet: String, to_planet: String, on_midpoint_callback: Callable = Callable()) -> void:
	visible = true
	_is_transitioning = true
	_progress = 0.0
	_target_planet_name = to_planet
	
	if destination_label:
		destination_label.text = "WARP VECTOR: %s ➔ %s" % [from_planet.to_upper(), to_planet.to_upper()]
	if status_label:
		status_label.text = "CALIBRATING HYPERSPACE INCLINATION..."
	if progress_bar:
		progress_bar.value = 0.0
	if detail_label:
		detail_label.text = "Preserving life-support integrity and carried mission cargo..."
		
	# Smooth asynchronous animation sequence
	var tween := create_tween()
	tween.tween_property(self, "_progress", 50.0, 0.45)
	tween.tween_callback(func():
		if status_label:
			status_label.text = "RECONFIGURING SURFACE ENVIRONMENT & ATMOSPHERE..."
		if on_midpoint_callback.is_valid():
			on_midpoint_callback.call()
	)
	tween.tween_property(self, "_progress", 100.0, 0.45)
	tween.tween_callback(func():
		if status_label:
			status_label.text = "ORBITAL INSERTION CONFIRMED. ENTERING SURFACE REGION."
		if progress_bar:
			progress_bar.value = 100.0
	)
	tween.tween_interval(0.2)
	tween.tween_callback(func():
		visible = false
		_is_transitioning = false
		transition_finished.emit()
	)


func _process(_delta: float) -> void:
	if _is_transitioning and progress_bar:
		progress_bar.value = _progress
