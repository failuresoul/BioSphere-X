"""
Comprehensive unit tests for BioSphere-X Python Pathfinding algorithms:
BFS, DFS, DLS, IDDFS, Bidirectional, Greedy Best-First, and A*.
Tests multiple maps, edge cases, obstacles, and unreachable targets.
"""
import pytest
from fastapi.testclient import TestClient
from main import app

from algorithms.pathfinding.bfs import bfs_search
from algorithms.pathfinding.dfs import dfs_search
from algorithms.pathfinding.dls import dls_search
from algorithms.pathfinding.iddfs import iddfs_search
from algorithms.pathfinding.bidirectional import bidirectional_search
from algorithms.pathfinding.greedy import greedy_search
from algorithms.pathfinding.astar import astar_search

client = TestClient(app)

ALGORITHMS = ["bfs", "dfs", "dls", "iddfs", "bidirectional", "greedy", "astar"]


def is_path_contiguous_and_valid(path, blocked_set, allow_diagonal=True):
    """Helper to verify that path coordinates form a valid, unbroken sequence."""
    if not path:
        return False
    for pt in path:
        coord = (pt[0], pt[1])
        if coord in blocked_set:
            return False
    for i in range(len(path) - 1):
        x1, y1 = path[i]
        x2, y2 = path[i + 1]
        dx = abs(x2 - x1)
        dy = abs(y2 - y1)
        if dx > 1 or dy > 1:
            return False
        if not allow_diagonal and (dx + dy) > 1:
            return False
    return True


# ---------------------------------------------------------------------------
# Direct Algorithm Unit Tests Across Multiple Maps
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("algo", ALGORITHMS)
def test_open_grid_map(algo):
    """Test all algorithms on an open 12x12 grid."""
    start = (1, 1)
    goal = (10, 10)
    width, height = 12, 12
    blocked = set()
    
    dispatch = {
        "bfs": lambda: bfs_search(start, goal, width, height, blocked),
        "dfs": lambda: dfs_search(start, goal, width, height, blocked),
        "dls": lambda: dls_search(start, goal, width, height, blocked, depth_limit=50),
        "iddfs": lambda: iddfs_search(start, goal, width, height, blocked, max_depth=30),
        "bidirectional": lambda: bidirectional_search(start, goal, width, height, blocked),
        "greedy": lambda: greedy_search(start, goal, width, height, blocked),
        "astar": lambda: astar_search(start, goal, width, height, blocked),
    }
    
    res = dispatch[algo]()
    assert res["success"] is True, f"{algo} failed on open grid"
    assert res["nodes_expanded"] > 0
    assert res["execution_time_ms"] >= 0.0
    path = res["path"]
    assert path[0] == start
    assert path[-1] == goal
    assert is_path_contiguous_and_valid(path, blocked)


@pytest.mark.parametrize("algo", ALGORITHMS)
def test_corridor_obstacle_map(algo):
    """Test all algorithms on a maze-like map with a wall obstacle that forces navigation around."""
    start = (0, 2)
    goal = (4, 2)
    width, height = 6, 6
    # Wall cutting across column 2 from y=0 to y=4, leaving gap at y=5
    blocked = {(2, 0), (2, 1), (2, 2), (2, 3), (2, 4)}
    
    dispatch = {
        "bfs": lambda: bfs_search(start, goal, width, height, blocked),
        "dfs": lambda: dfs_search(start, goal, width, height, blocked),
        "dls": lambda: dls_search(start, goal, width, height, blocked, depth_limit=40),
        "iddfs": lambda: iddfs_search(start, goal, width, height, blocked, max_depth=25),
        "bidirectional": lambda: bidirectional_search(start, goal, width, height, blocked),
        "greedy": lambda: greedy_search(start, goal, width, height, blocked),
        "astar": lambda: astar_search(start, goal, width, height, blocked),
    }
    
    res = dispatch[algo]()
    assert res["success"] is True, f"{algo} failed to navigate around corridor wall"
    path = res["path"]
    assert path[0] == start
    assert path[-1] == goal
    assert is_path_contiguous_and_valid(path, blocked)


@pytest.mark.parametrize("algo", ALGORITHMS)
def test_unreachable_goal_handling(algo):
    """Test that all algorithms safely report unreachable goals without crashing."""
    start = (0, 0)
    goal = (5, 5)
    width, height = 8, 8
    # Enclose goal completely with solid perimeter
    blocked = {
        (4, 4), (5, 4), (6, 4),
        (4, 5),         (6, 5),
        (4, 6), (5, 6), (6, 6)
    }
    
    dispatch = {
        "bfs": lambda: bfs_search(start, goal, width, height, blocked),
        "dfs": lambda: dfs_search(start, goal, width, height, blocked),
        "dls": lambda: dls_search(start, goal, width, height, blocked, depth_limit=20),
        "iddfs": lambda: iddfs_search(start, goal, width, height, blocked, max_depth=15),
        "bidirectional": lambda: bidirectional_search(start, goal, width, height, blocked),
        "greedy": lambda: greedy_search(start, goal, width, height, blocked),
        "astar": lambda: astar_search(start, goal, width, height, blocked),
    }
    
    res = dispatch[algo]()
    assert res["success"] is False, f"{algo} should report success=False for enclosed goal"
    assert res["path"] == []
    assert res["nodes_expanded"] > 0
    assert "unreachable" in res["message"].lower() or "limit" in res["message"].lower() or "cutoff" in res["message"].lower()


@pytest.mark.parametrize("algo", ALGORITHMS)
def test_start_is_goal(algo):
    """Test start == goal edge case across all algorithms."""
    start = (3, 3)
    goal = (3, 3)
    width, height = 10, 10
    blocked = set()
    
    dispatch = {
        "bfs": lambda: bfs_search(start, goal, width, height, blocked),
        "dfs": lambda: dfs_search(start, goal, width, height, blocked),
        "dls": lambda: dls_search(start, goal, width, height, blocked),
        "iddfs": lambda: iddfs_search(start, goal, width, height, blocked),
        "bidirectional": lambda: bidirectional_search(start, goal, width, height, blocked),
        "greedy": lambda: greedy_search(start, goal, width, height, blocked),
        "astar": lambda: astar_search(start, goal, width, height, blocked),
    }
    
    res = dispatch[algo]()
    assert res["success"] is True
    assert res["path"] == [start]


def test_coordinate_validation():
    """Test coordinate boundary and obstacle validation."""
    # Start out of bounds
    res = astar_search((-1, 0), (5, 5), 10, 10, set())
    assert res["success"] is False
    assert "out of bounds" in res["message"].lower()
    
    # Goal out of bounds
    res = bfs_search((0, 0), (10, 10), 10, 10, set())
    assert res["success"] is False
    assert "out of bounds" in res["message"].lower()
    
    # Start blocked
    res = greedy_search((1, 1), (5, 5), 10, 10, {(1, 1)})
    assert res["success"] is False
    assert "blocked" in res["message"].lower()
    
    # Goal blocked
    res = bidirectional_search((0, 0), (5, 5), 10, 10, {(5, 5)})
    assert res["success"] is False
    assert "blocked" in res["message"].lower()


# ---------------------------------------------------------------------------
# HTTP API Endpoint Tests via FastAPI TestClient
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("algo_name", ["bfs", "dfs", "dls", "iddfs", "bidirectional", "greedy", "astar"])
def test_api_endpoint_algorithms(algo_name):
    """Test API endpoint /api/ai/pathfinding/find-path with all algorithms."""
    req = {
        "algorithm": algo_name,
        "start": [1, 1],
        "goal": [6, 6],
        "grid_width": 10,
        "grid_height": 10,
        "blocked_cells": [[3, 1], [3, 2], [3, 3]],
        "allow_diagonal": True,
        "depth_limit": 30
    }
    response = client.post("/api/ai/pathfinding/find-path", json=req)
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert data["found"] is True
    assert len(data["path"]) > 0
    assert data["path"][0] == [1, 1]
    assert data["path"][-1] == [6, 6]
    assert data["nodes_expanded"] > 0
    assert data["execution_time_ms"] >= 0.0


def test_api_2d_matrix_grid_format():
    """Test API endpoint when passing a 2D matrix grid directly."""
    # 0 = walkable, 1 = blocked
    grid_matrix = [
        [0, 0, 1, 0],
        [0, 0, 1, 0],
        [0, 0, 0, 0],
        [0, 0, 1, 0]
    ]
    req = {
        "algorithm": "astar",
        "start": [0, 0],
        "goal": [3, 0],
        "grid": grid_matrix,
        "allow_diagonal": True
    }
    response = client.post("/api/ai/pathfinding/find-path", json=req)
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert data["path"][0] == [0, 0]
    assert data["path"][-1] == [3, 0]
    assert [2, 0] not in data["path"]


def test_api_algorithm_profiles_and_suitability():
    """Verify algorithm profiles endpoint and suitability payload in find-path."""
    # Test GET /profiles
    response = client.get("/api/ai/pathfinding/profiles")
    assert response.status_code == 200
    profiles = response.json()
    assert "astar" in profiles
    assert "dfs" in profiles
    assert profiles["astar"]["optimal"] is True
    assert profiles["astar"]["gameplay_suitable"] is True
    assert profiles["dfs"]["gameplay_suitable"] is False

    # Test that find-path includes suitability
    req = {
        "algorithm": "astar",
        "start": [0, 0],
        "goal": [2, 2],
        "grid_width": 5,
        "grid_height": 5,
        "blocked_cells": []
    }
    res = client.post("/api/ai/pathfinding/find-path", json=req)
    assert res.status_code == 200
    data = res.json()
    assert "suitability" in data
    assert data["suitability"]["gameplay_suitable"] is True

