extends Node
## Global singleton for storing selected ship data across scenes

var selected_ship_id: String = "enterprise_d"  # Default to Enterprise-D
var selected_ship_data: Dictionary = {}

func _ready() -> void:
	# Set default ship data
	if selected_ship_data.is_empty():
		selected_ship_data = get_default_ship_data()

func get_default_ship_data() -> Dictionary:
	return {
		"name": "USS Enterprise-D",
		"registry": "NCC-1701-D",
		"class": "Galaxy Class",
		"max_warp": 9.9,
		"model": "Enterprise_D.glb",
		"scale": 1.0,
		"era": "2363-2371"
	}

func get_model_path() -> String:
	var model_file: String = selected_ship_data.get("model", "Enterprise_D.glb")
	return "res://assets/models/" + model_file

func get_max_warp() -> float:
	return selected_ship_data.get("max_warp", 9.9)

func get_ship_name() -> String:
	return selected_ship_data.get("name", "USS Enterprise-D")

func get_registry() -> String:
	return selected_ship_data.get("registry", "NCC-1701-D")

func get_ship_class() -> String:
	return selected_ship_data.get("class", "Galaxy Class")
