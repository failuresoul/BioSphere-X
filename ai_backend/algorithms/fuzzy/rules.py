"""
Fuzzy Rule Definitions and Evaluation for BioSphere-X.
Implements Mamdani fuzzy IF-THEN rules with conjunction (t-norm) and rule weighting.
"""
from typing import Dict, Tuple, Any


class FuzzyRule:
    """
    Represents a Mamdani fuzzy rule of the form:
    IF (var1 is term1) AND (var2 is term2) ... THEN (out_var is out_term) [weight]
    """
    def __init__(
        self,
        antecedents: Dict[str, str],
        consequent: Tuple[str, str],
        weight: float = 1.0,
        description: str = ""
    ):
        self.antecedents = antecedents  # { "player_health": "CRITICAL", "recent_damage": "HIGH" }
        self.consequent = consequent    # ("enemy_aggression", "VERY_LOW")
        self.weight = max(0.0, min(1.0, float(weight)))
        self.description = description or self._generate_description()

    def evaluate(self, fuzzified_inputs: Dict[str, Dict[str, float]]) -> float:
        """
        Evaluates the firing strength of this rule using the min t-norm (fuzzy AND)
        and applies the rule weight.
        """
        if not self.antecedents:
            return 0.0

        strengths = []
        for var_name, term_name in self.antecedents.items():
            var_memberships = fuzzified_inputs.get(var_name, {})
            degree = var_memberships.get(term_name, 0.0)
            strengths.append(degree)

        firing_strength = min(strengths) if strengths else 0.0
        return max(0.0, min(1.0, firing_strength * self.weight))

    def _generate_description(self) -> str:
        ante_str = " AND ".join([f"{k} IS {v}" for k, v in self.antecedents.items()])
        cons_str = f"{self.consequent[0]} IS {self.consequent[1]}"
        return f"IF {ante_str} THEN {cons_str}"

    def to_dict(self) -> Dict[str, Any]:
        return {
            "antecedents": self.antecedents,
            "consequent": {
                "variable": self.consequent[0],
                "term": self.consequent[1]
            },
            "weight": self.weight,
            "description": self.description
        }
