"""
Breadth-First Search (BFS) Pathfinding Algorithm.
Guarantees the shortest path on unweighted uniform-cost graphs.
"""
from typing import List, Tuple, Set, Dict, Optional
from collections import deque
import time
from .common import get_neighbors, reconstruct_path, validate_coordinates


def bfs_search(
    start: Tuple[int, int],
    goal: Tuple[int, int],
    grid_width: int,
    grid_height: int,
    blocked_cells: Set[Tuple[int, int]],
    allow_diagonal: bool = True
) -> Dict:
    """
    Executes BFS search on a 2D grid.
    Returns dictionary with:
      - success (bool)
      - path (List[Tuple[int, int]])
      - nodes_expanded (int)
      - execution_time_ms (float)
      - message (str)
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
            "algorithm": "bfs"
        }
        
    if start == goal:
        t_elapsed = (time.perf_counter() - t0) * 1000.0
        return {
            "success": True,
            "path": [start],
            "nodes_expanded": 1,
            "execution_time_ms": round(t_elapsed, 4),
            "message": "Start is goal",
            "algorithm": "bfs"
        }
        
    queue = deque([start])
    visited: Set[Tuple[int, int]] = {start}
    came_from: Dict[Tuple[int, int], Tuple[int, int]] = {}
    nodes_expanded = 0
    
    while queue:
        current = queue.popleft()
        nodes_expanded += 1
        
        if current == goal:
            path = reconstruct_path(came_from, current)
            t_elapsed = (time.perf_counter() - t0) * 1000.0
            return {
                "success": True,
                "path": path,
                "nodes_expanded": nodes_expanded,
                "execution_time_ms": round(t_elapsed, 4),
                "message": f"Path found ({len(path)} steps)",
                "algorithm": "bfs"
            }
            
        for neighbor, _ in get_neighbors(current, grid_width, grid_height, blocked_cells, allow_diagonal):
            if neighbor not in visited:
                visited.add(neighbor)
                came_from[neighbor] = current
                queue.append(neighbor)
                
    t_elapsed = (time.perf_counter() - t0) * 1000.0
    return {
        "success": False,
        "path": [],
        "nodes_expanded": nodes_expanded,
        "execution_time_ms": round(t_elapsed, 4),
        "message": "Goal is unreachable (No path exists)",
        "algorithm": "bfs"
    }
