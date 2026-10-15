extends Area2D
class_name InteractionComponent
## Detects and manages interactions with nearby interactive world objects.
## Entities can be resources, alien terminals, containers, or survivors.

signal interactable_focused(target: Node2D)
signal interactable_unfocused(target: Node2D)
signal interacted(target: Node2D)

@export var interaction_radius: float = 48.0:
	set(val):
		interaction_radius = val
		_update_shape()

var _active_targets: Array[Node2D] = []
var _closest_target: Node2D = null
var _collision_shape: CollisionShape2D


func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 2 # Default interactable layer (layer 2)
	
	_ensure_shape()
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _ensure_shape() -> void:
	if not _collision_shape:
		_collision_shape = CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = interaction_radius
		_collision_shape.shape = circle
		add_child(_collision_shape)
	else:
		_update_shape()


func _update_shape() -> void:
	if _collision_shape and _collision_shape.shape is CircleShape2D:
		(_collision_shape.shape as CircleShape2D).radius = interaction_radius


func _process(_delta: float) -> void:
	_cleanup_invalid_targets()
	_update_focused_target()


func get_focused_target() -> Node2D:
	return _closest_target


func try_interact(user: Node2D = null) -> bool:
	if not _closest_target:
		return false
	
	interacted.emit(_closest_target)
	
	if _closest_target.has_method("interact"):
		_closest_target.call("interact", user if user else get_parent())
		return true
	
	return false


func _on_body_entered(body: Node2D) -> void:
	if _is_interactable(body) and not _active_targets.has(body):
		_active_targets.append(body)


func _on_body_exited(body: Node2D) -> void:
	_active_targets.erase(body)


func _on_area_entered(area: Area2D) -> void:
	if _is_interactable(area) and not _active_targets.has(area):
		_active_targets.append(area)


func _on_area_exited(area: Area2D) -> void:
	_active_targets.erase(area)


func _is_interactable(node: Node) -> bool:
	return node.is_in_group("interactable") or node.has_method("interact")


func _cleanup_invalid_targets() -> void:
	for i in range(_active_targets.size() - 1, -1, -1):
		var target := _active_targets[i]
		if not is_instance_valid(target) or not target.is_inside_tree():
			_active_targets.remove_at(i)


func _update_focused_target() -> void:
	var best_target: Node2D = null
	var min_dist_sq := INF
	var origin := global_position
	
	for target in _active_targets:
		if is_instance_valid(target):
			var dist_sq := origin.distance_squared_to(target.global_position)
			if dist_sq < min_dist_sq:
				min_dist_sq = dist_sq
				best_target = target
	
	if best_target != _closest_target:
		if _closest_target and is_instance_valid(_closest_target):
			interactable_unfocused.emit(_closest_target)
		_closest_target = best_target
		if _closest_target:
			interactable_focused.emit(_closest_target)
