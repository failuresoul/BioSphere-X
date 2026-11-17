"""A* Search: expands the cell with the lowest f(n) = g(n) + h(n).
Informed. g = moves so far, h = Manhattan distance. Always finds the shortest path."""
import heapq
import time
from .common import make_path, manhattan, neighbors, result


def search(grid, start, goal):
    t0 = time.perf_counter()
    start, goal = tuple(start), tuple(goal)
    # Priority queue of (f, -g, cell). On equal f, the larger g (closer to the goal) goes first.
    frontier = [(manhattan(start, goal), 0, start)]
    came_from = {start: None}
    g = {start: 0}
    closed = set()
    expanded = 0
    while frontier:
        _, neg_g, cell = heapq.heappop(frontier)
        cost = -neg_g
        if cell in closed:
            continue
        closed.add(cell)
        expanded += 1
        if cell == goal:
            return result("astar", True, make_path(came_from, goal), expanded, t0)
        for nxt in neighbors(grid, cell):
            new_g = cost + 1
            if new_g < g.get(nxt, float("inf")):
                g[nxt] = new_g
                came_from[nxt] = cell
                heapq.heappush(frontier, (new_g + manhattan(nxt, goal), -new_g, nxt))
    return result("astar", False, [], expanded, t0)
