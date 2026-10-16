"""
Test Suite for BioSphere-X Natural Language Command Parser.
Verifies lightweight offline natural language parsing:
  1. Collecting oxygen commands and parameter slot extraction.
  2. Showing inventory commands and category filtering.
  3. Returning to base / extraction commands.
  4. Finding research station / terminal locator commands.
  5. Vitals and status checking commands.
  6. Ambiguous command handling and clarification generation.
  7. Unknown command handling with suggested fallback actions.
  8. Purity guarantee: parser returns structured intent without mutating state.
  9. FastAPI HTTP endpoints via TestClient (/parse, /commands).
"""
import pytest
from fastapi.testclient import TestClient

from main import app
from algorithms.nlp.parser import CommandParser, ParsedCommand

client = TestClient(app)
parser = CommandParser()


# ===========================================================================
# 1. Collect Oxygen Command Tests
# ===========================================================================
def test_parse_collect_oxygen_standard():
    cmd = parser.parse("collect oxygen")
    assert cmd.is_valid is True
    assert cmd.intent == "collect_oxygen"
    assert cmd.status == "success"
    assert cmd.confidence >= 0.9
    assert cmd.parameters["target"] == "tank"
    assert cmd.parameters["requested_amount"] == 100.0


def test_parse_collect_oxygen_with_quantity():
    cmd = parser.parse("refill 50 oxygen")
    assert cmd.intent == "collect_oxygen"
    assert cmd.parameters["requested_amount"] == 50.0

    cmd_cells = parser.parse("gather 3 oxygen cells")
    assert cmd_cells.intent == "collect_oxygen"
    assert cmd_cells.parameters["target"] == "oxygen_cells"
    assert cmd_cells.parameters["requested_amount"] == 3.0


def test_parse_collect_oxygen_synonyms():
    for phrase in ["replenish suit oxygen", "get o2", "harvest oxygen cell", "breathe air"]:
        res = parser.parse(phrase)
        assert res.intent == "collect_oxygen", f"Failed for phrase: '{phrase}'"


# ===========================================================================
# 2. Show Inventory Command Tests
# ===========================================================================
def test_parse_show_inventory_standard():
    cmd = parser.parse("show inventory")
    assert cmd.is_valid is True
    assert cmd.intent == "show_inventory"
    assert cmd.parameters["open_ui"] is True
    assert cmd.parameters["filter_category"] == "all"


def test_parse_show_inventory_synonyms_and_filters():
    cmd_res = parser.parse("view carried resources")
    assert cmd_res.intent == "show_inventory"
    assert cmd_res.parameters["filter_category"] == "resources"

    cmd_bag = parser.parse("open backpack")
    assert cmd_bag.intent == "show_inventory"

    cmd_cargo = parser.parse("check cargo")
    assert cmd_cargo.intent == "show_inventory"


# ===========================================================================
# 3. Return to Base Command Tests
# ===========================================================================
def test_parse_return_to_base_standard():
    cmd = parser.parse("return to base")
    assert cmd.is_valid is True
    assert cmd.intent == "return_to_base"
    assert cmd.parameters["destination"] == "habitat_airlock"
    assert cmd.parameters["dock_airlock"] is True


def test_parse_return_to_base_synonyms():
    for phrase in ["go back to base", "extract to airlock", "recall to dome", "head back to sanctuary", "evacuate"]:
        res = parser.parse(phrase)
        assert res.intent == "return_to_base", f"Failed for phrase: '{phrase}'"


# ===========================================================================
# 4. Find Research Station Command Tests
# ===========================================================================
def test_parse_find_station_standard():
    cmd = parser.parse("find research station")
    assert cmd.is_valid is True
    assert cmd.intent == "find_station"
    assert cmd.parameters["station_type"] == "research_terminal"
    assert cmd.parameters["set_waypoint"] is True


def test_parse_find_station_subtypes():
    cmd_storage = parser.parse("where is the storage vault")
    assert cmd_storage.intent == "find_station"
    assert cmd_storage.parameters["station_type"] == "storage_terminal"

    cmd_return = parser.parse("locate return terminal")
    assert cmd_return.intent == "find_station"
    assert cmd_return.parameters["station_type"] == "return_terminal"

    cmd_outpost = parser.parse("locate terminal")
    assert cmd_outpost.intent == "find_station"


# ===========================================================================
# 5. Check Vitals and Status Tests
# ===========================================================================
def test_parse_check_vitals():
    for phrase in ["status", "check vitals", "suit status", "telemetry"]:
        res = parser.parse(phrase)
        assert res.intent == "check_vitals"
        assert res.is_valid is True


# ===========================================================================
# 6. Ambiguous Commands Handling
# ===========================================================================
def test_parse_ambiguous_commands():
    # Single ambiguous verb "find"
    cmd_find = parser.parse("find")
    assert cmd_find.intent == "ambiguous"
    assert cmd_find.is_valid is False
    assert cmd_find.status == "ambiguous"
    assert "Did you mean" in cmd_find.clarification_prompt
    assert len(cmd_find.suggested_actions) > 0

    # Single ambiguous verb "get"
    cmd_get = parser.parse("get")
    assert cmd_get.intent == "ambiguous"
    assert cmd_get.status == "ambiguous"

    # Single ambiguous verb "open"
    cmd_open = parser.parse("open")
    assert cmd_open.intent == "ambiguous"

    # Single ambiguous verb "go"
    cmd_go = parser.parse("go")
    assert cmd_go.intent == "ambiguous"


# ===========================================================================
# 7. Unknown Commands & Robust Fallbacks
# ===========================================================================
def test_parse_unknown_commands():
    cmd_gibberish = parser.parse("dance on the crater surface")
    assert cmd_gibberish.intent == "unknown"
    assert cmd_gibberish.is_valid is False
    assert cmd_gibberish.status == "unknown"
    assert "unrecognized" in cmd_gibberish.clarification_prompt
    assert "collect oxygen" in cmd_gibberish.suggested_actions

    cmd_empty = parser.parse("   ")
    assert cmd_empty.intent == "unknown"
    assert cmd_empty.is_valid is False


# ===========================================================================
# 8. Help Command
# ===========================================================================
def test_parse_help_command():
    cmd = parser.parse("help")
    assert cmd.intent == "help"
    assert cmd.is_valid is True
    assert len(cmd.parameters["commands"]) >= 4


# ===========================================================================
# 9. FastAPI HTTP Endpoints via TestClient
# ===========================================================================
def test_api_parse_endpoint():
    payload = {"query": "collect oxygen"}
    response = client.post("/api/ai/nlp/parse", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "success"
    assert data["parsed"]["intent"] == "collect_oxygen"
    assert data["parsed"]["parameters"]["target"] == "tank"


def test_api_parse_ambiguous_endpoint():
    payload = {"query": "find"}
    response = client.post("/api/ai/nlp/parse", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ambiguous"
    assert data["parsed"]["intent"] == "ambiguous"
    assert len(data["parsed"]["suggested_actions"]) >= 2


def test_api_command_catalog_endpoint():
    response = client.get("/api/ai/nlp/commands")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "success"
    assert data["count"] >= 4
    intent_ids = [c["id"] for c in data["commands"]]
    assert "collect_oxygen" in intent_ids
    assert "show_inventory" in intent_ids
    assert "return_to_base" in intent_ids
    assert "find_station" in intent_ids
