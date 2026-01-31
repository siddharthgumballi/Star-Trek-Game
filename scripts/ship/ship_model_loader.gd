extends Node3D
class_name ShipModelLoader
## Dynamically loads the ship model based on GlobalShipData selection

const MODELS_PATH := "res://assets/models/"

@export var default_model: String = "Enterprise_D.glb"

var _current_model: Node3D = null

func _ready() -> void:
	# Wait a frame for GlobalShipData to be ready
	await get_tree().process_frame
	_load_selected_ship()
	print("ShipModelLoader: Model loading complete")

func _load_selected_ship() -> void:
	# Get the model path from GlobalShipData
	var model_file: String = default_model
	var global_ship = get_node_or_null("/root/GlobalShipData")

	if global_ship and not global_ship.selected_ship_data.is_empty():
		model_file = global_ship.selected_ship_data.get("model", default_model)

	var model_path: String = MODELS_PATH + model_file

	# Remove existing model if any
	if _current_model:
		_current_model.queue_free()
		_current_model = null

	# Also remove any existing child models (from scene)
	for child in get_children():
		if child is Node3D and not child is CollisionShape3D:
			child.queue_free()

	# Load the new model
	if ResourceLoader.exists(model_path):
		var model_scene: PackedScene = load(model_path)
		if model_scene:
			_current_model = model_scene.instantiate()
			_current_model.name = "ShipMesh"

			# Rotate to face forward (-Z is forward in Godot)
			_current_model.rotation.y = PI

			# Auto-scale based on bounding box to normalize ship sizes
			var aabb := _get_node_aabb(_current_model)
			var max_dim: float = max(aabb.size.x, max(aabb.size.y, aabb.size.z))

			# Target size - 250x scale (real Enterprise-D is 642m = 0.642km)
			# At 250x: 160.5 km = ~40 units (1 unit ≈ 4 km)
			var target_size: float = 40.0
			if max_dim > 0:
				var scale_factor: float = target_size / max_dim
				# Apply custom scale from ship data
				var custom_scale: float = 1.0
				if global_ship and not global_ship.selected_ship_data.is_empty():
					custom_scale = global_ship.selected_ship_data.get("scale", 1.0)
				_current_model.scale = Vector3.ONE * scale_factor * custom_scale

			add_child(_current_model)
			print("Loaded ship model: ", model_file)
	else:
		push_warning("Ship model not found: " + model_path)
		# Fallback to default
		if model_file != default_model:
			var fallback_path: String = MODELS_PATH + default_model
			if ResourceLoader.exists(fallback_path):
				var fallback_scene: PackedScene = load(fallback_path)
				if fallback_scene:
					_current_model = fallback_scene.instantiate()
					_current_model.name = "ShipMesh"
					_current_model.rotation.y = PI
					add_child(_current_model)
					print("Loaded fallback model: ", default_model)

func _get_node_aabb(node: Node3D) -> AABB:
	var aabb := AABB()
	var first := true

	for child in node.get_children():
		if child is MeshInstance3D:
			var mesh_aabb: AABB = child.get_aabb()
			# Transform by child's local transform
			var transformed_pos: Vector3 = child.transform * mesh_aabb.position
			mesh_aabb.position = transformed_pos
			if first:
				aabb = mesh_aabb
				first = false
			else:
				aabb = aabb.merge(mesh_aabb)
		if child is Node3D:
			var child_aabb := _get_node_aabb(child)
			if child_aabb.size != Vector3.ZERO:
				if first:
					aabb = child_aabb
					first = false
				else:
					aabb = aabb.merge(child_aabb)

	return aabb

func get_model() -> Node3D:
	return _current_model

## Apply a shader material as overlay to all mesh instances in the ship model
## Used for warp stretch effect
func apply_warp_shader(shader_material: ShaderMaterial) -> void:
	if not _current_model:
		return

	_apply_shader_recursive(_current_model, shader_material)

func _apply_shader_recursive(node: Node, shader_material: ShaderMaterial) -> void:
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node
		# Store original material overlay if any
		if not mesh_instance.has_meta("_original_material_overlay"):
			mesh_instance.set_meta("_original_material_overlay", mesh_instance.material_overlay)
		mesh_instance.material_overlay = shader_material

	for child in node.get_children():
		_apply_shader_recursive(child, shader_material)

## Remove warp shader overlay and restore original material
func remove_warp_shader() -> void:
	if not _current_model:
		return

	_remove_shader_recursive(_current_model)

func _remove_shader_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node
		# Restore original material overlay
		if mesh_instance.has_meta("_original_material_overlay"):
			mesh_instance.material_overlay = mesh_instance.get_meta("_original_material_overlay")
			mesh_instance.remove_meta("_original_material_overlay")
		else:
			mesh_instance.material_overlay = null

	for child in node.get_children():
		_remove_shader_recursive(child)
