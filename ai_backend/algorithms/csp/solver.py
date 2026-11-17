"""
CSP: where to put the items at the start of a level.

Variables   : oxygen_tank_1, oxygen_tank_2, safe_dome, health_pickup, energy_pickup
Domain      : walkable tile positions [x, y] of the level
Constraints :
  1. not inside a wall                                   (unary)
  2. not near an enemy or the boss spawn                 (unary)
  3. items at least `min_spacing` tiles apart            (binary)
  4. at least one OXYGEN item (tank or dome) in each third of the level (global)
Search      : backtracking + forward checking.
  After each assignment, forward checking removes the values from the other
  variables' domains that would break a constraint. If a domain becomes empty
  we know at once that this choice fails, and try the next value (a backtrack).
Distance    : Manhattan, in tiles.
"""
import random

VARIABLES = ["oxygen_tank_1", "oxygen_tank_2", "safe_dome", "health_pickup", "energy_pickup"]
OXYGEN_ITEMS = ["oxygen_tank_1", "oxygen_tank_2", "safe_dome"]


def manhattan(a, b) -> int:
    return abs(a[0] - b[0]) + abs(a[1] - b[1])


def place_items(candidates, walls, enemies, boss_spawn, level_width, min_enemy_distance=4, min_spacing=5, seed=None) -> dict:
    """level_width = number of tiles across. Returns positions + number of backtracks."""
    walls = {tuple(w) for w in walls}
    dangers = [tuple(e) for e in enemies] + [tuple(boss_spawn)]

    def third(tile):                                    # 0, 1 or 2: which third of the level
        return min(2, tile[0] * 3 // level_width)

    # Unary constraints 1 and 2 shrink the domain before the search starts.
    tiles = [tuple(t) for t in candidates]
    random.Random(seed).shuffle(tiles)                  # a different (valid) layout per seed
    domain = [t for t in tiles if t not in walls and all(manhattan(t, d) >= min_enemy_distance for d in dangers)]
    domains = {var: list(domain) for var in VARIABLES}
    stats = {"backtracks": 0}

    def forward_check(assignment, domains):
        """New domains for the unassigned variables, or None if one becomes empty."""
        unassigned = [v for v in VARIABLES if v not in assignment]
        new = {}
        for var in unassigned:
            # Constraint 3: remove tiles too close to an item already placed.
            new[var] = [t for t in domains[var] if all(manhattan(t, p) >= min_spacing for p in assignment.values())]
        # Constraint 4: the oxygen items still to place must cover the thirds still missing.
        covered = {third(assignment[v]) for v in OXYGEN_ITEMS if v in assignment}
        missing = {0, 1, 2} - covered
        oxygen_left = [v for v in OXYGEN_ITEMS if v in new]
        if len(missing) > len(oxygen_left):
            return None
        if len(missing) == len(oxygen_left):
            for var in oxygen_left:                     # every remaining oxygen item MUST fill a missing third
                new[var] = [t for t in new[var] if third(t) in missing]
        if any(len(values) == 0 for values in new.values()):
            return None                                 # a domain is empty -> this choice fails
        return new

    def backtrack(assignment, domains):
        if len(assignment) == len(VARIABLES):
            return assignment
        # Choose the variable with the fewest values left (MRV heuristic).
        var = min((v for v in VARIABLES if v not in assignment), key=lambda v: len(domains[v]))
        for value in domains[var]:
            trial = {**assignment, var: value}
            new_domains = forward_check(trial, domains)
            if new_domains is not None:
                result = backtrack(trial, {**domains, **new_domains})
                if result:
                    return result
            stats["backtracks"] += 1                    # this value failed: undo it, try the next
        return None

    first = forward_check({}, domains)
    solution = backtrack({}, first) if first is not None else None
    return {
        "success": solution is not None,
        "positions": {var: list(solution[var]) for var in VARIABLES} if solution else {},
        "backtracks": stats["backtracks"],
    }
