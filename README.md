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

Two AI fighters fight each other in the boss arena, and nobody controls them. **Every algorithm is used in every match.** Both fighters have the same HP, damage and speed, and they swap sides every match.

**Setup.** For AI 1 (blue) and AI 2 (red), pick a **decision algorithm** (Minimax + alpha-beta / Minimax / MCTS; defaults are Minimax + alpha-beta vs MCTS) and a **search** setting (**Rotate all 7**, the default, or one fixed algorithm). Pick an arena (planet), then press **Start Match**, **Run 10 Matches** or **Back**.

**What each algorithm does in a match**

| Algorithm | In the match |
|---|---|
| 7 path-finding algorithms | Each fighter switches every 10 s: BFS → DFS → DLS → IDDFS → Bidirectional → Greedy → A*. Red starts 3 steps later, so they differ. The current one is shown above each fighter's head. |
| Minimax (+ alpha-beta) / MCTS | Each fighter picks its move every 0.5 s. After a special it rests 1.5 s, the same rule as the boss. |
| Fuzzy logic | Each fighter's aggression (from the opponent's HP, recent damage and distance) changes its speed and attack rate. |
| Forward chaining | Every 1 s: `IF my_hp < 30 THEN defensive_mode` (walking in becomes moving away) and `IF enemy_hp < 20 THEN finisher_mode` (cautious moves become attacks). At the end it is the referee: `IF blue_hp <= 0 THEN red_wins`, `IF red_hp <= 0 THEN blue_wins`, `IF time_up THEN compare_hp`. |
| CSP | Places health, energy and oxygen pickups and a healing dome at the start, and solves again whenever a pickup is taken. A fighter below 40% HP walks to a pickup. |
| FSM | Each fighter shows its mode: CHASE / ATTACK / DEFEND / PICKUP. Two Alien Patrols (FSM + A*) walk the arena and attack whichever fighter is closer. |

**On screen.** The blue panel (left) and red panel (right) show HP, the search algorithm with nodes expanded, path length and ms, the decision algorithm with its last move, the aggression and the FSM mode. The timer is at the top, and a rule log at the bottom shows what happened. Keys: **P** path lines, **F** alien state labels, **1 / 2 / 4** speed, **Esc** pause (then **Q** quits to the setup screen).

**A match ends** by knockout, or after **90 s**, when the higher HP % wins. The **result panel** shows the winner, the time, the damage dealt and an **Algorithms used** section:
- each search algorithm's times used, average nodes, average ms and average path length;
- each decision algorithm's decisions, average time and nodes evaluated / pruned;
- fuzzy updates, the rules fired, CSP solves and backtracks, and FSM mode changes.

Buttons: **Rematch**, **Change Setup** and **Home**.

**Run 10 Matches** plays them back to back at 4x and then shows a table (AI | Decision | Wins | Avg nodes | Avg search ms | Avg damage). It also saves every match to `user://ai_vs_ai_results.csv`; on Windows that is `%APPDATA%\Godot\app_userdata\BioSphere X\ai_vs_ai_results.csv`.

The code is in `scenes/ai_vs_ai_mode/`:
- `ai_vs_ai_setup.gd` is the setup screen.
- `ai_vs_ai_match.gd` runs the match on the same arena and fighters as Player vs AI, and is also the referee.
- `ai_fighter_controller.gd` is one AI fighter. It extends the boss brain and adds the rotation, rules, pickups and FSM.
- `ai_vs_ai_result.gd` is the result panel.

## Algorithms

| Algorithm | Type | File | Where it is used in the game |
|---|---|---|---|
| BFS | Uninformed search | `ai_backend/algorithms/pathfinding/bfs.py` | AI vs AI fighters (rotation every 10 s) |
| DFS | Uninformed search | `ai_backend/algorithms/pathfinding/dfs.py` | AI vs AI fighters (rotation every 10 s) |
| DLS (limit 20) | Uninformed search | `ai_backend/algorithms/pathfinding/dls.py` | AI vs AI fighters (rotation every 10 s) |
| IDDFS (limit 1..40) | Uninformed search | `ai_backend/algorithms/pathfinding/iddfs.py` | AI vs AI fighters (rotation every 10 s) |
| Bidirectional search | Uninformed search | `ai_backend/algorithms/pathfinding/bidirectional.py` | AI vs AI fighters (rotation every 10 s) |
| Greedy Best-First (Manhattan) | Informed search | `ai_backend/algorithms/pathfinding/greedy.py` | AI vs AI fighters (rotation every 10 s) |
| A* (f = g + h, Manhattan) | Informed search | `ai_backend/algorithms/pathfinding/astar.py` | Boss movement, alien CHASE, AI vs AI fighters |
| A* (local backup) | Informed search | `scripts/utils/modular_pathfinder.gd` | Used when the server does not answer within 0.4 s |
| Finite State Machine | Agent behaviour | `scenes/star_brawl/alien_enemy.gd` | Alien patrols in the exploration levels |
| Minimax, depth 4, with alpha-beta | Adversarial | `ai_backend/algorithms/adversarial/minimax.py` (`use_alpha_beta=True`) | Boss on planets 1, 4, 7, 10; AI vs AI fighters |
| Minimax, depth 4, no pruning | Adversarial | `ai_backend/algorithms/adversarial/minimax.py` (`use_alpha_beta=False`) | Boss on planets 2, 5, 8; AI vs AI fighters |
| MCTS (200 simulations, UCB1 c = 1.41) | Adversarial | `ai_backend/algorithms/adversarial/mcts.py` | Boss on planets 3, 6, 9; AI vs AI fighters |
| Fuzzy logic (3 inputs, 5 rules, centroid) | Other | `ai_backend/algorithms/fuzzy/engine.py` | Boss aggression 0 to 1 from player health, recent damage and distance; changes the boss's speed and attack rate slowly (boss loop step 3) |
| CSP (backtracking + forward checking) | Other | `ai_backend/algorithms/csp/solver.py` | Places 2 oxygen tanks, the safe dome, a health and an energy pickup at the start of each level |
| Forward chaining (5 rules) | Other | `ai_backend/algorithms/logic/engine.py` | `duel_won`, then `unlock_next_planet` after the boss; `low_health_warning` and `oxygen_warning` while playing |

**How it fits together**

- `scenes/star_brawl/arena_grid.gd` turns a level into tiles (the same rules for every agent): ground, platforms and walls are blocked, free tiles are the ones a fighter can reach. Moves go in 4 directions.
- Fuzzy logic: inputs `player_health`, `recent_damage` (damage taken in the last 5 s) and `distance` use triangle memberships (low / medium / high, or near / medium / far). The rules use AND = min, and the result is defuzzified with the centroid. Endpoint: `POST /fuzzy/aggression`.
- CSP: the variables are `oxygen_tank_1`, `oxygen_tank_2`, `safe_dome`, `health_pickup` and `energy_pickup`. The domain is the walkable floor tiles. The constraints are: not in a wall or hazard, not near aliens or the boss portal, at least 5 tiles apart, and at least one oxygen item in each third of the level. The answer is the positions plus the number of backtracks. Endpoint: `POST /csp/place`.
- Forward chaining fires IF-THEN rules until no new fact appears, and returns the new facts and the order the rules fired in. In AI vs AI the same engine also runs `defensive_mode`, `finisher_mode` and the referee rules. Endpoint: `POST /logic/infer`.
- `scripts/utils/path_planner.gd` sends the grid to `POST /pathfinding/find` asynchronously and falls back to the local A* if no answer arrives in time.
- `scenes/star_brawl/fighter_brain.gd` is the AI for one fighter. It searches a path on that grid and asks the backend for an action: `attack`, `block`, `dodge`, `move_closer`, `move_away` or `special`.
- The combat state used by Minimax and MCTS is in `ai_backend/algorithms/adversarial/combat_state.py`: `boss_hp`, `player_hp`, `distance`, `boss_energy`, `player_energy` and both cooldowns. One `apply_action()` holds the damage rules, and both algorithms use it. The evaluation rewards the boss keeping its health, the player losing health, and the boss staying at a good distance. Endpoint: `POST /adversarial/decide {algorithm, use_alpha_beta, state}`.

## Tests

```powershell
# Python: 7 path-finding algorithms, minimax (+ alpha-beta), MCTS, fuzzy, CSP, forward chaining
.\ai_backend\.venv\Scripts\python.exe -m pytest -q ai_backend\tests

# Godot: local A* + grid, a smoke test (both game modes, alien FSM, oxygen, items),
# and a full AI vs AI match at 4x that checks every algorithm was used
godot --headless --path . --import
godot --headless --path . res://tests/test_search.tscn
godot --headless --path . res://tests/test_game_modes.tscn
godot --headless --path . res://tests/test_ai_vs_ai.tscn
```

## Demo guide (about 5 minutes)

1. Run `launch_game_with_ai.bat`. Wait for the home screen; the backend window must stay open.
2. **AI vs AI** (start here):
   - Press **AI vs AI**. The setup screen should say **Python AI server: ONLINE**.
   - Keep the defaults (Minimax + alpha-beta vs MCTS, Rotate all 7) and press **Start Match**.
   - Press **P** to show the grid and the two paths, then **2** for 2x speed.
   - Point at the panels: the search algorithm changes every 10 s (the name above each head changes too). The decision line shows nodes and pruned nodes for alpha-beta, and win rate and simulations for MCTS. Aggression changes slowly. The FSM mode switches between CHASE, ATTACK, DEFEND and PICKUP.
   - Point at the rule log: CSP placing items, `defensive_mode` / `finisher_mode`, and pickups taken.
   - Press **Esc** to pause and explain, then **Esc** again to continue.
   - When the match ends (about 90 s, or 45 s at 2x), walk through the **result panel**. The path-finding table compares the 7 algorithms (IDDFS expands the most nodes, A* and Greedy the fewest, DFS gives the longest paths). The decision table shows how many nodes alpha-beta pruned. Below it: fuzzy updates, rules fired, CSP solves and FSM modes.
   - Optional: **Change Setup** then **Run 10 Matches**. That takes about 4 minutes at 4x and shows the win table and the CSV path.
3. **Player vs AI**:
   - Press **Home**, then **Player vs AI**, and pick planet 1. The briefing shows the boss AI (A* + Minimax+αβ).
   - In the level: the oxygen bar drains (pick up blue gems or stand in the safe dome). Aliens show their FSM state (press **F**), and press **P** to see their A* path when they chase you.
   - Go through the portal. The boss HUD shows `Boss: Minimax+αβ → attack | nodes …, pruned …`, the search line and `Aggression 0.xx`. After a special (red warning) the boss rests 1.5 s.
   - Planet 3 shows MCTS, and planet 2 shows Minimax without pruning.
4. If asked about tests: run `pytest` and the three Godot tests listed above.

If the server is not running, everything still works with fallbacks. The HUD shows `(local)` or `fallback`, and the AI vs AI setup screen shows OFFLINE.
