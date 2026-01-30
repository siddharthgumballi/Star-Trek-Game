extends Node3D
class_name ShipAudio
## Audio system for Enterprise-D: engine sounds, ambient, warp effects
## Uses authentic TNG sound effects from TrekCore

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
var _ambient_player: AudioStreamPlayer  # Bridge ambient (always playing)
var _engine_player: AudioStreamPlayer3D  # Engine sound (impulse)
var _warp_player: AudioStreamPlayer  # Warp sound

# Audio streams
var _ambient_stream: AudioStream
var _engine_stream: AudioStream
var _warp_stream: AudioStream

# State tracking
var _is_at_warp: bool = false
var _warp_sound_playing: bool = false

func _ready() -> void:
	# Resolve node paths
	if ship_controller_path:
		ship_controller = get_node_or_null(ship_controller_path) as ShipController
	if warp_drive_path:
		warp_drive = get_node_or_null(warp_drive_path) as WarpDrive

	_load_audio_files()
	_setup_audio_players()

func _load_audio_files() -> void:
	# Load TNG audio files
	var bridge_path := AUDIO_PATH + "tng_bridge.mp3"
	var engine_path := AUDIO_PATH + "tng_engine.mp3"
	var warp_path := AUDIO_PATH + "tng_warp.mp3"

	if ResourceLoader.exists(bridge_path):
		_ambient_stream = load(bridge_path)
		print("  Loaded bridge ambient: ", bridge_path)
	else:
		push_warning("Bridge ambient audio not found: " + bridge_path)

	if ResourceLoader.exists(engine_path):
		_engine_stream = load(engine_path)
		print("  Loaded engine sound: ", engine_path)
	else:
		push_warning("Engine audio not found: " + engine_path)

	if ResourceLoader.exists(warp_path):
		_warp_stream = load(warp_path)
		print("  Loaded warp sound: ", warp_path)
	else:
		push_warning("Warp audio not found: " + warp_path)

func _setup_audio_players() -> void:
	# Ambient bridge sound (non-positional, always plays)
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

	# Warp sound (non-positional)
	_warp_player = AudioStreamPlayer.new()
	_warp_player.bus = "Master"
	_warp_player.volume_db = warp_volume + master_volume
	if _warp_stream:
		_warp_player.stream = _warp_stream
	add_child(_warp_player)

	# Start ambient immediately (looping)
	if _ambient_stream:
		_ambient_player.play()

	# Start engine sound (looping)
	if _engine_stream:
		_engine_player.play()

func _process(_delta: float) -> void:
	_update_audio_state()
	_ensure_loops()

func _update_audio_state() -> void:
	# Check warp state
	var currently_at_warp: bool = false
	if warp_drive:
		currently_at_warp = warp_drive.is_at_warp

	# Handle warp transitions
	if currently_at_warp and not _is_at_warp:
		# Entering warp
		_on_enter_warp()
	elif not currently_at_warp and _is_at_warp:
		# Exiting warp
		_on_exit_warp()

	_is_at_warp = currently_at_warp

	# Adjust engine volume based on impulse
	if ship_controller and _engine_player:
		var impulse_fraction: float = ship_controller.get_impulse_fraction()
		# Fade engine based on impulse level
		var target_db: float = engine_volume + master_volume
		if impulse_fraction > 0:
			target_db += impulse_fraction * 6.0  # Louder at higher impulse
		else:
			target_db -= 6.0  # Quieter when stopped

		# At warp, fade out engine sound
		if _is_at_warp:
			target_db = -40.0

		_engine_player.volume_db = lerpf(_engine_player.volume_db, target_db, 0.1)

func _on_enter_warp() -> void:
	if _warp_stream and not _warp_sound_playing:
		_warp_player.play()
		_warp_sound_playing = true

func _on_exit_warp() -> void:
	_warp_sound_playing = false
	# Let warp sound finish naturally or stop it
	# _warp_player.stop()

func _ensure_loops() -> void:
	# Ensure ambient and engine keep looping
	if _ambient_stream and not _ambient_player.playing:
		_ambient_player.play()

	if _engine_stream and not _engine_player.playing and not _is_at_warp:
		_engine_player.play()

	# Loop warp sound while at warp
	if _is_at_warp and _warp_stream and not _warp_player.playing:
		_warp_player.play()

# Called when entering/exiting warp (can be connected to signal)
func play_warp_sound(entering: bool) -> void:
	if entering:
		_on_enter_warp()
	else:
		_on_exit_warp()
