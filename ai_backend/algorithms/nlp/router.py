"""
FastAPI Router for BioSphere-X Offline Command Parser.
Exposes endpoints for natural language gameplay command parsing and intent discovery.
"""
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from typing import Any, Dict, List, Optional

from .parser import CommandParser, ParsedCommand

router = APIRouter(prefix="/api/ai/nlp", tags=["Natural Language Command Parser"])

# Global singleton parser instance
parser = CommandParser()


class ParseRequest(BaseModel):
    query: str = Field(description="Raw player command text")
    context: Optional[Dict[str, Any]] = Field(default=None, description="Optional current game context")


class ParseResponse(BaseModel):
    status: str
    parsed: ParsedCommand


class CommandCatalogResponse(BaseModel):
    status: str = "success"
    commands: List[Dict[str, Any]]
    count: int


@router.post("/parse", response_model=ParseResponse)
def parse_command(req: ParseRequest) -> ParseResponse:
    """
    Parses a natural language gameplay command into a structured intent with validated parameters.
    Returns status, intent, parameters, confidence, and clarification if ambiguous or unknown.
    Does NOT alter game state.
    """
    try:
        parsed = parser.parse(req.query, req.context)
        return ParseResponse(
            status=parsed.status,
            parsed=parsed
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Command parsing failed: {str(e)}")


@router.get("/commands", response_model=CommandCatalogResponse)
def get_command_catalog() -> CommandCatalogResponse:
    """
    Returns full catalog of supported commands, descriptions, and examples.
    """
    catalog = parser.SUPPORTED_INTENTS
    return CommandCatalogResponse(
        status="success",
        commands=catalog,
        count=len(catalog)
    )
