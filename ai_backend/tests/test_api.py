import pytest
from fastapi.testclient import TestClient
from main import app

client = TestClient(app)


def test_health_endpoint():
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert data["service"] == "BioSphere-X AI Backend"


def test_api_test_endpoint():
    response = client.get("/api/test")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "success"
    assert "active and connected" in data["message"]


def test_echo_endpoint():
    payload = {"message": "hello_from_godot", "payload": {"astronaut": "explorer", "hp": 100}}
    response = client.post("/api/test-echo", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "success"
    assert "hello_from_godot" in data["message"]
    assert data["payload"]["astronaut"] == "explorer"


def test_pathfinding_endpoint():
    req = {
        "start": [0, 0],
        "goal": [4, 4],
        "grid_width": 10,
        "grid_height": 10,
        "blocked_cells": [[1, 0], [1, 1], [1, 2]],
        "allow_diagonal": True
    }
    response = client.post("/api/ai/pathfinding/find-path", json=req)
    assert response.status_code == 200
    data = response.json()
    assert data["found"] is True
    assert len(data["path"]) > 0
    assert data["path"][0] == [0, 0]
    assert data["path"][-1] == [4, 4]
