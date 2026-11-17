"""
Path finding: 7 algorithms, one file each, all with the same signature

    search(grid, start, goal) -> {"path", "nodes_expanded", "time_ms", "found", "algorithm"}

Uninformed: BFS, DFS, DLS (limit 20), IDDFS (limit 1..40), Bidirectional
Informed:   Greedy Best-First, A*  (Manhattan heuristic)
"""
from . import astar, bfs, bidirectional, dfs, dls, greedy, iddfs
from .common import is_walkable

ALGORITHMS = {
    "bfs": bfs.search,
    "dfs": dfs.search,
    "dls": dls.search,
    "iddfs": iddfs.search,
    "bidirectional": bidirectional.search,
    "greedy": greedy.search,
    "astar": astar.search,
}


def find_path(algorithm, grid, start, goal):
    """Runs one algorithm by name. Start and goal must be walkable tiles."""
    if algorithm not in ALGORITHMS:
        raise ValueError(f"unknown algorithm '{algorithm}'")
    if not is_walkable(grid, start) or not is_walkable(grid, goal):
        return {"algorithm": algorithm, "found": False, "path": [], "nodes_expanded": 0, "time_ms": 0.0}
    return ALGORITHMS[algorithm](grid, start, goal)
