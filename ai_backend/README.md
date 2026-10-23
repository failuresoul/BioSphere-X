# BioSphere X AI backend

The current game's setup, controls, and exact algorithm call sites are documented in the [project README](../README.md). This folder contains the local FastAPI service used by the 2D campaign.

From the project root, after installing [`requirements.txt`](requirements.txt) into `ai_backend/.venv`:

```powershell
.\ai_backend\.venv\Scripts\python.exe -m uvicorn ai_backend.main:app --host 127.0.0.1 --port 8000
```

Check `http://127.0.0.1:8000/health` and browse the live API at `http://127.0.0.1:8000/docs`.

| API group | Implementation | Current game use |
| --- | --- | --- |
| `/api/ai/boss` | [`adversarial/`](algorithms/adversarial/router.py) | Alpha-beta, Minimax, and MCTS boss decisions. |
| `/api/ai/fuzzy` | [`fuzzy/`](algorithms/fuzzy/router.py) | Adaptive boss aggression. |
| `/api/ai/csp` | [`csp/`](algorithms/csp/router.py) | Legal exploration pickup location. |
| `/api/ai/logic` | [`logic/`](algorithms/logic/router.py) | Forward-chaining victory confirmation. |
| `/api/ai/nlp` | [`nlp/`](algorithms/nlp/router.py) | Suit command parsing. |
| `/api/ai/pathfinding` | [`pathfinding/`](algorithms/pathfinding/router.py) | Exposed and tested here; the current game's boss route search runs locally in Godot. |

[`planning/`](algorithms/planning/__init__.py) is a placeholder; GOAP/STRIPS planning is not part of the current game. Run backend tests from the project root with `.\ai_backend\.venv\Scripts\python.exe -m pytest -q ai_backend\tests`.
