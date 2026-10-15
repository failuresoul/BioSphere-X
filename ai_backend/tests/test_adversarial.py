"""
Unit and Integration Tests for BioSphere-X Boss Adversarial AI Modules.
Tests CombatState, Minimax, Alpha-Beta Pruning, MCTS, and the FastAPI decision endpoints.
"""
import pytest
from fastapi.testclient import TestClient
from main import app

from algorithms.adversarial.combat_state import (
    CombatState,
    evaluate_combat_state,
    ACTION_TREMOR_SLAM,
    ACTION_PLASMA_BARRAGE,
    ACTION_CHARGE_RUSH,
    ACTION_PURSUE_ADVANCE,
    ACTION_TACTICAL_RETREAT,
    ACTION_GUARD_STANCE,
    ACTION_RECOVER_WAIT,
    ACTION_PLAYER_SHOOT,
    ACTION_PLAYER_DODGE
)
from algorithms.adversarial.minimax import MinimaxDecision
from algorithms.adversarial.alpha_beta import AlphaBetaDecision
from algorithms.adversarial.mcts import MCTSDecision

client = TestClient(app)


# ---------------------------------------------------------------------------
# 1. CombatState Tests
# ---------------------------------------------------------------------------
def test_combat_state_initial_legal_actions():
    """Verify legal actions when boss is at medium range with all cooldowns ready."""
    state = CombatState(distance=200.0, slam_cooldown=0.0, barrage_cooldown=0.0, charge_cooldown=0.0)
    actions = state.get_legal_actions()
    
    assert ACTION_PLASMA_BARRAGE in actions
    assert ACTION_CHARGE_RUSH in actions
    assert ACTION_PURSUE_ADVANCE in actions
    assert ACTION_TACTICAL_RETREAT in actions
    assert ACTION_GUARD_STANCE in actions
    # Tremor Slam should NOT be legal at distance 200 (requires <= 145)
    assert ACTION_TREMOR_SLAM not in actions


def test_combat_state_close_range_legal_actions():
    """Verify Tremor Slam is legal at close range when cooldown is 0."""
    state = CombatState(distance=100.0, slam_cooldown=0.0)
    actions = state.get_legal_actions()
    assert ACTION_TREMOR_SLAM in actions


def test_combat_state_recovery_forces_recover_wait():
    """When recovering, the only legal action should be RECOVER_WAIT."""
    state = CombatState(is_recovering=True, recover_timer=1.2)
    actions = state.get_legal_actions()
    assert actions == [ACTION_RECOVER_WAIT]


def test_combat_state_transitions():
    """Test state update upon applying Tremor Slam and subsequent player turn."""
    state = CombatState(distance=100.0, slam_cooldown=0.0, player_hp=100.0)
    next_state = state.apply_action(ACTION_TREMOR_SLAM)
    
    # Boss HP intact, player took damage
    assert next_state.player_hp < 100.0
    assert next_state.slam_cooldown > 0.0
    assert next_state.is_recovering is True
    assert next_state.turn == "player"

    # Player shoots back
    p_state = next_state.apply_action(ACTION_PLAYER_SHOOT)
    assert p_state.boss_hp < 500.0
    assert p_state.turn == "boss"


def test_combat_state_enrage_transition():
    """State automatically switches to Phase 2 if Boss HP <= 50% max HP."""
    state = CombatState(boss_hp=260.0, boss_max_hp=500.0, boss_phase=1)
    state.turn = "player"
    p_state = state.apply_action(ACTION_PLAYER_SHOOT)
    # 260 - 18 = 242 <= 250 (50%)
    assert p_state.boss_phase == 2


def test_combat_state_terminal_conditions():
    """Verify terminal conditions for win, loss, and max steps."""
    assert CombatState(boss_hp=0.0).is_terminal() is True
    assert CombatState(player_hp=0.0).is_terminal() is True
    assert CombatState(step_count=20, max_steps=20).is_terminal() is True
    assert CombatState(boss_hp=300.0, player_hp=80.0, step_count=5).is_terminal() is False


# ---------------------------------------------------------------------------
# 2. Heuristic Evaluation Tests
# ---------------------------------------------------------------------------
def test_evaluation_prefers_boss_victory():
    """Terminal boss victory should score higher than neutral or loss."""
    win_state = CombatState(boss_hp=400.0, player_hp=0.0)
    loss_state = CombatState(boss_hp=0.0, player_hp=80.0)
    neutral_state = CombatState(boss_hp=500.0, player_hp=100.0)
    
    assert evaluate_combat_state(win_state) > 5000.0
    assert evaluate_combat_state(loss_state) < -5000.0
    assert evaluate_combat_state(win_state) > evaluate_combat_state(neutral_state)


def test_evaluation_rewards_ready_cooldowns():
    """State with attacks ready should evaluate higher than state with attacks on cooldown."""
    ready_state = CombatState(slam_cooldown=0.0, barrage_cooldown=0.0, charge_cooldown=0.0)
    cooldown_state = CombatState(slam_cooldown=4.0, barrage_cooldown=4.0, charge_cooldown=5.0)
    assert evaluate_combat_state(ready_state) > evaluate_combat_state(cooldown_state)


# ---------------------------------------------------------------------------
# 3. Minimax & Alpha-Beta Search Tests
# ---------------------------------------------------------------------------
def test_minimax_selects_legal_action_with_statistics():
    """Minimax should return an action in legal_actions and populate node stats."""
    state = CombatState(distance=120.0, slam_cooldown=0.0)
    engine = MinimaxDecision(max_depth=3)
    res = engine.select_action(state)

    assert res["action"] in state.get_legal_actions()
    stats = res["statistics"]
    assert stats["nodes_evaluated"] > 0
    assert stats["max_depth_reached"] > 0
    assert "execution_time_ms" in stats
    assert stats["algorithm"] == "minimax"


def test_alpha_beta_matches_minimax_optimal_score():
    """Alpha-beta must produce an identical game-theoretic score to minimax with fewer or equal nodes."""
    state = CombatState(distance=180.0, slam_cooldown=0.0, barrage_cooldown=0.0, charge_cooldown=0.0)
    
    mm = MinimaxDecision(max_depth=3)
    ab = AlphaBetaDecision(max_depth=3)

    res_mm = mm.select_action(state)
    res_ab = ab.select_action(state)

    # Scores should be identical
    assert pytest.approx(res_mm["score"], abs=0.01) == res_ab["score"]
    # Alpha-Beta should prune branches and evaluate fewer or equal nodes
    assert res_ab["statistics"]["nodes_evaluated"] <= res_mm["statistics"]["nodes_evaluated"]
    assert res_ab["statistics"]["pruned_branches"] >= 0


# ---------------------------------------------------------------------------
# 4. MCTS Tests
# ---------------------------------------------------------------------------
def test_mcts_selects_legal_action_and_populates_visit_distribution():
    """MCTS should complete rollouts and return visit distribution."""
    state = CombatState(distance=100.0, slam_cooldown=0.0, barrage_cooldown=0.0)
    mcts = MCTSDecision(simulations=50, exploration_c=1.414)
    res = mcts.select_action(state)

    assert res["action"] in state.get_legal_actions()
    stats = res["statistics"]
    assert stats["simulations_completed"] == 50
    assert stats["nodes_expanded"] > 0
    assert len(stats["visit_counts"]) > 0
    assert stats["algorithm"] == "mcts"


# ---------------------------------------------------------------------------
# 5. FastAPI Endpoints Integration Tests
# ---------------------------------------------------------------------------
def test_api_get_algorithms():
    """GET /api/ai/boss/algorithms returns metadata for all algorithms."""
    response = client.get("/api/ai/boss/algorithms")
    assert response.status_code == 200
    data = response.json()
    assert "minimax" in data
    assert "alpha_beta" in data
    assert "mcts" in data
    assert "heuristic" in data


@pytest.mark.parametrize("algorithm", ["minimax", "alpha_beta", "mcts", "heuristic"])
def test_api_boss_decision_endpoints(algorithm):
    """POST /api/ai/boss/decision responds successfully for all supported algorithms."""
    payload = {
        "state": {
            "turn": "boss",
            "boss_hp": 480.0,
            "boss_max_hp": 500.0,
            "boss_phase": 1,
            "slam_cooldown": 0.0,
            "barrage_cooldown": 1.5,
            "charge_cooldown": 0.0,
            "is_recovering": False,
            "recover_timer": 0.0,
            "is_guarding": False,
            "player_hp": 90.0,
            "player_max_hp": 100.0,
            "player_energy": 80.0,
            "distance": 130.0
        },
        "algorithm": algorithm,
        "max_depth": 3,
        "simulations": 40
    }
    response = client.post("/api/ai/boss/decision", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert "action" in data
    assert data["action"] in data["legal_actions"]
    assert data["algorithm"] == algorithm
    assert "statistics" in data
    assert data["statistics"]["algorithm"] == algorithm or algorithm in data["statistics"]["algorithm"]
