# BioSphere-X

A complete, 2D top-down sci-fi survival game set on alien exoplanets, powered by **Godot 4** and an asynchronous **Python AI Backend**.

> 📚 **COMPREHENSIVE 0-TO-END DOCUMENTATION SUITE**:
> * 🎮 [**AI vs Player Architectural & Gameplay Guide (0 to End)**](AI_VS_PLAYER_GUIDE.md) — Comprehensive technical deep dive into astronaut kinematics, enemy state machines, fuzzy logic difficulty pacing, boss Minimax/Alpha-Beta decision trees, and offline NLP command terminal.
> * 🤖 [**AI vs AI Simulation Arena Guide (0 to End)**](AI_VS_AI_GUIDE.md) — Multi-agent benchmarking, A*/Theta*/BFS/Dijkstra/JPS pathfinding comparison, batch experiment runner, controlled planet scenarios, and automated CSV/JSON trial export.
> * 📜 [**Complete Game Rules & Survival Operations Manual**](GAME_RULES_AND_MANUAL.md) — Exhaustive player manual covering life support, resource mining economy, crafting recipes, base construction CSP rules, NASA exoplanetary star map, and combat protocols.
> * 🏆 [**Academic AI Defense & Pitch Guide**](ACADEMIC_DEFENSE.md) — Mathematical formulations, time/space complexity matrices, 5-minute viva presentation scripts, and live demonstration checklist for university evaluation panels.

---

## Table of Contents
1. [Comprehensive Documentation Suite](#comprehensive-documentation-suite)
2. [Project Overview & Architectural Milestones](#project-overview--architectural-milestones)
3. [Prerequisites & Quick Start](#prerequisites--quick-start)
4. [Master Controls & Keybindings](#master-controls--keybindings)
5. [How to Play: AI vs Player Mode (Complete Survival Guide)](#how-to-play-ai-vs-player-mode-complete-survival-guide)
6. [How to Play: AI vs AI Simulation Arena (Complete Benchmarking Guide)](#how-to-play-ai-vs-ai-simulation-arena-complete-benchmarking-guide)
7. [Algorithms Map & Implementation Reference](#algorithms-map--implementation-reference)
8. [Project Directory Structure](#project-directory-structure)
9. [Automated Verification & Test Suites](#automated-verification--test-suites)
10. [System Audit & Technical Specifications](#system-audit--technical-specifications)

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
| **Inventory & Crafting** | `I` | `Tab` | Open suit storage, craft items, view upgrades |
| **Base Construction** | `B` | — | Open structure build catalog & placement grid |
| **Survival Field Guide** | `H` | — | Open comprehensive in-game manual & encyclopedia |
| **AI Story Transmission** | `L` | — | Open AURA-7 mission lore logs & comms briefing |
| **Command Terminal** | `~` (Tilde / Backquote) | — | Open natural language tactical command line |
| **AI Nav Visualizer** | `F1` | — | Toggle real-time navigation mesh & path debug overlay |
| **Pause Game** | `Escape` | `P` | Pause world simulation, open settings & save menu |

---

## How to Play: AI vs Player Mode (Complete Survival Guide)

> 📖 **DETAILED GUIDES**:
> * For the exhaustive architectural blueprint covering kinematics, enemy FSMs, fuzzy logic, boss Minimax decision trees, and offline NLP terminal, see [**AI vs Player Architectural & Gameplay Guide (0 to End)**](AI_VS_PLAYER_GUIDE.md).
> * For the comprehensive player survival manual, crafting recipes, base construction CSP rules, and NASA exoplanetary star map, see [**Complete Game Rules & Survival Manual**](GAME_RULES_AND_MANUAL.md).

### 1. Game Start & The Main Menu
When launching BioSphere-X, the Main Menu offers:
* **New Game**: Initializes a new expedition starting on the habitable exoplanet **TRAPPIST-1 e**.
* **Continue**: Loads your saved expedition (vitals, inventory, missions, structures, and planet progression).
* **AI vs AI Simulation Arena**: Opens the autonomous multi-agent proving grounds.
* **Settings**: Adjust Master/SFX/Ambient audio volumes, window resolution, fullscreen, screen shake, difficulty mode, and keybindings.
* **Quit**: Safely exits the game.

---

### 2. HUD & Vitality Telemetry (Redesigned Sci-Fi Interface)
Upon entering the planetary world, your state-of-the-art Heads-Up Display provides clean, high-contrast survival telemetry without clutter:
* **Top-Left: EVA Life Support & Biome Diagnostics**:
  * **❤ VIT (Vitality / Health)**:
    * Decreases when struck by xenomorph melee strikes or acid projectiles.
    * Restored with medical nanites, harvested restorative fauna, or resting inside base modules.
    * Reaching `0 HP` triggers mission failure and game over.
  * **🫁 O2 (Oxygen Reserves)**:
    * Constantly depletes at `1.5 units/second` while exploring hostile alien atmospheres.
    * If reserves drop below `25%`, an audio warning sounds and flashing alerts appear.
    * Reaching `0%` inflicts rapid suffocation damage (`4.0 HP/sec`).
    * **Replenishment**: Approach cyan Oxygen Canisters and press `E`, enter the Base Atmospheric Dome safe-zone, or activate Oxygen Stations.
  * **⚡ PWR (Weapon & Suit Energy)**:
    * Powers your plasma pulse rifle. Recharges automatically when not firing.
  * **Biome Telemetry**: Real-time readouts of sector coordinates, environmental hazard level, and atmospheric drain rate.
* **Top-Right: Action Quick-Dock & Resource Monitor**:
  * **Quick Actions**: `[F1] NAV`, `🎒 [I] CRAFT`, `🔨 [B] BUILD`, `❓ [H] GUIDE`, `💻 [~] CMD`.
  * **Resource Counters**: Live counts of carried `⚡ Crystals`, `⛏ Titanium Alloy`, `🧬 Alien Biomass`, and `🫁 Oxygen Cells`.
* **Lower-Center: Floating Contextual Interaction Prompt**:
  * Displays a glowing keycap badge `[ E ]` and the contextual action (e.g. `[ E ]  Review Expedition Objectives`, `[ E ]  Harvest Oxygen Canister`, `[ E ]  Access Cargo Storage`) whenever near interactive entities.
* **Bottom-Center: Mission Directives HUD & Waypoint Compass**:
  * **Directive Card**: Displays the active mission name, objective category (`[COLLECT OXYGEN]`, `[RECON]`, etc.), and execution status (`● ACTIVE`).
  * **Progress Bar**: Real-time progress metric with exact count and percentage (e.g. `0 / 3 Cells (0%)`).
  * **Waypoint Compass**: Real-time dynamic distance and compass bearing to the objective target (e.g. `🧭 TARGET: Oxygen Canister [12m North-East]`).
* **Bottom Bar: Quick Reference Hotkey Dock**:
  * Subtle, clean docking bar showing all master controls at a glance.

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

### 8. Step-by-Step Walkthrough: Your First 10 Minutes in BioSphere-X

Follow this exact walkthrough to experience the complete gameplay loop from spawning to planetary mastery:

1. **Spawn & Safe Zone Orientation**:
   * You spawn in the center of **Bio-Hab Alpha Research Base**, protected by a glowing cyan atmospheric dome.
   * Take note of your top-left vitality monitor: while inside the dome, **Oxygen Recharges to 100%**.
   * Approach the in-base stations:
     * `[OPS] Mission Operations Console`: Press **`E`** to review current expedition directives.
     * `[INVENTORY] Cargo Storage Vault`: Press **`E`** to store surplus resources or retrieve survival gear.
     * `[DEPLOY] Habitat Airlock Gate`: Press **`E`** at the south portal to cycle the pressure doors and venture onto the planetary surface.

2. **Phase 1 — Locomotion & Oxygen Survival**:
   * Use **`W`, `A`, `S`, `D`** to navigate south through the canyon corridor.
   * Notice your Oxygen gauge draining at `1.5/s`. Look for glowing cyan **Oxygen Canisters** resting near rock outcrops.
   * Approach a canister and press **`E`** to harvest it, instantly recovering `+30.0 O2`.
   * Complete the first directive by harvesting 3 Oxygen Cells.

3. **Phase 2 — Economy & In-Field Crafting**:
   * Harvest magenta **Energy Crystals** and amber **Titanium Alloy** nodes using **`E`**.
   * Press **`I`** (or `Tab`) to open the **Inventory & Crafting Suite**.
   * Craft **Nanite Medical Stims** to restore lost health, or upgrade your suit battery capacity.

4. **Phase 3 — Combat Engagement & Tactics**:
   * Aim with your mouse cursor and discharge your plasma pulse rifle using **`Space`** or **`Left Mouse Button`**.
   * **Hostile Scouts (Green)**: Fast agile flankers. Backpedal (kite) while firing steady plasma bursts.
   * **Hostile Brutes (Red)**: Heavy armored melee tanks. Watch for the red windup attack cone, dodge laterally, and fire while they recover.
   * **Hostile Spitters (Cyan/Purple)**: Ranged artillery. Strafe perpendicular to incoming acid trajectory.

5. **Phase 4 — Base Construction**:
   * Press **`B`** to open the holographic **Construction Mode**.
   * Select an **Atmospheric Dome** and position it near a distant mineral field (green holographic silhouette indicates valid CSP placement).
   * Click **`Left Mouse Button`** to build. Step inside your newly constructed dome — suit oxygen consumption immediately drops to zero!
   * Erect **Defensive Barricades** across narrow canyon passes to funnel alien swarms.

6. **Phase 5 — Tactical Command Terminal & Outpost Override**:
   * Press **`~`** (Tilde) to open the tactical command line.
   * Type `"status report"` or `"refill oxygen"` to interact with the offline NLP engine.
   * Follow the bottom **Waypoint Compass** (`🧭 TARGET TRACKER`) North-East to locate the abandoned Research Outpost.
   * Press **`E`** at the outpost mainframe to decrypt alien planetary data.

7. **Phase 6 — Apex Boss & Star Map Travel**:
   * Decrypting the terminal awakens **Goliath Prime** (Apex Predator).
   * Utilize canyon wall pillars as cover to absorb Goliath's ranged acid barrage.
   * Neutralize Goliath Prime, claim rare biomass specimens, and return to the Habitat Airlock Gate.
   * Access the **Orbital Star Map** to select your next NASA target (e.g. **LHS 1140 b** or **Kepler-452 b**)!

### 4.9 Narrative Arc & The AURA-7 AI Comms System

BioSphere-X features an integrated narrative campaign driven by your orbital synthetic companion, **AURA-7** (*Autonomous Unmanned Reconnaissance Assistant, Gen-7*).

* **Incoming Transmission Modals**: Whenever you unlock or advance an expedition objective, AURA-7 broadcasts priority comms via a holographic orbital modal with audio chime and encrypted mission telemetry. You can click `[Accept Directive]` or press `[H]` to consult your field manual.
* **Encrypted Mission Logbook (`[L]`)**: Press **`L`** anytime during the mission to bring up the full narrative transmission history. Review classified field notes, xenobiological analyses, and historical logs left by the lost vanguard team.
* **Six-Act Campaign Storyline**:
  1. **Act I — Awakening & Life Support**: Restore compromised atmospheric seals and recover scatter-dropped oxygen canisters outside the southern airlock.
  2. **Act II — Xenobiological Taxonomy**: Harvest crystalline minerals and indigenous bio-flora to analyze alien photosynthetic adaptations.
  3. **Act III — Outpost Mainframe Breach**: Locate the abandoned Vanguard research facility and decrypt the encrypted telemetry black box.
  4. **Act IV — Swarm Perimeter Defense**: Stand your ground as local burrowing xenofauna test your thermal defensive grid.
  5. **Act V — The Goliath Protocol**: Confront the titanic subterranean Apex Guardian, utilizing canyon geography and plasma charge timing.
  6. **Act VI — Orbital Extraction**: Broadcast planetary viability indices to Earth Command and unlock the interstellar Star Map.
* **Bio-Hab Sanctuary & Emergency Revive**:
  * The central Bio-Hab dome maintains an atmospheric purity field (0% O2 loss, full thermal shielding, continuous health regeneration).
  * Should vitals reach critical zero in the field, AURA-7 activates emergency transponder beacons. Click **`⟲ RESPAWN AT BASE HABITAT SANCTUARY`** to immediately revive at full 100% Health and Oxygen without resetting world discovery.

---

## How to Play: AI vs AI Simulation Arena (Complete Benchmarking Guide)

> 🔬 **DETAILED ARENA GUIDE**:
> * For the exhaustive algorithmic breakdown of A*, Theta*, Greedy BFS, Dijkstra, and JPS, mathematical complexity proofs, batch experiment automation, and telemetry logs, see [**AI vs AI Simulation Arena Guide (0 to End)**](AI_VS_AI_GUIDE.md).

The **AI vs AI Simulation Arena** (`scenes/ai_vs_ai/ai_arena.tscn`) is accessible from the Main Menu. It provides an academic research environment where two autonomous agents run independent graph search and pathfinding algorithms side-by-side in real time. It features a **Batch Experiment Runner**, **Controlled Planet Scenarios Catalog**, and **Automated CSV/JSON Telemetry Export**.

```
+---------------------------------------------------------------------------------------------------------+
| [AGENT A (CYAN)] [A* OPTIMAL]      |            BIOSPHERE-X ARENA            |  [AGENT B (AMBER)] [GREEDY]      |
| [||||||||||||||||||||||||] 100 HP   | STATUS: ENGAGED [CAN_CHOKEPOINTS]       |  [||||||||||||||||       ] 75 HP|
| Nodes: 184 | Latency: 2.1ms        | Time: 00:14.2 / 120s                    |  Nodes: 436 | Latency: 4.8ms     |
+---------------------------------------------------------------------------------------------------------+
|                                                                                                         |
|                  [Agent A (Cyan Vanguard Operative)] ───────► (Active Planned Path)                     |
|                                     │                                                                   |
|                      [CONCAVE U-SHAPED CANYON TRAP]                                                     |
|                                     ▼                                                                   |
|                     [DATA BEACON / CENTER DAIS]                                                         |
|                                     ▲                                                                   |
|                  [Agent B (Amber Rival Operative)]  ───────► (Active Planned Path)                      |
|                                                                                                         |
+---------------------------------------------------------------------------------------------------------+
| [ ▶ Start ] [ ⏸ Pause ] [ ↺ Reset ] | [ ⚙ Match Setup ] [ 🎥 Cam ] [ 👁 Paths: ON ] [ 📊 AI Inspector ] |
+---------------------------------------------------------------------------------------------------------+
```

---

### 1. Step-by-Step Match Setup & Controls
1. **Launch the Arena**: From the Main Menu, click **🤖 AI vs AI SIMULATION ARENA**.
2. **Open Match Setup (`⚙ Match Setup`)**:
   * **Scenario Mode**:
     * **Pursuit and Combat**: Agents navigate around obstacles, track line-of-sight, maintain combat spacing (160–260px engagement sweet spot), and fire plasma rifles. Match ends upon agent elimination.
     * **Race to Objective**: Weapons are disabled. A glowing Data Beacon is situated at the arena center. Agents race across the terrain to reach it first.
   * **Tactical Map Preset**: Select between 4 distinct experimental environments:
     * **Symmetric Proving Grounds**: Balanced tournament arena with central pillars and symmetric flanking corridors.
     * **Canyon Chokepoints & U-Traps**: Concave barrier traps designed to demonstrate why greedy heuristics get stuck in local minima while A* navigates around.
     * **Open Crater Basin**: Sparse rock cover demonstrating raw heuristic search speed and directional pruning.
     * **The Labyrinth**: Dense grid maze with deep branching factor ($d \ge 25$) demonstrating search tree depth and memory bounds.
   * **Assign Algorithms Independently**:
     * Assign any of the 7 algorithms to **Agent A** (e.g. `A* Search (Optimal)`).
     * Assign any of the 7 algorithms to **Agent B** (e.g. `Greedy Best-First Search`).
   * **Tactical Roles (Dynamic Multi-Agent Behaviors)**:
     * **Adaptive Tactician (Balanced & Dynamic)**: Evaluates own and opponent vitality in real time. Backpedals into evasive retreat and searches for repair pickups below `45% HP`. Surges forward aggressively to finish off opponents when they are weakened below `35% HP`.
     * **Aggressive Assault (CQB Rapid Burst)**: High speed (`205 px/s`), closes into close-quarters standoff (`70–160px`), and discharges rapid plasma bursts (`0.32s` cooldown, `14.0` damage).
     * **Long-Range Marksman (Sniper & Kiting)**: Maintains maximum standoff (`260–380px`), strictly backpedaling if enemies approach, and fires high-velocity rail slugs (`29.0` damage, `750 px/s` velocity).
     * **Evasive Skirmisher (Agile Flanker)**: Agile lateral movement (`190 px/s`) with dynamic orbit switching every `1.2–2.6s` and immediate reflex dash evasion upon receiving damage.
   * **Predictive Lead Aiming**:
     * Agents calculate opponent velocity vectors and projectile flight latency to lead their shots ahead of moving targets.
   * **Dynamic Battlefield Pickups**:
     * **Nanite Repair Core (North Corridor, `(0, -145)`)**: Restores `+35 HP` on contact with green holographic beacon; respawns after `15.0s`. Low-health adaptive agents calculate utility to divert and secure it!
     * **Plasma Overcharge Cell (South Corridor, `(0, 145)`)**: Grants `+35%` movement velocity and `+30%` fire-rate overdrive for `8.0s` with glowing yellow energy halos; respawns after `18.0s`.
   * **Spawn Swapping**: Toggle **Swap Spawns** to flip starting positions, ensuring complete experimental fairness.
   * **Deterministic Seed**: Adjust the numeric seed (e.g. `42`) for identical, reproducible trials across benchmarks.
3. **Bottom Dock Interactive Controls**:
   * **`▶ Start`**: Deploys agents and begins autonomous execution.
   * **`⏸ Pause`** (or `Escape`): Freezes simulation instantly for frame-by-frame inspection.
   * **`↺ Reset`**: Clears path trees, restores full agent health, and resets positions to spawn pads.
   * **`🎥 Cam: Dynamic / Overview`**: Toggles between smooth midpoint tracking with adaptive combat zoom (`0.70x`–`1.35x`) and full arena overview.
   * **`👁 Paths: ON / OFF`**: Toggles live real-time rendering of planned paths and waypoint nodes on the arena floor.
   * **`📊 AI Inspector`**: Opens the comprehensive Academic AI Inspector dialog displaying theoretical classifications and live benchmark telemetry.
   * **Simulation Speed Slider**: Scale time factor dynamically from `0.25x` (slow-motion analysis) up to `4.00x` (rapid batch runs).

---

### 2. Live AI Path & Search Visualizer
When **`👁 Paths: ON`** is enabled, the simulation renders the internal algorithmic decisions directly on the arena floor:
* **Agent A Route (Cyan Glow)**: Draws a polyline along all remaining path waypoints for Agent A, terminating at the current target.
* **Agent B Route (Amber Glow)**: Draws a polyline along all remaining path waypoints for Agent B.
* **Pulsing Waypoint Nodes**: Glowing node rings illuminate each graph coordinate along the route, with a pulsing halo on the destination goal.
* **Combat Targeting Vector**: In Combat mode, a subtle red dashed line indicates when an agent has acquired clear line-of-sight to the opponent.

---

### 3. Academic AI Inspector & Defense Report
Clicking **`📊 AI Inspector`** (or clicking **`📊 View Academic Defense Report`** after a match) opens a dedicated side-by-side analysis window:
* **Theoretical Classification**:
  * Category (Informed Heuristic vs Uninformed Blind)
  * Cost Evaluation Function $f(n)$
  * Heuristic Admissibility Guarantee ($h(n) \le h^*(n)$)
  * Optimality & Completeness proofs
  * Big-O Time Complexity ($O(b^d)$)
  * Big-O Space Complexity ($O(b^d)$ vs $O(bd)$)
* **Live Realized Telemetry**:
  * Nodes Expanded: Number of search tree states inspected.
  * Algorithmic Latency: Cumulative time spent computing paths in milliseconds.
  * Physical Distance Traveled: Measured in arena pixels.
  * Path Efficiency Ratio: $\frac{\text{Straight-Line Euclidean Displacement}}{\text{Actual Traveled Distance}} \times 100\%$
* **Dynamic Presentation Summary**: Automatically synthesizes an oral defense explanation analyzing *why* the winning algorithm succeeded on the chosen terrain.
* **`📋 Copy Defense Summary`**: Copies the complete theoretical report to your system clipboard for instant pasting into presentation slides or lab reports.

---

### 4. Scientific Data Export (JSON & CSV)
Every match automatically logs comprehensive experimental data:
* **Export JSON**: Saves a full structured experiment record to `user://experiments/match_<scenario>_<timestamp>.json`.
* **Export CSV**: Appends a row to `user://experiments/match_<scenario>_<timestamp>.csv` including:
  * `Timestamp`, `Scenario`, `Map`, `RandomSeed`, `SwapSpawns`, `DurationSeconds`, `Outcome`, `Winner`.
  * `AgentA_Algo`, `AgentA_Requests`, `AgentA_NodesExpanded`, `AgentA_AlgoTimeMs`, `AgentA_DistanceTraveled`, `AgentA_RemainingHP`, `AgentA_DamageDealt`.
  * `AgentB_Algo`, `AgentB_Requests`, `AgentB_NodesExpanded`, `AgentB_AlgoTimeMs`, `AgentB_DistanceTraveled`, `AgentB_RemainingHP`, `AgentB_DamageDealt`.

---

## Teacher Presentation Guide & Oral Defense Cheat Sheet

This section provides the exact theoretical concepts, demonstration procedures, and answers to likely questions when presenting BioSphere-X to your computer science / artificial intelligence instructor.

### 1. Algorithm Complexity & Theoretical Guarantees Matrix

| Algorithm | Category | Cost Function $f(n)$ | Admissibility $h(n) \le h^*(n)$ | Complete? | Optimal? | Time Complexity | Space Complexity |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **A\* Search** | Informed | $f(n) = g(n) + h(n)$ | Admissible (Euclidean) | Yes | Yes | $O(b^d)$ | $O(b^d)$ (Stores all nodes) |
| **Greedy Best-First** | Informed | $f(n) = h(n)$ | Non-admissible (ignores $g$) | No (can loop) | No | $O(b^m)$ | $O(b^m)$ |
| **Breadth-First (BFS)** | Uninformed | $f(n) = \text{depth}(n)$ | N/A | Yes | Yes (uniform cost) | $O(b^d)$ | $O(b^d)$ (Exponential memory) |
| **Depth-First (DFS)** | Uninformed | $f(n) = -\text{depth}(n)$ | N/A | No (in infinite graphs) | No | $O(b^m)$ | $O(bm)$ (Linear memory) |
| **Depth-Limited (DLS)** | Uninformed | DFS with cutoff $l$ | N/A | No (if $d > l$) | No | $O(b^l)$ | $O(bl)$ |
| **Iterative Deepening (IDDFS)**| Uninformed | Iterative DLS ($l=0..d$) | N/A | Yes | Yes (uniform cost) | $O(b^d)$ | $O(bd)$ (Linear space!) |
| **Bidirectional Search** | Dual Frontier| Start $\rightarrow \leftarrow$ Goal | Preserved if heuristics admissible | Yes | Yes | $O(b^{d/2})$ | $O(b^{d/2})$ (Exponential speedup) |

*Where $b$ = effective branching factor (up to 8 for diagonal grids), $d$ = shallowest goal depth, $m$ = maximum search tree depth, $l$ = depth cutoff limit.*

---

### 2. Three Live Demonstrations to Show Your Teacher

#### Experiment A: The Concave Obstacle Trap (Greedy vs A*)
1. In **Match Setup**, select **Scenario: Pursuit and Combat** and **Map: Canyon Chokepoints & U-Traps**.
2. Set **Agent A** = `A* Search (Optimal)` and **Agent B** = `Greedy Best-First Search`.
3. Toggle **`👁 Paths: ON`** and click **Start**.
4. **What to Point Out to the Teacher**:
   * Agent B (Greedy) looks only at Euclidean distance to the goal ($h(n)$). Because entering the mouth of the concave U-trap reduces straight-line distance, Greedy aggressively plunges into the pocket and gets trapped against the back wall. It must expand dozens of extra nodes before it backtracks.
   * Agent A (A*) evaluates both accumulated path cost $g(n)$ and estimated remaining distance $h(n)$. It recognizes that moving deep into the concave pocket increases $g(n)$ without providing an exit, so it cleanly routes around the outer perimeter.
   * Open **`📊 AI Inspector`** to show the teacher the difference in **Nodes Expanded** and **Path Efficiency Ratio**.

#### Experiment B: The Memory vs Optimality Trade-Off (BFS vs IDDFS)
1. Select **Map: The Labyrinth** and **Scenario: Race to Objective**.
2. Set **Agent A** = `Breadth-First Search (BFS)` and **Agent B** = `Iterative Deepening DFS (IDDFS)`.
3. Click **Start**.
4. **What to Point Out to the Teacher**:
   * Both algorithms reach the objective in the exact same optimal number of steps.
   * However, BFS must store every node in its frontier queue, yielding an exponential memory footprint of $O(b^d)$.
   * IDDFS repeatedly runs depth-limited searches, keeping only the active branch in memory. Its memory footprint is strictly linear $O(bd)$.
   * Explain that the re-computation overhead of IDDFS is merely $\frac{b}{b-1}$, meaning IDDFS is vastly superior for memory-constrained autonomous rovers.

#### Experiment C: Directional Heuristic Pruning (BFS vs A*)
1. Select **Map: Open Crater Basin** and **Scenario: Race to Objective**.
2. Set **Agent A** = `A* Search (Optimal)` and **Agent B** = `Breadth-First Search (BFS)`.
3. Click **Start**.
4. **What to Point Out to the Teacher**:
   * In an open environment without walls, BFS blindly expands outward in expanding concentric circles, wasting CPU time on hundreds of nodes directed away from the goal.
   * A* uses its Euclidean heuristic to prioritize nodes pointing toward the objective, narrowing the search frontier into a pencil-thin beam.
   * Point out the **Execution Time (ms)** and **Nodes Expanded** counters on the top HUD to prove A*'s computational efficiency.

---

### 3. Likely Teacher Questions & Exact Answers

* **Q1: "Why is A* guaranteed to be optimal in your simulation?"**
  * **Answer**: "A* is mathematically guaranteed to be optimal because our heuristic function $h(n)$ uses 2D Euclidean distance, which satisfies both admissibility ($h(n) \le h^*(n)$) and consistency (triangle inequality: $h(n) \le c(n, a, n') + h(n')$). Because Euclidean distance is the straight-line distance, it never overestimates the true traversal cost on a grid."

* **Q2: "Why did you implement Bidirectional Search, and what is its time complexity?"**
  * **Answer**: "Bidirectional search replaces a single search tree of depth $d$ with two smaller search trees of depth $d/2$ originating from the start and goal simultaneously. The time complexity drops from $O(b^d)$ to $O(b^{d/2} + b^{d/2})$, which is an exponential reduction in state expansions."

* **Q3: "How does the boss alien AI make decisions?"**
  * **Answer**: "Goliath Prime uses the **Minimax algorithm with Alpha-Beta Pruning** evaluated to a depth of 4 plies. It evaluates board utility based on astronaut distance, player health percentage, weapon cooldown state, and cover positioning. Alpha-Beta pruning discards branches where the minimum score of the maximizing player is already worse than the maximum score achieved elsewhere, cutting average branch evaluations from $O(b^d)$ down to $O(b^{d/2})$."

* **Q4: "Why use Fuzzy Logic for game difficulty instead of hardcoded numbers?"**
  * **Answer**: "Human gameplay skills are continuous and non-linear. Traditional hardcoded thresholds cause abrupt 'rubber-banding' difficulty spikes. Our Mamdani Fuzzy Inference System evaluates player health, accuracy, and failure rate across trapezoidal membership sets (Low, Medium, High). Centroid defuzzification calculates a smooth, continuous aggression index between 0.10 and 1.00 that dynamically tunes enemy speed, damage, and cooldown multipliers without noticeable jarring transitions."

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
│       ├── controlled_planet_scenarios.gd # NASA Benchmark Scenarios Catalog
│       ├── experiment_export_manager.gd # Automated CSV/JSON Trial Logging
│       ├── floating_combat_text.gd   # Animated Combat Floating Numbers
│       ├── health_component.gd       # Vitality & Damage Mitigation
│       ├── map_data.gd               # 2D Grid Cell Classification
│       ├── placement_constraint_validator.gd # In-Engine CSP Validator
│       └── weapon_component.gd       # Plasma Pulse Rifle Controller
│
├── ui/                               # User Interface Components & Screens
│   ├── components/                   # Batch Experiments, Visualizer, Terminal, HUD
│   │   ├── batch_experiment_modal.gd # Automated Batch Trial Runner
│   │   ├── pathfinding_visualizer.gd # Real-Time Path & Search Grid Canvas
│   │   ├── command_terminal.gd       # Natural Language Processing Terminal
│   │   └── construction_menu.gd      # Base Building Hologram & CSP Menu
│   └── screens/                      # Main HUD, Level Loading, Planet Selection
│
├── tests/                            # Automated Headless Test Suites (35+ Suites)
│   ├── test_full_player_journey.tscn # End-to-End Complete Player Journey Test
│   ├── test_polish_and_performance.tscn # Multi-Enemy Stress & Audio Test
│   ├── test_save_load_pause.tscn     # Persistence & Pause Freezing Test
│   ├── test_command_parser.tscn      # Offline NLP Command Terminal Test
│   ├── test_logic_world_interactions.tscn # Production Rule World Test
│   ├── test_controlled_planet_scenarios.gd # NASA Scenario Catalog Suite
│   ├── test_automatic_export.gd      # CSV & JSON Auto-Export Suite
│   └── test_ai_vs_ai.tscn            # AI vs AI Arena Lifecycle Test
│
├── ACADEMIC_DEFENSE.md               # Viva & Professor Presentation Script
├── AI_VS_PLAYER_GUIDE.md             # Complete 0-to-End AI vs Player Technical Guide
├── AI_VS_AI_GUIDE.md                 # Complete 0-to-End AI vs AI Simulation & Benchmark Guide
├── GAME_RULES_AND_MANUAL.md          # Complete Player Survival Rulebook & Manual
├── project.godot                     # Godot 4 Project Configuration File
└── README.md                         # Project Master Hub Documentation
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
