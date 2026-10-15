"""
Alpha-Beta Pruning Decision Algorithm for BioSphere-X Boss Combat.
Enhances the standard minimax search with alpha-beta branch pruning and move ordering.
Boss maximizes utility (alpha), while the Player minimizes utility (beta).
Tracks pruned branch counts, nodes evaluated, and execution performance.
"""
import time
from typing import Dict, Any, List, Tuple
from .combat_state import CombatState, evaluate_combat_state


# Move ordering priority weights to maximize early cutoffs
ACTION_PRIORITY = {
    "TREMOR_SLAM": 10,
    "CHARGE_RUSH": 8,
    "PLASMA_BARRAGE": 7,
    "PURSUE_ADVANCE": 5,
    "TACTICAL_RETREAT": 4,
    "GUARD_STANCE": 3,
    "RECOVER_WAIT": 1,
    "PLAYER_SHOOT": 10,
    "PLAYER_DODGE": 7,
    "PLAYER_CLOSE_IN": 5,
    "PLAYER_FALL_BACK": 4,
    "PLAYER_REST": 2,
}


class AlphaBetaDecision:
    def __init__(self, max_depth: int = 4):
        self.max_depth = max_depth
        self.nodes_evaluated: int = 0
        self.pruned_branches: int = 0
        self.max_depth_reached: int = 0

    def select_action(self, state: CombatState) -> Dict[str, Any]:
        """
        Runs Alpha-Beta search from root state and returns the optimal action along with pruning statistics.
        """
        start_time = time.perf_counter()
        self.nodes_evaluated = 0
        self.pruned_branches = 0
        self.max_depth_reached = 0

        legal_actions = state.get_legal_actions()
        if not legal_actions:
            return {
                "action": "GUARD_STANCE",
                "score": 0.0,
                "statistics": {
                    "nodes_evaluated": 0,
                    "pruned_branches": 0,
                    "max_depth_reached": 0,
                    "execution_time_ms": 0.0,
                    "algorithm": "alpha_beta"
                }
            }

        if len(legal_actions) == 1:
            score = evaluate_combat_state(state)
            elapsed_ms = (time.perf_counter() - start_time) * 1000.0
            return {
                "action": legal_actions[0],
                "score": score,
                "statistics": {
                    "nodes_evaluated": 1,
                    "pruned_branches": 0,
                    "max_depth_reached": 0,
                    "execution_time_ms": elapsed_ms,
                    "algorithm": "alpha_beta",
                    "action_scores": {legal_actions[0]: score}
                }
            }

        # Order root actions to maximize pruning efficiency
        sorted_actions = sorted(legal_actions, key=lambda a: ACTION_PRIORITY.get(a, 0), reverse=True)

        alpha = float("-inf")
        beta = float("inf")
        best_score = float("-inf")
        best_action = sorted_actions[0]
        action_scores: Dict[str, float] = {}

        for action in sorted_actions:
            next_state = state.apply_action(action)
            # After Boss moves, it's Player's turn (MIN)
            score = self._min_value(next_state, 1, alpha, beta)
            action_scores[action] = round(score, 2)

            if score > best_score:
                best_score = score
                best_action = action

            alpha = max(alpha, best_score)
            if beta <= alpha:
                self.pruned_branches += 1
                break

        elapsed_ms = (time.perf_counter() - start_time) * 1000.0

        return {
            "action": best_action,
            "score": round(best_score, 2),
            "statistics": {
                "algorithm": "alpha_beta",
                "nodes_evaluated": self.nodes_evaluated,
                "pruned_branches": self.pruned_branches,
                "max_depth_reached": self.max_depth_reached,
                "execution_time_ms": round(elapsed_ms, 3),
                "action_scores": action_scores,
                "configured_depth": self.max_depth
            }
        }

    def _max_value(self, state: CombatState, current_depth: int, alpha: float, beta: float) -> float:
        self.nodes_evaluated += 1
        if current_depth > self.max_depth_reached:
            self.max_depth_reached = current_depth

        if current_depth >= self.max_depth or state.is_terminal():
            return evaluate_combat_state(state)

        legal_actions = state.get_legal_actions()
        if not legal_actions:
            return evaluate_combat_state(state)

        # Move ordering
        sorted_actions = sorted(legal_actions, key=lambda a: ACTION_PRIORITY.get(a, 0), reverse=True)

        v = float("-inf")
        for action in sorted_actions:
            next_state = state.apply_action(action)
            v = max(v, self._min_value(next_state, current_depth + 1, alpha, beta))
            if v >= beta:
                self.pruned_branches += 1
                return v  # Beta cutoff
            alpha = max(alpha, v)
        return v

    def _min_value(self, state: CombatState, current_depth: int, alpha: float, beta: float) -> float:
        self.nodes_evaluated += 1
        if current_depth > self.max_depth_reached:
            self.max_depth_reached = current_depth

        if current_depth >= self.max_depth or state.is_terminal():
            return evaluate_combat_state(state)

        legal_actions = state.get_legal_actions()
        if not legal_actions:
            return evaluate_combat_state(state)

        # Move ordering
        sorted_actions = sorted(legal_actions, key=lambda a: ACTION_PRIORITY.get(a, 0), reverse=True)

        v = float("inf")
        for action in sorted_actions:
            next_state = state.apply_action(action)
            v = min(v, self._max_value(next_state, current_depth + 1, alpha, beta))
            if v <= alpha:
                self.pruned_branches += 1
                return v  # Alpha cutoff
            beta = min(beta, v)
        return v
