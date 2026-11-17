"""
Shared helpers for all 7 path-finding algorithms.

Grid format: a list of rows, grid[y][x]. 0 = walkable tile, 1 = wall.
Cells are (x, y) tuples. Moves: 4 directions (right, left, down, up), cost 1.
"""
import time

DIRECTIONS = [(1, 0), (-1, 0), (0, 1), (0, -1)]


def neighbors(grid, cell):
    """Walkable cells next to `cell` (inside the grid, not a wall)."""
    x, y = cell
    for dx, dy in DIRECTIONS:
        nx, ny = x + dx, y + dy
        if 0 <= ny < len(grid) and 0 <= nx < len(grid[0]) and grid[ny][nx] == 0:
            yield (nx, ny)


def manhattan(a, b):
    """Heuristic h(n) = |dx| + |dy|."""
    return abs(a[0] - b[0]) + abs(a[1] - b[1])


def make_path(came_from, goal):
    """Follow the parent links back from the goal to the start."""
    path = [goal]
    while came_from[path[-1]] is not None:
        path.append(came_from[path[-1]])
    return path[::-1]


def result(name, found, path, nodes_expanded, start_time):
    """The same answer format for every algorithm."""
    return {
        "algorithm": name,
        "found": found,
        "path": [list(cell) for cell in path],
        "nodes_expanded": nodes_expanded,
        "time_ms": round((time.perf_counter() - start_time) * 1000.0, 3),
    }


def is_walkable(grid, cell):
    x, y = cell
    return 0 <= y < len(grid) and 0 <= x < len(grid[0]) and grid[y][x] == 0
