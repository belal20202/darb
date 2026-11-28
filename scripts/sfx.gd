class_name Sfx
extends RefCounted
## All sounds are generated in code (no audio files needed).

const RATE := 22050
static var _cache: Dictionary = {}

static func _wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w

static func get_sound(n: String) -> AudioStreamWAV:
	if _cache.has(n):
		return _cache[n]
	var s: AudioStreamWAV
	match n:
		"engine": s = _engine()
		"horn": s = _horn()
		"rain": s = _rain()
		"wind": s = _wind()
		"thunder": s = _thunder()
		"crash": s = _crash()
		_: s = _coin()
	_cache[n] = s
	return s

static func _engine() -> AudioStreamWAV:
	var n := RATE
	var a := PackedFloat32Array()
	a.resize(n)
	for i in n:
		var t := float(i) / RATE
		var v := 0.5 * sin(TAU * 90.0 * t) + 0.3 * sin(TAU * 180.0 * t + 0.5) + 0.2 * sin(TAU * 270.0 * t) + 0.12 * sin(TAU * 360.0 * t)
		v *= 0.8 + 0.2 * sin(TAU * 30.0 * t)
		v += 0.04 * (randf() * 2.0 - 1.0)
		a[i] = v * 0.9
	return _wav(a, true)

static func _horn() -> AudioStreamWAV:
	var n := RATE
	var a := PackedFloat32Array()
	a.resize(n)
	for i in n:
		var t := float(i) / RATE
		var v := 0.5 * signf(sin(TAU * 420.0 * t)) + 0.5 * signf(sin(TAU * 520.0 * t))
		v = v * 0.18 + 0.12 * sin(TAU * 420.0 * t) + 0.12 * sin(TAU * 520.0 * t)
		a[i] = v
	return _wav(a, true)

static func _rain() -> AudioStreamWAV:
	var n := RATE * 2
	var a := PackedFloat32Array()
	a.resize(n)
	var prev := 0.0
	for i in n:
		var r := randf() * 2.0 - 1.0
		a[i] = (r - prev * 0.5) * 0.28
		prev = r
	return _wav(a, true)

static func _wind() -> AudioStreamWAV:
	var n := RATE * 2
	var a := PackedFloat32Array()
	a.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp = lp * 0.97 + (randf() * 2.0 - 1.0) * 0.03
		a[i] = lp * 7.0 * (0.7 + 0.3 * sin(TAU * 0.5 * t))
	return _wav(a, true)

static func _thunder() -> AudioStreamWAV:
	var n := int(RATE * 2.8)
	var a := PackedFloat32Array()
	a.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp = lp * 0.92 + (randf() * 2.0 - 1.0) * 0.08
		a[i] = lp * 6.0 * exp(-t * 1.3) * (0.7 + 0.3 * sin(t * 25.0))
	return _wav(a, false)

static func _coin() -> AudioStreamWAV:
	var n := int(RATE * 0.3)
	var a := PackedFloat32Array()
	a.resize(n)
	for i in n:
		var t := float(i) / RATE
		var f := 880.0 if t < 0.1 else 1320.0
		a[i] = sin(TAU * f * t) * exp(-t * 9.0) * 0.5
	return _wav(a, false)

static func _crash() -> AudioStreamWAV:
	var n := int(RATE * 0.5)
	var a := PackedFloat32Array()
	a.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp = lp * 0.6 + (randf() * 2.0 - 1.0) * 0.4
		a[i] = lp * exp(-t * 9.0) * 0.9 + sin(TAU * 70.0 * t) * exp(-t * 12.0) * 0.5
	return _wav(a, false)
