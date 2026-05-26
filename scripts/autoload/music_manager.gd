extends Node

# Procedurally synthesised background music — no audio files required.
# Generates four looping tracks at startup using packed float buffers,
# then plays them via a single AudioStreamPlayer with LOOP_FORWARD set.

const SR: int = 22050  # sample rate (mono)

var _player: AudioStreamPlayer
var _tracks: Dictionary = {}
var _current: String = ""
var _rng: RandomNumberGenerator

func _ready() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.randomize()
	_player = AudioStreamPlayer.new()
	_player.volume_db = -14.0
	add_child(_player)
	_build_tracks()

func play_music(track_name: String) -> void:
	if track_name == _current and _player.playing:
		return
	var stream: AudioStreamWAV = _tracks.get(track_name) as AudioStreamWAV
	if stream == null:
		return
	_current = track_name
	_player.stream = stream
	_player.play()

func stop_music() -> void:
	_player.stop()
	_current = ""

func set_volume(db: float) -> void:
	_player.volume_db = db

# ── Track builders ────────────────────────────────────────────────────────────

func _build_tracks() -> void:
	_tracks["menu"]       = _track_menu()
	_tracks["board"]      = _track_board()
	_tracks["minigame"]   = _track_minigame()
	_tracks["scoreboard"] = _track_scoreboard()

# "Florida Breeze" — G major, 105 BPM, laid-back tropical
func _track_menu() -> AudioStreamWAV:
	var bpm: float = 105.0
	var bs: int    = int(SR * 60.0 / bpm)  # samples per beat
	var bars: int  = 2
	var buf        := _alloc(bs * 4 * bars)

	# Melody — G major, flowing quarter notes (8 beats)
	var mel: Array = [
		[392.0, 1], [494.0, 1], [587.0, 1], [784.0, 1],  # G4 B4 D5 G5
		[587.0, 1], [523.0, 1], [440.0, 1], [392.0, 1],  # D5 C5 A4 G4
	]
	_lay_melody(buf, mel, bs, 0.38)

	# Bass — G2 / D2 alternating half-notes
	var bas: Array = [
		[98.0, 2], [73.4, 2], [98.0, 2], [73.4, 2],  # G2 D2 G2 D2
	]
	_lay_bass(buf, bas, bs, 0.36)

	# Kick on beats 1 & 3 each bar
	for bar: int in bars:
		_add_kick(buf, bar * 4 * bs)
		_add_kick(buf, bar * 4 * bs + 2 * bs)

	# Hi-hat every 8th note
	for b: int in bars * 4:
		_add_hihat(buf, b * bs)
		_add_hihat(buf, b * bs + bs / 2)

	return _to_wav(buf)

# "Florida Man Shuffle" — C major, 120 BPM, upbeat party
func _track_board() -> AudioStreamWAV:
	var bpm: float = 120.0
	var bs: int    = int(SR * 60.0 / bpm)
	var bars: int  = 2
	var buf        := _alloc(bs * 4 * bars)

	var mel: Array = [
		[523.0, 1], [659.0, 1], [784.0, 1], [659.0, 1],  # C5 E5 G5 E5
		[698.0, 1], [587.0, 1], [698.0, 1], [587.0, 1],  # F5 D5 F5 D5
	]
	_lay_melody(buf, mel, bs, 0.36)

	var bas: Array = [
		[65.4, 4], [87.3, 4],  # C2 (whole), F2 (whole)
	]
	_lay_bass(buf, bas, bs, 0.38)

	# Kick every beat (party drive)
	for bar: int in bars:
		for b: int in 4:
			_add_kick(buf, (bar * 4 + b) * bs)

	for b: int in bars * 4:
		_add_hihat(buf, b * bs)
		_add_hihat(buf, b * bs + bs / 2)

	return _to_wav(buf)

# "Gator Chase" — A minor, 140 BPM, fast & tense
func _track_minigame() -> AudioStreamWAV:
	var bpm: float = 140.0
	var bs: int    = int(SR * 60.0 / bpm)
	var bars: int  = 2
	var buf        := _alloc(bs * 4 * bars)

	var mel: Array = [
		[440.0, 1], [523.0, 1], [659.0, 1], [880.0, 1],  # A4 C5 E5 A5
		[784.0, 1], [698.0, 1], [659.0, 1], [587.0, 1],  # G5 F5 E5 D5
	]
	_lay_melody(buf, mel, bs, 0.38)

	var bas: Array = [
		[55.0, 2], [55.0, 2], [49.0, 2], [49.0, 2],  # A1 A1 G1 G1
	]
	_lay_bass(buf, bas, bs, 0.40)

	# Kick on every beat and every off-beat
	for bar: int in bars:
		for b: int in 4:
			_add_kick(buf, (bar * 4 + b) * bs)
			_add_kick(buf, (bar * 4 + b) * bs + bs / 2)

	# 16th-note hi-hats
	for b: int in bars * 4:
		for q: int in 4:
			_add_hihat(buf, b * bs + q * bs / 4)

	return _to_wav(buf)

# "Sunshine Victory" — C major, 90 BPM, triumphant
# Melody: "Ah! vous dirai-je, maman" (public domain)
func _track_scoreboard() -> AudioStreamWAV:
	var bpm: float = 90.0
	var bs: int    = int(SR * 60.0 / bpm)
	var bars: int  = 2
	var buf        := _alloc(bs * 4 * bars)

	var mel: Array = [
		[523.0, 1], [523.0, 1], [784.0, 1], [784.0, 1],  # C5 C5 G5 G5
		[880.0, 1], [880.0, 1], [784.0, 2],               # A5 A5 G5 (half)
	]
	_lay_melody(buf, mel, bs, 0.40)

	var bas: Array = [
		[65.4, 2], [65.4, 2], [87.3, 2], [98.0, 2],  # C2 C2 F2 G2
	]
	_lay_bass(buf, bas, bs, 0.38)

	for bar: int in bars:
		_add_kick(buf, bar * 4 * bs)
		_add_kick(buf, bar * 4 * bs + 2 * bs)

	for b: int in bars * 4:
		_add_hihat(buf, b * bs)
		_add_hihat(buf, b * bs + bs / 2)

	return _to_wav(buf)

# ── Pattern helpers ───────────────────────────────────────────────────────────

func _lay_melody(buf: PackedFloat32Array, notes: Array, bs: int, vol: float) -> void:
	var beat: int = 0
	for note in notes:
		var freq: float  = float(note[0])
		var beats: int   = int(note[1])
		var dur: int     = beats * bs
		_add_melody(buf, beat * bs, dur, freq, vol)
		beat += beats

func _lay_bass(buf: PackedFloat32Array, notes: Array, bs: int, vol: float) -> void:
	var beat: int = 0
	for note in notes:
		var freq: float = float(note[0])
		var beats: int  = int(note[1])
		var dur: int    = beats * bs
		_add_bass(buf, beat * bs, dur, freq, vol)
		beat += beats

# ── Voice renderers ───────────────────────────────────────────────────────────

func _add_melody(buf: PackedFloat32Array, start: int, dur: int, freq: float, vol: float) -> void:
	var note_dur: int = int(dur * 0.88)
	var attack: int   = mini(int(SR * 0.010), note_dur)
	var release: int  = mini(int(SR * 0.055), note_dur)
	var n: int        = buf.size()
	var phase: float  = 0.0
	for i: int in note_dur:
		var env: float
		if i < attack:
			env = float(i) / attack
		elif i > note_dur - release:
			env = float(note_dur - i) / release
		else:
			env = 1.0
		phase += TAU * freq / SR
		var idx: int = start + i
		if idx < n:
			buf[idx] += sin(phase) * env * vol

func _add_bass(buf: PackedFloat32Array, start: int, dur: int, freq: float, vol: float) -> void:
	var attack: int  = mini(int(SR * 0.020), dur)
	var release: int = mini(int(SR * 0.120), dur)
	var n: int       = buf.size()
	for i: int in dur:
		var t: float = float(i) / SR
		var env: float
		if i < attack:
			env = float(i) / attack
		elif i > dur - release:
			env = float(dur - i) / release
		else:
			env = 1.0
		# Soft sawtooth via first three harmonics
		var s: float = sin(TAU * freq * t)       * 0.65
		s           += sin(TAU * freq * 2.0 * t) * 0.25
		s           += sin(TAU * freq * 3.0 * t) * 0.10
		var idx: int = start + i
		if idx < n:
			buf[idx] += s * env * vol

func _add_kick(buf: PackedFloat32Array, start: int) -> void:
	var dur: int = int(SR * 0.14)
	var n: int   = buf.size()
	for i: int in dur:
		var t: float   = float(i) / dur
		var freq: float = 120.0 - 80.0 * t
		var env: float  = exp(-9.0 * t) * 0.45
		var idx: int    = start + i
		if idx < n:
			buf[idx] += sin(TAU * freq * float(i) / SR) * env

func _add_hihat(buf: PackedFloat32Array, start: int) -> void:
	var dur: int = int(SR * 0.022)
	var n: int   = buf.size()
	for i: int in dur:
		var t: float = float(i) / dur
		var idx: int = start + i
		if idx < n:
			buf[idx] += (_rng.randf() * 2.0 - 1.0) * exp(-35.0 * t) * 0.09

# ── WAV helpers ───────────────────────────────────────────────────────────────

func _alloc(size: int) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(size)
	buf.fill(0.0)
	return buf

func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	# Normalise to prevent clipping
	var peak: float = 0.001
	for v: float in samples:
		peak = maxf(peak, absf(v))
	var scale: float = 0.88 / peak

	var s := AudioStreamWAV.new()
	s.mix_rate   = SR
	s.stereo     = false
	s.format     = AudioStreamWAV.FORMAT_16_BITS
	s.loop_mode  = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end   = samples.size()
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i: int in samples.size():
		var v: int = int(clampf(samples[i] * scale, -1.0, 1.0) * 32767.0)
		data[i * 2]     = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF
	s.data = data
	return s
