extends SubsystemBase
class_name OpsSystem
## Operations subsystem - sensors, scanning, and status reports
## Phase 3: Real data output from scene state

# =============================================================================
# SIGNALS
# =============================================================================

signal scan_started(target: String, scan_type: int)
signal scan_complete(target: String, data: Dictionary)
signal contact_detected(contact: Dictionary)

# =============================================================================
# STATE
# =============================================================================

const BASE_SENSOR_RANGE: float = 100000.0  # Base sensor range in units
var sensor_range: float = 100000.0  # Current range (affected by power)
var sensor_resolution: float = 1.0  # 0-2, affected by power
var active_scans: Dictionary = {}  # target_name -> scan_data

# Scan types and durations
enum ScanType { QUICK, STANDARD, DETAILED, DEEP }
const SCAN_DURATIONS: Dictionary = {
	ScanType.QUICK: 1.0,
	ScanType.STANDARD: 3.0,
	ScanType.DETAILED: 8.0,
	ScanType.DEEP: 15.0
}

# Current scan state
var _current_scan_target: String = ""
var _current_scan_type: int = ScanType.STANDARD
var _scan_progress: float = 0.0
var _scan_complete: bool = false
var _scan_target_node: Node3D = null

# External references
var _ship_controller: Node3D = null
var _warp_drive: Node3D = null
var _sector: Node = null

# =============================================================================
# INITIALIZATION
# =============================================================================

func _on_initialized() -> void:
	_subsystem_name = "ops"

	# Find external references
	_ship_controller = _find_node_by_script("ShipController")
	_warp_drive = _find_node_by_script("WarpDrive")
	_find_sector()

	_log_action("Operations systems online")

func _find_node_by_script(script_name: String) -> Node:
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

func _find_sector() -> void:
	var node: Node = get_tree().current_scene
	if node.has_method("get_all_planets"):
		_sector = node

func _process(delta: float) -> void:
	_process_scan(delta)

# =============================================================================
# COMMAND HANDLING
# =============================================================================

func _handle_command(intent: String, cmd: Dictionary) -> Dictionary:
	match intent:
		"scan", "scan_target":
			return _handle_scan(cmd)
		"long_range_scan":
			return _long_range_scan()
		"status_report", "status":
			return _status_report()
		"sensor_sweep":
			return _sensor_sweep(cmd)
		"ops_status":
			return _ops_status()
		"hail":
			return _handle_hail(cmd)
		"viewscreen":
			return _handle_viewscreen(cmd)
		_:
			return _result(false, "Unknown ops command: %s" % intent)

# =============================================================================
# SCANNING - Real data from scene
# =============================================================================

func _handle_scan(cmd: Dictionary) -> Dictionary:
	var target = cmd.get("target")
	var target_str: String = str(target) if target != null else ""

	if target_str.is_empty() or target_str == "null":
		return _result(false, "No scan target specified")

	var scan_type: int = ScanType.STANDARD
	var type_str: String = str(cmd.get("type", "standard")).to_lower()
	match type_str:
		"quick":
			scan_type = ScanType.QUICK
		"detailed":
			scan_type = ScanType.DETAILED
		"deep":
			scan_type = ScanType.DEEP

	# Try to find the target in scene
	_scan_target_node = _find_target_in_scene(target_str)

	# Start scan
	_current_scan_target = target_str
	_current_scan_type = scan_type
	_scan_progress = 0.0
	_scan_complete = false

	var duration: float = SCAN_DURATIONS[scan_type] / maxf(sensor_resolution, 0.5)
	_log_action("Initiating %s scan of %s (%.1fs)" % [type_str, target_str, duration])
	emit_signal("scan_started", target_str, scan_type)

	# Generate scan data
	var scan_data: Dictionary = _generate_real_scan_data(target_str)
	active_scans[target_str] = scan_data

	return _result(true, "Scan complete: %s" % target_str, scan_data)

func _process_scan(delta: float) -> void:
	if _current_scan_target.is_empty() or _scan_complete:
		return

	var duration: float = SCAN_DURATIONS[_current_scan_type] / maxf(sensor_resolution, 0.5)
	_scan_progress += delta / duration

	if _scan_progress >= 1.0:
		_scan_complete = true
		var scan_data: Dictionary = active_scans.get(_current_scan_target, {})
		_log_action("Scan of %s complete" % _current_scan_target)
		emit_signal("scan_complete", _current_scan_target, scan_data)

func _find_target_in_scene(target_name: String) -> Node3D:
	"""Find a target node in the scene."""
	if not _sector:
		_find_sector()

	if _sector and _sector.has_method("get_all_planets"):
		var planets: Dictionary = _sector.get_all_planets()
		var target_lower: String = target_name.to_lower()
		for name in planets:
			if name.to_lower() == target_lower:
				return planets[name]

	return null

func _generate_real_scan_data(target: String) -> Dictionary:
	"""Generate scan data using real scene information."""
	var scan_data: Dictionary = {
		"target": target,
		"scan_time": Time.get_datetime_string_from_system(),
		"resolution": sensor_resolution
	}

	# Try to get real data from target node
	if _scan_target_node and _ship_controller:
		var distance: float = _ship_controller.global_position.distance_to(_scan_target_node.global_position)
		var distance_km: float = distance * 10.0  # 1 unit = 10 km at 100x scale

		# Calculate relative velocity
		var relative_velocity: float = 0.0
		if _ship_controller.has_method("get_velocity_info"):
			var vel_info: Dictionary = _ship_controller.get_velocity_info()
			relative_velocity = vel_info.get("speed", 0.0)

		scan_data["distance_units"] = distance
		scan_data["distance_km"] = distance_km
		scan_data["distance_display"] = _format_distance(distance_km)
		scan_data["relative_velocity"] = relative_velocity
		scan_data["bearing"] = _calculate_bearing(_scan_target_node)
		scan_data["in_range"] = distance <= sensor_range

		# Estimate threat level (planets are not threats)
		scan_data["threat_level"] = "None"
		scan_data["threat_assessment"] = "Celestial body - no threat"

		# Target has no shields (it's a planet)
		scan_data["shields_detected"] = false
		scan_data["shield_status"] = "N/A"

	# Add static data based on target name
	var target_lower: String = target.to_lower()
	_add_target_specific_data(scan_data, target_lower)

	return scan_data

func _calculate_bearing(target_node: Node3D) -> String:
	"""Calculate bearing to target in Star Trek format."""
	if not _ship_controller or not target_node:
		return "Unknown"

	var ship_pos: Vector3 = _ship_controller.global_position
	var target_pos: Vector3 = target_node.global_position
	var direction: Vector3 = (target_pos - ship_pos).normalized()

	# Convert to spherical coordinates
	var azimuth: float = rad_to_deg(atan2(direction.x, -direction.z))
	var elevation: float = rad_to_deg(asin(direction.y))

	# Normalize azimuth to 0-360
	if azimuth < 0:
		azimuth += 360.0

	return "%.0f mark %.0f" % [azimuth, elevation]

func _format_distance(distance_km: float) -> String:
	"""Format distance for display."""
	if distance_km >= 1000000000:  # > 1 billion km
		return "%.2f billion km" % (distance_km / 1000000000.0)
	elif distance_km >= 1000000:  # > 1 million km
		return "%.2f million km" % (distance_km / 1000000.0)
	elif distance_km >= 1000:  # > 1000 km
		return "%.0f thousand km" % (distance_km / 1000.0)
	else:
		return "%.0f km" % distance_km

func _add_target_specific_data(scan_data: Dictionary, target_lower: String) -> void:
	"""Add target-specific scan information."""
	if "earth" in target_lower:
		scan_data["type"] = "Class M Planet"
		scan_data["diameter"] = "12,742 km"
		scan_data["atmosphere"] = "Nitrogen-Oxygen"
		scan_data["population"] = "8.2 billion"
		scan_data["life_signs"] = "Abundant"
		scan_data["technology_level"] = "Warp-capable"
	elif "mars" in target_lower:
		scan_data["type"] = "Class D Planet"
		scan_data["diameter"] = "6,779 km"
		scan_data["atmosphere"] = "Carbon dioxide (thin)"
		scan_data["population"] = "2.4 million (colonies)"
		scan_data["life_signs"] = "Human colonies detected"
		scan_data["technology_level"] = "Federation standard"
	elif "jupiter" in target_lower:
		scan_data["type"] = "Class J Gas Giant"
		scan_data["diameter"] = "139,820 km"
		scan_data["atmosphere"] = "Hydrogen-Helium"
		scan_data["moons"] = "95 detected"
		scan_data["life_signs"] = "None"
		scan_data["notes"] = "Extreme radiation environment"
	elif "saturn" in target_lower:
		scan_data["type"] = "Class J Gas Giant"
		scan_data["diameter"] = "116,460 km"
		scan_data["atmosphere"] = "Hydrogen-Helium"
		scan_data["moons"] = "146 detected"
		scan_data["ring_system"] = "Extensive"
		scan_data["life_signs"] = "None"
	elif "sun" in target_lower or "sol" in target_lower:
		scan_data["type"] = "G-type Main Sequence Star"
		scan_data["diameter"] = "1,392,700 km"
		scan_data["surface_temperature"] = "5,778 K"
		scan_data["corona_activity"] = "Normal"
		scan_data["solar_flares"] = "Minimal"
	elif "moon" in target_lower or "luna" in target_lower:
		scan_data["type"] = "Class D Moon"
		scan_data["diameter"] = "3,474 km"
		scan_data["atmosphere"] = "None"
		scan_data["population"] = "500,000 (colonies)"
		scan_data["life_signs"] = "Human presence"
	elif "venus" in target_lower:
		scan_data["type"] = "Class N Planet"
		scan_data["diameter"] = "12,104 km"
		scan_data["atmosphere"] = "Carbon dioxide (dense)"
		scan_data["surface_temperature"] = "465°C"
		scan_data["life_signs"] = "None"
	elif "mercury" in target_lower:
		scan_data["type"] = "Class B Planet"
		scan_data["diameter"] = "4,879 km"
		scan_data["atmosphere"] = "None (trace)"
		scan_data["life_signs"] = "None"
	elif "neptune" in target_lower:
		scan_data["type"] = "Class J Ice Giant"
		scan_data["diameter"] = "49,528 km"
		scan_data["atmosphere"] = "Hydrogen-Helium-Methane"
		scan_data["life_signs"] = "None"
	elif "uranus" in target_lower:
		scan_data["type"] = "Class J Ice Giant"
		scan_data["diameter"] = "50,724 km"
		scan_data["atmosphere"] = "Hydrogen-Helium-Methane"
		scan_data["life_signs"] = "None"
	else:
		scan_data["type"] = "Unknown"
		scan_data["status"] = "Insufficient sensor data"
		scan_data["recommendation"] = "Detailed scan required"

func scan_target(target_name: String) -> Dictionary:
	return _handle_scan({"target": target_name}).get("data", {})

# =============================================================================
# LONG RANGE SCAN - Real objects from scene
# =============================================================================

func _long_range_scan() -> Dictionary:
	_log_action("Initiating long range sensor sweep")

	var contacts: Array = []

	# Get real objects from sector
	if _sector and _sector.has_method("get_all_planets") and _ship_controller:
		var planets: Dictionary = _sector.get_all_planets()
		var ship_pos: Vector3 = _ship_controller.global_position

		for name in planets:
			var body: Node3D = planets[name]
			if not body:
				continue

			var distance: float = ship_pos.distance_to(body.global_position)
			var distance_km: float = distance * 10.0

			# Only include objects within sensor range
			if distance <= sensor_range:
				var contact: Dictionary = {
					"name": name,
					"bearing": _calculate_bearing(body),
					"distance_units": distance,
					"distance_km": distance_km,
					"distance_display": _format_distance(distance_km),
					"classification": _get_body_classification(name),
					"in_range": true
				}
				contacts.append(contact)
				emit_signal("contact_detected", contact)

	# Sort by distance
	contacts.sort_custom(func(a, b): return a.distance_units < b.distance_units)

	return _result(true, "Long range scan complete. %d contacts detected." % contacts.size(), {
		"contacts": contacts,
		"sensor_range": sensor_range,
		"sensor_range_km": sensor_range * 10.0,
		"resolution": sensor_resolution
	})

func _get_body_classification(name: String) -> String:
	"""Get classification for a celestial body."""
	var name_lower: String = name.to_lower()
	if "sun" in name_lower or "sol" in name_lower:
		return "G-type Star"
	elif "earth" in name_lower:
		return "Class M Planet"
	elif "mars" in name_lower:
		return "Class D Planet"
	elif "jupiter" in name_lower or "saturn" in name_lower:
		return "Class J Gas Giant"
	elif "neptune" in name_lower or "uranus" in name_lower:
		return "Class J Ice Giant"
	elif "venus" in name_lower:
		return "Class N Planet"
	elif "mercury" in name_lower:
		return "Class B Planet"
	elif "moon" in name_lower:
		return "Class D Moon"
	elif "starbase" in name_lower:
		return "Federation Starbase"
	else:
		return "Unknown"

func long_range_scan() -> Dictionary:
	return _long_range_scan().get("data", {})

# =============================================================================
# STATUS REPORT - Comprehensive live ship state
# =============================================================================

func _status_report() -> Dictionary:
	"""Generate comprehensive ship status report with live data."""
	var report: Dictionary = {}

	# Get core status
	if _core:
		report["alert_level"] = _core.get_alert_state()
		report["alert_name"] = _core.get_alert_name()
		report["power_distribution"] = _core.get_power_distribution()

	# Warp/Impulse state
	if _warp_drive:
		report["warp_state"] = "At Warp" if _warp_drive.is_at_warp else "Impulse"
		report["warp_factor"] = _warp_drive.current_warp_factor if _warp_drive.is_at_warp else 0.0
		report["warp_charging"] = _warp_drive.is_charging_warp
	else:
		report["warp_state"] = "Unknown"
		report["warp_factor"] = 0.0

	if _ship_controller:
		if _ship_controller.has_method("get_impulse_name"):
			report["impulse_state"] = _ship_controller.get_impulse_name()
		report["velocity"] = _ship_controller.linear_velocity.length()

	# Tactical status
	var tactical: SubsystemBase = _get_sibling_subsystem("tactical")
	if tactical:
		var tac_status: Dictionary = tactical.get_status()
		report["shields_raised"] = tac_status.get("shields_raised", false)
		report["shield_percent"] = tac_status.get("shield_percent", 100.0)
		report["shield_strength"] = tac_status.get("shield_strength", 100.0)
		report["current_target"] = tac_status.get("current_target", "")
		report["target_lock"] = tac_status.get("target_lock", false)
		report["torpedo_count"] = tac_status.get("torpedo_count", 0)
		report["phaser_cooldown"] = tac_status.get("phaser_cooldown", 0.0)
		report["torpedo_cooldown"] = tac_status.get("torpedo_cooldown", 0.0)
		report["phaser_ready"] = tac_status.get("phaser_ready", true)
		report["torpedo_ready"] = tac_status.get("torpedo_ready", true)

	# Engineering status
	var engineering: SubsystemBase = _get_sibling_subsystem("engineering")
	if engineering:
		var eng_status: Dictionary = engineering.get_status()
		report["warp_core_status"] = eng_status.get("warp_core_status", "Unknown")
		report["system_health"] = eng_status.get("system_health", {})

	# Ops-specific
	report["sensor_status"] = "Operational" if _enabled else "Offline"
	report["sensor_range"] = sensor_range
	report["sensor_range_km"] = sensor_range * 10.0
	report["sensor_resolution"] = sensor_resolution
	report["active_scans"] = active_scans.size()

	# Summary message
	var message: String = "Ship status: %s alert" % report.get("alert_name", "Unknown")
	if report.get("warp_state") == "At Warp":
		message += " | Warp %.1f" % report.get("warp_factor", 0)
	else:
		message += " | %s" % report.get("impulse_state", "Unknown")

	if report.get("shields_raised", false):
		message += " | Shields %.0f%%" % report.get("shield_percent", 100)

	return _result(true, message, report)

func _get_sibling_subsystem(name: String) -> SubsystemBase:
	"""Get another subsystem via core."""
	if _core and _core.has_method("get_subsystem"):
		return _core.get_subsystem(name)
	return null

func status_report() -> Dictionary:
	return _status_report().get("data", {})

# =============================================================================
# SENSOR SWEEP
# =============================================================================

func _sensor_sweep(cmd: Dictionary) -> Dictionary:
	var sweep_type: String = str(cmd.get("type", "standard")).to_lower()

	_log_action("Initiating %s sensor sweep" % sweep_type)

	var anomalies: Array = []
	var threats: Array = []

	# In a real implementation, this would scan for anomalies and threats
	# For now, return empty arrays

	return _result(true, "Sensor sweep complete. No anomalies detected.", {
		"sweep_type": sweep_type,
		"anomalies": anomalies,
		"threats": threats,
		"all_clear": anomalies.is_empty() and threats.is_empty(),
		"sensor_range": sensor_range
	})

# =============================================================================
# COMMUNICATIONS
# =============================================================================

func _handle_hail(cmd: Dictionary) -> Dictionary:
	var target = cmd.get("target")
	var target_str: String = str(target) if target != null else ""

	if target_str.is_empty() or target_str == "null":
		_log_action("Opening hailing frequencies")
		return _result(true, "Hailing frequencies open", {"channel": "open"})

	_log_action("Hailing %s" % target_str)
	return _result(true, "Hailing %s... no response" % target_str, {
		"target": target_str,
		"response": false
	})

func _handle_viewscreen(cmd: Dictionary) -> Dictionary:
	_log_action("Activating viewscreen")
	return _result(true, "On screen", {"viewscreen": "active"})

# =============================================================================
# STATUS
# =============================================================================

func _ops_status() -> Dictionary:
	return _result(true, "Operations status report", get_status())

func get_status() -> Dictionary:
	var base_status: Dictionary = super.get_status()

	base_status["sensor_range"] = sensor_range
	base_status["sensor_range_km"] = sensor_range * 10.0
	base_status["sensor_resolution"] = sensor_resolution
	base_status["active_scans"] = active_scans.keys()
	base_status["scanning"] = not _current_scan_target.is_empty() and not _scan_complete
	base_status["current_scan_target"] = _current_scan_target
	base_status["scan_progress"] = _scan_progress * 100.0

	return base_status

# =============================================================================
# POWER & ALERT RESPONSE
# =============================================================================

func on_power_changed(power_distribution: Dictionary) -> void:
	"""Respond to power distribution changes."""
	var sensor_power: float = power_distribution.get("sensors", 25.0)

	# Sensor resolution scales with power (25% = 1.0x, 50% = 2.0x)
	sensor_resolution = clampf(sensor_power / 25.0, 0.1, 2.0)

	# Sensor range also affected
	sensor_range = BASE_SENSOR_RANGE * sensor_resolution

	if sensor_power < 10.0:
		_log_action("Warning: Sensor power critically low")

func on_alert_changed(level: int) -> void:
	"""Respond to alert level changes."""
	match level:
		1:  # YELLOW - slight sensor boost
			sensor_resolution *= 1.1
			sensor_range = BASE_SENSOR_RANGE * sensor_resolution
		2:  # RED - no change to sensors (focus on combat)
			pass
