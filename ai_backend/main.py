"""
BioSphere-X AI backend (FastAPI).

Godot sends the current game situation here and gets back an AI answer:
  POST /api/ai/decision  -> Minimax or MCTS picks a combat action
  POST /api/ai/fuzzy     -> fuzzy logic picks the boss aggression
  POST /api/ai/csp       -> CSP places health / energy pickups
  POST /api/ai/rules     -> forward chaining derives facts (e.g. duel_won)
Search algorithms (DFS, A*, ...) run inside Godot: scripts/utils/modular_pathfinder.gd
"""
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional

from fastapi import FastAPI
from pydantic import BaseModel, Field

sys.path.insert(0, str(Path(__file__).resolve().parent))   # so "algorithms" can be imported

from algorithms.adversarial import CombatState, mcts_decision, minimax_decision  # noqa: E402
from algorithms.csp import place_pickups  # noqa: E402
from algorithms.fuzzy import fuzzy_aggression  # noqa: E402
from algorithms.rules import forward_chain  # noqa: E402

app = FastAPI(title="BioSphere-X AI Backend")


class StateIn(BaseModel):
    my_hp: float = 100.0
    enemy_hp: float = 100.0
    distance: float = 300.0
    my_energy: float = 50.0
    enemy_energy: float = 50.0
    my_cooldown: int = 0
    enemy_cooldown: int = 0


class DecisionIn(BaseModel):
    state: StateIn
    algorithm: str = "minimax"            # "minimax" or "mcts"
    depth: int = Field(default=3, ge=1, le=5)
    simulations: int = Field(default=200, ge=10, le=2000)
    alpha_beta: bool = False


class FuzzyIn(BaseModel):
    player_health: float = 100.0          # percent
    distance: float = 300.0               # pixels


class CspIn(BaseModel):
    candidates: List[List[int]]           # free floor tiles [x, y]
    walls: List[List[int]] = []
    enemy: List[int]
    items: List[str] = ["health", "energy", "health"]
    min_enemy_distance: int = 5
    min_spacing: int = 4
    seed: Optional[int] = None


class RulesIn(BaseModel):
    facts: Dict[str, Any]


@app.get("/health")
def health():
    return {"status": "ok", "service": "BioSphere-X AI Backend"}


@app.post("/api/ai/decision")
def decision(req: DecisionIn):
    state = CombatState(**req.state.model_dump())
    if req.algorithm.lower() == "mcts":
        result = mcts_decision(state, simulations=req.simulations)
    else:
        result = minimax_decision(state, depth=req.depth, use_alpha_beta=req.alpha_beta)
    return {"algorithm": req.algorithm.lower(), **result}


@app.post("/api/ai/fuzzy")
def fuzzy(req: FuzzyIn):
    return fuzzy_aggression(req.player_health, req.distance)


@app.post("/api/ai/csp")
def csp(req: CspIn):
    return place_pickups(req.candidates, req.walls, req.enemy, req.items,
                         req.min_enemy_distance, req.min_spacing, req.seed)


@app.post("/api/ai/rules")
def rules(req: RulesIn):
    return forward_chain(req.facts)


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8000)
