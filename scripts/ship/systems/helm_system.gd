extends SubsystemBase
class_name HelmSystem
## Helm subsystem - wraps existing ShipController and WarpDrive
## Delegates navigation commands to HUD autopilot system

# =============================================================================
# STATE
# =============================================================================

var _ship_controller: Node3D = null
var _warp_drive: Node3D = null
var _hud: Control = null

# Memory for contextual commands
var last_destination: String = ""
var last_warp_factor: float = 5.0

# =============================================================================
# INITIALIZATION
# =============================================================================

func _on_initialized() -> void:
	_subsystem_name = "helm"

	# Get references from core
	if _core:
		_ship_controller = _core.ship_controller
		_warp_drive = _core.warp_drive
		_hud = _core.hud

	# Fallback: find in scene tree
	if not _ship_controller:
		_ship_controller = _find_node_by_script("ShipController")
	if not _warp_drive:
		_warp_drive = _find_node_by_script("WarpDrive")

	_log_action("Helm system online")

func _find_node_by_script(script_name: String) -> Node:
	"""Find node by script class name."""
	var root: Node = get_tree().current_scene
	return _find_recursive(root, script_name)

func _find_recursive(node: Node, script_name: String) -> Node:
	var script: Script = node.get_script()
	if script and script.get_global_name() == script_name:
		return node
	for child in node.get_children():
		var result: Node = _find_recursive(child, script_name)
		if result:
			return result
	return null

# =============================================================================
# COMMAND HANDLING
# =============================================================================

func _handle_command(intent: String, cmd: Dictionary) -> Dictionary:
	match intent:
		"impulse":
			return _handle_impulse(cmd)
		"navigate", "warp":
			return _handle_navigate(cmd)
		"navigate_coordinates":
			return _handle_navigate_coordinates(cmd)
		"stop":
			return _handle_stop()
		"turn":
			return _handle_turn(cmd)
		"orbit":
			return _handle_orbit(cmd)
		"disengage":
			return _handle_disengage()
		"evasive":
			return _handle_evasive(cmd)
		"reverse":
			return _handle_reverse()
		"dock":
			return _handle_dock(cmd)
		"land":
			return _handle_land(cmd)
		_:
			return _result(false, "Unknown helm command: %s" % intent)

# =============================================================================
# IMPULSE CONTROL
# =============================================================================

func _handle_impulse(cmd: Dictionary) -> Dictionary:
	var percent = cmd.get("impulse_percent")
	if percent == null:
		percent = 100

	# Safely convert to int
	if percent is String:
		percent = int(percent) if percent.is_valid_int() else 100
	else:
		percent = int(percent)

	if not _hud:
		return _result(false, "Navigation system not available")

	if _hud.has_method("set_impulse_voice"):
		var result: Dictionary = _hud.set_impulse_voice(percent)
		_log_action("Set impulse to %d%%" % percent)
		if result.get("success", false) and _hud.has_method("show_computer_message"):
			_hud.show_computer_message(result.get("message", ""))
		return _result(result.get("success", false), result.get("message", "Command failed"))
	else:
		return _result(false, "Impulse control not available")

# =============================================================================
# NAVIGATION
# =============================================================================

func _handle_navigate(cmd: Dictionary) -> Dictionary:
	var target = cmd.get("target")
	var warp_factor = cmd.get("warp_factor")

	# Convert target to string safely
	var target_str: String = str(target) if target != null else ""

	# Handle contextual commands
	if target_str.is_empty() or target_str == "null":
		if last_destination.is_empty():
			return _result(false, "No destination specified")
		target_str = last_destination

	# Handle warp factor with null safety
	var warp_float: float = last_warp_factor
	if warp_factor != null:
		if warp_factor is String:
			warp_float = float(warp_factor) if warp_factor.is_valid_float() else last_warp_factor
		else:
			warp_float = float(warp_factor)

	if not _hud:
		return _result(false, "Navigation system not available")

	if _hud.has_method("engage_autopilot_voice"):
		var result: Dictionary = _hud.engage_autopilot_voice(target_str, warp_float)
		if result.get("success", false):
			_log_action("Set course for %s at warp %s" % [target_str, warp_float])
			if _hud.has_method("show_computer_message"):
				_hud.show_computer_message(result.get("message", ""))
			# Remember for contextual commands
			last_destination = target_str
			last_warp_factor = warp_float
		return _result(result.get("success", false), result.get("message", "Command failed"))
	else:
		return _result(false, "Navigation not available")

func _handle_navigate_coordinates(cmd: Dictionary) -> Dictionary:
	var x = cmd.get("x", 0)
	var y = cmd.get("y", 0)
	var z = cmd.get("z", 0)
	var warp_factor = cmd.get("warp_factor", last_warp_factor)

	# Safely convert coordinates
	var x_float: float = float(x) if x != null else 0.0
	var y_float: float = float(y) if y != null else 0.0
	var z_float: float = float(z) if z != null else 0.0
	var warp_float: float = float(warp_factor) if warp_factor != null else last_warp_factor

	if not _hud:
		return _result(false, "Navigation system not available")

	if _hud.has_method("engage_autopilot_coordinates"):
		var result: Dictionary = _hud.engage_autopilot_coordinates(x_float, y_float, z_float, warp_float)
		if result.get("success", false):
			_log_action("Set course for coordinates (%.0f, %.0f, %.0f)" % [x_float, y_float, z_float])
			if _hud.has_method("show_computer_message"):
				_hud.show_computer_message(result.get("message", ""))
			last_warp_factor = warp_float
		return _result(result.get("success", false), result.get("message", "Command failed"))
	else:
		return _result(false, "Coordinate navigation not available")

# =============================================================================
# STOP / DISENGAGE
# =============================================================================

func _handle_stop() -> Dictionary:
	if not _hud:
		return _result(false, "Navigation system not available")

	if _hud.has_method("all_stop_voice"):
		var result: Dictionary = _hud.all_stop_voice()
		_log_action("All stop")
		if result.get("success", false) and _hud.has_method("show_computer_message"):
			_hud.show_computer_message(result.get("message", ""))
		return _result(result.get("success", false), result.get("message", "Command failed"))
	else:
		return _result(false, "Stop control not available")

func _handle_disengage() -> Dictionary:
	if not _hud:
		return _result(false, "Navigation system not available")

	# Use all_stop_voice which handles disengaging autopilot
	if _hud.has_method("all_stop_voice"):
		var result: Dictionary = _hud.all_stop_voice()
		_log_action("Disengaged autopilot")
		if result.get("success", false) and _hud.has_method("show_computer_message"):
			_hud.show_computer_message(result.get("message", ""))
		return _result(result.get("success", false), result.get("message", "Command failed"))
	else:
		return _result(false, "Disengage not available")

# =============================================================================
# MANEUVERS
# =============================================================================

func _handle_turn(cmd: Dictionary) -> Dictionary:
	var maneuver = cmd.get("maneuver")
	var maneuver_str: String = str(maneuver) if maneuver != null else "standard turn"
	_log_action("Executing maneuver: %s" % maneuver_str)

	if _hud and _hud.has_method("show_computer_message"):
		_hud.show_computer_message("Executing %s" % maneuver_str)

	# TODO: Implement actual turn maneuvers via ship controller
	return _result(true, "Executing %s" % maneuver_str)

func _handle_orbit(cmd: Dictionary) -> Dictionary:
	var target = cmd.get("target")
	var target_str: String = str(target) if target != null else ""

	if target_str.is_empty() or target_str == "null":
		# Standard orbit (use nearest body or last destination)
		if not last_destination.is_empty():
			target_str = last_destination
		else:
			_log_action("Standard orbit engaged")
			if _hud and _hud.has_method("show_computer_message"):
				_hud.show_computer_message("Standard orbit engaged")
			return _result(true, "Standard orbit engaged")

	_log_action("Entering orbit around %s" % target_str)

	if _hud and _hud.has_method("show_computer_message"):
		_hud.show_computer_message("Entering orbit around %s" % target_str)

	# TODO: Implement orbit via autopilot
	return _result(true, "Entering orbit around %s" % target_str)

# =============================================================================
# EVASIVE MANEUVERS
# =============================================================================

func _handle_evasive(cmd: Dictionary) -> Dictionary:
	var maneuver = cmd.get("maneuver")
	var maneuver_str: String = str(maneuver) if maneuver != null else ""

	var message: String
	if maneuver_str.is_empty() or maneuver_str == "null":
		message = "Evasive maneuvers!"
	else:
		message = "Evasive pattern %s!" % maneuver_str.capitalize()

	_log_action(message)

	if _hud and _hud.has_method("show_computer_message"):
		_hud.show_computer_message(message)

	# TODO: Implement actual evasive maneuver patterns
	return _result(true, message, {"maneuver": maneuver_str})

# =============================================================================
# REVERSE
# =============================================================================

func _handle_reverse() -> Dictionary:
	_log_action("Reverse engines")

	if _hud and _hud.has_method("show_computer_message"):
		_hud.show_computer_message("Reversing course")

	# Set impulse to reverse
	if _ship_controller:
		_ship_controller.current_impulse = 0  # REVERSE level
		return _result(true, "Reverse engines engaged")

	return _result(true, "Reverse engines")

# =============================================================================
# DOCK
# =============================================================================

func _handle_dock(cmd: Dictionary) -> Dictionary:
	var target = cmd.get("target")
	var target_str: String = str(target) if target != null else "Starbase 1"

	if target_str == "null":
		target_str = "Starbase 1"

	_log_action("Initiating docking procedure with %s" % target_str)

	if _hud and _hud.has_method("show_computer_message"):
		_hud.show_computer_message("Initiating docking procedure with %s" % target_str)

	# TODO: Implement actual docking sequence
	return _result(true, "Initiating docking with %s" % target_str, {"target": target_str})

# =============================================================================
# LAND
# =============================================================================

func _handle_land(cmd: Dictionary) -> Dictionary:
	var target = cmd.get("target")
	var target_str: String = str(target) if target != null else ""

	if target_str.is_empty() or target_str == "null":
		return _result(false, "No landing target specified")

	_log_action("Initiating landing sequence on %s" % target_str)

	if _hud and _hud.has_method("show_computer_message"):
		_hud.show_computer_message("Initiating landing on %s" % target_str)

	# TODO: Implement actual landing sequence
	return _result(true, "Initiating landing on %s" % target_str, {"target": target_str})

# =============================================================================
# STATUS
# =============================================================================

func get_status() -> Dictionary:
	var base_status: Dictionary = super.get_status()

	# Add helm-specific status
	var warp_status: String = "Impulse"
	var current_speed: String = "All Stop"

	if _warp_drive and _warp_drive.get("is_at_warp"):
		warp_status = "Warp %s" % str(_warp_drive.get_warp_factor())
		current_speed = warp_status
	elif _ship_controller:
		if _ship_controller.has_method("get_impulse_name"):
			current_speed = _ship_controller.get_impulse_name()

	base_status["warp_status"] = warp_status
	base_status["current_speed"] = current_speed
	base_status["last_destination"] = last_destination

	return base_status
