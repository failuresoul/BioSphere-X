"""Tests for the 7 path-finding algorithms (ai_backend/algorithms/pathfinding/)."""
import pytest
from fastapi.testclient import TestClient

from algorithms.pathfinding import ALGORITHMS, find_path
from algorithms.pathfinding.dls import search as dls_search
from main import app

# 7 x 5 grid with a wall in column 3 that has one gap at the top (y = 0).
#   S . . # . . G
GRID = [
    [0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 1, 0, 0, 0],
    [0, 0, 0, 1, 0, 0, 0],
    [0, 0, 0, 1, 0, 0, 0],
    [0, 0, 0, 1, 0, 0, 0],
]
START, GOAL = [0, 4], [6, 4]
SHORTEST = 15          # 14 moves (up 4, right 6, down 4) -> 15 tiles


def valid_path(path, grid, start, goal):
    """Path starts at start, ends at goal, never enters a wall, moves 1 tile at a time."""
    if not path or path[0] != start or path[-1] != goal:
        return False
    for (x, y) in path:
        if grid[y][x] == 1:
            return False
    return all(abs(a[0] - b[0]) + abs(a[1] - b[1]) == 1 for a, b in zip(path, path[1:]))


@pytest.mark.parametrize("name", list(ALGORITHMS))
def test_every_algorithm_finds_a_valid_path(name):
    result = ALGORITHMS[name](GRID, START, GOAL)
    assert result["algorithm"] == name
    assert result["found"] is True
    assert valid_path(result["path"], GRID, START, GOAL)
    assert result["nodes_expanded"] > 0 and result["time_ms"] >= 0


def test_there_are_seven_algorithms():
    assert set(ALGORITHMS) == {"bfs", "dfs", "dls", "iddfs", "bidirectional", "greedy", "astar"}


@pytest.mark.parametrize("name", ["astar", "bfs", "iddfs", "bidirectional"])
def test_optimal_algorithms_give_the_shortest_path(name):
    assert len(ALGORITHMS[name](GRID, START, GOAL)["path"]) == SHORTEST


@pytest.mark.parametrize("name", list(ALGORITHMS))
def test_no_path_when_the_wall_is_closed(name):
    closed = [row[:] for row in GRID]
    closed[0][3] = 1
    result = ALGORITHMS[name](closed, START, GOAL)
    assert result["found"] is False and result["path"] == []


def test_dls_respects_its_depth_limit():
    assert dls_search(GRID, START, GOAL, limit=5)["found"] is False     # goal is 14 moves away
    assert dls_search(GRID, START, GOAL)["found"] is True               # default limit 20


def test_astar_expands_fewer_nodes_than_bfs():
    open_grid = [[0] * 12 for _ in range(12)]
    assert ALGORITHMS["astar"](open_grid, [0, 0], [11, 11])["nodes_expanded"] < \
        ALGORITHMS["bfs"](open_grid, [0, 0], [11, 11])["nodes_expanded"]


def test_start_on_a_wall_is_not_found():
    assert find_path("astar", GRID, [3, 2], GOAL)["found"] is False


def test_find_endpoint():
    client = TestClient(app)
    response = client.post("/pathfinding/find", json={"algorithm": "bidirectional", "grid": GRID, "start": START, "goal": GOAL})
    assert response.status_code == 200
    data = response.json()
    assert data["found"] and len(data["path"]) == SHORTEST
    assert client.post("/pathfinding/find", json={"algorithm": "nope", "grid": GRID, "start": START, "goal": GOAL}).status_code == 400
