extends Node3D
class_name SectorSolRealistic
## Sector 001 - Sol System (Realistic Visual Version)
##
## TEXTURE SETUP INSTRUCTIONS:
## ===========================
## 1. Create folder: res://assets/textures/planets/
##
## 2. Download textures from Solar System Scope (free):
##    https://www.solarsystemscope.com/textures/
##
##    Download these files (2K versions are fine, 8K for highest quality):
##    - 2k_sun.jpg
##    - 2k_mercury.jpg
##    - 2k_venus_surface.jpg
##    - 2k_earth_daymap.jpg
##    - 2k_earth_nightmap.jpg (optional)
##    - 2k_earth_clouds.jpg (optional)
##    - 2k_moon.jpg
##    - 2k_mars.jpg
##    - 2k_jupiter.jpg
##    - 2k_saturn.jpg
##    - 2k_saturn_ring_alpha.png
##
## 3. Place all textures in res://assets/textures/planets/
##
## 4. The scene will automatically load them on startup
##
## SCALE NOTES:
## ============
## - Distances are heavily compressed (real Sol system is 4.5B km)
## - Planet sizes are exaggerated for visibility
## - Ratios between planets are roughly maintained
##
## TNG VISUAL STYLE:
## =================
## - Soft, cinematic lighting
## - Cool ambient tones
## - Planets should feel majestic and serene

const TEXTURE_BASE_PATH = "res://assets/textures/planets/"

# REALISTIC SCALE: 1 game unit = 1000 km
# Full impulse (0.25c) = 75 units/second
# Travel times at full impulse:
#   Earth to Moon: ~5 seconds
#   Earth to Mars: ~12 minutes (at closest approach)
#   Earth to Jupiter: ~2.3 hours
#
# Planet radii scaled up ~100x for visibility (otherwise they'd be invisible dots)
# Orbital motion disabled (imperceptible at this scale)

var planet_configs: Array[Dictionary] = [
	{
		"name": "Sun",
		"type": "star",
		"distance": 0,
		"radius": 700,  # Real: 696 units (696,340 km)
		"texture": "2k_sun.jpg",
		"rotation_speed": 0.001,
		"emission": 5.0,
		"orbital_speed": 0.0
	},
	{
		"name": "Mercury",
		"type": "planet",
		"distance": 57900,  # 57.9 million km
		"radius": 250,  # Scaled up for visibility (real: 2.4 units)
		"texture": "2k_mercury.jpg",
		"rotation_speed": 0.002,
		"color": Color(0.6, 0.55, 0.5),
		"orbital_angle": 0.8,
		"orbital_speed": 0.0
	},
	{
		"name": "Venus",
		"type": "planet",
		"distance": 108200,  # 108.2 million km
		"radius": 600,  # Scaled up (real: 6 units)
		"texture": "2k_venus_surface.jpg",
		"rotation_speed": -0.001,
		"color": Color(0.9, 0.8, 0.6),
		"orbital_angle": 2.4,
		"orbital_speed": 0.0
	},
	{
		"name": "Earth",
		"type": "earth",
		"distance": 149600,  # 149.6 million km (1 AU)
		"radius": 640,  # Scaled up (real: 6.4 units)
		"texture": "2k_earth_daymap.jpg",
		"texture_night": "2k_earth_nightmap.jpg",
		"texture_clouds": "2k_earth_clouds.jpg",
		"rotation_speed": 0.01,
		"orbital_angle": 0.0,
		"axial_tilt": 23.4,
		"orbital_speed": 0.0
	},
	{
		"name": "Moon",
		"type": "moon",
		"parent": "Earth",
		"distance": 1200,  # Scaled up from 384 to stay outside Earth's visual radius (640)
		"radius": 175,  # Scaled up (real: 1.7 units)
		"texture": "2k_moon.jpg",
		"rotation_speed": 0.005,
		"color": Color(0.75, 0.75, 0.75),
		"orbital_angle": 0.0,
		"orbital_speed": 0.01  # Moon orbit visible
	},
	{
		"name": "Starbase 1",
		"type": "starbase",
		"parent": "Earth",
		"distance": 900,  # Between Earth surface (640) and Moon orbit (1200)
		"radius": 120,  # Visual size of the station
		"rotation_speed": 0.003,  # Slow majestic rotation
		"orbital_angle": 2.0,  # Offset from Moon's position
		"orbital_speed": 0.006,  # Orbit around Earth
		"color": Color(0.7, 0.8, 0.9)
	},
	{
		"name": "Mars",
		"type": "planet",
		"distance": 227900,  # 227.9 million km
		"radius": 340,  # Scaled up (real: 3.4 units)
		"texture": "2k_mars.jpg",
		"rotation_speed": 0.009,
		"color": Color(0.85, 0.45, 0.25),
		"orbital_angle": 1.5,
		"axial_tilt": 25.2,
		"orbital_speed": 0.0
	},
	{
		"name": "Jupiter",
		"type": "planet",
		"distance": 778500,  # 778.5 million km
		"radius": 700,  # Scaled up 10x (real: 70 units)
		"texture": "2k_jupiter.jpg",
		"rotation_speed": 0.02,
		"color": Color(0.85, 0.8, 0.7),
		"orbital_angle": 3.2,
		"axial_tilt": 3.1,
		"orbital_speed": 0.0
	},
	{
		"name": "Saturn",
		"type": "saturn",
		"distance": 1434000,  # 1.434 billion km
		"radius": 580,  # Scaled up 10x (real: 58 units)
		"texture": "2k_saturn.jpg",
		"texture_ring": "2k_saturn_ring_alpha.png",
		"rotation_speed": 0.018,
		"color": Color(0.9, 0.85, 0.7),
		"orbital_angle": 4.5,
		"axial_tilt": 26.7,
		"ring_inner": 1.3,
		"ring_outer": 2.5,
		"orbital_speed": 0.0
	},
	{
		"name": "Uranus",
		"type": "planet",
		"distance": 2871000,  # 2.871 billion km
		"radius": 250,  # Scaled up 10x (real: 25 units)
		"texture": "2k_uranus.jpg",
		"rotation_speed": -0.015,
		"color": Color(0.6, 0.85, 0.9),
		"orbital_angle": 5.8,
		"axial_tilt": 97.8,
		"orbital_speed": 0.0
	},
	{
		"name": "Neptune",
		"type": "planet",
		"distance": 4495000,  # 4.495 billion km
		"radius": 250,  # Scaled up 10x (real: 25 units)
		"texture": "2k_neptune.jpg",
		"rotation_speed": 0.016,
		"color": Color(0.3, 0.5, 0.9),
		"orbital_angle": 1.2,
		"axial_tilt": 28.3,
		"orbital_speed": 0.0
	}
]

# Track orbital angles for animation
var _orbital_angles: Dictionary = {}

# Scene references
var _planets: Dictionary = {}
var _environment: WorldEnvironment
var _sun_light: DirectionalLight3D
var _player_spawn: Marker3D

@export_group("Spawn Settings")
## Spawn ~1000 units (1 million km) from Earth - about 2.6x Earth-Moon distance
@export var spawn_distance_from_earth: float = 1000.0
@export var spawn_height: float = 200.0

func _ready() -> void:
	_setup_environment()
	_setup_lighting()
	_create_all_bodies()
	_setup_player_spawn()
	_position_player_ship()

	print("=== SECTOR 001: SOL SYSTEM (REALISTIC) ===")
	print("    Textures expected at: ", TEXTURE_BASE_PATH)

func _setup_environment() -> void:
	_environment = WorldEnvironment.new()
	var env := Environment.new()

	# Deep space sky
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.005, 0.005, 0.015)
	sky_mat.sky_horizon_color = Color(0.01, 0.01, 0.025)
	sky_mat.ground_bottom_color = Color(0.005, 0.005, 0.01)
	sky_mat.ground_horizon_color = Color(0.01, 0.01, 0.02)

	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY

	# Cool TNG ambient
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.12, 0.12, 0.18)
	env.ambient_light_energy = 0.4

	# Filmic tonemapping for cinematic look
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0

	# Bloom for star glow (reduced to prevent double-star effect)
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_strength = 0.6
	env.glow_bloom = 0.05
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_hdr_threshold = 1.2

	_environment.environment = env
	add_child(_environment)

func _setup_lighting() -> void:
	# Main sun light
	_sun_light = DirectionalLight3D.new()
	_sun_light.name = "SunLight"
	_sun_light.light_color = Color(1.0, 0.97, 0.92)
	_sun_light.light_energy = 1.3
	_sun_light.shadow_enabled = false
	_sun_light.rotation_degrees = Vector3(-15, -30, 0)
	add_child(_sun_light)

	# Soft fill light (simulates scattered light in space)
	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.light_color = Color(0.5, 0.6, 0.8)
	fill.light_energy = 0.25
	fill.rotation_degrees = Vector3(20, 150, 0)
	add_child(fill)

	# Rim light for planet edges
	var rim := DirectionalLight3D.new()
	rim.name = "RimLight"
	rim.light_color = Color(0.7, 0.8, 1.0)
	rim.light_energy = 0.15
	rim.rotation_degrees = Vector3(0, 90, 0)
	add_child(rim)

func _create_all_bodies() -> void:
	var bodies_node := Node3D.new()
	bodies_node.name = "CelestialBodies"
	add_child(bodies_node)

	for config in planet_configs:
		var body: Node3D = _create_body(config)
		if body:
			bodies_node.add_child(body)
			_planets[config["name"]] = body

func _create_body(config: Dictionary) -> Node3D:
	var body_type: String = config.get("type", "planet")
	var body: Node3D

	match body_type:
		"star":
			body = _create_sun(config)
		"earth":
			body = _create_earth(config)
		"saturn":
			body = _create_saturn(config)
		"moon":
			body = _create_generic_planet(config)
			# Moon will be positioned relative to parent in _process
		"starbase":
			body = _create_starbase(config)
			# Starbase will be positioned relative to parent in _process
		_:
			body = _create_generic_planet(config)

	if body:
		var body_name: String = config["name"]
		var angle: float = config.get("orbital_angle", 0)

		# Store initial orbital angle
		_orbital_angles[body_name] = angle

		# Position body (moon handled differently)
		if body_type != "moon":
			var distance: float = config.get("distance", 0)
			body.position = Vector3(
				sin(angle) * distance,
				0,
				cos(angle) * distance
			)

		body.name = body_name
		print("  Created: ", body_name, " at distance ", config.get("distance", 0))

	return body

func _create_sun(config: Dictionary) -> Node3D:
	var sun := Node3D.new()

	# Sun mesh
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = config["radius"]
	sphere.height = config["radius"] * 2.0
	sphere.radial_segments = 64
	sphere.rings = 32
	mesh.mesh = sphere

	# Emissive material
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.95, 0.85)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.95, 0.85)
	mat.emission_energy_multiplier = config.get("emission", 5.0)

	# Load sun texture
	var tex_path: String = TEXTURE_BASE_PATH + config.get("texture", "")
	if ResourceLoader.exists(tex_path):
		var tex = load(tex_path)
		mat.albedo_texture = tex
		mat.emission_texture = tex

	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sun.add_child(mesh)

	# Subtle corona glow (reduced size to prevent double-star appearance)
	var corona := _create_corona(config["radius"] * 1.05, Color(1.0, 0.95, 0.8, 0.08))
	sun.add_child(corona)

	# Store mesh reference for rotation
	sun.set_meta("mesh", mesh)

	return sun

func _create_earth(config: Dictionary) -> Node3D:
	var earth := Node3D.new()

	# Main planet mesh
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var sphere := SphereMesh.new()
	sphere.radius = config["radius"]
	sphere.height = config["radius"] * 2.0
	sphere.radial_segments = 64
	sphere.rings = 32
	mesh.mesh = sphere

	# Earth material
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.5, 0.8)

	# Load day texture
	var tex_path: String = TEXTURE_BASE_PATH + config.get("texture", "")
	if ResourceLoader.exists(tex_path):
		var tex = load(tex_path)
		mat.albedo_texture = tex
		mat.albedo_color = Color.WHITE

	# Apply axial tilt
	mesh.rotation_degrees.z = config.get("axial_tilt", 23.4)
	mesh.material_override = mat
	earth.add_child(mesh)

	# Atmosphere
	var atmo := _create_atmosphere(config["radius"] * 1.02, Color(0.4, 0.6, 1.0, 0.25))
	atmo.rotation_degrees.z = config.get("axial_tilt", 23.4)
	earth.add_child(atmo)

	# Clouds layer
	var clouds_tex_path: String = TEXTURE_BASE_PATH + config.get("texture_clouds", "")
	if ResourceLoader.exists(clouds_tex_path):
		var clouds := _create_clouds(config["radius"] * 1.01, clouds_tex_path)
		clouds.rotation_degrees.z = config.get("axial_tilt", 23.4)
		earth.add_child(clouds)

	# Store rotation speed
	earth.set_meta("rotation_speed", config.get("rotation_speed", 0.01))
	earth.set_meta("mesh", mesh)

	return earth

func _create_saturn(config: Dictionary) -> Node3D:
	var saturn := Node3D.new()

	# Planet mesh
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var sphere := SphereMesh.new()
	sphere.radius = config["radius"]
	sphere.height = config["radius"] * 2.0
	sphere.radial_segments = 64
	sphere.rings = 32
	mesh.mesh = sphere

	# Saturn material
	var mat := StandardMaterial3D.new()
	mat.albedo_color = config.get("color", Color(0.9, 0.85, 0.7))

	var tex_path: String = TEXTURE_BASE_PATH + config.get("texture", "")
	if ResourceLoader.exists(tex_path):
		var tex = load(tex_path)
		mat.albedo_texture = tex
		mat.albedo_color = Color.WHITE

	mesh.rotation_degrees.z = config.get("axial_tilt", 26.7)
	mesh.material_override = mat
	saturn.add_child(mesh)

	# Rings
	var ring_tex_path: String = TEXTURE_BASE_PATH + config.get("texture_ring", "")
	var inner_r: float = config["radius"] * config.get("ring_inner", 1.2)
	var outer_r: float = config["radius"] * config.get("ring_outer", 2.3)
	var rings := _create_ring_mesh(inner_r, outer_r, ring_tex_path, config.get("axial_tilt", 26.7))
	saturn.add_child(rings)

	saturn.set_meta("rotation_speed", config.get("rotation_speed", 0.018))
	saturn.set_meta("mesh", mesh)

	return saturn

func _create_generic_planet(config: Dictionary) -> Node3D:
	var planet := Node3D.new()

	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var sphere := SphereMesh.new()
	sphere.radius = config["radius"]
	sphere.height = config["radius"] * 2.0
	sphere.radial_segments = 48
	sphere.rings = 24
	mesh.mesh = sphere

	var mat := StandardMaterial3D.new()
	mat.albedo_color = config.get("color", Color(0.7, 0.7, 0.7))

	var tex_path: String = TEXTURE_BASE_PATH + config.get("texture", "")
	if ResourceLoader.exists(tex_path):
		var tex = load(tex_path)
		mat.albedo_texture = tex
		mat.albedo_color = Color.WHITE

	mesh.rotation_degrees.z = config.get("axial_tilt", 0)
	mesh.material_override = mat
	planet.add_child(mesh)

	planet.set_meta("rotation_speed", config.get("rotation_speed", 0.01))
	planet.set_meta("mesh", mesh)

	return planet

func _create_starbase(config: Dictionary) -> Node3D:
	var starbase := Node3D.new()
	var radius: float = config.get("radius", 120)

	# Load the spacedock GLB model
	var model_path := "res://assets/models/star_trek_earth_spacedock.glb"
	if ResourceLoader.exists(model_path):
		var model_scene: PackedScene = load(model_path)
		if model_scene:
			var model_instance: Node3D = model_scene.instantiate()
			model_instance.name = "SpacedockModel"

			# Scale the model to fit the configured radius
			# Adjust this scale factor based on the model's native size
			var scale_factor: float = radius / 5.0  # Adjust divisor based on model size
			model_instance.scale = Vector3(scale_factor, scale_factor, scale_factor)

			starbase.add_child(model_instance)

			# Store reference for rotation
			starbase.set_meta("mesh", model_instance)
			print("  Loaded spacedock model from: ", model_path)
	else:
		# Fallback to simple placeholder if model not found
		push_warning("Spacedock model not found at: " + model_path)
		var placeholder := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = radius
		sphere.height = radius * 2.0
		placeholder.mesh = sphere
		var mat := StandardMaterial3D.new()
		mat.albedo_color = config.get("color", Color(0.7, 0.8, 0.9))
		placeholder.material_override = mat
		starbase.add_child(placeholder)
		starbase.set_meta("mesh", placeholder)

	# Store rotation speed
	starbase.set_meta("rotation_speed", config.get("rotation_speed", 0.003))

	return starbase

func _create_atmosphere(radius: float, color: Color) -> MeshInstance3D:
	var atmo := MeshInstance3D.new()
	atmo.name = "Atmosphere"

	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 32
	sphere.rings = 16
	atmo.mesh = sphere

	var mat := ShaderMaterial.new()
	mat.shader = _get_atmosphere_shader()
	mat.set_shader_parameter("atmosphere_color", color)
	mat.set_shader_parameter("falloff", 3.0)

	atmo.material_override = mat
	atmo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	return atmo

func _create_corona(radius: float, color: Color) -> MeshInstance3D:
	var corona := MeshInstance3D.new()
	corona.name = "Corona"

	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 32
	sphere.rings = 16
	corona.mesh = sphere

	var mat := ShaderMaterial.new()
	mat.shader = _get_atmosphere_shader()
	mat.set_shader_parameter("atmosphere_color", color)
	mat.set_shader_parameter("falloff", 2.0)

	corona.material_override = mat
	corona.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	return corona

func _create_clouds(radius: float, tex_path: String) -> MeshInstance3D:
	var clouds := MeshInstance3D.new()
	clouds.name = "Clouds"

	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 48
	sphere.rings = 24
	clouds.mesh = sphere

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 1, 1, 0.5)

	if ResourceLoader.exists(tex_path):
		var tex = load(tex_path)
		mat.albedo_texture = tex

	clouds.material_override = mat
	clouds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	return clouds

func _create_ring_mesh(inner_r: float, outer_r: float, tex_path: String, tilt: float) -> MeshInstance3D:
	var ring_node := MeshInstance3D.new()
	ring_node.name = "Rings"

	# Generate ring geometry
	var arr_mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)

	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	var segments: int = 128
	for i in range(segments + 1):
		var angle: float = (float(i) / float(segments)) * TAU
		var c := cos(angle)
		var s := sin(angle)

		verts.append(Vector3(c * inner_r, 0, s * inner_r))
		norms.append(Vector3.UP)
		uvs.append(Vector2(float(i) / float(segments), 0.0))

		verts.append(Vector3(c * outer_r, 0, s * outer_r))
		norms.append(Vector3.UP)
		uvs.append(Vector2(float(i) / float(segments), 1.0))

	for i in range(segments):
		var b: int = i * 2
		indices.append_array([b, b+1, b+2, b+1, b+3, b+2])

	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	ring_node.mesh = arr_mesh

	# Ring material
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(0.9, 0.85, 0.7, 0.7)

	if ResourceLoader.exists(tex_path):
		var tex = load(tex_path)
		mat.albedo_texture = tex
		mat.albedo_color = Color.WHITE

	ring_node.material_override = mat
	ring_node.rotation_degrees.z = tilt
	ring_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	return ring_node

func _get_atmosphere_shader() -> Shader:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_front, unshaded;

uniform vec4 atmosphere_color : source_color = vec4(0.4, 0.6, 1.0, 0.3);
uniform float falloff : hint_range(0.5, 10.0) = 3.0;

void fragment() {
	vec3 view = normalize(CAMERA_POSITION_WORLD - (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	vec3 normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float rim = 1.0 - max(dot(view, normal), 0.0);
	rim = pow(rim, falloff);
	ALBEDO = atmosphere_color.rgb;
	ALPHA = rim * atmosphere_color.a;
}
"""
	return shader

func _setup_player_spawn() -> void:
	_player_spawn = Marker3D.new()
	_player_spawn.name = "PlayerSpawn"

	if _planets.has("Earth"):
		var earth: Node3D = _planets["Earth"]
		# Position player OUTSIDE Earth's orbit (radially outward from Sun)
		# This ensures the player never spawns in Earth's orbital path
		var earth_dir: Vector3 = earth.position.normalized()  # Direction from Sun to Earth
		var outward_offset: Vector3 = earth_dir * spawn_distance_from_earth  # Push player further from Sun
		_player_spawn.position = earth.position + outward_offset + Vector3(0, spawn_height, 0)
		# Face toward Earth - calculate rotation manually since node isn't in tree yet
		var dir_to_earth: Vector3 = (earth.position - _player_spawn.position).normalized()
		_player_spawn.basis = Basis.looking_at(dir_to_earth, Vector3.UP)
		print("  Player spawn outside Earth orbit at: ", _player_spawn.position)

	add_child(_player_spawn)

func _position_player_ship() -> void:
	var ship := get_node_or_null("Starship")
	if ship:
		ship.global_transform = _player_spawn.global_transform
		print("=== SHIP POSITIONED ===")
		print("  Ship global position: ", ship.global_position)
		print("  Ship rotation: ", ship.global_rotation_degrees)
	else:
		print("ERROR: Could not find Starship node!")

func _process(delta: float) -> void:
	# Update orbital positions and rotations
	for config in planet_configs:
		var planet_name: String = config["name"]
		if not _planets.has(planet_name):
			continue

		var planet: Node3D = _planets[planet_name]
		var orbital_speed: float = config.get("orbital_speed", 0.0)

		# Update orbital angle
		if orbital_speed != 0.0:
			_orbital_angles[planet_name] = _orbital_angles.get(planet_name, 0.0) + orbital_speed * delta

		var angle: float = _orbital_angles.get(planet_name, 0.0)

		# Handle moon or starbase orbiting parent planet
		if config.get("type") == "moon" or config.get("type") == "starbase":
			var parent_name: String = config.get("parent", "")
			if parent_name != "" and _planets.has(parent_name):
				var parent: Node3D = _planets[parent_name]
				var orbit_distance: float = config.get("distance", 600)
				planet.position = parent.position + Vector3(
					sin(angle) * orbit_distance,
					0,
					cos(angle) * orbit_distance
				)
		else:
			# Standard orbit around Sun (origin)
			var distance: float = config.get("distance", 0)
			if distance > 0:
				planet.position = Vector3(
					sin(angle) * distance,
					0,
					cos(angle) * distance
				)

		# Rotate planet on its axis
		var rotation_speed: float = config.get("rotation_speed", 0.0)
		var mesh = planet.get_meta("mesh", null)
		if mesh and rotation_speed != 0.0:
			mesh.rotate_y(rotation_speed * delta)

# =============================================================================
# PUBLIC API
# =============================================================================

func get_player_spawn_transform() -> Transform3D:
	return _player_spawn.global_transform

func get_planet(planet_name: String) -> Node3D:
	return _planets.get(planet_name, null)

func get_all_planets() -> Dictionary:
	return _planets

func get_planet_names() -> Array:
	return _planets.keys()

func get_earth() -> Node3D:
	return get_planet("Earth")
