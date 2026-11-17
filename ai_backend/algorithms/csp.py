"""
CSP: place pickups (health / energy) on arena tiles.

Variables : one per pickup.
Domains   : candidate floor tiles of the arena grid.
Constraints:
  - not inside a wall                          (unary)
  - not near the enemy  (distance >= min_enemy_distance)   (unary)
  - not too close to each other (distance >= min_spacing)  (binary)
Solved with backtracking search + forward checking. Distance = Manhattan.
"""
import random


def manhattan(a, b) -> int:
    return abs(a[0] - b[0]) + abs(a[1] - b[1])


def place_pickups(candidates, walls, enemy, items, min_enemy_distance=5, min_spacing=4, seed=None) -> dict:
    wall_set = {tuple(w) for w in walls}
    tiles = [tuple(t) for t in candidates]
    random.Random(seed).shuffle(tiles)                     # different (but valid) layouts each fight

    # Unary constraints shrink every domain before the search starts.
    base = [t for t in tiles if t not in wall_set and manhattan(t, enemy) >= min_enemy_distance]
    domains = {i: list(base) for i in range(len(items))}
    stats = {"assignments_tried": 0}

    def backtrack(assignment: dict, domains: dict):
        if len(assignment) == len(items):
            return assignment
        # Choose the unassigned variable with the fewest values left (MRV heuristic).
        var = min((v for v in domains if v not in assignment), key=lambda v: len(domains[v]))
        for value in domains[var]:
            stats["assignments_tried"] += 1
            # Forward checking: remove values that are now too close from the other domains.
            pruned = {v: [t for t in domains[v] if manhattan(t, value) >= min_spacing]
                      for v in domains if v not in assignment and v != var}
            if all(pruned.values()):                       # no domain became empty
                result = backtrack({**assignment, var: value}, {**domains, **pruned})
                if result:
                    return result
        return None                                        # dead end -> backtrack

    solution = backtrack({}, domains) if all(domains.values()) or not items else None
    placements = [{"item": items[i], "tile": list(solution[i])} for i in sorted(solution)] if solution else []
    return {"success": solution is not None, "placements": placements,
            "assignments_tried": stats["assignments_tried"]}
