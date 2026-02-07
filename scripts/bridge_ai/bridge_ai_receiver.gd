extends Node
class_name BridgeAIReceiver
## =============================================================================
## BRIDGE AI TCP RECEIVER
## =============================================================================
##
## This script receives voice commands from the Bridge AI Python system.
## It listens on a TCP port and parses incoming JSON commands.
##
## SETUP:
##   1. Add this script to a Node in your scene
##   2. The node will automatically start listening when the scene loads
##   3. Run the Python bridge_ai.py script to send voice commands
##
## SIGNALS:
##   command_received(command: Dictionary) - Emitted when a valid command arrives
##
## USAGE:
##   var receiver = $BridgeAIReceiver
##   receiver.command_received.connect(_on_bridge_command)
##
##   func _on_bridge_command(cmd: Dictionary):
##       match cmd.intent:
##           "warp": engage_warp(cmd.warp_factor)
##           "navigate": set_course(cmd.target)
## =============================================================================

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when a valid command is received from the Bridge AI
signal command_received(command: Dictionary)

## Emitted when the connection status changes
signal connection_status_changed(connected: bool)

# =============================================================================
# CONFIGURATION
# =============================================================================

## Port to listen on (must match bridge_ai.py)
@export var listen_port: int = 5005

## Enable debug printing
@export var debug_mode: bool = true

# =============================================================================
# INTERNAL STATE
# =============================================================================

var _server: TCPServer
var _client: StreamPeerTCP
var _is_client_connected: bool = false

# Buffer for incomplete messages
var _receive_buffer: String = ""

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_start_server()

	print("=" .repeat(60))
	print("BRIDGE AI RECEIVER - Initialized")
	print("  Listening on port: ", listen_port)
	print("=" .repeat(60))


func _exit_tree() -> void:
	_stop_server()


func _process(_delta: float) -> void:
	_check_for_connections()
	_receive_data()

# =============================================================================
# SERVER MANAGEMENT
# =============================================================================

func _start_server() -> void:
	"""Start the TCP server and begin listening for connections."""
	_server = TCPServer.new()

	var error: Error = _server.listen(listen_port)

	if error != OK:
		push_error("BridgeAI: Failed to start TCP server on port %d: %s" % [listen_port, error])
		return

	if debug_mode:
		print("[BRIDGE AI] TCP Server started on port ", listen_port)


func _stop_server() -> void:
	"""Stop the TCP server and disconnect any clients."""
	if _client and _is_client_connected:
		_client.disconnect_from_host()
		_is_client_connected = false

	if _server:
		_server.stop()

	if debug_mode:
		print("[BRIDGE AI] TCP Server stopped")


func _check_for_connections() -> void:
	"""Check for new incoming connections."""
	if not _server or not _server.is_listening():
		return

	# Check if a new client is trying to connect
	if _server.is_connection_available():
		# Accept the new connection
		var new_client: StreamPeerTCP = _server.take_connection()

		if new_client:
			# Disconnect old client if exists
			if _client and _is_client_connected:
				_client.disconnect_from_host()

			_client = new_client
			_is_client_connected = true
			_receive_buffer = ""

			if debug_mode:
				print("[BRIDGE AI] Client connected from: ",
					_client.get_connected_host(), ":", _client.get_connected_port())

			emit_signal("connection_status_changed", true)


func _receive_data() -> void:
	"""Check for and process incoming data from the client."""
	if not _client or not _is_client_connected:
		return

	# Check connection status
	_client.poll()
	var status: StreamPeerTCP.Status = _client.get_status()

	if status == StreamPeerTCP.STATUS_ERROR or status == StreamPeerTCP.STATUS_NONE:
		if _is_client_connected:
			if debug_mode:
				print("[BRIDGE AI] Client disconnected")
			_is_client_connected = false
			emit_signal("connection_status_changed", false)
		return

	if status != StreamPeerTCP.STATUS_CONNECTED:
		return

	# Check for available data
	var available: int = _client.get_available_bytes()
	if available <= 0:
		return

	# Read available data
	var data: Array = _client.get_data(available)
	var error: int = data[0]
	var bytes: PackedByteArray = data[1]

	if error != OK:
		if debug_mode:
			print("[BRIDGE AI] Error receiving data: ", error)
		return

	# Convert to string and add to buffer
	var text: String = bytes.get_string_from_utf8()
	_receive_buffer += text

	# Process complete messages (delimited by newline)
	_process_buffer()


func _process_buffer() -> void:
	"""Process complete messages in the receive buffer."""
	# Split by newlines to get complete messages
	while true:
		var newline_pos: int = _receive_buffer.find("\n")
		if newline_pos == -1:
			break

		# Extract the complete message
		var message: String = _receive_buffer.substr(0, newline_pos).strip_edges()
		_receive_buffer = _receive_buffer.substr(newline_pos + 1)

		if message.is_empty():
			continue

		# Process the message
		_handle_message(message)

# =============================================================================
# MESSAGE HANDLING
# =============================================================================

func _handle_message(message: String) -> void:
	"""Parse and handle an incoming JSON message."""
	if debug_mode:
		print("")
		print("=" .repeat(60))
		print("[BRIDGE AI] RECEIVED COMMAND")
		print("=" .repeat(60))
		print("  Raw: ", message)

	# Parse JSON
	var json := JSON.new()
	var parse_result: Error = json.parse(message)

	if parse_result != OK:
		push_warning("BridgeAI: Failed to parse JSON: %s" % json.get_error_message())
		_send_acknowledgment(false, "Invalid JSON")
		return

	var command: Dictionary = json.data

	# Validate command structure
	if not _validate_command(command):
		_send_acknowledgment(false, "Invalid command structure")
		return

	# Print parsed command
	if debug_mode:
		print("")
		print("  PARSED COMMAND:")
		print("    Department: ", command.get("department", "unknown"))
		print("    Intent:     ", command.get("intent", "unknown"))
		print("    Target:     ", command.get("target", "null"))
		print("    Warp:       ", command.get("warp_factor", "null"))
		print("    Impulse:    ", command.get("impulse_percent", "null"))
		print("    Maneuver:   ", command.get("maneuver", "null"))
		print("")

	# Send success acknowledgment
	_send_acknowledgment(true, "Command received")

	# Emit signal for game to handle
	emit_signal("command_received", command)

	if debug_mode:
		print("[BRIDGE AI] Command dispatched to game")
		print("=" .repeat(60))


func _validate_command(command: Dictionary) -> bool:
	"""
	Validate that a command has the required structure.

	Args:
		command: The parsed JSON command

	Returns:
		True if valid, False otherwise
	"""
	# Required fields
	if not command.has("department"):
		if debug_mode:
			print("  [INVALID] Missing 'department' field")
		return false

	if not command.has("intent"):
		if debug_mode:
			print("  [INVALID] Missing 'intent' field")
		return false

	# Valid departments
	var valid_departments: Array[String] = ["helm", "tactical", "engineering", "ops"]
	if command.department not in valid_departments:
		if debug_mode:
			print("  [INVALID] Unknown department: ", command.department)
		return false

	# Valid intents
	var valid_intents: Array[String] = [
		"navigate", "warp", "impulse", "stop", "turn",
		"raise_shields", "lower_shields"
	]
	if command.intent not in valid_intents:
		if debug_mode:
			print("  [INVALID] Unknown intent: ", command.intent)
		return false

	# Validate warp factor if present
	if command.has("warp_factor") and command.warp_factor != null:
		var wf = command.warp_factor
		if typeof(wf) != TYPE_FLOAT and typeof(wf) != TYPE_INT:
			if debug_mode:
				print("  [INVALID] warp_factor must be a number")
			return false
		if wf <= 0 or wf >= 10:
			if debug_mode:
				print("  [INVALID] warp_factor must be between 0 and 10")
			return false

	# Validate impulse percent if present
	if command.has("impulse_percent") and command.impulse_percent != null:
		var ip = command.impulse_percent
		if typeof(ip) != TYPE_FLOAT and typeof(ip) != TYPE_INT:
			if debug_mode:
				print("  [INVALID] impulse_percent must be a number")
			return false
		if ip < 0 or ip > 100:
			if debug_mode:
				print("  [INVALID] impulse_percent must be between 0 and 100")
			return false

	return true


func _send_acknowledgment(success: bool, message: String) -> void:
	"""
	Send an acknowledgment back to the Python client.

	Args:
		success: Whether the command was accepted
		message: Status message
	"""
	if not _client or not _is_client_connected:
		return

	var ack: Dictionary = {
		"success": success,
		"message": message,
		"timestamp": Time.get_unix_time_from_system()
	}

	var json_str: String = JSON.stringify(ack) + "\n"
	var bytes: PackedByteArray = json_str.to_utf8_buffer()

	_client.put_data(bytes)

	if debug_mode:
		print("  [ACK] Sent: ", "OK" if success else "ERROR", " - ", message)

# =============================================================================
# PUBLIC API
# =============================================================================

## Check if a client is currently connected
func is_client_connected() -> bool:
	return _is_client_connected


## Get the connected client's address (or empty string if not connected)
func get_client_address() -> String:
	if _client and _is_client_connected:
		return "%s:%d" % [_client.get_connected_host(), _client.get_connected_port()]
	return ""


## Manually disconnect the current client
func disconnect_client() -> void:
	if _client and _is_client_connected:
		_client.disconnect_from_host()
		_is_client_connected = false
		emit_signal("connection_status_changed", false)
		if debug_mode:
			print("[BRIDGE AI] Client manually disconnected")
