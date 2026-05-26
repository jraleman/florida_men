extends Node

const SAMPLE_RATE: int = 22050
const POOL_SIZE: int = 8

var _players: Array[AudioStreamPlayer] = []
var _pool_idx: int = 0
var _sounds: Dictionary = {}

func _ready() -> void:
	for i: int in POOL_SIZE:
		var asp := AudioStreamPlayer.new()
		add_child(asp)
		_players.append(asp)
	_build_sounds()

func _build_sounds() -> void:
	_sounds["ui_click"]    = _make_click()
	_sounds["dice_roll"]   = _make_dice_roll()
	_sounds["hop"]         = _make_hop()
	_sounds["lucky"]       = _make_arpeggio([523, 659, 784, 1047], 0.08)
	_sounds["unlucky"]     = _make_arpeggio([440, 370, 294], 0.10)
	_sounds["bonus"]       = _make_arpeggio([523, 659, 784, 1047, 1319], 0.07)
	_sounds["penalty"]     = _make_buzz_down(0.28)
	_sounds["start_space"] = _make_arpeggio([392, 523, 659, 784], 0.09)
	_sounds["normal"]      = _make_ping(660.0, 0.10)
	_sounds["game_start"]  = _make_arpeggio([392, 494, 587, 784], 0.11)
	_sounds["game_over"]   = _make_arpeggio([523, 440, 349, 262], 0.14)
	_sounds["score_point"] = _make_ping(1047.0, 0.07)
	_sounds["fanfare"]     = _make_arpeggio([261, 329, 392, 523, 659, 784], 0.08)

func play(sound_name: String, volume_db: float = 0.0) -> void:
	var stream: AudioStreamWAV = _sounds.get(sound_name) as AudioStreamWAV
	if stream == null:
		return
	var asp: AudioStreamPlayer = _players[_pool_idx]
	_pool_idx = (_pool_idx + 1) % POOL_SIZE
	asp.stream = stream
	asp.volume_db = volume_db
	asp.play()

# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	var n: int = samples.size()
	var data := PackedByteArray()
	data.resize(n * 2)
	for i: int in n:
		var s: int = int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		data[i * 2]     = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF
	stream.data = data
	return stream

func _make_click() -> AudioStreamWAV:
	var n: int = int(SAMPLE_RATE * 0.05)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i: int in n:
		var t: float = float(i) / SAMPLE_RATE
		samples[i] = (rng.randf() * 2.0 - 1.0) * exp(-20.0 * t) * 0.5
	return _make_wav(samples)

func _make_dice_roll() -> AudioStreamWAV:
	var n: int = int(SAMPLE_RATE * 0.22)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var phase: float = 0.0
	for i: int in n:
		var t: float = float(i) / n
		var env: float = sin(t * PI) * 0.35
		phase += TAU * (200.0 + 300.0 * t) / SAMPLE_RATE
		samples[i] = (sin(phase) * 0.3 + (rng.randf() * 2.0 - 1.0) * 0.7) * env
	return _make_wav(samples)

func _make_hop() -> AudioStreamWAV:
	var n: int = int(SAMPLE_RATE * 0.15)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var phase: float = 0.0
	for i: int in n:
		var t: float = float(i) / n
		var freq: float = 660.0 - 220.0 * t
		phase += TAU * freq / SAMPLE_RATE
		samples[i] = sin(phase) * exp(-7.0 * t) * 0.55
	return _make_wav(samples)

func _make_ping(freq: float, duration: float) -> AudioStreamWAV:
	var n: int = int(SAMPLE_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var phase: float = 0.0
	for i: int in n:
		var t: float = float(i) / SAMPLE_RATE
		phase += TAU * freq / SAMPLE_RATE
		samples[i] = sin(phase) * exp(-10.0 * t) * 0.6
	return _make_wav(samples)

func _make_arpeggio(freqs: Array, note_dur: float) -> AudioStreamWAV:
	var note_n: int = int(SAMPLE_RATE * note_dur)
	var total_n: int = note_n * freqs.size()
	var samples := PackedFloat32Array()
	samples.resize(total_n)
	for fi: int in freqs.size():
		var freq: float = float(freqs[fi])
		var offset: int = fi * note_n
		var phase: float = 0.0
		for i: int in note_n:
			var t: float = float(i) / note_n
			phase += TAU * freq / SAMPLE_RATE
			samples[offset + i] = sin(phase) * sin(t * PI) * 0.7
	return _make_wav(samples)

func _make_buzz_down(duration: float) -> AudioStreamWAV:
	var n: int = int(SAMPLE_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var phase: float = 0.0
	for i: int in n:
		var t: float = float(i) / n
		var freq: float = 300.0 * (1.0 - t * 0.55)
		phase += TAU * freq / SAMPLE_RATE
		samples[i] = signf(sin(phase)) * (1.0 - t) * 0.40
	return _make_wav(samples)
