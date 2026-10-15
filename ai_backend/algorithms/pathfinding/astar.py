"""
A* Pathfinding Algorithm for BioSphere-X 2D Grid Maps.
"""
import heapq
from typing import List, Tuple, Set, Optional


def heuristic(a: Tuple[int, int], b: Tuple[int, int], diagonal: bool = True) -> float:
    dx = abs(a[0] - b[0])
    dy = abs(a[1] - b[1])
    if diagonal:
        # Octile distance
        return (dx + dy) + (1.41421356 - 2.0) * min(dx, dy)
    return float(dx + dy)


def astar_grid_search(
    start: Tuple[int, int],
    goal: Tuple[int, int],
    grid_width: int,
    grid_height: int,
    blocked_cells: Set[Tuple[int, int]],
    allow_diagonal: bool = True
) -> Optional[List[Tuple[int, int]]]:
    """
    Computes an optimal path from start to goal on a 2D discrete grid.
    Returns list of (x, y) coordinates from start to goal, or None if unreachable.
    """
    if start == goal:
        return [start]
    
    if start in blocked_cells or goal in blocked_cells:
        return None
    
    if not (0 <= start[0] < grid_width and 0 <= start[1] < grid_height):
        return None
    if not (0 <= goal[0] < grid_width and 0 <= goal[1] < grid_height):
        return None

    # Priority queue: (f_score, counter, current_node)
    counter = 0
    open_heap = []
    heapq.heappush(open_heap, (heuristic(start, goal, allow_diagonal), counter, start))
    
    came_from = {}
    g_score = {start: 0.0}
    in_open_set = {start}

    cardinal_moves = [(1, 0, 1.0), (-1, 0, 1.0), (0, 1, 1.0), (0, -1, 1.0)]
    diagonal_moves = [(1, 1, 1.414), (-1, 1, 1.414), (1, -1, 1.414), (-1, -1, 1.414)]
    moves = cardinal_moves + (diagonal_moves if allow_diagonal else [])

    while open_heap:
        _, _, current = heapq.heappop(open_heap)
        in_open_set.discard(current)

        if current == goal:
            # Reconstruct path
            path = [current]
            while current in came_from:
                current = came_from[current]
                path.append(current)
            path.reverse()
            return path

        for dx, dy, cost in moves:
            neighbor = (current[0] + dx, current[1] + dy)
            nx, ny = neighbor

            if not (0 <= nx < grid_width and 0 <= ny < grid_height):
                continue
            if neighbor in blocked_cells:
                continue

            tentative_g = g_score[current] + cost
            if tentative_g < g_score.get(neighbor, float("inf")):
                came_from[neighbor] = current
                g_score[neighbor] = tentative_g
                f = tentative_g + heuristic(neighbor, goal, allow_diagonal)
                
                if neighbor not in in_open_set:
                    counter += 1
                    heapq.heappush(open_heap, (f, counter, neighbor))
                    in_open_set.add(neighbor)

    return None
