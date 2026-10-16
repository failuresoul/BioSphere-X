"""
Modular Rule-Based Inference Engine for BioSphere-X.
Supports explicit facts, IF-THEN rules with diverse operators, forward chaining inference,
priority-based conflict resolution, contradiction detection, and full explanation trees.
"""
from typing import Any, Dict, List, Optional, Set, Union
from pydantic import BaseModel, Field
import copy


class Condition(BaseModel):
    """
    Antecedent condition for an IF-THEN rule.
    Evaluates a specific fact field using standard or membership comparison operators.
    """
    field: str
    operator: str = "=="  # "==", "!=", "<", "<=", ">", ">=", "in", "not_in", "exists", "not_exists"
    value: Any = None
    default_if_missing: Optional[Any] = None

    def evaluate(self, facts: Dict[str, Any]) -> tuple[bool, str]:
        """
        Evaluates condition against working memory facts.
        Returns (satisfied: bool, diagnostic: str).
        Handles missing facts gracefully without raising exceptions.
        """
        exists = self.field in facts
        
        if self.operator == "exists":
            return (exists, f"Field '{self.field}' exists: {exists}")
        if self.operator == "not_exists":
            return (not exists, f"Field '{self.field}' absent: {not exists}")
            
        if not exists:
            if self.default_if_missing is not None:
                actual = self.default_if_missing
            elif self.operator in ("!=", "neq"):
                actual = None
            else:
                return (False, f"Missing required fact: '{self.field}'")
        else:
            actual = facts[self.field]
        expected = self.value
        
        try:
            if self.operator in ("==", "eq"):
                sat = (actual == expected)
            elif self.operator in ("!=", "neq"):
                sat = (actual != expected)
            elif self.operator in ("<", "lt"):
                sat = (float(actual) < float(expected))
            elif self.operator in ("<=", "lte"):
                sat = (float(actual) <= float(expected))
            elif self.operator in (">", "gt"):
                sat = (float(actual) > float(expected))
            elif self.operator in (">=", "gte"):
                sat = (float(actual) >= float(expected))
            elif self.operator == "in":
                if isinstance(expected, (list, tuple, set, dict, str)):
                    sat = (actual in expected)
                else:
                    sat = False
            elif self.operator == "not_in":
                if isinstance(expected, (list, tuple, set, dict, str)):
                    sat = (actual not in expected)
                else:
                    sat = True
            else:
                return (False, f"Unsupported operator: '{self.operator}'")
                
            diag = f"{self.field} ({actual}) {self.operator} {expected} -> {sat}"
            return (sat, diag)
        except (ValueError, TypeError) as e:
            return (False, f"Evaluation error on '{self.field}': {str(e)}")


class Rule(BaseModel):
    """
    IF-THEN production rule with salience/priority, explanations, and optional contradiction resolution.
    """
    id: str
    name: str
    description: str = ""
    category: str = "general"
    priority: int = 100  # Higher value = higher priority / fired earlier
    conditions: List[Condition] = Field(default_factory=list)
    conclusions: Dict[str, Any] = Field(default_factory=dict)
    actions: List[str] = Field(default_factory=list)
    explanation_template: str = ""
    overrides: List[str] = Field(default_factory=list)  # Facts or rule IDs that this rule explicitly invalidates

    def evaluate_antecedents(self, facts: Dict[str, Any]) -> tuple[bool, List[str]]:
        """
        Verifies if all conditions are satisfied by current facts.
        Returns (all_satisfied: bool, condition_diagnostics: List[str]).
        """
        diagnostics = []
        for cond in self.conditions:
            satisfied, diag = cond.evaluate(facts)
            diagnostics.append(diag)
            if not satisfied:
                return (False, diagnostics)
        return (True, diagnostics)

    def generate_explanation(self, facts: Dict[str, Any]) -> str:
        """
        Generates readable justification string for why this rule fired.
        """
        if self.explanation_template:
            try:
                return self.explanation_template.format(**facts)
            except Exception:
                pass
        return f"Rule '{self.name}' [{self.id}] fired based on matching facts."


class InferenceResult(BaseModel):
    """
    Comprehensive output of a forward chaining inference cycle.
    """
    initial_facts: Dict[str, Any]
    derived_facts: Dict[str, Any]
    all_facts: Dict[str, Any]
    applicable_actions: List[str]
    fired_rules: List[str]
    explanations: Dict[str, Any]
    contradictions_detected: List[Dict[str, Any]]
    iterations: int


class RuleInferenceEngine:
    """
    Forward-chaining production rule inference engine.
    Supports dependency chaining, missing fact tolerance, contradiction flagging,
    and explanation tree generation.
    """

    def __init__(self):
        self._rules: Dict[str, Rule] = {}
        self._register_default_biosphere_rules()

    def register_rule(self, rule: Rule) -> None:
        """Adds or updates a rule in the engine's rule base."""
        self._rules[rule.id] = rule

    def remove_rule(self, rule_id: str) -> bool:
        """Removes a rule by ID."""
        if rule_id in self._rules:
            del self._rules[rule_id]
            return True
        return False

    def get_rule(self, rule_id: str) -> Optional[Rule]:
        """Retrieves a rule by ID."""
        return self._rules.get(rule_id)

    def get_all_rules(self, category: Optional[str] = None) -> List[Rule]:
        """Returns all registered rules, optionally filtered by category."""
        if category:
            return [r for r in self._rules.values() if r.category == category]
        return list(self._rules.values())

    def forward_chain(
        self,
        initial_facts: Dict[str, Any],
        categories: Optional[List[str]] = None,
        max_iterations: int = 50
    ) -> InferenceResult:
        """
        Executes forward chaining inference starting from initial facts until fixpoint.
        Derives new conclusions, accumulates applicable actions, detects contradictory conditions,
        and builds a complete explanation trace.
        """
        working_memory: Dict[str, Any] = copy.deepcopy(initial_facts)
        derived_facts: Dict[str, Any] = {}
        applicable_actions: List[str] = []
        fired_rules: List[str] = []
        explanations: Dict[str, Any] = {}
        contradictions_detected: List[Dict[str, Any]] = []
        fact_priorities: Dict[str, int] = {k: 0 for k in working_memory.keys()}

        # Filter candidate rules by categories if specified
        active_rules = [
            r for r in self._rules.values()
            if categories is None or r.category in categories
        ]
        # Sort rules by priority descending (salience)
        active_rules.sort(key=lambda r: r.priority, reverse=True)

        fired_rule_ids: Set[str] = set()
        iterations = 0

        while iterations < max_iterations:
            iterations += 1
            rule_fired_this_round = False

            for rule in active_rules:
                if rule.id in fired_rule_ids:
                    continue  # Refraction: fire each rule instance at most once per execution

                satisfied, diagnostics = rule.evaluate_antecedents(working_memory)
                if not satisfied:
                    continue

                # Rule conditions met! Fire rule:
                fired_rule_ids.add(rule.id)
                fired_rules.append(rule.id)
                rule_fired_this_round = True
                explanation_str = rule.generate_explanation(working_memory)

                # Process overridden facts
                for ov in rule.overrides:
                    if ov in working_memory and ov not in rule.conclusions:
                        old_val = working_memory.pop(ov)
                        contradictions_detected.append({
                            "type": "override",
                            "rule_id": rule.id,
                            "field": ov,
                            "removed_value": old_val,
                            "reason": f"Rule '{rule.name}' priority override eliminated fact '{ov}'."
                        })

                # Assert conclusions (derived facts)
                for key, val in rule.conclusions.items():
                    if key in working_memory:
                        existing_val = working_memory[key]
                        if existing_val != val:
                            existing_priority = fact_priorities.get(key, 0)
                            if rule.priority >= existing_priority:
                                contradictions_detected.append({
                                    "type": "contradiction_resolved",
                                    "rule_id": rule.id,
                                    "field": key,
                                    "prior_value": existing_val,
                                    "new_value": val,
                                    "reason": f"Contradiction resolved by priority {rule.priority} >= {existing_priority}."
                                })
                                working_memory[key] = val
                                derived_facts[key] = val
                                fact_priorities[key] = rule.priority
                            else:
                                contradictions_detected.append({
                                    "type": "contradiction_ignored",
                                    "rule_id": rule.id,
                                    "field": key,
                                    "attempted_value": val,
                                    "retained_value": existing_val,
                                    "reason": f"Attempted update ignored: priority {rule.priority} < {existing_priority}."
                                })
                                continue
                    else:
                        working_memory[key] = val
                        derived_facts[key] = val
                        fact_priorities[key] = rule.priority

                    # Register explanation trace for derived fact
                    explanations[key] = {
                        "rule_id": rule.id,
                        "rule_name": rule.name,
                        "category": rule.category,
                        "explanation": explanation_str,
                        "antecedents_matched": diagnostics,
                        "priority": rule.priority
                    }

                # Assert actions
                for action in rule.actions:
                    if action not in applicable_actions:
                        applicable_actions.append(action)
                        explanations[f"action::{action}"] = {
                            "rule_id": rule.id,
                            "rule_name": rule.name,
                            "explanation": explanation_str
                        }

                # Restart loop across rules with updated working memory (forward chaining)
                break

            if not rule_fired_this_round:
                # Fixpoint reached: no more rules can fire
                break

        return InferenceResult(
            initial_facts=initial_facts,
            derived_facts=derived_facts,
            all_facts=working_memory,
            applicable_actions=applicable_actions,
            fired_rules=fired_rules,
            explanations=explanations,
            contradictions_detected=contradictions_detected,
            iterations=iterations
        )

    def explain(self, target_fact_or_action: str, result: InferenceResult) -> Dict[str, Any]:
        """
        Returns full explanation tree and reasoning chain for a specific derived fact or action.
        """
        if target_fact_or_action in result.explanations:
            return {
                "target": target_fact_or_action,
                "found": True,
                "trace": result.explanations[target_fact_or_action]
            }
        
        act_key = f"action::{target_fact_or_action}"
        if act_key in result.explanations:
            return {
                "target": target_fact_or_action,
                "found": True,
                "trace": result.explanations[act_key]
            }

        return {
            "target": target_fact_or_action,
            "found": False,
            "trace": "Target fact or action was not derived in the inference cycle."
        }

    # -----------------------------------------------------------------------
    # Built-In Domain Rules for BioSphere-X
    # -----------------------------------------------------------------------
    def _register_default_biosphere_rules(self) -> None:
        """
        Initializes domain rules for mission prerequisites, life-support warnings,
        extraction eligibility, and environmental survival conditions.
        """
        # ===================================================================
        # 1. LIFE SUPPORT & OXYGEN RULES
        # ===================================================================
        self.register_rule(Rule(
            id="rule_safe_zone_sanctuary",
            name="Atmospheric Safe Zone Sanctuary",
            description="Inside the research base dome, oxygen replenishment is active and hazard warnings are suppressed.",
            category="life_support",
            priority=200,  # Highest priority override
            conditions=[
                Condition(field="in_safe_zone", operator="==", value=True)
            ],
            conclusions={
                "atmospheric_sanctuary": True,
                "low_oxygen_warning": False,
                "critical_hypoxia": False,
                "suffocation_active": False
            },
            actions=["refill_life_support"],
            explanation_template="Astronaut is inside the secure atmospheric habitat dome. Life-support replenishment active.",
            overrides=["low_oxygen_warning", "critical_hypoxia", "suffocation_active"]
        ))

        self.register_rule(Rule(
            id="rule_oxygen_zero_suffocation",
            name="Life Support Complete Depletion",
            description="When oxygen level reaches 0%, emergency suffocation damage is triggered.",
            category="life_support",
            priority=150,
            conditions=[
                Condition(field="oxygen_level", operator="<=", value=0.0),
                Condition(field="in_safe_zone", operator="!=", value=True)
            ],
            conclusions={
                "suffocation_active": True,
                "low_oxygen_warning": True,
                "critical_hypoxia": True
            },
            actions=["apply_suffocation_damage", "alarm_critical_breach"],
            explanation_template="Oxygen reserves depleted to {oxygen_level:.1f}%. Immediate suffocation damage active."
        ))

        self.register_rule(Rule(
            id="rule_oxygen_critical_hypoxia",
            name="Critical Hypoxia Threshold",
            description="When oxygen is below 10%, triggers high-priority visual HUD pulse and audio alarm.",
            category="life_support",
            priority=120,
            conditions=[
                Condition(field="oxygen_level", operator="<", value=10.0),
                Condition(field="oxygen_level", operator=">", value=0.0),
                Condition(field="in_safe_zone", operator="!=", value=True)
            ],
            conclusions={
                "critical_hypoxia": True,
                "low_oxygen_warning": True
            },
            actions=["trigger_critical_audio_alarm", "flash_oxygen_hud"],
            explanation_template="Suit oxygen reserves critical at {oxygen_level:.1f}% (< 10%). Audio/visual hypoxia alarm triggered."
        ))

        self.register_rule(Rule(
            id="rule_oxygen_low_warning",
            name="Low Oxygen Caution Warning",
            description="When oxygen drops below 25%, triggers the HUD caution indicator.",
            category="life_support",
            priority=100,
            conditions=[
                Condition(field="oxygen_level", operator="<", value=25.0),
                Condition(field="oxygen_level", operator=">=", value=10.0),
                Condition(field="in_safe_zone", operator="!=", value=True)
            ],
            conclusions={
                "low_oxygen_warning": True
            },
            actions=["flash_oxygen_hud", "show_low_oxygen_warning"],
            explanation_template="Suit oxygen level is low at {oxygen_level:.1f}% (< 25%). Caution pulse displayed."
        ))

        # ===================================================================
        # 2. MISSION PREREQUISITES & PROGRESSION RULES
        # ===================================================================
        self.register_rule(Rule(
            id="rule_mission_01_oxygen_unlocks_lhs",
            name="Life Support Recovery Authorizes Hyperspace",
            description="Completing Mission 1 unlocks LHS 1140 b and unlocks Mission 2.",
            category="missions",
            priority=110,
            conditions=[
                Condition(field="mission_01_oxygen_completed", operator="==", value=True)
            ],
            conclusions={
                "lhs_1140_b_unlocked": True,
                "mission_02_eligible": True
            },
            actions=["notify_hyperspace_vector_unlocked"],
            explanation_template="Mission 1 (Life Support Recovery) accomplished. Sector vector to LHS 1140 b authorized."
        ))

        self.register_rule(Rule(
            id="rule_specimens_and_terminal_boss_ready",
            name="Field Intelligence Authorizes Apex Protocol",
            description="Harvesting required biomass specimens and scanning outpost terminal authorizes boss protocol.",
            category="missions",
            priority=105,
            conditions=[
                Condition(field="biomass_samples_collected", operator=">=", value=3),
                Condition(field="terminal_scanned", operator="==", value=True)
            ],
            conclusions={
                "boss_protocol_authorized": True,
                "mission_05_eligible": True
            },
            actions=["enable_boss_crater_waypoint"],
            explanation_template="Gathered {biomass_samples_collected} samples and scanned research terminal. Apex boss tracking active."
        ))

        self.register_rule(Rule(
            id="rule_boss_defeated_secures_surface",
            name="Apex Predator Neutralization Secures Perimeter",
            description="Defeating Goliath Prime neutralizes the surface threat and validates extraction criteria.",
            category="missions",
            priority=100,
            conditions=[
                Condition(field="boss_defeated", operator="==", value=True)
            ],
            conclusions={
                "surface_threat_neutralized": True,
                "boss_mission_completed": True
            },
            actions=["notify_perimeter_secured"],
            explanation_template="Apex threat Goliath Prime neutralized. Surface sector perimeter secured."
        ))

        self.register_rule(Rule(
            id="rule_sample_count_unlocks_extraction",
            name="Sample Count Unlocks Extraction Objective",
            description="When required scientific sample quota is collected, unlocks extraction objective.",
            category="missions",
            priority=115,
            conditions=[
                Condition(field="sample_count", operator=">=", value=3)
            ],
            conclusions={
                "extraction_objective_unlocked": True
            },
            actions=["unlock_extraction_objective", "notify_extraction_unlocked"],
            explanation_template="Required sample quota fulfilled ({sample_count} >= 3). Extraction objective unlocked."
        ))

        self.register_rule(Rule(
            id="rule_boss_and_item_enables_return_terminal",
            name="Apex Neutralization and Mission Artifact Enables Return Terminal",
            description="When boss is defeated and mission item is collected, enables the base return terminal.",
            category="extraction",
            priority=130,
            conditions=[
                Condition(field="boss_defeated", operator="==", value=True),
                Condition(field="mission_item_collected", operator="==", value=True)
            ],
            conclusions={
                "return_terminal_enabled": True
            },
            actions=["enable_return_terminal", "illuminate_return_beacon"],
            explanation_template="Apex boss defeated and mission artifact recovered. Base return terminal enabled."
        ))

        # ===================================================================
        # 3. EXTRACTION ELIGIBILITY RULES
        # ===================================================================
        self.register_rule(Rule(
            id="rule_combat_lockdown_blocks_extraction",
            name="Hostile Pursuit Airlock Lockdown",
            description="Active combat alert prevents opening the extraction portal.",
            category="extraction",
            priority=160,
            conditions=[
                Condition(field="combat_threat_active", operator="==", value=True),
                Condition(field="in_safe_zone", operator="!=", value=True)
            ],
            conclusions={
                "extraction_blocked": True,
                "extraction_eligible": False,
                "return_terminal_enabled": False
            },
            actions=["warn_combat_lockdown"],
            explanation_template="Alien hostiles in aggressive pursuit. Airlock security lockdown active.",
            overrides=["extraction_eligible", "return_terminal_enabled"]
        ))

        self.register_rule(Rule(
            id="rule_extraction_criteria_satisfied",
            name="Expedition Extraction Authorization",
            description="When required missions are complete, samples are carried, and player reaches base portal, extraction unlocks.",
            category="extraction",
            priority=120,
            conditions=[
                Condition(field="primary_missions_completed", operator="==", value=True),
                Condition(field="samples_carried", operator=">=", value=1),
                Condition(field="near_airlock", operator="==", value=True),
                Condition(field="extraction_blocked", operator="!=", value=True)
            ],
            conclusions={
                "extraction_eligible": True
            },
            actions=["unlock_airlock_exit", "prompt_extraction_complete"],
            explanation_template="Expedition telemetry verified. {samples_carried} samples in suit cargo at habitat airlock portal."
        ))

        # ===================================================================
        # 4. ENVIRONMENTAL & PLANETARY RULES
        # ===================================================================
        self.register_rule(Rule(
            id="rule_lhs_1140_b_super_earth_gravity",
            name="Super-Earth Heavy Gravity Atmosphere",
            description="High surface gravity increases oxygen and stamina consumption rates on LHS 1140 b.",
            category="environmental",
            priority=90,
            conditions=[
                Condition(field="planet_id", operator="==", value="lhs_1140_b")
            ],
            conclusions={
                "heavy_gravity_active": True,
                "oxygen_drain_rate": 2.2,
                "stamina_penalty": 1.4
            },
            actions=["apply_heavy_gravity_hud_badge"],
            explanation_template="Deployed on LHS 1140 b (Super-Earth). Heavy gravity atmosphere (O2 drain: 2.2/s, Stamina: 1.4x)."
        ))

        self.register_rule(Rule(
            id="rule_cryo_thermal_drain",
            name="Sub-Zero Thermal Cryo Drain",
            description="Cryogenic blackbody temperature triggers suit heating consumption.",
            category="environmental",
            priority=85,
            conditions=[
                Condition(field="ambient_temperature_k", operator="<", value=200.0),
                Condition(field="in_safe_zone", operator="!=", value=True)
            ],
            conclusions={
                "cryo_hazard_active": True,
                "suit_thermal_drain": 1.3
            },
            actions=["activate_suit_heating_circuit"],
            explanation_template="Cryogenic ambient temperature ({ambient_temperature_k:.0f} K < 200 K). Suit thermal drain elevated."
        ))
