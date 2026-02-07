extends Node
class_name BridgeCommandHandler
## Handles incoming Bridge AI commands and routes them through StarshipCore
## Falls back to direct HUD control if core is unavailable

@export var ship_path: NodePath
@export var warp_drive_path: NodePath
@export var hud_path: NodePath
@export var starship_core_path: NodePath

var ship: Node3D
var warp_drive: Node3D
var hud: Control  # LCARSHUD
var receiver: Node  # BridgeAIReceiver
var starship_core: Node  # StarshipCore

# Memory for contextual commands (fallback mode)
var last_destination: String = ""
var last_warp_factor: float = 5.0

func _ready() -> void:
	# Get references with null safety
	ship = get_node_or_null(ship_path) if ship_path else null
	warp_drive = get_node_or_null(warp_drive_path) if warp_drive_path else null
	hud = get_node_or_null(hud_path) if hud_path else null
	starship_core = get_node_or_null(starship_core_path) if starship_core_path else null

	# Fallback: find StarshipCore in scene tree
	if not starship_core:
		starship_core = _find_starship_core()

	# Connect to BridgeAIReceiver
	receiver = get_node_or_null("../BridgeAIReceiver")
	if receiver:
		receiver.command_received.connect(_on_command_received)
		print("[BRIDGE HANDLER] Connected to BridgeAIReceiver")
		if starship_core:
			print("[BRIDGE HANDLER] StarshipCore connected - using modular routing")
		elif hud:
			print("[BRIDGE HANDLER] HUD connected - using direct autopilot (fallback)")
		else:
			push_warning("[BRIDGE HANDLER] No routing available - voice commands may not work")
	else:
		push_warning("BridgeCommandHandler: Could not find BridgeAIReceiver")

func _find_starship_core() -> Node:
	"""Find StarshipCore in the scene tree."""
	var root: Node = get_tree().current_scene
	return _find_node_recursive(root, "StarshipCore")

func _find_node_recursive(node: Node, class_name_str: String) -> Node:
	var script: Script = node.get_script()
	if script and script.get_global_name() == class_name_str:
		return node
	for child in node.get_children():
		var result: Node = _find_node_recursive(child, class_name_str)
		if result:
			return result
	return null

func _on_command_received(cmd: Dictionary) -> void:
	if not cmd:
		_send_response(false, "Invalid command received")
		return

	var intent: String = str(cmd.get("intent", ""))
	var department: String = str(cmd.get("department", "helm"))

	print("[BRIDGE HANDLER] Received: ", intent, " from ", department)

	# Route through StarshipCore if available
	if starship_core and starship_core.has_method("route_command"):
		var result: Dictionary = starship_core.route_command(cmd)
		var success: bool = result.get("success", false)
		var message: String = result.get("message", "Command processed")
		_send_response(success, message)
		if success and hud and hud.has_method("show_computer_message"):
			hud.show_computer_message(message)
		return

	# Fallback: Route command based on intent (legacy mode)
	print("[BRIDGE HANDLER] Using fallback routing (no StarshipCore)")
	match intent:
		"impulse":
			_handle_impulse(cmd)
		"warp":
			_handle_warp(cmd)
		"stop":
			_handle_stop()
		"navigate":
			_handle_navigate(cmd)
		"navigate_coordinates":
			_handle_navigate_coordinates(cmd)
		"raise_shields":
			_handle_shields(true)
		"lower_shields":
			_handle_shields(false)
		"turn":
			_handle_turn(cmd)
		"orbit":
			_handle_orbit(cmd)
		"disengage":
			_handle_disengage()
		"status":
			_handle_status()
		"red_alert":
			_handle_alert("red")
		"yellow_alert":
			_handle_alert("yellow")
		"green_alert", "stand_down", "cancel_alert":
			_handle_alert("green")
		"damage_report":
			_handle_damage_report()
		"scan", "scan_target":
			_handle_scan(cmd)
		"":
			_send_response(false, "No command intent specified")
		_:
			print("[BRIDGE HANDLER] Unknown intent: ", intent)
			_send_response(false, "Unknown command: " + intent)

func _handle_impulse(cmd: Dictionary) -> void:
	var percent = cmd.get("impulse_percent")
	if percent == null:
		percent = 100

	# Safely convert to int
	if percent is String:
		percent = int(percent) if percent.is_valid_int() else 100
	else:
		percent = int(percent)

	if not hud:
		_send_response(false, "HUD not available")
		return

	if hud.has_method("set_impulse_voice"):
		var result: Dictionary = hud.set_impulse_voice(percent)
		_send_response(result.get("success", false), result.get("message", "Command failed"))
		if result.get("success", false) and hud.has_method("show_computer_message"):
			hud.show_computer_message(result.get("message", ""))
	else:
		_send_response(false, "Impulse control not available")

func _handle_warp(cmd: Dictionary) -> void:
	var factor = cmd.get("warp_factor")
	var target = cmd.get("target")

	# Convert target to string safely
	var target_str: String = str(target) if target != null else ""

	if target_str and not target_str.is_empty() and target_str != "null":
		# Full navigation command - delegate to navigate handler
		_handle_navigate(cmd)
	else:
		# Just engage warp at factor (no destination) - not supported via autopilot
		_send_response(false, "Please specify a destination. Say 'Set course for [planet], warp [factor]'")

func _handle_stop() -> void:
	if not hud:
		_send_response(false, "HUD not available")
		return

	if hud.has_method("all_stop_voice"):
		var result: Dictionary = hud.all_stop_voice()
		_send_response(result.get("success", false), result.get("message", "Command failed"))
		if result.get("success", false) and hud.has_method("show_computer_message"):
			hud.show_computer_message(result.get("message", ""))
	else:
		_send_response(false, "Stop control not available")

func _handle_navigate(cmd: Dictionary) -> void:
	var target = cmd.get("target")
	var warp_factor = cmd.get("warp_factor")

	# Convert target to string safely
	var target_str: String = str(target) if target != null else ""

	# Handle contextual commands
	if target_str.is_empty() or target_str == "null":
		if last_destination.is_empty():
			_send_response(false, "No destination specified")
			return
		target_str = last_destination

	# Handle warp factor with null safety
	var warp_float: float = last_warp_factor
	if warp_factor != null:
		if warp_factor is String:
			warp_float = float(warp_factor) if warp_factor.is_valid_float() else last_warp_factor
		else:
			warp_float = float(warp_factor)

	if not hud:
		_send_response(false, "HUD not available")
		return

	if hud.has_method("engage_autopilot_voice"):
		var result: Dictionary = hud.engage_autopilot_voice(target_str, warp_float)
		_send_response(result.get("success", false), result.get("message", "Command failed"))
		if result.get("success", false) and hud.has_method("show_computer_message"):
			hud.show_computer_message(result.get("message", ""))
			# Remember for contextual commands
			last_destination = target_str
			last_warp_factor = warp_float
	else:
		_send_response(false, "Navigation not available")

func _handle_navigate_coordinates(cmd: Dictionary) -> void:
	var x = cmd.get("x", 0)
	var y = cmd.get("y", 0)
	var z = cmd.get("z", 0)
	var warp_factor = cmd.get("warp_factor", last_warp_factor)

	# Safely convert coordinates
	var x_float: float = float(x) if x != null else 0.0
	var y_float: float = float(y) if y != null else 0.0
	var z_float: float = float(z) if z != null else 0.0
	var warp_float: float = float(warp_factor) if warp_factor != null else last_warp_factor

	if not hud:
		_send_response(false, "HUD not available")
		return

	if hud.has_method("engage_autopilot_coordinates"):
		var result: Dictionary = hud.engage_autopilot_coordinates(x_float, y_float, z_float, warp_float)
		_send_response(result.get("success", false), result.get("message", "Command failed"))
		if result.get("success", false) and hud.has_method("show_computer_message"):
			hud.show_computer_message(result.get("message", ""))
			last_warp_factor = warp_float
	else:
		_send_response(false, "Coordinate navigation not available")

func _handle_shields(raise: bool) -> void:
	var action: String = "raised" if raise else "lowered"
	print("[BRIDGE HANDLER] Shields ", action)
	_send_response(true, "Shields " + action)
	if hud and hud.has_method("show_computer_message"):
		hud.show_computer_message("Shields " + action)
	# TODO: Implement shields system

func _handle_turn(cmd: Dictionary) -> void:
	var maneuver = cmd.get("maneuver")
	var maneuver_str: String = str(maneuver) if maneuver != null else "standard turn"
	print("[BRIDGE HANDLER] Turn maneuver: ", maneuver_str)
	_send_response(true, "Executing " + maneuver_str)
	if hud and hud.has_method("show_computer_message"):
		hud.show_computer_message("Executing " + maneuver_str)
	# TODO: Implement turn maneuvers

func _handle_orbit(cmd: Dictionary) -> void:
	var target = cmd.get("target")
	var target_str: String = str(target) if target != null else ""

	if target_str.is_empty() or target_str == "null":
		_send_response(false, "No orbit target specified")
		return

	# TODO: Implement orbit via HUD
	_send_response(true, "Entering orbit around " + target_str)
	if hud and hud.has_method("show_computer_message"):
		hud.show_computer_message("Entering orbit around " + target_str)

func _handle_disengage() -> void:
	if not hud:
		_send_response(false, "HUD not available")
		return

	# Use all_stop_voice which handles disengaging autopilot
	if hud.has_method("all_stop_voice"):
		var result: Dictionary = hud.all_stop_voice()
		_send_response(result.get("success", false), result.get("message", "Command failed"))
		if result.get("success", false) and hud.has_method("show_computer_message"):
			hud.show_computer_message(result.get("message", ""))
	else:
		_send_response(false, "Disengage not available")

func _handle_status() -> void:
	# Report current ship status
	var status_msg: String = "Ship status: "
	if warp_drive and warp_drive.is_at_warp:
		status_msg += "At warp " + str(warp_drive.get_warp_factor()) + ". "
	elif ship and ship.current_impulse > 1:  # > STOP
		status_msg += "At impulse. "
	else:
		status_msg += "All stop. "

	_send_response(true, status_msg)
	if hud and hud.has_method("show_computer_message"):
		hud.show_computer_message(status_msg)

func _handle_alert(level: String) -> void:
	# Fallback alert handling when StarshipCore is not available
	var message: String
	match level:
		"red":
			message = "Red alert! All hands to battle stations!"
		"yellow":
			message = "Yellow alert. Increased readiness."
		_:
			message = "Standing down from alert status."

	print("[BRIDGE HANDLER] Alert: ", level)
	_send_response(true, message)
	if hud and hud.has_method("show_computer_message"):
		hud.show_computer_message(message)

func _handle_damage_report() -> void:
	# Fallback damage report when StarshipCore is not available
	var message: String = "All systems operational."
	_send_response(true, message)
	if hud and hud.has_method("show_computer_message"):
		hud.show_computer_message(message)

func _handle_scan(cmd: Dictionary) -> void:
	# Fallback scan handling when StarshipCore is not available
	var target = cmd.get("target")
	var target_str: String = str(target) if target != null else ""

	if target_str.is_empty() or target_str == "null":
		_send_response(false, "No scan target specified")
		return

	var message: String = "Scanning %s. Analysis in progress." % target_str
	_send_response(true, message)
	if hud and hud.has_method("show_computer_message"):
		hud.show_computer_message(message)

# =============================================================================
# RESPONSE HANDLING
# =============================================================================

func _send_response(success: bool, message: String) -> void:
	"""Send response back to Bridge AI via TCP."""
	var safe_message: String = message if message else "Unknown response"
	if receiver and receiver.has_method("_send_acknowledgment"):
		receiver._send_acknowledgment(success, safe_message)
