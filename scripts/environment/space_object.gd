extends Node3D
class_name SpaceObject
## Base class for space objects (stations, ships, planets, waypoints)

enum ObjectType { STATION, SHIP, PLANET, WAYPOINT, ASTEROID }

@export var object_name: String = "Unknown"
@export var object_type: ObjectType = ObjectType.STATION
@export var object_color: Color = Color.WHITE

var _label: Label3D
var _marker: MeshInstance3D

func _ready() -> void:
	_create_marker()
	_create_label()

func _create_marker() -> void:
	_marker = MeshInstance3D.new()

	match object_type:
		ObjectType.STATION:
			var mesh := BoxMesh.new()
			mesh.size = Vector3(100, 100, 100)
			_marker.mesh = mesh
			object_color = Color(0.6, 0.8, 1.0)

		ObjectType.SHIP:
			var mesh := BoxMesh.new()
			mesh.size = Vector3(50, 20, 80)
			_marker.mesh = mesh
			object_color = Color(0.8, 0.8, 0.8)

		ObjectType.PLANET:
			var mesh := SphereMesh.new()
			mesh.radius = 500
			mesh.height = 1000
			_marker.mesh = mesh
			object_color = Color(0.4, 0.6, 0.3)

		ObjectType.WAYPOINT:
			var mesh := SphereMesh.new()
			mesh.radius = 20
			mesh.height = 40
			_marker.mesh = mesh
			object_color = Color(1.0, 0.8, 0.2)

		ObjectType.ASTEROID:
			var mesh := SphereMesh.new()
			mesh.radius = 50
			mesh.height = 100
			_marker.mesh = mesh
			object_color = Color(0.4, 0.35, 0.3)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = object_color
	if object_type == ObjectType.WAYPOINT:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.emission_enabled = true
		mat.emission = object_color
		mat.emission_energy_multiplier = 2.0
	_marker.material_override = mat

	add_child(_marker)

func _create_label() -> void:
	_label = Label3D.new()
	_label.text = object_name
	_label.font_size = 32
	_label.modulate = object_color
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3(0, 150, 0)
	_label.no_depth_test = true
	add_child(_label)

func get_object_name() -> String:
	return object_name

func get_object_type() -> ObjectType:
	return object_type
