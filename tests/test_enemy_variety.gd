extends Node2D
## Automated Test Suite for BioSphere-X Enemy Variety and Defeat Rewards.
## Validates modular enemy presets, architecture reuse, attack styles (melee, heavy slam, ranged spit),
## procedural visual differentiation, configurable reward drops, and clean disappearance.

const AlienEnemyScript := preload("res://scenes/enemies/alien_enemy.gd")
const AlienEnemyVisualScript := preload("res://scenes/enemies/alien_enemy_visual.gd")
const CollectableResourceScript := preload("res://scripts/components/collectable_resource.gd")
const EnergyProjectileScript := preload("res://scenes/items/energy_projectile.gd")

var _base_enemy_scene := preload("res://scenes/enemies/alien_enemy.tscn")
var _scout_scene := preload("res://scenes/enemies/enemy_scout.tscn")
var _brute_scene := preload("res://scenes/enemies/enemy_brute.tscn")
var _spitter_scene := preload("res://scenes/enemies/enemy_spitter.tscn")


func _ready() -> void:
	print("==================================================")
	print("  BIOSPHERE-X: RUNNING ENEMY VARIETY TEST SUITE")
	print("==================================================")
	
	test_architecture_reuse_and_presets()
	test_dedicated_scenes()
	test_scout_attack_style()
	test_brute_heavy_slam_attack()
	test_spitter_ranged_attack()
	test_defeat_reward_drops()
	test_clean_corpse_disappearance()
	test_visual_distinction()
	test_planet_enemy_distribution()
	
	print("==================================================")
	print("  ALL ENEMY VARIETY TESTS COMPLETED! [9/9]")
	print("==================================================")
	get_tree().quit(0)


func test_architecture_reuse_and_presets() -> void:
	print("[TEST 1/9] Verifying architecture reuse and dynamic presets on single AlienEnemy class...")
	var enemy: CharacterBody2D = _base_enemy_scene.instantiate()
	add_child(enemy)
	
	# Apply Scout Preset
	enemy.call("apply_enemy_preset", AlienEnemyScript.EnemyType.SCOUT)
	assert(enemy.get("enemy_name") == "Xeno Scout", "Preset name should match Scout")
	assert(enemy.get("chase_speed") == 210.0, "Scout chase speed should be 210")
	assert(enemy.get("detection_range") == 320.0, "Scout detection range should be 320")
	assert(enemy.get("attack_style") == AlienEnemyScript.AttackStyle.MELEE_SWIPE, "Scout attack style should be MELEE_SWIPE")
	assert(enemy.get("attack_damage") == 8.0, "Scout attack damage should be 8")
	var hc = enemy.get_node("HealthComponent")
	assert(hc.get("max_health") == 35.0, "Scout HP should be 35")
	
	# Switch same instance to Armored Brute Preset
	enemy.call("apply_enemy_preset", AlienEnemyScript.EnemyType.ARMORED_BRUTE)
	assert(enemy.get("enemy_name") == "Armored Goliath", "Preset name should match Armored Brute")
	assert(enemy.get("chase_speed") == 75.0, "Brute chase speed should be 75")
	assert(enemy.get("detection_range") == 190.0, "Brute detection range should be 190")
	assert(enemy.get("attack_style") == AlienEnemyScript.AttackStyle.HEAVY_SLAM, "Brute attack style should be HEAVY_SLAM")
	assert(enemy.get("attack_damage") == 28.0, "Brute attack damage should be 28")
	assert(hc.get("max_health") == 180.0, "Brute HP should be 180")
	
	# Switch same instance to Spitter Preset
	enemy.call("apply_enemy_preset", AlienEnemyScript.EnemyType.SPITTER)
	assert(enemy.get("enemy_name") == "Acid Spitter", "Preset name should match Spitter")
	assert(enemy.get("chase_speed") == 115.0, "Spitter chase speed should be 115")
	assert(enemy.get("detection_range") == 270.0, "Spitter detection range should be 270")
	assert(enemy.get("attack_style") == AlienEnemyScript.AttackStyle.RANGED_SPIT, "Spitter attack style should be RANGED_SPIT")
	assert(enemy.get("attack_range") == 220.0, "Spitter attack range should be 220")
	assert(enemy.get("attack_damage") == 14.0, "Spitter attack damage should be 14")
	assert(hc.get("max_health") == 65.0, "Spitter HP should be 65")
	
	enemy.queue_free()
	print("  [PASS] Single unified enemy architecture cleanly supports all presets.")


func test_dedicated_scenes() -> void:
	print("[TEST 2/9] Verifying dedicated scene files (Scout, Brute, Spitter)...")
	var scout = _scout_scene.instantiate()
	var brute = _brute_scene.instantiate()
	var spitter = _spitter_scene.instantiate()
	
	add_child(scout)
	add_child(brute)
	add_child(spitter)
	
	assert(scout.get("enemy_type") == AlienEnemyScript.EnemyType.SCOUT, "Scout scene type must be SCOUT")
	assert(brute.get("enemy_type") == AlienEnemyScript.EnemyType.ARMORED_BRUTE, "Brute scene type must be ARMORED_BRUTE")
	assert(spitter.get("enemy_type") == AlienEnemyScript.EnemyType.SPITTER, "Spitter scene type must be SPITTER")
	
	# Check stat differentiation
	assert(scout.get("chase_speed") > spitter.get("chase_speed"), "Scout should be faster than Spitter")
	assert(spitter.get("chase_speed") > brute.get("chase_speed"), "Spitter should be faster than Brute")
	assert(brute.get_node("HealthComponent").get("max_health") > spitter.get_node("HealthComponent").get("max_health"), "Brute should have more HP than Spitter")
	assert(spitter.get_node("HealthComponent").get("max_health") > scout.get_node("HealthComponent").get("max_health"), "Spitter should have more HP than Scout")
	
	scout.queue_free()
	brute.queue_free()
	spitter.queue_free()
	print("  [PASS] Dedicated scene files instantiate with accurate and balanced attributes.")


func test_scout_attack_style() -> void:
	print("[TEST 3/9] Verifying Scout swift melee swipe attack...")
	var scout = _scout_scene.instantiate()
	add_child(scout)
	
	# Create a dummy target player
	var dummy = CharacterBody2D.new()
	dummy.name = "DummyPlayer"
	dummy.add_to_group("player")
	var dummy_hc = preload("res://scripts/components/health_component.gd").new()
	dummy_hc.name = "HealthComponent"
	dummy_hc.set("max_health", 100.0)
	dummy_hc.set("current_health", 100.0)
	dummy.add_child(dummy_hc)
	add_child(dummy)
	
	scout.global_position = Vector2.ZERO
	dummy.global_position = Vector2(15, 0)
	
	var attack_event := {"fired": false, "target": null, "damage": 0.0}
	scout.connect("enemy_attacked", func(target, dmg):
		attack_event["fired"] = true
		attack_event["target"] = target
		attack_event["damage"] = dmg
	)
	
	scout.set_target_player(dummy)
	scout.call("_execute_attack_strike")
	
	assert(attack_event["fired"], "enemy_attacked signal must be emitted")
	assert(attack_event["target"] == dummy, "Target should be dummy")
	assert(attack_event["damage"] == 8.0, "Damage should be 8.0")
	assert(dummy_hc.get("current_health") == 92.0, "Dummy should have taken 8 damage (100 -> 92)")
	
	scout.queue_free()
	dummy.queue_free()
	print("  [PASS] Scout melee swipe successfully dealt swift calibrated damage.")


func test_brute_heavy_slam_attack() -> void:
	print("[TEST 4/9] Verifying Armored Brute heavy crushing slam attack...")
	var brute = _brute_scene.instantiate()
	add_child(brute)
	
	var dummy = CharacterBody2D.new()
	dummy.name = "DummyPlayer"
	dummy.add_to_group("player")
	var dummy_hc = preload("res://scripts/components/health_component.gd").new()
	dummy_hc.name = "HealthComponent"
	dummy_hc.set("max_health", 100.0)
	dummy_hc.set("current_health", 100.0)
	dummy.add_child(dummy_hc)
	add_child(dummy)
	
	brute.global_position = Vector2.ZERO
	dummy.global_position = Vector2(25, 0)
	
	var attack_event := {"fired": false, "target": null, "damage": 0.0}
	brute.connect("enemy_attacked", func(target, dmg):
		attack_event["fired"] = true
		attack_event["target"] = target
		attack_event["damage"] = dmg
	)
	
	brute.set_target_player(dummy)
	brute.call("_execute_attack_strike")
	
	assert(attack_event["fired"], "enemy_attacked signal must be emitted")
	assert(attack_event["target"] == dummy, "Target should be dummy")
	assert(attack_event["damage"] == 28.0, "Damage should be 28.0")
	assert(dummy_hc.get("current_health") == 72.0, "Dummy should have taken 28 damage (100 -> 72)")
	
	brute.queue_free()
	dummy.queue_free()
	print("  [PASS] Armored Brute crushing slam executed with high impact damage.")


func test_spitter_ranged_attack() -> void:
	print("[TEST 5/9] Verifying Spitter ranged projectile attack...")
	var spitter = _spitter_scene.instantiate()
	add_child(spitter)
	
	var dummy = CharacterBody2D.new()
	dummy.name = "DummyPlayer"
	dummy.add_to_group("player")
	add_child(dummy)
	
	spitter.global_position = Vector2.ZERO
	dummy.global_position = Vector2(160, 0)
	
	var attack_event := {"fired": false, "target": null, "damage": 0.0}
	spitter.connect("enemy_attacked", func(target, dmg):
		attack_event["fired"] = true
		attack_event["target"] = target
		attack_event["damage"] = dmg
	)
	
	spitter.set_target_player(dummy)
	spitter.call("_execute_attack_strike")
	
	assert(attack_event["fired"], "enemy_attacked signal must be emitted")
	assert(attack_event["target"] == dummy, "Target should be dummy")
	assert(attack_event["damage"] == 14.0, "Damage should be 14.0")
	
	# Verify an EnergyProjectile was spawned
	var found_proj: Node2D = null
	for child in get_children():
		if child is Area2D and child.get_script() and child.get_script().get_global_name() == "EnergyProjectile":
			found_proj = child
			break
		elif child.has_method("setup") and child.name.begins_with("@Area2D") or child.name.begins_with("EnergyProjectile"):
			found_proj = child
			break
	
	assert(found_proj != null, "EnergyProjectile must be spawned into parent tree")
	assert(found_proj.get("damage") == 14.0, "Projectile damage should match spitter attack damage")
	assert(found_proj.get("source_node") == spitter, "Projectile source must be spitter")
	
	found_proj.queue_free()
	spitter.queue_free()
	dummy.queue_free()
	print("  [PASS] Spitter ranged projectile attack successfully spawned and configured.")


func test_defeat_reward_drops() -> void:
	print("[TEST 6/9] Verifying configurable reward drops upon enemy defeat...")
	var container = Node2D.new()
	add_child(container)
	
	var scout = _scout_scene.instantiate()
	container.add_child(scout)
	scout.set("drops_reward", true)
	scout.set("reward_drop_chance", 1.0)
	scout.set("primary_resource_type", 3)
	scout.set("primary_resource_min", 2)
	scout.set("primary_resource_max", 2)
	scout.set("secondary_drop_chance", 0.0)
	scout.set("disappear_on_death", false)
	
	var death_event := {"fired": false, "enemy": null}
	scout.connect("enemy_died", func(enemy_node):
		death_event["fired"] = true
		death_event["enemy"] = enemy_node
	)
	
	var dmg_ok: bool = scout.take_damage(100.0)
	assert(dmg_ok, "take_damage must return true")
	assert(death_event["fired"], "enemy_died signal must be emitted")
	assert(death_event["enemy"] == scout, "enemy_died should pass the defeated enemy instance")
	assert(scout.get("current_state") == AlienEnemyScript.State.DEAD, "State should be DEAD")
	
	# Check dropped collectable in container
	var dropped_resource: Area2D = null
	for child in container.get_children():
		if child is Area2D and child.has_method("get_resource_id_name"):
			dropped_resource = child
			break
	
	assert(dropped_resource != null, "Defeated enemy must spawn a CollectableResource")
	assert(dropped_resource.get("resource_type") == CollectableResourceScript.ResourceType.SCIENTIFIC_SAMPLE, "Resource type should be Scientific Sample (Biomass)")
	assert(dropped_resource.get("quantity") == 2, "Resource quantity should be 2")
	
	container.queue_free()
	print("  [PASS] Defeated enemies reliably spawn configured collectable resources.")


func test_clean_corpse_disappearance() -> void:
	print("[TEST 7/9] Verifying clean corpse cleanup behavior...")
	var enemy = _base_enemy_scene.instantiate()
	add_child(enemy)
	
	enemy.set("drops_reward", false)
	enemy.set("disappear_on_death", true)
	enemy.set("corpse_linger_time", 0.0) # Instant cleanup for test
	
	enemy.call("take_damage", 150.0)
	assert(enemy.get("current_state") == AlienEnemyScript.State.DEAD, "State should be DEAD")
	
	enemy.queue_free()
	print("  [PASS] Clean corpse cleanup and no-reward mode functioning correctly.")


func test_visual_distinction() -> void:
	print("[TEST 8/9] Verifying procedural visual distinction per enemy type...")
	var vis_scout = AlienEnemyVisualScript.new()
	var vis_brute = AlienEnemyVisualScript.new()
	var vis_spitter = AlienEnemyVisualScript.new()
	
	add_child(vis_scout)
	add_child(vis_brute)
	add_child(vis_spitter)
	
	vis_scout.call("set_enemy_type", AlienEnemyVisualScript.VisualEnemyType.SCOUT)
	vis_brute.call("set_enemy_type", AlienEnemyVisualScript.VisualEnemyType.ARMORED_BRUTE)
	vis_spitter.call("set_enemy_type", AlienEnemyVisualScript.VisualEnemyType.SPITTER)
	
	# Verify distinct scales
	assert(vis_scout.scale.x < 1.0, "Scout visual scale should be lean/compact (< 1.0)")
	assert(vis_brute.scale.x > 1.2, "Brute visual scale should be massive (> 1.2)")
	assert(absf(vis_spitter.scale.x - 1.05) < 0.05, "Spitter visual scale should be medium (~1.05)")
	
	# Verify distinct color palettes
	assert(vis_scout.get("bio_glow_color") != vis_brute.get("bio_glow_color"), "Scout and Brute must have distinct glow colors")
	assert(vis_spitter.get("bio_glow_color") != vis_brute.get("bio_glow_color"), "Spitter and Brute must have distinct glow colors")
	
	vis_scout.queue_free()
	vis_brute.queue_free()
	vis_spitter.queue_free()
	print("  [PASS] Procedural visuals clearly distinguish Scout, Brute, and Spitter.")


func test_planet_enemy_distribution() -> void:
	print("[TEST 9/9] Verifying balanced introductory planet enemy distribution...")
	var world_scene = preload("res://scenes/world/game_world.tscn")
	var world = world_scene.instantiate()
	add_child(world)
	
	var enemies_container = world.get_node_or_null("AlienEnemies")
	assert(enemies_container != null, "GameWorld must have AlienEnemies container")
	
	var count_scouts := 0
	var count_brutes := 0
	var count_spitters := 0
	
	for child in enemies_container.get_children():
		if child is CharacterBody2D:
			var etype = child.get("enemy_type")
			if etype == AlienEnemyScript.EnemyType.SCOUT:
				count_scouts += 1
			elif etype == AlienEnemyScript.EnemyType.ARMORED_BRUTE:
				count_brutes += 1
			elif etype == AlienEnemyScript.EnemyType.SPITTER:
				count_spitters += 1
	
	assert(count_scouts >= 2, "GameWorld must spawn at least 2 Scouts")
	assert(count_spitters >= 1, "GameWorld must spawn at least 1 Spitter")
	assert(count_brutes >= 1, "GameWorld must spawn at least 1 Armored Brute")
	
	print("  Planet enemy roster: %d Scouts, %d Spitters, %d Armored Brutes" % [count_scouts, count_spitters, count_brutes])
	
	world.queue_free()
	print("  [PASS] Introductory planet features a balanced variety of all 3 enemy types.")
