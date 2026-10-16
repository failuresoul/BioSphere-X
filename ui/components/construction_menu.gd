extends PanelContainer
## Modern Sci-Fi Construction Menu for BioSphere-X.
## Displays constructible base structures, dimensions, costs, and clearance rules.
## Initiates placement preview mode upon selecting a structure.

signal menu_opened()
signal menu_closed()
signal structure_selected_for_placement(structure_id: String)

@onready var close_button: Button = %CloseButton
@onready var structures_container: VBoxContainer = %StructuresContainer
@onready var build_zone_info_label: Label = %BuildZoneInfoLabel
@onready var audio_player: AudioStreamPlayer = %AudioPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	if close_button:
		close_button.pressed.connect(close_menu)
	
	_setup_audio()
	_connect_signals()
	refresh_menu()


func _setup_audio() -> void:
	if not audio_player:
		audio_player = AudioStreamPlayer.new()
		audio_player.name = "AudioPlayer"
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = 22050
		gen.buffer_length = 0.1
		audio_player.stream = gen
		add_child(audio_player)


func _connect_signals() -> void:
	var cm = get_node_or_null("/root/ConstructionManager")
	if cm:
		if cm.has_signal("structure_placed") and not cm.is_connected("structure_placed", _on_structure_placed):
			cm.connect("structure_placed", _on_structure_placed)
	
	var inv = get_node_or_null("/root/InventoryManager")
	if inv:
		if inv.has_signal("inventory_changed") and not inv.is_connected("inventory_changed", _on_inventory_changed):
			inv.connect("inventory_changed", _on_inventory_changed)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_B:
			toggle_menu()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and visible:
			close_menu()
			get_viewport().set_input_as_handled()


func toggle_menu() -> void:
	if visible:
		close_menu()
	else:
		open_menu()


func open_menu() -> void:
	visible = true
	refresh_menu()
	_play_tone(440.0)
	menu_opened.emit()


func close_menu() -> void:
	visible = false
	_play_tone(330.0)
	menu_closed.emit()


func _on_structure_placed(_id: String, _pos: Vector2i, _node: Node2D) -> void:
	if visible:
		refresh_menu()


func _on_inventory_changed() -> void:
	if visible:
		refresh_menu()


func refresh_menu() -> void:
	if not structures_container:
		return
	
	# Clear rows
	for child in structures_container.get_children():
		child.queue_free()
	
	var cm = get_node_or_null("/root/ConstructionManager")
	if not cm:
		return
	
	var catalog: Dictionary = cm.call("get_catalog")
	var avail_res: Dictionary = cm.call("get_available_resources")
	
	if build_zone_info_label:
		var bz: Rect2i = cm.call("get_build_zone")
		build_zone_info_label.text = "Authorized Base Sector: [%d,%d] to [%d,%d] (Perimeter Clearance Enforced)" % [
			bz.position.x, bz.position.y, bz.end.x, bz.end.y
		]
	
	for struct_id in catalog:
		var s_data: RefCounted = catalog[struct_id]
		var card := _create_structure_card(s_data, avail_res, cm)
		structures_container.add_child(card)


func _create_structure_card(s_data: RefCounted, avail_res: Dictionary, cm: Node) -> PanelContainer:
	var panel := PanelContainer.new()
	var s_id: String = str(s_data.get("id"))
	var cost: Dictionary = s_data.get("cost")
	
	# Check affordability
	var can_afford := true
	for r in cost:
		if int(avail_res.get(r, 0)) < int(cost[r]):
			can_afford = false
			break
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.09, 0.14, 0.94) if can_afford else Color(0.04, 0.06, 0.09, 0.85)
	style.set_border_width_all(1)
	style.border_color = Color(0.2, 0.85, 1.0, 0.8) if can_afford else Color(0.3, 0.35, 0.45, 0.5)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)
	
	# Header Row: Icon + Name + Size/Spacing badge + Build Button
	var header_hbox := HBoxContainer.new()
	vbox.add_child(header_hbox)
	
	var icon_lbl := Label.new()
	icon_lbl.text = str(s_data.get("icon"))
	header_hbox.add_child(icon_lbl)
	
	var name_lbl := Label.new()
	name_lbl.text = str(s_data.get("name"))
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.modulate = Color(0.2, 0.85, 1.0) if can_afford else Color(0.7, 0.75, 0.8)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(name_lbl)
	
	var spec_lbl := Label.new()
	spec_lbl.text = "[%dx%d | Spacing: %d]" % [s_data.get("width"), s_data.get("height"), s_data.get("min_spacing")]
	spec_lbl.add_theme_font_size_override("font_size", 10)
	spec_lbl.modulate = Color(0.95, 0.8, 0.25)
	header_hbox.add_child(spec_lbl)
	
	var build_btn := Button.new()
	build_btn.text = "CONSTRUCT"
	build_btn.custom_minimum_size = Vector2(85, 24)
	build_btn.add_theme_font_size_override("font_size", 10)
	build_btn.disabled = not can_afford
	build_btn.pressed.connect(func():
		close_menu()
		cm.call("start_placement_preview", s_id)
		structure_selected_for_placement.emit(s_id)
	)
	header_hbox.add_child(build_btn)
	
	# Description
	var desc_lbl := Label.new()
	desc_lbl.text = str(s_data.get("description"))
	desc_lbl.add_theme_font_size_override("font_size", 9)
	desc_lbl.modulate = Color(0.65, 0.7, 0.8)
	vbox.add_child(desc_lbl)
	
	# Cost Row
	var cost_hbox := HBoxContainer.new()
	cost_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(cost_hbox)
	
	for res_key in cost:
		var needed: int = int(cost[res_key])
		var current: int = int(avail_res.get(res_key, 0))
		var is_satisfied := current >= needed
		
		var badge := Label.new()
		badge.text = "%s: %d/%d %s" % [res_key.capitalize(), current, needed, "✓" if is_satisfied else "✕"]
		badge.add_theme_font_size_override("font_size", 9)
		badge.modulate = Color(0.2, 0.95, 0.6) if is_satisfied else Color(1.0, 0.45, 0.45)
		cost_hbox.add_child(badge)
		
	return panel


func _play_tone(freq: float) -> void:
	if not audio_player or not audio_player.stream is AudioStreamGenerator:
		return
	if not audio_player.playing:
		audio_player.play()
	var pb = audio_player.get_stream_playback()
	if pb:
		var frames: int = pb.get_frames_available()
		var n := mini(frames, 350)
		for i in n:
			var s := sin(float(i) * (freq / 22050.0) * TAU) * 0.18 * (1.0 - float(i) / float(n))
			pb.push_frame(Vector2(s, s))
