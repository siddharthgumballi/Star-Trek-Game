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
## SCALE NOTES - UNIFORM 100× WORLD SCALE:
## =======================================
## Everything is scaled uniformly by WORLD_SCALE = 100.0:
## - Orbital DISTANCES: real × 100 (Earth at 15M units)
## - Planet/star RADII: real × 100 (Earth radius 637 units)
## - Linear SPEEDS: real × 100 (Full impulse ~7,495 units/s)
##
## NOT SCALED: time, mass, angular rates
##
## This creates correct proportions at all scales while keeping
## the floating origin system stable.
##
## FLOATING ORIGIN SYSTEM:
## =======================
## This scene uses a Floating Origin system to prevent floating-point
## precision errors at large distances. Key points:
##
## - The player ship ALWAYS stays near world origin (0,0,0)
## - When the ship moves >50,000 units from origin, the entire universe shifts
## - All celestial bodies are children of _celestial_bodies node
## - _celestial_bodies is registered with FloatingOrigin autoload
## - Distance calculations use world positions (always valid)
## - Warp travel is fully compatible (no special handling needed)
##
## To add new objects to the world:
##   1. Make them children of _celestial_bodies, OR
##   2. Register them with FloatingOrigin.register_world_object()
##
## DO NOT:
## - Position objects using raw large coordinates
## - Use absolute positions for UI distance displays (use world_to_universe)
## - Assume origin is at the Sun (origin follows the player)
##
## TNG VISUAL STYLE:
## =================
## - Soft, cinematic lighting
## - Cool ambient tones
## - Planets should feel majestic and serene

const TEXTURE_BASE_PATH = "res://assets/textures/planets/"

# =============================================================================
# UNIFORM 100× WORLD SCALE
# =============================================================================
# All distances AND radii are scaled by 100×
# Base: 1 unit = 1000 km, Scaled: 1 unit = 10 km
# This creates correct proportions at all scales
#
# WORLD_SCALE is applied exactly ONCE to each value below.
# =============================================================================

const WORLD_SCALE: float = 100.0

# 1 AU in scaled game units
# Base: 149,597.87 units × 100 = 14,959,787 units
const AU: float = 14960000.0

# Warp arrival distance: 2 million km = 200,000 units at 100× scale
const WARP_ARRIVAL_DISTANCE: float = 200000.0

var planet_configs: Array[Dictionary] = [
	{
		"name": "Sun",
		"type": "star",
		"distance": 0,
		"radius": 69600,      # 696,000 km × 100 / 1000 = 69,600
		"texture": "2k_sun.jpg",
		"rotation_speed": 0.001,
		"emission": 5.0,
		"orbital_speed": 0.0
	},
	{
		"name": "Mercury",
		"type": "planet",
		"distance": 5790000,   # 57,900,000 km × 100 / 1000 = 5,790,000 (0.387 AU)
		"radius": 244,         # 2,440 km × 100 / 1000 = 244
		"texture": "2k_mercury.jpg",
		"rotation_speed": 0.002,
		"color": Color(0.6, 0.55, 0.5),
		"orbital_angle": 0.8,
		"orbital_speed": 0.0
	},
	{
		"name": "Venus",
		"type": "planet",
		"distance": 10820000,  # 108,200,000 km × 100 / 1000 = 10,820,000 (0.723 AU)
		"radius": 605,         # 6,052 km × 100 / 1000 = 605
		"texture": "2k_venus_surface.jpg",
		"rotation_speed": -0.001,
		"color": Color(0.9, 0.8, 0.6),
		"orbital_angle": 2.4,
		"orbital_speed": 0.0
	},
	{
		"name": "Earth",
		"type": "earth",
		"distance": 14960000,  # 149,600,000 km × 100 / 1000 = 14,960,000 (1.0 AU)
		"radius": 637,         # 6,371 km × 100 / 1000 = 637
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
		"distance": 38440,     # 384,400 km × 100 / 1000 = 38,440
		"radius": 174,         # 1,737 km × 100 / 1000 = 174
		"texture": "2k_moon.jpg",
		"rotation_speed": 0.005,
		"color": Color(0.75, 0.75, 0.75),
		"orbital_angle": 0.0,
		"orbital_speed": 0.01
	},
	{
		"name": "Starbase 1",
		"type": "starbase",
		"parent": "Earth",
		"distance": 4000,      # ~40,000 km orbit × 100 / 1000 = 4,000
		"radius": 100,         # Scaled up for visibility
		"rotation_speed": 0.003,
		"orbital_angle": 2.0,
		"orbital_speed": 0.006,
		"color": Color(0.7, 0.8, 0.9)
	},
	{
		"name": "Mars",
		"type": "planet",
		"distance": 22790000,  # 227,900,000 km × 100 / 1000 = 22,790,000 (1.524 AU)
		"radius": 339,         # 3,390 km × 100 / 1000 = 339
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
		"distance": 77850000,  # 778,500,000 km × 100 / 1000 = 77,850,000 (5.203 AU)
		"radius": 6991,        # 69,911 km × 100 / 1000 = 6,991
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
		"distance": 143200000, # 1,432,000,000 km × 100 / 1000 = 143,200,000 (9.537 AU)
		"radius": 5823,        # 58,232 km × 100 / 1000 = 5,823
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
		"distance": 287100000, # 2,871,000,000 km × 100 / 1000 = 287,100,000 (19.19 AU)
		"radius": 2536,        # 25,362 km × 100 / 1000 = 2,536
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
		"distance": 449800000, # 4,498,000,000 km × 100 / 1000 = 449,800,000 (30.07 AU)
		"radius": 2462,        # 24,622 km × 100 / 1000 = 2,462
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
var _celestial_bodies: Node3D  # Container for all planets/stations (registered with FloatingOrigin)
var _player_ship: Node3D       # Reference to player ship


@export_group("Spawn Settings")
## At 100× scale: Earth radius = 637 units
## Spawn ~1600 units from Earth center (~960 above surface)
## Moon at 38,440 units, Starbase at 4,000 units from Earth
@export var spawn_distance_from_earth: float = 1600.0
@export var spawn_height: float = 400.0

func _ready() -> void:
	_setup_environment()
	_setup_lighting()
	_create_all_bodies()
	_setup_player_spawn()
	_position_player_ship()
	_setup_floating_origin()
	_create_debug_objects()  # DEBUG: Add visible test objects

	print("=== SECTOR 001: SOL SYSTEM (REALISTIC) ===")
	print("    Textures expected at: ", TEXTURE_BASE_PATH)
	print("    Floating Origin: ENABLED")

func _setup_environment() -> void:
	_environment = WorldEnvironment.new()
	var env := Environment.new()

	# Milky way panoramic sky
	var sky_mat := PanoramaSkyMaterial.new()
	var milky_way_path: String = TEXTURE_BASE_PATH + "2k_stars_milky_way.jpg"
	if ResourceLoader.exists(milky_way_path):
		sky_mat.panorama = load(milky_way_path)
		print("  Loaded milky way sky texture")
	else:
		print("  WARNING: Milky way texture not found at: ", milky_way_path)

	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY

	# Cool TNG ambient
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.1, 0.1, 0.15)
	env.ambient_light_energy = 0.3

	# Filmic tonemapping for cinematic look
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0

	# Glow disabled
	env.glow_enabled = false

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
	_celestial_bodies = Node3D.new()
	_celestial_bodies.name = "CelestialBodies"
	add_child(_celestial_bodies)

	for config in planet_configs:
		var body: Node3D = _create_body(config)
		if body:
			_celestial_bodies.add_child(body)
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

		# Position body (moons and starbases orbit their parent, not the Sun)
		if body_type != "moon" and body_type != "starbase":
			var distance: float = config.get("distance", 0)
			body.position = Vector3(
				sin(angle) * distance,
				0,
				cos(angle) * distance
			)
		else:
			# Position moons/starbases relative to their parent immediately
			var parent_name: String = config.get("parent", "")
			if parent_name != "" and _planets.has(parent_name):
				var parent: Node3D = _planets[parent_name]
				var orbit_distance: float = config.get("distance", 600)
				body.position = parent.position + Vector3(
					sin(angle) * orbit_distance,
					0,
					cos(angle) * orbit_distance
				)

		body.name = body_name
		print("  Created: ", body_name, " at distance ", config.get("distance", 0), " type: ", body_type)

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

	# Corona removed - was causing excessive brightness

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
		var earth_pos: Vector3 = earth.position

		# Spawn above Earth - close enough to see it clearly
		# Earth radius is 637 at 100× scale, spawn ~1600 units from center
		var spawn_pos: Vector3 = earth_pos + Vector3(spawn_distance_from_earth * 0.5, spawn_height + 800, spawn_distance_from_earth * 0.5)

		_player_spawn.position = spawn_pos
		# Add to tree first, then look_at (requires being in tree)
		add_child(_player_spawn)
		_player_spawn.look_at(earth_pos, Vector3.UP)

		print("=== SPAWN SETUP ===")
		print("  Earth at: ", earth_pos)
		print("  Ship spawn at: ", spawn_pos)
	else:
		# Fallback spawn at origin area
		_player_spawn.position = Vector3(0, 500, 5000)
		print("  No Earth found, spawning at fallback position")
		add_child(_player_spawn)

func _position_player_ship() -> void:
	_player_ship = get_node_or_null("Starship")
	if _player_ship:
		var spawn_transform: Transform3D = _player_spawn.global_transform

		# DEBUG: Check if floating origin debug mode is active
		# Ship starts at origin, CelestialBodies is offset to bring spawn point to origin
		var universe_offset: Vector3 = spawn_transform.origin
		_player_ship.global_position = Vector3.ZERO

		# Calculate yaw-only rotation (0 pitch, 0 roll) facing toward Earth
		var earth_pos: Vector3 = _planets["Earth"].position if _planets.has("Earth") else Vector3.ZERO
		var to_earth: Vector3 = earth_pos - spawn_transform.origin
		to_earth.y = 0  # Flatten to horizontal plane
		if to_earth.length() > 0.1:
			var yaw: float = atan2(to_earth.x, to_earth.z)
			_player_ship.rotation = Vector3(0, yaw, 0)  # Pitch=0, Yaw=toward Earth, Roll=0
		else:
			_player_ship.rotation = Vector3.ZERO

		_celestial_bodies.global_position = -universe_offset

		print("=== SHIP POSITIONED (FLOATING ORIGIN) ===")

		print("  CelestialBodies position: ", _celestial_bodies.global_position)
	else:
		print("ERROR: Could not find Starship node!")

func _setup_floating_origin() -> void:
	# Register with the FloatingOrigin autoload
	var fo = get_node_or_null("/root/FloatingOrigin")
	if fo and _player_ship and _celestial_bodies:
		# Register the player ship
		fo.set_player_ship(_player_ship)

		# Register celestial bodies container - it will be shifted with origin
		fo.register_world_object(_celestial_bodies)

		# Set the initial world offset to match where we spawned
		fo.world_offset = _player_spawn.global_transform.origin

		print("=== FLOATING ORIGIN CONFIGURED ===")
		print("  Initial world offset: ", fo.world_offset)
		print("  Registered CelestialBodies for shifting")
	else:
		push_warning("FloatingOrigin autoload not found or missing references!")

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
			# Standard orbit around Sun (origin of CelestialBodies)
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

func _get_config_for_planet(planet_name: String) -> Dictionary:
	for config in planet_configs:
		if config.get("name") == planet_name:
			return config
	return {}

func get_all_planets() -> Dictionary:
	return _planets

func get_planet_names() -> Array:
	return _planets.keys()

func get_earth() -> Node3D:
	return get_planet("Earth")

func get_player_ship() -> Node3D:
	return _player_ship

## Get a planet's position in universe coordinates (true solar system position)
## Use this for UI displays showing absolute position
func get_planet_universe_position(planet_name: String) -> Vector3:
	var fo = get_node_or_null("/root/FloatingOrigin")
	var planet: Node3D = _planets.get(planet_name, null)
	if fo and planet:
		return fo.world_to_universe(planet.global_position)
	elif planet:
		return planet.global_position
	return Vector3.ZERO

## Get distance from player to a planet (works in world space, unaffected by floating origin)
func get_distance_to_planet(planet_name: String) -> float:
	var planet: Node3D = _planets.get(planet_name, null)
	if planet and _player_ship:
		return _player_ship.global_position.distance_to(planet.global_position)
	return -1.0

## Get the Sun's position in universe coordinates (always at 0,0,0)
func get_sun_universe_position() -> Vector3:
	return Vector3.ZERO  # Sun is at universe origin by definition

# =============================================================================
# DEBUG: Test visibility with simple objects
# =============================================================================

func _create_debug_objects() -> void:
	# DEBUG: Rendering confirmed working - disabling debug objects
	# To re-enable, set this to false:
	var skip_debug := true
	if skip_debug:
		print("=== DEBUG OBJECTS SKIPPED (rendering confirmed working) ===")
		return

	print("=== CREATING DEBUG OBJECTS ===")

	# Create a bright red sphere 100 units in front of the ship
	var debug_sphere_front := _create_debug_sphere(Color.RED, 10.0)
	debug_sphere_front.name = "DEBUG_FRONT"
	add_child(debug_sphere_front)
	debug_sphere_front.global_position = Vector3(0, 0, -100)  # In front of ship
	print("  Red sphere at (0, 0, -100) - should be in front of ship")

	# Create a green sphere 100 units to the right
	var debug_sphere_right := _create_debug_sphere(Color.GREEN, 10.0)
	debug_sphere_right.name = "DEBUG_RIGHT"
	add_child(debug_sphere_right)
	debug_sphere_right.global_position = Vector3(100, 0, 0)
	print("  Green sphere at (100, 0, 0) - to the right")

	# Create a blue sphere 100 units up
	var debug_sphere_up := _create_debug_sphere(Color.BLUE, 10.0)
	debug_sphere_up.name = "DEBUG_UP"
	add_child(debug_sphere_up)
	debug_sphere_up.global_position = Vector3(0, 100, 0)
	print("  Blue sphere at (0, 100, 0) - above ship")

	# Create a yellow sphere at Earth's position (should be visible)
	if _planets.has("Earth"):
		var earth: Node3D = _planets["Earth"]
		var debug_at_earth := _create_debug_sphere(Color.YELLOW, 500.0)
		debug_at_earth.name = "DEBUG_AT_EARTH"
		add_child(debug_at_earth)
		debug_at_earth.global_position = earth.global_position
		print("  Yellow sphere at Earth's position: ", earth.global_position)

	print("=== DEBUG OBJECTS CREATED ===")
	print("  If you can see colored spheres, rendering works!")
	print("  If you only see the sky, there's a camera/positioning issue")

func _create_debug_sphere(color: Color, radius: float) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	mesh_instance.mesh = sphere

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mesh_instance.material_override = mat
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	return mesh_instance
