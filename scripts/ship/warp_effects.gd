extends Node3D
class_name WarpEffects
## Visual effects coordinator for TNG-style warp animation
## Listens to WarpDrive signals and orchestrates nacelle glow, ship stretch, and flash effects
## Timing synchronized with TNG warp audio (~6.5s engage, ~7s disengage)

signal warp_effect_started()
signal warp_effect_finished()

@export_group("References")
@export var warp_drive_path: NodePath
@export var ship_model_loader_path: NodePath
@export var camera_manager_path: NodePath
@export var flash_overlay_path: NodePath

# Resolved references
var warp_drive: WarpDrive
var ship_model_loader: ShipModelLoader
var camera_manager: CameraManager
var flash_overlay: Node  # WarpFlashOverlay

@export_group("Timing - Engage (synced with 3.5s warp charge)")
@export var engage_nacelle_warmup: float = 1.0      # Nacelles start glowing
@export var engage_warp_field_buildup: float = 1.5  # Warp field forms around ship
@export var engage_stretch_buildup: float = 0.7     # Ship begins stretching
@export var engage_flash_and_jump: float = 0.3      # Rapid stretch + flash (at ~3.5s)
@export var engage_settle: float = 3.0              # Continue after warp engaged

@export_group("Timing - Disengage (7s total)")
@export var disengage_flash: float = 0.5            # Exit flash (immediate)
@export var disengage_settle: float = 6.5           # Return to normal after flash

@export_group("Stretch Settings")
@export var max_stretch: float = 0.5                # Maximum forward stretch
@export var compression_amount: float = 0.03        # Slight compression before stretch

@export_group("Nacelle Glow")
@export var nacelle_glow_color: Color = Color(0.4, 0.6, 1.0)  # Blue warp glow
@export var nacelle_idle_emission: float = 0.5
@export var nacelle_warp_emission: float = 4.0

@export_group("Warp Field")
@export var warp_field_color: Color = Color(0.5, 0.7, 1.0, 0.15)
@export var flash_color: Color = Color(0.8, 0.9, 1.0, 1.0)

# Internal state
var _warp_shader: ShaderMaterial
var _main_tween: Tween
var _nacelle_tween: Tween
var _is_animating: bool = false
var _nacelle_meshes: Array[MeshInstance3D] = []
var _ship_model: Node3D

# Nacelle light nodes (created dynamically)
var _nacelle_lights: Array[OmniLight3D] = []

func _ready() -> void:
	await get_tree().process_frame
	_resolve_references()
	_setup_shader()
	# Wait for ship model to load
	await get_tree().create_timer(0.5).timeout
	_find_nacelles()

func _resolve_references() -> void:
	if warp_drive_path:
		warp_drive = get_node_or_null(warp_drive_path) as WarpDrive
	if not warp_drive:
		warp_drive = get_parent().get_node_or_null("WarpDrive") as WarpDrive

	if ship_model_loader_path:
		ship_model_loader = get_node_or_null(ship_model_loader_path) as ShipModelLoader
	if not ship_model_loader:
		ship_model_loader = get_parent().get_node_or_null("ModelLoader") as ShipModelLoader

	if camera_manager_path:
		camera_manager = get_node_or_null(camera_manager_path) as CameraManager
	if not camera_manager:
		var sector = get_parent().get_parent()
		if sector:
			camera_manager = sector.get_node_or_null("CameraManager") as CameraManager

	if flash_overlay_path:
		flash_overlay = get_node_or_null(flash_overlay_path)
	if not flash_overlay:
		var sector = get_parent().get_parent()
		if sector:
			flash_overlay = sector.get_node_or_null("WarpFlashOverlay")

	if warp_drive:
		# Connect to charging_started for animation (plays during charge phase)
		if warp_drive.has_signal("warp_charging_started"):
			warp_drive.warp_charging_started.connect(_on_warp_charging_started)
		warp_drive.warp_disengaged.connect(_on_warp_disengaged)
		print("WarpEffects: Connected to WarpDrive signals")

func _setup_shader() -> void:
	var shader = load("res://shaders/warp_stretch.gdshader")
	if shader:
		_warp_shader = ShaderMaterial.new()
		_warp_shader.shader = shader
		_warp_shader.set_shader_parameter("stretch_amount", 0.0)
		_warp_shader.set_shader_parameter("glow_color", warp_field_color)
		_warp_shader.set_shader_parameter("glow_intensity", 0.0)

func _find_nacelles() -> void:
	# Find the ship model and locate nacelle meshes
	if not ship_model_loader:
		return

	_ship_model = ship_model_loader.get_model()
	if not _ship_model:
		return

	_nacelle_meshes.clear()
	_nacelle_lights.clear()

	# Search for meshes with "nacelle" in the name (case-insensitive)
	_find_nacelle_meshes_recursive(_ship_model)

	# If no nacelles found by name, try to find glowing/emissive parts
	if _nacelle_meshes.is_empty():
		_find_emissive_meshes_recursive(_ship_model)

	# Create dynamic lights at nacelle positions
	for nacelle in _nacelle_meshes:
		var light := OmniLight3D.new()
		light.light_color = nacelle_glow_color
		light.light_energy = 0.0
		light.omni_range = 30.0
		light.omni_attenuation = 1.5
		nacelle.add_child(light)
		_nacelle_lights.append(light)

	print("WarpEffects: Found ", _nacelle_meshes.size(), " nacelle meshes")

func _find_nacelle_meshes_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_name: String = node.name.to_lower()
		# Be strict - only match "nacelle" specifically, not general terms
		# This prevents matching the entire ship
		if "nacelle" in mesh_name:
			_nacelle_meshes.append(node)
			# Note: We don't modify materials anymore - just use lights

	for child in node.get_children():
		_find_nacelle_meshes_recursive(child)

func _find_emissive_meshes_recursive(node: Node) -> void:
	# Only look for emissive meshes if no nacelles were found by name
	# Be very conservative - only match if the mesh name suggests it's a light/glow
	if node is MeshInstance3D:
		var mesh_name: String = node.name.to_lower()
		# Only match obvious glow/light meshes, not the whole ship
		if "glow" in mesh_name or "light" in mesh_name or "bussard" in mesh_name:
			_nacelle_meshes.append(node)
			# Note: We don't modify materials anymore - just use lights

	for child in node.get_children():
		_find_emissive_meshes_recursive(child)

func _on_warp_charging_started(warp_factor: float) -> void:
	if _is_animating:
		_cancel_animation()
	_play_engage_sequence(warp_factor)

func _on_warp_disengaged() -> void:
	if _is_animating:
		_cancel_animation()
	_play_disengage_sequence()

func _cancel_animation() -> void:
	if _main_tween and _main_tween.is_valid():
		_main_tween.kill()
	if _nacelle_tween and _nacelle_tween.is_valid():
		_nacelle_tween.kill()
	_is_animating = false
	_reset_effects()

func _reset_effects() -> void:
	# Reset stretch shader parameters
	if _warp_shader:
		_warp_shader.set_shader_parameter("stretch_amount", 0.0)
		_warp_shader.set_shader_parameter("glow_intensity", 0.0)

	# Remove shader overlay from ship
	if ship_model_loader:
		ship_model_loader.remove_warp_shader()

	# Reset all nacelle effects
	_reset_nacelle_materials()

# =============================================================================
# TNG WARP ENGAGE SEQUENCE (~6.5 seconds)
# =============================================================================
# Phase 1 (0-2s):    Nacelles power up, blue glow intensifies
# Phase 2 (2-4s):    Warp field forms around ship, nacelles at full glow
# Phase 3 (4-5.5s):  Ship begins stretching forward, tension builds
# Phase 4 (5.5-6s):  Rapid stretch to max, bright flash at peak
# Phase 5 (6-6.5s):  Ship snaps back to normal, now at warp
# =============================================================================

func _play_engage_sequence(_warp_factor: float) -> void:
	_is_animating = true
	emit_signal("warp_effect_started")

	var is_bridge: bool = _is_bridge_mode()

	# Apply warp shader to ship (only in external views)
	if not is_bridge and ship_model_loader and _warp_shader:
		ship_model_loader.apply_warp_shader(_warp_shader)

	# Main animation tween
	_main_tween = create_tween()
	_main_tween.set_parallel(false)

	# Store timing markers
	var t1 := engage_nacelle_warmup        # 2.0s
	var t2 := engage_warp_field_buildup    # 2.0s
	var t3 := engage_stretch_buildup       # 1.5s
	var t4 := engage_flash_and_jump        # 0.5s
	var t5 := engage_settle                # 0.5s

	# === PHASE 1: Nacelle Warmup (0s - 2s) ===
	_main_tween.tween_callback(_start_nacelle_powerup)
	_main_tween.tween_method(_set_nacelle_glow, 0.0, 0.5, t1)

	# === PHASE 2: Warp Field Buildup (2s - 4s) ===
	_main_tween.tween_callback(func(): _start_warp_field_glow(is_bridge))
	_main_tween.tween_method(_set_nacelle_glow, 0.5, 1.0, t2)

	# === PHASE 3: Stretch Buildup (4s - 5.5s) ===
	# Slight compression then gradual stretch
	_main_tween.tween_method(_set_stretch, 0.0, -compression_amount, t3 * 0.2)
	_main_tween.tween_method(_set_stretch, -compression_amount, max_stretch * 0.3, t3 * 0.8)

	# === PHASE 4: Flash and Jump (5.5s - 6s) ===
	# Rapid stretch to maximum
	_main_tween.tween_method(_set_stretch, max_stretch * 0.3, max_stretch, t4 * 0.6)
	# Flash at peak
	_main_tween.tween_callback(func(): _trigger_flash(0.9, is_bridge))
	# Quick snap back
	_main_tween.tween_method(_set_stretch, max_stretch, 0.0, t4 * 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# === PHASE 5: Settle into Warp (6s - 6.5s) ===
	_main_tween.tween_callback(_settle_into_warp)
	_main_tween.tween_interval(t5)

	# Cleanup
	_main_tween.tween_callback(_on_engage_complete)

	print("WarpEffects: Playing TNG engage sequence (6.5s)")

func _start_nacelle_powerup() -> void:
	print("WarpEffects: Nacelles powering up...")
	# Nacelles start glowing - handled by _set_nacelle_glow

func _start_warp_field_glow(is_bridge: bool) -> void:
	print("WarpEffects: Warp field forming...")
	if is_bridge:
		return

	# Gradually increase warp field glow around ship
	if _warp_shader:
		var glow_tween := create_tween()
		glow_tween.tween_method(
			func(v): _warp_shader.set_shader_parameter("glow_intensity", v),
			0.0, 0.3, engage_warp_field_buildup
		)

func _settle_into_warp() -> void:
	print("WarpEffects: Entering warp...")
	# Fade warp field glow slightly (ship is now at warp)
	if _warp_shader:
		var fade_tween := create_tween()
		fade_tween.tween_method(
			func(v): _warp_shader.set_shader_parameter("glow_intensity", v),
			0.3, 0.0, engage_settle
		)

# =============================================================================
# TNG WARP DISENGAGE SEQUENCE (~7 seconds)
# =============================================================================
# Phase 1 (0-3s):    Warp field destabilizing, nacelles flickering
# Phase 2 (3-3.5s):  Exit flash, ship compresses briefly
# Phase 3 (3.5-7s):  Return to normal, nacelles power down
# =============================================================================

func _play_disengage_sequence() -> void:
	_is_animating = true
	emit_signal("warp_effect_started")

	var is_bridge: bool = _is_bridge_mode()

	if not is_bridge and ship_model_loader and _warp_shader:
		ship_model_loader.apply_warp_shader(_warp_shader)

	_main_tween = create_tween()
	_main_tween.set_parallel(false)

	var t1 := disengage_flash         # 0.5s
	var t2 := disengage_settle        # 6.5s

	# === IMMEDIATE FLASH ===
	_main_tween.tween_callback(func(): print("WarpEffects: Dropping out of warp..."))
	# Flash immediately
	_main_tween.tween_callback(func(): _trigger_flash(0.7, is_bridge))
	# Brief compression effect
	_main_tween.tween_method(_set_stretch, 0.0, -compression_amount * 2, t1 * 0.4)
	_main_tween.tween_method(_set_stretch, -compression_amount * 2, 0.0, t1 * 0.6).set_ease(Tween.EASE_OUT)

	# === SETTLE (after flash) ===
	# Nacelles power down gradually
	_main_tween.tween_method(_set_nacelle_glow, 0.5, 0.0, t2)

	# Cleanup
	_main_tween.tween_callback(_on_disengage_complete)

	print("WarpEffects: Playing TNG disengage sequence")

# =============================================================================
# EFFECT HELPERS
# =============================================================================

func _set_stretch(amount: float) -> void:
	if _warp_shader:
		_warp_shader.set_shader_parameter("stretch_amount", amount)

func _set_nacelle_glow(intensity: float) -> void:
	# Set nacelle light intensity ONLY - don't modify materials to avoid corruption
	for light in _nacelle_lights:
		if is_instance_valid(light):
			light.light_energy = intensity * nacelle_warp_emission

func _set_nacelle_glow_with_flicker(intensity: float) -> void:
	# Add some random flicker during warp exit
	var flicker := 1.0 + randf_range(-0.1, 0.1)
	_set_nacelle_glow(intensity * flicker)

func _trigger_flash(intensity: float, is_bridge: bool) -> void:
	if is_bridge:
		var bridge = _find_bridge_interior()
		if bridge and bridge.has_method("flash_viewscreen"):
			bridge.flash_viewscreen(intensity, flash_color)
	else:
		if flash_overlay and flash_overlay.has_method("flash"):
			flash_overlay.flash(intensity, flash_color)

func _find_bridge_interior() -> BridgeInterior:
	if camera_manager and camera_manager.bridge_interior:
		return camera_manager.bridge_interior
	var sector = get_parent().get_parent()
	if sector:
		return sector.get_node_or_null("BridgeInterior") as BridgeInterior
	return null

func _is_bridge_mode() -> bool:
	if camera_manager and camera_manager.has_method("is_bridge_mode"):
		return camera_manager.is_bridge_mode()
	elif camera_manager:
		return camera_manager.current_mode == CameraManager.CameraMode.BRIDGE
	return false

func _on_engage_complete() -> void:
	_is_animating = false
	if ship_model_loader:
		ship_model_loader.remove_warp_shader()
	# Reset nacelle glow to normal (don't keep ship glowing blue)
	_reset_nacelle_materials()
	emit_signal("warp_effect_finished")
	print("WarpEffects: Engage sequence complete - now at warp")

func _on_disengage_complete() -> void:
	_is_animating = false
	if ship_model_loader:
		ship_model_loader.remove_warp_shader()
	# Reset nacelle materials to original
	_reset_nacelle_materials()
	emit_signal("warp_effect_finished")
	print("WarpEffects: Disengage sequence complete - back to impulse")

func _reset_nacelle_materials() -> void:
	# Reset nacelle lights - we don't modify materials so no need to restore them
	for light in _nacelle_lights:
		if is_instance_valid(light):
			light.light_energy = 0.0
