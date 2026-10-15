extends Node
## Automated test suite for BioSphere-X Survival HUD.
## Tests node hierarchy, GameState signal updates, pause overlay, and viewport scaling.

func _ready() -> void:
	print("--- Running BioSphere-X Survival HUD Tests ---")
	_run_tests()


func _run_tests() -> void:
	var hud_scene: PackedScene = load("res://ui/screens/hud.tscn")
	assert(hud_scene != null, "HUD scene must load successfully")
	
	var hud: CanvasLayer = hud_scene.instantiate()
	add_child(hud)
	
	var gs := get_node("/root/GameState")
	assert(gs != null, "GameState autoload must exist")
	
	# 1. Component Hierarchy Check
	var health_bar: ProgressBar = hud.get_node("%HealthBar")
	var health_label: Label = hud.get_node("%HealthLabel")
	var oxygen_bar: ProgressBar = hud.get_node("%OxygenBar")
	var oxygen_label: Label = hud.get_node("%OxygenLabel")
	var crystal_label: Label = hud.get_node("%CrystalCount")
	var titanium_label: Label = hud.get_node("%TitaniumCount")
	var biomass_label: Label = hud.get_node("%BiomassCount")
	var objective_label: Label = hud.get_node("%ObjectiveLabel")
	var pause_overlay: Control = hud.get_node("%PauseOverlay")
	var resume_btn: Button = hud.get_node("%ResumeButton")
	
	assert(health_bar != null, "HealthBar must exist")
	assert(health_label != null, "HealthLabel must exist")
	assert(oxygen_bar != null, "OxygenBar must exist")
	assert(oxygen_label != null, "OxygenLabel must exist")
	assert(crystal_label != null, "CrystalCount must exist")
	assert(titanium_label != null, "TitaniumCount must exist")
	assert(biomass_label != null, "BiomassCount must exist")
	assert(objective_label != null, "ObjectiveLabel must exist")
	assert(pause_overlay != null, "PauseOverlay must exist")
	assert(resume_btn != null, "ResumeButton must exist")
	print("  [PASS] HUD component hierarchy verified")
	
	# 2. Vitality Updates via GameState Signals
	gs.call("set_health", 72.0, 100.0)
	assert(health_bar.value == 72.0, "HealthBar value must update to 72.0")
	assert("72 / 100" in health_label.text, "HealthLabel text must reflect 72 / 100")
	
	gs.call("set_oxygen", 85.0)
	assert(oxygen_bar.value == 85.0, "OxygenBar value must update to 85.0")
	assert("85%" in oxygen_label.text, "OxygenLabel must display 85%")
	print("  [PASS] Vitality signals (Health & Oxygen) verified")
	
	# 3. Resource Inventory Updates via GameState Signals
	gs.call("add_resource", "crystals", 3)
	assert(crystal_label.text == str(gs.get("resources")["crystals"]), "Crystal count must reflect GameState")
	
	gs.call("add_resource", "titanium", 7)
	assert(titanium_label.text == str(gs.get("resources")["titanium"]), "Titanium count must reflect GameState")
	
	gs.call("add_resource", "biomass", 4)
	assert(biomass_label.text == str(gs.get("resources")["biomass"]), "Biomass count must reflect GameState")
	print("  [PASS] Resource inventory signals verified (Crystals, Titanium, Biomass)")
	
	# 4. Objective Updates via GameState Signals
	var test_objective := "TEST OBJECTIVE // Locate crashed exploration rover."
	gs.call("set_objective", test_objective)
	assert(objective_label.text == test_objective, "ObjectiveLabel must update to new objective")
	print("  [PASS] Mission objective signals verified")
	
	# 5. Pause Overlay Verification
	assert(pause_overlay.visible == false, "PauseOverlay must initially be hidden")
	gs.call("set_paused", true)
	assert(pause_overlay.visible == true, "PauseOverlay must be visible when game is paused")
	gs.call("set_paused", false)
	assert(pause_overlay.visible == false, "PauseOverlay must hide when game is resumed")
	print("  [PASS] Pause overlay toggle verified")
	
	# 6. Screen Scaling & Anchors Verification
	var root_ctrl: Control = hud.get_node("Root")
	assert(root_ctrl.anchor_right == 1.0 and root_ctrl.anchor_bottom == 1.0, "Root control must span full rect")
	
	var top_left: Control = hud.get_node("Root/TopLeftMargin")
	assert(top_left.anchor_left == 0.0 and top_left.anchor_right == 0.0, "Vitality panel must be anchored to Top-Left")
	
	var top_right: Control = hud.get_node("Root/TopRightMargin")
	assert(top_right.anchor_left == 1.0 and top_right.anchor_right == 1.0, "Resources panel must be anchored to Top-Right")
	
	var bottom_obj: Control = hud.get_node("Root/BottomObjectiveMargin")
	assert(bottom_obj.anchor_left == 0.5 and bottom_obj.anchor_right == 0.5, "Objective panel must be centered horizontally")
	assert(bottom_obj.anchor_top == 1.0 and bottom_obj.anchor_bottom == 1.0, "Objective panel must be anchored to bottom")
	
	# Test dynamic viewport resize response
	var test_sizes: Array[Vector2i] = [Vector2i(800, 600), Vector2i(1280, 720), Vector2i(1920, 1080)]
	for vs in test_sizes:
		root_ctrl.custom_minimum_size = Vector2(vs)
		await get_tree().process_frame
		assert(top_left.get_rect().size.x > 100.0, "TopLeft panel must have valid width at %dx%d" % [vs.x, vs.y])
		assert(top_right.get_rect().size.x > 100.0, "TopRight panel must have valid width at %dx%d" % [vs.x, vs.y])
		assert(bottom_obj.get_rect().size.x > 200.0, "Objective panel must have valid width at %dx%d" % [vs.x, vs.y])
	print("  [PASS] Dynamic viewport scaling & screen anchoring verified across multiple resolutions")
	
	hud.queue_free()
	print("--- All BioSphere-X Survival HUD Tests Passed! ---")
	get_tree().quit(0)
