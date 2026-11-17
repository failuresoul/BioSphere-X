extends "res://scenes/star_brawl/fighter_brain.gd"
## One AI fighter in AI vs AI mode.
##
## It IS the Player vs AI boss brain (fighter_brain.gd): the same 4-step loop
## LOOK -> THINK (Minimax+alpha-beta / Minimax / MCTS every 0.5 s) -> ADJUST
## (fuzzy aggression) -> ATTACK AND REST (1.5 s rest after a special).
## On top of that it adds:
##   - SEARCH ROTATION: switches path-finding algorithm every 10 s
##       BFS -> DFS -> DLS -> IDDFS -> Bidirectional -> Greedy -> A*
##   - FORWARD CHAINING every 1 s:  IF my_hp < 30  THEN defensive_mode
##                                  IF enemy_hp < 20 THEN finisher_mode
##   - PICKUPS: when its HP is low it paths to a pickup (placed by the CSP)
##   - FSM MODE shown above its head: CHASE / ATTACK / DEFEND / PICKUP
##
## Its "arena" is ai_vs_ai_match.gd, which provides grid, energy_of(),
## perform_special(), record_search(), recent_damage_taken(), pickups() and log_event().

enum Mode { CHASE, ATTACK, DEFEND, PICKUP }
const MODE_NAMES := ["CHASE", "ATTACK", "DEFEND", "PICKUP"]
const ROTATE_TIME := 10.0         # seconds per search algorithm
const RULE_TIME := 1.0            # forward chaining once per second
const LOW_HP := 40.0              # below this HP % the fighter goes for a pickup

var side := "blue"                # "blue" or "red"
var rotate := true                # true = "Rotate all 7"
var rotation_index := 0
var defensive_mode := false
var finisher_mode := false
var mode: Mode = Mode.CHASE
var pickup_target: Node2D = null  # the pickup this fighter is walking to
var head_label: Label             # "BFS | CHASE" above the fighter

# Statistics for the result panel.
var decisions := 0
var decision_ms := 0.0
var nodes_evaluated := 0
var nodes_pruned := 0
var fuzzy_updates := 0
var mode_counts := {"CHASE": 0, "ATTACK": 0, "DEFEND": 0, "PICKUP": 0}

var _rotate_timer := ROTATE_TIME
var _rule_timer := 0.0


## search_choice = "rotate" or one fixed algorithm key; start_index = first algorithm when rotating.
func setup(p_side: String, decision: String, search_choice: String, start_index: int) -> void:
	side = p_side
	decision_algorithm = decision
	rotate = search_choice == "rotate"
	rotation_index = start_index
	_set_search(Pathfinder.ORDER[start_index % Pathfinder.ORDER.size()] if rotate else search_choice)
	mode_counts["CHASE"] = 1


func update(delta: float, me: SpaceFighter, foe: SpaceFighter, arena) -> void:
	if not active or me.knocked_out_state or foe.knocked_out_state:
		return
	_rotate_search(delta, arena)
	_check_rules(delta, me, foe, arena)
	_choose_pickup(me, arena)
	super.update(delta, me, foe, arena)          # the boss loop
	_update_mode(me, foe)
	if is_instance_valid(head_label):
		head_label.text = "%s | %s" % [Pathfinder.NAMES[search_algorithm], MODE_NAMES[mode]]


# ---------------------------------------------------------------------------
# Search rotation (every 10 s)
# ---------------------------------------------------------------------------
func _rotate_search(delta: float, arena) -> void:
	if not rotate:
		return
	_rotate_timer -= delta
	if _rotate_timer <= 0.0:
		_rotate_timer = ROTATE_TIME
		rotation_index += 1
		_set_search(Pathfinder.ORDER[rotation_index % Pathfinder.ORDER.size()])
		arena.log_event("%s search -> %s" % [side.to_upper(), Pathfinder.NAMES[search_algorithm]])


func _set_search(algorithm: String) -> void:
	search_algorithm = algorithm
	planner.algorithm = algorithm


# ---------------------------------------------------------------------------
# Forward chaining (every 1 s): defensive_mode / finisher_mode
# ---------------------------------------------------------------------------
func _check_rules(delta: float, me: SpaceFighter, foe: SpaceFighter, arena) -> void:
	_rule_timer -= delta
	if _rule_timer > 0.0:
		return
	_rule_timer = RULE_TIME
	var facts := {"my_hp": me.health / me.max_health * 100.0, "enemy_hp": foe.health / foe.max_health * 100.0}
	AIClient.request_rules(facts, _on_rules.bind(facts))


func _on_rules(response: Dictionary, facts: Dictionary) -> void:
	var arena = _arena.get_ref() if _arena else null
	if not active or arena == null:
		return
	var new_facts: Dictionary = {}
	var fired: Array = []
	if response.get("success", false):
		new_facts = response["data"].get("new_facts", {})
		fired = response["data"].get("fired_rules", [])
	else:                                        # fallback: the same two rules, checked here
		if float(facts["my_hp"]) < 30.0:
			new_facts["defensive_mode"] = true
			fired.append("defensive")
		if float(facts["enemy_hp"]) < 20.0:
			new_facts["finisher_mode"] = true
			fired.append("finisher")
	arena.record_rules(fired)
	var was_defensive := defensive_mode
	var was_finisher := finisher_mode
	defensive_mode = bool(new_facts.get("defensive_mode", false))
	finisher_mode = bool(new_facts.get("finisher_mode", false))
	if defensive_mode and not was_defensive:
		arena.log_event("%s: my_hp < 30 -> defensive_mode" % side.to_upper())
	if finisher_mode and not was_finisher:
		arena.log_event("%s: enemy_hp < 20 -> finisher_mode" % side.to_upper())


## The rule modes change the move chosen by Minimax / MCTS:
##   finisher_mode : cautious moves become "attack"
##   defensive_mode: walking in becomes "move_away"
func _apply_preferences(next_action: String) -> String:
	if finisher_mode and next_action in ["block", "dodge", "move_away"]:
		return "attack"
	if defensive_mode and next_action == "move_closer":
		return "move_away"
	return next_action


# ---------------------------------------------------------------------------
# Pickups: walk to one when HP is low
# ---------------------------------------------------------------------------
func _choose_pickup(me: SpaceFighter, arena) -> void:
	if is_instance_valid(pickup_target) and me.health / me.max_health * 100.0 < LOW_HP + 20.0:
		return                                   # keep going to the current one
	pickup_target = null
	if me.health / me.max_health * 100.0 >= LOW_HP:
		return
	var best_distance := INF
	for pickup in arena.pickups():
		var distance: float = me.position.distance_to(pickup.position)
		if distance < best_distance:
			best_distance = distance
			pickup_target = pickup


func plan_route(me: SpaceFighter, foe: SpaceFighter, arena) -> void:
	if is_instance_valid(pickup_target):
		var grid = arena.grid
		planner.request(grid, grid.to_cell(me.position), grid.to_cell(pickup_target.position), _on_path_ready)
	else:
		super.plan_route(me, foe, arena)


func _execute(me: SpaceFighter, foe: SpaceFighter, arena) -> void:
	if not is_instance_valid(pickup_target):
		super._execute(me, foe, arena)
		return
	# PICKUP: follow the path to the pickup.
	if not PlannerScript.follow(me, planner.path, arena.grid):
		me.desired_direction = signf(pickup_target.position.x - me.position.x)


# ---------------------------------------------------------------------------
# FSM mode (shown above the head)
# ---------------------------------------------------------------------------
func _update_mode(me: SpaceFighter, foe: SpaceFighter) -> void:
	var next: Mode = Mode.CHASE
	if is_instance_valid(pickup_target):
		next = Mode.PICKUP
	elif rest_timer > 0.0 or action in ["block", "dodge", "move_away"]:
		next = Mode.DEFEND
	elif action in ["attack", "special"] and absf(foe.position.x - me.position.x) < 220.0:
		next = Mode.ATTACK
	if next != mode:
		mode = next
		mode_counts[MODE_NAMES[mode]] += 1


# ---------------------------------------------------------------------------
# Statistics
# ---------------------------------------------------------------------------
func _on_decision(response: Dictionary, state: Dictionary) -> void:
	super._on_decision(response, state)
	if response.get("success", false):
		var data: Dictionary = response["data"]
		decisions += 1
		decision_ms += float(data.get("time_ms", 0.0))
		nodes_evaluated += int(data.get("nodes_evaluated", 0))
		nodes_pruned += int(data.get("nodes_pruned", 0))


func _on_fuzzy(response: Dictionary) -> void:
	super._on_fuzzy(response)
	if response.get("success", false):
		fuzzy_updates += 1


func panel_text(me: SpaceFighter) -> String:
	var search := "%s | Nodes %d | Path %d | %.1f ms" % [Pathfinder.NAMES[planner.used] + (" (local)" if planner.source == "local" else ""), planner.nodes, planner.path.size(), planner.time_ms]
	var modes := ""
	if defensive_mode:
		modes += "  DEFENSIVE"
	if finisher_mode:
		modes += "  FINISHER"
	return "HP %d / %d\nSearch: %s\nDecision: %s\nAggression %.2f   Mode: %s%s" % [
		ceili(me.health), ceili(me.max_health), search, decision_text(), aggression, MODE_NAMES[mode], modes]
