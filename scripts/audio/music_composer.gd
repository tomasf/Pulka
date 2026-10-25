class_name MusicComposer
extends RefCounted
## Renders the game's tunes from code: a winter humppa, a minor-key polska in
## 3/4, a driving arpeggio track and a sleigh-bell boogie. Runs on worker threads.

const RATE := 22050
const BPM := 156.0

## Root note (MIDI, bass octave) and whether the chord is minor, one per bar.
const CHORDS := [
	[43, false], [38, false], [40, true], [36, false], [43, false], [38, false], [36, false], [38, false],
	[40, true], [36, false], [43, false], [38, false], [40, true], [36, false], [38, false], [43, false],
]

## [MIDI note or -1 for a rest, length in eighths]
const MELODY := [
	[74, 1], [79, 1], [78, 1], [79, 1], [83, 2], [79, 2],
	[81, 1], [78, 1], [74, 1], [78, 1], [81, 2], [-1, 2],
	[79, 1], [76, 1], [71, 1], [76, 1], [79, 1], [81, 1], [83, 2],
	[84, 2], [83, 1], [81, 1], [79, 2], [76, 2],
	[74, 1], [79, 1], [78, 1], [79, 1], [83, 2], [86, 2],
	[86, 1], [83, 1], [81, 1], [78, 1], [74, 2], [78, 2],
	[76, 1], [79, 1], [84, 1], [83, 1], [81, 1], [79, 1], [76, 2],
	[78, 2], [81, 2], [79, 4],
	[83, 1], [83, 1], [81, 1], [79, 1], [83, 2], [88, 2],
	[88, 1], [86, 1], [84, 1], [83, 1], [84, 2], [79, 2],
	[79, 1], [83, 1], [86, 1], [83, 1], [91, 2], [86, 2],
	[86, 1], [84, 1], [83, 1], [81, 1], [78, 2], [74, 2],
	[76, 1], [79, 1], [83, 1], [79, 1], [76, 1], [79, 1], [83, 2],
	[84, 1], [83, 1], [81, 1], [79, 1], [76, 2], [72, 2],
	[74, 1], [78, 1], [81, 1], [84, 1], [83, 1], [81, 1], [78, 2],
	[79, 3], [-1, 1], [74, 1], [78, 1], [81, 1], [83, 1],
]

enum Wave { SINE, SQUARE, SAW }

const SONG_COUNT := 4

## E minor polska in 3/4: six eighths per bar.
const POLSKA_CHORDS := [
	[40, true], [40, true], [35, false], [35, false], [40, true], [40, true], [45, true], [35, false],
	[40, true], [38, false], [43, false], [43, false], [45, true], [40, true], [35, false], [40, true],
]
const POLSKA_MELODY := [
	[76, 2], [79, 1], [78, 1], [76, 1], [75, 1],
	[76, 1], [71, 1], [67, 1], [71, 1], [76, 2],
	[78, 1], [75, 1], [71, 1], [75, 1], [78, 1], [81, 1],
	[83, 3], [81, 1], [78, 1], [75, 1],
	[76, 2], [79, 1], [83, 1], [88, 2],
	[86, 1], [84, 1], [83, 1], [81, 1], [79, 1], [78, 1],
	[76, 1], [81, 1], [84, 1], [81, 1], [79, 1], [76, 1],
	[78, 3], [-1, 1], [71, 1], [75, 1],
	[76, 1], [78, 1], [79, 1], [81, 1], [83, 2],
	[81, 1], [78, 1], [74, 1], [78, 1], [81, 2],
	[79, 1], [83, 1], [86, 2], [83, 1], [79, 1],
	[74, 2], [79, 2], [83, 2],
	[84, 2], [83, 1], [81, 1], [79, 1], [76, 1],
	[79, 2], [76, 1], [79, 1], [83, 2],
	[81, 1], [79, 1], [78, 1], [76, 1], [75, 2],
	[76, 4], [-1, 2],
]

## D major driving arpeggios, 16 bars.
const ARP_CHORDS := [
	[38, false], [33, false], [35, true], [43, false], [38, false], [33, false], [35, true], [43, false],
	[40, true], [43, false], [38, false], [45, false], [40, true], [43, false], [45, false], [45, false],
]

## A major 12-bar blues, played twice.
const BOOGIE_CHORDS := [45, 45, 45, 45, 38, 38, 45, 45, 40, 38, 45, 40]


static func title(index: int) -> String:
	return ["Humppa i backen", "Polska på isen", "Fartvind", "Bjällerboogie"][index % SONG_COUNT]


static func render(index: int) -> AudioStreamWAV:
	match index % SONG_COUNT:
		1:
			return _polska()
		2:
			return _arpeggios()
		3:
			return _boogie()
		_:
			return _humppa()


static func _buffer(seconds: float) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(int(seconds * RATE))
	return buffer


static func _finish(buffer: PackedFloat32Array) -> AudioStreamWAV:
	var peak := 0.001
	for sample in buffer:
		peak = maxf(peak, absf(sample))
	var gain := 0.85 / peak
	for i in buffer.size():
		buffer[i] = buffer[i] * gain
	return Synth.to_stream(buffer)


static func _melody(buffer: PackedFloat32Array, notes: Array, step: float, amp: float, wave: Wave, decay := 1.5) -> void:
	var position := 0.0
	for note: Array in notes:
		var pitch: int = note[0]
		var length: int = note[1]
		if pitch >= 0:
			_tone(buffer, position * step, length * step * 0.92, _freq(pitch), amp, wave, 0.01, decay, true)
		position += length


## Oom-pah bass, off-beat chord stabs, sleigh bells and a bouncy square lead.
static func _humppa() -> AudioStreamWAV:
	var eighth := 60.0 / BPM / 2.0
	var bar := eighth * 8.0
	var buffer := _buffer(bar * CHORDS.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	for index in CHORDS.size():
		var chord: Array = CHORDS[index]
		var root: int = chord[0]
		var third := 3 if chord[1] else 4
		for beat in 4:
			var t := index * bar + beat * eighth * 2.0
			var bass := root if beat % 2 == 0 else root + 7
			_tone(buffer, t, eighth * 1.7, _freq(bass), 0.34, Wave.SINE, 0.004, 5.0)
			_tone(buffer, t, eighth * 1.2, _freq(bass + 12), 0.08, Wave.SQUARE, 0.004, 8.0)
			for interval in [12, 12 + third, 19, 24]:
				_tone(buffer, t + eighth, eighth * 0.75, _freq(root + interval + 12), 0.045, Wave.SAW, 0.003, 9.0)
			if beat % 2 == 0:
				_kick(buffer, t)
			else:
				_snare(buffer, t, rng)
			_bells(buffer, t, 0.06, rng)
			_bells(buffer, t + eighth, 0.035, rng)
	_melody(buffer, MELODY, eighth, 0.13, Wave.SQUARE)
	return _finish(buffer)


## Swedish polska in 3/4 with an accordion-like lead.
static func _polska() -> AudioStreamWAV:
	var eighth := 60.0 / 150.0 / 2.0
	var bar := eighth * 6.0
	var buffer := _buffer(bar * POLSKA_CHORDS.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for index in POLSKA_CHORDS.size():
		var chord: Array = POLSKA_CHORDS[index]
		var root: int = chord[0]
		var third := 3 if chord[1] else 4
		var t := index * bar
		_tone(buffer, t, eighth * 1.8, _freq(root), 0.36, Wave.SINE, 0.004, 4.0)
		_kick(buffer, t)
		for beat in [1, 2]:
			for interval in [12, 12 + third, 19]:
				_tone(buffer, t + beat * eighth * 2.0, eighth * 1.1, _freq(root + interval + 12), 0.05, Wave.SAW, 0.004, 6.0)
			_tone(buffer, t + beat * eighth * 2.0, eighth, _freq(root + 7 + 12), 0.08, Wave.SINE, 0.004, 7.0)
		_snare(buffer, t + eighth * 4.0, rng)
		for k in 6:
			_bells(buffer, t + k * eighth, 0.05 if k % 2 == 0 else 0.03, rng)
	_melody(buffer, POLSKA_MELODY, eighth, 0.11, Wave.SAW, 1.2)
	_melody(buffer, POLSKA_MELODY.map(func(n: Array) -> Array: return [n[0] - 12 if n[0] >= 0 else -1, n[1]]), eighth, 0.05, Wave.SQUARE, 1.2)
	return _finish(buffer)


## Four-on-the-floor with sixteenth-note arpeggios and a soaring lead.
static func _arpeggios() -> AudioStreamWAV:
	var sixteenth := 60.0 / 140.0 / 4.0
	var bar := sixteenth * 16.0
	var buffer := _buffer(bar * ARP_CHORDS.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var pattern := [0, 7, 12, 16, 19, 16, 12, 7]
	for index in ARP_CHORDS.size():
		var chord: Array = ARP_CHORDS[index]
		var root: int = chord[0]
		var minor: bool = chord[1]
		var t := index * bar
		for step in 16:
			var interval: int = pattern[step % pattern.size()]
			if minor and (interval == 16 or interval == 4):
				interval -= 1
			_tone(buffer, t + step * sixteenth, sixteenth * 0.9, _freq(root + 36 + interval), 0.05, Wave.SQUARE, 0.002, 14.0)
			if step % 2 == 0:
				var octave := 12 if step % 4 == 2 else 0
				_tone(buffer, t + step * sixteenth, sixteenth * 1.8, _freq(root + octave), 0.3, Wave.SINE, 0.003, 7.0)
			if step % 4 == 0:
				_kick(buffer, t + step * sixteenth)
			if step % 8 == 4:
				_snare(buffer, t + step * sixteenth, rng)
			if step % 4 == 2:
				_bells(buffer, t + step * sixteenth, 0.045, rng)
		var third := 3 if minor else 4
		var lead_a := root + 36 + third + (12 if index >= 8 else 0)
		var lead_b := root + 36 + 7 + (12 if index >= 8 else 0)
		_tone(buffer, t, bar * 0.45, _freq(lead_a), 0.1, Wave.SAW, 0.03, 0.8, true)
		_tone(buffer, t + bar * 0.5, bar * 0.45, _freq(lead_b if index % 2 == 0 else lead_a + 2), 0.1, Wave.SAW, 0.03, 0.8, true)
	return _finish(buffer)


## Shuffled boogie-woogie blues with walking bass and sleigh bells.
static func _boogie() -> AudioStreamWAV:
	var beat := 60.0 / 168.0
	var bar := beat * 4.0
	var choruses := 2
	var buffer := _buffer(bar * BOOGIE_CHORDS.size() * choruses)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var walk := [0, 4, 7, 9, 10, 9, 7, 4]
	var riff_a := [[12, 1], [15, 1], [16, 2], [19, 2], [21, 1], [19, 1]]
	var riff_b := [[22, 2], [21, 1], [19, 1], [16, 2], [12, 2]]
	for chorus in choruses:
		for index in BOOGIE_CHORDS.size():
			var root: int = BOOGIE_CHORDS[index]
			var t := (chorus * BOOGIE_CHORDS.size() + index) * bar
			for k in 8:
				var swung := t + floorf(k / 2.0) * beat + (beat * 2.0 / 3.0 if k % 2 == 1 else 0.0)
				_tone(buffer, swung, beat * 0.45, _freq(root + walk[k]), 0.3, Wave.SAW, 0.003, 6.0)
				_bells(buffer, swung, 0.045 if k % 2 == 0 else 0.03, rng)
			for b in 4:
				if b % 2 == 0:
					_kick(buffer, t + b * beat)
				else:
					_snare(buffer, t + b * beat, rng)
			var riff: Array = riff_a if (index + chorus) % 2 == 0 else riff_b
			var position := 0.0
			for note: Array in riff:
				var length: int = note[1]
				var swung_start := t + floorf(position / 2.0) * beat + (beat * 2.0 / 3.0 if int(position) % 2 == 1 else 0.0)
				_tone(buffer, swung_start, length * beat * 0.45, _freq(root + 24 + int(note[0])), 0.1, Wave.SQUARE, 0.008, 2.5, true)
				position += length
	return _finish(buffer)


static func _freq(midi: int) -> float:
	return 440.0 * pow(2.0, (midi - 69) / 12.0)


static func _tone(buffer: PackedFloat32Array, start: float, length: float, frequency: float, amp: float, wave: Wave, attack: float, decay: float, vibrato := false) -> void:
	var first := int(start * RATE)
	var count := int(length * RATE)
	var release := 0.015 * RATE
	var size := buffer.size()
	var phase := 0.0
	var step := frequency / RATE
	for k in count:
		var t := float(k) / RATE
		var env := minf(1.0, t / attack) * exp(-t * decay) * minf(1.0, (count - k) / release)
		var p := phase * TAU
		var s: float
		if wave == Wave.SINE:
			s = sin(p)
		elif wave == Wave.SQUARE:
			s = sin(p) + sin(3.0 * p) / 3.0 + sin(5.0 * p) / 5.0
		else:
			s = sin(p) + sin(2.0 * p) / 2.0 + sin(3.0 * p) / 3.0
		buffer[(first + k) % size] += s * env * amp
		phase += step * (1.0 + 0.006 * sin(t * TAU * 5.5)) if vibrato and t > 0.12 else step


static func _kick(buffer: PackedFloat32Array, start: float) -> void:
	var first := int(start * RATE)
	var phase := 0.0
	for k in int(0.22 * RATE):
		var t := float(k) / RATE
		phase += (48.0 + 110.0 * exp(-t * 35.0)) / RATE
		buffer[(first + k) % buffer.size()] += sin(phase * TAU) * exp(-t * 11.0) * 0.5


static func _snare(buffer: PackedFloat32Array, start: float, rng: RandomNumberGenerator) -> void:
	var first := int(start * RATE)
	var low := 0.0
	for k in int(0.16 * RATE):
		var t := float(k) / RATE
		var white := rng.randf_range(-1.0, 1.0)
		low += 0.4 * (white - low)
		buffer[(first + k) % buffer.size()] += ((white - low) * 0.3 + sin(t * TAU * 190.0) * 0.12) * exp(-t * 22.0)


static func _bells(buffer: PackedFloat32Array, start: float, amp: float, rng: RandomNumberGenerator) -> void:
	var first := int((start + rng.randf_range(-0.004, 0.004)) * RATE)
	for k in int(0.11 * RATE):
		var t := float(k) / RATE
		var ring := sin(t * TAU * 2650.0) + sin(t * TAU * 3720.0) * 0.7 + sin(t * TAU * 5110.0) * 0.5
		var jingle := ring * exp(-t * 28.0) + rng.randf_range(-1.0, 1.0) * exp(-t * 60.0) * 0.6
		buffer[(maxi(first, 0) + k) % buffer.size()] += jingle * amp
