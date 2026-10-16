"""
FastAPI Router for BioSphere-X Rule-Based Inference Engine.
Exposes endpoints for forward-chaining rule evaluation, action recommendation,
explanation tree queries, and dynamic rule registration.
"""
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from typing import Any, Dict, List, Optional

from .engine import RuleInferenceEngine, Rule, Condition, InferenceResult

router = APIRouter(prefix="/api/ai/logic", tags=["Rule-Based Inference Engine"])

# Global singleton engine instance
inference_engine = RuleInferenceEngine()


class InferRequest(BaseModel):
    facts: Dict[str, Any] = Field(default_factory=dict, description="Current observable gameplay facts")
    categories: Optional[List[str]] = Field(default=None, description="Optional rule categories filter")
    max_iterations: int = Field(default=50, description="Maximum forward chaining iterations")


class InferResponse(BaseModel):
    status: str = "success"
    derived_facts: Dict[str, Any] = Field(default_factory=dict)
    all_facts: Dict[str, Any] = Field(default_factory=dict)
    applicable_actions: List[str] = Field(default_factory=list)
    fired_rules: List[str] = Field(default_factory=list)
    explanations: Dict[str, Any] = Field(default_factory=dict)
    contradictions_detected: List[Dict[str, Any]] = Field(default_factory=list)
    iterations: int = 0


class RuleCatalogResponse(BaseModel):
    status: str = "success"
    rules: List[Rule] = Field(default_factory=list)
    count: int = 0


class ExplainRequest(BaseModel):
    target: str = Field(description="Target fact key or action to explain")
    facts: Dict[str, Any] = Field(default_factory=dict)


class ExplainResponse(BaseModel):
    status: str = "success"
    target: str
    found: bool
    trace: Any


@router.post("/infer", response_model=InferResponse)
def execute_inference(req: InferRequest) -> InferResponse:
    """
    Executes forward-chaining inference over the supplied facts.
    Returns:
      - derived_facts: Newly deduced state flags and values.
      - applicable_actions: Recommended gameplay actions (HUD alarms, audio triggers, extraction gates).
      - fired_rules: Sequence of fired production rules.
      - explanations: Human-readable justifications for all conclusions.
      - contradictions_detected: Resolved or flagged conflicting state facts.
    """
    try:
        res: InferenceResult = inference_engine.forward_chain(
            initial_facts=req.facts,
            categories=req.categories,
            max_iterations=req.max_iterations
        )
        return InferResponse(
            status="success",
            derived_facts=res.derived_facts,
            all_facts=res.all_facts,
            applicable_actions=res.applicable_actions,
            fired_rules=res.fired_rules,
            explanations=res.explanations,
            contradictions_detected=res.contradictions_detected,
            iterations=res.iterations
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Inference execution failed: {str(e)}")


@router.get("/rules", response_model=RuleCatalogResponse)
def get_rule_catalog(category: Optional[str] = None) -> RuleCatalogResponse:
    """
    Returns all registered production rules, categories, conditions, and actions.
    """
    rules = inference_engine.get_all_rules(category=category)
    return RuleCatalogResponse(
        status="success",
        rules=rules,
        count=len(rules)
    )


@router.post("/explain", response_model=ExplainResponse)
def explain_conclusion(req: ExplainRequest) -> ExplainResponse:
    """
    Explains the causal derivation chain for a specific derived fact or action.
    """
    try:
        res: InferenceResult = inference_engine.forward_chain(initial_facts=req.facts)
        exp = inference_engine.explain(req.target, res)
        return ExplainResponse(
            status="success",
            target=exp["target"],
            found=exp["found"],
            trace=exp["trace"]
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Explanation query failed: {str(e)}")


@router.post("/register-rule")
def register_rule(rule: Rule) -> Dict[str, Any]:
    """
    Dynamically registers a custom rule into the active knowledge base.
    """
    inference_engine.register_rule(rule)
    return {
        "status": "success",
        "message": f"Rule '{rule.name}' [{rule.id}] successfully registered.",
        "rule_id": rule.id
    }
