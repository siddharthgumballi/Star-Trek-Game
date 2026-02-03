extends Node3D
class_name WarpDrive
## Warp drive system for Enterprise-D with visual effects and speed multipliers

signal warp_engaged(warp_factor: float)
signal warp_disengaged()
signal warp_factor_changed(new_factor: float)
signal warp_blocked(reason: String, nearest_body: String)
signal warp_charging_started(warp_factor: float)  # Animation/sound start
signal warp_override_activated()  # Safety override enabled

@export_group("References")
@export var ship_controller_path: NodePath
@export var camera_path: NodePath

# Resolved references
var ship_controller: ShipController
var camera: Camera3D

@export_group("Warp Factors")
@export var max_warp_factor: float = 9.9  # Will be overridden by ship data
@export var warp_acceleration: float = 2.0

# TNG Warp Scale - speed in multiples of c (speed of light)
# Base: 1c = 299,792 km/s = 299.792 units/s
# Scaled (100×): 299.792 × 100 = 29,979 units/s
const LIGHT_SPEED_UNITS: float = 29979.0  # units per second (scaled)

# TNG warp scale lookup table [warp_factor, speed_in_c]
const TNG_WARP_SCALE: Array = [
	[1.0, 1.0],
	[2.0, 10.0],
	[3.0, 39.0],
	[4.0, 102.0],
	[5.0, 213.0],
	[6.0, 392.0],
	[7.0, 656.0],
	[8.0, 1024.0],
	[9.0, 1516.0],
	[9.2, 1649.0],
	[9.5, 1908.0],
	[9.6, 2014.0],
	[9.7, 2144.0],
	[9.8, 2305.0],
	[9.9, 3053.0],
	[9.95, 4490.0],
	[9.99, 7912.0],
	[9.999, 19974.0],
]

@export_group("Safety")
## Minimum distance from any celestial body to engage warp
## 5 million km = 500,000 units at 100× scale (1 unit = 10 km)
@export var min_safe_warp_distance: float = 500000.0

## Safety override: Press Ctrl+O 5 times rapidly to bypass proximity check
var _override_active: bool = false
var _override_press_count: int = 0
var _override_press_times: Array[float] = []
const OVERRIDE_REQUIRED_PRESSES: int = 5
const OVERRIDE_TIME_WINDOW: float = 2.0  # Must press 5 times within 2 seconds

@export_group("Visual Effects")
@export var star_stretch_amount: float = 50.0
@export var fov_warp_addition: float = 30.0
@export var warp_flash_color: Color = Color(0.5, 0.7, 1.0, 1.0)

@export_group("Controls")
@export var engage_key: String = "warp_engage"
@export var increase_key: String = "warp_increase"
@export var decrease_key: String = "warp_decrease"

# State
var is_at_warp: bool = false
var is_charging_warp: bool = false  # True during warp animation before actual warp
var current_warp_factor: float = 0.0
var target_warp_factor: float = 1.0
var warp_transition: float = 0.0  # 0 = impulse, 1 = full warp

# Warp charge timing - ship goes to warp 1 second before audio ends
# Audio is ~6.5 seconds, adjusted based on user testing
const WARP_CHARGE_TIME: float = 3.5
var _charge_timer: float = 0.0

# Visual effect nodes
var _warp_effect: Node3D
var _star_streaks: GPUParticles3D
var _warp_flash: MeshInstance3D

# Camera FOV tracking
var _base_camera_fov: float = 55.0

# Sector reference for planetary proximity check
var _sector: Node = null

func _ready() -> void:
	# Resolve node paths
	if ship_controller_path:
		ship_controller = get_node_or_null(ship_controller_path) as ShipController
	if camera_path:
		camera = get_node_or_null(camera_path) as Camera3D

	# Store the camera's base FOV for later restoration
	if camera:
		_base_camera_fov = camera.fov

	# Override max warp from selected ship
	var global_ship = get_node_or_null("/root/GlobalShipData")
	if global_ship and not global_ship.selected_ship_data.is_empty():
		max_warp_factor = global_ship.get_max_warp()
		print("Ship max warp factor: ", max_warp_factor)

	# Find the sector (root node with planet data)
	_find_sector()

	_setup_input_actions()
	_create_warp_effects()

func _find_sector() -> void:
	# Traverse up to find the sector node (has get_all_planets method)
	var node: Node = get_parent()
	while node:
		if node.has_method("get_all_planets"):
			_sector = node
			return
		node = node.get_parent()

func _setup_input_actions() -> void:
	# Add input actions if they don't exist
	if not InputMap.has_action("warp_engage"):
		InputMap.add_action("warp_engage")
		var event := InputEventKey.new()
		event.physical_keycode = KEY_W
		event.shift_pressed = true
		InputMap.action_add_event("warp_engage", event)

	if not InputMap.has_action("warp_increase"):
		InputMap.add_action("warp_increase")
		var event := InputEventKey.new()
		event.physical_keycode = KEY_EQUAL  # + key
		InputMap.action_add_event("warp_increase", event)

	if not InputMap.has_action("warp_decrease"):
		InputMap.add_action("warp_decrease")
		var event := InputEventKey.new()
		event.physical_keycode = KEY_MINUS
		InputMap.action_add_event("warp_decrease", event)

func _create_warp_effects() -> void:
	_warp_effect = Node3D.new()
	_warp_effect.name = "WarpEffects"
	add_child(_warp_effect)

	# Create star streak particles
	_star_streaks = GPUParticles3D.new()
	_star_streaks.name = "StarStreaks"
	_star_streaks.emitting = false
	_star_streaks.amount = 200
	_star_streaks.lifetime = 0.5
	_star_streaks.visibility_aabb = AABB(Vector3(-500, -500, -1000), Vector3(1000, 1000, 2000))

	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(200, 200, 50)
	material.direction = Vector3(0, 0, 1)
	material.spread = 0.0
	material.initial_velocity_min = 2000.0
	material.initial_velocity_max = 3000.0
	material.gravity = Vector3.ZERO
	material.scale_min = 0.5
	material.scale_max = 2.0
	material.color = Color(0.8, 0.9, 1.0, 0.8)
	_star_streaks.process_material = material

	# Simple mesh for particles
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.5, 0.5, 50.0)
	var mesh_material := StandardMaterial3D.new()
	mesh_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_material.albedo_color = Color(0.8, 0.9, 1.0, 0.8)
	mesh_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mesh_material
	_star_streaks.draw_pass_1 = mesh

	_star_streaks.position = Vector3(0, 0, -200)
	_warp_effect.add_child(_star_streaks)

func _input(event: InputEvent) -> void:
	# Safety override: Ctrl+O pressed 5 times rapidly
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_O and event.ctrl_pressed:
			_handle_override_press()

	if event.is_action_pressed("warp_engage"):
		if is_at_warp:
			disengage_warp()
		elif is_charging_warp:
			# Cancel warp charge
			_cancel_warp_charge()
		else:
			engage_warp()

	# Full stop while at warp should disengage and stop
	if event.is_action_pressed("full_stop") and is_at_warp:
		disengage_warp(true)  # true = full stop

	if event.is_action_pressed("warp_increase") and is_at_warp:
		set_warp_factor(target_warp_factor + 1.0)

	if event.is_action_pressed("warp_decrease") and is_at_warp:
		set_warp_factor(target_warp_factor - 1.0)

func _handle_override_press() -> void:
	var current_time: float = Time.get_ticks_msec() / 1000.0

	# Add this press time
	_override_press_times.append(current_time)

	# Remove old presses outside the time window
	while _override_press_times.size() > 0 and (current_time - _override_press_times[0]) > OVERRIDE_TIME_WINDOW:
		_override_press_times.pop_front()

	# Check if we have enough rapid presses
	if _override_press_times.size() >= OVERRIDE_REQUIRED_PRESSES:
		_override_active = true
		_override_press_times.clear()
		emit_signal("warp_override_activated")
		print("Override Accepted")
	else:
		var remaining: int = OVERRIDE_REQUIRED_PRESSES - _override_press_times.size()
		print("Override: %d more presses needed" % remaining)

func _cancel_warp_charge() -> void:
	if is_charging_warp:
		is_charging_warp = false
		_charge_timer = 0.0
		emit_signal("warp_disengaged")  # Triggers exit sound/animation
		print("Warp charge cancelled")

func _process(delta: float) -> void:
	# Handle warp charging timer
	if is_charging_warp:
		_charge_timer += delta
		if _charge_timer >= WARP_CHARGE_TIME:
			_complete_warp_engage()

	# Use _process for smooth visual updates (not tied to physics tick rate)
	if is_at_warp:
		_update_warp(delta)
	else:
		_update_impulse(delta)

	_update_visual_effects(delta)

func _update_warp(delta: float) -> void:
	# Smoothly approach target warp factor (clamped to prevent overshoot)
	current_warp_factor = lerpf(current_warp_factor, target_warp_factor, warp_acceleration * delta)
	current_warp_factor = clampf(current_warp_factor, 0.0, max_warp_factor)

	# Apply warp movement by directly moving the ship (avoids physics glitches)
	if ship_controller:
		var warp_speed: float = get_warp_speed_units(current_warp_factor)
		var forward: Vector3 = -ship_controller.global_transform.basis.z
		# Move ship directly instead of setting velocity (smoother)
		ship_controller.global_position += forward * warp_speed * delta
		# Reset linear velocity but allow angular velocity for steering
		ship_controller.linear_velocity = Vector3.ZERO
		# Angular velocity is NOT reset - allows steering during warp

	# Transition effect
	warp_transition = minf(warp_transition + delta * 2.0, 1.0)

func _update_impulse(delta: float) -> void:
	# Return to normal
	current_warp_factor = lerpf(current_warp_factor, 0.0, 3.0 * delta)
	warp_transition = maxf(warp_transition - delta * 3.0, 0.0)

func _update_visual_effects(_delta: float) -> void:
	# Star streaks
	if _star_streaks:
		_star_streaks.emitting = warp_transition > 0.1

		var mat: ParticleProcessMaterial = _star_streaks.process_material
		if mat:
			var speed: float = 2000.0 + current_warp_factor * 500.0
			mat.initial_velocity_min = speed
			mat.initial_velocity_max = speed * 1.5

	# Camera FOV effect
	if camera:
		if is_at_warp:
			# Calculate target FOV based on warp factor
			var warp_ratio: float = clampf(current_warp_factor / max_warp_factor, 0.0, 1.0)
			var target_fov: float = _base_camera_fov + (fov_warp_addition * warp_ratio)
			# Set FOV directly - no lerping to avoid oscillation
			camera.fov = target_fov
		elif warp_transition > 0.01:
			# Dropping out of warp - smoothly return to base
			camera.fov = lerpf(camera.fov, _base_camera_fov, 0.05)
		else:
			# Fully out of warp
			camera.fov = _base_camera_fov

## Check if ship is too close to any celestial body for warp
## Returns [is_safe: bool, nearest_body_name: String, distance: float]
func check_warp_clearance() -> Array:
	if not ship_controller or not _sector:
		return [true, "", 0.0]  # Can't check, allow warp

	var ship_pos: Vector3 = ship_controller.global_position
	var planets: Dictionary = _sector.get_all_planets()

	var nearest_body: String = ""
	var nearest_distance: float = INF

	for body_name in planets:
		var body: Node3D = planets[body_name]
		if not body:
			continue

		var distance: float = ship_pos.distance_to(body.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_body = body_name

	var is_safe: bool = nearest_distance >= min_safe_warp_distance
	return [is_safe, nearest_body, nearest_distance]

func engage_warp() -> void:
	if is_at_warp or is_charging_warp:
		return

	# Check planetary proximity before engaging warp
	var clearance: Array = check_warp_clearance()
	var is_safe: bool = clearance[0]
	var nearest_body: String = clearance[1]
	var distance: float = clearance[2]

	if not is_safe:
		# Check if override is active
		if _override_active:
			print("Override Used - Engaging warp despite proximity warning")
			_override_active = false  # Consume the override
		else:
			# At 100× scale: 1 unit = 10 km (1000 km / 100)
			var distance_km: float = distance * 10.0
			var min_safe_km: float = min_safe_warp_distance * 10.0
			var reason: String = "Too close to %s (%.0f km). Minimum safe distance: %.0f km. Press Ctrl+O 5x to override." % [
				nearest_body, distance_km, min_safe_km
			]
			emit_signal("warp_blocked", reason, nearest_body)
			print("WARP BLOCKED: ", reason)
			return

	# Start warp charging phase (animation + sound play)
	is_charging_warp = true
	_charge_timer = 0.0
	target_warp_factor = maxf(target_warp_factor, 1.0)

	# Capture the camera's current FOV as the base for warp effects
	if camera:
		_base_camera_fov = camera.fov

	# Signal that warp is starting (triggers animation and sound)
	emit_signal("warp_charging_started", target_warp_factor)
	print("Warp ", target_warp_factor, " charging...")

func _complete_warp_engage() -> void:
	# Called after charge timer completes - actually enter warp
	is_charging_warp = false
	is_at_warp = true

	emit_signal("warp_engaged", target_warp_factor)
	print("Warp ", target_warp_factor, " engaged!")

func disengage_warp(full_stop: bool = false) -> void:
	if not is_at_warp:
		return

	is_at_warp = false

	# Set impulse level
	if ship_controller:

		if full_stop:
			# Full stop - no momentum, impulse to stop
			ship_controller.linear_velocity = Vector3.ZERO
			ship_controller.current_impulse = ShipController.ImpulseLevel.STOP
			print("Dropping out of warp - ALL STOP")
		else:
			# Normal disengage - go to full impulse with some momentum
			var forward: Vector3 = -ship_controller.global_transform.basis.z
			ship_controller.linear_velocity = forward * ship_controller.full_impulse_speed
			ship_controller.current_impulse = ShipController.ImpulseLevel.FULL
			print("Dropping out of warp - Full Impulse")

	emit_signal("warp_disengaged")

func set_warp_factor(factor: float) -> void:
	target_warp_factor = clampf(factor, 1.0, max_warp_factor)
	emit_signal("warp_factor_changed", target_warp_factor)
	print("Warp factor set to ", target_warp_factor)

func get_warp_factor() -> float:
	return current_warp_factor

func get_target_warp_factor() -> float:
	return target_warp_factor

## Calculate speed in c (multiples of light speed) from warp factor using TNG scale
func get_warp_speed_in_c(warp_factor: float) -> float:
	if warp_factor <= 0:
		return 0.0

	# Find the two points to interpolate between
	var lower_idx: int = 0
	var upper_idx: int = TNG_WARP_SCALE.size() - 1

	for i in range(TNG_WARP_SCALE.size()):
		if TNG_WARP_SCALE[i][0] <= warp_factor:
			lower_idx = i
		if TNG_WARP_SCALE[i][0] >= warp_factor:
			upper_idx = i
			break

	# If exact match or at bounds, return directly
	if lower_idx == upper_idx:
		return TNG_WARP_SCALE[lower_idx][1]

	# Interpolate between the two points
	var lower_warp: float = TNG_WARP_SCALE[lower_idx][0]
	var upper_warp: float = TNG_WARP_SCALE[upper_idx][0]
	var lower_speed: float = TNG_WARP_SCALE[lower_idx][1]
	var upper_speed: float = TNG_WARP_SCALE[upper_idx][1]

	var t: float = (warp_factor - lower_warp) / (upper_warp - lower_warp)
	return lerpf(lower_speed, upper_speed, t)

## Calculate speed in game units per second from warp factor
func get_warp_speed_units(warp_factor: float) -> float:
	return get_warp_speed_in_c(warp_factor) * LIGHT_SPEED_UNITS
