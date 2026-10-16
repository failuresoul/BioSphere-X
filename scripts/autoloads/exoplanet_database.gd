extends Node
## Central Exoplanet Database and Scientific-to-Gameplay Mapping Service for BioSphere-X.
## Loads curated exoplanet observations inspired by the NASA Exoplanet Archive (Planetary Systems Composite Parameters table).
## Preserves raw source units, validates missing fields, provides a reliable fallback dataset,
## and enforces scientific caveats preventing conflation of physical measurements.

signal database_loaded(planet_count: int, is_fallback: bool)
signal planet_selected(planet_id: String, planet_data: Dictionary, gameplay_properties: Dictionary)

const DEFAULT_DATA_PATH := "res://data/exoplanets.json"

# State
var is_using_fallback: bool = false
var data_source_label: String = ""
var metadata: Dictionary = {}
var _planets_by_id: Dictionary = {}
var _planet_keys: Array[String] = []
var selected_planet_id: String = ""

# ---------------------------------------------------------------------------
# Curated Built-in Fallback Dataset (Used when local data file is missing/damaged)
# ---------------------------------------------------------------------------
const FALLBACK_METADATA: Dictionary = {
	"source": "NASA Exoplanet Archive (Built-in Fallback Dataset)",
	"source_url": "https://exoplanetarchive.ipac.caltech.edu/",
	"retrieval_date": "2026-10-17",
	"description": "Hardcoded local fallback archive for BioSphere-X ensuring offline game operational continuity.",
	"scientific_caveats": [
		"Equilibrium temperature (pl_eqt) is a theoretical blackbody estimate, not confirmed surface temperature.",
		"Planet radius alone is insufficient to calculate gravity without confirmed mass measurement.",
		"Orbital eccentricity indicates orbital ellipse elongation, not diurnal day/night rotation."
	],
	"units": {
		"sy_dist": "parsecs (pc)",
		"pl_orbper": "days",
		"pl_rade": "Earth Radii (R_earth)",
		"pl_bmasse": "Earth Mass (M_earth)",
		"pl_eqt": "Kelvin (K)",
		"pl_orbeccen": "dimensionless (0.0 to 1.0)",
		"st_teff": "Kelvin (K)"
	}
}

const FALLBACK_PLANETS: Array[Dictionary] = [
	{
		"pl_name": "TRAPPIST-1 e",
		"hostname": "TRAPPIST-1",
		"discoverymethod": "Transit",
		"disc_year": 2017,
		"sy_dist": 12.47,
		"pl_orbper": 6.099615,
		"pl_rade": 0.920,
		"pl_bmasse": 0.692,
		"pl_eqt": 251.0,
		"pl_orbeccen": 0.0051,
		"st_teff": 2566.0,
		"st_spectype": "M8 V",
		"notes": "Earth-sized planet in habitable zone. Fallback archive copy."
	},
	{
		"pl_name": "Kepler-186 f",
		"hostname": "Kepler-186",
		"discoverymethod": "Transit",
		"disc_year": 2014,
		"sy_dist": 177.6,
		"pl_orbper": 129.9441,
		"pl_rade": 1.170,
		"pl_bmasse": null,
		"pl_eqt": 188.0,
		"pl_orbeccen": 0.04,
		"st_teff": 3755.0,
		"st_spectype": "M1 V",
		"notes": "Mass unmeasured by radial velocity or TTV; surface gravity unconfirmed."
	},
	{
		"pl_name": "Proxima Centauri b",
		"hostname": "Proxima Centauri",
		"discoverymethod": "Radial Velocity",
		"disc_year": 2016,
		"sy_dist": 1.301,
		"pl_orbper": 11.1868,
		"pl_rade": null,
		"pl_bmasse": 1.07,
		"pl_eqt": 234.0,
		"pl_orbeccen": 0.109,
		"st_teff": 3042.0,
		"st_spectype": "M5.5 V",
		"notes": "Non-transiting Doppler detection; geometric radius unmeasured."
	},
	{
		"pl_name": "LHS 1140 b",
		"hostname": "LHS 1140",
		"discoverymethod": "Transit",
		"disc_year": 2017,
		"sy_dist": 15.0,
		"pl_orbper": 24.737,
		"pl_rade": 1.730,
		"pl_bmasse": 5.60,
		"pl_eqt": 226.0,
		"pl_orbeccen": 0.043,
		"st_teff": 3216.0,
		"st_spectype": "M4.5 V",
		"notes": "Super-Earth with high bulk density indicating rocky interior."
	},
	{
		"pl_name": "WASP-12 b",
		"hostname": "WASP-12",
		"discoverymethod": "Transit",
		"disc_year": 2008,
		"sy_dist": 432.5,
		"pl_orbper": 1.09142,
		"pl_rade": 21.3,
		"pl_bmasse": 467.2,
		"pl_eqt": 2575.0,
		"pl_orbeccen": 0.0447,
		"st_teff": 6300.0,
		"st_spectype": "F6 V",
		"notes": "Tidally disrupted ultra-hot gas giant."
	}
]


func _ready() -> void:
	load_database(DEFAULT_DATA_PATH)


## Loads exoplanet records from JSON file with seamless graceful degradation to fallback archive
func load_database(file_path: String = DEFAULT_DATA_PATH) -> bool:
	_planets_by_id.clear()
	_planet_keys.clear()
	
	var success := false
	if FileAccess.file_exists(file_path):
		var file := FileAccess.open(file_path, FileAccess.READ)
		if file:
			var content := file.get_as_text()
			file.close()
			
			var json := JSON.new()
			var parse_err := json.parse(content)
			if parse_err == OK and json.data is Dictionary:
				var root: Dictionary = json.data
				metadata = root.get("_metadata", {})
				var raw_list: Array = root.get("exoplanets", [])
				if not raw_list.is_empty():
					for raw_p in raw_list:
						if raw_p is Dictionary:
							_register_planet(raw_p)
					is_using_fallback = false
					data_source_label = "%s (Retrieved: %s)" % [
						metadata.get("source", "NASA Exoplanet Archive"),
						metadata.get("retrieval_date", "2026-10-17")
					]
					success = true
					print("[ExoplanetDatabase] Successfully loaded %d records from %s." % [_planet_keys.size(), file_path])
				else:
					push_warning("[ExoplanetDatabase] No exoplanets array in %s. Using fallback." % file_path)
			else:
				push_warning("[ExoplanetDatabase] Failed to parse JSON in %s (Error code %d). Using fallback." % [file_path, parse_err])
		else:
			push_warning("[ExoplanetDatabase] Unable to open %s. Using fallback." % file_path)
	else:
		push_warning("[ExoplanetDatabase] File not found: %s. Using fallback." % file_path)
		
	if not success:
		_load_fallback_dataset()
		
	# Default selection
	if not _planet_keys.is_empty() and selected_planet_id.is_empty():
		select_planet(_planet_keys[0])
		
	database_loaded.emit(_planet_keys.size(), is_using_fallback)
	return success


func _load_fallback_dataset() -> void:
	_planets_by_id.clear()
	_planet_keys.clear()
	is_using_fallback = true
	metadata = FALLBACK_METADATA.duplicate(true)
	data_source_label = "Built-in Fallback Dataset (Curated Archive, Retrieved: %s)" % metadata.get("retrieval_date", "2026-10-17")
	
	for raw_p in FALLBACK_PLANETS:
		_register_planet(raw_p)
		
	print("[ExoplanetDatabase] Activated fallback archive with %d planets." % _planet_keys.size())


func _register_planet(raw: Dictionary) -> void:
	var name_str: String = str(raw.get("pl_name", "Unknown Planet"))
	var id := name_str.to_lower().replace(" ", "_").replace("-", "_")
	
	var validated := {
		"id": id,
		"pl_name": name_str,
		"hostname": str(raw.get("hostname", "Unknown Star")),
		"discoverymethod": str(raw.get("discoverymethod", "Unknown Method")),
		"disc_year": int(raw.get("disc_year", 0)),
		# Preserved Source Units:
		"sy_dist": raw.get("sy_dist"),       # parsecs [pc]
		"pl_orbper": raw.get("pl_orbper"),   # days
		"pl_rade": raw.get("pl_rade"),       # Earth Radii [R_earth]
		"pl_bmasse": raw.get("pl_bmasse"),   # Earth Mass [M_earth]
		"pl_eqt": raw.get("pl_eqt"),         # Kelvin [K] (theoretical blackbody equilibrium)
		"pl_orbeccen": raw.get("pl_orbeccen"), # dimensionless
		"st_teff": raw.get("st_teff"),       # Kelvin [K]
		"st_spectype": str(raw.get("st_spectype", "Unknown")),
		"notes": str(raw.get("notes", "")),
		# Measurement Availability Flags:
		"has_mass": raw.get("pl_bmasse") != null,
		"has_radius": raw.get("pl_rade") != null,
		"has_eqt": raw.get("pl_eqt") != null,
		"has_eccentricity": raw.get("pl_orbeccen") != null
	}
	
	_planets_by_id[id] = validated
	_planet_keys.append(id)


# ---------------------------------------------------------------------------
# Scientific-to-Fictional Gameplay Mapping Engine
# ---------------------------------------------------------------------------
## Maps authentic astronomical parameters to clearly labeled fictional gameplay properties
## Strictly enforces scientific caveats regarding temperature, gravity, and eccentricity
func compute_gameplay_properties(planet: Dictionary) -> Dictionary:
	var pl_name: String = str(planet.get("pl_name", "Exoplanet"))
	var eqt = planet.get("pl_eqt")
	var rad = planet.get("pl_rade")
	var mass = planet.get("pl_bmasse")
	var ecc = planet.get("pl_orbeccen")
	var st_teff = planet.get("st_teff")
	var orbper = planet.get("pl_orbper")
	
	# -----------------------------------------------------------------------
	# 1. Fictional Hazard Level
	# -----------------------------------------------------------------------
	var hazard := "MODERATE"
	var hazard_reason := "Standard alien biosphere conditions."
	var hazard_color := Color(0.9, 0.75, 0.2)
	
	if eqt != null and float(eqt) >= 1500.0:
		hazard = "LETHAL"
		hazard_reason = "Extreme stellar proximity; hyperthermal radiation conflagration."
		hazard_color = Color(1.0, 0.15, 0.2)
	elif eqt != null and float(eqt) >= 500.0:
		hazard = "EXTREME"
		hazard_reason = "Intense stellar thermal flux and severe atmospheric turbulence."
		hazard_color = Color(1.0, 0.35, 0.2)
	elif orbper != null and float(orbper) < 2.0:
		hazard = "EXTREME"
		hazard_reason = "Tidal disruption zone; extreme orbital shear."
		hazard_color = Color(1.0, 0.35, 0.2)
	elif eqt != null and float(eqt) < 200.0:
		hazard = "ELEVATED"
		hazard_reason = "Cryogenic sub-zero environment; accelerated suit life-support drain."
		hazard_color = Color(0.3, 0.7, 1.0)
	elif mass != null and rad != null and float(mass) / pow(float(rad), 2.0) > 1.8:
		hazard = "ELEVATED"
		hazard_reason = "High surface gravity gradient; increased locomotion energy consumption."
		hazard_color = Color(0.85, 0.45, 0.95)
	else:
		hazard = "MODERATE"
		hazard_reason = "Habitable-zone candidate; localized environmental hazards present."
		hazard_color = Color(0.2, 0.85, 0.4)
		
	# -----------------------------------------------------------------------
	# 2. Fictional Sector Visibility
	# -----------------------------------------------------------------------
	var visibility := "Standard Twilight"
	var vis_desc := "Adequate visibility under host star illumination."
	if st_teff != null:
		var t := float(st_teff)
		if t >= 5500.0:
			visibility = "High Daylight"
			vis_desc = "Intense yellow-white solar illumination; long sightlines."
		elif t >= 3500.0:
			visibility = "Amber Twilight"
			vis_desc = "Warm orange illumination; moderate contrast shadows."
		elif t >= 2800.0:
			visibility = "Crimson Twilight"
			vis_desc = "Deep red M-dwarf spectrum; reduced peripheral vision."
		else:
			visibility = "Infrared Nocturnal"
			vis_desc = "Ultra-cool dwarf emission; near pitch darkness without artificial floodlights."
	
	# -----------------------------------------------------------------------
	# 3. Fictional Resource Scarcity & Mineral Abundance
	# -----------------------------------------------------------------------
	var resource_scarcity := "Balanced Mineral Reserves"
	var resource_desc := "Nominal distribution of titanium and crystal nodes."
	if mass != null and rad != null:
		var r_f := float(rad)
		var m_f := float(mass)
		var bulk_density_ratio: float = m_f / pow(r_f, 3.0)
		if bulk_density_ratio >= 1.1:
			resource_scarcity = "Dense Mineral Wealth"
			resource_desc = "Heavy rocky mantle rich in piezoelectric crystals and titanium ore."
		elif r_f >= 2.0:
			resource_scarcity = "Volatile-Rich Mantle"
			resource_desc = "Sub-Neptune envelope rich in cryogenic gases and exotic biomass."
		else:
			resource_scarcity = "Moderate Terrestrial Reserves"
			resource_desc = "Standard terrestrial crust mineral veins."
	elif mass == null and rad != null:
		resource_scarcity = "Unsurveyed Mineral Profile"
		resource_desc = "Bulk density undetermined (mass unmeasured); exploratory mining required."
	elif rad == null and mass != null:
		resource_scarcity = "Dense Core Candidate"
		resource_desc = "Doppler mass detected; surface deposits unmapped."
		
	# -----------------------------------------------------------------------
	# 4. Fictional Temperature Effects & Suit Thermal Stress
	# -----------------------------------------------------------------------
	var thermal_effect := "Nominal Thermal Load"
	var thermal_drain_modifier := 1.0
	if eqt != null:
		var eq := float(eqt)
		if eq >= 1500.0:
			thermal_effect = "Hyperthermal Conflagration (+250% Suit Coolant Drain)"
			thermal_drain_modifier = 2.5
		elif eq >= 400.0:
			thermal_effect = "High Thermal Stress (+150% Coolant Drain)"
			thermal_drain_modifier = 1.5
		elif eq <= 210.0:
			thermal_effect = "Cryogenic Hypothermia (+175% Suit Heating Drain)"
			thermal_drain_modifier = 1.75
		else:
			thermal_effect = "Temperate Baseline (Nominal Life-Support Consumption)"
			thermal_drain_modifier = 1.0
	else:
		thermal_effect = "Thermal Profile Unmeasured (Default baseline suit load)"
		thermal_drain_modifier = 1.0

	# -----------------------------------------------------------------------
	# 5. Scientific Caveat Compliances (Strictly Handled & Documented)
	# -----------------------------------------------------------------------
	var temp_caveat: String = ""
	if eqt != null:
		temp_caveat = "Theoretical Equilibrium Temp: %.1f K (Blackbody calculation; actual surface temperature is unconfirmed and depends on atmospheric greenhouse warming)." % float(eqt)
	else:
		temp_caveat = "Equilibrium temperature unmeasured in archive."

	var grav_caveat: String = ""
	if mass != null and rad != null:
		var approx_g := (float(mass) / pow(float(rad), 2.0)) * 9.80665
		grav_caveat = "Derived Bulk Acceleration: ~%.2f m/s² (~%.2f g). (Actual surface gravity depends on unmodeled interior density distribution)." % [approx_g, approx_g / 9.80665]
	elif mass == null:
		grav_caveat = "Surface gravity UNCONFIRMED: Planet radius alone is insufficient to calculate gravity without confirmed mass measurement (radial velocity / TTV required)."
	elif rad == null:
		grav_caveat = "Surface gravity UNCONFIRMED: Non-transiting planet; geometric radius unmeasured."

	var day_night_caveat: String = ""
	if ecc != null:
		day_night_caveat = "Orbital Eccentricity: e = %.4f (Quantifies orbital elongation and seasonal insolation variance; NOT a direct day/night rotation cycle measurement)." % float(ecc)
	else:
		day_night_caveat = "Orbital eccentricity unmeasured."

	return {
		"planet_id": planet.get("id"),
		"pl_name": pl_name,
		# Fictional Gameplay Properties (Clearly Labeled)
		"gameplay_hazard_level": hazard,
		"gameplay_hazard_reason": hazard_reason,
		"gameplay_hazard_color": hazard_color,
		"gameplay_visibility": visibility,
		"gameplay_visibility_desc": vis_desc,
		"gameplay_resource_scarcity": resource_scarcity,
		"gameplay_resource_desc": resource_desc,
		"gameplay_thermal_effect": thermal_effect,
		"gameplay_thermal_drain_modifier": thermal_drain_modifier,
		# Scientific Integrity Caveats
		"scientific_caveat_temperature": temp_caveat,
		"scientific_caveat_gravity": grav_caveat,
		"scientific_caveat_day_night": day_night_caveat
	}


# ---------------------------------------------------------------------------
# Public Query & Selection API
# ---------------------------------------------------------------------------
func get_all_planets() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for k in _planet_keys:
		list.append(_planets_by_id[k])
	return list


func get_planet_keys() -> Array[String]:
	return _planet_keys.duplicate()


func get_planet(planet_id: String) -> Dictionary:
	return _planets_by_id.get(planet_id, {})


func get_selected_planet() -> Dictionary:
	return _planets_by_id.get(selected_planet_id, {})


func get_selected_gameplay_properties() -> Dictionary:
	var p := get_selected_planet()
	if p.is_empty():
		return {}
	return compute_gameplay_properties(p)


func select_planet(planet_id: String) -> bool:
	if not _planets_by_id.has(planet_id):
		push_warning("[ExoplanetDatabase] Planet not found: %s" % planet_id)
		return false
		
	selected_planet_id = planet_id
	var p: Dictionary = _planets_by_id[planet_id]
	var props := compute_gameplay_properties(p)
	
	# Update GameState if present
	var gs = get_node_or_null("/root/GameState")
	if gs and "selected_planet" in gs:
		gs.selected_planet = p.get("pl_name", planet_id)
		
	# Notify MissionManager if present
	var mm = get_node_or_null("/root/MissionManager")
	if mm and mm.has_method("notify_event"):
		mm.call("notify_event", "planet_selected", {
			"planet_id": planet_id,
			"planet_name": p.get("pl_name"),
			"hazard_level": props.get("gameplay_hazard_level")
		})
		
	print("[ExoplanetDatabase] Selected planet target: %s [%s]" % [p.get("pl_name"), props.get("gameplay_hazard_level")])
	planet_selected.emit(planet_id, p, props)
	return true
