"""
Monte Carlo Tree Search with UCB1 selection (default 200 simulations).

Each simulation has 4 steps:
  1. Selection      - walk down the tree using UCB1
  2. Expansion      - add one untried action as a new child
  3. Simulation     - play random moves for a few turns (rollout)
  4. Backpropagation- add the result to every node on the way back up
Rewards are stored from "me"'s point of view (1 = good for me, 0 = bad).
"""
import math
import random
import time
from .combat_state import CombatState, evaluate

ROLLOUT_DEPTH = 10
UCB_C = 1.41


class Node:
    def __init__(self, state: CombatState, parent=None, action=None):
        self.state = state
        self.parent = parent
        self.action = action
        self.children = []
        self.untried = [] if state.is_terminal() else list(state.legal_actions())
        self.visits = 0
        self.reward = 0.0

    def ucb1_child(self):
        """Pick the child with the best UCB1 score for the player who moves here."""
        def ucb1(child):
            mean = child.reward / child.visits
            if not self.state.my_turn:
                mean = 1.0 - mean                 # the enemy wants a LOW reward for me
            return mean + UCB_C * math.sqrt(math.log(self.visits) / child.visits)
        return max(self.children, key=ucb1)


def _reward(state: CombatState) -> float:
    """Map the evaluation score to a reward between 0 and 1."""
    return max(0.0, min(1.0, 0.5 + evaluate(state) / 200.0))


def mcts_decision(state: CombatState, simulations: int = 200, seed=None) -> dict:
    start = time.perf_counter()
    rng = random.Random(seed)
    root = Node(state)

    for _ in range(simulations):
        node = root
        # 1. Selection
        while not node.untried and node.children:
            node = node.ucb1_child()
        # 2. Expansion
        if node.untried:
            action = node.untried.pop(rng.randrange(len(node.untried)))
            child = Node(node.state.apply(action), node, action)
            node.children.append(child)
            node = child
        # 3. Simulation (random rollout)
        sim = node.state
        for _ in range(ROLLOUT_DEPTH):
            if sim.is_terminal():
                break
            sim = sim.apply(rng.choice(sim.legal_actions()))
        reward = _reward(sim)
        # 4. Backpropagation
        while node is not None:
            node.visits += 1
            node.reward += reward
            node = node.parent

    # Final choice: the most visited child is the most trusted action.
    best = max(root.children, key=lambda c: c.visits) if root.children else None
    return {
        "action": best.action if best else "block",
        "score": round(best.reward / best.visits, 3) if best else 0.0,
        "nodes_expanded": _count_nodes(root),
        "simulations": simulations,
        "time_ms": round((time.perf_counter() - start) * 1000.0, 3),
    }


def _count_nodes(node: Node) -> int:
    return 1 + sum(_count_nodes(child) for child in node.children)
