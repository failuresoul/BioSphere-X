from algorithms.logic.engine import RuleInferenceEngine


def test_duel_rule_requires_rival_down_and_pilot_alive() -> None:
    engine = RuleInferenceEngine()
    won = engine.forward_chain(
        {"duel_active": True, "duel_rival_down": True, "duel_player_alive": True},
        categories=["duel"],
    )
    assert won.derived_facts["duel_won"] is True

    for facts in (
        {"duel_active": True, "duel_rival_down": False, "duel_player_alive": True},
        {"duel_active": True, "duel_rival_down": True, "duel_player_alive": False},
    ):
        result = engine.forward_chain(facts, categories=["duel"])
        assert "duel_won" not in result.derived_facts
