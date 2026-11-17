class_name FighterBrain
extends RefCounted
## The AI that controls one fighter (the boss in Player vs AI, both fighters in AI vs AI).
##
##  - MOVES with a search algorithm (DFS, DLS, IDDFS, Bidirectional, Best-First, A*)
##    that finds a path on the arena grid (see modular_pathfinder.gd).
##  - CHOOSES an action with an adversarial algorithm (Minimax or MCTS), computed by
##    the Python backend. Actions: attack, block, dodge, move_closer, move_away, special.
##  - If the backend is offline it uses a tiny fallback rule so the fight never freezes.
##
## The arena that owns the brain must provide: grid (ArenaGrid), energy_of(fighter),
## perform_special(fighter, foe) -> bool, and record_search(brain).

const Pathfinder = preload("res://scripts/utils/modular_pathfinder.gd")
const MELEE_RANGE := 115.0
const BLAST_RANGE := 450.0

var search_algorithm := "astar"
var decision_algorithm := "minimax"
var decide_interval := 0.5            # seconds between decisions
var route_interval := 0.35            # seconds between path searches

var action := "move_closer"           # current action from Minimax / MCTS
var source := "waiting"               # "backend", "offline" or "waiting"
var active := true
var path: Array = []                  # last path (Array of Vector2i tiles)
var path_found := false

# Statistics shown on screen and in the result panel.
var last_nodes := 0
var last_time_ms := 0.0
var searches := 0
var total_nodes := 0
var total_time_ms := 0.0
var damage_dealt := 0.0

var _route_timer := 0.0
var _decide_timer := 0.0
var _waiting := false
# The fighters and arena from the last update(). Stored as weak references so a
# late backend answer never touches a fighter that was already removed.
var _me: WeakRef
var _foe: WeakRef
var _arena: WeakRef


func _init(p_search: String = "astar", p_decision: String = "minimax") -> void:
	search_algorithm = p_search
	decision_algorithm = p_decision


## Called every physics frame by the arena.
func update(delta: float, me: SpaceFighter, foe: SpaceFighter, arena) -> void:
	if not active or me.knocked_out_state or foe.knocked_out_state:
		return
	_route_timer -= delta
	_decide_timer -= delta
	if _decide_timer <= 0.0:
		_decide_timer = decide_interval
		_request_decision(me, foe, arena)
	if _route_timer <= 0.0:
		_route_timer = route_interval
		plan_route(me, foe, arena)
	_execute(me, foe, arena)


# ---------------------------------------------------------------------------
# 1. SEARCH: find a path on the grid
# ---------------------------------------------------------------------------
func plan_route(me: SpaceFighter, foe: SpaceFighter, arena) -> void:
	var grid: ArenaGrid = arena.grid
	var start := grid.to_cell(me.position)
	var goal := grid.to_cell(foe.position)
	if action == "move_away" or action == "dodge":
		# Retreat target: the floor tile at the far side of the arena from the foe.
		var far_x := 1 if foe.position.x > me.position.x else grid.size.x - 2
		goal = grid.to_cell(Vector2(grid.to_world(Vector2i(far_x, 0)).x, me.position.y))
	var result: Dictionary = Pathfinder.search(search_algorithm, start, goal, grid.blocked, grid.size)
	path = result["path"]
	path_found = result["found"]
	last_nodes = result["nodes_expanded"]
	last_time_ms = result["time_ms"]
	searches += 1
	total_nodes += last_nodes
	total_time_ms += last_time_ms
	arena.record_search(self)


func average_nodes() -> float:
	return float(total_nodes) / maxf(1.0, searches)


func average_time_ms() -> float:
	return total_time_ms / maxf(1.0, searches)


# ---------------------------------------------------------------------------
# 2. DECISION: ask Minimax / MCTS for the next action
# ---------------------------------------------------------------------------
func _request_decision(me: SpaceFighter, foe: SpaceFighter, arena) -> void:
	if _waiting:
		return
	var state := {
		"my_hp": me.health / me.max_health * 100.0,
		"enemy_hp": foe.health / foe.max_health * 100.0,
		"distance": absf(foe.position.x - me.position.x),
		"my_energy": arena.energy_of(me),
		"enemy_energy": arena.energy_of(foe),
		"my_cooldown": ceili(me.special_cooldown),
		"enemy_cooldown": ceili(foe.special_cooldown),
	}
	_waiting = true
	_me = weakref(me)
	_foe = weakref(foe)
	_arena = weakref(arena)
	AIClient.request_decision(state, decision_algorithm, _on_decision.bind(state))


func _on_decision(response: Dictionary, state: Dictionary) -> void:
	_waiting = false
	var me = _me.get_ref()
	var foe = _foe.get_ref()
	var arena = _arena.get_ref()
	if not active or me == null or foe == null or arena == null:
		return                               # match already over
	if response.get("success", false):
		source = "backend"
		_set_action(str(response["data"].get("action", "move_closer")), me, foe, arena)
	else:
		source = "offline"
		_set_action(fallback_action(state), me, foe, arena)


## Simple rule used only when the Python backend cannot be reached.
static func fallback_action(state: Dictionary) -> String:
	if state["my_energy"] >= 50.0 and state["my_cooldown"] == 0 and state["distance"] <= 300.0:
		return "special"
	if state["distance"] <= BLAST_RANGE:
		return "attack"
	return "move_closer"


func _set_action(next_action: String, me: SpaceFighter, foe: SpaceFighter, arena) -> void:
	if me.knocked_out_state:
		return
	var changed_direction := (next_action in ["move_away", "dodge"]) != (action in ["move_away", "dodge"])
	action = next_action
	# One-shot actions happen once, right when they are chosen.
	if action == "dodge":
		me.facing = -_toward(me, foe)
		me.desired_direction = me.facing
		me.dash()
	elif action == "special" and not arena.perform_special(me, foe):
		action = "attack"                    # special not possible right now
	if changed_direction:
		plan_route(me, foe, arena)           # new target -> search again at once


# ---------------------------------------------------------------------------
# 3. EXECUTE the current action every frame
# ---------------------------------------------------------------------------
func _execute(me: SpaceFighter, foe: SpaceFighter, arena) -> void:
	var distance := absf(foe.position.x - me.position.x)
	var same_height := absf(foe.position.y - me.position.y) < 80.0
	match action:
		"attack", "special":
			if distance < MELEE_RANGE and same_height:
				me.desired_direction = 0.0
				me.facing = _toward(me, foe)
				me.punch()
			else:
				_follow_path(me, foe, arena)
				if distance < BLAST_RANGE and absf(foe.position.y - me.position.y) < 120.0 and me.facing == _toward(me, foe):
					me.blast()
		"block":
			me.desired_direction = 0.0
			me.facing = _toward(me, foe)
			me.block()
		"move_closer":
			if distance < MELEE_RANGE * 0.6 and same_height:
				me.desired_direction = 0.0
			else:
				_follow_path(me, foe, arena)
		_:  # move_away, dodge
			_follow_path(me, foe, arena)


## Walk/jump toward the next tile of the path.
func _follow_path(me: SpaceFighter, foe: SpaceFighter, arena) -> void:
	if path.size() < 2:
		# No path (search failed or already there): move straight at the target.
		var away := action in ["move_away", "dodge"]
		me.desired_direction = -_toward(me, foe) if away else _toward(me, foe)
		return
	var grid: ArenaGrid = arena.grid
	var here := grid.to_cell(me.position)
	var index := path.find(here)
	var next: Vector2i = path[mini(index + 1, path.size() - 1)] if index >= 0 else path[1]
	var dx := grid.to_world(next).x - me.position.x
	me.desired_direction = signf(dx) if absf(dx) > 10.0 else 0.0
	if next.y < here.y and (me.is_on_floor() or me.velocity.y > 0.0):
		me.jump()                            # next tile is higher: jump (or double jump)


static func _toward(me: SpaceFighter, foe: SpaceFighter) -> int:
	return 1 if foe.position.x >= me.position.x else -1


## Short text for the HUD, e.g. "A* + MINIMAX".
func title() -> String:
	return "%s + %s" % [Pathfinder.NAMES[search_algorithm], decision_algorithm.to_upper()]


func stats_text() -> String:
	var path_text := "%d" % path.size() if path_found else "none"
	var offline := "  (offline)" if source == "offline" else ""
	return "%s%s   nodes %d   path %s   %.2f ms" % [action.to_upper(), offline, last_nodes, path_text, last_time_ms]
