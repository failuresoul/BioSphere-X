import pytest

from algorithms.logic.engine import RuleInferenceEngine
from algorithms.nlp.parser import CommandParser


@pytest.mark.parametrize(
    ("command", "intent"),
    [
        ("suit attack", "suit_attack"),
        ("guard me", "suit_guard"),
        ("please heal me", "suit_heal"),
    ],
)
def test_suit_commands(command: str, intent: str) -> None:
    parsed = CommandParser().parse(command)
    assert parsed.is_valid
    assert parsed.intent == intent


def test_arena_wave_rule_requires_surviving_pilot_and_zero_enemies() -> None:
    engine = RuleInferenceEngine()
    ready = engine.forward_chain({
        "arena_wave_active": True,
        "arena_enemies_remaining": 0,
        "arena_player_alive": True,
    }, categories=["arena"])
    assert ready.derived_facts["arena_wave_cleared"] is True
    assert "advance_arena_wave" in ready.applicable_actions

    not_ready = engine.forward_chain({
        "arena_wave_active": True,
        "arena_enemies_remaining": 1,
        "arena_player_alive": True,
    }, categories=["arena"])
    assert "arena_wave_cleared" not in not_ready.derived_facts
