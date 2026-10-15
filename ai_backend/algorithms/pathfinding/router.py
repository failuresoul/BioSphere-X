from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from typing import List, Tuple, Optional, Any, Set
import time

from .common import get_algorithm_profile, ALGORITHM_PROFILES
from .bfs import bfs_search
from .dfs import dfs_search
from .dls import dls_search
from .iddfs import iddfs_search
from .bidirectional import bidirectional_search
from .greedy import greedy_search
from .astar import astar_search

router = APIRouter(prefix="/api/ai/pathfinding", tags=["Pathfinding"])


class PathRequest(BaseModel):
    start: List[int] = Field(..., description="Start grid coordinates [x, y]")
    goal: List[int] = Field(..., description="Goal grid coordinates [x, y]")
    algorithm: str = Field(default="astar", description="Algorithm: bfs, dfs, dls, iddfs, bidirectional, greedy, astar")
    grid: Optional[List[List[int]]] = Field(default=None, description="2D grid where 0 is walkable, non-zero is blocked")
    grid_width: Optional[int] = Field(default=80, ge=1)
    grid_height: Optional[int] = Field(default=80, ge=1)
    blocked_cells: Optional[List[List[int]]] = Field(default=None, description="Explicit list of blocked [x, y] coordinates")
    allow_diagonal: bool = Field(default=True)
    depth_limit: Optional[int] = Field(default=100, ge=1, description="Depth limit for DLS and max depth for IDDFS")


class PathResponse(BaseModel):
    success: bool
    found: bool
    path: List[List[int]]
    length: int
    nodes_expanded: int
    execution_time_ms: float
    algorithm: str
    message: str = ""
    suitability: Optional[dict] = None


@router.get("/profiles")
def get_profiles():
    """Returns suitability metadata, optimality, and caveats for all pathfinding algorithms."""
    return ALGORITHM_PROFILES



@router.post("/find-path", response_model=PathResponse)
@router.post("/search", response_model=PathResponse)
def execute_pathfinding(req: PathRequest):
    """
    Executes grid pathfinding using the specified algorithm.
    Validates start/goal coordinates and obstacles, handles unreachable goals safely,
    and returns comprehensive execution metrics.
    """
    start_tuple = (int(req.start[0]), int(req.start[1]))
    goal_tuple = (int(req.goal[0]), int(req.goal[1]))
    
    # Resolve grid dimensions and blocked cells
    blocked_set: Set[Tuple[int, int]] = set()
    width = req.grid_width or 80
    height = req.grid_height or 80
    
    if req.grid is not None and len(req.grid) > 0:
        height = len(req.grid)
        width = len(req.grid[0])
        for y in range(height):
            for x in range(width):
                if req.grid[y][x] != 0:
                    blocked_set.add((x, y))
                    
    if req.blocked_cells is not None:
        for b in req.blocked_cells:
            if len(b) >= 2:
                blocked_set.add((int(b[0]), int(b[1])))
                
    algo_key = req.algorithm.strip().lower()
    
    if algo_key in ("bfs", "breadth_first"):
        raw_res = bfs_search(start_tuple, goal_tuple, width, height, blocked_set, req.allow_diagonal)
    elif algo_key in ("dfs", "depth_first"):
        raw_res = dfs_search(start_tuple, goal_tuple, width, height, blocked_set, req.allow_diagonal)
    elif algo_key in ("dls", "depth_limited"):
        limit = req.depth_limit or 100
        raw_res = dls_search(start_tuple, goal_tuple, width, height, blocked_set, req.allow_diagonal, depth_limit=limit)
    elif algo_key in ("iddfs", "iterative_deepening"):
        limit = req.depth_limit or 100
        raw_res = iddfs_search(start_tuple, goal_tuple, width, height, blocked_set, req.allow_diagonal, max_depth=limit)
    elif algo_key in ("bidirectional", "bibfs", "bi_directional"):
        raw_res = bidirectional_search(start_tuple, goal_tuple, width, height, blocked_set, req.allow_diagonal)
    elif algo_key in ("greedy", "best_first", "greedy_best_first"):
        raw_res = greedy_search(start_tuple, goal_tuple, width, height, blocked_set, req.allow_diagonal)
    elif algo_key in ("astar", "a*", "a_star"):
        raw_res = astar_search(start_tuple, goal_tuple, width, height, blocked_set, req.allow_diagonal)
    else:
        # Default fallback to A* with an advisory message
        raw_res = astar_search(start_tuple, goal_tuple, width, height, blocked_set, req.allow_diagonal)
        raw_res["message"] = f"Unknown algorithm '{req.algorithm}', defaulted to A*. {raw_res.get('message', '')}"
        raw_res["algorithm"] = "astar"
        
    formatted_path = [[pt[0], pt[1]] for pt in raw_res.get("path", [])]
    is_success = bool(raw_res.get("success", False))
    
    return PathResponse(
        success=is_success,
        found=is_success,
        path=formatted_path,
        length=len(formatted_path),
        nodes_expanded=int(raw_res.get("nodes_expanded", 0)),
        execution_time_ms=float(raw_res.get("execution_time_ms", 0.0)),
        algorithm=str(raw_res.get("algorithm", algo_key)),
        message=str(raw_res.get("message", "")),
        suitability=get_algorithm_profile(algo_key)
    )

