"""
Iterative Deepening Depth-First Search (IDDFS) Pathfinding Algorithm.
Combines depth-first search's space-efficiency and breadth-first search's completeness.
"""
from typing import List, Tuple, Set, Dict, Optional
import time
from .common import get_neighbors, reconstruct_path, validate_coordinates


def iddfs_search(
    start: Tuple[int, int],
    goal: Tuple[int, int],
    grid_width: int,
    grid_height: int,
    blocked_cells: Set[Tuple[int, int]],
    allow_diagonal: bool = True,
    max_depth: Optional[int] = None
) -> Dict:
    """
    Executes Iterative Deepening DFS.
    Successively searches with depth limit 0, 1, 2, ... up to max_depth.
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
            "algorithm": "iddfs"
        }
        
    if start == goal:
        t_elapsed = (time.perf_counter() - t0) * 1000.0
        return {
            "success": True,
            "path": [start],
            "nodes_expanded": 1,
            "execution_time_ms": round(t_elapsed, 4),
            "message": "Start is goal",
            "algorithm": "iddfs"
        }
        
    if max_depth is None:
        # Theoretical max steps in a 2D grid
        max_depth = grid_width * grid_height
        
    total_nodes_expanded = 0
    
    for limit in range(0, max_depth + 1):
        stack: List[Tuple[Tuple[int, int], int]] = [(start, 0)]
        visited_depth: Dict[Tuple[int, int], int] = {start: 0}
        came_from: Dict[Tuple[int, int], Tuple[int, int]] = {}
        cutoff_occurred = False
        
        while stack:
            current, depth = stack.pop()
            total_nodes_expanded += 1
            
            if current == goal:
                path = reconstruct_path(came_from, current)
                t_elapsed = (time.perf_counter() - t0) * 1000.0
                return {
                    "success": True,
                    "path": path,
                    "nodes_expanded": total_nodes_expanded,
                    "depth_found": limit,
                    "execution_time_ms": round(t_elapsed, 4),
                    "message": f"Path found at depth {limit} ({len(path)} steps)",
                    "algorithm": "iddfs"
                }
                
            if depth >= limit:
                cutoff_occurred = True
                continue
                
            for neighbor, _ in get_neighbors(current, grid_width, grid_height, blocked_cells, allow_diagonal):
                next_depth = depth + 1
                if neighbor not in visited_depth or next_depth < visited_depth[neighbor]:
                    visited_depth[neighbor] = next_depth
                    came_from[neighbor] = current
                    stack.append((neighbor, next_depth))
                    
        # If no cutoff occurred in this full depth scan, the entire connected component was exhausted
        if not cutoff_occurred:
            break
            
    t_elapsed = (time.perf_counter() - t0) * 1000.0
    return {
        "success": False,
        "path": [],
        "nodes_expanded": total_nodes_expanded,
        "execution_time_ms": round(t_elapsed, 4),
        "message": "Goal is unreachable (Explored up to max depth)",
        "algorithm": "iddfs"
    }
