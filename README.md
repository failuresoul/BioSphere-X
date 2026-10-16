# BioSphere-X

A complete, 2D top-down sci-fi survival game set on alien exoplanets, powered by **Godot 4** and an asynchronous **Python AI Backend**.

---

## Table of Contents
1. [Overview & Project Journey](#overview--project-journey)
2. [How to Launch and Play](#how-to-launch-and-play)
3. [Controls & Keybindings](#controls--keybindings)
4. [Gameplay Systems & Player Guide](#gameplay-systems--player-guide)
5. [Algorithms Map & Implementation Guide](#algorithms-map--implementation-guide)
6. [AI vs AI Simulation Arena](#ai-vs-ai-simulation-arena)
7. [Project Directory Structure](#project-directory-structure)
8. [Automated Verification & Test Suites](#automated-verification--test-suites)
9. [System Audit & Known Limitations](#system-audit--known-limitations)

---

## Overview & Project Journey

BioSphere-X was designed and built from the ground up to unite polished real-time 60+ FPS sci-fi survival gameplay with classical and modern Artificial Intelligence algorithms. 

### Summary of Completed Journey (Prompts 1 – 30)
* **Prompt 1–3: Core Architecture & Player Mechanics** — Developed astronaut kinematics, 8-directional normalized movement, acceleration/friction damping, camera smoothing, and asynchronous HTTP client for Python AI integration.
* **Prompt 4–6: Procedural World Generation & Tile Systems** — Multi-tile terrain generator using simplex noise and cellular automata, classifying walkable crust, natural walls, rocks, and craters.
* **Prompt 7–9: Vitality & Survival Economy** — Atmospheric oxygen depletion, suffocation hazard, health damage/healing, energy weapons recharge, and collectable resource pickups with particle chimes.
* **Prompt 10–12: Multi-Algorithm Pathfinding & Navigation** — Implemented 7 distinct pathfinding algorithms in Python with native GDScript fallback, coordinate grid transformers, and line-of-sight raycasting.
* **Prompt 13–15: Alien Enemy Archetypes & State Machines** — Developed modular AI state machines (Idle, Patrol, Investigate, Chase, Attack, Dead) powering Scouts, Armored Brutes, and Ranged Spitters.
* **Prompt 16–18: Apex Boss AI & Adversarial Decision Making** — Created Goliath Prime with Minimax and Alpha-Beta Pruning tactical action selection, telegraph windup cones, and enrage thresholds.
* **Prompt 19–21: Dynamic Difficulty & Fuzzy Inference** — Integrated a Mamdani Fuzzy Inference System defuzzifying combat pressure, recent player damage, and distress signals to govern fair encounter multipliers.
* **Prompt 22–24: Base Building & CSP Layout Placement** — Developed Constraint Satisfaction Problem (CSP) solver enforcing spatial boundaries, clearance buffers, resource costs, and grid occupancy.
* **Prompt 25: Exoplanet Catalog & Progression** — Implemented real NASA/Caltech exoplanetary scientific catalog (TRAPPIST-1 e, LHS 1140 b, Kepler-452 b, etc.) with planetary unlocks and loading transitions.
* **Prompt 26: Logic-Based World Interactions** — Created a forward-chaining propositional production rule engine for atmospheric safe zones, sample unlock thresholds, and return terminal protocols.
* **Prompt 27: Natural Language Command Terminal** — Built an offline, zero-paid-dependency natural language parser extracting intents and slots for voice/typed astronaut commands with strict validation.
* **Prompt 28: Save/Load, Pause System & Menus** — Built versioned JSON save/load persistence, atomic file transactions, corruption recovery, and oxygen/timer pause freezing.
* **Prompt 29: Visuals, Procedural Audio, Accessibility & Performance** — Developed a 16-bit 22.05 kHz PCM procedural audio synthesizer (10 SFX + ambient space drone), enemy threat silhouette rims, camera screen shake, floating combat text, keyboard remapping, and sub-millisecond multi-enemy performance profiling.
* **Prompt 30: Final Integration, Release Verification & Polish** — Full project audit, unified AI vs AI Arena styling and audio feedback, comprehensive end-to-end player journey test suite, and release documentation.

---

## How to Launch and Play

### Prerequisites
1. **Godot Engine 4.x** (Standard official build, 4.0+)
2. **Python 3.10+** (Python 3.13 tested and supported)

---

### Step 1: Start the Python AI Backend (Recommended)
Open a terminal in the project directory:
```powershell
# Navigate to backend directory
cd ai_backend

# Activate virtual environment
.\.venv\Scripts\Activate.ps1    # On Windows PowerShell
# source .venv/bin/activate     # On Linux / macOS

# (Optional, first time) Install dependencies
pip install -r requirements.txt

# Start the FastAPI server on port 8000
uvicorn main:app --host 127.0.0.1 --port 8000 --reload
```
* Interactive API Documentation (Swagger UI): `http://127.0.0.1:8000/docs`
* Health Check Endpoint: `http://127.0.0.1:8000/health`

> **Note on Offline Operation**: If the Python backend is not started, BioSphere-X automatically degrades gracefully to internal GDScript algorithms (e.g. native A*, in-engine fuzzy logic, local CSP validator, built-in rule engine). Gameplay never crashes or freezes when offline.

---

### Step 2: Launch the Godot Game
* **Option A (Godot Editor)**: Open Godot 4, click **Import**, select `project.godot` in this repository, and press **F5** (Run Project).
* **Option B (Direct Console Executable)**:
  ```powershell
  # Windows Console Example:
  godot --path "e:\Ai Project"
  ```
* **Option C (Run in Headless Test Mode)**:
  ```powershell
  godot --headless --path "e:\Ai Project" --scene "res://tests/test_full_player_journey.tscn"
  ```

---

## Controls & Keybindings

All keybindings can be rebound directly in-game under **Main Menu -> Settings -> Controls** or **Pause Menu -> Settings**. Keybindings persist in `user://biosphere_x_settings.json`.

| Action | Default Key | Alternate Input | Description |
| :--- | :--- | :--- | :--- |
| **Move Up** | `W` | `Up Arrow` | Move astronaut north |
| **Move Down** | `S` | `Down Arrow` | Move astronaut south |
| **Move Left** | `A` | `Left Arrow` | Move astronaut west |
| **Move Right** | `D` | `Right Arrow` | Move astronaut east |
| **Attack / Fire Laser** | `Space` | `Left Mouse Button` | Fire plasma pulse rifle toward cursor |
| **Interact / Collect** | `E` | — | Harvest resources, activate consoles, enter airlocks |
| **Command Terminal** | `~` (Tilde / Backquote) | — | Toggle natural language astronaut CLI |
| **Inventory & Crafting** | `Tab` | — | Open suit storage, craft items, view upgrades |
| **Base Construction** | `B` | — | Open structure build catalog & placement grid |
| **Pause Game** | `Escape` | `P` | Pause world simulation, open settings & save menu |

---

## Gameplay Systems & Player Guide

### 1. Vitality & Survival
* **Oxygen (Cyan Bar)**: Consumed at 1.5 units/s during surface exploration. Warning alerts sound at $\le 25\%$. If oxygen reaches 0, you take 4.0 suffocation damage/s. Refill at atmospheric stations, oxygen canisters, or within Habitat Safe Zones.
* **Health (Crimson Bar)**: Decreases upon taking physical or venom attacks from xenomorphs. Restored using medical items or atmospheric regeneration. Reaching 0 triggers game over.
* **Energy (Yellow Bar)**: Powers your suit's plasma rifle. Depletes per shot and recharges automatically after a short delay.

### 2. Campaign Mission Progression
Expeditions follow a structured, story-driven progression sequence:
1. **Life Support Recovery**: Harvest oxygen cells from surface deposits to stabilize suit telemetry.
2. **Field Specimens**: Collect alien biomass and mineral samples from dangerous biomes.
3. **Outpost Override**: Discover and hack the abandoned scientific research terminal.
4. **Survive Alien Encounter**: Hold off aggressive xenomorph pressure waves.
5. **Goliath Protocol**: Track and neutralize the apex predator Goliath Prime.
6. **Expedition Extraction**: Return to the Habitat Module Airlock to secure planetary telemetry and unlock orbital transit.

### 3. Base Construction & Placement
Press **`B`** to open the structure catalog:
* **Photovoltaic Array (Solar)**: Restores auxiliary power and supplies energy grids.
* **Atmospheric Dome**: Projects an oxygenated sanctuary where oxygen consumption drops to zero.
* **Research Station**: Houses data terminals and unlocks advanced crafting tiers.
* **Defensive Barricade**: Blocks enemy line-of-sight and navigational pathfinding.
* *Placement Validation*: Placement conforms to strict territorial bounds, minimum structure clearances, and resource costs. Right-click or press `ESC` to cancel.

### 4. AI Command Terminal
Press **`~`** (Tilde) to open the tactical command line. The offline NLP parser understands natural language queries, such as:
* `"collect oxygen"` / `"refill oxygen"` — Replenishes suit oxygen from carried canisters or nearby stations.
* `"show inventory"` / `"check inventory"` — Displays current minerals, crystals, and canisters.
* `"check vitals"` / `"status report"` — Summarizes health, suit integrity, and oxygen reserves.
* `"return to base"` — Sets navigational trajectory to the Habitat Airlock (if outside combat).
* `"find research station"` — Locates the nearest terminal and sets a waypoint.
* `"help"` — Lists all recognized command patterns.

---

## Algorithms Map & Implementation Guide

BioSphere-X implements a wide array of core AI and Computer Science algorithms. Each algorithm is modularized, thoroughly tested, and mapped below:

### 1. Multi-Algorithm Pathfinding & Navigation
* **`A* Search (Optimal Euclidean & Manhattan)`**
  * *Implementation*: `ai_backend/algorithms/pathfinding/astar.py` and `scripts/components/map_data.gd`
  * *Where Used*: Standard enemy pathfinding, boss pursuit, and AI Arena Agent navigation.
* **`Greedy Best-First Search`**
  * *Implementation*: `ai_backend/algorithms/pathfinding/greedy_best_first.py`
  * *Where Used*: Fast exploration behavior; AI vs AI Arena comparison trials.
* **`Breadth-First Search (BFS)`**
  * *Implementation*: `ai_backend/algorithms/pathfinding/bfs.py`
  * *Where Used*: Unweighted shortest-hop verification and arena navigation benchmarking.
* **`Depth-First Search (DFS)`**
  * *Implementation*: `ai_backend/algorithms/pathfinding/dfs.py`
  * *Where Used*: Maze exploration testing and deep path branching studies.
* **`Depth-Limited Search (DLS)`**
  * *Implementation*: `ai_backend/algorithms/pathfinding/dls.py`
  * *Where Used*: Bounded tactical horizon path planning.
* **`Iterative Deepening DFS (IDDFS)`**
  * *Implementation*: `ai_backend/algorithms/pathfinding/iddfs.py`
  * *Where Used*: Memory-efficient complete search without heuristic bias.
* **`Bidirectional Search`**
  * *Implementation*: `ai_backend/algorithms/pathfinding/bidirectional.py`
  * *Where Used*: Dual-frontier simultaneous search between start and goal nodes.

### 2. Adversarial Decision-Making (Boss AI)
* **`Minimax Algorithm & Alpha-Beta Pruning`**
  * *Implementation*: `ai_backend/algorithms/adversarial/boss_adversarial.py`
  * *Connected In*: `scenes/enemies/boss_alien.gd`
  * *Where Used*: Goliath Prime evaluates future board states (player distance, health, cooldowns, arena cover) up to depth 4 to select optimal actions: Melee Smash, Venom Spit, Ground Slam, or Defensive Repositioning.

### 3. Dynamic Pacing & Adaptive Difficulty (FIS)
* **`Mamdani Fuzzy Inference System with Centroid Defuzzification`**
  * *Implementation*: `ai_backend/algorithms/fuzzy/fuzzy_difficulty.py`
  * *Connected In*: `scripts/autoloads/difficulty_controller.gd`
  * *Where Used*: Reads continuous input variables (`player_health`, `recent_damage`, `enemy_distance`, `repeated_failures`), evaluates 11 fuzzy inference rules, and defuzzifies into aggression multipliers (0.35x to 1.40x) governing enemy movement speed, attack damage, and cooldown intervals.

### 4. Constraint Satisfaction Problem (CSP Base Construction)
* **`Backtracking Search with Forward Checking & MRV (Minimum Remaining Values)`**
  * *Implementation*: `ai_backend/algorithms/csp/placement_csp.py`
  * *Connected In*: `scripts/components/placement_constraint_validator.gd` and `scripts/autoloads/construction_manager.gd`
  * *Where Used*: Evaluates structure placement candidates against economic constraints, map boundaries, natural obstacles, cell overlaps, and minimum spacing buffers before allowing placement.

### 5. Knowledge Representation & Production Rules
* **`Forward-Chaining Inference Engine`**
  * *Implementation*: `ai_backend/algorithms/logic/rule_inference.py`
  * *Connected In*: `scripts/autoloads/game_rule_engine.gd`
  * *Where Used*: Operates on explicit world facts (`player_in_safe_zone`, `oxygen_ratio`, `samples_collected`, `boss_defeated`) to derive gameplay conclusions: suppressing low oxygen alarms in domes, unlocking extraction objectives, and enabling return airlock consoles.

### 6. Natural Language Processing (Command Parsing)
* **`Offline Intent Classification & Slot Extraction`**
  * *Implementation*: `ai_backend/algorithms/nlp/command_parser.py`
  * *Connected In*: `ui/components/command_terminal.gd`
  * *Where Used*: Tokenizes and normalizes typed inputs, matches regular expressions and synonym sets, handles ambiguous words with clarifying suggestions, and outputs structured intent payloads to the game engine.

### 7. Digital Signal Processing (Procedural Audio Synthesizer)
* **`16-Bit 22.05 kHz PCM Waveform Synthesis`**
  * *Implementation*: `scripts/autoloads/audio_manager.gd`
  * *Where Used*: Generates zero-dependency sound effects (`laser_fire`, `laser_hit`, `player_hurt`, `enemy_death`, `pickup`, `oxygen_warning`, `mission_complete`, `ui_click`, `build`, `demolish`) and looping 55 Hz/110 Hz atmospheric drone audio purely in memory without external audio files.

---

## AI vs AI Simulation Arena

Launch directly from the **Main Menu -> AI vs AI Arena** (`scenes/ai_vs_ai/ai_arena.tscn`).

The Simulation Arena offers an experimental proving ground with identical sci-fi HUD styling to the main game:
* **Scenarios**:
  * *Pursuit & Combat*: Agents navigate obstacles, maintain tactical spacing, and engage in ranged plasma combat.
  * *Race to Objective*: Symmetrical competition to reach a pulsing central data beacon through maze corridors.
* **Algorithm Selection**: Independently assign any of the 7 pathfinding algorithms to Agent A and Agent B.
* **Fair Comparison Tools**: Toggle **Swap Spawns** to invert starting quadrants; fix the random seed for deterministic reproducibility.
* **Live Telemetry & Floating Combat Text**: Real-time display of nodes expanded, computation time in milliseconds, distance traveled, damage dealt, and floating damage numbers.
* **Data Export**: Export match metrics to structured **JSON** and **CSV** files in `user://experiments/`.

---

## Project Directory Structure

```
BioSphere-X/
├── ai_backend/                       # Python AI Lab Backend Service
│   ├── algorithms/                   # Modular algorithmic implementations
│   │   ├── adversarial/              # Minimax & Alpha-Beta Pruning (Boss AI)
│   │   ├── csp/                      # Constraint Satisfaction Problem (Base Building)
│   │   ├── fuzzy/                    # Mamdani Fuzzy Inference System (Difficulty)
│   │   ├── logic/                    # Forward-Chaining Propositional Rule Engine
│   │   ├── nlp/                      # Offline Command Parser & Slot Extractor
│   │   ├── pathfinding/              # 7 Pathfinding Algorithms & Navigation Router
│   │   └── planning/                 # Automated GOAP / STRIPS Planning
│   ├── tests/                        # 121 Pytest Automated Tests
│   ├── main.py                       # FastAPI Application Entry Point
│   └── requirements.txt              # Python Dependencies
│
├── data/                             # Game Configurations & Catalogs
│   ├── exoplanets.json               # NASA/Caltech Scientific Exoplanet Catalog
│   ├── base_structures.json          # Construction Catalog & Dimensions
│   └── craftable_items.json          # Crafting Recipes & Item Blueprints
│
├── scenes/                           # Godot 4 Game Scenes
│   ├── ai_vs_ai/                     # Autonomous Arena & Agents (ai_arena.tscn)
│   ├── enemies/                      # Scout, Brute, Spitter, and Goliath Boss
│   ├── main/                         # Main Menu, Settings Dialog, Entry Scene
│   ├── player/                       # Astronaut Player & Camera
│   └── world/                        # Procedural Game World & Biome Maps
│
├── scripts/                          # GDScript Core Logic
│   ├── autoloads/                    # Game Singletons
│   │   ├── ai_client.gd              # Asynchronous HTTP AI Client
│   │   ├── audio_manager.gd          # Procedural 16-Bit PCM Audio Synthesizer
│   │   ├── construction_manager.gd   # Base Building Placement Manager
│   │   ├── difficulty_controller.gd  # Adaptive Difficulty & Fuzzy Multipliers
│   │   ├── exoplanet_database.gd     # Scientific Exoplanet Data Service
│   │   ├── game_rule_engine.gd       # Forward-Chaining World Rule Engine
│   │   ├── game_state.gd             # Vitality, Oxygen, Resources & Pause Bus
│   │   ├── inventory_manager.gd      # Suit Storage & Crafting Authority
│   │   ├── mission_manager.gd        # Campaign Objectives & Telemetry
│   │   ├── navigation_manager.gd     # Spatial Grid & Navigation Routing
│   │   ├── planet_progression_manager.gd # Planetary Unlocks & Transitions
│   │   └── save_manager.gd           # Versioned Persistence & Settings
│   └── components/                   # Reusable Component Nodes
│       ├── collectable_resource.gd   # Interactive Resource Pickups
│       ├── floating_combat_text.gd   # Animated Combat Floating Numbers
│       ├── health_component.gd       # Vitality & Damage Mitigation
│       ├── map_data.gd               # 2D Grid Cell Classification
│       ├── placement_constraint_validator.gd # In-Engine CSP Validator
│       └── weapon_component.gd       # Plasma Pulse Rifle Controller
│
├── ui/                               # User Interface Components & Screens
│   ├── components/                   # Command Terminal, Construction & Inventory
│   └── screens/                      # Main HUD, Level Loading, Planet Selection
│
├── tests/                            # Automated Headless Test Suites (30+ Suites)
│   ├── test_full_player_journey.tscn # End-to-End Complete Player Journey Test
│   ├── test_polish_and_performance.tscn # Multi-Enemy Stress & Audio Test
│   ├── test_save_load_pause.tscn     # Persistence & Pause Freezing Test
│   ├── test_command_parser.tscn      # Offline NLP Command Terminal Test
│   ├── test_logic_world_interactions.tscn # Production Rule World Test
│   └── test_ai_vs_ai.tscn            # AI vs AI Arena Lifecycle Test
│
├── project.godot                     # Godot 4 Project Configuration File
└── README.md                         # Project Documentation
```

---

## Automated Verification & Test Suites

The project features a comprehensive test suite with 100% test pass rate across both Python and Godot.

### 1. Python Backend Pytest Suite
Run from the root directory:
```powershell
.\ai_backend\.venv\Scripts\python.exe -m pytest ai_backend/tests/
```
* **Results**: `121 passed in 1.01s` (adversarial, csp, fuzzy, nlp_parser, pathfinding, rule_engine).

### 2. Complete Player Journey Test (Prompt 30)
```powershell
godot --headless --path "e:\Ai Project" --scene "res://tests/test_full_player_journey.tscn"
```
* **Results**: `39 / 39 Passed, 0 Failed` (Movement, Resources, Oxygen/Health, Missions, Combat, Base Building, Planet Unlocks, Save/Quit/Reload Roundtrip).

### 3. Polish, Audio & Performance Test (Prompt 29)
```powershell
godot --headless --path "e:\Ai Project" --scene "res://tests/test_polish_and_performance.tscn"
```
* **Results**: `50 / 50 Passed, 0 Failed` (Synthesized PCM buffers, voice pooling, threat silhouettes, screen shake, keyboard remapping, and 15-enemy stress benchmark at 0.14 ms/frame).

### 4. Save/Load, Pause & Menus Test (Prompt 28)
```powershell
godot --headless --path "e:\Ai Project" --scene "res://tests/test_save_load_pause.tscn"
```
* **Results**: `46 / 46 Passed, 0 Failed` (Schema validation, corrupt file recovery, non-duplication of structures, pause oxygen freeze).

### 5. AI Command Terminal Test (Prompt 27)
```powershell
godot --headless --path "e:\Ai Project" --scene "res://tests/test_command_parser.tscn"
```
* **Results**: `73 / 73 Passed, 0 Failed` (Structured intent extraction, safety guarantees, ambiguous word clarification).

### 6. Logic-Based World Interactions Test (Prompt 26)
```powershell
godot --headless --path "e:\Ai Project" --scene "res://tests/test_logic_world_interactions.tscn"
```
* **Results**: `47 / 47 Passed, 0 Failed` (Sanctuary dome oxygen protection, sample quota unlock, boss item terminal gate).

### 7. AI vs AI Simulation Arena Test
```powershell
godot --headless --path "e:\Ai Project" --scene "res://tests/test_ai_vs_ai.tscn"
```
* **Results**: `8 / 8 Passed, 0 Failed` (Pursuit combat, race to objective, spawn swapping, JSON/CSV export).

---

## System Audit & Known Limitations

### Fully Functional Systems
* **Complete Player Journey**: Exploring, resource gathering, vitals maintenance, combat, mission progression, structure placement, exoplanet star map unlocks, and save/load persistence all verified working end-to-end.
* **Graceful Degradation**: Game operates with or without the Python backend active.
* **Procedural Sound**: Full sound effects and looping ambient music synthesize natively in code without missing external files.
* **Keyboard Remapping & Settings**: Rebinding keys dynamically updates Godot's `InputMap` and persists across game restarts.
* **AI vs AI Arena**: Complete head-to-head benchmarking environment with matching sci-fi UI styling, audio feedback, and data export.

### Known Limitations
* **Audio in Headless Mode**: When running Godot with the `--headless` flag on Linux/Windows servers, audio output hardware is bypassed by Godot's dummy audio driver; procedural audio buffers synthesize in memory and emit signals properly, but physical sound output requires running in standard graphical mode.
* **Display Resolution Scaling**: Changing the display resolution setting in the options menu applies in windowed mode; when Fullscreen mode is toggled, display sizing is managed directly by the operating system display server.
* **Single Active Command Terminal**: The command terminal is designed for single-operator typed natural language input; concurrent network terminal sessions are not supported.
