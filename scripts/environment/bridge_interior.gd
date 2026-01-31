extends Node3D
class_name BridgeInterior
## Highly detailed Enterprise-D bridge interior
## Based on the actual TNG set layout and proportions
##
## BRIDGE LAYOUT REFERENCE (Top-down view):
##
##                    [VIEWSCREEN]
##                         |
##            +-----------***-----------+
##           /   [OPS]         [CONN]    \
##          /      o             o        \
##         |                               |
##         |  [SCI]               [SCI]    |
##         |    o      RAMP        o       |
##         |         /      \              |
##         |        /        \             |
##         |   [X] [CAPTAIN] [R]           |
##         |        \        /             |
##         |         \      /              |
##         |    o    TACTICAL   o          |
##         |  [ENG]     o     [MISC]       |
##          \                             /
##           \    [TURBO]   [TURBO]      /
##            +-------------------------+
##
## Scale: 1 unit = 1 meter (real-world scale)
## Bridge diameter: ~12 meters
## Ceiling height: ~3 meters

@export_group("Visibility")
@export var visible_in_bridge_mode: bool = true

@export_group("Colors - TNG Palette")
@export var floor_color: Color = Color(0.35, 0.30, 0.25)  # Warm grey-brown carpet
@export var wall_color: Color = Color(0.45, 0.38, 0.32)   # Beige/tan walls
@export var ceiling_color: Color = Color(0.25, 0.22, 0.20) # Darker ceiling
@export var console_base_color: Color = Color(0.15, 0.12, 0.10)  # Dark console frames
@export var lcars_orange: Color = Color(1.0, 0.6, 0.2)
@export var lcars_blue: Color = Color(0.4, 0.7, 1.0)
@export var lcars_red: Color = Color(0.9, 0.2, 0.2)
@export var lcars_yellow: Color = Color(1.0, 0.85, 0.3)
@export var lcars_purple: Color = Color(0.7, 0.5, 0.9)
@export var viewscreen_color: Color = Color(0.02, 0.02, 0.05)  # Dark when off

# Bridge dimensions (meters) - based on actual TNG set
const BRIDGE_RADIUS: float = 6.0
const BRIDGE_HEIGHT: float = 3.0
const FLOOR_THICKNESS: float = 0.1
const WALL_THICKNESS: float = 0.15
const COMMAND_PLATFORM_HEIGHT: float = 0.4
const RAMP_LENGTH: float = 2.5

# Node references for dynamic control
var _viewscreen_mesh: MeshInstance3D
var _ambient_light: OmniLight3D
var _console_lights: Array[OmniLight3D] = []
var _lcars_panels: Array[MeshInstance3D] = []

func _ready() -> void:
	_build_bridge()

func _build_bridge() -> void:
	# Build in layers from bottom to top
	_create_floor_structure()
	_create_walls()
	_create_ceiling()
	_create_viewscreen()
	_create_command_area()
	_create_forward_stations()
	_create_rear_stations()
	_create_side_stations()
	_create_tactical_station()
	_create_turbolift_alcoves()
	_create_lighting()
	_create_railings()

# ============================================================================
# FLOOR STRUCTURE
# ============================================================================
func _create_floor_structure() -> void:
	# Main floor (lower level - forward stations)
	var lower_floor := _create_floor_section(
		Vector3(0, 0, -2),
		Vector3(BRIDGE_RADIUS * 2, FLOOR_THICKNESS, 5),
		"LowerFloor"
	)

	# Command platform (raised center area)
	var command_platform := _create_floor_section(
		Vector3(0, COMMAND_PLATFORM_HEIGHT, 1.5),
		Vector3(8, FLOOR_THICKNESS, 6),
		"CommandPlatform"
	)

	# Rear floor section
	var rear_floor := _create_floor_section(
		Vector3(0, 0, 4.5),
		Vector3(BRIDGE_RADIUS * 2, FLOOR_THICKNESS, 3),
		"RearFloor"
	)

	# Ramps connecting levels (left and right)
	_create_ramp(Vector3(-2, 0, -0.5), -1)  # Left ramp
	_create_ramp(Vector3(2, 0, -0.5), 1)    # Right ramp

func _create_floor_section(pos: Vector3, size: Vector3, section_name: String) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = section_name

	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = pos

	var mat := StandardMaterial3D.new()
	mat.albedo_color = floor_color
	mat.roughness = 0.9  # Carpet-like
	mesh_instance.material_override = mat

	add_child(mesh_instance)
	return mesh_instance

func _create_ramp(pos: Vector3, side: int) -> void:
	var ramp := MeshInstance3D.new()
	ramp.name = "Ramp_" + ("Left" if side < 0 else "Right")

	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.5, FLOOR_THICKNESS, RAMP_LENGTH)
	ramp.mesh = mesh

	# Angle the ramp
	ramp.position = pos + Vector3(0, COMMAND_PLATFORM_HEIGHT / 2, 0)
	ramp.rotation_degrees.x = -rad_to_deg(atan2(COMMAND_PLATFORM_HEIGHT, RAMP_LENGTH))

	var mat := StandardMaterial3D.new()
	mat.albedo_color = floor_color
	mat.roughness = 0.9
	ramp.material_override = mat

	add_child(ramp)

# ============================================================================
# WALLS - Curved bridge perimeter
# ============================================================================
func _create_walls() -> void:
	# Create curved wall segments around the bridge
	var segments: int = 24
	var wall_height: float = BRIDGE_HEIGHT

	for i in range(segments):
		var angle: float = (float(i) / segments) * TAU
		var next_angle: float = (float(i + 1) / segments) * TAU

		# Skip the viewscreen area (front ~60 degrees)
		if angle > deg_to_rad(330) or angle < deg_to_rad(30):
			continue

		# Skip turbolift door areas (rear)
		if angle > deg_to_rad(140) and angle < deg_to_rad(160):
			continue
		if angle > deg_to_rad(200) and angle < deg_to_rad(220):
			continue

		var x: float = cos(angle) * BRIDGE_RADIUS
		var z: float = sin(angle) * BRIDGE_RADIUS

		var wall_segment := MeshInstance3D.new()
		wall_segment.name = "WallSegment_" + str(i)

		var mesh := BoxMesh.new()
		mesh.size = Vector3(WALL_THICKNESS, wall_height, 1.6)
		wall_segment.mesh = mesh

		wall_segment.position = Vector3(x, wall_height / 2, z)
		wall_segment.rotation.y = -angle + PI/2

		var mat := StandardMaterial3D.new()
		mat.albedo_color = wall_color
		mat.roughness = 0.7
		wall_segment.material_override = mat

		add_child(wall_segment)

		# Add LCARS panel strips on walls
		if i % 3 == 0:
			_add_wall_lcars_panel(wall_segment, wall_height)

func _add_wall_lcars_panel(wall: MeshInstance3D, wall_height: float) -> void:
	var panel := MeshInstance3D.new()
	panel.name = "LCARS_WallPanel"

	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.02, 0.8, 1.2)
	panel.mesh = mesh
	panel.position = Vector3(WALL_THICKNESS/2 + 0.01, wall_height * 0.3, 0)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = lcars_orange
	mat.emission_enabled = true
	mat.emission = lcars_orange
	mat.emission_energy_multiplier = 0.5
	panel.material_override = mat

	wall.add_child(panel)
	_lcars_panels.append(panel)

# ============================================================================
# CEILING
# ============================================================================
func _create_ceiling() -> void:
	# Main ceiling dome (simplified as flat with raised center)
	var ceiling := MeshInstance3D.new()
	ceiling.name = "Ceiling"

	var mesh := CylinderMesh.new()
	mesh.top_radius = BRIDGE_RADIUS - 0.5
	mesh.bottom_radius = BRIDGE_RADIUS
	mesh.height = 0.3
	ceiling.mesh = mesh
	ceiling.position = Vector3(0, BRIDGE_HEIGHT, 1)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = ceiling_color
	mat.roughness = 0.8
	ceiling.material_override = mat

	add_child(ceiling)

	# Ceiling light fixtures (characteristic TNG ring lights)
	_create_ceiling_lights()

func _create_ceiling_lights() -> void:
	# Central light ring
	var light_ring := MeshInstance3D.new()
	light_ring.name = "CeilingLightRing"

	var mesh := TorusMesh.new()
	mesh.inner_radius = 1.5
	mesh.outer_radius = 2.0
	light_ring.mesh = mesh
	light_ring.position = Vector3(0, BRIDGE_HEIGHT - 0.1, 1)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.95, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(1, 0.95, 0.9)
	mat.emission_energy_multiplier = 2.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	light_ring.material_override = mat

	add_child(light_ring)

# ============================================================================
# VIEWSCREEN - Main forward display
# ============================================================================
func _create_viewscreen() -> void:
	# Viewscreen frame
	var frame := MeshInstance3D.new()
	frame.name = "ViewscreenFrame"

	var frame_mesh := BoxMesh.new()
	frame_mesh.size = Vector3(7, 3.5, 0.3)
	frame.mesh = frame_mesh
	frame.position = Vector3(0, 1.75, -BRIDGE_RADIUS + 0.15)

	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = console_base_color
	frame.material_override = frame_mat

	add_child(frame)

	# Viewscreen display surface
	_viewscreen_mesh = MeshInstance3D.new()
	_viewscreen_mesh.name = "ViewscreenDisplay"

	var screen_mesh := BoxMesh.new()
	screen_mesh.size = Vector3(6.5, 3.0, 0.05)
	_viewscreen_mesh.mesh = screen_mesh
	_viewscreen_mesh.position = Vector3(0, 1.75, -BRIDGE_RADIUS + 0.35)

	var screen_mat := StandardMaterial3D.new()
	screen_mat.albedo_color = viewscreen_color
	screen_mat.emission_enabled = true
	screen_mat.emission = Color(0.1, 0.15, 0.3)
	screen_mat.emission_energy_multiplier = 0.3
	_viewscreen_mesh.material_override = screen_mat

	add_child(_viewscreen_mesh)

	# Viewscreen side panels (LCARS)
	_create_viewscreen_side_panel(Vector3(-3.8, 1.5, -BRIDGE_RADIUS + 0.4), true)
	_create_viewscreen_side_panel(Vector3(3.8, 1.5, -BRIDGE_RADIUS + 0.4), false)

func _create_viewscreen_side_panel(pos: Vector3, is_left: bool) -> void:
	var panel := MeshInstance3D.new()
	panel.name = "ViewscreenPanel_" + ("Left" if is_left else "Right")

	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.6, 2.5, 0.1)
	panel.mesh = mesh
	panel.position = pos

	var mat := StandardMaterial3D.new()
	mat.albedo_color = lcars_blue
	mat.emission_enabled = true
	mat.emission = lcars_blue
	mat.emission_energy_multiplier = 0.8
	panel.material_override = mat

	add_child(panel)
	_lcars_panels.append(panel)

# ============================================================================
# COMMAND AREA - Captain's chair and flanking seats
# ============================================================================
func _create_command_area() -> void:
	# Captain's chair (center)
	_create_command_chair(Vector3(0, COMMAND_PLATFORM_HEIGHT, 1.5), "CaptainChair", true)

	# Counselor's chair (left of captain)
	_create_command_chair(Vector3(-1.8, COMMAND_PLATFORM_HEIGHT, 1.5), "CounselorChair", false)

	# First Officer's chair (right of captain)
	_create_command_chair(Vector3(1.8, COMMAND_PLATFORM_HEIGHT, 1.5), "FirstOfficerChair", false)

	# Command console between chairs
	_create_command_console(Vector3(-0.9, COMMAND_PLATFORM_HEIGHT, 1.5), "LeftConsole")
	_create_command_console(Vector3(0.9, COMMAND_PLATFORM_HEIGHT, 1.5), "RightConsole")

func _create_command_chair(pos: Vector3, chair_name: String, is_captain: bool) -> void:
	var chair := Node3D.new()
	chair.name = chair_name
	chair.position = pos
	add_child(chair)

	# Chair base
	var base := MeshInstance3D.new()
	base.name = "Base"
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.25
	base_mesh.bottom_radius = 0.35
	base_mesh.height = 0.3
	base.mesh = base_mesh
	base.position = Vector3(0, 0.15, 0)

	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = console_base_color
	base.material_override = base_mat
	chair.add_child(base)

	# Chair seat
	var seat := MeshInstance3D.new()
	seat.name = "Seat"
	var seat_mesh := BoxMesh.new()
	var seat_width: float = 0.7 if is_captain else 0.6
	seat_mesh.size = Vector3(seat_width, 0.15, 0.5)
	seat.mesh = seat_mesh
	seat.position = Vector3(0, 0.45, 0)

	var seat_mat := StandardMaterial3D.new()
	seat_mat.albedo_color = Color(0.3, 0.25, 0.22)  # Dark leather brown
	seat_mat.roughness = 0.6
	seat.material_override = seat_mat
	chair.add_child(seat)

	# Chair back
	var back := MeshInstance3D.new()
	back.name = "Back"
	var back_mesh := BoxMesh.new()
	back_mesh.size = Vector3(seat_width, 0.7, 0.1)
	back.mesh = back_mesh
	back.position = Vector3(0, 0.85, 0.2)
	back.material_override = seat_mat
	chair.add_child(back)

	# Armrests with controls (captain only has full armrest consoles)
	if is_captain:
		_create_armrest_console(chair, Vector3(-0.45, 0.55, 0), true)
		_create_armrest_console(chair, Vector3(0.45, 0.55, 0), false)

func _create_armrest_console(parent: Node3D, pos: Vector3, is_left: bool) -> void:
	var armrest := MeshInstance3D.new()
	armrest.name = "Armrest_" + ("Left" if is_left else "Right")

	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.15, 0.08, 0.35)
	armrest.mesh = mesh
	armrest.position = pos

	var mat := StandardMaterial3D.new()
	mat.albedo_color = console_base_color
	armrest.material_override = mat
	parent.add_child(armrest)

	# LCARS buttons on armrest
	var buttons := MeshInstance3D.new()
	buttons.name = "Buttons"
	var btn_mesh := BoxMesh.new()
	btn_mesh.size = Vector3(0.12, 0.02, 0.25)
	buttons.mesh = btn_mesh
	buttons.position = Vector3(0, 0.05, 0)

	var btn_mat := StandardMaterial3D.new()
	btn_mat.albedo_color = lcars_orange
	btn_mat.emission_enabled = true
	btn_mat.emission = lcars_orange
	btn_mat.emission_energy_multiplier = 0.6
	buttons.material_override = btn_mat
	armrest.add_child(buttons)

func _create_command_console(pos: Vector3, console_name: String) -> void:
	var console := MeshInstance3D.new()
	console.name = console_name

	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.5, 0.6, 0.3)
	console.mesh = mesh
	console.position = pos + Vector3(0, 0.3, 0.3)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = console_base_color
	console.material_override = mat

	add_child(console)

	# Console screen
	var screen := MeshInstance3D.new()
	screen.name = "Screen"
	var screen_mesh := BoxMesh.new()
	screen_mesh.size = Vector3(0.4, 0.35, 0.02)
	screen.mesh = screen_mesh
	screen.position = Vector3(0, 0.15, -0.15)
	screen.rotation_degrees.x = -30

	var screen_mat := StandardMaterial3D.new()
	screen_mat.albedo_color = lcars_blue
	screen_mat.emission_enabled = true
	screen_mat.emission = lcars_blue
	screen_mat.emission_energy_multiplier = 0.5
	screen.material_override = screen_mat

	console.add_child(screen)
	_lcars_panels.append(screen)

# ============================================================================
# FORWARD STATIONS - Ops (Data) and Conn (Helm)
# ============================================================================
func _create_forward_stations() -> void:
	# Operations station (left forward - Data's station)
	_create_forward_console(Vector3(-1.2, 0, -3.5), "OpsStation", lcars_yellow)

	# Conn/Helm station (right forward)
	_create_forward_console(Vector3(1.2, 0, -3.5), "ConnStation", lcars_orange)

	# Shared forward console arc
	_create_forward_console_arc()

func _create_forward_console(pos: Vector3, station_name: String, accent_color: Color) -> void:
	var station := Node3D.new()
	station.name = station_name
	station.position = pos
	add_child(station)

	# Console base
	var base := MeshInstance3D.new()
	base.name = "ConsoleBase"
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(1.8, 0.8, 0.8)
	base.mesh = base_mesh
	base.position = Vector3(0, 0.4, 0)

	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = console_base_color
	base.material_override = base_mat
	station.add_child(base)

	# Angled display surface
	var display := MeshInstance3D.new()
	display.name = "Display"
	var disp_mesh := BoxMesh.new()
	disp_mesh.size = Vector3(1.6, 0.5, 0.05)
	display.mesh = disp_mesh
	display.position = Vector3(0, 0.9, -0.2)
	display.rotation_degrees.x = -45

	var disp_mat := StandardMaterial3D.new()
	disp_mat.albedo_color = accent_color
	disp_mat.emission_enabled = true
	disp_mat.emission = accent_color
	disp_mat.emission_energy_multiplier = 0.7
	display.material_override = disp_mat
	station.add_child(display)
	_lcars_panels.append(display)

	# Chair for this station
	_create_station_chair(station, Vector3(0, 0, 0.8))

	# Console light
	var light := OmniLight3D.new()
	light.name = "ConsoleLight"
	light.light_color = accent_color
	light.light_energy = 0.5
	light.omni_range = 2.0
	light.position = Vector3(0, 1.2, 0)
	station.add_child(light)
	_console_lights.append(light)

func _create_forward_console_arc() -> void:
	# The curved console that spans between Ops and Conn
	var arc := MeshInstance3D.new()
	arc.name = "ForwardConsoleArc"

	var mesh := BoxMesh.new()
	mesh.size = Vector3(4.5, 0.6, 0.4)
	arc.mesh = mesh
	arc.position = Vector3(0, 0.3, -4.2)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = console_base_color
	arc.material_override = mat

	add_child(arc)

	# LCARS strip on arc
	var strip := MeshInstance3D.new()
	strip.name = "LCARSStrip"
	var strip_mesh := BoxMesh.new()
	strip_mesh.size = Vector3(4.0, 0.15, 0.02)
	strip.mesh = strip_mesh
	strip.position = Vector3(0, 0.2, -0.21)

	var strip_mat := StandardMaterial3D.new()
	strip_mat.albedo_color = lcars_purple
	strip_mat.emission_enabled = true
	strip_mat.emission = lcars_purple
	strip_mat.emission_energy_multiplier = 0.5
	strip.material_override = strip_mat
	arc.add_child(strip)
	_lcars_panels.append(strip)

func _create_station_chair(parent: Node3D, pos: Vector3) -> void:
	var chair := MeshInstance3D.new()
	chair.name = "StationChair"

	# Simple chair representation
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.5, 0.8, 0.5)
	chair.mesh = mesh
	chair.position = pos + Vector3(0, 0.4, 0)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.22, 0.2)
	chair.material_override = mat

	parent.add_child(chair)

# ============================================================================
# REAR STATIONS - Science, Engineering, Environment along back wall
# ============================================================================
func _create_rear_stations() -> void:
	# Science Station 1 (rear left)
	_create_rear_console(Vector3(-4, 0, 4), "ScienceStation1", lcars_blue, -30)

	# Science Station 2 (rear right)
	_create_rear_console(Vector3(4, 0, 4), "ScienceStation2", lcars_blue, 30)

	# Engineering station (rear center-left)
	_create_rear_console(Vector3(-2.5, 0, 5), "EngineeringStation", lcars_red, 0)

	# Environment station (rear center-right)
	_create_rear_console(Vector3(2.5, 0, 5), "EnvironmentStation", lcars_yellow, 0)

func _create_rear_console(pos: Vector3, station_name: String, accent_color: Color, angle_y: float) -> void:
	var station := Node3D.new()
	station.name = station_name
	station.position = pos
	station.rotation_degrees.y = angle_y
	add_child(station)

	# Standing console (taller, no chair)
	var console := MeshInstance3D.new()
	console.name = "Console"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.2, 1.8, 0.4)
	console.mesh = mesh
	console.position = Vector3(0, 0.9, 0)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = console_base_color
	console.material_override = mat
	station.add_child(console)

	# Main display
	var display := MeshInstance3D.new()
	display.name = "Display"
	var disp_mesh := BoxMesh.new()
	disp_mesh.size = Vector3(1.0, 1.2, 0.05)
	display.mesh = disp_mesh
	display.position = Vector3(0, 0.3, -0.23)

	var disp_mat := StandardMaterial3D.new()
	disp_mat.albedo_color = accent_color
	disp_mat.emission_enabled = true
	disp_mat.emission = accent_color
	disp_mat.emission_energy_multiplier = 0.6
	display.material_override = disp_mat
	console.add_child(display)
	_lcars_panels.append(display)

	# Small light
	var light := OmniLight3D.new()
	light.light_color = accent_color
	light.light_energy = 0.3
	light.omni_range = 1.5
	light.position = Vector3(0, 2, 0)
	station.add_child(light)
	_console_lights.append(light)

# ============================================================================
# SIDE STATIONS - Along curved walls
# ============================================================================
func _create_side_stations() -> void:
	# Left side stations
	_create_side_console(Vector3(-5.2, COMMAND_PLATFORM_HEIGHT, 0), "LeftStation1", lcars_orange, 90)
	_create_side_console(Vector3(-5.2, COMMAND_PLATFORM_HEIGHT, 2), "LeftStation2", lcars_blue, 90)

	# Right side stations
	_create_side_console(Vector3(5.2, COMMAND_PLATFORM_HEIGHT, 0), "RightStation1", lcars_orange, -90)
	_create_side_console(Vector3(5.2, COMMAND_PLATFORM_HEIGHT, 2), "RightStation2", lcars_blue, -90)

func _create_side_console(pos: Vector3, station_name: String, accent_color: Color, angle_y: float) -> void:
	var station := Node3D.new()
	station.name = station_name
	station.position = pos
	station.rotation_degrees.y = angle_y
	add_child(station)

	# Wall-mounted console
	var console := MeshInstance3D.new()
	console.name = "Console"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.0, 1.0, 0.25)
	console.mesh = mesh
	console.position = Vector3(0, 0.8, 0)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = console_base_color
	console.material_override = mat
	station.add_child(console)

	# Display
	var display := MeshInstance3D.new()
	display.name = "Display"
	var disp_mesh := BoxMesh.new()
	disp_mesh.size = Vector3(0.8, 0.6, 0.02)
	display.mesh = disp_mesh
	display.position = Vector3(0, 0.2, -0.14)

	var disp_mat := StandardMaterial3D.new()
	disp_mat.albedo_color = accent_color
	disp_mat.emission_enabled = true
	disp_mat.emission = accent_color
	disp_mat.emission_energy_multiplier = 0.5
	display.material_override = disp_mat
	console.add_child(display)
	_lcars_panels.append(display)

# ============================================================================
# TACTICAL STATION - Behind captain (Worf's station)
# ============================================================================
func _create_tactical_station() -> void:
	var tactical := Node3D.new()
	tactical.name = "TacticalStation"
	tactical.position = Vector3(0, COMMAND_PLATFORM_HEIGHT, 3.5)
	add_child(tactical)

	# Horseshoe-shaped tactical console
	var console_left := MeshInstance3D.new()
	console_left.name = "ConsoleLeft"
	var mesh_l := BoxMesh.new()
	mesh_l.size = Vector3(0.8, 1.0, 0.4)
	console_left.mesh = mesh_l
	console_left.position = Vector3(-0.8, 0.5, 0)
	console_left.rotation_degrees.y = 20

	var mat := StandardMaterial3D.new()
	mat.albedo_color = console_base_color
	console_left.material_override = mat
	tactical.add_child(console_left)

	var console_right := MeshInstance3D.new()
	console_right.name = "ConsoleRight"
	var mesh_r := BoxMesh.new()
	mesh_r.size = Vector3(0.8, 1.0, 0.4)
	console_right.mesh = mesh_r
	console_right.position = Vector3(0.8, 0.5, 0)
	console_right.rotation_degrees.y = -20
	console_right.material_override = mat
	tactical.add_child(console_right)

	var console_center := MeshInstance3D.new()
	console_center.name = "ConsoleCenter"
	var mesh_c := BoxMesh.new()
	mesh_c.size = Vector3(1.2, 1.0, 0.4)
	console_center.mesh = mesh_c
	console_center.position = Vector3(0, 0.5, 0.3)
	console_center.material_override = mat
	tactical.add_child(console_center)

	# Tactical displays (red/orange for weapons)
	_add_tactical_display(console_left, lcars_red)
	_add_tactical_display(console_right, lcars_red)
	_add_tactical_display(console_center, lcars_orange)

	# Overhead tactical display
	var overhead := MeshInstance3D.new()
	overhead.name = "OverheadDisplay"
	var oh_mesh := BoxMesh.new()
	oh_mesh.size = Vector3(2.0, 0.8, 0.1)
	overhead.mesh = oh_mesh
	overhead.position = Vector3(0, 2.2, 0.2)
	overhead.rotation_degrees.x = 30

	var oh_mat := StandardMaterial3D.new()
	oh_mat.albedo_color = lcars_red
	oh_mat.emission_enabled = true
	oh_mat.emission = lcars_red
	oh_mat.emission_energy_multiplier = 0.4
	overhead.material_override = oh_mat
	tactical.add_child(overhead)
	_lcars_panels.append(overhead)

	# Tactical station light
	var light := OmniLight3D.new()
	light.light_color = lcars_red
	light.light_energy = 0.4
	light.omni_range = 2.5
	light.position = Vector3(0, 1.5, 0)
	tactical.add_child(light)
	_console_lights.append(light)

func _add_tactical_display(console: MeshInstance3D, color: Color) -> void:
	var display := MeshInstance3D.new()
	display.name = "Display"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.6, 0.5, 0.02)
	display.mesh = mesh
	display.position = Vector3(0, 0.3, -0.22)
	display.rotation_degrees.x = -20

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.6
	display.material_override = mat
	console.add_child(display)
	_lcars_panels.append(display)

# ============================================================================
# TURBOLIFT ALCOVES - Rear entrances
# ============================================================================
func _create_turbolift_alcoves() -> void:
	_create_turbolift(Vector3(-3.5, 0, 5.5), "TurboliftLeft", 25)
	_create_turbolift(Vector3(3.5, 0, 5.5), "TurboliftRight", -25)

func _create_turbolift(pos: Vector3, lift_name: String, angle_y: float) -> void:
	var turbolift := Node3D.new()
	turbolift.name = lift_name
	turbolift.position = pos
	turbolift.rotation_degrees.y = angle_y
	add_child(turbolift)

	# Door frame
	var frame := MeshInstance3D.new()
	frame.name = "DoorFrame"
	var frame_mesh := BoxMesh.new()
	frame_mesh.size = Vector3(1.4, 2.4, 0.2)
	frame.mesh = frame_mesh
	frame.position = Vector3(0, 1.2, 0)

	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = wall_color * 0.8
	frame.material_override = frame_mat
	turbolift.add_child(frame)

	# Door (closed)
	var door := MeshInstance3D.new()
	door.name = "Door"
	var door_mesh := BoxMesh.new()
	door_mesh.size = Vector3(1.2, 2.2, 0.05)
	door.mesh = door_mesh
	door.position = Vector3(0, 1.1, -0.1)

	var door_mat := StandardMaterial3D.new()
	door_mat.albedo_color = Color(0.3, 0.28, 0.26)
	door_mat.metallic = 0.3
	door.material_override = door_mat
	turbolift.add_child(door)

	# Door indicator light
	var indicator := MeshInstance3D.new()
	indicator.name = "Indicator"
	var ind_mesh := BoxMesh.new()
	ind_mesh.size = Vector3(0.3, 0.08, 0.02)
	indicator.mesh = ind_mesh
	indicator.position = Vector3(0, 2.35, -0.12)

	var ind_mat := StandardMaterial3D.new()
	ind_mat.albedo_color = lcars_blue
	ind_mat.emission_enabled = true
	ind_mat.emission = lcars_blue
	ind_mat.emission_energy_multiplier = 1.0
	indicator.material_override = ind_mat
	turbolift.add_child(indicator)

# ============================================================================
# LIGHTING SYSTEM
# ============================================================================
func _create_lighting() -> void:
	# Main ambient light
	_ambient_light = OmniLight3D.new()
	_ambient_light.name = "AmbientLight"
	_ambient_light.light_color = Color(1.0, 0.95, 0.9)  # Warm white
	_ambient_light.light_energy = 1.5
	_ambient_light.omni_range = 15.0
	_ambient_light.position = Vector3(0, 2.5, 1)
	add_child(_ambient_light)

	# Forward area light
	var forward_light := OmniLight3D.new()
	forward_light.name = "ForwardLight"
	forward_light.light_color = Color(0.9, 0.95, 1.0)  # Slightly cool
	forward_light.light_energy = 0.8
	forward_light.omni_range = 8.0
	forward_light.position = Vector3(0, 2.5, -3)
	add_child(forward_light)

	# Viewscreen ambient glow
	var screen_light := OmniLight3D.new()
	screen_light.name = "ViewscreenLight"
	screen_light.light_color = Color(0.5, 0.6, 0.8)
	screen_light.light_energy = 0.5
	screen_light.omni_range = 5.0
	screen_light.position = Vector3(0, 1.5, -5)
	add_child(screen_light)

# ============================================================================
# RAILINGS - Safety rails around command area
# ============================================================================
func _create_railings() -> void:
	# Command area front railing (separating from lower level)
	_create_railing_segment(Vector3(-3, COMMAND_PLATFORM_HEIGHT, -0.5), Vector3(3, COMMAND_PLATFORM_HEIGHT, -0.5))

	# Side railings
	_create_railing_segment(Vector3(-3.5, COMMAND_PLATFORM_HEIGHT, -0.3), Vector3(-3.5, COMMAND_PLATFORM_HEIGHT, 3))
	_create_railing_segment(Vector3(3.5, COMMAND_PLATFORM_HEIGHT, -0.3), Vector3(3.5, COMMAND_PLATFORM_HEIGHT, 3))

func _create_railing_segment(start: Vector3, end: Vector3) -> void:
	var railing := Node3D.new()
	railing.name = "Railing"
	add_child(railing)

	var dir: Vector3 = end - start
	var length: float = dir.length()
	var center: Vector3 = (start + end) / 2

	# Horizontal bar
	var bar := MeshInstance3D.new()
	bar.name = "Bar"
	var bar_mesh := CylinderMesh.new()
	bar_mesh.top_radius = 0.03
	bar_mesh.bottom_radius = 0.03
	bar_mesh.height = length
	bar.mesh = bar_mesh
	bar.position = center + Vector3(0, 0.9, 0)
	bar.rotation.z = PI / 2
	bar.rotation.y = atan2(dir.x, dir.z)

	var bar_mat := StandardMaterial3D.new()
	bar_mat.albedo_color = Color(0.5, 0.45, 0.4)
	bar_mat.metallic = 0.6
	bar.material_override = bar_mat
	railing.add_child(bar)

	# Vertical posts
	var num_posts: int = int(length / 1.5) + 1
	for i in range(num_posts):
		var t: float = float(i) / max(num_posts - 1, 1)
		var post_pos: Vector3 = start.lerp(end, t)

		var post := MeshInstance3D.new()
		post.name = "Post_" + str(i)
		var post_mesh := CylinderMesh.new()
		post_mesh.top_radius = 0.025
		post_mesh.bottom_radius = 0.025
		post_mesh.height = 0.9
		post.mesh = post_mesh
		post.position = post_pos + Vector3(0, 0.45, 0)
		post.material_override = bar_mat
		railing.add_child(post)

# ============================================================================
# PUBLIC API - For external control
# ============================================================================

## Set bridge visibility (called by camera manager)
func set_bridge_visible(is_visible: bool) -> void:
	visible = is_visible

## Set alert status (changes lighting color)
func set_alert_status(alert: String) -> void:
	match alert:
		"red":
			_set_ambient_color(Color(1.0, 0.2, 0.2), 0.8)
			_pulse_lcars_panels(lcars_red)
		"yellow":
			_set_ambient_color(Color(1.0, 0.8, 0.2), 1.0)
			_pulse_lcars_panels(lcars_yellow)
		"normal":
			_set_ambient_color(Color(1.0, 0.95, 0.9), 1.5)

func _set_ambient_color(color: Color, energy: float) -> void:
	if _ambient_light:
		_ambient_light.light_color = color
		_ambient_light.light_energy = energy

func _pulse_lcars_panels(color: Color) -> void:
	for panel in _lcars_panels:
		if panel and is_instance_valid(panel):
			var mat: StandardMaterial3D = panel.material_override
			if mat:
				mat.emission = color

## Get the viewscreen position for rendering space view
func get_viewscreen_position() -> Vector3:
	if _viewscreen_mesh:
		return _viewscreen_mesh.global_position
	return global_position + Vector3(0, 1.75, -BRIDGE_RADIUS)

## Get ideal camera position for bridge view
func get_bridge_camera_position() -> Vector3:
	# Position behind captain's chair, slightly elevated
	return global_position + Vector3(0, COMMAND_PLATFORM_HEIGHT + 1.6, 2.5)

## Get camera look target for bridge view
func get_bridge_look_target() -> Vector3:
	# Look at viewscreen
	return global_position + Vector3(0, 1.5, -BRIDGE_RADIUS)

## Flash the viewscreen for warp engage/disengage effect (bridge camera mode only)
## intensity: 0.0 to 1.0 (maps to emission strength)
## color: Flash color (default blue-white)
func flash_viewscreen(intensity: float = 0.8, color: Color = Color(0.7, 0.85, 1.0)) -> void:
	if not _viewscreen_mesh:
		return

	# Store original material properties
	var mat: StandardMaterial3D = _viewscreen_mesh.material_override
	if not mat:
		return

	var original_emission: Color = mat.emission
	var original_energy: float = mat.emission_energy_multiplier

	# Create flash effect
	var flash_emission: Color = color
	var flash_energy: float = 5.0 * intensity

	# Apply flash
	mat.emission = flash_emission
	mat.emission_energy_multiplier = flash_energy

	# Animate back to original
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(mat, "emission", original_emission, 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "emission_energy_multiplier", original_energy, 0.3).set_ease(Tween.EASE_OUT)
