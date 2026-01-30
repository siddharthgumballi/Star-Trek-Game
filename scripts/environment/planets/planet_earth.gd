extends PlanetBase
class_name PlanetEarth
## Earth - Special planet with atmosphere, clouds, and city lights
##
## REQUIRED TEXTURES (place in res://assets/textures/planets/):
##   - earth_daymap.jpg      (color map - continents, oceans)
##   - earth_normal.jpg      (optional - terrain bumps)
##   - earth_specular.jpg    (optional - ocean reflections)
##   - earth_nightmap.jpg    (optional - city lights)
##   - earth_clouds.jpg      (optional - cloud layer)
##
## DOWNLOAD FROM:
##   https://www.solarsystemscope.com/textures/
##   Select "Earth" -> Download 2K or 4K versions
##
## ATMOSPHERE EFFECT:
##   Creates a secondary, slightly larger sphere with a custom shader
##   that produces a blue glow at the limb (edge) of the planet

@export_group("Atmosphere")
@export var atmosphere_enabled: bool = true
@export var atmosphere_color: Color = Color(0.4, 0.6, 1.0, 0.3)
@export var atmosphere_height: float = 0.03  # Percentage of planet radius
@export var atmosphere_falloff: float = 3.0  # How quickly glow fades

@export_group("Clouds")
@export var clouds_enabled: bool = true
@export var clouds_texture_path: String = ""
@export var clouds_height: float = 0.005  # Above surface
@export var clouds_rotation_offset: float = 0.002  # Clouds move slightly faster

# Internal
var _atmosphere_mesh: MeshInstance3D
var _clouds_mesh: MeshInstance3D
var _atmosphere_material: ShaderMaterial
var _clouds_material: StandardMaterial3D

func _ready() -> void:
	# Set Earth-specific defaults
	planet_name = "Earth"
	axial_tilt = 23.4  # Earth's actual axial tilt

	# Call parent _ready
	super._ready()

	# Add Earth-specific features
	if atmosphere_enabled:
		_create_atmosphere()
	if clouds_enabled:
		_create_clouds()

func _create_atmosphere() -> void:
	## Creates a glowing atmosphere effect using a rim-lighting shader
	_atmosphere_mesh = MeshInstance3D.new()
	_atmosphere_mesh.name = "Atmosphere"

	var atmo_sphere := SphereMesh.new()
	var atmo_radius: float = planet_radius * (1.0 + atmosphere_height)
	atmo_sphere.radius = atmo_radius
	atmo_sphere.height = atmo_radius * 2.0
	atmo_sphere.radial_segments = 48
	atmo_sphere.rings = 24
	_atmosphere_mesh.mesh = atmo_sphere

	# Create atmosphere shader material
	_atmosphere_material = ShaderMaterial.new()
	_atmosphere_material.shader = _create_atmosphere_shader()
	_atmosphere_material.set_shader_parameter("atmosphere_color", atmosphere_color)
	_atmosphere_material.set_shader_parameter("falloff", atmosphere_falloff)

	_atmosphere_mesh.material_override = _atmosphere_material
	_atmosphere_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	add_child(_atmosphere_mesh)

func _create_atmosphere_shader() -> Shader:
	## Rim-glow shader for atmosphere effect
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_front, unshaded;

uniform vec4 atmosphere_color : source_color = vec4(0.4, 0.6, 1.0, 0.3);
uniform float falloff : hint_range(0.1, 10.0) = 3.0;

varying vec3 world_normal;
varying vec3 world_position;

void vertex() {
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Calculate view direction
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - world_position);

	// Rim lighting - stronger at edges
	float rim = 1.0 - max(dot(view_dir, normalize(world_normal)), 0.0);
	rim = pow(rim, falloff);

	ALBEDO = atmosphere_color.rgb;
	ALPHA = rim * atmosphere_color.a;
}
"""
	return shader

func _create_clouds() -> void:
	## Creates a cloud layer that rotates slightly faster than the surface
	_clouds_mesh = MeshInstance3D.new()
	_clouds_mesh.name = "Clouds"

	var cloud_sphere := SphereMesh.new()
	var cloud_radius: float = planet_radius * (1.0 + clouds_height)
	cloud_sphere.radius = cloud_radius
	cloud_sphere.height = cloud_radius * 2.0
	cloud_sphere.radial_segments = 48
	cloud_sphere.rings = 24
	_clouds_mesh.mesh = cloud_sphere

	# Cloud material - transparent white with texture
	_clouds_material = StandardMaterial3D.new()
	_clouds_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_clouds_material.albedo_color = Color(1.0, 1.0, 1.0, 0.6)
	_clouds_material.cull_mode = BaseMaterial3D.CULL_BACK

	# Load cloud texture if available
	if clouds_texture_path != "" and ResourceLoader.exists(clouds_texture_path):
		var cloud_tex = load(clouds_texture_path) as Texture2D
		if cloud_tex:
			_clouds_material.albedo_texture = cloud_tex
			print("  Loaded clouds: ", clouds_texture_path)

	_clouds_mesh.material_override = _clouds_material
	_clouds_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Apply same axial tilt
	_clouds_mesh.rotation_degrees.z = axial_tilt

	add_child(_clouds_mesh)

func _process(delta: float) -> void:
	# Parent rotation
	super._process(delta)

	# Clouds rotate slightly faster (weather patterns)
	if _clouds_mesh and rotation_speed != 0.0:
		_clouds_mesh.rotate_y((rotation_speed + clouds_rotation_offset) * delta)

# =============================================================================
# PUBLIC API
# =============================================================================

## Update atmosphere color
func set_atmosphere_color(color: Color) -> void:
	atmosphere_color = color
	if _atmosphere_material:
		_atmosphere_material.set_shader_parameter("atmosphere_color", color)

## Update atmosphere intensity
func set_atmosphere_falloff(value: float) -> void:
	atmosphere_falloff = value
	if _atmosphere_material:
		_atmosphere_material.set_shader_parameter("falloff", value)

## Toggle atmosphere visibility
func set_atmosphere_visible(visible: bool) -> void:
	if _atmosphere_mesh:
		_atmosphere_mesh.visible = visible

## Toggle clouds visibility
func set_clouds_visible(visible: bool) -> void:
	if _clouds_mesh:
		_clouds_mesh.visible = visible
