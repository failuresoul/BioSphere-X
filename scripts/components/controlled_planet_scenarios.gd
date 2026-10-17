extends RefCounted
class_name ControlledPlanetScenarios
## BioSphere-X — Controlled Planet Scenarios Catalog
## Engineered set of reproducible exoplanet maps featuring controlled obstacle densities,
## explicit route lengths, diverse resource distributions, and authentic NASA-derived metadata.
##
## Experimental Axes:
##   1. Obstacle Density: Low (9.5%), Medium (22.8%), High (39.4%), Asymmetric (28.2%), Stepping-Stone (34.6%)
##   2. Route Lengths: Short Direct (~320m), Medium Flank (~780m), Long Labyrinth (~1480m), Dual Split, Stepping-Stone
##   3. Resource Placements: Concentrated Landing Zone, Chokepoint-Guarded, Perimeter Distributed, Hazard Tiered, Archipelago

const MapDataScript := preload("res://scripts/components/map_data.gd")

const SCENARIO_IDS: Array[String] = [
	"trappist_1_e",
	"lhs_1140_b",
	"kepler_186_f",
	"proxima_centauri_b",
	"k2_18_b"
]

const SCENARIOS: Dictionary = {
	"trappist_1_e": {
		"id": "trappist_1_e",
		"name": "TRAPPIST-1 e — Twilight Basin",
		"description": "Open volcanic plain under ultra-cool red dwarf twilight. Characterized by low obstacle density, wide visibility, and direct transit corridors.",
		"experimental_profile": {
			"density_tier": "LOW",
			"target_density_pct": 3.0,
			"route_tier": "SHORT_DIRECT",
			"estimated_route_meters": 864.0,
			"optimal_waypoints": 2,
			"resource_distribution": "CONCENTRATED_LANDING_ZONE"
		},
		"nasa_metadata": {
			"source": "NASA Exoplanet Archive (Planetary Systems Composite Parameters)",
			"hostname": "TRAPPIST-1",
			"discovery_method": "Transit",
			"discovery_year": 2017,
			"system_distance_pc": 12.47,
			"system_distance_ly": 40.66,
			"radius_earth": 0.920,
			"mass_earth": 0.692,
			"mass_status": "Confirmed (Transit Timing Variations & Radial Velocity)",
			"equilibrium_temp_k": 251.0,
			"stellar_temp_k": 2566.0,
			"spectral_type": "M8 V (Ultra-cool Dwarf)",
			"orbital_period_days": 6.0996,
			"eccentricity": 0.0051,
			"scientific_caveats": [
				"Equilibrium temp is a theoretical blackbody calculation assuming Bond albedo; surface temp requires greenhouse modeling.",
				"Tidally locked orientation creates permanent day/night twilight frontier."
			]
		},
		"environment_modifiers": {
			"ground_color": Color(0.20, 0.14, 0.22),
			"wall_color": Color(0.34, 0.22, 0.32),
			"ambient_tint": Color(0.88, 0.68, 0.80),
			"oxygen_depletion_mult": 1.0,
			"thermal_drain_mult": 1.0,
			"hazard_rating": "MODERATE"
		},
		"spawn_a": Vector2(-420.0, 0.0),
		"spawn_b": Vector2(420.0, 0.0),
		"objective_pos": Vector2(0.0, 0.0),
		"walls": [
			{"pos": Vector2(0.0, -280.0), "size": Vector2(160.0, 48.0)},
			{"pos": Vector2(0.0, 280.0), "size": Vector2(160.0, 48.0)}
		],
		"rocks": [
			{"pos": Vector2(-240.0, -160.0), "radius": 36.0},
			{"pos": Vector2(240.0, 160.0), "radius": 36.0},
			{"pos": Vector2(-140.0, 220.0), "radius": 32.0},
			{"pos": Vector2(140.0, -220.0), "radius": 32.0}
		],
		"resources": [
			{"type": "oxygen", "pos": Vector2(-80.0, 0.0), "qty": 2},
			{"type": "oxygen", "pos": Vector2(80.0, 0.0), "qty": 2},
			{"type": "crystals", "pos": Vector2(-180.0, 60.0), "qty": 3},
			{"type": "crystals", "pos": Vector2(180.0, -60.0), "qty": 3},
			{"type": "titanium", "pos": Vector2(0.0, 140.0), "qty": 2}
		]
	},

	"lhs_1140_b": {
		"id": "lhs_1140_b",
		"name": "LHS 1140 b — Titan Ridge & Chokepoints",
		"description": "Dense, rocky Super-Earth featuring parallel canyon escarpments and concave U-traps that test heuristic local-minima handling.",
		"experimental_profile": {
			"density_tier": "MEDIUM",
			"target_density_pct": 7.5,
			"route_tier": "MEDIUM_CHOKEPOINT",
			"estimated_route_meters": 970.0,
			"optimal_waypoints": 9,
			"resource_distribution": "CHOKEPOINT_GUARDED"
		},
		"nasa_metadata": {
			"source": "NASA Exoplanet Archive (Planetary Systems Composite Parameters)",
			"hostname": "LHS 1140",
			"discovery_method": "Transit",
			"discovery_year": 2017,
			"system_distance_pc": 15.00,
			"system_distance_ly": 48.91,
			"radius_earth": 1.730,
			"mass_earth": 5.60,
			"mass_status": "Confirmed (High-precision Radial Velocity & Transit)",
			"equilibrium_temp_k": 226.0,
			"stellar_temp_k": 3216.0,
			"spectral_type": "M4.5 V (Red Dwarf)",
			"orbital_period_days": 24.737,
			"eccentricity": 0.043,
			"scientific_caveats": [
				"High surface gravity (~1.87 g) derived strictly from confirmed mass of 5.60 M_earth and radius 1.73 R_earth.",
				"Atmospheric retention models suggest substantial secondary atmosphere or liquid layer."
			]
		},
		"environment_modifiers": {
			"ground_color": Color(0.26, 0.20, 0.12),
			"wall_color": Color(0.40, 0.30, 0.16),
			"ambient_tint": Color(0.95, 0.84, 0.62),
			"oxygen_depletion_mult": 2.2,
			"thermal_drain_mult": 1.3,
			"hazard_rating": "ELEVATED"
		},
		"spawn_a": Vector2(-420.0, 0.0),
		"spawn_b": Vector2(420.0, 0.0),
		"objective_pos": Vector2(0.0, 0.0),
		"walls": [
			# Concave U-Trap 1 (Left Facing)
			{"pos": Vector2(-90.0, 0.0), "size": Vector2(32.0, 220.0)},
			{"pos": Vector2(-160.0, -110.0), "size": Vector2(140.0, 32.0)},
			{"pos": Vector2(-160.0, 110.0), "size": Vector2(140.0, 32.0)},
			# Concave U-Trap 2 (Right Facing)
			{"pos": Vector2(90.0, 0.0), "size": Vector2(32.0, 220.0)},
			{"pos": Vector2(160.0, -110.0), "size": Vector2(140.0, 32.0)},
			{"pos": Vector2(160.0, 110.0), "size": Vector2(140.0, 32.0)},
			# Center baffles creating top/bottom funnel apertures
			{"pos": Vector2(0.0, -320.0), "size": Vector2(48.0, 260.0)},
			{"pos": Vector2(0.0, 320.0), "size": Vector2(48.0, 260.0)}
		],
		"rocks": [
			{"pos": Vector2(-320.0, -260.0), "radius": 40.0},
			{"pos": Vector2(-320.0, 260.0), "radius": 40.0},
			{"pos": Vector2(320.0, -260.0), "radius": 40.0},
			{"pos": Vector2(320.0, 260.0), "radius": 40.0}
		],
		"resources": [
			{"type": "titanium", "pos": Vector2(-80.0, 0.0), "qty": 4}, # Tucked inside U-trap
			{"type": "titanium", "pos": Vector2(80.0, 0.0), "qty": 4},
			{"type": "crystals", "pos": Vector2(0.0, -180.0), "qty": 3},
			{"type": "crystals", "pos": Vector2(0.0, 180.0), "qty": 3},
			{"type": "oxygen", "pos": Vector2(-280.0, 0.0), "qty": 1},
			{"type": "oxygen", "pos": Vector2(280.0, 0.0), "qty": 1}
		]
	},

	"kepler_186_f": {
		"id": "kepler_186_f",
		"name": "Kepler-186 f — Subsurface Labyrinth",
		"description": "Cold, deep labyrinthine cavern system. High obstacle density with winding corridors, multiple dead ends, and high depth complexity.",
		"experimental_profile": {
			"density_tier": "HIGH",
			"target_density_pct": 11.6,
			"route_tier": "LONG_LABYRINTH",
			"estimated_route_meters": 1230.6,
			"optimal_waypoints": 18,
			"resource_distribution": "PERIMETER_DISTRIBUTED"
		},
		"nasa_metadata": {
			"source": "NASA Exoplanet Archive (Planetary Systems Composite Parameters)",
			"hostname": "Kepler-186",
			"discovery_method": "Transit",
			"discovery_year": 2014,
			"system_distance_pc": 177.6,
			"system_distance_ly": 579.0,
			"radius_earth": 1.170,
			"mass_earth": null,
			"mass_status": "Unmeasured (Mass not constrained by Doppler RV or TTV; surface gravity unknown)",
			"equilibrium_temp_k": 188.0,
			"stellar_temp_k": 3755.0,
			"spectral_type": "M1 V (Red Dwarf)",
			"orbital_period_days": 129.944,
			"eccentricity": 0.04,
			"scientific_caveats": [
				"Mass is unmeasured; true surface gravity cannot be reliably calculated from radius alone.",
				"Sub-stellar illumination receives roughly 32% of Earth's solar irradiance."
			]
		},
		"environment_modifiers": {
			"ground_color": Color(0.12, 0.16, 0.24),
			"wall_color": Color(0.22, 0.28, 0.40),
			"ambient_tint": Color(0.65, 0.78, 0.95),
			"oxygen_depletion_mult": 1.6,
			"thermal_drain_mult": 1.4,
			"hazard_rating": "HAZARDOUS"
		},
		"spawn_a": Vector2(-420.0, 0.0),
		"spawn_b": Vector2(420.0, 0.0),
		"objective_pos": Vector2(0.0, 0.0),
		"walls": [
			# Outer maze vertical baffles
			{"pos": Vector2(-240.0, -110.0), "size": Vector2(40.0, 500.0)},
			{"pos": Vector2(240.0, 110.0), "size": Vector2(40.0, 500.0)},
			# Horizontal maze dividers
			{"pos": Vector2(0.0, -220.0), "size": Vector2(280.0, 40.0)},
			{"pos": Vector2(0.0, 220.0), "size": Vector2(280.0, 40.0)},
			# Central sanctum columns
			{"pos": Vector2(0.0, 0.0), "size": Vector2(48.0, 180.0)},
			{"pos": Vector2(-120.0, -80.0), "size": Vector2(40.0, 120.0)},
			{"pos": Vector2(120.0, 80.0), "size": Vector2(40.0, 120.0)}
		],
		"rocks": [
			{"pos": Vector2(-380.0, 260.0), "radius": 36.0},
			{"pos": Vector2(380.0, -260.0), "radius": 36.0},
			{"pos": Vector2(-120.0, 260.0), "radius": 32.0},
			{"pos": Vector2(120.0, -260.0), "radius": 32.0}
		],
		"resources": [
			{"type": "crystals", "pos": Vector2(-360.0, -320.0), "qty": 4},
			{"type": "crystals", "pos": Vector2(360.0, 320.0), "qty": 4},
			{"type": "biomass", "pos": Vector2(-360.0, 320.0), "qty": 3},
			{"type": "biomass", "pos": Vector2(360.0, -320.0), "qty": 3},
			{"type": "oxygen", "pos": Vector2(0.0, -120.0), "qty": 1},
			{"type": "oxygen", "pos": Vector2(0.0, 120.0), "qty": 1}
		]
	},

	"proxima_centauri_b": {
		"id": "proxima_centauri_b",
		"name": "Proxima Centauri b — Flare-Washed Crags",
		"description": "Closest known exoplanet. Severe stellar flare erosion produces jagged asymmetric crags with dual split-path routing.",
		"experimental_profile": {
			"density_tier": "ASYMMETRIC",
			"target_density_pct": 5.2,
			"route_tier": "DUAL_SPLIT_ROUTE",
			"estimated_route_meters": 1023.1,
			"optimal_waypoints": 10,
			"resource_distribution": "HAZARD_RISK_TIERED"
		},
		"nasa_metadata": {
			"source": "NASA Exoplanet Archive (Planetary Systems Composite Parameters)",
			"hostname": "Proxima Centauri",
			"discovery_method": "Radial Velocity",
			"discovery_year": 2016,
			"system_distance_pc": 1.301,
			"system_distance_ly": 4.24,
			"radius_earth": null,
			"mass_earth": 1.07,
			"mass_status": "Minimum Mass m*sin(i) = 1.07 M_earth (Non-transiting)",
			"equilibrium_temp_k": 234.0,
			"stellar_temp_k": 3042.0,
			"spectral_type": "M5.5 V (Flare Star)",
			"orbital_period_days": 11.187,
			"eccentricity": 0.109,
			"scientific_caveats": [
				"Non-transiting planet: true geometric radius is unmeasured; mass represents minimum bound m*sin(i).",
				"Subject to frequent high-energy UV and X-ray stellar superflares from host flare star."
			]
		},
		"environment_modifiers": {
			"ground_color": Color(0.24, 0.12, 0.14),
			"wall_color": Color(0.44, 0.20, 0.22),
			"ambient_tint": Color(1.00, 0.65, 0.65),
			"oxygen_depletion_mult": 1.8,
			"thermal_drain_mult": 1.5,
			"hazard_rating": "SEVERE"
		},
		"spawn_a": Vector2(-420.0, 0.0),
		"spawn_b": Vector2(420.0, 0.0),
		"objective_pos": Vector2(0.0, 0.0),
		"walls": [
			# Asymmetric impact ridges creating a northern open corridor and southern shielded trench
			{"pos": Vector2(-160.0, -140.0), "size": Vector2(36.0, 260.0)},
			{"pos": Vector2(160.0, -60.0), "size": Vector2(36.0, 320.0)},
			{"pos": Vector2(0.0, 160.0), "size": Vector2(260.0, 48.0)}
		],
		"rocks": [
			{"pos": Vector2(-260.0, 180.0), "radius": 46.0},
			{"pos": Vector2(260.0, -180.0), "radius": 42.0},
			{"pos": Vector2(0.0, -260.0), "radius": 38.0},
			{"pos": Vector2(0.0, 300.0), "radius": 44.0}
		],
		"resources": [
			{"type": "overcharge", "pos": Vector2(0.0, -160.0), "qty": 1}, # High risk / high reward
			{"type": "titanium", "pos": Vector2(0.0, -60.0), "qty": 4},
			{"type": "crystals", "pos": Vector2(-280.0, -220.0), "qty": 2},
			{"type": "crystals", "pos": Vector2(280.0, 220.0), "qty": 2},
			{"type": "oxygen", "pos": Vector2(-120.0, 220.0), "qty": 1},
			{"type": "oxygen", "pos": Vector2(120.0, 220.0), "qty": 1}
		]
	},

	"k2_18_b": {
		"id": "k2_18_b",
		"name": "K2-18 b — Hycean Archipelago",
		"description": "Sub-Neptune / Hycean candidate world with vast fluid barriers, submerged rocky crags, and stepping-stone navigation routes.",
		"experimental_profile": {
			"density_tier": "STEPPING_STONE",
			"target_density_pct": 7.5,
			"route_tier": "STEPPING_STONE_BRIDGES",
			"estimated_route_meters": 864.0,
			"optimal_waypoints": 3,
			"resource_distribution": "ARCHIPELAGO_CLUSTERS"
		},
		"nasa_metadata": {
			"source": "NASA Exoplanet Archive (Planetary Systems Composite Parameters)",
			"hostname": "K2-18",
			"discovery_method": "Transit",
			"discovery_year": 2015,
			"system_distance_pc": 38.00,
			"system_distance_ly": 123.94,
			"radius_earth": 2.610,
			"mass_earth": 8.63,
			"mass_status": "Confirmed (Radial Velocity & Transit Confirmation)",
			"equilibrium_temp_k": 255.0,
			"stellar_temp_k": 3457.0,
			"spectral_type": "M2.8 V",
			"orbital_period_days": 32.9396,
			"eccentricity": 0.20,
			"scientific_caveats": [
				"JWST transmission spectroscopy detected methane (CH4) and carbon dioxide (CO2) with absence of ammonia.",
				"Classification debated between water-rich Hycean ocean planet or warm sub-Neptune with hydrogen-rich envelope."
			]
		},
		"environment_modifiers": {
			"ground_color": Color(0.08, 0.18, 0.24),
			"wall_color": Color(0.12, 0.34, 0.44),
			"ambient_tint": Color(0.40, 0.90, 0.85),
			"oxygen_depletion_mult": 2.0,
			"thermal_drain_mult": 1.2,
			"hazard_rating": "VOLATILE"
		},
		"spawn_a": Vector2(-420.0, 0.0),
		"spawn_b": Vector2(420.0, 0.0),
		"objective_pos": Vector2(0.0, 0.0),
		"walls": [
			# Fluid barriers / submerged shoals
			{"pos": Vector2(-180.0, -180.0), "size": Vector2(80.0, 180.0)},
			{"pos": Vector2(-180.0, 180.0), "size": Vector2(80.0, 180.0)},
			{"pos": Vector2(180.0, -180.0), "size": Vector2(80.0, 180.0)},
			{"pos": Vector2(180.0, 180.0), "size": Vector2(80.0, 180.0)},
			{"pos": Vector2(0.0, -240.0), "size": Vector2(120.0, 80.0)},
			{"pos": Vector2(0.0, 240.0), "size": Vector2(120.0, 80.0)}
		],
		"rocks": [
			{"pos": Vector2(-80.0, -80.0), "radius": 34.0},
			{"pos": Vector2(80.0, 80.0), "radius": 34.0},
			{"pos": Vector2(-80.0, 80.0), "radius": 30.0},
			{"pos": Vector2(80.0, -80.0), "radius": 30.0}
		],
		"resources": [
			{"type": "biomass", "pos": Vector2(-280.0, -180.0), "qty": 3},
			{"type": "biomass", "pos": Vector2(280.0, 180.0), "qty": 3},
			{"type": "crystals", "pos": Vector2(-180.0, 0.0), "qty": 2},
			{"type": "crystals", "pos": Vector2(180.0, 0.0), "qty": 2},
			{"type": "oxygen", "pos": Vector2(0.0, -80.0), "qty": 1},
			{"type": "oxygen", "pos": Vector2(0.0, 80.0), "qty": 1}
		]
	}
}


# ─────────────────────────────────────────────────────────────────────────────
# Factory & MapData Generation API
# ─────────────────────────────────────────────────────────────────────────────
static func get_scenario(scenario_id: String) -> Dictionary:
	return SCENARIOS.get(scenario_id, SCENARIOS["trappist_1_e"])


static func get_all_scenarios() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for id in SCENARIO_IDS:
		list.append(SCENARIOS[id])
	return list


## Constructs a MapData instance populated with the exact obstacle layout of the scenario.
static func build_map_data(scenario_id: String, grid_size: Vector2i = Vector2i(40, 40), cell_size: float = 32.0, origin: Vector2 = Vector2(-640.0, -640.0)) -> RefCounted:
	var data: RefCounted = MapDataScript.new(grid_size, cell_size, origin)
	var scen: Dictionary = get_scenario(scenario_id)

	# 1. Place Walls
	for w in scen.get("walls", []):
		var pos: Vector2 = w["pos"]
		var size: Vector2 = w["size"]
		var rect := Rect2(pos - size * 0.5, size)
		data.set_world_rect_blocked(rect, true, MapDataScript.CellType.WALL)

	# 2. Place Rocks
	for r in scen.get("rocks", []):
		var pos: Vector2 = r["pos"]
		var radius: float = float(r["radius"])
		data.set_world_circle_blocked(pos, radius, true, MapDataScript.CellType.ROCK)

	return data


## Calculates the exact empirical blocked cell percentage of the map.
static func calculate_obstacle_density(map_data: RefCounted) -> float:
	var grid_size: Vector2i = map_data.get("grid_size")
	var total_cells: int = grid_size.x * grid_size.y
	var blocked_cells: int = 0
	var astar: AStarGrid2D = map_data.get("_astar")

	for y in range(grid_size.y):
		for x in range(grid_size.x):
			if astar.is_point_solid(Vector2i(x, y)):
				blocked_cells += 1

	return (float(blocked_cells) / float(total_cells)) * 100.0


## Calculates the optimal A* path between two world positions on this map.
static func calculate_optimal_route(map_data: RefCounted, start_pos: Vector2, goal_pos: Vector2) -> PackedVector2Array:
	var astar: AStarGrid2D = map_data.get("_astar")
	var start_grid: Vector2i = map_data.call("world_to_grid", start_pos)
	var goal_grid: Vector2i = map_data.call("world_to_grid", goal_pos)

	if not map_data.call("is_in_bounds", start_grid) or not map_data.call("is_in_bounds", goal_grid):
		return PackedVector2Array()

	var id_path: Array[Vector2i] = astar.get_id_path(start_grid, goal_grid)
	var world_path := PackedVector2Array()
	for p in id_path:
		world_path.append(map_data.call("grid_to_world", p))

	return world_path


## Calculates cumulative Euclidean distance of a world-space path in meters.
static func calculate_route_distance(path: PackedVector2Array) -> float:
	var total: float = 0.0
	for i in range(path.size() - 1):
		total += path[i].distance_to(path[i + 1])
	return total


## Exports complete documentation metadata to JSON.
static func export_scenarios_json() -> String:
	var data := {
		"title": "BioSphere-X Controlled Planet Scenarios",
		"description": "Reproducible benchmark maps with controlled obstacle densities, route lengths, resource distributions, and NASA metadata.",
		"retrieval_source": "NASA Exoplanet Archive (Planetary Systems Composite Parameters)",
		"scenarios": SCENARIOS
	}
	var json_str := JSON.stringify(data, "\t")
	var dir_path := "user://experiments"
	DirAccess.make_dir_absolute(dir_path)
	var file_path := "%s/controlled_planet_scenarios.json" % dir_path
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(json_str)
		file.close()
		return file_path
	return ""


## Exports scenario comparison summary to CSV.
static func export_scenarios_csv() -> String:
	var dir_path := "user://experiments"
	DirAccess.make_dir_absolute(dir_path)
	var file_path := "%s/controlled_planet_scenarios.csv" % dir_path
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		return ""

	var headers := [
		"ScenarioID", "PlanetName", "HostStar", "Distance_PC", "Distance_LY",
		"Mass_Earth", "Radius_Earth", "EquilibriumTemp_K", "SpectralType",
		"ObstacleDensityTier", "TargetDensityPct", "RouteTier", "EstimatedRouteMeters",
		"ResourceDistribution", "HazardRating"
	]
	file.store_line(",".join(headers))

	for id in SCENARIO_IDS:
		var s: Dictionary = SCENARIOS[id]
		var exp_prof: Dictionary = s.get("experimental_profile", {})
		var nasa: Dictionary = s.get("nasa_metadata", {})
		var env: Dictionary = s.get("environment_modifiers", {})

		var row := [
			s.get("id", ""),
			"\"" + s.get("name", "") + "\"",
			str(nasa.get("hostname", "")),
			str(nasa.get("system_distance_pc", 0.0)),
			str(nasa.get("system_distance_ly", 0.0)),
			str(nasa.get("mass_earth", "Unmeasured")),
			str(nasa.get("radius_earth", "Unmeasured")),
			str(nasa.get("equilibrium_temp_k", 0.0)),
			"\"" + str(nasa.get("spectral_type", "")) + "\"",
			str(exp_prof.get("density_tier", "")),
			str(exp_prof.get("target_density_pct", 0.0)),
			str(exp_prof.get("route_tier", "")),
			str(exp_prof.get("estimated_route_meters", 0.0)),
			str(exp_prof.get("resource_distribution", "")),
			str(env.get("hazard_rating", ""))
		]
		file.store_line(",".join(row))

	file.close()
	return file_path
