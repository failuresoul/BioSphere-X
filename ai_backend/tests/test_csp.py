"""Tests for CSP item placement (algorithms/csp/solver.py): every constraint must hold."""
from fastapi.testclient import TestClient

from algorithms.csp import OXYGEN_ITEMS, VARIABLES, manhattan, place_items
from main import app

WIDTH = 30                                                   # a level 30 tiles wide
GROUND = [[x, 9] for x in range(WIDTH)]                      # floor row
PLATFORM = [[x, 6] for x in range(5, 12)]                    # one platform
CANDIDATES = GROUND + PLATFORM
WALLS = [[14, 9], [15, 9]]
ENEMIES = [[8, 9], [20, 9]]
BOSS = [28, 9]


def solve(seed):
    return place_items(CANDIDATES, WALLS, ENEMIES, BOSS, WIDTH, min_enemy_distance=4, min_spacing=5, seed=seed)


def test_all_constraints_hold():
    for seed in range(10):                                   # several different layouts
        result = solve(seed)
        assert result["success"] and result["backtracks"] >= 0
        pos = {var: tuple(result["positions"][var]) for var in VARIABLES}
        for tile in pos.values():
            assert list(tile) in CANDIDATES                  # on a walkable tile
            assert list(tile) not in WALLS                   # not in a wall
            for danger in ENEMIES + [BOSS]:                  # not near enemies or the boss spawn
                assert manhattan(tile, danger) >= 4
        tiles = list(pos.values())
        for i in range(len(tiles)):                          # minimum distance between items
            for j in range(i + 1, len(tiles)):
                assert manhattan(tiles[i], tiles[j]) >= 5
        thirds = {min(2, pos[v][0] * 3 // WIDTH) for v in OXYGEN_ITEMS}
        assert thirds == {0, 1, 2}                           # oxygen in every third


def test_impossible_level_fails():
    tiny = [[x, 9] for x in range(6)]                        # too small for 5 spaced-out items
    assert place_items(tiny, [], [], [100, 100], 6)["success"] is False


def test_csp_endpoint():
    response = TestClient(app).post("/csp/place", json={
        "candidates": CANDIDATES, "walls": WALLS, "enemies": ENEMIES, "boss_spawn": BOSS, "level_width": WIDTH, "seed": 1})
    assert response.status_code == 200
    data = response.json()
    assert data["success"] and set(data["positions"]) == set(VARIABLES) and "backtracks" in data
