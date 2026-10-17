extends SceneTree
## BioSphere-X — Controlled Planet Scenarios Automated Test Suite
## Validates reproducible exoplanet maps across:
##   1. Obstacle density tiers (Low, Medium, High, Asymmetric, Stepping-Stone)
##   2. Route lengths and pathfinding traversability (Direct, Chokepoint, Labyrinth)
##   3. Resource distribution models (Concentrated, Guarded, Perimeter, Tiered, Archipelago)
##   4. NASA-derived scientific metadata and scientific caveats
##   5. JSON and CSV experimental telemetry export

const ScenariosScript := preload("res://scripts/components/controlled_planet_scenarios.gd")
const PlanetConfigScript := preload("res://scripts/components/planet_level_config.gd")
const ArenaScript := preload("res://scenes/ai_vs_ai/ai_arena.gd")

func _init() -> void:
	print("\n=====================================================================")
	print("🪐 BioSphere-X: Controlled Planet Scenarios Test Suite")
	print("=====================================================================\n")

	# 1. Verify Catalog Completeness
	print("[1/6] Verifying scenario catalog completeness...")
	var scenario_ids: Array[String] = ScenariosScript.SCENARIO_IDS
	assert(scenario_ids.size() == 5, "Must have exactly 5 controlled scenarios")
	for id in ["trappist_1_e", "lhs_1140_b", "kepler_186_f", "proxima_centauri_b", "k2_18_b"]:
		assert(scenario_ids.has(id), "Catalog missing scenario: %s" % id)
	print("  ✓ All 5 exoplanet scenarios registered in catalog.")

	# 2. Verify NASA Scientific Metadata & Caveats
	print("\n[2/6] Verifying NASA-derived metadata and scientific caveats...")
	for id in scenario_ids:
		var scen: Dictionary = ScenariosScript.get_scenario(id)
		var nasa: Dictionary = scen.get("nasa_metadata", {})
		assert(not str(nasa.get("hostname", "")).is_empty(), "NASA metadata missing hostname")
		assert(float(nasa.get("system_distance_pc", 0.0)) > 0.0, "NASA metadata missing distance_pc")
		assert(float(nasa.get("system_distance_ly", 0.0)) > 0.0, "NASA metadata missing distance_ly")
		assert(float(nasa.get("equilibrium_temp_k", 0.0)) > 0.0, "NASA metadata missing equilibrium_temp_k")
		assert(not str(nasa.get("spectral_type", "")).is_empty(), "NASA metadata missing spectral_type")
		var caveats: Array = nasa.get("scientific_caveats", [])
		assert(caveats.size() >= 2, "NASA metadata must document at least 2 scientific caveats")

		# Scientific rigor assertions:
		if id == "kepler_186_f":
			assert(nasa.get("mass_earth") == null, "Kepler-186 f mass must be null (unmeasured)")
		elif id == "proxima_centauri_b":
			assert(nasa.get("radius_earth") == null, "Proxima Centauri b radius must be null (non-transiting)")
		elif id == "lhs_1140_b":
			assert(float(nasa.get("mass_earth", 0.0)) > 5.0, "LHS 1140 b mass must reflect super-Earth ~5.6 M_earth")
		elif id == "trappist_1_e":
			assert(float(nasa.get("mass_earth", 0.0)) < 1.0, "TRAPPIST-1 e mass must reflect confirmed ~0.69 M_earth")
		elif id == "k2_18_b":
			assert(float(nasa.get("mass_earth", 0.0)) > 8.0, "K2-18 b mass must reflect sub-Neptune ~8.63 M_earth")
			assert(float(nasa.get("radius_earth", 0.0)) > 2.0, "K2-18 b radius must reflect ~2.61 R_earth")

		print("  ✓ %s: Host %s (%s), Dist: %.2f ly, Teq: %.0f K, Caveats: %d" % [
			scen.get("name"), nasa.get("hostname"), nasa.get("spectral_type"),
			float(nasa.get("system_distance_ly")), float(nasa.get("equilibrium_temp_k")),
			caveats.size()
		])

	# 3. Verify Map Generation & Obstacle Density
	print("\n[3/6] Verifying procedural map generation & empirical obstacle density...")
	print("\n+--------------------------------------------------------------------------------------------------------------------------------+")
	print("| SCENARIO ID        | DENSITY TIER    | TARGET DENSITY | EMPIRICAL DENSITY | ROUTE TIER         | WAYPOINTS | ROUTE LENGTH (M) |")
	print("+--------------------------------------------------------------------------------------------------------------------------------+")

	for id in scenario_ids:
		var scen: Dictionary = ScenariosScript.get_scenario(id)
		var exp_prof: Dictionary = scen.get("experimental_profile", {})
		var map_data = ScenariosScript.build_map_data(id)
		assert(map_data != null, "build_map_data must return valid MapData")

		var empirical_density: float = ScenariosScript.calculate_obstacle_density(map_data)
		var target_density: float = float(exp_prof.get("target_density_pct", 0.0))
		var density_tier: String = str(exp_prof.get("density_tier", ""))

		# Validate density bounds: empirical density must match target profile
		match density_tier:
			"LOW":
				assert(empirical_density < 5.0, "LOW density tier must be < 5%")
			"ASYMMETRIC":
				assert(empirical_density >= 4.0 and empirical_density <= 7.0, "ASYMMETRIC tier must be 4-7%")
			"MEDIUM":
				assert(empirical_density >= 6.0 and empirical_density <= 9.0, "MEDIUM density tier must be 6-9%")
			"STEPPING_STONE":
				assert(empirical_density >= 6.0 and empirical_density <= 9.0, "STEPPING_STONE tier must be 6-9%")
			"HIGH":
				assert(empirical_density >= 10.0, "HIGH density tier must be >= 10%")

		# Calculate optimal path from Spawn A to Spawn B
		var spawn_a: Vector2 = scen.get("spawn_a", Vector2(-420, 0))
		var spawn_b: Vector2 = scen.get("spawn_b", Vector2(420, 0))
		var route: PackedVector2Array = ScenariosScript.calculate_optimal_route(map_data, spawn_a, spawn_b)
		assert(route.size() > 0, "Scenario %s must have traversable route between spawns" % id)
		var route_dist: float = ScenariosScript.calculate_route_distance(route)
		assert(route_dist >= 800.0, "Route distance should span arena >= 800m")

		print("| %-18s | %-15s | %13.1f%% | %16.1f%% | %-18s | %9d | %14.1f m |" % [
			id, density_tier, target_density, empirical_density,
			str(exp_prof.get("route_tier", "")), route.size(), route_dist
		])

	print("+--------------------------------------------------------------------------------------------------------------------------------+")

	# 4. Verify Resource Placements
	print("\n[4/6] Verifying resource placements and game economy types...")
	var valid_resource_types := ["oxygen", "titanium", "crystals", "biomass", "overcharge"]
	for id in scenario_ids:
		var scen: Dictionary = ScenariosScript.get_scenario(id)
		var resources: Array = scen.get("resources", [])
		assert(resources.size() >= 5, "Scenario %s must have at least 5 resource nodes" % id)
		var total_qty: int = 0
		for r in resources:
			var r_type: String = str(r.get("type", ""))
			assert(valid_resource_types.has(r_type), "Invalid resource type '%s' in scenario %s" % [r_type, id])
			var qty: int = int(r.get("qty", 0))
			assert(qty > 0, "Resource quantity must be positive")
			total_qty += qty
		print("  ✓ %s: %d resource placements, total yield: %d units" % [
			id, resources.size(), total_qty
		])

	# 5. Verify JSON and CSV Telemetry Exports
	print("\n[5/6] Verifying scenario documentation export (JSON & CSV)...")
	var json_path: String = ScenariosScript.export_scenarios_json()
	assert(not json_path.is_empty(), "JSON export path must not be empty")
	assert(FileAccess.file_exists(json_path), "Exported JSON file must exist on disk: %s" % json_path)

	var csv_path: String = ScenariosScript.export_scenarios_csv()
	assert(not csv_path.is_empty(), "CSV export path must not be empty")
	assert(FileAccess.file_exists(csv_path), "Exported CSV file must exist on disk: %s" % csv_path)

	# Validate CSV contents
	var csv_file := FileAccess.open(csv_path, FileAccess.READ)
	assert(csv_file != null, "Must be able to open exported CSV")
	var header_line := csv_file.get_line()
	assert(header_line.begins_with("ScenarioID"), "CSV header must begin with ScenarioID")
	var data_rows := 0
	while not csv_file.eof_reached():
		var line := csv_file.get_line().strip_edges()
		if not line.is_empty():
			data_rows += 1
	csv_file.close()
	assert(data_rows == 5, "CSV must contain exactly 5 scenario data rows, got: %d" % data_rows)
	print("  ✓ JSON exported to: %s" % json_path)
	print("  ✓ CSV exported to:  %s (5 scenario rows verified)" % csv_path)

	# 6. Verify System Integrations (PlanetLevelConfig & AIArena)
	print("\n[6/6] Verifying BioSphere-X system integrations...")
	for id in scenario_ids:
		var cfg = PlanetConfigScript.get_config_by_id(id)
		assert(cfg != null, "PlanetConfigScript must return valid config for: %s" % id)
		assert(cfg.get("planet_id") == id, "Planet config ID must match requested: %s" % id)

	# Verify AIArena presets
	for id in scenario_ids:
		assert(ArenaScript.MAP_PRESETS.has(id), "AIArena MAP_PRESETS must include scenario: %s" % id)
	print("  ✓ PlanetLevelConfig factory validated for all 5 scenarios.")
	print("  ✓ AIArena MAP_PRESETS integration validated for all 5 scenarios.")

	print("\n=====================================================================")
	print("🎉 ALL CONTROLLED PLANET SCENARIO TESTS PASSED SUCCESSFULLY!")
	print("=====================================================================\n")

	quit(0)
