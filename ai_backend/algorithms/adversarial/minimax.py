"""
Minimax Decision Algorithm for BioSphere-X Boss Combat.
Exhaustively searches the adversarial game tree up to a specified depth limit.
Boss acts as the MAX agent, while the Player is modeled as the MIN agent.
Gathers execution statistics including evaluated node counts, runtime, and action utilities.
"""
import time
from typing import Dict, Any, Tuple, Optional
from .combat_state import CombatState, evaluate_combat_state


class MinimaxDecision:
    def __init__(self, max_depth: int = 3):
        self.max_depth = max_depth
        self.nodes_evaluated: int = 0
        self.max_depth_reached: int = 0
        self.total_branches_explored: int = 0
        self.internal_nodes_count: int = 0

    def select_action(self, state: CombatState) -> Dict[str, Any]:
        """
        Runs Minimax search from the root state and returns the optimal action along with statistics.
        """
        start_time = time.perf_counter()
        self.nodes_evaluated = 0
        self.max_depth_reached = 0
        self.total_branches_explored = 0
        self.internal_nodes_count = 0

        legal_actions = state.get_legal_actions()
        if not legal_actions:
            return {
                "action": "GUARD_STANCE",
                "score": 0.0,
                "statistics": {
                    "nodes_evaluated": 0,
                    "max_depth_reached": 0,
                    "execution_time_ms": 0.0,
                    "algorithm": "minimax"
                }
            }

        # If only one legal action exists (e.g., RECOVER_WAIT), return immediately
        if len(legal_actions) == 1:
            score = evaluate_combat_state(state)
            elapsed_ms = (time.perf_counter() - start_time) * 1000.0
            return {
                "action": legal_actions[0],
                "score": score,
                "statistics": {
                    "nodes_evaluated": 1,
                    "max_depth_reached": 0,
                    "execution_time_ms": elapsed_ms,
                    "algorithm": "minimax",
                    "action_scores": {legal_actions[0]: score}
                }
            }

        best_score = float("-inf")
        best_action = legal_actions[0]
        action_scores: Dict[str, float] = {}

        for action in legal_actions:
            next_state = state.apply_action(action)
            # After Boss moves, it's Player's turn (MIN)
            score = self._min_value(next_state, 1)
            action_scores[action] = round(score, 2)

            if score > best_score:
                best_score = score
                best_action = action

        elapsed_ms = (time.perf_counter() - start_time) * 1000.0
        avg_branching = (
            (self.total_branches_explored / self.internal_nodes_count)
            if self.internal_nodes_count > 0 else len(legal_actions)
        )

        return {
            "action": best_action,
            "score": round(best_score, 2),
            "statistics": {
                "algorithm": "minimax",
                "nodes_evaluated": self.nodes_evaluated,
                "max_depth_reached": self.max_depth_reached,
                "execution_time_ms": round(elapsed_ms, 3),
                "action_scores": action_scores,
                "average_branching_factor": round(avg_branching, 2),
                "configured_depth": self.max_depth
            }
        }

    def _max_value(self, state: CombatState, current_depth: int) -> float:
        self.nodes_evaluated += 1
        if current_depth > self.max_depth_reached:
            self.max_depth_reached = current_depth

        if current_depth >= self.max_depth or state.is_terminal():
            return evaluate_combat_state(state)

        legal_actions = state.get_legal_actions()
        if not legal_actions:
            return evaluate_combat_state(state)

        self.internal_nodes_count += 1
        self.total_branches_explored += len(legal_actions)

        v = float("-inf")
        for action in legal_actions:
            next_state = state.apply_action(action)
            v = max(v, self._min_value(next_state, current_depth + 1))
        return v

    def _min_value(self, state: CombatState, current_depth: int) -> float:
        self.nodes_evaluated += 1
        if current_depth > self.max_depth_reached:
            self.max_depth_reached = current_depth

        if current_depth >= self.max_depth or state.is_terminal():
            return evaluate_combat_state(state)

        legal_actions = state.get_legal_actions()
        if not legal_actions:
            return evaluate_combat_state(state)

        self.internal_nodes_count += 1
        self.total_branches_explored += len(legal_actions)

        v = float("inf")
        for action in legal_actions:
            next_state = state.apply_action(action)
            v = min(v, self._max_value(next_state, current_depth + 1))
        return v
