"""Depth-First Search: expands the newest cell first (a LIFO stack).
Uninformed. Finds a path, but usually not the shortest one."""
import time
from .common import make_path, neighbors, result


def search(grid, start, goal):
    t0 = time.perf_counter()
    start, goal = tuple(start), tuple(goal)
    stack = [start]
    came_from = {start: None}
    expanded = 0
    while stack:
        cell = stack.pop()                     # newest cell first
        expanded += 1
        if cell == goal:
            return result("dfs", True, make_path(came_from, goal), expanded, t0)
        for nxt in neighbors(grid, cell):
            if nxt not in came_from:
                came_from[nxt] = cell
                stack.append(nxt)
    return result("dfs", False, [], expanded, t0)
