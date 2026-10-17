extends PanelContainer
## AI Experiment Dashboard — BioSphere-X
## Real-time observability panel that makes all AI behaviour observable and
## measurable for academic demonstration.
##
## Panels displayed:
##   1. Backend Status          – Python AI backend online/offline indicator
##   2. Pathfinding Experiment  – algorithm, execution time, nodes expanded, path length
##   3. Adaptive Difficulty     – algorithm mode, aggression, intensity, fuzzy rule source
##   4. Session Statistics      – success rate, match outcome, total runs
##
## Toggle: Tab key (global) or call toggle_dashboard() / open_dashboard().

# ─────────────────────────────────────────────────────────────────────────────
signal dashboard_toggled(is_visible: bool)

# Layout constants
const PANEL_WIDTH: float  = 430.0
const UPDATE_INTERVAL: float = 0.35

# Colour palette
const COL_HEADER:     Color = Color(0.45, 0.95, 1.00, 1.0)
const COL_LABEL:      Color = Color(0.72, 0.85, 1.00, 1.0)
const COL_VALUE_GOOD: Color = Color(0.35, 1.00, 0.60, 1.0)
const COL_VALUE_WARN: Color = Color(1.00, 0.82, 0.20, 1.0)
const COL_VALUE_BAD:  Color = Color(1.00, 0.35, 0.35, 1.0)
const COL_OFFLINE:    Color = Color(0.60, 0.60, 0.60, 1.0)
const COL_DIM:        Color = Color(0.55, 0.65, 0.80, 1.0)

const ALGO_NAMES: Dictionary = {
	"astar":                "A* (Heuristic Search)",
	"bfs":                  "BFS (Breadth-First Search)",
	"dfs":                  "DFS (Depth-First Search)",
	"dls":                  "DLS (Depth-Limited Search)",
	"iddfs":                "IDDFS (Iterative Deepening)",
	"bidirectional":        "Bidirectional Search",
	"greedy":               "Greedy Best-First Search",
	"in_engine_fuzzy":      "Fuzzy FIS — GDScript (In-Engine)",
	"backend_python_fuzzy": "Fuzzy FIS — Python Mamdani",
	"adaptive_simple":      "Rule-Based Simple Evaluation",
	"fixed_easy":           "Fixed Profile — Easy",
	"fixed_normal":         "Fixed Profile — Normal",
	"fixed_hard":           "Fixed Profile — Hard",
	"fixed_nightmare":      "Fixed Profile — Nightmare",
}

# Pathfinding labels
var _lbl_algo:        Label
var _lbl_exec_time:   Label
var _lbl_nodes:       Label
var _lbl_path_len:    Label
var _lbl_path_source: Label
var _lbl_path_status: Label

# Difficulty labels
var _lbl_diff_algo:  Label
var _lbl_aggression: Label
var _lbl_intensity:  Label
var _lbl_speed_mult: Label
var _lbl_dmg_mult:   Label
var _lbl_cd_mult:    Label
var _lbl_diff_mode:  Label

# Adaptive vs Fixed Benchmark Labels
var _lbl_bench_mode:       Label
var _lbl_bench_deaths:     Label
var _lbl_bench_dmg:        Label
var _lbl_bench_missions:   Label
var _lbl_bench_agg_shifts: Label
var _lbl_bench_range:      Label

# Stats labels
var _lbl_success_rate:  Label
var _lbl_total_runs:    Label
var _lbl_successes:     Label
var _lbl_failures:      Label
var _lbl_match_outcome: Label

# Backend labels
var _lbl_backend_status:   Label
var _lbl_backend_endpoint: Label

# Animation
var _pulse_lbl:    Label
var _pulse_timer:  float = 0.0

# Session counters
var _total_path_requests:  int = 0
var _total_path_successes: int = 0
var _last_outcome:         String = "—"
var _last_update_timer:    float = 0.0


# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_build_ui()
	_connect_signals()
	visible = false
	call_deferred("_refresh_all")


func _process(delta: float) -> void:
	_last_update_timer -= delta
	if _last_update_timer <= 0.0:
		_last_update_timer = UPDATE_INTERVAL
		if visible:
			_refresh_all()

	_pulse_timer += delta
	if _pulse_lbl:
		var alpha := (sin(_pulse_timer * 3.0) * 0.5) + 0.5
		_pulse_lbl.modulate = Color(0.35, 1.0, 0.55, alpha)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			toggle_dashboard()
			get_viewport().set_input_as_handled()


# ─────────────────────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────────────────────
func toggle_dashboard() -> void:
	visible = not visible
	if visible:
		_refresh_all()
	dashboard_toggled.emit(visible)


func open_dashboard() -> void:
	if not visible:
		visible = true
		_refresh_all()
		dashboard_toggled.emit(true)


func close_dashboard() -> void:
	if visible:
		visible = false
		dashboard_toggled.emit(false)


func record_pathfinding_result(metrics: Dictionary) -> void:
	_total_path_requests += 1
	if metrics.get("success", false):
		_total_path_successes += 1
		_last_outcome = "SUCCESS"
	else:
		_last_outcome = "FAILURE"
	_update_pathfinding_panel(metrics)
	_update_stats_panel()


# ─────────────────────────────────────────────────────────────────────────────
# Signal Connections
# ─────────────────────────────────────────────────────────────────────────────
func _connect_signals() -> void:
	var nav = get_node_or_null("/root/NavigationManager")
	if nav:
		nav.metrics_updated.connect(_on_nav_metrics_updated)

	var dc = get_node_or_null("/root/DifficultyController")
	if dc:
		dc.difficulty_updated.connect(_on_difficulty_updated)

	var ai = get_node_or_null("/root/AIClient")
	if ai:
		ai.backend_availability_changed.connect(_on_backend_availability_changed)


func _on_nav_metrics_updated(metrics: Dictionary) -> void:
	record_pathfinding_result(metrics)


func _on_difficulty_updated(_agg: float, _inten: float, _params: Dictionary) -> void:
	_update_difficulty_panel()


func _on_backend_availability_changed(is_available: bool) -> void:
	_update_backend_panel(is_available)


# ─────────────────────────────────────────────────────────────────────────────
# Data Refresh
# ─────────────────────────────────────────────────────────────────────────────
func _refresh_all() -> void:
	_update_difficulty_panel()
	_update_stats_panel()
	_update_backend_panel_from_node()


func _update_pathfinding_panel(metrics: Dictionary) -> void:
	if not is_instance_valid(_lbl_algo):
		return

	var algo_raw:  String = str(metrics.get("algorithm", "—"))
	var algo_disp: String = ALGO_NAMES.get(algo_raw.to_lower(), algo_raw)
	var exec_ms:   float  = float(metrics.get("execution_time_ms", 0.0))
	var nodes_exp: int    = int(metrics.get("nodes_expanded", 0))
	var path_len:  int    = int(metrics.get("path_length", 0))
	var source:    String = str(metrics.get("source", "—"))
	var success:   bool   = bool(metrics.get("success", false))
	var is_fb:     bool   = bool(metrics.get("is_fallback", false))

	_lbl_algo.text     = algo_disp
	_lbl_algo.modulate = COL_VALUE_WARN if is_fb else COL_VALUE_GOOD

	_lbl_exec_time.text     = "%.3f ms" % exec_ms
	_lbl_exec_time.modulate = COL_VALUE_WARN if exec_ms > 50.0 else COL_VALUE_GOOD

	_lbl_nodes.text     = str(nodes_exp) + " cells"
	_lbl_nodes.modulate = COL_LABEL

	_lbl_path_len.text     = str(path_len) + " waypoints"
	_lbl_path_len.modulate = COL_VALUE_GOOD if path_len > 0 else COL_VALUE_BAD

	_lbl_path_source.text     = source
	_lbl_path_source.modulate = COL_VALUE_WARN if is_fb else COL_DIM

	_lbl_path_status.text     = "✓  PATH FOUND" if success else "✗  NO PATH"
	_lbl_path_status.modulate = COL_VALUE_GOOD if success else COL_VALUE_BAD


func _update_difficulty_panel() -> void:
	var dc = get_node_or_null("/root/DifficultyController")
	if not dc or not is_instance_valid(_lbl_diff_algo):
		return

	var telem:  Dictionary = dc.get_telemetry()
	var mode:   String     = str(telem.get("mode", "—"))
	var src:    String     = str(telem.get("source", "—"))
	var agg:    float      = float(telem.get("aggression", 0.0))
	var inten:  float      = float(telem.get("encounter_intensity", 1.0))
	var params: Dictionary = telem.get("parameters", {})

	_lbl_diff_algo.text     = ALGO_NAMES.get(src.to_lower(), src)
	_lbl_diff_algo.modulate = COL_VALUE_GOOD

	_lbl_aggression.text     = "%.2f / 1.00" % agg
	_lbl_aggression.modulate = _aggression_color(agg)

	_lbl_intensity.text     = "%.2fx" % inten
	_lbl_intensity.modulate = _aggression_color(clampf(inten - 0.5, 0.0, 1.0))

	_lbl_speed_mult.text     = "%.2fx" % float(params.get("speed_multiplier", 1.0))
	_lbl_dmg_mult.text       = "%.2fx" % float(params.get("attack_damage_multiplier", 1.0))
	_lbl_cd_mult.text        = "%.2fx" % float(params.get("attack_cooldown_multiplier", 1.0))
	_lbl_speed_mult.modulate = COL_LABEL
	_lbl_dmg_mult.modulate   = COL_LABEL
	_lbl_diff_mode.text     = mode
	_lbl_diff_mode.modulate = COL_DIM

	# Update Adaptive vs Fixed Benchmark Telemetry
	var bm: Dictionary = telem.get("benchmark", {})
	if is_instance_valid(_lbl_bench_mode):
		_lbl_bench_mode.text = str(bm.get("mode", mode)).replace("_", " ").capitalize()
		_lbl_bench_deaths.text = str(bm.get("deaths", 0))
		_lbl_bench_deaths.modulate = COL_VALUE_GOOD if int(bm.get("deaths", 0)) == 0 else COL_VALUE_BAD
		_lbl_bench_dmg.text = "%.1f HP" % float(bm.get("damage_sustained", 0.0))

		var comp_count: int = int(bm.get("missions_completed", 0))
		var total_m: int = int(bm.get("total_missions", 0))
		var comp_rate: float = float(bm.get("completion_rate_pct", 0.0))
		if total_m > 0:
			_lbl_bench_missions.text = "%d / %d (%.0f%%)" % [comp_count, total_m, comp_rate]
			_lbl_bench_missions.modulate = COL_VALUE_GOOD if comp_rate >= 80.0 else (COL_VALUE_WARN if comp_rate >= 50.0 else COL_VALUE_BAD)
		else:
			_lbl_bench_missions.text = "Tracking active expedition"
			_lbl_bench_missions.modulate = COL_DIM

		_lbl_bench_agg_shifts.text = "%d adaptations" % int(bm.get("aggression_changes_count", 0))
		_lbl_bench_range.text = "%.2f ⇄ %.2f (avg %.2f)" % [
			float(bm.get("min_aggression", agg)),
			float(bm.get("max_aggression", agg)),
			float(bm.get("avg_aggression", agg))
		]


func _update_stats_panel() -> void:
	if not is_instance_valid(_lbl_success_rate):
		return

	var rate: float = 0.0
	if _total_path_requests > 0:
		rate = float(_total_path_successes) / float(_total_path_requests) * 100.0
	var path_failures: int = _total_path_requests - _total_path_successes

	var gs = get_node_or_null("/root/GameState")
	var game_failures: int = 0
	if gs:
		game_failures = int(gs.get("failure_count"))

	_lbl_success_rate.text     = "%.1f%%" % rate
	_lbl_success_rate.modulate = COL_VALUE_GOOD if rate >= 80.0 else (COL_VALUE_WARN if rate >= 50.0 else COL_VALUE_BAD)

	_lbl_total_runs.text    = str(_total_path_requests)
	_lbl_total_runs.modulate = COL_LABEL

	_lbl_successes.text     = str(_total_path_successes)
	_lbl_successes.modulate = COL_VALUE_GOOD

	_lbl_failures.text     = "%d path  +  %d combat" % [path_failures, game_failures]
	_lbl_failures.modulate = COL_VALUE_BAD if (path_failures + game_failures) > 0 else COL_VALUE_GOOD

	_lbl_match_outcome.text     = _last_outcome
	_lbl_match_outcome.modulate = COL_VALUE_GOOD if _last_outcome == "SUCCESS" else (COL_VALUE_BAD if _last_outcome == "FAILURE" else COL_DIM)


func _update_backend_panel_from_node() -> void:
	var ai = get_node_or_null("/root/AIClient")
	_update_backend_panel(bool(ai.get("is_backend_available")) if ai else false)


func _update_backend_panel(is_online: bool) -> void:
	if not is_instance_valid(_lbl_backend_status):
		return
	if is_online:
		_lbl_backend_status.text     = "● ONLINE"
		_lbl_backend_status.modulate = COL_VALUE_GOOD
	else:
		_lbl_backend_status.text     = "○ OFFLINE — GDScript fallback active"
		_lbl_backend_status.modulate = COL_VALUE_WARN


func _aggression_color(t: float) -> Color:
	t = clampf(t, 0.0, 1.0)
	if t < 0.45:
		return COL_VALUE_GOOD
	elif t < 0.75:
		return COL_VALUE_WARN
	return COL_VALUE_BAD


# ─────────────────────────────────────────────────────────────────────────────
# Procedural UI Construction
# ─────────────────────────────────────────────────────────────────────────────
func _build_ui() -> void:
	custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	size_flags_horizontal = Control.SIZE_SHRINK_END
	size_flags_vertical   = Control.SIZE_SHRINK_BEGIN

	var root_style := StyleBoxFlat.new()
	root_style.bg_color            = Color(0.04, 0.07, 0.13, 0.97)
	root_style.border_color        = Color(0.20, 0.65, 1.00, 0.80)
	root_style.border_width_left   = 2
	root_style.border_width_right  = 2
	root_style.border_width_top    = 2
	root_style.border_width_bottom = 2
	root_style.corner_radius_top_left     = 8
	root_style.corner_radius_top_right    = 8
	root_style.corner_radius_bottom_left  = 8
	root_style.corner_radius_bottom_right = 8
	root_style.content_margin_left   = 14
	root_style.content_margin_right  = 14
	root_style.content_margin_top    = 12
	root_style.content_margin_bottom = 14
	add_theme_stylebox_override("panel", root_style)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 7)
	add_child(root_vbox)

	# Header row
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 6)
	root_vbox.add_child(hdr)

	_pulse_lbl = Label.new()
	_pulse_lbl.text = "●"
	_pulse_lbl.add_theme_font_size_override("font_size", 14)
	hdr.add_child(_pulse_lbl)

	var title := Label.new()
	title.text = "AI EXPERIMENT DASHBOARD"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", COL_HEADER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.add_theme_font_size_override("font_size", 12)
	close_btn.add_theme_color_override("font_color", COL_DIM)
	close_btn.pressed.connect(close_dashboard)
	hdr.add_child(close_btn)

	var hint := Label.new()
	hint.text = "[ TAB ] — toggle  ·  live refresh every %.0f ms" % (UPDATE_INTERVAL * 1000.0)
	hint.add_theme_font_size_override("font_size", 9)
	hint.add_theme_color_override("font_color", Color(0.40, 0.52, 0.70, 0.85))
	root_vbox.add_child(hint)

	_add_divider(root_vbox)

	# ─ Backend Status ─────────────────────────────────────────────────────────
	_add_section_header(root_vbox, "⚡  BACKEND STATUS")
	var sec_be := _add_section_box(root_vbox)
	_lbl_backend_status   = _add_row(sec_be, "Connection",   "Checking…")
	_lbl_backend_endpoint = _add_row(sec_be, "Endpoint",     "http://127.0.0.1:8000")
	_lbl_backend_endpoint.modulate = COL_DIM

	_add_divider(root_vbox)

	# ─ Pathfinding Experiment ─────────────────────────────────────────────────
	_add_section_header(root_vbox, "🔍  PATHFINDING EXPERIMENT")
	var sec_pf := _add_section_box(root_vbox)
	_lbl_algo        = _add_row(sec_pf, "Algorithm",        "Awaiting first request…")
	_lbl_exec_time   = _add_row(sec_pf, "Execution Time",   "—")
	_lbl_nodes       = _add_row(sec_pf, "Nodes Expanded",   "—")
	_lbl_path_len    = _add_row(sec_pf, "Path Length",      "—")
	_lbl_path_source = _add_row(sec_pf, "Compute Source",   "—")
	_lbl_path_status = _add_row(sec_pf, "Result",           "—")

	_add_divider(root_vbox)

	# ─ Adaptive Difficulty ────────────────────────────────────────────────────
	_add_section_header(root_vbox, "🧠  ADAPTIVE DIFFICULTY ENGINE")
	var sec_dc := _add_section_box(root_vbox)
	_lbl_diff_algo  = _add_row(sec_dc, "AI Algorithm",          "—")
	_lbl_aggression = _add_row(sec_dc, "Aggression",            "—")
	_lbl_intensity  = _add_row(sec_dc, "Encounter Intensity",   "—")
	_lbl_speed_mult = _add_row(sec_dc, "Speed Multiplier",      "—")
	_lbl_dmg_mult   = _add_row(sec_dc, "Damage Multiplier",     "—")
	_lbl_cd_mult    = _add_row(sec_dc, "Cooldown Multiplier",   "—")
	_lbl_diff_mode  = _add_row(sec_dc, "Mode",                  "—")

	_add_divider(root_vbox)

	# ─ Adaptive vs Fixed Benchmark ──────────────────────────────────────────
	_add_section_header(root_vbox, "⚖️  ADAPTIVE VS FIXED BENCHMARK")
	var sec_bm := _add_section_box(root_vbox)

	var bm_btn_row := HBoxContainer.new()
	bm_btn_row.add_theme_constant_override("separation", 4)
	sec_bm.add_child(bm_btn_row)

	var btn_fuzzy := _make_small_btn("Fuzzy Adaptive", COL_VALUE_GOOD)
	btn_fuzzy.pressed.connect(func(): _switch_diff_mode("adaptive_fuzzy"))
	bm_btn_row.add_child(btn_fuzzy)

	var btn_norm := _make_small_btn("Fixed Normal", COL_HEADER)
	btn_norm.pressed.connect(func(): _switch_diff_mode("normal"))
	bm_btn_row.add_child(btn_norm)

	var btn_hard := _make_small_btn("Fixed Hard", COL_VALUE_WARN)
	btn_hard.pressed.connect(func(): _switch_diff_mode("hard"))
	bm_btn_row.add_child(btn_hard)

	_lbl_bench_mode       = _add_row(sec_bm, "Active Controller",  "Adaptive Fuzzy")
	_lbl_bench_deaths     = _add_row(sec_bm, "Player Deaths",      "0")
	_lbl_bench_dmg        = _add_row(sec_bm, "Damage Sustained",   "0.0 HP")
	_lbl_bench_missions   = _add_row(sec_bm, "Mission Completion", "—")
	_lbl_bench_agg_shifts = _add_row(sec_bm, "Aggression Shifts",  "0")
	_lbl_bench_range      = _add_row(sec_bm, "Aggression Range",   "0.60 ⇄ 0.60")

	_add_divider(root_vbox)

	# ─ Session Statistics ─────────────────────────────────────────────────────
	_add_section_header(root_vbox, "📊  SESSION STATISTICS")
	var sec_st := _add_section_box(root_vbox)
	_lbl_success_rate  = _add_row(sec_st, "Path Success Rate",  "—")
	_lbl_total_runs    = _add_row(sec_st, "Total Requests",     "0")
	_lbl_successes     = _add_row(sec_st, "Successes",          "0")
	_lbl_failures      = _add_row(sec_st, "Failures",           "0")
	_lbl_match_outcome = _add_row(sec_st, "Last Match Outcome", "—")

	_add_divider(root_vbox)

	var footer := Label.new()
	footer.text = "BioSphere-X  ·  Academic AI Demonstration  ·  All metrics sampled from live subsystems"
	footer.add_theme_font_size_override("font_size", 8)
	footer.add_theme_color_override("font_color", Color(0.32, 0.42, 0.58, 0.80))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD
	root_vbox.add_child(footer)


func _add_section_header(parent: Control, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", COL_HEADER)
	parent.add_child(lbl)


func _add_section_box(parent: Control) -> VBoxContainer:
	var bg := PanelContainer.new()
	var sty := StyleBoxFlat.new()
	sty.bg_color = Color(0.07, 0.12, 0.22, 0.55)
	sty.corner_radius_top_left     = 5
	sty.corner_radius_top_right    = 5
	sty.corner_radius_bottom_left  = 5
	sty.corner_radius_bottom_right = 5
	sty.content_margin_left   = 10
	sty.content_margin_right  = 10
	sty.content_margin_top    = 6
	sty.content_margin_bottom = 6
	bg.add_theme_stylebox_override("panel", sty)
	parent.add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	bg.add_child(vbox)
	return vbox


func _add_row(parent: VBoxContainer, key: String, default_val: String) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)

	var k := Label.new()
	k.text = key + ":"
	k.custom_minimum_size = Vector2(148, 0)
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


func _add_divider(parent: VBoxContainer) -> void:
	var sep := HSeparator.new()
	var sty := StyleBoxFlat.new()
	sty.bg_color             = Color(0.18, 0.42, 0.72, 0.30)
	sty.content_margin_top    = 1
	sty.content_margin_bottom = 1
	sep.add_theme_stylebox_override("separator", sty)
	parent.add_child(sep)


func _make_small_btn(label: String, col: Color) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(0, 22)
	btn.add_theme_font_size_override("font_size", 9)
	btn.add_theme_color_override("font_color", col)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.14, 0.25, 0.90)
	s.border_color = col.darkened(0.3)
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
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	btn.add_theme_stylebox_override("normal", s)
	return btn


func _switch_diff_mode(mode: String) -> void:
	var dc = get_node_or_null("/root/DifficultyController")
	if dc and dc.has_method("set_difficulty_mode"):
		dc.call("set_difficulty_mode", mode)
		_refresh_all()
