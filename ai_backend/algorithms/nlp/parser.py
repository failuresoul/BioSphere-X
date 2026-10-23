"""
Lightweight Offline Command Parser for BioSphere-X.
Translates free-form textual gameplay commands into structured intents with validated parameters.
Requires NO internet access or paid LLM APIs.
"""
from typing import Any, Dict, List, Optional, Tuple
import re
from pydantic import BaseModel, Field


class ParsedCommand(BaseModel):
    raw_input: str
    intent: str  # "collect_oxygen", "show_inventory", "return_to_base", "find_station", "check_vitals", "help", "ambiguous", "unknown"
    confidence: float  # 0.0 to 1.0
    parameters: Dict[str, Any] = Field(default_factory=dict)
    is_valid: bool
    status: str  # "success", "ambiguous", "unknown"
    clarification_prompt: str = ""
    suggested_actions: List[str] = Field(default_factory=list)


class CommandParser:
    """
    Rule-based offline NLP command parser using tokenization, keyword matching,
    intent classification, and parameter slot filling.
    """

    SUPPORTED_INTENTS: List[Dict[str, Any]] = [
        {
            "id": "suit_attack",
            "name": "Suit Attack Mode",
            "description": "Sets the pilot suit to boost weapon damage.",
            "examples": ["attack", "suit attack", "focus fire"]
        },
        {
            "id": "suit_guard",
            "name": "Suit Guard Mode",
            "description": "Sets the pilot suit to reduce incoming damage.",
            "examples": ["defend", "guard", "shield me"]
        },
        {
            "id": "suit_heal",
            "name": "Suit Repair Mode",
            "description": "Sets the pilot suit to repair health using pulse energy.",
            "examples": ["heal", "repair suit", "heal me"]
        },
        {
            "id": "collect_oxygen",
            "name": "Collect Oxygen",
            "description": "Refills suit life-support or gathers oxygen canisters.",
            "examples": ["collect oxygen", "refill o2", "gather oxygen cells", "take 50 oxygen"]
        },
        {
            "id": "show_inventory",
            "name": "Show Inventory",
            "description": "Opens backpack cargo or displays carried resources.",
            "examples": ["show inventory", "open backpack", "check carried items", "view resources"]
        },
        {
            "id": "return_to_base",
            "name": "Return to Base",
            "description": "Navigates back to the research habitat dome or initiates extraction.",
            "examples": ["return to base", "go back to habitat", "extract to airlock", "recall to dome"]
        },
        {
            "id": "find_station",
            "name": "Find Station / Terminal",
            "description": "Locates the nearest research terminal, storage console, or base outpost.",
            "examples": ["find research station", "locate terminal", "where is the outpost", "track nearest station"]
        },
        {
            "id": "check_vitals",
            "name": "Check Vitals",
            "description": "Reviews astronaut health, oxygen percentage, and suit hazard telemetry.",
            "examples": ["status", "check vitals", "suit status", "oxygen level"]
        },
        {
            "id": "help",
            "name": "Command Terminal Help",
            "description": "Displays list of supported commands and operational manual.",
            "examples": ["help", "commands", "manual", "?"]
        }
    ]

    def __init__(self):
        self._compile_patterns()

    def _compile_patterns(self) -> None:
        """Compiles regex matchers for intent recognition and parameter extraction."""
        self._re_suit_attack = re.compile(r"\b(attack|focus\s+fire|shoot|fight)\b", re.IGNORECASE)
        self._re_suit_guard = re.compile(r"\b(defend|guard|protect|shield)\b", re.IGNORECASE)
        self._re_suit_heal = re.compile(r"\b(heal|healing|medic|repair\s+suit)\b", re.IGNORECASE)
        # 1. Collect Oxygen
        self._re_o2_intent = re.compile(
            r"\b(collect|gather|get|refill|replenish|harvest|take|recharge|breathe|fill|use)\b.*?\b(oxygen|o2|air|cells?|canisters?|tank)\b"
            r"|\b(oxygen|o2)\b.*?\b(collect|gather|refill|replenish|recharge|boost)\b"
            r"|^\s*(oxygen|o2)\s*$",
            re.IGNORECASE
        )
        self._re_number = re.compile(r"\b(\d+(?:\.\d+)?)\s*(?:%|units?|cells?|pts?)?\b", re.IGNORECASE)

        # 2. Show Inventory
        self._re_inventory_intent = re.compile(
            r"\b(show|open|view|display|check|list|inspect|see)\b.*?\b(inventory|items?|cargo|backpack|resources?|bag|gear|supplies|pockets?)\b"
            r"|^\s*(inventory|items|cargo|backpack|bag)\s*$",
            re.IGNORECASE
        )

        # 3. Return to Base
        self._re_base_intent = re.compile(
            r"\b(return|go\s+back|head\s+back|retreat|teleport|extract|evacuate|recall|navigate\s+to|dock\s+at)\b.*?\b(base|habitat|dome|airlock|sanctuary|home|ship|station)\b"
            r"|^\s*(return|extract|evacuate|recall)\s*$",
            re.IGNORECASE
        )

        # 4. Find Station / Terminal
        self._re_station_intent = re.compile(
            r"\b(find|locate|where\s+is|track|show|point\s+to|search\s+for|navigate\s+to)\b.*?\b(research|terminal|outpost|console|station|beacon|waypoint|scanner|vault|storage|depot)\b"
            r"|^\s*(terminal|station|outpost|vault)\s*$",
            re.IGNORECASE
        )

        # 5. Check Vitals
        self._re_vitals_intent = re.compile(
            r"\b(status|vitals?|health|suit|telemetry|condition|diagnostics?)\b",
            re.IGNORECASE
        )

        # 6. Help
        self._re_help_intent = re.compile(
            r"^\s*(help|\?|commands|manual|syntax|info)\s*$",
            re.IGNORECASE
        )

        # Ambiguous keyword triggers (single verbs without clarifying noun targets)
        self._re_ambiguous_find = re.compile(r"^\s*(find|locate|where|search|track)\s*$", re.IGNORECASE)
        self._re_ambiguous_get = re.compile(r"^\s*(get|take|collect|gather)\s*$", re.IGNORECASE)
        self._re_ambiguous_open = re.compile(r"^\s*(open|show|view|check)\s*$", re.IGNORECASE)
        self._re_ambiguous_go = re.compile(r"^\s*(go|walk|travel|run|move)\s*$", re.IGNORECASE)

    def parse(self, text: str, context: Optional[Dict[str, Any]] = None) -> ParsedCommand:
        """
        Parses textual player command into validated intent and parameters.
        Does NOT alter game state. Returns structured interpretation.
        """
        raw = text.strip()
        if not raw:
            return ParsedCommand(
                raw_input="",
                intent="unknown",
                confidence=0.0,
                parameters={},
                is_valid=False,
                status="unknown",
                clarification_prompt="Please enter a command (e.g. 'collect oxygen', 'show inventory', 'return to base').",
                suggested_actions=["help", "collect oxygen", "show inventory", "return to base"]
            )

        for pattern, intent, mode in (
            (self._re_suit_attack, "suit_attack", "attack"),
            (self._re_suit_guard, "suit_guard", "guard"),
            (self._re_suit_heal, "suit_heal", "heal"),
        ):
            if pattern.search(raw):
                return ParsedCommand(
                    raw_input=raw,
                    intent=intent,
                    confidence=0.95,
                    parameters={"suit_mode": mode},
                    is_valid=True,
                    status="success",
                    suggested_actions=["set_suit_mode"]
                )

        # Check Ambiguous commands first
        if self._re_ambiguous_find.match(raw):
            return ParsedCommand(
                raw_input=raw,
                intent="ambiguous",
                confidence=0.5,
                parameters={"stem": "find"},
                is_valid=False,
                status="ambiguous",
                clarification_prompt="Target unspecified. Did you mean: 'find research station' or 'find oxygen'?",
                suggested_actions=["find research station", "find oxygen", "return to base"]
            )

        if self._re_ambiguous_get.match(raw):
            return ParsedCommand(
                raw_input=raw,
                intent="ambiguous",
                confidence=0.5,
                parameters={"stem": "get"},
                is_valid=False,
                status="ambiguous",
                clarification_prompt="Item unspecified. Did you mean: 'collect oxygen' or 'view inventory'?",
                suggested_actions=["collect oxygen", "show inventory"]
            )

        if self._re_ambiguous_open.match(raw):
            return ParsedCommand(
                raw_input=raw,
                intent="ambiguous",
                confidence=0.5,
                parameters={"stem": "open"},
                is_valid=False,
                status="ambiguous",
                clarification_prompt="View target unspecified. Did you mean: 'show inventory' or 'check vitals'?",
                suggested_actions=["show inventory", "check vitals"]
            )

        if self._re_ambiguous_go.match(raw):
            return ParsedCommand(
                raw_input=raw,
                intent="ambiguous",
                confidence=0.5,
                parameters={"stem": "go"},
                is_valid=False,
                status="ambiguous",
                clarification_prompt="Destination unspecified. Did you mean: 'return to base' or 'find research station'?",
                suggested_actions=["return to base", "find research station"]
            )

        # 1. Collect Oxygen
        if self._re_o2_intent.search(raw):
            amount = 100.0  # default full refill
            num_match = self._re_number.search(raw)
            if num_match:
                try:
                    parsed_amt = float(num_match.group(1))
                    if parsed_amt > 0:
                        amount = min(parsed_amt, 100.0)
                except ValueError:
                    pass

            target = "tank"
            if "canister" in raw.lower() or "cell" in raw.lower():
                target = "oxygen_cells"

            return ParsedCommand(
                raw_input=raw,
                intent="collect_oxygen",
                confidence=0.95,
                parameters={
                    "target": target,
                    "requested_amount": amount,
                    "unit": "percentage" if target == "tank" else "units"
                },
                is_valid=True,
                status="success",
                clarification_prompt="",
                suggested_actions=["confirm_refill", "navigate_to_oxygen_depot"]
            )

        # 2. Show Inventory
        if self._re_inventory_intent.search(raw):
            category = "all"
            if "resource" in raw.lower() or "mineral" in raw.lower() or "metal" in raw.lower():
                category = "resources"
            elif "tool" in raw.lower() or "equipment" in raw.lower() or "gear" in raw.lower():
                category = "equipment"

            return ParsedCommand(
                raw_input=raw,
                intent="show_inventory",
                confidence=0.95,
                parameters={
                    "view_mode": "dialog",
                    "filter_category": category,
                    "open_ui": True
                },
                is_valid=True,
                status="success",
                clarification_prompt="",
                suggested_actions=["open_inventory_dialog"]
            )

        # 3. Return to Base
        if self._re_base_intent.search(raw):
            destination = "habitat_airlock"
            if "dome" in raw.lower() or "sanctuary" in raw.lower():
                destination = "base_habitat"

            return ParsedCommand(
                raw_input=raw,
                intent="return_to_base",
                confidence=0.95,
                parameters={
                    "destination": destination,
                    "dock_airlock": True,
                    "auto_path": True
                },
                is_valid=True,
                status="success",
                clarification_prompt="",
                suggested_actions=["set_base_waypoint", "initiate_airlock_extraction"]
            )

        # 4. Find Station / Terminal
        if self._re_station_intent.search(raw):
            st_type = "research_terminal"
            if "storage" in raw.lower() or "vault" in raw.lower():
                st_type = "storage_terminal"
            elif "return" in raw.lower() or "extraction" in raw.lower():
                st_type = "return_terminal"
            elif "outpost" in raw.lower() or "base" in raw.lower():
                st_type = "base_station"

            return ParsedCommand(
                raw_input=raw,
                intent="find_station",
                confidence=0.92,
                parameters={
                    "station_type": st_type,
                    "set_waypoint": True,
                    "ping_radar": True
                },
                is_valid=True,
                status="success",
                clarification_prompt="",
                suggested_actions=["display_waypoint_marker", "highlight_station_radar"]
            )

        # 5. Check Vitals
        if self._re_vitals_intent.search(raw):
            return ParsedCommand(
                raw_input=raw,
                intent="check_vitals",
                confidence=0.90,
                parameters={"scope": "all"},
                is_valid=True,
                status="success",
                clarification_prompt="",
                suggested_actions=["display_vitals_hud"]
            )

        # 6. Help
        if self._re_help_intent.search(raw):
            return ParsedCommand(
                raw_input=raw,
                intent="help",
                confidence=1.0,
                parameters={"commands": [c["id"] for c in self.SUPPORTED_INTENTS]},
                is_valid=True,
                status="success",
                clarification_prompt="",
                suggested_actions=["display_terminal_help"]
            )

        # 7. Unknown command
        return ParsedCommand(
            raw_input=raw,
            intent="unknown",
            confidence=0.1,
            parameters={},
            is_valid=False,
            status="unknown",
            clarification_prompt=f"Command '{raw}' unrecognized. Try 'collect oxygen', 'show inventory', 'return to base', or 'help'.",
            suggested_actions=["help", "collect oxygen", "show inventory", "return to base", "find research station"]
        )
