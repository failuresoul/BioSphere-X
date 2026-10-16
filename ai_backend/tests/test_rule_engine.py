"""
Comprehensive Test Suite for BioSphere-X Rule-Based Inference Engine.
Verifies:
  1. Condition evaluation across all operators (==, !=, <, <=, >, >=, in, not_in, exists, not_exists).
  2. Safe evaluation over missing facts.
  3. Multi-step forward chaining rule dependencies (A -> B -> C).
  4. Contradictory condition resolution and priority-based overrides.
  5. BioSphere-X domain rules:
     - Life support & safe zone sanctuary overrides.
     - Critical hypoxia and emergency suffocation.
     - Mission prerequisites & planetary hyperspace clearances.
     - Boss protocol authorization.
     - Combat lockdown blocking extraction.
     - Complete extraction authorization criteria.
     - Environmental super-earth gravity & cryo-thermal drain.
  6. Explanation generation and derivation traces.
  7. FastAPI HTTP endpoints via TestClient (/infer, /rules, /explain, /register-rule).
"""
import pytest
from fastapi.testclient import TestClient

from main import app
from algorithms.logic.engine import (
    RuleInferenceEngine,
    Rule,
    Condition,
    InferenceResult
)

client = TestClient(app)


# ===========================================================================
# 1. Condition & Operator Unit Tests
# ===========================================================================
def test_condition_operators():
    facts = {
        "oxygen": 15.5,
        "planet": "lhs_1140_b",
        "inventory": ["sample_a", "sample_b"],
        "hazard_rating": 3
    }

    # Equality
    sat, _ = Condition(field="planet", operator="==", value="lhs_1140_b").evaluate(facts)
    assert sat is True
    sat, _ = Condition(field="planet", operator="==", value="mars").evaluate(facts)
    assert sat is False

    # Inequality
    sat, _ = Condition(field="planet", operator="!=", value="mars").evaluate(facts)
    assert sat is True

    # Numeric comparisons
    sat, _ = Condition(field="oxygen", operator="<", value=20.0).evaluate(facts)
    assert sat is True
    sat, _ = Condition(field="oxygen", operator="<=", value=15.5).evaluate(facts)
    assert sat is True
    sat, _ = Condition(field="oxygen", operator=">", value=10.0).evaluate(facts)
    assert sat is True
    sat, _ = Condition(field="oxygen", operator=">=", value=15.5).evaluate(facts)
    assert sat is True
    sat, _ = Condition(field="hazard_rating", operator=">", value=5).evaluate(facts)
    assert sat is False

    # Membership
    sat, _ = Condition(field="sample_a", operator="in", value=facts["inventory"]).evaluate({"sample_a": "sample_a"})
    # testing 'in' with field in container
    cond_in = Condition(field="planet", operator="in", value=["lhs_1140_b", "proxima_b"])
    sat, _ = cond_in.evaluate(facts)
    assert sat is True

    cond_not_in = Condition(field="planet", operator="not_in", value=["earth", "mars"])
    sat, _ = cond_not_in.evaluate(facts)
    assert sat is True

    # Exists / Not Exists
    sat, _ = Condition(field="oxygen", operator="exists").evaluate(facts)
    assert sat is True
    sat, _ = Condition(field="unknown_key", operator="exists").evaluate(facts)
    assert sat is False

    sat, _ = Condition(field="unknown_key", operator="not_exists").evaluate(facts)
    assert sat is True
    sat, _ = Condition(field="oxygen", operator="not_exists").evaluate(facts)
    assert sat is False


def test_missing_facts_tolerance():
    """Missing facts must evaluate to False gracefully without throwing exceptions."""
    facts = {"oxygen": 50.0}
    cond = Condition(field="unrecorded_variable", operator=">", value=10.0)
    satisfied, diag = cond.evaluate(facts)
    assert satisfied is False
    assert "Missing required fact" in diag


# ===========================================================================
# 2. Multi-Step Forward Chaining Rule Dependencies
# ===========================================================================
def test_multi_step_forward_chaining():
    """
    Tests forward chaining dependency chain:
      Rule 1: samples >= 3 -> sample_threshold_met
      Rule 2: sample_threshold_met + terminal_hacked -> lab_unlocked
      Rule 3: lab_unlocked -> extraction_beacon_active
    """
    engine = RuleInferenceEngine()

    engine.register_rule(Rule(
        id="r1_samples",
        name="Sample Quota",
        priority=100,
        conditions=[Condition(field="samples", operator=">=", value=3)],
        conclusions={"sample_threshold_met": True},
        actions=["log_sample_quota"]
    ))

    engine.register_rule(Rule(
        id="r2_lab",
        name="Lab Clearance",
        priority=90,
        conditions=[
            Condition(field="sample_threshold_met", operator="==", value=True),
            Condition(field="terminal_hacked", operator="==", value=True)
        ],
        conclusions={"lab_unlocked": True},
        actions=["open_lab_door"]
    ))

    engine.register_rule(Rule(
        id="r3_beacon",
        name="Extraction Beacon",
        priority=80,
        conditions=[Condition(field="lab_unlocked", operator="==", value=True)],
        conclusions={"extraction_beacon_active": True},
        actions=["broadcast_beacon"]
    ))

    # Initial state: samples = 3, terminal_hacked = True
    initial = {"samples": 4, "terminal_hacked": True}
    res = engine.forward_chain(initial)

    assert "sample_threshold_met" in res.derived_facts
    assert "lab_unlocked" in res.derived_facts
    assert "extraction_beacon_active" in res.derived_facts
    assert res.all_facts["extraction_beacon_active"] is True
    assert "open_lab_door" in res.applicable_actions
    assert "broadcast_beacon" in res.applicable_actions
    assert res.fired_rules == ["r1_samples", "r2_lab", "r3_beacon"]
    assert res.iterations == 4  # 3 fired rounds + 1 fixpoint check round


# ===========================================================================
# 3. Contradictory Conditions & Priority-Based Overrides
# ===========================================================================
def test_contradiction_priority_resolution():
    """
    Tests that a high-priority rule overrides a low-priority rule asserting conflicting facts,
    and records the contradiction resolution event.
    """
    engine = RuleInferenceEngine()

    # Low priority rule says extraction is authorized
    engine.register_rule(Rule(
        id="r_low_auth",
        name="Regular Extraction",
        priority=50,
        conditions=[Condition(field="mission_done", operator="==", value=True)],
        conclusions={"can_extract": True}
    ))

    # High priority rule overrides extraction due to hostile lockdown
    engine.register_rule(Rule(
        id="r_high_lockdown",
        name="Combat Lockdown",
        priority=150,
        conditions=[Condition(field="hostile_nearby", operator="==", value=True)],
        conclusions={"can_extract": False},
        actions=["alert_lockdown"]
    ))

    initial = {"mission_done": True, "hostile_nearby": True}
    res = engine.forward_chain(initial)

    # Since r_high_lockdown has priority 150 > 50, it fires first or overrides
    assert res.all_facts["can_extract"] is False
    assert "alert_lockdown" in res.applicable_actions


def test_fact_overrides_removal():
    """
    Tests that a rule's 'overrides' list removes specified stale facts from working memory.
    """
    engine = RuleInferenceEngine()

    engine.register_rule(Rule(
        id="r_shelter",
        name="Enter Shelter",
        priority=100,
        conditions=[Condition(field="in_shelter", operator="==", value=True)],
        conclusions={"shelter_active": True},
        overrides=["hazard_warning", "freeze_alert"]
    ))

    initial = {
        "in_shelter": True,
        "hazard_warning": True,
        "freeze_alert": True,
        "score": 100
    }
    res = engine.forward_chain(initial)

    assert res.all_facts["shelter_active"] is True
    assert "hazard_warning" not in res.all_facts
    assert "freeze_alert" not in res.all_facts
    assert res.all_facts["score"] == 100
    assert len(res.contradictions_detected) >= 2


# ===========================================================================
# 4. BioSphere-X Built-In Domain Rules
# ===========================================================================
def test_biosphere_life_support_sanctuary():
    """Inside safe zone, oxygen warnings and suffocation are suppressed."""
    engine = RuleInferenceEngine()

    # Player has 0% oxygen BUT is inside safe zone dome
    facts = {
        "oxygen_level": 0.0,
        "in_safe_zone": True
    }
    res = engine.forward_chain(facts)

    assert res.all_facts.get("atmospheric_sanctuary") is True
    assert res.all_facts.get("low_oxygen_warning") is False
    assert res.all_facts.get("critical_hypoxia") is False
    assert res.all_facts.get("suffocation_active") is False
    assert "refill_life_support" in res.applicable_actions
    assert "apply_suffocation_damage" not in res.applicable_actions


def test_biosphere_oxygen_warnings():
    """Outside safe zone, low and critical oxygen trigger expected warnings."""
    engine = RuleInferenceEngine()

    # 1. Low oxygen (between 10% and 25%)
    res_low = engine.forward_chain({"oxygen_level": 18.0, "in_safe_zone": False})
    assert res_low.derived_facts.get("low_oxygen_warning") is True
    assert res_low.derived_facts.get("critical_hypoxia") is None
    assert "flash_oxygen_hud" in res_low.applicable_actions

    # 2. Critical hypoxia (between 0% and 10%)
    res_crit = engine.forward_chain({"oxygen_level": 5.0, "in_safe_zone": False})
    assert res_crit.derived_facts.get("critical_hypoxia") is True
    assert res_crit.derived_facts.get("low_oxygen_warning") is True
    assert "trigger_critical_audio_alarm" in res_crit.applicable_actions

    # 3. Complete depletion (<= 0%)
    res_zero = engine.forward_chain({"oxygen_level": 0.0, "in_safe_zone": False})
    assert res_zero.derived_facts.get("suffocation_active") is True
    assert "apply_suffocation_damage" in res_zero.applicable_actions
    assert "alarm_critical_breach" in res_zero.applicable_actions


def test_biosphere_mission_progression():
    """Mission 1 completion unlocks LHS 1140 b and sets Mission 2 eligible."""
    engine = RuleInferenceEngine()

    res = engine.forward_chain({"mission_01_oxygen_completed": True})
    assert res.derived_facts.get("lhs_1140_b_unlocked") is True
    assert res.derived_facts.get("mission_02_eligible") is True
    assert "notify_hyperspace_vector_unlocked" in res.applicable_actions


def test_biosphere_boss_prerequisites():
    """Biomass samples >= 3 and scanned terminal unlocks apex boss protocol."""
    engine = RuleInferenceEngine()

    # Incomplete: only samples
    res_part = engine.forward_chain({"biomass_samples_collected": 3, "terminal_scanned": False})
    assert res_part.derived_facts.get("boss_protocol_authorized") is None

    # Complete
    res_full = engine.forward_chain({"biomass_samples_collected": 3, "terminal_scanned": True})
    assert res_full.derived_facts.get("boss_protocol_authorized") is True
    assert res_full.derived_facts.get("mission_05_eligible") is True
    assert "enable_boss_crater_waypoint" in res_full.applicable_actions


def test_biosphere_extraction_eligibility_and_lockdown():
    """Verifies airlock extraction authorization and combat lockdown override."""
    engine = RuleInferenceEngine()

    # Case A: Ready for extraction
    facts_ready = {
        "primary_missions_completed": True,
        "samples_carried": 2,
        "near_airlock": True,
        "combat_threat_active": False,
        "in_safe_zone": False
    }
    res_ready = engine.forward_chain(facts_ready)
    assert res_ready.all_facts.get("extraction_eligible") is True
    assert "unlock_airlock_exit" in res_ready.applicable_actions

    # Case B: Under hostile attack (combat threat active) -> Lockdown overrides extraction
    facts_combat = {
        "primary_missions_completed": True,
        "samples_carried": 2,
        "near_airlock": True,
        "combat_threat_active": True,
        "in_safe_zone": False
    }
    res_combat = engine.forward_chain(facts_combat)
    assert res_combat.all_facts.get("extraction_blocked") is True
    assert res_combat.all_facts.get("extraction_eligible") is False
    assert "warn_combat_lockdown" in res_combat.applicable_actions
    assert "unlock_airlock_exit" not in res_combat.applicable_actions


def test_biosphere_environmental_rules():
    """Super-Earth gravity and cryogenic temperature apply respective modifiers."""
    engine = RuleInferenceEngine()

    res_env = engine.forward_chain({
        "planet_id": "lhs_1140_b",
        "ambient_temperature_k": 180.0,
        "in_safe_zone": False
    })

    assert res_env.derived_facts.get("heavy_gravity_active") is True
    assert res_env.derived_facts.get("oxygen_drain_rate") == 2.2
    assert res_env.derived_facts.get("stamina_penalty") == 1.4
    assert res_env.derived_facts.get("cryo_hazard_active") is True
    assert "apply_heavy_gravity_hud_badge" in res_env.applicable_actions
    assert "activate_suit_heating_circuit" in res_env.applicable_actions


# ===========================================================================
# 5. Explanations & Reasoning Traces
# ===========================================================================
def test_explanation_generation():
    engine = RuleInferenceEngine()
    res = engine.forward_chain({"oxygen_level": 8.5, "in_safe_zone": False})

    exp = engine.explain("critical_hypoxia", res)
    assert exp["found"] is True
    assert "Critical Hypoxia Threshold" in exp["trace"]["rule_name"]
    assert "8.5%" in exp["trace"]["explanation"]
    assert len(exp["trace"]["antecedents_matched"]) >= 2

    # Action explanation
    exp_action = engine.explain("trigger_critical_audio_alarm", res)
    assert exp_action["found"] is True


# ===========================================================================
# 6. HTTP API Endpoints via TestClient
# ===========================================================================
def test_api_infer_endpoint():
    payload = {
        "facts": {
            "oxygen_level": 12.0,
            "in_safe_zone": False,
            "mission_01_oxygen_completed": True
        }
    }
    response = client.post("/api/ai/logic/infer", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "success"
    assert data["derived_facts"]["low_oxygen_warning"] is True
    assert data["derived_facts"]["lhs_1140_b_unlocked"] is True
    assert "flash_oxygen_hud" in data["applicable_actions"]
    assert "notify_hyperspace_vector_unlocked" in data["applicable_actions"]
    assert len(data["fired_rules"]) >= 2


def test_api_rule_catalog_endpoint():
    response = client.get("/api/ai/logic/rules")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "success"
    assert data["count"] >= 8
    rule_ids = [r["id"] for r in data["rules"]]
    assert "rule_safe_zone_sanctuary" in rule_ids
    assert "rule_extraction_criteria_satisfied" in rule_ids


def test_api_explain_endpoint():
    payload = {
        "target": "low_oxygen_warning",
        "facts": {"oxygen_level": 22.0, "in_safe_zone": False}
    }
    response = client.post("/api/ai/logic/explain", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "success"
    assert data["found"] is True
    assert "Caution" in data["trace"]["rule_name"]


def test_api_register_rule_endpoint():
    custom_rule = {
        "id": "rule_solar_flare_event",
        "name": "Solar Flare Atmospheric Disturbance",
        "category": "environmental",
        "priority": 130,
        "conditions": [
            {"field": "solar_flare_active", "operator": "==", "value": True}
        ],
        "conclusions": {
            "radar_scrambled": True,
            "comms_down": True
        },
        "actions": ["show_radar_static_fx"],
        "explanation_template": "Intense solar coronal mass ejection active. Sensor radar scrambled."
    }
    response = client.post("/api/ai/logic/register-rule", json=custom_rule)
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "success"
    assert data["rule_id"] == "rule_solar_flare_event"

    # Verify rule is evaluated in infer endpoint
    infer_resp = client.post("/api/ai/logic/infer", json={"facts": {"solar_flare_active": True}})
    infer_data = infer_resp.json()
    assert infer_data["derived_facts"]["radar_scrambled"] is True
    assert "show_radar_static_fx" in infer_data["applicable_actions"]
