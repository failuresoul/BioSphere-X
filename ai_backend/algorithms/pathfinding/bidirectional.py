"""
Bidirectional Search Pathfinding Algorithm.
Simultaneously explores forward from start and backward from goal until frontiers intersect.
"""
from typing import List, Tuple, Set, Dict, Optional
from collections import deque
import time
from .common import get_neighbors, reconstruct_path, validate_coordinates


def bidirectional_search(
    start: Tuple[int, int],
    goal: Tuple[int, int],
    grid_width: int,
    grid_height: int,
    blocked_cells: Set[Tuple[int, int]],
    allow_diagonal: bool = True
) -> Dict:
    """
    Executes Bidirectional BFS between start and goal.
    Returns path, success, nodes_expanded, and execution time.
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
            "algorithm": "bidirectional"
        }
        
    if start == goal:
        t_elapsed = (time.perf_counter() - t0) * 1000.0
        return {
            "success": True,
            "path": [start],
            "nodes_expanded": 1,
            "execution_time_ms": round(t_elapsed, 4),
            "message": "Start is goal",
            "algorithm": "bidirectional"
        }
        
    q_forward = deque([start])
    q_backward = deque([goal])
    
    forward_came_from: Dict[Tuple[int, int], Tuple[int, int]] = {}
    backward_came_from: Dict[Tuple[int, int], Tuple[int, int]] = {}
    
    forward_visited: Set[Tuple[int, int]] = {start}
    backward_visited: Set[Tuple[int, int]] = {goal}
    
    nodes_expanded = 0
    meeting_node: Optional[Tuple[int, int]] = None
    
    while q_forward and q_backward:
        # Step Forward
        if q_forward:
            curr_f = q_forward.popleft()
            nodes_expanded += 1
            
            if curr_f in backward_visited:
                meeting_node = curr_f
                break
                
            for neighbor, _ in get_neighbors(curr_f, grid_width, grid_height, blocked_cells, allow_diagonal):
                if neighbor not in forward_visited:
                    forward_visited.add(neighbor)
                    forward_came_from[neighbor] = curr_f
                    q_forward.append(neighbor)
                    
                    if neighbor in backward_visited:
                        meeting_node = neighbor
                        break
                        
        if meeting_node is not None:
            break
            
        # Step Backward
        if q_backward:
            curr_b = q_backward.popleft()
            nodes_expanded += 1
            
            if curr_b in forward_visited:
                meeting_node = curr_b
                break
                
            for neighbor, _ in get_neighbors(curr_b, grid_width, grid_height, blocked_cells, allow_diagonal):
                if neighbor not in backward_visited:
                    backward_visited.add(neighbor)
                    backward_came_from[neighbor] = curr_b
                    q_backward.append(neighbor)
                    
                    if neighbor in forward_visited:
                        meeting_node = neighbor
                        break
                        
        if meeting_node is not None:
            break
            
    if meeting_node is not None:
        # Reconstruct path from start to meeting_node
        path_from_start = reconstruct_path(forward_came_from, meeting_node)
        
        # Reconstruct path from meeting_node to goal
        path_to_goal = []
        curr = meeting_node
        while curr in backward_came_from:
            curr = backward_came_from[curr]
            path_to_goal.append(curr)
            
        full_path = path_from_start + path_to_goal
        t_elapsed = (time.perf_counter() - t0) * 1000.0
        return {
            "success": True,
            "path": full_path,
            "nodes_expanded": nodes_expanded,
            "meeting_node": list(meeting_node),
            "execution_time_ms": round(t_elapsed, 4),
            "message": f"Bidirectional path found meeting at {meeting_node} ({len(full_path)} steps)",
            "algorithm": "bidirectional"
        }
        
    t_elapsed = (time.perf_counter() - t0) * 1000.0
    return {
        "success": False,
        "path": [],
        "nodes_expanded": nodes_expanded,
        "execution_time_ms": round(t_elapsed, 4),
        "message": "Goal is unreachable (Frontiers did not intersect)",
        "algorithm": "bidirectional"
    }
