"""
Monte Carlo Tree Search (MCTS) Decision Algorithm for BioSphere-X Boss Combat.
Implements the 4 classic MCTS phases:
1. Selection (Upper Confidence Bound for Trees - UCT)
2. Expansion (Instantiating child nodes for untried actions)
3. Simulation / Rollout (Random/heuristic playouts to a horizon)
4. Backpropagation (Propagating simulation results up the search tree)
Tracks visit distributions, win rates, tree depth, and simulation throughput.
"""
import math
import random
import time
from typing import Dict, Any, List, Optional
from .combat_state import CombatState, evaluate_combat_state


class MCTSNode:
    def __init__(self, state: CombatState, parent: Optional['MCTSNode'] = None, action_from_parent: Optional[str] = None):
        self.state = state
        self.parent = parent
        self.action_from_parent = action_from_parent
        self.children: Dict[str, 'MCTSNode'] = {}
        self.untried_actions: List[str] = state.get_legal_actions()
        self.visits: int = 0
        self.total_value: float = 0.0  # Normalized sum from Boss (root) perspective: [0.0, 1.0]

    def is_fully_expanded(self) -> bool:
        return len(self.untried_actions) == 0

    def is_terminal(self) -> bool:
        return self.state.is_terminal()

    def best_child(self, exploration_weight: float = 1.414) -> 'MCTSNode':
        """
        Selects child using the Upper Confidence Bound for Trees (UCT) formula:
        UCT = (W_i / N_i) + c * sqrt(ln(N_parent) / N_i)
        """
        best_score = float("-inf")
        best_nodes: List['MCTSNode'] = []
        log_parent_visits = math.log(max(1, self.visits))

        for child in self.children.values():
            if child.visits == 0:
                return child
            exploitation = child.total_value / child.visits
            exploration = exploration_weight * math.sqrt(log_parent_visits / child.visits)
            uct = exploitation + exploration

            if uct > best_score:
                best_score = uct
                best_nodes = [child]
            elif math.isclose(uct, best_score, rel_tol=1e-5):
                best_nodes.append(child)

        return random.choice(best_nodes) if best_nodes else next(iter(self.children.values()))


class MCTSDecision:
    def __init__(self, simulations: int = 200, exploration_c: float = 1.414, max_rollout_steps: int = 8):
        self.simulations = simulations
        self.exploration_c = exploration_c
        self.max_rollout_steps = max_rollout_steps
        self.nodes_expanded = 0
        self.max_tree_depth = 0

    def select_action(self, state: CombatState) -> Dict[str, Any]:
        """
        Runs MCTS for the configured simulation count and selects the most robust action.
        """
        start_time = time.perf_counter()
        self.nodes_expanded = 0
        self.max_tree_depth = 0

        root = MCTSNode(state.clone())
        legal_actions = list(root.untried_actions)

        if not legal_actions:
            return {
                "action": "GUARD_STANCE",
                "score": 0.5,
                "statistics": {
                    "simulations_completed": 0,
                    "nodes_expanded": 0,
                    "max_tree_depth": 0,
                    "execution_time_ms": 0.0,
                    "algorithm": "mcts"
                }
            }

        if len(legal_actions) == 1:
            elapsed_ms = (time.perf_counter() - start_time) * 1000.0
            return {
                "action": legal_actions[0],
                "score": 1.0,
                "statistics": {
                    "simulations_completed": 1,
                    "nodes_expanded": 1,
                    "max_tree_depth": 0,
                    "execution_time_ms": elapsed_ms,
                    "algorithm": "mcts",
                    "visit_counts": {legal_actions[0]: 1},
                    "action_win_rates": {legal_actions[0]: 1.0}
                }
            }

        # Run MCTS iterations
        for _ in range(self.simulations):
            # 1. Selection
            node = root
            depth = 0
            while not node.is_terminal() and node.is_fully_expanded():
                if not node.children:
                    break
                node = node.best_child(self.exploration_c)
                depth += 1

            if depth > self.max_tree_depth:
                self.max_tree_depth = depth

            # 2. Expansion
            if not node.is_terminal() and node.untried_actions:
                action = random.choice(node.untried_actions)
                node.untried_actions.remove(action)
                next_state = node.state.apply_action(action)
                child_node = MCTSNode(next_state, parent=node, action_from_parent=action)
                node.children[action] = child_node
                node = child_node
                self.nodes_expanded += 1
                depth += 1
                if depth > self.max_tree_depth:
                    self.max_tree_depth = depth

            # 3. Rollout / Simulation
            reward = self._rollout(node.state)

            # 4. Backpropagation
            curr: Optional[MCTSNode] = node
            while curr is not None:
                curr.visits += 1
                curr.total_value += reward
                curr = curr.parent

        # Decision rule: Most visited child (robust child strategy)
        best_action = legal_actions[0]
        max_visits = -1
        visit_counts: Dict[str, int] = {}
        action_win_rates: Dict[str, float] = {}

        for act, child in root.children.items():
            visit_counts[act] = child.visits
            win_rate = (child.total_value / child.visits) if child.visits > 0 else 0.0
            action_win_rates[act] = round(win_rate, 3)
            if child.visits > max_visits:
                max_visits = child.visits
                best_action = act

        elapsed_ms = (time.perf_counter() - start_time) * 1000.0

        return {
            "action": best_action,
            "score": action_win_rates.get(best_action, 0.5),
            "statistics": {
                "algorithm": "mcts",
                "simulations_completed": self.simulations,
                "nodes_expanded": self.nodes_expanded,
                "max_tree_depth": self.max_tree_depth,
                "execution_time_ms": round(elapsed_ms, 3),
                "visit_counts": visit_counts,
                "action_win_rates": action_win_rates,
                "most_visited_count": max_visits
            }
        }

    def _rollout(self, initial_state: CombatState) -> float:
        """
        Fast heuristic-guided simulation rollout from given state.
        Returns normalized reward [0.0, 1.0] where 1.0 is full Boss victory and 0.0 is Boss defeat.
        """
        curr = initial_state.clone()
        steps = 0

        while not curr.is_terminal() and steps < self.max_rollout_steps:
            actions = curr.get_legal_actions()
            if not actions:
                break
            # Random action selection during rollout
            chosen = random.choice(actions)
            curr = curr.apply_action(chosen)
            steps += 1

        # Evaluate final rollout state and normalize score into [0.0, 1.0]
        raw_eval = evaluate_combat_state(curr)
        # Raw eval typically ranges from -10000 to +10000 (or -500 to +500 in non-terminal states)
        # Sigmoid or clamped linear mapping
        normalized = 1.0 / (1.0 + math.exp(-raw_eval / 250.0))
        return normalized
