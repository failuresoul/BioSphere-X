"""
Natural Language Processing (NLP) module for BioSphere-X.
Provides lightweight offline intent parsing and slot filling for astronaut commands.
"""
from .parser import CommandParser, ParsedCommand

__all__ = ["CommandParser", "ParsedCommand"]
