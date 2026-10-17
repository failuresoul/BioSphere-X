# BioSphere-X

A complete, 2D top-down sci-fi survival game set on alien exoplanets, powered by **Godot 4** and an asynchronous **Python AI Backend**.

---

## Table of Contents
1. [Project Overview & Architectural Milestones](#project-overview--architectural-milestones)
2. [Prerequisites & Quick Start](#prerequisites--quick-start)
3. [Master Controls & Keybindings](#master-controls--keybindings)
4. [How to Play: AI vs Player Mode (Complete Survival Guide)](#how-to-play-ai-vs-player-mode-complete-survival-guide)
5. [How to Play: AI vs AI Simulation Arena (Complete Benchmarking Guide)](#how-to-play-ai-vs-ai-simulation-arena-complete-benchmarking-guide)
6. [Algorithms Map & Implementation Reference](#algorithms-map--implementation-reference)
7. [Project Directory Structure](#project-directory-structure)
8. [Automated Verification & Test Suites](#automated-verification--test-suites)
9. [System Audit & Technical Specifications](#system-audit--technical-specifications)

---

## Project Overview & Architectural Milestones

BioSphere-X unites a real-time, responsive 60+ FPS sci-fi survival experience with classical and modern Artificial Intelligence algorithms. The application operates via a decoupled architecture:

* **Godot 4 Frontend**: Handles 2D graphics rendering, kinematics physics, player controls, audio synthesis, camera screen shake, UI dialogs, and local game state.
* **Python FastAPI AI Backend**: An asynchronous analytical microservice providing algorithmic computation for pathfinding, adversarial boss decision trees, fuzzy difficulty pacing, constraint satisfaction layout, natural language processing, and automated planning.
* **Offline Resilience**: If the Python backend is offline, the game automatically falls back to internal GDScript implementations with zero stutter, freezes, or crashes.

### Development Milestones Overview
* **Milestone 1: Core Architecture & Player Kinematics** — Developed astronaut movement physics with normalized diagonal velocity, acceleration/friction damping, camera smoothing, and asynchronous HTTP client communication.
* **Milestone 2: Procedural World Generation & Tile Systems** — Multi-tile terrain generator using simplex noise and cellular automata, classifying walkable crust, natural walls, rocks, and crater hazards.
* **Milestone 3: Vitality & Survival Economy** — Atmospheric oxygen depletion, suffocation damage, health restoration, energy weapons recharge, and collectable resource pickups with particle effects.
* **Milestone 4: Multi-Algorithm Pathfinding & Navigation** — Implemented 7 pathfinding algorithms in Python with native GDScript fallback, coordinate grid transformers, and line-of-sight raycasting.
* **Milestone 5: Alien Enemy Archetypes & State Machines** — Developed modular AI state machines (Idle, Patrol, Investigate, Chase, Attack, Dead) powering Scouts, Armored Brutes, and Ranged Spitters.
* **Milestone 6: Apex Boss AI & Adversarial Decision Making** — Created Goliath Prime with Minimax and Alpha-Beta Pruning action selection, telegraph windup cones, and enrage phases.
* **Milestone 7: Dynamic Difficulty & Fuzzy Inference** — Integrated a Mamdani Fuzzy Inference System defuzzifying combat pressure, recent player damage, and distress signals to govern fair encounter multipliers.
* **Milestone 8: Base Building & CSP Layout Placement** — Developed Constraint Satisfaction Problem (CSP) solver enforcing spatial boundaries, clearance buffers, resource costs, and grid occupancy.
* **Milestone 9: Exoplanet Catalog & Progression** — Implemented real NASA/Caltech exoplanetary scientific catalog (TRAPPIST-1 e, LHS 1140 b, Kepler-452 b, etc.) with planetary unlocks and loading transitions.
* **Milestone 10: Logic-Based World Interactions** — Created a forward-chaining propositional production rule engine for atmospheric safe zones, sample unlock thresholds, and return terminal protocols.
* **Milestone 11: Natural Language Command Terminal** — Built an offline, zero-paid-dependency natural language parser extracting intents and slots for voice/typed astronaut commands with strict validation.
* **Milestone 12: Save/Load, Pause System & Menus** — Built versioned JSON save/load persistence, atomic file transactions, corruption recovery, and oxygen/timer pause freezing.
* **Milestone 13: Visuals, Procedural Audio, Accessibility & Performance** — Developed a 16-bit 22.05 kHz PCM procedural audio synthesizer (10 SFX + ambient space drone), enemy threat silhouette rims, camera screen shake, floating combat text, keyboard remapping, and sub-millisecond multi-enemy performance profiling.
* **Milestone 14: Final Integration & Release-Ready Verification** — Full project audit, unified AI vs AI Arena styling and audio feedback, comprehensive end-to-end player journey test suite, and release documentation.

---

## Prerequisites & Quick Start

### System Requirements
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
* **Interactive API Documentation (Swagger UI)**: `http://127.0.0.1:8000/docs`
* **Health Check Endpoint**: `http://127.0.0.1:8000/health`

> **Note on Offline Operation**: If the Python backend is not started, BioSphere-X automatically degrades gracefully to internal GDScript algorithms (e.g. native A*, in-engine fuzzy logic, local CSP validator, built-in rule engine). Gameplay never crashes or freezes when offline.

---

### Step 2: Launch the Godot Game
* **Option A (Godot Editor)**: Open Godot 4, click **Import**, select `project.godot` in this repository, and press **F5** (Run Project).
* **Option B (Direct Console Executable)**:
  ```powershell
  godot --path "e:\Ai Project"
  ```
* **Option C (Run in Headless Test Mode)**:
  ```powershell
  godot --headless --path "e:\Ai Project" --scene "res://tests/test_full_player_journey.tscn"
  ```

---

## Master Controls & Keybindings

All keybindings can be customized in-game under **Main Menu -> Settings -> Controls** or **Pause Menu -> Settings**. Keybindings persist in `user://biosphere_x_settings.json`.

| Action | Primary Input | Secondary Input | In-Game Purpose |
| :--- | :--- | :--- | :--- |
| **Move Up** | `W` | `Up Arrow` | Move astronaut north across surface |
| **Move Down** | `S` | `Down Arrow` | Move astronaut south across surface |
| **Move Left** | `A` | `Left Arrow` | Move astronaut west across surface |
| **Move Right** | `D` | `Right Arrow` | Move astronaut east across surface |
| **Attack / Fire Rifle** | `Space` | `Left Mouse Button` | Fire plasma pulse rifle toward mouse cursor |
| **Interact / Collect** | `E` | — | Harvest resources, activate consoles, enter airlocks |
| **Command Terminal** | `~` (Tilde / Backquote) | — | Open natural language tactical command line |
| **Inventory & Crafting** | `Tab` | — | Open suit storage, craft items, view upgrades |
| **Base Construction** | `B` | — | Open structure build catalog & placement grid |
| **Pause Game** | `Escape` | `P` | Pause world simulation, open settings & save menu |

---

## How to Play: AI vs Player Mode (Complete Survival Guide)

### 1. Game Start & The Main Menu
When launching BioSphere-X, the Main Menu offers:
* **New Game**: Initializes a new expedition starting on the habitable exoplanet **TRAPPIST-1 e**.
* **Continue**: Loads your saved expedition (vitals, inventory, missions, structures, and planet progression).
* **AI vs AI Simulation Arena**: Opens the autonomous multi-agent proving grounds.
* **Settings**: Adjust Master/SFX/Ambient audio volumes, window resolution, fullscreen, screen shake, difficulty mode, and keybindings.
* **Quit**: Safely exits the game.

---

### 2. HUD & Vitality Telemetry
Upon entering the planetary world, your Heads-Up Display provides real-time survival readouts:
* **Suit Oxygen (Cyan Bar, Top Left)**:
  * Oxygen constantly depletes at `1.5 units/second` during surface exploration.
  * If reserves drop below `25%`, an audio alarm sounds and visual warning flashes occur.
  * If reserves reach `0%`, you suffer `4.0 suffocation damage/second`.
  * **Replenishment**: Harvest cyan Oxygen Canisters with `E`, use oxygen cells from inventory, enter an Atmospheric Dome base structure, or return to the Habitat Airlock.
* **Suit Integrity / Health (Crimson Bar, Top Left)**:
  * Decreases when struck by xenomorph melee strikes or acid projectiles.
  * Screen shake and directional trauma flash indicate incoming damage.
  * Restored using medical items, crafted nanite injectors, or resting inside base modules.
  * Reaching `0 HP` triggers game over.
* **Weapon Energy (Yellow Bar, Top Left)**:
  * Powers your plasma pulse rifle. Each discharge consumes energy.
  * Weapon recharge begins automatically after a brief pause (`0.35s`).
* **Resource Inventory Counters (Top Center)**:
  * Displays carried quantities of Energy Crystals, Titanium Alloy, Alien Biomass, and Oxygen Cells.
* **Mission Objectives Tracker (Top Right)**:
  * Displays your active expedition directive, progress percentage, and waypoint guidance.

---

### 3. Surface Exploration & Resource Harvesting
Wander the procedural alien terrain using `W`, `A`, `S`, `D`. Glowing surface items can be harvested by approaching them and pressing **`E`**:
* **Energy Crystals (Magenta Glow)**: Power base modules and advanced plasma weapon crafting.
* **Titanium Alloy (Amber Glow)**: Essential structural metal for base construction and barricades.
* **Scientific Biomass (Emerald Glow)**: Alien flora and fauna specimens required for research progression.
* **Oxygen Cells (Cyan Glow)**: Restores `30.0` units of suit oxygen immediately upon harvest.

---

### 4. Combat Tactics & Enemy Archetypes
Aim with your mouse cursor and fire plasma bolts with `Space` or `Left Mouse Button`. Enemies exhibit distinct behaviors and visual threat silhouettes:
* **Scout (Neon Lime/Amber Arc)**:
  * Fast, agile predator with high movement speed.
  * Attempts to flank the astronaut and perform rapid melee bites.
  * *Tactic*: Keep moving backward (kiting) and fire quick pulses before it closes distance.
* **Armored Brute (Crimson Carapace Arc)**:
  * Large, heavily armored creature with high health and knockback resistance.
  * Features a heavy ground slam attack with an area-of-effect telegraph cone.
  * *Tactic*: Maintain distance; do not trade melee hits. Bait its slam animation, then punish during its recovery cooldown.
* **Ranged Spitter (Cyan Venom Halo)**:
  * Stationary or slow-moving artillery alien with bioluminescent acid glands.
  * Fires ballistic acid globs that travel toward the player's predicted position.
  * *Tactic*: Dodge perpendicular to the incoming acid trajectory and eliminate from mid-range.
* **Goliath Prime (Apex Boss)**:
  * Neutralizing Goliath Prime is required in the late campaign.
  * Controlled by a **Minimax / Alpha-Beta Pruning decision tree** that predicts player maneuvers 4 moves ahead.
  * Uses sweeping melee strikes, shockwave stomps, and acid bombardments. Enters an enrage phase below 40% HP.
  * *Tactic*: Utilize natural wall pillars as cover to absorb ranged projectiles and kite around chokepoints.

---

### 5. Base Construction & Fortification
Press **`B`** to enter Construction Mode. A holographic placement blueprint appears:
* **Structure Catalog**:
  * **Photovoltaic Array (Solar)**: Restores base power and auxiliary energy reserves.
  * **Atmospheric Dome**: Projects an oxygenated sanctuary dome. Inside this radius, suit oxygen consumption is **completely halted**, and reserves recharge safely.
  * **Research Outpost**: Contains scientific terminals that decrypt planetary data.
  * **Defensive Barricade**: Physical fortifications that block hostile line-of-sight and navigational pathfinding.
* **Placement Rules**:
  * **Green Blueprint**: Valid placement satisfying all spatial, domain, and economic constraints. Click `Left Mouse Button` to construct.
  * **Red Blueprint**: Invalid placement. The floating tooltip explains the violation (e.g. *Insufficient Resources*, *Terrain Obstacle*, *Outside Authorized Build Zone*, or *Too Close to Existing Structure*).
  * Right-click or press `ESC` to exit construction mode.
  * Press **Demolish Mode** to dismantle existing structures and recoup `50%` of construction materials.

---

### 6. Natural Language Tactical Command Terminal
Press **`~`** (Tilde) to open the in-game command terminal. You can type natural-language instructions; the built-in offline NLP parser interprets your intent safely:
* `"collect oxygen"` / `"refill oxygen"` — Safely replenishes suit oxygen from carried canisters or nearby stations.
* `"show inventory"` / `"check inventory"` — Summarizes all resources and crafted components in suit storage.
* `"check vitals"` / `"status report"` — Reports exact numeric health, oxygen, and energy status.
* `"return to base"` — Calculates and sets navigation trajectory toward the Habitat Airlock (only allowed when out of combat).
* `"find research station"` — Scans map telemetry and sets a waypoint to the nearest outpost console.
* `"help"` — Lists all recognized command templates and syntax rules.

---

### 7. Campaign Progression & Star Map Unlocks
The primary campaign progresses through six distinct operational phases:
1. **Life Support Recovery**: Harvest oxygen cells from surface deposits to stabilize suit telemetry.
2. **Field Specimens**: Collect alien biomass and mineral samples from dangerous biomes.
3. **Outpost Override**: Discover and hack the abandoned scientific research terminal.
4. **Survive Alien Encounter**: Hold off aggressive xenomorph pressure waves.
5. **Goliath Protocol**: Track and neutralize the apex predator Goliath Prime.
6. **Expedition Extraction**: Return to the Habitat Module Airlock to secure planetary telemetry and unlock orbital transit.

Once extraction is achieved, access the **Orbital Star Map** to select and travel to new scientific destinations (e.g. **LHS 1140 b**, **Kepler-452 b**, **Gliese 667 Cc**). Each planet introduces distinct gravity, atmospheric hazards, and enemy compositions.

---

## How to Play: AI vs AI Simulation Arena (Complete Benchmarking Guide)

The **AI vs AI Simulation Arena** (`scenes/ai_vs_ai/ai_arena.tscn`) is accessible from the Main Menu. It provides an experimental environment where two autonomous agents compete without human intervention.

```
+------------------------------------------------------------------------------------+
|  BIOSPHERE-X // AI vs AI ARENA   | STATUS: RUNNING | Time: 14.2s / 120s | Sim: 1.00x|
+------------------------------------------------------------------------------------+
| [MATCH CONFIGURATION]            |                                                  |
| Scenario: Pursuit and Combat     |               [Agent A: A* Search]               |
| Agent A: A* Search (Optimal)     |                        v                         |
| Agent B: Greedy Best-First       |           # # #                 # # #            |
| [x] Swap Spawns  Seed: [42]      |           #   #    [OBJECTIVE]  #   #            |
|                                  |           # # #                 # # #            |
| [ Start ] [ Pause ] [ Reset ]    |                        ^                         |
|                                  |            [Agent B: Greedy Best-First]          |
+------------------------------------------------------------------------------------+
| AGENT A: [||||||||||  ] 82 HP | Nodes: 312 | 4.2ms || AGENT B: [||||||     ] 46 HP |
+------------------------------------------------------------------------------------+
```

---

### 1. Step-by-Step Match Setup
1. **Launch the Arena**: From the Main Menu, click **🤖 AI vs AI SIMULATION ARENA**.
2. **Select Scenario Mode**:
   * **Pursuit and Combat**: Agent A and Agent B spawn at opposite ends of a symmetric maze. Both agents navigate around obstacles, track line-of-sight, maintain combat spacing, and fire plasma rifles at each other. The match ends when one agent is eliminated.
   * **Race to Objective**: Weapons are disabled. A pulsing Data Beacon spawns at the exact center of the arena. Both agents compete to navigate through obstacle chokepoints and reach the beacon first.
3. **Assign Algorithms Independently**:
   * Choose any of the 7 algorithms for **Agent A** (e.g. `A* Search (Optimal)`).
   * Choose any of the 7 algorithms for **Agent B** (e.g. `Greedy Best-First Search`).
4. **Configure Trial Controls**:
   * **Swap Spawns**: Invert the starting quadrants of Agent A and Agent B to verify that one side's terrain does not create an unfair bias.
   * **Seed SpinBox**: Set a fixed numeric seed (e.g. `42`) to guarantee identical obstacle layouts and deterministic runs across comparison trials.
   * **Simulation Speed Slider**: Scale the time factor from `0.25x` (slow-motion frame-by-frame analysis) up to `4.00x` (rapid batch testing).
5. **Run the Simulation**:
   * Click **Start** to launch the match.
   * Click **Pause** (or press `Escape`) to freeze the agents and inspect positions.
   * Click **Reset** to return both agents to their starting positions with full health and clear telemetry.

---

### 2. Live Telemetry HUD & Visual Feedback
* **Agent A (Cyan)** vs **Agent B (Amber/Orange)**.
* **Real-Time HP Gauges**: Shows current health points and percentage.
* **Nodes Expanded Counter**: Measures search efficiency — the total number of graph nodes inspected by the algorithm.
* **Execution Time (ms)**: Measures algorithmic latency — the cumulative time in milliseconds spent computing paths.
* **Floating Combat Numbers**: When an agent takes damage, animated red damage numbers rise and fade in world-space.
* **Procedural Sound**: Firing sounds (`laser_fire`), impact sounds (`laser_hit`), and death sounds (`enemy_death`) trigger dynamically.

---

### 3. Match Outcomes & Scientific Data Export
When a match concludes, a victory banner announces the winner (e.g. `★ AGENT A WON (ELIMINATION) ★` or `★ AGENT B WON (OBJECTIVE REACHED) ★`).

You can export complete trial telemetry by clicking:
* **Export JSON**: Saves a full structured experiment log to `user://experiments/match_<scenario>_<timestamp>.json` containing:
  * Algorithm configurations, random seed, spawn swap setting, match duration.
  * Total path requests, total nodes expanded, average time per request (ms).
  * Total distance traveled (px), damage dealt, and damage taken.
* **Export CSV**: Appends a row to `user://experiments/match_<scenario>_<timestamp>.csv` formatted for direct import into Pandas, Excel, or R for comparative plotting.

---

## Algorithms Map & Implementation Reference

Every algorithm in BioSphere-X is modularized, covered by unit tests, and accessible in both Python and GDScript:

### 1. Pathfinding & Graph Search
* **`A* Search (Optimal Euclidean & Manhattan)`**
  * *Python Backend*: `ai_backend/algorithms/pathfinding/astar.py`
  * *Godot Integration*: `scripts/components/map_data.gd` and `scripts/autoloads/navigation_manager.gd`
  * *Role*: Primary pathfinding algorithm for enemies, bosses, and autonomous agents. Guarantees shortest path under admissible heuristics.
* **`Greedy Best-First Search`**
  * *Python Backend*: `ai_backend/algorithms/pathfinding/greedy_best_first.py`
  * *Role*: Expands nodes closest to the goal using heuristic distance alone. Extremely fast, but not guaranteed to find the shortest path.
* **`Breadth-First Search (BFS)`**
  * *Python Backend*: `ai_backend/algorithms/pathfinding/bfs.py`
  * *Role*: Unweighted shortest-path exploration expanding node frontiers uniformly.
* **`Depth-First Search (DFS)`**
  * *Python Backend*: `ai_backend/algorithms/pathfinding/dfs.py`
  * *Role*: Deep graph exploration used in maze benchmarks and connectivity checks.
* **`Depth-Limited Search (DLS)`**
  * *Python Backend*: `ai_backend/algorithms/pathfinding/dls.py`
  * *Role*: Bounded depth exploration that halts search beyond a predefined depth limit.
* **`Iterative Deepening DFS (IDDFS)`**
  * *Python Backend*: `ai_backend/algorithms/pathfinding/iddfs.py`
  * *Role*: Combines the optimality of BFS with the $O(bd)$ minimal memory footprint of DFS.
* **`Bidirectional Search`**
  * *Python Backend*: `ai_backend/algorithms/pathfinding/bidirectional.py`
  * *Role*: Simultaneous search expanding forward from the start node and backward from the goal until frontiers intersect.

---

### 2. Adversarial Decision-Making (Boss AI)
* **`Minimax Algorithm with Alpha-Beta Pruning`**
  * *Python Backend*: `ai_backend/algorithms/adversarial/boss_adversarial.py`
  * *Godot Integration*: `scenes/enemies/boss_alien.gd`
  * *Role*: Goliath Prime evaluates future combat states up to depth 4, maximizing boss advantage while minimizing player utility. Pruning discards non-optimal subtrees, selecting between Melee Smash, Acid Artillery, Ground Slam, and Tactical Repositioning.

---

### 3. Dynamic Pacing & Adaptive Difficulty
* **`Mamdani Fuzzy Inference System (FIS) with Centroid Defuzzification`**
  * *Python Backend*: `ai_backend/algorithms/fuzzy/fuzzy_difficulty.py`
  * *Godot Integration*: `scripts/autoloads/difficulty_controller.gd`
  * *Role*: Evaluates 4 continuous gameplay variables (`player_health`, `recent_damage`, `enemy_distance`, `repeated_failures`) across 11 fuzzy inference rules, defuzzifying into continuous aggression multipliers (0.35x to 1.40x) governing enemy movement speed, attack damage, and cooldown intervals.

---

### 4. Constraint Satisfaction Problem (CSP Base Construction)
* **`Backtracking Search with Forward Checking & MRV (Minimum Remaining Values)`**
  * *Python Backend*: `ai_backend/algorithms/csp/placement_csp.py`
  * *Godot Integration*: `scripts/components/placement_constraint_validator.gd` and `scripts/autoloads/construction_manager.gd`
  * *Role*: Treats structure placement as a CSP where variables are structure locations, domains are 2D grid coordinates, and constraints include grid boundaries, authorized build zones, non-overlapping footprints, natural terrain clearance, and resource costs.

---

### 5. Knowledge Representation & Production Rules
* **`Forward-Chaining Propositional Rule Engine`**
  * *Python Backend*: `ai_backend/algorithms/logic/rule_inference.py`
  * *Godot Integration*: `scripts/autoloads/game_rule_engine.gd`
  * *Role*: Evaluates world facts (`player_in_safe_zone`, `oxygen_ratio`, `samples_collected`, `boss_defeated`) against conditional IF-THEN rules, deriving higher-order gameplay states (e.g. suppressing low oxygen alarms in domes, unlocking extraction objectives, enabling airlock return consoles).

---

### 6. Natural Language Processing (Command Parsing)
* **`Offline Intent Classification & Slot Extraction`**
  * *Python Backend*: `ai_backend/algorithms/nlp/command_parser.py`
  * *Godot Integration*: `ui/components/command_terminal.gd`
  * *Role*: Normalizes player natural language strings, applies regular expression patterns and synonym dictionaries, validates parameters, and outputs structured intent payloads to the game engine without external network dependencies.

---

### 7. Digital Signal Processing (Procedural Audio Synthesizer)
* **`16-Bit 22.05 kHz PCM Waveform Synthesis`**
  * *Godot Integration*: `scripts/autoloads/audio_manager.gd`
  * *Role*: Synthesizes uncompressed audio streams directly in memory using frequency modulation, low-frequency oscillators, white noise, and exponential decay envelopes, providing 10 distinct sound effects and looping atmospheric drone audio.

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

### 2. End-to-End Player Journey Test Suite
```powershell
godot --headless --path "e:\Ai Project" --scene "res://tests/test_full_player_journey.tscn"
```
* **Results**: `39 / 39 Passed, 0 Failed` (Movement, Resources, Oxygen/Health, Missions, Combat, Base Building, Planet Unlocks, Save/Quit/Reload Roundtrip).

### 3. Visuals, Audio & Performance Benchmark Suite
```powershell
godot --headless --path "e:\Ai Project" --scene "res://tests/test_polish_and_performance.tscn"
```
* **Results**: `50 / 50 Passed, 0 Failed` (Synthesized PCM buffers, voice pooling, threat silhouettes, screen shake, keyboard remapping, and 15-enemy stress benchmark at 0.14 ms/frame).

### 4. Save/Load & Menus Integration Test Suite
```powershell
godot --headless --path "e:\Ai Project" --scene "res://tests/test_save_load_pause.tscn"
```
* **Results**: `46 / 46 Passed, 0 Failed` (Schema validation, corrupt file recovery, non-duplication of structures, pause oxygen freeze).

### 5. Natural Language Command Terminal Test Suite
```powershell
godot --headless --path "e:\Ai Project" --scene "res://tests/test_command_parser.tscn"
```
* **Results**: `73 / 73 Passed, 0 Failed` (Structured intent extraction, safety guarantees, ambiguous word clarification).

### 6. Logic-Based World Interactions Test Suite
```powershell
godot --headless --path "e:\Ai Project" --scene "res://tests/test_logic_world_interactions.tscn"
```
* **Results**: `47 / 47 Passed, 0 Failed` (Sanctuary dome oxygen protection, sample quota unlock, boss item terminal gate).

### 7. AI vs AI Simulation Arena Test Suite
```powershell
godot --headless --path "e:\Ai Project" --scene "res://tests/test_ai_vs_ai.tscn"
```
* **Results**: `8 / 8 Passed, 0 Failed` (Pursuit combat, race to objective, spawn swapping, JSON/CSV export).

---

## System Audit & Technical Specifications

### Fully Functional Systems
* **Complete Player Journey**: Exploring, resource gathering, vitals maintenance, combat, mission progression, structure placement, exoplanet star map unlocks, and save/load persistence all verified working end-to-end.
* **Graceful Degradation**: Game operates with or without the Python backend active.
* **Procedural Sound**: Full sound effects and looping ambient music synthesize natively in code without missing external files.
* **Keyboard Remapping & Settings**: Rebinding keys dynamically updates Godot's `InputMap` and persists across game restarts.
* **AI vs AI Arena**: Complete head-to-head benchmarking environment with matching sci-fi UI styling, audio feedback, and data export.

### Technical Notes & Specifications
* **Audio in Headless Mode**: When running Godot with the `--headless` flag on Linux/Windows servers, audio output hardware is bypassed by Godot's dummy audio driver; procedural audio buffers synthesize in memory and emit signals properly, but physical sound output requires running in standard graphical mode.
* **Display Resolution Scaling**: Changing the display resolution setting in the options menu applies in windowed mode; when Fullscreen mode is toggled, display sizing is managed directly by the operating system display server.
* **Single Active Command Terminal**: The command terminal is designed for single-operator typed natural language input; concurrent network terminal sessions are not supported.
