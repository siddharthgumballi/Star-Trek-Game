extends Node3D
class_name PlanetBase
## Base class for all planets - handles mesh, material, rotation, and texturing
##
## TEXTURE SETUP:
##   1. Download NASA textures from: https://www.solarsystemscope.com/textures/
##      Or: https://planetpixelemporium.com/planets.html (free for non-commercial)
##   2. Place textures in res://assets/textures/planets/
##   3. Assign texture path in the exported variable
##
## TO SWAP TEXTURES:
##   - Change the texture_path export variable
##   - For higher resolution, simply replace the file (keep same name)
##   - Supports JPG, PNG, and WebP formats
##
## TO ADJUST SCALE:
##   - Modify planet_radius for visual size
##   - Modify orbit_distance in parent scene for positioning
##
## MATERIAL PROPERTIES:
##   - albedo_texture: Main color/surface map
##   - normal_texture: Optional bump mapping for terrain
##   - emission_texture: Optional night-side lights (Earth)
##   - roughness: How shiny the surface appears

@export_group("Planet Properties")
@export var planet_name: String = "Planet"
@export var planet_radius: float = 100.0
@export var rotation_speed: float = 0.01  # Radians per second
@export var axial_tilt: float = 0.0  # Degrees

@export_group("Textures")
## Path to albedo/color texture (e.g., "res://assets/textures/planets/earth_daymap.jpg")
@export var albedo_texture_path: String = ""
## Path to normal/bump map texture (optional)
@export var normal_texture_path: String = ""
## Path to specular map (optional, for oceans/ice)
@export var specular_texture_path: String = ""
## Path to night/emission texture (optional, for city lights)
@export var emission_texture_path: String = ""

@export_group("Material Settings")
@export var base_color: Color = Color(0.8, 0.8, 0.8)
@export var roughness: float = 0.8
@export var metallic: float = 0.0
@export var emission_strength: float = 0.0

@export_group("Mesh Quality")
@export var radial_segments: int = 64
@export var rings: int = 32

# Internal references
var _mesh_instance: MeshInstance3D
var _material: StandardMaterial3D
var _sphere_mesh: SphereMesh

func _ready() -> void:
	_create_planet_mesh()
	_setup_material()
	_apply_textures()
	_apply_axial_tilt()
	print("Planet created: ", planet_name, " (radius: ", planet_radius, ")")

func _create_planet_mesh() -> void:
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "PlanetMesh"

	_sphere_mesh = SphereMesh.new()
	_sphere_mesh.radius = planet_radius
	_sphere_mesh.height = planet_radius * 2.0
	_sphere_mesh.radial_segments = radial_segments
	_sphere_mesh.rings = rings

	_mesh_instance.mesh = _sphere_mesh
	add_child(_mesh_instance)

func _setup_material() -> void:
	_material = StandardMaterial3D.new()

	# Base properties
	_material.albedo_color = base_color
	_material.roughness = roughness
	_material.metallic = metallic

	# Enable features we might use
	_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	# Emission for night-side or hot planets
	if emission_strength > 0:
		_material.emission_enabled = true
		_material.emission_energy_multiplier = emission_strength

	_mesh_instance.material_override = _material

func _apply_textures() -> void:
	# Load and apply albedo texture
	if albedo_texture_path != "" and ResourceLoader.exists(albedo_texture_path):
		var albedo_tex = load(albedo_texture_path) as Texture2D
		if albedo_tex:
			_material.albedo_texture = albedo_tex
			_material.albedo_color = Color.WHITE  # Let texture show through
			print("  Loaded albedo: ", albedo_texture_path)

	# Load and apply normal map
	if normal_texture_path != "" and ResourceLoader.exists(normal_texture_path):
		var normal_tex = load(normal_texture_path) as Texture2D
		if normal_tex:
			_material.normal_enabled = true
			_material.normal_texture = normal_tex
			_material.normal_scale = 1.0
			print("  Loaded normal: ", normal_texture_path)

	# Load and apply specular map (as roughness texture, inverted)
	if specular_texture_path != "" and ResourceLoader.exists(specular_texture_path):
		var spec_tex = load(specular_texture_path) as Texture2D
		if spec_tex:
			_material.roughness_texture = spec_tex
			print("  Loaded specular: ", specular_texture_path)

	# Load and apply emission texture (night lights)
	if emission_texture_path != "" and ResourceLoader.exists(emission_texture_path):
		var emission_tex = load(emission_texture_path) as Texture2D
		if emission_tex:
			_material.emission_enabled = true
			_material.emission_texture = emission_tex
			_material.emission_energy_multiplier = emission_strength if emission_strength > 0 else 1.0
			print("  Loaded emission: ", emission_texture_path)

func _apply_axial_tilt() -> void:
	if axial_tilt != 0.0:
		_mesh_instance.rotation_degrees.z = axial_tilt

func _process(delta: float) -> void:
	# Rotate planet around its axis
	if rotation_speed != 0.0:
		_mesh_instance.rotate_y(rotation_speed * delta)

# =============================================================================
# PUBLIC API
# =============================================================================

## Update planet radius at runtime
func set_radius(new_radius: float) -> void:
	planet_radius = new_radius
	if _sphere_mesh:
		_sphere_mesh.radius = new_radius
		_sphere_mesh.height = new_radius * 2.0

## Update rotation speed
func set_rotation_speed(speed: float) -> void:
	rotation_speed = speed

## Get the mesh instance for additional modifications
func get_mesh() -> MeshInstance3D:
	return _mesh_instance

## Get the material for additional modifications
func get_material() -> StandardMaterial3D:
	return _material

## Dynamically load a new albedo texture
func set_albedo_texture(path: String) -> void:
	if ResourceLoader.exists(path):
		var tex = load(path) as Texture2D
		if tex and _material:
			_material.albedo_texture = tex
			_material.albedo_color = Color.WHITE
