# BioSphere-X Python AI Backend

High-performance Python AI service powering the advanced simulation algorithms for **BioSphere-X**.

## Architecture & Separation of Concerns

- **Godot 4 Engine (Frontend / Client)**:
  - Real-time 60+ FPS game simulation, 2D rendering, camera controls, player input handling, local CharacterBody2D physics, tile maps, particle animations, and UI.
- **Python FastAPI Service (AI Backend / Server)**:
  - Complex computational algorithms:
    1. **Pathfinding**: Grid-based A*, hierarchical path planning, dynamic flow fields.
    2. **Adversarial**: Minimax, Alpha-Beta pruning, creature confrontation logic.
    3. **Fuzzy Inference**: Danger evaluation, threat assessment, creature state transitions.
    4. **Constraint Satisfaction (CSP)**: Base building layout, resource allocation schedules.
    5. **Logic Inference**: First-order logic engine for alien flora/fauna discovery deduction.
    6. **Automated Planning**: GOAP / STRIPS goal-oriented planning for survival behaviors.
    7. **NLP**: Communications decoding, alien signal translation, research log queries.

---

## Setup Guide (Virtual Environment)

### 1. Prerequisites
- Python 3.10+ (Python 3.13 tested and supported)

### 2. Create Virtual Environment
Open PowerShell or your command prompt in this directory (`ai_backend`):
```powershell
python -m venv .venv
```

### 3. Activate Virtual Environment
- **Windows (PowerShell)**:
  ```powershell
  .\.venv\Scripts\Activate.ps1
  ```
- **Windows (Command Prompt)**:
  ```cmd
  .venv\Scripts\activate.bat
  ```
- **Linux / macOS**:
  ```bash
  source .venv/bin/activate
  ```

### 4. Install Dependencies
```bash
pip install -r requirements.txt
```

---

## Running the AI Backend

Start the FastAPI local development server with auto-reload:

```bash
uvicorn main:app --host 127.0.0.1 --port 8000 --reload
```

The server will be available at:
- **Base URL**: `http://127.0.0.1:8000`
- **Interactive Swagger Docs**: `http://127.0.0.1:8000/docs`
- **OpenAPI JSON**: `http://127.0.0.1:8000/openapi.json`

---

## API Endpoints Reference

### Health & Connectivity
- `GET /health`: Returns service health status, version, and server timestamp.
- `GET /api/test`: Verifies basic GET communication between Godot and Python.
- `POST /api/test-echo`: Echoes back payload to verify JSON serialization and HTTP POST integrity.

### Algorithms
- `POST /api/ai/pathfinding/find-path`: Solves 2D grid path from `start` to `goal` considering `blocked_cells`.
- *(Upcoming endpoints for adversarial, fuzzy, csp, logic, planning, and nlp will be routed under `/api/ai/...`)*

---

## Graceful Degradation in Godot

If the Python backend is offline or unreachable:
- The Godot game client continues running smoothly without hanging, freezing, or crashing.
- `AIClient` automatically flags the backend as offline and falls back to local Godot components (such as native `AStarGrid2D`).
