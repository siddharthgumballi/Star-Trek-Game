extends Control
class_name LCARSHUD
## LCARS-style Star Trek HUD with speed, heading, warp factor, and minimap

@export_group("References")
@export var ship_path: NodePath
@export var warp_drive_path: NodePath
@export var camera_manager_path: NodePath
@export var sector_path: NodePath = NodePath("..")

# Resolved references
var ship: ShipController
var warp_drive: WarpDrive
var camera_manager: CameraManager
var sector: Node3D  # SectorSolRealistic

@export_group("LCARS Colors")
@export var lcars_orange: Color = Color(1.0, 0.6, 0.2, 1.0)
@export var lcars_blue: Color = Color(0.6, 0.8, 1.0, 1.0)
@export var lcars_purple: Color = Color(0.8, 0.6, 1.0, 1.0)
@export var lcars_red: Color = Color(1.0, 0.3, 0.3, 1.0)
@export var lcars_yellow: Color = Color(1.0, 0.9, 0.4, 1.0)
@export var lcars_bg: Color = Color(0.05, 0.05, 0.1, 0.8)

# UI Elements
var _main_panel: Panel
var _impulse_label: Label
var _heading_label: Label
var _warp_label: Label
var _camera_label: Label
var _controls_label: Label
var _minimap: Control
var _minimap_panel: Panel
var _minimap_ship: Control
var _minimap_expanded: bool = false
var _minimap_title: Label

# Persistent map elements (created once, updated each frame)
var _planet_markers: Dictionary = {}  # planet_name -> ColorRect
var _planet_labels: Dictionary = {}   # planet_name -> Label
var _orbit_container: Control         # Container for orbit rings (drawn once)

# Minimap sizes
const MINIMAP_SMALL_SIZE: Vector2 = Vector2(160, 180)
const MINIMAP_LARGE_SIZE: Vector2 = Vector2(500, 560)

# Map zoom
var _map_zoom_slider: HSlider
var _map_zoom_label: Label
var _map_zoom: float = 1.0  # 1.0 = full solar system, higher = zoomed in

# Map panning
var _map_dragging: bool = false
var _map_offset: Vector2 = Vector2.ZERO  # Pan offset in map coordinates
var _map_drag_start: Vector2 = Vector2.ZERO

# Course plotting
var _course_panel: Panel
var _course_destination_label: Label
var _course_distance_label: Label
var _course_eta_label: Label
var _course_speed_buttons: Array[Button] = []
var _course_engage_button: Button
var _selected_destination: Node3D = null
var _selected_destination_name: String = ""
var _selected_speed: int = 2  # 0=1/4, 1=1/2, 2=3/4, 3=Full
var _autopilot_active: bool = false
var _autopilot_destination: Vector3 = Vector3.ZERO
var _autopilot_aligning: bool = false  # True while turning to face target before warp
var _disengage_button: Button = null

# Orbit mode
var _orbit_active: bool = false
var _orbit_target: Node3D = null
var _orbit_target_name: String = ""
var _orbit_angle: float = 0.0
var _orbit_distance: float = 1000.0  # Standard orbit distance (default, overridden per planet)
var _orbit_speed: float = 0.1  # Radians per second
var _orbit_height: float = 200.0  # Height above orbital plane

# Docking mode
var _docked: bool = false
var _docked_at: String = ""
var _dock_panel: Panel = null
var _dock_button: Button = null  # Shows when in range to dock

# Planet colors for map
var PLANET_COLORS: Dictionary = {
	"Sun": Color(1.0, 0.9, 0.3),
	"Mercury": Color(0.6, 0.5, 0.4),
	"Venus": Color(0.9, 0.7, 0.4),
	"Earth": Color(0.3, 0.5, 1.0),
	"Moon": Color(0.7, 0.7, 0.7),
	"Starbase 1": Color(0.7, 0.85, 1.0),  # Light blue for Federation starbase
	"Mars": Color(0.9, 0.4, 0.2),
	"Jupiter": Color(0.8, 0.7, 0.5),
	"Saturn": Color(0.9, 0.8, 0.5),
	"Uranus": Color(0.5, 0.8, 0.9),
	"Neptune": Color(0.3, 0.4, 0.9)
}

# Tracked objects for minimap
var _tracked_objects: Array[Node3D] = []

# Alert/notification display
var _alert_label: Label
var _alert_timer: Timer

# Heading input panel
var _heading_panel: Panel
var _heading_pitch_input: SpinBox
var _heading_yaw_input: SpinBox
var _heading_warp_input: SpinBox
var _heading_engage_button: Button

# Course panel warp mode
var _course_mode_impulse: Button
var _course_mode_warp: Button
var _course_warp_input: SpinBox
var _course_impulse_container: HBoxContainer
var _course_warp_container: HBoxContainer
var _course_use_warp: bool = false
var _course_warp_factor: float = 5.0
var _autopilot_using_warp: bool = false

# Arrival prompt panel
var _arrival_panel: Panel
var _arrival_destination_label: Label
var _arrival_orbit_button: Button
var _arrival_dismiss_button: Button

# ETA display
var _eta_label: Label

func _ready() -> void:
	# Resolve node paths
	if ship_path:
		ship = get_node_or_null(ship_path) as ShipController
	if warp_drive_path:
		warp_drive = get_node_or_null(warp_drive_path) as WarpDrive
	if camera_manager_path:
		camera_manager = get_node_or_null(camera_manager_path) as CameraManager
	if sector_path:
		sector = get_node_or_null(sector_path)

	_create_lcars_ui()
	_setup_map_input()
	_connect_warp_signals()

func _connect_warp_signals() -> void:
	if warp_drive:
		if warp_drive.has_signal("warp_blocked"):
			warp_drive.warp_blocked.connect(_on_warp_blocked)

func _setup_map_input() -> void:
	if not InputMap.has_action("toggle_map"):
		InputMap.add_action("toggle_map")
		var m := InputEventKey.new()
		m.physical_keycode = KEY_M
		InputMap.action_add_event("toggle_map", m)

	if not InputMap.has_action("standard_orbit"):
		InputMap.add_action("standard_orbit")
		var o := InputEventKey.new()
		o.physical_keycode = KEY_O
		InputMap.action_add_event("standard_orbit", o)

	if not InputMap.has_action("dock_undock"):
		InputMap.add_action("dock_undock")
		var d := InputEventKey.new()
		d.physical_keycode = KEY_D
		d.shift_pressed = true  # Shift+D for docking
		InputMap.action_add_event("dock_undock", d)

	if not InputMap.has_action("set_heading"):
		InputMap.add_action("set_heading")
		var h := InputEventKey.new()
		h.physical_keycode = KEY_H
		h.meta_pressed = true  # CMD+H on Mac, Ctrl+H on Windows/Linux
		InputMap.action_add_event("set_heading", h)
		# Also add Ctrl+H for cross-platform
		var h2 := InputEventKey.new()
		h2.physical_keycode = KEY_H
		h2.ctrl_pressed = true
		InputMap.action_add_event("set_heading", h2)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_map"):
		_toggle_map_size()
		_map_offset = Vector2.ZERO  # Reset pan when toggling

	# Cancel autopilot or orbit with Space
	if event.is_action_pressed("full_stop"):
		if _autopilot_active:
			_disengage_autopilot()
		if _orbit_active:
			_disengage_orbit()

	# Standard orbit with O key (toggle)
	if event.is_action_pressed("standard_orbit"):
		# If arrival panel is visible, pressing O enters orbit at that destination
		if _arrival_panel and _arrival_panel.visible:
			_on_arrival_orbit()
		elif _orbit_active:
			_disengage_orbit()
		else:
			_try_enter_orbit()

	# Docking with D key (toggle)
	if event.is_action_pressed("dock_undock"):
		if _docked:
			_undock()
		else:
			_try_dock()

	# Set heading with CMD/Ctrl+H
	if event.is_action_pressed("set_heading"):
		_show_heading_panel()

	# Map dragging with right mouse button (only when expanded)
	if _minimap_expanded and _minimap_panel:
		if event is InputEventMouseButton:
			var mb: InputEventMouseButton = event
			if mb.button_index == MOUSE_BUTTON_RIGHT:
				# Check if click is within minimap bounds
				var local_pos: Vector2 = _minimap.get_local_mouse_position()
				var in_map: bool = local_pos.x >= 0 and local_pos.x <= _minimap.size.x and local_pos.y >= 0 and local_pos.y <= _minimap.size.y
				if in_map:
					if mb.pressed:
						_map_dragging = true
						_map_drag_start = mb.position
					else:
						_map_dragging = false

		if event is InputEventMouseMotion and _map_dragging:
			var motion: InputEventMouseMotion = event
			_map_offset += motion.relative
			# Redraw orbits with new offset
			_draw_orbit_rings()

func _create_lcars_ui() -> void:
	# Main panel background
	_main_panel = Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = lcars_bg
	style.corner_radius_top_left = 20
	style.corner_radius_bottom_left = 20
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_color = lcars_orange
	_main_panel.add_theme_stylebox_override("panel", style)
	_main_panel.position = Vector2(20, 20)
	_main_panel.size = Vector2(320, 380)
	add_child(_main_panel)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(15, 15)
	vbox.size = Vector2(290, 350)
	_main_panel.add_child(vbox)

	# Title bar - show selected ship name
	var title := Label.new()
	var ship_name: String = "USS ENTERPRISE NCC-1701-D"
	var global_ship = get_node_or_null("/root/GlobalShipData")
	if global_ship and not global_ship.selected_ship_data.is_empty():
		ship_name = global_ship.get_ship_name() + " " + global_ship.get_registry()
	title.text = ship_name.to_upper()
	title.add_theme_color_override("font_color", lcars_orange)
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 10)
	vbox.add_child(sep)

	# Impulse display
	_impulse_label = _create_data_label("IMPULSE", lcars_blue)
	vbox.add_child(_impulse_label)

	# Warp display
	_warp_label = _create_data_label("WARP", lcars_purple)
	vbox.add_child(_warp_label)

	# Heading display (clickable)
	_heading_label = _create_data_label("HEADING", lcars_yellow)
	_heading_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_heading_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_heading_label.gui_input.connect(_on_heading_label_clicked)
	vbox.add_child(_heading_label)

	# Camera mode
	_camera_label = _create_data_label("CAMERA", lcars_orange)
	vbox.add_child(_camera_label)

	# Separator
	var sep2 := HSeparator.new()
	sep2.add_theme_constant_override("separation", 10)
	vbox.add_child(sep2)

	# Controls help
	_controls_label = Label.new()
	_controls_label.text = "E/Q Impulse | W/S Pitch | A/D Yaw\nZ/C Roll | Space Stop | O Orbit\nShift+W Warp | +/- Warp Factor\nShift+D Dock | F1-F4 Camera | M Map\nCtrl+H Set Heading | Click map for course"
	_controls_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_controls_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_controls_label)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	# Change Ship button
	var change_ship_btn := Button.new()
	change_ship_btn.text = "CHANGE SHIP"
	change_ship_btn.custom_minimum_size = Vector2(120, 30)
	change_ship_btn.pressed.connect(_on_change_ship_pressed)

	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.15, 0.15, 0.25)
	btn_style.corner_radius_top_left = 5
	btn_style.corner_radius_top_right = 5
	btn_style.corner_radius_bottom_left = 5
	btn_style.corner_radius_bottom_right = 5
	btn_style.border_width_left = 2
	btn_style.border_width_right = 2
	btn_style.border_width_top = 2
	btn_style.border_width_bottom = 2
	btn_style.border_color = lcars_blue
	change_ship_btn.add_theme_stylebox_override("normal", btn_style)

	var btn_hover := btn_style.duplicate()
	btn_hover.bg_color = Color(0.2, 0.25, 0.35)
	btn_hover.border_color = lcars_orange
	change_ship_btn.add_theme_stylebox_override("hover", btn_hover)

	change_ship_btn.add_theme_color_override("font_color", lcars_blue)
	change_ship_btn.add_theme_font_size_override("font_size", 12)
	vbox.add_child(change_ship_btn)

	# Create minimap
	_create_minimap()

	# Create alert notification label (centered at top)
	_create_alert_display()

	# Create ETA display (top center, below alert)
	_create_eta_display()

func _create_alert_display() -> void:
	_alert_label = Label.new()
	_alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_alert_label.add_theme_color_override("font_color", lcars_red)
	_alert_label.add_theme_font_size_override("font_size", 18)
	_alert_label.anchors_preset = Control.PRESET_TOP_WIDE
	_alert_label.anchor_top = 0.1
	_alert_label.anchor_bottom = 0.1
	_alert_label.visible = false
	add_child(_alert_label)

	# Create timer for auto-hide
	_alert_timer = Timer.new()
	_alert_timer.one_shot = true
	_alert_timer.timeout.connect(_hide_alert)
	add_child(_alert_timer)

func _show_alert(message: String, duration: float = 4.0) -> void:
	_alert_label.text = message
	_alert_label.visible = true
	_alert_timer.start(duration)

func _hide_alert() -> void:
	_alert_label.visible = false

func _create_eta_display() -> void:
	_eta_label = Label.new()
	_eta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_eta_label.add_theme_color_override("font_color", Color(0.6, 0.85, 0.92))  # TNG Teal/Cyan
	_eta_label.add_theme_font_size_override("font_size", 22)
	_eta_label.anchors_preset = Control.PRESET_TOP_WIDE
	_eta_label.anchor_left = 0.25
	_eta_label.anchor_right = 0.75
	_eta_label.anchor_top = 0.0
	_eta_label.anchor_bottom = 0.0
	_eta_label.offset_top = 15
	_eta_label.offset_bottom = 50
	_eta_label.visible = false
	add_child(_eta_label)

func _update_eta() -> void:
	if not _eta_label:
		return

	# Only show ETA during active autopilot
	if not _autopilot_active:
		_eta_label.visible = false
		return

	_eta_label.visible = true

	# Calculate distance to destination
	if not ship:
		return

	var distance: float = ship.global_position.distance_to(_autopilot_destination)

	# Calculate current speed
	var speed: float = 0.0
	var speed_type: String = ""

	if _autopilot_aligning:
		# Still aligning - show that status
		_eta_label.text = "ALIGNING TO %s..." % _selected_destination_name.to_upper()
		_eta_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.0))  # Orange
		return

	if _autopilot_using_warp and warp_drive and warp_drive.is_at_warp:
		# At warp - use warp speed
		speed = warp_drive.get_warp_speed_units(warp_drive.get_warp_factor())
		speed_type = "WARP %.1f" % warp_drive.get_warp_factor()
		_eta_label.add_theme_color_override("font_color", lcars_purple)
	else:
		# At impulse - use ship speed
		speed = abs(ship.forward_speed)
		speed_type = ship.get_impulse_name().to_upper()
		_eta_label.add_theme_color_override("font_color", lcars_yellow)

	# Calculate ETA
	if speed > 0.1:
		var eta_seconds: float = distance / speed

		# Format the time nicely
		var eta_str: String
		if eta_seconds < 60:
			eta_str = "%.0f sec" % eta_seconds
		elif eta_seconds < 3600:
			var mins: int = int(eta_seconds / 60)
			var secs: int = int(eta_seconds) % 60
			eta_str = "%d min %02d sec" % [mins, secs]
		elif eta_seconds < 86400:
			var hours: int = int(eta_seconds / 3600)
			var mins: int = int((eta_seconds - hours * 3600) / 60)
			eta_str = "%d hr %02d min" % [hours, mins]
		else:
			var days: int = int(eta_seconds / 86400)
			var hours: int = int((eta_seconds - days * 86400) / 3600)
			eta_str = "%d days %d hr" % [days, hours]

		# Format distance
		var dist_str: String
		var dist_km: float = distance * 1000.0  # 1 unit = 1000 km
		if dist_km >= 1000000000:  # 1 billion km
			dist_str = "%.2f B km" % (dist_km / 1000000000.0)
		elif dist_km >= 1000000:  # 1 million km
			dist_str = "%.2f M km" % (dist_km / 1000000.0)
		elif dist_km >= 1000:
			dist_str = "%.0f K km" % (dist_km / 1000.0)
		else:
			dist_str = "%.0f km" % dist_km

		_eta_label.text = "%s → %s | ETA: %s | %s" % [
			speed_type,
			_selected_destination_name.to_upper(),
			eta_str,
			dist_str
		]
	else:
		_eta_label.text = "EN ROUTE TO %s | CALCULATING..." % _selected_destination_name.to_upper()

func _on_warp_blocked(reason: String, _nearest_body: String) -> void:
	_show_alert("WARP DRIVE OFFLINE: " + reason)

func _create_data_label(prefix: String, color: Color) -> Label:
	var label := Label.new()
	label.text = prefix + ": ---"
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 16)
	return label

func _create_minimap() -> void:
	# Minimap panel - pass clicks to children
	_minimap_panel = Panel.new()
	_minimap_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.02, 0.05, 0.9)
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_right = 20
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.border_color = lcars_blue
	_minimap_panel.add_theme_stylebox_override("panel", style)
	_minimap_panel.anchor_left = 1.0
	_minimap_panel.anchor_right = 1.0
	_minimap_panel.offset_left = -MINIMAP_SMALL_SIZE.x - 20
	_minimap_panel.offset_right = -20
	_minimap_panel.offset_top = 20
	_minimap_panel.offset_bottom = 20 + MINIMAP_SMALL_SIZE.y
	add_child(_minimap_panel)

	# Minimap title
	_minimap_title = Label.new()
	_minimap_title.text = "NAVIGATION [M]"
	_minimap_title.position = Vector2(10, 5)
	_minimap_title.add_theme_color_override("font_color", lcars_blue)
	_minimap_title.add_theme_font_size_override("font_size", 12)
	_minimap_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minimap_panel.add_child(_minimap_title)

	# Minimap container - pass clicks through to planet buttons
	_minimap = Control.new()
	_minimap.clip_contents = true  # Clip contents to bounds
	_minimap.position = Vector2(10, 25)
	_minimap.size = Vector2(140, 140)
	_minimap.mouse_filter = Control.MOUSE_FILTER_PASS
	_minimap_panel.add_child(_minimap)

	# Minimap background - allow clicks to pass through
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.02, 0.05, 0.08, 1.0)
	bg.size = Vector2(140, 140)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minimap.add_child(bg)

	# Orbit container (for drawing orbits) - allow clicks to pass through
	_orbit_container = Control.new()
	_orbit_container.name = "Orbits"
	_orbit_container.visible = false  # Only visible in expanded mode
	_orbit_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minimap.add_child(_orbit_container)

	# Create planet markers (hidden initially, positioned each frame)
	_create_planet_markers()

	# Ship indicator - always on top, allow clicks to pass through
	_minimap_ship = Control.new()
	_minimap_ship.position = Vector2(70, 70)
	_minimap_ship.z_index = 100
	_minimap_ship.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minimap.add_child(_minimap_ship)

	var enterprise := Polygon2D.new()
	enterprise.color = lcars_orange
	enterprise.polygon = PackedVector2Array([
		Vector2(0, -8), Vector2(-4, -7), Vector2(-6, -5), Vector2(-7, -2), Vector2(-7, 1),
		Vector2(-5, 3), Vector2(-2, 4),
		Vector2(-6, 5), Vector2(-6, 12), Vector2(-5, 12), Vector2(-5, 6),
		Vector2(-1, 5), Vector2(-1, 10), Vector2(1, 10), Vector2(1, 5),
		Vector2(5, 6), Vector2(5, 12), Vector2(6, 12), Vector2(6, 5),
		Vector2(2, 4), Vector2(5, 3), Vector2(7, 1), Vector2(7, -2), Vector2(6, -5), Vector2(4, -7),
	])
	_minimap_ship.add_child(enterprise)

	# Zoom slider (only visible when expanded)
	_map_zoom_slider = HSlider.new()
	_map_zoom_slider.min_value = 0.1
	_map_zoom_slider.max_value = 50.0
	_map_zoom_slider.value = 1.0
	_map_zoom_slider.step = 0.1
	_map_zoom_slider.size = Vector2(200, 20)
	_map_zoom_slider.position = Vector2(10, MINIMAP_LARGE_SIZE.y - 55)
	_map_zoom_slider.visible = false
	_map_zoom_slider.value_changed.connect(_on_map_zoom_changed)
	_minimap_panel.add_child(_map_zoom_slider)

	_map_zoom_label = Label.new()
	_map_zoom_label.text = "ZOOM: 1.0x"
	_map_zoom_label.add_theme_font_size_override("font_size", 11)
	_map_zoom_label.add_theme_color_override("font_color", lcars_blue)
	_map_zoom_label.position = Vector2(220, MINIMAP_LARGE_SIZE.y - 55)
	_map_zoom_label.visible = false
	_minimap_panel.add_child(_map_zoom_label)

	# Reset view button
	var reset_btn := Button.new()
	reset_btn.text = "CENTER"
	reset_btn.custom_minimum_size = Vector2(70, 25)
	reset_btn.position = Vector2(320, MINIMAP_LARGE_SIZE.y - 58)
	reset_btn.visible = false
	reset_btn.name = "ResetViewBtn"
	reset_btn.pressed.connect(_on_reset_map_view)
	var reset_style := StyleBoxFlat.new()
	reset_style.bg_color = Color(0.2, 0.3, 0.4)
	reset_style.corner_radius_top_left = 3
	reset_style.corner_radius_top_right = 3
	reset_style.corner_radius_bottom_left = 3
	reset_style.corner_radius_bottom_right = 3
	reset_btn.add_theme_stylebox_override("normal", reset_style)
	_minimap_panel.add_child(reset_btn)

func _on_map_zoom_changed(value: float) -> void:
	_map_zoom = value
	if _map_zoom_label:
		_map_zoom_label.text = "ZOOM: %.1fx" % value
	# Redraw orbit rings at new zoom level
	if _minimap_expanded:
		_draw_orbit_rings()

func _on_reset_map_view() -> void:
	_map_offset = Vector2.ZERO
	_map_zoom = 1.0
	if _map_zoom_slider:
		_map_zoom_slider.value = 1.0
	if _minimap_expanded:
		_draw_orbit_rings()

func _create_course_panel() -> void:
	_course_panel = Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.95)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = lcars_yellow
	_course_panel.add_theme_stylebox_override("panel", style)
	_course_panel.size = Vector2(300, 280)
	_course_panel.position = Vector2(360, 100)
	_course_panel.visible = false
	add_child(_course_panel)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(15, 10)
	vbox.size = Vector2(270, 260)
	_course_panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "SET COURSE"
	title.add_theme_color_override("font_color", lcars_yellow)
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)

	# Destination
	_course_destination_label = Label.new()
	_course_destination_label.text = "Destination: ---"
	_course_destination_label.add_theme_color_override("font_color", lcars_blue)
	_course_destination_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(_course_destination_label)

	# Distance
	_course_distance_label = Label.new()
	_course_distance_label.text = "Distance: ---"
	_course_distance_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_course_distance_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_course_distance_label)

	# ETA
	_course_eta_label = Label.new()
	_course_eta_label.text = "ETA: ---"
	_course_eta_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_course_eta_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_course_eta_label)

	# Mode selection (Impulse / Warp)
	var mode_label := Label.new()
	mode_label.text = "Travel Mode:"
	mode_label.add_theme_color_override("font_color", lcars_orange)
	mode_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(mode_label)

	var mode_hbox := HBoxContainer.new()
	mode_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(mode_hbox)

	_course_mode_impulse = Button.new()
	_course_mode_impulse.text = "IMPULSE"
	_course_mode_impulse.custom_minimum_size = Vector2(80, 30)
	_course_mode_impulse.pressed.connect(_on_course_mode_impulse)
	mode_hbox.add_child(_course_mode_impulse)

	_course_mode_warp = Button.new()
	_course_mode_warp.text = "WARP"
	_course_mode_warp.custom_minimum_size = Vector2(80, 30)
	_course_mode_warp.pressed.connect(_on_course_mode_warp)
	mode_hbox.add_child(_course_mode_warp)

	# Impulse speed container
	_course_impulse_container = HBoxContainer.new()
	_course_impulse_container.add_theme_constant_override("separation", 5)
	vbox.add_child(_course_impulse_container)

	var speed_names: Array[String] = ["1/4", "1/2", "3/4", "FULL"]
	for i in range(4):
		var btn := Button.new()
		btn.text = speed_names[i]
		btn.custom_minimum_size = Vector2(50, 30)
		btn.pressed.connect(_on_speed_selected.bind(i))
		_course_impulse_container.add_child(btn)
		_course_speed_buttons.append(btn)

	# Warp factor container
	_course_warp_container = HBoxContainer.new()
	_course_warp_container.add_theme_constant_override("separation", 10)
	_course_warp_container.visible = false
	vbox.add_child(_course_warp_container)

	var warp_label := Label.new()
	warp_label.text = "Warp Factor:"
	warp_label.add_theme_color_override("font_color", lcars_purple)
	_course_warp_container.add_child(warp_label)

	_course_warp_input = SpinBox.new()
	_course_warp_input.min_value = 1.0
	_course_warp_input.max_value = 9.99
	_course_warp_input.step = 0.1
	_course_warp_input.value = 5.0
	_course_warp_input.custom_minimum_size = Vector2(80, 30)
	_course_warp_input.value_changed.connect(_on_course_warp_changed)
	if warp_drive:
		_course_warp_input.max_value = warp_drive.max_warp_factor
	_course_warp_container.add_child(_course_warp_input)

	# Update button styles
	_update_speed_button_styles()
	_update_course_mode_styles()

	# Buttons row
	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_hbox)

	# Engage button
	_course_engage_button = Button.new()
	_course_engage_button.text = "ENGAGE"
	_course_engage_button.custom_minimum_size = Vector2(100, 35)
	_course_engage_button.pressed.connect(_on_engage_pressed)
	var engage_style := StyleBoxFlat.new()
	engage_style.bg_color = Color(0.2, 0.5, 0.2)
	engage_style.corner_radius_top_left = 5
	engage_style.corner_radius_top_right = 5
	engage_style.corner_radius_bottom_left = 5
	engage_style.corner_radius_bottom_right = 5
	_course_engage_button.add_theme_stylebox_override("normal", engage_style)
	btn_hbox.add_child(_course_engage_button)

	# Cancel button
	var cancel_btn := Button.new()
	cancel_btn.text = "CANCEL"
	cancel_btn.custom_minimum_size = Vector2(80, 35)
	cancel_btn.pressed.connect(_on_course_cancel)
	var cancel_style := StyleBoxFlat.new()
	cancel_style.bg_color = Color(0.5, 0.2, 0.2)
	cancel_style.corner_radius_top_left = 5
	cancel_style.corner_radius_top_right = 5
	cancel_style.corner_radius_bottom_left = 5
	cancel_style.corner_radius_bottom_right = 5
	cancel_btn.add_theme_stylebox_override("normal", cancel_style)
	btn_hbox.add_child(cancel_btn)

func _update_speed_button_styles() -> void:
	for i in range(_course_speed_buttons.size()):
		var btn: Button = _course_speed_buttons[i]
		var style := StyleBoxFlat.new()
		if i == _selected_speed:
			style.bg_color = lcars_orange
		else:
			style.bg_color = Color(0.2, 0.2, 0.3)
		style.corner_radius_top_left = 3
		style.corner_radius_top_right = 3
		style.corner_radius_bottom_left = 3
		style.corner_radius_bottom_right = 3
		btn.add_theme_stylebox_override("normal", style)

func _update_course_mode_styles() -> void:
	if not _course_mode_impulse or not _course_mode_warp:
		return

	var impulse_style := StyleBoxFlat.new()
	var warp_style := StyleBoxFlat.new()

	if _course_use_warp:
		impulse_style.bg_color = Color(0.2, 0.2, 0.3)
		warp_style.bg_color = lcars_purple
	else:
		impulse_style.bg_color = lcars_orange
		warp_style.bg_color = Color(0.2, 0.2, 0.3)

	for s in [impulse_style, warp_style]:
		s.corner_radius_top_left = 3
		s.corner_radius_top_right = 3
		s.corner_radius_bottom_left = 3
		s.corner_radius_bottom_right = 3

	_course_mode_impulse.add_theme_stylebox_override("normal", impulse_style)
	_course_mode_warp.add_theme_stylebox_override("normal", warp_style)

func _on_course_mode_impulse() -> void:
	_course_use_warp = false
	_course_impulse_container.visible = true
	_course_warp_container.visible = false
	_update_course_mode_styles()
	_update_course_info()

func _on_course_mode_warp() -> void:
	_course_use_warp = true
	_course_impulse_container.visible = false
	_course_warp_container.visible = true
	_update_course_mode_styles()
	_update_course_info()

func _on_course_warp_changed(_value: float) -> void:
	_course_warp_factor = _course_warp_input.value
	_update_course_info()

func _on_planet_clicked(planet_name: String) -> void:
	if not sector or not _minimap_expanded:
		return

	var planet = sector.get_planet(planet_name) if sector.has_method("get_planet") else null
	if not planet:
		return

	_selected_destination = planet
	_selected_destination_name = planet_name
	_show_course_panel()

func _show_course_panel() -> void:
	if not _course_panel:
		_create_course_panel()

	_course_panel.visible = true
	_course_destination_label.text = "Destination: " + _selected_destination_name
	_update_course_info()

func _update_course_info() -> void:
	if not ship or not _selected_destination:
		return

	var distance: float = ship.global_position.distance_to(_selected_destination.global_position)
	var distance_km: float = distance * 1000.0  # 1 unit = 1000 km

	# Format distance
	var dist_str: String
	if distance_km >= 1000000000:  # 1 billion km
		dist_str = "%.2f billion km" % (distance_km / 1000000000.0)
	elif distance_km >= 1000000:
		dist_str = "%.2f million km" % (distance_km / 1000000.0)
	else:
		dist_str = "%.0f km" % distance_km
	_course_distance_label.text = "Distance: " + dist_str

	# Calculate ETA based on mode and selected speed
	var speed: float = 0.0
	if _course_use_warp and warp_drive:
		# Warp speed in units/second
		speed = warp_drive.get_warp_speed_units(_course_warp_factor)
	else:
		# Impulse speed
		var speed_fractions: Array[float] = [0.25, 0.5, 0.75, 1.0]
		speed = ship.full_impulse_speed * speed_fractions[_selected_speed]

	var eta_seconds: float = distance / speed if speed > 0 else 0

	var eta_str: String
	if eta_seconds >= 86400:  # Days
		eta_str = "%.1f days" % (eta_seconds / 86400.0)
	elif eta_seconds >= 3600:
		eta_str = "%.1f hours" % (eta_seconds / 3600.0)
	elif eta_seconds >= 60:
		eta_str = "%.1f minutes" % (eta_seconds / 60.0)
	else:
		eta_str = "%.0f seconds" % eta_seconds
	_course_eta_label.text = "ETA: " + eta_str

func _on_speed_selected(speed_index: int) -> void:
	_selected_speed = speed_index
	_update_speed_button_styles()
	_update_course_info()

func _on_engage_pressed() -> void:
	if not _selected_destination or not ship:
		return

	_autopilot_active = true
	_autopilot_destination = _selected_destination.global_position
	_course_panel.visible = false

	if _course_use_warp and warp_drive:
		# Warp mode - start alignment phase first, DON'T engage warp yet
		_autopilot_using_warp = true
		_autopilot_aligning = true  # Must align before warp
		warp_drive.set_warp_factor(_course_warp_factor)
		# DO NOT engage warp here - wait for alignment to complete
		print("Aligning to ", _selected_destination_name, " for Warp %.1f" % _course_warp_factor)
	else:
		# Impulse mode - can start immediately (will turn while moving)
		_autopilot_using_warp = false
		_autopilot_aligning = false
		var impulse_levels: Array = [
			ShipController.ImpulseLevel.QUARTER,
			ShipController.ImpulseLevel.HALF,
			ShipController.ImpulseLevel.THREE_QUARTER,
			ShipController.ImpulseLevel.FULL
		]
		ship.current_impulse = impulse_levels[_selected_speed]
		ship._update_target_speed()
		print("Course set to ", _selected_destination_name, " at ", ["1/4", "1/2", "3/4", "Full"][_selected_speed], " impulse")

	# Show disengage button
	_show_disengage_button()

func _on_course_cancel() -> void:
	_course_panel.visible = false
	_selected_destination = null

func _disengage_autopilot() -> void:
	_autopilot_active = false
	_autopilot_aligning = false
	_autopilot_using_warp = false
	if ship:
		ship.current_impulse = ShipController.ImpulseLevel.STOP
		ship._update_target_speed()
		ship.angular_velocity = Vector3.ZERO  # Stop any rotation
	# Also disengage warp if at warp
	if warp_drive and warp_drive.is_at_warp:
		warp_drive.disengage_warp(true)  # Full stop
	_hide_disengage_button()
	print("Autopilot disengaged")

# === HEADING INPUT PANEL ===

func _on_heading_label_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_show_heading_panel()

func _show_heading_panel() -> void:
	if not _heading_panel:
		_create_heading_panel()

	# Pre-fill with current heading
	if ship:
		var rot: Vector3 = ship.global_rotation_degrees
		_heading_pitch_input.value = rot.x
		_heading_yaw_input.value = rot.y

	_heading_panel.visible = true

func _create_heading_panel() -> void:
	_heading_panel = Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.95)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = lcars_yellow
	_heading_panel.add_theme_stylebox_override("panel", style)
	_heading_panel.size = Vector2(300, 240)
	_heading_panel.position = Vector2(360, 100)
	_heading_panel.visible = false
	add_child(_heading_panel)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(15, 10)
	vbox.size = Vector2(270, 220)
	_heading_panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "SET HEADING"
	title.add_theme_color_override("font_color", lcars_yellow)
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)

	# Pitch input
	var pitch_hbox := HBoxContainer.new()
	pitch_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(pitch_hbox)

	var pitch_label := Label.new()
	pitch_label.text = "Pitch (°):"
	pitch_label.add_theme_color_override("font_color", lcars_blue)
	pitch_label.custom_minimum_size = Vector2(80, 0)
	pitch_hbox.add_child(pitch_label)

	_heading_pitch_input = SpinBox.new()
	_heading_pitch_input.min_value = -90
	_heading_pitch_input.max_value = 90
	_heading_pitch_input.step = 1
	_heading_pitch_input.custom_minimum_size = Vector2(100, 30)
	pitch_hbox.add_child(_heading_pitch_input)

	# Yaw input
	var yaw_hbox := HBoxContainer.new()
	yaw_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(yaw_hbox)

	var yaw_label := Label.new()
	yaw_label.text = "Yaw (°):"
	yaw_label.add_theme_color_override("font_color", lcars_blue)
	yaw_label.custom_minimum_size = Vector2(80, 0)
	yaw_hbox.add_child(yaw_label)

	_heading_yaw_input = SpinBox.new()
	_heading_yaw_input.min_value = -180
	_heading_yaw_input.max_value = 180
	_heading_yaw_input.step = 1
	_heading_yaw_input.custom_minimum_size = Vector2(100, 30)
	yaw_hbox.add_child(_heading_yaw_input)

	# Warp factor input
	var warp_hbox := HBoxContainer.new()
	warp_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(warp_hbox)

	var warp_label := Label.new()
	warp_label.text = "Warp Factor:"
	warp_label.add_theme_color_override("font_color", lcars_purple)
	warp_label.custom_minimum_size = Vector2(80, 0)
	warp_hbox.add_child(warp_label)

	_heading_warp_input = SpinBox.new()
	_heading_warp_input.min_value = 1.0
	_heading_warp_input.max_value = 9.99
	_heading_warp_input.step = 0.1
	_heading_warp_input.value = 5.0
	_heading_warp_input.custom_minimum_size = Vector2(100, 30)
	# Update max warp based on ship
	if warp_drive:
		_heading_warp_input.max_value = warp_drive.max_warp_factor
	warp_hbox.add_child(_heading_warp_input)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	# Buttons row
	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_hbox)

	# Engage button
	_heading_engage_button = Button.new()
	_heading_engage_button.text = "ENGAGE"
	_heading_engage_button.custom_minimum_size = Vector2(100, 35)
	_heading_engage_button.pressed.connect(_on_heading_engage)
	var engage_style := StyleBoxFlat.new()
	engage_style.bg_color = Color(0.2, 0.5, 0.2)
	engage_style.corner_radius_top_left = 5
	engage_style.corner_radius_top_right = 5
	engage_style.corner_radius_bottom_left = 5
	engage_style.corner_radius_bottom_right = 5
	_heading_engage_button.add_theme_stylebox_override("normal", engage_style)
	btn_hbox.add_child(_heading_engage_button)

	# Cancel button
	var cancel_btn := Button.new()
	cancel_btn.text = "CANCEL"
	cancel_btn.custom_minimum_size = Vector2(80, 35)
	cancel_btn.pressed.connect(_on_heading_cancel)
	btn_hbox.add_child(cancel_btn)

func _on_heading_engage() -> void:
	if not ship or not warp_drive:
		return

	# Set ship heading
	var target_pitch: float = _heading_pitch_input.value
	var target_yaw: float = _heading_yaw_input.value
	ship.global_rotation_degrees = Vector3(target_pitch, target_yaw, 0)

	# Set warp factor and engage
	var warp_factor: float = _heading_warp_input.value
	warp_drive.set_warp_factor(warp_factor)
	warp_drive.engage_warp()

	_heading_panel.visible = false
	print("Heading set to %.0f° / %.0f°, engaging Warp %.1f" % [target_pitch, target_yaw, warp_factor])

func _on_heading_cancel() -> void:
	_heading_panel.visible = false

# === ARRIVAL PROMPT ===

func _show_arrival_prompt(destination_name: String) -> void:
	if not _arrival_panel:
		_create_arrival_panel()

	_arrival_destination_label.text = "Arrived at " + destination_name
	_arrival_panel.visible = true

	# Play arrival alert
	_show_alert("ARRIVED: " + destination_name)

func _create_arrival_panel() -> void:
	_arrival_panel = Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.12, 0.95)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = lcars_blue
	_arrival_panel.add_theme_stylebox_override("panel", style)
	_arrival_panel.size = Vector2(280, 140)
	_arrival_panel.position = Vector2(360, 150)
	_arrival_panel.visible = false
	add_child(_arrival_panel)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(15, 15)
	vbox.size = Vector2(250, 110)
	_arrival_panel.add_child(vbox)

	# Destination label
	_arrival_destination_label = Label.new()
	_arrival_destination_label.text = "Arrived at ---"
	_arrival_destination_label.add_theme_color_override("font_color", lcars_blue)
	_arrival_destination_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_arrival_destination_label)

	# Prompt text
	var prompt_label := Label.new()
	prompt_label.text = "Enter standard orbit?"
	prompt_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	prompt_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(prompt_label)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 15)
	vbox.add_child(spacer)

	# Buttons row
	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 15)
	vbox.add_child(btn_hbox)

	# Orbit button
	_arrival_orbit_button = Button.new()
	_arrival_orbit_button.text = "ORBIT (O)"
	_arrival_orbit_button.custom_minimum_size = Vector2(100, 35)
	_arrival_orbit_button.pressed.connect(_on_arrival_orbit)
	var orbit_style := StyleBoxFlat.new()
	orbit_style.bg_color = Color(0.2, 0.4, 0.6)
	orbit_style.corner_radius_top_left = 5
	orbit_style.corner_radius_top_right = 5
	orbit_style.corner_radius_bottom_left = 5
	orbit_style.corner_radius_bottom_right = 5
	_arrival_orbit_button.add_theme_stylebox_override("normal", orbit_style)
	btn_hbox.add_child(_arrival_orbit_button)

	# Dismiss button
	_arrival_dismiss_button = Button.new()
	_arrival_dismiss_button.text = "DISMISS"
	_arrival_dismiss_button.custom_minimum_size = Vector2(90, 35)
	_arrival_dismiss_button.pressed.connect(_on_arrival_dismiss)
	btn_hbox.add_child(_arrival_dismiss_button)

func _on_arrival_orbit() -> void:
	_arrival_panel.visible = false
	# Enter orbit around the destination
	if _selected_destination and _selected_destination_name:
		_enter_orbit(_selected_destination, _selected_destination_name)

func _on_arrival_dismiss() -> void:
	_arrival_panel.visible = false

func _try_enter_orbit() -> void:
	if not ship or not sector:
		return

	# Find best planet to orbit - prioritize by how close we are relative to orbit range
	var ship_pos: Vector3 = ship.global_position
	var best_planet: Node3D = null
	var best_name: String = ""
	var best_ratio: float = INF  # Lower ratio = closer relative to orbit range

	for planet_name in PLANET_COLORS.keys():
		if planet_name == "Sun":  # Can't orbit the Sun at close range
			continue
		var planet = sector.get_planet(planet_name) if sector.has_method("get_planet") else null
		if planet:
			var dist: float = ship_pos.distance_to(planet.global_position)
			var orbit_range: float = _get_orbit_range(planet_name)
			# Calculate ratio of distance to orbit range (lower = better match)
			var ratio: float = dist / orbit_range
			if ratio < 1.0 and ratio < best_ratio:
				best_ratio = ratio
				best_planet = planet
				best_name = planet_name

	if best_planet:
		_enter_orbit(best_planet, best_name)
	else:
		print("No planet in range for standard orbit")

func _get_orbit_range(planet_name: String) -> float:
	# Maximum distance to enter orbit (approximately 2x planet radius)
	# Planet radii at 250x scale: Jupiter=17475, Saturn=14525, Earth=1595, etc.
	match planet_name:
		"Jupiter":
			return 35000.0  # radius 17,475
		"Saturn":
			return 29000.0  # radius 14,525
		"Earth":
			return 3200.0   # radius 1,595
		"Venus":
			return 3000.0   # radius 1,515
		"Uranus":
			return 12700.0  # radius 6,365
		"Neptune":
			return 12400.0  # radius 6,175
		"Mars":
			return 1700.0   # radius 850
		"Mercury":
			return 1200.0   # radius 610
		"Moon":
			return 900.0    # radius 435 - smaller range to not conflict with Earth
		"Starbase 1":
			return 300.0    # radius 125 - smaller range for station
		_:
			return 2000.0

func _get_orbit_distance(planet_name: String) -> float:
	# Standard orbit distance: radius + altitude margin
	# Margin scales with planet size: gas giants +500, medium +200, small +100
	match planet_name:
		"Jupiter":
			return 18000.0  # radius 17,475 + 525
		"Saturn":
			return 15000.0  # radius 14,525 + 475
		"Earth":
			return 1700.0   # radius 1,595 + 105
		"Venus":
			return 1620.0   # radius 1,515 + 105
		"Uranus":
			return 6600.0   # radius 6,365 + 235
		"Neptune":
			return 6400.0   # radius 6,175 + 225
		"Mars":
			return 950.0    # radius 850 + 100
		"Mercury":
			return 710.0    # radius 610 + 100
		"Moon":
			return 500.0    # radius 435 + 65
		"Starbase 1":
			return 175.0    # radius 125 + 50
		_:
			return 1000.0   # default

func _update_orbit(delta: float) -> void:
	if not _orbit_active or not _orbit_target or not ship:
		return

	# Update orbit angle
	_orbit_angle += _orbit_speed * delta

	# Calculate new position
	var planet_pos: Vector3 = _orbit_target.global_position
	var orbit_x: float = sin(_orbit_angle) * _orbit_distance
	var orbit_z: float = cos(_orbit_angle) * _orbit_distance

	var target_pos: Vector3 = planet_pos + Vector3(orbit_x, _orbit_height, orbit_z)

	# Smooth interpolation for jitter-free orbit (frame-rate independent)
	var smooth_factor: float = 1.0 - exp(-20.0 * delta)
	ship.global_position = ship.global_position.lerp(target_pos, smooth_factor)

	# Face direction of travel (tangent to orbit) - smooth rotation
	var tangent: Vector3 = Vector3(cos(_orbit_angle), 0, -sin(_orbit_angle)).normalized()
	if tangent.length() > 0.001:
		var target_basis: Basis = Basis.looking_at(tangent, Vector3.UP)
		ship.basis = ship.basis.slerp(target_basis, smooth_factor)

	# Ensure physics is frozen during orbit
	ship.linear_velocity = Vector3.ZERO
	ship.angular_velocity = Vector3.ZERO
	ship.freeze = true
	ship.freeze = true

func _enter_orbit(planet: Node3D, planet_name: String) -> void:
	_orbit_active = true
	_orbit_target = planet
	_orbit_target_name = planet_name
	_orbit_distance = _get_orbit_distance(planet_name)

	# Calculate initial orbit angle based on current position
	var to_ship: Vector3 = ship.global_position - planet.global_position
	_orbit_angle = atan2(to_ship.x, to_ship.z)

	# Stop any autopilot
	if _autopilot_active:
		_autopilot_active = false
		_autopilot_aligning = false
		_hide_disengage_button()

	# Stop ship's own movement and freeze physics
	if ship:
		ship.current_impulse = ShipController.ImpulseLevel.STOP
		ship._update_target_speed()
		ship.linear_velocity = Vector3.ZERO
		ship.angular_velocity = Vector3.ZERO
		ship.freeze = true

	print("Entering standard orbit around ", planet_name)

func _disengage_orbit() -> void:
	_orbit_active = false
	_orbit_target = null
	_orbit_target_name = ""
	# Unfreeze physics and set to 1/4 impulse
	if ship:
		ship.freeze = false
		ship.current_impulse = ShipController.ImpulseLevel.QUARTER
	print("Breaking orbit - 1/4 Impulse")

# === DOCKING SYSTEM ===

func _try_dock() -> void:
	if not ship or not sector or _docked:
		return

	# Check if we're orbiting Starbase 1
	if _orbit_active and _orbit_target_name == "Starbase 1":
		_dock("Starbase 1")
		return

	# Check if we're close enough to dock without being in orbit
	var starbase = sector.get_planet("Starbase 1") if sector.has_method("get_planet") else null
	if starbase:
		var dist: float = ship.global_position.distance_to(starbase.global_position)
		if dist < 300.0:  # Within docking range
			_dock("Starbase 1")
			return

	print("Not in range to dock - enter orbit around Starbase 1 first")

func _dock(starbase_name: String) -> void:
	if not ship or not sector:
		return

	var starbase = sector.get_planet(starbase_name) if sector.has_method("get_planet") else null
	if not starbase:
		return

	_docked = true
	_docked_at = starbase_name

	# Stop any orbit
	if _orbit_active:
		_orbit_active = false
		_orbit_target = null
		_orbit_target_name = ""

	# Stop autopilot
	if _autopilot_active:
		_autopilot_active = false
		_autopilot_aligning = false
		_hide_disengage_button()

	# Freeze ship completely
	if ship:
		ship.current_impulse = ShipController.ImpulseLevel.STOP
		ship._update_target_speed()
		ship.linear_velocity = Vector3.ZERO
		ship.angular_velocity = Vector3.ZERO
		ship.freeze = true

		# Position ship at docking position (slightly below starbase)
		var dock_offset := Vector3(0, -150, 200)  # Offset from starbase center
		ship.global_position = starbase.global_position + dock_offset
		# Face away from station
		ship.look_at(ship.global_position + Vector3(0, 0, 1), Vector3.UP)

	# Show docked UI
	_show_dock_panel()
	print("Docked at ", starbase_name)

func _undock() -> void:
	if not _docked or not ship:
		return

	_docked = false
	var old_station: String = _docked_at
	_docked_at = ""

	# Unfreeze ship
	ship.freeze = false

	# Push ship away from station
	var push_dir := -ship.global_transform.basis.z  # Forward direction
	ship.linear_velocity = push_dir * 10.0  # Gentle push

	# Hide docked UI
	_hide_dock_panel()
	print("Undocked from ", old_station)

func _create_dock_panel() -> void:
	_dock_panel = Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.12, 0.95)
	style.corner_radius_top_left = 15
	style.corner_radius_top_right = 15
	style.corner_radius_bottom_left = 15
	style.corner_radius_bottom_right = 15
	style.border_width_left = 4
	style.border_width_right = 4
	style.border_width_top = 4
	style.border_width_bottom = 4
	style.border_color = lcars_blue
	_dock_panel.add_theme_stylebox_override("panel", style)
	_dock_panel.size = Vector2(300, 180)
	# Center horizontally
	_dock_panel.anchor_left = 0.5
	_dock_panel.anchor_right = 0.5
	_dock_panel.anchor_top = 0.3
	_dock_panel.offset_left = -150
	_dock_panel.offset_right = 150
	_dock_panel.visible = false
	add_child(_dock_panel)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(20, 15)
	vbox.size = Vector2(260, 150)
	_dock_panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "DOCKED: STARBASE 1"
	title.name = "DockTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", lcars_blue)
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 15)
	vbox.add_child(sep)

	# Status info
	var status := Label.new()
	status.text = "Status: All Systems Nominal\nDocking Bay: Alpha-7\nClearance: Granted"
	status.add_theme_color_override("font_color", Color(0.7, 0.8, 0.7))
	status.add_theme_font_size_override("font_size", 14)
	vbox.add_child(status)

	# Separator
	var sep2 := HSeparator.new()
	sep2.add_theme_constant_override("separation", 15)
	vbox.add_child(sep2)

	# Undock button
	var undock_btn := Button.new()
	undock_btn.text = "UNDOCK [Shift+D]"
	undock_btn.custom_minimum_size = Vector2(120, 40)
	undock_btn.pressed.connect(_undock)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.4, 0.2, 0.2)
	btn_style.corner_radius_top_left = 8
	btn_style.corner_radius_top_right = 8
	btn_style.corner_radius_bottom_left = 8
	btn_style.corner_radius_bottom_right = 8
	btn_style.border_width_left = 2
	btn_style.border_width_right = 2
	btn_style.border_width_top = 2
	btn_style.border_width_bottom = 2
	btn_style.border_color = lcars_orange
	undock_btn.add_theme_stylebox_override("normal", btn_style)
	var hover_style := btn_style.duplicate()
	hover_style.bg_color = Color(0.5, 0.25, 0.25)
	undock_btn.add_theme_stylebox_override("hover", hover_style)
	vbox.add_child(undock_btn)

func _show_dock_panel() -> void:
	if not _dock_panel:
		_create_dock_panel()
	# Update title with station name
	var title = _dock_panel.get_node_or_null("VBoxContainer/DockTitle") as Label
	if title:
		title.text = "DOCKED: " + _docked_at.to_upper()
	_dock_panel.visible = true

func _hide_dock_panel() -> void:
	if _dock_panel:
		_dock_panel.visible = false

func _update_docking_ui() -> void:
	# This updates the dock button on the course panel when orbiting a starbase
	if _orbit_active and _orbit_target_name == "Starbase 1" and not _docked:
		if not _dock_button:
			_create_dock_button()
		_dock_button.visible = true
	else:
		if _dock_button:
			_dock_button.visible = false

func _create_dock_button() -> void:
	_dock_button = Button.new()
	_dock_button.text = "DOCK [Shift+D]"
	_dock_button.custom_minimum_size = Vector2(100, 35)
	_dock_button.position = Vector2(20, 400)
	_dock_button.pressed.connect(_try_dock)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.3, 0.5)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = lcars_blue
	_dock_button.add_theme_stylebox_override("normal", style)
	_dock_button.visible = false
	add_child(_dock_button)

func _show_disengage_button() -> void:
	if not _disengage_button:
		_disengage_button = Button.new()
		_disengage_button.text = "DISENGAGE [Space]"
		_disengage_button.custom_minimum_size = Vector2(140, 35)
		_disengage_button.position = Vector2(20, 360)
		_disengage_button.pressed.connect(_on_disengage_pressed)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.6, 0.2, 0.2)
		style.corner_radius_top_left = 5
		style.corner_radius_top_right = 5
		style.corner_radius_bottom_left = 5
		style.corner_radius_bottom_right = 5
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_color = lcars_red
		_disengage_button.add_theme_stylebox_override("normal", style)
		add_child(_disengage_button)
	_disengage_button.visible = true

func _hide_disengage_button() -> void:
	if _disengage_button:
		_disengage_button.visible = false

func _on_disengage_pressed() -> void:
	if _autopilot_active:
		_disengage_autopilot()
	if _orbit_active:
		_disengage_orbit()

func _create_planet_markers() -> void:
	# Create markers for all planets once
	for planet_name in PLANET_COLORS.keys():
		var color: Color = PLANET_COLORS[planet_name]

		# Planet button (clickable marker)
		var marker := Button.new()
		marker.flat = false
		marker.custom_minimum_size = Vector2(16, 16)
		marker.size = Vector2(16, 16)
		marker.visible = false
		marker.z_index = 50
		marker.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		# Style the button to look like a colored dot with border
		var style_normal := StyleBoxFlat.new()
		style_normal.bg_color = color
		style_normal.border_width_left = 2
		style_normal.border_width_right = 2
		style_normal.border_width_top = 2
		style_normal.border_width_bottom = 2
		style_normal.border_color = Color.WHITE
		style_normal.corner_radius_top_left = 10
		style_normal.corner_radius_top_right = 10
		style_normal.corner_radius_bottom_left = 10
		style_normal.corner_radius_bottom_right = 10
		marker.add_theme_stylebox_override("normal", style_normal)

		# Hover style - brighter
		var style_hover := StyleBoxFlat.new()
		style_hover.bg_color = color.lightened(0.3)
		style_hover.border_width_left = 2
		style_hover.border_width_right = 2
		style_hover.border_width_top = 2
		style_hover.border_width_bottom = 2
		style_hover.border_color = lcars_yellow
		style_hover.corner_radius_top_left = 10
		style_hover.corner_radius_top_right = 10
		style_hover.corner_radius_bottom_left = 10
		style_hover.corner_radius_bottom_right = 10
		marker.add_theme_stylebox_override("hover", style_hover)
		marker.add_theme_stylebox_override("pressed", style_hover)

		# Connect click signal
		marker.pressed.connect(_on_planet_clicked.bind(planet_name))

		_minimap.add_child(marker)
		_planet_markers[planet_name] = marker

		# Planet label as clickable button
		var label_btn := Button.new()
		label_btn.text = planet_name
		label_btn.flat = true
		label_btn.add_theme_font_size_override("font_size", 11)
		label_btn.add_theme_color_override("font_color", color)
		label_btn.add_theme_color_override("font_hover_color", lcars_yellow)
		label_btn.visible = false
		label_btn.z_index = 51
		label_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		label_btn.pressed.connect(_on_planet_clicked.bind(planet_name))
		_minimap.add_child(label_btn)
		_planet_labels[planet_name] = label_btn

func _toggle_map_size() -> void:
	_minimap_expanded = not _minimap_expanded
	_rebuild_map_layout()

func _rebuild_map_layout() -> void:
	var bg = _minimap.get_node_or_null("Background") as ColorRect
	var reset_btn = _minimap_panel.get_node_or_null("ResetViewBtn")

	if _minimap_expanded:
		_minimap_panel.offset_left = -MINIMAP_LARGE_SIZE.x - 20
		_minimap_panel.offset_bottom = 20 + MINIMAP_LARGE_SIZE.y
		_minimap.size = Vector2(MINIMAP_LARGE_SIZE.x - 20, MINIMAP_LARGE_SIZE.y - 80)
		if bg:
			bg.size = _minimap.size
		_minimap_title.text = "SOL SYSTEM MAP [M] - Right-click drag to pan"
		_orbit_container.visible = true
		_map_zoom_slider.visible = true
		_map_zoom_label.visible = true
		if reset_btn:
			reset_btn.visible = true
		_draw_orbit_rings()
	else:
		_minimap_panel.offset_left = -MINIMAP_SMALL_SIZE.x - 20
		_minimap_panel.offset_bottom = 20 + MINIMAP_SMALL_SIZE.y
		_minimap.size = Vector2(140, 140)
		if bg:
			bg.size = Vector2(140, 140)
		_minimap_title.text = "NAVIGATION [M]"
		_orbit_container.visible = false
		_map_zoom_slider.visible = false
		_map_zoom_label.visible = false
		if reset_btn:
			reset_btn.visible = false

func _draw_orbit_rings() -> void:
	# Clear old orbits
	for child in _orbit_container.get_children():
		child.queue_free()

	var map_center: Vector2 = _minimap.size / 2 + _map_offset
	var max_distance: float = 5000000.0 / _map_zoom  # Zoom affects visible range
	var map_scale: float = (min(_minimap.size.x, _minimap.size.y) / 2 - 20) / max_distance

	# Draw orbit circles using Line2D for each planet orbit (realistic distances)
	var orbit_distances: Dictionary = {
		"Mercury": 57900, "Venus": 108200, "Earth": 149600,
		"Mars": 227900, "Jupiter": 778500, "Saturn": 1434000,
		"Uranus": 2871000, "Neptune": 4495000
	}

	for planet_name in orbit_distances.keys():
		var dist: float = orbit_distances[planet_name]
		var radius: float = dist * map_scale

		# Skip orbits that are way too large (performance)
		if radius > 2000:
			continue

		var orbit_line := Line2D.new()
		orbit_line.width = 1.0
		orbit_line.default_color = Color(0.2, 0.3, 0.4, 0.5)

		# Draw circle with segments
		var points: PackedVector2Array = []
		var segments: int = 64
		for i in range(segments + 1):
			var angle: float = (float(i) / float(segments)) * TAU
			points.append(map_center + Vector2(cos(angle), sin(angle)) * radius)
		orbit_line.points = points
		_orbit_container.add_child(orbit_line)

func _process(delta: float) -> void:
	_update_impulse()
	_update_warp()
	_update_heading()
	_update_camera()
	_update_minimap()
	_update_autopilot(delta)
	_update_orbit(delta)
	_update_docking_ui()
	_update_eta()

	# Update course info if panel is visible
	if _course_panel and _course_panel.visible:
		_update_course_info()

func _update_autopilot(_delta: float) -> void:
	if not _autopilot_active or not ship:
		return

	# Update destination if tracking a moving body (like Moon)
	if _selected_destination:
		_autopilot_destination = _selected_destination.global_position

	var ship_pos: Vector3 = ship.global_position
	var to_target: Vector3 = _autopilot_destination - ship_pos
	var distance: float = to_target.length()

	# Calculate desired heading
	var target_dir: Vector3 = to_target.normalized()
	var current_forward: Vector3 = -ship.global_transform.basis.z
	var current_up: Vector3 = ship.global_transform.basis.y

	# Calculate angle between current heading and target (always positive)
	var dot: float = current_forward.dot(target_dir)
	var angle_to_target: float = acos(clampf(dot, -1.0, 1.0))
	var is_aligned: bool = angle_to_target < 0.05  # ~3 degrees

	# Handle alignment phase for warp
	if _autopilot_aligning:
		if is_aligned:
			# Alignment complete - now level the ship, then engage warp
			_autopilot_aligning = false
			# Correct roll to level the ship
			_apply_roll_correction(current_forward, current_up)
			if warp_drive:
				warp_drive.engage_warp()
				print("Alignment complete - Warp ", warp_drive.target_warp_factor, " engaged!")
		else:
			# Still aligning - rotate toward target (fast: 180° in 3 seconds)
			_apply_autopilot_rotation_v2(current_forward, current_up, target_dir, 1.05)
		return  # Don't do anything else while aligning

	# Check if we've arrived
	var arrival_distance: float = _get_orbit_range(_selected_destination_name) if _selected_destination_name != "Sun" else 25000.0

	# If at warp, drop out at orbit range + buffer (minimum 5000 units = 5M km)
	if _autopilot_using_warp and warp_drive and warp_drive.is_at_warp:
		arrival_distance = max(arrival_distance + 2000.0, 5000.0)

	if distance < arrival_distance:
		print("Arrived at ", _selected_destination_name)
		_autopilot_active = false
		_autopilot_aligning = false
		_hide_disengage_button()

		# Drop out of warp if using warp autopilot
		if _autopilot_using_warp and warp_drive and warp_drive.is_at_warp:
			warp_drive.disengage_warp()  # Goes to full impulse
			_autopilot_using_warp = false

		# Show arrival prompt (unless it's the Sun)
		if _selected_destination and _selected_destination_name != "Sun":
			_show_arrival_prompt(_selected_destination_name)
		return

	# Continue course corrections during travel
	if not is_aligned:
		_apply_autopilot_rotation_v2(current_forward, current_up, target_dir, 1.05)
	else:
		# Aligned with target - correct roll to keep ship level
		_apply_roll_correction(current_forward, current_up)

## Apply autopilot rotation using cross product (guaranteed shortest path)
func _apply_autopilot_rotation_v2(current_forward: Vector3, current_up: Vector3, target_dir: Vector3, max_speed: float) -> void:
	if not ship:
		return

	# Use cross product to find rotation axis - this ALWAYS gives shortest path
	var rotation_axis: Vector3 = current_forward.cross(target_dir)
	var axis_length: float = rotation_axis.length()

	if axis_length < 0.001:
		# Vectors are parallel - either aligned or opposite
		var dot: float = current_forward.dot(target_dir)
		if dot < 0:
			# Facing opposite direction - rotate around up axis
			rotation_axis = current_up
			axis_length = 1.0
			rotation_axis = rotation_axis / axis_length
			ship.angular_velocity = rotation_axis * max_speed
		else:
			# Already aligned
			ship.angular_velocity = Vector3.ZERO
		return

	# Normalize the rotation axis
	rotation_axis = rotation_axis / axis_length

	# Calculate angle to target
	var dot_product: float = current_forward.dot(target_dir)
	var angle: float = acos(clampf(dot_product, -1.0, 1.0))

	# Scale speed based on remaining angle (slow down when close)
	var speed_factor: float = clampf(angle / 0.35, 0.2, 1.0)  # Slow down within 20 degrees
	var angular_speed: float = max_speed * speed_factor

	# Apply rotation around the axis at the calculated speed
	ship.angular_velocity = rotation_axis * angular_speed

## Correct roll to level the ship (call after alignment is complete)
func _apply_roll_correction(current_forward: Vector3, current_up: Vector3) -> void:
	if not ship:
		return

	var world_up: Vector3 = Vector3.UP
	var forward_normalized: Vector3 = current_forward.normalized()

	# Project world up onto the plane perpendicular to forward (to isolate roll)
	var world_up_in_plane: Vector3 = (world_up - forward_normalized * world_up.dot(forward_normalized)).normalized()

	# The roll error is the angle between ship's up and the projected world up
	var roll_dot: float = current_up.dot(world_up_in_plane)
	var roll_angle: float = acos(clampf(roll_dot, -1.0, 1.0))

	# Only correct if roll is significant (> 2 degrees)
	if roll_angle < 0.035:
		ship.angular_velocity = Vector3.ZERO
		return

	# Determine roll direction
	var roll_cross: Vector3 = current_up.cross(world_up_in_plane)
	var roll_direction: float = sign(roll_cross.dot(forward_normalized))

	# Apply roll correction (rotate around forward axis to level out)
	var roll_correction_speed: float = clampf(roll_angle * 1.5, 0.1, 0.8)  # Smooth correction
	ship.angular_velocity = forward_normalized * roll_direction * roll_correction_speed

func _update_impulse() -> void:
	if not ship or not _impulse_label:
		return

	# At warp, impulse is not relevant
	if warp_drive and warp_drive.is_at_warp:
		_impulse_label.text = "IMPULSE: -"
		_impulse_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		return

	var impulse_name: String = ship.get_impulse_name()

	# Calculate actual speed (1 unit = 1000 km, so speed * 1000 = km/s)
	var speed_kms: float = abs(ship.forward_speed) * 1000.0  # km/s
	var speed_c: float = speed_kms / 299792.0  # Fraction of light speed

	# Format speed display
	var speed_str: String
	if speed_c >= 0.01:
		speed_str = "%.2fc" % speed_c  # Show as fraction of c
	elif speed_kms >= 1000:
		speed_str = "%.0f km/s" % speed_kms
	elif speed_kms >= 1:
		speed_str = "%.1f km/s" % speed_kms
	else:
		speed_str = "0 km/s"

	# Add status indicator (docked > orbit > autopilot > normal)
	if _docked:
		_impulse_label.text = "DOCKED: %s" % _docked_at
		_impulse_label.add_theme_color_override("font_color", lcars_blue)
	elif _orbit_active:
		_impulse_label.text = "ORBIT: Standard orbit - %s" % _orbit_target_name
		_impulse_label.add_theme_color_override("font_color", lcars_purple)
	elif _autopilot_active:
		if _autopilot_aligning:
			_impulse_label.text = "ALIGNING: → %s" % _selected_destination_name
			_impulse_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.0))  # Orange for aligning
		else:
			_impulse_label.text = "AUTOPILOT: %s → %s" % [impulse_name, _selected_destination_name]
			_impulse_label.add_theme_color_override("font_color", lcars_yellow)
	else:
		_impulse_label.text = "IMPULSE: %s (%s)" % [impulse_name, speed_str]
		# Color based on impulse level
		var fraction: float = ship.get_impulse_fraction()
		if fraction >= 1.0:
			_impulse_label.add_theme_color_override("font_color", lcars_orange)
		elif fraction > 0:
			_impulse_label.add_theme_color_override("font_color", lcars_blue)
		else:
			_impulse_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))

func _update_warp() -> void:
	if not _warp_label:
		return

	if warp_drive and warp_drive.is_at_warp:
		var wf: float = warp_drive.get_warp_factor()
		# Show appropriate precision - more decimals for warp 9+
		if wf >= 9.0:
			# For warp 9+, show up to 2 decimal places, but don't round up to 10
			var display_wf: float = minf(wf, warp_drive.max_warp_factor)
			if display_wf >= 9.99:
				_warp_label.text = "WARP: Factor %.3f" % display_wf
			elif display_wf >= 9.9:
				_warp_label.text = "WARP: Factor %.2f" % display_wf
			else:
				_warp_label.text = "WARP: Factor %.1f" % display_wf
		else:
			_warp_label.text = "WARP: Factor %.1f" % wf
		_warp_label.add_theme_color_override("font_color", lcars_purple)
	else:
		_warp_label.text = "WARP: Standby"
		_warp_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))

func _update_heading() -> void:
	if not ship or not _heading_label:
		return

	var rot: Vector3 = ship.global_rotation_degrees
	_heading_label.text = "HEADING: %.0f° / %.0f° / %.0f°" % [rot.x, rot.y, rot.z]

func _update_camera() -> void:
	if not _camera_label:
		return

	if camera_manager:
		_camera_label.text = "CAMERA: " + camera_manager.get_mode_name().to_upper()
	else:
		_camera_label.text = "CAMERA: EXTERNAL"

func _update_minimap() -> void:
	if not ship or not _minimap:
		return

	# Update ship rotation indicator
	var yaw: float = ship.global_rotation.y
	_minimap_ship.rotation = -yaw

	var map_size: Vector2 = _minimap.size
	var map_center: Vector2 = map_size / 2

	# Get ship position - use universe coordinates for expanded map (Sun-centered)
	# This makes the ship appear to move on the map, not the planets
	var ship_pos: Vector3 = ship.global_position  # World position (for compact mode)
	var ship_universe_pos: Vector3 = ship_pos     # Universe position (for expanded mode)

	var fo = get_node_or_null("/root/FloatingOrigin")
	if fo:
		ship_universe_pos = fo.get_player_universe_position()

	# Different scale for expanded vs compact map
	# Realistic scale: Neptune at 4.5M units, Mars at 228K units
	var max_distance: float
	if _minimap_expanded:
		max_distance = 5000000.0 / _map_zoom  # Apply zoom
	else:
		max_distance = 500000.0
	var map_scale: float = (min(map_size.x, map_size.y) / 2 - 20) / max_distance

	# Update ship position
	if _minimap_expanded:
		# Expanded: Sun-centered with pan offset, ship moves on map
		# Use universe coordinates so ship appears to move through solar system
		var adjusted_center: Vector2 = map_center + _map_offset
		var ship_x: float = adjusted_center.x + ship_universe_pos.x * map_scale
		var ship_y: float = adjusted_center.y + ship_universe_pos.z * map_scale
		_minimap_ship.position = Vector2(ship_x, ship_y)
	else:
		# Compact: Ship-centered
		_minimap_ship.position = map_center

	# Update planet positions (pass universe ship pos for expanded mode)
	_update_planet_markers(map_center, map_scale, ship_pos, ship_universe_pos)

func _update_planet_markers(map_center: Vector2, map_scale: float, ship_pos: Vector3, ship_universe_pos: Vector3 = Vector3.ZERO) -> void:
	if not sector:
		return

	# Apply pan offset to map center when expanded
	var adjusted_center: Vector2 = map_center
	if _minimap_expanded:
		adjusted_center += _map_offset

	# Get FloatingOrigin for universe coordinate conversion
	var fo = get_node_or_null("/root/FloatingOrigin")

	for planet_name in PLANET_COLORS.keys():
		var marker: Button = _planet_markers.get(planet_name)
		var label_btn: Button = _planet_labels.get(planet_name)
		if not marker:
			continue

		# Get planet from sector
		var planet = sector.get_planet(planet_name) if sector.has_method("get_planet") else null
		if not planet:
			marker.visible = false
			if label_btn:
				label_btn.visible = false
			continue

		# Get planet position - use universe coordinates for expanded mode
		var planet_pos: Vector3 = planet.global_position  # World position
		var planet_universe_pos: Vector3 = planet_pos     # Universe position
		if fo:
			planet_universe_pos = fo.world_to_universe(planet_pos)

		# Calculate marker size (larger in expanded mode for easier clicking)
		var size: float = 6.0
		var is_starbase: bool = planet_name == "Starbase 1"
		match planet_name:
			"Sun":
				size = 20.0 if _minimap_expanded else 6.0
			"Jupiter", "Saturn":
				size = 16.0 if _minimap_expanded else 5.0
			"Uranus", "Neptune":
				size = 12.0 if _minimap_expanded else 4.0
			"Earth", "Venus":
				size = 14.0 if _minimap_expanded else 4.0
			"Moon", "Mercury":
				size = 10.0 if _minimap_expanded else 3.0
			"Mars":
				size = 12.0 if _minimap_expanded else 4.0
			"Starbase 1":
				size = 12.0 if _minimap_expanded else 4.0

		# Calculate position
		var x: float
		var y: float
		if _minimap_expanded:
			# Expanded: Use universe coordinates (Sun at center, ship moves)
			x = adjusted_center.x + planet_universe_pos.x * map_scale
			y = adjusted_center.y + planet_universe_pos.z * map_scale
		else:
			# Compact: Ship-centered (use relative world positions)
			var rel: Vector3 = planet_pos - ship_pos
			x = map_center.x + rel.x * map_scale
			y = map_center.y + rel.z * map_scale

		# Check bounds (with some margin)
		var margin: float = 50.0
		var in_bounds: bool = x >= -margin and x <= _minimap.size.x + margin and y >= -margin and y <= _minimap.size.y + margin

		# Update marker
		marker.visible = in_bounds and _minimap_expanded  # Only clickable when expanded
		marker.custom_minimum_size = Vector2(size, size)
		marker.size = Vector2(size, size)
		marker.position = Vector2(x - size/2, y - size/2)

		# Update button style with rounded corners based on size
		# Starbases use square markers (radius 0), planets use circles
		var style_normal: StyleBoxFlat = marker.get_theme_stylebox("normal") as StyleBoxFlat
		var style_hover: StyleBoxFlat = marker.get_theme_stylebox("hover") as StyleBoxFlat
		if style_normal:
			var corner_radius: int = 0 if is_starbase else int(size / 2)
			style_normal.corner_radius_top_left = corner_radius
			style_normal.corner_radius_top_right = corner_radius
			style_normal.corner_radius_bottom_left = corner_radius
			style_normal.corner_radius_bottom_right = corner_radius
		if style_hover:
			var corner_radius: int = 0 if is_starbase else int(size / 2)
			style_hover.corner_radius_top_left = corner_radius
			style_hover.corner_radius_top_right = corner_radius
			style_hover.corner_radius_bottom_left = corner_radius
			style_hover.corner_radius_bottom_right = corner_radius

		# Update label button (expanded mode only, skip Moon)
		if label_btn:
			label_btn.visible = in_bounds and _minimap_expanded and planet_name != "Moon"
			label_btn.position = Vector2(x + size/2 + 4, y - 8)

func add_tracked_object(obj: Node3D) -> void:
	if obj and not _tracked_objects.has(obj):
		_tracked_objects.append(obj)

func remove_tracked_object(obj: Node3D) -> void:
	_tracked_objects.erase(obj)

func _on_change_ship_pressed() -> void:
	# Return to ship selection screen
	print("Returning to ship selection...")
	get_tree().change_scene_to_file("res://scenes/ui/ship_selection.tscn")
