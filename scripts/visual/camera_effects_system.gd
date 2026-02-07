extends Node
class_name CameraEffectsSystem
## Camera cinematics: shake, vibration, FOV effects
## Subtle, cinematic effects only

# =============================================================================
# CONFIGURATION
# =============================================================================

# Shake presets (duration, intensity)
const SHAKE_PRESETS: Dictionary = {
	"phaser": {"duration": 0.15, "intensity": 0.01, "frequency": 30.0},
	"torpedo": {"duration": 0.25, "intensity": 0.015, "frequency": 25.0},
	"alert": {"duration": 0.3, "intensity": 0.02, "frequency": 20.0},
	"impact": {"duration": 0.4, "intensity": 0.03, "frequency": 15.0},
	"warp_exit": {"duration": 0.5, "intensity": 0.02, "frequency": 10.0}
}

# Idle vibration
const IDLE_VIBRATION_INTENSITY: float = 0.001
const IDLE_VIBRATION_FREQUENCY: float = 5.0

# FOV effects
const BASE_FOV: float = 55.0
const WARP_CHARGE_FOV_PULSE: float = 3.0  # FOV increase during charge
const FOV_TRANSITION_TIME: float = 0.5

# =============================================================================
# STATE
# =============================================================================

var _enabled: bool = true
var _camera: Camera3D = null
var _original_position: Vector3 = Vector3.ZERO
var _original_fov: float = BASE_FOV

# Shake state
var _shake_active: bool = false
var _shake_time: float = 0.0
var _shake_duration: float = 0.0
var _shake_intensity: float = 0.0
var _shake_frequency: float = 0.0

# Idle vibration
var _idle_vibration_enabled: bool = true
var _vibration_time: float = 0.0

# FOV state
var _warp_charging: bool = false
var _fov_tween: Tween = null

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	call_deferred("_initialize")

func _initialize() -> void:
	_find_camera()

func _find_camera() -> void:
	var parent: Node = get_parent()
	if parent and parent.has_method("get_camera"):
		_camera = parent.get_camera()

	if not _camera:
		# Search in groups
		var cameras: Array = get_tree().get_nodes_in_group("camera")
		if not cameras.is_empty():
			_camera = cameras[0]

	if not _camera:
		# Search scene tree
		_camera = _find_camera_recursive(get_tree().current_scene)

	if _camera:
		_original_fov = _camera.fov
		print("[CAMERA FX] Camera found, base FOV: %.1f" % _original_fov)

func _find_camera_recursive(node: Node) -> Camera3D:
	if node is Camera3D:
		return node
	for child in node.get_children():
		var result: Camera3D = _find_camera_recursive(child)
		if result:
			return result
	return null

# =============================================================================
# PROCESS
# =============================================================================

func _process(delta: float) -> void:
	if not _enabled or not _camera:
		return

	var offset: Vector3 = Vector3.ZERO

	# Apply shake
	if _shake_active:
		offset += _calculate_shake(delta)

	# Apply idle vibration (only when not at warp)
	if _idle_vibration_enabled and not _warp_charging:
		offset += _calculate_idle_vibration(delta)

	# Apply offset to camera
	if _camera.get_parent():
		# Camera is child of something (likely ship) - use local offset
		# Only apply rotation-based shake to avoid breaking camera follow
		_apply_rotation_shake(offset)

func _calculate_shake(delta: float) -> Vector3:
	_shake_time += delta

	if _shake_time >= _shake_duration:
		_shake_active = false
		_shake_time = 0.0
		return Vector3.ZERO

	# Decay intensity over time
	var decay: float = 1.0 - (_shake_time / _shake_duration)
	var current_intensity: float = _shake_intensity * decay

	# High-frequency noise
	var noise_x: float = sin(_shake_time * _shake_frequency * PI * 2.0 + randf() * 0.5)
	var noise_y: float = cos(_shake_time * _shake_frequency * PI * 2.0 * 1.3 + randf() * 0.5)
	var noise_z: float = sin(_shake_time * _shake_frequency * PI * 2.0 * 0.7 + randf() * 0.5)

	return Vector3(noise_x, noise_y, noise_z) * current_intensity

func _calculate_idle_vibration(delta: float) -> Vector3:
	_vibration_time += delta

	# Very subtle, low-frequency movement
	var x: float = sin(_vibration_time * IDLE_VIBRATION_FREQUENCY) * IDLE_VIBRATION_INTENSITY
	var y: float = cos(_vibration_time * IDLE_VIBRATION_FREQUENCY * 1.3) * IDLE_VIBRATION_INTENSITY * 0.5
	var z: float = sin(_vibration_time * IDLE_VIBRATION_FREQUENCY * 0.7) * IDLE_VIBRATION_INTENSITY * 0.3

	return Vector3(x, y, z)

func _apply_rotation_shake(offset: Vector3) -> void:
	# Apply shake as rotation rather than position to work with camera rigs
	if not _camera:
		return

	# Scale down for rotation (radians are more sensitive)
	var rot_scale: float = 0.5
	_camera.rotation.x = offset.y * rot_scale
	_camera.rotation.y = offset.x * rot_scale

# =============================================================================
# PUBLIC API
# =============================================================================

func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not enabled and _camera:
		_camera.rotation = Vector3.ZERO
		if _fov_tween:
			_fov_tween.kill()
		_camera.fov = _original_fov

func trigger_shake(shake_type: String, duration: float = -1, intensity: float = -1) -> void:
	if not _enabled:
		return

	var preset: Dictionary = SHAKE_PRESETS.get(shake_type, SHAKE_PRESETS["impact"])

	_shake_active = true
	_shake_time = 0.0
	_shake_duration = duration if duration > 0 else preset["duration"]
	_shake_intensity = intensity if intensity > 0 else preset["intensity"]
	_shake_frequency = preset["frequency"]

func start_warp_charge_fov() -> void:
	if not _enabled or not _camera:
		return

	_warp_charging = true

	# Subtle FOV pulse during charge
	if _fov_tween:
		_fov_tween.kill()

	_fov_tween = create_tween()
	_fov_tween.set_loops()

	# Pulse FOV slightly
	_fov_tween.tween_property(_camera, "fov", _original_fov + WARP_CHARGE_FOV_PULSE, 0.8)
	_fov_tween.tween_property(_camera, "fov", _original_fov, 0.8)

func end_warp_charge_fov() -> void:
	_warp_charging = false

	if _fov_tween:
		_fov_tween.kill()

	# Note: Don't reset FOV here as warp drive handles FOV during actual warp
	# Only reset if we're not at warp
	var warp_drive = _find_node_by_class("WarpDrive")
	if warp_drive and not warp_drive.is_at_warp and _camera:
		var reset_tween: Tween = create_tween()
		reset_tween.tween_property(_camera, "fov", _original_fov, FOV_TRANSITION_TIME)

func _find_node_by_class(class_name_str: String) -> Node:
	var root: Node = get_tree().current_scene
	return _find_recursive(root, class_name_str)

func _find_recursive(node: Node, class_name_str: String) -> Node:
	var script: Script = node.get_script()
	if script and script.get_global_name() == class_name_str:
		return node
	for child in node.get_children():
		var result: Node = _find_recursive(child, class_name_str)
		if result:
			return result
	return null

func set_idle_vibration(enabled: bool) -> void:
	_idle_vibration_enabled = enabled
