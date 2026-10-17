extends Control
## BioSphere-X — Pathfinding Visualizer
## Interactive grid that animates BFS, DFS, Greedy Best-First, and A* step by step.
##
## Controls:
##   Left-click      – Set START marker (mode: start) or paint walls (mode: wall)
##   Right-click     – Erase walls / reset cell to empty
##   Algorithm tabs  – Switch between BFS | DFS | Greedy | A*
##   [RUN]           – Animate the search from scratch
##   [STEP]          – Single-step the animation
##   [RESET]         – Clear visited / path layers; keep walls
##   [CLEAR ALL]     – Reset entire grid
##   [SPEED ▲▼]      – Adjust animation speed
##   ESC / ✕         – Close visualizer

signal visualizer_closed()

# ─────────────────────────────────────────────────────────────────────────────
# Grid configuration
const GRID_COLS:   int   = 30
const GRID_ROWS:   int   = 20
const CELL_SIZE:   float = 22.0
const CELL_PAD:    float = 1.0

# Colours
const COL_BG:          Color = Color(0.03, 0.06, 0.12, 1.0)
const COL_PANEL:       Color = Color(0.05, 0.09, 0.18, 0.98)
const COL_EMPTY:       Color = Color(0.10, 0.14, 0.22, 1.0)
const COL_WALL:        Color = Color(0.16, 0.22, 0.32, 1.0)
const COL_EXPLORED:    Color = Color(0.12, 0.35, 0.58, 0.75)
const COL_FRONTIER:    Color = Color(0.22, 0.62, 0.95, 0.85)
const COL_PATH:        Color = Color(0.15, 0.95, 0.55, 1.0)
const COL_START:       Color = Color(0.25, 1.00, 0.45, 1.0)
const COL_GOAL:        Color = Color(1.00, 0.32, 0.32, 1.0)
const COL_HEADER:      Color = Color(0.45, 0.95, 1.00, 1.0)
const COL_LABEL:       Color = Color(0.70, 0.85, 1.00, 1.0)
const COL_VALUE_GOOD:  Color = Color(0.30, 1.00, 0.55, 1.0)
const COL_VALUE_WARN:  Color = Color(1.00, 0.80, 0.20, 1.0)
const COL_VALUE_BAD:   Color = Color(1.00, 0.35, 0.35, 1.0)

# Cell state bitmask constants
const STATE_EMPTY:    int = 0
const STATE_WALL:     int = 1
const STATE_START:    int = 2
const STATE_GOAL:     int = 3
const STATE_EXPLORED: int = 4
const STATE_FRONTIER: int = 5
const STATE_PATH:     int = 6

# Edit modes
const MODE_START:  String = "start"
const MODE_GOAL:   String = "goal"
const MODE_WALL:   String = "wall"

# Algorithm list displayed in the UI (parallel arrays)
const ALGO_KEYS:   Array[String] = ["bfs", "dfs", "greedy", "astar"]
const ALGO_LABELS: Array[String] = ["BFS", "DFS", "Greedy", "A*"]
const ALGO_COLORS: Array[Color]  = [
	Color(0.40, 0.75, 1.00),
	Color(1.00, 0.55, 0.20),
	Color(0.90, 0.40, 1.00),
	Color(0.25, 1.00, 0.55),
]

# Speed tiers: steps per second
const SPEED_TIERS: Array[float] = [2.0, 5.0, 15.0, 40.0, 120.0]

# ─────────────────────────────────────────────────────────────────────────────
# State
var _grid:           Array       = []   # [row][col] = cell state int
var _start:          Vector2i    = Vector2i(3, 10)
var _goal:           Vector2i    = Vector2i(26, 10)
var _edit_mode:      String      = MODE_WALL
var _selected_algo:  int         = 3    # default A*
var _speed_tier:     int         = 2    # index into SPEED_TIERS

# Animation playback
var _search_steps:   Array       = []   # each step = {explored, frontier, path}
var _step_index:     int         = 0
var _playing:        bool        = false
var _step_timer:     float       = 0.0
var _final_metrics:  Dictionary  = {}
var _is_done:        bool        = false

# Node references
var _canvas:         Control
var _info_box:       VBoxContainer
var _lbl_algo:       Label
var _lbl_nodes:      Label
var _lbl_path:       Label
var _lbl_time:       Label
var _lbl_status:     Label
var _lbl_step:       Label
var _lbl_mode:       Label
var _btn_run:        Button
var _btn_step:       Button
var _btn_reset:      Button
var _algo_buttons:   Array       = []
var _mode_buttons:   Array       = []
var _lbl_speed:      Label

# Drag-painting state
var _painting:       bool        = false
var _paint_erase:    bool        = false

# Cached blocked set for the current grid
var _blocked_cache:  Dictionary  = {}

# Grid origin on the canvas (computed in _build_ui)
var _grid_origin:    Vector2     = Vector2.ZERO


# ─────────────────────────────────────────────────────────────────────────────
func _init() -> void:
	_init_grid()
	_seed_default_walls()


func _ready() -> void:
	if _grid.is_empty():
		_init_grid()
		_seed_default_walls()
	_build_ui()
	_run_search()


func _process(delta: float) -> void:
	if _playing and not _is_done:
		_step_timer -= delta
		if _step_timer <= 0.0:
			_step_timer = 1.0 / SPEED_TIERS[_speed_tier]
			_advance_step()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_on_close()
			get_viewport().set_input_as_handled()


# ─────────────────────────────────────────────────────────────────────────────
# Grid initialisation
# ─────────────────────────────────────────────────────────────────────────────
func _init_grid() -> void:
	_grid = []
	for r in GRID_ROWS:
		var row: Array = []
		for _c in GRID_COLS:
			row.append(STATE_EMPTY)
		_grid.append(row)
	_grid[_start.y][_start.x] = STATE_START
	_grid[_goal.y][_goal.x]   = STATE_GOAL


func _seed_default_walls() -> void:
	# Add a realistic U-shaped wall + two corridors to make search behaviour visible
	for r in range(4, 16):
		_set_cell(Vector2i(10, r), STATE_WALL)
		_set_cell(Vector2i(20, r), STATE_WALL)
	for c in range(10, 21):
		_set_cell(Vector2i(c, 4), STATE_WALL)
	# Openings
	_set_cell(Vector2i(10, 10), STATE_EMPTY)
	_set_cell(Vector2i(20,  8), STATE_EMPTY)
	_rebuild_blocked_cache()


func _set_cell(pos: Vector2i, state: int) -> void:
	if pos.x < 0 or pos.x >= GRID_COLS or pos.y < 0 or pos.y >= GRID_ROWS:
		return
	# Protect start/goal from being overwritten with wall state
	if state == STATE_WALL and (pos == _start or pos == _goal):
		return
	_grid[pos.y][pos.x] = state


func _rebuild_blocked_cache() -> void:
	_blocked_cache = {}
	if _grid.is_empty():
		return
	for r in GRID_ROWS:
		for c in GRID_COLS:
			if _grid[r][c] == STATE_WALL:
				_blocked_cache[Vector2i(c, r)] = true


# ─────────────────────────────────────────────────────────────────────────────
# Inline Instrumented Search (records explored/frontier per step)
# ─────────────────────────────────────────────────────────────────────────────
func _run_search() -> void:
	_playing        = false
	_step_index     = 0
	_is_done        = false
	_final_metrics  = {}
	_rebuild_blocked_cache()

	var algo: String = ALGO_KEYS[_selected_algo]
	var t_start := Time.get_ticks_usec()

	match algo:
		"bfs":
			_search_steps = _instrument_bfs()
		"dfs":
			_search_steps = _instrument_dfs()
		"greedy":
			_search_steps = _instrument_greedy()
		"astar":
			_search_steps = _instrument_astar()

	var elapsed := float(Time.get_ticks_usec() - t_start) / 1000.0

	if _search_steps.is_empty():
		_search_steps = [{
			"explored": {},
			"frontier": {},
			"path": [],
			"done": true,
			"found": false
		}]

	var last: Dictionary = _search_steps[_search_steps.size() - 1]
	_final_metrics = {
		"algorithm":         ALGO_LABELS[_selected_algo],
		"nodes_expanded":    _search_steps.size(),
		"path_length":       last.get("path", []).size(),
		"execution_time_ms": snappedf(elapsed, 0.001),
		"found":             last.get("found", false)
	}

	_update_info_panel()
	if _canvas:
		_canvas.queue_redraw()


# ─────────────────────────────────────────────────────────────────────────────
# Instrumented BFS
# ─────────────────────────────────────────────────────────────────────────────
func _instrument_bfs() -> Array:
	var steps: Array      = []
	var queue: Array      = [_start]
	var head:  int        = 0
	var visited: Dictionary   = {_start: true}
	var came_from: Dictionary = {}

	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		var frontier_set: Dictionary = {}
		for i in range(head, queue.size()):
			frontier_set[queue[i]] = true

		if current == _goal:
			var path := _reconstruct(came_from, current)
			steps.append({
				"explored":  visited.duplicate(),
				"frontier":  frontier_set,
				"path":      path,
				"done":      true,
				"found":     true
			})
			return steps

		for nb in _get_neighbors(current):
			if not visited.has(nb):
				visited[nb] = true
				came_from[nb] = current
				queue.append(nb)
				frontier_set[nb] = true

		steps.append({
			"explored": visited.duplicate(),
			"frontier": frontier_set.duplicate(),
			"path":     [],
			"done":     false,
			"found":    false,
			"current":  current
		})

	steps.append({"explored": visited.duplicate(), "frontier": {}, "path": [], "done": true, "found": false})
	return steps


# ─────────────────────────────────────────────────────────────────────────────
# Instrumented DFS
# ─────────────────────────────────────────────────────────────────────────────
func _instrument_dfs() -> Array:
	var steps: Array       = []
	var stack: Array       = [_start]
	var visited: Dictionary    = {_start: true}
	var came_from: Dictionary  = {}

	while stack.size() > 0:
		var current: Vector2i = stack[stack.size() - 1]
		stack.pop_back()

		var frontier_set: Dictionary = {}
		for item in stack:
			frontier_set[item] = true

		if current == _goal:
			var path := _reconstruct(came_from, current)
			steps.append({
				"explored": visited.duplicate(),
				"frontier": frontier_set,
				"path":     path,
				"done":     true,
				"found":    true
			})
			return steps

		for nb in _get_neighbors(current):
			if not visited.has(nb):
				visited[nb] = true
				came_from[nb] = current
				stack.append(nb)
				frontier_set[nb] = true

		steps.append({
			"explored": visited.duplicate(),
			"frontier": frontier_set.duplicate(),
			"path":     [],
			"done":     false,
			"found":    false,
			"current":  current
		})

	steps.append({"explored": visited.duplicate(), "frontier": {}, "path": [], "done": true, "found": false})
	return steps


# ─────────────────────────────────────────────────────────────────────────────
# Instrumented Greedy Best-First
# ─────────────────────────────────────────────────────────────────────────────
func _instrument_greedy() -> Array:
	var steps: Array = []
	var heap:  Array = []
	_heap_push_g(heap, _start, _heuristic(_start))
	var visited:   Dictionary = {_start: true}
	var came_from: Dictionary = {}

	while heap.size() > 0:
		var top: Array = _heap_pop_g(heap)
		var current: Vector2i = top[1]

		var frontier_set: Dictionary = {}
		for item in heap:
			frontier_set[item[1]] = true

		if current == _goal:
			var path := _reconstruct(came_from, current)
			steps.append({
				"explored": visited.duplicate(),
				"frontier": frontier_set,
				"path":     path,
				"done":     true,
				"found":    true
			})
			return steps

		for nb in _get_neighbors(current):
			if not visited.has(nb):
				visited[nb] = true
				came_from[nb] = current
				_heap_push_g(heap, nb, _heuristic(nb))
				frontier_set[nb] = true

		steps.append({
			"explored": visited.duplicate(),
			"frontier": frontier_set.duplicate(),
			"path":     [],
			"done":     false,
			"found":    false,
			"current":  current
		})

	steps.append({"explored": visited.duplicate(), "frontier": {}, "path": [], "done": true, "found": false})
	return steps


# ─────────────────────────────────────────────────────────────────────────────
# Instrumented A*
# ─────────────────────────────────────────────────────────────────────────────
func _instrument_astar() -> Array:
	var steps: Array = []
	var heap:  Array = []
	_heap_push_g(heap, _start, _heuristic(_start))
	var came_from: Dictionary = {}
	var g_score:   Dictionary = {_start: 0.0}
	var closed:    Dictionary = {}
	var in_open:   Dictionary = {_start: true}

	while heap.size() > 0:
		var top: Array = _heap_pop_g(heap)
		var current: Vector2i = top[1]
		in_open.erase(current)
		closed[current] = true

		var frontier_set: Dictionary = {}
		for item in heap:
			frontier_set[item[1]] = true

		if current == _goal:
			var path := _reconstruct(came_from, current)
			steps.append({
				"explored": closed.duplicate(),
				"frontier": frontier_set,
				"path":     path,
				"done":     true,
				"found":    true
			})
			return steps

		for nb in _get_neighbors(current):
			if closed.has(nb):
				continue
			var tentative_g: float = g_score.get(current, INF) + _cost(current, nb)
			if tentative_g < g_score.get(nb, INF):
				came_from[nb] = current
				g_score[nb]   = tentative_g
				var f: float  = tentative_g + _heuristic(nb)
				if not in_open.has(nb):
					in_open[nb] = true
					frontier_set[nb] = true
				_heap_push_g(heap, nb, f)

		steps.append({
			"explored": closed.duplicate(),
			"frontier": frontier_set.duplicate(),
			"path":     [],
			"done":     false,
			"found":    false,
			"current":  current
		})

	steps.append({"explored": closed.duplicate(), "frontier": {}, "path": [], "done": true, "found": false})
	return steps


# ─────────────────────────────────────────────────────────────────────────────
# Graph helpers
# ─────────────────────────────────────────────────────────────────────────────
func _get_neighbors(pos: Vector2i) -> Array:
	var result: Array = []
	var dirs: Array[Vector2i] = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	for d in dirs:
		var nb: Vector2i = pos + d
		if nb.x >= 0 and nb.x < GRID_COLS and nb.y >= 0 and nb.y < GRID_ROWS:
			if not _blocked_cache.has(nb):
				result.append(nb)
	return result


func _heuristic(a: Vector2i) -> float:
	var dx := absf(float(a.x - _goal.x))
	var dy := absf(float(a.y - _goal.y))
	return dx + dy   # Manhattan (no diagonal moves)


func _cost(a: Vector2i, b: Vector2i) -> float:
	return float(absi(a.x - b.x) + absi(a.y - b.y))


func _reconstruct(came_from: Dictionary, cur: Vector2i) -> Array:
	var path: Array = [cur]
	while came_from.has(cur):
		cur = came_from[cur]
		path.append(cur)
	path.reverse()
	return path


# Simple min-heap for greedy/astar [priority, Vector2i]
func _heap_push_g(heap: Array, pos: Vector2i, priority: float) -> void:
	heap.append([priority, pos])
	var i := heap.size() - 1
	while i > 0:
		var parent := (i - 1) / 2
		if heap[i][0] < heap[parent][0]:
			var tmp = heap[i]; heap[i] = heap[parent]; heap[parent] = tmp
			i = parent
		else:
			break


func _heap_pop_g(heap: Array) -> Array:
	var top: Array = heap[0]
	var last: Array = heap.pop_back()
	if heap.size() > 0:
		heap[0] = last
		var i := 0
		while true:
			var l := i * 2 + 1
			var r := i * 2 + 2
			var s := i
			if l < heap.size() and heap[l][0] < heap[s][0]: s = l
			if r < heap.size() and heap[r][0] < heap[s][0]: s = r
			if s != i:
				var tmp = heap[i]; heap[i] = heap[s]; heap[s] = tmp; i = s
			else:
				break
	return top


# ─────────────────────────────────────────────────────────────────────────────
# Animation control
# ─────────────────────────────────────────────────────────────────────────────
func _advance_step() -> void:
	if _step_index >= _search_steps.size():
		_playing = false
		_is_done = true
		if _btn_run: _btn_run.text = "▶ RUN"
		if _canvas: _canvas.queue_redraw()
		return

	_step_index += 1
	if _step_index >= _search_steps.size():
		_playing = false
		_is_done = true
		if _btn_run: _btn_run.text = "▶ RUN"
	_update_step_label()
	if _canvas: _canvas.queue_redraw()


func _update_step_label() -> void:
	if _lbl_step:
		var shown := mini(_step_index, _search_steps.size())
		_lbl_step.text = "Step: %d / %d" % [shown, _search_steps.size()]


# ─────────────────────────────────────────────────────────────────────────────
# Canvas drawing (the main visualizer grid)
# ─────────────────────────────────────────────────────────────────────────────
func _draw_canvas() -> void:
	if not _canvas:
		return

	# Determine what to render
	var step_data: Dictionary = {}
	if _search_steps.size() > 0:
		var idx := clampi(_step_index - 1, 0, _search_steps.size() - 1)
		step_data = _search_steps[idx]

	var explored: Dictionary = step_data.get("explored", {})
	var frontier: Dictionary = step_data.get("frontier", {})
	var path: Array          = step_data.get("path", [])
	var path_set: Dictionary = {}
	for p in path:
		path_set[p] = true

	# Draw grid cells
	for r in GRID_ROWS:
		for c in GRID_COLS:
			var cell_pos := Vector2i(c, r)
			var rect := Rect2(
				_grid_origin + Vector2(c, r) * (CELL_SIZE + CELL_PAD),
				Vector2(CELL_SIZE, CELL_SIZE)
			)

			var cell_state: int = _grid[r][c]
			var col: Color

			if cell_state == STATE_WALL:
				col = COL_WALL
			elif cell_pos == _start:
				col = COL_START
			elif cell_pos == _goal:
				col = COL_GOAL
			elif path_set.has(cell_pos):
				col = COL_PATH
			elif frontier.has(cell_pos):
				col = COL_FRONTIER
			elif explored.has(cell_pos):
				col = COL_EXPLORED
			else:
				col = COL_EMPTY

			_canvas.draw_rect(rect, col)

			# Grid line border
			_canvas.draw_rect(rect, Color(0.06, 0.10, 0.18, 0.60), false, 0.5)

	# Draw start marker (S)
	var start_rect := Rect2(
		_grid_origin + Vector2(_start.x, _start.y) * (CELL_SIZE + CELL_PAD),
		Vector2(CELL_SIZE, CELL_SIZE)
	)
	_canvas.draw_rect(start_rect, COL_START)
	_draw_cell_label(_canvas, start_rect, "S", Color(0.05, 0.15, 0.08, 1.0))

	# Draw goal marker (G)
	var goal_rect := Rect2(
		_grid_origin + Vector2(_goal.x, _goal.y) * (CELL_SIZE + CELL_PAD),
		Vector2(CELL_SIZE, CELL_SIZE)
	)
	_canvas.draw_rect(goal_rect, COL_GOAL)
	_draw_cell_label(_canvas, goal_rect, "G", Color(0.15, 0.05, 0.05, 1.0))


func _draw_cell_label(canvas: Control, rect: Rect2, text: String, col: Color) -> void:
	# Draw centred single-character label inside a grid cell
	var font := ThemeDB.fallback_font
	var fs    := 10
	var size  := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var tpos  := rect.position + (rect.size - size) * 0.5 + Vector2(0, size.y * 0.5)
	canvas.draw_string(font, tpos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


# ─────────────────────────────────────────────────────────────────────────────
# Info panel update
# ─────────────────────────────────────────────────────────────────────────────
func _update_info_panel() -> void:
	if _final_metrics.is_empty():
		return
	if _lbl_algo:
		_lbl_algo.text = str(_final_metrics.get("algorithm", "—"))
	if _lbl_nodes:
		_lbl_nodes.text = str(_final_metrics.get("nodes_expanded", "—")) + " cells"
	if _lbl_path:
		var pl: int = int(_final_metrics.get("path_length", 0))
		_lbl_path.text = str(pl) + " steps"
		if _lbl_path:
			_lbl_path.modulate = COL_VALUE_GOOD if pl > 0 else COL_VALUE_BAD
	if _lbl_time:
		_lbl_time.text = "%.3f ms" % float(_final_metrics.get("execution_time_ms", 0.0))
	if _lbl_status:
		var found: bool = bool(_final_metrics.get("found", false))
		_lbl_status.text = "✓ PATH FOUND" if found else "✗ NO PATH"
		_lbl_status.modulate = COL_VALUE_GOOD if found else COL_VALUE_BAD
	_update_step_label()


# ─────────────────────────────────────────────────────────────────────────────
# Mouse interaction (wall painting, start/goal placement)
# ─────────────────────────────────────────────────────────────────────────────
func _on_canvas_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_painting    = event.pressed
			_paint_erase = false
			if event.pressed:
				_handle_cell_click(event.position, false)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_painting    = event.pressed
			_paint_erase = true
			if event.pressed:
				_handle_cell_click(event.position, true)

	elif event is InputEventMouseMotion and _painting:
		_handle_cell_click(event.position, _paint_erase)


func _handle_cell_click(pos: Vector2, erase: bool) -> void:
	var col := int((pos.x - _grid_origin.x) / (CELL_SIZE + CELL_PAD))
	var row := int((pos.y - _grid_origin.y) / (CELL_SIZE + CELL_PAD))
	if col < 0 or col >= GRID_COLS or row < 0 or row >= GRID_ROWS:
		return

	var cell := Vector2i(col, row)

	if erase:
		if _grid[row][col] == STATE_WALL:
			_grid[row][col] = STATE_EMPTY
			_rebuild_blocked_cache()
			_run_search()
		return

	match _edit_mode:
		MODE_WALL:
			if cell != _start and cell != _goal:
				var old: int = _grid[row][col]
				var new_state: int = STATE_EMPTY if old == STATE_WALL else STATE_WALL
				_grid[row][col] = new_state
				_rebuild_blocked_cache()
				_run_search()

		MODE_START:
			if cell != _goal and _grid[row][col] != STATE_WALL:
				_grid[_start.y][_start.x] = STATE_EMPTY
				_start = cell
				_grid[row][col] = STATE_START
				_run_search()

		MODE_GOAL:
			if cell != _start and _grid[row][col] != STATE_WALL:
				_grid[_goal.y][_goal.x] = STATE_EMPTY
				_goal = cell
				_grid[row][col] = STATE_GOAL
				_run_search()

	if _canvas:
		_canvas.queue_redraw()


# ─────────────────────────────────────────────────────────────────────────────
# UI construction
# ─────────────────────────────────────────────────────────────────────────────
func _build_ui() -> void:
	anchor_right  = 1.0
	anchor_bottom = 1.0
	mouse_filter  = Control.MOUSE_FILTER_STOP

	# Semi-transparent full-screen backdrop
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.01, 0.02, 0.05, 0.88)
	backdrop.anchor_right  = 1.0
	backdrop.anchor_bottom = 1.0
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	# Outer panel
	var panel := PanelContainer.new()
	panel.anchor_left   = 0.5
	panel.anchor_top    = 0.5
	panel.anchor_right  = 0.5
	panel.anchor_bottom = 0.5

	var grid_px_w := GRID_COLS * (CELL_SIZE + CELL_PAD) + CELL_PAD
	var grid_px_h := GRID_ROWS * (CELL_SIZE + CELL_PAD) + CELL_PAD
	var panel_w   := grid_px_w + 260.0
	var panel_h   := grid_px_h + 110.0

	panel.offset_left   = -panel_w * 0.5
	panel.offset_top    = -panel_h * 0.5
	panel.offset_right  = panel_w  * 0.5
	panel.offset_bottom = panel_h  * 0.5

	var sty := StyleBoxFlat.new()
	sty.bg_color          = COL_PANEL
	sty.border_width_left = 2
	sty.border_width_right = 2
	sty.border_width_top = 2
	sty.border_width_bottom = 2
	sty.corner_radius_top_left = 10
	sty.corner_radius_top_right = 10
	sty.corner_radius_bottom_left = 10
	sty.corner_radius_bottom_right = 10
	sty.content_margin_left = 14
	sty.content_margin_right = 14
	sty.content_margin_top = 12
	sty.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sty)
	add_child(panel)

	# Main layout: VBox
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# ── Title bar ─────────────────────────────────────────────────────────────
	var title_hbox := HBoxContainer.new()
	title_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(title_hbox)

	var pulse := Label.new()
	pulse.text = "🔍"
	pulse.add_theme_font_size_override("font_size", 16)
	title_hbox.add_child(pulse)

	var title := Label.new()
	title.text = "PATHFINDING VISUALIZER"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", COL_HEADER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_hbox.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.add_theme_font_size_override("font_size", 14)
	close_btn.add_theme_color_override("font_color", Color(0.6, 0.65, 0.8))
	close_btn.pressed.connect(_on_close)
	title_hbox.add_child(close_btn)

	# ── Algorithm selector row ─────────────────────────────────────────────────
	var algo_hbox := HBoxContainer.new()
	algo_hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(algo_hbox)

	var algo_lbl := Label.new()
	algo_lbl.text = "Algorithm:"
	algo_lbl.add_theme_font_size_override("font_size", 11)
	algo_lbl.add_theme_color_override("font_color", COL_LABEL)
	algo_hbox.add_child(algo_lbl)

	_algo_buttons = []
	for i in ALGO_KEYS.size():
		var btn := Button.new()
		btn.text = ALGO_LABELS[i]
		btn.custom_minimum_size = Vector2(60, 26)
		btn.add_theme_font_size_override("font_size", 11)
		var normal_sty := _make_btn_sty(Color(0.10, 0.16, 0.28, 1.0), Color(0.25, 0.55, 0.90, 0.60))
		btn.add_theme_stylebox_override("normal", normal_sty)
		btn.pressed.connect(_on_algo_selected.bind(i))
		algo_hbox.add_child(btn)
		_algo_buttons.append(btn)

	_refresh_algo_buttons()

	# Spacer
	var sp1 := Control.new()
	sp1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	algo_hbox.add_child(sp1)

	# Speed control
	var spd_lbl := Label.new()
	spd_lbl.text = "Speed:"
	spd_lbl.add_theme_font_size_override("font_size", 10)
	spd_lbl.add_theme_color_override("font_color", COL_LABEL)
	algo_hbox.add_child(spd_lbl)

	var spd_down := Button.new()
	spd_down.text = "◀"
	spd_down.custom_minimum_size = Vector2(22, 22)
	spd_down.add_theme_font_size_override("font_size", 10)
	spd_down.pressed.connect(func(): _speed_tier = clampi(_speed_tier - 1, 0, SPEED_TIERS.size() - 1); _refresh_speed_label())
	algo_hbox.add_child(spd_down)

	_lbl_speed = Label.new()
	_lbl_speed.custom_minimum_size = Vector2(45, 0)
	_lbl_speed.add_theme_font_size_override("font_size", 10)
	_lbl_speed.add_theme_color_override("font_color", COL_VALUE_GOOD)
	_lbl_speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	algo_hbox.add_child(_lbl_speed)
	_refresh_speed_label()

	var spd_up := Button.new()
	spd_up.text = "▶"
	spd_up.custom_minimum_size = Vector2(22, 22)
	spd_up.add_theme_font_size_override("font_size", 10)
	spd_up.pressed.connect(func(): _speed_tier = clampi(_speed_tier + 1, 0, SPEED_TIERS.size() - 1); _refresh_speed_label())
	algo_hbox.add_child(spd_up)

	# ── Content row: Grid + Side panel ────────────────────────────────────────
	var content_hbox := HBoxContainer.new()
	content_hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(content_hbox)

	# ── Canvas ────────────────────────────────────────────────────────────────
	_canvas = Control.new()
	_canvas.custom_minimum_size = Vector2(grid_px_w, grid_px_h)
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.gui_input.connect(_on_canvas_gui_input)
	_canvas.draw.connect(_draw_canvas)
	content_hbox.add_child(_canvas)
	_grid_origin = Vector2(0, 0)

	# ── Right side panel ──────────────────────────────────────────────────────
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(230, 0)
	side.add_theme_constant_override("separation", 6)
	content_hbox.add_child(side)

	# Metrics box
	var metrics_panel := _make_sub_panel(side, "📊  SEARCH METRICS")
	_lbl_algo   = _add_metric_row(metrics_panel, "Algorithm",       "—")
	_lbl_nodes  = _add_metric_row(metrics_panel, "Nodes Expanded",  "—")
	_lbl_path   = _add_metric_row(metrics_panel, "Path Length",     "—")
	_lbl_time   = _add_metric_row(metrics_panel, "Execution Time",  "—")
	_lbl_status = _add_metric_row(metrics_panel, "Result",          "—")
	_lbl_step   = _add_metric_row(metrics_panel, "Animation Step",  "—")

	_add_vsep(side)

	# Edit mode
	var mode_panel := _make_sub_panel(side, "✏️  EDIT MODE")
	var mode_hbox  := HBoxContainer.new()
	mode_hbox.add_theme_constant_override("separation", 4)
	mode_panel.add_child(mode_hbox)

	_mode_buttons = []
	var modes  := [MODE_WALL,  MODE_START,    MODE_GOAL]
	var mlbls  := ["Wall",     "Set Start",   "Set Goal"]
	var mcols  := [COL_WALL.lightened(0.5), COL_START, COL_GOAL]
	for i in modes.size():
		var mbtn := Button.new()
		mbtn.text = mlbls[i]
		mbtn.custom_minimum_size = Vector2(66, 24)
		mbtn.add_theme_font_size_override("font_size", 10)
		mbtn.add_theme_stylebox_override("normal", _make_btn_sty(Color(0.10, 0.16, 0.28, 1.0), mcols[i].darkened(0.5)))
		mbtn.pressed.connect(_on_mode_selected.bind(modes[i]))
		mode_hbox.add_child(mbtn)
		_mode_buttons.append(mbtn)

	var hint_lbl := Label.new()
	hint_lbl.text = "LMB: paint/place  •  RMB: erase"
	hint_lbl.add_theme_font_size_override("font_size", 9)
	hint_lbl.add_theme_color_override("font_color", Color(0.45, 0.55, 0.72, 0.90))
	hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	mode_panel.add_child(hint_lbl)

	_refresh_mode_buttons()
	_update_mode_label()

	_add_vsep(side)

	# Playback controls
	var ctrl_panel := _make_sub_panel(side, "▶  PLAYBACK")
	var ctrl_grid  := GridContainer.new()
	ctrl_grid.columns = 2
	ctrl_grid.add_theme_constant_override("h_separation", 6)
	ctrl_grid.add_theme_constant_override("v_separation", 5)
	ctrl_panel.add_child(ctrl_grid)

	_btn_run = _make_action_btn("▶ RUN", COL_VALUE_GOOD)
	_btn_run.pressed.connect(_on_run_pressed)
	ctrl_grid.add_child(_btn_run)

	_btn_step = _make_action_btn("⏭ STEP", COL_VALUE_WARN)
	_btn_step.pressed.connect(_on_step_pressed)
	ctrl_grid.add_child(_btn_step)

	_btn_reset = _make_action_btn("↺ RESET", Color(0.55, 0.75, 1.00))
	_btn_reset.pressed.connect(_on_reset_pressed)
	ctrl_grid.add_child(_btn_reset)

	var clear_btn := _make_action_btn("🗑 CLEAR ALL", Color(1.00, 0.50, 0.50))
	clear_btn.pressed.connect(_on_clear_all_pressed)
	ctrl_grid.add_child(clear_btn)

	_add_vsep(side)

	# Legend
	var legend := _make_sub_panel(side, "🎨  LEGEND")
	_add_legend_row(legend, COL_START,    "Start (S)")
	_add_legend_row(legend, COL_GOAL,     "Goal (G)")
	_add_legend_row(legend, COL_PATH,     "Final Path")
	_add_legend_row(legend, COL_FRONTIER, "Frontier / Open")
	_add_legend_row(legend, COL_EXPLORED, "Explored / Closed")
	_add_legend_row(legend, COL_WALL,     "Wall / Blocked")

	# ── Status bar ────────────────────────────────────────────────────────────
	var status_hbox := HBoxContainer.new()
	vbox.add_child(status_hbox)

	_lbl_mode = Label.new()
	_lbl_mode.add_theme_font_size_override("font_size", 9)
	_lbl_mode.add_theme_color_override("font_color", Color(0.45, 0.60, 0.80, 0.90))
	_lbl_mode.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_hbox.add_child(_lbl_mode)

	var esc_hint := Label.new()
	esc_hint.text = "ESC or ✕ to close"
	esc_hint.add_theme_font_size_override("font_size", 9)
	esc_hint.add_theme_color_override("font_color", Color(0.35, 0.45, 0.60, 0.80))
	status_hbox.add_child(esc_hint)

	_update_info_panel()


# ─────────────────────────────────────────────────────────────────────────────
# UI helper factories
# ─────────────────────────────────────────────────────────────────────────────
func _make_sub_panel(parent: Control, header: String) -> VBoxContainer:
	var bg := PanelContainer.new()
	var sty := StyleBoxFlat.new()
	sty.corner_radius_top_left = 5
	sty.corner_radius_top_right = 5
	sty.corner_radius_bottom_left = 5
	sty.corner_radius_bottom_right = 5
	sty.content_margin_left = 8
	sty.content_margin_right = 8
	sty.content_margin_top  = 6
	sty.content_margin_bottom = 6
	bg.add_theme_stylebox_override("panel", sty)
	parent.add_child(bg)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	bg.add_child(vb)

	var h := Label.new()
	h.text = header
	h.add_theme_font_size_override("font_size", 10)
	h.add_theme_color_override("font_color", COL_HEADER)
	vb.add_child(h)
	return vb


func _add_metric_row(parent: VBoxContainer, key: String, default_val: String) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)

	var k := Label.new()
	k.text = key + ":"
	k.custom_minimum_size = Vector2(100, 0)
	k.add_theme_font_size_override("font_size", 10)
	k.add_theme_color_override("font_color", COL_LABEL)
	k.clip_text = true
	row.add_child(k)

	var v := Label.new()
	v.text = default_val
	v.add_theme_font_size_override("font_size", 10)
	v.add_theme_color_override("font_color", COL_VALUE_GOOD)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.clip_text = true
	row.add_child(v)
	return v


func _add_legend_row(parent: VBoxContainer, color: Color, label: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(14, 14)
	swatch.color = color
	row.add_child(swatch)

	var lbl := Label.new()
	lbl.text = label
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", COL_LABEL)
	row.add_child(lbl)


func _add_vsep(parent: VBoxContainer) -> void:
	var sep := HSeparator.new()
	var sty := StyleBoxFlat.new()
	sty.bg_color = Color(0.18, 0.40, 0.70, 0.30)
	sty.content_margin_top = 1
	sty.content_margin_bottom = 1
	sep.add_theme_stylebox_override("separator", sty)
	parent.add_child(sep)


func _make_btn_sty(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color    = bg
	s.border_color = border
	s.border_width_left = 1
	s.border_width_right = 1
	s.border_width_top = 1
	s.border_width_bottom = 1
	s.corner_radius_top_left = 4
	s.corner_radius_top_right = 4
	s.corner_radius_bottom_left = 4
	s.corner_radius_bottom_right = 4
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top  = 3
	s.content_margin_bottom = 3
	return s


func _make_action_btn(label: String, col: Color) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(100, 26)
	btn.add_theme_font_size_override("font_size", 10)
	btn.add_theme_color_override("font_color", col)
	btn.add_theme_stylebox_override("normal", _make_btn_sty(Color(0.08, 0.14, 0.26, 1.0), col.darkened(0.4)))
	return btn


# ─────────────────────────────────────────────────────────────────────────────
# Button callbacks
# ─────────────────────────────────────────────────────────────────────────────
func _on_algo_selected(idx: int) -> void:
	_selected_algo = idx
	_refresh_algo_buttons()
	_stop_and_reset()
	_run_search()
	_update_info_panel()


func _on_mode_selected(mode: String) -> void:
	_edit_mode = mode
	_refresh_mode_buttons()
	_update_mode_label()


func _on_run_pressed() -> void:
	if _playing:
		_playing = false
		if _btn_run: _btn_run.text = "▶ RUN"
		return

	if _is_done:
		_stop_and_reset()
		_run_search()

	_playing    = true
	_is_done    = false
	_step_timer = 0.0
	if _btn_run: _btn_run.text = "⏸ PAUSE"


func _on_step_pressed() -> void:
	if _playing:
		_playing = false
		if _btn_run: _btn_run.text = "▶ RUN"
	_advance_step()


func _on_reset_pressed() -> void:
	_stop_and_reset()
	_run_search()
	_update_info_panel()
	if _canvas: _canvas.queue_redraw()


func _on_clear_all_pressed() -> void:
	_playing = false
	if _btn_run: _btn_run.text = "▶ RUN"
	_init_grid()
	_rebuild_blocked_cache()
	_run_search()
	_update_info_panel()
	if _canvas: _canvas.queue_redraw()


func _on_close() -> void:
	_playing = false
	visible  = false
	visualizer_closed.emit()


func _stop_and_reset() -> void:
	_playing    = false
	_step_index = 0
	_is_done    = false
	_search_steps = []
	if _btn_run: _btn_run.text = "▶ RUN"


# ─────────────────────────────────────────────────────────────────────────────
# UI refresh helpers
# ─────────────────────────────────────────────────────────────────────────────
func _refresh_algo_buttons() -> void:
	for i in _algo_buttons.size():
		var btn: Button = _algo_buttons[i]
		var active: bool = (i == _selected_algo)
		var col: Color = ALGO_COLORS[i]
		var sty    := _make_btn_sty(
			col.darkened(0.55) if active else Color(0.10, 0.16, 0.28, 1.0),
			col
		)
		btn.add_theme_stylebox_override("normal", sty)
		btn.add_theme_color_override("font_color", col if active else COL_LABEL)


func _refresh_mode_buttons() -> void:
	var modes   := [MODE_WALL,  MODE_START,  MODE_GOAL]
	var mcols   := [COL_WALL.lightened(0.5), COL_START, COL_GOAL]
	for i in _mode_buttons.size():
		var btn: Button = _mode_buttons[i]
		var active: bool = (_edit_mode == String(modes[i]))
		btn.add_theme_stylebox_override("normal",
			_make_btn_sty(mcols[i].darkened(0.6) if active else Color(0.10, 0.16, 0.28, 1.0), mcols[i])
		)
		btn.add_theme_color_override("font_color", mcols[i] if active else COL_LABEL)


func _refresh_speed_label() -> void:
	if _lbl_speed:
		_lbl_speed.text = "%.0f /s" % SPEED_TIERS[_speed_tier]


func _update_mode_label() -> void:
	if _lbl_mode:
		match _edit_mode:
			MODE_WALL:  _lbl_mode.text = "Mode: PAINT WALLS — click cells to toggle walls"
			MODE_START: _lbl_mode.text = "Mode: SET START — click an empty cell"
			MODE_GOAL:  _lbl_mode.text = "Mode: SET GOAL — click an empty cell"
