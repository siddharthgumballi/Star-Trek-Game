extends Node
class_name CinematicEffectsManager
## Master controller for all cinematic visual effects
## Phase 4: Advanced Cinematic Presentation Layer
##
## Toggle all effects with: cinematic_effects_enabled
## Individual systems can be toggled separately

signal effects_toggled(enabled: bool)

# =============================================================================
# MASTER TOGGLE
# =============================================================================

@export var cinematic_effects_enabled: bool = true:
	set(value):
		cinematic_effects_enabled = value
		_apply_effects_state()
		emit_signal("effects_toggled", value)

# =============================================================================
# SUBSYSTEM REFERENCES
# =============================================================================

var shield_visuals: Node = null
var weapon_visuals: Node = null
var alert_lighting: Node = null
var engine_visuals: Node = null
var camera_effects: Node = null

# External references
var _starship_core: Node = null
var _ship_controller: Node3D = null
var _warp_drive: Node3D = null
var _camera: Camera3D = null
var _tactical: Node = null

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	call_deferred("_initialize")

func _initialize() -> void:
	_resolve_references()
	_create_subsystems()
	_connect_signals()
	print("[CINEMATIC] Effects manager initialized (enabled: %s)" % cinematic_effects_enabled)

func _resolve_references() -> void:
	_starship_core = _find_node_by_class("StarshipCore")
	_ship_controller = _find_node_by_class("ShipController")
	_warp_drive = _find_node_by_class("WarpDrive")
	_camera = _find_camera()

	if _starship_core:
		_tactical = _starship_core.get_subsystem("tactical")

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

func _find_camera() -> Camera3D:
	var cameras: Array = get_tree().get_nodes_in_group("camera")
	if not cameras.is_empty():
		return cameras[0]
	# Search for any Camera3D
	return _find_camera_recursive(get_tree().current_scene)

func _find_camera_recursive(node: Node) -> Camera3D:
	if node is Camera3D:
		return node
	for child in node.get_children():
		var result: Camera3D = _find_camera_recursive(child)
		if result:
			return result
	return null

# =============================================================================
# SUBSYSTEM CREATION
# =============================================================================

func _create_subsystems() -> void:
	# Shield Visuals
	var shield_script: Script = load("res://scripts/visual/shield_visual_system.gd")
	if shield_script:
		shield_visuals = Node.new()
		shield_visuals.set_script(shield_script)
		shield_visuals.name = "ShieldVisuals"
		add_child(shield_visuals)

	# Weapon Visuals
	var weapon_script: Script = load("res://scripts/visual/weapon_visual_system.gd")
	if weapon_script:
		weapon_visuals = Node.new()
		weapon_visuals.set_script(weapon_script)
		weapon_visuals.name = "WeaponVisuals"
		add_child(weapon_visuals)

	# Alert Lighting
	var alert_script: Script = load("res://scripts/visual/alert_lighting_system.gd")
	if alert_script:
		alert_lighting = Node.new()
		alert_lighting.set_script(alert_script)
		alert_lighting.name = "AlertLighting"
		add_child(alert_lighting)

	# Engine Visuals
	var engine_script: Script = load("res://scripts/visual/engine_visual_system.gd")
	if engine_script:
		engine_visuals = Node.new()
		engine_visuals.set_script(engine_script)
		engine_visuals.name = "EngineVisuals"
		add_child(engine_visuals)

	# Camera Effects
	var camera_script: Script = load("res://scripts/visual/camera_effects_system.gd")
	if camera_script:
		camera_effects = Node.new()
		camera_effects.set_script(camera_script)
		camera_effects.name = "CameraEffects"
		add_child(camera_effects)

func _connect_signals() -> void:
	# Connect to starship core signals
	if _starship_core:
		if _starship_core.has_signal("alert_changed"):
			_starship_core.alert_changed.connect(_on_alert_changed)
		if _starship_core.has_signal("power_changed"):
			_starship_core.power_changed.connect(_on_power_changed)

	# Connect to tactical signals
	if _tactical:
		if _tactical.has_signal("shields_changed"):
			_tactical.shields_changed.connect(_on_shields_changed)
		if _tactical.has_signal("weapon_fired"):
			_tactical.weapon_fired.connect(_on_weapon_fired)

	# Connect to warp drive signals
	if _warp_drive:
		if _warp_drive.has_signal("warp_charging_started"):
			_warp_drive.warp_charging_started.connect(_on_warp_charging)
		if _warp_drive.has_signal("warp_engaged"):
			_warp_drive.warp_engaged.connect(_on_warp_engaged)
		if _warp_drive.has_signal("warp_disengaged"):
			_warp_drive.warp_disengaged.connect(_on_warp_disengaged)

# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_alert_changed(level: int) -> void:
	if not cinematic_effects_enabled:
		return
	if alert_lighting and alert_lighting.has_method("set_alert_level"):
		alert_lighting.set_alert_level(level)
	if camera_effects and level == 2:  # RED alert
		camera_effects.trigger_shake("alert", 0.3, 0.02)

func _on_power_changed(distribution: Dictionary) -> void:
	if not cinematic_effects_enabled:
		return
	if engine_visuals and engine_visuals.has_method("update_power"):
		engine_visuals.update_power(distribution)
	if shield_visuals and shield_visuals.has_method("update_power"):
		shield_visuals.update_power(distribution.get("shields", 25.0))
	if weapon_visuals and weapon_visuals.has_method("update_power"):
		weapon_visuals.update_power(distribution.get("weapons", 25.0))

func _on_shields_changed(strength: float, is_raised: bool) -> void:
	if not cinematic_effects_enabled:
		return
	if shield_visuals and shield_visuals.has_method("update_shields"):
		shield_visuals.update_shields(strength, is_raised)

func _on_weapon_fired(weapon_type: String, target: String) -> void:
	if not cinematic_effects_enabled:
		return

	if weapon_type == "phasers":
		if weapon_visuals and weapon_visuals.has_method("fire_phasers"):
			weapon_visuals.fire_phasers(target)
		if camera_effects:
			camera_effects.trigger_shake("phaser", 0.15, 0.01)
	elif weapon_type == "torpedoes":
		if weapon_visuals and weapon_visuals.has_method("fire_torpedo"):
			weapon_visuals.fire_torpedo(target)
		if camera_effects:
			camera_effects.trigger_shake("torpedo", 0.25, 0.015)

func _on_warp_charging(warp_factor: float) -> void:
	if not cinematic_effects_enabled:
		return
	if engine_visuals and engine_visuals.has_method("start_warp_charge"):
		engine_visuals.start_warp_charge()
	if camera_effects and camera_effects.has_method("start_warp_charge_fov"):
		camera_effects.start_warp_charge_fov()

func _on_warp_engaged(warp_factor: float) -> void:
	if not cinematic_effects_enabled:
		return
	if engine_visuals and engine_visuals.has_method("set_warp_active"):
		engine_visuals.set_warp_active(true, warp_factor)

func _on_warp_disengaged() -> void:
	if not cinematic_effects_enabled:
		return
	if engine_visuals and engine_visuals.has_method("set_warp_active"):
		engine_visuals.set_warp_active(false, 0.0)
	if camera_effects and camera_effects.has_method("end_warp_charge_fov"):
		camera_effects.end_warp_charge_fov()

# =============================================================================
# EFFECTS STATE
# =============================================================================

func _apply_effects_state() -> void:
	var subsystems: Array = [shield_visuals, weapon_visuals, alert_lighting, engine_visuals, camera_effects]

	for subsystem in subsystems:
		if subsystem and subsystem.has_method("set_enabled"):
			subsystem.set_enabled(cinematic_effects_enabled)

# =============================================================================
# PUBLIC API
# =============================================================================

func trigger_shield_impact(impact_point: Vector3, intensity: float = 1.0) -> void:
	if not cinematic_effects_enabled:
		return
	if shield_visuals and shield_visuals.has_method("trigger_impact"):
		shield_visuals.trigger_impact(impact_point, intensity)

func get_camera() -> Camera3D:
	return _camera

func get_ship() -> Node3D:
	return _ship_controller
