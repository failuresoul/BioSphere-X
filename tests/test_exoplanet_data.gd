extends Node
## Automated Test Suite for Exoplanet Data, Provenance, and Scientific Mapping (Prompt 24).
## Validates:
##   1. NASA Exoplanet Archive inspired local data file structure, provenance, and retrieval date.
##   2. Preservation of authentic scientific source units (pc, days, R_earth, M_earth, K, eccentricity).
##   3. Missing value validation (unmeasured mass, non-transiting radius, null values).
##   4. Strict compliance with scientific integrity caveats:
##      - Equilibrium temp != confirmed surface temp
##      - Radius != sufficient for gravity
##      - Eccentricity != direct day/night rotation cycle
##   5. Clearly labeled fictional gameplay property mappings (Hazard, Visibility, Resources, Thermal).
##   6. Graceful degradation: Fallback dataset when file is missing or damaged.
##   7. Selection event bus and GameState synchronization.
##   8. PlanetSelectionScreen UI lifecycle and interaction.

const PlanetSelectionScreenScene := preload("res://ui/screens/planet_selection_screen.tscn")

var _test_count: int = 0
var _pass_count: int = 0


func _ready() -> void:
	print("==================================================")
	print("  BIOSPHERE-X: EXOPLANET DATA & SCIENTIFIC MAPPING")
	print("==================================================")
	
	test_provenance_and_metadata()
	test_source_units_preservation()
	test_missing_values_validation()
	test_scientific_caveats_enforcement()
	test_fictional_gameplay_mapping()
	test_fallback_dataset_on_missing_file()
	test_planet_selection_and_gamestate_sync()
	test_ui_screen_lifecycle_and_interaction()
	
	print("==================================================")
	print("  ALL EXOPLANET DATA TESTS PASSED! [%d/%d]" % [_pass_count, _test_count])
	print("==================================================")
	get_tree().quit(0)


func _assert_test(condition: bool, test_name: String, error_msg: String = "") -> void:
	_test_count += 1
	if condition:
		_pass_count += 1
	else:
		push_error("FAILED: %s -> %s" % [test_name, error_msg])
		assert(condition, "%s: %s" % [test_name, error_msg])


# ---------------------------------------------------------------------------
# Test 1: Provenance, Metadata, and Retrieval Date
# ---------------------------------------------------------------------------
func test_provenance_and_metadata() -> void:
	print("[TEST 1/8] Testing NASA Exoplanet Archive Provenance & Metadata...")
	var db = get_node("/root/ExoplanetDatabase")
	db.load_database("res://data/exoplanets.json")
	
	_assert_test(not db.is_using_fallback, "Loaded real JSON data file, not fallback", "Expected real JSON data")
	_assert_test(db.get_all_planets().size() >= 7, "Contains at least 7 curated exoplanets", "Count was %d" % db.get_all_planets().size())
	
	var meta: Dictionary = db.metadata
	_assert_test(meta.has("source"), "Metadata has source documentation", "Missing source")
	_assert_test(meta.get("source").contains("NASA Exoplanet Archive"), "Source specifies NASA Exoplanet Archive", "Source: %s" % meta.get("source"))
	_assert_test(meta.has("retrieval_date"), "Metadata has retrieval_date", "Missing retrieval_date")
	_assert_test(not str(meta.get("retrieval_date")).is_empty(), "Retrieval date is populated", "Empty retrieval date")
	_assert_test(meta.has("scientific_caveats"), "Metadata documents scientific caveats", "Missing caveats")
	_assert_test(meta.get("scientific_caveats").size() >= 3, "Contains at least 3 scientific caveats", "Caveat count mismatch")
	_assert_test(meta.has("units"), "Metadata documents scientific units dictionary", "Missing units schema")


# ---------------------------------------------------------------------------
# Test 2: Source Units Preservation
# ---------------------------------------------------------------------------
func test_source_units_preservation() -> void:
	print("[TEST 2/8] Testing Authentic Scientific Source Units Preservation...")
	var db = get_node("/root/ExoplanetDatabase")
	var trap: Dictionary = db.get_planet("trappist_1_e")
	
	_assert_test(not trap.is_empty(), "TRAPPIST-1 e record exists", "TRAPPIST-1 e missing")
	_assert_test(is_equal_approx(float(trap.get("pl_orbper")), 6.099615), "pl_orbper preserved in days (~6.10 days)", "Period: %s" % trap.get("pl_orbper"))
	_assert_test(is_equal_approx(float(trap.get("pl_rade")), 0.920), "pl_rade preserved in Earth Radii (0.920 R⊕)", "Radius: %s" % trap.get("pl_rade"))
	_assert_test(is_equal_approx(float(trap.get("pl_bmasse")), 0.692), "pl_bmasse preserved in Earth Mass (0.692 M⊕)", "Mass: %s" % trap.get("pl_bmasse"))
	_assert_test(is_equal_approx(float(trap.get("pl_eqt")), 251.0), "pl_eqt preserved in Kelvin (251.0 K)", "Eq Temp: %s" % trap.get("pl_eqt"))
	_assert_test(is_equal_approx(float(trap.get("sy_dist")), 12.47), "sy_dist preserved in parsecs (12.47 pc)", "Distance: %s" % trap.get("sy_dist"))
	_assert_test(is_equal_approx(float(trap.get("st_teff")), 2566.0), "st_teff preserved in Kelvin (2566 K)", "Teff: %s" % trap.get("st_teff"))


# ---------------------------------------------------------------------------
# Test 3: Missing Value Validation & Graceful Null Handling
# ---------------------------------------------------------------------------
func test_missing_values_validation() -> void:
	print("[TEST 3/8] Testing Missing Values and Unmeasured Field Validation...")
	var db = get_node("/root/ExoplanetDatabase")
	
	# Kepler-186 f has unmeasured mass (pl_bmasse: null)
	var kep: Dictionary = db.get_planet("kepler_186_f")
	_assert_test(not kep.is_empty(), "Kepler-186 f record exists", "Missing Kepler-186 f")
	_assert_test(kep.get("pl_bmasse") == null, "Kepler-186 f mass is null (unmeasured by RV/TTV)", "Mass should be null")
	_assert_test(not kep.get("has_mass"), "has_mass flag is false for Kepler-186 f", "Expected false has_mass")
	_assert_test(kep.get("has_radius"), "has_radius flag is true for Kepler-186 f", "Expected true has_radius")
	
	# Proxima Centauri b is non-transiting (pl_rade: null)
	var prox: Dictionary = db.get_planet("proxima_centauri_b")
	_assert_test(not prox.is_empty(), "Proxima Centauri b record exists", "Missing Proxima Centauri b")
	_assert_test(prox.get("pl_rade") == null, "Proxima Centauri b radius is null (non-transiting)", "Radius should be null")
	_assert_test(not prox.get("has_radius"), "has_radius flag is false for Proxima Centauri b", "Expected false has_radius")
	_assert_test(prox.get("has_mass"), "has_mass flag is true for Proxima Centauri b (Doppler mass)", "Expected true has_mass")
	
	# TOI-700 d has unmeasured mass
	var toi: Dictionary = db.get_planet("toi_700_d")
	_assert_test(toi.get("pl_bmasse") == null, "TOI-700 d mass is null", "Mass should be null")


# ---------------------------------------------------------------------------
# Test 4: Scientific Integrity Caveats Enforcement
# ---------------------------------------------------------------------------
func test_scientific_caveats_enforcement() -> void:
	print("[TEST 4/8] Testing Strict Scientific Caveat Enforcement...")
	var db = get_node("/root/ExoplanetDatabase")
	
	# Caveat 1: Equilibrium temperature is NOT surface temperature
	var trap = db.get_planet("trappist_1_e")
	var trap_props = db.compute_gameplay_properties(trap)
	var temp_caveat: String = trap_props.get("scientific_caveat_temperature", "")
	_assert_test(temp_caveat.contains("theoretical") or temp_caveat.contains("Theoretical"), "Temp caveat mentions theoretical nature", "Caveat was: %s" % temp_caveat)
	_assert_test(temp_caveat.contains("surface temperature is unconfirmed"), "Temp caveat confirms surface temp is unconfirmed", "Caveat was: %s" % temp_caveat)
	_assert_test(temp_caveat.contains("greenhouse"), "Temp caveat highlights atmospheric greenhouse effect", "Caveat was: %s" % temp_caveat)
	
	# Caveat 2: Planet radius is NOT sufficient to calculate gravity
	var kep = db.get_planet("kepler_186_f") # mass is null
	var kep_props = db.compute_gameplay_properties(kep)
	var grav_caveat_kep: String = kep_props.get("scientific_caveat_gravity", "")
	_assert_test(grav_caveat_kep.contains("UNCONFIRMED"), "Kepler-186 f gravity flagged as UNCONFIRMED", "Caveat: %s" % grav_caveat_kep)
	_assert_test(grav_caveat_kep.contains("radius alone is insufficient"), "Explicitly notes radius alone is insufficient", "Caveat: %s" % grav_caveat_kep)
	
	# When mass IS known (LHS 1140 b), gravity is labeled as derived bulk estimate
	var lhs = db.get_planet("lhs_1140_b")
	var lhs_props = db.compute_gameplay_properties(lhs)
	var grav_caveat_lhs: String = lhs_props.get("scientific_caveat_gravity", "")
	_assert_test(grav_caveat_lhs.contains("Derived Bulk Acceleration"), "LHS 1140 b provides derived bulk estimate", "Caveat: %s" % grav_caveat_lhs)
	_assert_test(grav_caveat_lhs.contains("unmodeled interior"), "Notes dependence on interior distribution", "Caveat: %s" % grav_caveat_lhs)
	
	# Caveat 3: Orbital eccentricity is NOT diurnal day/night cycle
	var ecc_caveat: String = trap_props.get("scientific_caveat_day_night", "")
	_assert_test(ecc_caveat.contains("seasonal") or ecc_caveat.contains("elongation"), "Eccentricity caveat notes seasonal/orbital elongation", "Caveat: %s" % ecc_caveat)
	_assert_test(ecc_caveat.contains("NOT a direct day/night"), "Explicitly denies direct day/night rotation measurement", "Caveat: %s" % ecc_caveat)


# ---------------------------------------------------------------------------
# Test 5: Clearly Labeled Fictional Gameplay Mapping
# ---------------------------------------------------------------------------
func test_fictional_gameplay_mapping() -> void:
	print("[TEST 5/8] Testing Fictional Gameplay Properties Mapping...")
	var db = get_node("/root/ExoplanetDatabase")
	
	# Extreme hot Jupiter: WASP-12 b (T_eq ~2575 K, P ~1.09 days, T_eff 6300 K)
	var wasp = db.get_planet("wasp_12_b")
	var wasp_props = db.compute_gameplay_properties(wasp)
	_assert_test(wasp_props.get("gameplay_hazard_level") == "LETHAL", "WASP-12 b hazard level is LETHAL", "Hazard: %s" % wasp_props.get("gameplay_hazard_level"))
	_assert_test(wasp_props.get("gameplay_visibility").contains("High Daylight"), "WASP-12 b visibility is High Daylight (F6 V star)", "Vis: %s" % wasp_props.get("gameplay_visibility"))
	_assert_test(wasp_props.get("gameplay_thermal_effect").contains("Hyperthermal"), "WASP-12 b thermal effect is Hyperthermal", "Thermal: %s" % wasp_props.get("gameplay_thermal_effect"))
	_assert_test(float(wasp_props.get("gameplay_thermal_drain_modifier")) >= 2.0, "WASP-12 b thermal drain modifier >= 2.0", "Modifier: %s" % wasp_props.get("gameplay_thermal_drain_modifier"))
	
	# Cold candidate: Kepler-186 f (T_eq 188 K)
	var kep = db.get_planet("kepler_186_f")
	var kep_props = db.compute_gameplay_properties(kep)
	_assert_test(kep_props.get("gameplay_hazard_level") == "ELEVATED", "Kepler-186 f hazard is ELEVATED (Cryogenic)", "Hazard: %s" % kep_props.get("gameplay_hazard_level"))
	_assert_test(kep_props.get("gameplay_thermal_effect").contains("Cryogenic"), "Kepler-186 f thermal effect is Cryogenic", "Thermal: %s" % kep_props.get("gameplay_thermal_effect"))
	
	# Moderate candidate: TRAPPIST-1 e (T_eq 251 K)
	var trap = db.get_planet("trappist_1_e")
	var trap_props = db.compute_gameplay_properties(trap)
	_assert_test(trap_props.get("gameplay_hazard_level") == "MODERATE", "TRAPPIST-1 e hazard is MODERATE", "Hazard: %s" % trap_props.get("gameplay_hazard_level"))
	_assert_test(trap_props.get("gameplay_visibility").contains("Infrared") or trap_props.get("gameplay_visibility").contains("Crimson"), "TRAPPIST-1 e visibility reflects ultra-cool M-dwarf spectrum", "Vis: %s" % trap_props.get("gameplay_visibility"))


# ---------------------------------------------------------------------------
# Test 6: Fallback Dataset Activation on Missing File
# ---------------------------------------------------------------------------
func test_fallback_dataset_on_missing_file() -> void:
	print("[TEST 6/8] Testing Graceful Fallback Dataset on Missing Data File...")
	var db = get_node("/root/ExoplanetDatabase")
	
	# Load intentionally non-existent file
	var ok_fake: bool = db.load_database("res://data/completely_missing_nonexistent_file_xyz.json")
	_assert_test(not ok_fake, "Loading missing file returns false", "Expected false on missing file")
	_assert_test(db.is_using_fallback, "is_using_fallback is true", "Fallback was not active")
	_assert_test(db.get_all_planets().size() >= 5, "Fallback archive contains at least 5 planets", "Count was %d" % db.get_all_planets().size())
	_assert_test(db.data_source_label.contains("Fallback"), "Data source label clearly states Fallback Dataset", "Label: %s" % db.data_source_label)
	
	# Querying planets still works flawlessly in fallback mode
	var fallback_trap = db.get_planet("trappist_1_e")
	_assert_test(not fallback_trap.is_empty(), "TRAPPIST-1 e is available in fallback dataset", "Missing in fallback")
	var fb_props = db.compute_gameplay_properties(fallback_trap)
	_assert_test(fb_props.get("gameplay_hazard_level") == "MODERATE", "Fallback properties computed properly", "Failed fallback mapping")
	
	# Restore normal database for remaining tests
	var ok_restore: bool = db.load_database("res://data/exoplanets.json")
	_assert_test(ok_restore, "Restored normal database successfully", "Failed to restore database")
	_assert_test(not db.is_using_fallback, "is_using_fallback is false after restore", "Still using fallback")


# ---------------------------------------------------------------------------
# Test 7: Planet Selection and GameState Synchronization
# ---------------------------------------------------------------------------
func test_planet_selection_and_gamestate_sync() -> void:
	print("[TEST 7/8] Testing Planet Selection Event Bus and GameState Sync...")
	var db = get_node("/root/ExoplanetDatabase")
	var gs = get_node("/root/GameState")
	
	var signal_received := {"emitted": false, "planet_id": "", "name": ""}
	var conn = db.planet_selected.connect(func(p_id, p_data, _props):
		signal_received["emitted"] = true
		signal_received["planet_id"] = p_id
		signal_received["name"] = p_data.get("pl_name", "")
	, CONNECT_ONE_SHOT)
	
	var select_ok: bool = db.select_planet("lhs_1140_b")
	_assert_test(select_ok, "select_planet('lhs_1140_b') returned true", "Selection failed")
	_assert_test(signal_received["emitted"], "planet_selected signal emitted", "Signal not emitted")
	_assert_test(signal_received["planet_id"] == "lhs_1140_b", "Emitted planet ID matches lhs_1140_b", "ID mismatch")
	_assert_test(db.selected_planet_id == "lhs_1140_b", "db.selected_planet_id updated", "ID mismatch")
	_assert_test(gs.selected_planet == "LHS 1140 b", "GameState.selected_planet synchronized", "GameState mismatch: %s" % gs.selected_planet)
	
	# Selection of non-existent planet fails safely
	var invalid_sel: bool = db.select_planet("planet_nemesis_fake_99")
	_assert_test(not invalid_sel, "Selecting invalid planet returns false safely", "Expected false")


# ---------------------------------------------------------------------------
# Test 8: PlanetSelectionScreen UI Lifecycle and Interaction
# ---------------------------------------------------------------------------
func test_ui_screen_lifecycle_and_interaction() -> void:
	print("[TEST 8/8] Testing PlanetSelectionScreen UI Lifecycle & Interactions...")
	var screen = PlanetSelectionScreenScene.instantiate()
	add_child(screen)
	
	_assert_test(not screen.visible, "Screen initially hidden", "Screen should start hidden")
	
	# Open screen
	var state := {"opened": false, "closed": false}
	screen.screen_opened.connect(func(): state["opened"] = true)
	screen.open_screen()
	_assert_test(screen.visible, "Screen is visible after open_screen()", "Screen not visible")
	_assert_test(state["opened"], "screen_opened signal emitted", "Missing opened signal")
	
	# Test planet list container populated
	var list_container: VBoxContainer = screen.get_node("%PlanetListContainer")
	_assert_test(list_container != null, "PlanetListContainer exists in UI", "Missing list container")
	_assert_test(list_container.get_child_count() >= 7, "UI list has at least 7 planet buttons", "Child count: %d" % list_container.get_child_count())
	
	# Test scientific labels populated
	var p_name_label: Label = screen.get_node("%PlanetNameLabel")
	var sci_params: RichTextLabel = screen.get_node("%ScientificParamsLabel")
	var sci_caveats: RichTextLabel = screen.get_node("%ScientificCaveatsLabel")
	var game_props: RichTextLabel = screen.get_node("%GameplayPropsLabel")
	
	_assert_test(p_name_label != null and not p_name_label.text.is_empty(), "PlanetNameLabel populated", "Empty planet name")
	_assert_test(sci_params != null and sci_params.text.contains("OBSERVED SCIENTIFIC PARAMETERS"), "Scientific params label has content", "Empty sci params")
	_assert_test(sci_caveats != null and sci_caveats.text.contains("SCIENTIFIC INTERPRETATION SAFEGUARDS"), "Scientific caveats label has safeguards", "Empty caveats")
	_assert_test(game_props != null and game_props.text.contains("FICTIONAL GAMEPLAY PROPERTIES"), "Gameplay props label has fictional properties", "Empty gameplay props")
	
	# Test Deploy / Confirm destination
	var confirmed := {"emitted": false, "id": "", "name": ""}
	screen.destination_confirmed.connect(func(p_id, p_name):
		confirmed["emitted"] = true
		confirmed["id"] = p_id
		confirmed["name"] = p_name
	)
	var deploy_btn: Button = screen.get_node("%DeployButton")
	_assert_test(deploy_btn != null, "DeployButton exists in UI", "Missing deploy button")
	deploy_btn.emit_signal("pressed")
	_assert_test(confirmed["emitted"], "destination_confirmed signal emitted", "Missing confirmed signal")
	
	# Close screen
	screen.screen_closed.connect(func(): state["closed"] = true)
	screen.close_screen()
	_assert_test(not screen.visible, "Screen is hidden after close_screen()", "Screen still visible")
	_assert_test(state["closed"], "screen_closed signal emitted", "Missing closed signal")
	
	remove_child(screen)
	screen.free()
