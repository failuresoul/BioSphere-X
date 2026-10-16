"""
BioSphere-X Fuzzy Inference System Modules.
Adaptive difficulty regulation and creature aggression evaluation.
"""
from .membership import LinguisticVariable, triangular, trapezoidal
from .rules import FuzzyRule
from .engine import FuzzyInferenceEngine, FIXED_DIFFICULTY_PROFILES
from .router import router

__all__ = [
    "LinguisticVariable",
    "triangular",
    "trapezoidal",
    "FuzzyRule",
    "FuzzyInferenceEngine",
    "FIXED_DIFFICULTY_PROFILES",
    "router"
]
