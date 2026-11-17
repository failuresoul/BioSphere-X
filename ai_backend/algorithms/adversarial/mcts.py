"""
Monte Carlo Tree Search (200 simulations by default).

Each simulation does 4 steps:
  1. Selection       - walk down the tree, always taking the child with the best UCB1
                       UCB1 = win_rate + c * sqrt(ln(parent visits) / child visits),  c = 1.41
  2. Expansion       - add one move that was not tried yet as a new child
  3. Simulation      - play random moves (at most 10) to see how the fight goes
  4. Backpropagation - add the result to every node on the way back to the root
Result of a simulation (from the boss's view): 1 = boss wins, 0 = boss loses,
otherwise 0.5 + health lead / 200 (a partial win).
The chosen move is the most visited child; win_rate = its average result.
"""
import math
import random
import time
from .combat_state import CombatState

C = 1.41
MAX_SIMULATION_MOVES = 10


class Node:
    def __init__(self, state: CombatState, parent=None, action=None):
        self.state = state
        self.parent = parent
        self.action = action                 # the move that led here
        self.children = []
        self.untried = [] if state.is_terminal() else list(state.legal_actions())
        self.visits = 0
        self.wins = 0.0                      # sum of results, from the boss's view

    def best_ucb1_child(self):
        def ucb1(child):
            win_rate = child.wins / child.visits
            if not self.state.boss_turn:
                win_rate = 1.0 - win_rate    # the player wants the boss to LOSE
            return win_rate + C * math.sqrt(math.log(self.visits) / child.visits)
        return max(self.children, key=ucb1)


def result_for_boss(state: CombatState) -> float:
    if state.player_hp <= 0:
        return 1.0
    if state.boss_hp <= 0:
        return 0.0
    return max(0.0, min(1.0, 0.5 + (state.boss_hp - state.player_hp) / 200.0))


def mcts_decision(state: CombatState, simulations: int = 200, seed=None) -> dict:
    start = time.perf_counter()
    rng = random.Random(seed)
    root = Node(state)

    for _ in range(simulations):
        node = root
        # 1. Selection
        while not node.untried and node.children:
            node = node.best_ucb1_child()
        # 2. Expansion
        if node.untried:
            action = node.untried.pop(rng.randrange(len(node.untried)))
            child = Node(node.state.apply_action(action), node, action)
            node.children.append(child)
            node = child
        # 3. Simulation: a random game of at most 10 moves
        sim = node.state
        for _ in range(MAX_SIMULATION_MOVES):
            if sim.is_terminal():
                break
            sim = sim.apply_action(rng.choice(sim.legal_actions()))
        result = result_for_boss(sim)
        # 4. Backpropagation
        while node is not None:
            node.visits += 1
            node.wins += result
            node = node.parent

    best = max(root.children, key=lambda c: c.visits) if root.children else None
    return {
        "action": best.action if best else "block",
        "win_rate": round(best.wins / best.visits, 3) if best else 0.0,
        "simulations": simulations,
        "time_ms": round((time.perf_counter() - start) * 1000.0, 3),
    }
