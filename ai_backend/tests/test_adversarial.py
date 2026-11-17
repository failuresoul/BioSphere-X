"""Tests for the combat state, Minimax (with / without alpha-beta) and MCTS."""
import pytest
from fastapi.testclient import TestClient

from algorithms.adversarial import ACTIONS, CombatState, evaluate, mcts_decision, minimax_decision
from main import app

# Some different fight situations.
STATES = [
    CombatState(),
    CombatState(distance=100, boss_hp=60, player_hp=80),
    CombatState(distance=600, boss_energy=80, player_energy=10),
    CombatState(distance=250, boss_hp=30, player_hp=30, boss_cooldown=2),
]


# ---- combat state -------------------------------------------------------------
def test_damage_rules():
    hit = CombatState(distance=100).apply_action("attack")          # punch
    assert hit.player_hp == 90 and not hit.boss_turn
    shot = CombatState(distance=300).apply_action("attack")         # shot from further away
    assert shot.player_hp == 94
    blocked = CombatState(distance=100, player_guard="block").apply_action("attack")
    assert blocked.player_hp == 96
    # The player uses the same rules on its turn.
    assert hit.apply_action("attack").boss_hp == 90


def test_special_needs_energy_and_no_cooldown():
    assert "special" not in CombatState(boss_energy=20).legal_actions()
    assert "special" not in CombatState(boss_energy=80, boss_cooldown=1).legal_actions()
    assert "special" in CombatState(boss_energy=80).legal_actions()


def test_evaluation_likes_boss_health_and_good_distance():
    assert evaluate(CombatState(boss_hp=90, player_hp=40, distance=300)) > evaluate(CombatState(boss_hp=40, player_hp=90, distance=300))
    assert evaluate(CombatState(distance=100)) > evaluate(CombatState(distance=700))
    assert evaluate(CombatState(player_hp=0)) == 1000


# ---- both algorithms return legal actions --------------------------------------
@pytest.mark.parametrize("state", STATES)
def test_both_algorithms_return_legal_actions(state):
    for use_ab in (True, False):
        result = minimax_decision(state, use_alpha_beta=use_ab)
        assert result["action"] in state.legal_actions()
        assert result["nodes_evaluated"] > 0 and result["time_ms"] >= 0
    result = mcts_decision(state, seed=1)
    assert result["action"] in state.legal_actions()
    assert result["simulations"] == 200 and 0.0 <= result["win_rate"] <= 1.0


# ---- minimax --------------------------------------------------------------------
def test_minimax_attacks_a_near_player_with_very_low_hp():
    state = CombatState(distance=80, player_hp=5, boss_energy=0)   # no energy: special not possible
    for use_ab in (True, False):
        assert minimax_decision(state, use_alpha_beta=use_ab)["action"] == "attack"


@pytest.mark.parametrize("state", STATES)
def test_alpha_beta_same_action_fewer_nodes(state):
    plain = minimax_decision(state, use_alpha_beta=False)
    pruned = minimax_decision(state, use_alpha_beta=True)
    assert pruned["action"] == plain["action"]
    assert pruned["score"] == plain["score"]
    assert pruned["nodes_evaluated"] < plain["nodes_evaluated"]
    assert pruned["nodes_pruned"] > 0 and plain["nodes_pruned"] == 0


# ---- MCTS ---------------------------------------------------------------------------
def test_mcts_finishes_a_nearly_dead_player():
    result = mcts_decision(CombatState(distance=80, player_hp=5, boss_energy=0), seed=2)
    assert result["action"] == "attack" and result["win_rate"] > 0.9


# ---- endpoint -------------------------------------------------------------------------
@pytest.mark.parametrize("algorithm, use_ab", [("minimax", True), ("minimax", False), ("mcts", False)])
def test_decide_endpoint(algorithm, use_ab):
    response = TestClient(app).post("/adversarial/decide", json={
        "algorithm": algorithm, "use_alpha_beta": use_ab, "state": {"distance": 90, "player_hp": 50}})
    assert response.status_code == 200
    data = response.json()
    assert data["action"] in ACTIONS
    assert ("nodes_pruned" in data) if algorithm == "minimax" else ("win_rate" in data)
