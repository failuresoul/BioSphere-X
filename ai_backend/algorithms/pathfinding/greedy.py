"""
Greedy Best-First Search Pathfinding Algorithm.
Prioritizes nodes solely using the heuristic distance h(n) towards the goal.
"""
from typing import List, Tuple, Set, Dict, Optional
import heapq
import time
from .common import get_neighbors, reconstruct_path, validate_coordinates, heuristic_octile, heuristic_manhattan


def greedy_search(
    start: Tuple[int, int],
    goal: Tuple[int, int],
    grid_width: int,
    grid_height: int,
    blocked_cells: Set[Tuple[int, int]],
    allow_diagonal: bool = True
) -> Dict:
    """
    Executes Greedy Best-First Search.
    Returns path, success status, nodes expanded, and execution time.
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
            "algorithm": "greedy"
        }
        
    if start == goal:
        t_elapsed = (time.perf_counter() - t0) * 1000.0
        return {
            "success": True,
            "path": [start],
            "nodes_expanded": 1,
            "execution_time_ms": round(t_elapsed, 4),
            "message": "Start is goal",
            "algorithm": "greedy"
        }
        
    heuristic_func = heuristic_octile if allow_diagonal else heuristic_manhattan
    
    # Priority queue stores: (h_score, tie_breaker_counter, node)
    counter = 0
    open_heap = []
    heapq.heappush(open_heap, (heuristic_func(start, goal), counter, start))
    
    visited: Set[Tuple[int, int]] = {start}
    came_from: Dict[Tuple[int, int], Tuple[int, int]] = {}
    nodes_expanded = 0
    
    while open_heap:
        _, _, current = heapq.heappop(open_heap)
        nodes_expanded += 1
        
        if current == goal:
            path = reconstruct_path(came_from, current)
            t_elapsed = (time.perf_counter() - t0) * 1000.0
            return {
                "success": True,
                "path": path,
                "nodes_expanded": nodes_expanded,
                "execution_time_ms": round(t_elapsed, 4),
                "message": f"Greedy path found ({len(path)} steps)",
                "algorithm": "greedy"
            }
            
        for neighbor, _ in get_neighbors(current, grid_width, grid_height, blocked_cells, allow_diagonal):
            if neighbor not in visited:
                visited.add(neighbor)
                came_from[neighbor] = current
                counter += 1
                h_val = heuristic_func(neighbor, goal)
                heapq.heappush(open_heap, (h_val, counter, neighbor))
                
    t_elapsed = (time.perf_counter() - t0) * 1000.0
    return {
        "success": False,
        "path": [],
        "nodes_expanded": nodes_expanded,
        "execution_time_ms": round(t_elapsed, 4),
        "message": "Goal is unreachable (Explored all reachable nodes)",
        "algorithm": "greedy"
    }
