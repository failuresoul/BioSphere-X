extends Node

const ArenaScene = preload("res://scenes/orbit_arena/orbit_arena.tscn")

var arena: Node3D
var failures: int = 0


func _ready() -> void:
	arena = ArenaScene.instantiate()
	add_child(arena)
	await get_tree().process_frame
	arena.start_run()
	_check(arena.phase == "combat", "Expedition starts in combat")
	_check(arena.enemies.size() == 3, "Opening wave contains three enemies")
	for algorithm in arena.PATH_ALGORITHMS:
		_check(arena.arena_path(Vector3(-10, 0, -9), Vector3.ZERO, algorithm).size() > 0, "%s navigates the 3D arena" % algorithm)
	arena._deploy_turret()
	await _wait_frames(100)
	_check(arena.turrets.size() == 1, "CSP support turret can be placed")

	for enemy in arena.enemies.duplicate():
		enemy.take_hit(1000.0)
	await _wait_for_phase("upgrade")
	_check(arena.phase == "upgrade", "Forward chaining advances a cleared wave")
	arena._choose_upgrade(0)
	_check(arena.player_damage == 22.0, "Upgrade increases player damage")
	_check(arena.enemies.size() == 4, "Second wave contains four enemies")
	_check(arena.algorithm_cursor == 7, "First planet deploys all seven pathfinding algorithms")

	for enemy in arena.enemies.duplicate():
		enemy.take_hit(1000.0)
	await _wait_for_phase("upgrade")
	arena._choose_upgrade(1)
	_check(arena.wave_index == 2 and arena.enemies.size() == 1, "Boss wave begins")
	_check(arena.enemies[0].boss_algorithm == "alpha_beta", "First planet boss uses alpha-beta")
	arena.enemies[0].take_hit(1000.0)
	await _wait_for_phase("planet_clear")
	_check(arena.phase == "planet_clear", "First planet can be completed")
	arena._next_planet()
	_check(arena.planet_index == 1 and arena.enemies.size() == 3, "Next planet loads")
	for expected_algorithm in ["minimax", "mcts"]:
		for enemy in arena.enemies.duplicate():
			enemy.take_hit(1000.0)
		await _wait_for_phase("upgrade")
		arena._choose_upgrade(2)
		for enemy in arena.enemies.duplicate():
			enemy.take_hit(1000.0)
		await _wait_for_phase("upgrade")
		arena._choose_upgrade(3)
		_check(arena.enemies[0].boss_algorithm == expected_algorithm, "%s boss decision is selected" % expected_algorithm)
		arena.enemies[0].take_hit(1000.0)
		var target_phase := "victory" if expected_algorithm == "mcts" else "planet_clear"
		await _wait_for_phase(target_phase)
		_check(arena.phase == target_phase, "%s planet resolves" % expected_algorithm)
		if expected_algorithm == "minimax":
			arena._next_planet()
	print("Orbit Arena: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	get_tree().quit(0 if failures == 0 else 1)


func _wait_frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _wait_for_phase(expected: String) -> void:
	for i in 180:
		if arena.phase == expected:
			return
		await get_tree().process_frame


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  [PASS] %s" % label)
	else:
		failures += 1
		push_error("[FAIL] %s" % label)
