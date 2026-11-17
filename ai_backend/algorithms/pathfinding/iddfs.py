"""Iterative Deepening DFS: runs DLS with limit 1, 2, 3, ... 40.
Uninformed. Finds the shortest path (like BFS) with little memory (like DFS)."""
import time
from .common import make_path, result
from .dls import depth_limited

MAX_LIMIT = 40


def search(grid, start, goal):
    t0 = time.perf_counter()
    start, goal = tuple(start), tuple(goal)
    total_expanded = 0
    for limit in range(1, MAX_LIMIT + 1):      # deepen one step at a time
        found, came_from, expanded = depth_limited(grid, start, goal, limit)
        total_expanded += expanded
        if found:
            return result("iddfs", True, make_path(came_from, goal), total_expanded, t0)
    return result("iddfs", False, [], total_expanded, t0)
