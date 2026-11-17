"""
Forward chaining: start from known facts, fire every IF-THEN rule whose
conditions are true, add its conclusion as a new fact, and repeat until no
rule adds anything new.

Facts example: {"boss_hp": 0, "player_hp": 40, "oxygen": 15}
"""
import operator

OPS = {"<=": operator.le, "<": operator.lt, ">": operator.gt, ">=": operator.ge, "==": operator.eq}

# (rule name, IF conditions [(fact, operator, value), ...], THEN new fact)
RULES = [
    ("victory", [("boss_hp", "<=", 0), ("player_hp", ">", 0)], "duel_won"),
    ("unlock", [("duel_won", "==", True)], "unlock_next_planet"),
    ("defeat", [("player_hp", "<=", 0)], "duel_lost"),
    ("low_health", [("player_hp", ">", 0), ("player_hp", "<", 30)], "low_health_warning"),
    ("low_oxygen", [("oxygen", "<", 20)], "oxygen_warning"),
]


def forward_chain(facts: dict) -> dict:
    known = dict(facts)
    fired = []                                   # the order in which rules fired
    changed = True
    while changed:                               # repeat until nothing new is added
        changed = False
        for name, conditions, conclusion in RULES:
            if known.get(conclusion) is True:
                continue                         # already known
            if all(fact in known and OPS[op](known[fact], value) for fact, op, value in conditions):
                known[conclusion] = True         # new fact
                fired.append(name)
                changed = True
    new_facts = {k: v for k, v in known.items() if k not in facts}
    return {"new_facts": new_facts, "fired_rules": fired, "facts": known}
