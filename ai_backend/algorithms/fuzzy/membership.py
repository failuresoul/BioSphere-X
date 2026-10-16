"""
Fuzzy Logic Membership Functions and Linguistic Variables for BioSphere-X.
Defines triangular and trapezoidal membership functions and linguistic variable domain representations.
"""
from typing import Callable, Dict, Tuple, Any
import math


def triangular(x: float, a: float, b: float, c: float) -> float:
    """
    Triangular membership function:
    - 0 for x <= a or x >= c
    - (x - a) / (b - a) for a < x <= b
    - (c - x) / (c - b) for b < x < c
    """
    if x <= a or x >= c:
        return 0.0
    if math.isclose(x, b, abs_tol=1e-7):
        return 1.0
    if a < x <= b:
        return (x - a) / (b - a) if not math.isclose(b, a, abs_tol=1e-7) else 1.0
    if b < x < c:
        return (c - x) / (c - b) if not math.isclose(c, b, abs_tol=1e-7) else 1.0
    return 0.0


def trapezoidal(x: float, a: float, b: float, c: float, d: float) -> float:
    """
    Trapezoidal membership function:
    - 0 for x <= a or x >= d
    - (x - a) / (b - a) for a < x < b
    - 1 for b <= x <= c
    - (d - x) / (d - c) for c < x < d
    """
    if x <= a or x >= d:
        return 0.0
    if b <= x <= c:
        return 1.0
    if a < x < b:
        return (x - a) / (b - a) if not math.isclose(b, a, abs_tol=1e-7) else 1.0
    if c < x < d:
        return (d - x) / (d - c) if not math.isclose(d, c, abs_tol=1e-7) else 1.0
    return 0.0


class LinguisticVariable:
    """
    Represents an input or output linguistic variable with named fuzzy sets (terms)
    and their corresponding membership functions.
    """
    def __init__(self, name: str, domain: Tuple[float, float]):
        self.name = name
        self.domain_min = domain[0]
        self.domain_max = domain[1]
        self.terms: Dict[str, Callable[[float], float]] = {}

    def add_term(self, term_name: str, mf: Callable[[float], float]) -> 'LinguisticVariable':
        """Registers a named fuzzy set and its membership function."""
        self.terms[term_name] = mf
        return self

    def fuzzify(self, value: float) -> Dict[str, float]:
        """
        Calculates membership degrees for all terms for a given crisp input value.
        Clamps value to domain bounds.
        """
        clamped_val = max(self.domain_min, min(self.domain_max, float(value)))
        memberships: Dict[str, float] = {}
        for term_name, mf in self.terms.items():
            degree = mf(clamped_val)
            memberships[term_name] = max(0.0, min(1.0, float(degree)))
        return memberships
