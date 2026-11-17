"""Tests for the fuzzy aggression controller."""
from fastapi.testclient import TestClient

from algorithms.fuzzy import fuzzy_aggression, triangle
from main import app


def test_triangle_membership():
    assert triangle(50, 20, 50, 80) == 1.0
    assert triangle(35, 20, 50, 80) == 0.5
    assert triangle(10, 20, 50, 80) == 0.0
    assert triangle(0, 0, 0, 40) == 1.0          # left shoulder


def test_healthy_player_gets_high_aggression():
    assert fuzzy_aggression(100, 100)["label"] == "high"


def test_weak_player_up_close_gets_low_aggression():
    assert fuzzy_aggression(10, 50)["label"] == "low"


def test_half_health_gives_medium():
    assert fuzzy_aggression(50, 400)["label"] == "medium"


def test_far_distance_raises_aggression():
    assert fuzzy_aggression(50, 1000)["aggression"] > fuzzy_aggression(50, 400)["aggression"]


def test_fuzzy_endpoint():
    response = TestClient(app).post("/api/ai/fuzzy", json={"player_health": 90, "distance": 200})
    assert response.status_code == 200
    assert response.json()["label"] in ("low", "medium", "high")
