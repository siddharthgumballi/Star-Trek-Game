extends Node
class_name KeyboardController
## Manual keyboard controls for all starship systems
## Phase 3: Complete keyboard interface for all subsystems
##
## CONTROLS:
## =========
## TACTICAL:
##   Shift+S     - Toggle shields (raise/lower)
##   F           - Fire phasers (requires target lock)
##   T           - Fire torpedoes (requires target lock)
##   Tab         - Cycle through targets
##   X           - Clear target
##
## ALERTS:
##   R           - Red alert
##   Y           - Yellow alert
##   G           - Green alert / Stand down
##
## POWER PRESETS:
##   1           - Balanced power (25/25/25/25)
##   2           - Combat power (shields/weapons)
##   3           - Evasive power (engines)
##   4           - Science power (sensors)
##
## POWER ADJUSTMENT:
##   Shift+1     - Boost engines (+10%)
##   Shift+2     - Boost shields (+10%)
##   Shift+3     - Boost weapons (+10%)
##   Shift+4     - Boost sensors (+10%)
##
## HELM:
##   V           - Evasive maneuvers (V for eVasive)
##   B           - Reverse engines
##   O           - Standard orbit (already mapped)
##
## OPS:
##   N           - Long range scan
##   P           - Status rePort
##
## ALREADY MAPPED (in other scripts):
##   E/Q         - Impulse up/down
##   W/S         - Pitch up/down
##   A/D         - Yaw left/right
##   Z/C         - Roll left/right
##   Space       - Full stop
##   Shift+W     - Engage/disengage warp
##   +/-         - Warp factor up/down
##   Shift+D     - Dock
##   F1-F4       - Camera modes
##   M           - Map
##   F3          - Debug overlay

# =============================================================================
# REFERENCES
# =============================================================================

var _starship_core: Node = null
var _warp_drive: Node3D = null
var _hud: Control = null

# Target cycling
var _available_targets: Array = []
var _current_target_index: int = -1

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	_setup_input_actions()
	# Defer reference resolution to ensure scene is ready
	call_deferred("_resolve_references")
	call_deferred("_create_controls_overlay")

func _resolve_references() -> void:
	_starship_core = _find_node_by_class("StarshipCore")
	_warp_drive = _find_node_by_class("WarpDrive")
	_hud = _find_node_by_class("HUD")

	if _starship_core:
		print("[KEYBOARD] Controls initialized - connected to StarshipCore")
		print("[KEYBOARD] Press F1 for controls help")
	else:
		print("[KEYBOARD] Warning: StarshipCore not found")

func _create_controls_overlay() -> void:
	"""Create controls help overlay if not present."""
	# Check if already exists
	var existing = _find_node_by_class("ControlsOverlay")
	if existing:
		return

	var overlay_script: Script = load("res://scripts/hud/controls_overlay.gd")
	if overlay_script:
		var overlay: CanvasLayer = CanvasLayer.new()
		overlay.set_script(overlay_script)
		overlay.name = "ControlsOverlay"
		get_tree().current_scene.add_child(overlay)
		print("[KEYBOARD] Controls overlay created (F1 to toggle)")

func _find_node_by_class(class_name_str: String) -> Node:
	var root: Node = get_tree().current_scene
	return _find_recursive(root, class_name_str)

func _find_recursive(node: Node, class_name_str: String) -> Node:
	var script: Script = node.get_script()
	if script and script.get_global_name() == class_name_str:
		return node
	for child in node.get_children():
		var result: Node = _find_recursive(child, class_name_str)
		if result:
			return result
	return null

# =============================================================================
# INPUT ACTION SETUP
# =============================================================================

func _setup_input_actions() -> void:
	# Tactical
	_add_key_action("toggle_shields", KEY_S, true)  # Shift+S
	_add_key_action("fire_phasers", KEY_F)
	_add_key_action("fire_torpedoes", KEY_T)
	_add_key_action("cycle_target", KEY_TAB)
	_add_key_action("clear_target", KEY_X)

	# Alerts
	_add_key_action("red_alert", KEY_R)
	_add_key_action("yellow_alert", KEY_Y)
	_add_key_action("green_alert", KEY_G)

	# Power presets (1-4)
	_add_key_action("power_balanced", KEY_1)
	_add_key_action("power_combat", KEY_2)
	_add_key_action("power_evasive", KEY_3)
	_add_key_action("power_science", KEY_4)

	# Power boost (Shift+1-4)
	_add_key_action("boost_engines", KEY_1, true)
	_add_key_action("boost_shields", KEY_2, true)
	_add_key_action("boost_weapons", KEY_3, true)
	_add_key_action("boost_sensors", KEY_4, true)

	# Helm (V for eVasive - E is impulse, O is already orbit)
	_add_key_action("evasive_maneuvers", KEY_V)
	_add_key_action("reverse_engines", KEY_B)
	# O/orbit is already mapped in ship_controller

	# Ops (P for rePort - M is map)
	_add_key_action("long_range_scan", KEY_N)
	_add_key_action("status_report", KEY_P)

func _add_key_action(action_name: String, keycode: int, shift: bool = false, ctrl: bool = false) -> void:
	if InputMap.has_action(action_name):
		return

	InputMap.add_action(action_name)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.shift_pressed = shift
	event.ctrl_pressed = ctrl
	InputMap.action_add_event(action_name, event)

# =============================================================================
# INPUT HANDLING
# =============================================================================

func _input(event: InputEvent) -> void:
	if not _starship_core:
		return

	# Tactical
	if event.is_action_pressed("toggle_shields"):
		_toggle_shields()
	elif event.is_action_pressed("fire_phasers"):
		_fire_phasers()
	elif event.is_action_pressed("fire_torpedoes"):
		_fire_torpedoes()
	elif event.is_action_pressed("cycle_target"):
		_cycle_target()
	elif event.is_action_pressed("clear_target"):
		_clear_target()

	# Alerts
	elif event.is_action_pressed("red_alert"):
		_set_alert("red_alert")
	elif event.is_action_pressed("yellow_alert"):
		_set_alert("yellow_alert")
	elif event.is_action_pressed("green_alert"):
		_set_alert("green_alert")

	# Power presets (check shift state to differentiate from boost)
	elif event.is_action_pressed("power_balanced") and not event.is_action_pressed("boost_engines"):
		_apply_power_preset("balanced")
	elif event.is_action_pressed("power_combat") and not event.is_action_pressed("boost_shields"):
		_apply_power_preset("combat")
	elif event.is_action_pressed("power_evasive") and not event.is_action_pressed("boost_weapons"):
		_apply_power_preset("evasive")
	elif event.is_action_pressed("power_science") and not event.is_action_pressed("boost_sensors"):
		_apply_power_preset("science")

	# Power boost
	elif event.is_action_pressed("boost_engines"):
		_boost_power("engines")
	elif event.is_action_pressed("boost_shields"):
		_boost_power("shields")
	elif event.is_action_pressed("boost_weapons"):
		_boost_power("weapons")
	elif event.is_action_pressed("boost_sensors"):
		_boost_power("sensors")

	# Helm (V = evasive, B = reverse)
	elif event.is_action_pressed("evasive_maneuvers"):
		_evasive_maneuvers()
	elif event.is_action_pressed("reverse_engines"):
		_reverse_engines()
	# Note: O for orbit is already handled by lcars_hud.gd

	# Ops (N = scan, P = status)
	elif event.is_action_pressed("long_range_scan"):
		_long_range_scan()
	elif event.is_action_pressed("status_report"):
		_status_report()

# =============================================================================
# TACTICAL COMMANDS
# =============================================================================

func _toggle_shields() -> void:
	var tactical = _starship_core.get_subsystem("tactical")
	if not tactical:
		_show_message("Tactical systems offline")
		return

	var status: Dictionary = tactical.get_status()
	var shields_raised: bool = status.get("shields_raised", false)
	var transitioning: bool = status.get("shields_transitioning", false)

	if transitioning:
		_show_message("Shields transitioning...")
		return

	var cmd: Dictionary
	if shields_raised:
		cmd = {"department": "tactical", "intent": "lower_shields"}
		_show_message("Lowering shields...")
	else:
		cmd = {"department": "tactical", "intent": "raise_shields"}
		_show_message("Raising shields...")

	_starship_core.route_command(cmd)

func _fire_phasers() -> void:
	var cmd: Dictionary = {
		"department": "tactical",
		"intent": "fire_phasers"
	}
	var result: Dictionary = _starship_core.route_command(cmd)
	_show_message(result.get("message", "Phasers fired"))

func _fire_torpedoes() -> void:
	var cmd: Dictionary = {
		"department": "tactical",
		"intent": "fire_torpedoes"
	}
	var result: Dictionary = _starship_core.route_command(cmd)
	_show_message(result.get("message", "Torpedoes fired"))

func _cycle_target() -> void:
	# Get available targets from the scene
	_update_available_targets()

	if _available_targets.is_empty():
		_show_message("No targets in range")
		return

	_current_target_index = (_current_target_index + 1) % _available_targets.size()
	var target_name: String = _available_targets[_current_target_index]

	var cmd: Dictionary = {
		"department": "tactical",
		"intent": "set_target",
		"target": target_name
	}
	var result: Dictionary = _starship_core.route_command(cmd)
	_show_message("Targeting: %s" % target_name)

func _clear_target() -> void:
	var cmd: Dictionary = {
		"department": "tactical",
		"intent": "set_target",
		"target": ""
	}
	_starship_core.route_command(cmd)
	_current_target_index = -1
	_show_message("Target cleared")

func _update_available_targets() -> void:
	_available_targets.clear()

	# Get targets from sector (planets)
	var root: Node = get_tree().current_scene
	if root.has_method("get_all_planets"):
		var planets: Dictionary = root.get_all_planets()
		for name in planets:
			_available_targets.append(name)

	# Sort alphabetically
	_available_targets.sort()

# =============================================================================
# ALERT COMMANDS
# =============================================================================

func _set_alert(alert_type: String) -> void:
	var cmd: Dictionary = {
		"department": "core",
		"intent": alert_type
	}
	var result: Dictionary = _starship_core.route_command(cmd)
	_show_message(result.get("message", alert_type.replace("_", " ").capitalize()))

# =============================================================================
# POWER COMMANDS
# =============================================================================

func _apply_power_preset(preset: String) -> void:
	var cmd: Dictionary = {
		"department": "engineering",
		"intent": "power_preset",
		"preset": preset
	}
	var result: Dictionary = _starship_core.route_command(cmd)
	_show_message("Power: %s configuration" % preset.capitalize())

func _boost_power(subsystem: String) -> void:
	var cmd: Dictionary = {
		"department": "engineering",
		"intent": "divert_power",
		"subsystem": subsystem,
		"amount": 10
	}
	var result: Dictionary = _starship_core.route_command(cmd)
	if result.get("success", false):
		_show_message("+10%% power to %s" % subsystem)
	else:
		_show_message(result.get("message", "Cannot divert power"))

# =============================================================================
# HELM COMMANDS
# =============================================================================

func _evasive_maneuvers() -> void:
	var cmd: Dictionary = {
		"department": "helm",
		"intent": "evasive"
	}
	var result: Dictionary = _starship_core.route_command(cmd)
	_show_message("Evasive maneuvers!")

func _reverse_engines() -> void:
	var cmd: Dictionary = {
		"department": "helm",
		"intent": "reverse"
	}
	var result: Dictionary = _starship_core.route_command(cmd)
	_show_message("Reverse engines")

func _standard_orbit() -> void:
	var cmd: Dictionary = {
		"department": "helm",
		"intent": "orbit"
	}
	var result: Dictionary = _starship_core.route_command(cmd)
	_show_message("Standard orbit")

# =============================================================================
# OPS COMMANDS
# =============================================================================

func _long_range_scan() -> void:
	var cmd: Dictionary = {
		"department": "ops",
		"intent": "long_range_scan"
	}
	var result: Dictionary = _starship_core.route_command(cmd)

	var data: Dictionary = result.get("data", {})
	var contacts: Array = data.get("contacts", [])
	_show_message("Scan complete: %d contacts" % contacts.size())

func _status_report() -> void:
	var cmd: Dictionary = {
		"department": "ops",
		"intent": "status_report"
	}
	var result: Dictionary = _starship_core.route_command(cmd)
	_show_message(result.get("message", "Status report"))

# =============================================================================
# UI FEEDBACK
# =============================================================================

func _show_message(message: String) -> void:
	print("[KEYBOARD] %s" % message)

	# Try to show on HUD
	if _hud and _hud.has_method("show_computer_message"):
		_hud.show_computer_message(message)
