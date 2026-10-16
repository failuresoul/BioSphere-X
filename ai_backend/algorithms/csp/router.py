"""
FastAPI Router for BioSphere-X Base-Structure Placement Constraint Satisfaction Problem (CSP).
Exposes endpoints for validating base-building placement requests, inspecting the structure catalog,
and querying automated placement recommendations.
"""
from fastapi import APIRouter, HTTPException
from typing import Dict, Any

from .solver import (
    BasePlacementSolver,
    PlacementRequest,
    PlacementResponse,
    SuggestPlacementsRequest,
    SuggestPlacementsResponse,
    STRUCTURE_CATALOG
)

router = APIRouter(prefix="/api/ai/csp", tags=["Base Structure CSP Placement"])

# Global solver instance
placement_solver = BasePlacementSolver()


@router.get("/structures")
def get_structure_catalog() -> Dict[str, Any]:
    """
    Returns the catalog of constructible base structures with dimensions, resource costs,
    and minimum spacing constraints.
    """
    return {
        "status": "success",
        "structures": STRUCTURE_CATALOG,
        "count": len(STRUCTURE_CATALOG)
    }


@router.post("/validate-placement", response_model=PlacementResponse)
def validate_structure_placement(req: PlacementRequest) -> PlacementResponse:
    """
    Evaluates whether a candidate structure placement satisfies all constraints:
      - Resource sufficiency (economic)
      - Grid boundary containment
      - Authorized build zone boundaries
      - Terrain collision / blocked cell clearance
      - Non-overlap with existing structures
      - Minimum spacing buffer between structures
    Returns validity flag, precise reason if invalid, and diagnostic footprint.
    """
    try:
        response = placement_solver.validate(req)
        return response
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Placement validation failed: {str(e)}")


@router.post("/suggest-placements", response_model=SuggestPlacementsResponse)
def suggest_structure_placements(req: SuggestPlacementsRequest) -> SuggestPlacementsResponse:
    """
    Scans candidate positions within the authorized build zone or search zone and returns
    a list of valid coordinates that satisfy all placement constraints.
    """
    try:
        response = placement_solver.suggest_placements(req)
        return response
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Placement suggestion search failed: {str(e)}")
