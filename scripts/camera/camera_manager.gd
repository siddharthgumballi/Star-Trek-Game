extends Node3D
class_name CameraManager
## Manages multiple camera modes: external, bridge, flyby, free
## Uses local offsets to avoid floating point precision issues at large distances

signal camera_mode_changed(mode: String)

enum CameraMode { EXTERNAL, BRIDGE, FLYBY, FREE }

@export_group("References")
@export var target_ship_path: NodePath
@export var bridge_interior_path: NodePath

# Resolved references
var target_ship: Node3D
var bridge_interior: BridgeInterior

@export_group("External Camera")
@export var external_distance: float = 80.0
@export var external_height: float = 25.0
@export var zoom_min: float = 30.0
@export var zoom_max: float = 1000.0
@export var zoom_speed: float = 20.0

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

# Orbit camera state (for click-drag)
var _orbit_yaw: float = 0.0      # Horizontal angle around ship
var _orbit_pitch: float = 0.15   # Vertical angle (radians)
var _is_dragging: bool = false
var _orbit_sensitivity: float = 0.005

# Free camera state - follows ship position, not rotation
var _free_offset: Vector3 = Vector3.ZERO  # Offset from ship in world space
var _free_yaw: float = 0.0
var _free_pitch: float = 0.0
var _free_zoom: float = 1.0

# Zoom state
var _current_zoom: float = 80.0

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

	# Find existing camera or create one
	_camera = get_node_or_null("MainCamera") as Camera3D
	if not _camera:
		_camera = Camera3D.new()
		_camera.name = "MainCamera"
		add_child(_camera)

	_camera.current = true
	_camera.far = 5000000.0  # 5 million units to see distant planets
	_camera.near = 1.0
	_camera.fov = 55.0

	_setup_inputs()
	_current_zoom = external_distance

	# Deferred initialization to ensure ship is positioned
	call_deferred("_deferred_init")

func _setup_inputs() -> void:
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

func _deferred_init() -> void:
	# Wait for ship to be positioned
	await get_tree().create_timer(0.1).timeout

	if not target_ship and target_ship_path:
		target_ship = get_node_or_null(target_ship_path)

	if target_ship and _camera:
		# Position camera behind ship
		var offset := Vector3(0, external_height, _current_zoom)
		_camera.global_position = target_ship.global_position + offset
		_camera.look_at(target_ship.global_position, Vector3.UP)
		_initialized = true
		print("=== CAMERA READY ===")
		print("  Ship at: ", target_ship.global_position)
		print("  Camera at: ", _camera.global_position)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_external"):
		set_mode(CameraMode.EXTERNAL)
	elif event.is_action_pressed("camera_bridge"):
		set_mode(CameraMode.BRIDGE)
	elif event.is_action_pressed("camera_flyby"):
		set_mode(CameraMode.FLYBY)
	elif event.is_action_pressed("camera_free"):
		set_mode(CameraMode.FREE)

	# Handle click-drag orbit and scroll zoom for External mode
	if current_mode == CameraMode.EXTERNAL:
		if event is InputEventMouseButton:
			var mb: InputEventMouseButton = event
			if mb.button_index == MOUSE_BUTTON_LEFT:
				_is_dragging = mb.pressed
			elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
				_current_zoom = clampf(_current_zoom - zoom_speed, zoom_min, zoom_max)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
				_current_zoom = clampf(_current_zoom + zoom_speed, zoom_min, zoom_max)

		if event is InputEventMagnifyGesture:
			var magnify: InputEventMagnifyGesture = event
			var zoom_delta: float = (1.0 - magnify.factor) * zoom_speed * 5.0
			_current_zoom = clampf(_current_zoom + zoom_delta, zoom_min, zoom_max)

		if event is InputEventPanGesture:
			var pan: InputEventPanGesture = event
			_current_zoom = clampf(_current_zoom + pan.delta.y * zoom_speed * 0.5, zoom_min, zoom_max)

		if event is InputEventMouseMotion and _is_dragging:
			var motion: InputEventMouseMotion = event
			_orbit_yaw -= motion.relative.x * _orbit_sensitivity
			_orbit_pitch -= motion.relative.y * _orbit_sensitivity
			_orbit_pitch = clampf(_orbit_pitch, -1.2, 1.2)

	# Free mode - same zoom as F1
	if current_mode == CameraMode.FREE:
		if event is InputEventMouseButton:
			var mb: InputEventMouseButton = event
			if mb.button_index == MOUSE_BUTTON_LEFT:
				_is_dragging = mb.pressed
			elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
				_current_zoom = clampf(_current_zoom - zoom_speed, zoom_min, zoom_max)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
				_current_zoom = clampf(_current_zoom + zoom_speed, zoom_min, zoom_max)

		if event is InputEventMagnifyGesture:
			var magnify: InputEventMagnifyGesture = event
			var zoom_delta: float = (1.0 - magnify.factor) * zoom_speed * 5.0
			_current_zoom = clampf(_current_zoom + zoom_delta, zoom_min, zoom_max)

		if event is InputEventPanGesture:
			var pan: InputEventPanGesture = event
			_current_zoom = clampf(_current_zoom + pan.delta.y * zoom_speed * 0.5, zoom_min, zoom_max)

		if event is InputEventMouseMotion and _is_dragging:
			var motion: InputEventMouseMotion = event
			_free_yaw -= motion.relative.x * _orbit_sensitivity
			_free_pitch -= motion.relative.y * _orbit_sensitivity
			_free_pitch = clampf(_free_pitch, -1.5, 1.5)

func _process(delta: float) -> void:
	if not target_ship and target_ship_path:
		target_ship = get_node_or_null(target_ship_path)
		if target_ship:
			print("CameraManager: Found target ship: ", target_ship.name)

	_frames_waited += 1
	if not _initialized and _frames_waited >= 3 and target_ship:
		_initialized = true
		print("=== CAMERA INITIALIZED ===")

	if not target_ship:
		return

	match current_mode:
		CameraMode.EXTERNAL:
			_update_external(delta)
		CameraMode.BRIDGE:
			_update_bridge(delta)
		CameraMode.FLYBY:
			_update_flyby(delta)
		CameraMode.FREE:
			_update_free(delta)

func _update_external(_delta: float) -> void:
	# Camera only moves when user drags or zooms - no automatic movement

	# Calculate camera offset in LOCAL ship space
	var local_offset := Vector3(
		sin(_orbit_yaw) * cos(_orbit_pitch) * _current_zoom,
		sin(_orbit_pitch) * _current_zoom + external_height,
		cos(_orbit_yaw) * cos(_orbit_pitch) * _current_zoom
	)

	# Transform local offset to world space and add to ship position
	var ship_basis: Basis = target_ship.global_transform.basis
	var world_offset: Vector3 = ship_basis * local_offset

	# Set camera position (ship position + rotated offset)
	_camera.global_position = target_ship.global_position + world_offset

	# Look at ship
	_camera.look_at(target_ship.global_position, Vector3.UP)

func _update_bridge(_delta: float) -> void:
	var t_basis: Basis = target_ship.global_transform.basis
	var t_pos: Vector3 = target_ship.global_position

	if bridge_interior:
		bridge_interior.global_position = t_pos + t_basis * bridge_offset
		bridge_interior.global_transform.basis = t_basis

		var cam_pos: Vector3 = bridge_interior.get_bridge_camera_position()
		var look_target: Vector3 = bridge_interior.get_bridge_look_target()

		_camera.global_position = cam_pos
		_camera.look_at(look_target, t_basis.y)
	else:
		var bridge_world: Vector3 = t_pos + t_basis * bridge_offset
		_camera.global_position = bridge_world

		var forward: Vector3 = -t_basis.z
		var look_target: Vector3 = _camera.global_position + forward * 1000.0
		_camera.look_at(look_target, t_basis.y)

func _update_flyby(delta: float) -> void:
	_flyby_angle += flyby_orbit_speed * delta

	# Calculate offset in local space
	var local_offset := Vector3(
		cos(_flyby_angle) * flyby_distance,
		sin(_flyby_angle * 0.5) * 100.0 + 100.0,
		sin(_flyby_angle) * flyby_distance
	)

	# Transform to world and position camera
	var ship_basis: Basis = target_ship.global_transform.basis
	var world_offset: Vector3 = ship_basis * local_offset

	_camera.global_position = target_ship.global_position + world_offset
	_camera.look_at(target_ship.global_position, Vector3.UP)

func _update_free(_delta: float) -> void:
	# Free camera - orbits around ship in WORLD space (not ship's local space)
	# Ship turns, camera stays in same world position relative to ship
	var offset := Vector3(
		sin(_free_yaw) * cos(_free_pitch) * _current_zoom,
		sin(_free_pitch) * _current_zoom + external_height,
		cos(_free_yaw) * cos(_free_pitch) * _current_zoom
	)

	_camera.global_position = target_ship.global_position + offset
	_camera.look_at(target_ship.global_position, Vector3.UP)

func set_mode(mode: CameraMode) -> void:
	if current_mode == mode:
		return

	current_mode = mode
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_is_dragging = false

	if bridge_interior:
		bridge_interior.visible = (mode == CameraMode.BRIDGE)

	match mode:
		CameraMode.EXTERNAL:
			_camera.fov = 55.0
		CameraMode.BRIDGE:
			_camera.fov = bridge_fov
		CameraMode.FLYBY:
			_camera.fov = 60.0
		CameraMode.FREE:
			_camera.fov = 70.0
			# Copy current orbit angles to free camera
			_free_yaw = _orbit_yaw
			_free_pitch = _orbit_pitch
			_free_zoom = 1.0

	var mode_name: String = ["External", "Bridge", "Flyby", "Free"][mode]
	print("Camera mode: ", mode_name)
	emit_signal("camera_mode_changed", mode_name)

func get_mode() -> CameraMode:
	return current_mode

func get_mode_name() -> String:
	return ["External", "Bridge", "Flyby", "Free"][current_mode]
