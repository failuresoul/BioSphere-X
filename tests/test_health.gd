extends Node
## Automated test suite for BioSphere-X Health, Damage, Clamping, and Game-Over System.
## Validates reusable HealthComponent, Player integration, Damage Feedback, HUD, and Game-Over state.

const HealthComponentClass = preload("res://scripts/components/health_component.gd")
const PlayerClass = preload("res://scenes/player/player.gd")
const AstronautVisualClass = preload("res://scenes/player/astronaut_visual.gd")

func _ready() -> void:
	print("--- Running BioSphere-X Health & Damage Tests ---")
	_run_tests()


func _run_tests() -> void:
	# -----------------------------------------------------------------------
	# 1. HealthComponent Unit Tests (Clamping, Damage, Healing, Signals)
	# -----------------------------------------------------------------------
	var hc = HealthComponentClass.new()
	hc.invulnerability_time = 0.0 # Zero invuln delay for instantaneous unit testing
	hc.max_health = 100.0
	add_child(hc)
	
	assert(hc.is_alive() == true, "HealthComponent must initially be alive")
	assert(hc.is_dead() == false, "HealthComponent must not be dead initially")
	assert(hc.current_health == 100.0, "Initial health must equal max_health (100.0)")
	assert(is_equal_approx(hc.get_health_ratio(), 1.0), "Initial health ratio must be 1.0")
	
	# Damage signal tracking
	var dmg_data: Dictionary = {"amount": 0.0, "called": false}
	hc.damaged.connect(func(amt: float, _src: Node):
		dmg_data["amount"] = amt
		dmg_data["called"] = true
	)
	
	var dmg_success: bool = hc.damage(30.0)
	assert(dmg_success == true, "Damage must return true when applied")
	assert(is_equal_approx(hc.current_health, 70.0), "Current health must decrease to 70.0")
	assert(dmg_data["called"] == true and is_equal_approx(dmg_data["amount"], 30.0), "Damaged signal must emit correct amount")
	
	# Healing & Overheal Clamping
	var heal_data: Dictionary = {"amount": 0.0, "called": false}
	hc.healed.connect(func(amt: float):
		heal_data["amount"] = amt
		heal_data["called"] = true
	)
	
	hc.heal(15.0)
	assert(is_equal_approx(hc.current_health, 85.0), "Current health must heal to 85.0")
	assert(heal_data["called"] == true and is_equal_approx(heal_data["amount"], 15.0), "Healed signal must emit correct amount")
	
	# Test Overhealing: Cannot exceed max_health
	hc.heal(50.0)
	assert(is_equal_approx(hc.current_health, 100.0), "Health must be clamped at max_health (100.0)")
	assert(is_equal_approx(hc.get_health_ratio(), 1.0), "Health ratio must not exceed 1.0")
	
	# Invulnerability Test
	hc.is_invulnerable = true
	var invuln_dmg: bool = hc.damage(20.0)
	assert(invuln_dmg == false, "Damage must be ignored when is_invulnerable is true")
	assert(is_equal_approx(hc.current_health, 100.0), "Health must remain intact when invulnerable")
	hc.is_invulnerable = false
	
	# Lethal Damage & Zero-Clamping Test
	var died_called: Dictionary = {"value": false}
	hc.died.connect(func():
		died_called["value"] = true
	)
	
	var lethal_result: bool = hc.damage(250.0)
	assert(lethal_result == true, "Lethal hit must apply")
	assert(hc.current_health == 0.0, "Health must be clamped to 0.0, never negative")
	assert(hc.is_dead() == true, "HealthComponent must register as dead")
	assert(hc.is_alive() == false, "HealthComponent must not be alive")
	assert(died_called["value"] == true, "died signal must be emitted when health drops to 0")
	
	# Cannot damage already dead entity
	var post_mortem_dmg: bool = hc.damage(10.0)
	assert(post_mortem_dmg == false, "Cannot damage an entity that is already dead")
	assert(hc.current_health == 0.0, "Health must stay at 0.0")
	
	# Reset
	hc.reset()
	assert(is_equal_approx(hc.current_health, 100.0), "reset() must restore health to max_health")
	hc.queue_free()
	print("  [PASS] HealthComponent unit tests passed (Damage, Heal, Clamping, Dead state)")
	
	# -----------------------------------------------------------------------
	# 2. Reusability for Enemies / Bosses
	# -----------------------------------------------------------------------
	var enemy_dummy := Node2D.new()
	var enemy_hc = HealthComponentClass.new()
	enemy_hc.max_health = 500.0 # Boss HP pool
	enemy_dummy.add_child(enemy_hc)
	add_child(enemy_dummy)
	
	assert(enemy_hc.max_health == 500.0, "Component supports arbitrary enemy/boss max health")
	assert(enemy_hc.current_health == 500.0, "Enemy HP initialized correctly")
	enemy_hc.damage(120.0)
	assert(is_equal_approx(enemy_hc.current_health, 380.0), "Enemy took independent damage")
	enemy_dummy.queue_free()
	print("  [PASS] Component reusability for enemies and bosses verified")
	
	# -----------------------------------------------------------------------
	# 3. Player Integration & Death Freezing
	# -----------------------------------------------------------------------
	var player_scene: PackedScene = load("res://scenes/player/player.tscn")
	assert(player_scene != null, "Player scene must exist")
	var player = player_scene.instantiate()
	add_child(player)
	
	var p_hc = player.get_node("HealthComponent")
	assert(p_hc != null, "Player must contain a HealthComponent child")
	p_hc.invulnerability_time = 0.0
	
	var p_vis = player.get_node("Visual")
	assert(p_vis != null, "Player must contain AstronautVisual")
	
	# Test Player takes damage
	var p_damaged_called: Dictionary = {"amount": 0.0}
	player.player_damaged.connect(func(amt: float, _cur: float, _mx: float):
		p_damaged_called["amount"] = amt
	)
	
	player.take_damage(25.0)
	assert(is_equal_approx(player.get_current_health(), 75.0), "Player current health must be 75.0")
	assert(is_equal_approx(p_damaged_called["amount"], 25.0), "player_damaged signal emitted")
	assert(p_vis._damage_flash_timer > 0.0, "Visual damage flash timer triggered")
	
	# Test Player healing
	player.heal(10.0)
	assert(is_equal_approx(player.get_current_health(), 85.0), "Player current health healed to 85.0")
	
	# Test Player Lethal Damage -> Movement & Combat Frozen
	var p_died_called: Dictionary = {"value": false}
	player.player_died.connect(func():
		p_died_called["value"] = true
	)
	
	player.take_damage(200.0)
	assert(player.is_dead == true, "Player is_dead flag must be true")
	assert(p_died_called["value"] == true, "player_died signal emitted")
	assert(p_vis.is_dead == true, "AstronautVisual is_dead set to true")
	
	# Process physics frame to verify movement is strictly frozen
	player.velocity = Vector2(240, 240)
	player._physics_process(0.016)
	assert(player.velocity == Vector2.ZERO, "Velocity must be clamped to Vector2.ZERO when dead")
	
	player.queue_free()
	print("  [PASS] Player integration, damage feedback, and death freeze verified")
	
	# -----------------------------------------------------------------------
	# 4. HUD Damage Feedback & Game-Over State Verification
	# -----------------------------------------------------------------------
	var hud_scene: PackedScene = load("res://ui/screens/hud.tscn")
	assert(hud_scene != null, "HUD scene must exist")
	var hud: CanvasLayer = hud_scene.instantiate()
	add_child(hud)
	
	var gs := get_node("/root/GameState")
	assert(gs != null, "GameState autoload must exist")
	
	# Reset GameState to known clean state
	gs.call("restart_game")
	assert(gs.get("is_game_over") == false, "GameState must start with is_game_over == false")
	
	var damage_vignette: ColorRect = hud.get_node("%DamageVignette")
	var game_over_overlay: Control = hud.get_node("%GameOverOverlay")
	var restart_btn: Button = hud.get_node("%RestartButton")
	var health_bar: ProgressBar = hud.get_node("%HealthBar")
	
	assert(damage_vignette != null, "HUD must have DamageVignette")
	assert(game_over_overlay != null, "HUD must have GameOverOverlay")
	assert(restart_btn != null, "HUD must have RestartButton")
	assert(game_over_overlay.visible == false, "GameOverOverlay must initially be hidden")
	
	# Damage feedback trigger on HUD
	gs.call("damage_player", 20.0)
	assert(health_bar.value == 80.0, "HUD HealthBar must reflect 80.0 HP")
	assert(hud._damage_flash_alpha > 0.0, "HUD red damage screen flash alpha must be triggered")
	
	# Fatal Damage -> Trigger Game-Over
	gs.call("damage_player", 100.0)
	assert(gs.get("is_game_over") == true, "GameState is_game_over must become true on lethal damage")
	assert(game_over_overlay.visible == true, "GameOverOverlay must be visible upon game-over")
	
	# Test Restart Button Functionality
	restart_btn.emit_signal("pressed")
	assert(gs.get("is_game_over") == false, "GameState is_game_over must be reset to false")
	assert(game_over_overlay.visible == false, "GameOverOverlay must be hidden after restart")
	assert(gs.get("health") == gs.get("max_health"), "Health must be restored to maximum")
	
	hud.queue_free()
	print("  [PASS] HUD damage feedback (vignette), GameOverOverlay, and Restart verified")
	
	print("--- All BioSphere-X Health & Damage Tests Passed Successfully! ---")
	get_tree().quit(0)
