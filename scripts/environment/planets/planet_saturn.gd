extends PlanetBase
class_name PlanetSaturn
## Saturn - Gas giant with iconic ring system
##
## REQUIRED TEXTURES (place in res://assets/textures/planets/):
##   - saturn.jpg          (color map - bands and storms)
##   - saturn_ring.png     (ring texture with alpha - MUST have transparency)
##
## DOWNLOAD FROM:
##   https://www.solarsystemscope.com/textures/
##   Select "Saturn" for planet, and "Saturn Ring" for rings
##
## RING SYSTEM:
##   Creates a flat disc mesh with proper UV mapping
##   Ring texture should be a horizontal strip with alpha transparency
##   Inner edge is the gap near Saturn, outer edge fades to space

@export_group("Ring Properties")
@export var rings_enabled: bool = true
@export var ring_texture_path: String = ""
@export var ring_inner_radius: float = 1.2  # Multiplier of planet radius
@export var ring_outer_radius: float = 2.3  # Multiplier of planet radius
@export var ring_segments: int = 128
@export var ring_color: Color = Color(0.9, 0.85, 0.7, 0.8)
@export var ring_tilt: float = 26.7  # Saturn's ring tilt in degrees

# Internal
var _ring_mesh: MeshInstance3D
var _ring_material: StandardMaterial3D

func _ready() -> void:
	# Set Saturn-specific defaults
	planet_name = "Saturn"
	axial_tilt = 26.7  # Saturn's axial tilt matches ring tilt

	# Call parent _ready
	super._ready()

	# Add rings
	if rings_enabled:
		_create_rings()

func _create_rings() -> void:
	## Creates Saturn's ring system as a flat disc with hole in center
	_ring_mesh = MeshInstance3D.new()
	_ring_mesh.name = "Rings"

	# Create ring geometry using ArrayMesh for proper UV mapping
	var ring_mesh := _generate_ring_mesh()
	_ring_mesh.mesh = ring_mesh

	# Ring material
	_ring_material = StandardMaterial3D.new()
	_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_material.cull_mode = BaseMaterial3D.CULL_DISABLED  # Visible from both sides
	_ring_material.albedo_color = ring_color
	_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL

	# Load ring texture if available
	if ring_texture_path != "" and ResourceLoader.exists(ring_texture_path):
		var ring_tex = load(ring_texture_path) as Texture2D
		if ring_tex:
			_ring_material.albedo_texture = ring_tex
			_ring_material.albedo_color = Color.WHITE
			print("  Loaded ring texture: ", ring_texture_path)
	else:
		# Create procedural ring pattern if no texture
		_ring_material.albedo_color = ring_color

	_ring_mesh.material_override = _ring_material
	_ring_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Tilt rings to match planet's axial tilt
	_ring_mesh.rotation_degrees.z = axial_tilt

	add_child(_ring_mesh)

func _generate_ring_mesh() -> ArrayMesh:
	## Generates a ring/disc mesh with proper UVs for ring texture
	var arr_mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	var inner_r: float = planet_radius * ring_inner_radius
	var outer_r: float = planet_radius * ring_outer_radius

	# Generate ring vertices
	for i in range(ring_segments + 1):
		var angle: float = (float(i) / float(ring_segments)) * TAU
		var cos_a: float = cos(angle)
		var sin_a: float = sin(angle)

		# Inner vertex
		vertices.append(Vector3(cos_a * inner_r, 0, sin_a * inner_r))
		normals.append(Vector3.UP)
		uvs.append(Vector2(float(i) / float(ring_segments), 0.0))

		# Outer vertex
		vertices.append(Vector3(cos_a * outer_r, 0, sin_a * outer_r))
		normals.append(Vector3.UP)
		uvs.append(Vector2(float(i) / float(ring_segments), 1.0))

	# Generate indices for triangle strip
	for i in range(ring_segments):
		var base: int = i * 2

		# First triangle
		indices.append(base)
		indices.append(base + 1)
		indices.append(base + 2)

		# Second triangle
		indices.append(base + 1)
		indices.append(base + 3)
		indices.append(base + 2)

	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	return arr_mesh

func _process(delta: float) -> void:
	# Parent rotation
	super._process(delta)

	# Rings don't rotate with the planet (they're in orbital plane)
	# But we keep them aligned with the axial tilt

# =============================================================================
# PUBLIC API
# =============================================================================

## Update ring visibility
func set_rings_visible(visible: bool) -> void:
	if _ring_mesh:
		_ring_mesh.visible = visible

## Update ring dimensions
func set_ring_dimensions(inner_mult: float, outer_mult: float) -> void:
	ring_inner_radius = inner_mult
	ring_outer_radius = outer_mult
	if _ring_mesh:
		_ring_mesh.mesh = _generate_ring_mesh()

## Update ring color/transparency
func set_ring_color(color: Color) -> void:
	ring_color = color
	if _ring_material:
		if _ring_material.albedo_texture:
			_ring_material.albedo_color = Color.WHITE
		else:
			_ring_material.albedo_color = color

## Get ring mesh for additional modifications
func get_ring_mesh() -> MeshInstance3D:
	return _ring_mesh
