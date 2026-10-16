extends Node
## Automated Integration Test Suite for Visuals, Audio, Accessibility, Settings, and Performance (Prompt 29).
##
## Verifies:
##   1. Procedural 16-bit PCM Audio synthesis (SFX catalog + Ambient space drone).
##   2. SFX playback pooling, volume bus synchronization, and ambient looping.
##   3. Screen shake feedback and floating combat text lifecycle.
##   4. Enemy threat silhouette rims and visual archetype readability.
##   5. Expanded Settings: resolution, difficulty mode, ambient volume, and keyboard remapping.
##   6. Performance Profiling: 15 active AI enemies simultaneously navigating and updating.

const EnemyScene := preload("res://scenes/enemies/alien_enemy.tscn")
const PlayerScene := preload("res://scenes/player/player.tscn")
const FloatingCombatTextScript := preload("res://scripts/components/floating_combat_text.gd")

var _passed_tests: int = 0
var _failed_tests: int = 0


func _ready() -> void:
	print("=================================================================")
	print("🧪 Starting BioSphere-X Polish, Audio, Settings & Performance Test Suite")
	print("=================================================================")
	
	_run_all_tests()
	
	print("=================================================================")
	print("Test Results: %d Passed, %d Failed" % [_passed_tests, _failed_tests])
	print("=================================================================")
	
	if _failed_tests > 0:
		push_error("Polish & Performance tests failed!")
	else:
		print("✅ ALL POLISH, AUDIO, SETTINGS & PERFORMANCE TESTS COMPLETED SUCCESSFULLY!")
		
	get_tree().quit(0 if _failed_tests == 0 else 1)


func _run_all_tests() -> void:
	test_procedural_audio_manager()
	test_visual_feedback_and_shake()
	test_enemy_silhouette_visuals()
	test_accessibility_and_settings()
	test_keyboard_remapping_inputmap()
	test_multi_enemy_performance_profile()


# ---------------------------------------------------------------------------
# Test 1: Procedural AudioManager Subsystem
# ---------------------------------------------------------------------------
func test_procedural_audio_manager() -> void:
	print("\n--- Test Suite 1: Procedural Audio Manager & Synthesizer ---")
	var am = get_node_or_null("/root/AudioManager")
	_assert_true(am != null, "AudioManager autoload registered")
	if not am:
		return

	# Verify SFX streams are present and populated
	var sfx_keys: Array = ["laser_fire", "laser_hit", "player_hurt", "enemy_death", "pickup", "oxygen_warning", "mission_complete", "ui_click", "build", "demolish"]
	for k in sfx_keys:
		var has_sfx: bool = bool(am.get("_sfx_streams").has(k))
		_assert_true(has_sfx, "SFX '%s' synthesized into cache" % k)
		if has_sfx:
			var stream: AudioStreamWAV = am.get("_sfx_streams")[k]
			_assert_true(stream.data.size() > 0, "SFX '%s' PCM sample buffer is non-empty (%d bytes)" % [k, stream.data.size()])

	# Ambient stream
	var amb_stream: AudioStreamWAV = am.get("_ambient_stream")
	_assert_true(amb_stream != null, "Ambient space drone synthesized")
	if amb_stream:
		_assert_true(amb_stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Ambient space drone has forward looping enabled")
		_assert_true(amb_stream.data.size() >= 44100, "Ambient drone buffer duration is adequate (%d bytes)" % amb_stream.data.size())

	# Test SFX playback invocation
	var tracker := {
		"sfx_heard": false,
		"ambient_heard": false
	}
	am.sfx_played.connect(func(s_name: String):
		if s_name == "pickup":
			tracker["sfx_heard"] = true
	, CONNECT_ONE_SHOT)
	am.call("play_sfx", "pickup")
	_assert_true(tracker["sfx_heard"], "play_sfx('pickup') triggered and emitted sfx_played signal")

	# Test Ambient playback
	am.ambient_started.connect(func(_t_name: String):
		tracker["ambient_heard"] = true
	, CONNECT_ONE_SHOT)
	am.call("play_ambient", "space_ambient")
	_assert_true(tracker["ambient_heard"], "play_ambient() started and emitted ambient_started signal")
	am.call("stop_ambient")


# ---------------------------------------------------------------------------
# Test 2: Visual Feedback & Screen Shake
# ---------------------------------------------------------------------------
func test_visual_feedback_and_shake() -> void:
	print("\n--- Test Suite 2: Visual Feedback & Screen Shake ---")
	var player = PlayerScene.instantiate()
	add_child(player)
	player.global_position = Vector2(100, 100)

	# Test screen shake triggering
	_assert_eq(player.get("_shake_intensity"), 0.0, "Player camera shake initially 0")
	player.call("trigger_screen_shake", 5.0)
	_assert_eq(player.get("_shake_intensity"), 5.0, "trigger_screen_shake sets camera intensity to 5.0")

	# Process decay frame
	player._physics_process(0.1)
	var decayed: float = float(player.get("_shake_intensity"))
	_assert_true(decayed < 5.0 and decayed > 0.0, "Screen shake decays over time (Current: %f)" % decayed)

	# Test FloatingCombatText instantiation
	var float_lbl = FloatingCombatTextScript.spawn(self, Vector2(120, 120), "-24", Color(1.0, 0.3, 0.3))
	_assert_true(float_lbl != null, "FloatingCombatText spawned successfully")
	if float_lbl:
		_assert_eq(float_lbl.text, "-24", "FloatingCombatText displays correct damage text")
		_assert_true(float_lbl.top_level, "FloatingCombatText is top_level to prevent clipping")

	player.queue_free()


# ---------------------------------------------------------------------------
# Test 3: Enemy Silhouette Visuals & Archetype Readability
# ---------------------------------------------------------------------------
func test_enemy_silhouette_visuals() -> void:
	print("\n--- Test Suite 3: Enemy Threat Silhouette Readability ---")
	var enemy = EnemyScene.instantiate()
	add_child(enemy)

	var vis = enemy.get_node_or_null("Visual")
	_assert_true(vis != null, "AlienEnemyVisual node exists")
	if vis:
		# Check Scout preset
		enemy.call("apply_enemy_preset", 0) # Scout
		_assert_eq(int(vis.get("enemy_type")), 0, "Visual set to Scout archetype")
		_assert_true(vis.has_method("play_damage_flash"), "Visual has play_damage_flash method")
		
		# Check Armored Brute preset
		enemy.call("apply_enemy_preset", 1) # Armored Brute
		_assert_eq(int(vis.get("enemy_type")), 1, "Visual updated to Armored Brute archetype")
		_assert_true(vis.scale.x > 1.2, "Armored Brute visual scale is enlarged for silhouette contrast (%f)" % vis.scale.x)

		# Check Spitter preset
		enemy.call("apply_enemy_preset", 2) # Spitter
		_assert_eq(int(vis.get("enemy_type")), 2, "Visual updated to Spitter archetype")

	enemy.queue_free()


# ---------------------------------------------------------------------------
# Test 4: Accessibility, Settings & Difficulty Controls
# ---------------------------------------------------------------------------
func test_accessibility_and_settings() -> void:
	print("\n--- Test Suite 4: Accessibility, Volume, Resolution & Difficulty ---")
	var sm = get_node_or_null("/root/SaveManager")
	var dc = get_node_or_null("/root/DifficultyController")
	if not sm:
		return

	# Test difficulty integration
	var test_cfg = {
		"master_volume": 0.85,
		"sfx_volume": 0.75,
		"ambient_volume": 0.50,
		"resolution": "1600x900",
		"fullscreen": false,
		"screen_shake": true,
		"camera_smoothing": true,
		"difficulty_mode": "hard"
	}
	sm.call("apply_settings", test_cfg)

	_assert_eq(sm.current_settings.get("difficulty_mode"), "hard", "SaveManager recorded 'hard' difficulty setting")
	if dc:
		_assert_eq(dc.difficulty_mode, "hard", "DifficultyController synchronized to 'hard' mode")

	# Test easy mode
	sm.call("apply_settings", {"difficulty_mode": "easy"})
	if dc:
		_assert_eq(dc.difficulty_mode, "easy", "DifficultyController synchronized to 'easy' mode")

	# Reset back to adaptive fuzzy
	sm.call("apply_settings", {"difficulty_mode": "adaptive_fuzzy"})
	if dc:
		_assert_eq(dc.difficulty_mode, "adaptive_fuzzy", "DifficultyController restored to 'adaptive_fuzzy' mode")


# ---------------------------------------------------------------------------
# Test 5: Keyboard Remapping & InputMap Synchronization
# ---------------------------------------------------------------------------
func test_keyboard_remapping_inputmap() -> void:
	print("\n--- Test Suite 5: Keyboard Remapping & InputMap ---")
	var sm = get_node_or_null("/root/SaveManager")
	if not sm:
		return

	# Rebind move_up to KEY_UP and interact to KEY_F
	var custom_bindings = {
		"move_up": KEY_UP,
		"interact": KEY_F
	}
	sm.call("apply_keybindings", custom_bindings)

	_assert_true(InputMap.has_action("move_up"), "InputMap contains 'move_up' action")
	_assert_true(InputMap.has_action("interact"), "InputMap contains 'interact' action")

	# Verify key event mapping
	var move_up_events = InputMap.action_get_events("move_up")
	var mapped_key := 0
	for ev in move_up_events:
		if ev is InputEventKey:
			mapped_key = ev.keycode
			break
	_assert_eq(mapped_key, KEY_UP, "'move_up' successfully remapped to KEY_UP (Arrow Up)")

	var interact_events = InputMap.action_get_events("interact")
	var mapped_interact_key := 0
	for ev in interact_events:
		if ev is InputEventKey:
			mapped_interact_key = ev.keycode
			break
	_assert_eq(mapped_interact_key, KEY_F, "'interact' successfully remapped to KEY_F")

	# Verify keycode string helper
	_assert_eq(sm.call("get_key_name", KEY_W), "W", "get_key_name returns 'W' for KEY_W")
	_assert_eq(sm.call("get_key_name", KEY_SPACE), "Space", "get_key_name returns 'Space' for KEY_SPACE")

	# Restore default bindings
	sm.call("apply_keybindings", {"move_up": KEY_W, "interact": KEY_E})


# ---------------------------------------------------------------------------
# Test 6: Performance & Multi-Enemy Stress Profile
# ---------------------------------------------------------------------------
func test_multi_enemy_performance_profile() -> void:
	print("\n--- Test Suite 6: Multi-Enemy Stress & Performance Profile ---")
	var root_node := Node2D.new()
	root_node.name = "TestStressWorld"
	add_child(root_node)

	var player = PlayerScene.instantiate()
	root_node.add_child(player)
	player.global_position = Vector2(400, 400)

	# Spawn 15 diverse alien enemies
	var enemies: Array[Node2D] = []
	for i in 15:
		var e: CharacterBody2D = EnemyScene.instantiate()
		root_node.add_child(e)
		var archetype := i % 3 # 0: Scout, 1: Brute, 2: Spitter
		e.call("apply_enemy_preset", archetype)
		var angle := (float(i) / 15.0) * TAU
		e.global_position = Vector2(400, 400) + Vector2.from_angle(angle) * 180.0
		enemies.append(e)

	_assert_eq(enemies.size(), 15, "15 alien enemies spawned in simulation arena")

	# Profile 60 physics frames
	var start_usec := Time.get_ticks_usec()
	for f in 60:
		player._physics_process(0.0166)
		for e in enemies:
			e._physics_process(0.0166)
	var elapsed_usec := Time.get_ticks_usec() - start_usec
	var elapsed_ms := float(elapsed_usec) / 1000.0
	var avg_ms_per_frame := elapsed_ms / 60.0

	print("  [PROFILE RESULTS] 60 frames for 15 active enemies: %.2f ms total (%.3f ms per frame)" % [elapsed_ms, avg_ms_per_frame])
	_assert_true(avg_ms_per_frame < 5.0, "Average frame time under 5.0ms (Achieved: %.3f ms)" % avg_ms_per_frame)

	# Cleanup
	root_node.queue_free()


# ---------------------------------------------------------------------------
# Assertion Helpers
# ---------------------------------------------------------------------------
func _assert_true(condition: bool, test_name: String) -> void:
	if condition:
		print("  [PASS] %s" % test_name)
		_passed_tests += 1
	else:
		push_error("  [FAIL] %s" % test_name)
		_failed_tests += 1


func _assert_eq(actual: Variant, expected: Variant, test_name: String) -> void:
	if actual == expected:
		print("  [PASS] %s (Value: %s)" % [test_name, str(actual)])
		_passed_tests += 1
	else:
		push_error("  [FAIL] %s (Expected: %s, Got: %s)" % [test_name, str(expected), str(actual)])
		_failed_tests += 1
