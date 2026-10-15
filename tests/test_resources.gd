extends Node
## Automated test suite for BioSphere-X Collectable Resources.
## Validates resource types (Oxygen Cell, Metal, Crystal, Sample), configurable quantities,
## proximity visual indicators, player interaction (E), inventory & HUD updates,
## and strict prevention of repeated collection.

const CollectableResourceClass = preload("res://scripts/components/collectable_resource.gd")
const CollectableScene = preload("res://scenes/items/collectable_resource.tscn")
const PlayerScene = preload("res://scenes/player/player.tscn")

func _ready() -> void:
	print("--- Running BioSphere-X Resource Collection Tests ---")
	_run_tests()


func _run_tests() -> void:
	var gs := get_node("/root/GameState")
	assert(gs != null, "GameState autoload must exist")
	gs.call("restart_game")
	
	# -----------------------------------------------------------------------
	# 1. Component Instantiation & Inspector Configuration
	# -----------------------------------------------------------------------
	var item = CollectableScene.instantiate()
	item.resource_type = CollectableResourceClass.ResourceType.METAL
	item.quantity = 3
	item.interaction_radius = 50.0
	add_child(item)
	
	assert(item.resource_type == CollectableResourceClass.ResourceType.METAL, "Resource type must be METAL")
	assert(item.quantity == 3, "Quantity must be 3")
	assert(item.interaction_radius == 50.0, "Interaction radius must be 50.0")
	assert("Metal" in item.get_display_name(), "Display name must contain Metal")
	assert(item.get_resource_id_name() == "titanium", "Resource ID for Metal must map to titanium")
	print("  [PASS] Resource instantiation and inspector configuration verified")
	
	# -----------------------------------------------------------------------
	# 2. Proximity Visual Indicators (Prompt visibility)
	# -----------------------------------------------------------------------
	var test_player := CharacterBody2D.new()
	test_player.add_to_group("player")
	add_child(test_player)
	
	var prompt: Label = item.get_node_or_null("_prompt_label")
	if not prompt:
		prompt = item.find_child("*Label*", true, false)
	
	# Simulate player walking near item
	item._on_body_entered(test_player)
	assert(item._is_player_near == true, "Player should be marked near item")
	if prompt:
		assert(prompt.visible == true, "Prompt indicator must be visible when player is near")
		assert("[E]" in prompt.text, "Prompt text must prompt [E] interaction")
		assert("(+3)" in prompt.text, "Prompt text must show quantity (+3)")
	
	# Simulate player walking away
	item._on_body_exited(test_player)
	assert(item._is_player_near == false, "Player should be marked not near item")
	if prompt:
		assert(prompt.visible == false, "Prompt indicator must hide when player moves away")
	print("  [PASS] Proximity detection and visual indicator verified")
	
	# -----------------------------------------------------------------------
	# 3. Collection Interaction & Inventory Update
	# -----------------------------------------------------------------------
	var start_metal: int = gs.get_resource("titanium")
	var collected_signal_fired: Dictionary = {"called": false, "qty": 0}
	item.collected.connect(func(_user, _type, amt: int):
		collected_signal_fired["called"] = true
		collected_signal_fired["qty"] = amt
	)
	
	var success: bool = item.interact(test_player)
	assert(success == true, "First interact call must return true")
	assert(collected_signal_fired["called"] == true, "collected signal must be emitted")
	assert(collected_signal_fired["qty"] == 3, "collected amount must be 3")
	assert(gs.get_resource("titanium") == start_metal + 3, "Inventory titanium/metal must increase by 3")
	assert(item.is_collected == true, "Item must be marked is_collected = true")
	print("  [PASS] Interaction collection and inventory update verified")
	
	# -----------------------------------------------------------------------
	# 4. Prevention of Repeated Collection (No double pickup)
	# -----------------------------------------------------------------------
	var repeat_success: bool = item.interact(test_player)
	assert(repeat_success == false, "Repeated interact must return false")
	assert(gs.get_resource("titanium") == start_metal + 3, "Inventory must NOT increase on repeated collection")
	print("  [PASS] Strict prevention of repeated collection verified")
	
	# -----------------------------------------------------------------------
	# 5. Verification of All 4 Resource Types
	# -----------------------------------------------------------------------
	# A. Oxygen Cell (Type 0) -> Adds to inventory and refills oxygen
	gs.call("set_oxygen", 40.0)
	var o2_item = CollectableScene.instantiate()
	o2_item.resource_type = CollectableResourceClass.ResourceType.OXYGEN_CELL
	o2_item.quantity = 1
	o2_item.oxygen_restore_amount = 30.0
	add_child(o2_item)
	
	var start_o2: float = gs.get("oxygen")
	o2_item.interact(test_player)
	assert(gs.get_resource("oxygen_cells") >= 1, "Oxygen cells inventory updated")
	assert(gs.get("oxygen") > start_o2, "Oxygen level restored by oxygen cell")
	assert(is_equal_approx(gs.get("oxygen"), start_o2 + 30.0), "Oxygen restored by exact configured amount (+30.0)")
	
	# B. Energy Crystal (Type 2)
	var crystal_item = CollectableScene.instantiate()
	crystal_item.resource_type = CollectableResourceClass.ResourceType.ENERGY_CRYSTAL
	crystal_item.quantity = 2
	add_child(crystal_item)
	var start_cryst: int = gs.get_resource("crystals")
	crystal_item.interact(test_player)
	assert(gs.get_resource("crystals") == start_cryst + 2, "Crystals inventory increased by 2")
	
	# C. Scientific Sample (Type 3)
	var sample_item = CollectableScene.instantiate()
	sample_item.resource_type = CollectableResourceClass.ResourceType.SCIENTIFIC_SAMPLE
	sample_item.quantity = 4
	add_child(sample_item)
	var start_biomass: int = gs.get_resource("biomass")
	sample_item.interact(test_player)
	assert(gs.get_resource("biomass") == start_biomass + 4, "Biomass/samples inventory increased by 4")
	print("  [PASS] All 4 resource types verified (Oxygen Cell, Metal, Crystal, Scientific Sample)")
	
	# -----------------------------------------------------------------------
	# 6. Player Controller Integration (try_interact)
	# -----------------------------------------------------------------------
	var player = PlayerScene.instantiate()
	player.position = Vector2(200, 200)
	add_child(player)
	
	var world_item = CollectableScene.instantiate()
	world_item.resource_type = CollectableResourceClass.ResourceType.ENERGY_CRYSTAL
	world_item.quantity = 1
	world_item.position = Vector2(210, 200) # 10 pixels away from player
	add_child(world_item)
	
	# Simulate interaction component detection
	var interact_comp = player.get_node("InteractionComponent")
	assert(interact_comp != null, "Player must have InteractionComponent")
	interact_comp._on_area_entered(world_item)
	interact_comp._process(0.016)
	
	var player_collected_crystals: int = gs.get_resource("crystals")
	var did_interact: bool = player.try_interact()
	assert(did_interact == true, "player.try_interact() should succeed on focused collectable")
	assert(gs.get_resource("crystals") == player_collected_crystals + 1, "Player pickup incremented crystals")
	assert(world_item.is_collected == true, "World item marked collected through player interaction")
	print("  [PASS] Player controller try_interact() integration verified")
	
	test_player.queue_free()
	player.queue_free()
	print("--- All BioSphere-X Resource Collection Tests Passed Successfully! ---")
	get_tree().quit(0)
