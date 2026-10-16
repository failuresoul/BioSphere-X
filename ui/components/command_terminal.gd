extends PanelContainer
class_name CommandTerminal
## Sci-Fi Natural Language Command Terminal for BioSphere-X.
## Connects player commands to the Python AI offline NLP parser via AIClient.
## Godot validates parsed intent against current game state and executes via existing gameplay systems.

signal command_submitted(raw_text: String)
signal command_parsed(parsed_intent: Dictionary)
signal action_validated(intent: String, is_valid: bool, reason: String)
signal action_executed(action_name: String, result: Dictionary)
signal terminal_toggled(is_open: bool)

@onready var close_button: Button = %CloseButton
@onready var clear_button: Button = %ClearButton
@onready var input_line: LineEdit = %InputLine
@onready var send_button: Button = %SendButton
@onready var output_console: RichTextLabel = %OutputConsole
@onready var backend_badge: Label = %BackendBadge
@onready var status_label: Label = %StatusLabel

# Quick action shortcut buttons
@onready var btn_oxygen: Button = %BtnOxygen
@onready var btn_inventory: Button = %BtnInventory
@onready var btn_return: Button = %BtnReturn
@onready var btn_station: Button = %BtnStation
@onready var btn_vitals: Button = %BtnVitals
@onready var btn_help: Button = %BtnHelp

var _command_history: Array[String] = []
var _history_index: int = -1
var _is_busy: bool = false
var _force_offline_mode: bool = false

# Pre-compiled regex patterns for lightweight offline fallback parsing
var _re_oxygen: RegEx
var _re_inventory: RegEx
var _re_return: RegEx
var _re_station: RegEx
var _re_vitals: RegEx
var _re_help: RegEx
var _re_ambiguous: RegEx


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_compile_local_regexes()
	_connect_ui_events()
	_display_welcome_banner()
	_check_backend_status()


func _compile_local_regexes() -> void:
	_re_oxygen = RegEx.new()
	_re_oxygen.compile("(?i)\\b(refill|collect|gather|replenish|get|take|restore|recharge|fill|use|consume|grab|boost)\\b.*?\\b(oxygen|o2|air|tank|canister|resupply)\\b|\\b(oxygen|o2)\\b.*?\\b(refill|collect|replenish|restore|recharge|canister)\\b")
	
	_re_inventory = RegEx.new()
	_re_inventory.compile("(?i)\\b(inventory|items|bag|cargo|backpack|storage|crafting|supplies|show|open|view|display|check|inspect)\\b.*?\\b(inventory|items|bag|cargo|backpack|resources|crafting|supplies)\\b|^\\s*(inventory|items|bag|cargo|backpack)\\s*$")
	
	_re_return = RegEx.new()
	_re_return.compile("(?i)\\b(return|go\\s+back|evacuate|extract|dock|teleport|head\\s+back|travel\\s+to|walk\\s+to)\\b.*?\\b(base|camp|home|habitat|outpost|airlock|shuttle|ship)\\b|^\\s*(return|evacuate|extract)\\s*$")
	
	_re_station = RegEx.new()
	_re_station.compile("(?i)\\b(find|locate|where\\s+is|track|search\\s+for|point\\s+to|navigate\\s+to)\\b.*?\\b(research|terminal|outpost|console|station|beacon|waypoint|storage|vault|depot)\\b")
	
	_re_vitals = RegEx.new()
	_re_vitals.compile("(?i)\\b(vitals|status|health|stats|condition|suit\\s+status|diagnostics)\\b")
	
	_re_help = RegEx.new()
	_re_help.compile("(?i)^\\s*(help|\\?|commands|syntax|usage|guide|options)\\s*$")
	
	_re_ambiguous = RegEx.new()
	_re_ambiguous.compile("(?i)^\\s*(find|get|open|go|check|station|terminal|base|oxygen|inventory)\\s*$")


func _connect_ui_events() -> void:
	if close_button:
		close_button.pressed.connect(close_terminal)
	if clear_button:
		clear_button.pressed.connect(clear_console)
	if send_button:
		send_button.pressed.connect(_on_send_pressed)
	if input_line:
		input_line.text_submitted.connect(submit_command)
		
	# Quick command buttons
	if btn_oxygen:
		btn_oxygen.pressed.connect(func(): submit_command("collect oxygen"))
	if btn_inventory:
		btn_inventory.pressed.connect(func(): submit_command("show inventory"))
	if btn_return:
		btn_return.pressed.connect(func(): submit_command("return to base"))
	if btn_station:
		btn_station.pressed.connect(func(): submit_command("find research station"))
	if btn_vitals:
		btn_vitals.pressed.connect(func(): submit_command("check vitals"))
	if btn_help:
		btn_help.pressed.connect(func(): submit_command("help"))
		
	var client = get_node_or_null("/root/AIClient")
	if client and client.has_signal("backend_availability_changed"):
		client.backend_availability_changed.connect(_on_backend_availability_changed)


func _display_welcome_banner() -> void:
	if not output_console:
		return
	output_console.clear()
	output_console.append_text("[color=#00e5ff][b]// BIOSPHERE-X COMMAND TERMINAL // [OFFLINE NATURAL LANGUAGE PARSER][/b][/color]\n")
	output_console.append_text("[color=#88aabb]Type commands naturally in plain English (e.g. 'collect oxygen', 'show inventory', 'return to base', 'find research station', 'help').[/color]\n")
	output_console.append_text("[color=#557799]──────────────────────────────────────────────────────────────────────────[/color]\n")


func _check_backend_status() -> void:
	var client = get_node_or_null("/root/AIClient")
	if client and client.has_method("check_health"):
		client.call("check_health", _on_health_check_result)
	else:
		_update_backend_badge(false)


func _on_health_check_result(res: Dictionary) -> void:
	if not is_instance_valid(self):
		return
	var online: bool = bool(res.get("success", false))
	_update_backend_badge(online)


func _on_backend_availability_changed(online: bool) -> void:
	_update_backend_badge(online)


func _update_backend_badge(is_online: bool) -> void:
	if not backend_badge:
		return
	if is_online and not _force_offline_mode:
		backend_badge.text = "● PYTHON AI BACKEND [ONLINE]"
		backend_badge.modulate = Color(0.2, 1.0, 0.5)
	else:
		backend_badge.text = "○ EMBEDDED GDSCRIPT ENGINE [OFFLINE]"
		backend_badge.modulate = Color(1.0, 0.7, 0.2)


func set_force_offline_mode(force: bool) -> void:
	_force_offline_mode = force
	_update_backend_badge(not force)


# ---------------------------------------------------------------------------
# Terminal Visibility & Navigation
# ---------------------------------------------------------------------------
func toggle_terminal() -> void:
	if visible:
		close_terminal()
	else:
		open_terminal()


func open_terminal() -> void:
	visible = true
	terminal_toggled.emit(true)
	if input_line:
		input_line.grab_focus()
		input_line.text = ""
	_history_index = -1


func close_terminal() -> void:
	visible = false
	terminal_toggled.emit(false)
	if input_line:
		input_line.release_focus()


func clear_console() -> void:
	if output_console:
		output_console.clear()
		_display_welcome_banner()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
		
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			close_terminal()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_UP:
			_navigate_history(-1)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_DOWN:
			_navigate_history(1)
			get_viewport().set_input_as_handled()


func _navigate_history(direction: int) -> void:
	if _command_history.is_empty() or not input_line:
		return
	_history_index = clampi(_history_index + direction, 0, _command_history.size() - 1)
	input_line.text = _command_history[_history_index]
	input_line.caret_column = input_line.text.length()


func _on_send_pressed() -> void:
	if input_line:
		submit_command(input_line.text)


# ---------------------------------------------------------------------------
# Command Dispatch Pipeline
# ---------------------------------------------------------------------------
func submit_command(raw_text: String) -> void:
	var trimmed := raw_text.strip_edges()
	if trimmed.is_empty():
		return
		
	if input_line:
		input_line.clear()
		
	_command_history.append(trimmed)
	_history_index = _command_history.size()
	
	command_submitted.emit(trimmed)
	
	# Echo in console
	output_console.append_text("[color=#00e5ff]> %s[/color]\n" % trimmed)
	if status_label:
		status_label.text = "PARSING INTENT..."
		status_label.modulate = Color(0.3, 0.8, 1.0)
		
	var context := _gather_player_context()
	var client = get_node_or_null("/root/AIClient")
	
	# If offline mode is forced or AIClient not available, use local parser directly
	if _force_offline_mode or client == null or not client.has_method("request_command_parse"):
		var local_parsed := _parse_command_locally(trimmed)
		_process_parsed_command(local_parsed, "GDScript NLP")
		return
		
	_is_busy = true
	client.call("request_command_parse", trimmed, context, func(res: Dictionary):
		_is_busy = false
		if not is_instance_valid(self):
			return
		if res.get("success", false) and res.has("parsed"):
			_process_parsed_command(res["parsed"], "Python Backend")
		else:
			# Fallback seamlessly to local parser
			var fallback_parsed := _parse_command_locally(trimmed)
			_process_parsed_command(fallback_parsed, "GDScript NLP (Fallback)")
	)


func _gather_player_context() -> Dictionary:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var gs = get_node_or_null("/root/GameState")
	var gre = get_node_or_null("/root/GameRuleEngine")
	
	return {
		"player_position": {
			"x": player.global_position.x if player else 0.0,
			"y": player.global_position.y if player else 0.0
		},
		"oxygen": gs.oxygen if gs else 100.0,
		"max_oxygen": gs.max_oxygen if gs else 100.0,
		"health": gs.health if gs else 100.0,
		"is_combat_alert": gre.combat_threat_active if gre and "combat_threat_active" in gre else false,
		"selected_planet": gs.selected_planet if gs and "selected_planet" in gs else "TRAPPIST-1 e"
	}


# ---------------------------------------------------------------------------
# Natural Language Parser (Lightweight Offline GDScript Implementation)
# Matches Python algorithms.nlp.parser specifications and schema.
# ---------------------------------------------------------------------------
func _parse_command_locally(query: String) -> Dictionary:
	var q := query.strip_edges().to_lower()
	
	if q.is_empty():
		return {
			"raw_query": query, "intent": "unknown", "parameters": {},
			"is_valid": false, "status": "unknown",
			"clarification": "No command entered.", "suggested_actions": ["help"]
		}
		
	# 1. Ambiguous check (single keywords without target)
	if _re_ambiguous.search(q) != null and not q in ["help", "inventory", "vitals", "status"]:
		var clar := "Command '%s' is ambiguous. Please specify parameters (e.g. 'collect oxygen', 'find research station', 'return to base')." % query
		return {
			"raw_query": query, "intent": "ambiguous", "parameters": {"raw_token": q},
			"is_valid": false, "status": "ambiguous",
			"clarification": clar,
			"suggested_actions": ["collect oxygen", "show inventory", "return to base", "find research station"]
		}
		
	# 2. Help Command
	if _re_help.search(q) != null:
		return {
			"raw_query": query, "intent": "help",
			"parameters": {
				"commands": [
					{"intent": "collect_oxygen", "syntax": "collect [amount] oxygen / refill o2", "desc": "Refills suit life support from base or consumes canisters."},
					{"intent": "show_inventory", "syntax": "show inventory / inspect cargo / open items", "desc": "Displays suit resources, equipment, and crafting manifest."},
					{"intent": "return_to_base", "syntax": "return to base / evacuate to habitat", "desc": "Plots return trajectory to habitat airlock if path is secure."},
					{"intent": "find_station", "syntax": "find research station / locate terminal", "desc": "Tracks nearest terminal or atmospheric depot with navigation waypoints."},
					{"intent": "check_vitals", "syntax": "check vitals / suit diagnostics / status", "desc": "Displays health, oxygen, hazard level, and threat state."}
				]
			},
			"is_valid": true, "status": "ok",
			"clarification": "Available BioSphere-X commands.",
			"suggested_actions": []
		}
		
	# 3. Collect Oxygen Command
	if _re_oxygen.search(q) != null:
		var amount: float = 100.0
		var amt_regex := RegEx.new()
		amt_regex.compile("(\\d+(?:\\.\\d+)?)")
		var m := amt_regex.search(q)
		if m != null:
			amount = clampf(float(m.get_string(1)), 1.0, 100.0)
			
		var target := "tank"
		if "pack" in q or "cell" in q or "canister" in q:
			target = "oxygen_cells"
			
		return {
			"raw_query": query, "intent": "collect_oxygen",
			"parameters": {
				"target": target,
				"requested_amount": amount,
				"unit": "percent"
			},
			"is_valid": true, "status": "ok",
			"clarification": "Requested life-support oxygen replenishment.",
			"suggested_actions": []
		}
		
	# 4. Show Inventory Command
	if _re_inventory.search(q) != null:
		var filter_cat := "all"
		if "resource" in q or "mineral" in q:
			filter_cat = "resources"
		elif "consumable" in q or "pack" in q or "cell" in q:
			filter_cat = "consumables"
			
		return {
			"raw_query": query, "intent": "show_inventory",
			"parameters": {
				"filter_category": filter_cat,
				"open_ui": true
			},
			"is_valid": true, "status": "ok",
			"clarification": "Access suit cargo and inventory telemetry.",
			"suggested_actions": []
		}
		
	# 5. Return to Base Command
	if _re_return.search(q) != null:
		var dest := "habitat_airlock"
		if "camp" in q or "home" in q:
			dest = "base_habitat"
			
		return {
			"raw_query": query, "intent": "return_to_base",
			"parameters": {
				"destination": dest,
				"dock_airlock": true
			},
			"is_valid": true, "status": "ok",
			"clarification": "Plot evacuation route back to research base.",
			"suggested_actions": []
		}
		
	# 6. Find Research Station / Terminals
	if _re_station.search(q) != null:
		var st_type := "research_terminal"
		if "storage" in q or "vault" in q or "depot" in q:
			st_type = "storage_terminal"
		elif "return" in q or "extraction" in q or "exit" in q:
			st_type = "return_terminal"
		elif "oxygen" in q or "air" in q or "atmospheric" in q:
			st_type = "oxygen_station"
		elif "gate" in q or "planet" in q:
			st_type = "planet_gate"
			
		return {
			"raw_query": query, "intent": "find_station",
			"parameters": {
				"station_type": st_type,
				"set_waypoint": true
			},
			"is_valid": true, "status": "ok",
			"clarification": "Locate facility and lock navigation vector.",
			"suggested_actions": []
		}
		
	# 7. Check Vitals
	if _re_vitals.search(q) != null:
		return {
			"raw_query": query, "intent": "check_vitals",
			"parameters": {"scope": "all"},
			"is_valid": true, "status": "ok",
			"clarification": "Astronaut biometric and suit telemetry.",
			"suggested_actions": []
		}
		
	# 8. Unknown fallback
	return {
		"raw_query": query, "intent": "unknown", "parameters": {},
		"is_valid": false, "status": "unknown",
		"clarification": "Unrecognized command '%s'. Type 'help' to review supported directives." % query,
		"suggested_actions": ["collect oxygen", "show inventory", "return to base", "find research station", "help"]
	}


# ---------------------------------------------------------------------------
# Intent Processing & Game-State Validation
# ---------------------------------------------------------------------------
func _process_parsed_command(parsed: Dictionary, engine_label: String) -> void:
	command_parsed.emit(parsed)
	
	var status: String = str(parsed.get("status", "unknown"))
	var is_valid: bool = bool(parsed.get("is_valid", false))
	var intent: String = str(parsed.get("intent", "unknown"))
	var params: Dictionary = parsed.get("parameters", {})
	
	output_console.append_text("[color=#88aabb][PARSER: %s | INTENT: %s | STATUS: %s][/color]\n" % [
		engine_label, intent.to_upper(), status.to_upper()
	])
	
	# Ambiguous command handling
	if status == "ambiguous":
		var clar: String = str(parsed.get("clarification", "Command is ambiguous."))
		output_console.append_text("[color=#ffd166]⚠ [AMBIGUOUS COMMAND][/color] %s\n" % clar)
		var suggestions: Array = parsed.get("suggested_actions", [])
		if not suggestions.is_empty():
			output_console.append_text("[color=#88bbff]Suggested syntax:[/color]\n")
			for s in suggestions:
				output_console.append_text("  • [color=#70d6ff]%s[/color]\n" % str(s))
		output_console.append_text("\n")
		action_validated.emit("ambiguous", false, clar)
		if status_label:
			status_label.text = "STATUS: AMBIGUOUS DIRECTIVE"
			status_label.modulate = Color(1.0, 0.8, 0.3)
		return
		
	# Unknown command handling
	if status == "unknown" or not is_valid:
		var clar: String = str(parsed.get("clarification", "Command not recognized."))
		output_console.append_text("[color=#ff6b6b]? [UNKNOWN COMMAND][/color] %s\n" % clar)
		var suggestions: Array = parsed.get("suggested_actions", [])
		if not suggestions.is_empty():
			output_console.append_text("[color=#88bbff]Try one of:[/color] %s\n" % ", ".join(suggestions))
		output_console.append_text("\n")
		action_validated.emit("unknown", false, clar)
		if status_label:
			status_label.text = "STATUS: UNKNOWN DIRECTIVE"
			status_label.modulate = Color(1.0, 0.4, 0.4)
		return
		
	# Supported & Valid Intent -> Authoritative Validation & Execution in Godot
	var result := validate_and_execute(parsed)
	
	if result["success"]:
		output_console.append_text("[color=#06d6a0]✔ [ACTION EXECUTED][/color] %s\n\n" % result["reason"])
		if status_label:
			status_label.text = "STATUS: EXECUTED SUCCESS"
			status_label.modulate = Color(0.2, 1.0, 0.5)
	else:
		output_console.append_text("[color=#ef476f]✖ [ACTION IMPOSSIBLE][/color] %s\n\n" % result["reason"])
		if status_label:
			status_label.text = "STATUS: REJECTED (STATE CONFLICT)"
			status_label.modulate = Color(1.0, 0.3, 0.3)


# ---------------------------------------------------------------------------
# Authoritative Godot Game-State Validation & Execution Subsystem
# ---------------------------------------------------------------------------
func validate_and_execute(parsed: Dictionary) -> Dictionary:
	var intent: String = str(parsed.get("intent", ""))
	var params: Dictionary = parsed.get("parameters", {})
	
	var gs = get_node_or_null("/root/GameState")
	var inv = get_node_or_null("/root/InventoryManager")
	var gre = get_node_or_null("/root/GameRuleEngine")
	var nav = get_node_or_null("/root/NavigationManager")
	var player := get_tree().get_first_node_in_group("player") as Node2D
	
	match intent:
		"collect_oxygen":
			return _execute_collect_oxygen(params, gs, inv, player)
			
		"show_inventory":
			return _execute_show_inventory(params, gs, inv)
			
		"return_to_base":
			return _execute_return_to_base(params, gs, gre, nav, player)
			
		"find_station":
			return _execute_find_station(params, nav, player)
			
		"check_vitals":
			return _execute_check_vitals(gs, gre)
			
		"help":
			return _execute_help(params)
			
		_:
			var reason := "Unimplemented gameplay intent: '%s'" % intent
			action_validated.emit(intent, false, reason)
			return {"success": false, "reason": reason}


func _execute_collect_oxygen(params: Dictionary, gs: Node, inv: Node, player: Node2D) -> Dictionary:
	if gs == null:
		var err := "GameState singleton unavailable."
		action_validated.emit("collect_oxygen", false, err)
		return {"success": false, "reason": err}
		
	# Impossible condition 1: Oxygen already at 100% capacity
	if gs.oxygen >= gs.max_oxygen:
		var reason := "Cannot collect oxygen: Suit life-support tanks are already at 100% capacity."
		action_validated.emit("collect_oxygen", false, reason)
		return {"success": false, "reason": reason}
		
	# Check if player is near base/depot atmospheric generator
	var near_station := false
	if gs.is_oxygen_refilling:
		near_station = true
	else:
		var stations = get_tree().get_nodes_in_group("oxygen_stations")
		var p_pos := player.global_position if player else Vector2.ZERO
		for st in stations:
			if st is Node2D:
				var rad: float = float(st.get("radius")) if "radius" in st else 90.0
				if p_pos.distance_to(st.global_position) <= rad + 20.0:
					near_station = true
					break
					
	if near_station:
		gs.refill_oxygen(-1.0)
		var reason := "Atmospheric core linked: Suit life support recharged to 100% capacity."
		action_validated.emit("collect_oxygen", true, "Refilled at station")
		action_executed.emit("collect_oxygen", {"restored": 100.0, "source": "station"})
		return {"success": true, "reason": reason}
		
	# Check if player has consumable oxygen item in inventory
	if inv:
		if inv.has_method("has_item") and inv.call("has_item", "oxygen_pack", 1):
			inv.call("use_item", "oxygen_pack", player)
			var reason := "Consumed 1 Oxygen Resupply Pack (+60% O2). Life support stabilized."
			action_validated.emit("collect_oxygen", true, "Used oxygen pack")
			action_executed.emit("collect_oxygen", {"restored": 60.0, "source": "oxygen_pack"})
			return {"success": true, "reason": reason}
		elif inv.has_method("has_item") and inv.call("has_item", "oxygen_cells", 1):
			inv.call("use_item", "oxygen_cells", player)
			var reason := "Vented 1 Oxygen Cell canister (+30% O2). Life support restored."
			action_validated.emit("collect_oxygen", true, "Used oxygen cell")
			action_executed.emit("collect_oxygen", {"restored": 30.0, "source": "oxygen_cells"})
			return {"success": true, "reason": reason}
			
	# Fallback to direct GameState resource storage
	if gs.get_resource("oxygen_cells") > 0:
		gs.resources["oxygen_cells"] -= 1
		gs.refill_oxygen(30.0)
		if gs.has_signal("resource_changed"):
			gs.resource_changed.emit("oxygen_cells", gs.resources["oxygen_cells"])
		var reason := "Vented 1 Oxygen Cell canister from suit cargo (+30% O2)."
		action_validated.emit("collect_oxygen", true, "Used oxygen cell from cargo")
		action_executed.emit("collect_oxygen", {"restored": 30.0, "source": "oxygen_cells"})
		return {"success": true, "reason": reason}
		
	# Impossible condition 2: No oxygen canisters carried and not near atmospheric station
	var reason := "Impossible action: No oxygen cells or resupply packs in cargo, and astronaut is not in range of an atmospheric generator. Navigate to Base or craft Oxygen Cells."
	action_validated.emit("collect_oxygen", false, reason)
	return {"success": false, "reason": reason}


func _execute_show_inventory(params: Dictionary, gs: Node, inv: Node) -> Dictionary:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and "inventory_dialog" in hud and hud.inventory_dialog:
		if hud.inventory_dialog.has_method("toggle_visibility"):
			hud.inventory_dialog.call("toggle_visibility")
		else:
			hud.inventory_dialog.visible = true
			
	var crystals: int = gs.get_resource("crystals") if gs else 0
	var titanium: int = gs.get_resource("titanium") if gs else 0
	var biomass: int = gs.get_resource("biomass") if gs else 0
	var cells: int = gs.get_resource("oxygen_cells") if gs else 0
	
	var reason := "Cargo manifest active: Crystals: %d | Titanium: %d | Biomass: %d | O2 Cells: %d. Inventory HUD displayed." % [
		crystals, titanium, biomass, cells
	]
	action_validated.emit("show_inventory", true, "Inventory retrieved")
	action_executed.emit("show_inventory", {"crystals": crystals, "titanium": titanium, "biomass": biomass, "oxygen_cells": cells})
	return {"success": true, "reason": reason}


func _execute_return_to_base(params: Dictionary, gs: Node, gre: Node, nav: Node, player: Node2D) -> Dictionary:
	# Impossible condition 1: Hostile pursuit lockdown
	if gre and ("combat_threat_active" in gre and gre.combat_threat_active or "is_extraction_blocked" in gre and gre.is_extraction_blocked):
		var lock_msg: String = str(gre.get("extraction_block_reason")) if "extraction_block_reason" in gre and not str(gre.get("extraction_block_reason")).is_empty() else "Hostile pursuit active: Airlock security lockdown prevents return sequence until threat is neutralized!"
		action_validated.emit("return_to_base", false, lock_msg)
		return {"success": false, "reason": lock_msg}
		
	var base_target := Vector2.ZERO # Research base center
	var p_pos := player.global_position if player else Vector2(250, 250)
	var dist := p_pos.distance_to(base_target)
	
	# If already inside base radius
	if dist <= 80.0:
		var reason := "Astronaut is already within Base Habitat perimeter. Airlock status: DOCKED."
		action_validated.emit("return_to_base", true, "Already docked")
		action_executed.emit("return_to_base", {"status": "docked", "target": base_target})
		return {"success": true, "reason": reason}
		
	# Register navigation route to base
	if nav and nav.has_method("register_active_path"):
		var direct_path := PackedVector2Array([p_pos, base_target])
		nav.call("register_active_path", 9999, direct_path, Color(0.2, 0.9, 0.4, 0.9))
		
	var mm = get_node_or_null("/root/MissionManager")
	var mission_note := ""
	if mm and mm.has_method("get_active_mission"):
		var active = mm.call("get_active_mission")
		if active and str(active.get("id")) != "mission_06_extraction":
			var t_val = active.get("title")
			var title_str: String = str(t_val) if t_val != null else ""
			mission_note = " (Active Directive '%s' remains in progress)" % title_str
		
	var reason := "Return trajectory plotted to Bio-Base Habitat (0, 0). Range: %.1fm. Follow HUD navigation waypoint to return safely.%s" % [
		dist, (" " + mission_note if not mission_note.is_empty() else "")
	]
	action_validated.emit("return_to_base", true, "Waypoint locked")
	action_executed.emit("return_to_base", {"status": "waypoint_set", "distance": dist, "target": base_target})
	return {"success": true, "reason": reason}


func _execute_find_station(params: Dictionary, nav: Node, player: Node2D) -> Dictionary:
	var target_type: String = str(params.get("station_type", "research_terminal"))
	var p_pos := player.global_position if player else Vector2.ZERO
	
	var candidates: Array[Node] = []
	match target_type:
		"research_terminal":
			candidates = get_tree().get_nodes_in_group("terminals")
		"storage_terminal":
			candidates = get_tree().get_nodes_in_group("storage_terminals")
			if candidates.is_empty():
				candidates = get_tree().get_nodes_in_group("base_stations")
		"return_terminal":
			candidates = get_tree().get_nodes_in_group("return_terminals")
		"oxygen_station":
			candidates = get_tree().get_nodes_in_group("oxygen_stations")
		_:
			candidates = get_tree().get_nodes_in_group("terminals")
			
	var closest_node: Node2D = null
	var closest_dist: float = 999999.0
	
	for c in candidates:
		if c is Node2D and c.is_visible_in_tree():
			var d := p_pos.distance_to(c.global_position)
			if d < closest_dist:
				closest_dist = d
				closest_node = c
				
	if closest_node:
		var st_name: String = str(closest_node.get("station_name")) if "station_name" in closest_node else (str(closest_node.get("terminal_name")) if "terminal_name" in closest_node else closest_node.name)
		var dest := closest_node.global_position
		
		if nav and nav.has_method("register_active_path"):
			var path := PackedVector2Array([p_pos, dest])
			nav.call("register_active_path", 9998, path, Color(0, 0.85, 1, 0.9))
			
		var reason := "Located %s at (%.1f, %.1f) - Range: %.1fm. Navigation waypoint locked." % [
			st_name, dest.x, dest.y, closest_dist
		]
		action_validated.emit("find_station", true, "Station locked")
		action_executed.emit("find_station", {"station": st_name, "position": dest, "distance": closest_dist})
		return {"success": true, "reason": reason}
	else:
		var reason := "No operational %s detected within current planetary sector." % target_type
		action_validated.emit("find_station", false, reason)
		return {"success": false, "reason": reason}


func _execute_check_vitals(gs: Node, gre: Node) -> Dictionary:
	var hp: float = gs.health if gs else 100.0
	var max_hp: float = gs.max_health if gs else 100.0
	var o2: float = gs.oxygen if gs else 100.0
	var energy: float = gs.energy if gs else 100.0
	var planet: String = gs.selected_planet if gs and "selected_planet" in gs else "Unknown"
	var threat: String = "COMBAT ALERT" if gre and "combat_threat_active" in gre and gre.combat_threat_active else "NOMINAL"
	
	var reason := "EVA Telemetry -> Health: %.0f/%.0f | O2: %.0f%% | Energy: %.0f%% | Planet: %s | Threat: %s" % [
		hp, max_hp, o2, energy, planet, threat
	]
	action_validated.emit("check_vitals", true, "Vitals retrieved")
	action_executed.emit("check_vitals", {"health": hp, "oxygen": o2, "energy": energy, "threat": threat})
	return {"success": true, "reason": reason}


func _execute_help(params: Dictionary) -> Dictionary:
	var commands: Array = params.get("commands", [])
	output_console.append_text("[color=#00e5ff][b]BioSphere-X Command Catalog:[/b][/color]\n")
	if not commands.is_empty():
		for c in commands:
			output_console.append_text(" • [color=#ffd166]%s[/color]: %s\n" % [str(c.get("syntax", "")), str(c.get("desc", ""))])
	else:
		output_console.append_text(" • [color=#ffd166]collect oxygen[/color]: Refills suit life support from base or consumes canisters.\n")
		output_console.append_text(" • [color=#ffd166]show inventory[/color]: Displays suit resources, equipment, and crafting manifest.\n")
		output_console.append_text(" • [color=#ffd166]return to base[/color]: Plots return trajectory to habitat airlock if path is secure.\n")
		output_console.append_text(" • [color=#ffd166]find research station[/color]: Tracks nearest terminal with navigation waypoints.\n")
		output_console.append_text(" • [color=#ffd166]check vitals[/color]: Displays health, oxygen, hazard level, and threat state.\n")
	output_console.append_text("\n")
	
	action_validated.emit("help", true, "Help displayed")
	action_executed.emit("help", {})
	return {"success": true, "reason": "Command catalog printed to terminal output."}
