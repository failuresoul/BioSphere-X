"""
Depth-Limited Search (DLS) Pathfinding Algorithm.
Explores paths using DFS up to a specified maximum depth limit.
"""
from typing import List, Tuple, Set, Dict, Optional
import time
from .common import get_neighbors, reconstruct_path, validate_coordinates


def dls_search(
    start: Tuple[int, int],
    goal: Tuple[int, int],
    grid_width: int,
    grid_height: int,
    blocked_cells: Set[Tuple[int, int]],
    allow_diagonal: bool = True,
    depth_limit: int = 50
) -> Dict:
    """
    Executes Depth-Limited Search up to `depth_limit`.
    Returns dictionary with:
      - success (bool)
      - path (List[Tuple[int, int]])
      - nodes_expanded (int)
      - execution_time_ms (float)
      - message (str)
      - cutoff (bool)
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
            "cutoff": False,
            "algorithm": "dls"
        }
        
    if start == goal:
        t_elapsed = (time.perf_counter() - t0) * 1000.0
        return {
            "success": True,
            "path": [start],
            "nodes_expanded": 1,
            "execution_time_ms": round(t_elapsed, 4),
            "message": "Start is goal",
            "cutoff": False,
            "algorithm": "dls"
        }
        
    # Stack stores: (current_node, current_depth)
    stack: List[Tuple[Tuple[int, int], int]] = [(start, 0)]
    # Keep track of shortest depth at which each node was visited to avoid redundant deeper cycles
    visited_depth: Dict[Tuple[int, int], int] = {start: 0}
    came_from: Dict[Tuple[int, int], Tuple[int, int]] = {}
    nodes_expanded = 0
    cutoff_occurred = False
    
    while stack:
        current, depth = stack.pop()
        nodes_expanded += 1
        
        if current == goal:
            path = reconstruct_path(came_from, current)
            t_elapsed = (time.perf_counter() - t0) * 1000.0
            return {
                "success": True,
                "path": path,
                "nodes_expanded": nodes_expanded,
                "execution_time_ms": round(t_elapsed, 4),
                "message": f"Path found within depth {depth} ({len(path)} steps)",
                "cutoff": False,
                "algorithm": "dls"
            }
            
        if depth >= depth_limit:
            cutoff_occurred = True
            continue
            
        for neighbor, _ in get_neighbors(current, grid_width, grid_height, blocked_cells, allow_diagonal):
            next_depth = depth + 1
            if neighbor not in visited_depth or next_depth < visited_depth[neighbor]:
                visited_depth[neighbor] = next_depth
                came_from[neighbor] = current
                stack.append((neighbor, next_depth))
                
    t_elapsed = (time.perf_counter() - t0) * 1000.0
    msg = f"Depth limit {depth_limit} exceeded (Cutoff)" if cutoff_occurred else "Goal is unreachable within bounds"
    return {
        "success": False,
        "path": [],
        "nodes_expanded": nodes_expanded,
        "execution_time_ms": round(t_elapsed, 4),
        "message": msg,
        "cutoff": cutoff_occurred,
        "algorithm": "dls"
    }
