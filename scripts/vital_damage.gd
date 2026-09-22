extends RefCounted
## Vital impacts are finite damage, never an unconditional kill.
static func resolve(organs: Array,ordinary: float) -> float:
	if organs.has("heart"): return 900.0
	if organs.has("brain"): return 450.0
	return ordinary
