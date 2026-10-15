"""
Common utilities and data structures for 2D Grid Pathfinding in BioSphere-X.
"""
from typing import List, Tuple, Set, Optional, Dict
import math


def heuristic_octile(a: Tuple[int, int], b: Tuple[int, int]) -> float:
    """Octile distance heuristic for 8-connected grid."""
    dx = abs(a[0] - b[0])
    dy = abs(a[1] - b[1])
    return (dx + dy) + (1.41421356 - 2.0) * min(dx, dy)


def heuristic_manhattan(a: Tuple[int, int], b: Tuple[int, int]) -> float:
    """Manhattan distance heuristic for 4-connected grid."""
    return float(abs(a[0] - b[0]) + abs(a[1] - b[1]))


def heuristic_euclidean(a: Tuple[int, int], b: Tuple[int, int]) -> float:
    """Euclidean distance heuristic."""
    return math.hypot(a[0] - b[0], a[1] - b[1])


def get_neighbors(
    node: Tuple[int, int],
    grid_width: int,
    grid_height: int,
    blocked_cells: Set[Tuple[int, int]],
    allow_diagonal: bool = True
) -> List[Tuple[Tuple[int, int], float]]:
    """
    Returns valid neighbor nodes and transition step costs.
    Cardinal movements cost 1.0; diagonal movements cost sqrt(2) ≈ 1.414.
    """
    cardinal_offsets = [
        ((1, 0), 1.0),
        ((-1, 0), 1.0),
        ((0, 1), 1.0),
        ((0, -1), 1.0)
    ]
    diagonal_offsets = [
        ((1, 1), 1.4142),
        ((-1, 1), 1.4142),
        ((1, -1), 1.4142),
        ((-1, -1), 1.4142)
    ]
    
    offsets = cardinal_offsets + (diagonal_offsets if allow_diagonal else [])
    neighbors = []
    
    x, y = node
    for (dx, dy), cost in offsets:
        nx, ny = x + dx, y + dy
        if 0 <= nx < grid_width and 0 <= ny < grid_height:
            neighbor = (nx, ny)
            if neighbor not in blocked_cells:
                # If diagonal move, ensure at least one adjacent cardinal cell is walkable (prevent cutting through solid walls)
                if dx != 0 and dy != 0:
                    c1 = (x + dx, y)
                    c2 = (x, y + dy)
                    if c1 in blocked_cells and c2 in blocked_cells:
                        continue
                neighbors.append((neighbor, cost))
                
    return neighbors


def reconstruct_path(came_from: Dict[Tuple[int, int], Tuple[int, int]], current: Tuple[int, int]) -> List[Tuple[int, int]]:
    """Reconstructs the path from start to current node using came_from map."""
    path = [current]
    while current in came_from:
        current = came_from[current]
        path.append(current)
    path.reverse()
    return path


def validate_coordinates(
    start: Tuple[int, int],
    goal: Tuple[int, int],
    grid_width: int,
    grid_height: int,
    blocked_cells: Set[Tuple[int, int]]
) -> Tuple[bool, str]:
    """
    Validates start and goal coordinates within grid boundaries and obstacles.
    Returns (is_valid, error_message).
    """
    if not (0 <= start[0] < grid_width and 0 <= start[1] < grid_height):
        return False, f"Start position {start} is out of bounds (Grid: {grid_width}x{grid_height})"
        
    if not (0 <= goal[0] < grid_width and 0 <= goal[1] < grid_height):
        return False, f"Goal position {goal} is out of bounds (Grid: {grid_width}x{grid_height})"
        
    if start in blocked_cells:
        return False, f"Start position {start} is blocked by an obstacle"
        
    if goal in blocked_cells:
        return False, f"Goal position {goal} is blocked by an obstacle"
        
    return True, ""
