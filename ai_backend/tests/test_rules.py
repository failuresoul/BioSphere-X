"""Tests for forward chaining."""
from fastapi.testclient import TestClient

from algorithms.rules import forward_chain
from main import app


def test_duel_won_and_chained_unlock():
    result = forward_chain({"boss_hp": 0, "player_hp": 40, "planet": 2})
    assert result["derived"]["duel_won"] is True
    assert result["derived"]["unlock_next_planet"] is True        # derived from duel_won
    assert result["fired_rules"][:2] == ["victory", "unlock"]


def test_no_win_while_boss_alive_or_player_down():
    assert "duel_won" not in forward_chain({"boss_hp": 30, "player_hp": 40, "planet": 0})["derived"]
    lost = forward_chain({"boss_hp": 0, "player_hp": 0, "planet": 0})["derived"]
    assert "duel_won" not in lost and lost["duel_lost"] is True


def test_last_planet_completes_campaign_and_low_health_warning():
    derived = forward_chain({"boss_hp": 0, "player_hp": 20, "planet": 9})["derived"]
    assert derived["campaign_complete"] and derived["low_health_warning"]
    assert "unlock_next_planet" not in derived


def test_rules_endpoint():
    response = TestClient(app).post("/api/ai/rules", json={"facts": {"boss_hp": 0, "player_hp": 1, "planet": 0}})
    assert response.status_code == 200
    assert response.json()["derived"]["duel_won"] is True
