extends Node
class_name FloatingOriginClass
## Floating Origin System for Large-Scale Space Simulation
##
## WHY THIS IS REQUIRED:
## ====================
## Godot uses 32-bit floats for positions. At large distances from the origin,
## floating-point precision degrades causing:
##   - Visual jitter (objects shake/vibrate)
##   - Physics instability (collision detection fails)
##   - Animation glitches
##   - Camera stuttering
##
## At 1 unit = 1000 km scale:
##   - Earth is at 149,600 units (1 AU) from Sun
##   - Neptune is at 4,498,000 units from Sun
##   - Float precision breaks down around 100,000+ units
##
## THE SOLUTION:
## =============
## Instead of moving the player through the universe, we keep the player
## near the origin and move the universe around them. This ensures all
## calculations happen with maximum floating-point precision.
##
## HOW IT WORKS:
## =============
## 1. Player ship is always kept near Vector3.ZERO
## 2. When ship exceeds ORIGIN_RESET_DISTANCE from origin, we:
##    a. Calculate the ship's current position as an offset
##    b. Subtract that offset from ALL world objects (planets, stations, etc.)
##    c. Reset the ship to Vector3.ZERO
## 3. We track the cumulative offset so we always know "true" universe positions
##
## ADDING NEW OBJECTS:
## ===================
## Any object that exists in "logical space" (planets, stations, ships, markers)
## must be registered with this system OR be a child of a registered node.
## Use register_world_object() to add new top-level objects.
## Children of registered objects are shifted automatically via their parent.
##
## WARNING - COMMON MISTAKES:
## ==========================
## - DO NOT position objects using global_position directly for large distances
##   Instead, use set_logical_position() which accounts for the current offset
## - DO NOT use the camera as a reference frame for positioning
## - DO NOT assume world origin is at the Sun - it's wherever the player is
## - DO NOT forget to register dynamically spawned objects

signal origin_shifted(offset: Vector3)

## Distance threshold before origin reset triggers (in game units)
## 50 units = 50,000 km - well within float precision safe zone
const ORIGIN_RESET_DISTANCE: float = 50.0

## Accumulated world offset - the "true" position of world origin
## Add this to any object's local position to get its "universe" position
var world_offset: Vector3 = Vector3.ZERO

## Reference to the player ship (set by the sector/game scene)
var player_ship: Node3D = null

## List of root-level world objects that need to be shifted
## Children of these objects are shifted automatically
var _world_objects: Array[Node3D] = []

## Statistics for debugging
var total_shifts: int = 0
var last_shift_offset: Vector3 = Vector3.ZERO

func _ready() -> void:
	print("=== FLOATING ORIGIN SYSTEM INITIALIZED ===")
	print("  Reset threshold: ", ORIGIN_RESET_DISTANCE, " units (", ORIGIN_RESET_DISTANCE * 1000, " km)")
	print("  Press F12 to toggle floating origin debug display")

func _input(event: InputEvent) -> void:
	# F12 to toggle debug info
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		debug_print_state()

func _physics_process(_delta: float) -> void:
	if not player_ship or not is_instance_valid(player_ship):
		return

	# Check if player has moved too far from origin
	var distance_from_origin: float = player_ship.global_position.length()

	if distance_from_origin > ORIGIN_RESET_DISTANCE:
		_perform_origin_shift()

## Register the player ship - this is the reference point for origin shifts
func set_player_ship(ship: Node3D) -> void:
	player_ship = ship
	print("FloatingOrigin: Player ship registered - ", ship.name)

## Register a world object that should be shifted with origin changes
## This should be called for root-level objects (planets container, stations, etc.)
## Children of registered objects are automatically shifted via their parent
func register_world_object(obj: Node3D) -> void:
	if obj and not _world_objects.has(obj):
		_world_objects.append(obj)
		print("FloatingOrigin: Registered world object - ", obj.name)

## Unregister a world object (call when object is destroyed)
func unregister_world_object(obj: Node3D) -> void:
	_world_objects.erase(obj)

## Convert a "universe" position to current world position
## Use this when you know the absolute position in the solar system
func universe_to_world(universe_pos: Vector3) -> Vector3:
	return universe_pos - world_offset

## Convert current world position to "universe" position
## Use this to get the true solar system coordinates
func world_to_universe(world_pos: Vector3) -> Vector3:
	return world_pos + world_offset

## Set an object's position using universe coordinates
## This automatically accounts for the current world offset
func set_logical_position(obj: Node3D, universe_pos: Vector3) -> void:
	obj.global_position = universe_to_world(universe_pos)

## Get an object's position in universe coordinates
func get_logical_position(obj: Node3D) -> Vector3:
	return world_to_universe(obj.global_position)

## Get the player's true position in the universe
func get_player_universe_position() -> Vector3:
	if player_ship and is_instance_valid(player_ship):
		return world_to_universe(player_ship.global_position)
	return world_offset

## Perform the origin shift - moves the universe, not the player
func _perform_origin_shift() -> void:
	if not player_ship:
		return

	# The offset is the player's current position
	var shift_offset: Vector3 = player_ship.global_position

	# Skip tiny shifts (avoid micro-corrections)
	if shift_offset.length() < 1.0:
		return

	print("=== FLOATING ORIGIN SHIFT ===")
	print("  Ship was at: ", shift_offset)
	print("  Shifting ", _world_objects.size(), " world objects")

	# Update cumulative world offset
	world_offset += shift_offset
	last_shift_offset = shift_offset
	total_shifts += 1

	# Shift all registered world objects
	for obj in _world_objects:
		if is_instance_valid(obj):
			obj.global_position -= shift_offset

	# Reset player to origin
	# Note: We shift world objects but NOT the player - player stays at origin
	player_ship.global_position = Vector3.ZERO

	# If player has velocity, it's preserved (we only change position)
	# RigidBody3D linear_velocity is in world space and unaffected

	print("  New world offset: ", world_offset)
	print("  Total shifts: ", total_shifts)
	print("  Ship now at: ", player_ship.global_position)

	# Notify any listeners (camera, HUD, etc.)
	emit_signal("origin_shifted", shift_offset)

## Force an immediate origin shift (useful after warp travel)
func force_origin_reset() -> void:
	if player_ship and is_instance_valid(player_ship):
		if player_ship.global_position.length() > 0.1:
			_perform_origin_shift()

## Get distance from origin (for debugging/UI)
func get_distance_from_origin() -> float:
	if player_ship and is_instance_valid(player_ship):
		return player_ship.global_position.length()
	return 0.0

## Debug: Print current state
func debug_print_state() -> void:
	print("=== FLOATING ORIGIN STATE ===")
	print("  World offset: ", world_offset)
	print("  Player world pos: ", player_ship.global_position if player_ship else "N/A")
	print("  Player universe pos: ", get_player_universe_position())
	print("  Distance from origin: ", get_distance_from_origin())
	print("  Total shifts: ", total_shifts)
	print("  Registered objects: ", _world_objects.size())

# =============================================================================
# WARP TRAVEL COMPATIBILITY
# =============================================================================
# The floating origin system is fully compatible with warp travel:
#
# 1. During warp, the ship moves via global_position updates
# 2. FloatingOrigin checks distance from origin every physics frame
# 3. When ship exceeds threshold, universe shifts back instantly
# 4. At high warp (9.999 = ~20000c), ship may move 100,000+ units/frame
# 5. This triggers immediate origin reset - completely transparent to player
#
# WARP DESTINATION HANDLING:
# - Autopilot destinations are Node3D references (planets/stations)
# - These nodes shift with FloatingOrigin, so relative distance stays correct
# - Distance calculations use world positions, which are always valid
#
# NO SPECIAL WARP CODE NEEDED - the system handles it automatically
# =============================================================================
