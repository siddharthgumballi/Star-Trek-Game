extends Node3D
class_name CinematicShipCamera
## Cinematic camera for Galaxy-class starship

# =============================================================================
# CONFIGURATION
# =============================================================================

@export_group("Target")
@export var target: Node3D

@export_group("Position")
@export var follow_distance: float = 400.0
@export var follow_height: float = 200.0
@export var min_distance: float = 150.0
@export var max_distance: float = 800.0
@export var zoom_speed: float = 30.0

@export_group("Smoothing")
@export var position_lag: float = 2.5
@export var rotation_lag: float = 2.0

@export_group("Look Target")
@export var look_ahead: float = 80.0
@export var look_down: float = -60.0

@export_group("FOV")
@export var base_fov: float = 55.0
@export var max_fov: float = 70.0

# =============================================================================
# STATE
# =============================================================================

@onready var camera: Camera3D = $Camera3D

var _target_ship: ShipController = null
var _smoothed_pos: Vector3 = Vector3.ZERO
var _smoothed_rot: Quaternion = Quaternion.IDENTITY
var _current_fov: float = 55.0

# =============================================================================
# READY
# =============================================================================

func _ready() -> void:
	_current_fov = base_fov
	if target:
		_snap_to_target()
		if target is ShipController:
			_target_ship = target as ShipController

func _snap_to_target() -> void:
	if not target:
		return
	var t_pos: Vector3 = target.global_position
	var t_basis: Basis = target.global_transform.basis

	var offset: Vector3 = Vector3(0, follow_height, follow_distance)
	_smoothed_pos = t_pos + t_basis * offset
	global_position = _smoothed_pos

	look_at(t_pos + Vector3(0, look_down, 0))
	_smoothed_rot = Quaternion(global_transform.basis)

# =============================================================================
# INPUT
# =============================================================================

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_zoom_in"):
		follow_distance = maxf(follow_distance - zoom_speed, min_distance)
	elif event.is_action_pressed("camera_zoom_out"):
		follow_distance = minf(follow_distance + zoom_speed, max_distance)

# =============================================================================
# UPDATE
# =============================================================================

func _physics_process(delta: float) -> void:
	if not target:
		return

	_update_position(delta)
	_update_rotation(delta)
	_update_fov(delta)

func _update_position(delta: float) -> void:
	var t_pos: Vector3 = target.global_position
	var t_basis: Basis = target.global_transform.basis

	var offset: Vector3 = Vector3(0, follow_height, follow_distance)
	var desired: Vector3 = t_pos + t_basis * offset

	var smooth: float = 1.0 - exp(-position_lag * delta)
	_smoothed_pos = _smoothed_pos.lerp(desired, smooth)
	global_position = _smoothed_pos

func _update_rotation(delta: float) -> void:
	var t_pos: Vector3 = target.global_position
	var t_basis: Basis = target.global_transform.basis

	var look_offset: Vector3 = Vector3(0, look_down, -look_ahead)
	var look_target: Vector3 = t_pos + t_basis * look_offset

	var dir: Vector3 = (look_target - global_position).normalized()
	var up: Vector3 = Vector3.UP
	if absf(dir.dot(Vector3.UP)) > 0.98:
		up = t_basis.z

	var desired_basis: Basis = Basis.looking_at(dir, up)
	var desired_rot: Quaternion = Quaternion(desired_basis)

	var smooth: float = 1.0 - exp(-rotation_lag * delta)
	_smoothed_rot = _smoothed_rot.slerp(desired_rot, smooth)
	global_transform.basis = Basis(_smoothed_rot)

func _update_fov(delta: float) -> void:
	if not camera or not _target_ship:
		return

	var speed: float = _target_ship.linear_velocity.length()
	var max_speed: float = _target_ship._estimate_max_speed()
	var ratio: float = clampf(speed / max_speed, 0.0, 1.0)

	var target_fov: float = lerpf(base_fov, max_fov, ratio)
	_current_fov = lerpf(_current_fov, target_fov, 2.0 * delta)
	camera.fov = _current_fov

# =============================================================================
# PUBLIC
# =============================================================================

func set_target(new_target: Node3D) -> void:
	target = new_target
	if target is ShipController:
		_target_ship = target as ShipController
	else:
		_target_ship = null
	if target:
		_snap_to_target()
