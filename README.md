# BioSphere X

The Horizon Ark has gone silent somewhere across **10 real NASA exoplanets**.
Fly from world to world, survive on limited oxygen, and beat each planet's AI guardian to bring the crew home.

A 2D space fighting game for an AI course: **Godot 4** for the game and **Python (FastAPI)** for the AI server.

## How to run (Windows)

You need **Godot 4** (tested with 4.7.2) and **Python 3** (tested with 3.13).

1. Install the AI server once (PowerShell, in this folder):
   ```powershell
   python -m venv ai_backend\.venv
   .\ai_backend\.venv\Scripts\python.exe -m pip install -r ai_backend\requirements.txt
   ```
2. Start everything:
   ```powershell
   .\launch_game_with_ai.bat
   ```
   This starts the AI server (`start_ai_backend.bat`, http://127.0.0.1:8000/health) and then the game. Keep the server window open.

If the server is off, the game still runs on simple fallbacks: a local A*, attack-if-near for the boss, and fixed item spots.

## The two modes

**Player vs AI.**
- **Campaign:** pick a pilot, then fly the planet map. Each planet has an exploration level and then a boss fight. You earn star ratings and upgrades, and progress saves automatically.
- **Exploring:** your oxygen drains over time; refill it with blue tanks or by standing in the safe dome.
- **Controls:** A/D move, Space jump, J punch, K shoot, Shift dash, E Orbit Pulse, Q suit mode (attack / guard / heal), **P** show AI paths, **F** show the aliens' FSM states, Esc pause.

**AI vs AI.**
- Two AI fighters fight in the boss arena, and every algorithm is used in every match.
- **Controls:** **P** paths, **F** alien states, **1 / 2 / 4** speed, Esc pause (then Q quits to the setup screen).

## The 2 AI agents

- **Alien Patrol** (`scenes/star_brawl/alien_enemy.gd`): a Finite State Machine. IDLE → PATROL → CHASE → ATTACK, CHASE → SEARCH → PATROL, and any state → DEAD. It only sees you in front of it and not through walls (a raycast). In CHASE it follows an A* path.
- **Boss** (`scenes/star_brawl/fighter_brain.gd`): runs a 4-step loop.
  1. **Look**: read HP, distance, energy and cooldowns.
  2. **Think**: Minimax (+ alpha-beta) or MCTS picks the move.
  3. **Adjust**: fuzzy logic sets the aggression.
  4. **Attack and rest**: after a special it rests 1.5 s.

  It moves with A*.

## Algorithms

| Algorithm | Group | File | Used in Player vs AI | Used in AI vs AI |
|---|---|---|---|---|
| BFS | Uninformed search | `ai_backend/algorithms/pathfinding/bfs.py` | – | Movement (rotation) |
| DFS | Uninformed search | `ai_backend/algorithms/pathfinding/dfs.py` | – | Movement (rotation) |
| DLS (limit 20) | Uninformed search | `ai_backend/algorithms/pathfinding/dls.py` | – | Movement (rotation) |
| IDDFS (limit 1..40) | Uninformed search | `ai_backend/algorithms/pathfinding/iddfs.py` | – | Movement (rotation) |
| Bidirectional | Uninformed search | `ai_backend/algorithms/pathfinding/bidirectional.py` | – | Movement (rotation) |
| Greedy Best-First | Informed search | `ai_backend/algorithms/pathfinding/greedy.py` | – | Movement (rotation) |
| A* (f = g + h, Manhattan) | Informed search | `ai_backend/algorithms/pathfinding/astar.py`, backup `scripts/utils/modular_pathfinder.gd` | Boss movement, alien CHASE | Movement (rotation), Alien Patrols |
| Minimax + alpha-beta (depth 4) | Adversarial search | `ai_backend/algorithms/adversarial/minimax.py` | Boss on planets 1, 4, 7, 10 (2, 5, 8 without pruning) | Fighter decisions every 0.5 s |
| MCTS (200 simulations, UCB1) | Adversarial search | `ai_backend/algorithms/adversarial/mcts.py` | Boss on planets 3, 6, 9 | Fighter decisions every 0.5 s |
| Fuzzy logic | Uncertainty | `ai_backend/algorithms/fuzzy/engine.py` | Boss aggression (speed and attack rate) | Each fighter's aggression |
| Forward chaining | Logic | `ai_backend/algorithms/logic/engine.py` | `duel_won` → `unlock_next_planet`; low health / oxygen warnings | `defensive_mode`, `finisher_mode`, and the referee (`red_wins` / `blue_wins` / `compare_hp`) |
| CSP (backtracking + forward checking) | Constraint satisfaction | `ai_backend/algorithms/csp/solver.py` | Places 2 oxygen tanks, the safe dome, health and energy | Places pickups, and solves again after each one is taken |
| FSM | Agent behaviour | `scenes/star_brawl/alien_enemy.gd`, `scenes/ai_vs_ai_mode/ai_fighter_controller.gd` | Alien Patrols | Fighter modes CHASE / ATTACK / DEFEND / PICKUP, plus 2 Alien Patrols |

Every agent searches the same tile grid (`scenes/star_brawl/arena_grid.gd`): walkable tiles, blocked walls, and 4-way moves. Path requests are asynchronous, so the game never freezes.

## How to demo AI vs AI to the teacher

1. Run `launch_game_with_ai.bat` and press **AI vs AI**. Check that the setup screen says **Python AI server: ONLINE**.
2. Keep the defaults (**Minimax + alpha-beta** vs **MCTS**, **Rotate all 7**) and press **Start Match**. Press **P** for the paths and **2** for 2x speed.
3. Point at the panels: the search algorithm changes every 10 s (also shown above each head). Show the nodes and pruned nodes for alpha-beta and the win rate for MCTS, the fuzzy aggression, and the FSM mode. The rule log at the bottom shows CSP placements and `defensive_mode` / `finisher_mode`. **Esc** pauses so you can explain.
4. At the end (knockout or 90 s, decided by the forward-chaining referee), the **result panel** lists every algorithm used. Compare the 7 searches: IDDFS expands the most nodes, A* and Greedy the fewest, and DFS finds the longest paths. Then show alpha-beta's pruned nodes, the fuzzy updates, rules fired, CSP solves and FSM modes.
5. Press **Change Setup** and then **Run 10 Matches**. It plays at 4x (about 4 min), then shows the table (AI | Decision | Wins | Avg nodes | Avg search ms | Avg damage) and saves `ai_vs_ai_results.csv`.

## Tests

```powershell
# Python: 7 path-finding algorithms, minimax (+ alpha-beta), MCTS, fuzzy, forward chaining, CSP, API health
.\ai_backend\.venv\Scripts\python.exe -m pytest -q ai_backend\tests

# Godot: local A* backup + grid, and the smoke test (Player vs AI boss fight, then a full AI vs AI match)
godot --headless --path . --import
godot --headless --path . res://tests/test_search.tscn
godot --headless --path . res://tests/test_smoke.tscn
```
