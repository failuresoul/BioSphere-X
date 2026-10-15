extends Node
## Automated test suite for BioSphere-X Interaction and Tutorial Systems.
## Validates contextual prompts across resources, oxygen stations, doors, and terminals,
## modular interaction handling, and full beginning-to-end tutorial progression.

const CollectableScene = preload("res://scenes/items/collectable_resource.tscn")
const OxygenStationClass = preload("res://scripts/components/oxygen_station.gd")
const TerminalClass = preload("res://scripts/components/research_terminal.gd")
const DoorClass = preload("res://scripts/components/airlock_door.gd")
const TutorialManagerClass = preload("res://scripts/components/tutorial_manager.gd")
const PlayerScene = preload("res://scenes/player/player.tscn")
const HUDScene = preload("res://ui/screens/hud.tscn")

func _ready() -> void:
	print("--- Running BioSphere-X Interaction & Tutorial Tests ---")
	_run_tests()


func _run_tests() -> void:
	var gs := get_node("/root/GameState")
	assert(gs != null, "GameState autoload must exist")
	gs.call("restart_game")
	
	# -----------------------------------------------------------------------
	# 1. Contextual Interaction Prompts across Diverse Objects
	# -----------------------------------------------------------------------
	# A. Resource Item
	var resource_item = CollectableScene.instantiate()
	resource_item.resource_type = 2 # ENERGY_CRYSTAL
	resource_item.quantity = 2
	add_child(resource_item)
	assert("Energy Crystal" in resource_item.get_interaction_prompt(), "Resource prompt must specify item name")
	assert("Press E" in resource_item.get_interaction_prompt(), "Resource prompt must include Press E")
	
	# B. Oxygen Station
	var o2_station = OxygenStationClass.new()
	add_child(o2_station)
	assert("Refill Oxygen" in o2_station.get_interaction_prompt(), "Oxygen station prompt must state Refill Oxygen")
	
	# C. Research Terminal
	var terminal = TerminalClass.new()
	add_child(terminal)
	assert("Access" in terminal.get_interaction_prompt() or "Terminal" in terminal.get_interaction_prompt(), "Terminal prompt must specify terminal access")
	
	# D. Airlock Door
	var door = DoorClass.new()
	add_child(door)
	assert(door.get_interaction_prompt() == "Press E to Open Airlock", "Closed door must prompt to Open")
	door.interact()
	assert(door.is_open == true, "Door must be open after interact")
	assert(door.get_interaction_prompt() == "Press E to Close Airlock", "Open door must prompt to Close")
	print("  [PASS] Contextual interaction prompts verified across resources, stations, terminals, and doors")
	
	# -----------------------------------------------------------------------
	# 2. Modular InteractionComponent Integration
	# -----------------------------------------------------------------------
	var player = PlayerScene.instantiate()
	player.position = Vector2(100, 100)
	add_child(player)
	
	var interact_comp = player.get_node("InteractionComponent")
	assert(interact_comp != null, "Player must have InteractionComponent")
	
	var prompt_received: Dictionary = {"text": ""}
	interact_comp.prompt_changed.connect(func(txt: String):
		prompt_received["text"] = txt
	)
	
	# Position terminal adjacent to player
	terminal.position = Vector2(110, 100)
	interact_comp._on_area_entered(terminal)
	interact_comp._process(0.016)
	
	assert(interact_comp.get_focused_target() == terminal, "Terminal must be focused")
	assert("Terminal" in interact_comp.get_current_prompt(), "Current prompt must reflect focused terminal")
	
	var player_interacted: bool = player.try_interact()
	assert(player_interacted == true, "player.try_interact() must execute modular interaction on terminal")
	assert(terminal.is_scanned == true, "Terminal must register scanned state")
	print("  [PASS] Modular player interaction and prompt dispatch verified")
	
	# -----------------------------------------------------------------------
	# 3. Beginning-to-End Tutorial Progression
	# -----------------------------------------------------------------------
	var tutorial = TutorialManagerClass.new()
	tutorial.set_player(player)
	add_child(tutorial)
	
	assert(tutorial.current_step == TutorialManagerClass.TutorialStep.MOVEMENT, "Tutorial must start at STEP 1: MOVEMENT")
	assert(tutorial.is_tutorial_complete == false, "Tutorial must start incomplete")
	
	# Step 1: Locomotion -> Player moves
	player.velocity = Vector2(100, 0)
	tutorial._process(1.5) # Simulate 1.5s of movement
	assert(tutorial.current_step == TutorialManagerClass.TutorialStep.OXYGEN, "Tutorial must advance to STEP 2: OXYGEN")
	print("  [PASS] Tutorial Step 1 (Locomotion) completed")
	
	# Step 2: Life Support / Oxygen -> Observes atmosphere
	tutorial._process(4.5) # Simulate 4.5s observing oxygen
	assert(tutorial.current_step == TutorialManagerClass.TutorialStep.COLLECT, "Tutorial must advance to STEP 3: COLLECT")
	print("  [PASS] Tutorial Step 2 (Life Support) completed")
	
	# Step 3: Resource Recovery -> Collects resource
	gs.call("add_resource", "crystals", 1)
	assert(tutorial.current_step == TutorialManagerClass.TutorialStep.REACH_STATION, "Tutorial must advance to STEP 4: REACH_STATION")
	print("  [PASS] Tutorial Step 3 (Resource Recovery) completed")
	
	# Step 4: Reach Station -> Accesses Research Terminal
	var tutorial_complete_fired: Dictionary = {"value": false}
	tutorial.tutorial_completed.connect(func():
		tutorial_complete_fired["value"] = true
	)
	
	tutorial.notify_terminal_scanned()
	assert(tutorial.current_step == TutorialManagerClass.TutorialStep.COMPLETE, "Tutorial must reach COMPLETE state")
	assert(tutorial.is_tutorial_complete == true, "Tutorial is_tutorial_complete must be true")
	assert(tutorial_complete_fired["value"] == true, "tutorial_completed signal must be emitted")
	print("  [PASS] Tutorial Step 4 & Final Protocol Completion verified")
	
	# -----------------------------------------------------------------------
	# 4. HUD Contextual Prompt & Tutorial Banner Display
	# -----------------------------------------------------------------------
	var hud = HUDScene.instantiate()
	add_child(hud)
	
	var contextual_prompt: PanelContainer = hud.get_node("%ContextualPrompt")
	var prompt_label: Label = hud.get_node("%PromptLabel")
	var tutorial_step_label: Label = hud.get_node("%TutorialStepLabel")
	var tutorial_desc_label: Label = hud.get_node("%TutorialDescLabel")
	var tutorial_progress_label: Label = hud.get_node("%TutorialProgressLabel")
	
	assert(contextual_prompt != null, "HUD must have ContextualPrompt panel")
	assert(prompt_label != null, "HUD must have PromptLabel")
	assert(tutorial_step_label != null, "HUD must have TutorialStepLabel")
	assert(tutorial_desc_label != null, "HUD must have TutorialDescLabel")
	assert(tutorial_progress_label != null, "HUD must have TutorialProgressLabel")
	
	# Test prompt visibility update
	gs.emit_signal("interaction_prompt_changed", "Press E to Collect Oxygen Cell (+1)")
	assert(contextual_prompt.visible == true, "Contextual prompt must be visible when target is focused")
	assert("Oxygen Cell" in prompt_label.text, "Prompt text must reflect target action")
	
	# Test prompt clear
	gs.emit_signal("interaction_prompt_changed", "")
	assert(contextual_prompt.visible == false, "Contextual prompt must hide when target unfocused")
	
	# Test tutorial banner update
	gs.emit_signal("tutorial_step_changed", 0, "STEP 1/4: LOCOMOTION", "Use WASD to move", false)
	assert("LOCOMOTION" in tutorial_step_label.text, "Tutorial header reflects current step")
	assert("●" in tutorial_progress_label.text, "Tutorial progress indicator shows active step")
	
	# Test tutorial banner complete
	gs.emit_signal("tutorial_step_changed", 4, "PROTOCOL ACCOMPLISHED", "Surveyed", true)
	assert("PROTOCOL" in tutorial_step_label.text, "Tutorial header reflects accomplishment")
	print("  [PASS] HUD contextual prompt and tutorial banner verified")
	
	resource_item.queue_free()
	o2_station.queue_free()
	terminal.queue_free()
	door.queue_free()
	player.queue_free()
	tutorial.queue_free()
	hud.queue_free()
	
	print("--- All BioSphere-X Interaction & Tutorial Tests Passed Successfully! ---")
	get_tree().quit(0)
