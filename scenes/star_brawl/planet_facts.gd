extends RefCounted

# Radius and orbital period: NASA Exoplanet Catalog. Surface palettes are game art,
# not observations of these distant worlds.
const DATA := [
	{"name": "TRAPPIST-1 e", "radius": 0.92, "year": 6.1, "class": "TERRESTRIAL", "source": "https://science.nasa.gov/exoplanet-catalog/trappist-1-e/", "biome": "rock", "base": Color("3d807c"), "light": Color("98c6af"), "dark": Color("274a62"), "sky": Color("465e91"), "horizon": Color("8ab3c7"), "rim": Color("76d5c7"), "danger": Color("fa9e90"), "star": Color("ff9b83"), "hazard": "acid"},
	{"name": "LHS 1140 b", "radius": 1.73, "year": 24.7, "class": "SUPER EARTH", "source": "https://science.nasa.gov/exoplanet-catalog/lhs-1140-b/", "biome": "ice", "base": Color("47738f"), "light": Color("c6e9ee"), "dark": Color("263f68"), "sky": Color("414e82"), "horizon": Color("8fa9ca"), "rim": Color("bcf2f6"), "danger": Color("84ddf7"), "star": Color("e38b8c"), "hazard": "ice"},
	{"name": "Kepler-452 b", "radius": 1.63, "year": 384.8, "class": "SUPER EARTH", "source": "https://science.nasa.gov/exoplanet-catalog/kepler-452-b/", "biome": "highland", "base": Color("547b70"), "light": Color("d2c98b"), "dark": Color("3a526d"), "sky": Color("5079aa"), "horizon": Color("a6c1cf"), "rim": Color("c5d5a3"), "danger": Color("ecb572"), "star": Color("ffe1a1"), "hazard": "acid"},
	{"name": "GJ 667 C c", "radius": 1.77, "year": 28.1, "class": "SUPER EARTH", "estimate": true, "source": "https://science.nasa.gov/exoplanet-catalog/gj-667-c-c/", "biome": "crystal", "base": Color("627b91"), "light": Color("bfe4e4"), "dark": Color("344d6e"), "sky": Color("536b89"), "horizon": Color("a5bdcd"), "rim": Color("a8f0ec"), "danger": Color("bba0f2"), "star": Color("ffc7a1"), "hazard": "plasma"},
	{"name": "Proxima Centauri b", "radius": 1.02, "year": 11.2, "class": "SUPER EARTH", "estimate": true, "source": "https://science.nasa.gov/exoplanet-catalog/proxima-centauri-b/", "biome": "frost", "base": Color("547088"), "light": Color("d3e1e8"), "dark": Color("273d5e"), "sky": Color("384b77"), "horizon": Color("879bb9"), "rim": Color("cae9f2"), "danger": Color("fa9d92"), "star": Color("f98678"), "hazard": "ice"},
	{"name": "55 Cancri e", "radius": 1.875, "year": 0.7, "class": "SUPER EARTH", "source": "https://science.nasa.gov/exoplanet-catalog/55-cancri-e/", "biome": "lava", "base": Color("853f47"), "light": Color("f8a65c"), "dark": Color("452d50"), "sky": Color("8d4d70"), "horizon": Color("dda08e"), "rim": Color("ffc47d"), "danger": Color("ff8a4e"), "star": Color("ffe2aa"), "hazard": "lava"},
	{"name": "TOI-700 d", "radius": 1.145, "year": 37.4, "class": "SUPER EARTH", "source": "https://science.nasa.gov/exoplanet-catalog/toi-700-d/", "biome": "reef", "base": Color("247f88"), "light": Color("9ed9bd"), "dark": Color("27566c"), "sky": Color("47889b"), "horizon": Color("a7d6c5"), "rim": Color("a8e8ca"), "danger": Color("f2b476"), "star": Color("ffa693"), "hazard": "acid"},
	{"name": "K2-18 b", "radius": 2.37, "year": 32.9, "class": "SUPER EARTH", "source": "https://science.nasa.gov/exoplanet-catalog/k2-18-b/", "biome": "cloud", "base": Color("457ba0"), "light": Color("d1d8d4"), "dark": Color("34476d"), "sky": Color("4f688e"), "horizon": Color("a7bccc"), "rim": Color("c0e5ec"), "danger": Color("aac8ff"), "star": Color("ffc7aa"), "hazard": "plasma"},
	{"name": "Kepler-186 f", "radius": 1.17, "year": 129.9, "class": "SUPER EARTH", "source": "https://science.nasa.gov/exoplanet-catalog/kepler-186-f/", "biome": "dust", "base": Color("786071"), "light": Color("c5a5a6"), "dark": Color("474563"), "sky": Color("725c8d"), "horizon": Color("b7a7bf"), "rim": Color("dfb6da"), "danger": Color("f19ac2"), "star": Color("f49a88"), "hazard": "plasma"},
	{"name": "Kepler-62 f", "radius": 1.41, "year": 267.3, "class": "SUPER EARTH", "source": "https://science.nasa.gov/exoplanet-catalog/kepler-62-f/", "biome": "sanctuary", "base": Color("42768d"), "light": Color("dcc99d"), "dark": Color("294766"), "sky": Color("3b6087"), "horizon": Color("96b4c6"), "rim": Color("f4dfaa"), "danger": Color("ffe19e"), "star": Color("ffe1aa"), "hazard": "plasma"}
]


static func at(index: int) -> Dictionary:
	return DATA[clampi(index, 0, DATA.size() - 1)]


static func short_fact(index: int) -> String:
	var fact: Dictionary = at(index)
	var estimated := "~" if bool(fact.get("estimate", false)) else ""
	return "%s%.2f× EARTH  •  %.1f-DAY YEAR  •  %s" % [estimated, float(fact["radius"]), float(fact["year"]), str(fact["class"])]
