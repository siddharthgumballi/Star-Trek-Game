extends Node
class_name ScaleConstantsClass
## Global scale constants for the Star Trek game
##
## UNIFORM 100× WORLD SCALE SYSTEM:
## ================================
## All spatial quantities are scaled by WORLD_SCALE = 100.0
## This is applied EXACTLY ONCE to each base value.
##
## SCALED (× WORLD_SCALE):
##   - Distances (orbital, spawn, arrival)
##   - Radii (planets, stars)
##   - Linear speeds (impulse, warp)
##   - Linear accelerations
##
## NOT SCALED:
##   - Time (delta)
##   - Mass
##   - Angular rates (rad/sec)
##   - Angular damping
##
## Base unit: 1 unit = 1000 km (before scaling)
## Scaled unit: 1 unit = 10 km (after 100× scaling)

# =============================================================================
# MASTER SCALE CONSTANT - APPLY EXACTLY ONCE
# =============================================================================
const WORLD_SCALE: float = 100.0

# =============================================================================
# BASE VALUES (real scale, 1 unit = 1000 km)
# =============================================================================
const BASE_KM_PER_UNIT: float = 1000.0
const BASE_AU_KM: float = 149597870.7  # 1 AU in km
const BASE_LIGHT_SPEED_KMS: float = 299792.458  # km/s

# =============================================================================
# DERIVED SCALED VALUES
# =============================================================================

# Effective km per game unit (for UI display conversion)
# game_units × KM_PER_UNIT = real kilometers
const KM_PER_UNIT: float = BASE_KM_PER_UNIT / WORLD_SCALE  # = 10.0 km

# 1 AU in game units (scaled)
# Base: 149,597,870.7 km / 1000 = 149,597.87 units
# Scaled: 149,597.87 × 100 = 14,959,787 units
const AU_IN_UNITS: float = (BASE_AU_KM / BASE_KM_PER_UNIT) * WORLD_SCALE  # ~15 million

# Light speed in game units/sec (scaled)
# Base: 299,792.458 km/s / 1000 = 299.79 units/s
# Scaled: 299.79 × 100 = 29,979 units/s
const LIGHT_SPEED_UNITS: float = (BASE_LIGHT_SPEED_KMS / BASE_KM_PER_UNIT) * WORLD_SCALE  # ~29,979

# Full impulse = 0.25c (scaled)
# Base: 74,948 km/s / 1000 = 74.948 units/s
# Scaled: 74.948 × 100 = 7,495 units/s
const FULL_IMPULSE_SPEED: float = LIGHT_SPEED_UNITS * 0.25  # ~7,495

# =============================================================================
# PLANET BASE DATA (real values in km, will be scaled on use)
# =============================================================================

# Planet orbital distances in AU
const MERCURY_AU: float = 0.387
const VENUS_AU: float = 0.723
const EARTH_AU: float = 1.0
const MARS_AU: float = 1.524
const JUPITER_AU: float = 5.203
const SATURN_AU: float = 9.537
const URANUS_AU: float = 19.19
const NEPTUNE_AU: float = 30.07

# Planet radii in km (real values)
const EARTH_RADIUS_KM: float = 6371.0
const SUN_RADIUS_KM: float = 696000.0
const MOON_RADIUS_KM: float = 1737.0
const MERCURY_RADIUS_KM: float = 2440.0
const VENUS_RADIUS_KM: float = 6052.0
const MARS_RADIUS_KM: float = 3390.0
const JUPITER_RADIUS_KM: float = 69911.0
const SATURN_RADIUS_KM: float = 58232.0
const URANUS_RADIUS_KM: float = 25362.0
const NEPTUNE_RADIUS_KM: float = 24622.0

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

## Convert AU to scaled game units
static func au_to_units(au: float) -> float:
	return au * AU_IN_UNITS

## Convert scaled game units to AU
static func units_to_au(units: float) -> float:
	return units / AU_IN_UNITS

## Convert real km to scaled game units
static func km_to_units(km: float) -> float:
	return (km / BASE_KM_PER_UNIT) * WORLD_SCALE

## Convert scaled game units to real km (for UI display)
static func units_to_km(units: float) -> float:
	return units * KM_PER_UNIT

## Convert real meters to scaled game units
static func meters_to_units(meters: float) -> float:
	return km_to_units(meters / 1000.0)

## Scale a base speed (units/s at 1:1) to world scale
static func scale_speed(base_speed: float) -> float:
	return base_speed * WORLD_SCALE

## Scale a base distance to world scale
static func scale_distance(base_distance: float) -> float:
	return base_distance * WORLD_SCALE
