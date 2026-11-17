class_name FighterBrain
extends RefCounted
## The AI that controls one fighter: the boss in Player vs AI, and both
## fighters in AI vs AI. Every frame it runs the BOSS LOOP:
##
##   1) LOOK    read the distance, both health bars, energy and cooldowns
##   2) THINK   ask Minimax (+ alpha-beta) or MCTS on the Python server for the
##              best move. Async: the game never waits for the answer.
##   3) ADJUST  fuzzy logic sets the aggression (0-1); the boss's speed and attack
##              rate follow it SLOWLY (smooth, never sudden)
##   4) ATTACK AND REST  do the move; after a big attack (special) rest 1.5 s
##              so the player can hit back
##
## If the server is slow or offline: fallback rule (attack if near, else move closer).
## Movement uses a path from path_planner.gd (the boss always uses A*).
## Actions: attack, block, dodge, move_closer, move_away, special.
##
## The arena that owns the brain must provide: grid, energy_of(fighter),
## perform_special(fighter, foe) -> bool, record_search(planner) and
## recent_damage_taken() (only when use_fuzzy is on).

const Pathfinder = preload("res://scripts/utils/modular_pathfinder.gd")
const PlannerScript = preload("res://scripts/utils/path_planner.gd")

## Decision algorithms: key -> name on screen.
const DECISION_NAMES := {"minimax_ab": "Minimax+αβ", "minimax": "Minimax", "mcts": "MCTS"}
const MELEE_RANGE := 75.0           # a punch only reaches about 82 px (see star_brawl._on_strike)
const BLAST_RANGE := 450.0          # a shot can hit up to here
const NEAR := 300.0                 # fallback rule: "near" means closer than this
const REACH_HEIGHT := 50.0          # a punch only lands if the height difference is below this
const REST_TIME := 1.5              # rest after a big attack
const SERVER_TIMEOUT := 0.8         # seconds to wait for Minimax / MCTS
const FUZZY_INTERVAL := 2.0         # ask the fuzzy controller every 2 s
const AGGRESSION_CHANGE := 0.1      # aggression moves at most 0.1 per second (smooth)

var search_algorithm := "astar"
var decision_algorithm := "minimax_ab"   # "minimax_ab", "minimax" or "mcts"
var decide_interval := 0.5            # seconds between decisions
var route_interval := 0.35            # seconds between path searches

var action := "move_closer"           # current move
var source := "waiting"               # "server", "fallback" or "waiting"
var last_decision: Dictionary = {}    # last answer from the server (nodes, pruned, win_rate...)
var rest_timer := 0.0                 # > 0 while resting after a big attack
var active := true
var planner                           # path_planner.gd: current path + search statistics
var damage_dealt := 0.0

# Step 3 ADJUST (fuzzy difficulty). Only the Player vs AI boss uses it.
var use_fuzzy := false
var aggression := 0.5                 # current value, shown on the HUD
var aggression_target := 0.5          # latest answer from the fuzzy controller
var base_speed := 0.0                 # boss speed / attack interval at aggression 0.5
var base_attack_interval := 0.0
var _fuzzy_timer := 0.0

var _route_timer := 0.0
var _decide_timer := 0.0
var _waiting := false
# The fighters and arena from the last update(), as weak references so a late
# server answer never touches a fighter that was already removed.
var _me: WeakRef
var _foe: WeakRef
var _arena: WeakRef


func _init(p_search: String = "astar", p_decision: String = "minimax_ab") -> void:
	search_algorithm = p_search
	decision_algorithm = p_decision
	planner = PlannerScript.new(p_search)


## The boss loop. Called every physics frame by the arena.
func update(delta: float, me: SpaceFighter, foe: SpaceFighter, arena) -> void:
	if not active or me.knocked_out_state or foe.knocked_out_state:
		return
	_me = weakref(me)
	_foe = weakref(foe)
	_arena = weakref(arena)

	_adjust(delta, me, foe, arena)               # Step 3: ADJUST (fuzzy difficulty), also while resting

	# Step 4b: REST after a big attack: stand still, no new decisions.
	if rest_timer > 0.0:
		rest_timer -= delta
		me.desired_direction = 0.0
		return

	_decide_timer -= delta
	if _decide_timer <= 0.0:
		_decide_timer = decide_interval
		var state := look(me, foe, arena)        # Step 1: LOOK
		_think(state)                            # Step 2: THINK (async, answer arrives later)

	_route_timer -= delta
	if _route_timer <= 0.0:
		_route_timer = route_interval
		plan_route(me, foe, arena)
	_execute(me, foe, arena)                     # Step 4: ATTACK (do the current move)


# ---------------------------------------------------------------------------
# Step 1: LOOK
# ---------------------------------------------------------------------------
## Reads the situation. Health is in percent so big and small fighters compare fairly.
func look(me: SpaceFighter, foe: SpaceFighter, arena) -> Dictionary:
	return {
		"boss_hp": me.health / me.max_health * 100.0,
		"player_hp": foe.health / foe.max_health * 100.0,
		"distance": absf(foe.position.x - me.position.x),
		"boss_energy": arena.energy_of(me),
		"player_energy": arena.energy_of(foe),
		"boss_cooldown": ceili(me.special_cooldown),
		"player_cooldown": ceili(foe.special_cooldown),
	}


# ---------------------------------------------------------------------------
# Step 2: THINK
# ---------------------------------------------------------------------------
func _think(state: Dictionary) -> void:
	if _waiting:
		return                                   # previous question not answered yet
	_waiting = true
	var algorithm := "mcts" if decision_algorithm == "mcts" else "minimax"
	var use_alpha_beta := decision_algorithm == "minimax_ab"
	AIClient.request_decision(state, algorithm, use_alpha_beta, SERVER_TIMEOUT, _on_decision.bind(state))


func _on_decision(response: Dictionary, state: Dictionary) -> void:
	_waiting = false
	var me = _me.get_ref()
	var foe = _foe.get_ref()
	var arena = _arena.get_ref()
	if not active or me == null or foe == null or arena == null:
		return                                   # fight already over
	var next_action: String
	if response.get("success", false):
		source = "server"
		last_decision = response["data"]
		next_action = str(last_decision.get("action", "move_closer"))
	else:
		source = "fallback"                      # server slow or offline
		last_decision = {}
		next_action = fallback_action(state)
	_set_action(next_action, me, foe, arena)


## Used when the server does not answer in time: attack if near, else move closer.
static func fallback_action(state: Dictionary) -> String:
	return "attack" if state["distance"] <= NEAR else "move_closer"


# ---------------------------------------------------------------------------
# Step 3: ADJUST (fuzzy difficulty)
# ---------------------------------------------------------------------------
## Every 2 s ask the fuzzy controller for a target aggression. Every frame move
## the real aggression a little toward it, then set speed and attack rate:
##   aggression 0 -> 80% speed, attacks 30% slower
##   aggression 1 -> 120% speed, attacks 30% faster
## If the server is off, the last target is kept.
func _adjust(delta: float, me: SpaceFighter, foe: SpaceFighter, arena) -> void:
	if not use_fuzzy:
		return
	_fuzzy_timer -= delta
	if _fuzzy_timer <= 0.0:
		_fuzzy_timer = FUZZY_INTERVAL
		var health := foe.health / foe.max_health * 100.0
		AIClient.request_fuzzy(health, arena.recent_damage_taken(), absf(foe.position.x - me.position.x), _on_fuzzy)
	aggression = move_toward(aggression, aggression_target, AGGRESSION_CHANGE * delta)
	me.move_speed = base_speed * (0.8 + 0.4 * aggression)
	me.attack_interval = base_attack_interval * (1.3 - 0.6 * aggression)


func _on_fuzzy(response: Dictionary) -> void:
	if response.get("success", false):
		aggression_target = clampf(float(response["data"].get("aggression", 0.5)), 0.0, 1.0)


# ---------------------------------------------------------------------------
# Step 4: ATTACK AND REST
# ---------------------------------------------------------------------------
func _set_action(next_action: String, me: SpaceFighter, foe: SpaceFighter, arena) -> void:
	if me.knocked_out_state:
		return
	var was_retreating := action in ["move_away", "dodge"]
	action = next_action
	# One-shot moves happen once, right when they are chosen.
	if action == "dodge":
		me.facing = -_toward(me, foe)
		me.desired_direction = me.facing
		me.dash()
	elif action == "special":
		if arena.perform_special(me, foe):
			rest_timer = REST_TIME               # big attack -> rest so the player can hit back
		else:
			action = "attack"                    # special not possible right now
	if was_retreating != (action in ["move_away", "dodge"]):
		plan_route(me, foe, arena)               # new target -> ask for a new path at once


## Does the current move every frame.
func _execute(me: SpaceFighter, foe: SpaceFighter, arena) -> void:
	var distance := absf(foe.position.x - me.position.x)
	var same_height := absf(foe.position.y - me.position.y) < REACH_HEIGHT
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


# ---------------------------------------------------------------------------
# Movement: path from the planner (async, keeps the last path meanwhile)
# ---------------------------------------------------------------------------
func plan_route(me: SpaceFighter, foe: SpaceFighter, arena) -> void:
	var grid = arena.grid
	var start: Vector2i = grid.to_cell(me.position)
	var goal: Vector2i = grid.to_cell(foe.position)
	if action == "move_away" or action == "dodge":
		# Retreat target: the floor tile at the far side of the arena from the foe.
		var far_x: int = 1 if foe.position.x > me.position.x else grid.size.x - 2
		goal = grid.to_cell(Vector2(grid.to_world(Vector2i(far_x, 0)).x, me.position.y))
	planner.request(grid, start, goal, _on_path_ready)


func _on_path_ready() -> void:
	var arena = _arena.get_ref() if _arena else null
	if active and arena != null:
		arena.record_search(planner)


func _follow_path(me: SpaceFighter, foe: SpaceFighter, arena) -> void:
	if not PlannerScript.follow(me, planner.path, arena.grid):
		# No path yet (or the search failed): move straight at / away from the target.
		var away := action in ["move_away", "dodge"]
		me.desired_direction = -_toward(me, foe) if away else _toward(me, foe)


static func _toward(me: SpaceFighter, foe: SpaceFighter) -> int:
	return 1 if foe.position.x >= me.position.x else -1


# ---------------------------------------------------------------------------
# Statistics and HUD text
# ---------------------------------------------------------------------------
func average_nodes() -> float:
	return float(planner.total_nodes) / maxf(1.0, planner.searches)


func average_time_ms() -> float:
	return planner.total_time_ms / maxf(1.0, planner.searches)


## e.g. "A* + Minimax+αβ"
func title() -> String:
	return "%s + %s" % [Pathfinder.NAMES[search_algorithm], DECISION_NAMES[decision_algorithm]]


## e.g. "Minimax+αβ → attack | nodes 120, pruned 64"
func decision_text() -> String:
	var shown: String = DECISION_NAMES[decision_algorithm]
	if rest_timer > 0.0:
		return "%s → rest (%.1f s)" % [shown, rest_timer]
	if source == "fallback":
		return "%s → %s | fallback (server slow)" % [shown, action]
	if last_decision.is_empty():
		return "%s → %s" % [shown, action]
	if decision_algorithm == "mcts":
		return "%s → %s | win rate %.2f, %d sims" % [shown, action, float(last_decision.get("win_rate", 0)), int(last_decision.get("simulations", 0))]
	return "%s → %s | nodes %d, pruned %d" % [shown, action, int(last_decision.get("nodes_evaluated", 0)), int(last_decision.get("nodes_pruned", 0))]


## Two HUD lines: the decision, then the path search.
func stats_text() -> String:
	return "%s\n%s" % [decision_text(), planner.hud_text()]
