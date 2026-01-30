extends Control
class_name FlightHUD
## Flight telemetry HUD with deg/sec rotation display.

@export var ship: ShipController

@onready var speed_label: Label = $MarginContainer/VBoxContainer/SpeedLabel
@onready var heading_label: Label = $MarginContainer/VBoxContainer/HeadingLabel
@onready var thrust_label: Label = $MarginContainer/VBoxContainer/ThrustLabel
@onready var velocity_label: Label = $MarginContainer/VBoxContainer/VelocityLabel
@onready var controls_label: Label = $MarginContainer/VBoxContainer/ControlsLabel

func _ready() -> void:
	if controls_label:
		controls_label.text = """Controls:
W/S - Thrust Forward/Reverse
A/D - Yaw Left/Right
Q/E - Roll Left/Right
↑/↓ - Pitch Up/Down
Shift - Boost
Space - Full Stop
Mouse Wheel - Zoom"""

func _process(_delta: float) -> void:
	if not ship:
		return

	var info: Dictionary = ship.get_velocity_info()

	if speed_label:
		var speed: float = info.get("speed", 0.0)
		var forward: float = info.get("forward_speed", 0.0)
		speed_label.text = "Speed: %.1f m/s (Fwd: %.1f)" % [speed, forward]

	if heading_label:
		var heading: Vector3 = info.get("heading", Vector3.ZERO)
		heading_label.text = "Heading: P:%.1f° Y:%.1f° R:%.1f°" % [heading.x, heading.y, heading.z]

	if thrust_label:
		var thrust_text: String = "Thrust: "
		if ship.full_stop_active:
			thrust_text += "FULL STOP"
		elif ship.boost_active and ship.thrust_input > 0:
			thrust_text += "BOOST %.0f%%" % (ship.thrust_input * 100)
		else:
			thrust_text += "%.0f%%" % (ship.thrust_input * 100)
		thrust_label.text = thrust_text

	if velocity_label:
		# Show rotation rate in degrees per second
		var ang_deg: Vector3 = info.get("angular_deg_sec", Vector3.ZERO)
		velocity_label.text = "Rotation: P:%.1f°/s Y:%.1f°/s R:%.1f°/s" % [ang_deg.x, ang_deg.y, ang_deg.z]
