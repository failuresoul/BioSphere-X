class_name BossDecisionModule
extends RefCounted
## Base interface for BioSphere-X Boss decision-making modules.
## Defines a common contract for selecting combat actions and collecting decision statistics.

## Virtual method: receives current combat context and returns a dictionary with:
## - "action": chosen action name (String)
## - "score": heuristic evaluation score (float)
## - "statistics": decision telemetry such as nodes evaluated, depth, runtime (Dictionary)
func choose_action(_context: Dictionary) -> Dictionary:
	return {
		"action": "GUARD_STANCE",
		"score": 0.0,
		"statistics": {}
	}


## Returns the human-readable identifier for this decision algorithm.
func get_module_name() -> String:
	return "BaseDecisionModule"
