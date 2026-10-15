extends Node
## Automated test suite for BioSphere-X Oxygen and Environmental Survival.
## Validates gradual depletion, configurable rates, pause freezing, low O2 warnings,
## suffocation damage without arbitrary instant death, and Safe Zone/Station refills.

const OxygenStationClass = preload("res://scripts/components/oxygen_station.gd")
const PlayerClass = preload("res://scenes/player/player.gd")

func _ready() -> void:
	print("--- Running BioSphere-X Oxygen & Survival Tests ---")
	_run_tests()


func _run_tests() -> void:
	var gs := get_node("/root/GameState")
	assert(gs != null, "GameState autoload must exist")
	
	# Reset to clean known state
	gs.call("restart_game")
	assert(gs.get("oxygen") == 100.0, "Oxygen must start at 100.0")
	assert(gs.get("max_oxygen") == 100.0, "Max oxygen must start at 100.0")
	assert(gs.get("is_low_oxygen") == false, "Low oxygen flag must start false")
	assert(gs.get("is_oxygen_depleted") == false, "Depleted flag must start false")
	
	# -----------------------------------------------------------------------
	# 1. Configurable Oxygen Consumption Rate
	# -----------------------------------------------------------------------
	gs.set("oxygen_depletion_rate", 20.0) # 20 units per second for fast test step
	gs._process(1.0)
	assert(is_equal_approx(gs.get("oxygen"), 80.0), "Oxygen must deplete according to configurable rate (80.0)")
	
	gs.set("oxygen_depletion_rate", 10.0)
	gs._process(2.0)
	assert(is_equal_approx(gs.get("oxygen"), 60.0), "Oxygen depletion must adjust with updated rate (60.0)")
	print("  [PASS] Configurable oxygen consumption rate verified")
	
	# -----------------------------------------------------------------------
	# 2. Pause Freezing Verification (No depletion during pause)
	# -----------------------------------------------------------------------
	gs.call("set_paused", true)
	var o2_before_pause: float = gs.get("oxygen")
	gs._process(5.0) # Simulate 5 seconds passing while paused
	assert(is_equal_approx(gs.get("oxygen"), o2_before_pause), "Oxygen must strictly not deplete while game is paused")
	gs.call("set_paused", false)
	print("  [PASS] Pause freeze for oxygen timer verified")
	
	# -----------------------------------------------------------------------
	# 3. Low Oxygen Warning Signals & Threshold Trigger
	# -----------------------------------------------------------------------
	var warning_received: Dictionary = {"called": false, "state": false}
	gs.connect("oxygen_low_warning", func(is_low: bool):
		warning_received["called"] = true
		warning_received["state"] = is_low
	)
	
	# Drain oxygen down to 20% (below 25% threshold)
	gs.call("set_oxygen", 20.0)
	assert(gs.get("is_low_oxygen") == true, "is_low_oxygen flag must become true below 25%")
	assert(warning_received["called"] == true and warning_received["state"] == true, "oxygen_low_warning signal must emit true")
	print("  [PASS] Low oxygen warning threshold and signal verified")
	
	# -----------------------------------------------------------------------
	# 4. Gradual Suffocation Damage (Avoid Arbitrary Instant Death)
	# -----------------------------------------------------------------------
	gs.call("set_health", 100.0, 100.0)
	gs.call("set_oxygen", 0.0)
	assert(gs.get("is_oxygen_depleted") == true, "is_oxygen_depleted flag must be true at 0 O2")
	
	gs.set("suffocation_damage_rate", 10.0) # 10 HP damage per second
	gs._process(1.0)
	assert(is_equal_approx(gs.get("health"), 90.0), "Health must decrease gradually (90.0), not instant kill")
	assert(gs.get("is_game_over") == false, "Player must remain alive while health is remaining")
	
	gs._process(2.0)
	assert(is_equal_approx(gs.get("health"), 70.0), "Continuous suffocation damage applied correctly over time")
	print("  [PASS] Gradual suffocation damage over time verified (no arbitrary instant death)")
	
	# -----------------------------------------------------------------------
	# 5. Oxygen Station & Safe Zone Atmospheric Refill
	# -----------------------------------------------------------------------
	var station = OxygenStationClass.new()
	station.name = "TestStation"
	station.radius = 64.0
	station.refill_rate = 40.0
	station.instant_interact_refill = true
	add_child(station)
	
	var test_player := CharacterBody2D.new()
	test_player.add_to_group("player")
	add_child(test_player)
	
	var entered_called: Dictionary = {"value": false}
	station.player_entered_station.connect(func(_st):
		entered_called["value"] = true
	)
	
	# Simulate entering station perimeter
	station._on_body_entered(test_player)
	assert(entered_called["value"] == true, "player_entered_station must be emitted")
	assert(gs.get("is_oxygen_refilling") == true, "GameState is_oxygen_refilling must be true inside station")
	
	# Process refill over 1 second
	var o2_start: float = gs.get("oxygen")
	gs._process(1.0)
	assert(gs.get("oxygen") > o2_start, "Oxygen must replenish inside station")
	assert(is_equal_approx(gs.get("oxygen"), o2_start + 40.0), "Oxygen replenished at station refill_rate")
	
	# Instant interaction test (press E / interact)
	var interact_success: bool = station.interact(test_player)
	assert(interact_success == true, "Instant refill interact must succeed")
	assert(is_equal_approx(gs.get("oxygen"), 100.0), "Oxygen must be fully restored to 100.0")
	assert(gs.get("is_low_oxygen") == false, "Low oxygen flag must clear after full recharge")
	assert(gs.get("is_oxygen_depleted") == false, "Depleted flag must clear after recharge")
	
	# Simulate exiting station perimeter
	var exited_called: Dictionary = {"value": false}
	station.player_exited_station.connect(func(_st):
		exited_called["value"] = true
	)
	station._on_body_exited(test_player)
	assert(exited_called["value"] == true, "player_exited_station must be emitted")
	assert(gs.get("is_oxygen_refilling") == false, "GameState is_oxygen_refilling must be false after exit")
	
	station.queue_free()
	test_player.queue_free()
	print("  [PASS] Oxygen station and safe zone refill verified (Passive & Instant)")
	
	# -----------------------------------------------------------------------
	# 6. HUD Oxygen Integration (Progress, Alert, Recharging Badge)
	# -----------------------------------------------------------------------
	var hud_scene: PackedScene = load("res://ui/screens/hud.tscn")
	assert(hud_scene != null, "HUD scene must exist")
	var hud: CanvasLayer = hud_scene.instantiate()
	add_child(hud)
	
	var oxygen_bar: ProgressBar = hud.get_node("%OxygenBar")
	var oxygen_label: Label = hud.get_node("%OxygenLabel")
	var status_label: Label = hud.get_node("%OxygenStatusLabel")
	assert(oxygen_bar != null, "OxygenBar must exist in HUD")
	assert(oxygen_label != null, "OxygenLabel must exist in HUD")
	assert(status_label != null, "OxygenStatusLabel must exist in HUD")
	
	# Normal Level
	gs.call("set_oxygen", 80.0)
	assert(oxygen_bar.value == 80.0, "OxygenBar reflects 80.0")
	assert("80%" in oxygen_label.text, "OxygenLabel displays 80%")
	
	# Recharging State
	gs.call("set_oxygen_refilling", true)
	hud._process(0.016)
	assert(status_label.visible == true, "OxygenStatusLabel visible when recharging")
	assert("RECHARGING" in status_label.text, "Status badge indicates recharging")
	gs.call("set_oxygen_refilling", false)
	
	# Low Oxygen State
	gs.call("set_oxygen", 15.0)
	hud._process(0.016)
	assert(status_label.visible == true, "OxygenStatusLabel visible when oxygen is critical")
	assert("CRITICAL" in status_label.text, "Status badge indicates critical warning")
	
	hud.queue_free()
	print("  [PASS] HUD oxygen status and warning display verified")
	
	# -----------------------------------------------------------------------
	# 7. Complete Suffocation Game Over
	# -----------------------------------------------------------------------
	gs.call("set_health", 5.0, 100.0)
	gs.call("set_oxygen", 0.0)
	gs.set("suffocation_damage_rate", 20.0)
	gs._process(0.5) # Lethal suffocation step
	assert(gs.get("health") == 0.0, "Health must drop to 0.0")
	assert(gs.get("is_game_over") == true, "Game Over triggered when suffocation depletes health to zero")
	print("  [PASS] Lethal suffocation game-over state transition verified")
	
	print("--- All BioSphere-X Oxygen & Survival Tests Passed Successfully! ---")
	get_tree().quit(0)
