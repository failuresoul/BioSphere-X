"""Tests for CSP pickup placement."""
from fastapi.testclient import TestClient

from algorithms.csp import manhattan, place_pickups
from main import app

ROW = [[x, 9] for x in range(25)]          # one floor row, 25 tiles wide


def test_all_constraints_hold():
    walls = [[12, 9]]
    enemy = [20, 9]
    result = place_pickups(ROW, walls, enemy, ["health", "energy", "health"], 5, 4, seed=3)
    assert result["success"]
    tiles = [p["tile"] for p in result["placements"]]
    assert len(tiles) == 3
    for tile in tiles:
        assert tile not in walls
        assert manhattan(tile, enemy) >= 5
    for i in range(3):
        for j in range(i + 1, 3):
            assert manhattan(tiles[i], tiles[j]) >= 4


def test_impossible_problem_fails():
    tiny = [[0, 0], [1, 0], [2, 0]]
    assert not place_pickups(tiny, [], [9, 9], ["health", "energy"], 1, 4)["success"]


def test_csp_endpoint():
    response = TestClient(app).post("/api/ai/csp", json={"candidates": ROW, "walls": [], "enemy": [0, 9], "seed": 1})
    assert response.status_code == 200
    data = response.json()
    assert data["success"] and len(data["placements"]) == 3
