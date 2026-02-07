extends Node
class_name EngineVisualSystem
## Engine glow effects based on power, impulse, and warp state
## Nacelle glow, heat shimmer, warp charge buildup

# =============================================================================
# CONFIGURATION
# =============================================================================

const BASE_GLOW_ENERGY: float = 1.0
const WARP_GLOW_MULTIPLIER: float = 3.0
const IMPULSE_GLOW_MULTIPLIER: float = 1.5
const CHARGE_GLOW_MULTIPLIER: float = 2.0
const GLOW_TRANSITION_TIME: float = 0.5
const SHIMMER_INTENSITY: float = 0.3

# Nacelle positions (relative to ship center) - Galaxy class approximate
# Nacelles are on pylons behind and above the engineering section
const NACELLE_POSITIONS: Array = [
	Vector3(-12, 8, 35),   # Left nacelle (port)
	Vector3(12, 8, 35)     # Right nacelle (starboard)
]

# =============================================================================
# STATE
# =============================================================================

var _enabled: bool = true
var _ship: Node3D = null
var _warp_drive: Node3D = null

# Engine power state
var _engine_power: float = 25.0
var _impulse_level: float = 0.0
var _warp_active: bool = false
var _warp_charging: bool = false
var _warp_factor: float = 0.0

# Visual components
var _nacelle_lights: Array = []  # OmniLight3D array
var _nacelle_meshes: Array = []  # MeshInstance3D array for glow
var _shimmer_particles: Array = []  # GPUParticles3D array

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	call_deferred("_initialize")

func _initialize() -> void:
	_find_references()
	_create_nacelle_effects()
	_connect_signals()

func _find_references() -> void:
	var parent: Node = get_parent()
	if parent and parent.has_method("get_ship"):
		_ship = parent.get_ship()
	if not _ship:
		_ship = _find_node_by_class("ShipController")

	_warp_drive = _find_node_by_class("WarpDrive")

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

func _connect_signals() -> void:
	if _warp_drive:
		if _warp_drive.has_signal("warp_charging_started"):
			_warp_drive.warp_charging_started.connect(_on_warp_charging)
		if _warp_drive.has_signal("warp_engaged"):
			_warp_drive.warp_engaged.connect(_on_warp_engaged)
		if _warp_drive.has_signal("warp_disengaged"):
			_warp_drive.warp_disengaged.connect(_on_warp_disengaged)

# =============================================================================
# NACELLE EFFECTS CREATION
# =============================================================================

func _create_nacelle_effects() -> void:
	if not _ship:
		return

	for i in range(NACELLE_POSITIONS.size()):
		var pos: Vector3 = NACELLE_POSITIONS[i]
		_create_nacelle_light(pos, i)
		_create_nacelle_glow_mesh(pos, i)
		_create_heat_shimmer(pos, i)

func _create_nacelle_light(position: Vector3, index: int) -> void:
	var light: OmniLight3D = OmniLight3D.new()
	light.name = "NacelleLight_%d" % index
	light.light_color = Color(0.3, 0.5, 1.0)  # Blue warp glow
	light.light_energy = BASE_GLOW_ENERGY
	light.omni_range = 25.0
	light.omni_attenuation = 1.5

	_ship.add_child(light)
	light.position = position
	_nacelle_lights.append(light)

func _create_nacelle_glow_mesh(position: Vector3, index: int) -> void:
	# Skip creating visible mesh - just use lights for subtle glow
	# The original mesh was too large and distracting
	# Only create if we want visible nacelle glow (disabled by default)
	var create_visible_mesh: bool = false

	if not create_visible_mesh:
		_nacelle_meshes.append(null)  # Placeholder to maintain array alignment
		return

	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "NacelleGlow_%d" % index

	# Create small sphere for subtle glow point (not a huge capsule)
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	mesh_instance.mesh = sphere

	# Emissive material - very subtle
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.3, 0.5, 1.0, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.5, 1.0)
	mat.emission_energy_multiplier = BASE_GLOW_ENERGY
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_instance.material_override = mat

	_ship.add_child(mesh_instance)
	mesh_instance.position = position
	_nacelle_meshes.append(mesh_instance)

func _create_heat_shimmer(position: Vector3, index: int) -> void:
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.name = "HeatShimmer_%d" % index
	particles.amount = 20
	particles.lifetime = 1.0
	particles.emitting = false

	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(1, 1, 5)
	mat.direction = Vector3(0, 0, 1)
	mat.spread = 15.0
	mat.initial_velocity_min = 10.0
	mat.initial_velocity_max = 30.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.5
	mat.scale_max = 1.5
	mat.color = Color(0.5, 0.7, 1.0, 0.3)
	particles.process_material = mat

	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.5
	var mesh_mat: StandardMaterial3D = StandardMaterial3D.new()
	mesh_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_mat.albedo_color = Color(0.5, 0.7, 1.0, 0.2)
	mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mesh_mat
	particles.draw_pass_1 = mesh

	_ship.add_child(particles)
	particles.position = position + Vector3(0, 0, 10)  # Behind nacelle
	_shimmer_particles.append(particles)

# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_warp_charging(warp_factor: float) -> void:
	_warp_charging = true
	_warp_factor = warp_factor
	_update_engine_visuals()

func _on_warp_engaged(warp_factor: float) -> void:
	_warp_charging = false
	_warp_active = true
	_warp_factor = warp_factor
	_update_engine_visuals()

func _on_warp_disengaged() -> void:
	_warp_active = false
	_warp_charging = false
	_warp_factor = 0.0
	_update_engine_visuals()

# =============================================================================
# PROCESS
# =============================================================================

func _process(delta: float) -> void:
	if not _enabled:
		return

	_update_impulse_from_ship()

func _update_impulse_from_ship() -> void:
	if not _ship:
		return

	# Get impulse level from ship controller
	if _ship.has_method("get_impulse_fraction"):
		var new_impulse: float = _ship.get_impulse_fraction()
		if absf(new_impulse - _impulse_level) > 0.01:
			_impulse_level = new_impulse
			_update_engine_visuals()

# =============================================================================
# PUBLIC API
# =============================================================================

func set_enabled(enabled: bool) -> void:
	_enabled = enabled

	# Disable particles
	for particles in _shimmer_particles:
		if particles:
			particles.emitting = enabled and (_warp_active or _impulse_level > 0.3)

func update_power(distribution: Dictionary) -> void:
	_engine_power = distribution.get("engines", 25.0)
	_update_engine_visuals()

func start_warp_charge() -> void:
	_warp_charging = true
	_update_engine_visuals()

func set_warp_active(active: bool, warp_factor: float) -> void:
	_warp_active = active
	_warp_charging = false
	_warp_factor = warp_factor
	_update_engine_visuals()

# =============================================================================
# VISUAL UPDATE
# =============================================================================

func _update_engine_visuals() -> void:
	if not _enabled:
		return

	var target_energy: float = _calculate_glow_energy()
	var target_color: Color = _calculate_glow_color()

	_animate_nacelle_glow(target_energy, target_color)
	_update_shimmer_particles()

func _calculate_glow_energy() -> float:
	var energy: float = BASE_GLOW_ENERGY

	# Power allocation affects base glow
	var power_factor: float = _engine_power / 25.0
	energy *= (0.5 + power_factor * 0.5)

	# Impulse increases glow
	energy += _impulse_level * IMPULSE_GLOW_MULTIPLIER

	# Warp charging builds up
	if _warp_charging:
		energy *= CHARGE_GLOW_MULTIPLIER

	# Warp active is brightest
	if _warp_active:
		var warp_intensity: float = 1.0 + (_warp_factor / 10.0)
		energy *= WARP_GLOW_MULTIPLIER * warp_intensity

	return energy

func _calculate_glow_color() -> Color:
	if _warp_active:
		# Bright blue-white at warp
		var intensity: float = minf(_warp_factor / 5.0, 1.0)
		return Color(0.5 + intensity * 0.5, 0.7 + intensity * 0.3, 1.0)
	elif _warp_charging:
		# Building up - pulse between blue and white
		return Color(0.4, 0.6, 1.0)
	elif _impulse_level > 0.5:
		# High impulse - brighter blue
		return Color(0.4, 0.6, 1.0)
	else:
		# Idle - dim blue
		return Color(0.3, 0.5, 1.0)

func _animate_nacelle_glow(target_energy: float, target_color: Color) -> void:
	for light in _nacelle_lights:
		if light:
			var tween: Tween = create_tween()
			tween.tween_property(light, "light_energy", target_energy, GLOW_TRANSITION_TIME)
			tween.parallel().tween_property(light, "light_color", target_color, GLOW_TRANSITION_TIME)

	for mesh in _nacelle_meshes:
		if mesh and mesh.material_override:
			var mat: StandardMaterial3D = mesh.material_override
			var tween: Tween = create_tween()
			tween.tween_property(mat, "emission_energy_multiplier", target_energy, GLOW_TRANSITION_TIME)
			tween.parallel().tween_property(mat, "emission", target_color, GLOW_TRANSITION_TIME)
			tween.parallel().tween_property(mat, "albedo_color", Color(target_color.r, target_color.g, target_color.b, 0.3), GLOW_TRANSITION_TIME)

func _update_shimmer_particles() -> void:
	var should_emit: bool = _warp_active or _warp_charging or _impulse_level > 0.3

	for particles in _shimmer_particles:
		if particles:
			particles.emitting = should_emit and _enabled

			# Adjust particle speed based on state
			var mat: ParticleProcessMaterial = particles.process_material
			if mat:
				var speed_mult: float = 1.0
				if _warp_active:
					speed_mult = 3.0 + _warp_factor * 0.5
				elif _warp_charging:
					speed_mult = 2.0
				elif _impulse_level > 0:
					speed_mult = 1.0 + _impulse_level

				mat.initial_velocity_min = 10.0 * speed_mult
				mat.initial_velocity_max = 30.0 * speed_mult
