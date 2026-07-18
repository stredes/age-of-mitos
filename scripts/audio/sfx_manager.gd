## SFX Manager — Procedural sound effects for Age of Mitos.
## Generates simple WAV sounds at runtime so the game can have audio
## feedback without shipping external audio files.
##
## Usage: SFXManager.play("select")  or  SFXManager.play_move()
class_name SFXManager
extends Node

# =============================================================================
# Singleton Reference
# =============================================================================

static var instance: SFXManager = null

# =============================================================================
# Configuration
# =============================================================================

const SAMPLE_RATE: int = 22050
const VOLUME_DB_DEFAULT: float = -4.0
const POOL_SIZE: int = 8

# =============================================================================
# Cached Sounds
# =============================================================================

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_index: int = 0

# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	instance = self
	_init_pool()
	_generate_all_sounds()


func _init_pool() -> void:
	for i in POOL_SIZE:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_pool.append(player)

# =============================================================================
# Public API
# =============================================================================

func play(sound_name: String, volume_db: float = VOLUME_DB_DEFAULT, pitch: float = 1.0) -> void:
	if not _streams.has(sound_name):
		push_warning("SFXManager: Unknown sound '%s'." % sound_name)
		return
	var player: AudioStreamPlayer = _get_player()
	player.stream = _streams[sound_name]
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()


func play_select() -> void:
	play("select", -8.0, randf_range(0.95, 1.05))


func play_move() -> void:
	play("move", -6.0, randf_range(0.9, 1.1))


func play_attack() -> void:
	play("attack", -4.0, randf_range(0.85, 1.15))


func play_build() -> void:
	play("build", -6.0, randf_range(0.9, 1.1))


func play_harvest() -> void:
	play("harvest", -6.0, randf_range(0.88, 1.12))


func play_error() -> void:
	play("error", -4.0, 1.0)


func play_repair() -> void:
	play("repair", -6.0, randf_range(0.9, 1.1))


func play_death() -> void:
	play("death", -3.0, randf_range(0.8, 1.2))


func play_heal() -> void:
	play("heal", -6.0, randf_range(0.9, 1.1))

# =============================================================================
# Sound Generation
# =============================================================================

func _generate_all_sounds() -> void:
	_streams["select"] = _gen_click(0.008, 1800.0, 0.7)
	_streams["move"] = _gen_tone_burst(0.06, 600.0, 900.0, 0.5)
	_streams["attack"] = _gen_noise_burst(0.15, 0.9)
	_streams["build"] = _gen_hammer(0.12)
	_streams["harvest"] = _gen_chop(0.10)
	_streams["error"] = _gen_buzzer(0.20, 220.0)
	_streams["repair"] = _gen_hammer(0.10, 1600.0)
	_streams["death"] = _gen_falling_tone(0.4, 800.0, 120.0)
	_streams["heal"] = _gen_rising_chime(0.25, 1000.0, 2000.0)


## Short click — UI select feedback.
func _gen_click(duration: float, freq: float, volume: float) -> AudioStreamWAV:
	var samples: PackedByteArray = _empty_samples(duration)
	var length: int = samples.size()
	for i in length:
		var t: float = float(i) / float(SAMPLE_RATE)
		var envelope: float = 1.0 - float(i) / float(length)
		envelope = envelope * envelope
		var val: float = sin(TAU * freq * t) * envelope * volume
		samples.encode_u8(i, _float_to_u8(val))
	return _make_wav(samples)


## Simple tone burst that sweeps from freq_a to freq_b.
func _gen_tone_burst(duration: float, freq_a: float, freq_b: float, volume: float) -> AudioStreamWAV:
	var samples: PackedByteArray = _empty_samples(duration)
	var length: int = samples.size()
	for i in length:
		var t: float = float(i) / float(length)
		var freq: float = lerpf(freq_a, freq_b, t)
		var envelope: float = sin(t * PI)
		var val: float = sin(TAU * freq * (float(i) / float(SAMPLE_RATE))) * envelope * volume
		samples.encode_u8(i, _float_to_u8(val))
	return _make_wav(samples)


## Noise burst — attack grunt / impact.
func _gen_noise_burst(duration: float, volume: float) -> AudioStreamWAV:
	var samples: PackedByteArray = _empty_samples(duration)
	var length: int = samples.size()
	for i in length:
		var envelope: float = 1.0 - float(i) / float(length)
		envelope = envelope * envelope
		var noise: float = randf_range(-1.0, 1.0)
		# Low-pass by averaging neighbours
		if i > 0:
			var prev: float = _u8_to_float(samples[i - 1])
			noise = (noise + prev) * 0.5
		var val: float = noise * envelope * volume
		samples.encode_u8(i, _float_to_u8(val))
	return _make_wav(samples)


## Hammer hit — two fast taps.
func _gen_hammer(duration: float, base_freq: float = 2000.0) -> AudioStreamWAV:
	var total_samples: int = int(duration * float(SAMPLE_RATE) * 2.0) + int(0.02 * float(SAMPLE_RATE))
	var samples: PackedByteArray = PackedByteArray()
	samples.resize(total_samples)
	var tap_len: int = int(duration * float(SAMPLE_RATE))
	var gap: int = int(0.02 * float(SAMPLE_RATE))
	for i in total_samples:
		var val: float = 0.0
		# First tap
		if i < tap_len:
			var t: float = float(i) / float(tap_len)
			var env: float = (1.0 - t) * (1.0 - t)
			val = (sin(TAU * base_freq * (float(i) / float(SAMPLE_RATE))) * 0.4
				+ randf_range(-0.3, 0.3)) * env
		# Second tap
		var offset: int = tap_len + gap
		if i >= offset and i < offset + tap_len:
			var local_i: int = i - offset
			var t: float = float(local_i) / float(tap_len)
			var env: float = (1.0 - t) * (1.0 - t)
			val = (sin(TAU * (base_freq * 0.8) * (float(i) / float(SAMPLE_RATE))) * 0.4
				+ randf_range(-0.3, 0.3)) * env
		samples.encode_u8(i, _float_to_u8(val))
	return _make_wav(samples)


## Axe chop — quick descending scrape.
func _gen_chop(duration: float) -> AudioStreamWAV:
	var samples: PackedByteArray = _empty_samples(duration)
	var length: int = samples.size()
	for i in length:
		var t: float = float(i) / float(length)
		var envelope: float = sin(t * PI) * (1.0 - t * 0.5)
		var freq: float = lerpf(3000.0, 600.0, t)
		var val: float = (sin(TAU * freq * (float(i) / float(SAMPLE_RATE))) * 0.5
			+ randf_range(-0.4, 0.4) * (1.0 - t)) * envelope
		samples.encode_u8(i, _float_to_u8(val))
	return _make_wav(samples)


## Buzzer — error feedback, harsh square-ish tone.
func _gen_buzzer(duration: float, freq: float) -> AudioStreamWAV:
	var samples: PackedByteArray = _empty_samples(duration)
	var length: int = samples.size()
	for i in length:
		var t: float = float(i) / float(length)
		var envelope: float = 1.0 - t
		# Square wave approximation
		var phase: float = fmod(float(i) / float(SAMPLE_RATE) * freq, 1.0)
		var wave: float = 1.0 if phase < 0.5 else -1.0
		var val: float = wave * envelope * 0.5
		samples.encode_u8(i, _float_to_u8(val))
	return _make_wav(samples)


## Falling tone — unit death.
func _gen_falling_tone(duration: float, freq_start: float, freq_end: float) -> AudioStreamWAV:
	var samples: PackedByteArray = _empty_samples(duration)
	var length: int = samples.size()
	for i in length:
		var t: float = float(i) / float(length)
		var envelope: float = (1.0 - t) * (1.0 - t)
		var freq: float = lerpf(freq_start, freq_end, t)
		var val: float = sin(TAU * freq * (float(i) / float(SAMPLE_RATE))) * envelope * 0.6
		# Add slight noise at end for dusty effect
		if t > 0.5:
			val += randf_range(-0.15, 0.15) * (t - 0.5) * 2.0
		samples.encode_u8(i, _float_to_u8(val))
	return _make_wav(samples)


## Rising chime — heal feedback.
func _gen_rising_chime(duration: float, freq_start: float, freq_end: float) -> AudioStreamWAV:
	var samples: PackedByteArray = _empty_samples(duration)
	var length: int = samples.size()
	for i in length:
		var t: float = float(i) / float(length)
		var envelope: float = sin(t * PI) * 0.6
		var freq: float = lerpf(freq_start, freq_end, t)
		var val: float = sin(TAU * freq * (float(i) / float(SAMPLE_RATE))) * envelope
		# Soft second harmonic for sparkle
		val += sin(TAU * (freq * 2.0) * (float(i) / float(SAMPLE_RATE))) * envelope * 0.2
		samples.encode_u8(i, _float_to_u8(val))
	return _make_wav(samples)

# =============================================================================
# Helpers
# =============================================================================

func _empty_samples(duration: float) -> PackedByteArray:
	var count: int = maxi(int(duration * float(SAMPLE_RATE)), 1)
	var arr: PackedByteArray = PackedByteArray()
	arr.resize(count)
	return arr


func _float_to_u8(val: float) -> int:
	var clamped: float = clampf(val, -1.0, 1.0)
	return int((clamped * 0.5 + 0.5) * 255.0)


func _u8_to_float(sample: int) -> float:
	return (float(sample) / 255.0) * 2.0 - 1.0


func _make_wav(samples: PackedByteArray) -> AudioStreamWAV:
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = samples
	return wav


func _get_player() -> AudioStreamPlayer:
	for i in POOL_SIZE:
		var idx: int = (_pool_index + i) % POOL_SIZE
		if not _pool[idx].playing:
			_pool_index = (idx + 1) % POOL_SIZE
			return _pool[idx]
	# Steal oldest
	var stolen: AudioStreamPlayer = _pool[_pool_index]
	stolen.stop()
	_pool_index = (_pool_index + 1) % POOL_SIZE
	return stolen
