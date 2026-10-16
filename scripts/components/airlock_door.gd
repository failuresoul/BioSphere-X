extends StaticBody2D
class_name AirlockDoor
## Interactive Airlock Pressure Door for BioSphere-X.
## Toggles open/closed state on interaction, controlling collision and passageway access.

signal door_toggled(is_open: bool)

@export var door_name: String = "Habitat Module Airlock"
@export var is_open: bool = false:
	set(val):
		is_open = val
		_update_door_state()
		queue_redraw()

@export var door_size: Vector2 = Vector2(48, 16)
@export var open_offset: float = 24.0

var _collision_shape: CollisionShape2D
var _interaction_area: Area2D
var _slide_progress: float = 0.0


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("doors")
	collision_layer = 1
	collision_mask = 1
	
	_setup_collision()
	_setup_interaction_area()
	_update_door_state()


func _setup_collision() -> void:
	_collision_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = door_size
	_collision_shape.shape = rect
	add_child(_collision_shape)


func _setup_interaction_area() -> void:
	_interaction_area = Area2D.new()
	_interaction_area.name = "InteractionArea"
	_interaction_area.collision_layer = 2 # Layer 2 (Interactable)
	_interaction_area.collision_mask = 1  # Detect Player
	
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 52.0
	shape.shape = circle
	_interaction_area.add_child(shape)
	add_child(_interaction_area)


func _process(delta: float) -> void:
	var target_progress: float = 1.0 if is_open else 0.0
	if not is_equal_approx(_slide_progress, target_progress):
		_slide_progress = move_toward(_slide_progress, target_progress, delta * 4.0)
		queue_redraw()


func _update_door_state() -> void:
	if _collision_shape:
		_collision_shape.set_deferred("disabled", is_open)


func get_interaction_prompt() -> String:
	return "Press E to Close Airlock" if is_open else "Press E to Open Airlock"


func can_interact(_user: Node2D = null) -> bool:
	return true


func interact(_user: Node2D = null) -> bool:
	is_open = not is_open
	door_toggled.emit(is_open)
	
	var mm := get_node_or_null("/root/MissionManager")
	if mm:
		mm.call("notify_event", "base_reached", {"target_zone": "habitat_airlock", "door": self, "is_open": is_open})
		
	return true


func _draw() -> void:
	# 1. Door Frame / Jambs
	var half_w := door_size.x * 0.5
	var half_h := door_size.y * 0.5
	
	# Left frame pillar
	draw_rect(Rect2(-half_w - 6, -half_h - 2, 6, door_size.y + 4), Color(0.12, 0.15, 0.22))
	draw_rect(Rect2(-half_w - 6, -half_h - 2, 6, door_size.y + 4), Color(0.3, 0.35, 0.45), false, 1.0)
	
	# Right frame pillar
	draw_rect(Rect2(half_w, -half_h - 2, 6, door_size.y + 4), Color(0.12, 0.15, 0.22))
	draw_rect(Rect2(half_w, -half_h - 2, 6, door_size.y + 4), Color(0.3, 0.35, 0.45), false, 1.0)
	
	# 2. Sliding Blast Doors (split in middle)
	var door_slide: float = _slide_progress * open_offset
	var half_door_w: float = half_w
	
	# Left door leaf
	var left_rect := Rect2(-half_w - door_slide, -half_h, half_door_w, door_size.y)
	draw_rect(left_rect, Color(0.18, 0.22, 0.30))
	draw_rect(left_rect, Color(0.25, 0.75, 0.95), false, 1.2)
	
	# Right door leaf
	var right_rect := Rect2(0.0 + door_slide, -half_h, half_door_w, door_size.y)
	draw_rect(right_rect, Color(0.18, 0.22, 0.30))
	draw_rect(right_rect, Color(0.25, 0.75, 0.95), false, 1.2)
	
	# Central Hazard / Status Stripe
	var stripe_color := Color(0.1, 0.9, 0.5) if is_open else Color(0.95, 0.4, 0.2)
	if is_open:
		draw_line(Vector2(-half_w - door_slide + 4, 0), Vector2(-door_slide - 4, 0), stripe_color, 2.0)
		draw_line(Vector2(door_slide + 4, 0), Vector2(half_w + door_slide - 4, 0), stripe_color, 2.0)
	else:
		draw_line(Vector2(-half_w + 4, 0), Vector2(half_w - 4, 0), stripe_color, 2.0)
