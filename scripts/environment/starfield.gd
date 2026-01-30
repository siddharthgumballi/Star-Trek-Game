extends Node3D
class_name Starfield
## Generates a simple starfield for visual reference in space.
## Stars are placed on a large sphere that follows the camera.

@export var star_count: int = 5000
@export var sphere_radius: float = 400000.0  # 400k units - within camera far plane
@export var min_star_size: float = 50.0
@export var max_star_size: float = 200.0

var _star_mesh: SphereMesh
var _star_material: StandardMaterial3D
var _multimesh: MultiMesh
var _multimesh_instance: MultiMeshInstance3D

func _ready() -> void:
	_create_starfield()

func _process(_delta: float) -> void:
	# Follow the camera so stars are always visible
	var camera := get_viewport().get_camera_3d()
	if camera:
		global_position = camera.global_position

func _create_starfield() -> void:
	# Create star mesh (small sphere)
	_star_mesh = SphereMesh.new()
	_star_mesh.radius = 1.0
	_star_mesh.height = 2.0
	_star_mesh.radial_segments = 4
	_star_mesh.rings = 2

	# Create emissive material so stars glow (subtle, not competing with sun)
	_star_material = StandardMaterial3D.new()
	_star_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_star_material.albedo_color = Color.WHITE
	_star_material.emission_enabled = true
	_star_material.emission = Color.WHITE
	_star_material.emission_energy_multiplier = 0.8  # Reduced from 2.0

	_star_mesh.material = _star_material

	# Create MultiMesh for efficient rendering of many stars
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_colors = true
	_multimesh.mesh = _star_mesh
	_multimesh.instance_count = star_count

	# Position stars randomly on sphere surface
	for i in range(star_count):
		var pos := _random_point_on_sphere() * sphere_radius
		var star_size := randf_range(min_star_size, max_star_size)

		var star_transform := Transform3D()
		star_transform.origin = pos
		star_transform = star_transform.scaled(Vector3.ONE * star_size)

		_multimesh.set_instance_transform(i, star_transform)

		# Random star color (mostly white, some tinted)
		var color := _random_star_color()
		_multimesh.set_instance_color(i, color)

	# Create instance and add to scene
	_multimesh_instance = MultiMeshInstance3D.new()
	_multimesh_instance.multimesh = _multimesh
	add_child(_multimesh_instance)

func _random_point_on_sphere() -> Vector3:
	# Uniform distribution on sphere surface
	var theta := randf() * TAU
	var phi := acos(2.0 * randf() - 1.0)

	return Vector3(
		sin(phi) * cos(theta),
		sin(phi) * sin(theta),
		cos(phi)
	)

func _random_star_color() -> Color:
	var roll := randf()
	if roll < 0.7:
		# White star
		return Color(1, 1, 1, 1)
	elif roll < 0.8:
		# Blue-white
		return Color(0.8, 0.9, 1, 1)
	elif roll < 0.9:
		# Yellow
		return Color(1, 1, 0.8, 1)
	else:
		# Red
		return Color(1, 0.7, 0.6, 1)
