extends Node
class_name ScaleConstantsClass
## Global scale constants for the Star Trek game
##
## SCALE SYSTEM:
## - Orbital distances: 1 unit = 1000 km (1 AU = 149,600 units)
## - Planet/ship sizes: 250x scale for visibility
## - This hybrid approach keeps astronomical distances manageable
##   while making ships and planets visible

# Base unit conversion for DISTANCES
# 1 unit = 1000 km
const KM_PER_UNIT: float = 1000.0

# Size scale factor (applied to radii only, not orbital distances)
const SIZE_SCALE_FACTOR: float = 250.0

# 1 Astronomical Unit in game units
# 1 AU = 149,597,870.7 km ≈ 149,600 units at 1 unit = 1000 km
const AU_IN_UNITS: float = 149600.0

# Ship size (Enterprise-D is ~642m in reality)
# At 250x: 642m * 250 / 1000 = 160.5 units → rounded to 40 for gameplay
const SHIP_SIZE: float = 40.0

# Planet distances from Sun in AU (for reference)
const MERCURY_AU: float = 0.387
const VENUS_AU: float = 0.723
const EARTH_AU: float = 1.0
const MARS_AU: float = 1.524
const JUPITER_AU: float = 5.203
const SATURN_AU: float = 9.537
const URANUS_AU: float = 19.19
const NEPTUNE_AU: float = 30.07

# Speed conversions
# Full impulse = 0.25c = 74,948 km/s = 74.948 units/s
const FULL_IMPULSE_SPEED: float = 75.0  # units per second

# Helper function to convert AU to game units
static func au_to_units(au: float) -> float:
	return au * AU_IN_UNITS

# Helper function to convert game units to AU
static func units_to_au(units: float) -> float:
	return units / AU_IN_UNITS
