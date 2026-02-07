extends RefCounted
class_name PowerSystem
## Power allocation logic for starship systems
## Manages distribution across engines, shields, weapons, and sensors

const TOTAL_POWER: float = 100.0

# Power allocation categories
enum PowerCategory { ENGINES, SHIELDS, WEAPONS, SENSORS }

# Default power distribution (balanced)
const DEFAULT_DISTRIBUTION: Dictionary = {
	"engines": 25.0,
	"shields": 25.0,
	"weapons": 25.0,
	"sensors": 25.0
}

# Current power allocation
var _distribution: Dictionary = {}

# =============================================================================
# INITIALIZATION
# =============================================================================

func _init() -> void:
	reset_to_default()

func reset_to_default() -> void:
	"""Reset power distribution to default balanced state."""
	_distribution = DEFAULT_DISTRIBUTION.duplicate()

# =============================================================================
# POWER DISTRIBUTION
# =============================================================================

func get_power_distribution() -> Dictionary:
	"""Get current power distribution."""
	return _distribution.duplicate()

func set_power_distribution(new_distribution: Dictionary) -> bool:
	"""Set power distribution. Must sum to 100.

	Args:
		new_distribution: Dictionary with engines, shields, weapons, sensors

	Returns:
		True if valid and applied, false otherwise
	"""
	if not _validate_distribution(new_distribution):
		return false

	_distribution = new_distribution.duplicate()
	return true

func modify_power(subsystem: String, delta: float) -> bool:
	"""Modify power for a single subsystem, redistributing from/to others.

	Args:
		subsystem: Name of subsystem to modify (engines, shields, weapons, sensors)
		delta: Amount to add (positive) or remove (negative)

	Returns:
		True if modification was applied
	"""
	if subsystem not in _distribution:
		return false

	var current: float = _distribution[subsystem]
	var new_value: float = clampf(current + delta, 0.0, 100.0)
	var actual_delta: float = new_value - current

	if absf(actual_delta) < 0.01:
		return false

	# Redistribute the delta among other subsystems
	var other_subsystems: Array = []
	for key in _distribution.keys():
		if key != subsystem:
			other_subsystems.append(key)

	if other_subsystems.is_empty():
		return false

	# Calculate how much to take/give to each other subsystem
	var redistribute_each: float = -actual_delta / other_subsystems.size()

	# Check if redistribution is valid (no subsystem goes below 0 or above 100)
	for other in other_subsystems:
		var other_new: float = _distribution[other] + redistribute_each
		if other_new < 0.0 or other_new > 100.0:
			return false

	# Apply the changes
	_distribution[subsystem] = new_value
	for other in other_subsystems:
		_distribution[other] += redistribute_each

	return true

func divert_power_from_to(from_subsystem: String, to_subsystem: String, amount: float) -> bool:
	"""Transfer power from one subsystem to another.

	Args:
		from_subsystem: Subsystem to take power from
		to_subsystem: Subsystem to give power to
		amount: Amount of power to transfer

	Returns:
		True if transfer was successful
	"""
	if from_subsystem not in _distribution or to_subsystem not in _distribution:
		return false

	if from_subsystem == to_subsystem:
		return false

	var from_current: float = _distribution[from_subsystem]
	var to_current: float = _distribution[to_subsystem]

	# Calculate actual transfer amount (clamped to available/capacity)
	var actual_amount: float = minf(amount, from_current)
	actual_amount = minf(actual_amount, 100.0 - to_current)

	if actual_amount < 0.01:
		return false

	_distribution[from_subsystem] = from_current - actual_amount
	_distribution[to_subsystem] = to_current + actual_amount

	return true

# =============================================================================
# PRESETS
# =============================================================================

func apply_preset(preset_name: String) -> bool:
	"""Apply a named power preset.

	Available presets:
	- balanced: Equal distribution (25% each)
	- combat: Shields 40%, Weapons 35%, Engines 15%, Sensors 10%
	- evasive: Engines 50%, Shields 30%, Sensors 15%, Weapons 5%
	- science: Sensors 50%, Shields 20%, Engines 20%, Weapons 10%
	"""
	var presets: Dictionary = {
		"balanced": {"engines": 25.0, "shields": 25.0, "weapons": 25.0, "sensors": 25.0},
		"combat": {"engines": 15.0, "shields": 40.0, "weapons": 35.0, "sensors": 10.0},
		"evasive": {"engines": 50.0, "shields": 30.0, "weapons": 5.0, "sensors": 15.0},
		"science": {"engines": 20.0, "shields": 20.0, "weapons": 10.0, "sensors": 50.0}
	}

	if preset_name in presets:
		_distribution = presets[preset_name].duplicate()
		return true

	return false

# =============================================================================
# VALIDATION
# =============================================================================

func _validate_distribution(dist: Dictionary) -> bool:
	"""Validate that a distribution is valid (correct keys, sums to 100)."""
	var required_keys: Array = ["engines", "shields", "weapons", "sensors"]

	# Check all required keys exist
	for key in required_keys:
		if key not in dist:
			return false

	# Check no extra keys
	if dist.size() != required_keys.size():
		return false

	# Check all values are valid numbers
	var total: float = 0.0
	for key in dist.keys():
		var value = dist[key]
		if not (value is float or value is int):
			return false
		if value < 0.0 or value > 100.0:
			return false
		total += float(value)

	# Check sum equals 100 (with small tolerance for floating point)
	return absf(total - TOTAL_POWER) < 0.1

func get_power_for(subsystem: String) -> float:
	"""Get power level for a specific subsystem."""
	return _distribution.get(subsystem, 0.0)
