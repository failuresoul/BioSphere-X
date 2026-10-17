class_name PlanetLevelConfig
extends Resource
## Data model representing a playable exoplanet level configuration for BioSphere-X.
## Encapsulates map geometry, environmental and atmospheric rates, resource fields,
## enemy encounter compositions, and campaign mission sequences.

@export var planet_id: String = ""
@export var planet_name: String = ""
@export var description: String = ""
@export var unlock_required_planet_id: String = ""
@export var unlock_required_mission_id: String = ""
@export var unlock_description: String = ""

# Map Geometry
@export var grid_size: Vector2i = Vector2i(80, 80)
@export var cell_size: float = 32.0
@export var world_size: Vector2 = Vector2(2560.0, 2560.0)
@export var world_origin: Vector2 = Vector2(-1280.0, -1280.0)
@export var ground_color: Color = Color(0.18, 0.14, 0.20)
@export var canyon_wall_color: Color = Color(0.32, 0.22, 0.30)
@export var barrier_color: Color = Color(0.95, 0.25, 0.40, 0.70)

# Environment & Survival
@export var ambient_tint: Color = Color(0.85, 0.75, 0.85)
@export var oxygen_depletion_rate: float = 1.5
@export var hazard_level: String = "MODERATE"
@export var thermal_drain_rate: float = 1.0

# Resource Distribution
@export var deposit_specs: Array = []
@export var collectable_specs: Array = []
@export var station_specs: Array = []

# Enemy Encounter Composition
@export var enemy_scouts_count: int = 3
@export var enemy_brutes_count: int = 1
@export var enemy_spitters_count: int = 2
@export var has_boss: bool = true
@export var base_aggression: float = 0.5

# Campaign Mission Sequence
@export var mission_sequence: Array = []


static func create_trappist_1_e() -> Resource:
	var cfg = load("res://scripts/components/planet_level_config.gd").new()
	cfg.planet_id = "trappist_1_e"
	cfg.planet_name = "TRAPPIST-1 e"
	cfg.description = "Primary landing zone. Rocky Earth-sized world in red dwarf twilight. Moderate hazard environment."
	cfg.unlock_required_planet_id = ""
	cfg.unlock_required_mission_id = ""
	cfg.unlock_description = "Default starter expedition world."
	
	cfg.ground_color = Color(0.20, 0.14, 0.22)
	cfg.canyon_wall_color = Color(0.34, 0.22, 0.32)
	cfg.ambient_tint = Color(0.88, 0.68, 0.80)
	cfg.oxygen_depletion_rate = 1.0
	cfg.hazard_level = "MODERATE"
	cfg.thermal_drain_rate = 1.0
	
	# Resource Distribution
	cfg.deposit_specs = [
		{"pos": Vector2(-680, 520), "type": 0, "radius": 26.0}, # Crystals
		{"pos": Vector2(-620, 600), "type": 0, "radius": 30.0},
		{"pos": Vector2(-540, 680), "type": 0, "radius": 28.0},
		{"pos": Vector2(-720, -420), "type": 1, "radius": 28.0}, # Titanium
		{"pos": Vector2(-780, -520), "type": 1, "radius": 32.0},
		{"pos": Vector2(520, 580), "type": 2, "radius": 26.0},  # Biomass
		{"pos": Vector2(620, 640), "type": 2, "radius": 30.0}
	]
	
	cfg.collectable_specs = [
		{"pos": Vector2(0, 160), "type": 0, "qty": 1},    # Immediate South Airlock Oxygen Cell
		{"pos": Vector2(100, -120), "type": 0, "qty": 1},  # Oxygen Cells
		{"pos": Vector2(-320, -320), "type": 0, "qty": 1},
		{"pos": Vector2(460, 200), "type": 0, "qty": 2},
		{"pos": Vector2(520, -380), "type": 1, "qty": 2},  # Titanium
		{"pos": Vector2(-220, 260), "type": 1, "qty": 2},
		{"pos": Vector2(-540, 540), "type": 2, "qty": 1},  # Crystals
		{"pos": Vector2(160, 220), "type": 2, "qty": 1},
		{"pos": Vector2(-140, 100), "type": 3, "qty": 1},  # Biomass Samples
		{"pos": Vector2(460, 560), "type": 3, "qty": 2}
	]
	
	cfg.enemy_scouts_count = 3
	cfg.enemy_spitters_count = 2
	cfg.enemy_brutes_count = 1
	cfg.has_boss = true
	cfg.base_aggression = 0.5
	
	# Mission Sequence
	cfg.mission_sequence = [
		{
			"id": "mission_01_oxygen",
			"title": "LIFE SUPPORT RECOVERY",
			"desc": "Atmosphere toxic. Recover 3 Oxygen Cells from fallen crates to stabilize life support.",
			"type": 0, # COLLECT_OXYGEN
			"target": 3.0,
			"rewards": {"oxygen_refill": 100.0, "biomass": 1},
			"params": {"required_resource": "oxygen_cells"},
			"unit": "Cells"
		},
		{
			"id": "mission_02_samples",
			"title": "FIELD SPECIMENS",
			"desc": "Harvest 3 Alien Biomass specimens from flora or xenomorph organisms.",
			"type": 1, # RETRIEVE_SAMPLES
			"target": 3.0,
			"rewards": {"crystals": 3, "titanium": 2},
			"params": {"required_resource": "biomass"},
			"unit": "Samples"
		},
		{
			"id": "mission_03_terminal",
			"title": "OUTPOST OVERRIDE",
			"desc": "Navigate North-East across the canyon and scan the Alpha-7 Research Terminal.",
			"type": 2, # ACTIVATE_TERMINAL
			"target": 1.0,
			"rewards": {"crystals": 5, "energy_refill": 100.0},
			"params": {"terminal_id": "Alpha-7 Research Terminal"},
			"unit": "Terminal"
		},
		{
			"id": "mission_05_boss",
			"title": "GOLIATH PROTOCOL",
			"desc": "Track Goliath Prime to the crater basin and neutralize the apex alien creature.",
			"type": 4, # DEFEAT_BOSS
			"target": 1.0,
			"rewards": {"crystals": 10, "titanium": 10, "biomass": 10},
			"params": {"boss_id": "GoliathPrime"},
			"unit": "Apex Threat"
		},
		{
			"id": "mission_06_extraction",
			"title": "EXPEDITION EXTRACTION",
			"desc": "Surface objectives complete. Return to the Habitat Module Airlock to secure telemetry.",
			"type": 5, # RETURN_TO_BASE
			"target": 1.0,
			"rewards": {"mission_rating": "EXEMPLARY"},
			"params": {"target_zone": "habitat_airlock"},
			"unit": "Airlock"
		}
	]
	
	return cfg


static func create_lhs_1140_b() -> Resource:
	var cfg = load("res://scripts/components/planet_level_config.gd").new()
	cfg.planet_id = "lhs_1140_b"
	cfg.planet_name = "LHS 1140 b"
	cfg.description = "Dense Super-Earth. Heavy rocky interior rich in titanium and crystal minerals. High gravity & atmospheric strain."
	cfg.unlock_required_planet_id = "trappist_1_e"
	cfg.unlock_required_mission_id = "mission_01_oxygen"
	cfg.unlock_description = "Complete 'LIFE SUPPORT RECOVERY' on TRAPPIST-1 e to authorize hyperspace vector."
	
	cfg.ground_color = Color(0.26, 0.20, 0.12)
	cfg.canyon_wall_color = Color(0.40, 0.30, 0.16)
	cfg.barrier_color = Color(1.0, 0.65, 0.15, 0.75) # Golden Amber Energy Barrier
	cfg.ambient_tint = Color(0.95, 0.84, 0.62)
	cfg.oxygen_depletion_rate = 2.2 # Heavy gravity / atmosphere drag
	cfg.hazard_level = "ELEVATED"
	cfg.thermal_drain_rate = 1.3
	
	# Resource Distribution - Heavy mineral wealth!
	cfg.deposit_specs = [
		{"pos": Vector2(-700, 480), "type": 0, "radius": 32.0}, # Crystals (Dense)
		{"pos": Vector2(-600, 560), "type": 0, "radius": 34.0},
		{"pos": Vector2(-760, 640), "type": 0, "radius": 30.0},
		{"pos": Vector2(-500, 640), "type": 0, "radius": 32.0},
		{"pos": Vector2(-740, -400), "type": 1, "radius": 34.0}, # Titanium (Heavy veins)
		{"pos": Vector2(-800, -500), "type": 1, "radius": 36.0},
		{"pos": Vector2(-640, -460), "type": 1, "radius": 32.0},
		{"pos": Vector2(-600, -380), "type": 1, "radius": 30.0},
		{"pos": Vector2(500, 600), "type": 2, "radius": 24.0}   # Biomass (Sparse)
	]
	
	cfg.collectable_specs = [
		{"pos": Vector2(80, -100), "type": 0, "qty": 1},   # Oxygen
		{"pos": Vector2(-280, -280), "type": 0, "qty": 1},
		{"pos": Vector2(500, -360), "type": 1, "qty": 4},  # Dense Titanium
		{"pos": Vector2(640, -400), "type": 1, "qty": 4},
		{"pos": Vector2(-200, 240), "type": 1, "qty": 3},
		{"pos": Vector2(-520, 520), "type": 2, "qty": 2},  # Crystals
		{"pos": Vector2(-580, 600), "type": 2, "qty": 3},
		{"pos": Vector2(140, 200), "type": 2, "qty": 2},
		{"pos": Vector2(440, 540), "type": 3, "qty": 1}   # Biomass
	]
	
	# Heavy armored enemy pack
	cfg.enemy_scouts_count = 2
	cfg.enemy_spitters_count = 3
	cfg.enemy_brutes_count = 4 # Heavy brutes dominating the super-earth surface
	cfg.has_boss = false
	cfg.base_aggression = 0.75
	
	# Mission Sequence for LHS 1140 b
	cfg.mission_sequence = [
		{
			"id": "lhs_01_minerals",
			"title": "SUPER-EARTH EXTRACTION",
			"desc": "Heavy mineral veins detected. Harvest 4 Titanium units from the dense super-earth crust.",
			"type": 0, # COLLECT_OXYGEN / generic resource collection
			"target": 4.0,
			"rewards": {"crystals": 6, "titanium": 6},
			"params": {"required_resource": "titanium"},
			"unit": "Titanium"
		},
		{
			"id": "lhs_02_survive",
			"title": "HEAVY GRAVITY COMBAT",
			"desc": "Armored brute predators converging. Survive the high-gravity pressure assault for 15 seconds.",
			"type": 3, # SURVIVE_ENCOUNTER
			"target": 15.0,
			"rewards": {"oxygen_cells": 3, "crystals": 8},
			"params": {"duration": 15.0, "fail_on_death": true},
			"unit": "Seconds"
		},
		{
			"id": "lhs_03_extraction",
			"title": "SUPER-EARTH RETURN",
			"desc": "Core samples secured. Evacuate back to base airlock safely.",
			"type": 5, # RETURN_TO_BASE
			"target": 1.0,
			"rewards": {"mission_rating": "SUPER-EARTH MASTER"},
			"params": {"target_zone": "habitat_airlock"},
			"unit": "Airlock"
		}
	]
	
	return cfg


static func create_kepler_186_f() -> Resource:
	var cfg = load("res://scripts/components/planet_level_config.gd").new()
	cfg.planet_id = "kepler_186_f"
	cfg.planet_name = "Kepler-186 f"
	cfg.description = "Habitable zone Earth-sized world (1.17 R_Earth) orbiting red dwarf Kepler-186. Subsurface cavern labyrinth."
	cfg.unlock_required_planet_id = "lhs_1140_b"
	cfg.unlock_required_mission_id = "lhs_03_extraction"
	cfg.unlock_description = "Complete 'SUPER-EARTH RETURN' on LHS 1140 b."

	cfg.ground_color = Color(0.12, 0.16, 0.24)
	cfg.canyon_wall_color = Color(0.22, 0.28, 0.40)
	cfg.barrier_color = Color(0.35, 0.65, 0.95, 0.75)
	cfg.ambient_tint = Color(0.65, 0.78, 0.95)
	cfg.oxygen_depletion_rate = 1.6
	cfg.hazard_level = "HAZARDOUS"
	cfg.thermal_drain_rate = 1.4

	cfg.deposit_specs = [
		{"pos": Vector2(-750, 450), "type": 0, "radius": 30.0},
		{"pos": Vector2(750, -450), "type": 0, "radius": 30.0},
		{"pos": Vector2(-750, -450), "type": 2, "radius": 28.0},
		{"pos": Vector2(750, 450), "type": 2, "radius": 28.0}
	]

	cfg.collectable_specs = [
		{"pos": Vector2(-360, -320), "type": 2, "qty": 4},
		{"pos": Vector2(360, 320), "type": 2, "qty": 4},
		{"pos": Vector2(-360, 320), "type": 3, "qty": 3},
		{"pos": Vector2(360, -320), "type": 3, "qty": 3},
		{"pos": Vector2(0, -120), "type": 0, "qty": 1},
		{"pos": Vector2(0, 120), "type": 0, "qty": 1}
	]

	cfg.enemy_scouts_count = 4
	cfg.enemy_spitters_count = 3
	cfg.enemy_brutes_count = 2
	cfg.has_boss = true
	cfg.base_aggression = 0.80

	cfg.mission_sequence = [
		{
			"id": "kepler_01_explore",
			"title": "LABYRINTH RECONNAISSANCE",
			"desc": "Penetrate the subsurface labyrinth and recover peripheral crystal deposits.",
			"type": 0,
			"target": 4.0,
			"rewards": {"crystals": 8, "titanium": 4},
			"params": {"required_resource": "crystals"},
			"unit": "Crystals"
		},
		{
			"id": "kepler_02_survive",
			"title": "SUB-ZERO LABYRINTH COMBAT",
			"desc": "Withstand alien predators in the freezing cavern tunnels for 20 seconds.",
			"type": 3,
			"target": 20.0,
			"rewards": {"oxygen_refill": 100.0, "biomass": 4},
			"params": {"duration": 20.0, "fail_on_death": true},
			"unit": "Seconds"
		},
		{
			"id": "kepler_03_extraction",
			"title": "CAVERN EVACUATION",
			"desc": "All labyrinth objectives complete. Return to habitat airlock.",
			"type": 5,
			"target": 1.0,
			"rewards": {"mission_rating": "LABYRINTH MASTER"},
			"params": {"target_zone": "habitat_airlock"},
			"unit": "Airlock"
		}
	]

	return cfg


static func create_proxima_centauri_b() -> Resource:
	var cfg = load("res://scripts/components/planet_level_config.gd").new()
	cfg.planet_id = "proxima_centauri_b"
	cfg.planet_name = "Proxima Centauri b"
	cfg.description = "Nearest exoplanet to Solar System (4.24 ly). Harsh stellar flare erosion and rugged split-canyon crags."
	cfg.unlock_required_planet_id = "kepler_186_f"
	cfg.unlock_required_mission_id = "kepler_03_extraction"
	cfg.unlock_description = "Complete 'CAVERN EVACUATION' on Kepler-186 f."

	cfg.ground_color = Color(0.24, 0.12, 0.14)
	cfg.canyon_wall_color = Color(0.44, 0.20, 0.22)
	cfg.barrier_color = Color(1.0, 0.35, 0.20, 0.80)
	cfg.ambient_tint = Color(1.0, 0.65, 0.65)
	cfg.oxygen_depletion_rate = 1.8
	cfg.hazard_level = "SEVERE"
	cfg.thermal_drain_rate = 1.5

	cfg.deposit_specs = [
		{"pos": Vector2(0, -160), "type": 1, "radius": 34.0},
		{"pos": Vector2(0, -60), "type": 1, "radius": 32.0},
		{"pos": Vector2(-280, -220), "type": 0, "radius": 28.0},
		{"pos": Vector2(280, 220), "type": 0, "radius": 28.0}
	]

	cfg.collectable_specs = [
		{"pos": Vector2(0, -60), "type": 1, "qty": 4},
		{"pos": Vector2(-280, -220), "type": 2, "qty": 2},
		{"pos": Vector2(280, 220), "type": 2, "qty": 2},
		{"pos": Vector2(-120, 220), "type": 0, "qty": 1},
		{"pos": Vector2(120, 220), "type": 0, "qty": 1}
	]

	cfg.enemy_scouts_count = 5
	cfg.enemy_spitters_count = 4
	cfg.enemy_brutes_count = 3
	cfg.has_boss = true
	cfg.base_aggression = 0.85

	cfg.mission_sequence = [
		{
			"id": "proxima_01_flares",
			"title": "FLARE CRAG TITANIUM",
			"desc": "Collect 4 titanium units exposed by stellar flare erosion in the central crag.",
			"type": 0,
			"target": 4.0,
			"rewards": {"crystals": 8, "titanium": 8},
			"params": {"required_resource": "titanium"},
			"unit": "Titanium"
		},
		{
			"id": "proxima_02_survive",
			"title": "SUPERFLARE ASSAULT",
			"desc": "Survive the flare-crazed predator wave for 20 seconds.",
			"type": 3,
			"target": 20.0,
			"rewards": {"oxygen_cells": 4, "energy_refill": 100.0},
			"params": {"duration": 20.0, "fail_on_death": true},
			"unit": "Seconds"
		},
		{
			"id": "proxima_03_extraction",
			"title": "FLARE CRAG EXTRACTION",
			"desc": "Telemetry recorded. Return to habitat airlock before next superflare cycle.",
			"type": 5,
			"target": 1.0,
			"rewards": {"mission_rating": "FLARE MASTER"},
			"params": {"target_zone": "habitat_airlock"},
			"unit": "Airlock"
		}
	]

	return cfg


static func create_k2_18_b() -> Resource:
	var cfg = load("res://scripts/components/planet_level_config.gd").new()
	cfg.planet_id = "k2_18_b"
	cfg.planet_name = "K2-18 b"
	cfg.description = "Candidate Hycean ocean world / sub-Neptune (8.63 M_Earth, 2.61 R_Earth) with methane atmosphere and fluid shoals."
	cfg.unlock_required_planet_id = "proxima_centauri_b"
	cfg.unlock_required_mission_id = "proxima_03_extraction"
	cfg.unlock_description = "Complete 'FLARE CRAG EXTRACTION' on Proxima Centauri b."

	cfg.ground_color = Color(0.08, 0.18, 0.24)
	cfg.canyon_wall_color = Color(0.12, 0.34, 0.44)
	cfg.barrier_color = Color(0.20, 0.90, 0.80, 0.75)
	cfg.ambient_tint = Color(0.40, 0.90, 0.85)
	cfg.oxygen_depletion_rate = 2.0
	cfg.hazard_level = "VOLATILE"
	cfg.thermal_drain_rate = 1.2

	cfg.deposit_specs = [
		{"pos": Vector2(-280, -180), "type": 2, "radius": 32.0},
		{"pos": Vector2(280, 180), "type": 2, "radius": 32.0},
		{"pos": Vector2(-180, 0), "type": 0, "radius": 28.0},
		{"pos": Vector2(180, 0), "type": 0, "radius": 28.0}
	]

	cfg.collectable_specs = [
		{"pos": Vector2(-280, -180), "type": 3, "qty": 3},
		{"pos": Vector2(280, 180), "type": 3, "qty": 3},
		{"pos": Vector2(-180, 0), "type": 2, "qty": 2},
		{"pos": Vector2(180, 0), "type": 2, "qty": 2},
		{"pos": Vector2(0, -80), "type": 0, "qty": 1},
		{"pos": Vector2(0, 80), "type": 0, "qty": 1}
	]

	cfg.enemy_scouts_count = 4
	cfg.enemy_spitters_count = 5
	cfg.enemy_brutes_count = 2
	cfg.has_boss = true
	cfg.base_aggression = 0.90

	cfg.mission_sequence = [
		{
			"id": "k2_01_samples",
			"title": "HYCEAN BIOMASS SALVAGE",
			"desc": "Retrieve 3 aquatic biomass specimens from the submerged shoal islands.",
			"type": 1,
			"target": 3.0,
			"rewards": {"biomass": 6, "crystals": 6},
			"params": {"required_resource": "biomass"},
			"unit": "Biomass"
		},
		{
			"id": "k2_02_survive",
			"title": "ARCHIPELAGO AMBUSH",
			"desc": "Survive coordinated aquatic spitter swarm attack for 20 seconds.",
			"type": 3,
			"target": 20.0,
			"rewards": {"oxygen_refill": 100.0, "crystals": 10},
			"params": {"duration": 20.0, "fail_on_death": true},
			"unit": "Seconds"
		},
		{
			"id": "k2_03_extraction",
			"title": "HYCEAN ARCHIPELAGO RETURN",
			"desc": "Expedition data secured. Return safely to habitat airlock.",
			"type": 5,
			"target": 1.0,
			"rewards": {"mission_rating": "HYCEAN MASTER"},
			"params": {"target_zone": "habitat_airlock"},
			"unit": "Airlock"
		}
	]

	return cfg


static func get_config_by_id(planet_id: String) -> Resource:
	match planet_id:
		"lhs_1140_b":
			return create_lhs_1140_b()
		"kepler_186_f":
			return create_kepler_186_f()
		"proxima_centauri_b":
			return create_proxima_centauri_b()
		"k2_18_b":
			return create_k2_18_b()
		_:
			return create_trappist_1_e()

