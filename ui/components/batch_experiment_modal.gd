extends PanelContainer
## BioSphere-X — Repeatable AI-vs-AI Batch Experiment Runner & Benchmark Modal
## Runs controlled multi-trial matches on identical maps with recorded random seeds
## and alternating starting positions to eliminate positional and stochastic bias.

signal modal_closed()

const COL_BG: Color          = Color(0.02, 0.05, 0.10, 0.98)
const COL_HEADER: Color      = Color(0.40, 0.95, 1.00, 1.0)
const COL_LABEL: Color       = Color(0.72, 0.85, 1.00, 1.0)
const COL_CYAN: Color        = Color(0.12, 0.88, 1.00, 1.0)
const COL_AMBER: Color       = Color(1.00, 0.55, 0.15, 1.0)
const COL_GREEN: Color       = Color(0.25, 1.00, 0.55, 1.0)
const COL_RED: Color         = Color(1.00, 0.35, 0.35, 1.0)
const COL_DIM: Color         = Color(0.50, 0.62, 0.78, 1.0)

var arena: Node = null

# UI References
var _trials_spin: SpinBox
var _map_opt: OptionButton
var _scenario_opt: OptionButton
var _algo_a_opt: OptionButton
var _algo_b_opt: OptionButton
var _base_seed_spin: SpinBox
var _alternate_spawns_chk: CheckBox
var _pair_seeds_chk: CheckBox
var _fast_speed_chk: CheckBox

var _btn_start: Button
var _btn_stop: Button
var _btn_export_json: Button
var _btn_export_csv: Button
var _btn_close: Button

var _lbl_progress: Label
var _progress_bar: ProgressBar
var _lbl_status: Label

var _lbl_a_winrate: Label
var _lbl_b_winrate: Label
var _lbl_draws: Label
var _lbl_spawn_bias: Label
var _lbl_avg_duration: Label
var _lbl_avg_nodes: Label

var _log_container: VBoxContainer
var _log_scroll: ScrollContainer


func _init() -> void:
	pass


func _ready() -> void:
	_build_ui()
	visible = false


func setup(arena_ref: Node) -> void:
	arena = arena_ref
	if arena:
		if arena.has_signal("batch_started"):
			arena.batch_started.connect(_on_arena_batch_started)
		if arena.has_signal("batch_trial_completed"):
			arena.batch_trial_completed.connect(_on_arena_trial_completed)
		if arena.has_signal("batch_finished"):
			arena.batch_finished.connect(_on_arena_batch_finished)
		_sync_from_arena()


func open_modal() -> void:
	visible = true
	_sync_from_arena()
	_refresh_summary()


func close_modal() -> void:
	visible = false
	modal_closed.emit()


# ─────────────────────────────────────────────────────────────────────────────
# UI Construction
# ─────────────────────────────────────────────────────────────────────────────
func _build_ui() -> void:
	custom_minimum_size = Vector2(880, 580)
	anchors_preset = Control.PRESET_CENTER
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -440.0
	offset_top = -290.0
	offset_right = 440.0
	offset_bottom = 290.0

	var sty := StyleBoxFlat.new()
	sty.bg_color = COL_BG
	sty.border_color = Color(0.20, 0.85, 1.00, 0.85)
	sty.border_width_left = 2
	sty.border_width_right = 2
	sty.border_width_top = 2
	sty.border_width_bottom = 2
	sty.corner_radius_top_left = 12
	sty.corner_radius_top_right = 12
	sty.corner_radius_bottom_left = 12
	sty.corner_radius_bottom_right = 12
	sty.content_margin_left = 18
	sty.content_margin_right = 18
	sty.content_margin_top = 14
	sty.content_margin_bottom = 14
	add_theme_stylebox_override("panel", sty)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	add_child(main_vbox)

	# 1. Header Bar
	var header_hbox := HBoxContainer.new()
	main_vbox.add_child(header_hbox)

	var header_vbox := VBoxContainer.new()
	header_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(header_vbox)

	var title_lbl := Label.new()
	title_lbl.text = "🧪 REPEATABLE AI-VS-AI EXPERIMENT BENCHMARK"
	title_lbl.add_theme_font_size_override("font_size", 15)
	title_lbl.add_theme_color_override("font_color", COL_HEADER)
	header_vbox.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "Multi-Trial Rig: Controlled Maps, Alternating Starting Positions, and Deterministic Recorded Seeds"
	sub_lbl.add_theme_font_size_override("font_size", 10)
	sub_lbl.add_theme_color_override("font_color", COL_DIM)
	header_vbox.add_child(sub_lbl)

	_btn_close = Button.new()
	_btn_close.text = " ✕ "
	_btn_close.custom_minimum_size = Vector2(30, 24)
	_btn_close.add_theme_font_size_override("font_size", 11)
	_btn_close.pressed.connect(close_modal)
	header_hbox.add_child(_btn_close)

	_add_hsep(main_vbox)

	# 2. Config Grid
	var cfg_grid := GridContainer.new()
	cfg_grid.columns = 4
	cfg_grid.add_theme_constant_override("h_separation", 12)
	cfg_grid.add_theme_constant_override("v_separation", 6)
	main_vbox.add_child(cfg_grid)

	# Row 1: Trials, Base Seed, Map, Scenario
	_add_grid_label(cfg_grid, "Match Trials:")
	_trials_spin = SpinBox.new()
	_trials_spin.min_value = 2.0
	_trials_spin.max_value = 50.0
	_trials_spin.step = 2.0
	_trials_spin.value = 4.0
	_trials_spin.custom_minimum_size = Vector2(90, 26)
	cfg_grid.add_child(_trials_spin)

	_add_grid_label(cfg_grid, "Base Seed:")
	_base_seed_spin = SpinBox.new()
	_base_seed_spin.min_value = 1.0
	_base_seed_spin.max_value = 999999.0
	_base_seed_spin.value = 42.0
	_base_seed_spin.custom_minimum_size = Vector2(100, 26)
	cfg_grid.add_child(_base_seed_spin)

	# Row 2: Map, Scenario, Algo A, Algo B
	_add_grid_label(cfg_grid, "Map Preset:")
	_map_opt = OptionButton.new()
	_map_opt.custom_minimum_size = Vector2(170, 26)
	cfg_grid.add_child(_map_opt)

	_add_grid_label(cfg_grid, "Scenario:")
	_scenario_opt = OptionButton.new()
	_scenario_opt.custom_minimum_size = Vector2(160, 26)
	cfg_grid.add_child(_scenario_opt)

	_add_grid_label(cfg_grid, "Agent A (Cyan):")
	_algo_a_opt = OptionButton.new()
	_algo_a_opt.custom_minimum_size = Vector2(170, 26)
	cfg_grid.add_child(_algo_a_opt)

	_add_grid_label(cfg_grid, "Agent B (Amber):")
	_algo_b_opt = OptionButton.new()
	_algo_b_opt.custom_minimum_size = Vector2(160, 26)
	cfg_grid.add_child(_algo_b_opt)

	# Row 3: Scientific Options
	var opts_hbox := HBoxContainer.new()
	opts_hbox.add_theme_constant_override("separation", 18)
	main_vbox.add_child(opts_hbox)

	_alternate_spawns_chk = CheckBox.new()
	_alternate_spawns_chk.text = "Alternate Starting Positions (Eliminate Spawn Bias)"
	_alternate_spawns_chk.button_pressed = true
	_alternate_spawns_chk.add_theme_font_size_override("font_size", 10)
	opts_hbox.add_child(_alternate_spawns_chk)

	_pair_seeds_chk = CheckBox.new()
	_pair_seeds_chk.text = "Pair Seeds across Flipped Spawns"
	_pair_seeds_chk.button_pressed = true
	_pair_seeds_chk.add_theme_font_size_override("font_size", 10)
	opts_hbox.add_child(_pair_seeds_chk)

	_fast_speed_chk = CheckBox.new()
	_fast_speed_chk.text = "Accelerate Sim (4.0x)"
	_fast_speed_chk.button_pressed = true
	_fast_speed_chk.add_theme_font_size_override("font_size", 10)
	opts_hbox.add_child(_fast_speed_chk)

	# 3. Action Buttons & Progress Bar
	var action_hbox := HBoxContainer.new()
	action_hbox.add_theme_constant_override("separation", 10)
	main_vbox.add_child(action_hbox)

	_btn_start = Button.new()
	_btn_start.text = "▶ START BATCH EXPERIMENT"
	_btn_start.custom_minimum_size = Vector2(190, 30)
	_btn_start.add_theme_font_size_override("font_size", 11)
	_btn_start.add_theme_color_override("font_color", COL_GREEN)
	_btn_start.pressed.connect(_on_start_batch_pressed)
	action_hbox.add_child(_btn_start)

	_btn_stop = Button.new()
	_btn_stop.text = "⏹ STOP"
	_btn_stop.custom_minimum_size = Vector2(80, 30)
	_btn_stop.add_theme_font_size_override("font_size", 11)
	_btn_stop.add_theme_color_override("font_color", COL_RED)
	_btn_stop.disabled = true
	_btn_stop.pressed.connect(_on_stop_batch_pressed)
	action_hbox.add_child(_btn_stop)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_hbox.add_child(sp)

	_btn_export_json = Button.new()
	_btn_export_json.text = "💾 Export JSON"
	_btn_export_json.custom_minimum_size = Vector2(100, 30)
	_btn_export_json.add_theme_font_size_override("font_size", 10)
	_btn_export_json.pressed.connect(_on_export_json_pressed)
	action_hbox.add_child(_btn_export_json)

	_btn_export_csv = Button.new()
	_btn_export_csv.text = "📊 Export CSV"
	_btn_export_csv.custom_minimum_size = Vector2(100, 30)
	_btn_export_csv.add_theme_font_size_override("font_size", 10)
	_btn_export_csv.pressed.connect(_on_export_csv_pressed)
	action_hbox.add_child(_btn_export_csv)

	# Progress Bar Row
	var prog_vbox := VBoxContainer.new()
	prog_vbox.add_theme_constant_override("separation", 2)
	main_vbox.add_child(prog_vbox)

	var prog_header := HBoxContainer.new()
	prog_vbox.add_child(prog_header)

	_lbl_progress = Label.new()
	_lbl_progress.text = "Ready to execute controlled trials."
	_lbl_progress.add_theme_font_size_override("font_size", 10)
	_lbl_progress.add_theme_color_override("font_color", COL_LABEL)
	_lbl_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prog_header.add_child(_lbl_progress)

	_lbl_status = Label.new()
	_lbl_status.text = "IDLE"
	_lbl_status.add_theme_font_size_override("font_size", 10)
	_lbl_status.add_theme_color_override("font_color", COL_DIM)
	prog_header.add_child(_lbl_status)

	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(0, 8)
	_progress_bar.max_value = 100.0
	_progress_bar.value = 0.0
	_progress_bar.show_percentage = false
	prog_vbox.add_child(_progress_bar)

	_add_hsep(main_vbox)

	# 4. Telemetry Summary Cards
	var cards_hbox := HBoxContainer.new()
	cards_hbox.add_theme_constant_override("separation", 10)
	main_vbox.add_child(cards_hbox)

	var card1 := _make_card(cards_hbox, "🏆 WIN RATE MATRIX")
	_lbl_a_winrate = _add_card_row(card1, "Agent A (Cyan):", "—")
	_lbl_b_winrate = _add_card_row(card1, "Agent B (Amber):", "—")
	_lbl_draws = _add_card_row(card1, "Draws / Ties:", "—")

	var card2 := _make_card(cards_hbox, "⚖️ SPAWN BIAS ANALYSIS")
	_lbl_spawn_bias = _add_card_row(card2, "Left vs Right:", "—")
	var card2_hint := Label.new()
	card2_hint.text = "Alternating spawns neutralizes map asymmetry."
	card2_hint.add_theme_font_size_override("font_size", 9)
	card2_hint.add_theme_color_override("font_color", COL_DIM)
	card1.add_child(card2_hint)

	var card3 := _make_card(cards_hbox, "⏱️ EFFICIENCY & AVERAGES")
	_lbl_avg_duration = _add_card_row(card3, "Avg Match Time:", "—")
	_lbl_avg_nodes = _add_card_row(card3, "Avg Nodes (A/B):", "—")

	_add_hsep(main_vbox)

	# 5. Trial Log Table
	var table_header := Label.new()
	table_header.text = "📜 TRIAL-BY-TRIAL EXPERIMENTAL LOG"
	table_header.add_theme_font_size_override("font_size", 11)
	table_header.add_theme_color_override("font_color", COL_HEADER)
	main_vbox.add_child(table_header)

	var col_header := HBoxContainer.new()
	col_header.add_theme_constant_override("separation", 6)
	main_vbox.add_child(col_header)

	_add_col_label(col_header, "#", 30)
	_add_col_label(col_header, "Seed", 60)
	_add_col_label(col_header, "Spawns (A / B)", 160)
	_add_col_label(col_header, "Winner", 110)
	_add_col_label(col_header, "Duration", 65)
	_add_col_label(col_header, "Outcome Reason", 220)
	_add_col_label(col_header, "Nodes (A/B)", 90)
	_add_col_label(col_header, "Action", 60)

	_log_scroll = ScrollContainer.new()
	_log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_scroll.custom_minimum_size = Vector2(0, 130)
	main_vbox.add_child(_log_scroll)

	_log_container = VBoxContainer.new()
	_log_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_container.add_theme_constant_override("separation", 2)
	_log_scroll.add_child(_log_container)


func _make_card(parent: Control, title: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.04, 0.08, 0.16, 0.85)
	s.border_color = Color(0.18, 0.35, 0.60, 0.50)
	s.border_width_left = 1
	s.border_width_right = 1
	s.border_width_top = 1
	s.border_width_bottom = 1
	s.corner_radius_top_left = 6
	s.corner_radius_top_right = 6
	s.corner_radius_bottom_left = 6
	s.corner_radius_bottom_right = 6
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", s)
	parent.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	panel.add_child(vb)

	var h := Label.new()
	h.text = title
	h.add_theme_font_size_override("font_size", 10)
	h.add_theme_color_override("font_color", COL_HEADER)
	vb.add_child(h)

	return vb


func _add_card_row(parent: VBoxContainer, label_text: String, default_val: String) -> Label:
	var hb := HBoxContainer.new()
	parent.add_child(hb)

	var l := Label.new()
	l.text = label_text
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", COL_LABEL)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(l)

	var v := Label.new()
	v.text = default_val
	v.add_theme_font_size_override("font_size", 10)
	v.add_theme_color_override("font_color", Color.WHITE)
	hb.add_child(v)

	return v


func _add_grid_label(grid: GridContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", COL_LABEL)
	grid.add_child(l)


func _add_col_label(parent: Control, text: String, width: float) -> void:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(width, 0)
	l.add_theme_font_size_override("font_size", 9)
	l.add_theme_color_override("font_color", COL_HEADER)
	parent.add_child(l)


func _add_hsep(parent: Control) -> void:
	var sep := HSeparator.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.18, 0.35, 0.65, 0.35)
	s.content_margin_top = 1
	s.content_margin_bottom = 1
	sep.add_theme_stylebox_override("separator", s)
	parent.add_child(sep)


# ─────────────────────────────────────────────────────────────────────────────
# Sync & Arena Control
# ─────────────────────────────────────────────────────────────────────────────
func _sync_from_arena() -> void:
	if not arena:
		return

	# Maps
	if _map_opt and _map_opt.item_count == 0:
		var labels: Array = arena.MAP_PRESET_LABELS
		for i in labels.size():
			_map_opt.add_item(labels[i], i)
		var cur_map: String = arena.get("current_map")
		var idx: int = arena.MAP_PRESETS.find(cur_map)
		if idx >= 0:
			_map_opt.selected = idx

	# Scenarios
	if _scenario_opt and _scenario_opt.item_count == 0:
		var scens: Array = arena.SCENARIO_LABELS
		for i in scens.size():
			_scenario_opt.add_item(scens[i], i)
		var cur_scen: String = arena.get("current_scenario")
		var idx: int = arena.SCENARIOS.find(cur_scen)
		if idx >= 0:
			_scenario_opt.selected = idx

	# Algorithms
	if _algo_a_opt and _algo_a_opt.item_count == 0:
		for i in arena.ALGO_LABELS.size():
			_algo_a_opt.add_item(arena.ALGO_LABELS[i], i)
			_algo_b_opt.add_item(arena.ALGO_LABELS[i], i)
		var a_alg: String = arena.get("agent_a_algorithm")
		var b_alg: String = arena.get("agent_b_algorithm")
		var a_idx: int = arena.ALGORITHMS.find(a_alg)
		var b_idx: int = arena.ALGORITHMS.find(b_alg)
		if a_idx >= 0: _algo_a_opt.selected = a_idx
		if b_idx >= 0: _algo_b_opt.selected = b_idx

	if _base_seed_spin:
		_base_seed_spin.value = arena.get("random_seed")


func _on_start_batch_pressed() -> void:
	if not arena:
		return

	# Apply selections to arena
	if _map_opt:
		arena.set("current_map", arena.MAP_PRESETS[_map_opt.selected])
		if arena.has_method("change_map"):
			arena.call("change_map", arena.MAP_PRESETS[_map_opt.selected])
	if _scenario_opt:
		arena.set("current_scenario", arena.SCENARIOS[_scenario_opt.selected])
	if _algo_a_opt:
		arena.set("agent_a_algorithm", arena.ALGORITHMS[_algo_a_opt.selected])
	if _algo_b_opt:
		arena.set("agent_b_algorithm", arena.ALGORITHMS[_algo_b_opt.selected])

	var trials: int = int(_trials_spin.value)
	var base_seed: int = int(_base_seed_spin.value)
	var alt_spawns: bool = _alternate_spawns_chk.button_pressed
	var pair_seeds: bool = _pair_seeds_chk.button_pressed
	var fast_sim: bool = _fast_speed_chk.button_pressed

	_clear_log()
	_btn_start.disabled = true
	_btn_stop.disabled = false
	_lbl_status.text = "RUNNING BATCH"
	_lbl_status.add_theme_color_override("font_color", COL_GREEN)

	if arena.has_method("start_batch_experiment"):
		arena.call("start_batch_experiment", trials, alt_spawns, base_seed, pair_seeds, fast_sim)


func _on_stop_batch_pressed() -> void:
	if arena and arena.has_method("stop_batch_experiment"):
		arena.call("stop_batch_experiment")
	_btn_start.disabled = false
	_btn_stop.disabled = true
	_lbl_status.text = "STOPPED"
	_lbl_status.add_theme_color_override("font_color", COL_AMBER)


func _on_export_json_pressed() -> void:
	if arena and arena.has_method("export_batch_json"):
		var p: String = arena.call("export_batch_json")
		if _lbl_progress:
			_lbl_progress.text = "Exported JSON to: %s" % p


func _on_export_csv_pressed() -> void:
	if arena and arena.has_method("export_batch_csv"):
		var p: String = arena.call("export_batch_csv")
		if _lbl_progress:
			_lbl_progress.text = "Exported CSV to: %s" % p


# ─────────────────────────────────────────────────────────────────────────────
# Arena Batch Event Callbacks
# ─────────────────────────────────────────────────────────────────────────────
func _on_arena_batch_started(total_trials: int) -> void:
	if _progress_bar:
		_progress_bar.max_value = float(total_trials)
		_progress_bar.value = 0.0
	if _lbl_progress:
		_lbl_progress.text = "Starting trial 1 / %d..." % total_trials


func _on_arena_trial_completed(trial_idx: int, total_trials: int, trial_result: Dictionary) -> void:
	if _progress_bar:
		_progress_bar.value = float(trial_idx + 1)
	if _lbl_progress:
		var pct := int((float(trial_idx + 1) / float(total_trials)) * 100.0)
		_lbl_progress.text = "Completed trial %d / %d (%d%%) — Seed: %s" % [
			trial_idx + 1, total_trials, pct, str(trial_result.get("random_seed", 0))
		]

	_add_log_row(trial_idx, trial_result)
	_refresh_summary()


func _on_arena_batch_finished(summary: Dictionary) -> void:
	_btn_start.disabled = false
	_btn_stop.disabled = true
	_lbl_status.text = "COMPLETED"
	_lbl_status.add_theme_color_override("font_color", COL_GREEN)

	if _lbl_progress:
		_lbl_progress.text = "Batch complete! %d trials processed." % summary.get("total_trials", 0)

	_refresh_summary()


# ─────────────────────────────────────────────────────────────────────────────
# Summary & Table Rendering
# ─────────────────────────────────────────────────────────────────────────────
func _refresh_summary() -> void:
	if not arena or not arena.has_method("get_batch_summary"):
		return

	var s: Dictionary = arena.call("get_batch_summary")
	if s.is_empty():
		return

	var total: int = int(s.get("total_trials", 0))
	if total == 0:
		return

	var a_wins: int = int(s.get("agent_a_wins", 0))
	var b_wins: int = int(s.get("agent_b_wins", 0))
	var draws: int  = int(s.get("draws", 0))

	var a_rate: float = float(s.get("agent_a_winrate", 0.0))
	var b_rate: float = float(s.get("agent_b_winrate", 0.0))
	var draw_rate: float = float(s.get("draw_rate", 0.0))

	if _lbl_a_winrate:
		_lbl_a_winrate.text = "%d / %d (%.1f%%)" % [a_wins, total, a_rate]
		_lbl_a_winrate.add_theme_color_override("font_color", COL_CYAN)

	if _lbl_b_winrate:
		_lbl_b_winrate.text = "%d / %d (%.1f%%)" % [b_wins, total, b_rate]
		_lbl_b_winrate.add_theme_color_override("font_color", COL_AMBER)

	if _lbl_draws:
		_lbl_draws.text = "%d / %d (%.1f%%)" % [draws, total, draw_rate]

	if _lbl_spawn_bias:
		var left_wins: int = int(s.get("left_spawn_wins", 0))
		var right_wins: int = int(s.get("right_spawn_wins", 0))
		var delta_bias: float = absf(float(s.get("spawn_bias_delta", 0.0)))
		var verdict := "Fair (Δ < 10%)" if delta_bias <= 10.0 else "Asymmetric (Δ %.1f%%)" % delta_bias
		_lbl_spawn_bias.text = "L: %d | R: %d — %s" % [left_wins, right_wins, verdict]

	if _lbl_avg_duration:
		_lbl_avg_duration.text = "%.2fs" % float(s.get("avg_duration", 0.0))

	if _lbl_avg_nodes:
		var a_nodes: float = float(s.get("avg_nodes_a", 0.0))
		var b_nodes: float = float(s.get("avg_nodes_b", 0.0))
		_lbl_avg_nodes.text = "%.0f vs %.0f" % [a_nodes, b_nodes]


func _clear_log() -> void:
	for c in _log_container.get_children():
		c.queue_free()


func _add_log_row(trial_idx: int, res: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_log_container.add_child(row)

	# #
	var l_num := Label.new()
	l_num.text = "#%d" % (trial_idx + 1)
	l_num.custom_minimum_size = Vector2(30, 0)
	l_num.add_theme_font_size_override("font_size", 9)
	l_num.add_theme_color_override("font_color", COL_DIM)
	row.add_child(l_num)

	# Seed
	var l_seed := Label.new()
	l_seed.text = str(res.get("random_seed", 0))
	l_seed.custom_minimum_size = Vector2(60, 0)
	l_seed.add_theme_font_size_override("font_size", 9)
	l_seed.add_theme_color_override("font_color", COL_LABEL)
	row.add_child(l_seed)

	# Spawns
	var swapped: bool = res.get("swap_spawns", false)
	var spawn_str := "A: Right | B: Left" if swapped else "A: Left | B: Right"
	var l_spawn := Label.new()
	l_spawn.text = spawn_str
	l_spawn.custom_minimum_size = Vector2(160, 0)
	l_spawn.add_theme_font_size_override("font_size", 9)
	l_spawn.add_theme_color_override("font_color", COL_AMBER if swapped else COL_CYAN)
	row.add_child(l_spawn)

	# Winner
	var winner: String = res.get("winner", "None")
	var l_win := Label.new()
	l_win.text = winner
	l_win.custom_minimum_size = Vector2(110, 0)
	l_win.add_theme_font_size_override("font_size", 9)
	if winner == "Agent A":
		l_win.add_theme_color_override("font_color", COL_CYAN)
	elif winner == "Agent B":
		l_win.add_theme_color_override("font_color", COL_AMBER)
	else:
		l_win.add_theme_color_override("font_color", COL_DIM)
	row.add_child(l_win)

	# Duration
	var l_dur := Label.new()
	l_dur.text = "%.1fs" % float(res.get("match_duration_seconds", 0.0))
	l_dur.custom_minimum_size = Vector2(65, 0)
	l_dur.add_theme_font_size_override("font_size", 9)
	row.add_child(l_dur)

	# Outcome Reason
	var l_reas := Label.new()
	l_reas.text = res.get("outcome", "")
	l_reas.custom_minimum_size = Vector2(220, 0)
	l_reas.add_theme_font_size_override("font_size", 9)
	row.add_child(l_reas)

	# Nodes
	var a_nodes: int = int(res.get("agent_a", {}).get("total_nodes_expanded", 0))
	var b_nodes: int = int(res.get("agent_b", {}).get("total_nodes_expanded", 0))
	var l_nod := Label.new()
	l_nod.text = "%d / %d" % [a_nodes, b_nodes]
	l_nod.custom_minimum_size = Vector2(90, 0)
	l_nod.add_theme_font_size_override("font_size", 9)
	row.add_child(l_nod)

	# Replay Action
	var btn_rep := Button.new()
	btn_rep.text = "Replay"
	btn_rep.custom_minimum_size = Vector2(55, 20)
	btn_rep.add_theme_font_size_override("font_size", 8)
	btn_rep.pressed.connect(func():
		_replay_trial(res)
	)
	row.add_child(btn_rep)


func _replay_trial(res: Dictionary) -> void:
	if not arena:
		return
	arena.set("random_seed", res.get("random_seed", 42))
	arena.set("swap_spawns", res.get("swap_spawns", false))
	arena.set("current_map", res.get("map_preset", "symmetric"))
	arena.set("current_scenario", res.get("scenario", "combat"))
	if arena.has_method("reset_match"):
		arena.call("reset_match")
	if arena.has_method("start_match"):
		arena.call("start_match")
	close_modal()
