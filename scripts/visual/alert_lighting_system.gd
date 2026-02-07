extends Node
class_name AlertLightingSystem
## Dynamic screen effects based on alert state
## RED: Flashing red borders + "RED ALERT" text at top center
## YELLOW: Subtle yellow border glow
## GREEN: No effects

# =============================================================================
# CONFIGURATION
# =============================================================================

const TRANSITION_TIME: float = 0.5
const RED_FLASH_INTERVAL: float = 1.0  # Red alert flash period
const BORDER_WIDTH: float = 8.0  # Pixel width of border glow

# =============================================================================
# STATE
# =============================================================================

var _enabled: bool = true
var _current_alert: int = 0
var _flash_time: float = 0.0

# UI Elements
var _canvas_layer: CanvasLayer = null
var _alert_label: Label = null
var _border_top: ColorRect = null
var _border_bottom: ColorRect = null
var _border_left: ColorRect = null
var _border_right: ColorRect = null

# Tweens
var _transition_tween: Tween = null

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	call_deferred("_initialize")

func _initialize() -> void:
	_create_ui()
	_set_alert_visuals(0, true)  # Start at green (no effects)

func _create_ui() -> void:
	# Create canvas layer for alert UI
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 95  # Above most UI but below controls overlay
	_canvas_layer.name = "AlertUILayer"
	add_child(_canvas_layer)

	# Create RED ALERT label at top center
	_alert_label = Label.new()
	_alert_label.name = "AlertLabel"
	_alert_label.text = "RED ALERT"
	_alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_alert_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_alert_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_alert_label.position = Vector2(-100, 20)
	_alert_label.size = Vector2(200, 40)
	_alert_label.add_theme_font_size_override("font_size", 28)
	_alert_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.1))
	_alert_label.add_theme_color_override("font_outline_color", Color(0.3, 0.0, 0.0))
	_alert_label.add_theme_constant_override("outline_size", 3)
	_alert_label.visible = false
	_canvas_layer.add_child(_alert_label)

	# Create border rectangles (flashing red glow on edges)
	_border_top = _create_border_rect("BorderTop", true, false)
	_border_bottom = _create_border_rect("BorderBottom", true, true)
	_border_left = _create_border_rect("BorderLeft", false, false)
	_border_right = _create_border_rect("BorderRight", false, true)

func _create_border_rect(rect_name: String, is_horizontal: bool, is_far_edge: bool) -> ColorRect:
	var rect: ColorRect = ColorRect.new()
	rect.name = rect_name
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color(1.0, 0.15, 0.1, 0.0)  # Red, start invisible

	if is_horizontal:
		# Top or bottom border
		rect.anchor_left = 0.0
		rect.anchor_right = 1.0
		rect.offset_left = 0
		rect.offset_right = 0
		if is_far_edge:
			# Bottom
			rect.anchor_top = 1.0
			rect.anchor_bottom = 1.0
			rect.offset_top = -BORDER_WIDTH
			rect.offset_bottom = 0
		else:
			# Top
			rect.anchor_top = 0.0
			rect.anchor_bottom = 0.0
			rect.offset_top = 0
			rect.offset_bottom = BORDER_WIDTH
	else:
		# Left or right border
		rect.anchor_top = 0.0
		rect.anchor_bottom = 1.0
		rect.offset_top = 0
		rect.offset_bottom = 0
		if is_far_edge:
			# Right
			rect.anchor_left = 1.0
			rect.anchor_right = 1.0
			rect.offset_left = -BORDER_WIDTH
			rect.offset_right = 0
		else:
			# Left
			rect.anchor_left = 0.0
			rect.anchor_right = 0.0
			rect.offset_left = 0
			rect.offset_right = BORDER_WIDTH

	_canvas_layer.add_child(rect)
	return rect

# =============================================================================
# PROCESS
# =============================================================================

func _process(delta: float) -> void:
	if not _enabled:
		return

	# Red alert flashing
	if _current_alert == 2:
		_flash_time += delta
		_update_red_flash()

func _update_red_flash() -> void:
	# Sinusoidal flash - smooth pulsing
	var flash: float = (sin(_flash_time * PI * 2.0 / RED_FLASH_INTERVAL) + 1.0) * 0.5
	var alpha: float = 0.4 + flash * 0.5  # Range from 0.4 to 0.9

	# Update border colors
	var flash_color: Color = Color(1.0, 0.15, 0.1, alpha)
	if _border_top:
		_border_top.color = flash_color
	if _border_bottom:
		_border_bottom.color = flash_color
	if _border_left:
		_border_left.color = flash_color
	if _border_right:
		_border_right.color = flash_color

	# Pulse the label too
	if _alert_label:
		var label_alpha: float = 0.7 + flash * 0.3
		_alert_label.modulate = Color(1.0, 1.0, 1.0, label_alpha)

# =============================================================================
# PUBLIC API
# =============================================================================

func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not enabled:
		_set_alert_visuals(0, true)

func set_alert_level(level: int) -> void:
	if level == _current_alert:
		return

	_current_alert = level
	_flash_time = 0.0
	_set_alert_visuals(level, false)

func _set_alert_visuals(level: int, instant: bool) -> void:
	var duration: float = 0.0 if instant else TRANSITION_TIME

	# Kill existing transition
	if _transition_tween:
		_transition_tween.kill()

	if level == 2:  # RED ALERT
		# Show label
		if _alert_label:
			_alert_label.visible = true
			_alert_label.modulate = Color(1, 1, 1, 1)

		# Show borders (will be animated in _update_red_flash)
		var start_color: Color = Color(1.0, 0.15, 0.1, 0.5)
		if _border_top:
			_border_top.color = start_color
		if _border_bottom:
			_border_bottom.color = start_color
		if _border_left:
			_border_left.color = start_color
		if _border_right:
			_border_right.color = start_color

	elif level == 1:  # YELLOW ALERT
		# Hide red alert label
		if _alert_label:
			_alert_label.visible = false

		# Subtle yellow border
		var yellow_color: Color = Color(1.0, 0.8, 0.2, 0.25)
		if _border_top:
			_border_top.color = yellow_color
		if _border_bottom:
			_border_bottom.color = yellow_color
		if _border_left:
			_border_left.color = yellow_color
		if _border_right:
			_border_right.color = yellow_color

	else:  # GREEN (normal)
		# Hide everything
		if _alert_label:
			_alert_label.visible = false

		var clear_color: Color = Color(1.0, 0.15, 0.1, 0.0)
		if _border_top:
			_border_top.color = clear_color
		if _border_bottom:
			_border_bottom.color = clear_color
		if _border_left:
			_border_left.color = clear_color
		if _border_right:
			_border_right.color = clear_color
