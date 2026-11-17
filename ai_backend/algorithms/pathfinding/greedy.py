"""Greedy Best-First Search: expands the cell that LOOKS closest to the goal.
Informed: f(n) = h(n) (Manhattan). Fast, but the path is not always shortest."""
import heapq
import time
from .common import make_path, manhattan, neighbors, result


def search(grid, start, goal):
    t0 = time.perf_counter()
    start, goal = tuple(start), tuple(goal)
    frontier = [(manhattan(start, goal), start)]   # priority queue ordered by h(n)
    came_from = {start: None}
    expanded = 0
    while frontier:
        _, cell = heapq.heappop(frontier)
        expanded += 1
        if cell == goal:
            return result("greedy", True, make_path(came_from, goal), expanded, t0)
        for nxt in neighbors(grid, cell):
            if nxt not in came_from:
                came_from[nxt] = cell
                heapq.heappush(frontier, (manhattan(nxt, goal), nxt))
    return result("greedy", False, [], expanded, t0)
