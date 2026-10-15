# BioSphere-X

A 2D top-down sci-fi survival game set on alien exoplanets, built with **Godot 4** and an asynchronous **Python AI Backend**.

---

## Architecture & System Separation

- **Godot 4 (GDScript Frontend / Game Client)**:
  - 60+ FPS real-time gameplay loop, 2D rendering, camera controls, player input handling, CharacterBody2D physics, explorable maps, collision boundaries, procedural animations, and UI.
- **Python FastAPI (AI Lab Backend / Server)**:
  - Standalone service handling advanced computational algorithms:
    - **Pathfinding**: Grid A* and heuristic path planning.
    - **Adversarial Decisions**: Minimax, Alpha-Beta pruning, creature confrontation logic.
    - **Fuzzy Inference**: Environmental hazard and creature aggression evaluation.
    - **Constraint Satisfaction (CSP)**: Base building layout and resource scheduling.
    - **Logic Inference**: First-order logic engine for alien flora/fauna discovery deduction.
    - **Automated Planning**: GOAP / STRIPS survival and base expansion planning.
    - **NLP**: Communications decoding, alien signal translation, research logs.

---

## Prerequisites

1. **Godot 4.x** (Standard build, version 4.0+)
2. **Python 3.10+** (Python 3.13 tested and supported)

---

## How to Launch Both Applications

### 1. Launch the Python AI Backend
In a terminal, navigate to the `ai_backend` folder:
```powershell
# Navigate to backend directory
cd ai_backend

# (Optional) Activate virtual environment if using .venv
.\.venv\Scripts\Activate.ps1   # Windows PowerShell
# source .venv/bin/activate    # Linux / macOS

# Install dependencies (first time only)
pip install -r requirements.txt

# Start the FastAPI server on port 8000
uvicorn main:app --host 127.0.0.1 --port 8000 --reload
```
- Health Check: `http://127.0.0.1:8000/health`
- Swagger Interactive API Docs: `http://127.0.0.1:8000/docs`

### 2. Launch the Godot Game
- Open **Godot 4**, click **Import**, select `project.godot` in this repository, and press **F5** (or the ▶ Run button).
- Or run directly from terminal:
  ```powershell
  godot --path .
  ```

---

## Graceful Degradation & Offline Mode

The Godot game client includes an automated asynchronous client ([ai_client.gd](file:///e:/Ai%20Project/scripts/autoloads/ai_client.gd)):
- **If the Python backend is offline**: The game continues running smoothly without hanging, freezing, or crashing. Local Godot systems (like native `AStarGrid2D`) seamlessly provide fallback behavior.
- **When the backend connects**: The client automatically detects availability and routes AI queries to Python.

---

## Project Structure

```
├── ai_backend/             # Python AI Lab Backend Service
│   ├── algorithms/         # Modular algorithm implementations
│   │   ├── adversarial/    # Minimax & Alpha-Beta decision logic
│   │   ├── csp/            # Constraint satisfaction problems
│   │   ├── fuzzy/          # Fuzzy logic danger & threat models
│   │   ├── logic/          # Propositional & first-order logic engine
│   │   ├── nlp/            # Natural language processing & dialogue
│   │   ├── pathfinding/    # A* pathfinding algorithm & router
│   │   └── planning/       # GOAP / STRIPS automated planning
│   ├── tests/              # Pytest test suite
│   ├── main.py             # FastAPI entry point & test endpoints
│   ├── requirements.txt    # Python dependencies
│   └── README.md           # Backend documentation & API guide
│
├── assets/                 # Art, audio, fonts, tilesets
├── data/                   # JSON / config data files
├── resources/              # Custom Godot resources (.tres)
├── scenes/                 # All Godot scenes
│   ├── enemies/
│   ├── items/
│   ├── main/               # Entry-point scene (main.tscn)
│   ├── player/             # Astronaut player scene (player.tscn)
│   └── world/              # Explorable game world scene (game_world.tscn)
├── scripts/
│   ├── autoloads/          # Singletons (e.g., ai_client.gd)
│   ├── components/         # Reusable nodes (MapData, Health, Interactions, etc.)
│   └── utils/              # Helper utilities
├── tests/                  # Automated Godot headless test suites
├── project.godot           # Godot project configuration
└── README.md
```

---

## Automated Test Suites

Run test suites from the project root:
```powershell
# Python Backend Tests
pytest ai_backend

# Godot Player Tests
godot --headless -s res://tests/test_player.gd

# Godot Animation & 8-Way Direction Tests
godot --headless -s res://tests/test_player_animation.gd

# Godot Map & AStar Navigation Tests
godot --headless -s res://tests/test_map.gd

# Godot AIClient HTTP Integration Tests
godot --headless res://tests/test_ai_client.tscn
```
