"""Depth-Limited Search: DFS that never goes deeper than `limit` moves.
Uninformed. Fails if the goal is further away than the limit (default 20)."""
import time
from .common import make_path, neighbors, result


def depth_limited(grid, start, goal, limit):
    """DFS with a depth limit. Returns (found, came_from, nodes_expanded).
    A cell is visited again only if we reach it with fewer moves than before."""
    stack = [(start, 0)]                       # (cell, depth)
    came_from = {start: None}
    best_depth = {start: 0}
    expanded = 0
    while stack:
        cell, depth = stack.pop()
        expanded += 1
        if cell == goal:
            return True, came_from, expanded
        if depth == limit:
            continue                           # limit reached: do not go deeper
        for nxt in neighbors(grid, cell):
            if depth + 1 < best_depth.get(nxt, limit + 1):
                best_depth[nxt] = depth + 1
                came_from[nxt] = cell
                stack.append((nxt, depth + 1))
    return False, came_from, expanded


def search(grid, start, goal, limit=20):
    t0 = time.perf_counter()
    start, goal = tuple(start), tuple(goal)
    found, came_from, expanded = depth_limited(grid, start, goal, limit)
    return result("dls", found, make_path(came_from, goal) if found else [], expanded, t0)
