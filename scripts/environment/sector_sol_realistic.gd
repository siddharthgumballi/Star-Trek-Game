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
## - Orbital distances: 1 unit = 1000 km (REAL AU scale)
##   * Earth at 149,600 units = 1 AU = 149.6 million km
##   * Neptune at 4,498,000 units = 30 AU
## - Planet/ship sizes: 250x scale for visibility
##   * Earth radius: 1,595 units (real: 6,371 km)
##   * Ship size: ~40 units
##
## FLOATING ORIGIN SYSTEM:
## =======================
## This scene uses a Floating Origin system to prevent floating-point
## precision errors at large distances. Key points:
##
## - The player ship ALWAYS stays near world origin (0,0,0)
## - When the ship moves >50 units from origin, the entire universe shifts
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

# SCALE SYSTEM:
# - Orbital distances: 1 unit = 1000 km (1 AU = 149,600 units)
# - Planet radii: 250x for visibility
# - This hybrid approach keeps astronomical distances real
#   while making ships and planets visible

# 1 AU in game units (1 unit = 1000 km)
const AU: float = 149600.0

var planet_configs: Array[Dictionary] = [
	{
		"name": "Sun",
		"type": "star",
		"distance": 0,
		"radius": 20000,  # Reduced for gameplay (real 250x would be 174,000, engulfing Mercury)
		"texture": "2k_sun.jpg",
		"rotation_speed": 0.001,
		"emission": 5.0,
		"orbital_speed": 0.0
	},
	{
		"name": "Mercury",
		"type": "planet",
		"distance": 57900,   # 0.387 AU = 57,909,050 km
		"radius": 610,       # Real: 2,440 km × 250 / 1000 = 610
		"texture": "2k_mercury.jpg",
		"rotation_speed": 0.002,
		"color": Color(0.6, 0.55, 0.5),
		"orbital_angle": 0.8,
		"orbital_speed": 0.0
	},
	{
		"name": "Venus",
		"type": "planet",
		"distance": 108200,  # 0.723 AU = 108,208,000 km
		"radius": 1515,      # Real: 6,052 km × 250 / 1000 = 1,513
		"texture": "2k_venus_surface.jpg",
		"rotation_speed": -0.001,
		"color": Color(0.9, 0.8, 0.6),
		"orbital_angle": 2.4,
		"orbital_speed": 0.0
	},
	{
		"name": "Earth",
		"type": "earth",
		"distance": 149600,  # 1.0 AU = 149,600,000 km
		"radius": 1595,      # Real: 6,371 km × 250 / 1000 = 1,593
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
		"distance": 3000,    # Outside Earth's visual radius (1595) + margin
		"radius": 435,       # Real: 1,737 km × 250 / 1000 = 434
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
		"distance": 2200,    # Between Earth surface (1595) and Moon (3000)
		"radius": 125,
		"rotation_speed": 0.003,
		"orbital_angle": 2.0,
		"orbital_speed": 0.006,
		"color": Color(0.7, 0.8, 0.9)
	},
	{
		"name": "Mars",
		"type": "planet",
		"distance": 227900,  # 1.524 AU = 227,939,200 km
		"radius": 850,       # Real: 3,390 km × 250 / 1000 = 848
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
		"distance": 778300,  # 5.203 AU = 778,299,000 km
		"radius": 17475,     # Real: 69,911 km × 250 / 1000 = 17,478
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
		"distance": 1427000, # 9.537 AU = 1,426,666,000 km
		"radius": 14525,     # Real: 58,232 km × 250 / 1000 = 14,558
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
		"distance": 2871000, # 19.19 AU = 2,870,658,000 km
		"radius": 6365,      # Real: 25,362 km × 250 / 1000 = 6,341
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
		"distance": 4498000, # 30.07 AU = 4,498,396,000 km
		"radius": 6175,      # Real: 24,622 km × 250 / 1000 = 6,156
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
## Spawn outside Earth's radius (1595 units) + buffer for clear view of planet
## Moon is at 385 units, Starbase at 250 units from Earth
@export var spawn_distance_from_earth: float = 3000.0
@export var spawn_height: float = 500.0

func _ready() -> void:
	_setup_environment()
	_setup_lighting()
	_create_all_bodies()
	_setup_player_spawn()
	_position_player_ship()
	_setup_floating_origin()

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

		# Spawn above Earth (Y axis) to avoid Moon's orbital plane
		# Moon orbits at 4000 units in XZ plane, so spawning on Y avoids collision
		var spawn_pos: Vector3 = earth_pos + Vector3(spawn_distance_from_earth * 0.7, spawn_height + 2000, spawn_distance_from_earth * 0.7)

		_player_spawn.position = spawn_pos
		# Face toward Earth
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
		# FLOATING ORIGIN SETUP:
		# Instead of moving ship to spawn point, we:
		# 1. Keep ship at origin (0,0,0)
		# 2. Offset the entire universe so spawn point is at origin

		var spawn_transform: Transform3D = _player_spawn.global_transform
		var universe_offset: Vector3 = spawn_transform.origin

		# Ship stays at origin, facing the right direction
		_player_ship.global_position = Vector3.ZERO
		_player_ship.global_transform.basis = spawn_transform.basis

		# Offset all celestial bodies so spawn point is now at origin
		_celestial_bodies.global_position = -universe_offset

		print("=== SHIP POSITIONED (FLOATING ORIGIN) ===")
		print("  Universe offset: ", universe_offset)
		print("  Ship at origin: ", _player_ship.global_position)
		print("  Ship rotation: ", _player_ship.global_rotation_degrees)
		print("  CelestialBodies offset: ", _celestial_bodies.global_position)

		# Print ship children to verify model loader
		print("  Ship children: ", _player_ship.get_child_count())
		for child in _player_ship.get_children():
			print("    - ", child.name, " (", child.get_class(), ")")
	else:
		print("ERROR: Could not find Starship node!")

func _setup_floating_origin() -> void:
	# Register with the FloatingOrigin autoload
	var fo = get_node_or_null("/root/FloatingOrigin")
	if fo and _player_ship and _celestial_bodies:
		# Register the player ship
		fo.set_player_ship(_player_ship)

		# Register the celestial bodies container
		# When origin shifts, this entire node (and all children) will be moved
		fo.register_world_object(_celestial_bodies)

		# Set the initial world offset to match where we spawned
		# This is the "true" universe position of the origin
		fo.world_offset = _player_spawn.global_transform.origin

		print("=== FLOATING ORIGIN CONFIGURED ===")
		print("  Initial world offset: ", fo.world_offset)
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
