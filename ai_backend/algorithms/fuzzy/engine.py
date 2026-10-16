"""
Adaptive Difficulty Fuzzy Inference Engine for BioSphere-X.
Implements Mamdani inference with Centroid Defuzzification to dynamically regulate
enemy aggression and combat difficulty based on player health, recent damage, and spatial distance.
"""
import logging
import time
from typing import Dict, List, Any, Optional, Tuple

from .membership import LinguisticVariable, triangular, trapezoidal
from .rules import FuzzyRule

logger = logging.getLogger("biosphere_fuzzy")
if not logger.handlers:
    handler = logging.StreamHandler()
    formatter = logging.Formatter("[%(asctime)s] [FUZZY-AI] %(levelname)s: %(message)s")
    handler.setFormatter(formatter)
    logger.addHandler(handler)
    logger.setLevel(logging.INFO)


# Fixed baseline profiles for comparative testing
FIXED_DIFFICULTY_PROFILES: Dict[str, Dict[str, Any]] = {
    "easy": {
        "difficulty_score": 0.35,
        "enemy_aggression": 0.35,
        "description": "Lenient parameters for casual play or exploration; lower speeds and generous cooldowns."
    },
    "normal": {
        "difficulty_score": 0.60,
        "enemy_aggression": 0.60,
        "description": "Standard balanced combat experience with standard creature responsiveness."
    },
    "hard": {
        "difficulty_score": 0.85,
        "enemy_aggression": 0.85,
        "description": "Intense encounters for skilled players; aggressive creatures and rapid attacks."
    },
    "nightmare": {
        "difficulty_score": 1.00,
        "enemy_aggression": 1.00,
        "description": "Maximum hostility; creatures move rapidly with minimal delay and maximum vigilance."
    }
}


class FuzzyInferenceEngine:
    def __init__(self, output_bounds: Tuple[float, float] = (0.15, 1.0)):
        self.output_bounds = output_bounds
        self.inputs: Dict[str, LinguisticVariable] = {}
        self.output: Optional[LinguisticVariable] = None
        self.rules: List[FuzzyRule] = []
        
        self._setup_default_system()

    def _setup_default_system(self) -> None:
        """Configures the default linguistic variables, membership functions, and rule base."""
        # 1. Input: Player Health (0 to 100)
        health_var = LinguisticVariable("player_health", (0.0, 100.0))
        health_var.add_term("CRITICAL", lambda x: trapezoidal(x, -10.0, 0.0, 20.0, 40.0))
        health_var.add_term("MODERATE", lambda x: triangular(x, 25.0, 50.0, 75.0))
        health_var.add_term("HEALTHY", lambda x: trapezoidal(x, 60.0, 80.0, 100.0, 110.0))
        self.inputs["player_health"] = health_var

        # 2. Input: Recent Damage Taken (0 to 100)
        damage_var = LinguisticVariable("recent_damage", (0.0, 100.0))
        damage_var.add_term("LOW", lambda x: trapezoidal(x, -10.0, 0.0, 15.0, 30.0))
        damage_var.add_term("MEDIUM", lambda x: triangular(x, 20.0, 45.0, 70.0))
        damage_var.add_term("HIGH", lambda x: trapezoidal(x, 55.0, 75.0, 100.0, 110.0))
        self.inputs["recent_damage"] = damage_var

        # 3. Input: Enemy Distance in pixels (0 to 600)
        dist_var = LinguisticVariable("enemy_distance", (0.0, 600.0))
        dist_var.add_term("CLOSE", lambda x: trapezoidal(x, -10.0, 0.0, 80.0, 160.0))
        dist_var.add_term("MEDIUM", lambda x: triangular(x, 120.0, 250.0, 380.0))
        dist_var.add_term("FAR", lambda x: trapezoidal(x, 320.0, 450.0, 600.0, 650.0))
        self.inputs["enemy_distance"] = dist_var

        # 4. Output: Enemy Aggression (0.1 to 1.0)
        aggression_var = LinguisticVariable("enemy_aggression", (0.1, 1.0))
        aggression_var.add_term("VERY_LOW", lambda x: trapezoidal(x, 0.05, 0.10, 0.20, 0.35))
        aggression_var.add_term("LOW", lambda x: triangular(x, 0.25, 0.40, 0.55))
        aggression_var.add_term("BALANCED", lambda x: triangular(x, 0.45, 0.60, 0.75))
        aggression_var.add_term("HIGH", lambda x: triangular(x, 0.65, 0.78, 0.90))
        aggression_var.add_term("AGGRESSIVE", lambda x: trapezoidal(x, 0.80, 0.90, 1.00, 1.05))
        self.output = aggression_var

        # Default Mamdani Rule Base
        self.rules = [
            # High distress / Critical health relief rules
            FuzzyRule(
                {"player_health": "CRITICAL", "recent_damage": "HIGH"},
                ("enemy_aggression", "VERY_LOW"),
                weight=1.0,
                description="Struggling player under heavy damage receives immediate relief"
            ),
            FuzzyRule(
                {"player_health": "CRITICAL", "enemy_distance": "CLOSE"},
                ("enemy_aggression", "LOW"),
                weight=1.0,
                description="Creatures ease off close-quarters pressure when player is critical"
            ),
            FuzzyRule(
                {"player_health": "CRITICAL", "recent_damage": "MEDIUM"},
                ("enemy_aggression", "LOW"),
                weight=0.9
            ),
            FuzzyRule(
                {"player_health": "CRITICAL", "recent_damage": "LOW"},
                ("enemy_aggression", "BALANCED"),
                weight=0.8
            ),

            # Moderate health dynamic pacing
            FuzzyRule(
                {"player_health": "MODERATE", "recent_damage": "HIGH"},
                ("enemy_aggression", "LOW"),
                weight=1.0,
                description="Moderate health with high incoming damage dials back pressure"
            ),
            FuzzyRule(
                {"player_health": "MODERATE", "recent_damage": "MEDIUM"},
                ("enemy_aggression", "BALANCED"),
                weight=1.0
            ),
            FuzzyRule(
                {"player_health": "MODERATE", "recent_damage": "LOW"},
                ("enemy_aggression", "HIGH"),
                weight=0.9
            ),

            # Healthy player high challenge rules
            FuzzyRule(
                {"player_health": "HEALTHY", "recent_damage": "LOW", "enemy_distance": "CLOSE"},
                ("enemy_aggression", "AGGRESSIVE"),
                weight=1.0,
                description="Healthy unharmed player at close quarters encounters peak aggression"
            ),
            FuzzyRule(
                {"player_health": "HEALTHY", "recent_damage": "LOW", "enemy_distance": "FAR"},
                ("enemy_aggression", "HIGH"),
                weight=0.9,
                description="Creatures actively press toward healthy disengaged players"
            ),
            FuzzyRule(
                {"player_health": "HEALTHY", "recent_damage": "HIGH"},
                ("enemy_aggression", "BALANCED"),
                weight=0.9
            ),

            # Spatial distance fallback rules
            FuzzyRule(
                {"recent_damage": "HIGH"},
                ("enemy_aggression", "LOW"),
                weight=0.7,
                description="High damage taken consistently dampens overall aggression"
            ),
            FuzzyRule(
                {"enemy_distance": "FAR", "recent_damage": "LOW"},
                ("enemy_aggression", "HIGH"),
                weight=0.8
            )
        ]

    def evaluate(
        self,
        player_health: float,
        recent_damage: float,
        enemy_distance: float,
        fixed_mode: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Executes fuzzy inference on crisp input values and returns defuzzified aggression
        and operational gameplay modifiers.
        """
        start_time = time.perf_counter()

        # Handle fixed-difficulty mode comparison if requested
        if fixed_mode and fixed_mode.lower() in FIXED_DIFFICULTY_PROFILES:
            profile = FIXED_DIFFICULTY_PROFILES[fixed_mode.lower()]
            aggression = profile["enemy_aggression"]
            elapsed_ms = (time.perf_counter() - start_time) * 1000.0
            return {
                "difficulty_score": round(aggression, 3),
                "enemy_aggression": round(aggression, 3),
                "parameters": self.calculate_multipliers(aggression),
                "mode": f"fixed_{fixed_mode.lower()}",
                "description": profile["description"],
                "firing_rules": [],
                "fuzzified_inputs": {},
                "execution_time_ms": round(elapsed_ms, 3)
            }

        # 1. Validate & clamp inputs
        clamped_health = max(0.0, min(100.0, float(player_health)))
        clamped_damage = max(0.0, min(100.0, float(recent_damage)))
        clamped_dist = max(0.0, min(600.0, float(enemy_distance)))

        raw_inputs = {
            "player_health": clamped_health,
            "recent_damage": clamped_damage,
            "enemy_distance": clamped_dist
        }

        # 2. Fuzzification
        fuzzified: Dict[str, Dict[str, float]] = {}
        for var_name, var_obj in self.inputs.items():
            fuzzified[var_name] = var_obj.fuzzify(raw_inputs[var_name])

        # 3. Rule Evaluation & Consequent Implication
        active_firing_rules: List[Dict[str, Any]] = []
        # Store maximum firing degree for each consequent term of the output
        consequent_activations: Dict[str, float] = {term: 0.0 for term in self.output.terms.keys()}

        for rule in self.rules:
            strength = rule.evaluate(fuzzified)
            if strength > 0.0:
                out_term = rule.consequent[1]
                consequent_activations[out_term] = max(consequent_activations[out_term], strength)
                active_firing_rules.append({
                    "rule": rule.description,
                    "strength": round(strength, 3),
                    "target_term": out_term
                })

        # 4. Defuzzification (Centroid Method / Center of Gravity)
        crisp_aggression = self._defuzzify_centroid(consequent_activations)
        
        # 5. Strict bounding guarantee
        bounded_aggression = max(self.output_bounds[0], min(self.output_bounds[1], crisp_aggression))
        elapsed_ms = (time.perf_counter() - start_time) * 1000.0

        logger.info(
            f"Fuzzy Evaluated: HP={clamped_health:.1f}, Dmg={clamped_damage:.1f}, Dist={clamped_dist:.1f} "
            f"-> Aggression={bounded_aggression:.3f} ({len(active_firing_rules)} rules fired in {elapsed_ms:.2f}ms)"
        )

        return {
            "difficulty_score": round(bounded_aggression, 3),
            "enemy_aggression": round(bounded_aggression, 3),
            "parameters": self.calculate_multipliers(bounded_aggression),
            "mode": "adaptive",
            "firing_rules": active_firing_rules,
            "fuzzified_inputs": fuzzified,
            "defuzzification_method": "centroid",
            "execution_time_ms": round(elapsed_ms, 3)
        }

    def _defuzzify_centroid(self, activations: Dict[str, float], num_samples: int = 150) -> float:
        """
        Calculates the Center of Gravity (Centroid) across the aggregated fuzzy output set.
        z* = sum(z * mu(z)) / sum(mu(z))
        """
        z_min = self.output.domain_min
        z_max = self.output.domain_max
        step = (z_max - z_min) / float(num_samples)

        numerator = 0.0
        denominator = 0.0

        for i in range(num_samples + 1):
            z = z_min + i * step
            # Aggregation: max over clipped consequent membership functions
            mu_z = 0.0
            for term_name, act_degree in activations.items():
                if act_degree > 0.0:
                    term_mf = self.output.terms[term_name]
                    # Mamdani min implication
                    clipped = min(act_degree, term_mf(z))
                    mu_z = max(mu_z, clipped)

            numerator += z * mu_z
            denominator += mu_z

        if denominator <= 1e-6:
            # Fallback to neutral midpoint if no rules fired
            return 0.55

        return numerator / denominator

    @staticmethod
    def calculate_multipliers(aggression: float) -> Dict[str, float]:
        """
        Translates a normalized aggression scalar [0.1, 1.0] into bounded gameplay multipliers
        for movement speed, attack damage, attack cooldown, and detection range.
        """
        agg = max(0.1, min(1.0, float(aggression)))
        
        # 1. Movement Speed Multiplier: 0.80x to 1.25x
        speed_mult = 0.75 + (0.50 * agg)

        # 2. Attack Damage Multiplier: 0.75x to 1.25x
        damage_mult = 0.70 + (0.55 * agg)

        # 3. Attack Cooldown Multiplier: Higher aggression = faster attacks (0.75x to 1.35x cooldown)
        cooldown_mult = 1.40 - (0.65 * agg)

        # 4. Detection Range Multiplier: 0.85x to 1.20x
        detection_mult = 0.80 + (0.40 * agg)

        return {
            "speed_multiplier": round(speed_mult, 3),
            "attack_damage_multiplier": round(damage_mult, 3),
            "attack_cooldown_multiplier": round(cooldown_mult, 3),
            "detection_range_multiplier": round(detection_mult, 3)
        }
