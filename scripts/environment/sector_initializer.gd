extends Node
class_name SectorInitializer
## Handles sector initialization - positions player ship at spawn point
##
## Attach this to any sector scene to automatically position the player ship.
## Requires:
##   - A SectorSol (or similar sector script) as parent or sibling
##   - A ship node with the specified path

@export var ship_path: NodePath
@export var use_spawn_transform: bool = true

var _sector: Node
var _ship: Node3D

func _ready() -> void:
	# Find sector script (parent should have it)
	_sector = get_parent()

	# Find ship
	if ship_path:
		_ship = get_node_or_null(ship_path)

	# Position ship at spawn after sector is ready
	call_deferred("_position_ship")

func _position_ship() -> void:
	if not _ship:
		push_warning("SectorInitializer: No ship found at path: ", ship_path)
		return

	if _sector.has_method("get_player_spawn_transform") and use_spawn_transform:
		_ship.global_transform = _sector.get_player_spawn_transform()
		print("Ship positioned at sector spawn point")
	elif _sector.has_method("get_player_spawn_position"):
		_ship.global_position = _sector.get_player_spawn_position()
		print("Ship positioned at sector spawn position")
