extends CanvasLayer
class_name DebugOverlay
## Development debug display for starship systems
## Phase 3: Expanded to show all system states
## Toggle with F6

@export var starship_core_path: NodePath
@export var ship_path: NodePath
@export var warp_drive_path: NodePath

var _starship_core: Node = null
var _ship: Node3D = null
var _warp_drive: Node3D = null

var _visible: bool = false
var _panel: PanelContainer
var _label: RichTextLabel

# Update rate
var _update_timer: float = 0.0
const UPDATE_INTERVAL: float = 0.1  # 10 updates per second

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	layer = 100  # Above most UI
	_setup_input()
	_resolve_references()
	_create_ui()
	_panel.visible = _visible

func _setup_input() -> void:
	if not InputMap.has_action("toggle_debug"):
		InputMap.add_action("toggle_debug")
		var event := InputEventKey.new()
		event.physical_keycode = KEY_F6
		InputMap.action_add_event("toggle_debug", event)

func _resolve_references() -> void:
	if starship_core_path:
		_starship_core = get_node_or_null(starship_core_path)
	if ship_path:
		_ship = get_node_or_null(ship_path)
	if warp_drive_path:
		_warp_drive = get_node_or_null(warp_drive_path)

	# Fallback: search scene tree
	if not _starship_core:
		_starship_core = _find_node_by_class("StarshipCore")
	if not _ship:
		_ship = _find_node_by_class("ShipController")
	if not _warp_drive:
		_warp_drive = _find_node_by_class("WarpDrive")

func _find_node_by_class(class_name_str: String) -> Node:
	var root: Node = get_tree().current_scene
	return _find_recursive(root, class_name_str)

func _find_recursive(node: Node, class_name_str: String) -> Node:
	var script: Script = node.get_script()
	if script and script.get_global_name() == class_name_str:
		return node
	for child in node.get_children():
		var result: Node = _find_recursive(child, class_name_str)
		if result:
			return result
	return null

# =============================================================================
# UI CREATION
# =============================================================================

func _create_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "DebugPanel"

	# Style the panel
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.85)
	style.border_color = Color(0.2, 0.6, 1.0, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", style)

	# Position in top-left
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.position = Vector2(10, 10)
	_panel.custom_minimum_size = Vector2(380, 520)

	# Create label for content
	_label = RichTextLabel.new()
	_label.name = "DebugLabel"
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.custom_minimum_size = Vector2(360, 500)

	# Monospace font
	_label.add_theme_font_size_override("normal_font_size", 11)
	_label.add_theme_font_size_override("bold_font_size", 11)
	_label.add_theme_color_override("default_color", Color(0.8, 0.9, 1.0))

	_panel.add_child(_label)
	add_child(_panel)

# =============================================================================
# INPUT HANDLING
# =============================================================================

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		_visible = not _visible
		_panel.visible = _visible
		print("[DEBUG] Overlay %s" % ("visible" if _visible else "hidden"))

# =============================================================================
# UPDATE
# =============================================================================

func _process(delta: float) -> void:
	if not _visible:
		return

	_update_timer += delta
	if _update_timer >= UPDATE_INTERVAL:
		_update_timer = 0.0
		_update_display()

func _update_display() -> void:
	var text: String = ""

	# Header
	text += "[b][color=#4af]STARSHIP DEBUG (F6)[/color][/b]\n"
	text += "[color=#444]" + "─".repeat(38) + "[/color]\n"

	# ==========================================================================
	# ALERT STATUS
	# ==========================================================================
	text += _section("ALERT STATUS")
	if _starship_core:
		var alert: int = _starship_core.get_alert_state()
		var alert_name: String = _starship_core.get_alert_name()
		var alert_color: String = _get_alert_color(alert)
		text += "[color=%s]● %s ALERT[/color]\n" % [alert_color, alert_name.to_upper()]
	else:
		text += "[color=#666]Core not found[/color]\n"

	# ==========================================================================
	# WARP STATE
	# ==========================================================================
	text += _section("WARP STATE")
	if _warp_drive:
		if _warp_drive.is_at_warp:
			text += "[color=#0ff]AT WARP %.1f[/color]\n" % _warp_drive.current_warp_factor
		elif _warp_drive.is_charging_warp:
			text += "[color=#ff0]CHARGING... (%.1fs)[/color]\n" % _warp_drive._charge_timer
		else:
			text += "Impulse Mode\n"
	if _ship:
		if _ship.has_method("get_impulse_name"):
			text += "Speed: %s\n" % _ship.get_impulse_name()
		text += "Velocity: %.1f u/s\n" % _ship.linear_velocity.length()

	# ==========================================================================
	# POWER DISTRIBUTION
	# ==========================================================================
	text += _section("POWER DISTRIBUTION")
	if _starship_core:
		var power: Dictionary = _starship_core.get_power_distribution()
		text += _power_bar("ENG", power.get("engines", 0))
		text += _power_bar("SHD", power.get("shields", 0))
		text += _power_bar("WPN", power.get("weapons", 0))
		text += _power_bar("SEN", power.get("sensors", 0))
	else:
		text += "[color=#666]N/A[/color]\n"

	# ==========================================================================
	# TACTICAL STATUS
	# ==========================================================================
	text += _section("TACTICAL")
	var tactical: SubsystemBase = _get_subsystem("tactical")
	if tactical:
		var status: Dictionary = tactical.get_status()

		# Shields
		var shield_pct: float = status.get("shield_percent", 100.0)
		var shield_color: String = _get_health_color(shield_pct)
		var shield_state: String = "RAISED" if status.get("shields_raised", false) else "DOWN"
		if status.get("shields_transitioning", false):
			shield_state = "TRANSITIONING"
		text += "Shields: [color=%s]%s %.0f%%[/color]\n" % [shield_color, shield_state, shield_pct]
		text += _progress_bar("Shield", shield_pct, 100.0, shield_color)

		# Target
		var target: String = status.get("current_target", "")
		var lock_pct: float = status.get("target_lock_progress", 0.0)
		if status.get("target_lock", false):
			text += "Target: [color=#0f0]LOCKED[/color] %s\n" % target
		elif not status.get("locking_target", "").is_empty():
			text += "Target: [color=#ff0]LOCKING %.0f%%[/color]\n" % lock_pct
			text += _progress_bar("Lock", lock_pct, 100.0, "#ff0")
		else:
			text += "Target: None\n"

		# Weapons
		var phaser_cd: float = status.get("phaser_cooldown", 0.0)
		var phaser_max: float = status.get("phaser_cooldown_max", 2.0)
		var torpedo_cd: float = status.get("torpedo_cooldown", 0.0)
		var torpedo_max: float = status.get("torpedo_cooldown_max", 5.0)

		if phaser_cd > 0:
			text += "Phasers: [color=#f80]%.1fs[/color]\n" % phaser_cd
			text += _cooldown_bar("Phaser", phaser_cd, phaser_max)
		else:
			text += "Phasers: [color=#0f0]READY[/color]\n"

		if torpedo_cd > 0:
			text += "Torpedoes: [color=#f80]%.1fs[/color] (%d)\n" % [torpedo_cd, status.get("torpedo_count", 0)]
			text += _cooldown_bar("Torpedo", torpedo_cd, torpedo_max)
		else:
			text += "Torpedoes: [color=#0f0]READY[/color] (%d)\n" % status.get("torpedo_count", 0)
	else:
		text += "[color=#666]Offline[/color]\n"

	# ==========================================================================
	# ENGINEERING
	# ==========================================================================
	text += _section("ENGINEERING")
	var engineering: SubsystemBase = _get_subsystem("engineering")
	if engineering:
		var status: Dictionary = engineering.get_status()
		text += "Warp Core: %s\n" % status.get("warp_core_status", "Unknown")

		# Power transitioning indicator
		if status.get("power_transitioning", false):
			text += "[color=#ff0]Power transitioning...[/color]\n"

		# Damaged systems
		var health: Dictionary = status.get("system_health", {})
		var damaged: Array = []
		for sys in health:
			if health[sys] < 100.0:
				damaged.append("%s: %.0f%%" % [sys.substr(0, 4), health[sys]])
		if damaged.is_empty():
			text += "[color=#0f0]All systems nominal[/color]\n"
		else:
			for d in damaged:
				text += "[color=#f80]%s[/color]\n" % d
	else:
		text += "[color=#666]Offline[/color]\n"

	# ==========================================================================
	# SENSORS
	# ==========================================================================
	text += _section("SENSORS")
	var ops: SubsystemBase = _get_subsystem("ops")
	if ops:
		var status: Dictionary = ops.get_status()
		text += "Range: %.0f km\n" % status.get("sensor_range_km", 0)
		text += "Resolution: %.1fx\n" % status.get("sensor_resolution", 1.0)
		if status.get("scanning", false):
			text += "[color=#0ff]Scanning: %s (%.0f%%)[/color]\n" % [
				status.get("current_scan_target", ""),
				status.get("scan_progress", 0)
			]
	else:
		text += "[color=#666]Offline[/color]\n"

	# ==========================================================================
	# POSITION
	# ==========================================================================
	text += _section("POSITION")
	if _ship:
		var pos: Vector3 = _ship.global_position
		text += "X: %12.0f\n" % pos.x
		text += "Y: %12.0f\n" % pos.y
		text += "Z: %12.0f\n" % pos.z

	_label.text = text

# =============================================================================
# HELPERS
# =============================================================================

func _section(title: String) -> String:
	return "\n[color=#888]%s[/color]\n" % title

func _get_alert_color(level: int) -> String:
	match level:
		0: return "#0f0"  # GREEN
		1: return "#ff0"  # YELLOW
		2: return "#f00"  # RED
		_: return "#fff"

func _get_health_color(percent: float) -> String:
	if percent >= 75.0:
		return "#0f0"
	elif percent >= 50.0:
		return "#ff0"
	elif percent >= 25.0:
		return "#f80"
	else:
		return "#f00"

func _power_bar(label: String, value: float) -> String:
	var bar_len: int = 15
	var filled: int = int((value / 100.0) * bar_len)
	var empty: int = bar_len - filled

	var color: String = "#8cf"
	if value >= 40.0:
		color = "#0f0"
	elif value <= 15.0:
		color = "#f80"

	var bar: String = "[color=%s]%s[/color][color=#444]%s[/color]" % [
		color,
		"█".repeat(filled),
		"░".repeat(empty)
	]
	return "[color=#8cf]%s:[/color] %s %5.1f%%\n" % [label, bar, value]

func _progress_bar(label: String, value: float, max_val: float, color: String) -> String:
	var bar_len: int = 20
	var percent: float = clampf(value / max_val, 0.0, 1.0)
	var filled: int = int(percent * bar_len)
	var empty: int = bar_len - filled

	return "[color=%s]%s[/color][color=#333]%s[/color]\n" % [
		color,
		"▓".repeat(filled),
		"░".repeat(empty)
	]

func _cooldown_bar(label: String, remaining: float, max_val: float) -> String:
	var bar_len: int = 20
	var percent: float = clampf(remaining / max_val, 0.0, 1.0)
	var filled: int = int(percent * bar_len)
	var empty: int = bar_len - filled

	# Cooldown shows remaining time, so filled = not ready
	return "[color=#f80]%s[/color][color=#0f0]%s[/color]\n" % [
		"▓".repeat(filled),
		"░".repeat(empty)
	]

func _get_subsystem(name: String) -> SubsystemBase:
	if _starship_core and _starship_core.has_method("get_subsystem"):
		return _starship_core.get_subsystem(name)
	return null
