from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from typing import List, Tuple, Optional
from .astar import astar_grid_search

router = APIRouter(prefix="/api/ai/pathfinding", tags=["Pathfinding"])


class PathRequest(BaseModel):
    start: Tuple[int, int] = Field(..., description="Start grid coordinates [x, y]")
    goal: Tuple[int, int] = Field(..., description="Goal grid coordinates [x, y]")
    grid_width: int = Field(default=80, ge=1)
    grid_height: int = Field(default=80, ge=1)
    blocked_cells: List[Tuple[int, int]] = Field(default_factory=list)
    allow_diagonal: bool = Field(default=True)


class PathResponse(BaseModel):
    found: bool
    path: List[Tuple[int, int]]
    length: int


@router.post("/find-path", response_model=PathResponse)
def find_path(req: PathRequest):
    blocked_set = set(req.blocked_cells)
    path = astar_grid_search(
        start=req.start,
        goal=req.goal,
        grid_width=req.grid_width,
        grid_height=req.grid_height,
        blocked_cells=blocked_set,
        allow_diagonal=req.allow_diagonal
    )
    if path is None:
        return PathResponse(found=False, path=[], length=0)
    return PathResponse(found=True, path=path, length=len(path))
