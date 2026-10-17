"""
BioSphere-X AI Backend Application Entry Point.
Provides a local HTTP API for advanced AI algorithms including pathfinding,
adversarial decision-making, fuzzy inference, CSP, logic deduction, planning, and NLP.
"""
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import Any, Dict
import time
import sys
from pathlib import Path

# Ensure ai_backend directory is in sys.path so 'algorithms' is always found
backend_dir = Path(__file__).resolve().parent
if str(backend_dir) not in sys.path:
    sys.path.insert(0, str(backend_dir))

from algorithms.pathfinding.router import router as pathfinding_router
from algorithms.adversarial.router import router as adversarial_router
from algorithms.fuzzy.router import router as fuzzy_router
from algorithms.csp.router import router as csp_router
from algorithms.logic.router import router as logic_router
from algorithms.nlp.router import router as nlp_router

app = FastAPI(
    title="BioSphere-X AI Backend",
    description="Python AI Lab service powering BioSphere-X simulation algorithms",
    version="1.0.0"
)

# Enable CORS for local cross-origin connections
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Attach algorithm routers
app.include_router(pathfinding_router)
app.include_router(adversarial_router)
app.include_router(fuzzy_router)
app.include_router(csp_router)
app.include_router(logic_router)
app.include_router(nlp_router)


class EchoRequest(BaseModel):
    message: str = Field(default="ping")
    payload: Dict[str, Any] = Field(default_factory=dict)


class EchoResponse(BaseModel):
    status: str
    message: str
    payload: Dict[str, Any]
    server_time: float


@app.get("/health", tags=["Health"])
def health_check():
    """
    Standard health check endpoint to verify backend availability.
    """
    return {
        "status": "ok",
        "service": "BioSphere-X AI Backend",
        "version": "1.0.0",
        "timestamp": time.time()
    }


@app.get("/api/test", tags=["Test"])
def test_connection():
    """
    Simple verification endpoint for testing Godot to Python communication.
    """
    return {
        "status": "success",
        "message": "Python AI Backend is active and connected to BioSphere-X!",
        "service": "BioSphere-X AI Backend",
        "timestamp": time.time()
    }


@app.post("/api/test-echo", response_model=EchoResponse, tags=["Test"])
def test_echo(req: EchoRequest):
    """
    Echo test endpoint to verify JSON POST communication between Godot and Python.
    """
    return EchoResponse(
        status="success",
        message=f"Echo from Python: {req.message}",
        payload=req.payload,
        server_time=time.time()
    )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="127.0.0.1", port=8000, reload=True)
