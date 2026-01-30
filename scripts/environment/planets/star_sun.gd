extends Node3D
class_name StarSun
## The Sun - Emissive star with glow effect
##
## TEXTURE (optional):
##   - sun.jpg   (solar surface texture)
##
## The Sun doesn't need complex texturing - it's primarily emissive
## The glow effect is achieved through:
##   1. Unshaded emissive material
##   2. Post-process bloom (handled by WorldEnvironment)
##   3. Optional corona effect

@export_group("Sun Properties")
@export var sun_radius: float = 800.0
@export var sun_color: Color = Color(1.0, 0.95, 0.85)  # Warm yellow-white
@export var emission_strength: float = 5.0
@export var texture_path: String = ""

@export_group("Corona")
@export var corona_enabled: bool = true
@export var corona_color: Color = Color(1.0, 0.9, 0.7, 0.2)
@export var corona_size: float = 1.3  # Multiplier of sun radius

@export_group("Rotation")
@export var rotation_speed: float = 0.001  # Sun rotates slowly

# Internal
var _sun_mesh: MeshInstance3D
var _corona_mesh: MeshInstance3D
var _sun_material: StandardMaterial3D
var _corona_material: ShaderMaterial

func _ready() -> void:
	_create_sun_mesh()
	if corona_enabled:
		_create_corona()
	print("Sun created: radius ", sun_radius)

func _create_sun_mesh() -> void:
	_sun_mesh = MeshInstance3D.new()
	_sun_mesh.name = "SunMesh"

	var sphere := SphereMesh.new()
	sphere.radius = sun_radius
	sphere.height = sun_radius * 2.0
	sphere.radial_segments = 64
	sphere.rings = 32
	_sun_mesh.mesh = sphere

	# Emissive material - unshaded for maximum brightness
	_sun_material = StandardMaterial3D.new()
	_sun_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_sun_material.albedo_color = sun_color
	_sun_material.emission_enabled = true
	_sun_material.emission = sun_color
	_sun_material.emission_energy_multiplier = emission_strength

	# Load texture if available
	if texture_path != "" and ResourceLoader.exists(texture_path):
		var tex = load(texture_path) as Texture2D
		if tex:
			_sun_material.albedo_texture = tex
			_sun_material.emission_texture = tex
			print("  Loaded sun texture: ", texture_path)

	_sun_mesh.material_override = _sun_material
	_sun_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	add_child(_sun_mesh)

func _create_corona() -> void:
	## Creates a soft glow around the sun using a rim shader
	_corona_mesh = MeshInstance3D.new()
	_corona_mesh.name = "Corona"

	var corona_sphere := SphereMesh.new()
	corona_sphere.radius = sun_radius * corona_size
	corona_sphere.height = sun_radius * corona_size * 2.0
	corona_sphere.radial_segments = 48
	corona_sphere.rings = 24
	_corona_mesh.mesh = corona_sphere

	# Corona shader for soft glow effect
	_corona_material = ShaderMaterial.new()
	_corona_material.shader = _create_corona_shader()
	_corona_material.set_shader_parameter("corona_color", corona_color)
	_corona_material.set_shader_parameter("falloff", 2.0)

	_corona_mesh.material_override = _corona_material
	_corona_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	add_child(_corona_mesh)

func _create_corona_shader() -> Shader:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_front, unshaded;

uniform vec4 corona_color : source_color = vec4(1.0, 0.9, 0.7, 0.2);
uniform float falloff : hint_range(0.5, 5.0) = 2.0;

varying vec3 world_normal;
varying vec3 world_position;

void vertex() {
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - world_position);
	float rim = 1.0 - max(dot(view_dir, normalize(world_normal)), 0.0);
	rim = pow(rim, falloff);

	ALBEDO = corona_color.rgb * 2.0;  // Boost brightness
	ALPHA = rim * corona_color.a;
}
"""
	return shader

func _process(delta: float) -> void:
	# Slow rotation
	if _sun_mesh and rotation_speed != 0.0:
		_sun_mesh.rotate_y(rotation_speed * delta)

# =============================================================================
# PUBLIC API
# =============================================================================

func set_emission_strength(strength: float) -> void:
	emission_strength = strength
	if _sun_material:
		_sun_material.emission_energy_multiplier = strength

func set_sun_color(color: Color) -> void:
	sun_color = color
	if _sun_material:
		_sun_material.albedo_color = color
		_sun_material.emission = color

func set_corona_visible(visible: bool) -> void:
	if _corona_mesh:
		_corona_mesh.visible = visible
