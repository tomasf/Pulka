class_name MusicComposer
extends RefCounted
## Renders the game's tunes from code: a winter humppa, a minor-key polska in
## 3/4, a driving arpeggio track and a sleigh-bell boogie. Instruments are
## filtered, detuned oscillators with real envelopes, mixed into a small room
## reverb, so the result sounds played rather than beeped. Runs on worker
## threads (and is pre-rendered for the web build).

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

enum Wave { SINE, TRIANGLE, SQUARE, SAW, WARM }


## How one instrument sounds: oscillator, envelope, filter and chorus.
class Voice:
	var wave := Wave.SINE
	var attack := 0.01
	## Exponential fall from the peak towards `sustain`, per second.
	var decay := 3.0
	var sustain := 0.0
	var release := 0.05
	## One-pole low-pass cutoff in Hz; 0 leaves the tone unfiltered.
	var cutoff := 0.0
	## Second oscillator detuned by this ratio, for a chorused, wider tone.
	var detune := 0.0
	var vibrato := false

	func _init(shape: Wave, attack_time: float, decay_rate: float, sustain_level: float, release_time: float, cutoff_hz := 0.0, detune_ratio := 0.0, wobble := false) -> void:
		wave = shape
		attack = attack_time
		decay = decay_rate
		sustain = sustain_level
		release = release_time
		cutoff = cutoff_hz
		detune = detune_ratio
		vibrato = wobble

	## Soft flute/organ-like lead with chorus and delayed vibrato.
	static func lead() -> Voice:
		return Voice.new(Wave.WARM, 0.02, 2.2, 0.55, 0.12, 0.0, 0.004, true)

	## Reedy accordion or harmonica: detuned saws through a soft filter.
	static func reed(cutoff_hz := 2200.0) -> Voice:
		return Voice.new(Wave.SAW, 0.015, 1.5, 0.7, 0.08, cutoff_hz, 0.006, true)

	## Short accordion "pah" on the off-beat.
	static func stab() -> Voice:
		return Voice.new(Wave.SAW, 0.006, 7.0, 0.15, 0.05, 1600.0, 0.005)

	## Slow, dark chord bed under everything.
	static func pad() -> Voice:
		return Voice.new(Wave.SAW, 0.3, 0.4, 0.75, 0.4, 750.0, 0.008)

	## Round plucked bass: triangle with a soft decay.
	static func bass() -> Voice:
		return Voice.new(Wave.TRIANGLE, 0.005, 4.0, 0.25, 0.06, 900.0)

	static func sub() -> Voice:
		return Voice.new(Wave.SINE, 0.005, 3.0, 0.3, 0.06)

	## Gentle music-box arpeggio.
	static func bell() -> Voice:
		return Voice.new(Wave.TRIANGLE, 0.003, 9.0, 0.0, 0.05, 2600.0)

const SONG_COUNT := 7

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

## G major schottis, sixteenth-note grid (16 per bar).
const SCHOTTIS_CHORDS := [
	[43, false], [36, false], [38, false], [43, false], [43, false], [40, true], [38, false], [43, false],
	[36, false], [43, false], [45, true], [38, false], [36, false], [43, false], [38, false], [43, false],
]
const SCHOTTIS_MELODY := [
	[74, 3], [71, 1], [74, 3], [79, 1], [78, 4], [74, 4],
	[76, 3], [72, 1], [76, 3], [79, 1], [84, 4], [79, 4],
	[78, 3], [74, 1], [78, 3], [81, 1], [84, 3], [81, 1], [78, 4],
	[79, 6], [78, 2], [79, 8],
	[74, 3], [71, 1], [74, 3], [79, 1], [83, 4], [79, 4],
	[76, 3], [79, 1], [83, 3], [88, 1], [86, 4], [83, 4],
	[81, 3], [79, 1], [78, 3], [76, 1], [74, 4], [78, 4],
	[79, 8], [-1, 8],
	[84, 3], [83, 1], [81, 3], [79, 1], [76, 4], [79, 4],
	[83, 3], [81, 1], [79, 3], [78, 1], [79, 4], [74, 4],
	[76, 3], [79, 1], [81, 3], [84, 1], [83, 4], [81, 4],
	[78, 3], [81, 1], [86, 3], [84, 1], [81, 4], [78, 4],
	[79, 3], [76, 1], [72, 3], [76, 1], [79, 4], [84, 4],
	[83, 3], [79, 1], [74, 3], [79, 1], [83, 4], [86, 4],
	[84, 3], [83, 1], [81, 3], [78, 1], [74, 4], [76, 2], [78, 2],
	[79, 12], [-1, 4],
]

## D major fast waltz, six eighths per bar.
const WALTZ_CHORDS := [
	[38, false], [38, false], [45, false], [45, false], [43, false], [38, false], [45, false], [38, false],
	[35, true], [43, false], [38, false], [45, false], [43, false], [38, false], [45, false], [38, false],
]
const WALTZ_MELODY := [
	[74, 2], [78, 2], [81, 2], [86, 4], [81, 2], [81, 2], [79, 2], [76, 2], [73, 4], [76, 2],
	[79, 2], [83, 2], [86, 2], [86, 4], [78, 2], [76, 2], [79, 2], [85, 2], [86, 4], [-1, 2],
	[83, 2], [78, 2], [74, 2], [79, 4], [83, 2], [81, 2], [78, 2], [74, 2], [76, 4], [73, 2],
	[71, 2], [74, 2], [79, 2], [78, 2], [81, 2], [86, 2], [85, 2], [83, 2], [79, 2], [86, 6],
]

## A minor storm, eight eighths per bar.
const STORM_CHORDS := [
	[45, true], [41, false], [36, false], [43, false], [45, true], [41, false], [40, false], [45, true],
	[38, true], [45, true], [41, false], [43, false], [45, true], [41, false], [40, false], [45, true],
]
const STORM_MELODY := [
	[76, 1], [76, 1], [72, 1], [76, 1], [79, 2], [76, 2],
	[77, 1], [76, 1], [74, 1], [72, 1], [69, 4],
	[72, 1], [76, 1], [79, 1], [84, 1], [83, 2], [79, 2],
	[79, 2], [77, 2], [74, 4],
	[81, 1], [81, 1], [79, 1], [77, 1], [76, 2], [72, 2],
	[74, 1], [76, 1], [77, 1], [81, 1], [84, 4],
	[83, 1], [80, 1], [76, 1], [80, 1], [83, 2], [86, 2],
	[81, 6], [-1, 2],
	[77, 1], [81, 1], [86, 1], [81, 1], [77, 2], [74, 2],
	[76, 1], [72, 1], [76, 1], [81, 1], [79, 2], [76, 2],
	[77, 2], [76, 1], [74, 1], [72, 2], [77, 2],
	[79, 2], [83, 2], [86, 4],
	[88, 1], [86, 1], [84, 1], [83, 1], [81, 2], [76, 2],
	[77, 1], [81, 1], [84, 1], [81, 1], [77, 4],
	[76, 2], [80, 2], [83, 2], [88, 2],
	[81, 4], [-1, 4],
]

## A major 12-bar blues, played twice.
const BOOGIE_CHORDS := [45, 45, 45, 45, 38, 38, 45, 45, 40, 38, 45, 40]


static func title(index: int) -> String:
	return ["Humppa i backen", "Polska på isen", "Fartvind", "Bjällerboogie", "Schottis i spåret", "Kälkvals", "Snöstormen"][index % SONG_COUNT]


static func render(index: int) -> AudioStreamWAV:
	match index % SONG_COUNT:
		1:
			return _polska()
		2:
			return _arpeggios()
		3:
			return _boogie()
		4:
			return _schottis()
		5:
			return _waltz()
		6:
			return _storm()
		_:
			return _humppa()


static func _buffer(seconds: float) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(int(seconds * RATE))
	return buffer


static func _finish(buffer: PackedFloat32Array, room := 0.22) -> AudioStreamWAV:
	_reverb(buffer, room)
	var peak := 0.001
	for sample in buffer:
		peak = maxf(peak, absf(sample))
	var gain := 0.85 / peak
	for i in buffer.size():
		# Gentle tape-style saturation keeps peaks round.
		buffer[i] = tanh(buffer[i] * gain * 1.15) / tanh(1.15)
	return Synth.to_stream(buffer)


static func _melody(buffer: PackedFloat32Array, notes: Array, step: float, amp: float, voice: Voice, transpose := 0, legato := 0.95) -> void:
	var position := 0.0
	for note: Array in notes:
		var pitch: int = note[0]
		var length: int = note[1]
		if pitch >= 0:
			_note(buffer, position * step, length * step * legato, pitch + transpose, amp, voice)
		position += length


## Holds a chord for `length` seconds on the pad voice.
static func _chord(buffer: PackedFloat32Array, start: float, length: float, root: int, minor: bool, amp: float, voice: Voice) -> void:
	for interval in [0, 3 if minor else 4, 7]:
		_note(buffer, start, length, root + interval, amp, voice)


## Oom-pah bass, accordion stabs, a soft pad, sleigh bells and a flute lead.
static func _humppa() -> AudioStreamWAV:
	var eighth := 60.0 / BPM / 2.0
	var bar := eighth * 8.0
	var buffer := _buffer(bar * CHORDS.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	for index in CHORDS.size():
		var chord: Array = CHORDS[index]
		var root: int = chord[0]
		var minor: bool = chord[1]
		var third := 3 if minor else 4
		_chord(buffer, index * bar, bar, root + 24, minor, 0.03, Voice.pad())
		for beat in 4:
			var t := index * bar + beat * eighth * 2.0
			var bass := root if beat % 2 == 0 else root + 7
			_note(buffer, t, eighth * 1.7, bass, 0.32, Voice.bass())
			_note(buffer, t, eighth * 1.5, bass, 0.18, Voice.sub())
			for interval in [12, 12 + third, 19]:
				_note(buffer, t + eighth, eighth * 0.8, root + interval + 12, 0.05, Voice.stab())
			if beat % 2 == 0:
				_kick(buffer, t)
			else:
				_snare(buffer, t, rng)
			_bells(buffer, t, 0.045, rng)
			_bells(buffer, t + eighth, 0.025, rng)
	_melody(buffer, MELODY, eighth, 0.16, Voice.lead())
	_melody(buffer, MELODY, eighth, 0.035, Voice.reed(1800.0), -12)
	return _finish(buffer, 0.24)


## Swedish polska in 3/4 with an accordion lead.
static func _polska() -> AudioStreamWAV:
	var eighth := 60.0 / 150.0 / 2.0
	var bar := eighth * 6.0
	var buffer := _buffer(bar * POLSKA_CHORDS.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for index in POLSKA_CHORDS.size():
		var chord: Array = POLSKA_CHORDS[index]
		var root: int = chord[0]
		var minor: bool = chord[1]
		var third := 3 if minor else 4
		var t := index * bar
		_chord(buffer, t, bar, root + 24, minor, 0.03, Voice.pad())
		_note(buffer, t, eighth * 1.8, root, 0.34, Voice.bass())
		_note(buffer, t, eighth * 1.6, root, 0.16, Voice.sub())
		_kick(buffer, t)
		for beat in [1, 2]:
			for interval in [12, 12 + third, 19]:
				_note(buffer, t + beat * eighth * 2.0, eighth * 1.2, root + interval + 12, 0.05, Voice.stab())
		_snare(buffer, t + eighth * 4.0, rng)
		for k in 6:
			_bells(buffer, t + k * eighth, 0.035 if k % 2 == 0 else 0.02, rng)
	_melody(buffer, POLSKA_MELODY, eighth, 0.12, Voice.reed(2600.0), 0, 0.98)
	_melody(buffer, POLSKA_MELODY, eighth, 0.06, Voice.lead(), -12)
	return _finish(buffer, 0.28)


## Four-on-the-floor with music-box arpeggios, a wide pad and a soaring lead.
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
		_chord(buffer, t, bar, root + 24, minor, 0.04, Voice.pad())
		for step in 16:
			var interval: int = pattern[step % pattern.size()]
			if minor and interval == 16:
				interval -= 1
			_note(buffer, t + step * sixteenth, sixteenth * 1.6, root + 36 + interval, 0.06, Voice.bell())
			if step % 2 == 0:
				var octave := 12 if step % 4 == 2 else 0
				_note(buffer, t + step * sixteenth, sixteenth * 1.8, root + octave, 0.3, Voice.bass())
			if step % 4 == 0:
				_kick(buffer, t + step * sixteenth)
				_note(buffer, t + step * sixteenth, sixteenth * 3.0, root, 0.12, Voice.sub())
			if step % 8 == 4:
				_snare(buffer, t + step * sixteenth, rng)
			if step % 4 == 2:
				_bells(buffer, t + step * sixteenth, 0.03, rng)
		var third := 3 if minor else 4
		var lead_a := root + 36 + third + (12 if index >= 8 else 0)
		var lead_b := root + 36 + 7 + (12 if index >= 8 else 0)
		_note(buffer, t, bar * 0.48, lead_a, 0.12, Voice.lead())
		_note(buffer, t + bar * 0.5, bar * 0.48, lead_b if index % 2 == 0 else lead_a + 2, 0.12, Voice.lead())
	return _finish(buffer, 0.32)


## Shuffled boogie-woogie with walking bass, harmonica and sleigh bells.
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
			_chord(buffer, t, bar, root + 24, false, 0.025, Voice.pad())
			for k in 8:
				var swung := t + floorf(k / 2.0) * beat + (beat * 2.0 / 3.0 if k % 2 == 1 else 0.0)
				_note(buffer, swung, beat * 0.55, root + walk[k], 0.3, Voice.bass())
				_bells(buffer, swung, 0.03 if k % 2 == 0 else 0.02, rng)
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
				_note(buffer, swung_start, length * beat * 0.5, root + 24 + int(note[0]), 0.11, Voice.reed(2000.0))
				position += length
	return _finish(buffer, 0.2)


## Schottis: oom on beats one and three, chords on two and four, a reedy
## accordion lead with the dotted lilt, and a flute an octave below.
static func _schottis() -> AudioStreamWAV:
	var sixteenth := 60.0 / 148.0 / 4.0
	var bar := sixteenth * 16.0
	var buffer := _buffer(bar * SCHOTTIS_CHORDS.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	for index in SCHOTTIS_CHORDS.size():
		var chord: Array = SCHOTTIS_CHORDS[index]
		var root: int = chord[0]
		var minor: bool = chord[1]
		var third := 3 if minor else 4
		var t := index * bar
		_chord(buffer, t, bar, root + 24, minor, 0.025, Voice.pad())
		for beat in 4:
			var at := t + beat * sixteenth * 4.0
			if beat % 2 == 0:
				_note(buffer, at, sixteenth * 3.5, root if beat == 0 else root + 7, 0.32, Voice.bass())
				_note(buffer, at, sixteenth * 3.0, root, 0.14, Voice.sub())
				_kick(buffer, at)
			else:
				for interval in [12, 12 + third, 19]:
					_note(buffer, at, sixteenth * 2.5, root + interval + 12, 0.05, Voice.stab())
				_snare(buffer, at, rng)
			_bells(buffer, at, 0.03, rng)
			_bells(buffer, at + sixteenth * 3.0, 0.02, rng)
	_melody(buffer, SCHOTTIS_MELODY, sixteenth, 0.12, Voice.reed(2400.0), 0, 0.97)
	_melody(buffer, SCHOTTIS_MELODY, sixteenth, 0.05, Voice.lead(), -12)
	return _finish(buffer, 0.26)


## A quick sledding waltz: bass on one, chords on two and three, a flute
## lead over a music-box ostinato.
static func _waltz() -> AudioStreamWAV:
	var eighth := 60.0 / 176.0 / 2.0
	var bar := eighth * 6.0
	var buffer := _buffer(bar * WALTZ_CHORDS.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = 47
	for index in WALTZ_CHORDS.size():
		var chord: Array = WALTZ_CHORDS[index]
		var root: int = chord[0]
		var minor: bool = chord[1]
		var third := 3 if minor else 4
		var t := index * bar
		_chord(buffer, t, bar, root + 24, minor, 0.03, Voice.pad())
		_note(buffer, t, eighth * 1.9, root, 0.32, Voice.bass())
		_note(buffer, t, eighth * 1.6, root, 0.15, Voice.sub())
		_kick(buffer, t)
		for beat in [1, 2]:
			for interval in [12, 12 + third, 19]:
				_note(buffer, t + beat * eighth * 2.0, eighth * 1.3, root + interval + 12, 0.04, Voice.stab())
		for k in 6:
			var arp: int = [0, third, 7, 12, 7, third][k]
			_note(buffer, t + k * eighth, eighth * 1.5, root + 36 + arp, 0.035, Voice.bell())
			_bells(buffer, t + k * eighth, 0.02, rng)
	_melody(buffer, WALTZ_MELODY, eighth, 0.15, Voice.lead(), 0, 0.97)
	return _finish(buffer, 0.3)


## Driving minor-key storm: pumping octave bass, four on the floor, a
## harmonica lead and a pad that swells underneath.
static func _storm() -> AudioStreamWAV:
	var eighth := 60.0 / 162.0 / 2.0
	var bar := eighth * 8.0
	var buffer := _buffer(bar * STORM_CHORDS.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = 53
	for index in STORM_CHORDS.size():
		var chord: Array = STORM_CHORDS[index]
		var root: int = chord[0]
		var minor: bool = chord[1]
		var third := 3 if minor else 4
		var t := index * bar
		_chord(buffer, t, bar, root + 24, minor, 0.04, Voice.pad())
		for k in 8:
			var at := t + k * eighth
			_note(buffer, at, eighth * 0.9, root + (12 if k % 2 == 1 else 0), 0.26, Voice.bass())
			if k % 2 == 0:
				_kick(buffer, at)
			if k % 4 == 2:
				_snare(buffer, at, rng)
			_bells(buffer, at, 0.025, rng)
			var arp: int = [0, 7, 12, third + 12][k % 4]
			_note(buffer, at, eighth * 0.8, root + 36 + arp, 0.03, Voice.bell())
	_melody(buffer, STORM_MELODY, eighth, 0.13, Voice.reed(2100.0), 0, 0.96)
	_melody(buffer, STORM_MELODY, eighth, 0.04, Voice.lead(), 12)
	return _finish(buffer, 0.28)


static func _freq(midi: int) -> float:
	return 440.0 * pow(2.0, (midi - 69) / 12.0)


## Adds one note to the buffer (wrapping at the end, so loops stay seamless).
static func _note(buffer: PackedFloat32Array, start: float, length: float, midi: int, amp: float, voice: Voice) -> void:
	# A player is never machine-exact: nudge timing (±6 ms) and loudness (±12 %).
	var jitter := hash(Vector2(start, midi))
	start += ((jitter & 0xFF) / 255.0 - 0.5) * 0.012
	amp *= 0.88 + (((jitter >> 8) & 0xFF) / 255.0) * 0.24
	var first := maxi(int(start * RATE), 0)
	var held := int(length * RATE)
	var tail := int(voice.release * RATE)
	var size := buffer.size()
	var step := _freq(midi) / RATE
	var phase_a := 0.0
	var phase_b := 0.37
	var low := 0.0
	var smoothing := 1.0 - exp(-TAU * voice.cutoff / RATE) if voice.cutoff > 0.0 else 1.0
	var level := 0.0
	for k in held + tail:
		var t := float(k) / RATE
		if k < held:
			level = minf(1.0, t / voice.attack) * (voice.sustain + (1.0 - voice.sustain) * exp(-t * voice.decay))
		else:
			level *= 1.0 - 1.0 / maxf(tail, 1.0) * 4.0 if level > 0.0001 else 0.0
		var wobble := 1.0 + 0.005 * sin(t * TAU * 5.2) * smoothstep(0.15, 0.4, t) if voice.vibrato else 1.0
		var s := _oscillate(voice.wave, phase_a)
		if voice.detune > 0.0:
			s = (s + _oscillate(voice.wave, phase_b)) * 0.5
			phase_b = fmod(phase_b + step * (1.0 + voice.detune) * wobble, 1.0)
		phase_a = fmod(phase_a + step * wobble, 1.0)
		low += smoothing * (s - low)
		buffer[(first + k) % size] += low * level * amp


static func _oscillate(wave: Wave, phase: float) -> float:
	match wave:
		Wave.TRIANGLE:
			return 4.0 * absf(phase - 0.5) - 1.0
		Wave.SQUARE:
			return 1.0 if phase < 0.5 else -1.0
		Wave.SAW:
			return 2.0 * phase - 1.0
		Wave.WARM:
			var p := phase * TAU
			return sin(p) + 0.32 * sin(2.0 * p) + 0.12 * sin(3.0 * p)
	return sin(phase * TAU)


## A small Schroeder room (four damped combs into two all-passes). The buffer
## is processed twice so the tail wraps into the start and loops seamlessly.
## All delay lines share one flat array (packed arrays copy on write).
static func _reverb(buffer: PackedFloat32Array, wet: float) -> void:
	var lengths := PackedInt32Array([557, 593, 641, 677, 277, 211])
	var offsets := PackedInt32Array()
	var total := 0
	for length in lengths:
		offsets.append(total)
		total += length
	var lines := PackedFloat32Array()
	lines.resize(total)
	var heads := PackedInt32Array([0, 0, 0, 0, 0, 0])
	var damped := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	var dry := buffer.duplicate()
	var size := buffer.size()
	for round in 2:
		for i in size:
			var input := dry[i] * 0.25
			var out := 0.0
			for c in 4:
				var at := offsets[c] + heads[c]
				var delayed := lines[at]
				damped[c] = delayed * 0.7 + damped[c] * 0.3
				lines[at] = input + damped[c] * 0.8
				heads[c] = (heads[c] + 1) % lengths[c]
				out += delayed
			for a in range(4, 6):
				var at := offsets[a] + heads[a]
				var delayed := lines[at]
				lines[at] = out + delayed * 0.5
				out = delayed - out * 0.5
				heads[a] = (heads[a] + 1) % lengths[a]
			if round == 1:
				buffer[i] = dry[i] + out * wet


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
		buffer[(maxi(first, 0) + k) % buffer.size()] += jingle * amp * 0.65
