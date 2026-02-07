extends SubsystemBase
class_name EngineeringSystem
## Engineering subsystem - power distribution and system health management
## Phase 3: Real-time power effects on all ship systems

# =============================================================================
# SIGNALS
# =============================================================================

signal power_transition_started(from: Dictionary, to: Dictionary)
signal power_transition_complete()
signal system_damaged(system_name: String, health: float)
signal system_repaired(system_name: String, health: float)
signal warp_core_status_changed(status: int)

# =============================================================================
# STATE
# =============================================================================

# System health (0-100 for each system)
var system_health: Dictionary = {
	"engines": 100.0,
	"shields": 100.0,
	"weapons": 100.0,
	"sensors": 100.0,
	"life_support": 100.0,
	"warp_core": 100.0,
	"hull": 100.0
}

# Warp core status
enum WarpCoreStatus { OFFLINE, STANDBY, ONLINE, CRITICAL }
var warp_core_status: int = WarpCoreStatus.ONLINE
var warp_core_output: float = 100.0  # Percentage of maximum output

# Repair state
var _repair_queue: Array = []
var _current_repair: String = ""
var _repair_progress: float = 0.0
const REPAIR_RATE: float = 5.0  # Health points per second

# =============================================================================
# POWER TRANSITION STATE (smooth transitions)
# =============================================================================

var _power_transitioning: bool = false
var _power_transition_progress: float = 0.0
var _power_from: Dictionary = {}
var _power_to: Dictionary = {}
const POWER_TRANSITION_TIME: float = 1.5  # Seconds for smooth transition

# =============================================================================
# POWER EFFECT MULTIPLIERS (calculated from current distribution)
# =============================================================================

# These are publicly accessible for other systems to query
var engine_power_multiplier: float = 1.0  # Affects warp charge, impulse accel, turn rate
var shield_power_multiplier: float = 1.0  # Affects shield regen rate
var weapon_power_multiplier: float = 1.0  # Affects cooldowns
var sensor_power_multiplier: float = 1.0  # Affects scan range, lock speed

# Alert level modifiers
var _alert_engine_drain: float = 1.0  # RED alert increases engine power draw

# =============================================================================
# INITIALIZATION
# =============================================================================

func _on_initialized() -> void:
	_subsystem_name = "engineering"
	_recalculate_multipliers()
	_log_action("Engineering systems online")

func _process(delta: float) -> void:
	_process_repairs(delta)
	_process_power_transition(delta)

# =============================================================================
# COMMAND HANDLING
# =============================================================================

func _handle_command(intent: String, cmd: Dictionary) -> Dictionary:
	match intent:
		"divert_power":
			return _handle_divert_power(cmd)
		"set_power", "power_distribution":
			return _handle_set_power(cmd)
		"power_preset":
			return _handle_power_preset(cmd)
		"damage_report":
			return _damage_report()
		"repair":
			return _handle_repair(cmd)
		"warp_core_status":
			return _warp_core_report()
		"engineering_status":
			return _engineering_status()
		_:
			return _result(false, "Unknown engineering command: %s" % intent)

# =============================================================================
# POWER MANAGEMENT - Smooth transitions
# =============================================================================

func _handle_divert_power(cmd: Dictionary) -> Dictionary:
	var subsystem: String = str(cmd.get("subsystem", "")).to_lower()
	var amount = cmd.get("amount", 10)

	# Convert amount safely
	var amount_float: float = 10.0
	if amount is String:
		amount_float = float(amount) if amount.is_valid_float() else 10.0
	else:
		amount_float = float(amount)

	if not _core:
		return _result(false, "Core systems unavailable")

	# Validate the change won't exceed limits
	var current_dist: Dictionary = _core.get_power_distribution()
	var new_value: float = current_dist.get(subsystem, 0) + amount_float

	if new_value > 100.0:
		return _result(false, "Cannot exceed 100%% power to %s" % subsystem)
	if new_value < 0.0:
		return _result(false, "Cannot reduce %s power below 0%%" % subsystem)

	# Start smooth transition
	var success: bool = _start_power_transition(subsystem, amount_float)
	if success:
		_log_action("Diverting %.0f%% power to %s" % [amount_float, subsystem])
		return _result(true, "Diverting power to %s" % subsystem, {
			"subsystem": subsystem,
			"amount": amount_float,
			"transition_time": POWER_TRANSITION_TIME
		})
	else:
		return _result(false, "Unable to divert power to %s" % subsystem)

func _start_power_transition(subsystem: String, delta: float) -> bool:
	"""Start a smooth power transition."""
	if not _core:
		return false

	_power_from = _core.get_power_distribution()

	# Calculate target distribution
	var success: bool = _core.modify_power(subsystem, delta)
	if not success:
		return false

	_power_to = _core.get_power_distribution()

	# Reset to start state for transition
	_core.set_power_distribution(_power_from)

	# Begin transition
	_power_transitioning = true
	_power_transition_progress = 0.0

	emit_signal("power_transition_started", _power_from, _power_to)
	return true

func _process_power_transition(delta: float) -> void:
	"""Process smooth power transitions."""
	if not _power_transitioning:
		return

	_power_transition_progress += delta / POWER_TRANSITION_TIME

	if _power_transition_progress >= 1.0:
		# Transition complete
		_power_transition_progress = 1.0
		_power_transitioning = false

		if _core:
			_core.set_power_distribution(_power_to)

		emit_signal("power_transition_complete")
		_log_action("Power redistribution complete")
	else:
		# Interpolate power values
		var interpolated: Dictionary = {}
		for key in _power_from:
			var from_val: float = _power_from[key]
			var to_val: float = _power_to[key]
			interpolated[key] = lerpf(from_val, to_val, _power_transition_progress)

		if _core:
			_core.set_power_distribution(interpolated)

func _handle_set_power(cmd: Dictionary) -> Dictionary:
	var distribution: Dictionary = {}

	# Extract power levels from command
	for key in ["engines", "shields", "weapons", "sensors"]:
		if cmd.has(key):
			var value = cmd[key]
			if value is String:
				distribution[key] = float(value) if value.is_valid_float() else 25.0
			else:
				distribution[key] = float(value)

	if distribution.is_empty():
		return _result(false, "No power distribution specified")

	# Fill in missing values to maintain balance
	var specified_total: float = 0.0
	var missing_keys: Array = []
	for key in ["engines", "shields", "weapons", "sensors"]:
		if key in distribution:
			specified_total += distribution[key]
		else:
			missing_keys.append(key)

	if not missing_keys.is_empty():
		var remaining: float = 100.0 - specified_total
		if remaining < 0:
			return _result(false, "Power distribution exceeds 100%%")
		var each: float = remaining / missing_keys.size()
		for key in missing_keys:
			distribution[key] = each

	# Validate total
	var total: float = 0.0
	for key in distribution:
		total += distribution[key]
	if absf(total - 100.0) > 0.1:
		return _result(false, "Power distribution must sum to 100%% (got %.1f%%)" % total)

	if not _core:
		return _result(false, "Core systems unavailable")

	# Start smooth transition to new distribution
	_power_from = _core.get_power_distribution()
	_power_to = distribution
	_power_transitioning = true
	_power_transition_progress = 0.0

	_log_action("Redistributing power")
	emit_signal("power_transition_started", _power_from, _power_to)

	return _result(true, "Power redistribution initiated", {
		"target": distribution,
		"transition_time": POWER_TRANSITION_TIME
	})

func _handle_power_preset(cmd: Dictionary) -> Dictionary:
	var preset: String = str(cmd.get("preset", "balanced")).to_lower()

	if not _core:
		return _result(false, "Core systems unavailable")

	# Get preset distribution
	var presets: Dictionary = {
		"balanced": {"engines": 25.0, "shields": 25.0, "weapons": 25.0, "sensors": 25.0},
		"combat": {"engines": 15.0, "shields": 40.0, "weapons": 35.0, "sensors": 10.0},
		"evasive": {"engines": 50.0, "shields": 30.0, "weapons": 5.0, "sensors": 15.0},
		"science": {"engines": 20.0, "shields": 20.0, "weapons": 10.0, "sensors": 50.0}
	}

	if preset not in presets:
		return _result(false, "Unknown power preset: %s. Valid: balanced, combat, evasive, science" % preset)

	# Start smooth transition
	_power_from = _core.get_power_distribution()
	_power_to = presets[preset]
	_power_transitioning = true
	_power_transition_progress = 0.0

	_log_action("Applying power preset: %s" % preset)
	emit_signal("power_transition_started", _power_from, _power_to)

	return _result(true, "Applying %s power configuration" % preset, {
		"preset": preset,
		"target": _power_to,
		"transition_time": POWER_TRANSITION_TIME
	})

func get_power_distribution() -> Dictionary:
	if _core:
		return _core.get_power_distribution()
	return {}

func set_power_distribution(distribution: Dictionary) -> bool:
	if _core:
		return _core.set_power_distribution(distribution)
	return false

func divert_power(subsystem: String, delta: float) -> bool:
	if _core:
		return _core.modify_power(subsystem, delta)
	return false

# =============================================================================
# POWER EFFECT CALCULATIONS
# =============================================================================

func _recalculate_multipliers() -> void:
	"""Recalculate power effect multipliers based on current distribution."""
	var dist: Dictionary = get_power_distribution()
	if dist.is_empty():
		return

	# Base multiplier: 25% power = 1.0x, scales linearly
	# More power = better performance
	engine_power_multiplier = dist.get("engines", 25.0) / 25.0
	shield_power_multiplier = dist.get("shields", 25.0) / 25.0
	weapon_power_multiplier = dist.get("weapons", 25.0) / 25.0
	sensor_power_multiplier = dist.get("sensors", 25.0) / 25.0

	# Apply alert modifiers
	engine_power_multiplier *= _alert_engine_drain

func on_power_changed(power_distribution: Dictionary) -> void:
	"""Called when power distribution changes - recalculate multipliers."""
	_recalculate_multipliers()

func on_alert_changed(level: int) -> void:
	"""Called when alert level changes - affects power consumption."""
	match level:
		0:  # GREEN
			_alert_engine_drain = 1.0
		1:  # YELLOW
			_alert_engine_drain = 1.0
		2:  # RED
			_alert_engine_drain = 0.9  # 10% more power draw from engines at red alert

	_recalculate_multipliers()

# =============================================================================
# POWER EFFECT GETTERS (for other systems to query)
# =============================================================================

func get_warp_charge_multiplier() -> float:
	"""Get multiplier for warp charge time. Higher = faster charge."""
	return engine_power_multiplier

func get_impulse_acceleration_multiplier() -> float:
	"""Get multiplier for impulse acceleration."""
	return engine_power_multiplier

func get_turn_rate_multiplier() -> float:
	"""Get multiplier for ship turn rate."""
	return 0.8 + (engine_power_multiplier * 0.2)  # Less dramatic effect

func get_shield_regen_multiplier() -> float:
	"""Get multiplier for shield regeneration rate."""
	return shield_power_multiplier

func get_weapon_cooldown_multiplier() -> float:
	"""Get multiplier for weapon cooldown. Lower = faster cooldown."""
	return 1.0 / maxf(weapon_power_multiplier, 0.5)

func get_scan_range_multiplier() -> float:
	"""Get multiplier for sensor scan range."""
	return sensor_power_multiplier

func get_target_lock_multiplier() -> float:
	"""Get multiplier for target lock speed. Higher = faster lock."""
	return sensor_power_multiplier

# =============================================================================
# DAMAGE & HEALTH
# =============================================================================

func _damage_report() -> Dictionary:
	var damaged_systems: Array = []
	var critical_systems: Array = []

	for sys_name in system_health:
		var health: float = system_health[sys_name]
		if health < 100.0:
			damaged_systems.append({
				"system": sys_name,
				"health": health,
				"status": _get_health_status(health)
			})
			if health < 25.0:
				critical_systems.append(sys_name)

	var message: String
	if damaged_systems.is_empty():
		message = "All systems operational"
	elif not critical_systems.is_empty():
		message = "Critical damage to: %s" % ", ".join(critical_systems)
	else:
		message = "%d system(s) damaged" % damaged_systems.size()

	return _result(true, message, {
		"systems": system_health.duplicate(),
		"damaged": damaged_systems,
		"critical": critical_systems,
		"hull_integrity": system_health.get("hull", 100.0)
	})

func _get_health_status(health: float) -> String:
	if health >= 90.0:
		return "Operational"
	elif health >= 70.0:
		return "Minor damage"
	elif health >= 50.0:
		return "Moderate damage"
	elif health >= 25.0:
		return "Heavy damage"
	else:
		return "Critical"

func report_system_health() -> Dictionary:
	return system_health.duplicate()

func apply_damage(system_name: String, amount: float) -> void:
	if system_name in system_health:
		system_health[system_name] = maxf(0.0, system_health[system_name] - amount)
		_log_action("Damage to %s: %.0f%% remaining" % [system_name, system_health[system_name]])
		emit_signal("system_damaged", system_name, system_health[system_name])
		emit_signal("status_changed", _subsystem_name, get_status())

func repair_system(system_name: String, amount: float) -> void:
	if system_name in system_health:
		var old_health: float = system_health[system_name]
		system_health[system_name] = minf(100.0, system_health[system_name] + amount)
		if system_health[system_name] != old_health:
			emit_signal("system_repaired", system_name, system_health[system_name])

# =============================================================================
# REPAIR SYSTEM
# =============================================================================

func _handle_repair(cmd: Dictionary) -> Dictionary:
	var system: String = str(cmd.get("system", "")).to_lower()

	if system.is_empty():
		# Auto-select most damaged system
		var lowest_health: float = 100.0
		for sys_name in system_health:
			if system_health[sys_name] < lowest_health:
				lowest_health = system_health[sys_name]
				system = sys_name

		if lowest_health >= 100.0:
			return _result(true, "All systems operational, no repairs needed")

	if system not in system_health:
		return _result(false, "Unknown system: %s" % system)

	if system_health[system] >= 100.0:
		return _result(true, "%s is already at 100%%" % system.capitalize())

	# Queue repair
	if system not in _repair_queue and system != _current_repair:
		_repair_queue.append(system)
		_log_action("Queued repairs for %s" % system)
		return _result(true, "Repair teams dispatched to %s" % system.capitalize(), {
			"system": system,
			"current_health": system_health[system],
			"queue_position": _repair_queue.size()
		})
	else:
		return _result(true, "Repairs already in progress for %s" % system.capitalize())

func _process_repairs(delta: float) -> void:
	# Start next repair if idle
	if _current_repair.is_empty() and not _repair_queue.is_empty():
		_current_repair = _repair_queue.pop_front()
		_repair_progress = 0.0
		_log_action("Repairs started on %s" % _current_repair)

	# Process current repair
	if not _current_repair.is_empty():
		var repair_amount: float = REPAIR_RATE * delta
		system_health[_current_repair] = minf(100.0, system_health[_current_repair] + repair_amount)

		if system_health[_current_repair] >= 100.0:
			_log_action("Repairs complete: %s" % _current_repair)
			emit_signal("system_repaired", _current_repair, 100.0)
			_current_repair = ""

# =============================================================================
# WARP CORE
# =============================================================================

func _warp_core_report() -> Dictionary:
	var status_names: Dictionary = {
		WarpCoreStatus.OFFLINE: "Offline",
		WarpCoreStatus.STANDBY: "Standby",
		WarpCoreStatus.ONLINE: "Online",
		WarpCoreStatus.CRITICAL: "Critical"
	}

	return _result(true, "Warp core: %s at %.0f%% output" % [
		status_names[warp_core_status],
		warp_core_output
	], {
		"status": warp_core_status,
		"status_name": status_names[warp_core_status],
		"output": warp_core_output,
		"health": system_health.get("warp_core", 100.0)
	})

func get_warp_core_status() -> String:
	var status_names: Dictionary = {
		WarpCoreStatus.OFFLINE: "Offline",
		WarpCoreStatus.STANDBY: "Standby",
		WarpCoreStatus.ONLINE: "Online",
		WarpCoreStatus.CRITICAL: "Critical"
	}
	return status_names.get(warp_core_status, "Unknown")

func set_warp_core_status(status: int) -> void:
	var old_status: int = warp_core_status
	warp_core_status = status
	if old_status != status:
		emit_signal("warp_core_status_changed", status)
		_log_action("Warp core status: %s" % get_warp_core_status())

# =============================================================================
# STATUS
# =============================================================================

func _engineering_status() -> Dictionary:
	return _result(true, "Engineering status report", get_status())

func get_status() -> Dictionary:
	var base_status: Dictionary = super.get_status()

	base_status["system_health"] = system_health.duplicate()
	base_status["warp_core_status"] = get_warp_core_status()
	base_status["warp_core_output"] = warp_core_output
	base_status["power_distribution"] = get_power_distribution()
	base_status["repair_queue"] = _repair_queue.duplicate()
	base_status["current_repair"] = _current_repair
	base_status["power_transitioning"] = _power_transitioning

	# Power effect multipliers
	base_status["engine_multiplier"] = engine_power_multiplier
	base_status["shield_multiplier"] = shield_power_multiplier
	base_status["weapon_multiplier"] = weapon_power_multiplier
	base_status["sensor_multiplier"] = sensor_power_multiplier

	return base_status
