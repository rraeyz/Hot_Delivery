class_name Kitchen
extends RefCounted
## Pure cooking rules (testable without the UI).


## Quality from how close the needle stopped to the zone center (1 = perfect).
static func quality(needle: float, zone: float) -> float:
	return clampf(1.0 - absf(needle - zone) / 0.35, 0.0, 1.0)
