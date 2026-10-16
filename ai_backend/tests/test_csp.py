"""
Test Suite for Base Structure Placement CSP Solver.
Verifies economic, geometric, territorial, and collision constraints:
  1. Structure catalog querying.
  2. Fully valid placement.
  3. Resource constraint violation.
  4. Grid bounds constraint violation.
  5. Build zone boundary constraint violation.
  6. Blocked terrain obstacle constraint violation.
  7. Occupied structure cell overlap constraint violation.
  8. Minimum spacing proximity constraint violation.
  9. Valid candidate placement search / suggestion.
 10. HTTP FastAPI endpoints via TestClient.
"""
import pytest
from fastapi.testclient import TestClient
from main import app
from algorithms.csp.solver import BasePlacementSolver, PlacementRequest, ExistingStructure, SuggestPlacementsRequest

client = TestClient(app)
solver = BasePlacementSolver()


def test_structure_catalog():
    response = client.get("/api/ai/csp/structures")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "success"
    assert data["count"] >= 6
    assert "oxygen_generator" in data["structures"]
    assert "defense_turret" in data["structures"]
    assert "solar_array" in data["structures"]


def test_valid_placement():
    req = PlacementRequest(
        structure_id="oxygen_generator",
        position=[10, 10],
        structure_size=[2, 2],
        structure_cost={"titanium": 4, "crystals": 2},
        min_spacing=1,
        available_resources={"titanium": 10, "crystals": 5},
        grid_size=[80, 80],
        build_zone=[5, 5, 25, 25],
        blocked_cells=[[0, 0], [1, 1]],
        existing_structures=[
            ExistingStructure(id="sentry_1", name="Automated Sentry", position=[5, 5], size=[1, 1], min_spacing=1)
        ]
    )
    res = solver.validate(req)
    assert res.valid is True
    assert res.reason == ""
    assert len(res.violated_constraints) == 0
    assert len(res.occupied_footprint) == 4 # 2x2 = 4 cells
    assert res.remaining_resources["titanium"] == 6 # 10 - 4
    assert res.remaining_resources["crystals"] == 3 # 5 - 2


def test_insufficient_resources_constraint():
    req = PlacementRequest(
        structure_id="defense_turret",
        position=[12, 12],
        structure_cost={"titanium": 5, "crystals": 3},
        available_resources={"titanium": 2, "crystals": 3}, # Only 2 titanium, needs 5
        grid_size=[80, 80]
    )
    res = solver.validate(req)
    assert res.valid is False
    assert "RESOURCES" in res.violated_constraints
    assert "titanium" in res.reason.lower()
    # Available resources should remain unmodified
    assert res.remaining_resources["titanium"] == 2


def test_grid_bounds_constraint():
    # Outside negative
    req_neg = PlacementRequest(
        structure_id="radar_beacon",
        position=[-1, 5],
        grid_size=[80, 80],
        available_resources={"titanium": 10, "crystals": 10}
    )
    res_neg = solver.validate(req_neg)
    assert res_neg.valid is False
    assert "BOUNDS" in res_neg.violated_constraints

    # Outside max
    req_max = PlacementRequest(
        structure_id="oxygen_generator", # size 2x2
        position=[79, 79], # Footprint extends to 80, 80 (out of 80x80 grid)
        grid_size=[80, 80],
        available_resources={"titanium": 10, "crystals": 10}
    )
    res_max = solver.validate(req_max)
    assert res_max.valid is False
    assert "BOUNDS" in res_max.violated_constraints


def test_build_zone_constraint():
    req = PlacementRequest(
        structure_id="solar_array", # size 2x1
        position=[30, 30],
        build_zone=[10, 10, 20, 20], # Build zone is [10, 10] to [20, 20]
        grid_size=[80, 80],
        available_resources={"titanium": 10, "crystals": 10}
    )
    res = solver.validate(req)
    assert res.valid is False
    assert "BUILD_ZONE" in res.violated_constraints
    assert "build zone" in res.reason.lower()


def test_blocked_terrain_constraint():
    req = PlacementRequest(
        structure_id="oxygen_generator", # 2x2 footprint: [10,10], [11,10], [10,11], [11,11]
        position=[10, 10],
        blocked_cells=[[11, 11]], # Terrain rock obstacle at [11, 11]
        grid_size=[80, 80],
        available_resources={"titanium": 10, "crystals": 10}
    )
    res = solver.validate(req)
    assert res.valid is False
    assert "BLOCKED" in res.violated_constraints
    assert "(11, 11)" in res.reason


def test_occupied_cell_constraint():
    req = PlacementRequest(
        structure_id="defense_turret", # 1x1 at [15, 15]
        position=[15, 15],
        existing_structures=[
            ExistingStructure(id="depot_1", name="Resource Depot", position=[14, 14], size=[2, 2])
            # Depot occupies [14,14], [15,14], [14,15], [15,15] -> Overlaps!
        ],
        grid_size=[80, 80],
        available_resources={"titanium": 10, "crystals": 10}
    )
    res = solver.validate(req)
    assert res.valid is False
    assert "OCCUPIED" in res.violated_constraints
    assert "Resource Depot" in res.reason


def test_min_spacing_constraint():
    # Existing turret at [10, 10] with min_spacing 1.
    # A candidate structure placed directly adjacent at [11, 10] has Chebyshev distance 1 <= min_spacing 1 -> VIOLATION!
    req_too_close = PlacementRequest(
        structure_id="defense_turret",
        position=[11, 10], # Adjacent to [10, 10]
        structure_size=[1, 1],
        min_spacing=1,
        existing_structures=[
            ExistingStructure(id="turret_1", name="Perimeter Sentry", position=[10, 10], size=[1, 1], min_spacing=1)
        ],
        grid_size=[80, 80],
        available_resources={"titanium": 10, "crystals": 10}
    )
    res_too_close = solver.validate(req_too_close)
    assert res_too_close.valid is False
    assert "MIN_SPACING" in res_too_close.violated_constraints
    assert "minimum spacing" in res_too_close.reason.lower() or "clearance" in res_too_close.reason.lower()

    # When placed with distance 2 (e.g. at [12, 10]): distance is 2 > min_spacing 1 -> VALID!
    req_adequate_spacing = PlacementRequest(
        structure_id="defense_turret",
        position=[12, 10],
        structure_size=[1, 1],
        min_spacing=1,
        existing_structures=[
            ExistingStructure(id="turret_1", name="Perimeter Sentry", position=[10, 10], size=[1, 1], min_spacing=1)
        ],
        grid_size=[80, 80],
        available_resources={"titanium": 10, "crystals": 10}
    )
    res_adequate = solver.validate(req_adequate_spacing)
    assert res_adequate.valid is True
    assert len(res_adequate.violated_constraints) == 0


def test_suggest_placements():
    req = SuggestPlacementsRequest(
        structure_id="solar_array", # 2x1
        search_zone=[5, 5, 10, 10],
        max_suggestions=3,
        available_resources={"titanium": 10, "crystals": 10},
        grid_size=[80, 80],
        blocked_cells=[[5, 5], [6, 5], [7, 5]]
    )
    res = solver.suggest_placements(req)
    assert len(res.suggestions) > 0
    assert len(res.suggestions) <= 3
    # First suggestion cannot be [5, 5] because it's blocked
    assert [5, 5] not in res.suggestions


def test_api_validate_placement_endpoint():
    payload = {
        "structure_id": "oxygen_generator",
        "position": [12, 14],
        "available_resources": {"titanium": 10, "crystals": 10},
        "grid_size": [80, 80],
        "build_zone": [0, 0, 40, 40]
    }
    response = client.post("/api/ai/csp/validate-placement", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["valid"] is True
    assert data["structure_id"] == "oxygen_generator"
    assert data["structure_size"] == [2, 2]
    assert len(data["occupied_footprint"]) == 4
