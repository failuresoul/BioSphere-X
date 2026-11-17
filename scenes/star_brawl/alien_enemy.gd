extends SpaceFighter
## AGENT 1: Alien patrol, controlled by a Finite State Machine (FSM).
##
##   IDLE   --(waited IDLE_TIME)-->      PATROL
##   PATROL --(sees the player)-->       CHASE
##   CHASE  --(close enough)-->          ATTACK
##   ATTACK --(player moved away)-->     CHASE
##   CHASE  --(loses sight of player)--> SEARCH
##   SEARCH --(sees the player)-->       CHASE
##   SEARCH --(gives up after a while)-> PATROL
##   any    --(health = 0)-->            DEAD
##
## The alien only sees the player IN FRONT of it and NOT through walls or
## platforms (a raycast). In CHASE it follows an A* path to the player.

const PlannerScript = preload("res://scripts/utils/path_planner.gd")

enum State { IDLE, PATROL, CHASE, ATTACK, SEARCH, DEAD }
const STATE_NAMES := ["IDLE", "PATROL", "CHASE", "ATTACK", "SEARCH", "DEAD"]
const STATE_COLORS := [Color("c8d3e6"), Color("8df7be"), Color("ffd36b"), Color("ff6f7d"), Color("b9a2ff"), Color("777777")]

const IDLE_TIME := 1.5        # seconds standing still before patrolling
const PATROL_RANGE := 160.0   # walks this far left/right of its home
const SIGHT_RANGE := 520.0    # how far it can see
const ATTACK_RANGE := 75.0    # close enough to hit
const SEARCH_TIME := 3.0      # gives up searching after this
const REPLAN_TIME := 0.5      # asks for a new A* path this often while chasing

var species := 0
var hover_clock := 0.0
var redraw_timer := 0.0

var state: State = State.IDLE
var state_time := 0.0         # seconds spent in the current state
var home_x := 0.0
var patrol_direction := 1
var last_seen := Vector2.ZERO # where the player was last seen
var replan_timer := 0.0
var planner = PlannerScript.new("astar")   # CHASE uses A*
var state_label: Label


func _ready() -> void:
	super._ready()
	sprite.visible = false
	scale = Vector2.ONE * 0.72
	move_speed = 150.0 + species * 18.0
	punch_damage = 6.0 + species
	home_x = position.x
	state_label = Label.new()
	state_label.position = Vector2(-50, -100)
	state_label.size = Vector2(100, 20)
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_label.add_theme_font_size_override("font_size", 15)
	add_child(state_label)
	_change_state(State.IDLE)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	hover_clock += delta
	redraw_timer -= delta
	if redraw_timer <= 0.0:
		redraw_timer = 0.10
		queue_redraw()


func _change_state(next: State) -> void:
	state = next
	state_time = 0.0
	state_label.text = STATE_NAMES[next]
	state_label.add_theme_color_override("font_color", STATE_COLORS[next])


## The FSM. Called every physics frame by the level (star_brawl.gd).
func think(delta: float, player: SpaceFighter, grid) -> void:
	state_time += delta
	if health <= 0.0 or knocked_out_state:
		if state != State.DEAD:
			_change_state(State.DEAD)
		desired_direction = 0.0
		return
	var sees := can_see(player)
	var distance := position.distance_to(player.position)
	# Close enough to hit: near horizontally AND at about the same height.
	var in_reach := absf(player.position.x - position.x) < ATTACK_RANGE and absf(player.position.y - position.y) < 50.0
	match state:
		State.IDLE:
			desired_direction = 0.0
			if sees:
				_change_state(State.CHASE)
			elif state_time > IDLE_TIME:
				_change_state(State.PATROL)
		State.PATROL:
			# Walk back and forth around the home position.
			if position.x > home_x + PATROL_RANGE:
				patrol_direction = -1
			elif position.x < home_x - PATROL_RANGE:
				patrol_direction = 1
			desired_direction = patrol_direction * 0.6
			if sees:
				_change_state(State.CHASE)
		State.CHASE:
			last_seen = player.position
			replan_timer -= delta
			if replan_timer <= 0.0:
				replan_timer = REPLAN_TIME
				planner.request(grid, grid.to_cell(position), grid.to_cell(player.position), _on_path_ready)
			if not PlannerScript.follow(self, planner.path, grid):
				desired_direction = signf(player.position.x - position.x)   # no path yet: walk straight
			if in_reach:
				_change_state(State.ATTACK)
			elif not sees:
				_change_state(State.SEARCH)
		State.ATTACK:
			desired_direction = 0.0
			facing = 1 if player.position.x > position.x else -1
			if attack_cooldown <= 0.0:
				punch()
				attack_cooldown = 1.35
			if not in_reach and distance > ATTACK_RANGE * 1.2:
				_change_state(State.CHASE if sees else State.SEARCH)
		State.SEARCH:
			# Go to the place where the player was last seen.
			var dx := last_seen.x - position.x
			desired_direction = signf(dx) * 0.7 if absf(dx) > 20.0 else 0.0
			if sees:
				_change_state(State.CHASE)
			elif state_time > SEARCH_TIME:
				home_x = position.x
				_change_state(State.PATROL)


## True if the player is in front of the alien, in range, and no wall or
## platform is between them (raycast against the level layer).
func can_see(player: SpaceFighter) -> bool:
	if not is_instance_valid(player) or player.knocked_out_state:
		return false
	var to_player := player.position - position
	var in_front := signf(to_player.x) == facing or absf(to_player.x) < 20.0
	if not in_front or to_player.length() > SIGHT_RANGE or absf(to_player.y) > 220.0:
		return false
	var eye := position + Vector2(0, -20)
	var ray := PhysicsRayQueryParameters2D.create(eye, player.position + Vector2(0, -20), 1)   # layer 1 = walls/platforms
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()


## any --(health = 0)--> DEAD
func take_damage(amount: float, push_direction: int) -> void:
	super.take_damage(amount, push_direction)
	if knocked_out_state and state != State.DEAD:
		_change_state(State.DEAD)


func _on_path_ready() -> void:
	if is_instance_valid(arena) and arena.has_method("record_search"):
		arena.record_search(planner)


func _update_pose() -> void:
	pass


func _draw() -> void:
	var bob := sin(hover_clock * 5.0) * 3.0
	var body := Color("bb6dff") if species == 0 else (Color("ff9b65") if species == 1 else Color("9be884"))
	var dark := body.darkened(0.48)
	var eye := Color("8af8ff") if species != 1 else Color("fff2a1")
	draw_circle(Vector2(0, 33), 36, Color(0.02, 0.03, 0.10, 0.35))
	if species == 0:
		# Four-legged crawler with antennae.
		for side in [-1, 1]:
			draw_line(Vector2(side * 20, 6 + bob), Vector2(side * 37, 28), dark, 9)
			draw_line(Vector2(side * 8, 16 + bob), Vector2(side * 24, 34), dark, 8)
			draw_line(Vector2(side * 15, -24 + bob), Vector2(side * 27, -44 + bob), body, 5)
			draw_circle(Vector2(side * 27, -44 + bob), 5, eye)
		draw_circle(Vector2(0, -4 + bob), 34, dark)
		draw_circle(Vector2(0, -10 + bob), 29, body)
		draw_circle(Vector2(-11, -14 + bob), 7, eye)
		draw_circle(Vector2(11, -14 + bob), 7, eye)
		draw_circle(Vector2(-10, -13 + bob), 3, Color("123555"))
		draw_circle(Vector2(12, -13 + bob), 3, Color("123555"))
	elif species == 1:
		# Floating crystalline sentinel.
		var shell := PackedVector2Array([Vector2(0, -50 + bob), Vector2(32, -18 + bob), Vector2(27, 18 + bob), Vector2(0, 31 + bob), Vector2(-27, 18 + bob), Vector2(-32, -18 + bob)])
		draw_colored_polygon(shell, dark)
		var core := PackedVector2Array([Vector2(0, -42 + bob), Vector2(23, -15 + bob), Vector2(18, 13 + bob), Vector2(0, 25 + bob), Vector2(-18, 13 + bob), Vector2(-23, -15 + bob)])
		draw_colored_polygon(core, body)
		draw_circle(Vector2(0, -10 + bob), 12, eye)
		draw_circle(Vector2(0, -10 + bob), 6, Color("2b304e"))
		draw_line(Vector2(-27, -5 + bob), Vector2(-48, 9 + bob), body, 8)
		draw_line(Vector2(27, -5 + bob), Vector2(48, 9 + bob), body, 8)
	else:
		# Green sporeling with three glowing eyes and soft tendrils.
		for side in [-1, 0, 1]:
			draw_line(Vector2(side * 18, 8 + bob), Vector2(side * 23, 34), dark, 8)
		draw_circle(Vector2(0, -7 + bob), 34, dark)
		draw_circle(Vector2(0, -13 + bob), 29, body)
		for side in [-1, 0, 1]:
			draw_circle(Vector2(side * 15, -17 + bob), 6, eye)
			draw_circle(Vector2(side * 15, -16 + bob), 2, Color("284b55"))
		draw_circle(Vector2(-24, -36 + bob), 9, body.lightened(0.18))
		draw_circle(Vector2(22, -39 + bob), 7, body.lightened(0.18))
	if invulnerable > 0.0:
		draw_arc(Vector2(0, -9 + bob), 42, 0, TAU, 36, Color(1, 1, 1, 0.65), 2.0)
	draw_rect(Rect2(-30, -59, 60, 5), Color("192c45"))
	draw_rect(Rect2(-30, -59, 60.0 * health / max_health, 5), Color("8df7be"))
