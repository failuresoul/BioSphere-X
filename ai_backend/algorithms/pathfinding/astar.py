"""
A* Pathfinding Algorithm for BioSphere-X 2D Grid Maps.
Computes optimal paths balancing exact cost g(n) and heuristic h(n).
"""
from typing import List, Tuple, Set, Dict, Optional
import heapq
import time
from .common import get_neighbors, reconstruct_path, validate_coordinates, heuristic_octile, heuristic_manhattan


def astar_search(
    start: Tuple[int, int],
    goal: Tuple[int, int],
    grid_width: int,
    grid_height: int,
    blocked_cells: Set[Tuple[int, int]],
    allow_diagonal: bool = True
) -> Dict:
    """
    Computes an optimal path from start to goal on a 2D discrete grid using A*.
    Returns standardized dictionary with success, path, nodes_expanded, and execution_time_ms.
    """
    t0 = time.perf_counter()
    
    is_valid, err_msg = validate_coordinates(start, goal, grid_width, grid_height, blocked_cells)
    if not is_valid:
        t_elapsed = (time.perf_counter() - t0) * 1000.0
        return {
            "success": False,
            "path": [],
            "nodes_expanded": 0,
            "execution_time_ms": round(t_elapsed, 4),
            "message": err_msg,
            "algorithm": "astar"
        }

    if start == goal:
        t_elapsed = (time.perf_counter() - t0) * 1000.0
        return {
            "success": True,
            "path": [start],
            "nodes_expanded": 1,
            "execution_time_ms": round(t_elapsed, 4),
            "message": "Start is goal",
            "algorithm": "astar"
        }

    heuristic_func = heuristic_octile if allow_diagonal else heuristic_manhattan

    counter = 0
    open_heap = []
    heapq.heappush(open_heap, (heuristic_func(start, goal), counter, start))
    
    came_from: Dict[Tuple[int, int], Tuple[int, int]] = {}
    g_score: Dict[Tuple[int, int], float] = {start: 0.0}
    in_open_set: Set[Tuple[int, int]] = {start}
    closed_set: Set[Tuple[int, int]] = set()
    nodes_expanded = 0

    while open_heap:
        _, _, current = heapq.heappop(open_heap)
        in_open_set.discard(current)
        closed_set.add(current)
        nodes_expanded += 1

        if current == goal:
            path = reconstruct_path(came_from, current)
            t_elapsed = (time.perf_counter() - t0) * 1000.0
            return {
                "success": True,
                "path": path,
                "nodes_expanded": nodes_expanded,
                "execution_time_ms": round(t_elapsed, 4),
                "message": f"Optimal A* path found ({len(path)} steps)",
                "algorithm": "astar"
            }

        for neighbor, cost in get_neighbors(current, grid_width, grid_height, blocked_cells, allow_diagonal):
            if neighbor in closed_set:
                continue

            tentative_g = g_score[current] + cost
            if tentative_g < g_score.get(neighbor, float("inf")):
                came_from[neighbor] = current
                g_score[neighbor] = tentative_g
                f = tentative_g + heuristic_func(neighbor, goal)
                
                if neighbor not in in_open_set:
                    counter += 1
                    heapq.heappush(open_heap, (f, counter, neighbor))
                    in_open_set.add(neighbor)

    t_elapsed = (time.perf_counter() - t0) * 1000.0
    return {
        "success": False,
        "path": [],
        "nodes_expanded": nodes_expanded,
        "execution_time_ms": round(t_elapsed, 4),
        "message": "Goal is unreachable (No path exists)",
        "algorithm": "astar"
    }


def astar_grid_search(
    start: Tuple[int, int],
    goal: Tuple[int, int],
    grid_width: int,
    grid_height: int,
    blocked_cells: Set[Tuple[int, int]],
    allow_diagonal: bool = True
) -> Optional[List[Tuple[int, int]]]:
    """
    Legacy wrapper returning Optional[List[Tuple[int, int]]] for backwards compatibility.
    """
    res = astar_search(start, goal, grid_width, grid_height, blocked_cells, allow_diagonal)
    if res["success"]:
        return res["path"]
    return None
