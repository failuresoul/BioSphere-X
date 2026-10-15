"""
FastAPI Router for BioSphere-X Boss Adversarial Decision Making.
Exposes endpoints for evaluating combat states and selecting optimal boss actions
via Minimax, Alpha-Beta Pruning, Monte Carlo Tree Search, or Heuristic evaluation.
"""
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from typing import Optional, Dict, Any, List
import time

from .combat_state import CombatState, evaluate_combat_state, BOSS_ACTIONS
from .minimax import MinimaxDecision
from .alpha_beta import AlphaBetaDecision
from .mcts import MCTSDecision

router = APIRouter(prefix="/api/ai/boss", tags=["Boss Adversarial AI"])


class CombatStateDTO(BaseModel):
    turn: str = Field(default="boss", description="'boss' or 'player'")
    boss_hp: float = Field(default=500.0, ge=0.0)
    boss_max_hp: float = Field(default=500.0, ge=1.0)
    boss_phase: int = Field(default=1, ge=1, le=2)
    slam_cooldown: float = Field(default=0.0, ge=0.0)
    barrage_cooldown: float = Field(default=0.0, ge=0.0)
    charge_cooldown: float = Field(default=0.0, ge=0.0)
    is_recovering: bool = Field(default=False)
    recover_timer: float = Field(default=0.0, ge=0.0)
    is_guarding: bool = Field(default=False)
    player_hp: float = Field(default=100.0, ge=0.0)
    player_max_hp: float = Field(default=100.0, ge=1.0)
    player_energy: float = Field(default=100.0, ge=0.0, le=100.0)
    distance: float = Field(default=200.0, ge=0.0)


class BossDecisionRequest(BaseModel):
    state: CombatStateDTO
    algorithm: str = Field(default="alpha_beta", description="minimax, alpha_beta, mcts, heuristic")
    max_depth: Optional[int] = Field(default=4, ge=1, le=6, description="Search depth limit for minimax / alpha-beta")
    simulations: Optional[int] = Field(default=150, ge=10, le=1000, description="Rollouts for MCTS")
    exploration_c: Optional[float] = Field(default=1.414, ge=0.1, le=5.0, description="Exploration weight for MCTS UCT")


class BossDecisionResponse(BaseModel):
    action: str
    algorithm: str
    score: float
    statistics: Dict[str, Any]
    legal_actions: List[str]
    message: str = ""


ALGORITHM_INFO = {
    "minimax": {
        "name": "Minimax Search",
        "description": "Exhaustive depth-limited adversarial search assuming optimal counter-play from the player.",
        "strengths": "Guarantees mathematically optimal action selection within the explored horizon.",
        "tradeoffs": "Exponential time complexity O(b^d); evaluates every sub-tree without pruning.",
        "recommended_for": "Low depth horizons (d <= 3) and analytical baseline comparisons."
    },
    "alpha_beta": {
        "name": "Alpha-Beta Pruning",
        "description": "Optimized minimax search that prunes provably suboptimal branches using move ordering.",
        "strengths": "Finds identical optimal moves as minimax while reducing evaluated nodes by up to 50-70%.",
        "tradeoffs": "Performance depends heavily on effective move ordering.",
        "recommended_for": "Production real-time combat at depths 4-5 within strict frame budgets."
    },
    "mcts": {
        "name": "Monte Carlo Tree Search (UCT)",
        "description": "Simulation-driven tree search that balances exploration and exploitation via UCB1.",
        "strengths": "Anytime algorithm; robust without requiring deep hand-crafted minimax pruning rules.",
        "tradeoffs": "Stochastic variance; requires sufficient rollouts to converge on optimal lines.",
        "recommended_for": "Complex tactical states with large branch counts or variable time budgets."
    },
    "heuristic": {
        "name": "Direct Heuristic Evaluation",
        "description": "Greedy 1-step evaluation comparing immediate state transitions.",
        "strengths": "Ultra-fast execution (<0.1ms) with zero branch exploration overhead.",
        "tradeoffs": "Susceptible to horizon effect and tactical traps.",
        "recommended_for": "Zero-latency fallback when backend load is saturated."
    }
}


@router.get("/algorithms")
def get_supported_algorithms():
    """Returns profiles and metadata for all boss decision algorithms."""
    return ALGORITHM_INFO


@router.post("/decision", response_model=BossDecisionResponse)
def compute_boss_decision(req: BossDecisionRequest):
    """
    Receives current combat state and returns the optimal boss action along with decision statistics.
    Supports Minimax, Alpha-Beta pruning, MCTS, and direct Heuristic evaluation.
    """
    s_dto = req.state
    state = CombatState(
        turn=s_dto.turn,
        boss_hp=s_dto.boss_hp,
        boss_max_hp=s_dto.boss_max_hp,
        boss_phase=s_dto.boss_phase,
        slam_cooldown=s_dto.slam_cooldown,
        barrage_cooldown=s_dto.barrage_cooldown,
        charge_cooldown=s_dto.charge_cooldown,
        is_recovering=s_dto.is_recovering,
        recover_timer=s_dto.recover_timer,
        is_guarding=s_dto.is_guarding,
        player_hp=s_dto.player_hp,
        player_max_hp=s_dto.player_max_hp,
        player_energy=s_dto.player_energy,
        distance=s_dto.distance
    )

    legal_actions = state.get_legal_actions()
    algo_key = req.algorithm.strip().lower()

    if algo_key in ("minimax", "mini_max"):
        engine = MinimaxDecision(max_depth=req.max_depth or 3)
        res = engine.select_action(state)

    elif algo_key in ("alpha_beta", "alphabeta", "ab"):
        engine = AlphaBetaDecision(max_depth=req.max_depth or 4)
        res = engine.select_action(state)

    elif algo_key in ("mcts", "monte_carlo", "uct"):
        engine = MCTSDecision(
            simulations=req.simulations or 150,
            exploration_c=req.exploration_c or 1.414
        )
        res = engine.select_action(state)

    elif algo_key in ("heuristic", "greedy"):
        start_t = time.perf_counter()
        best_act = legal_actions[0] if legal_actions else "GUARD_STANCE"
        best_val = float("-inf")
        scores = {}
        for act in legal_actions:
            nxt = state.apply_action(act)
            sc = evaluate_combat_state(nxt)
            scores[act] = round(sc, 2)
            if sc > best_val:
                best_val = sc
                best_act = act
        elapsed = (time.perf_counter() - start_t) * 1000.0
        res = {
            "action": best_act,
            "score": round(best_val, 2),
            "statistics": {
                "algorithm": "heuristic",
                "execution_time_ms": round(elapsed, 3),
                "action_scores": scores
            }
        }

    else:
        # Fallback to alpha_beta
        engine = AlphaBetaDecision(max_depth=req.max_depth or 4)
        res = engine.select_action(state)
        res["statistics"]["algorithm"] = f"alpha_beta (fallback from unknown '{req.algorithm}')"

    return BossDecisionResponse(
        action=res["action"],
        algorithm=req.algorithm,
        score=float(res.get("score", 0.0)),
        statistics=res.get("statistics", {}),
        legal_actions=legal_actions,
        message=f"Action selected using {req.algorithm}"
    )
