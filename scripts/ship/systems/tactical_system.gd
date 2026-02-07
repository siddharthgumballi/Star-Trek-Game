extends SubsystemBase
class_name TacticalSystem
## Tactical subsystem - shields, weapons, and targeting
## Phase 3: Full state-driven implementation with power/alert effects

# =============================================================================
# SIGNALS
# =============================================================================

signal shields_changed(strength: float, is_raised: bool)
signal target_locked(target_name: String)
signal target_lost()
signal weapon_fired(weapon_type: String, target: String)
signal weapon_cooldown_complete(weapon_type: String)

# =============================================================================
# SHIELD STATE
# =============================================================================

var shields_raised: bool = false
var shield_max_strength: float = 100.0
var shield_current_strength: float = 100.0
var shield_target_strength: float = 100.0  # For gradual transitions
var shield_frequency: float = 257.4  # MHz

# Shield transitions (gradual raise/lower)
var _shield_transition_active: bool = false
var _shield_transition_direction: int = 0  # 1 = raising, -1 = lowering
const SHIELD_RAISE_RATE: float = 40.0  # % per second
const SHIELD_LOWER_RATE: float = 60.0  # % per second

# Shield regeneration
const BASE_SHIELD_REGEN_RATE: float = 2.0  # % per second at 100% power
var _current_regen_rate: float = 2.0  # Affected by power and alert

# =============================================================================
# WEAPON STATE
# =============================================================================

# Torpedoes
var torpedo_count: int = 250
var quantum_torpedo_count: int = 0
const MAX_TORPEDOES: int = 250

# Cooldowns (in seconds)
var phaser_cooldown: float = 0.0
var torpedo_cooldown: float = 0.0

# Base cooldown times (modified by power level)
const BASE_PHASER_COOLDOWN: float = 2.0
const BASE_TORPEDO_COOLDOWN: float = 5.0

# Current effective cooldown times (recalculated on power change)
var _effective_phaser_cooldown: float = 2.0
var _effective_torpedo_cooldown: float = 5.0

# Weapon power levels
var phaser_power: float = 100.0  # Damage multiplier
var torpedo_yield: float = 100.0

# =============================================================================
# TARGETING STATE
# =============================================================================

var current_target: String = ""
var target_lock: bool = false
var target_lock_progress: float = 0.0  # 0-100%
var _target_node: Node3D = null

# Target lock timing (affected by sensor power)
const BASE_TARGET_LOCK_TIME: float = 2.0  # Seconds at 100% sensor power
var _effective_lock_time: float = 2.0
var _locking_target: String = ""

# =============================================================================
# EXTERNAL REFERENCES
# =============================================================================

var _warp_drive: Node3D = null
var _ship_controller: Node3D = null

# =============================================================================
# INITIALIZATION
# =============================================================================

func _on_initialized() -> void:
	_subsystem_name = "tactical"

	# Find warp drive and ship controller for state validation
	_warp_drive = _find_node_by_script("WarpDrive")
	_ship_controller = _find_node_by_script("ShipController")

	_log_action("Tactical systems online")

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

# =============================================================================
# PROCESS - Update cooldowns, shields, targeting every frame
# =============================================================================

func _process(delta: float) -> void:
	_process_cooldowns(delta)
	_process_shields(delta)
	_process_targeting(delta)

func _process_cooldowns(delta: float) -> void:
	# Update weapon cooldowns
	if phaser_cooldown > 0:
		phaser_cooldown = maxf(0.0, phaser_cooldown - delta)
		if phaser_cooldown <= 0:
			emit_signal("weapon_cooldown_complete", "phasers")

	if torpedo_cooldown > 0:
		torpedo_cooldown = maxf(0.0, torpedo_cooldown - delta)
		if torpedo_cooldown <= 0:
			emit_signal("weapon_cooldown_complete", "torpedoes")

func _process_shields(delta: float) -> void:
	# Handle gradual shield transitions
	if _shield_transition_active:
		if _shield_transition_direction > 0:
			# Raising shields
			shield_current_strength += SHIELD_RAISE_RATE * delta
			if shield_current_strength >= shield_target_strength:
				shield_current_strength = shield_target_strength
				_shield_transition_active = false
				shields_raised = true
				_log_action("Shields fully raised at %.0f%%" % shield_current_strength)
		else:
			# Lowering shields
			shield_current_strength -= SHIELD_LOWER_RATE * delta
			if shield_current_strength <= 0:
				shield_current_strength = 0.0
				_shield_transition_active = false
				shields_raised = false
				_log_action("Shields fully lowered")

		emit_signal("shields_changed", shield_current_strength, shields_raised)

	# Shield regeneration (only when raised and not transitioning)
	elif shields_raised and shield_current_strength < shield_max_strength:
		var regen: float = _current_regen_rate * delta
		shield_current_strength = minf(shield_current_strength + regen, shield_max_strength)

func _process_targeting(delta: float) -> void:
	# Handle target lock progress
	if not _locking_target.is_empty() and not target_lock:
		target_lock_progress += (100.0 / _effective_lock_time) * delta

		if target_lock_progress >= 100.0:
			target_lock_progress = 100.0
			target_lock = true
			current_target = _locking_target
			_locking_target = ""
			_log_action("Target locked: %s" % current_target)
			emit_signal("target_locked", current_target)

# =============================================================================
# COMMAND HANDLING
# =============================================================================

func _handle_command(intent: String, cmd: Dictionary) -> Dictionary:
	match intent:
		"raise_shields":
			return _raise_shields()
		"lower_shields":
			return _lower_shields()
		"set_target", "target":
			return _set_target(cmd)
		"fire_phasers", "phasers", "fire":
			return _fire_phasers(cmd)
		"fire_torpedoes", "torpedoes", "fire_torpedo":
			return _fire_torpedoes(cmd)
		"modulate_shields":
			return _modulate_shields(cmd)
		"tactical_status":
			return _tactical_status()
		_:
			return _result(false, "Unknown tactical command: %s" % intent)

# =============================================================================
# SHIELDS - Gradual transitions
# =============================================================================

func _raise_shields() -> Dictionary:
	# Validate: Can't raise shields during warp charge
	if _warp_drive and _warp_drive.is_charging_warp:
		return _result(false, "Cannot raise shields during warp charge sequence")

	if shields_raised and not _shield_transition_active:
		return _result(true, "Shields already raised", {"shield_strength": shield_current_strength})

	if _shield_transition_active and _shield_transition_direction > 0:
		return _result(true, "Shields already raising", {"shield_strength": shield_current_strength})

	# Start gradual shield raise
	_shield_transition_active = true
	_shield_transition_direction = 1
	shield_target_strength = shield_max_strength

	_log_action("Raising shields...")
	emit_signal("status_changed", _subsystem_name, get_status())

	return _result(true, "Raising shields", {
		"shields_raising": true,
		"current_strength": shield_current_strength,
		"target_strength": shield_target_strength
	})

func _lower_shields() -> Dictionary:
	if not shields_raised and not _shield_transition_active:
		return _result(true, "Shields already lowered")

	if _shield_transition_active and _shield_transition_direction < 0:
		return _result(true, "Shields already lowering", {"shield_strength": shield_current_strength})

	# Start gradual shield lower
	_shield_transition_active = true
	_shield_transition_direction = -1

	_log_action("Lowering shields...")
	emit_signal("status_changed", _subsystem_name, get_status())

	return _result(true, "Lowering shields", {"shields_lowering": true})

func raise_shields() -> bool:
	var result: Dictionary = _raise_shields()
	return result.success

func lower_shields() -> bool:
	var result: Dictionary = _lower_shields()
	return result.success

func _modulate_shields(cmd: Dictionary) -> Dictionary:
	var frequency = cmd.get("frequency")
	if frequency == null:
		shield_frequency = randf_range(200.0, 350.0)
	else:
		shield_frequency = float(frequency)

	_log_action("Shield frequency modulated to %.1f MHz" % shield_frequency)
	return _result(true, "Shield frequency set to %.1f MHz" % shield_frequency, {
		"frequency": shield_frequency
	})

## Apply damage to shields. Returns remaining damage that passed through.
func apply_shield_damage(damage: float) -> float:
	if not shields_raised or shield_current_strength <= 0:
		return damage  # No shields, full damage passes through

	var absorbed: float = minf(damage, shield_current_strength)
	shield_current_strength -= absorbed

	if shield_current_strength <= 0:
		shield_current_strength = 0.0
		shields_raised = false
		_shield_transition_active = false
		_log_action("Shields collapsed!")
		emit_signal("shields_changed", 0.0, false)
	else:
		emit_signal("shields_changed", shield_current_strength, true)

	return damage - absorbed  # Remaining damage

# =============================================================================
# TARGETING - Lock time based on sensor power
# =============================================================================

func _set_target(cmd: Dictionary) -> Dictionary:
	var target = cmd.get("target")
	var target_str: String = str(target) if target != null else ""

	if target_str.is_empty() or target_str == "null":
		# Clear target
		current_target = ""
		target_lock = false
		target_lock_progress = 0.0
		_locking_target = ""
		_target_node = null
		_log_action("Target cleared")
		emit_signal("target_lost")
		return _result(true, "Target cleared")

	# Validate target exists in scene (optional - can target anything for now)
	_target_node = _find_target_in_scene(target_str)

	# Start target lock sequence
	_locking_target = target_str
	target_lock = false
	target_lock_progress = 0.0

	_log_action("Acquiring target lock: %s (%.1fs)" % [target_str, _effective_lock_time])

	return _result(true, "Acquiring target lock: %s" % target_str, {
		"target": target_str,
		"lock_time": _effective_lock_time,
		"target_exists": _target_node != null
	})

func _find_target_in_scene(target_name: String) -> Node3D:
	"""Try to find a target node in the scene tree."""
	var root: Node = get_tree().current_scene

	# Check if scene has get_all_planets method (sector)
	if root.has_method("get_all_planets"):
		var planets: Dictionary = root.get_all_planets()
		var target_lower: String = target_name.to_lower()
		for name in planets:
			if name.to_lower() == target_lower:
				return planets[name]

	return null

func set_target(target_name: String) -> bool:
	var result: Dictionary = _set_target({"target": target_name})
	return result.success

func get_target_distance() -> float:
	"""Get distance to current target in units."""
	if not target_lock or not _target_node or not _ship_controller:
		return -1.0
	return _ship_controller.global_position.distance_to(_target_node.global_position)

# =============================================================================
# WEAPONS - State validation and power-dependent cooldowns
# =============================================================================

func _fire_phasers(cmd: Dictionary) -> Dictionary:
	# State validation
	var validation: Dictionary = _validate_weapon_fire()
	if not validation.valid:
		return _result(false, validation.reason)

	if phaser_cooldown > 0:
		return _result(false, "Phasers recharging (%.1f seconds)" % phaser_cooldown)

	var power: float = cmd.get("power", phaser_power)
	phaser_cooldown = _effective_phaser_cooldown

	_log_action("Phasers fired at %s (power: %.0f%%, cooldown: %.1fs)" % [
		current_target, power, _effective_phaser_cooldown
	])
	emit_signal("weapon_fired", "phasers", current_target)

	return _result(true, "Phasers fired at %s" % current_target, {
		"target": current_target,
		"power": power,
		"damage": power * 0.5,  # Base damage calculation
		"cooldown": _effective_phaser_cooldown,
		"target_distance": get_target_distance()
	})

func _fire_torpedoes(cmd: Dictionary) -> Dictionary:
	# State validation
	var validation: Dictionary = _validate_weapon_fire()
	if not validation.valid:
		return _result(false, validation.reason)

	if torpedo_cooldown > 0:
		return _result(false, "Torpedo tubes reloading (%.1f seconds)" % torpedo_cooldown)

	if torpedo_count <= 0:
		return _result(false, "No torpedoes remaining")

	var count: int = cmd.get("count", 1)
	count = mini(count, torpedo_count)

	torpedo_count -= count
	torpedo_cooldown = _effective_torpedo_cooldown

	_log_action("Fired %d torpedo(es) at %s (remaining: %d, cooldown: %.1fs)" % [
		count, current_target, torpedo_count, _effective_torpedo_cooldown
	])
	emit_signal("weapon_fired", "torpedoes", current_target)

	return _result(true, "Fired %d torpedo(es) at %s" % [count, current_target], {
		"target": current_target,
		"count": count,
		"yield": torpedo_yield,
		"remaining": torpedo_count,
		"cooldown": _effective_torpedo_cooldown,
		"target_distance": get_target_distance()
	})

func _validate_weapon_fire() -> Dictionary:
	"""Validate that weapons can be fired in current state."""
	# Can't fire during warp
	if _warp_drive and _warp_drive.is_at_warp:
		return {"valid": false, "reason": "Cannot fire weapons at warp speed"}

	if _warp_drive and _warp_drive.is_charging_warp:
		return {"valid": false, "reason": "Cannot fire weapons during warp charge"}

	# Must have target lock
	if not target_lock or current_target.is_empty():
		return {"valid": false, "reason": "No target locked"}

	return {"valid": true, "reason": ""}

func fire_phasers() -> bool:
	var result: Dictionary = _fire_phasers({})
	return result.success

func fire_torpedoes(count: int = 1) -> bool:
	var result: Dictionary = _fire_torpedoes({"count": count})
	return result.success

# =============================================================================
# STATUS
# =============================================================================

func _tactical_status() -> Dictionary:
	return _result(true, "Tactical status report", get_status())

func get_status() -> Dictionary:
	var base_status: Dictionary = super.get_status()

	# Shield status
	base_status["shields_raised"] = shields_raised
	base_status["shield_strength"] = shield_current_strength
	base_status["shield_max"] = shield_max_strength
	base_status["shield_percent"] = (shield_current_strength / shield_max_strength) * 100.0
	base_status["shield_frequency"] = shield_frequency
	base_status["shield_regen_rate"] = _current_regen_rate
	base_status["shields_transitioning"] = _shield_transition_active

	# Weapon status
	base_status["torpedo_count"] = torpedo_count
	base_status["torpedo_max"] = MAX_TORPEDOES
	base_status["phaser_power"] = phaser_power
	base_status["phaser_cooldown"] = phaser_cooldown
	base_status["phaser_cooldown_max"] = _effective_phaser_cooldown
	base_status["phaser_ready"] = phaser_cooldown <= 0
	base_status["torpedo_cooldown"] = torpedo_cooldown
	base_status["torpedo_cooldown_max"] = _effective_torpedo_cooldown
	base_status["torpedo_ready"] = torpedo_cooldown <= 0 and torpedo_count > 0

	# Targeting status
	base_status["current_target"] = current_target
	base_status["target_lock"] = target_lock
	base_status["target_lock_progress"] = target_lock_progress
	base_status["locking_target"] = _locking_target
	base_status["target_distance"] = get_target_distance()

	return base_status

# =============================================================================
# ALERT RESPONSE - Affects shield regen and weapon cooldowns
# =============================================================================

func on_alert_changed(level: int) -> void:
	"""Respond to alert level changes."""
	_recalculate_rates()

	if level == 2:  # RED ALERT
		# Auto-raise shields on red alert
		if not shields_raised and not _shield_transition_active:
			raise_shields()
			_log_action("Shields auto-raised (Red Alert)")
	elif level == 0:  # GREEN
		pass  # Optionally lower shields

# =============================================================================
# POWER RESPONSE - Affects cooldowns, regen, and lock time
# =============================================================================

func on_power_changed(power_distribution: Dictionary) -> void:
	"""Respond to power distribution changes."""
	var weapons_power: float = power_distribution.get("weapons", 25.0)
	var shields_power: float = power_distribution.get("shields", 25.0)
	var sensors_power: float = power_distribution.get("sensors", 25.0)

	# Phaser power scales with weapons allocation (25% = 100%, 50% = 150%)
	phaser_power = clampf(weapons_power * 4.0, 0.0, 200.0)

	# Store power values for rate calculations
	_weapons_power = weapons_power
	_shields_power = shields_power
	_sensors_power = sensors_power

	_recalculate_rates()

	if weapons_power < 10.0:
		_log_action("Warning: Weapons power critically low")

var _weapons_power: float = 25.0
var _shields_power: float = 25.0
var _sensors_power: float = 25.0

func _recalculate_rates() -> void:
	"""Recalculate all rates based on current power and alert state."""
	var alert_level: int = 0
	if _core:
		alert_level = _core.get_alert_state()

	# Alert modifiers
	var shield_regen_modifier: float = 1.0
	var cooldown_modifier: float = 1.0

	match alert_level:
		0:  # GREEN
			shield_regen_modifier = 1.0
			cooldown_modifier = 1.0
		1:  # YELLOW
			shield_regen_modifier = 1.0
			cooldown_modifier = 0.95  # 5% faster
		2:  # RED
			shield_regen_modifier = 1.25  # 25% faster regen
			cooldown_modifier = 0.85  # 15% faster cooldowns

	# Shield regeneration: base * (shields_power / 25) * alert_modifier
	var power_factor: float = _shields_power / 25.0
	_current_regen_rate = BASE_SHIELD_REGEN_RATE * power_factor * shield_regen_modifier

	# Weapon cooldowns: base / (weapons_power / 25) * alert_modifier
	# Higher power = shorter cooldown
	var weapons_factor: float = maxf(_weapons_power / 25.0, 0.5)  # Min 50% effect
	_effective_phaser_cooldown = (BASE_PHASER_COOLDOWN / weapons_factor) * cooldown_modifier
	_effective_torpedo_cooldown = (BASE_TORPEDO_COOLDOWN / weapons_factor) * cooldown_modifier

	# Target lock time: base / (sensors_power / 25)
	var sensors_factor: float = maxf(_sensors_power / 25.0, 0.5)
	_effective_lock_time = BASE_TARGET_LOCK_TIME / sensors_factor
