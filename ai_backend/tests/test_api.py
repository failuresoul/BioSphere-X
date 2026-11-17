"""API health: the server is up and every AI endpoint answers."""
from fastapi.testclient import TestClient

from main import app

client = TestClient(app)


def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_every_endpoint_answers():
    grid = [[0, 0, 0], [0, 0, 0]]
    calls = [
        ("/pathfinding/find", {"algorithm": "astar", "grid": grid, "start": [0, 0], "goal": [2, 1]}),
        ("/adversarial/decide", {"algorithm": "minimax", "use_alpha_beta": True, "state": {}}),
        ("/fuzzy/aggression", {"player_health": 50, "recent_damage": 0, "distance": 300}),
        ("/logic/infer", {"facts": {"oxygen": 10}}),
        ("/csp/place", {"candidates": [[x, 9] for x in range(30)], "boss_spawn": [100, 100], "level_width": 30}),
    ]
    for path, body in calls:
        assert client.post(path, json=body).status_code == 200, path
