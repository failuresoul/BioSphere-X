"""
Minimax adversarial search (depth-limited, default depth 3).

"me" is the MAX player, the enemy is the MIN player. Leaves are scored with
`evaluate()` from combat_state.py. Alpha-beta pruning is an on/off option:
it returns the same action but expands fewer nodes.
"""
import time
from .combat_state import CombatState, evaluate


def minimax_decision(state: CombatState, depth: int = 3, use_alpha_beta: bool = False) -> dict:
    start = time.perf_counter()
    counter = {"nodes": 0}

    def value(node: CombatState, depth_left: int, alpha: float, beta: float) -> float:
        counter["nodes"] += 1
        if depth_left == 0 or node.is_terminal():
            return evaluate(node)
        if node.my_turn:                                   # MAX node
            best = float("-inf")
            for action in node.legal_actions():
                best = max(best, value(node.apply(action), depth_left - 1, alpha, beta))
                alpha = max(alpha, best)
                if use_alpha_beta and alpha >= beta:
                    break                                  # prune: MIN will never allow this
            return best
        best = float("inf")                                # MIN node
        for action in node.legal_actions():
            best = min(best, value(node.apply(action), depth_left - 1, alpha, beta))
            beta = min(beta, best)
            if use_alpha_beta and alpha >= beta:
                break                                      # prune: MAX already has better
        return best

    # Root: try every action and keep the one with the highest minimax value.
    best_action, best_score = "block", float("-inf")
    alpha = float("-inf")
    for action in state.legal_actions():
        score = value(state.apply(action), depth - 1, alpha, float("inf"))
        if score > best_score:
            best_action, best_score = action, score
        if use_alpha_beta:
            alpha = max(alpha, best_score)

    return {
        "action": best_action,
        "score": round(best_score, 2),
        "nodes_expanded": counter["nodes"],
        "time_ms": round((time.perf_counter() - start) * 1000.0, 3),
    }
