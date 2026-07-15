## Handles all audio playback including music, SFX, and ambience.
##
## AudioManager manages audio buses, provides volume and mute controls,
## supports music crossfading, SFX pooling for performance, and 3D positional
## audio for in-world sounds. It exposes a clean API for other systems to
## trigger audio without managing AudioStreamPlayer lifecycle.
extends Node

# =============================================================================
# Constants
# =============================================================================

## Audio bus indices matching the project's Audio bus layout.
const BUS_MASTER: int = 0
const BUS_MUSIC: int = 1
const BUS_SFX: int = 2
const BUS_AMBIENCE: int = 3

## Default volume in linear (1.0 = 0 dB).
const DEFAULT_VOLUME: float = 1.0

## Crossfade duration in seconds for music transitions.
const CROSSFADE_DURATION: float = 1.5

## Maximum number of pooled SFX players.
const MAX_SFX_POOL_SIZE: int = 32

## Maximum number of pooled 3D SFX players.
const MAX_3D_SFX_POOL_SIZE: int = 16

## Fade duration for music start/stop.
const MUSIC_FADE_DURATION: float = 0.5

# =============================================================================
# Signals
# =============================================================================

## Emitted when a music track begins playing.
signal music_started(track_name: String)

## Emitted when music is paused.
signal music_paused

## Emitted when music resumes.
signal music_resumed

## Emitted when music is stopped.
signal music_stopped

## Emitted when a SFX is played.
signal sfx_played(sfx_name: String)

## Emitted when volume changes on a bus.
signal volume_changed(bus_name: String, linear_volume: float)

## Emitted when a bus is muted or unmuted.
signal bus_muted(bus_name: String, is_muted: bool)

# =============================================================================
# Properties
# =============================================================================

## Two AudioStreamPlayers for crossfading music (A/B pattern).
var _music_player_a: AudioStreamPlayer = AudioStreamPlayer.new()
var _music_player_b: AudioStreamPlayer = AudioStreamPlayer.new()

## Reference to whichever music player is currently active.
var _active_music_player: AudioStreamPlayer = _music_player_a

## The name of the currently playing music track.
var _current_music_track: String = ""

## Queue of track names to play after the current one finishes.
var _music_queue: Array[String] = []

## Whether music is currently paused.
var _music_paused: bool = false

## Volume cache per bus name (linear).
var _bus_volumes: Dictionary = {
	"Master": DEFAULT_VOLUME,
	"Music": DEFAULT_VOLUME,
	"SFX": DEFAULT_VOLUME,
	"Ambience": DEFAULT_VOLUME,
}

## Mute state per bus name.
var _bus_muted: Dictionary = {
	"Master": false,
	"Music": false,
	"SFX": false,
	"Ambience": false,
}

## Pool of reusable AudioStreamPlayers for 2D SFX.
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_pool_index: int = 0

## Pool of reusable AudioStreamPlayer3D for 3D SFX.
var _3d_sfx_pool: Array[AudioStreamPlayer3D] = []
var _3d_sfx_pool_index: int = 0

## Cache of loaded AudioStreams to avoid repeated disk reads.
var _stream_cache: Dictionary = {}

## Active 2D SFX players (currently playing, not in pool).
var _active_sfx: Array[AudioStreamPlayer] = []

## Active 3D SFX players.
var _active_3d_sfx: Array[AudioStreamPlayer3D] = []

# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses_exist()
	_initialize_music_players()
	_initialize_sfx_pool()
	_initialize_3d_sfx_pool()
	_apply_all_volumes()

# =============================================================================
# Bus Setup
# =============================================================================

## Ensure all required audio buses exist. If they don't, the game falls back
## to whatever buses are defined in the project. This is a safety net.
func _ensure_buses_exist() -> void:
	var required_buses: Array[String] = ["Master", "Music", "SFX", "Ambience"]
	for bus_name: String in required_buses:
		var idx: int = AudioServer.get_bus_index(bus_name)
		if idx == -1:
			AudioServer.add_bus(AudioServer.bus_count)
			var new_index: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(new_index, bus_name)
			AudioServer.set_bus_send(new_index, "Master")

# =============================================================================
# Music Player Initialization
# =============================================================================

## Set up the two music AudioStreamPlayers used for crossfading.
func _initialize_music_players() -> void:
	for player: AudioStreamPlayer in [_music_player_a, _music_player_b]:
		add_child(player)
		player.bus = "Music"
		player.volume_db = 0.0
		_music_player_b.playing = false
		_music_player_a.playing = false

# =============================================================================
# SFX Pool Initialization
# =============================================================================

## Create the pool of reusable AudioStreamPlayers for 2D sound effects.
func _initialize_sfx_pool() -> void:
	for i in range(MAX_SFX_POOL_SIZE):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		player.finished.connect(_on_sfx_player_finished.bind(player))
		_sfx_pool.append(player)


## Create the pool of reusable AudioStreamPlayer3D for positional sound effects.
func _initialize_3d_sfx_pool() -> void:
	for i in range(MAX_3D_SFX_POOL_SIZE):
		var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		player.bus = "SFX"
		add_child(player)
		player.finished.connect(_on_3d_sfx_player_finished.bind(player))
		_3d_sfx_pool.append(player)

# =============================================================================
# Music Control
# =============================================================================

## Play a music track, optionally crossfading from the current track.
## [param track_path: String] Resource path to the AudioStream.
## [param track_name: String] A human-readable name for the track.
## [param crossfade: bool] Whether to crossfade from the current track.
func play_music(track_path: String, track_name: String = "", crossfade: bool = true) -> void:
	if track_name.is_empty():
		track_name = track_path.get_file().get_basename()

	if _current_music_track == track_name and _active_music_player.playing:
		return  # Already playing this track.

	var stream: AudioStream = _load_stream(track_path)
	if stream == null:
		push_error("AudioManager: Failed to load music track '%s'." % track_path)
		return

	_current_music_track = track_name

	if crossfade and _active_music_player.playing:
		_crossfade_to(stream, track_name)
	else:
		_active_music_player.stream = stream
		_active_music_player.volume_db = 0.0
		_active_music_player.play()
		music_started.emit(track_name)


## Stop all music playback.
func stop_music() -> void:
	_music_player_a.stop()
	_music_player_b.stop()
	_current_music_track = ""
	_music_queue.clear()
	music_stopped.emit()


## Pause the currently playing music.
func pause_music() -> void:
	if _active_music_player.playing:
		_active_music_player.stream_paused = true
		_music_paused = true
		music_paused.emit()


## Resume paused music.
func resume_music() -> void:
	if _music_paused:
		_active_music_player.stream_paused = false
		_music_paused = false
		music_resumed.emit()


## Add a track to the music queue. Plays automatically after current track ends.
## [param track_path: String] Resource path to the AudioStream.
## [param track_name: String] A human-readable name.
func queue_music(track_path: String, track_name: String = "") -> void:
	if track_name.is_empty():
		track_name = track_path.get_file().get_basename()
	_music_queue.append(track_name)
	# Preload the stream so it's ready.
	_load_stream(track_path)


## Clear the music queue.
func clear_music_queue() -> void:
	_music_queue.clear()


## Get the name of the currently playing track.
func get_current_track() -> String:
	return _current_music_track


## Check if music is currently playing.
func is_music_playing() -> bool:
	return _active_music_player.playing and not _music_paused


## Crossfade from the active player to the other player with the new stream.
## [param new_stream: The AudioStream to play.
## [param track_name: String] Name of the new track.
func _crossfade_to(new_stream: AudioStream, track_name: String) -> void:
	var old_player: AudioStreamPlayer = _active_music_player
	var new_player: AudioStreamPlayer = _music_player_b if _active_music_player == _music_player_a else _music_player_a

	new_player.stream = new_stream
	new_player.volume_db = -40.0  # Start silent.
	new_player.play()

	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(old_player, "volume_db", -40.0, CROSSFADE_DURATION)
	tween.tween_property(new_player, "volume_db", 0.0, CROSSFADE_DURATION)
	tween.chain().tween_callback(old_player.stop)

	_active_music_player = new_player
	music_started.emit(track_name)

# =============================================================================
# SFX Control
# =============================================================================

## Play a 2D sound effect from the SFX pool.
## [param stream_path: String] Resource path to the AudioStream.
## [param volume_db: float] Volume adjustment in dB (0 = default).
## [param pitch: float] Pitch scale (1.0 = normal).
## [return] The AudioStreamPlayer that was assigned, or null on failure.
func play_sfx(stream_path: String, volume_db: float = 0.0, pitch: float = 1.0) -> AudioStreamPlayer:
	var stream: AudioStream = _load_stream(stream_path)
	if stream == null:
		push_error("AudioManager: Failed to load SFX '%s'." % stream_path)
		return null

	var player: AudioStreamPlayer = _get_available_sfx_player()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()
	_active_sfx.append(player)
	sfx_played.emit(stream_path.get_file().get_basename())
	return player


## Play a 3D positional sound effect at a world position.
## [param stream_path: String] Resource path to the AudioStream.
## [param world_position: Vector3] The position in 3D world space.
## [param volume_db: float] Volume adjustment in dB.
## [param pitch: float] Pitch scale.
## [return] The AudioStreamPlayer3D that was assigned, or null on failure.
func play_sfx_3d(stream_path: String, world_position: Vector3, volume_db: float = 0.0, pitch: float = 1.0) -> AudioStreamPlayer3D:
	var stream: AudioStream = _load_stream(stream_path)
	if stream == null:
		push_error("AudioManager: Failed to load 3D SFX '%s'." % stream_path)
		return null

	var player: AudioStreamPlayer3D = _get_available_3d_sfx_player()
	player.stream = stream
	player.global_position = world_position
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()
	_active_3d_sfx.append(player)
	sfx_played.emit(stream_path.get_file().get_basename())
	return player


## Play a 2D sound effect with random pitch variation for natural sounds.
## [param stream_path: String] Resource path to the AudioStream.
## [param min_pitch: float] Minimum pitch scale.
## [param max_pitch: float] Maximum pitch scale.
## [param volume_db: float] Volume adjustment in dB.
func play_sfx_varied(stream_path: String, min_pitch: float = 0.9, max_pitch: float = 1.1, volume_db: float = 0.0) -> void:
	var pitch: float = randf_range(min_pitch, max_pitch)
	play_sfx(stream_path, volume_db, pitch)

# =============================================================================
# SFX Pooling
# =============================================================================

## Get the next available AudioStreamPlayer from the pool.
## If all are busy, steals the oldest one.
func _get_available_sfx_player() -> AudioStreamPlayer:
	# Find an idle player.
	for i in range(MAX_SFX_POOL_SIZE):
		var idx: int = (_sfx_pool_index + i) % MAX_SFX_POOL_SIZE
		if not _sfx_pool[idx].playing:
			_sfx_pool_index = (idx + 1) % MAX_SFX_POOL_SIZE
			return _sfx_pool[idx]

	# All busy — steal the one at the current index (oldest in rotation).
	var stolen: AudioStreamPlayer = _sfx_pool[_sfx_pool_index]
	stolen.stop()
	_sfx_pool_index = (_sfx_pool_index + 1) % MAX_SFX_POOL_SIZE
	return stolen


## Get the next available AudioStreamPlayer3D from the pool.
func _get_available_3d_sfx_player() -> AudioStreamPlayer3D:
	for i in range(MAX_3D_SFX_POOL_SIZE):
		var idx: int = (_3d_sfx_pool_index + i) % MAX_3D_SFX_POOL_SIZE
		if not _3d_sfx_pool[idx].playing:
			_3d_sfx_pool_index = (idx + 1) % MAX_3D_SFX_POOL_SIZE
			return _3d_sfx_pool[idx]

	var stolen: AudioStreamPlayer3D = _3d_sfx_pool[_3d_sfx_pool_index]
	stolen.stop()
	_3d_sfx_pool_index = (_3d_sfx_pool_index + 1) % MAX_3D_SFX_POOL_SIZE
	return stolen


## Callback when a 2D SFX player finishes playing.
func _on_sfx_player_finished(player: AudioStreamPlayer) -> void:
	_active_sfx.erase(player)


## Callback when a 3D SFX player finishes playing.
func _on_3d_sfx_player_finished(player: AudioStreamPlayer3D) -> void:
	_active_3d_sfx.erase(player)

# =============================================================================
# Volume Control
# =============================================================================

## Set the volume for an audio bus.
## [param bus_name: String] "Master", "Music", "SFX", or "Ambience".
## [param linear: float] Volume in linear scale (0.0 to 1.0).
func set_volume(bus_name: String, linear: float) -> void:
	linear = clampf(linear, 0.0, 1.0)
	_bus_volumes[bus_name] = linear
	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	if bus_idx == -1:
		push_warning("AudioManager: Bus '%s' not found." % bus_name)
		return
	# Convert linear to dB: 0.0 linear = -80 dB, 1.0 linear = 0 dB.
	var db: float = linear_to_db(linear) if linear > 0.0 else -80.0
	AudioServer.set_bus_volume_db(bus_idx, db)
	volume_changed.emit(bus_name, linear)


## Get the current volume for an audio bus (linear).
## [param bus_name: String] The bus name.
## [return] Volume in linear scale.
func get_volume(bus_name: String) -> float:
	return _bus_volumes.get(bus_name, DEFAULT_VOLUME)


## Set whether an audio bus is muted.
## [param bus_name: String] The bus name.
## [param muted: bool] Whether to mute.
func set_muted(bus_name: String, muted: bool) -> void:
	_bus_muted[bus_name] = muted
	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	if bus_idx == -1:
		push_warning("AudioManager: Bus '%s' not found." % bus_name)
		return
	AudioServer.set_bus_mute(bus_idx, muted)
	bus_muted.emit(bus_name, muted)


## Toggle mute on a bus.
## [param bus_name: String] The bus name.
func toggle_mute(bus_name: String) -> void:
	var current: bool = _bus_muted.get(bus_name, false)
	set_muted(bus_name, not current)


## Check if a bus is muted.
## [param bus_name: String] The bus name.
func is_muted(bus_name: String) -> bool:
	return _bus_muted.get(bus_name, false)


## Apply all cached volumes and mute states to the AudioServer.
func _apply_all_volumes() -> void:
	for bus_name: String in _bus_volumes:
		set_volume(bus_name, _bus_volumes[bus_name])
	for bus_name: String in _bus_muted:
		if _bus_muted[bus_name]:
			set_muted(bus_name, true)

# =============================================================================
# Stream Loading & Caching
# =============================================================================

## Load an AudioStream from a resource path, using a cache to avoid re-loading.
## [param path: String] The res:// path to the AudioStream.
## [return] The AudioStream, or null if loading failed.
func _load_stream(path: String) -> AudioStream:
	if _stream_cache.has(path):
		return _stream_cache[path]

	if not ResourceLoader.exists(path):
		push_error("AudioManager: AudioStream not found at '%s'." % path)
		return null

	var stream: Resource = ResourceLoader.load(path)
	if stream is AudioStream:
		_stream_cache[path] = stream
		return stream as AudioStream

	push_error("AudioManager: Resource at '%s' is not an AudioStream." % path)
	return null

# =============================================================================
# Convenience Methods
# =============================================================================

## Play a UI button click sound.
func play_ui_click() -> void:
	var path: String = "res://audio/sfx/ui_click.wav"
	if ResourceLoader.exists(path):
		play_sfx(path, -6.0)


## Play a UI button hover sound.
func play_ui_hover() -> void:
	var path: String = "res://audio/sfx/ui_hover.wav"
	if ResourceLoader.exists(path):
		play_sfx(path, -12.0)


## Fade out and stop music over a given duration.
## [param duration: float] Time in seconds for the fade.
func fade_out_music(duration: float = MUSIC_FADE_DURATION) -> void:
	if not _active_music_player.playing:
		return
	var tween: Tween = create_tween()
	tween.tween_property(_active_music_player, "volume_db", -40.0, duration)
	tween.tween_callback(_active_music_player.stop)
	tween.tween_callback(func() -> void: _current_music_track = ""; music_stopped.emit())


## Process the music queue. Call this when a track finishes (connected to
## AudioStreamPlayer.finished signal).
func _on_music_finished() -> void:
	if _music_queue.size() > 0:
		var next_track_name: String = _music_queue.pop_front()
		var next_track_path: String = "res://audio/music/%s.ogg" % next_track_name
		if ResourceLoader.exists(next_track_path):
			play_music(next_track_path, next_track_name, true)
		else:
			push_warning("AudioManager: Queued track '%s' not found." % next_track_path)
			_current_music_track = ""
	else:
		_current_music_track = ""
