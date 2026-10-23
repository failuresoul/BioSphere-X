extends Node2D

const PlanetFacts = preload("res://scenes/star_brawl/planet_facts.gd")

var planet_index := 0
var radius := 50.0


func set_planet(index: int, next_radius: float = 50.0) -> void:
	planet_index = clampi(index, 0, PlanetFacts.DATA.size() - 1)
	radius = next_radius
	queue_redraw()


func _draw() -> void:
	var fact: Dictionary = PlanetFacts.at(planet_index)
	var base: Color = fact["base"]
	var light: Color = fact["light"]
	var dark: Color = fact["dark"]
	var rim: Color = fact["rim"]
	var biome := str(fact["biome"])
	draw_circle(Vector2(4, 6) * radius / 50.0, radius * 1.08, Color(dark, 0.30))
	draw_circle(Vector2.ZERO, radius * 1.05, Color(rim, 0.23))
	draw_circle(Vector2.ZERO, radius, dark)
	draw_circle(Vector2(-radius * 0.10, -radius * 0.10), radius * 0.87, base)
	draw_circle(Vector2(-radius * 0.22, -radius * 0.23), radius * 0.65, base.lerp(light, 0.32))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1301 + planet_index * 1813
	if biome == "cloud":
		for band in 5:
			var y := (-0.58 + band * 0.29) * radius
			var half_width := sqrt(maxf(0.0, radius * radius - y * y)) * 0.85
			draw_line(Vector2(-half_width, y), Vector2(half_width, y - radius * 0.07), Color(light, 0.46), radius * (0.11 if band % 2 == 0 else 0.07))
	elif biome == "lava":
		for crack in 8:
			var angle := rng.randf_range(0.0, TAU)
			var start := Vector2.from_angle(angle) * radius * rng.randf_range(0.10, 0.42)
			var finish := start + Vector2.from_angle(angle + rng.randf_range(-0.8, 0.8)) * radius * 0.32
			draw_line(start, finish, Color(light, 0.88), radius * 0.05)
			draw_circle(finish, radius * 0.045, Color("ffe3a8"))
	elif biome == "crystal" or biome == "frost" or biome == "ice":
		for shard in 10:
			var at := Vector2(rng.randf_range(-0.62, 0.62), rng.randf_range(-0.65, 0.65)) * radius
			var size := radius * rng.randf_range(0.08, 0.19)
			draw_colored_polygon(PackedVector2Array([at + Vector2(0, -size), at + Vector2(size * 0.75, size * 0.3), at + Vector2(-size * 0.7, size * 0.5)]), Color(light, 0.64))
	else:
		for patch in 17:
			var at := Vector2(rng.randf_range(-0.72, 0.72), rng.randf_range(-0.72, 0.72)) * radius
			var max_size := radius - at.length() - radius * 0.04
			if max_size > radius * 0.03:
				draw_circle(at, minf(max_size, radius * rng.randf_range(0.035, 0.12)), Color(light if patch % 3 == 0 else dark, 0.48))
	if biome == "sanctuary":
		draw_arc(Vector2.ZERO, radius * 1.16, -0.33, PI + 0.30, 50, Color("f9e5b7", 0.82), maxf(2.0, radius * 0.035))
	elif biome == "dust":
		draw_arc(Vector2.ZERO, radius * 0.68, -0.8, 1.4, 28, Color(light, 0.35), maxf(2.0, radius * 0.04))
	draw_arc(Vector2.ZERO, radius * 0.98, 2.7, 5.8, 42, Color(light, 0.45), maxf(1.2, radius * 0.025))
