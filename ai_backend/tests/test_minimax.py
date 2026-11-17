"""Tests for the combat state and Minimax (with and without alpha-beta)."""
from fastapi.testclient import TestClient

from algorithms.adversarial import ACTIONS, CombatState, evaluate, minimax_decision
from main import app


def test_actions_and_special_needs_energy():
    assert ACTIONS == ["attack", "block", "dodge", "move_closer", "move_away", "special"]
    assert "special" not in CombatState(my_energy=20).legal_actions()
    assert "special" not in CombatState(my_energy=80, my_cooldown=2).legal_actions()
    assert "special" in CombatState(my_energy=80).legal_actions()


def test_attack_and_block_change_health():
    hit = CombatState(distance=100).apply("attack")
    assert hit.enemy_hp == 90 and not hit.my_turn
    blocked = CombatState(distance=100, enemy_guard="block").apply("attack")
    assert blocked.enemy_hp == 96
    # The enemy acts through the same rules (the state is flipped internally).
    counter = hit.apply("attack")
    assert counter.my_hp == 90 and counter.my_turn


def test_evaluation_is_health_difference_plus_bonuses():
    assert evaluate(CombatState(my_hp=80, enemy_hp=50, distance=300, my_energy=0, enemy_energy=0)) == 30
    assert evaluate(CombatState(enemy_hp=0)) == 1000


def test_minimax_attacks_when_in_range():
    result = minimax_decision(CombatState(distance=100, my_energy=0), depth=3)
    assert result["action"] == "attack"
    assert result["nodes_expanded"] > 1 and result["time_ms"] >= 0


def test_minimax_finishes_a_weak_enemy():
    result = minimax_decision(CombatState(distance=100, enemy_hp=8), depth=3)
    assert result["action"] in ("attack", "special")
    assert result["score"] == 1000


def test_alpha_beta_same_choice_fewer_nodes():
    state = CombatState(distance=250, my_hp=70, enemy_hp=60, my_energy=60)
    plain = minimax_decision(state, depth=3)
    pruned = minimax_decision(state, depth=3, use_alpha_beta=True)
    assert plain["score"] == pruned["score"]
    assert pruned["nodes_expanded"] < plain["nodes_expanded"]


def test_decision_endpoint_minimax():
    response = TestClient(app).post("/api/ai/decision", json={"state": {"distance": 90}, "algorithm": "minimax"})
    assert response.status_code == 200
    data = response.json()
    assert data["algorithm"] == "minimax" and data["action"] in ACTIONS
