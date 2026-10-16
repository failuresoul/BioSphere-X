"""
Comprehensive Unit and Integration Tests for BioSphere-X Fuzzy Adaptive Difficulty System.
Tests membership functions, Mamdani rule evaluation, centroid defuzzification,
representative scenario outputs, fixed difficulty baselines, and FastAPI endpoints.
"""
import pytest
from fastapi.testclient import TestClient
from main import app

from algorithms.fuzzy.membership import triangular, trapezoidal, LinguisticVariable
from algorithms.fuzzy.rules import FuzzyRule
from algorithms.fuzzy.engine import FuzzyInferenceEngine, FIXED_DIFFICULTY_PROFILES

client = TestClient(app)


# ---------------------------------------------------------------------------
# 1. Membership Function Tests
# ---------------------------------------------------------------------------
def test_triangular_membership_function():
    """Verify triangular membership values across distinct regions."""
    # Triangular MF with a=20, b=50, c=80
    assert triangular(10.0, 20.0, 50.0, 80.0) == 0.0 # Outside left
    assert triangular(20.0, 20.0, 50.0, 80.0) == 0.0 # Left boundary
    assert triangular(35.0, 20.0, 50.0, 80.0) == 0.5 # Left slope
    assert triangular(50.0, 20.0, 50.0, 80.0) == 1.0 # Peak
    assert triangular(65.0, 20.0, 50.0, 80.0) == 0.5 # Right slope
    assert triangular(80.0, 20.0, 50.0, 80.0) == 0.0 # Right boundary
    assert triangular(90.0, 20.0, 50.0, 80.0) == 0.0 # Outside right


def test_trapezoidal_membership_function():
    """Verify trapezoidal membership values including plateau and slopes."""
    # Trapezoidal MF with a=10, b=30, c=70, d=90
    assert trapezoidal(5.0, 10.0, 30.0, 70.0, 90.0) == 0.0 # Outside left
    assert trapezoidal(20.0, 10.0, 30.0, 70.0, 90.0) == 0.5 # Left slope
    assert trapezoidal(30.0, 10.0, 30.0, 70.0, 90.0) == 1.0 # Left plateau edge
    assert trapezoidal(50.0, 10.0, 30.0, 70.0, 90.0) == 1.0 # Plateau center
    assert trapezoidal(70.0, 10.0, 30.0, 70.0, 90.0) == 1.0 # Right plateau edge
    assert trapezoidal(80.0, 10.0, 30.0, 70.0, 90.0) == 0.5 # Right slope
    assert trapezoidal(95.0, 10.0, 30.0, 70.0, 90.0) == 0.0 # Outside right


def test_linguistic_variable_fuzzification_and_clamping():
    """Verify LinguisticVariable correctly fuzzifies inputs and clamps out-of-domain values."""
    var = LinguisticVariable("health", (0.0, 100.0))
    var.add_term("LOW", lambda x: trapezoidal(x, -10.0, 0.0, 25.0, 50.0))
    var.add_term("HIGH", lambda x: trapezoidal(x, 50.0, 75.0, 100.0, 110.0))

    # In-bounds value
    fuzz = var.fuzzify(25.0)
    assert fuzz["LOW"] == 1.0
    assert fuzz["HIGH"] == 0.0

    # Below domain minimum (clamped to 0.0)
    fuzz_under = var.fuzzify(-50.0)
    assert fuzz_under["LOW"] == 1.0
    assert fuzz_under["HIGH"] == 0.0

    # Above domain maximum (clamped to 100.0)
    fuzz_over = var.fuzzify(200.0)
    assert fuzz_over["LOW"] == 0.0
    assert fuzz_over["HIGH"] == 1.0


# ---------------------------------------------------------------------------
# 2. Fuzzy Rule Evaluation Tests
# ---------------------------------------------------------------------------
def test_fuzzy_rule_evaluation():
    """Verify fuzzy rule conjunction using min t-norm and weight application."""
    rule = FuzzyRule(
        {"health": "CRITICAL", "damage": "HIGH"},
        ("aggression", "VERY_LOW"),
        weight=0.8
    )

    fuzzified_inputs = {
        "health": {"CRITICAL": 0.7, "HEALTHY": 0.0},
        "damage": {"HIGH": 0.5, "LOW": 0.1}
    }

    # min(0.7, 0.5) * 0.8 = 0.5 * 0.8 = 0.4
    strength = rule.evaluate(fuzzified_inputs)
    assert pytest.approx(strength, abs=1e-4) == 0.40


# ---------------------------------------------------------------------------
# 3. Representative Scenario Adaptive Difficulty Tests
# ---------------------------------------------------------------------------
def test_scenario_critical_health_heavy_damage_gives_low_aggression():
    """
    Scenario 1: Player is on the verge of death and taking intense hits.
    The system should dial back enemy aggression to prevent rapid, unfair defeat.
    """
    engine = FuzzyInferenceEngine()
    res = engine.evaluate(player_health=10.0, recent_damage=85.0, enemy_distance=60.0)

    aggression = res["enemy_aggression"]
    assert 0.15 <= aggression <= 0.45, f"Expected low aggression for critical player, got {aggression}"
    assert res["parameters"]["speed_multiplier"] < 1.0
    assert res["parameters"]["attack_cooldown_multiplier"] > 1.0 # Slower attack rate


def test_scenario_healthy_player_close_combat_gives_high_aggression():
    """
    Scenario 2: Player is healthy, unscathed, and right next to the enemy.
    The system should ramp up aggression to deliver a thrilling and challenging fight.
    """
    engine = FuzzyInferenceEngine()
    res = engine.evaluate(player_health=95.0, recent_damage=0.0, enemy_distance=50.0)

    aggression = res["enemy_aggression"]
    assert 0.75 <= aggression <= 1.0, f"Expected high aggression for healthy player, got {aggression}"
    assert res["parameters"]["speed_multiplier"] >= 1.10
    assert res["parameters"]["attack_cooldown_multiplier"] <= 0.95 # Rapid attack rate


def test_scenario_moderate_health_and_damage_gives_balanced_aggression():
    """
    Scenario 3: Player has moderate health, taking steady hits at medium range.
    The system should maintain a balanced baseline combat experience.
    """
    engine = FuzzyInferenceEngine()
    res = engine.evaluate(player_health=50.0, recent_damage=45.0, enemy_distance=250.0)

    aggression = res["enemy_aggression"]
    assert 0.45 <= aggression <= 0.72, f"Expected balanced aggression, got {aggression}"


def test_scenario_healthy_player_at_long_range_presses_forward():
    """
    Scenario 4: Player is at long range taking no damage.
    Enemies should have high pursuit pressure to close distance.
    """
    engine = FuzzyInferenceEngine()
    res = engine.evaluate(player_health=90.0, recent_damage=5.0, enemy_distance=450.0)

    aggression = res["enemy_aggression"]
    assert aggression >= 0.60, f"Expected elevated aggression to close distance, got {aggression}"


def test_output_bounds_strictly_enforced_across_extreme_inputs():
    """Verify that outputs strictly stay within [0.15, 1.00] regardless of extreme input values."""
    engine = FuzzyInferenceEngine(output_bounds=(0.15, 1.0))

    extremes = [
        (0.0, 100.0, 0.0),
        (100.0, 0.0, 600.0),
        (-999.0, 999.0, -100.0),
        (500.0, -200.0, 9999.0)
    ]

    for hp, dmg, dist in extremes:
        res = engine.evaluate(hp, dmg, dist)
        agg = res["enemy_aggression"]
        assert 0.15 <= agg <= 1.0, f"Output {agg} violated bounds [0.15, 1.0] for inputs ({hp}, {dmg}, {dist})"


# ---------------------------------------------------------------------------
# 4. Fixed Difficulty Mode Tests
# ---------------------------------------------------------------------------
@pytest.mark.parametrize("mode,expected_agg", [
    ("easy", 0.35),
    ("normal", 0.60),
    ("hard", 0.85),
    ("nightmare", 1.00)
])
def test_fixed_difficulty_modes(mode, expected_agg):
    """Verify fixed-difficulty modes return consistent benchmark values."""
    engine = FuzzyInferenceEngine()
    res = engine.evaluate(player_health=20.0, recent_damage=90.0, enemy_distance=50.0, fixed_mode=mode)

    assert res["mode"] == f"fixed_{mode}"
    assert res["enemy_aggression"] == expected_agg
    assert "parameters" in res


# ---------------------------------------------------------------------------
# 5. FastAPI Endpoints Integration Tests
# ---------------------------------------------------------------------------
def test_api_get_profiles():
    """GET /api/ai/fuzzy/profiles returns all fixed difficulty presets."""
    response = client.get("/api/ai/fuzzy/profiles")
    assert response.status_code == 200
    data = response.json()
    assert "easy" in data
    assert "normal" in data
    assert "hard" in data
    assert "nightmare" in data


def test_api_get_rules():
    """GET /api/ai/fuzzy/rules returns system structure, terms, and rules."""
    response = client.get("/api/ai/fuzzy/rules")
    assert response.status_code == 200
    data = response.json()
    assert "inputs" in data
    assert "player_health" in data["inputs"]
    assert "recent_damage" in data["inputs"]
    assert "enemy_distance" in data["inputs"]
    assert data["rules_count"] > 0


def test_api_post_difficulty_adaptive():
    """POST /api/ai/fuzzy/difficulty evaluates adaptive difficulty successfully."""
    payload = {
        "player_health": 85.0,
        "recent_damage": 10.0,
        "enemy_distance": 150.0
    }
    response = client.post("/api/ai/fuzzy/difficulty", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert 0.15 <= data["difficulty_score"] <= 1.0
    assert 0.15 <= data["enemy_aggression"] <= 1.0
    assert data["mode"] == "adaptive"
    assert "parameters" in data
    assert "speed_multiplier" in data["parameters"]
    assert "attack_cooldown_multiplier" in data["parameters"]
    assert "attack_damage_multiplier" in data["parameters"]
    assert "detection_range_multiplier" in data["parameters"]
    assert len(data["firing_rules"]) > 0


def test_api_post_difficulty_fixed_mode():
    """POST /api/ai/fuzzy/difficulty returns fixed profile when requested."""
    payload = {
        "player_health": 50.0,
        "recent_damage": 50.0,
        "enemy_distance": 200.0,
        "fixed_mode": "hard"
    }
    response = client.post("/api/ai/fuzzy/difficulty", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["mode"] == "fixed_hard"
    assert data["enemy_aggression"] == 0.85
