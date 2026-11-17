"""
Minimax adversarial search, looking 4 moves ahead (depth 4).

  BOSS   = MAX player: picks the move with the HIGHEST score
  PLAYER = MIN player: picks the move with the LOWEST score
Leaves are scored with evaluate() from combat_state.py.

Alpha-beta pruning (use_alpha_beta=True):
  alpha = best score MAX can already guarantee
  beta  = best score MIN can already guarantee
  If alpha >= beta, the remaining moves of this node cannot change the
  answer, so they are skipped ("pruned"). Same answer, fewer nodes.
"""
import time
from .combat_state import CombatState, evaluate


def minimax_decision(state: CombatState, depth: int = 4, use_alpha_beta: bool = True) -> dict:
    start = time.perf_counter()
    stats = {"evaluated": 0, "pruned": 0}

    def value(node: CombatState, depth_left: int, alpha: float, beta: float) -> float:
        stats["evaluated"] += 1
        if depth_left == 0 or node.is_terminal():
            return evaluate(node)
        actions = node.legal_actions()
        if node.boss_turn:                                       # MAX node (boss)
            best = float("-inf")
            for i, action in enumerate(actions):
                best = max(best, value(node.apply_action(action), depth_left - 1, alpha, beta))
                alpha = max(alpha, best)
                if use_alpha_beta and alpha >= beta:
                    stats["pruned"] += len(actions) - i - 1      # these moves are skipped
                    break
            return best
        best = float("inf")                                      # MIN node (player)
        for i, action in enumerate(actions):
            best = min(best, value(node.apply_action(action), depth_left - 1, alpha, beta))
            beta = min(beta, best)
            if use_alpha_beta and alpha >= beta:
                stats["pruned"] += len(actions) - i - 1
                break
        return best

    # Root (boss to move): try every move and keep the one with the highest value.
    best_action, best_score = "block", float("-inf")
    alpha = float("-inf")
    for action in state.legal_actions():
        score = value(state.apply_action(action), depth - 1, alpha, float("inf"))
        if score > best_score:
            best_action, best_score = action, score
        if use_alpha_beta:
            alpha = max(alpha, best_score)

    return {
        "action": best_action,
        "score": round(best_score, 2),
        "nodes_evaluated": stats["evaluated"],
        "nodes_pruned": stats["pruned"],
        "time_ms": round((time.perf_counter() - start) * 1000.0, 3),
    }
