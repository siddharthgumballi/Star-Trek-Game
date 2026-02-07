extends CanvasLayer
class_name ControlsOverlay
## Displays keyboard controls help
## Toggle with F7

var _visible: bool = false
var _panel: PanelContainer
var _scroll: ScrollContainer
var _label: RichTextLabel
var _center_container: CenterContainer

func _ready() -> void:
	layer = 100
	_setup_input()
	_create_ui()
	_panel.visible = _visible

func _setup_input() -> void:
	if not InputMap.has_action("toggle_controls_help"):
		InputMap.add_action("toggle_controls_help")
		var event := InputEventKey.new()
		event.physical_keycode = KEY_F7
		InputMap.action_add_event("toggle_controls_help", event)

func _create_ui() -> void:
	# Create a centered container that blocks mouse when visible
	_center_container = CenterContainer.new()
	_center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_center_container.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Pass through when not over panel
	add_child(_center_container)

	_panel = PanelContainer.new()
	_panel.name = "ControlsPanel"
	# Block all mouse events when panel is visible
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.05, 0.95)
	style.border_color = Color(0.3, 0.5, 0.8, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(20)
	_panel.add_theme_stylebox_override("panel", style)

	# Fixed size that fits on screen
	_panel.custom_minimum_size = Vector2(650, 450)

	# Scroll container for content - consume mouse events
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(610, 410)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.mouse_filter = Control.MOUSE_FILTER_STOP  # Block scroll from passing through

	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false  # Let ScrollContainer handle scrolling
	_label.custom_minimum_size = Vector2(590, 0)  # Width fixed, height auto
	_label.add_theme_font_size_override("normal_font_size", 13)
	_label.add_theme_color_override("default_color", Color(0.85, 0.9, 1.0))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Let scroll container handle

	_label.text = _build_help_text()

	_scroll.add_child(_label)
	_panel.add_child(_scroll)
	_center_container.add_child(_panel)

	# Connect to gui_input to consume scroll events
	_panel.gui_input.connect(_on_panel_gui_input)
	_scroll.gui_input.connect(_on_scroll_gui_input)

func _build_help_text() -> String:
	var t: String = ""

	t += "[center][b][color=#4af]STARSHIP CONTROLS[/color][/b][/center]\n"
	t += "[center][color=#666]Press F7 to close | Scroll to see more[/color][/center]\n\n"

	# Two column layout using tabs
	t += "[color=#ff0]═══ FLIGHT ═══[/color]                    [color=#ff0]═══ TACTICAL ═══[/color]\n"
	t += "[color=#8cf]W/S[/color]      Pitch up/down              [color=#8cf]Shift+S[/color]  Toggle shields\n"
	t += "[color=#8cf]A/D[/color]      Yaw left/right             [color=#8cf]F[/color]        Fire phasers\n"
	t += "[color=#8cf]Z/C[/color]      Roll left/right            [color=#8cf]T[/color]        Fire torpedoes\n"
	t += "[color=#8cf]E/Q[/color]      Increase/decrease impulse  [color=#8cf]Tab[/color]      Cycle targets\n"
	t += "[color=#8cf]Shift+W[/color]  Engage/exit warp           [color=#8cf]X[/color]        Clear target\n"
	t += "[color=#8cf]+/-[/color]      Warp factor up/down\n"
	t += "[color=#8cf]V[/color]        Evasive maneuvers\n"
	t += "[color=#8cf]B[/color]        Reverse engines\n"
	t += "[color=#8cf]Space[/color]    Full stop\n\n"

	t += "[color=#ff0]═══ ALERTS ═══[/color]                     [color=#ff0]═══ POWER PRESETS ═══[/color]\n"
	t += "[color=#f00]R[/color]        Red alert                  [color=#8cf]1[/color]        Balanced (25/25/25/25)\n"
	t += "[color=#ff0]Y[/color]        Yellow alert               [color=#8cf]2[/color]        Combat (shields/weapons)\n"
	t += "[color=#0f0]G[/color]        Green alert (stand down)   [color=#8cf]3[/color]        Evasive (engines)\n"
	t += "                                     [color=#8cf]4[/color]        Science (sensors)\n\n"

	t += "[color=#ff0]═══ POWER BOOST ═══[/color]                [color=#ff0]═══ OPERATIONS ═══[/color]\n"
	t += "[color=#8cf]Shift+1[/color]  +10%% engines              [color=#8cf]N[/color]        Long range scan\n"
	t += "[color=#8cf]Shift+2[/color]  +10%% shields              [color=#8cf]P[/color]        Status report\n"
	t += "[color=#8cf]Shift+3[/color]  +10%% weapons              [color=#8cf]M[/color]        Toggle map\n"
	t += "[color=#8cf]Shift+4[/color]  +10%% sensors\n\n"

	t += "[color=#ff0]═══ DEBUG ═══[/color]\n"
	t += "[color=#8cf]F6[/color]       Debug overlay (system status)\n"
	t += "[color=#8cf]F7[/color]       This help screen\n"

	return t

func _on_panel_gui_input(event: InputEvent) -> void:
	# Consume all mouse events when panel is visible
	if event is InputEventMouseButton:
		get_viewport().set_input_as_handled()

func _on_scroll_gui_input(event: InputEvent) -> void:
	# Consume scroll wheel events - let ScrollContainer handle them
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# Mark as handled so camera doesn't zoom
			get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	# Toggle visibility
	if event.is_action_pressed("toggle_controls_help"):
		_visible = not _visible
		_panel.visible = _visible
		get_viewport().set_input_as_handled()
		return

	# When panel is visible, consume mouse wheel events if mouse is over panel
	if _visible and _panel.visible:
		if event is InputEventMouseButton:
			var mb: InputEventMouseButton = event
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				# Check if mouse is over the panel
				var panel_rect: Rect2 = _panel.get_global_rect()
				if panel_rect.has_point(mb.position):
					# Scroll the container manually and consume event
					var scroll_amount: float = 30.0
					if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
						_scroll.scroll_vertical -= scroll_amount
					else:
						_scroll.scroll_vertical += scroll_amount
					get_viewport().set_input_as_handled()
