extends RefCounted

## Original synthesized holiday music and semantic toy-game cues.

const RATE := 22050
static var _cache: Dictionary = {}


## The loop is composed here; it has no external recordings or downloads.
static func music() -> AudioStreamWAV:
	if not _cache.has("music"):
		var notes := [60, 64, 67, 72, 69, 67, 64, 62, 65, 69, 72, 69, 67, 64, 62, 67]
		var beat := 60.0 / 112.0
		var frames := roundi(notes.size() * beat * RATE)
		var bytes := PackedByteArray()
		bytes.resize(frames * 2)
		for frame in frames:
			var time := float(frame) / RATE
			var index := mini(notes.size() - 1, floori(time / beat))
			var age := fmod(time, beat)
			var frequency := 440.0 * pow(2.0, (notes[index] - 69) / 12.0)
			var envelope := minf(1.0, age * 160.0) * exp(-age * 6.0)
			var melody := sin(TAU * frequency * time) + 0.22 * sin(TAU * frequency * 2.0 * time)
			var bass := sin(TAU * frequency * 0.25 * time) * exp(-age * 3.0) * 0.35
			bytes.encode_s16(frame * 2, roundi((melody * envelope + bass) * 3300.0))
		var stream := _stream(bytes)
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = frames
		_cache["music"] = stream
	return _cache["music"]


## Cue identities are explicit, so an unknown event cannot sound like success.
static func cue(id: String) -> AudioStreamWAV:
	if not _cache.has(id):
		var pitches := {
			"roll": [220.0, 277.18, 329.63],
			"coin": [659.25, 830.61, 987.77],
			"tag": [523.25, 783.99],
			"bump": [174.61, 130.81],
			"start": [392.0, 523.25, 659.25],
			"finish": [523.25, 659.25, 783.99, 1046.5],
		}
		assert(pitches.has(id), "Unknown Florida Men sound: " + id)
		var notes: Array = pitches[id]
		var length := 0.085
		var frames := roundi(notes.size() * length * RATE)
		var bytes := PackedByteArray()
		bytes.resize(frames * 2)
		for frame in frames:
			var time := float(frame) / RATE
			var index := mini(notes.size() - 1, floori(time / length))
			var age := fmod(time, length)
			var envelope := minf(1.0, age * 300.0) * maxf(0.0, 1.0 - age / length)
			var wave := sin(TAU * float(notes[index]) * time)
			bytes.encode_s16(frame * 2, roundi(wave * envelope * 9000.0))
		_cache[id] = _stream(bytes)
	return _cache[id]


static func _stream(bytes: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = bytes
	return stream
