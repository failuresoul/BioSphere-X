# BioSphere-X: Complete Game Rules, Survival Manual & Operations Guide (0 to End)

A comprehensive, zero-to-end player manual, operational rulebook, and survival guide for **BioSphere-X**.

---

## Table of Contents
1. [Mission Briefing & Narrative Setting](#1-mission-briefing--narrative-setting)
2. [Master Controls & Keybindings Reference](#2-master-controls--keybindings-reference)
3. [Atmospheric Survival & Life-Support Rules](#3-atmospheric-survival--life-support-rules)
4. [Resource Harvesting, Mining & Economy](#4-resource-harvesting-mining--economy)
5. [Crafting Blueprints & Equipment Upgrades](#5-crafting-blueprints--equipment-upgrades)
6. [Outpost Construction & Placement Rules](#6-outpost-construction--placement-rules)
7. [Planetary Catalog & Scientific Progression](#7-planetary-catalog--scientific-progression)
8. [Mission Directive Protocols](#8-mission-directive-protocols)
9. [Combat Engagement Rules & Threat Bestiary](#9-combat-engagement-rules--threat-bestiary)
10. [Apex Encounter: Goliath Prime Protocol](#10-apex-encounter-goliath-prime-protocol)
11. [Command Terminal AI Operations (NLP)](#11-command-terminal-ai-operations-nlp)
12. [Save Persistence, Pause Freezing & Settings](#12-save-persistence-pause-freezing--settings)

---

## 1. Mission Briefing & Narrative Setting

You are an astronaut operative deployed as part of the **Deep Space Exoplanet Survey Initiative**. Following an atmospheric entry anomaly during orbital insertion, your landing pod crash-lands on the uncharted crust of an alien exoplanet.

Your mission directives:
1. **Survive**: Preserve EVA suit life-support and oxygen integrity in unbreathable alien atmospheres.
2. **Mine & Construct**: Harvest indigenous minerals and construct self-sustaining automated outposts.
3. **Research**: Collect alien bio-specimens to satisfy planetary scientific quotas.
4. **Pacify & Advance**: Neutralize apex planetary guardians to retrieve warp cores and unlock travel to other exoplanets.

---

## 2. Master Controls & Keybindings Reference

Controls can be remapped at any time via **Main Menu -> Settings -> Controls** or **Pause Menu -> Settings**. All bindings automatically persist across play sessions.

| Action | Primary Key | Secondary Key | Function |
| :--- | :--- | :--- | :--- |
| **Move Up / North** | `W` | `Up Arrow` | Move astronaut north across surface |
| **Move Down / South** | `S` | `Down Arrow` | Move astronaut south across surface |
| **Move Left / West** | `A` | `Left Arrow` | Move astronaut west across surface |
| **Move Right / East** | `D` | `Right Arrow` | Move astronaut east across surface |
| **Sprint / Kinetic Boost**| `Shift` | — | Increase movement speed from 200 to 320 px/s |
| **Primary Fire / Shoot** | `Left Mouse Button` | `Spacebar` | Fire plasma pulse rifle toward crosshair |
| **Interact / Mine / Use** | `E` | `Enter` | Harvest resource node or open terminal |
| **Inventory & Crafting** | `I` | `Tab` | Open backpack and crafting station |
| **Construction Menu** | `B` | `C` | Open outpost structure fabrication menu |
| **Star Map / Planets** | `M` | `P` | Open planetary system progression map |
| **Command Terminal** | `~` (Tilde) | `T` | Open typed Natural Language Suit AI |
| **Pathfinding Debug** | `F3` | — | Toggle real-time algorithmic visualizer |
| **Pause Game** | `Escape` | `P` | Pause simulation, freeze vitals, open menu |

---

## 3. Atmospheric Survival & Life-Support Rules

Your EVA pressure suit is your lifeline. Neglecting your suit vitals will result in rapid mission failure.

```
+--------------------------------------------------------------------------+
|                            SUIT LIFE SUPPORT                             |
|                                                                          |
|  [OXYGEN: 84 / 100]  ======> Drain: 1.0 unit/sec (Normal Surface)        |
|  [HEALTH: 100 / 100] ======> Normal Status                               |
+--------------------------------------------------------------------------+
```

### 3.1 Oxygen Depletion Rules
* **Standard Depletion**: Oxygen drains continuously at a base rate of **$1.0\text{ unit/second}$**.
* **Environmental Hazards**: Hostile weather or toxic planetary biomes increase drain rate up to **$1.5\text{ units/second}$**.
* **Sprinting Penalty**: Sprinting increases oxygen consumption by **$+25\%$**.

### 3.2 Suffocation & Health Damage
* When oxygen reaches **$0.0$**, emergency alarms flash crimson.
* The suit enters **Suffocation Mode**, inflicting **$5.0\text{ HP/second}$** direct damage to player health.
* Armor and shields **cannot mitigate suffocation damage**.

### 3.3 Replenishment & Sanctuary Domes
* **Oxygen Cells**: Found scattered across the surface. Harvesting an Oxygen Cell restores **$+30.0\text{ O}_2$** immediately.
* **Atmospheric Sanctuary Domes**: Safe zones enclosed in crystalline domes. Inside a sanctuary dome:
  1. Oxygen drain is **paused entirely ($0.0\text{ O}_2/\text{s}$)**.
  2. The astronaut passively regenerates **$+2.0\text{ HP/second}$**.
  3. Hostile alien enemies cannot cross dome perimeter barriers.

---

## 4. Resource Harvesting, Mining & Economy

The planetary surface is rich in harvestable geological deposits. Stand within $60\text{ px}$ of a deposit and press **[E]** to mine.

```
       [OXYGEN CELL]           [TITANIUM METAL]          [ENERGY CRYSTAL]           [ALIEN BIOMASS]
       Restores Vitals         Base Construction         Weapon Enhancements        Research Quotas
```

| Resource Name | Icon / Color | Primary Purpose | Found In |
| :--- | :--- | :--- | :--- |
| **Oxygen Cell** | Cyan Glow | Refills $+30$ suit life-support | Atmospheric crystal fields |
| **Titanium Metal** | Slate Gray | Constructing walls, scrubbers, turrets | Canyons & rocky crags |
| **Energy Crystal** | Electric Purple | Upgrading plasma pulse rifle & shields | Subterranean caverns & craters |
| **Alien Biomass** | Emerald Green | Planetary research quotas & biotech labs | Defeated alien fauna |

---

## 5. Crafting Blueprints & Equipment Upgrades

Press **[I]** or **[Tab]** to open the **Inventory & Crafting Dialog**.

```
+-----------------------------------------------------------------------+
|                       FABRICATION & CRAFTING TABLE                    |
+-----------------------------------------------------------------------+
|  [RECIPE]                 [COST]                     [EFFECT]         |
|  Reinforced O2 Tank       15 Metal, 5 Crystals       Max O2: 100 -> 150
|  High-Yield Plasma Cell   10 Crystals, 5 Biomass     Rifle Dmg: +35%  |
|  Kinetic Absorber Shield  20 Metal, 10 Crystals      Shield: 50 HP    |
|  Thruster Booster Boots   12 Metal, 8 Crystals       Sprint: +40 px/s |
|  Med-Gel Injector         5 Biomass, 2 O2 Cells      Heals +50 HP     |
+-----------------------------------------------------------------------+
```

### Crafting Rules
1. Crafting executes instantaneously upon pressing **[Craft Item]** if materials are available.
2. Equipment upgrades apply permanently to your astronaut profile and persist into save files.
3. Med-Gel injectors can be stored in quick-slots and activated via **[1 - 4]** during combat.

---

## 6. Outpost Construction & Placement Rules

Press **[B]** to open the **Construction Menu**. BioSphere-X uses an automated Constraint Satisfaction Problem (CSP) solver to enforce realistic spatial planning.

```
+-----------------------------------------------------------------------+
|                         STRUCTURE CATALOG                             |
+-----------------------------------------------------------------------+
|  Structure Type      | Cost              | Function                   |
|  Oxygen Scrubber     | 20 Metal, 5 Cryst | Creates 120px safe zone    |
|  Defense Turret      | 25 Metal, 10 Cryst| Auto-engages enemies (20dmg|
|  Solar Reactor       | 15 Metal, 8 Cryst | Powers nearby structures   |
|  Research Station    | 30 Metal, 15 Bio  | Analyzes planetary samples |
|  Beacon Relay        | 10 Metal, 5 Cryst | Extends radar minimap range|
+-----------------------------------------------------------------------+
```

### Spatial Placement Constraints (CSP Rules)
* **Rule 1 (Terrain Clearance)**: Structures cannot be placed on solid natural walls, jagged boulders, or deep impact craters.
* **Rule 2 (No Overlap)**: Structures must have at least **1 full grid cell ($32\text{ px}$)** clearance from existing buildings.
* **Rule 3 (Resource Gate)**: You must have the required materials in inventory; costs are deducted atomically.
* **Rule 4 (Power Grid Radius)**: Defense turrets and research stations require a Solar Reactor within **$12\text{ grid tiles}$**.

---

## 7. Planetary Catalog & Scientific Progression

Press **[M]** to view the **Exoplanetary Star Map**. Every world is modeled after real scientific data from NASA and the Caltech Exoplanet Archive.

```
[TRAPPIST-1 e] ===> [LHS 1140 b] ===> [Kepler-186 f] ===> [Proxima b] ===> [K2-18 b]
 (Twilight Basin)   (Titan Ridges)   (Subsurface Caves)  (Flare Crags)    (Hycean Sea)
```

| Exoplanet ID | Distance (ly) | Gravity | Temperature | Planetary Hazard | Unlock Requirement |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **TRAPPIST-1 e** | 40.66 | $0.93g$ | $251\text{ K}$ | Moderate O2 Drain ($1.0\times$) | Default Starting Planet |
| **LHS 1140 b** | 48.91 | $1.25g$ | $226\text{ K}$ | High Gravity ($1.2\times$ O2 Drain) | Complete 3 Missions on TRAPPIST-1 e |
| **Kepler-186 f** | 579.0 | $1.04g$ | $188\text{ K}$ | Subzero Frost (Sprint penalized)| Defeat Goliath Prime on LHS 1140 b |
| **Proxima b** | 4.24 | $1.08g$ | $234\text{ K}$ | Flare Radiation ($1.4\times$ Drain) | Secure 20 Biomass on Kepler-186 f |
| **K2-18 b** | 123.9 | $1.10g$ | $255\text{ K}$ | Hycean Vapor & Submerged Bridges| Complete Goliath Protocol Bounty |

---

## 8. Mission Directive Protocols

The planetary HUD tracks primary objectives via the **Mission Directive System**:

1. **Directive Alpha: Life-Support Recovery**:
   * Gather $3\times$ Oxygen Cells and craft a Reinforced O2 Tank.
2. **Directive Beta: Field Research Quotas**:
   * Collect $10\times$ Alien Biomass samples and deliver them to the Research Terminal.
3. **Directive Gamma: Outpost Fortification**:
   * Erect $1\times$ Solar Reactor and $2\times$ Defense Turrets.
4. **Directive Delta: Goliath Protocol**:
   * Locate the ancient impact crater basin and neutralize the apex guardian **Goliath Prime**.

---

## 9. Combat Engagement Rules & Threat Bestiary

Combat is governed by real-time ballistic projectile mechanics and physics impulses.

### 9.1 Ballistic Rules
* Projectiles travel at $450\text{ px/s}$ with a range of $600\text{ px}$.
* Projectiles are stopped by solid rocks and walls, leaving glowing plasma impact scorch marks.
* Hits apply knockback force proportional to rifle charge ($\vec{v} += \vec{d} \cdot F_{\text{knockback}}$).

### 9.2 Alien Bestiary

```
[ALIEN SCOUT]               [ARMORED BRUTE]             [RANGED SPITTER]
HP: 45 | Spd: 210           HP: 160 | Spd: 90           HP: 80 | Spd: 130
Hit-and-Run Flanker         Heavy Tank & Knockback      Corrosive Plasma Artillery
```

* **Alien Scout**: Fast pack hunters. Break line-of-sight behind canyon rocks to force them into investigate mode, then ambush them from behind.
* **Armored Brute**: Heavy armor absorbs $60\%$ knockback. Keep your distance and kite backwards using sprint bursts.
* **Ranged Spitter**: Launches slow-moving green bio-plasma. Strafe perpendicularly to dodge the projectiles while returning fire.

---

## 10. Apex Encounter: Goliath Prime Protocol

The planetary boss **Goliath Prime** guards the warp beacon inside the ancient impact crater basin.

```
       +-----------------------------------------------------------+
       |             BOSS ENCOUNTER PHASES & TACTICS               |
       +-----------------------------------------------------------+
       |  PHASE 1 (100% - 50% HP):                                 |
       |  - Guard Stance: 20% damage absorption.                   |
       |  - Tremor Slam: Red hazard circle telegraphs 1.2s. Dodge! |
       |  - Plasma Nova: 8 radial energy bolts.                    |
       |                                                           |
       |  PHASE 2 (< 50% HP ENRAGED):                              |
       |  - Crimson aura activates (+40% speed, faster attacks).   |
       |  - Charge Rush: 380 px/s bull-charge. Sidestep immediately!
       |                                                           |
       |  FAIR TACTICAL WINDOW (RECOVERY):                         |
       |  - After heavy attacks, Goliath recovers for 1.5s.        |
       |  - Goliath takes +25% BONUS DAMAGE during recovery!       |
       +-----------------------------------------------------------+
```

### Defeat Rewards
Defeating Goliath Prime triggers a colossal reward cache drop:
* **$3\times$ Energy Crystals**
* **$3\times$ Titanium Metal**
* **$3\times$ Alien Biomass**
* **$2\times$ Oxygen Cells**
* **Planetary Warp Core** (Unlocks the next exoplanet on the Star Map).

---

## 11. Command Terminal AI Operations (NLP)

Press **[~]** or **[T]** to open the Natural Language Command Terminal. The terminal processes plain-English typed instructions offline without cloud lag or subscriptions.

### Supported Commands & Syntax Examples
* **Navigation**:
  * `"navigate to nearest sanctuary dome"`
  * `"guide me to landing zone"`
* **Construction**:
  * `"build oxygen scrubber at coordinates 25 30"`
  * `"construct defense turret"`
* **Fabrication**:
  * `"craft high yield plasma cell"`
  * `"make med-gel injector"`
* **Diagnostics**:
  * `"status report"`
  * `"report suit oxygen levels and health"`

---

## 12. Save Persistence, Pause Freezing & Settings

### 12.1 Atomic Save System
* Pressing **[Save Game]** in the pause menu or reaching a planetary checkpoint executes an atomic file transaction to `user://biosphere_x_save.json`.
* If system power is lost during a write, the previous backup is preserved, guaranteeing **zero save corruption**.

### 12.2 Pause Freezing Guarantees
* When the pause menu is active (**[Escape]**):
  * **Oxygen depletion is frozen completely ($0.0\text{ drain}$)**.
  * All enemy AI perception ticks, combat timers, and projectiles pause.
  * Audio volume lowers with an ambient low-pass filter.

### 12.3 Display & Graphics Settings
* Supports Windowed, Borderless, and Fullscreen modes.
* Full UI resolution scaling accommodates displays from $1280 \times 720$ up to $4\text{K}$ Ultra-HD.
