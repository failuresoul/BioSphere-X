"""
Forward chaining over a few IF-THEN rules.

Facts are a dictionary such as {"boss_hp": 0, "player_hp": 40, "planet": 2}.
Each loop fires every rule whose conditions are all true and adds its
conclusion as a new fact, until nothing new can be derived.
"""
import operator

OPS = {"<=": operator.le, "<": operator.lt, ">": operator.gt, ">=": operator.ge, "==": operator.eq}

# (rule name, list of (fact, operator, value), new fact)
RULES = [
    ("victory", [("boss_hp", "<=", 0), ("player_hp", ">", 0)], "duel_won"),
    ("defeat", [("player_hp", "<=", 0)], "duel_lost"),
    ("unlock", [("duel_won", "==", True), ("planet", "<", 9)], "unlock_next_planet"),
    ("final", [("duel_won", "==", True), ("planet", ">=", 9)], "campaign_complete"),
    ("danger", [("player_hp", ">", 0), ("player_hp", "<", 30)], "low_health_warning"),
]


def forward_chain(facts: dict) -> dict:
    known = dict(facts)
    fired = []
    changed = True
    while changed:                       # repeat until no rule adds a new fact
        changed = False
        for name, conditions, conclusion in RULES:
            if known.get(conclusion) is True:
                continue                 # already derived
            if all(fact in known and OPS[op](known[fact], value) for fact, op, value in conditions):
                known[conclusion] = True
                fired.append(name)
                changed = True
    derived = {k: v for k, v in known.items() if k not in facts}
    return {"facts": known, "derived": derived, "fired_rules": fired}
