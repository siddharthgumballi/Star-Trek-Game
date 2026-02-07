extends Node
class_name WeaponVisualSystem
## TNG-accurate Star Trek weapon visual effects
## Based on actual TNG reference footage

# =============================================================================
# CONFIGURATION - TNG SCREEN ACCURATE
# =============================================================================

# Phaser configuration - TNG orange beam
const PHASER_BEAM_DURATION: float = 2.0
const PHASER_BEAM_WIDTH: float = 0.3  # Thin beam for 16-unit ship
const PHASER_COLOR: Color = Color(1.0, 0.45, 0.1)  # TNG orange
const PHASER_GLOW_COLOR: Color = Color(1.0, 0.7, 0.2)  # Bright yellow-orange emission
const PHASER_EMITTER_SIZE: float = 0.8  # Emission point sized for 16-unit ship

# Torpedo configuration - Red/orange starburst
const TORPEDO_SPEED: float = 600.0
const TORPEDO_ACCELERATION: float = 150.0
const TORPEDO_SIZE: float = 0.5  # Sized for 16-unit ship
const TORPEDO_COLOR: Color = Color(1.0, 0.25, 0.05)  # Deep red-orange
const TORPEDO_GLOW_COLOR: Color = Color(1.0, 0.4, 0.1)  # Orange glow
const TORPEDO_SPIKE_COUNT: int = 6  # Star spikes
const TORPEDO_PULSE_RATE: float = 12.0

# Impact effects - scaled for 16-unit ship
const IMPACT_FLASH_INTENSITY: float = 8.0
const IMPACT_FLASH_RANGE: float = 30.0

# =============================================================================
# WEAPON HARDPOINTS - Positioned at ship origin
# Will fire from ship center - the beam extends TO the target
# =============================================================================

# Phaser arrays - fire from ship center (offset will be adjusted visually)
const GALAXY_PHASER_ARRAYS: Array = [
	{"pos": Vector3.ZERO, "name": "Main Array"},
]

# Torpedo launchers - fire from ship center
const GALAXY_TORPEDO_LAUNCHERS: Array = [
	{"pos": Vector3.ZERO, "name": "Forward Launcher"},
]

# =============================================================================
# AUDIO
# =============================================================================

const PHASER_SOUND_PATH: String = "res://assets/audio/weapons/tng_phaser.mp3"
const TORPEDO_SOUND_PATH: String = "res://assets/audio/weapons/tng_torpedo.mp3"

var _phaser_audio: AudioStreamPlayer = null
var _torpedo_audio: AudioStreamPlayer = null

# =============================================================================
# STATE
# =============================================================================

var _enabled: bool = true
var _ship: Node3D = null
var _weapons_power: float = 25.0

var _active_phasers: Array = []
var _active_torpedoes: Array = []
var _phaser_array_index: int = 0
var _ship_model: Node3D = null  # The actual visual model

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	call_deferred("_initialize")

func _initialize() -> void:
	_find_ship()
	_setup_audio()
	if _ship:
		print("[WEAPONS VFX] TNG-accurate weapon system online")
	else:
		print("[WEAPONS VFX] Warning: Ship not found, searching again...")
		await get_tree().create_timer(0.5).timeout
		_find_ship()

func _setup_audio() -> void:
	# Phaser sound
	_phaser_audio = AudioStreamPlayer.new()
	_phaser_audio.name = "PhaserAudio"
	_phaser_audio.volume_db = -5.0  # Slightly quieter
	if ResourceLoader.exists(PHASER_SOUND_PATH):
		_phaser_audio.stream = load(PHASER_SOUND_PATH)
	add_child(_phaser_audio)

	# Torpedo sound
	_torpedo_audio = AudioStreamPlayer.new()
	_torpedo_audio.name = "TorpedoAudio"
	_torpedo_audio.volume_db = -3.0
	if ResourceLoader.exists(TORPEDO_SOUND_PATH):
		_torpedo_audio.stream = load(TORPEDO_SOUND_PATH)
	add_child(_torpedo_audio)

	print("[WEAPONS VFX] Audio loaded")

func _find_ship() -> void:
	var parent: Node = get_parent()
	if parent and parent.has_method("get_ship"):
		_ship = parent.get_ship()

	if not _ship:
		_ship = _find_node_by_class("ShipController")

	if _ship:
		print("[WEAPONS VFX] Ship controller found: ", _ship.name)
		print("[WEAPONS VFX] Ship controller position: ", _ship.global_position)

		# Find the actual visual model for accurate weapon positioning
		var model_loader = _ship.get_node_or_null("ModelLoader")
		if model_loader:
			# The visual model is usually named "ShipMesh"
			_ship_model = model_loader.get_node_or_null("ShipMesh")
			if _ship_model:
				print("[WEAPONS VFX] Visual model found: %s" % _ship_model.name)
				print("[WEAPONS VFX] Model global position: %s" % _ship_model.global_position)
				print("[WEAPONS VFX] Model local position: %s" % _ship_model.position)
				print("[WEAPONS VFX] Model scale: %s" % _ship_model.scale)
			else:
				# Try first child
				for child in model_loader.get_children():
					if child is Node3D:
						_ship_model = child
						print("[WEAPONS VFX] Using model: %s" % _ship_model.name)
						break

func _find_node_by_class(class_name_str: String) -> Node:
	var root: Node = get_tree().current_scene
	if not root:
		return null
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
# PROCESS
# =============================================================================

func _process(delta: float) -> void:
	if not _enabled:
		return
	_update_phasers(delta)
	_update_torpedoes(delta)

func _update_phasers(delta: float) -> void:
	var to_remove: Array = []

	for phaser_data in _active_phasers:
		var phaser: Node3D = phaser_data["node"]
		var target: Node3D = phaser_data["target"]
		var time: float = phaser_data["time"]
		var duration: float = phaser_data["duration"]
		var emitter_offset: Vector3 = phaser_data["emitter_offset"]

		if not is_instance_valid(phaser):
			to_remove.append(phaser_data)
			continue

		phaser_data["time"] = time + delta
		var progress: float = time / duration

		if _ship:
			# Use visual model position if available, otherwise ship controller
			var ship_pos: Vector3
			var ship_basis: Basis
			if _ship_model and is_instance_valid(_ship_model):
				ship_pos = _ship_model.global_position
				ship_basis = _ship_model.global_transform.basis
			else:
				ship_pos = _ship.global_position
				ship_basis = _ship.global_transform.basis

			# Calculate world position of emitter on ship
			var emitter_world: Vector3 = ship_pos + ship_basis * emitter_offset

			# Get target position
			var target_pos: Vector3
			if target and is_instance_valid(target):
				target_pos = target.global_position
			else:
				# Fire forward if no target - use ship's forward direction
				target_pos = emitter_world + (-ship_basis.z * 2000.0)

			# Update beam geometry
			_update_phaser_beam(phaser, emitter_world, target_pos, time, progress)

		if time >= duration:
			_end_phaser(phaser)
			to_remove.append(phaser_data)

	for data in to_remove:
		_active_phasers.erase(data)

func _update_phaser_beam(phaser: Node3D, start: Vector3, end: Vector3, time: float, progress: float) -> void:
	var beam: MeshInstance3D = phaser.get_node_or_null("Beam")
	var emitter_glow: MeshInstance3D = phaser.get_node_or_null("EmitterGlow")
	var emitter_light: OmniLight3D = phaser.get_node_or_null("EmitterLight")

	var direction: Vector3 = end - start
	var distance: float = direction.length()

	# Calculate intensity - ramp up, sustain, ramp down
	var intensity: float = 1.0
	if progress < 0.1:
		intensity = progress / 0.1
	elif progress > 0.85:
		intensity = (1.0 - progress) / 0.15

	# Subtle flicker
	intensity *= (0.95 + sin(time * 20.0) * 0.05)

	# Update beam - position at MIDPOINT so cylinder spans start to end
	if beam:
		var midpoint: Vector3 = (start + end) / 2.0
		beam.global_position = midpoint
		if distance > 0.1:
			beam.look_at(end, Vector3.UP)
			beam.rotate_object_local(Vector3.RIGHT, PI / 2)
		beam.scale = Vector3(1, distance, 1)

		if beam.material_override:
			beam.material_override.set_shader_parameter("intensity", intensity)
			beam.material_override.set_shader_parameter("time_val", time)

	# Update emitter glow position (stays at origin point on ship)
	if emitter_glow:
		emitter_glow.global_position = start
		if emitter_glow.material_override:
			var mat: StandardMaterial3D = emitter_glow.material_override
			mat.emission_energy_multiplier = 8.0 * intensity

	if emitter_light:
		emitter_light.global_position = start
		emitter_light.light_energy = 6.0 * intensity

func _update_torpedoes(delta: float) -> void:
	var to_remove: Array = []

	for torpedo_data in _active_torpedoes:
		var torpedo: Node3D = torpedo_data["node"]
		var target: Node3D = torpedo_data["target"]
		var time: float = torpedo_data["time"]
		var speed: float = torpedo_data["speed"]

		if not is_instance_valid(torpedo):
			to_remove.append(torpedo_data)
			continue

		torpedo_data["time"] = time + delta
		torpedo_data["speed"] = minf(speed + TORPEDO_ACCELERATION * delta, TORPEDO_SPEED * 1.5)
		speed = torpedo_data["speed"]

		# Update starburst pulse effect
		_update_torpedo_starburst(torpedo, time)

		# Move toward target
		if target and is_instance_valid(target):
			var current_dir: Vector3 = -torpedo.global_transform.basis.z
			var to_target: Vector3 = (target.global_position - torpedo.global_position).normalized()
			var homing: float = 0.015
			var new_dir: Vector3 = current_dir.lerp(to_target, homing).normalized()
			torpedo.look_at(torpedo.global_position + new_dir, Vector3.UP)
			torpedo.global_position += new_dir * speed * delta

			var dist: float = torpedo.global_position.distance_to(target.global_position)
			if dist < 15.0:  # Impact distance scaled for smaller ship
				_torpedo_impact(torpedo.global_position, target)
				torpedo.queue_free()
				to_remove.append(torpedo_data)
				continue
		else:
			torpedo.global_position += -torpedo.global_transform.basis.z * speed * delta

		if time > 15.0:
			torpedo.queue_free()
			to_remove.append(torpedo_data)

	for data in to_remove:
		_active_torpedoes.erase(data)

func _update_torpedo_starburst(torpedo: Node3D, time: float) -> void:
	var pulse: float = (sin(time * TORPEDO_PULSE_RATE) * 0.4 + 0.6)

	# Update all spike meshes
	for i in range(TORPEDO_SPIKE_COUNT):
		var spike: MeshInstance3D = torpedo.get_node_or_null("Spike%d" % i)
		if spike and spike.material_override:
			var mat: StandardMaterial3D = spike.material_override
			mat.emission_energy_multiplier = 5.0 + pulse * 3.0

	# Update core glow
	var core: MeshInstance3D = torpedo.get_node_or_null("Core")
	if core and core.material_override:
		var mat: StandardMaterial3D = core.material_override
		mat.emission_energy_multiplier = 8.0 + pulse * 4.0

	# Update light
	var light: OmniLight3D = torpedo.get_node_or_null("Light")
	if light:
		light.light_energy = 4.0 + pulse * 2.0

# =============================================================================
# PUBLIC API
# =============================================================================

func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not enabled:
		for phaser_data in _active_phasers:
			if is_instance_valid(phaser_data["node"]):
				phaser_data["node"].queue_free()
		_active_phasers.clear()
		for torpedo_data in _active_torpedoes:
			if is_instance_valid(torpedo_data["node"]):
				torpedo_data["node"].queue_free()
		_active_torpedoes.clear()

func update_power(weapons_power: float) -> void:
	_weapons_power = weapons_power

func fire_phasers(target_name: String) -> void:
	if not _enabled:
		return

	if not _ship:
		_find_ship()
		if not _ship:
			print("[WEAPONS VFX] Cannot fire phasers - no ship found")
			return

	var target: Node3D = _find_target(target_name)

	# Get the phaser array position
	var array_data: Dictionary = GALAXY_PHASER_ARRAYS[_phaser_array_index]
	_phaser_array_index = (_phaser_array_index + 1) % GALAXY_PHASER_ARRAYS.size()

	# Play phaser sound
	if _phaser_audio and _phaser_audio.stream:
		_phaser_audio.play()

	# Debug: print ship info
	print("[WEAPONS VFX] === PHASER FIRE DEBUG ===")
	print("  _ship controller: %s at %s" % [_ship.name if _ship else "NULL", _ship.global_position if _ship else "N/A"])
	if _ship_model:
		print("  _ship_model: %s at %s" % [_ship_model.name, _ship_model.global_position])
	else:
		print("  _ship_model: NOT FOUND (using controller position)")
	if target:
		print("  Target: %s at %s" % [target.name, target.global_position])
	else:
		print("  Target: NONE (firing forward)")

	_create_phaser_beam(target, array_data["pos"])

func fire_torpedo(target_name: String) -> void:
	if not _enabled:
		return

	if not _ship:
		_find_ship()
		if not _ship:
			print("[WEAPONS VFX] Cannot fire torpedo - no ship found")
			return

	var target: Node3D = _find_target(target_name)
	var launcher: Dictionary = GALAXY_TORPEDO_LAUNCHERS[0]
	var world_pos: Vector3 = _ship.global_position + _ship.global_transform.basis * launcher["pos"]
	print("[WEAPONS VFX] Torpedo away from %s" % launcher["name"])
	print("  Ship position: %s" % _ship.global_position)
	print("  Launcher offset: %s" % launcher["pos"])
	print("  World position: %s" % world_pos)

	# Play torpedo sound
	if _torpedo_audio and _torpedo_audio.stream:
		_torpedo_audio.play()

	_create_torpedo(target)

# =============================================================================
# PHASER BEAM CREATION - TNG Orange Beam from Saucer Rim
# =============================================================================

func _create_phaser_beam(target: Node3D, emitter_offset: Vector3) -> void:
	var phaser_node: Node3D = Node3D.new()
	phaser_node.name = "PhaserBeam"

	# === THE BEAM - Orange continuous beam ===
	var beam: MeshInstance3D = MeshInstance3D.new()
	beam.name = "Beam"

	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = PHASER_BEAM_WIDTH
	cyl.bottom_radius = PHASER_BEAM_WIDTH * 0.8  # Slight taper
	cyl.height = 1.0
	cyl.radial_segments = 12
	beam.mesh = cyl

	# Shader for glowing beam effect
	var beam_mat: ShaderMaterial = ShaderMaterial.new()
	beam_mat.shader = _create_beam_shader()
	beam_mat.set_shader_parameter("beam_color", PHASER_COLOR)
	beam_mat.set_shader_parameter("glow_color", PHASER_GLOW_COLOR)
	beam_mat.set_shader_parameter("intensity", 1.0)
	beam.material_override = beam_mat
	phaser_node.add_child(beam)

	# === EMITTER GLOW - Small subtle point where beam originates ===
	var emitter_glow: MeshInstance3D = MeshInstance3D.new()
	emitter_glow.name = "EmitterGlow"

	var glow_sphere: SphereMesh = SphereMesh.new()
	glow_sphere.radius = 0.15  # Very small - just a hint of glow
	glow_sphere.height = 0.3
	glow_sphere.radial_segments = 8
	glow_sphere.rings = 4
	emitter_glow.mesh = glow_sphere

	var glow_mat: StandardMaterial3D = StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.albedo_color = PHASER_GLOW_COLOR
	glow_mat.emission_enabled = true
	glow_mat.emission = PHASER_GLOW_COLOR
	glow_mat.emission_energy_multiplier = 4.0  # Reduced
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.albedo_color.a = 0.9
	emitter_glow.material_override = glow_mat
	phaser_node.add_child(emitter_glow)

	# === EMITTER LIGHT - Illuminates the ship hull ===
	var emitter_light: OmniLight3D = OmniLight3D.new()
	emitter_light.name = "EmitterLight"
	emitter_light.light_color = PHASER_GLOW_COLOR
	emitter_light.light_energy = 4.0
	emitter_light.omni_range = 8.0  # Scaled for 16-unit ship
	emitter_light.omni_attenuation = 1.2
	phaser_node.add_child(emitter_light)

	# Add to scene
	get_tree().current_scene.add_child(phaser_node)

	# Calculate initial position
	var start_pos: Vector3 = _ship.global_position + _ship.global_transform.basis * emitter_offset
	phaser_node.global_position = start_pos

	# Track
	var power_mult: float = _weapons_power / 25.0
	_active_phasers.append({
		"node": phaser_node,
		"target": target,
		"time": 0.0,
		"duration": PHASER_BEAM_DURATION * power_mult,
		"emitter_offset": emitter_offset
	})

	# Impact effect at target
	if target:
		_create_phaser_impact(target)

func _create_beam_shader() -> Shader:
	var shader: Shader = Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_disabled, unshaded;

uniform vec4 beam_color : source_color = vec4(1.0, 0.45, 0.1, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.7, 0.2, 1.0);
uniform float intensity : hint_range(0.0, 2.0) = 1.0;
uniform float time_val : hint_range(0.0, 1000.0) = 0.0;

void fragment() {
	// Distance from beam center (UV.x goes 0-1 around cylinder)
	float dist = abs(UV.x - 0.5) * 2.0;

	// Core is brightest in center
	float core = 1.0 - smoothstep(0.0, 0.4, dist);
	core = pow(core, 1.5);

	// Outer glow extends further
	float outer = 1.0 - smoothstep(0.0, 1.0, dist);
	outer = pow(outer, 0.7);

	// Energy shimmer along beam length
	float shimmer = sin(UV.y * 80.0 - TIME * 30.0) * 0.1 + 0.9;
	shimmer *= sin(UV.y * 40.0 + TIME * 20.0) * 0.05 + 0.95;

	// Blend core and outer colors
	vec3 color = mix(beam_color.rgb, glow_color.rgb, core * 0.7);

	// Apply intensity and shimmer
	float final_intensity = intensity * shimmer;

	ALBEDO = color * final_intensity * 2.0;
	EMISSION = color * final_intensity * 3.0;
	ALPHA = outer * beam_color.a * intensity;
}
"""
	return shader

func _create_phaser_impact(target: Node3D) -> void:
	if not is_instance_valid(target):
		return

	# Impact glow at target
	var impact: GPUParticles3D = GPUParticles3D.new()
	impact.amount = 30
	impact.lifetime = 0.4
	impact.explosiveness = 0.0

	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 1.5  # Scaled for 16-unit ship
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 90.0
	mat.initial_velocity_min = 5.0
	mat.initial_velocity_max = 15.0
	mat.gravity = Vector3.ZERO
	mat.damping_min = 10.0
	mat.damping_max = 20.0
	mat.scale_min = 0.15
	mat.scale_max = 0.5
	mat.color = PHASER_COLOR
	impact.process_material = mat

	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.2  # Scaled
	var mesh_mat: StandardMaterial3D = StandardMaterial3D.new()
	mesh_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_mat.albedo_color = PHASER_GLOW_COLOR
	mesh_mat.emission_enabled = true
	mesh_mat.emission = PHASER_GLOW_COLOR
	mesh_mat.emission_energy_multiplier = 3.0
	mesh.material = mesh_mat
	impact.draw_pass_1 = mesh

	impact.global_position = target.global_position
	get_tree().current_scene.add_child(impact)

	var timer: SceneTreeTimer = get_tree().create_timer(PHASER_BEAM_DURATION + 1.0)
	timer.timeout.connect(impact.queue_free)

func _end_phaser(phaser: Node3D) -> void:
	if not is_instance_valid(phaser):
		return

	var tween: Tween = create_tween()
	tween.set_parallel(true)

	var emitter_glow: MeshInstance3D = phaser.get_node_or_null("EmitterGlow")
	var emitter_light: OmniLight3D = phaser.get_node_or_null("EmitterLight")
	var beam: MeshInstance3D = phaser.get_node_or_null("Beam")

	if emitter_light:
		tween.tween_property(emitter_light, "light_energy", 0.0, 0.3)
	if emitter_glow and emitter_glow.material_override:
		tween.tween_property(emitter_glow.material_override, "emission_energy_multiplier", 0.0, 0.3)
	if beam and beam.material_override:
		tween.tween_method(func(val): beam.material_override.set_shader_parameter("intensity", val), 1.0, 0.0, 0.3)

	tween.set_parallel(false)
	tween.tween_callback(phaser.queue_free)

# =============================================================================
# TORPEDO CREATION - Red/Orange Starburst (TNG Photon Torpedo)
# =============================================================================

func _create_torpedo(target: Node3D) -> void:
	var torpedo: Node3D = Node3D.new()
	torpedo.name = "PhotonTorpedo"

	# === CENTRAL CORE - Bright glowing sphere ===
	var core: MeshInstance3D = MeshInstance3D.new()
	core.name = "Core"

	var core_sphere: SphereMesh = SphereMesh.new()
	core_sphere.radius = TORPEDO_SIZE * 0.6
	core_sphere.height = TORPEDO_SIZE * 1.2
	core_sphere.radial_segments = 16
	core_sphere.rings = 8
	core.mesh = core_sphere

	var core_mat: StandardMaterial3D = StandardMaterial3D.new()
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.albedo_color = Color(1.0, 0.9, 0.7)  # White-hot center
	core_mat.emission_enabled = true
	core_mat.emission = Color(1.0, 0.8, 0.5)
	core_mat.emission_energy_multiplier = 10.0
	core.material_override = core_mat
	torpedo.add_child(core)

	# === STARBURST SPIKES - Radiating points ===
	for i in range(TORPEDO_SPIKE_COUNT):
		var spike: MeshInstance3D = MeshInstance3D.new()
		spike.name = "Spike%d" % i

		# Create elongated spike shape
		var spike_mesh: CylinderMesh = CylinderMesh.new()
		spike_mesh.top_radius = 0.1
		spike_mesh.bottom_radius = TORPEDO_SIZE * 0.4
		spike_mesh.height = TORPEDO_SIZE * 3.0
		spike.mesh = spike_mesh

		var spike_mat: StandardMaterial3D = StandardMaterial3D.new()
		spike_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		spike_mat.albedo_color = TORPEDO_COLOR
		spike_mat.emission_enabled = true
		spike_mat.emission = TORPEDO_GLOW_COLOR
		spike_mat.emission_energy_multiplier = 6.0
		spike_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		spike_mat.albedo_color.a = 0.8
		spike.material_override = spike_mat

		# Position spikes radiating outward in a star pattern
		var angle: float = (float(i) / TORPEDO_SPIKE_COUNT) * TAU
		spike.rotation = Vector3(0, 0, angle + PI / 2)
		spike.position = Vector3(0, 0, 0)

		torpedo.add_child(spike)

	# === ADDITIONAL DIAGONAL SPIKES for more star-like appearance ===
	for i in range(TORPEDO_SPIKE_COUNT):
		var spike2: MeshInstance3D = MeshInstance3D.new()
		spike2.name = "SpikeDiag%d" % i

		var spike_mesh2: CylinderMesh = CylinderMesh.new()
		spike_mesh2.top_radius = 0.05
		spike_mesh2.bottom_radius = TORPEDO_SIZE * 0.25
		spike_mesh2.height = TORPEDO_SIZE * 2.0
		spike2.mesh = spike_mesh2

		var spike_mat2: StandardMaterial3D = StandardMaterial3D.new()
		spike_mat2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		spike_mat2.albedo_color = TORPEDO_COLOR
		spike_mat2.emission_enabled = true
		spike_mat2.emission = TORPEDO_GLOW_COLOR
		spike_mat2.emission_energy_multiplier = 4.0
		spike_mat2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		spike_mat2.albedo_color.a = 0.6
		spike2.material_override = spike_mat2

		# Offset angle for secondary spikes
		var angle: float = (float(i) / TORPEDO_SPIKE_COUNT) * TAU + (TAU / (TORPEDO_SPIKE_COUNT * 2))
		spike2.rotation = Vector3(PI / 4, 0, angle + PI / 2)

		torpedo.add_child(spike2)

	# === OUTER GLOW HALO ===
	var halo: MeshInstance3D = MeshInstance3D.new()
	halo.name = "Halo"

	var halo_mesh: SphereMesh = SphereMesh.new()
	halo_mesh.radius = TORPEDO_SIZE * 1.5
	halo_mesh.height = TORPEDO_SIZE * 3.0
	halo.mesh = halo_mesh

	var halo_mat: StandardMaterial3D = StandardMaterial3D.new()
	halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_mat.albedo_color = Color(TORPEDO_GLOW_COLOR.r, TORPEDO_GLOW_COLOR.g, TORPEDO_GLOW_COLOR.b, 0.3)
	halo_mat.emission_enabled = true
	halo_mat.emission = TORPEDO_GLOW_COLOR
	halo_mat.emission_energy_multiplier = 2.0
	halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo.material_override = halo_mat
	torpedo.add_child(halo)

	# === POINT LIGHT ===
	var light: OmniLight3D = OmniLight3D.new()
	light.name = "Light"
	light.light_color = TORPEDO_GLOW_COLOR
	light.light_energy = 4.0
	light.omni_range = 15.0  # Scaled for 16-unit ship
	light.omni_attenuation = 1.3
	torpedo.add_child(light)

	# === TRAIL PARTICLES ===
	var trail: GPUParticles3D = _create_torpedo_trail()
	torpedo.add_child(trail)

	# Position at launcher - use visual model if available
	var launcher: Dictionary = GALAXY_TORPEDO_LAUNCHERS[0]
	var ship_pos: Vector3
	var ship_basis: Basis
	if _ship_model and is_instance_valid(_ship_model):
		ship_pos = _ship_model.global_position
		ship_basis = _ship_model.global_transform.basis
	else:
		ship_pos = _ship.global_position
		ship_basis = _ship.global_transform.basis

	torpedo.global_position = ship_pos + ship_basis * launcher["pos"]

	# Orient toward target
	if target and is_instance_valid(target):
		torpedo.look_at(target.global_position, Vector3.UP)
	else:
		torpedo.global_transform.basis = ship_basis

	get_tree().current_scene.add_child(torpedo)

	# Launch flash
	_create_launch_flash(torpedo.global_position)

	_active_torpedoes.append({
		"node": torpedo,
		"target": target,
		"time": 0.0,
		"speed": TORPEDO_SPEED * 0.3
	})

func _create_torpedo_trail() -> GPUParticles3D:
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.name = "Trail"
	particles.amount = 40
	particles.lifetime = 0.4
	particles.explosiveness = 0.0
	particles.local_coords = false

	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.15  # Scaled for small torpedo
	mat.direction = Vector3(0, 0, 1)
	mat.spread = 20.0
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 8.0
	mat.gravity = Vector3.ZERO
	mat.damping_min = 5.0
	mat.damping_max = 10.0
	mat.scale_min = 0.08
	mat.scale_max = 0.2
	mat.color = TORPEDO_GLOW_COLOR
	particles.process_material = mat

	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.1  # Scaled
	var mesh_mat: StandardMaterial3D = StandardMaterial3D.new()
	mesh_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_mat.albedo_color = TORPEDO_GLOW_COLOR
	mesh_mat.emission_enabled = true
	mesh_mat.emission = TORPEDO_GLOW_COLOR
	mesh_mat.emission_energy_multiplier = 3.0
	mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_mat.albedo_color.a = 0.7
	mesh.material = mesh_mat
	particles.draw_pass_1 = mesh

	particles.position = Vector3(0, 0, TORPEDO_SIZE)
	return particles

func _create_launch_flash(position: Vector3) -> void:
	var flash: OmniLight3D = OmniLight3D.new()
	flash.light_color = TORPEDO_GLOW_COLOR
	flash.light_energy = 6.0
	flash.omni_range = 15.0  # Scaled for 16-unit ship
	flash.global_position = position
	get_tree().current_scene.add_child(flash)

	var tween: Tween = create_tween()
	tween.tween_property(flash, "light_energy", 0.0, 0.4)
	tween.tween_callback(flash.queue_free)

# =============================================================================
# TORPEDO IMPACT
# =============================================================================

func _torpedo_impact(position: Vector3, target: Node3D) -> void:
	# Flash
	var flash: OmniLight3D = OmniLight3D.new()
	flash.light_color = Color(1.0, 0.7, 0.4)
	flash.light_energy = IMPACT_FLASH_INTENSITY
	flash.omni_range = IMPACT_FLASH_RANGE
	flash.global_position = position
	get_tree().current_scene.add_child(flash)

	var tween: Tween = create_tween()
	tween.tween_property(flash, "light_energy", 0.0, 0.8)
	tween.tween_callback(flash.queue_free)

	# Fireball
	_create_fireball(position)

	# Shockwave
	_create_shockwave(position)

func _create_fireball(position: Vector3) -> void:
	var fireball: GPUParticles3D = GPUParticles3D.new()
	fireball.amount = 100
	fireball.lifetime = 1.0
	fireball.explosiveness = 0.95
	fireball.one_shot = true
	fireball.emitting = true

	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 1.5  # Scaled for 16-unit ship
	mat.spread = 180.0
	mat.initial_velocity_min = 10.0
	mat.initial_velocity_max = 30.0
	mat.gravity = Vector3.ZERO
	mat.damping_min = 10.0
	mat.damping_max = 20.0
	mat.scale_min = 0.3
	mat.scale_max = 1.0

	var gradient: Gradient = Gradient.new()
	gradient.add_point(0.0, Color(1.0, 1.0, 0.9, 1.0))
	gradient.add_point(0.2, Color(1.0, 0.7, 0.3, 1.0))
	gradient.add_point(0.5, Color(1.0, 0.4, 0.1, 0.8))
	gradient.add_point(0.8, Color(0.8, 0.2, 0.05, 0.4))
	gradient.add_point(1.0, Color(0.3, 0.1, 0.05, 0.0))
	var gradient_tex: GradientTexture1D = GradientTexture1D.new()
	gradient_tex.gradient = gradient
	mat.color_ramp = gradient_tex

	fireball.process_material = mat

	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.3  # Scaled
	var mesh_mat: StandardMaterial3D = StandardMaterial3D.new()
	mesh_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_mat.vertex_color_use_as_albedo = true
	mesh_mat.emission_enabled = true
	mesh_mat.emission = Color(1.0, 0.5, 0.2)
	mesh_mat.emission_energy_multiplier = 2.0
	mesh.material = mesh_mat
	fireball.draw_pass_1 = mesh

	fireball.global_position = position
	get_tree().current_scene.add_child(fireball)

	get_tree().create_timer(3.0).timeout.connect(fireball.queue_free)

func _create_shockwave(position: Vector3) -> void:
	var ring: MeshInstance3D = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 1.0  # Scaled for 16-unit ship
	torus.outer_radius = 1.8
	torus.rings = 24
	torus.ring_segments = 24
	ring.mesh = torus

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.6, 0.3, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.5, 0.2)
	mat.emission_energy_multiplier = 2.0
	ring.material_override = mat

	ring.global_position = position
	ring.rotation_degrees = Vector3(90, 0, 0)
	ring.scale = Vector3(0.1, 0.1, 0.1)
	get_tree().current_scene.add_child(ring)

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(3.0, 3.0, 3.0), 0.8).set_ease(Tween.EASE_OUT)  # Scaled
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.8)
	tween.tween_property(mat, "emission_energy_multiplier", 0.0, 0.8)
	tween.set_parallel(false)
	tween.tween_callback(ring.queue_free)

# =============================================================================
# UTILITY
# =============================================================================

func _find_target(target_name: String) -> Node3D:
	if target_name.is_empty():
		return null

	var root: Node = get_tree().current_scene
	if root.has_method("get_all_planets"):
		var planets: Dictionary = root.get_all_planets()
		var target_lower: String = target_name.to_lower()
		for planet_name in planets:
			if planet_name.to_lower() == target_lower:
				return planets[planet_name]
	return null
