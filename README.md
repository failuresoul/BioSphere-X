# BioSphere X

A 2D space fighting game made for an AI course. Fighters move with **search algorithms** and choose their attacks with **adversarial search**. The game is made in **Godot 4**; some AI algorithms run in a small **Python (FastAPI)** backend.

## How to run (Windows)

You need **Godot 4** (tested with 4.7.2) and **Python 3** (tested with 3.13).

1. Install the backend once (in PowerShell, in this folder):

   ```powershell
   python -m venv ai_backend\.venv
   .\ai_backend\.venv\Scripts\python.exe -m pip install -r ai_backend\requirements.txt
   ```

2. Start the game and the backend together:

   ```powershell
   .\launch_game_with_ai.bat
   ```

   The launcher starts the backend (`start_ai_backend.bat`) and opens Godot. Check the backend at http://127.0.0.1:8000/health.

**Run them by hand instead:** start the backend with `.\ai_backend\.venv\Scripts\python.exe -m uvicorn ai_backend.main:app --port 8000`, then open `project.godot` in Godot and press **F5**.

If the backend is not running, the game still works. Paths come from a local A* in Godot (the HUD shows `A* (local)`). The boss uses a fallback rule: attack if near, else move closer. Items go to fixed spots, and the warnings are checked locally. Path requests are asynchronous, so the game never freezes: each agent keeps its last path until the new one arrives.

## The two game modes

On the home screen, pick one of two buttons.

### Player vs AI

You play through 10 planets. On each planet you explore the level, go through the portal, and fight the boss.

- **Oxygen survival.** While exploring, the oxygen bar (top left) drops 1.5 per second, so a full bar lasts about 65 s. An oxygen tank gives +40, and standing in the **safe dome** refills 8 per second. At 0 oxygen you lose 4 health per second. Below 20 oxygen a warning appears.
- **Item placement (CSP).** At the start of each level a CSP solver places 2 oxygen tanks, the safe dome, a health pickup and an energy pickup.
- **Aliens (Agent 1)** patrol the level using a **Finite State Machine**: IDLE → PATROL → CHASE → ATTACK, CHASE → SEARCH → PATROL, and any state → DEAD. An alien sees you only when you are in front of it and no wall or platform is in between (a raycast). In CHASE it follows an A* path. Its state is shown in a small label above it (F toggles the labels).

- The boss **moves** with A*.
- The boss **decides** its next move with adversarial search. Planets 1, 4, 7 and 10 use **Minimax with alpha-beta**, planets 2, 5 and 8 use **Minimax without pruning**, and planets 3, 6 and 9 use **MCTS**.
- Every frame the boss runs a 4-step loop. **Look**: read the distance, both health bars and the cooldowns. **Think**: ask the server for the best move without freezing the game. **Adjust**: fuzzy logic sets the boss's aggression (0 to 1) from your health, the damage you took recently, and the distance. The boss's speed and attack rate follow it slowly. **Attack and rest**: after a big attack (special) the boss rests 1.5 s so you can hit back.
- If the server is slow (no answer in 0.8 s), the boss uses a fallback: attack if near, otherwise move closer.
- The HUD (top right) shows the boss's thinking, e.g. `Boss: Minimax+αβ → attack | nodes 120, pruned 64` (or `MCTS → attack | win rate 0.62, 200 sims`), the latest search, e.g. `Search: A* | Nodes: 34 | 0.4 ms`, and `Aggression 0.72`.

| Key | Action |
|---|---|
| A / D or arrow keys | Move |
| Space / W | Jump (double jump) |
| J | Punch |
| K | Blaster shot |
| Shift | Dash |
| E | Orbit Pulse (needs 70 energy) |
| P | Show / hide the grid and the current AI paths |
| F | Show / hide the aliens' state labels |
| Esc | Pause |

### AI vs AI

Two AI fighters fight each other, and nobody controls them.

1. For **AI 1 (blue)** and **AI 2 (red)**, choose a **search algorithm** (BFS / DFS / DLS / IDDFS / Bidirectional / Greedy / A*) and a **decision algorithm** (Minimax + alpha-beta / Minimax / MCTS).
2. Choose an arena (planet) and press **Start**.
3. During the match the HUD shows, for each AI: its algorithms, health, current action, nodes expanded, path length and search time (ms). Press **P** to draw each AI's path (blue and red lines).
4. A match ends by knockout, or after 60 seconds. If time runs out, the AI with more health wins. The result panel shows the winner, time taken, total damage dealt, and each AI's average nodes expanded and average search time.
5. **Run 10 matches** plays 10 matches back to back at 3x speed and shows a win table.

Press **Esc** to stop a match and go back to the setup screen.

## Algorithms

| Algorithm | Type | File | Where it is used in the game |
|---|---|---|---|
| BFS | Uninformed search | `ai_backend/algorithms/pathfinding/bfs.py` | Fighter movement (AI vs AI choice) |
| DFS | Uninformed search | `ai_backend/algorithms/pathfinding/dfs.py` | Fighter movement (AI vs AI choice) |
| DLS (limit 20) | Uninformed search | `ai_backend/algorithms/pathfinding/dls.py` | Fighter movement (AI vs AI choice) |
| IDDFS (limit 1..40) | Uninformed search | `ai_backend/algorithms/pathfinding/iddfs.py` | Fighter movement (AI vs AI choice) |
| Bidirectional search | Uninformed search | `ai_backend/algorithms/pathfinding/bidirectional.py` | Fighter movement (AI vs AI choice) |
| Greedy Best-First (Manhattan) | Informed search | `ai_backend/algorithms/pathfinding/greedy.py` | Fighter movement (AI vs AI choice) |
| A* (f = g + h, Manhattan) | Informed search | `ai_backend/algorithms/pathfinding/astar.py` | Boss movement, alien CHASE, AI vs AI choice |
| A* (local backup) | Informed search | `scripts/utils/modular_pathfinder.gd` | Used when the server does not answer within 0.4 s |
| Finite State Machine | Agent behaviour | `scenes/star_brawl/alien_enemy.gd` | Alien patrols in the exploration levels |
| Minimax, depth 4, with alpha-beta | Adversarial | `ai_backend/algorithms/adversarial/minimax.py` (`use_alpha_beta=True`) | Boss on planets 1, 4, 7, 10; AI vs AI choice |
| Minimax, depth 4, no pruning | Adversarial | `ai_backend/algorithms/adversarial/minimax.py` (`use_alpha_beta=False`) | Boss on planets 2, 5, 8; AI vs AI choice |
| MCTS (200 simulations, UCB1 c = 1.41) | Adversarial | `ai_backend/algorithms/adversarial/mcts.py` | Boss on planets 3, 6, 9; AI vs AI choice |
| Fuzzy logic (3 inputs, 5 rules, centroid) | Other | `ai_backend/algorithms/fuzzy/engine.py` | Boss aggression 0 to 1 from player health, recent damage and distance; changes the boss's speed and attack rate slowly (boss loop step 3) |
| CSP (backtracking + forward checking) | Other | `ai_backend/algorithms/csp/solver.py` | Places 2 oxygen tanks, the safe dome, a health and an energy pickup at the start of each level |
| Forward chaining (5 rules) | Other | `ai_backend/algorithms/logic/engine.py` | `duel_won`, then `unlock_next_planet` after the boss; `low_health_warning` and `oxygen_warning` while playing |

**How it fits together**

- `scenes/star_brawl/arena_grid.gd` turns a level into tiles (the same rules for every agent): ground, platforms and walls are blocked, free tiles are the ones a fighter can reach. Moves go in 4 directions.
- Fuzzy logic: inputs `player_health`, `recent_damage` (damage taken in the last 5 s) and `distance` use triangle memberships (low / medium / high, or near / medium / far). The rules use AND = min, and the result is defuzzified with the centroid. Endpoint: `POST /fuzzy/aggression`.
- CSP: the variables are `oxygen_tank_1`, `oxygen_tank_2`, `safe_dome`, `health_pickup` and `energy_pickup`. The domain is the walkable floor tiles. The constraints are: not in a wall or hazard, not near aliens or the boss portal, at least 5 tiles apart, and at least one oxygen item in each third of the level. The answer is the positions plus the number of backtracks. Endpoint: `POST /csp/place`.
- Forward chaining fires IF-THEN rules until no new fact appears, and returns the new facts and the order the rules fired in. Endpoint: `POST /logic/infer`.
- `scripts/utils/path_planner.gd` sends the grid to `POST /pathfinding/find` asynchronously and falls back to the local A* if no answer arrives in time.
- `scenes/star_brawl/fighter_brain.gd` is the AI for one fighter. It searches a path on that grid and asks the backend for an action: `attack`, `block`, `dodge`, `move_closer`, `move_away` or `special`.
- The combat state used by Minimax and MCTS is in `ai_backend/algorithms/adversarial/combat_state.py`: `boss_hp`, `player_hp`, `distance`, `boss_energy`, `player_energy` and both cooldowns. One `apply_action()` holds the damage rules, and both algorithms use it. The evaluation rewards the boss keeping its health, the player losing health, and the boss staying at a good distance. Endpoint: `POST /adversarial/decide {algorithm, use_alpha_beta, state}`.

## Tests

```powershell
# Python: 7 path-finding algorithms, minimax (+ alpha-beta), MCTS, fuzzy, CSP, forward chaining
.\ai_backend\.venv\Scripts\python.exe -m pytest -q ai_backend\tests

# Godot: local A* + grid, and a smoke test (both game modes, alien FSM, oxygen, items)
godot --headless --path . --import
godot --headless --path . res://tests/test_search.tscn
godot --headless --path . res://tests/test_game_modes.tscn
```
