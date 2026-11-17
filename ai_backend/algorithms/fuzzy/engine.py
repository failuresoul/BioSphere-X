"""
Fuzzy logic: how aggressive should the boss be? (0 = calm, 1 = very aggressive)

Inputs
  player_health   0-100     low / medium / high
  recent_damage   0-50      low / medium / high   (damage the player took in the last few seconds)
  distance        0-1000 px near / medium / far
Output
  aggression      0-1       low / medium / high

Steps
  1. Fuzzify:   triangle membership functions turn each number into degrees 0-1.
  2. Rules:     AND = min. Each rule cuts ("clips") its output set at its strength.
  3. Aggregate: the clipped output sets are combined with max.
  4. Centroid:  aggression = centre of gravity of the combined shape.
"""


def triangle(x: float, a: float, b: float, c: float) -> float:
    """0 at a, rises to 1 at b, falls to 0 at c. (a == b or b == c makes a shoulder.)"""
    if x == b:
        return 1.0
    if x <= a or x >= c:
        return 0.0
    return (x - a) / (b - a) if x < b else (c - x) / (c - b)


HEALTH = {"low": (0, 0, 40), "medium": (20, 50, 80), "high": (60, 100, 100)}
DAMAGE = {"low": (0, 0, 15), "medium": (5, 20, 35), "high": (25, 50, 50)}
DISTANCE = {"near": (0, 0, 300), "medium": (150, 400, 650), "far": (500, 1000, 1000)}
AGGRESSION = {"low": (0, 0, 0.5), "medium": (0.25, 0.5, 0.75), "high": (0.5, 1, 1)}

# IF <conditions> THEN aggression is <output>
RULES = [
    ({"health": "low"}, "low"),                         # R1: player is weak -> go easy
    ({"health": "high", "distance": "near"}, "high"),   # R2: healthy player up close -> press hard
    ({"damage": "high"}, "low"),                        # R3: player just took a beating -> give a break
    ({"health": "medium"}, "medium"),                   # R4: middle health -> normal
    ({"distance": "far"}, "medium"),                    # R5: far away -> chase at a normal pace
]


def fuzzy_aggression(player_health: float, recent_damage: float, distance: float) -> dict:
    # 1. Fuzzify (clamp inputs to their ranges first)
    degrees = {
        "health": {t: triangle(max(0, min(100, player_health)), *abc) for t, abc in HEALTH.items()},
        "damage": {t: triangle(max(0, min(50, recent_damage)), *abc) for t, abc in DAMAGE.items()},
        "distance": {t: triangle(max(0, min(1000, distance)), *abc) for t, abc in DISTANCE.items()},
    }
    # 2. Rule strengths (AND = min); several rules for the same output -> max
    strength = {"low": 0.0, "medium": 0.0, "high": 0.0}
    for conditions, output in RULES:
        fire = min(degrees[var][term] for var, term in conditions.items())
        strength[output] = max(strength[output], fire)
    # 3 + 4. Clip each output set, combine with max, take the centroid (sampled 0.00 .. 1.00)
    top = bottom = 0.0
    for i in range(101):
        x = i / 100
        mu = max(min(strength[t], triangle(x, *abc)) for t, abc in AGGRESSION.items())
        top += x * mu
        bottom += mu
    aggression = top / bottom if bottom > 0 else 0.5
    return {"aggression": round(aggression, 3), "rule_strengths": strength, "memberships": degrees}
