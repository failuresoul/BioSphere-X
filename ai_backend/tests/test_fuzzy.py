"""Tests for the fuzzy boss difficulty (algorithms/fuzzy/engine.py)."""
from fastapi.testclient import TestClient

from algorithms.fuzzy import fuzzy_aggression, triangle
from main import app


def test_triangle_membership():
    assert triangle(50, 20, 50, 80) == 1.0
    assert triangle(35, 20, 50, 80) == 0.5
    assert triangle(10, 20, 50, 80) == 0.0
    assert triangle(0, 0, 0, 40) == 1.0                  # left shoulder


def test_aggression_is_between_0_and_1():
    for health in (0, 30, 60, 100):
        for damage in (0, 25, 50):
            for distance in (0, 400, 1000):
                assert 0.0 <= fuzzy_aggression(health, damage, distance)["aggression"] <= 1.0


def test_weak_player_gets_low_aggression():
    assert fuzzy_aggression(10, 0, 500)["aggression"] < 0.35


def test_healthy_player_up_close_gets_high_aggression():
    assert fuzzy_aggression(100, 0, 50)["aggression"] > 0.65


def test_recent_damage_calms_the_boss():
    assert fuzzy_aggression(100, 50, 50)["aggression"] < fuzzy_aggression(100, 0, 50)["aggression"]


def test_fuzzy_endpoint():
    response = TestClient(app).post("/fuzzy/aggression", json={"player_health": 90, "recent_damage": 5, "distance": 200})
    assert response.status_code == 200
    assert 0.0 <= response.json()["aggression"] <= 1.0
