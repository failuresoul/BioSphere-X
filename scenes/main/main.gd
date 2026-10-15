extends Node2D
## Main scene — entry point for BioSphere-X.
## Transitions to the game world. A title screen can be added here later.

func _ready() -> void:
	print("BioSphere-X: Starting...")
	get_tree().change_scene_to_file.call_deferred("res://scenes/world/game_world.tscn")
