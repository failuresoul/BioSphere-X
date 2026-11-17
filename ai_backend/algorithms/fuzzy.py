"""
Fuzzy logic: player health + distance  ->  boss aggression (low / medium / high).

1. Fuzzify the two inputs with 3 triangular membership functions each.
2. Fire 5 IF-THEN rules (AND = min, rules with the same output combine with max).
3. Defuzzify with a weighted average of the output term centres.
"""


def triangle(x: float, a: float, b: float, c: float) -> float:
    """Triangular membership: 0 at a, 1 at b, 0 at c (a == b or b == c gives a shoulder)."""
    if x == b:
        return 1.0
    if x <= a or x >= c:
        return 0.0
    return (x - a) / (b - a) if x < b else (c - x) / (c - b)


HEALTH = {"low": (0, 0, 40), "medium": (20, 50, 80), "high": (60, 100, 100)}            # percent
DISTANCE = {"near": (0, 0, 300), "medium": (150, 400, 650), "far": (500, 1000, 1000)}  # pixels
AGGRESSION_CENTRES = {"low": 20.0, "medium": 50.0, "high": 80.0}

# (health term, distance term or None, output term)
RULES = [
    ("high", None, "high"),       # R1: IF health is high THEN aggression is high
    ("medium", None, "medium"),   # R2: IF health is medium THEN aggression is medium
    ("low", None, "low"),         # R3: IF health is low THEN aggression is low (give the player a chance)
    (None, "far", "high"),        # R4: IF distance is far THEN aggression is high (close the gap)
    ("low", "near", "low"),       # R5: IF health is low AND distance is near THEN aggression is low
]


def fuzzy_aggression(player_health: float, distance: float) -> dict:
    health = max(0.0, min(100.0, player_health))
    dist = max(0.0, min(1000.0, distance))
    h = {term: triangle(health, *abc) for term, abc in HEALTH.items()}
    d = {term: triangle(dist, *abc) for term, abc in DISTANCE.items()}

    strength = {"low": 0.0, "medium": 0.0, "high": 0.0}
    for h_term, d_term, out in RULES:
        parts = []
        if h_term:
            parts.append(h[h_term])
        if d_term:
            parts.append(d[d_term])
        strength[out] = max(strength[out], min(parts))      # AND = min, combine = max

    total = sum(strength.values())
    value = sum(strength[t] * AGGRESSION_CENTRES[t] for t in strength) / total if total > 0 else 50.0
    label = "low" if value < 35 else ("medium" if value < 65 else "high")
    return {"aggression": round(value, 2), "label": label, "rule_strengths": strength,
            "health_membership": h, "distance_membership": d}
