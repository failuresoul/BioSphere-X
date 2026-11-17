"""Tests for Monte Carlo Tree Search."""
from fastapi.testclient import TestClient

from algorithms.adversarial import ACTIONS, CombatState, mcts_decision
from main import app


def test_mcts_returns_a_legal_action_with_stats():
    result = mcts_decision(CombatState(), simulations=200, seed=1)
    assert result["action"] in ACTIONS
    assert result["simulations"] == 200
    assert result["nodes_expanded"] > len(ACTIONS)
    assert 0.0 <= result["score"] <= 1.0


def test_mcts_attacks_a_nearly_dead_enemy():
    state = CombatState(distance=100, enemy_hp=5, my_energy=0)
    result = mcts_decision(state, simulations=300, seed=2)
    assert result["action"] == "attack"


def test_mcts_never_picks_special_without_energy():
    for seed in range(5):
        assert mcts_decision(CombatState(my_energy=0), simulations=50, seed=seed)["action"] != "special"


def test_decision_endpoint_mcts():
    response = TestClient(app).post("/api/ai/decision", json={"state": {}, "algorithm": "mcts", "simulations": 100})
    assert response.status_code == 200
    data = response.json()
    assert data["algorithm"] == "mcts" and data["simulations"] == 100
