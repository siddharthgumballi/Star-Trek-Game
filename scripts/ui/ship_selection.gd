extends Control
class_name ShipSelection
## Ship selection screen with 3D preview carousel

signal ship_selected(ship_id: String)

const MODELS_PATH := "res://assets/models/"

# Ship database - maps ship_id to ship data
# Lengths are actual ship lengths in meters for proper scaling
var SHIPS: Dictionary = {
	"enterprise_tos": {
		"name": "USS Enterprise",
		"registry": "NCC-1701",
		"class": "Constitution Class",
		"max_warp": 8.0,
		"model": "classic_u.s.s._enterprise_from_star_trek_tos.glb",
		"length": 289.0,  # meters
		"era": "2245-2285"
	},
	"enterprise_a": {
		"name": "USS Enterprise-A",
		"registry": "NCC-1701-A",
		"class": "Constitution II Class",
		"max_warp": 8.5,
		"model": "star_trek_online__constitution_ii_class.glb",
		"length": 305.0,
		"era": "2286-2293"
	},
	"enterprise_b": {
		"name": "USS Enterprise-B",
		"registry": "NCC-1701-B",
		"class": "Excelsior Class",
		"max_warp": 9.0,
		"model": "excelsior_refit_uss_enterprise_ncc-1701-b.glb",
		"length": 467.0,
		"era": "2293-2329"
	},
	"enterprise_c": {
		"name": "USS Enterprise-C",
		"registry": "NCC-1701-C",
		"class": "Ambassador Class",
		"max_warp": 9.2,
		"model": "ambassador_class_u.s.s._enterprise_ncc-1701-c.glb",
		"length": 526.0,
		"era": "2332-2344"
	},
	"enterprise_d": {
		"name": "USS Enterprise-D",
		"registry": "NCC-1701-D",
		"class": "Galaxy Class",
		"max_warp": 9.9,
		"model": "Enterprise_D.glb",
		"length": 642.5,
		"era": "2363-2371"
	},
	"enterprise_e": {
		"name": "USS Enterprise-E",
		"registry": "NCC-1701-E",
		"class": "Sovereign Class",
		"max_warp": 9.985,
		"model": "star_trek_online__sovereign_class.glb",
		"length": 685.0,
		"era": "2372-2408"
	},
	"enterprise_f": {
		"name": "USS Enterprise-F",
		"registry": "NCC-1701-F",
		"class": "Odyssey Class",
		"max_warp": 9.98,
		"model": "star_trek_online__odessey_class__enterprise_f.glb",
		"length": 1061.0,
		"era": "2409-2401"
	},
	"enterprise_g": {
		"name": "USS Enterprise-G",
		"registry": "NCC-1701-G",
		"class": "Constitution III Class",
		"max_warp": 9.99,
		"model": "star_trek_online__constitution_class_iii.glb",
		"length": 560.0,
		"era": "2402-Present"
	}
}

var ship_order: Array[String] = [
	"enterprise_tos", "enterprise_a", "enterprise_b", "enterprise_c",
	"enterprise_d", "enterprise_e", "enterprise_f", "enterprise_g"
]

# UI Colors (LCARS style)
var lcars_orange := Color(1.0, 0.6, 0.2)
var lcars_blue := Color(0.6, 0.8, 1.0)
var lcars_purple := Color(0.8, 0.6, 1.0)
var lcars_bg := Color(0.02, 0.02, 0.05)

# Current selection
var _current_index: int = 4  # Start with Enterprise-D
var _preview_viewport: SubViewport
var _preview_camera: Camera3D
var _preview_ship: Node3D
var _preview_container: SubViewportContainer
var _rotation_angle: float = 0.0

# Click-drag rotation
var _is_dragging: bool = false
var _drag_rotation_x: float = 0.0  # Pitch
var _drag_rotation_y: float = 0.0  # Yaw
var _auto_rotate: bool = true  # Auto-rotate when not dragging
var _drag_sensitivity: float = 0.01

# UI elements
var _title_label: Label
var _ship_name_label: Label
var _registry_label: Label
var _class_label: Label
var _warp_label: Label
var _era_label: Label
var _left_btn: Button
var _right_btn: Button
var _select_btn: Button
var _ship_buttons: Array[Button] = []

func _ready() -> void:
	_create_background()
	_create_preview_viewport()
	_create_ui()
	_load_ship_preview(ship_order[_current_index])

func _create_background() -> void:
	# Full screen dark background
	var bg := ColorRect.new()
	bg.color = lcars_bg
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Starfield effect (simple dots)
	var starfield := Control.new()
	starfield.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(starfield)

	for i in range(100):
		var star := ColorRect.new()
		star.color = Color(1, 1, 1, randf_range(0.3, 0.8))
		star.size = Vector2(2, 2)
		star.position = Vector2(randf() * 1920, randf() * 1080)
		starfield.add_child(star)

func _create_preview_viewport() -> void:
	# SubViewport for 3D ship preview - LARGE to fill most of the screen
	_preview_container = SubViewportContainer.new()
	_preview_container.stretch = true
	_preview_container.set_anchors_preset(Control.PRESET_CENTER)
	_preview_container.anchor_left = 0.05
	_preview_container.anchor_right = 0.95
	_preview_container.anchor_top = 0.08
	_preview_container.anchor_bottom = 0.72
	_preview_container.offset_left = 0
	_preview_container.offset_right = 0
	_preview_container.offset_top = 0
	_preview_container.offset_bottom = 0
	add_child(_preview_container)

	_preview_viewport = SubViewport.new()
	_preview_viewport.size = Vector2i(1728, 691)  # Larger viewport
	_preview_viewport.transparent_bg = true
	_preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_preview_container.add_child(_preview_viewport)

	# Preview scene setup
	var preview_scene := Node3D.new()
	preview_scene.name = "PreviewScene"
	_preview_viewport.add_child(preview_scene)

	# Camera - positioned closer for larger ships
	_preview_camera = Camera3D.new()
	_preview_camera.position = Vector3(0, 30, 200)
	_preview_camera.fov = 50
	_preview_camera.far = 10000
	preview_scene.add_child(_preview_camera)
	# Look at origin after adding to tree
	_preview_camera.look_at(Vector3.ZERO, Vector3.UP)

	# Lighting
	var key_light := DirectionalLight3D.new()
	key_light.light_color = Color(1.0, 0.98, 0.95)
	key_light.light_energy = 1.2
	key_light.rotation_degrees = Vector3(-30, 45, 0)
	preview_scene.add_child(key_light)

	var fill_light := DirectionalLight3D.new()
	fill_light.light_color = Color(0.6, 0.7, 0.9)
	fill_light.light_energy = 0.5
	fill_light.rotation_degrees = Vector3(10, -135, 0)
	preview_scene.add_child(fill_light)

	var rim_light := DirectionalLight3D.new()
	rim_light.light_color = Color(0.8, 0.9, 1.0)
	rim_light.light_energy = 0.3
	rim_light.rotation_degrees = Vector3(0, 180, 0)
	preview_scene.add_child(rim_light)

	# Environment
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.01, 0.02)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.15, 0.15, 0.2)
	env.ambient_light_energy = 0.5
	env_node.environment = env
	preview_scene.add_child(env_node)

	# Ship container (for rotation)
	_preview_ship = Node3D.new()
	_preview_ship.name = "ShipContainer"
	preview_scene.add_child(_preview_ship)

func _create_ui() -> void:
	# Title - positioned at top
	_title_label = Label.new()
	_title_label.text = "SELECT YOUR STARSHIP"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 32)
	_title_label.add_theme_color_override("font_color", lcars_orange)
	_title_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_title_label.offset_top = 10
	_title_label.offset_bottom = 50
	add_child(_title_label)

	# Info panel (bottom)
	var info_panel := Panel.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.05, 0.1, 0.9)
	panel_style.corner_radius_top_left = 15
	panel_style.corner_radius_top_right = 15
	panel_style.border_width_top = 3
	panel_style.border_color = lcars_blue
	info_panel.add_theme_stylebox_override("panel", panel_style)
	info_panel.anchor_left = 0.2
	info_panel.anchor_right = 0.8
	info_panel.anchor_top = 0.72
	info_panel.anchor_bottom = 0.88
	info_panel.offset_left = 0
	info_panel.offset_right = 0
	add_child(info_panel)

	# Info layout
	var info_hbox := HBoxContainer.new()
	info_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	info_hbox.add_theme_constant_override("separation", 50)
	info_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	info_panel.add_child(info_hbox)

	# Ship name section
	var name_vbox := VBoxContainer.new()
	name_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	info_hbox.add_child(name_vbox)

	_ship_name_label = Label.new()
	_ship_name_label.text = "USS Enterprise-D"
	_ship_name_label.add_theme_font_size_override("font_size", 28)
	_ship_name_label.add_theme_color_override("font_color", lcars_orange)
	name_vbox.add_child(_ship_name_label)

	_registry_label = Label.new()
	_registry_label.text = "NCC-1701-D"
	_registry_label.add_theme_font_size_override("font_size", 20)
	_registry_label.add_theme_color_override("font_color", lcars_blue)
	name_vbox.add_child(_registry_label)

	# Separator
	var sep := VSeparator.new()
	sep.custom_minimum_size.x = 2
	info_hbox.add_child(sep)

	# Class section
	var class_vbox := VBoxContainer.new()
	class_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	info_hbox.add_child(class_vbox)

	var class_title := Label.new()
	class_title.text = "CLASS"
	class_title.add_theme_font_size_override("font_size", 12)
	class_title.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	class_vbox.add_child(class_title)

	_class_label = Label.new()
	_class_label.text = "Galaxy Class"
	_class_label.add_theme_font_size_override("font_size", 18)
	_class_label.add_theme_color_override("font_color", Color.WHITE)
	class_vbox.add_child(_class_label)

	# Separator
	var sep2 := VSeparator.new()
	sep2.custom_minimum_size.x = 2
	info_hbox.add_child(sep2)

	# Warp section
	var warp_vbox := VBoxContainer.new()
	warp_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	info_hbox.add_child(warp_vbox)

	var warp_title := Label.new()
	warp_title.text = "MAX WARP"
	warp_title.add_theme_font_size_override("font_size", 12)
	warp_title.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	warp_vbox.add_child(warp_title)

	_warp_label = Label.new()
	_warp_label.text = "Warp 9.9"
	_warp_label.add_theme_font_size_override("font_size", 18)
	_warp_label.add_theme_color_override("font_color", lcars_purple)
	warp_vbox.add_child(_warp_label)

	# Separator
	var sep3 := VSeparator.new()
	sep3.custom_minimum_size.x = 2
	info_hbox.add_child(sep3)

	# Era section
	var era_vbox := VBoxContainer.new()
	era_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	info_hbox.add_child(era_vbox)

	var era_title := Label.new()
	era_title.text = "SERVICE ERA"
	era_title.add_theme_font_size_override("font_size", 12)
	era_title.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	era_vbox.add_child(era_title)

	_era_label = Label.new()
	_era_label.text = "2363-2371"
	_era_label.add_theme_font_size_override("font_size", 18)
	_era_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	era_vbox.add_child(_era_label)

	# Navigation arrows - positioned at sides of preview
	_left_btn = _create_nav_button("<", Vector2(50, 0.5), true)
	_left_btn.pressed.connect(_on_prev_ship)
	add_child(_left_btn)

	_right_btn = _create_nav_button(">", Vector2(-50, 0.5), false)
	_right_btn.pressed.connect(_on_next_ship)
	add_child(_right_btn)

	# Hint text for click-drag rotation
	var hint_label := Label.new()
	hint_label.text = "Click and drag to rotate ship"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 14)
	hint_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	hint_label.anchor_left = 0.0
	hint_label.anchor_right = 1.0
	hint_label.anchor_top = 0.70
	hint_label.anchor_bottom = 0.70
	hint_label.offset_top = 5
	hint_label.offset_bottom = 25
	add_child(hint_label)

	# Bottom container for ship buttons + engage button
	var bottom_container := VBoxContainer.new()
	bottom_container.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_container.add_theme_constant_override("separation", 15)
	bottom_container.anchor_left = 0.1
	bottom_container.anchor_right = 0.9
	bottom_container.anchor_top = 0.88
	bottom_container.anchor_bottom = 0.98
	add_child(bottom_container)

	# Ship selection buttons row
	var btn_container := HBoxContainer.new()
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_container.add_theme_constant_override("separation", 8)
	bottom_container.add_child(btn_container)

	for i in range(ship_order.size()):
		var ship_id: String = ship_order[i]
		var ship_data: Dictionary = SHIPS[ship_id]
		var btn := Button.new()
		btn.text = ship_data["registry"]
		btn.custom_minimum_size = Vector2(95, 32)
		btn.pressed.connect(_on_ship_button_pressed.bind(i))
		_style_ship_button(btn, i == _current_index)
		btn_container.add_child(btn)
		_ship_buttons.append(btn)

	# Engage button row (centered below ship buttons)
	var engage_container := HBoxContainer.new()
	engage_container.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_container.add_child(engage_container)

	_select_btn = Button.new()
	_select_btn.text = "ENGAGE"
	_select_btn.custom_minimum_size = Vector2(180, 45)
	_select_btn.pressed.connect(_on_select_pressed)

	var select_style := StyleBoxFlat.new()
	select_style.bg_color = Color(0.15, 0.35, 0.15)
	select_style.corner_radius_top_left = 8
	select_style.corner_radius_top_right = 8
	select_style.corner_radius_bottom_left = 8
	select_style.corner_radius_bottom_right = 8
	select_style.border_width_left = 2
	select_style.border_width_right = 2
	select_style.border_width_top = 2
	select_style.border_width_bottom = 2
	select_style.border_color = lcars_orange
	_select_btn.add_theme_stylebox_override("normal", select_style)

	var select_hover := select_style.duplicate()
	select_hover.bg_color = Color(0.25, 0.5, 0.25)
	_select_btn.add_theme_stylebox_override("hover", select_hover)

	_select_btn.add_theme_font_size_override("font_size", 18)
	_select_btn.add_theme_color_override("font_color", lcars_orange)
	engage_container.add_child(_select_btn)

func _create_nav_button(text: String, _offset: Vector2, is_left: bool) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(60, 100)

	if is_left:
		btn.anchor_left = 0.01
		btn.anchor_right = 0.01
	else:
		btn.anchor_left = 0.99
		btn.anchor_right = 0.99
	btn.anchor_top = 0.35
	btn.anchor_bottom = 0.35
	btn.offset_left = -30
	btn.offset_right = 30
	btn.offset_top = -50
	btn.offset_bottom = 50

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.8)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = lcars_blue
	btn.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate()
	hover.bg_color = Color(0.15, 0.15, 0.25, 0.9)
	hover.border_color = lcars_orange
	btn.add_theme_stylebox_override("hover", hover)

	btn.add_theme_font_size_override("font_size", 32)
	btn.add_theme_color_override("font_color", lcars_blue)

	return btn

func _style_ship_button(btn: Button, selected: bool) -> void:
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5

	if selected:
		style.bg_color = lcars_orange
		style.border_width_bottom = 3
		style.border_color = Color.WHITE
		btn.add_theme_color_override("font_color", Color.BLACK)
	else:
		style.bg_color = Color(0.15, 0.15, 0.2)
		style.border_width_bottom = 0
		btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

	btn.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate()
	hover.bg_color = style.bg_color.lightened(0.2)
	btn.add_theme_stylebox_override("hover", hover)

var _pending_model_data: Dictionary = {}

func _load_ship_preview(ship_id: String) -> void:
	var ship_data: Dictionary = SHIPS[ship_id]

	# Clear existing ship
	for child in _preview_ship.get_children():
		child.queue_free()

	# Reset rotation when loading new ship
	_drag_rotation_x = 0.0
	_drag_rotation_y = 0.0
	_rotation_angle = 0.0
	_auto_rotate = true

	# Load new ship model
	var model_path: String = MODELS_PATH + ship_data["model"]
	print("Loading ship model: ", model_path)

	if ResourceLoader.exists(model_path):
		var model_scene: PackedScene = load(model_path)
		if model_scene:
			var model: Node3D = model_scene.instantiate()

			# Add model to scene FIRST
			_preview_ship.add_child(model)

			# Force visibility immediately
			_force_visibility(model)

			# Debug: print model structure
			print("  Model children: ", model.get_child_count())
			_print_node_tree(model, "  ")

			# Store data for deferred processing
			_pending_model_data = {
				"model": model,
				"ship_data": ship_data
			}

			# Defer AABB calculation to next frame so transforms are initialized
			call_deferred("_finalize_model_setup")
		else:
			print("  ERROR: Failed to instantiate model scene")
	else:
		print("  ERROR: Model file does not exist: ", model_path)

	# Update info labels immediately
	_ship_name_label.text = ship_data["name"]
	_registry_label.text = ship_data["registry"]
	_class_label.text = ship_data["class"]
	var warp_val: float = ship_data["max_warp"]
	_warp_label.text = "Warp " + str(warp_val)
	_era_label.text = ship_data["era"]

	# Update button styles
	for i in range(_ship_buttons.size()):
		_style_ship_button(_ship_buttons[i], i == _current_index)

func _finalize_model_setup() -> void:
	if _pending_model_data.is_empty():
		return

	var model: Node3D = _pending_model_data["model"]
	var ship_data: Dictionary = _pending_model_data["ship_data"]
	_pending_model_data = {}

	if not is_instance_valid(model):
		return

	# Calculate bounding box using a more robust method
	var aabb := _get_visual_aabb(model)
	var model_length: float = max(aabb.size.x, max(aabb.size.y, aabb.size.z))

	print("  Model AABB: ", aabb, " length: ", model_length)

	# Use actual ship length to calculate scale
	# We want all ships to appear at similar visual size in preview
	var target_preview_size: float = 140.0  # Larger target visual size

	# Scale based on model length (make it fill the view)
	var scale_factor: float
	var center: Vector3

	if model_length > 0.1 and model_length < 50000.0:
		scale_factor = target_preview_size / model_length
		center = aabb.position + aabb.size / 2.0
	else:
		# Fallback for models with bad AABBs - use known ship length
		print("  WARNING: Bad AABB (", model_length, "), using ship length estimate")
		var known_length: float = ship_data.get("length", 500.0)
		# Assume model is roughly at 1 unit = 1 meter scale
		scale_factor = target_preview_size / known_length
		# Try to use mesh positions directly
		center = _find_mesh_center(model)
		print("  Mesh center fallback: ", center)

	model.scale = Vector3.ONE * scale_factor
	print("  AABB center: ", center)

	if center.length() > 0.01:
		model.position = -center * scale_factor
	else:
		model.position = Vector3.ZERO

	print("  Model loaded with scale: ", scale_factor, " position: ", model.position)

	# Camera distance for consistent framing
	_preview_camera.position = Vector3(0, 30, 250)
	_preview_camera.look_at(Vector3.ZERO, Vector3.UP)

func _find_mesh_center(node: Node) -> Vector3:
	var total_pos := Vector3.ZERO
	var count := 0

	_collect_mesh_positions(node, Transform3D.IDENTITY, total_pos, count)

	if count > 0:
		return total_pos / count
	return Vector3.ZERO

func _collect_mesh_positions(node: Node, parent_transform: Transform3D, total_pos: Vector3, count: int) -> Array:
	var current_transform := parent_transform
	if node is Node3D:
		current_transform = parent_transform * (node as Node3D).transform

	if node is MeshInstance3D:
		var mi: MeshInstance3D = node
		if mi.mesh:
			var mesh_center := mi.mesh.get_aabb().get_center()
			total_pos += current_transform * mesh_center
			count += 1

	for child in node.get_children():
		var result: Array = _collect_mesh_positions(child, current_transform, total_pos, count)
		total_pos = result[0]
		count = result[1]

	return [total_pos, count]

func _print_node_tree(node: Node, indent: String) -> void:
	var type_str: String = node.get_class()
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node
		if mi.mesh:
			type_str += " (has mesh, AABB: " + str(mi.get_aabb()) + ")"
		else:
			type_str += " (no mesh)"
	if node is Node3D:
		var n3d: Node3D = node
		type_str += " visible=" + str(n3d.visible)
	print(indent, node.name, " [", type_str, "]")
	# Only print first few levels to avoid spam
	if indent.length() < 12:
		for child in node.get_children():
			_print_node_tree(child, indent + "  ")

func _force_visibility(node: Node) -> void:
	if node is Node3D:
		(node as Node3D).visible = true
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_force_visibility(child)

func _get_node_aabb(node: Node3D) -> AABB:
	var aabb := AABB()
	var first := true

	for child in node.get_children():
		if child is MeshInstance3D:
			var mesh_aabb: AABB = child.get_aabb()
			mesh_aabb.position += child.position
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

## More robust AABB calculation that handles various model structures
func _get_visual_aabb(root: Node3D) -> AABB:
	_mesh_count = 0
	var result: Array = _collect_mesh_aabb(root, Transform3D.IDENTITY, AABB(), true)
	print("  Found ", _mesh_count, " mesh instances with valid meshes")
	return result[0]

var _mesh_count: int = 0

func _collect_mesh_aabb(node: Node, parent_transform: Transform3D, aabb: AABB, first: bool) -> Array:
	# Calculate this node's transform in model space
	var current_transform: Transform3D = parent_transform
	if node is Node3D:
		current_transform = parent_transform * (node as Node3D).transform

	# If this is a mesh instance, add its AABB
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node
		if mi.mesh:
			_mesh_count += 1
			var mesh_aabb: AABB = mi.mesh.get_aabb()

			# Transform the 8 corners of the local AABB to model space
			var corners: Array = [
				current_transform * mesh_aabb.position,
				current_transform * Vector3(mesh_aabb.end.x, mesh_aabb.position.y, mesh_aabb.position.z),
				current_transform * Vector3(mesh_aabb.position.x, mesh_aabb.end.y, mesh_aabb.position.z),
				current_transform * Vector3(mesh_aabb.position.x, mesh_aabb.position.y, mesh_aabb.end.z),
				current_transform * Vector3(mesh_aabb.end.x, mesh_aabb.end.y, mesh_aabb.position.z),
				current_transform * Vector3(mesh_aabb.end.x, mesh_aabb.position.y, mesh_aabb.end.z),
				current_transform * Vector3(mesh_aabb.position.x, mesh_aabb.end.y, mesh_aabb.end.z),
				current_transform * mesh_aabb.end
			]

			for corner in corners:
				if first:
					aabb = AABB(corner, Vector3.ZERO)
					first = false
				else:
					aabb = aabb.expand(corner)

	# Recurse into children
	for child in node.get_children():
		var result: Array = _collect_mesh_aabb(child, current_transform, aabb, first)
		aabb = result[0]
		first = result[1]

	return [aabb, first]

func _process(delta: float) -> void:
	if _auto_rotate and not _is_dragging:
		# Slowly rotate the preview ship when not dragging
		_rotation_angle += delta * 0.3
		_preview_ship.rotation.y = _rotation_angle
		_preview_ship.rotation.x = 0.0
	else:
		# Apply drag rotation
		_preview_ship.rotation.y = _drag_rotation_y
		_preview_ship.rotation.x = _drag_rotation_x

func _input(event: InputEvent) -> void:
	# Keyboard navigation
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_LEFT:
			_on_prev_ship()
		elif event.keycode == KEY_RIGHT:
			_on_next_ship()
		elif event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			_on_select_pressed()

	# Mouse click-drag rotation for ship preview
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			# Check if click is within the preview container area
			var viewport_size := get_viewport().get_visible_rect().size
			var container_rect := Rect2(
				viewport_size.x * _preview_container.anchor_left,
				viewport_size.y * _preview_container.anchor_top,
				viewport_size.x * (_preview_container.anchor_right - _preview_container.anchor_left),
				viewport_size.y * (_preview_container.anchor_bottom - _preview_container.anchor_top)
			)
			if container_rect.has_point(mb.position):
				_is_dragging = mb.pressed
				if mb.pressed:
					_auto_rotate = false
					# Sync drag rotation with current auto-rotation
					_drag_rotation_y = _rotation_angle

	if event is InputEventMouseMotion and _is_dragging:
		var motion: InputEventMouseMotion = event
		_drag_rotation_y += motion.relative.x * _drag_sensitivity
		_drag_rotation_x -= motion.relative.y * _drag_sensitivity
		# Clamp vertical rotation to avoid flipping
		_drag_rotation_x = clampf(_drag_rotation_x, -0.8, 0.8)

func _on_prev_ship() -> void:
	_current_index = (_current_index - 1 + ship_order.size()) % ship_order.size()
	_load_ship_preview(ship_order[_current_index])

func _on_next_ship() -> void:
	_current_index = (_current_index + 1) % ship_order.size()
	_load_ship_preview(ship_order[_current_index])

func _on_ship_button_pressed(index: int) -> void:
	_current_index = index
	_load_ship_preview(ship_order[_current_index])

func _on_select_pressed() -> void:
	var selected_id: String = ship_order[_current_index]
	var ship_data: Dictionary = SHIPS[selected_id]

	# Store selection globally
	var global_ship = get_node_or_null("/root/GlobalShipData")
	if global_ship:
		global_ship.selected_ship_id = selected_id
		global_ship.selected_ship_data = ship_data

	emit_signal("ship_selected", selected_id)

	# Transition to main game
	get_tree().change_scene_to_file("res://scenes/sectors/Sector_001_Sol_Realistic.tscn")

# Static accessor for ship data
static func get_ship_data(ship_id: String) -> Dictionary:
	var ships: Dictionary = {
		"enterprise_tos": {
			"name": "USS Enterprise",
			"registry": "NCC-1701",
			"class": "Constitution Class",
			"max_warp": 8.0,
			"model": "classic_u.s.s._enterprise_from_star_trek_tos.glb",
			"length": 289.0
		},
		"enterprise_a": {
			"name": "USS Enterprise-A",
			"registry": "NCC-1701-A",
			"class": "Constitution II Class",
			"max_warp": 8.5,
			"model": "star_trek_online__constitution_ii_class.glb",
			"length": 305.0
		},
		"enterprise_b": {
			"name": "USS Enterprise-B",
			"registry": "NCC-1701-B",
			"class": "Excelsior Class",
			"max_warp": 9.0,
			"model": "excelsior_refit_uss_enterprise_ncc-1701-b.glb",
			"length": 467.0
		},
		"enterprise_c": {
			"name": "USS Enterprise-C",
			"registry": "NCC-1701-C",
			"class": "Ambassador Class",
			"max_warp": 9.2,
			"model": "ambassador_class_u.s.s._enterprise_ncc-1701-c.glb",
			"length": 526.0
		},
		"enterprise_d": {
			"name": "USS Enterprise-D",
			"registry": "NCC-1701-D",
			"class": "Galaxy Class",
			"max_warp": 9.9,
			"model": "Enterprise_D.glb",
			"length": 642.5
		},
		"enterprise_e": {
			"name": "USS Enterprise-E",
			"registry": "NCC-1701-E",
			"class": "Sovereign Class",
			"max_warp": 9.985,
			"model": "star_trek_online__sovereign_class.glb",
			"length": 685.0
		},
		"enterprise_f": {
			"name": "USS Enterprise-F",
			"registry": "NCC-1701-F",
			"class": "Odyssey Class",
			"max_warp": 9.98,
			"model": "star_trek_online__odessey_class__enterprise_f.glb",
			"length": 1061.0
		},
		"enterprise_g": {
			"name": "USS Enterprise-G",
			"registry": "NCC-1701-G",
			"class": "Constitution III Class",
			"max_warp": 9.99,
			"model": "star_trek_online__constitution_class_iii.glb",
			"length": 560.0
		}
	}
	return ships.get(ship_id, {})
