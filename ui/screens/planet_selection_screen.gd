extends Control
## Exoplanet Expedition Selection Screen for BioSphere-X.
## Displays verified scientific parameters inspired by NASA Exoplanet Archive data,
## enforces scientific integrity caveats, and maps observations to clearly labeled
## fictional gameplay properties (Hazard, Visibility, Resource Scarcity, Thermal Effects).

signal screen_opened()
signal screen_closed()
signal destination_confirmed(planet_id: String, planet_name: String)

@onready var close_button: Button = %CloseButton
@onready var deploy_button: Button = %DeployButton
@onready var planet_list_container: VBoxContainer = %PlanetListContainer
@onready var source_badge: Label = %SourceBadge
@onready var title_label: Label = %TitleLabel
@onready var planet_name_label: Label = %PlanetNameLabel
@onready var host_star_label: Label = %HostStarLabel
@onready var scientific_params_label: RichTextLabel = %ScientificParamsLabel
@onready var scientific_caveats_label: RichTextLabel = %ScientificCaveatsLabel
@onready var gameplay_props_label: RichTextLabel = %GameplayPropsLabel
@onready var feedback_label: Label = %FeedbackLabel

var _current_selected_id: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	if close_button:
		close_button.pressed.connect(close_screen)
	if deploy_button:
		deploy_button.pressed.connect(_on_deploy_pressed)
		
	var db = get_node_or_null("/root/ExoplanetDatabase")
	if db:
		if db.has_signal("database_loaded"):
			db.database_loaded.connect(_on_database_loaded)
		if db.has_signal("planet_selected"):
			db.planet_selected.connect(_on_planet_selected_externally)
			
	refresh_screen()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_P:
			toggle_screen()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and visible:
			close_screen()
			get_viewport().set_input_as_handled()


func open_screen() -> void:
	refresh_screen()
	visible = true
	screen_opened.emit()


func close_screen() -> void:
	visible = false
	screen_closed.emit()


func toggle_screen() -> void:
	if visible:
		close_screen()
	else:
		open_screen()


func refresh_screen() -> void:
	var db = get_node_or_null("/root/ExoplanetDatabase")
	if not db:
		return
		
	# Update source badge
	if source_badge:
		if bool(db.get("is_using_fallback")):
			source_badge.text = "MODE: BUILT-IN FALLBACK ARCHIVE (OFFLINE)"
			source_badge.modulate = Color(1.0, 0.7, 0.2)
		else:
			source_badge.text = "DATA SOURCE: %s" % db.get("data_source_label")
			source_badge.modulate = Color(0.2, 0.9, 0.6)
			
	_populate_planet_list()
	
	# Select currently active or first planet
	var current_id: String = db.get("selected_planet_id")
	if current_id.is_empty():
		var keys: Array = db.call("get_planet_keys")
		if not keys.is_empty():
			current_id = str(keys[0])
			
	if not current_id.is_empty():
		display_planet(current_id)


func _populate_planet_list() -> void:
	if not planet_list_container:
		return
		
	for child in planet_list_container.get_children():
		child.queue_free()
		
	var db = get_node_or_null("/root/ExoplanetDatabase")
	if not db:
		return
		
	var planets: Array = db.call("get_all_planets")
	for p in planets:
		var p_id: String = str(p.get("id"))
		var p_name: String = str(p.get("pl_name"))
		var dist = p.get("sy_dist")
		var dist_str := "%.1f pc" % float(dist) if dist != null else "Dist: Unmeasured"
		var method: String = str(p.get("discoverymethod", "Unknown"))
		
		var btn := Button.new()
		btn.text = "%s\n[%s | %s]" % [p_name, dist_str, method]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(230, 48)
		btn.add_theme_font_size_override("font_size", 12)
		
		# Button style
		btn.pressed.connect(func(): display_planet(p_id))
		planet_list_container.add_child(btn)


func display_planet(planet_id: String) -> void:
	var db = get_node_or_null("/root/ExoplanetDatabase")
	if not db:
		return
		
	var p: Dictionary = db.call("get_planet", planet_id)
	if p.is_empty():
		return
		
	_current_selected_id = planet_id
	var props: Dictionary = db.call("compute_gameplay_properties", p)
	
	# Header & Host
	if planet_name_label:
		planet_name_label.text = str(p.get("pl_name"))
	if host_star_label:
		var host: String = str(p.get("hostname"))
		var spectype: String = str(p.get("st_spectype", "Unknown"))
		var teff = p.get("st_teff")
		var teff_str := "%.0f K" % float(teff) if teff != null else "Unmeasured"
		host_star_label.text = "Host Star: %s | Spectral Type: %s | T_eff: %s" % [host, spectype, teff_str]
		
	# Available Scientific Parameters (Source Units Preserved)
	if scientific_params_label:
		var rad = p.get("pl_rade")
		var mass = p.get("pl_bmasse")
		var eqt = p.get("pl_eqt")
		var ecc = p.get("pl_orbeccen")
		var per = p.get("pl_orbper")
		var dist = p.get("sy_dist")
		
		var rad_str := "%.3f R⊕ (Earth Radii)" % float(rad) if rad != null else "[color=#e08040]Unmeasured (No transit observed)[/color]"
		var mass_str := "%.3f M⊕ (Earth Mass)" % float(mass) if mass != null else "[color=#e08040]Unmeasured (Radial Velocity / TTV required)[/color]"
		var eqt_str := "%.1f K (Theoretical Blackbody)" % float(eqt) if eqt != null else "[color=#e08040]Unmeasured[/color]"
		var ecc_str := "%.4f" % float(ecc) if ecc != null else "[color=#e08040]Unmeasured[/color]"
		var per_str := "%.4f days" % float(per) if per != null else "[color=#e08040]Unmeasured[/color]"
		var dist_str := "%.2f parsecs (%.2f ly)" % [float(dist), float(dist) * 3.26156] if dist != null else "[color=#e08040]Unmeasured[/color]"
		
		var text := "[b][u]OBSERVED SCIENTIFIC PARAMETERS (NASA Exoplanet Archive Units):[/u][/b]\n"
		text += "• [b]Discovery Method:[/b] %s (Discovered: %s)\n" % [p.get("discoverymethod"), str(p.get("disc_year"))]
		text += "• [b]Distance from Solar System (sy_dist):[/b] %s\n" % dist_str
		text += "• [b]Orbital Period (pl_orbper):[/b] %s\n" % per_str
		text += "• [b]Planet Radius (pl_rade):[/b] %s\n" % rad_str
		text += "• [b]Planet Mass (pl_bmasse):[/b] %s\n" % mass_str
		text += "• [b]Equilibrium Temperature (pl_eqt):[/b] %s\n" % eqt_str
		text += "• [b]Orbital Eccentricity (pl_orbeccen):[/b] %s\n" % ecc_str
		text += "• [b]Field Notes:[/b] %s" % str(p.get("notes"))
		scientific_params_label.text = text
		
	# Scientific Caveats (Explicit Required Scientific Safeguards)
	if scientific_caveats_label:
		var c_text := "[b][color=#ffcc00]⚠️ SCIENTIFIC INTERPRETATION SAFEGUARDS:[/color][/b]\n"
		c_text += "1. [b]Temperature Distinction:[/b] %s\n" % props.get("scientific_caveat_temperature")
		c_text += "2. [b]Gravity Distinction:[/b] %s\n" % props.get("scientific_caveat_gravity")
		c_text += "3. [b]Eccentricity Distinction:[/b] %s" % props.get("scientific_caveat_day_night")
		scientific_caveats_label.text = c_text
		
	# Clearly Labeled Fictional Gameplay Properties
	if gameplay_props_label:
		var haz: String = str(props.get("gameplay_hazard_level"))
		var haz_color: Color = props.get("gameplay_hazard_color", Color.WHITE)
		var haz_hex := haz_color.to_html(false)
		
		var g_text := "[b][u]FICTIONAL GAMEPLAY PROPERTIES (Derived Approximation):[/u][/b]\n"
		g_text += "• [b]Expedition Hazard Level:[/b] [color=#%s][b][%s][/b][/color] — %s\n" % [
			haz_hex, haz, props.get("gameplay_hazard_reason")
		]
		g_text += "• [b]Sector Visibility & Lighting:[/b] %s (%s)\n" % [
			props.get("gameplay_visibility"), props.get("gameplay_visibility_desc")
		]
		g_text += "• [b]Resource Abundance & Yields:[/b] %s (%s)\n" % [
			props.get("gameplay_resource_scarcity"), props.get("gameplay_resource_desc")
		]
		g_text += "• [b]Suit Thermal Environment:[/b] %s" % props.get("gameplay_thermal_effect")
		gameplay_props_label.text = g_text
		
	if feedback_label:
		var db_sel = db.get("selected_planet_id")
		if db_sel == planet_id:
			feedback_label.text = "✓ CURRENTLY TARGETED EXPEDITION DESTINATION"
			feedback_label.modulate = Color(0.2, 1.0, 0.6)
		else:
			feedback_label.text = "Click 'Set as Destination' to lock planetary coordinates."
			feedback_label.modulate = Color(0.8, 0.8, 0.8)


func _on_deploy_pressed() -> void:
	if _current_selected_id.is_empty():
		return
	var db = get_node_or_null("/root/ExoplanetDatabase")
	if db:
		db.call("select_planet", _current_selected_id)
		var p = db.call("get_planet", _current_selected_id)
		var p_name = p.get("pl_name", _current_selected_id)
		if feedback_label:
			feedback_label.text = "✓ EXPEDITION DESTINATION LOCKED: %s!" % p_name
			feedback_label.modulate = Color(0.2, 1.0, 0.6)
		destination_confirmed.emit(_current_selected_id, p_name)


func _on_database_loaded(_count: int, _is_fallback: bool) -> void:
	refresh_screen()


func _on_planet_selected_externally(planet_id: String, _data: Dictionary, _props: Dictionary) -> void:
	if visible and planet_id != _current_selected_id:
		display_planet(planet_id)
