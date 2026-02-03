extends RigidBody3D
class_name ShipController
## Galaxy-class starship flight controller
##
## CONTROLS:
##   W/S - Pitch up/down
##   A/D - Yaw left/right
##   Z/C - Roll left/right
##   E/Q - Increase/decrease impulse
##   Space - Full stop

# =============================================================================
# CONFIGURATION
# =============================================================================

@export_group("Mass")
@export var ship_mass: float = 1500000.0
@export var center_of_mass_offset: Vector3 = Vector3(0, 0, -20)

@export_group("Impulse Speeds")
## Full impulse = 0.25c, scaled by WORLD_SCALE (100×)
## Base: 75 units/s × 100 = 7,495 units/s
@export var full_impulse_speed: float = 7495.0
@export var impulse_acceleration: float = 15.0  # Smooth acceleration (not scaled - it's a rate)

@export_group("Rotation Limits (rad/sec)")
@export var max_pitch_rate: float = 0.12
@export var max_yaw_rate: float = 0.15
@export var max_roll_rate: float = 0.10

@export_group("Torque Strength")
@export var pitch_torque: float = 15000000000.0
@export var yaw_torque: float = 25000000000.0
@export var roll_torque: float = 15000000000.0

@export_group("Damping")
@export var base_angular_damping: float = 0.8

# =============================================================================
# STATE
# =============================================================================

enum ImpulseLevel { REVERSE, STOP, QUARTER, HALF, THREE_QUARTER, FULL }

var current_impulse: ImpulseLevel = ImpulseLevel.STOP
var target_speed: float = 0.0
var actual_speed: float = 0.0

var thrust_input: float = 0.0
var rotation_input: Vector3 = Vector3.ZERO
var boost_active: bool = false
var full_stop_active: bool = false
var local_velocity: Vector3 = Vector3.ZERO
var forward_speed: float = 0.0

var _turn_input: float = 0.0
var _pitch_input: float = 0.0
var _roll_input: float = 0.0
var _impulse_change_cooldown: float = 0.0

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	mass = ship_mass
	gravity_scale = 0.0
	linear_damp = 0.0
	angular_damp = base_angular_damping
	freeze = false

	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = center_of_mass_offset

	_setup_inputs()
	_apply_ship_maneuverability()
	print("=== SHIP READY === W/S Pitch, A/D Yaw, Z/C Roll, E/Q Impulse")

func _apply_ship_maneuverability() -> void:
	# Get maneuverability multiplier from selected ship
	var global_ship = get_node_or_null("/root/GlobalShipData")
	if global_ship and global_ship.has_method("get_maneuverability"):
		var maneuverability: float = global_ship.get_maneuverability()

		# Apply multiplier to rotation rates (higher = faster turns)
		max_pitch_rate *= maneuverability
		max_yaw_rate *= maneuverability
		max_roll_rate *= maneuverability

		# Also scale torque to match (smaller ships need less torque)
		var ship_length: float = global_ship.get_ship_length()
		var length_ratio: float = ship_length / 642.5  # Galaxy class baseline
		var mass_scale: float = length_ratio * length_ratio * length_ratio  # Volume scales with cube

		# Adjust mass and torque based on ship size
		mass = ship_mass * mass_scale
		pitch_torque *= mass_scale
		yaw_torque *= mass_scale
		roll_torque *= mass_scale

		print("Ship maneuverability: ", maneuverability, " mass scale: ", mass_scale)

func _setup_inputs() -> void:
	var actions: Array[String] = [
		"pitch_up", "pitch_down", "turn_left", "turn_right",
		"roll_left", "roll_right",
		"impulse_increase", "impulse_decrease", "full_stop",
		"yaw_left", "yaw_right", "thrust_forward", "thrust_reverse"
	]
	for action in actions:
		if InputMap.has_action(action):
			InputMap.erase_action(action)

	# W - Pitch up
	InputMap.add_action("pitch_up")
	var w := InputEventKey.new()
	w.physical_keycode = KEY_W
	InputMap.action_add_event("pitch_up", w)

	# S - Pitch down
	InputMap.add_action("pitch_down")
	var s := InputEventKey.new()
	s.physical_keycode = KEY_S
	InputMap.action_add_event("pitch_down", s)

	# A - Yaw left
	InputMap.add_action("turn_left")
	var a := InputEventKey.new()
	a.physical_keycode = KEY_A
	InputMap.action_add_event("turn_left", a)

	# D - Yaw right
	InputMap.add_action("turn_right")
	var d := InputEventKey.new()
	d.physical_keycode = KEY_D
	InputMap.action_add_event("turn_right", d)

	# Z - Roll right
	InputMap.add_action("roll_right")
	var z := InputEventKey.new()
	z.physical_keycode = KEY_Z
	InputMap.action_add_event("roll_right", z)

	# C - Roll left
	InputMap.add_action("roll_left")
	var c := InputEventKey.new()
	c.physical_keycode = KEY_C
	InputMap.action_add_event("roll_left", c)

	# E - Increase impulse
	InputMap.add_action("impulse_increase")
	var e := InputEventKey.new()
	e.physical_keycode = KEY_E
	InputMap.action_add_event("impulse_increase", e)

	# Q - Decrease impulse
	InputMap.add_action("impulse_decrease")
	var q := InputEventKey.new()
	q.physical_keycode = KEY_Q
	InputMap.action_add_event("impulse_decrease", q)

	# Space - Full stop
	InputMap.add_action("full_stop")
	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	InputMap.action_add_event("full_stop", space)

# =============================================================================
# PHYSICS PROCESS
# =============================================================================

func _physics_process(delta: float) -> void:
	_update_cooldowns(delta)
	_read_input()

	if full_stop_active:
		_do_full_stop(delta)
	else:
		_do_impulse_movement(delta)
		_do_rotation()

	_clamp_angular_velocity()
	_update_state()

func _update_cooldowns(delta: float) -> void:
	if _impulse_change_cooldown > 0:
		_impulse_change_cooldown -= delta

func _read_input() -> void:
	if _impulse_change_cooldown <= 0:
		if Input.is_action_just_pressed("impulse_increase"):
			_increase_impulse()
			_impulse_change_cooldown = 0.2
		elif Input.is_action_just_pressed("impulse_decrease"):
			_decrease_impulse()
			_impulse_change_cooldown = 0.2

	full_stop_active = Input.is_action_pressed("full_stop")
	if full_stop_active:
		current_impulse = ImpulseLevel.STOP
		target_speed = 0.0

	# Pitch (W/S)
	_pitch_input = 0.0
	if Input.is_action_pressed("pitch_up"):
		_pitch_input = 1.0
	elif Input.is_action_pressed("pitch_down"):
		_pitch_input = -1.0

	# Yaw (A/D)
	_turn_input = 0.0
	if Input.is_action_pressed("turn_left"):
		_turn_input = -1.0
	elif Input.is_action_pressed("turn_right"):
		_turn_input = 1.0

	# Roll (Z/C)
	_roll_input = 0.0
	if Input.is_action_pressed("roll_left"):
		_roll_input = -1.0
	elif Input.is_action_pressed("roll_right"):
		_roll_input = 1.0

func _do_impulse_movement(delta: float) -> void:
	actual_speed = lerpf(actual_speed, target_speed, impulse_acceleration * delta / 100.0)
	var forward: Vector3 = -global_transform.basis.z
	linear_velocity = forward * actual_speed

# =============================================================================
# ROTATION - Simple manual control
# =============================================================================

func _do_rotation() -> void:
	var local_angular: Vector3 = global_transform.basis.inverse() * angular_velocity
	var local_torque: Vector3 = Vector3.ZERO

	# PITCH (W/S)
	if _pitch_input > 0.1 and local_angular.x > -max_pitch_rate:
		local_torque.x = -pitch_torque
	elif _pitch_input < -0.1 and local_angular.x < max_pitch_rate:
		local_torque.x = pitch_torque

	# YAW (A/D)
	if _turn_input > 0.1 and local_angular.y > -max_yaw_rate:
		local_torque.y = -yaw_torque
	elif _turn_input < -0.1 and local_angular.y < max_yaw_rate:
		local_torque.y = yaw_torque

	# ROLL (Z/C)
	if _roll_input > 0.1 and local_angular.z < max_roll_rate:
		local_torque.z = roll_torque
	elif _roll_input < -0.1 and local_angular.z > -max_roll_rate:
		local_torque.z = -roll_torque

	if local_torque != Vector3.ZERO:
		apply_torque(global_transform.basis * local_torque)

func _clamp_angular_velocity() -> void:
	var local_angular: Vector3 = global_transform.basis.inverse() * angular_velocity
	local_angular.x = clampf(local_angular.x, -max_pitch_rate, max_pitch_rate)
	local_angular.y = clampf(local_angular.y, -max_yaw_rate, max_yaw_rate)
	local_angular.z = clampf(local_angular.z, -max_roll_rate, max_roll_rate)
	angular_velocity = global_transform.basis * local_angular

func _do_full_stop(delta: float) -> void:
	actual_speed = lerpf(actual_speed, 0.0, 3.0 * delta)
	var forward: Vector3 = -global_transform.basis.z
	linear_velocity = forward * actual_speed

	if angular_velocity.length() > 0.001:
		apply_torque(-angular_velocity * mass * 5.0)

func _update_state() -> void:
	local_velocity = global_transform.basis.inverse() * linear_velocity
	forward_speed = -local_velocity.z
	thrust_input = float(current_impulse) / float(ImpulseLevel.FULL)
	rotation_input = Vector3(_pitch_input, _turn_input, _roll_input)

# =============================================================================
# IMPULSE CONTROL
# =============================================================================

func _increase_impulse() -> void:
	match current_impulse:
		ImpulseLevel.REVERSE:
			current_impulse = ImpulseLevel.STOP
		ImpulseLevel.STOP:
			current_impulse = ImpulseLevel.QUARTER
		ImpulseLevel.QUARTER:
			current_impulse = ImpulseLevel.HALF
		ImpulseLevel.HALF:
			current_impulse = ImpulseLevel.THREE_QUARTER
		ImpulseLevel.THREE_QUARTER:
			current_impulse = ImpulseLevel.FULL
	_update_target_speed()
	print("Impulse: ", get_impulse_name())

func _decrease_impulse() -> void:
	match current_impulse:
		ImpulseLevel.FULL:
			current_impulse = ImpulseLevel.THREE_QUARTER
		ImpulseLevel.THREE_QUARTER:
			current_impulse = ImpulseLevel.HALF
		ImpulseLevel.HALF:
			current_impulse = ImpulseLevel.QUARTER
		ImpulseLevel.QUARTER:
			current_impulse = ImpulseLevel.STOP
		ImpulseLevel.STOP:
			current_impulse = ImpulseLevel.REVERSE
	_update_target_speed()
	print("Impulse: ", get_impulse_name())

func _update_target_speed() -> void:
	match current_impulse:
		ImpulseLevel.REVERSE:
			target_speed = -full_impulse_speed * 0.25
		ImpulseLevel.STOP:
			target_speed = 0.0
		ImpulseLevel.QUARTER:
			target_speed = full_impulse_speed * 0.25
		ImpulseLevel.HALF:
			target_speed = full_impulse_speed * 0.5
		ImpulseLevel.THREE_QUARTER:
			target_speed = full_impulse_speed * 0.75
		ImpulseLevel.FULL:
			target_speed = full_impulse_speed

# =============================================================================
# PUBLIC API
# =============================================================================

func get_impulse_name() -> String:
	match current_impulse:
		ImpulseLevel.REVERSE: return "Reverse"
		ImpulseLevel.STOP: return "All Stop"
		ImpulseLevel.QUARTER: return "1/4 Impulse"
		ImpulseLevel.HALF: return "1/2 Impulse"
		ImpulseLevel.THREE_QUARTER: return "3/4 Impulse"
		ImpulseLevel.FULL: return "Full Impulse"
	return "Unknown"

func get_impulse_fraction() -> float:
	match current_impulse:
		ImpulseLevel.REVERSE: return -0.25
		ImpulseLevel.STOP: return 0.0
		ImpulseLevel.QUARTER: return 0.25
		ImpulseLevel.HALF: return 0.5
		ImpulseLevel.THREE_QUARTER: return 0.75
		ImpulseLevel.FULL: return 1.0
	return 0.0

func get_velocity_info() -> Dictionary:
	var local_ang: Vector3 = global_transform.basis.inverse() * angular_velocity
	return {
		"speed": linear_velocity.length(),
		"forward_speed": forward_speed,
		"local_velocity": local_velocity,
		"angular_velocity": angular_velocity,
		"angular_velocity_local": local_ang,
		"angular_deg_sec": Vector3(rad_to_deg(local_ang.x), rad_to_deg(local_ang.y), rad_to_deg(local_ang.z)),
		"heading": global_rotation_degrees,
		"impulse_level": current_impulse,
		"impulse_name": get_impulse_name(),
		"target_speed": target_speed,
		"actual_speed": actual_speed
	}

func set_damping(linear: float, angular: float) -> void:
	linear_damp = linear
	angular_damp = angular
