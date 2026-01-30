extends Node3D
class_name CameraManager
## Manages multiple camera modes: external, bridge, flyby, free

signal camera_mode_changed(mode: String)

enum CameraMode { EXTERNAL, BRIDGE, FLYBY, FREE }

@export_group("References")
@export var target_ship_path: NodePath
@export var bridge_interior_path: NodePath

# Resolved references
var target_ship: Node3D
var bridge_interior: BridgeInterior

@export_group("External Camera")
@export var external_distance: float = 400.0
@export var external_height: float = 200.0
@export var zoom_min: float = 80.0
@export var zoom_max: float = 1500.0
@export var zoom_speed: float = 50.0

@export_group("Bridge Camera")
@export var bridge_offset: Vector3 = Vector3(0, 8, -40)
@export var bridge_fov: float = 75.0

@export_group("Flyby Camera")
@export var flyby_distance: float = 300.0
@export var flyby_orbit_speed: float = 0.1

@export_group("Free Camera")
@export var free_move_speed: float = 500.0
@export var free_look_sensitivity: float = 0.003

# State
var current_mode: CameraMode = CameraMode.EXTERNAL
var _camera: Camera3D
var _flyby_angle: float = 0.0
var _free_velocity: Vector3 = Vector3.ZERO

# Orbit camera state (for click-drag in F1 and F4)
var _orbit_yaw: float = 0.0      # Horizontal angle around ship
var _orbit_pitch: float = 0.05  # Vertical angle (radians, 0 = level, positive = above)
var _is_dragging: bool = false
var _orbit_sensitivity: float = 0.005
var _time_since_drag: float = 0.0  # Timer for returning to default position
var _default_orbit_yaw: float = 0.0
var _default_orbit_pitch: float = 0.05
var _return_delay: float = 5.0  # Seconds before returning to default

# Zoom state for F1 (External) and F4 (Free) modes
var _current_zoom: float = 400.0

# Smoothing
var _smoothed_pos: Vector3 = Vector3(0, 1000, 1000)  # Start away from origin to avoid being inside Sun
var _smoothed_rot: Quaternion = Quaternion.IDENTITY

# Ship velocity tracking for warp detection
var _last_ship_pos: Vector3 = Vector3.ZERO
var _ship_speed: float = 0.0

var _initialized: bool = false
var _frames_waited: int = 0

func _ready() -> void:
	# Resolve node paths
	if target_ship_path:
		target_ship = get_node_or_null(target_ship_path)
	if bridge_interior_path:
		bridge_interior = get_node_or_null(bridge_interior_path) as BridgeInterior

	# Initially hide bridge interior
	if bridge_interior:
		bridge_interior.visible = false

	_camera = Camera3D.new()
	_camera.current = true
	_camera.far = 500000.0  # 500k units - enough to see nearby planets
	_camera.near = 1.0
	add_child(_camera)

	# Setup input actions
	_setup_inputs()

	# Initialize zoom to default distance
	_current_zoom = external_distance

func _setup_inputs() -> void:
	# Camera mode switching: F1-F4
	if not InputMap.has_action("camera_external"):
		InputMap.add_action("camera_external")
		var e := InputEventKey.new()
		e.physical_keycode = KEY_F1
		InputMap.action_add_event("camera_external", e)

	if not InputMap.has_action("camera_bridge"):
		InputMap.add_action("camera_bridge")
		var e := InputEventKey.new()
		e.physical_keycode = KEY_F2
		InputMap.action_add_event("camera_bridge", e)

	if not InputMap.has_action("camera_flyby"):
		InputMap.add_action("camera_flyby")
		var e := InputEventKey.new()
		e.physical_keycode = KEY_F3
		InputMap.action_add_event("camera_flyby", e)

	if not InputMap.has_action("camera_free"):
		InputMap.add_action("camera_free")
		var e := InputEventKey.new()
		e.physical_keycode = KEY_F4
		InputMap.action_add_event("camera_free", e)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_external"):
		set_mode(CameraMode.EXTERNAL)
	elif event.is_action_pressed("camera_bridge"):
		set_mode(CameraMode.BRIDGE)
	elif event.is_action_pressed("camera_flyby"):
		set_mode(CameraMode.FLYBY)
	elif event.is_action_pressed("camera_free"):
		set_mode(CameraMode.FREE)

	# Handle click-drag orbit and scroll zoom for External and Free modes
	if current_mode == CameraMode.EXTERNAL or current_mode == CameraMode.FREE:
		if event is InputEventMouseButton:
			var mb: InputEventMouseButton = event
			if mb.button_index == MOUSE_BUTTON_LEFT:
				_is_dragging = mb.pressed
				if not mb.pressed:
					_time_since_drag = 0.0
			# Scroll wheel zoom
			elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
				_current_zoom = clampf(_current_zoom - zoom_speed, zoom_min, zoom_max)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
				_current_zoom = clampf(_current_zoom + zoom_speed, zoom_min, zoom_max)

		# Trackpad pinch-to-zoom
		if event is InputEventMagnifyGesture:
			var magnify: InputEventMagnifyGesture = event
			var zoom_delta: float = (1.0 - magnify.factor) * zoom_speed * 5.0
			_current_zoom = clampf(_current_zoom + zoom_delta, zoom_min, zoom_max)

		# Trackpad two-finger scroll for zoom
		if event is InputEventPanGesture:
			var pan: InputEventPanGesture = event
			_current_zoom = clampf(_current_zoom + pan.delta.y * zoom_speed * 0.5, zoom_min, zoom_max)

		if event is InputEventMouseMotion and _is_dragging:
			var motion: InputEventMouseMotion = event
			_orbit_yaw -= motion.relative.x * _orbit_sensitivity
			_orbit_pitch -= motion.relative.y * _orbit_sensitivity
			_orbit_pitch = clampf(_orbit_pitch, -1.2, 1.2)
			_time_since_drag = 0.0

func _process(delta: float) -> void:
	# Use _process instead of _physics_process for smooth camera movement
	# Re-resolve target_ship if needed
	if not target_ship and target_ship_path:
		target_ship = get_node_or_null(target_ship_path)
		if target_ship:
			print("CameraManager: Found target ship: ", target_ship.name)

	# Initialize camera after a few frames
	_frames_waited += 1

	if not _initialized and _frames_waited >= 3:
		if target_ship:
			var ship_pos: Vector3 = target_ship.global_position
			var ship_back: Vector3 = target_ship.global_transform.basis.z
			_smoothed_pos = ship_pos + ship_back * external_distance + Vector3(0, external_height, 0)
			_camera.global_position = _smoothed_pos
			_camera.look_at(ship_pos, Vector3.UP)
			_initialized = true
			print("=== CAMERA INITIALIZED ===")
			print("  Ship at: ", ship_pos)
			print("  Camera at: ", _smoothed_pos)
		else:
			# Fallback: position camera to see Earth area (at ~150000 units from origin)
			_smoothed_pos = Vector3(152000, 500, 0)
			_camera.global_position = _smoothed_pos
			_camera.look_at(Vector3(149600, 0, 0), Vector3.UP)  # Look at Earth's approximate position
			_initialized = true
			print("=== CAMERA FALLBACK (no ship found) ===")
			print("  Camera at: ", _smoothed_pos)

	# Track ship speed to detect warp (used by all camera modes)
	if target_ship and delta > 0:
		var t_pos: Vector3 = target_ship.global_position
		_ship_speed = _last_ship_pos.distance_to(t_pos) / delta
		_last_ship_pos = t_pos

	match current_mode:
		CameraMode.EXTERNAL:
			_update_external(delta)
		CameraMode.BRIDGE:
			_update_bridge(delta)
		CameraMode.FLYBY:
			_update_flyby(delta)
		CameraMode.FREE:
			_update_free(delta)

func _update_external(delta: float) -> void:
	if not target_ship:
		return

	var t_pos: Vector3 = target_ship.global_position
	var t_basis: Basis = target_ship.global_transform.basis

	# Safety check: if camera is too far from ship, snap to it immediately
	var dist_to_ship: float = _smoothed_pos.distance_to(t_pos)
	if dist_to_ship > zoom_max * 5.0 or dist_to_ship > 50000.0:
		var ship_back: Vector3 = t_basis.z
		_smoothed_pos = t_pos + ship_back * _current_zoom + Vector3(0, external_height, 0)
		_camera.global_position = _smoothed_pos
		_camera.look_at(t_pos, Vector3.UP)
		print("Camera EMERGENCY snap to ship!")

	# Calculate target "back of ship" angles in world space
	var ship_back: Vector3 = t_basis.z  # Ship's backward direction
	var target_yaw: float = atan2(ship_back.x, ship_back.z)
	var target_pitch: float = 0.15  # Slightly above

	# Return to behind ship after delay when not dragging
	if not _is_dragging:
		_time_since_drag += delta
		if _time_since_drag > _return_delay:
			# Smoothly return to behind ship (world space angles)
			_orbit_yaw = lerp_angle(_orbit_yaw, target_yaw, 2.0 * delta)
			_orbit_pitch = lerpf(_orbit_pitch, target_pitch, 2.0 * delta)

	# Calculate camera position in WORLD space (independent of ship rotation)
	var distance: float = _current_zoom
	var cam_x: float = sin(_orbit_yaw) * cos(_orbit_pitch) * distance
	var cam_y: float = sin(_orbit_pitch) * distance + external_height
	var cam_z: float = cos(_orbit_yaw) * cos(_orbit_pitch) * distance

	var desired: Vector3 = t_pos + Vector3(cam_x, cam_y, cam_z)

	# If ship is at warp speed (> 1000 units/sec), snap camera to avoid oscillation
	# Otherwise use smooth follow for cinematic feel
	if _ship_speed > 1000.0:
		_smoothed_pos = desired
	else:
		var smooth_factor: float = 1.0 - exp(-12.0 * delta)
		_smoothed_pos = _smoothed_pos.lerp(desired, smooth_factor)
	_camera.global_position = _smoothed_pos

	# Look at ship (world up so you see ship banking)
	_camera.look_at(t_pos, Vector3.UP)

	# FOV is set in set_mode() - don't override here to allow warp drive effects

func _update_bridge(delta: float) -> void:
	if not target_ship:
		return

	var t_basis: Basis = target_ship.global_transform.basis
	var t_pos: Vector3 = target_ship.global_position

	# Exponential smoothing factor (frame-rate independent)
	var smooth_factor: float = 1.0 - exp(-15.0 * delta)

	# Update bridge interior position to follow ship
	if bridge_interior:
		bridge_interior.global_position = t_pos + t_basis * bridge_offset
		bridge_interior.global_transform.basis = t_basis

		# Use bridge's recommended camera position (behind captain's chair)
		var cam_pos: Vector3 = bridge_interior.get_bridge_camera_position()
		var look_target: Vector3 = bridge_interior.get_bridge_look_target()

		_camera.global_position = _camera.global_position.lerp(cam_pos, smooth_factor)
		_camera.look_at(look_target, t_basis.y)
	else:
		# Fallback if no bridge interior
		var bridge_world: Vector3 = t_pos + t_basis * bridge_offset
		_camera.global_position = _camera.global_position.lerp(bridge_world, smooth_factor)

		var forward: Vector3 = -t_basis.z
		var look_target: Vector3 = _camera.global_position + forward * 1000.0
		_camera.look_at(look_target, t_basis.y)

	# FOV is set in set_mode() - don't override here to allow warp drive effects

func _update_flyby(delta: float) -> void:
	if not target_ship:
		return

	var t_pos: Vector3 = target_ship.global_position

	# Safety check: snap if too far
	if _smoothed_pos.distance_to(t_pos) > flyby_distance * 10.0:
		_smoothed_pos = t_pos + Vector3(flyby_distance, 100, 0)

	_flyby_angle += flyby_orbit_speed * delta

	# Orbit around ship
	var x: float = cos(_flyby_angle) * flyby_distance
	var z: float = sin(_flyby_angle) * flyby_distance
	var y: float = sin(_flyby_angle * 0.5) * 100.0 + 100.0

	var desired: Vector3 = t_pos + Vector3(x, y, z)

	# If ship is at warp speed, snap camera to avoid oscillation
	if _ship_speed > 1000.0:
		_smoothed_pos = desired
	else:
		var smooth_factor: float = 1.0 - exp(-8.0 * delta)
		_smoothed_pos = _smoothed_pos.lerp(desired, smooth_factor)
	_camera.global_position = _smoothed_pos

	# Always look at ship
	_camera.look_at(t_pos, Vector3.UP)
	# FOV is set in set_mode() - don't override here to allow warp drive effects

func _update_free(delta: float) -> void:
	# Free camera orbits ship with click-drag and scroll zoom, WASD still controls ship
	if not target_ship:
		return

	var t_pos: Vector3 = target_ship.global_position

	# Safety check: snap if too far
	if _smoothed_pos.distance_to(t_pos) > zoom_max * 10.0:
		_smoothed_pos = t_pos + Vector3(0, external_height, _current_zoom)

	# Calculate orbit position using zoom distance
	var distance: float = _current_zoom
	var height_factor: float = _current_zoom / external_distance
	var cam_x: float = sin(_orbit_yaw) * cos(_orbit_pitch) * distance
	var cam_y: float = sin(_orbit_pitch) * distance + (external_height + 20) * height_factor
	var cam_z: float = cos(_orbit_yaw) * cos(_orbit_pitch) * distance

	var desired: Vector3 = t_pos + Vector3(cam_x, cam_y, cam_z)

	# If ship is at warp speed, snap camera to avoid oscillation
	if _ship_speed > 1000.0:
		_smoothed_pos = desired
	else:
		var smooth_factor: float = 1.0 - exp(-10.0 * delta)
		_smoothed_pos = _smoothed_pos.lerp(desired, smooth_factor)
	_camera.global_position = _smoothed_pos

	# Always look at ship center
	_camera.look_at(t_pos, Vector3.UP)

	# FOV is set in set_mode() - don't override here to allow warp drive effects

func set_mode(mode: CameraMode) -> void:
	if current_mode == mode:
		return

	current_mode = mode

	# Mouse is always visible now (click-drag to orbit)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_is_dragging = false

	# Show/hide bridge interior based on mode
	if bridge_interior:
		bridge_interior.visible = (mode == CameraMode.BRIDGE)

	# Set base FOV for the mode (warp_drive.gd will modify this during warp)
	match mode:
		CameraMode.EXTERNAL:
			_camera.fov = 55.0
		CameraMode.BRIDGE:
			_camera.fov = bridge_fov
		CameraMode.FLYBY:
			_camera.fov = 60.0
		CameraMode.FREE:
			_camera.fov = 70.0

	var mode_name: String = ["External", "Bridge", "Flyby", "Free"][mode]
	print("Camera mode: ", mode_name)
	emit_signal("camera_mode_changed", mode_name)

func get_mode() -> CameraMode:
	return current_mode

func get_mode_name() -> String:
	return ["External", "Bridge", "Flyby", "Free"][current_mode]
