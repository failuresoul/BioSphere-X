# BioSphere X

BioSphere X is a 2D space platform fighting game. Choose a human pilot in space armor, follow the Horizon Ark's distress signal across ten planet chapters, and fight an AI guardian at the end of each one. The playable project is the Godot scene [`scenes/star_brawl/star_brawl.tscn`](scenes/star_brawl/star_brawl.tscn), configured as the main scene in [`project.godot`](project.godot).

## Requirements

- **Godot 4** with the standard (non-.NET) editor. The project was tested with Godot **4.7.2** and uses its Compatibility renderer.
- **Python** and `pip` for the local AI service. The setup below was tested with Python **3.13**.
- **Windows** for the supplied one-click launcher. The Godot project and Python backend can also be started manually on other desktop systems.

The game assets are included. No account or API key is needed. Godot talks to the Python AI service at `http://127.0.0.1:8000` on your own computer.

## Install and run on Windows

1. Install [Godot for Windows](https://godotengine.org/download/windows/) and [Python for Windows](https://www.python.org/downloads/windows/) if they are not installed. With Windows Package Manager, the tested major versions can be installed using:

   ```powershell
   winget install --id GodotEngine.GodotEngine --exact
   winget install --id Python.Python.3.13 --exact
   ```

2. Open PowerShell in the folder containing this README. Create the backend environment and install its dependencies once:

   ```powershell
   py -3.13 -m venv ai_backend\.venv
   .\ai_backend\.venv\Scripts\python.exe -m pip install -r ai_backend\requirements.txt
   ```

   If `py -3.13` is unavailable but `python` runs your installed Python, use `python -m venv ai_backend\.venv` for the first command.

3. Launch both the AI service and game:

   ```powershell
   .\launch_game_with_ai.bat
   ```

The launcher reuses a running backend or starts [`start_ai_backend.bat`](start_ai_backend.bat), then opens Godot. Keep the backend window open while playing. To check it, open `http://127.0.0.1:8000/health`; it should report `"status":"ok"` and `"service":"BioSphere-X AI Backend"`. Interactive API documentation is at `http://127.0.0.1:8000/docs`.

### Run the two processes manually

From the project root, start the backend in one terminal:

```powershell
.\ai_backend\.venv\Scripts\python.exe -m uvicorn ai_backend.main:app --host 127.0.0.1 --port 8000
```

In a second terminal, run `godot --path .`, or import [`project.godot`](project.godot) in the Godot editor and press **F5**. If `godot` is not on your `PATH`, use the path to your Godot executable. On Linux or macOS, create a Python virtual environment with `python3 -m venv ai_backend/.venv`, install `ai_backend/requirements.txt`, start the same Uvicorn module with that environment's Python, then open the Godot project.

The AI service is required for the complete campaign: it confirms boss victories and supplies boss decisions, adaptive difficulty, CSP pickup placement, and command parsing. The game tries to start the service when launched directly, but the Windows launcher or the manual two-terminal method is the reliable setup.

## How to play

The flow is **Home → Planet Map → Level Preview → Exploration → Boss Portal → Boss Fight → Result → Upgrade/Next Planet**. Home has **Play**, **Guide**, **Settings**, pilot selection, a confirmed **Restart**, and **Exit Game** at the top right.

- Select one of three armored human pilots. Your selection is saved.
- Clear ten story chapters based on catalogued exoplanets. The map and level previews show each planet's radius and orbital period from NASA's Exoplanet Catalog; the terrain, colors, story, and enemies are fictional game art. Source URLs for each planet are in [`planet_facts.gd`](scenes/star_brawl/planet_facts.gd).
- Cross a scrolling 3,000-pixel level with alien patrols, platforms, and planet-specific hazards. Enter the portal near the end to reach a separate boss arena.
- Fight ten distinct, progressively larger and faster guardians. Each has a different telegraphed special attack and a character built from downloaded sprite assets.
- A victory unlocks the next chapter and awards one to three stars based on remaining health. A first clear offers **Armor** (+25 maximum health), **Power** (+5 attack damage), or **Flux** (+35 movement speed and energy).
- Replay cleared planets for a better star rating. Settings, pilot choice, stars, unlocks, and upgrades persist between runs.

| Control | Action |
| --- | --- |
| `A` / `D` or left / right arrows | Move |
| `Space`, `W`, or up arrow | Jump; jump again for a double jump, or land on an enemy to stomp |
| `J` | Close strike |
| `K` | Star blaster |
| `Shift` | Dash |
| `E` | Orbit Pulse when the meter reaches 70 |
| `Q` | Cycle suit modes: attack, guard, heal |
| `Tab` | Type a suit command such as `attack`, `defend`, `heal`, or `status` |
| `Esc` | Pause, resume, or go back from a menu |

The pause menu also offers **Restart Planet**, **Galaxy Map**, and **Home**.

## Where the algorithms are implemented

The active game is [`star_brawl.gd`](scenes/star_brawl/star_brawl.gd). It calls local Godot code for boss navigation and the Python service through [`ai_client.gd`](scripts/autoloads/ai_client.gd) for the other AI systems. The service entry point is [`ai_backend/main.py`](ai_backend/main.py).

| Algorithm | Implementation | Use in the current game |
| --- | --- | --- |
| A* search | [`modular_pathfinder.gd`](scripts/utils/modular_pathfinder.gd); Python version [`astar.py`](ai_backend/algorithms/pathfinding/astar.py) | Boss navigation; also the fallback if another route search cannot find a path. |
| Breadth-first search (BFS) | [`modular_pathfinder.gd`](scripts/utils/modular_pathfinder.gd); [`bfs.py`](ai_backend/algorithms/pathfinding/bfs.py) | One of the rotating boss route searches. |
| Depth-first search (DFS) | [`modular_pathfinder.gd`](scripts/utils/modular_pathfinder.gd); [`dfs.py`](ai_backend/algorithms/pathfinding/dfs.py) | Rotating boss route search. |
| Depth-limited search (DLS) | [`modular_pathfinder.gd`](scripts/utils/modular_pathfinder.gd); [`dls.py`](ai_backend/algorithms/pathfinding/dls.py) | Rotating boss route search with a depth limit. |
| Iterative deepening DFS (IDDFS) | [`modular_pathfinder.gd`](scripts/utils/modular_pathfinder.gd); [`iddfs.py`](ai_backend/algorithms/pathfinding/iddfs.py) | Rotating boss route search with short lookahead to avoid long frame stalls. |
| Bidirectional search | [`modular_pathfinder.gd`](scripts/utils/modular_pathfinder.gd); [`bidirectional.py`](ai_backend/algorithms/pathfinding/bidirectional.py) | Rotating boss route search from both ends. |
| Greedy best-first search | [`modular_pathfinder.gd`](scripts/utils/modular_pathfinder.gd); [`greedy.py`](ai_backend/algorithms/pathfinding/greedy.py) | Rotating heuristic boss route search. |
| Alpha-beta pruning | [`alpha_beta.py`](ai_backend/algorithms/adversarial/alpha_beta.py) | Boss action decisions on chapters 1, 4, 7, and 10. |
| Minimax | [`minimax.py`](ai_backend/algorithms/adversarial/minimax.py) | Boss action decisions on chapters 2, 5, and 8. |
| Monte Carlo tree search (MCTS) | [`mcts.py`](ai_backend/algorithms/adversarial/mcts.py) | Boss action decisions on chapters 3, 6, and 9. |
| Fuzzy inference | [`engine.py`](ai_backend/algorithms/fuzzy/engine.py), [`membership.py`](ai_backend/algorithms/fuzzy/membership.py), [`rules.py`](ai_backend/algorithms/fuzzy/rules.py) | Adjusts boss aggression and movement speed from player health, recent damage, and distance. |
| Constraint satisfaction (CSP) | [`solver.py`](ai_backend/algorithms/csp/solver.py) | Finds a legal position for the exploration arena's health and energy pickup. |
| Forward-chaining rules | [`engine.py`](ai_backend/algorithms/logic/engine.py) | Confirms `duel_won` after the boss falls and the player is alive, allowing the result and unlock. |
| Natural language command parsing | [`parser.py`](ai_backend/algorithms/nlp/parser.py) | Interprets typed suit mode and status commands. Simple attack/guard/heal keyword handling remains if the service does not answer. |

The rotating route searches run in Godot via `star_brawl.gd::_plan_rival_route()`. The matching Python pathfinding implementations are available through the API and are covered by backend tests, but **the current boss navigation does not call that Python endpoint**. Boss action choices are requested in `_request_boss_decision()`, fuzzy aggression in `_request_adaptive_difficulty()`, CSP placement in `_request_pickup_location()`, rule inference in `_on_knockout()`, and NLP in `_on_order_submitted()`. Chapter-specific special attacks are scripted in `BOSS_SPECIALS` and `_resolve_boss_special()`; they are separate from the search and decision algorithms.

Older prototype guides in this repository describe 3D/base-building or AI-vs-AI features that are not in the current main scene. In particular, GOAP/STRIPS planning is only a package placeholder in [`ai_backend/algorithms/planning`](ai_backend/algorithms/planning/__init__.py), and Theta*, Dijkstra, and JPS are not used by this 2D campaign.

## Project layout and saved data

| Location | Purpose |
| --- | --- |
| [`scenes/star_brawl/`](scenes/star_brawl/star_brawl.gd) | Current game screens, fighters, bosses, levels, planets, and progression. |
| [`scripts/utils/modular_pathfinder.gd`](scripts/utils/modular_pathfinder.gd) | Local seven-algorithm navigation used during boss fights. |
| [`scripts/autoloads/ai_client.gd`](scripts/autoloads/ai_client.gd) | Godot HTTP bridge to the local AI service. |
| [`ai_backend/algorithms/`](ai_backend/algorithms/__init__.py) | Python decision, fuzzy, CSP, rule, NLP, and pathfinding implementations. |
| [`assets/star_brawl/`](assets/star_brawl/ASSET_CREDITS.md) | Bundled sprites, boss parts, audio, and asset credits. |
| [`tests/test_star_brawl.tscn`](tests/test_star_brawl.tscn) and [`ai_backend/tests/`](ai_backend/tests/test_api.py) | Game-flow and Python backend tests. |

Godot saves campaign progress to `user://orbit_breakers_progress.cfg` and sound/fullscreen settings to `user://biosphere_x_settings.cfg`. On Windows, `user://` normally resolves under `%APPDATA%\Godot\app_userdata\BioSphere X\`. Use **Restart** on Home to reset campaign progress through the in-game confirmation; the selected pilot is kept.

## Run the tests

From the project root after installing dependencies:

```powershell
.\ai_backend\.venv\Scripts\python.exe -m pytest -q ai_backend\tests
godot --headless --path . res://tests/test_star_brawl.tscn
```

Use the full path to the Godot executable for the second command if `godot` is not on your `PATH`. The Godot test runs the home, map, portal, boss, result, upgrade, ten-chapter progression, and restart flows. The Python suite covers the service and algorithm modules.

## Troubleshooting

- **Godot is not found:** install it or open `project.godot` from the Godot editor. The Windows launcher searches `PATH` and WinGet's package directory.
- **Backend fails to start:** rerun the dependency installation command, then run the manual Uvicorn command to see its error. Check that `http://127.0.0.1:8000/health` identifies the BioSphere-X service and that port 8000 is free.
- **A fallen boss does not open the result screen:** check the backend health endpoint. Victory confirmation requires the Python forward-chaining rule engine. Restart the planet from Pause after restoring the service.
- **New artwork is missing in the editor:** open the project in Godot once so it can import the bundled PNG files, then run it again.

Art and audio licenses are documented in [`assets/star_brawl/ASSET_CREDITS.md`](assets/star_brawl/ASSET_CREDITS.md).
