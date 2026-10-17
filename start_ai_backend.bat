@echo off
title BioSphere-X Python AI Backend
echo ========================================================
echo   Starting BioSphere-X Python AI Backend Server
echo   API Docs: http://127.0.0.1:8000/docs
echo   Health:   http://127.0.0.1:8000/health
echo ========================================================
cd /d "%~dp0"
if exist "ai_backend\.venv\Scripts\python.exe" (
    echo Using project virtual environment...
    "ai_backend\.venv\Scripts\python.exe" -m uvicorn ai_backend.main:app --host 127.0.0.1 --port 8000 --reload
) else (
    echo Using system Python installation...
    python -m uvicorn ai_backend.main:app --host 127.0.0.1 --port 8000 --reload
)
pause
