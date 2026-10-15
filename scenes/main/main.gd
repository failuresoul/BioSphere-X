extends Control
## Main Menu & Game Mode Selector for BioSphere-X.
## Provides direct access to:
## 1. Survival Campaign (Human player controls astronaut)
## 2. AI vs AI Simulation Arena (Autonomous Agent A vs Agent B research testbed)

@onready var survival_button: Button = %SurvivalButton
@onready var ai_arena_button: Button = %AIArenaButton
@onready var backend_status_label: Label = %BackendStatusLabel
@onready var refresh_backend_btn: Button = %RefreshBackendButton


func _ready() -> void:
	Engine.time_scale = 1.0 # Ensure standard time scale
	_setup_button_events()
	_check_backend_status()


func _setup_button_events() -> void:
	if survival_button:
		survival_button.pressed.connect(_on_survival_pressed)
	if ai_arena_button:
		ai_arena_button.pressed.connect(_on_ai_arena_pressed)
	if refresh_backend_btn:
		refresh_backend_btn.pressed.connect(_check_backend_status)


func _check_backend_status() -> void:
	if backend_status_label:
		backend_status_label.text = "Checking Python AI Backend..."
		backend_status_label.modulate = Color(0.7, 0.7, 0.7)

	var ai_client = get_node_or_null("/root/AIClient")
	if ai_client and ai_client.has_method("check_health"):
		ai_client.call("check_health", func(res: Dictionary):
			if not is_instance_valid(self):
				return
			var online := bool(res.get("success", false))
			if backend_status_label:
				if online:
					backend_status_label.text = "● PYTHON AI BACKEND: ONLINE (127.0.0.1:8000)"
					backend_status_label.modulate = Color(0.2, 1.0, 0.5)
				else:
					backend_status_label.text = "○ PYTHON AI BACKEND: OFFLINE (Fallback Mode Active)"
					backend_status_label.modulate = Color(1.0, 0.6, 0.2)
		)
	elif backend_status_label:
		backend_status_label.text = "○ AIClient Autoload not detected"


func _on_survival_pressed() -> void:
	print("BioSphere-X: Launching Survival Campaign...")
	get_tree().change_scene_to_file("res://scenes/world/game_world.tscn")


func _on_ai_arena_pressed() -> void:
	print("BioSphere-X: Launching AI vs AI Simulation Arena...")
	get_tree().change_scene_to_file("res://scenes/ai_vs_ai/ai_arena.tscn")
