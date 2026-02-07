extends Node
class_name StarshipCore
## Central coordinator for all starship subsystems
## Routes commands, manages state, and coordinates between departments

signal alert_changed(level: int)
signal power_changed(distribution: Dictionary)
signal command_executed(department: String, intent: String, result: Dictionary)
signal subsystem_registered(name: String)

# =============================================================================
# ALERT LEVELS
# =============================================================================

enum AlertLevel { GREEN = 0, YELLOW = 1, RED = 2 }

const ALERT_NAMES: Dictionary = {
	AlertLevel.GREEN: "Green",
	AlertLevel.YELLOW: "Yellow",
	AlertLevel.RED: "Red"
}

# =============================================================================
# AUDIO
# =============================================================================

const RED_ALERT_SOUND_PATH: String = "res://assets/audio/alerts/tng_red_alert.mp3"
const RED_ALERT_DURATION: float = 10.0  # Play for 10 seconds

var _red_alert_audio: AudioStreamPlayer = null
var _red_alert_timer: Timer = null

# =============================================================================
# STATE
# =============================================================================

var _alert_level: int = AlertLevel.GREEN
var _subsystems: Dictionary = {}  # name -> SubsystemBase
var _power_system: PowerSystem

# External references (set via @export or found at runtime)
@export var ship_controller_path: NodePath
@export var warp_drive_path: NodePath
@export var hud_path: NodePath

var ship_controller: Node3D = null
var warp_drive: Node3D = null
var hud: Control = null

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	_power_system = PowerSystem.new()

	# Resolve external references
	_resolve_references()

	# Auto-register child subsystems
	_register_child_subsystems()

	# Create keyboard controller for manual input
	_create_keyboard_controller()

	# Create cinematic effects manager for visual feedback
	_create_cinematic_effects()

	# Setup red alert audio
	_setup_alert_audio()

	print("[STARSHIP CORE] Initialized with %d subsystems" % _subsystems.size())

func _setup_alert_audio() -> void:
	"""Setup audio player for red alert klaxon."""
	_red_alert_audio = AudioStreamPlayer.new()
	_red_alert_audio.name = "RedAlertAudio"
	_red_alert_audio.volume_db = -2.0  # Prominent but not deafening
	if ResourceLoader.exists(RED_ALERT_SOUND_PATH):
		_red_alert_audio.stream = load(RED_ALERT_SOUND_PATH)
		print("[STARSHIP CORE] Red alert audio loaded")
	add_child(_red_alert_audio)

	# Timer to stop the alert sound after duration
	_red_alert_timer = Timer.new()
	_red_alert_timer.name = "RedAlertTimer"
	_red_alert_timer.one_shot = true
	_red_alert_timer.timeout.connect(_stop_red_alert_sound)
	add_child(_red_alert_timer)

func _play_red_alert_sound() -> void:
	"""Play the red alert klaxon for RED_ALERT_DURATION seconds."""
	if _red_alert_audio and _red_alert_audio.stream:
		_red_alert_audio.play()
		_red_alert_timer.start(RED_ALERT_DURATION)
		print("[STARSHIP CORE] Red alert klaxon playing")

func _stop_red_alert_sound() -> void:
	"""Stop the red alert klaxon."""
	if _red_alert_audio and _red_alert_audio.playing:
		_red_alert_audio.stop()
		print("[STARSHIP CORE] Red alert klaxon stopped")

func _create_keyboard_controller() -> void:
	"""Create keyboard controller for manual input if not already present."""
	# Check if one already exists
	for child in get_children():
		if child.get_script() and child.get_script().get_global_name() == "KeyboardController":
			return

	# Create new keyboard controller
	var kb_script: Script = load("res://scripts/ship/keyboard_controller.gd")
	if kb_script:
		var kb_controller: Node = Node.new()
		kb_controller.set_script(kb_script)
		kb_controller.name = "KeyboardController"
		add_child(kb_controller)
		print("[STARSHIP CORE] Keyboard controller created")

func _create_cinematic_effects() -> void:
	"""Create cinematic effects manager for visual feedback if not already present."""
	# Check if one already exists
	for child in get_children():
		if child.get_script() and child.get_script().get_global_name() == "CinematicEffectsManager":
			return

	# Create new cinematic effects manager
	var fx_script: Script = load("res://scripts/visual/cinematic_effects_manager.gd")
	if fx_script:
		var fx_manager: Node = Node.new()
		fx_manager.set_script(fx_script)
		fx_manager.name = "CinematicEffectsManager"
		add_child(fx_manager)
		print("[STARSHIP CORE] Cinematic effects manager created")

func _resolve_references() -> void:
	"""Resolve node path references to actual nodes."""
	if ship_controller_path:
		ship_controller = get_node_or_null(ship_controller_path)
	if warp_drive_path:
		warp_drive = get_node_or_null(warp_drive_path)
	if hud_path:
		hud = get_node_or_null(hud_path)

	# Fallback: try to find them in the scene tree
	if not ship_controller:
		ship_controller = _find_node_by_class("ShipController")
	if not warp_drive:
		warp_drive = _find_node_by_class("WarpDrive")

func _find_node_by_class(class_name_str: String) -> Node:
	"""Find a node by its class name in the scene tree."""
	var root: Node = get_tree().current_scene
	return _find_node_recursive(root, class_name_str)

func _find_node_recursive(node: Node, class_name_str: String) -> Node:
	if node.get_class() == class_name_str:
		return node
	# Check script class_name
	var script: Script = node.get_script()
	if script and script.get_global_name() == class_name_str:
		return node
	for child in node.get_children():
		var result: Node = _find_node_recursive(child, class_name_str)
		if result:
			return result
	return null

func _register_child_subsystems() -> void:
	"""Register all child nodes that extend SubsystemBase."""
	for child in get_children():
		if child is SubsystemBase:
			register_subsystem(child)

# =============================================================================
# SUBSYSTEM MANAGEMENT
# =============================================================================

func register_subsystem(subsystem: SubsystemBase) -> void:
	"""Register a subsystem with the core."""
	var sys_name: String = subsystem.name.to_lower().replace("system", "")
	_subsystems[sys_name] = subsystem
	subsystem.initialize(self)
	emit_signal("subsystem_registered", sys_name)
	print("[STARSHIP CORE] Registered subsystem: %s" % sys_name)

func get_subsystem(name: String) -> SubsystemBase:
	"""Get a subsystem by name."""
	return _subsystems.get(name.to_lower(), null)

func has_subsystem(name: String) -> bool:
	"""Check if a subsystem is registered."""
	return name.to_lower() in _subsystems

func get_all_subsystem_names() -> Array:
	"""Get list of all registered subsystem names."""
	return _subsystems.keys()

# =============================================================================
# COMMAND ROUTING
# =============================================================================

func route_command(cmd: Dictionary) -> Dictionary:
	"""Route a command to the appropriate subsystem.

	Args:
		cmd: Command dictionary with 'department', 'intent', and parameters

	Returns:
		Result dictionary with 'success', 'message', and optional 'data'
	"""
	var department: String = str(cmd.get("department", "")).to_lower()
	var intent: String = str(cmd.get("intent", ""))

	# Handle core-level commands first
	var core_result: Dictionary = _handle_core_command(intent, cmd)
	if not core_result.is_empty():
		emit_signal("command_executed", "core", intent, core_result)
		return core_result

	# Map department names to subsystem names
	var subsystem_name: String = _map_department_to_subsystem(department)

	# Validate subsystem exists
	if subsystem_name.is_empty():
		return {
			"success": false,
			"message": "Unknown department: %s" % department,
			"data": {}
		}

	var subsystem: SubsystemBase = _subsystems.get(subsystem_name, null)
	if not subsystem:
		return {
			"success": false,
			"message": "Subsystem not available: %s" % subsystem_name,
			"data": {}
		}

	# Log and execute
	print("[STARSHIP CORE] Routing '%s' to %s" % [intent, subsystem_name])
	var result: Dictionary = subsystem.execute_command(cmd)

	emit_signal("command_executed", subsystem_name, intent, result)
	return result

func _map_department_to_subsystem(department: String) -> String:
	"""Map department names to subsystem names."""
	var mapping: Dictionary = {
		# Helm
		"helm": "helm",
		"navigation": "helm",
		"conn": "helm",
		"flight": "helm",
		# Tactical
		"tactical": "tactical",
		"weapons": "tactical",
		"security": "tactical",
		"shields": "tactical",
		# Engineering
		"engineering": "engineering",
		"engine": "engineering",
		"power": "engineering",
		# Operations
		"operations": "ops",
		"ops": "ops",
		"science": "ops",
		"sensors": "ops",
		"communications": "ops",
		"comms": "ops"
	}
	return mapping.get(department.to_lower(), department.to_lower())

func _handle_core_command(intent: String, cmd: Dictionary) -> Dictionary:
	"""Handle commands that are processed at the core level."""
	match intent:
		"red_alert":
			return _set_alert(AlertLevel.RED, cmd)
		"yellow_alert":
			return _set_alert(AlertLevel.YELLOW, cmd)
		"green_alert", "stand_down", "cancel_alert":
			return _set_alert(AlertLevel.GREEN, cmd)
		"status", "status_report":
			return _get_full_status()
		"damage_report":
			# Route to engineering
			var eng: SubsystemBase = _subsystems.get("engineering", null)
			if eng:
				return eng.execute_command(cmd)
			return {"success": false, "message": "Engineering offline", "data": {}}
		_:
			return {}  # Not a core command

func _set_alert(level: int, _cmd: Dictionary) -> Dictionary:
	"""Set the ship's alert state."""
	var old_level: int = _alert_level
	_alert_level = level

	# Notify all subsystems
	for subsystem in _subsystems.values():
		subsystem.on_alert_changed(level)

	emit_signal("alert_changed", level)

	# Handle red alert sound
	if level == AlertLevel.RED and old_level != AlertLevel.RED:
		# Just entered red alert - play the klaxon
		_play_red_alert_sound()
	elif level != AlertLevel.RED and old_level == AlertLevel.RED:
		# Leaving red alert - stop the klaxon if playing
		_stop_red_alert_sound()

	var message: String = "%s alert" % ALERT_NAMES[level]
	if level == AlertLevel.RED:
		message = "Red alert! All hands to battle stations!"
	elif level == AlertLevel.YELLOW:
		message = "Yellow alert. Increased readiness."
	else:
		message = "Standing down from alert status."

	return {
		"success": true,
		"message": message,
		"data": {
			"previous_level": old_level,
			"current_level": level,
			"level_name": ALERT_NAMES[level]
		}
	}

func _get_full_status() -> Dictionary:
	"""Get complete ship status from all subsystems."""
	var subsystem_status: Dictionary = {}
	for name in _subsystems:
		subsystem_status[name] = _subsystems[name].get_status()

	return {
		"success": true,
		"message": "Ship status report",
		"data": {
			"alert_level": _alert_level,
			"alert_name": ALERT_NAMES[_alert_level],
			"power_distribution": _power_system.get_power_distribution(),
			"subsystems": subsystem_status
		}
	}

# =============================================================================
# ALERT STATE
# =============================================================================

func set_alert_state(level: int) -> bool:
	"""Set the ship's alert level."""
	if level < AlertLevel.GREEN or level > AlertLevel.RED:
		return false

	var result: Dictionary = _set_alert(level, {})
	return result.success

func get_alert_state() -> int:
	"""Get current alert level."""
	return _alert_level

func get_alert_name() -> String:
	"""Get current alert level as string."""
	return ALERT_NAMES.get(_alert_level, "Unknown")

# =============================================================================
# POWER MANAGEMENT
# =============================================================================

func get_power_distribution() -> Dictionary:
	"""Get current power distribution."""
	return _power_system.get_power_distribution()

func set_power_distribution(distribution: Dictionary) -> bool:
	"""Set power distribution."""
	var success: bool = _power_system.set_power_distribution(distribution)
	if success:
		_notify_power_changed()
	return success

func modify_power(subsystem: String, delta: float) -> bool:
	"""Modify power for a subsystem."""
	var success: bool = _power_system.modify_power(subsystem, delta)
	if success:
		_notify_power_changed()
	return success

func apply_power_preset(preset_name: String) -> bool:
	"""Apply a power preset."""
	var success: bool = _power_system.apply_preset(preset_name)
	if success:
		_notify_power_changed()
	return success

func _notify_power_changed() -> void:
	"""Notify all subsystems of power change."""
	var distribution: Dictionary = _power_system.get_power_distribution()
	for subsystem in _subsystems.values():
		subsystem.on_power_changed(distribution)
	emit_signal("power_changed", distribution)

# =============================================================================
# FULL STATUS
# =============================================================================

func get_full_status() -> Dictionary:
	"""Get complete ship status."""
	return _get_full_status().data
