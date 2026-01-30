extends Node3D
class_name EngineEffects
## Visual effects for Enterprise-D engines: nacelle glow, impulse engines, running lights

@export_group("References")
@export var ship_controller_path: NodePath

# Resolved reference
var ship_controller: ShipController

@export_group("Nacelle Glow")
@export var nacelle_glow_color: Color = Color(0.4, 0.6, 1.0, 1.0)
@export var nacelle_glow_intensity: float = 2.0
@export var nacelle_glow_size: float = 8.0

@export_group("Impulse Engines")
@export var impulse_color_idle: Color = Color(1.0, 0.3, 0.1, 1.0)
@export var impulse_color_thrust: Color = Color(1.0, 0.6, 0.2, 1.0)
@export var impulse_color_boost: Color = Color(1.0, 0.9, 0.5, 1.0)
@export var impulse_intensity_idle: float = 1.0
@export var impulse_intensity_thrust: float = 3.0
@export var impulse_intensity_boost: float = 5.0

@export_group("Running Lights")
@export var running_light_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var blink_interval: float = 1.0

# Node references
var _nacelle_left: OmniLight3D
var _nacelle_right: OmniLight3D
var _impulse_light: OmniLight3D
var _running_lights: Array[OmniLight3D] = []
var _blink_timer: float = 0.0
var _blink_state: bool = true

func _ready() -> void:
	# Resolve node path
	if ship_controller_path:
		ship_controller = get_node_or_null(ship_controller_path) as ShipController

	_create_nacelle_lights()
	_create_impulse_light()
	_create_running_lights()

func _create_nacelle_lights() -> void:
	# Left nacelle glow
	_nacelle_left = OmniLight3D.new()
	_nacelle_left.light_color = nacelle_glow_color
	_nacelle_left.light_energy = nacelle_glow_intensity
	_nacelle_left.omni_range = nacelle_glow_size * 10
	_nacelle_left.position = Vector3(-35, 10, 30)  # Adjust based on model
	add_child(_nacelle_left)

	# Right nacelle glow
	_nacelle_right = OmniLight3D.new()
	_nacelle_right.light_color = nacelle_glow_color
	_nacelle_right.light_energy = nacelle_glow_intensity
	_nacelle_right.omni_range = nacelle_glow_size * 10
	_nacelle_right.position = Vector3(35, 10, 30)  # Adjust based on model
	add_child(_nacelle_right)

func _create_impulse_light() -> void:
	# Impulse engine glow (rear of saucer/engineering hull)
	_impulse_light = OmniLight3D.new()
	_impulse_light.light_color = impulse_color_idle
	_impulse_light.light_energy = impulse_intensity_idle
	_impulse_light.omni_range = 50.0
	_impulse_light.position = Vector3(0, 5, 70)  # Rear of ship
	add_child(_impulse_light)

func _create_running_lights() -> void:
	# Navigation lights
	var positions: Array[Vector3] = [
		Vector3(-50, 5, -30),   # Left wing tip (red)
		Vector3(50, 5, -30),    # Right wing tip (green)
		Vector3(0, 15, -50),    # Top of saucer
		Vector3(0, -10, 50),    # Bottom rear
	]

	var colors: Array[Color] = [
		Color(1.0, 0.0, 0.0),  # Red - port
		Color(0.0, 1.0, 0.0),  # Green - starboard
		Color(1.0, 1.0, 1.0),  # White - top
		Color(1.0, 1.0, 1.0),  # White - rear
	]

	for i in range(positions.size()):
		var light := OmniLight3D.new()
		light.light_color = colors[i]
		light.light_energy = 1.5
		light.omni_range = 20.0
		light.position = positions[i]
		add_child(light)
		_running_lights.append(light)

func _process(delta: float) -> void:
	_update_impulse_engines()
	_update_running_lights(delta)
	_update_nacelle_pulse(delta)

func _update_impulse_engines() -> void:
	if not ship_controller or not _impulse_light:
		return

	var thrust: float = ship_controller.thrust_input
	var boost: bool = ship_controller.boost_active

	if boost and thrust > 0:
		_impulse_light.light_color = impulse_color_boost
		_impulse_light.light_energy = impulse_intensity_boost
	elif absf(thrust) > 0.1:
		_impulse_light.light_color = impulse_color_thrust
		_impulse_light.light_energy = impulse_intensity_thrust * absf(thrust)
	else:
		_impulse_light.light_color = impulse_color_idle
		_impulse_light.light_energy = impulse_intensity_idle

func _update_running_lights(delta: float) -> void:
	_blink_timer += delta
	if _blink_timer >= blink_interval:
		_blink_timer = 0.0
		_blink_state = not _blink_state

	# Blink the white lights only
	for i in range(_running_lights.size()):
		if i >= 2:  # White lights
			_running_lights[i].visible = _blink_state

func _update_nacelle_pulse(_delta: float) -> void:
	# Subtle pulse effect on nacelles
	var pulse: float = (sin(Time.get_ticks_msec() * 0.002) + 1.0) * 0.5
	var intensity: float = nacelle_glow_intensity * (0.8 + pulse * 0.4)

	if _nacelle_left:
		_nacelle_left.light_energy = intensity
	if _nacelle_right:
		_nacelle_right.light_energy = intensity
