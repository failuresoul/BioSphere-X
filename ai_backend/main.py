"""
BioSphere-X AI backend (FastAPI).

Godot sends the current game situation here and gets back an AI answer:
  POST /pathfinding/find   -> BFS, DFS, DLS, IDDFS, Bidirectional, Greedy or A* path
  POST /adversarial/decide -> Minimax (+ alpha-beta) or MCTS picks the boss's move
  POST /fuzzy/aggression   -> fuzzy logic: how aggressive the boss should be (0-1)
  POST /logic/infer        -> forward chaining: new facts (duel_won, oxygen_warning, ...)
  POST /csp/place          -> CSP: where to put oxygen tanks, the safe dome and pickups
If this server is off or slow, Godot uses simple fallbacks so the game never freezes.
"""
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

sys.path.insert(0, str(Path(__file__).resolve().parent))   # so "algorithms" can be imported

from algorithms.adversarial import CombatState, mcts_decision, minimax_decision  # noqa: E402
from algorithms.csp import place_items  # noqa: E402
from algorithms.fuzzy import fuzzy_aggression  # noqa: E402
from algorithms.logic import forward_chain  # noqa: E402
from algorithms.pathfinding import ALGORITHMS, find_path  # noqa: E402

app = FastAPI(title="BioSphere-X AI Backend")


class PathIn(BaseModel):
    algorithm: str = "astar"              # bfs, dfs, dls, iddfs, bidirectional, greedy, astar
    grid: List[List[int]]                 # grid[y][x]: 0 = walkable, 1 = wall
    start: List[int]                      # [x, y]
    goal: List[int]                       # [x, y]


class StateIn(BaseModel):
    boss_hp: float = 100.0                # percent
    player_hp: float = 100.0              # percent
    distance: float = 300.0               # pixels
    boss_energy: float = 50.0
    player_energy: float = 50.0
    boss_cooldown: int = 0                # turns until "special" is ready
    player_cooldown: int = 0


class DecideIn(BaseModel):
    algorithm: str = "minimax"            # "minimax" or "mcts"
    use_alpha_beta: bool = True           # only used by minimax
    state: StateIn


class FuzzyIn(BaseModel):
    player_health: float = 100.0          # percent
    recent_damage: float = 0.0            # damage the player took in the last few seconds
    distance: float = 300.0               # pixels


class LogicIn(BaseModel):
    facts: Dict[str, Any]                 # e.g. {"boss_hp": 0, "player_hp": 40, "oxygen": 15}


class CspIn(BaseModel):
    candidates: List[List[int]]           # walkable tiles [x, y]
    walls: List[List[int]] = []           # blocked tiles (walls, hazards)
    enemies: List[List[int]] = []         # enemy tiles
    boss_spawn: List[int]                 # tile of the boss portal
    level_width: int                      # number of tiles across the level
    min_enemy_distance: int = 4
    min_spacing: int = 5
    seed: Optional[int] = None


@app.get("/health")
def health():
    return {"status": "ok", "service": "BioSphere-X AI Backend"}


@app.post("/pathfinding/find")
def pathfinding(req: PathIn):
    if req.algorithm not in ALGORITHMS:
        raise HTTPException(status_code=400, detail=f"algorithm must be one of {list(ALGORITHMS)}")
    return find_path(req.algorithm, req.grid, req.start, req.goal)


@app.post("/adversarial/decide")
def decide(req: DecideIn):
    state = CombatState(**req.state.model_dump())
    if req.algorithm == "mcts":
        result = mcts_decision(state)
    elif req.algorithm == "minimax":
        result = minimax_decision(state, use_alpha_beta=req.use_alpha_beta)
    else:
        raise HTTPException(status_code=400, detail="algorithm must be 'minimax' or 'mcts'")
    return {"algorithm": req.algorithm, "use_alpha_beta": req.use_alpha_beta and req.algorithm == "minimax", **result}


@app.post("/fuzzy/aggression")
def fuzzy(req: FuzzyIn):
    return fuzzy_aggression(req.player_health, req.recent_damage, req.distance)


@app.post("/logic/infer")
def logic(req: LogicIn):
    return forward_chain(req.facts)


@app.post("/csp/place")
def csp(req: CspIn):
    return place_items(req.candidates, req.walls, req.enemies, req.boss_spawn, req.level_width,
                       req.min_enemy_distance, req.min_spacing, req.seed)


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8000)
