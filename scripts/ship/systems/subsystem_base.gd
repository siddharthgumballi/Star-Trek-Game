extends Node
class_name SubsystemBase
## Base class for all starship subsystems with standard interface

signal status_changed(subsystem_name: String, status: Dictionary)
signal action_logged(subsystem_name: String, action: String, details: Dictionary)
signal command_result(success: bool, message: String, data: Dictionary)

# Reference to the central coordinator
var _core: Node = null
var _subsystem_name: String = "unknown"
var _enabled: bool = true

# =============================================================================
# INITIALIZATION
# =============================================================================

func initialize(core: Node) -> void:
	"""Called by StarshipCore when registering this subsystem."""
	_core = core
	_subsystem_name = name.to_lower().replace("system", "")
	_on_initialized()

func _on_initialized() -> void:
	"""Override in subclasses for custom initialization."""
	pass

# =============================================================================
# COMMAND INTERFACE
# =============================================================================

func execute_command(cmd: Dictionary) -> Dictionary:
	"""Execute a command and return result dictionary.

	Args:
		cmd: Command dictionary with 'intent' and optional parameters

	Returns:
		Dictionary with 'success', 'message', and optional 'data'
	"""
	if not _enabled:
		return _result(false, "%s system is offline" % _subsystem_name.capitalize())

	var intent: String = str(cmd.get("intent", ""))
	return _handle_command(intent, cmd)

func _handle_command(intent: String, cmd: Dictionary) -> Dictionary:
	"""Override in subclasses to handle specific intents."""
	return _result(false, "Unknown command: %s" % intent)

# =============================================================================
# STATUS INTERFACE
# =============================================================================

func get_status() -> Dictionary:
	"""Return current status of this subsystem."""
	return {
		"name": _subsystem_name,
		"enabled": _enabled,
		"online": _enabled
	}

func set_enabled(enabled: bool) -> void:
	"""Enable or disable this subsystem."""
	_enabled = enabled
	emit_signal("status_changed", _subsystem_name, get_status())

# =============================================================================
# EVENT HANDLERS
# =============================================================================

func on_alert_changed(level: int) -> void:
	"""Called when ship alert level changes."""
	pass

func on_power_changed(power_distribution: Dictionary) -> void:
	"""Called when power distribution changes."""
	pass

# =============================================================================
# UTILITIES
# =============================================================================

func _result(success: bool, message: String, data: Dictionary = {}) -> Dictionary:
	"""Create a standardized result dictionary."""
	return {
		"success": success,
		"message": message,
		"data": data,
		"subsystem": _subsystem_name
	}

func _log_action(action: String, details: Dictionary = {}) -> void:
	"""Log an action for this subsystem."""
	emit_signal("action_logged", _subsystem_name, action, details)
	print("[%s] %s" % [_subsystem_name.to_upper(), action])

func get_core() -> Node:
	"""Get reference to the StarshipCore."""
	return _core
