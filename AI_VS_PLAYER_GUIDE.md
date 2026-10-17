# BioSphere-X: Complete AI vs Player Architecture & Gameplay Guide (0 to End)

A comprehensive, ground-up architectural blueprint and operational manual detailing every component, mathematical model, and execution loop governing **AI vs Player** survival mode in **BioSphere-X**.

---

## Table of Contents
1. [High-Level System Architecture](#1-high-level-system-architecture)
2. [Player Astronaut Kinematics & Mechanics](#2-player-astronaut-kinematics--mechanics)
3. [Atmospheric Survival & Life-Support Economy](#3-atmospheric-survival--life-support-economy)
4. [Alien Enemy AI: Modular Finite State Machines](#4-alien-enemy-ai-modular-finite-state-machines)
5. [Sensory Perception & Line-of-Sight Raycasting](#5-sensory-perception--line-of-sight-raycasting)
6. [Adaptive Pacing: Mamdani Fuzzy Inference Controller](#6-adaptive-pacing-mamdani-fuzzy-inference-controller)
7. [Apex Boss AI: Goliath Prime & Minimax Decision Making](#7-apex-boss-ai-goliath-prime--minimax-decision-making)
8. [Combat Mechanics, Damage Pipeline & Ballistics](#8-combat-mechanics-damage-pipeline--ballistics)
9. [Base Construction & Constraint Satisfaction (CSP)](#9-base-construction--constraint-satisfaction-csp)
10. [Propositional Logic Engine & Safe Zones](#10-propositional-logic-engine--safe-zones)
11. [Natural Language Command Terminal](#11-natural-language-command-terminal)
12. [End-to-End Game Loop & Execution Sequence](#12-end-to-end-game-loop--execution-sequence)

---

## 1. High-Level System Architecture

In **AI vs Player** mode, the game operates as a distributed system pairing a 60+ FPS real-time rendering and physics client (**Godot 4**) with an asynchronous computational intelligence microservice (**Python FastAPI Backend**). If the network is severed or the backend is offline, local GDScript fallback modules take over with zero interruption.

```
       +-----------------------------------------------------------+
       |                  GODOT 4 ENGINE CLIENT                    |
       |                                                           |
       |  +--------------------+        +-----------------------+  |
       |  |  Player Character  | <----> |  Alien Enemy FSMs     |  |
       |  |  (Input, Physics)  |        |  (Scout, Brute, Boss) |  |
       |  +--------------------+        +-----------------------+  |
       |            |                               |              |
       |            v                               v              |
       |  +--------------------+        +-----------------------+  |
       |  | Life Support (O2)  |        | Collision & Raycasts  |  |
       |  | & Health Manager   |        | (PhysicsServer2D)     |  |
       |  +--------------------+        +-----------------------+  |
       |            ^                               ^              |
       +------------|-------------------------------|--------------+
                    | (HTTP REST JSON)              |
                    v                               v
       +-----------------------------------------------------------+
       |               PYTHON FASTAPI AI BACKEND                   |
       |                                                           |
       |  +-----------------------+   +-------------------------+  |
       |  |  A* / Theta* / JPS    |   |  Mamdani Fuzzy Logic    |  |
       |  |  Pathfinding Engine   |   |  (Adaptive Difficulty)  |  |
       |  +-----------------------+   +-------------------------+  |
       |  +-----------------------+   +-------------------------+  |
       |  |  Minimax & Alpha-Beta |   |  CSP Base Construction   |  |
       |  |  Boss Decision Tree   |   |  & Natural Language NLP |  |
       |  +-----------------------+   +-------------------------+  |
       +-----------------------------------------------------------+
```

---

## 2. Player Astronaut Kinematics & Mechanics

The player controls a stranded astronaut equipped with an EVA pressurized suit and a plasma pulse rifle.

### 2.1 Kinematic Equation of Motion
Player movement is governed by an acceleration-friction model in [`scenes/player/player.gd`](file:///e:/Ai%20Project/scenes/player/player.gd):

$$\vec{v}_{t} = \vec{v}_{t-1} + (\vec{d} \cdot v_{\text{max}} - \vec{v}_{t-1}) \cdot \alpha \cdot \Delta t$$

* $\vec{d}$: Normalized input direction vector $(\text{Input.get_vector("move_left", "move_right", "move_up", "move_down")})$.
* $v_{\text{max}}$: Base speed ($200.0\text{ px/s}$ walk, $320.0\text{ px/s}$ sprint).
* $\alpha$: Responsiveness coefficient ($14.0\text{ s}^{-1}$ during acceleration, $10.0\text{ s}^{-1}$ during friction deceleration).
* Diagonal normalization guarantees $\|\vec{d}\| \le 1.0$, preventing diagonal speed exploitation.

### 2.2 Aiming & Weapon Ballistics
* The astronaut's upper body and rifle rotate smoothly toward the cursor:
  $$\theta = \text{atan2}(y_{\text{mouse}} - y_{\text{player}}, x_{\text{mouse}} - x_{\text{player}})$$
* Primary fire instantiates an [`EnergyProjectile`](file:///e:/Ai%20Project/scenes/items/energy_projectile.gd) launched with velocity vector $\vec{v}_{\text{proj}} = \text{Vector2.from_angle}(\theta) \times 450.0\text{ px/s}$.
* Recoil applies a brief opposite impulse $\vec{v}_{\text{recoil}} = -\vec{v}_{\text{proj\_dir}} \times 35.0\text{ px/s}$.

---

## 3. Atmospheric Survival & Life-Support Economy

Survival in BioSphere-X hinges on managing life-support systems monitored via the [HUD](file:///e:/Ai%20Project/ui/screens/hud.gd).

```
   [100% OXYGEN] ----(Normal Drain: 1.0/s)----> [0% OXYGEN CRITICAL]
                                                        |
                                                        v
   [100% HEALTH] <--(Suffocation: 5.0 HP/s)-------------+
```

### 3.1 Vitality Equations
* **Oxygen Depletion**:
  $$O_2(t) = \max\left(0.0, O_2(t - \Delta t) - r_{\text{drain}} \times \Delta t\right)$$
  Where $r_{\text{drain}} = 1.0\text{ units/s}$ default, multiplied by planetary hazard modifiers (e.g., $1.4\times$ on flare-washed crags).
* **Suffocation State**:
  When $O_2(t) \le 0.0$, the suit life-support alarms activate and health begins taking damage:
  $$\text{HP}(t) = \text{HP}(t - \Delta t) - 5.0\text{ HP/s} \times \Delta t$$
* **Replenishment**:
  Collecting an **Oxygen Cell** immediately restores $+30.0\text{ O}_2$ and resets the suit suffocation threshold. Entering an **Atmospheric Sanctuary Dome** halts oxygen consumption entirely ($r_{\text{drain}} = 0.0$) and heals $+2.0\text{ HP/s}$.

---

## 4. Alien Enemy AI: Modular Finite State Machines

Alien enemies ([`scenes/enemies/alien_enemy.gd`](file:///e:/Ai%20Project/scenes/enemies/alien_enemy.gd)) operate under a deterministic 6-state Hierarchical Finite State Machine (HFSM):

```
                       +-------------------+
                       |       IDLE        |
                       +-------------------+
                          | ^           ^
             Timer expires| |           | Player lost > 4s
                          v |           |
                       +-------------------+
                       |      PATROL       |
                       +-------------------+
                          |             ^
             Target sensed|             | Target out of range
                          v             |
                       +-------------------+
          +----------> |      CHASE        | <----------+
          |            +-------------------+            |
          |               |             ^               |
Target out|     In strike |             | Target escapes|
of range  |         range |             | attack range  |
          |               v             |               |
          |            +-------------------+            |
          +----------- |      ATTACK       |            |
                       +-------------------+            |
                                |                       |
                 Player evasive |                       |
                                v                       |
                       +-------------------+            |
                       |    INVESTIGATE    | -----------+
                       +-------------------+
                                |
                   HP <= 0.0    v
                       +-------------------+
                       |       DEAD        |
                       +-------------------+
```

### 4.1 State Definitions
1. **IDLE**: Scans surroundings with zero velocity. A randomized timer ($1.5 - 3.0\text{ s}$) transitions the unit into PATROL.
2. **PATROL**: Selects a reachable random waypoint within `patrol_radius` ($180\text{ px}$) using navigation grid waypoints.
3. **CHASE**: Triggered when the player enters detection range ($240\text{ px}$) and line-of-sight is confirmed. The enemy requests an optimal path via A* or Theta* from the backend or local navigation manager.
4. **ATTACK**: Triggered when distance $\le \text{attack\_range}$ ($48\text{ px}$ for melee, $240\text{ px}$ for ranged). Performs a telegraph animation, executes strike dealing damage to player `HealthComponent`, then enters a brief cooldown.
5. **INVESTIGATE**: If the player breaks line-of-sight behind a wall, the enemy rushes to the **last known player position** and conducts a local search for $3.5\text{ s}$ before returning to patrol.
6. **DEAD**: Triggered upon health exhaustion. Collision shapes and physics layers are deferred-disabled (`set_deferred("disabled", true)`), death animations play, and resource rewards drop.

### 4.2 Enemy Archetypes
* **Alien Scout**: High velocity ($210\text{ px/s}$), low health ($45\text{ HP}$), wide perception cone. Attacks in hit-and-run flanking maneuvers.
* **Armored Brute**: High health ($160\text{ HP}$), high knockback resistance ($60\%$), heavy damage ($30\text{ HP/strike}$).
* **Ranged Spitter**: Maintains a standoff distance of $180\text{ px}$, launching corrosive bio-plasma projectiles.

---

## 5. Sensory Perception & Line-of-Sight Raycasting

Enemy awareness is not a simple radial trigger; it uses physical line-of-sight raycasts to prevent enemies from seeing through solid walls:

```
    [Enemy] ================== Raycast ==================> [Player] (CLEAR LOS: CHASE)
    
    [Enemy] ======= Raycast ======> [Wall Tile] ... X ... [Player] (BLOCKED: NO AGGRO)
```

1. **Distance Check**: Euclidean distance $D = \|\vec{p}_{\text{player}} - \vec{p}_{\text{enemy}}\| \le R_{\text{detect}}$.
2. **Raycast Verification**: A 2D physics raycast query is cast from enemy position to player center against collision mask 1 (World obstacles). If a collider is struck prior to reaching the player, line-of-sight is blocked (`has_line_of_sight = false`).
3. **Ethereal Phasing Override**: Specialized ethereal enemy variants have `can_see_through_walls = true`, enabling stealth ambush in subterranean caverns.

---

## 6. Adaptive Pacing: Mamdani Fuzzy Inference Controller

To prevent frustration for novice players and boredom for experts, the game features a Mamdani Fuzzy Inference System ([`scripts/autoloads/difficulty_controller.gd`](file:///e:/Ai%20Project/scripts/autoloads/difficulty_controller.gd) and Python `ai_backend/fuzzy_logic.py`).

### 6.1 Input Membership Functions
1. **Player Health Ratio** ($HP \in [0.0, 1.0]$): `CRITICAL` ($[0, 0.35]$), `MODERATE` ($[0.25, 0.75]$), `HIGH` ($[0.65, 1.0]$).
2. **Combat Pressure** ($P \in [0.0, 1.0]$): Determined by number of actively pursuing enemies and proximity.
3. **Damage Rate** ($D_{\text{recent}} \in [0.0, 1.0]$): Sustained damage over the last 10 seconds.

### 6.2 Rule Base Excerpt
* **IF** Health is `CRITICAL` **AND** Combat Pressure is `HIGH` **THEN** Aggression is `REDUCED` ($0.4\times$).
* **IF** Health is `HIGH` **AND** Combat Pressure is `LOW` **THEN** Aggression is `INCREASED` ($1.35\times$).
* **IF** Damage Rate is `ZERO` **AND** Health is `HIGH` **THEN** Aggression is `HIGH` ($1.2\times$).

### 6.3 Defuzzification & Multipliers
Using the **Center of Gravity (Centroid)** defuzzification technique:

$$y^* = \frac{\int y \cdot \mu_C(y) \, dy}{\int \mu_C(y) \, dy}$$

The defuzzified crisp output $y^* \in [0.1, 1.0]$ scales enemy parameters in real time:
* **Speed Multiplier**: $0.85\times - 1.25\times$
* **Damage Multiplier**: $0.75\times - 1.30\times$
* **Attack Cooldown**: $1.30\times - 0.70\times$ (higher aggression decreases cooldown)

---

## 7. Apex Boss AI: Goliath Prime & Minimax Decision Making

The apex planetary boss **Goliath Prime** ([`scenes/boss/boss_enemy.gd`](file:///e:/Ai%20Project/scenes/boss/boss_enemy.gd)) employs adversarial game-tree evaluation for intelligent tactical counters.

### 7.1 Decision Tree & Minimax
At key decision intervals, the boss simulates potential player counter-actions (firing plasma, dodging, retreating) across a 3-ply game tree using Alpha-Beta pruning:

$$V(s) = \max_{a \in \text{Actions}} \left( \min_{p \in \text{PlayerResponses}} \text{EvaluateUtility}(s, a, p) \right)$$

Utility evaluates:
* Expected damage inflicted on astronaut.
* Standoff distance vs weapon effective range.
* Boss spatial coverage and arena cornering.

### 7.2 Boss Combat Phases
1. **Phase 1: Territorial Guardian ($100\% - 50\%\text{ HP}$)**:
   * **Defensive Guard**: Mitigates incoming damage by $20\%$.
   * **Tremor Slam**: Telegraphs a growing radial hazard cone ($1.2\text{ s}$ windup), followed by an earth-shattering shockwave ($45\text{ damage}$, heavy knockback).
   * **Plasma Barrage**: Sprays 8 radial energy bolts in an expanding spiral.
2. **Phase 2: Enraged Behemoth ($< 50\%\text{ HP}$)**:
   * Triggered once HP drops below 250/500. Triggers an invulnerable roar pause ($1.2\text{ s}$).
   * Visual shifts to aggressive deep crimson plasma aura.
   * Movement speed jumps $+40\%$, attack recovery windows shrink from $2.0\text{ s}$ to $0.8\text{ s}$.
   * **Charge Rush**: Locks onto astronaut's vector, charging with $380\text{ px/s}$ ramming velocity.
3. **Fair Tactical Windows (Vulnerable Recovery)**:
   * Immediately following a heavy attack, Goliath Prime enters **State.RECOVER** for $1.5\text{ s}$.
   * During recovery, the boss takes **$+25\%$ bonus damage** and cannot attack, giving skilled players an intentional counterattack opportunity.

---

## 8. Combat Mechanics, Damage Pipeline & Ballistics

### 8.1 Damage Pipeline
When a projectile or melee swipe connects, damage passes through a standardized `DamageData` pipeline:

```
[Attacker] -> Create DamageData(Amount, Type, Knockback, Source)
                  |
                  v
              [Target] -> apply_damage(DamageData)
                              |
                              +---> Check Shield Mitigation
                              |
                              +---> Calculate Knockback Vector (Velocity += dir * force)
                              |
                              +---> HealthComponent.damage(FinalAmount)
                                        |
                                        +---> Emit `damaged` & Spawn Floating Text
                                        +---> If HP <= 0 -> Emit `died`
```

### 8.2 Safe Deferred Disabling
To prevent physics query crashes during query flushes (`godot_physics_server_2d.cpp`), all collision modifications and item drop registrations on defeat are dispatched via `set_deferred` and `call_deferred`.

---

## 9. Base Construction & Constraint Satisfaction (CSP)

Players construct outposts and research bases using an in-engine and Python-backed Constraint Satisfaction Problem (CSP) solver ([`scripts/components/placement_constraint_validator.gd`](file:///e:/Ai%20Project/scripts/components/placement_constraint_validator.gd)).

### 9.1 Mathematical Formulation
* **Variables**: Structure anchor coordinate $(X, Y) \in \mathbb{Z}^2$.
* **Domain**: Valid map grid coordinates within the playable boundary.
* **Constraints**:
  1. **Terrain Walkability**: All grid cells occupied by structure footprint must be walkable crust ($C_{\text{cell}} \ne \text{WALL}, \text{ROCK}, \text{CRATER}$).
  2. **Clearance Buffer**: Must maintain at least $1\text{ tile}$ clearance from existing structures to avoid doorway choking.
  3. **Resource Affordability**: Player inventory must possess $\ge$ structure cost ($\text{Metal}, \text{Titanium}, \text{Crystals}$).
  4. **Power Connectivity**: Power generators must be placed within relay grid distance ($12\text{ tiles}$).

---

## 10. Propositional Logic Engine & Safe Zones

World environmental logic is governed by a forward-chaining propositional production rule engine ([`scripts/components/rule_world_interaction_engine.gd`](file:///e:/Ai%20Project/scripts/components/rule_world_interaction_engine.gd)):

### 10.1 Active Propositional Facts
* $F_1$: `player_inside_sanctuary_dome`
* $F_2$: `alien_sample_quota_met` ($N_{\text{biomass}} \ge 10$)
* $F_3$: `goliath_core_acquired`
* $F_4$: `outpost_power_active`

### 10.2 Inference Rules
* **Rule 1 (Atmospheric Scrubbing)**:  
  $$\text{player\_inside\_sanctuary\_dome} \implies \text{oxygen\_depletion\_paused} \land \text{passive\_health\_regen}$$
* **Rule 2 (Lab Decontamination Protocol)**:  
  $$\text{alien\_sample\_quota\_met} \land \text{outpost\_power\_active} \implies \text{biotech\_lab\_door\_unlocked}$$
* **Rule 3 (Exoplanet Extraction Gate)**:  
  $$\text{goliath\_core\_acquired} \land \text{player\_at\_extraction\_beacon} \implies \text{mission\_complete\_and\_star\_chart\_advance}$$

---

## 11. Natural Language Command Terminal

Players can open the in-game command terminal (`~` or `T`) to command suit AI via typed natural language ([`ui/components/command_terminal.gd`](file:///e:/Ai%20Project/ui/components/command_terminal.gd)):

### 11.1 Offline NLP Architecture
Uses an intent-slot classification model running locally with zero cloud dependencies:
* **Tokenization & Normalization**: Strips punctuation, lowers casing, removes filler stop words.
* **Intent Classification**: Matches keywords and synsets to canonical intents:
  * `build_structure`: "construct an oxygen scrubber at coordinates 10 20"
  * `navigate_to`: "guide me to the nearest sanctuary dome"
  * `craft_item`: "fabricate plasma pulse ammo"
  * `query_status`: "report suit oxygen levels and armor integrity"
* **Slot Extraction**: Regex and dictionary lookup extracts target structure types, resource quantities, and grid coordinates.

---

## 12. End-to-End Game Loop & Execution Sequence

```
[GAME INITIALIZATION]
  1. Load NASA Exoplanet parameters & generate procedural terrain map.
  2. Instantiate Player Astronaut at planetary landing zone.
  3. Start Life-Support depletion clock & spawn planetary resource nodes.
  4. Spawn patrolling enemy alien archetypes and place Goliath Prime in crater.
  
[REAL-TIME FRAME LOOP (60 Hz)]
  1. Input Gathering -> Astronaut kinematics velocity updated.
  2. Physics Collision Resolution -> Player/Enemy/Obstacle contacts resolved.
  3. Life Support Tick -> Subtract oxygen; apply suffocation damage if O2 == 0.
  4. Enemy AI Update:
       - Update Line-of-sight raycasts to player.
       - Advance HFSM states (Patrol, Chase, Attack).
       - Query Fuzzy Inference for adaptive speed/damage scaling.
  5. Boss AI Minimax Evaluation -> Evaluate tactical moves and windups.
  6. Projectile Ballistics & Floating Combat Text rendering.
  
[INTERACTION & PROGRESSION]
  1. Player mines resources [E] & crafts upgrades in Inventory.
  2. Player places structures with CSP validator.
  3. Player completes mission milestones -> triggers Rule Engine unlocks.
  4. Boss Defeat -> Drops Colossal Reward Cache & unlocks next Exoplanet!
```
