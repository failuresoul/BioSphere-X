extends RefCounted
class_name PlacementConstraintValidator
## Separate, extensible modular constraint-checking engine for structure placement.
## Enforces blocked tiles, occupied cells, build zone boundaries, minimum spacing, and resources.
## New complex placement rules (e.g. power grid reach, oxygen piping, foundation stability)
## can be added dynamically by extending BaseConstraintRule.

# ---------------------------------------------------------------------------
# Base Constraint Rule Interface
# ---------------------------------------------------------------------------
class BaseConstraintRule extends RefCounted:
	var rule_id: String = "BASE_RULE"
	var description: String = "Base placement rule"
	
	func evaluate(_candidate: Dictionary, _context: Dictionary) -> Dictionary:
		return {"valid": true, "reason": "", "constraint_id": rule_id}


# ---------------------------------------------------------------------------
# Rule 1: Blocked Natural Terrain Tiles Rule
# ---------------------------------------------------------------------------
class BlockedTileRule extends BaseConstraintRule:
	func _init() -> void:
		rule_id = "BLOCKED"
		description = "Checks that footprint does not collide with natural terrain obstacles (rocks, walls, boundaries)."
		
	func evaluate(candidate: Dictionary, context: Dictionary) -> Dictionary:
		var map = context.get("map_data")
		if not map or not map.has_method("is_cell_blocked"):
			return {"valid": true, "reason": "", "constraint_id": rule_id}
			
		var footprint: Array = candidate.get("footprint", [])
		for c in footprint:
			var cell: Vector2i = c
			if bool(map.call("is_cell_blocked", cell)):
				return {
					"valid": false,
					"reason": "Placement collides with blocked terrain at (%d, %d)." % [cell.x, cell.y],
					"constraint_id": rule_id
				}
		return {"valid": true, "reason": "", "constraint_id": rule_id}


# ---------------------------------------------------------------------------
# Rule 2: Occupied Existing Structure Cells Rule
# ---------------------------------------------------------------------------
class OccupiedCellRule extends BaseConstraintRule:
	func _init() -> void:
		rule_id = "OCCUPIED"
		description = "Checks that footprint does not overlap existing buildings or facilities."
		
	func evaluate(candidate: Dictionary, context: Dictionary) -> Dictionary:
		var grid_pos: Vector2i = candidate.get("position", Vector2i.ZERO)
		var size: Vector2i = candidate.get("size", Vector2i.ONE)
		var cand_rect := Rect2i(grid_pos, size)
		
		var placed: Array = context.get("placed_structures", [])
		for st in placed:
			var s_pos: Vector2i = st.get("position", Vector2i.ZERO)
			var s_sz: Vector2i = st.get("size", Vector2i.ONE)
			var s_rect := Rect2i(s_pos, s_sz)
			
			if cand_rect.intersects(s_rect):
				var s_name: String = str(st.get("name", "Existing Structure"))
				return {
					"valid": false,
					"reason": "Placement overlaps existing structure '%s' at (%d, %d)." % [s_name, s_pos.x, s_pos.y],
					"constraint_id": rule_id
				}
		return {"valid": true, "reason": "", "constraint_id": rule_id}


# ---------------------------------------------------------------------------
# Rule 3: Authorized Buildable Zone Rule
# ---------------------------------------------------------------------------
class BuildZoneRule extends BaseConstraintRule:
	func _init() -> void:
		rule_id = "BUILD_ZONE"
		description = "Checks that candidate footprint is contained inside designated buildable zones."
		
	func evaluate(candidate: Dictionary, context: Dictionary) -> Dictionary:
		var build_zones: Array = context.get("build_zones", [])
		var fallback_zone: Rect2i = context.get("build_zone_bounds", Rect2i(0, 0, 80, 80))
		
		var footprint: Array = candidate.get("footprint", [])
		if footprint.is_empty():
			return {"valid": true, "reason": "", "constraint_id": rule_id}
			
		for c in footprint:
			var cell: Vector2i = c
			var is_inside := false
			
			if not build_zones.is_empty():
				for bz in build_zones:
					if bz is Rect2i and bz.has_point(cell):
						is_inside = true
						break
			else:
				# Use fallback single Rect2i
				if cell.x >= fallback_zone.position.x and cell.x <= fallback_zone.end.x and \
				   cell.y >= fallback_zone.position.y and cell.y <= fallback_zone.end.y:
					is_inside = true
					
			if not is_inside:
				return {
					"valid": false,
					"reason": "Placement at (%d, %d) is outside authorized build zone." % [cell.x, cell.y],
					"constraint_id": rule_id
				}
				
		return {"valid": true, "reason": "", "constraint_id": rule_id}


# ---------------------------------------------------------------------------
# Rule 4: Minimum Structure Spacing Buffer Rule
# ---------------------------------------------------------------------------
class MinimumSpacingRule extends BaseConstraintRule:
	func _init() -> void:
		rule_id = "MIN_SPACING"
		description = "Checks that candidate footprint respects minimum proximity buffer distance to other structures."
		
	func evaluate(candidate: Dictionary, context: Dictionary) -> Dictionary:
		var footprint: Array = candidate.get("footprint", [])
		var cand_spacing: int = int(candidate.get("min_spacing", 1))
		var placed: Array = context.get("placed_structures", [])
		
		for st in placed:
			var s_pos: Vector2i = st.get("position", Vector2i.ZERO)
			var s_sz: Vector2i = st.get("size", Vector2i.ONE)
			var s_spacing: int = int(st.get("min_spacing", 1))
			var effective_spacing: int = maxi(cand_spacing, s_spacing)
			
			if effective_spacing <= 0:
				continue
				
			for c in footprint:
				var cell: Vector2i = c
				for dy in s_sz.y:
					for dx in s_sz.x:
						var s_cell := Vector2i(s_pos.x + dx, s_pos.y + dy)
						var dist: int = maxi(absi(cell.x - s_cell.x), absi(cell.y - s_cell.y))
						# If dist is 0, handled by OccupiedCellRule; if 0 < dist <= effective_spacing, it's a spacing violation
						if dist > 0 and dist <= effective_spacing:
							var s_name: String = str(st.get("name", "Structure"))
							return {
								"valid": false,
								"reason": "Too close to '%s' (clearance: %d cells, required: %d cells)." % [
									s_name, dist, effective_spacing + 1
								],
								"constraint_id": rule_id
							}
		return {"valid": true, "reason": "", "constraint_id": rule_id}


# ---------------------------------------------------------------------------
# Rule 5: Resource Availability Rule
# ---------------------------------------------------------------------------
class ResourceCostRule extends BaseConstraintRule:
	func _init() -> void:
		rule_id = "RESOURCES"
		description = "Checks that the player possesses sufficient carried resources for construction."
		
	func evaluate(candidate: Dictionary, context: Dictionary) -> Dictionary:
		var cost: Dictionary = candidate.get("cost", {})
		var avail: Dictionary = context.get("available_resources", {})
		
		var missing: Array[String] = []
		for res_k in cost:
			var needed: int = int(cost[res_k])
			var current: int = int(avail.get(res_k, 0))
			if current < needed:
				missing.append("%s (need %d, have %d)" % [res_k, needed, current])
				
		if not missing.is_empty():
			return {
				"valid": false,
				"reason": "Insufficient resources: %s." % (", ".join(missing)),
				"constraint_id": rule_id
			}
		return {"valid": true, "reason": "", "constraint_id": rule_id}


# ---------------------------------------------------------------------------
# Rule 6: Grid Boundary Rule
# ---------------------------------------------------------------------------
class GridBoundaryRule extends BaseConstraintRule:
	func _init() -> void:
		rule_id = "BOUNDS"
		description = "Checks that footprint does not exceed the boundaries of the world grid."
		
	func evaluate(candidate: Dictionary, context: Dictionary) -> Dictionary:
		var grid_size: Vector2i = context.get("grid_size", Vector2i(80, 80))
		var footprint: Array = candidate.get("footprint", [])
		
		for c in footprint:
			var cell: Vector2i = c
			if cell.x < 0 or cell.x >= grid_size.x or cell.y < 0 or cell.y >= grid_size.y:
				return {
					"valid": false,
					"reason": "Structure footprint extends outside world grid boundaries.",
					"constraint_id": rule_id
				}
		return {"valid": true, "reason": "", "constraint_id": rule_id}


# ---------------------------------------------------------------------------
# Validator Engine Instance
# ---------------------------------------------------------------------------
var _rules: Array = []


func _init() -> void:
	register_default_rules()


func register_default_rules() -> void:
	_rules.clear()
	# Order: Quick economic checks first, then bounds, build zone, terrain collision, overlap, and spacing
	add_rule(ResourceCostRule.new())
	add_rule(GridBoundaryRule.new())
	add_rule(BuildZoneRule.new())
	add_rule(BlockedTileRule.new())
	add_rule(OccupiedCellRule.new())
	add_rule(MinimumSpacingRule.new())


func add_rule(rule: RefCounted) -> void:
	if rule and not _rules.has(rule):
		_rules.append(rule)


func remove_rule_by_id(p_rule_id: String) -> void:
	for i in range(_rules.size() - 1, -1, -1):
		if _rules[i].rule_id == p_rule_id:
			_rules.remove_at(i)


func validate(candidate: Dictionary, context: Dictionary) -> Dictionary:
	var violated: Array[String] = []
	var reasons: Array[String] = []
	
	for rule in _rules:
		var res: Dictionary = rule.evaluate(candidate, context)
		if not bool(res.get("valid", true)):
			var cid: String = str(res.get("constraint_id", rule.rule_id))
			var rsn: String = str(res.get("reason", "Constraint violated"))
			violated.append(cid)
			reasons.append(rsn)
			
	var is_valid: bool = violated.is_empty()
	var primary_reason: String = reasons[0] if not reasons.is_empty() else ""
	
	return {
		"valid": is_valid,
		"reason": primary_reason,
		"violated_constraints": violated,
		"all_reasons": reasons
	}
