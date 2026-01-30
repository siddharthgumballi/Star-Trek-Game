extends Node3D
class_name SectorSol
## Sector 001 - Sol System
## Federation Core Space - Earth, birthplace of the Federation
##
## DESIGN PHILOSOPHY:
##   - Calm, orderly, safe Federation space
##   - Majestic scale emphasizing Earth's importance
##   - TNG-style cool, cinematic lighting
##   - No combat, hazards, or clutter
##
## SCALE NOTES:
##   Game units are roughly 1 unit = 1 meter for ship scale
##   Planetary distances are heavily compressed for gameplay
##   Real Sol System would be ~4.5 billion km to Neptune
##   We compress to ~50,000 units total for playable space
##
## TO ADD STARBASE EARTH (SPACEDOCK):
##   1. Create a Starbase scene (large orbital station)
##   2. Instance it as child of Earth node
##   3. Position at Vector3(0, 200, -800) relative to Earth
##   4. This places it in high Earth orbit, visible from spawn
##
## TO SCALE/REPOSITION PLANETS:
##   - Adjust the planet_data dictionary below
##   - distance: units from Sun (compressed scale)
##   - radius: visual size of planet
##   - Maintain relative proportions for believability
##
## TO REUSE AS TEMPLATE FOR OTHER SECTORS:
##   1. Duplicate this script, rename class
##   2. Modify planet_data for new system's bodies
##   3. Adjust sun_color and environment for system's star type
##   4. Change spawn_position for appropriate starting location

# =============================================================================
# CONFIGURATION
# =============================================================================

@export_group("Sun Properties")
@export var sun_color: Color = Color(1.0, 0.95, 0.8)  # Warm yellow-white G-type star
@export var sun_radius: float = 1500.0  # Large and visible
@export var sun_light_energy: float = 1.5

@export_group("Environment")
@export var ambient_color: Color = Color(0.15, 0.15, 0.2)  # Brighter ambient for visibility
@export var ambient_energy: float = 0.5

@export_group("Player Spawn")
## Player spawns near Earth, with Earth visible to the side
@export var spawn_near_earth: bool = true
@export var spawn_offset: Vector3 = Vector3(800, 200, -1000)  # Offset so Earth is visible

# Planet configuration - CINEMATIC SCALE for dramatic visuals
# These are NOT realistic - they're designed to look impressive like TNG establishing shots
var planet_data: Dictionary = {
	"Earth": {
		"distance": 3000,
		"radius": 600,           # LARGE - dominates the view
		"color": Color(0.2, 0.4, 0.8),  # Deep blue marble
		"rotation_speed": 0.005,
		"description": "Federation Headquarters, Human homeworld",
		"is_primary": true
	},
	"Moon": {
		"distance": 3000,        # Same as Earth, offset by angle
		"radius": 150,
		"color": Color(0.7, 0.7, 0.7),  # Gray
		"rotation_speed": 0.003,
		"description": "Luna - Earth's moon"
	},
	"Mars": {
		"distance": 6000,
		"radius": 400,
		"color": Color(0.85, 0.45, 0.25),  # Rust red
		"rotation_speed": 0.004,
		"description": "Utopia Planitia Fleet Yards"
	},
	"Jupiter": {
		"distance": 12000,
		"radius": 1200,          # Massive gas giant
		"color": Color(0.85, 0.75, 0.6),
		"rotation_speed": 0.008,
		"description": "Gas giant, Jovian moons"
	},
	"Saturn": {
		"distance": 20000,
		"radius": 1000,
		"color": Color(0.9, 0.85, 0.65),
		"rotation_speed": 0.007,
		"description": "Ringed gas giant",
		"has_rings": true
	}
}

# =============================================================================
# INTERNAL STATE
# =============================================================================

var _sun: MeshInstance3D
var _planets: Dictionary = {}  # name -> Node3D
var _environment: WorldEnvironment
var _sun_light: DirectionalLight3D
var _player_spawn: Marker3D

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	_setup_environment()
	_setup_sun()
	_setup_planets()
	_setup_player_spawn()
	# Position ship after everything is set up
	call_deferred("_position_player_ship")
	print("=== SECTOR 001: SOL SYSTEM INITIALIZED ===")
	print("    Federation Core Space - Welcome to Earth")

func _position_player_ship() -> void:
	# Find the Starship node and position it at spawn
	var ship := get_node_or_null("Starship")
	if ship:
		ship.global_transform = get_player_spawn_transform()
		print("    Enterprise positioned at: ", ship.global_position)

	# Debug: print planet positions
	for planet_name in _planets:
		var planet: Node3D = _planets[planet_name]
		print("    ", planet_name, " at: ", planet.position, " radius: ", planet_data[planet_name]["radius"])

func _setup_environment() -> void:
	# Create WorldEnvironment for TNG-style space atmosphere
	_environment = WorldEnvironment.new()

	var env := Environment.new()

	# Sky - deep space black with subtle blue tint
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.01, 0.01, 0.03)
	sky_material.sky_horizon_color = Color(0.02, 0.02, 0.05)
	sky_material.ground_bottom_color = Color(0.01, 0.01, 0.02)
	sky_material.ground_horizon_color = Color(0.02, 0.02, 0.04)

	var sky := Sky.new()
	sky.sky_material = sky_material
	env.sky = sky
	env.background_mode = Environment.BG_SKY

	# Ambient light - cool, soft, cinematic TNG feel
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient_color
	env.ambient_light_energy = ambient_energy

	# Tonemap for cinematic look
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	# Subtle glow for stars and bright objects
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_bloom = 0.05
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE

	# Subtle fog for depth (very distant, space-like)
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.05, 0.1)
	env.fog_density = 0.00001
	env.fog_sky_affect = 0.0

	_environment.environment = env
	add_child(_environment)

func _setup_sun() -> void:
	# Sun container for organization
	var sun_node := Node3D.new()
	sun_node.name = "Sol"
	add_child(sun_node)

	# Sun mesh - emissive sphere
	_sun = MeshInstance3D.new()
	_sun.name = "SunMesh"
	var sphere := SphereMesh.new()
	sphere.radius = sun_radius
	sphere.height = sun_radius * 2
	sphere.radial_segments = 64
	sphere.rings = 32
	_sun.mesh = sphere

	# Emissive material for the sun - bright glowing star
	var sun_mat := StandardMaterial3D.new()
	sun_mat.emission_enabled = true
	sun_mat.emission = sun_color
	sun_mat.emission_energy_multiplier = 5.0  # Very bright
	sun_mat.albedo_color = sun_color
	sun_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_sun.material_override = sun_mat

	print("    Sun created at origin, radius: ", sun_radius)

	sun_node.add_child(_sun)

	# Directional light representing sunlight - illuminates everything
	_sun_light = DirectionalLight3D.new()
	_sun_light.name = "SunLight"
	_sun_light.light_color = sun_color
	_sun_light.light_energy = sun_light_energy
	_sun_light.shadow_enabled = false  # Shadows can cause issues at this scale
	# Light direction: shining outward from sun toward planets
	# Planets are spread around, so we use a general angle
	_sun_light.rotation_degrees = Vector3(-20, 0, 0)
	add_child(_sun_light)

	# Add fill light for better planet visibility
	var fill_light := DirectionalLight3D.new()
	fill_light.name = "FillLight"
	fill_light.light_color = Color(0.6, 0.7, 0.9)  # Cool fill
	fill_light.light_energy = 0.4
	fill_light.rotation_degrees = Vector3(30, 120, 0)
	add_child(fill_light)

func _setup_planets() -> void:
	var planets_node := Node3D.new()
	planets_node.name = "Planets"
	add_child(planets_node)

	for planet_name in planet_data:
		var data: Dictionary = planet_data[planet_name]
		var planet := _create_planet(planet_name, data)
		planets_node.add_child(planet)
		_planets[planet_name] = planet

func _create_planet(planet_name: String, data: Dictionary) -> Node3D:
	var planet_node := Node3D.new()
	planet_node.name = planet_name

	# Position planet at its orbital distance (along Z axis for simplicity)
	# In a real implementation, you'd spread them around the sun
	var angle: float = _get_orbital_angle(planet_name)
	var distance: float = data["distance"]
	planet_node.position = Vector3(
		sin(angle) * distance,
		0,
		cos(angle) * distance
	)

	# Create planet mesh
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	var sphere := SphereMesh.new()
	sphere.radius = data["radius"]
	sphere.height = data["radius"] * 2
	sphere.radial_segments = 48
	sphere.rings = 24
	mesh_instance.mesh = sphere

	# Planet material - bright enough to see in space
	var mat := StandardMaterial3D.new()
	mat.albedo_color = data["color"]

	# All planets get some emission to be visible in space
	mat.emission_enabled = true
	mat.emission = data["color"] * 0.3
	mat.emission_energy_multiplier = 0.8

	# Earth gets extra special treatment - brighter and more vibrant
	if data.get("is_primary", false):
		mat.emission = data["color"] * 0.5
		mat.emission_energy_multiplier = 1.2
		mat.albedo_color = Color(0.3, 0.5, 0.9)  # Brighter blue

	mesh_instance.material_override = mat
	planet_node.add_child(mesh_instance)

	# Add rings for Saturn
	if data.get("has_rings", false):
		var rings := _create_rings(data["radius"])
		planet_node.add_child(rings)

	# Store rotation speed for animation
	planet_node.set_meta("rotation_speed", data["rotation_speed"])
	planet_node.set_meta("description", data["description"])

	return planet_node

func _create_rings(planet_radius: float) -> MeshInstance3D:
	# Simple ring using a torus or cylinder
	# For now, use a flattened cylinder as placeholder
	var rings := MeshInstance3D.new()
	rings.name = "Rings"

	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = planet_radius * 2.2
	ring_mesh.bottom_radius = planet_radius * 2.2
	ring_mesh.height = 5.0
	rings.mesh = ring_mesh

	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.8, 0.75, 0.6, 0.7)
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rings.material_override = ring_mat

	# Cut out the inner portion (simple approach - in production use a proper ring mesh)
	# This is a placeholder - proper rings would use a custom mesh or shader

	return rings

func _get_orbital_angle(planet_name: String) -> float:
	# Spread planets around the sun for visual interest
	var angles: Dictionary = {
		"Earth": 0.0,       # Earth directly in front of sun from spawn
		"Moon": 0.15,       # Moon slightly offset from Earth
		"Mars": 1.2,        # Mars off to the side
		"Jupiter": 2.8,     # Jupiter in another direction
		"Saturn": 4.5
	}
	return angles.get(planet_name, 0.0)

func _setup_player_spawn() -> void:
	_player_spawn = Marker3D.new()
	_player_spawn.name = "PlayerSpawn"

	if spawn_near_earth and _planets.has("Earth"):
		var earth: Node3D = _planets["Earth"]
		_player_spawn.position = earth.position + spawn_offset
		# Face forward into space (Earth will be visible to the left)
		_player_spawn.rotation_degrees = Vector3(0, -30, 0)
	else:
		_player_spawn.position = Vector3(0, 0, 5000)

	add_child(_player_spawn)

# =============================================================================
# RUNTIME
# =============================================================================

func _process(delta: float) -> void:
	# Rotate planets slowly for visual effect
	for planet_name in _planets:
		var planet: Node3D = _planets[planet_name]
		var speed: float = planet.get_meta("rotation_speed", 0.0)
		var mesh: Node3D = planet.get_node_or_null("Mesh")
		if mesh:
			mesh.rotate_y(speed * delta)

# =============================================================================
# PUBLIC API
# =============================================================================

## Get the spawn position for placing the player ship
func get_player_spawn_position() -> Vector3:
	return _player_spawn.global_position

## Get the spawn transform (position and rotation)
func get_player_spawn_transform() -> Transform3D:
	return _player_spawn.global_transform

## Get a planet node by name
func get_planet(planet_name: String) -> Node3D:
	return _planets.get(planet_name, null)

## Get Earth specifically (commonly needed)
func get_earth() -> Node3D:
	return get_planet("Earth")

## Get position suitable for Spacedock (high Earth orbit)
func get_spacedock_position() -> Vector3:
	var earth := get_earth()
	if earth:
		return earth.position + Vector3(0, 200, -800)
	return Vector3.ZERO

## Get all planet names
func get_planet_names() -> Array:
	return _planets.keys()

## Get planet description (for UI/scanning)
func get_planet_description(planet_name: String) -> String:
	if planet_data.has(planet_name):
		return planet_data[planet_name].get("description", "")
	return ""
