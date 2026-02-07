extends Node
class_name ShipStateManager
## Finite State Machine for cinematic ship behavior
## Manages state transitions and prevents invalid operations

# =============================================================================
# SIGNALS
# =============================================================================

signal state_changed(old_state: State, new_state: State)
signal command_rejected(reason: String)
signal command_accepted(command: String)
signal navigation_complete(destination: String)
signal computer_announcement(message: String)

# =============================================================================
# STATE DEFINITIONS
# =============================================================================

enum State {
	IDLE,
	ALIGNING,
	WARP_CHARGING,
	IN_WARP,
	WARP_EXITING,
	IMPULSE,
	MANEUVERING
}

# Valid state transitions
const VALID_TRANSITIONS: Dictionary = {
	State.IDLE: [State.ALIGNING, State.IMPULSE, State.MANEUVERING],
	State.ALIGNING: [State.WARP_CHARGING, State.IDLE],
	State.WARP_CHARGING: [State.IN_WARP, State.IDLE],
	State.IN_WARP: [State.WARP_EXITING],
	State.WARP_EXITING: [State.IDLE, State.IMPULSE],
	State.IMPULSE: [State.IDLE, State.ALIGNING, State.MANEUVERING],
	State.MANEUVERING: [State.IDLE, State.IMPULSE]
}

const STATE_NAMES: Dictionary = {
	State.IDLE: "IDLE",
	State.ALIGNING: "ALIGNING",
	State.WARP_CHARGING: "WARP_CHARGING",
	State.IN_WARP: "IN_WARP",
	State.WARP_EXITING: "WARP_EXITING",
	State.IMPULSE: "IMPULSE",
	State.MANEUVERING: "MANEUVERING"
}

# =============================================================================
# CONFIGURATION
# =============================================================================

@export var alignment_threshold: float = 0.02  # Radians (~1 degree)
@export var alignment_speed: float = 1.5  # Radians per second
@export var warp_charge_time: float = 1.5  # Seconds
@export var warp_exit_time: float = 1.0  # Seconds
@export var impulse_acceleration_time: float = 2.0  # Seconds to reach target speed

# =============================================================================
# REFERENCES
# =============================================================================

@export var ship_path: NodePath
@export var warp_drive_path: NodePath
@export var hud_path: NodePath

var ship: Node3D  # Actually RigidBody3D/ShipController
var warp_drive: Node3D
var hud: Control
var sector: Node3D

# =============================================================================
# STATE
# =============================================================================

var current_state: State = State.IDLE
var _navigation_target: Node3D = null
var _navigation_target_name: String = ""
var _target_warp_factor: float = 5.0
var _target_impulse_percent: int = 100

# Short-term memory
var last_destination: String = ""
var last_warp_factor: float = 5.0

# Sequence tracking
var _sequence_step: int = 0
var _sequence_timer: float = 0.0
var _is_aligned: bool = false

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	ship = get_node_or_null(ship_path)
	warp_drive = get_node_or_null(warp_drive_path)
	hud = get_node_or_null(hud_path)
	sector = get_parent()

	_log("ShipStateManager initialized")
	_log("  State: " + STATE_NAMES[current_state])

func _process(delta: float) -> void:
	match current_state:
		State.ALIGNING:
			_process_aligning(delta)
		State.WARP_CHARGING:
			_process_warp_charging(delta)
		State.IN_WARP:
			_process_in_warp(delta)
		State.WARP_EXITING:
			_process_warp_exiting(delta)
		State.MANEUVERING:
			_process_maneuvering(delta)

# =============================================================================
# STATE TRANSITIONS
# =============================================================================

func _can_transition_to(new_state: State) -> bool:
	if current_state == new_state:
		return false
	var allowed: Array = VALID_TRANSITIONS.get(current_state, [])
	return new_state in allowed

func _transition_to(new_state: State) -> bool:
	if not _can_transition_to(new_state):
		_log("REJECTED transition: " + STATE_NAMES[current_state] + " -> " + STATE_NAMES[new_state])
		return false

	var old_state := current_state
	current_state = new_state
	_log("STATE: " + STATE_NAMES[old_state] + " -> " + STATE_NAMES[new_state])
	emit_signal("state_changed", old_state, new_state)
	return true

func get_state_name() -> String:
	return STATE_NAMES[current_state]

func is_busy() -> bool:
	return current_state != State.IDLE and current_state != State.IMPULSE

# =============================================================================
# COMMAND VALIDATION
# =============================================================================

func validate_navigation_command(target_name: String, warp_factor: float) -> Dictionary:
	"""Validate a navigation command before execution."""
	var result := {"valid": false, "reason": "", "target": null}

	# Check if ship is busy
	if is_busy():
		result.reason = "Helm is currently executing a maneuver."
		return result

	# Find target in navigation database
	var target := _find_navigation_target(target_name)
	if not target:
		result.reason = "Unable to locate " + target_name + " in navigation database."
		return result

	# Validate warp factor
	if warp_factor <= 0 or warp_factor >= 10:
		result.reason = "Warp factor must be between 1 and 9.99."
		return result

	# Check max warp
	if warp_drive and warp_factor > warp_drive.max_warp_factor:
		result.reason = "Warp " + str(warp_factor) + " exceeds ship maximum of " + str(warp_drive.max_warp_factor) + "."
		return result

	# Check if already at warp
	if warp_drive and warp_drive.is_at_warp:
		result.reason = "Cannot set new course while at warp. Disengage first."
		return result

	# Check gravity well (simplified - check distance to nearest body)
	if warp_drive and not _is_safe_for_warp():
		result.reason = "Too close to gravitational body for warp. Minimum safe distance required."
		return result

	result.valid = true
	result.target = target
	return result

func validate_impulse_command(percent: int) -> Dictionary:
	"""Validate an impulse command."""
	var result := {"valid": false, "reason": ""}

	if current_state == State.IN_WARP:
		result.reason = "Cannot change impulse while at warp."
		return result

	if current_state == State.ALIGNING or current_state == State.WARP_CHARGING:
		result.reason = "Helm is preparing for warp. Command rejected."
		return result

	if percent < 0 or percent > 100:
		result.reason = "Impulse must be between 0 and 100 percent."
		return result

	result.valid = true
	return result

func validate_stop_command() -> Dictionary:
	"""Validate an all-stop command."""
	# Stop is always valid - emergency override
	return {"valid": true, "reason": ""}

func _find_navigation_target(target_name: String) -> Node3D:
	"""Find a celestial body by name."""
	if not sector:
		sector = get_tree().current_scene

	if sector and sector.has_method("get_planet"):
		return sector.get_planet(target_name)

	# Fallback: search by name
	var bodies := get_tree().get_nodes_in_group("celestial_bodies")
	for body in bodies:
		if body.name.to_lower() == target_name.to_lower():
			return body

	return null

func _is_safe_for_warp() -> bool:
	"""Check if ship is outside gravity wells."""
	if not warp_drive or not warp_drive.has_method("can_engage_warp"):
		return true
	return warp_drive.can_engage_warp()

# =============================================================================
# NAVIGATION SEQUENCE
# =============================================================================

func execute_navigation(target_name: String, warp_factor: float) -> bool:
	"""Execute a full navigation sequence."""
	var validation := validate_navigation_command(target_name, warp_factor)

	if not validation.valid:
		_announce(validation.reason)
		emit_signal("command_rejected", validation.reason)
		return false

	# Store for memory
	_navigation_target = validation.target
	_navigation_target_name = target_name
	_target_warp_factor = warp_factor
	last_destination = target_name
	last_warp_factor = warp_factor

	# Start sequence
	_sequence_step = 0
	_announce("Course laid in. " + target_name + ", warp " + str(warp_factor) + ".")
	emit_signal("command_accepted", "Navigation to " + target_name)

	# Begin alignment
	_transition_to(State.ALIGNING)
	_is_aligned = false

	return true

func _process_aligning(delta: float) -> void:
	"""Rotate ship toward target."""
	if not ship or not _navigation_target:
		_abort_navigation("Lost navigation target.")
		return

	var target_pos: Vector3 = _navigation_target.global_position
	var ship_pos: Vector3 = ship.global_position
	var direction: Vector3 = (target_pos - ship_pos).normalized()

	# Current forward
	var current_forward: Vector3 = -ship.global_transform.basis.z

	# Calculate angle to target
	var angle: float = current_forward.angle_to(direction)

	if angle < alignment_threshold:
		# Aligned!
		_is_aligned = true
		_log("Alignment complete. Angle: " + str(rad_to_deg(angle)) + " degrees")
		_announce("Warp core spooling.")
		_transition_to(State.WARP_CHARGING)
		_sequence_timer = 0.0
		return

	# Rotate toward target
	var rotation_axis: Vector3 = current_forward.cross(direction).normalized()
	if rotation_axis.length() < 0.001:
		rotation_axis = Vector3.UP

	var rotation_amount: float = min(alignment_speed * delta, angle)
	ship.rotate(rotation_axis, rotation_amount)

func _process_warp_charging(delta: float) -> void:
	"""Cinematic delay before warp."""
	_sequence_timer += delta

	if _sequence_timer >= warp_charge_time:
		_announce("Engaging warp " + str(_target_warp_factor) + ".")
		_engage_warp()

func _engage_warp() -> void:
	"""Actually engage the warp drive."""
	if not warp_drive:
		_abort_navigation("Warp drive offline.")
		return

	warp_drive.target_warp_factor = _target_warp_factor

	if warp_drive.has_method("engage_warp"):
		warp_drive.engage_warp()

	_transition_to(State.IN_WARP)

func _process_in_warp(delta: float) -> void:
	"""Monitor warp travel and check for arrival."""
	if not _navigation_target or not ship:
		return

	var distance: float = ship.global_position.distance_to(_navigation_target.global_position)

	# Get arrival distance from sector or use default
	var arrival_distance: float = 100000.0  # 1 million km default
	if sector and "WARP_ARRIVAL_DISTANCE" in sector:
		arrival_distance = sector.WARP_ARRIVAL_DISTANCE

	if distance <= arrival_distance:
		_begin_warp_exit()

func _begin_warp_exit() -> void:
	"""Start the warp exit sequence."""
	_transition_to(State.WARP_EXITING)
	_sequence_timer = 0.0

	# Disengage warp
	if warp_drive and warp_drive.has_method("disengage_warp"):
		warp_drive.disengage_warp()

func _process_warp_exiting(delta: float) -> void:
	"""Handle post-warp cooldown."""
	_sequence_timer += delta

	if _sequence_timer >= warp_exit_time:
		_announce("Arrived at " + _navigation_target_name + ".")
		emit_signal("navigation_complete", _navigation_target_name)
		_navigation_target = null
		_navigation_target_name = ""
		_transition_to(State.IDLE)

func _abort_navigation(reason: String) -> void:
	"""Abort current navigation."""
	_log("Navigation aborted: " + reason)
	_announce(reason)

	if warp_drive and warp_drive.is_at_warp:
		warp_drive.disengage_warp()

	_navigation_target = null
	current_state = State.IDLE  # Force reset

# =============================================================================
# IMPULSE CONTROL
# =============================================================================

func execute_impulse(percent: int) -> bool:
	"""Execute impulse command with gradual acceleration."""
	var validation := validate_impulse_command(percent)

	if not validation.valid:
		_announce(validation.reason)
		emit_signal("command_rejected", validation.reason)
		return false

	_target_impulse_percent = percent

	# Set impulse level
	if ship and "current_impulse" in ship:
		# ImpulseLevel: REVERSE=0, STOP=1, QUARTER=2, HALF=3, THREE_QUARTER=4, FULL=5
		var level: int = 1  # STOP
		if percent >= 100:
			level = 5  # FULL
		elif percent >= 75:
			level = 4  # THREE_QUARTER
		elif percent >= 50:
			level = 3  # HALF
		elif percent >= 25:
			level = 2  # QUARTER

		ship.current_impulse = level
		if ship.has_method("_update_target_speed"):
			ship._update_target_speed()

	if current_state == State.IDLE and percent > 0:
		_transition_to(State.IMPULSE)
	elif percent == 0 and current_state == State.IMPULSE:
		_transition_to(State.IDLE)

	var speed_name: String = _get_impulse_name(percent)
	_announce(speed_name + " impulse.")
	emit_signal("command_accepted", "Impulse " + str(percent) + "%")

	return true

func _get_impulse_name(percent: int) -> String:
	if percent >= 100:
		return "Full"
	elif percent >= 75:
		return "Three quarter"
	elif percent >= 50:
		return "Half"
	elif percent >= 25:
		return "One quarter"
	else:
		return "All stop. Zero"

# =============================================================================
# STOP COMMAND
# =============================================================================

func execute_stop() -> bool:
	"""Execute all-stop command."""
	_log("Executing all stop")

	# Disengage warp if active
	if warp_drive and warp_drive.is_at_warp:
		warp_drive.disengage_warp()
		_announce("Dropping out of warp. All stop.")
	else:
		_announce("All stop.")

	# Stop impulse
	if ship and "current_impulse" in ship:
		ship.current_impulse = 1  # STOP
		if ship.has_method("_update_target_speed"):
			ship._update_target_speed()
		# Gradual stop - don't zero velocity instantly
		var current_vel: Vector3 = ship.linear_velocity
		ship.linear_velocity = current_vel * 0.1  # Rapid but not instant
		ship.angular_velocity = Vector3.ZERO

	# Reset state
	_navigation_target = null
	current_state = State.IDLE

	emit_signal("command_accepted", "All stop")
	return true

# =============================================================================
# MANEUVER COMMANDS
# =============================================================================

func execute_maneuver(maneuver: String) -> bool:
	"""Execute a turn or maneuver."""
	if is_busy() and current_state != State.IMPULSE:
		_announce("Helm is busy. Maneuver rejected.")
		emit_signal("command_rejected", "Helm busy")
		return false

	_transition_to(State.MANEUVERING)
	_announce("Executing " + maneuver + ".")
	emit_signal("command_accepted", "Maneuver: " + maneuver)

	# TODO: Implement actual maneuver logic
	# For now, just return to idle after a delay
	await get_tree().create_timer(2.0).timeout
	_transition_to(State.IDLE)

	return true

func _process_maneuvering(_delta: float) -> void:
	# Placeholder for maneuver processing
	pass

# =============================================================================
# MEMORY COMMANDS
# =============================================================================

func execute_increase_speed() -> bool:
	"""Increase warp factor from memory."""
	if current_state == State.IN_WARP and warp_drive:
		var new_factor: float = min(last_warp_factor + 1.0, warp_drive.max_warp_factor)
		warp_drive.target_warp_factor = new_factor
		last_warp_factor = new_factor
		_announce("Increasing to warp " + str(new_factor) + ".")
		return true
	elif current_state == State.IMPULSE:
		return execute_impulse(100)
	return false

func execute_return_to_last() -> bool:
	"""Return to last destination."""
	if last_destination.is_empty():
		_announce("No previous destination in memory.")
		return false
	return execute_navigation(last_destination, last_warp_factor)

# =============================================================================
# COMPUTER VOICE
# =============================================================================

func _announce(message: String) -> void:
	"""Send computer announcement."""
	_log("COMPUTER: " + message)
	emit_signal("computer_announcement", message)

# =============================================================================
# LOGGING
# =============================================================================

func _log(message: String) -> void:
	print("[STATE MANAGER] " + message)
