extends PanelContainer
## Modern Sci-Fi Inventory and Crafting UI for BioSphere-X.
## Displays carried items, stack counts, consumable USE actions, and fabrication workbench.
## Updates dynamically and synchronously on item collection, consumption, and fabrication.

signal dialog_opened()
signal dialog_closed()

# Node References
@onready var close_button: Button = %CloseButton
@onready var inventory_tab_btn: Button = %InventoryTabButton
@onready var crafting_tab_btn: Button = %CraftingTabButton
@onready var items_container: VBoxContainer = %ItemsContainer
@onready var recipes_container: VBoxContainer = %RecipesContainer
@onready var feedback_status_label: Label = %FeedbackStatusLabel
@onready var suit_summary_label: Label = %SuitSummaryLabel
@onready var audio_player: AudioStreamPlayer = %AudioPlayer

var _feedback_timer: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	if close_button:
		close_button.pressed.connect(close_dialog)
	
	_setup_audio()
	_connect_inventory_signals()
	refresh_display()


func _setup_audio() -> void:
	if not audio_player:
		audio_player = AudioStreamPlayer.new()
		audio_player.name = "AudioPlayer"
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = 22050
		gen.buffer_length = 0.1
		audio_player.stream = gen
		add_child(audio_player)


func _connect_inventory_signals() -> void:
	var inv = get_node_or_null("/root/InventoryManager")
	if inv:
		if inv.has_signal("inventory_changed") and not inv.is_connected("inventory_changed", _on_inventory_changed):
			inv.connect("inventory_changed", _on_inventory_changed)
		if inv.has_signal("item_crafted") and not inv.is_connected("item_crafted", _on_item_crafted):
			inv.connect("item_crafted", _on_item_crafted)
		if inv.has_signal("crafting_failed") and not inv.is_connected("crafting_failed", _on_crafting_failed):
			inv.connect("crafting_failed", _on_crafting_failed)
		if inv.has_signal("item_used") and not inv.is_connected("item_used", _on_item_used):
			inv.connect("item_used", _on_item_used)


func _process(delta: float) -> void:
	if _feedback_timer > 0.0:
		_feedback_timer = maxf(0.0, _feedback_timer - delta)
		if _feedback_timer <= 0.0 and feedback_status_label:
			feedback_status_label.text = "System Ready. Press [I] to Toggle."
			feedback_status_label.modulate = Color(0.6, 0.75, 0.85)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_I or event.keycode == KEY_TAB:
			toggle_visibility()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and visible:
			close_dialog()
			get_viewport().set_input_as_handled()


func toggle_visibility() -> void:
	if visible:
		close_dialog()
	else:
		open_dialog()


func open_dialog() -> void:
	visible = true
	refresh_display()
	_play_ui_tone(440.0)
	dialog_opened.emit()


func close_dialog() -> void:
	visible = false
	_play_ui_tone(330.0)
	dialog_closed.emit()


# ---------------------------------------------------------------------------
# Dynamic UI Refresh
# ---------------------------------------------------------------------------
func refresh_display() -> void:
	_refresh_inventory_column()
	_refresh_crafting_column()


func _on_inventory_changed() -> void:
	if visible:
		refresh_display()


func _on_item_crafted(recipe_id: String, result_id: String, qty: int) -> void:
	var inv = get_node_or_null("/root/InventoryManager")
	var item_def = inv.call("get_item_definition", result_id) if inv else null
	var item_name: String = item_def.get("name") if item_def else result_id
	show_feedback("✓ FABRICATION COMPLETE: +%d %s" % [qty, item_name], Color(0.2, 1.0, 0.6))
	_play_craft_tone()
	refresh_display()


func _on_crafting_failed(_recipe_id: String, reason: String) -> void:
	show_feedback("✕ FABRICATION FAILED: %s" % reason, Color(1.0, 0.35, 0.35))
	_play_ui_tone(220.0)


func _on_item_used(item_id: String, data: Dictionary) -> void:
	var item_name: String = str(data.get("name", item_id))
	show_feedback("► CONSUMED: %s" % item_name, Color(0.2, 0.85, 1.0))
	_play_ui_tone(580.0)
	refresh_display()


func show_feedback(text: String, col: Color = Color.WHITE) -> void:
	if feedback_status_label:
		feedback_status_label.text = text
		feedback_status_label.modulate = col
		_feedback_timer = 3.5


# ---------------------------------------------------------------------------
# Inventory List Column
# ---------------------------------------------------------------------------
func _refresh_inventory_column() -> void:
	if not items_container:
		return
	
	# Clear existing rows
	for child in items_container.get_children():
		child.queue_free()
	
	var inv = get_node_or_null("/root/InventoryManager")
	if not inv:
		return
	
	var all_items: Dictionary = inv.call("get_all_items")
	var total_items_count := 0
	
	for item_id in all_items:
		var qty: int = int(all_items[item_id])
		if qty <= 0:
			continue
		
		total_items_count += qty
		var item_def = inv.call("get_item_definition", item_id)
		var row := _create_item_row(item_id, qty, item_def)
		items_container.add_child(row)
	
	if total_items_count == 0:
		var empty_label := Label.new()
		empty_label.text = "No cargo carried on suit.\nCollect resources or craft items."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.modulate = Color(0.6, 0.65, 0.75)
		items_container.add_child(empty_label)
	
	if suit_summary_label:
		suit_summary_label.text = "Carried Cargo: %d Items" % total_items_count


func _create_item_row(item_id: String, qty: int, item_def: RefCounted) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.18, 0.9)
	style.set_border_width_all(1)
	style.border_color = Color(0.2, 0.45, 0.65, 0.7)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)
	
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	panel.add_child(hbox)
	
	# Icon
	var icon_lbl := Label.new()
	icon_lbl.text = item_def.get("icon") if item_def else "📦"
	icon_lbl.custom_minimum_size = Vector2(24, 0)
	hbox.add_child(icon_lbl)
	
	# Name & Category
	var vbox_text := VBoxContainer.new()
	vbox_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox_text)
	
	var name_lbl := Label.new()
	name_lbl.text = item_def.get("name") if item_def else item_id
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.modulate = Color(0.9, 0.95, 1.0)
	vbox_text.add_child(name_lbl)
	
	var cat_lbl := Label.new()
	cat_lbl.text = item_def.call("get_category_name") if item_def else "Item"
	cat_lbl.add_theme_font_size_override("font_size", 9)
	cat_lbl.modulate = Color(0.55, 0.75, 0.9)
	vbox_text.add_child(cat_lbl)
	
	# Quantity / Max Stack
	var max_stk: int = int(item_def.get("max_stack")) if item_def else 99
	var qty_lbl := Label.new()
	qty_lbl.text = "%d / %d" % [qty, max_stk]
	qty_lbl.add_theme_font_size_override("font_size", 11)
	qty_lbl.modulate = Color(0.95, 0.8, 0.25)
	hbox.add_child(qty_lbl)
	
	# Use Button for consumables & upgrades
	if item_def and bool(item_def.call("is_consumable")):
		var use_btn := Button.new()
		use_btn.text = "USE"
		use_btn.custom_minimum_size = Vector2(48, 22)
		use_btn.add_theme_font_size_override("font_size", 10)
		var can_use: bool = bool(item_def.call("can_use"))
		use_btn.disabled = not can_use
		use_btn.pressed.connect(func():
			var inv = get_node_or_null("/root/InventoryManager")
			if inv:
				inv.call("use_item", item_id)
		)
		hbox.add_child(use_btn)
	
	return panel


# ---------------------------------------------------------------------------
# Crafting Column
# ---------------------------------------------------------------------------
func _refresh_crafting_column() -> void:
	if not recipes_container:
		return
	
	# Clear existing cards
	for child in recipes_container.get_children():
		child.queue_free()
	
	var inv = get_node_or_null("/root/InventoryManager")
	if not inv:
		return
	
	var all_recipes: Array = inv.call("get_all_recipes")
	for recipe in all_recipes:
		var card := _create_recipe_card(recipe, inv)
		recipes_container.add_child(card)


func _create_recipe_card(recipe: RefCounted, inv: Node) -> PanelContainer:
	var panel := PanelContainer.new()
	var can_craft: bool = bool(recipe.call("can_craft", inv))
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.09, 0.14, 0.92) if can_craft else Color(0.04, 0.06, 0.09, 0.85)
	style.set_border_width_all(1)
	style.border_color = Color(0.2, 0.85, 1.0, 0.8) if can_craft else Color(0.3, 0.35, 0.45, 0.5)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)
	
	# Header Row: Icon + Name + Quantity
	var header_hbox := HBoxContainer.new()
	vbox.add_child(header_hbox)
	
	var res_id: String = recipe.get("result_item_id")
	var result_def = inv.call("get_item_definition", res_id)
	
	var icon_lbl := Label.new()
	icon_lbl.text = result_def.get("icon") if result_def else "🛠️"
	header_hbox.add_child(icon_lbl)
	
	var name_lbl := Label.new()
	name_lbl.text = "%s (x%d)" % [recipe.get("name"), recipe.get("result_quantity")]
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.modulate = Color(0.2, 0.85, 1.0) if can_craft else Color(0.8, 0.85, 0.9)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(name_lbl)
	
	# Craft Button
	var craft_btn := Button.new()
	craft_btn.text = "FABRICATE"
	craft_btn.custom_minimum_size = Vector2(80, 24)
	craft_btn.add_theme_font_size_override("font_size", 10)
	craft_btn.disabled = not can_craft
	var r_id: String = recipe.get("recipe_id")
	craft_btn.pressed.connect(func():
		inv.call("craft_item", r_id)
	)
	header_hbox.add_child(craft_btn)
	
	# Description
	var desc_lbl := Label.new()
	desc_lbl.text = recipe.get("description")
	desc_lbl.add_theme_font_size_override("font_size", 9)
	desc_lbl.modulate = Color(0.65, 0.7, 0.8)
	vbox.add_child(desc_lbl)
	
	# Requirements line
	var reqs_hbox := HBoxContainer.new()
	reqs_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(reqs_hbox)
	
	var ingredients: Dictionary = recipe.get("ingredients")
	for ing_id in ingredients:
		var req_qty: int = int(ingredients[ing_id])
		var cur_qty: int = int(inv.call("get_item_count", ing_id))
		var ing_def = inv.call("get_item_definition", ing_id)
		var ing_name: String = ing_def.get("name") if ing_def else ing_id
		
		var ing_badge := Label.new()
		var is_satisfied := cur_qty >= req_qty
		ing_badge.text = "%s: %d/%d %s" % [ing_name, cur_qty, req_qty, "✓" if is_satisfied else "✕"]
		ing_badge.add_theme_font_size_override("font_size", 9)
		ing_badge.modulate = Color(0.2, 0.95, 0.6) if is_satisfied else Color(1.0, 0.45, 0.45)
		reqs_hbox.add_child(ing_badge)
	
	return panel


# ---------------------------------------------------------------------------
# Procedural Audio Synthesis
# ---------------------------------------------------------------------------
func _play_ui_tone(freq: float) -> void:
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


func _play_craft_tone() -> void:
	if not audio_player or not audio_player.stream is AudioStreamGenerator:
		return
	if not audio_player.playing:
		audio_player.play()
	var pb = audio_player.get_stream_playback()
	if pb:
		var frames: int = pb.get_frames_available()
		var n := mini(frames, 600)
		for i in n:
			var step_freq := 0.25 if i < 200 else (0.35 if i < 400 else 0.50)
			var s := sin(float(i) * step_freq) * 0.22 * (1.0 - float(i) / float(n))
			pb.push_frame(Vector2(s, s))
