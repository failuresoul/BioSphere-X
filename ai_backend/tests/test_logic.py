"""Tests for forward chaining (algorithms/logic/engine.py)."""
from fastapi.testclient import TestClient

from algorithms.logic import forward_chain
from main import app


def test_duel_won_then_unlock_in_order():
    result = forward_chain({"boss_hp": 0, "player_hp": 40, "oxygen": 80})
    assert result["new_facts"] == {"duel_won": True, "unlock_next_planet": True}
    assert result["fired_rules"] == ["victory", "unlock"]      # unlock needs duel_won first


def test_no_win_while_the_boss_is_alive():
    assert "duel_won" not in forward_chain({"boss_hp": 30, "player_hp": 40})["new_facts"]


def test_player_down_is_a_loss_not_a_win():
    new = forward_chain({"boss_hp": 0, "player_hp": 0})["new_facts"]
    assert new == {"duel_lost": True}


def test_warnings():
    new = forward_chain({"player_hp": 20, "oxygen": 10})["new_facts"]
    assert new == {"low_health_warning": True, "oxygen_warning": True}
    assert forward_chain({"player_hp": 90, "oxygen": 50})["new_facts"] == {}


def test_logic_endpoint():
    response = TestClient(app).post("/logic/infer", json={"facts": {"boss_hp": 0, "player_hp": 1}})
    assert response.status_code == 200
    assert response.json()["new_facts"]["unlock_next_planet"] is True
