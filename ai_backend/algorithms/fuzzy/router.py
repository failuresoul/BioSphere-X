"""
FastAPI Router for BioSphere-X Adaptive Difficulty Fuzzy Inference System.
Exposes endpoints for evaluating real-time combat states, inspecting rule bases,
and comparing adaptive difficulty with fixed preset profiles.
"""
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from typing import Optional, Dict, Any, List

from .engine import FuzzyInferenceEngine, FIXED_DIFFICULTY_PROFILES

router = APIRouter(prefix="/api/ai/fuzzy", tags=["Fuzzy Adaptive Difficulty"])

# Global singleton engine instance
fuzzy_engine = FuzzyInferenceEngine()


class FuzzyDifficultyRequest(BaseModel):
    player_health: float = Field(default=100.0, ge=0.0, le=100.0, description="Current player health (0-100)")
    recent_damage: float = Field(default=0.0, ge=0.0, le=100.0, description="Recent damage sustained by player (0-100)")
    enemy_distance: float = Field(default=200.0, ge=0.0, le=1000.0, description="Distance from player in pixels (0-1000)")
    repeated_failures: float = Field(default=0.0, ge=0.0, le=20.0, description="Number of player deaths / failed attempts (0-20)")
    fixed_mode: Optional[str] = Field(default=None, description="Optional fixed mode: 'easy', 'normal', 'hard', 'nightmare'")


class FuzzyDifficultyResponse(BaseModel):
    difficulty_score: float
    enemy_aggression: float
    parameters: Dict[str, float]
    mode: str
    description: Optional[str] = ""
    firing_rules: List[Dict[str, Any]]
    fuzzified_inputs: Dict[str, Dict[str, float]]
    defuzzification_method: str = "centroid"
    execution_time_ms: float


@router.get("/profiles")
def get_fixed_profiles():
    """Returns fixed difficulty profiles for comparative benchmarking."""
    return FIXED_DIFFICULTY_PROFILES


@router.get("/rules")
def get_fuzzy_system_metadata():
    """Returns all active linguistic variables, terms, and fuzzy rule descriptions."""
    input_vars = {}
    for var_name, var_obj in fuzzy_engine.inputs.items():
        input_vars[var_name] = {
            "domain": [var_obj.domain_min, var_obj.domain_max],
            "terms": list(var_obj.terms.keys())
        }
        
    output_var = {
        "name": fuzzy_engine.output.name,
        "domain": [fuzzy_engine.output.domain_min, fuzzy_engine.output.domain_max],
        "terms": list(fuzzy_engine.output.terms.keys())
    }

    rules_meta = [rule.to_dict() for rule in fuzzy_engine.rules]

    return {
        "system": "BioSphere-X Mamdani Adaptive Difficulty",
        "inputs": input_vars,
        "output": output_var,
        "rules_count": len(rules_meta),
        "rules": rules_meta
    }


@router.post("/difficulty", response_model=FuzzyDifficultyResponse)
def evaluate_adaptive_difficulty(req: FuzzyDifficultyRequest):
    """
    Receives player combat metrics (health, recent damage, distance, repeated failures) and infers
    a bounded difficulty and enemy aggression value using Mamdani fuzzy logic and centroid defuzzification.
    """
    try:
        res = fuzzy_engine.evaluate(
            player_health=req.player_health,
            recent_damage=req.recent_damage,
            enemy_distance=req.enemy_distance,
            repeated_failures=req.repeated_failures,
            fixed_mode=req.fixed_mode
        )
        return FuzzyDifficultyResponse(**res)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Fuzzy inference failed: {str(e)}")
