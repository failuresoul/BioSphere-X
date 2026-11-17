extends Control
## AI vs AI result panel: one match ("Algorithms used") or the 10-match table.
## Buttons: [Rematch] [Change Setup] [Home]

signal rematch_requested
signal setup_requested
signal home_requested

const Pathfinder = preload("res://scripts/utils/modular_pathfinder.gd")
const DECISION_NAMES := {"minimax_ab": "Minimax+αβ", "minimax": "Minimax", "mcts": "MCTS"}

var title_label: Label
var subtitle_label: Label
var body: RichTextLabel          # left column (or the whole width for the 10-match table)
var body_right: RichTextLabel    # right column (single match only)


func _ready() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := Panel.new()
	panel.position = Vector2(60, 20)
	panel.size = Vector2(1160, 680)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0c193a")
	style.border_color = Color("66dfe9")
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	title_label = _label(panel, Vector2(0, 14), 36, Color("f5fbff"))
	subtitle_label = _label(panel, Vector2(0, 62), 17, Color("9be7e7"))
	body = _text_box(panel)
	body_right = _text_box(panel)
	_button(panel, "REMATCH", Vector2(250, 612), func() -> void: rematch_requested.emit())
	_button(panel, "CHANGE SETUP", Vector2(470, 612), func() -> void: setup_requested.emit())
	_button(panel, "HOME", Vector2(690, 612), func() -> void: home_requested.emit())


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("080b22"))


## One match.
func show_match(r: Dictionary) -> void:
	var blue: Dictionary = r["blue"]
	var red: Dictionary = r["red"]
	title_label.text = {"blue": "AI 1 (BLUE) WINS", "red": "AI 2 (RED) WINS", "draw": "DRAW"}[r["winner"]]
	subtitle_label.text = "Time %.1f s  •  %s  •  rule fired: %s" % [r["time"], r["reason"], r["deciding_rule"]]
	_columns(true)
	var t := _table(["", "AI 1 (Blue)", "AI 2 (Red)"], [
		["Damage dealt", "%.0f" % blue["damage"], "%.0f" % red["damage"]],
		["Health left", "%d %%" % roundi(blue["health"]), "%d %%" % roundi(red["health"])],
	])
	t += "\n[b]ALGORITHMS USED[/b]\n\n"
	t += "[b]Path finding[/b] (both fighters, rotating every 10 s)\n"
	var rows: Array = []
	for algorithm in Pathfinder.ORDER:
		var s: Dictionary = r["search"].get(algorithm, {"count": 0, "nodes": 0, "ms": 0.0, "path": 0})
		var n := maxf(1.0, s["count"])
		rows.append([Pathfinder.NAMES[algorithm], str(s["count"]), "%.1f" % (s["nodes"] / n), "%.2f" % (s["ms"] / n), "%.1f" % (s["path"] / n)])
	t += _table(["Algorithm", "Used", "Avg nodes", "Avg ms", "Avg path"], rows)
	var missing: Array[String] = []
	for row in rows:
		if row[1] == "0":
			missing.append(row[0])
	if not missing.is_empty():
		t += "[color=#f6da88](not reached: %s - the match ended before its turn)[/color]\n" % ", ".join(missing)
	body.text = t
	var d := "[b]Decisions[/b] (every 0.5 s)\n"
	d += _table(["", "AI 1 (Blue)", "AI 2 (Red)"], [
		["Algorithm", DECISION_NAMES[blue["decision"]], DECISION_NAMES[red["decision"]]],
		["Decisions", str(blue["decisions"]), str(red["decisions"])],
		["Avg time", "%.1f ms" % blue["avg_decision_ms"], "%.1f ms" % red["avg_decision_ms"]],
		["Nodes evaluated", _minimax_only(blue, "nodes_evaluated"), _minimax_only(red, "nodes_evaluated")],
		["Nodes pruned", _minimax_only(blue, "nodes_pruned"), _minimax_only(red, "nodes_pruned")],
		["Won", "yes" if r["winner"] == "blue" else "no", "yes" if r["winner"] == "red" else "no"],
	])
	d += "\n[b]Fuzzy logic[/b]: %d aggression updates (blue %d, red %d)\n" % [blue["fuzzy_updates"] + red["fuzzy_updates"], blue["fuzzy_updates"], red["fuzzy_updates"]]
	d += "\n[b]Forward chaining[/b]: %s\n" % _counts(r["rules"])
	d += "\n[b]CSP[/b]: %d solves, %d backtracks\n" % [r["csp"]["solves"], r["csp"]["backtracks"]]
	d += "\n[b]FSM[/b] (mode changes)\nBlue: %s\nRed: %s\nAlien Patrols: %d A* searches\n" % [_counts(blue["modes"]), _counts(red["modes"]), r["alien_searches"]]
	body_right.text = d


## The "Run 10 matches" table.
func show_batch(results: Array, csv_path: String) -> void:
	var wins := {"blue": 0, "red": 0, "draw": 0}
	var sums := {"blue": {"nodes": 0.0, "ms": 0.0, "damage": 0.0}, "red": {"nodes": 0.0, "ms": 0.0, "damage": 0.0}}
	for r in results:
		wins[r["winner"]] += 1
		for side in ["blue", "red"]:
			sums[side]["nodes"] += float(r[side]["avg_nodes"])
			sums[side]["ms"] += float(r[side]["avg_ms"])
			sums[side]["damage"] += float(r[side]["damage"])
	var n := float(results.size())
	_columns(false)
	title_label.text = "%d MATCHES:  AI 1  %d  -  %d  AI 2" % [results.size(), wins["blue"], wins["red"]]
	subtitle_label.text = "Draws %d  •  sides swapped every match  •  saved to %s" % [wins["draw"], csv_path]
	var rows: Array = []
	for side in ["blue", "red"]:
		rows.append(["AI 1 (Blue)" if side == "blue" else "AI 2 (Red)", DECISION_NAMES[results[0][side]["decision"]], str(wins[side]),
			"%.1f" % (sums[side]["nodes"] / n), "%.2f" % (sums[side]["ms"] / n), "%.0f" % (sums[side]["damage"] / n)])
	var t := _table(["AI", "Decision", "Wins", "Avg nodes", "Avg search ms", "Avg damage"], rows)
	t += "\n[b]Matches[/b]\n"
	var match_rows: Array = []
	for i in results.size():
		var r: Dictionary = results[i]
		match_rows.append([str(i + 1), str(r["winner"]).to_upper(), "%.1f s" % r["time"], r["reason"], "%.0f / %.0f" % [r["blue"]["damage"], r["red"]["damage"]]])
	t += _table(["#", "Winner", "Time", "How", "Damage blue / red"], match_rows)
	body.text = t


## Node counts only exist for Minimax (MCTS counts simulations instead).
func _minimax_only(side: Dictionary, key: String) -> String:
	return "n/a (MCTS)" if side["decision"] == "mcts" else str(side[key])


func _text_box(parent: Node) -> RichTextLabel:
	var box := RichTextLabel.new()
	box.bbcode_enabled = true
	box.add_theme_font_size_override("normal_font_size", 15)
	box.add_theme_font_size_override("bold_font_size", 16)
	parent.add_child(box)
	return box


## Single match: two columns. Batch table: one wide column.
func _columns(two: bool) -> void:
	body.position = Vector2(40, 100)
	body.size = Vector2(540 if two else 1080, 500)
	body_right.visible = two
	body_right.position = Vector2(610, 100)
	body_right.size = Vector2(520, 500)


func _table(header: Array, rows: Array) -> String:
	var t := "[table=%d]" % header.size()
	for cell in header:
		t += "[cell][b][color=#9be7e7]%s   [/color][/b][/cell]" % cell
	for row in rows:
		for cell in row:
			t += "[cell]%s   [/cell]" % str(cell)
	return t + "[/table]\n"


func _counts(counts: Dictionary) -> String:
	var parts: Array[String] = []
	for key in counts:
		if counts[key] > 0:
			parts.append("%s ×%d" % [key, counts[key]])
	return ", ".join(parts) if not parts.is_empty() else "none"


func _label(parent: Node, at: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = at
	label.size = Vector2(1160, font_size + 14)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _button(parent: Node, text: String, at: Vector2, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.position = at
	button.size = Vector2(200, 52)
	button.add_theme_font_size_override("font_size", 19)
	button.pressed.connect(action)
	parent.add_child(button)
