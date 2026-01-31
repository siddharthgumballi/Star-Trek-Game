extends CanvasLayer
class_name WarpFlashOverlay
## Full-screen flash overlay for warp engage/disengage effects
## Positioned at layer 100 (above HUD) for maximum visibility

@export var default_flash_color: Color = Color(0.7, 0.85, 1.0, 1.0)
@export var flash_duration: float = 0.6  # Longer flash for TNG effect

var _color_rect: ColorRect
var _flash_tween: Tween

func _ready() -> void:
	# Set layer above HUD
	layer = 100

	# Create the color rect for flash effect
	_color_rect = ColorRect.new()
	_color_rect.name = "FlashRect"
	_color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_color_rect.color = Color(default_flash_color.r, default_flash_color.g, default_flash_color.b, 0.0)
	add_child(_color_rect)

## Trigger a flash effect
## intensity: 0.0 to 1.0 (maps to alpha)
## color: Optional override color
func flash(intensity: float = 0.8, color: Color = Color.WHITE) -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()

	# Use provided color or default
	var flash_col: Color = color if color != Color.WHITE else default_flash_color

	# Set initial flash color with full intensity
	_color_rect.color = Color(flash_col.r, flash_col.g, flash_col.b, intensity)

	# Animate fade out
	_flash_tween = create_tween()
	_flash_tween.tween_property(_color_rect, "color:a", 0.0, flash_duration).set_ease(Tween.EASE_OUT)

## Quick flash for engage (brighter, faster)
func flash_engage() -> void:
	flash(0.8, default_flash_color)

## Quick flash for disengage (dimmer)
func flash_disengage() -> void:
	flash(0.6, default_flash_color)

## Set the flash color without triggering a flash
func set_flash_color(color: Color) -> void:
	default_flash_color = color
