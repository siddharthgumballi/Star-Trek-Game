extends Node3D
class_name ShipAudio
## Audio system for Enterprise-D: engine sounds, ambient, warp effects
## Warp engage/exit sounds play ONCE - no looping

const AUDIO_PATH := "res://assets/audio/"

@export_group("References")
@export var ship_controller_path: NodePath
@export var warp_drive_path: NodePath

# Resolved references
var ship_controller: ShipController
var warp_drive: WarpDrive

@export_group("Volume (dB)")
@export var master_volume: float = 0.0
@export var ambient_volume: float = -8.0
@export var engine_volume: float = -12.0
@export var warp_volume: float = -5.0

# Audio players
var _ambient_player: AudioStreamPlayer
var _engine_player: AudioStreamPlayer3D
var _warp_engage_player: AudioStreamPlayer
var _warp_exit_player: AudioStreamPlayer

# Audio streams
var _ambient_stream: AudioStream
var _engine_stream: AudioStream
var _warp_engage_stream: AudioStream
var _warp_exit_stream: AudioStream

# State tracking
var _is_at_warp: bool = false

func _ready() -> void:
	if ship_controller_path:
		ship_controller = get_node_or_null(ship_controller_path) as ShipController
	if warp_drive_path:
		warp_drive = get_node_or_null(warp_drive_path) as WarpDrive

	_load_audio_files()
	_setup_audio_players()
	_connect_warp_signals()

func _connect_warp_signals() -> void:
	if warp_drive:
		# Connect to charging_started for engage sound (plays during animation)
		if warp_drive.has_signal("warp_charging_started"):
			if not warp_drive.warp_charging_started.is_connected(_on_warp_charging_started):
				warp_drive.warp_charging_started.connect(_on_warp_charging_started)
		# Connect to disengaged for exit sound
		if not warp_drive.warp_disengaged.is_connected(_on_warp_disengaged):
			warp_drive.warp_disengaged.connect(_on_warp_disengaged)
		print("ShipAudio: Connected to WarpDrive signals")

func _on_warp_charging_started(_warp_factor: float) -> void:
	# Play warp engage sound when charging begins (not when warp actually starts)
	if _is_at_warp:
		return
	_is_at_warp = true

	# Play warp engage sound ONCE
	if _warp_engage_stream and _warp_engage_player:
		_warp_engage_player.stop()  # Stop any previous play
		_warp_engage_player.play()
		print("ShipAudio: Playing warp engage sound (once)")

func _on_warp_disengaged() -> void:
	# Only play if we were at warp
	if not _is_at_warp:
		return
	_is_at_warp = false

	# Play warp exit sound ONCE
	if _warp_exit_stream and _warp_exit_player:
		_warp_exit_player.stop()  # Stop any previous play
		_warp_exit_player.play()
		print("ShipAudio: Playing warp exit sound (once)")

func _load_audio_files() -> void:
	var bridge_path := AUDIO_PATH + "tng_bridge.mp3"
	var engine_path := AUDIO_PATH + "tng_engine.mp3"
	var warp_engage_path := AUDIO_PATH + "tng_warp_engage.mp3"
	var warp_exit_path := AUDIO_PATH + "tng_warp_exit.mp3"

	if ResourceLoader.exists(bridge_path):
		_ambient_stream = load(bridge_path)
		print("ShipAudio: Loaded bridge ambient")

	if ResourceLoader.exists(engine_path):
		_engine_stream = load(engine_path)
		print("ShipAudio: Loaded engine sound")

	if ResourceLoader.exists(warp_engage_path):
		_warp_engage_stream = load(warp_engage_path)
		print("ShipAudio: Loaded warp engage sound")
	else:
		push_warning("Warp engage audio not found: " + warp_engage_path)

	if ResourceLoader.exists(warp_exit_path):
		_warp_exit_stream = load(warp_exit_path)
		print("ShipAudio: Loaded warp exit sound")
	else:
		push_warning("Warp exit audio not found: " + warp_exit_path)

func _setup_audio_players() -> void:
	# Ambient bridge sound
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.bus = "Master"
	_ambient_player.volume_db = ambient_volume + master_volume
	if _ambient_stream:
		_ambient_player.stream = _ambient_stream
	add_child(_ambient_player)

	# Engine sound (3D positional)
	_engine_player = AudioStreamPlayer3D.new()
	_engine_player.bus = "Master"
	_engine_player.volume_db = engine_volume + master_volume
	_engine_player.max_distance = 2000.0
	_engine_player.unit_size = 100.0
	if _engine_stream:
		_engine_player.stream = _engine_stream
	add_child(_engine_player)

	# Warp engage sound (ONE-SHOT, not looping)
	_warp_engage_player = AudioStreamPlayer.new()
	_warp_engage_player.bus = "Master"
	_warp_engage_player.volume_db = warp_volume + master_volume + 3.0
	if _warp_engage_stream:
		_warp_engage_stream.loop = false  # Ensure no loop
		_warp_engage_player.stream = _warp_engage_stream
	add_child(_warp_engage_player)

	# Warp exit sound (ONE-SHOT, not looping)
	_warp_exit_player = AudioStreamPlayer.new()
	_warp_exit_player.bus = "Master"
	_warp_exit_player.volume_db = warp_volume + master_volume + 3.0
	if _warp_exit_stream:
		_warp_exit_stream.loop = false  # Ensure no loop
		_warp_exit_player.stream = _warp_exit_stream
	add_child(_warp_exit_player)

	# Start ambient and engine (these loop)
	if _ambient_stream:
		_ambient_player.play()
	if _engine_stream:
		_engine_player.play()

func _process(_delta: float) -> void:
	# Keep ambient and engine looping
	if _ambient_stream and not _ambient_player.playing:
		_ambient_player.play()

	if _engine_stream and not _engine_player.playing:
		_engine_player.play()

	# Adjust engine volume based on state
	if ship_controller and _engine_player:
		var target_db: float = engine_volume + master_volume

		if warp_drive and warp_drive.is_at_warp:
			# Fade out engine during warp
			target_db = -40.0
		elif ship_controller.has_method("get_impulse_fraction"):
			var impulse_fraction: float = ship_controller.get_impulse_fraction()
			if impulse_fraction > 0:
				target_db += impulse_fraction * 6.0
			else:
				target_db -= 6.0

		_engine_player.volume_db = lerpf(_engine_player.volume_db, target_db, 0.1)
