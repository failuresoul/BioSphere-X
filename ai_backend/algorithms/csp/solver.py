"""
BioSphere-X Base-Structure Placement Constraint Satisfaction Problem (CSP) Solver.
Evaluates spatial and economic constraints for base construction:
  1. Resource availability (economic constraint).
  2. Grid boundary containment (domain constraint).
  3. Authorized build zone boundaries (territorial constraint).
  4. Blocked terrain obstacle clearance (collision constraint).
  5. Existing structure non-overlap (unary/binary collision constraint).
  6. Minimum spacing buffer between structures (proximity clearance constraint).
"""
import time
from typing import List, Dict, Tuple, Set, Optional, Any
from pydantic import BaseModel, Field


# ---------------------------------------------------------------------------
# Default Known Structure Catalog
# ---------------------------------------------------------------------------
STRUCTURE_CATALOG: Dict[str, Dict[str, Any]] = {
    "oxygen_generator": {
        "id": "oxygen_generator",
        "name": "Life-Support Pod",
        "size": [2, 2],
        "cost": {"titanium": 4, "crystals": 2},
        "min_spacing": 1,
        "description": "Atmospheric generator producing regional oxygen safe zone."
    },
    "defense_turret": {
        "id": "defense_turret",
        "name": "Automated Sentry",
        "size": [1, 1],
        "cost": {"titanium": 3, "crystals": 3},
        "min_spacing": 2,
        "description": "Perimeter defense turret targeting hostile indigenous predators."
    },
    "solar_array": {
        "id": "solar_array",
        "name": "Photovoltaic Array",
        "size": [2, 1],
        "cost": {"titanium": 2, "crystals": 2},
        "min_spacing": 1,
        "description": "Auxiliary solar generator recharging suit energy cells."
    },
    "storage_depot": {
        "id": "storage_depot",
        "name": "Resource Depot",
        "size": [2, 2],
        "cost": {"titanium": 5, "biomass": 2},
        "min_spacing": 1,
        "description": "Reinforced field vault for securing surface harvest specimens."
    },
    "bio_dome": {
        "id": "bio_dome",
        "name": "Biosphere Hab Dome",
        "size": [3, 3],
        "cost": {"titanium": 8, "biomass": 6, "crystals": 4},
        "min_spacing": 2,
        "description": "Controlled atmospheric habitat module for long-term survival."
    },
    "radar_beacon": {
        "id": "radar_beacon",
        "name": "Telemetry Beacon",
        "size": [1, 1],
        "cost": {"titanium": 2, "crystals": 1},
        "min_spacing": 1,
        "description": "Tactical scanning radar revealing map hazards and specimens."
    }
}


# ---------------------------------------------------------------------------
# Pydantic Request / Response Models
# ---------------------------------------------------------------------------
class ExistingStructure(BaseModel):
    id: str = Field(description="Unique instance or type ID of existing structure")
    name: Optional[str] = Field(default="Existing Structure", description="Display name")
    position: List[int] = Field(description="[x, y] top-left grid coordinate")
    size: List[int] = Field(default=[1, 1], description="[width, height] in grid cells")
    min_spacing: Optional[int] = Field(default=1, description="Spacing required by this structure")


class PlacementRequest(BaseModel):
    structure_id: str = Field(description="Type ID of structure to place")
    position: List[int] = Field(description="[x, y] candidate top-left grid coordinates")
    structure_size: Optional[List[int]] = Field(default=None, description="[width, height] in cells. If None, derived from catalog.")
    structure_cost: Optional[Dict[str, int]] = Field(default=None, description="Resource cost. If None, derived from catalog.")
    min_spacing: Optional[int] = Field(default=None, description="Minimum spacing in cells. If None, derived from catalog.")
    available_resources: Dict[str, int] = Field(default_factory=dict, description="Player current carried resources")
    grid_size: List[int] = Field(default=[80, 80], description="[grid_width, grid_height]")
    build_zone: Optional[List[int]] = Field(default=None, description="Optional build zone [min_x, min_y, max_x, max_y]")
    blocked_cells: List[List[int]] = Field(default_factory=list, description="List of [x, y] coordinates with natural terrain obstacles")
    existing_structures: List[ExistingStructure] = Field(default_factory=list, description="List of already placed structures")
    occupied_cells: Optional[List[List[int]]] = Field(default=None, description="Optional explicit list of [x, y] cells occupied by structures")


class PlacementResponse(BaseModel):
    valid: bool = Field(description="True if placement satisfies all constraints; False otherwise")
    reason: str = Field(description="Human-readable reason if invalid, or empty string if valid")
    violated_constraints: List[str] = Field(default_factory=list, description="Constraint violation tags: RESOURCES, BOUNDS, BUILD_ZONE, BLOCKED, OCCUPIED, MIN_SPACING")
    structure_id: str
    structure_name: str
    position: List[int]
    structure_size: List[int]
    cost: Dict[str, int]
    occupied_footprint: List[List[int]] = Field(description="Cells candidate structure occupies")
    clearance_zone: List[List[int]] = Field(description="Perimeter buffer cells required by min_spacing")
    remaining_resources: Dict[str, int] = Field(description="Projected resources remaining after deduction (if valid)")
    execution_time_ms: float


class SuggestPlacementsRequest(BaseModel):
    structure_id: str
    search_zone: Optional[List[int]] = Field(default=None, description="[min_x, min_y, max_x, max_y] search bounds")
    max_suggestions: int = Field(default=5, ge=1, le=50)
    available_resources: Dict[str, int] = Field(default_factory=dict)
    grid_size: List[int] = Field(default=[80, 80])
    build_zone: Optional[List[int]] = Field(default=None)
    blocked_cells: List[List[int]] = Field(default_factory=list)
    existing_structures: List[ExistingStructure] = Field(default_factory=list)
    occupied_cells: Optional[List[List[int]]] = Field(default=None)


class SuggestPlacementsResponse(BaseModel):
    structure_id: str
    suggestions: List[List[int]] = Field(description="List of valid [x, y] coordinates")
    total_evaluated: int
    execution_time_ms: float


# ---------------------------------------------------------------------------
# Core Placement Constraint Solver Engine
# ---------------------------------------------------------------------------
class BasePlacementSolver:
    """
    Evaluates and solves CSP constraints for base structure placement in BioSphere-X.
    """

    @staticmethod
    def get_footprint(pos_x: int, pos_y: int, width: int, height: int) -> List[Tuple[int, int]]:
        """Returns all grid cells within the axis-aligned rectangular footprint."""
        cells: List[Tuple[int, int]] = []
        for dy in range(height):
            for dx in range(width):
                cells.append((pos_x + dx, pos_y + dy))
        return cells

    @staticmethod
    def get_clearance_zone(pos_x: int, pos_y: int, width: int, height: int, spacing: int) -> List[Tuple[int, int]]:
        """Returns the perimeter halo cells surrounding the footprint up to `spacing` cells."""
        if spacing <= 0:
            return []
        
        footprint_set = set(BasePlacementSolver.get_footprint(pos_x, pos_y, width, height))
        clearance_cells: List[Tuple[int, int]] = []
        
        for dy in range(-spacing, height + spacing):
            for dx in range(-spacing, width + spacing):
                cell = (pos_x + dx, pos_y + dy)
                if cell not in footprint_set:
                    clearance_cells.append(cell)
        return clearance_cells

    def validate(self, req: PlacementRequest) -> PlacementResponse:
        start_time = time.perf_counter()

        # 1. Resolve structure definition & attributes
        catalog_entry = STRUCTURE_CATALOG.get(req.structure_id, {})
        struct_name = catalog_entry.get("name", req.structure_id.replace("_", " ").title())
        
        size = req.structure_size or catalog_entry.get("size", [1, 1])
        width, height = size[0], size[1]
        
        cost = req.structure_cost if req.structure_cost is not None else catalog_entry.get("cost", {})
        min_spacing = req.min_spacing if req.min_spacing is not None else catalog_entry.get("min_spacing", 1)

        pos_x, pos_y = req.position[0], req.position[1]
        footprint = self.get_footprint(pos_x, pos_y, width, height)
        clearance_zone = self.get_clearance_zone(pos_x, pos_y, width, height, min_spacing)

        violated: List[str] = []
        reasons: List[str] = []

        # -------------------------------------------------------------------
        # Constraint 1: Available Resources (Economic Constraint)
        # -------------------------------------------------------------------
        insufficient_resources: List[str] = []
        remaining_res: Dict[str, int] = dict(req.available_resources)
        for res_name, needed in cost.items():
            avail = req.available_resources.get(res_name, 0)
            if avail < needed:
                insufficient_resources.append(f"{res_name} (need {needed}, have {avail})")
            else:
                remaining_res[res_name] = avail - needed

        if insufficient_resources:
            violated.append("RESOURCES")
            reasons.append(f"Insufficient resources: {', '.join(insufficient_resources)}")

        # -------------------------------------------------------------------
        # Constraint 2: Grid Boundaries (Domain Constraint)
        # -------------------------------------------------------------------
        grid_w, grid_h = req.grid_size[0], req.grid_size[1]
        out_of_bounds: List[Tuple[int, int]] = []
        for cx, cy in footprint:
            if cx < 0 or cx >= grid_w or cy < 0 or cy >= grid_h:
                out_of_bounds.append((cx, cy))

        if out_of_bounds:
            violated.append("BOUNDS")
            reasons.append(f"Structure footprint extends outside world grid [0, 0, {grid_w}, {grid_h}] at {out_of_bounds[0]}")

        # -------------------------------------------------------------------
        # Constraint 3: Build Zone Boundaries (Territorial Constraint)
        # -------------------------------------------------------------------
        if req.build_zone is not None and len(req.build_zone) == 4:
            bz_x1, bz_y1, bz_x2, bz_y2 = req.build_zone
            outside_bz: List[Tuple[int, int]] = []
            for cx, cy in footprint:
                if cx < bz_x1 or cx > bz_x2 or cy < bz_y1 or cy > bz_y2:
                    outside_bz.append((cx, cy))
            
            if outside_bz:
                violated.append("BUILD_ZONE")
                reasons.append(f"Structure footprint at {outside_bz[0]} is outside authorized base build zone [{bz_x1}, {bz_y1}, {bz_x2}, {bz_y2}]")

        # -------------------------------------------------------------------
        # Constraint 4: Blocked Natural Terrain (Collision Constraint)
        # -------------------------------------------------------------------
        blocked_set: Set[Tuple[int, int]] = {(c[0], c[1]) for c in req.blocked_cells}
        blocked_collisions: List[Tuple[int, int]] = []
        for cell in footprint:
            if cell in blocked_set:
                blocked_collisions.append(cell)

        if blocked_collisions:
            violated.append("BLOCKED")
            reasons.append(f"Structure footprint collides with natural terrain obstacle at ({blocked_collisions[0][0]}, {blocked_collisions[0][1]})")

        # -------------------------------------------------------------------
        # Constraint 5: Occupied Structure Cells (Overlap Constraint)
        # -------------------------------------------------------------------
        occupied_map: Dict[Tuple[int, int], str] = {}
        for struct in req.existing_structures:
            s_w, s_h = struct.size[0], struct.size[1]
            s_name = struct.name or struct.id
            for s_cell in self.get_footprint(struct.position[0], struct.position[1], s_w, s_h):
                occupied_map[s_cell] = s_name

        if req.occupied_cells:
            for oc in req.occupied_cells:
                cell_tuple = (oc[0], oc[1])
                if cell_tuple not in occupied_map:
                    occupied_map[cell_tuple] = "Existing Structure"

        overlap_collisions: List[Tuple[Tuple[int, int], str]] = []
        for cell in footprint:
            if cell in occupied_map:
                overlap_collisions.append((cell, occupied_map[cell]))

        if overlap_collisions:
            violated.append("OCCUPIED")
            coll_cell, coll_name = overlap_collisions[0]
            reasons.append(f"Structure overlaps existing '{coll_name}' at ({coll_cell[0]}, {coll_cell[1]})")

        # -------------------------------------------------------------------
        # Constraint 6: Minimum Spacing Clearance (Proximity Buffer)
        # -------------------------------------------------------------------
        # Distance metric: Chebyshev distance max(|x1-x2|, |y1-y2|).
        # A min_spacing of S requires clearance distance d >= (S + 1) between any cell of
        # the candidate structure and any cell of an existing structure.
        # Alternatively: candidate clearance zone must not overlap existing structures,
        # AND candidate footprint must not overlap existing structure's clearance zones.
        spacing_violations: List[str] = []
        for struct in req.existing_structures:
            s_w, s_h = struct.size[0], struct.size[1]
            s_spacing = struct.min_spacing if struct.min_spacing is not None else 1
            effective_spacing = max(min_spacing, s_spacing)
            
            if effective_spacing <= 0:
                continue

            s_footprint = self.get_footprint(struct.position[0], struct.position[1], s_w, s_h)
            
            # Check minimum Chebyshev distance between any cell of candidate and any cell of existing
            for c_cell in footprint:
                for s_cell in s_footprint:
                    dist = max(abs(c_cell[0] - s_cell[0]), abs(c_cell[1] - s_cell[1]))
                    # If dist is 0, it's an overlap (handled by OCCUPIED).
                    # If 0 < dist <= effective_spacing, it's a spacing violation!
                    if 0 < dist <= effective_spacing:
                        s_name = struct.name or struct.id
                        spacing_violations.append(
                            f"Too close to '{s_name}' (clearance: {dist} cells, required: {effective_spacing + 1} cells)"
                        )
                        break
                if spacing_violations:
                    break

        if spacing_violations:
            violated.append("MIN_SPACING")
            reasons.append(spacing_violations[0])

        elapsed_ms = (time.perf_counter() - start_time) * 1000.0
        is_valid = len(violated) == 0
        final_reason = reasons[0] if reasons else ""

        return PlacementResponse(
            valid=is_valid,
            reason=final_reason,
            violated_constraints=violated,
            structure_id=req.structure_id,
            structure_name=struct_name,
            position=[pos_x, pos_y],
            structure_size=[width, height],
            cost=cost,
            occupied_footprint=[[c[0], c[1]] for c in footprint],
            clearance_zone=[[c[0], c[1]] for c in clearance_zone],
            remaining_resources=remaining_res if is_valid else dict(req.available_resources),
            execution_time_ms=round(elapsed_ms, 3)
        )

    def suggest_placements(self, req: SuggestPlacementsRequest) -> SuggestPlacementsResponse:
        """
        Searches for valid candidate placement positions within the search zone
        satisfying all constraints.
        """
        start_time = time.perf_counter()
        
        # Determine search bounds
        if req.search_zone:
            min_x, min_y, max_x, max_y = req.search_zone
        elif req.build_zone:
            min_x, min_y, max_x, max_y = req.build_zone
        else:
            min_x, min_y = 0, 0
            max_x = min(req.grid_size[0] - 1, 30)
            max_y = min(req.grid_size[1] - 1, 30)

        # Structure dimensions
        catalog_entry = STRUCTURE_CATALOG.get(req.structure_id, {})
        size = catalog_entry.get("size", [1, 1])
        w, h = size[0], size[1]

        valid_positions: List[List[int]] = []
        evaluated = 0

        for y in range(min_y, max_y - h + 2):
            for x in range(min_x, max_x - w + 2):
                evaluated += 1
                eval_req = PlacementRequest(
                    structure_id=req.structure_id,
                    position=[x, y],
                    structure_size=size,
                    structure_cost=catalog_entry.get("cost", {}),
                    min_spacing=catalog_entry.get("min_spacing", 1),
                    available_resources=req.available_resources,
                    grid_size=req.grid_size,
                    build_zone=req.build_zone,
                    blocked_cells=req.blocked_cells,
                    existing_structures=req.existing_structures,
                    occupied_cells=req.occupied_cells
                )
                res = self.validate(eval_req)
                if res.valid:
                    valid_positions.append([x, y])
                    if len(valid_positions) >= req.max_suggestions:
                        break
            if len(valid_positions) >= req.max_suggestions:
                break

        elapsed_ms = (time.perf_counter() - start_time) * 1000.0
        return SuggestPlacementsResponse(
            structure_id=req.structure_id,
            suggestions=valid_positions,
            total_evaluated=evaluated,
            execution_time_ms=round(elapsed_ms, 3)
        )
