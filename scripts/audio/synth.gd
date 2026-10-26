class_name Synth
extends RefCounted
## Procedurally synthesized placeholder sound effects. Each generator returns a
## ready-to-play AudioStreamWAV, so the game ships without any audio files.

const RATE := 22050


static func to_stream(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = samples.size()
	return stream


## Crossfades the tail into the head so the buffer loops without a click.
static func make_loopable(samples: PackedFloat32Array, fade: int) -> PackedFloat32Array:
	var length := samples.size() - fade
	var out := samples.slice(0, length)
	for i in fade:
		var t := float(i) / fade
		out[i] = samples[i] * t + samples[length + i] * (1.0 - t)
	return out


static func _buffer(seconds: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(seconds * RATE))
	return out


static func effects() -> Dictionary:
	return {
		"jump": jump(),
		"land": land(),
		"crash": crash(),
		"coin": coin(),
		"cocoa": fanfare(),
		"boost": boost(),
		"whoosh": whoosh(),
		"horn": horn(),
		"moose": moose(),
		"poff": poff(),
		"beep": beep(660.0),
		"go": beep(1320.0),
		"trick": fanfare(1.5),
		"oops": oops(),
		"jingle": jingle(),
		"hohoho": hohoho(),
		"splat": poff(),
		"train_horn": train_horn(),
		"jet": jet(),
		"splash": splash(),
	}


static func wind() -> AudioStreamWAV:
	var out := _buffer(4.3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var low := 0.0
	var band := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var cutoff := 0.03 + 0.025 * sin(t * TAU * 0.5) + 0.015 * sin(t * TAU * 1.25)
		low += cutoff * (rng.randf_range(-1.0, 1.0) - low)
		band += 0.3 * (low - band)
		out[i] = (low - band * 0.5) * 6.0 * (0.7 + 0.3 * sin(t * TAU * 0.75))
	return to_stream(make_loopable(out, int(0.3 * RATE)), true)


static func scrape() -> AudioStreamWAV:
	var out := _buffer(2.2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var low := 0.0
	var grain := 0.0
	for i in out.size():
		if rng.randf() < 0.004:
			grain = rng.randf_range(0.4, 1.0)
		grain *= 0.9993
		var white := rng.randf_range(-1.0, 1.0)
		low += 0.25 * (white - low)
		out[i] = (white - low) * (0.35 + grain * 0.65) * 0.5
	return to_stream(make_loopable(out, int(0.2 * RATE)), true)


static func engine() -> AudioStreamWAV:
	var out := _buffer(1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var low := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var p := t * 48.0
		var saw := 2.0 * (p - floorf(p)) - 1.0
		low += 0.05 * (rng.randf_range(-1.0, 1.0) - low)
		out[i] = (saw * 0.35 + sin(t * TAU * 96.0) * 0.25 + low * 1.5) * (0.85 + 0.15 * sin(t * TAU * 8.0))
	return to_stream(out, true)


static func jump() -> AudioStreamWAV:
	var out := _buffer(0.3)
	var phase := 0.0
	for i in out.size():
		var t := float(i) / RATE
		phase += (260.0 + 900.0 * t) / RATE
		out[i] = sin(phase * TAU) * exp(-t * 9.0) * 0.5
	return to_stream(out)


static func land() -> AudioStreamWAV:
	var out := _buffer(0.35)
	var rng := RandomNumberGenerator.new()
	var phase := 0.0
	var low := 0.0
	for i in out.size():
		var t := float(i) / RATE
		phase += (90.0 - 50.0 * t) / RATE
		low += 0.15 * (rng.randf_range(-1.0, 1.0) - low)
		out[i] = sin(phase * TAU) * exp(-t * 14.0) * 0.7 + low * exp(-t * 10.0) * 1.4
	return to_stream(out)


static func crash() -> AudioStreamWAV:
	var out := _buffer(1.1)
	var rng := RandomNumberGenerator.new()
	var phase := 0.0
	var low := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var boing := 520.0 * exp(-t * 2.2) + 80.0
		phase += boing * (1.0 + 0.08 * sin(t * TAU * 18.0)) / RATE
		low += 0.12 * (rng.randf_range(-1.0, 1.0) - low)
		var thud := low * exp(-t * 7.0) * 1.8
		out[i] = sin(phase * TAU) * exp(-t * 2.5) * 0.45 + thud
	return to_stream(out)


static func coin() -> AudioStreamWAV:
	var out := _buffer(0.35)
	for i in out.size():
		var t := float(i) / RATE
		var f := 1318.5 if t < 0.07 else 1975.5
		out[i] = (sin(t * TAU * f) + 0.3 * sin(t * TAU * f * 2.0)) * exp(-t * 9.0) * 0.35
	return to_stream(out)


static func fanfare(speed := 1.0) -> AudioStreamWAV:
	var notes := [784.0, 987.8, 1174.7, 1568.0]
	var step := 0.09 / speed
	var out := _buffer(step * notes.size() + 0.4)
	for n in notes.size():
		var start := int(n * step * RATE)
		var f: float = notes[n]
		for k in int(0.4 * RATE):
			var idx := start + k
			if idx >= out.size():
				break
			var t := float(k) / RATE
			out[idx] += (sin(t * TAU * f) + 0.4 * sin(t * TAU * f * 3.0) / 3.0) * exp(-t * 6.0) * 0.25
	return to_stream(out)


static func boost() -> AudioStreamWAV:
	var out := _buffer(0.8)
	var rng := RandomNumberGenerator.new()
	var phase := 0.0
	var low := 0.0
	for i in out.size():
		var t := float(i) / RATE
		phase += (200.0 + 1200.0 * t * t) / RATE
		low += (0.05 + t * 0.4) * (rng.randf_range(-1.0, 1.0) - low)
		out[i] = (sin(phase * TAU) * 0.3 + low * 0.8) * minf(t * 10.0, 1.0) * exp(-t * 2.5)
	return to_stream(out)


static func whoosh() -> AudioStreamWAV:
	var out := _buffer(0.6)
	var rng := RandomNumberGenerator.new()
	var low := 0.0
	var band := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var env := sin(clampf(t / 0.6, 0.0, 1.0) * PI)
		var cutoff := 0.05 + 0.3 * env
		low += cutoff * (rng.randf_range(-1.0, 1.0) - low)
		band += 0.5 * (low - band)
		out[i] = (low - band) * env * 2.2
	return to_stream(out)


static func horn() -> AudioStreamWAV:
	var out := _buffer(0.75)
	for i in out.size():
		var t := float(i) / RATE
		var on := 1.0 if (t < 0.22 or (t > 0.32 and t < 0.7)) else 0.0
		var s := 0.0
		for f in [392.0, 494.0]:
			var p: float = t * f
			s += (2.0 * (p - floorf(p)) - 1.0) * 0.2
		out[i] = s * on
	return to_stream(out)


static func moose() -> AudioStreamWAV:
	var out := _buffer(1.0)
	var phase := 0.0
	var low := 0.0
	for i in out.size():
		var t := float(i) / RATE
		phase += (95.0 + 25.0 * sin(t * TAU * 1.5) - 30.0 * t) / RATE
		var saw := 2.0 * (phase - floorf(phase)) - 1.0
		low += (0.08 + 0.05 * sin(t * TAU * 4.0)) * (saw - low)
		out[i] = low * 1.4 * sin(clampf(t, 0.0, 1.0) * PI)
	return to_stream(out)


static func poff() -> AudioStreamWAV:
	var out := _buffer(0.4)
	var rng := RandomNumberGenerator.new()
	var low := 0.0
	for i in out.size():
		var t := float(i) / RATE
		low += 0.3 * (rng.randf_range(-1.0, 1.0) - low)
		out[i] = low * exp(-t * 12.0) * 1.6
	return to_stream(out)


static func beep(frequency: float) -> AudioStreamWAV:
	var out := _buffer(0.25)
	for i in out.size():
		var t := float(i) / RATE
		out[i] = (sin(t * TAU * frequency) + sin(t * TAU * frequency * 3.0) / 3.0) * minf(1.0, (0.25 - t) * 30.0) * 0.3
	return to_stream(out)


## Two-tone diesel horn, low and long.
static func train_horn() -> AudioStreamWAV:
	var out := _buffer(1.6)
	var low := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var s := 0.0
		for f in [185.0, 233.0, 277.0]:
			var p: float = t * f
			s += 2.0 * (p - floorf(p)) - 1.0
		low += 0.15 * (s - low)
		var env := minf(1.0, t * 12.0) * minf(1.0, (1.6 - t) * 6.0)
		out[i] = low * env * 0.35
	return to_stream(out)


## Jet engine roar swelling and fading as it passes.
static func jet() -> AudioStreamWAV:
	var out := _buffer(5.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var low := 0.0
	var band := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var pass_by := exp(-pow((t - 2.4) / 1.1, 2.0))
		low += (0.04 + 0.2 * pass_by) * (rng.randf_range(-1.0, 1.0) - low)
		band += 0.5 * (low - band)
		out[i] = (low - band * 0.3) * (0.15 + pass_by) * 2.2 + sin(t * TAU * (900.0 - 300.0 * t / 5.0)) * pass_by * 0.05
	return to_stream(out)


## Water splash: a broadband slap, a churning body of filtered noise, rising
## bubble "bloops" and a sprinkle of falling droplets.
static func splash() -> AudioStreamWAV:
	var out := _buffer(0.9)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var low := 0.0
	var band := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var white := rng.randf_range(-1.0, 1.0)
		low += 0.35 * (white - low)
		band += 0.12 * (low - band)
		var slap := (white - low) * exp(-t * 45.0) * 0.9
		var body := (low - band) * exp(-t * 7.0) * (0.8 + 0.2 * sin(t * 90.0)) * 1.4
		out[i] = slap + body
	for bubble in 14:
		var start := rng.randf_range(0.02, 0.45)
		var pitch := rng.randf_range(350.0, 1300.0)
		var loud := rng.randf_range(0.08, 0.2) * exp(-start * 3.0)
		var phase := 0.0
		var first := int(start * RATE)
		for k in int(0.07 * RATE):
			var t := float(k) / RATE
			phase += pitch * (1.0 + 7.0 * t) / RATE
			if first + k < out.size():
				out[first + k] += sin(phase * TAU) * exp(-t * 55.0) * loud
	for drop in 22:
		var first := int(rng.randf_range(0.15, 0.85) * RATE)
		var pitch := rng.randf_range(1800.0, 4200.0)
		for k in int(0.02 * RATE):
			var t := float(k) / RATE
			if first + k < out.size():
				out[first + k] += sin(t * TAU * pitch * (1.0 + 4.0 * t)) * exp(-t * 220.0) * 0.06
	return to_stream(out)


static func jingle() -> AudioStreamWAV:
	var out := _buffer(1.6)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for shake in 12:
		var start := int((shake * 0.12 + rng.randf_range(0.0, 0.03)) * RATE)
		for k in int(0.18 * RATE):
			var idx := start + k
			if idx >= out.size():
				break
			var t := float(k) / RATE
			var ring := sin(t * TAU * 2650.0) + sin(t * TAU * 3720.0) * 0.7 + sin(t * TAU * 5110.0) * 0.5
			out[idx] += (ring * exp(-t * 22.0) + rng.randf_range(-1.0, 1.0) * exp(-t * 50.0) * 0.5) * 0.12
	return to_stream(out)


## A cartoon "ho ho ho": three low sung vowels.
static func hohoho() -> AudioStreamWAV:
	var out := _buffer(1.3)
	var phase := 0.0
	var low := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var syllable := fmod(t, 0.38)
		var on := 1.0 if syllable < 0.28 and t < 1.14 else 0.0
		var env := on * minf(syllable * 30.0, 1.0) * exp(-syllable * 4.0)
		phase += (120.0 - syllable * 40.0) / RATE
		var saw := 2.0 * (phase - floorf(phase)) - 1.0
		low += 0.06 * (saw - low)
		out[i] = (low * 2.2 + sin(phase * TAU * 4.0) * 0.08) * env
	return to_stream(out)


static func oops() -> AudioStreamWAV:
	var out := _buffer(0.5)
	var phase := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var f := 700.0 - 500.0 * t if t < 0.18 else 500.0 - 300.0 * (t - 0.18)
		phase += f * (1.0 + 0.05 * sin(t * TAU * 30.0)) / RATE
		out[i] = (sin(phase * TAU) + 0.5 * sin(phase * TAU * 2.0)) * exp(-t * 4.0) * 0.3
	return to_stream(out)
