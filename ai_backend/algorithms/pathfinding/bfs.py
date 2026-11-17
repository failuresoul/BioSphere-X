"""Breadth-First Search: expands the oldest cell first (a FIFO queue).
Uninformed. Always finds the shortest path when every move costs 1."""
import time
from collections import deque
from .common import make_path, neighbors, result


def search(grid, start, goal):
    t0 = time.perf_counter()
    start, goal = tuple(start), tuple(goal)
    queue = deque([start])
    came_from = {start: None}
    expanded = 0
    while queue:
        cell = queue.popleft()                 # oldest cell first
        expanded += 1
        if cell == goal:
            return result("bfs", True, make_path(came_from, goal), expanded, t0)
        for nxt in neighbors(grid, cell):
            if nxt not in came_from:
                came_from[nxt] = cell
                queue.append(nxt)
    return result("bfs", False, [], expanded, t0)
