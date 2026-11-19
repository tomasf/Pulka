class_name MusicComposer
extends RefCounted
## Renders the game's tunes from code: folk dances (humppa, polska, schottis,
## waltz), a boogie and a storm, plus modern tracks (synthwave, drum'n'bass,
## chiptune and house). Each song is arranged from parts (intro, themes, a
## B part, a breakdown, a key-changed finale, an ending) that switch layers
## in and out, with fills, cymbals and risers between them. Instruments are
## filtered, detuned oscillators with real envelopes, mixed into a small room
## reverb, so the result sounds played rather than beeped. Runs on worker
## threads (and is pre-rendered for the exports).

const RATE := 22050
const BPM := 156.0
## Room after the last bar for the final chord and reverb to ring out.
const TAIL := 2.5

## Layers a part can switch on; each song decides what they mean for it.
const DRUMS := 1
const BASS := 2
## Chord comping: off-beat stabs, piano.
const COMP := 4
const PAD := 8
const BELLS := 16
const ARP := 32
const LEAD := 64
## The lead with a second voice a diatonic third below.
const HARMONY := 128
## A snare fill at the end of the part.
const FILL := 256
## A cymbal on the part's first beat.
const CRASH := 512
## Sparse drums (a breakdown or an intro).
const HALF := 1024
## A noise swell over the part's last two bars.
const RISE := 2048
## The part's last bar is the song's final chord.
const END := 4096

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

	## Short bright pluck for arpeggios and house riffs.
	static func pluck() -> Voice:
		return Voice.new(Wave.SAW, 0.002, 8.0, 0.0, 0.12, 2400.0, 0.005)

	## Wide detuned saw lead.
	static func supersaw() -> Voice:
		return Voice.new(Wave.SAW, 0.012, 1.0, 0.75, 0.25, 3400.0, 0.012)

	## Slow, wide, airy pad.
	static func wide() -> Voice:
		return Voice.new(Wave.SAW, 0.45, 0.3, 0.8, 0.6, 1300.0, 0.014)

	## Punchy filtered saw bass.
	static func saw_bass() -> Voice:
		return Voice.new(Wave.SAW, 0.004, 5.0, 0.35, 0.05, 700.0, 0.004)

	## Growling, slowly beating drum'n'bass bass.
	static func reese() -> Voice:
		return Voice.new(Wave.SAW, 0.01, 0.2, 0.9, 0.08, 420.0, 0.012)

	## Electric piano.
	static func keys() -> Voice:
		return Voice.new(Wave.WARM, 0.003, 4.5, 0.18, 0.2, 3200.0, 0.003)

	## Square-wave lead, like an old game console.
	static func chip() -> Voice:
		return Voice.new(Wave.SQUARE, 0.002, 1.2, 0.55, 0.03, 4200.0, 0.0, true)

	## Very short square blips for fast arpeggios.
	static func chip_arp() -> Voice:
		return Voice.new(Wave.SQUARE, 0.001, 14.0, 0.0, 0.01, 3600.0)

	## Plain triangle bass.
	static func chip_bass() -> Voice:
		return Voice.new(Wave.TRIANGLE, 0.002, 1.5, 0.7, 0.02)


## One part of a song: how many bars, the chords (repeating if shorter), the
## melody (in the song's steps, from the part's start), which layers play,
## a transposition and which of the song's lead sounds to use.
class Part:
	var bars := 0
	var chords: Array = []
	var melody: Array = []
	var layers := 0
	var shift := 0
	var lead := 0

	func _init(bar_count: int, chord_list: Array, notes: Array, layer_mask: int, semitones := 0, lead_variant := 0) -> void:
		bars = bar_count
		chords = chord_list
		melody = notes
		layers = layer_mask
		shift = semitones
		lead = lead_variant

	func has(layer: int) -> bool:
		return (layers & layer) != 0


## A song being rendered: its timing, key, lead sounds and buffers.
class Song:
	var buffer := PackedFloat32Array()
	## Layers ducked by every kick (sidechain pumping), mixed in at the end.
	var pumped := PackedFloat32Array()
	var pumping := false
	var kicks := PackedFloat32Array()
	var beat := 0.0
	## The grid the melodies are written in (eighths or sixteenths).
	var step := 0.0
	var bar := 0.0
	## Tonic pitch class and mode, for harmonies.
	var key := 0
	var minor := false
	## Per lead variant: voices as [Voice, amp, octave shift, legato, delay in steps].
	var leads: Array = []
	var rng := RandomNumberGenerator.new()

	func _init(bpm: float, steps_per_beat: int, beats: int, key_class: int, minor_key: bool, seed_value: int) -> void:
		beat = 60.0 / bpm
		step = beat / steps_per_beat
		bar = beat * beats
		key = key_class
		minor = minor_key
		rng.seed = seed_value


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

## Humppa B part, G major's relative minor side: Em C G D | Em C D D.
const HUMPPA_B_CHORDS := [
	[40, true], [36, false], [43, false], [38, false], [40, true], [36, false], [38, false], [38, false],
]
const HUMPPA_B := [
	[71, 2], [74, 1], [76, 1], [79, 2], [76, 2],
	[72, 1], [76, 1], [79, 1], [84, 1], [83, 2], [79, 2],
	[74, 2], [79, 2], [83, 3], [81, 1],
	[78, 4], [74, 2], [-1, 2],
	[76, 1], [79, 1], [83, 1], [79, 1], [88, 2], [86, 2],
	[84, 1], [83, 1], [81, 1], [79, 1], [76, 2], [72, 2],
	[74, 1], [78, 1], [81, 1], [84, 1], [86, 2], [84, 1], [81, 1],
	[78, 3], [-1, 1], [74, 1], [76, 1], [78, 1], [81, 1],
]

## Polska B part in the relative major, back via B major: G D Em B | C G B B.
const POLSKA_B_CHORDS := [
	[43, false], [38, false], [40, true], [35, false], [36, false], [43, false], [35, false], [35, false],
]
const POLSKA_B := [
	[79, 2], [83, 1], [86, 1], [83, 2],
	[81, 1], [78, 1], [74, 1], [78, 1], [81, 2],
	[79, 1], [76, 1], [71, 1], [76, 1], [79, 1], [83, 1],
	[78, 3], [75, 1], [71, 2],
	[76, 1], [79, 1], [84, 1], [79, 1], [76, 1], [72, 1],
	[74, 2], [79, 2], [83, 2],
	[81, 1], [78, 1], [75, 1], [78, 1], [81, 1], [83, 1],
	[78, 4], [-1, 2],
]

## Fartvind's second theme: Bm G D A | Bm G A A.
const FARTVIND_B_CHORDS := [
	[35, true], [43, false], [38, false], [45, false], [35, true], [43, false], [45, false], [45, false],
]

## Boogie riffs for the later choruses (semitones above the root, in eighths).
const BOOGIE_RIFF_C := [[24, 1], [22, 1], [19, 1], [16, 1], [19, 2], [12, 2]]
const BOOGIE_RIFF_D := [[15, 1], [16, 1], [19, 1], [21, 1], [22, 2], [21, 1], [19, 1]]

## Schottis B part: Em C D G | Em Am D D, with the same dotted lilt.
const SCHOTTIS_B_CHORDS := [
	[40, true], [36, false], [38, false], [43, false], [40, true], [45, true], [38, false], [38, false],
]
const SCHOTTIS_B := [
	[76, 3], [71, 1], [76, 3], [79, 1], [83, 4], [79, 4],
	[76, 3], [72, 1], [76, 3], [79, 1], [84, 4], [76, 4],
	[78, 3], [74, 1], [78, 3], [81, 1], [86, 4], [81, 4],
	[83, 6], [81, 2], [79, 8],
	[83, 3], [79, 1], [76, 3], [79, 1], [83, 4], [88, 4],
	[84, 3], [81, 1], [76, 3], [81, 1], [84, 4], [81, 4],
	[78, 3], [81, 1], [84, 3], [81, 1], [78, 4], [74, 4],
	[81, 8], [-1, 4], [74, 2], [78, 2],
]

## Waltz B part: Bm G D A | Bm Em A A.
const WALTZ_B_CHORDS := [
	[35, true], [43, false], [38, false], [45, false], [35, true], [40, true], [45, false], [45, false],
]
const WALTZ_B := [
	[78, 2], [81, 2], [83, 2],
	[83, 4], [79, 2],
	[78, 2], [81, 2], [86, 2],
	[85, 4], [-1, 2],
	[83, 2], [86, 2], [83, 2],
	[79, 4], [76, 2],
	[73, 2], [76, 2], [79, 2],
	[81, 4], [-1, 2],
]

## Storm B part: F G Em Am | Dm F E E.
const STORM_B_CHORDS := [
	[41, false], [43, false], [40, true], [45, true], [38, true], [41, false], [40, false], [40, false],
]
const STORM_B := [
	[77, 1], [81, 1], [84, 1], [81, 1], [89, 2], [84, 2],
	[83, 1], [79, 1], [74, 1], [79, 1], [83, 2], [86, 2],
	[83, 2], [79, 2], [76, 2], [79, 2],
	[81, 4], [76, 2], [72, 2],
	[74, 1], [77, 1], [81, 1], [86, 1], [84, 2], [81, 2],
	[84, 1], [81, 1], [77, 1], [81, 1], [84, 2], [89, 2],
	[88, 2], [86, 1], [83, 1], [80, 2], [76, 2],
	[80, 3], [-1, 1], [76, 1], [80, 1], [83, 1], [86, 1],
]

## Nordljus, synthwave in A minor (sixteenths): Am F C G.
const NORDLJUS_CHORDS := [[45, true], [41, false], [36, false], [43, false]]
const NORDLJUS_A := [
	[76, 6], [74, 2], [72, 4], [69, 4],
	[72, 8], [69, 4], [72, 4],
	[79, 6], [76, 2], [74, 4], [72, 4],
	[74, 12], [-1, 4],
	[76, 6], [74, 2], [72, 4], [76, 4],
	[81, 8], [79, 4], [77, 4],
	[76, 6], [74, 2], [72, 4], [74, 4],
	[71, 8], [74, 4], [79, 4],
]
## F G Am Am | F G C E.
const NORDLJUS_B_CHORDS := [
	[41, false], [43, false], [45, true], [45, true], [41, false], [43, false], [36, false], [40, false],
]
const NORDLJUS_B := [
	[77, 4], [76, 4], [72, 8],
	[74, 4], [76, 4], [79, 8],
	[81, 12], [79, 2], [76, 2],
	[76, 16],
	[77, 4], [81, 4], [84, 8],
	[83, 4], [81, 4], [79, 8],
	[79, 6], [76, 2], [72, 8],
	[80, 8], [83, 4], [76, 4],
]

## Pulkaraketen, liquid drum'n'bass in D minor (sixteenths): Dm Bb F C.
const PULKA_CHORDS := [[38, true], [34, false], [41, false], [36, false]]
const PULKA_A := [
	[74, 2], [77, 2], [81, 4], [79, 2], [77, 2], [76, 2], [74, 2],
	[77, 4], [74, 4], [70, 8],
	[72, 2], [77, 2], [81, 4], [84, 4], [81, 4],
	[79, 8], [76, 4], [72, 4],
	[74, 2], [77, 2], [81, 4], [86, 4], [84, 2], [81, 2],
	[82, 4], [81, 4], [77, 8],
	[77, 2], [81, 2], [84, 4], [81, 4], [77, 4],
	[79, 12], [-1, 4],
]
## Gm Bb A A, twice.
const PULKA_B_CHORDS := [[43, true], [34, false], [45, false], [45, false]]
const PULKA_B := [
	[79, 4], [82, 4], [86, 8],
	[86, 4], [84, 4], [82, 8],
	[81, 4], [85, 4], [88, 8],
	[88, 8], [85, 4], [81, 4],
	[79, 4], [82, 4], [86, 4], [84, 4],
	[82, 4], [86, 4], [89, 8],
	[88, 6], [86, 2], [85, 8],
	[81, 16],
]

## Snöbollskrig, chiptune in C major (sixteenths): C Am F G | C Am Dm G.
const SNO_CHORDS := [
	[36, false], [45, true], [41, false], [43, false], [36, false], [45, true], [38, true], [43, false],
]
const SNO_A := [
	[72, 2], [76, 2], [79, 2], [84, 2], [83, 2], [79, 2], [76, 2], [79, 2],
	[81, 4], [76, 4], [72, 4], [76, 4],
	[77, 2], [81, 2], [84, 2], [81, 2], [77, 4], [72, 4],
	[79, 2], [83, 2], [86, 4], [84, 2], [83, 2], [81, 2], [79, 2],
	[72, 2], [76, 2], [79, 2], [84, 2], [88, 4], [84, 4],
	[84, 2], [83, 2], [81, 2], [76, 2], [81, 4], [84, 4],
	[86, 2], [84, 2], [81, 2], [77, 2], [74, 4], [77, 4],
	[79, 8], [-1, 4], [79, 2], [83, 2],
]
## F G Em Am | F G C C.
const SNO_B_CHORDS := [
	[41, false], [43, false], [40, true], [45, true], [41, false], [43, false], [36, false], [36, false],
]
const SNO_B := [
	[77, 1], [79, 1], [81, 1], [84, 1], [81, 2], [77, 2], [72, 4], [77, 4],
	[79, 1], [81, 1], [83, 1], [86, 1], [83, 2], [79, 2], [74, 4], [79, 4],
	[76, 1], [79, 1], [83, 1], [88, 1], [86, 2], [83, 2], [79, 4], [76, 4],
	[81, 8], [76, 4], [81, 4],
	[84, 4], [81, 4], [77, 4], [81, 4],
	[86, 4], [83, 4], [79, 4], [83, 4],
	[84, 2], [83, 2], [81, 2], [79, 2], [76, 2], [74, 2], [72, 4],
	[72, 8], [-1, 8],
]

## Pudersnö, house in F major (sixteenths): Bb C Am Dm.
const PUDER_CHORDS := [[34, false], [36, false], [33, true], [38, true]]
const PUDER_A := [
	[-1, 2], [77, 2], [-1, 1], [77, 1], [74, 2], [77, 2], [79, 2], [81, 4],
	[-1, 2], [79, 2], [-1, 1], [79, 1], [76, 2], [79, 2], [81, 2], [84, 4],
	[-1, 2], [81, 2], [-1, 1], [81, 1], [76, 2], [72, 2], [76, 2], [81, 4],
	[77, 6], [74, 2], [77, 4], [81, 4],
	[-1, 2], [82, 2], [-1, 1], [82, 1], [81, 2], [77, 2], [74, 2], [77, 4],
	[-1, 2], [84, 2], [-1, 1], [84, 1], [82, 2], [79, 2], [76, 2], [79, 4],
	[81, 4], [79, 2], [76, 2], [72, 4], [76, 4],
	[74, 12], [-1, 4],
]
## Gm Bb F C | Gm Bb C C.
const PUDER_B_CHORDS := [
	[31, true], [34, false], [41, false], [36, false], [31, true], [34, false], [36, false], [36, false],
]
const PUDER_B := [
	[79, 8], [82, 4], [86, 4],
	[86, 8], [84, 4], [82, 4],
	[81, 8], [77, 4], [81, 4],
	[79, 16],
	[79, 4], [82, 4], [86, 4], [89, 4],
	[89, 8], [86, 4], [82, 4],
	[84, 8], [88, 4], [91, 4],
	[88, 12], [-1, 4],
]


const SONG_COUNT := 11


static func title(index: int) -> String:
	return ["Humppa i backen", "Polska på isen", "Fartvind", "Bjällerboogie", "Schottis i spåret", "Kälkvals", "Snöstormen",
		"Nordljus", "Pulkaraketen", "Snöbollskrig", "Pudersnö"][index % SONG_COUNT]


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
		7:
			return _nordljus()
		8:
			return _pulkaraketen()
		9:
			return _snowball()
		10:
			return _powder()
		_:
			return _humppa()


## Snödag: a separate, unhurried 108 BPM menu arrangement in D major.
## Music-box answers, soft accordion offbeats and a round two-beat bass.
## Notes and room tails wrap at the bar boundary for a seamless loop.
static func render_menu() -> AudioStreamWAV:
	var eighth := 60.0 / 108.0 / 2.0
	var bar := eighth * 8.0
	var chords := [[50, false], [47, true], [43, false], [45, false],
		[50, false], [42, true], [43, false], [45, false],
		[47, true], [43, false], [50, false], [45, false],
		[43, false], [45, false], [50, false], [50, false]]
	var melody := [
		[[74, 2], [78, 1], [81, 1], [78, 2], [76, 2]],
		[[74, 3], [73, 1], [71, 2], [-1, 2]],
		[[71, 2], [74, 2], [79, 3], [78, 1]],
		[[76, 4], [73, 2], [-1, 2]],
		[[74, 2], [78, 1], [81, 1], [86, 2], [81, 2]],
		[[85, 2], [81, 2], [78, 3], [-1, 1]],
		[[79, 2], [78, 1], [76, 1], [74, 2], [71, 2]],
		[[73, 3], [76, 1], [74, 2], [-1, 2]],
		[[78, 2], [81, 2], [83, 3], [81, 1]],
		[[79, 3], [78, 1], [74, 4]],
		[[78, 2], [81, 2], [86, 2], [85, 2]],
		[[81, 4], [76, 2], [-1, 2]],
		[[79, 2], [78, 2], [74, 2], [71, 2]],
		[[73, 2], [76, 2], [81, 2], [79, 2]],
		[[78, 3], [76, 1], [74, 4]],
		[[81, 2], [78, 2], [74, 2], [-1, 2]],
	]
	var buffer := _buffer(bar * chords.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = 1082026
	var lead := Voice.new(Wave.WARM, 0.025, 3.8, 0.28, 0.18, 2400.0, 0.003)
	for i in chords.size():
		var root: int = chords[i][0]
		var minor: bool = chords[i][1]
		var t := i * bar
		_chord(buffer, t, bar, root + 12, minor, 0.032, Voice.pad())
		for beat in 4:
			if beat % 2 == 0:
				_note(buffer, t + beat * eighth * 2, eighth * 2.5, root - 12 if beat == 0 else root - 5, 0.20, Voice.bass())
			for interval in [0, 3 if minor else 4, 7]:
				_note(buffer, t + (beat * 2 + 1) * eighth, eighth * 0.7, root + interval + 12, 0.024, Voice.stab())
			_bells(buffer, t + beat * eighth * 2, 0.016 if beat % 2 == 0 else 0.009, rng)
		var tick := 0
		for note: Array in melody[i]:
			if note[0] >= 0:
				_note(buffer, t + tick * eighth, note[1] * eighth * 0.88, note[0], 0.11, lead)
				_note(buffer, t + tick * eighth, eighth * 0.8, note[0] + 12, 0.038, Voice.bell())
			tick += note[1]
	return _finish(buffer, 0.32)


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


## Plays `plan` part by part: `play_bar` renders one bar's backing
## (song, start time, chord root, minor, part, bar within the part), then the
## part's melody, fill, cymbal and riser are added.
static func _arrange(song: Song, plan: Array, play_bar: Callable, room: float) -> AudioStreamWAV:
	var total := 0
	for part: Part in plan:
		total += part.bars
	song.buffer = _buffer(total * song.bar + TAIL)
	if song.pumping:
		song.pumped = _buffer(total * song.bar + TAIL)
	var start := 0.0
	var bounds := PackedFloat32Array([0.0])
	for part: Part in plan:
		for b in part.bars:
			var chord: Array = part.chords[b % part.chords.size()]
			var root: int = chord[0] + part.shift
			var t := start + b * song.bar
			if part.has(END) and b == part.bars - 1:
				_ending(song, t, root, chord[1])
			else:
				play_bar.call(song, t, root, chord[1], part, b)
		if part.has(LEAD) and not part.melody.is_empty():
			_lead(song, part, start)
		if part.has(CRASH):
			_cymbal(song.buffer, start, 0.07, song.rng)
		if part.has(FILL):
			_fill(song, start + (part.bars - 1) * song.bar)
		if part.has(RISE):
			var span := mini(2, part.bars) * song.bar
			_riser(song.buffer, start + part.bars * song.bar - span, span, 0.1, song.rng)
		start += part.bars * song.bar
		bounds.append(start)
	_pump(song)
	_lift_quiet_parts(song.buffer, bounds)
	return _finish(song.buffer, room)


## Brings parts that are much quieter than the rest (a breakdown with only a
## pad, a sparse intro) up towards the song's level, so they still sound
## calmer but don't vanish under the wind. Gains glide across part borders.
static func _lift_quiet_parts(buffer: PackedFloat32Array, bounds: PackedFloat32Array) -> void:
	var levels := PackedFloat32Array()
	var peaks := PackedFloat32Array()
	var loudest := 0.0001
	for p in bounds.size() - 1:
		var first := int(bounds[p] * RATE)
		var last := mini(int(bounds[p + 1] * RATE), buffer.size())
		var sum := 0.0
		var peak := 0.0001
		for i in range(first, last, 4):
			sum += buffer[i] * buffer[i]
			peak = maxf(peak, absf(buffer[i]))
		levels.append(sqrt(sum / maxf((last - first) / 4.0, 1.0)))
		peaks.append(peak)
		loudest = maxf(loudest, peak)
	var sorted := levels.duplicate()
	sorted.sort()
	var target := sorted[sorted.size() / 2] * 0.6
	var gains := PackedFloat32Array()
	# Never so much that the part's peaks outgrow the rest of the song.
	for p in levels.size():
		gains.append(clampf(minf(target / maxf(levels[p], 0.0001), loudest * 0.9 / peaks[p]), 1.0, 3.0))
	# Glide inside the quieter part, so a loud entry is never boosted.
	var glide := 0.4 * RATE
	for p in levels.size():
		var first := int(bounds[p] * RATE)
		var last := mini(int(bounds[p + 1] * RATE), buffer.size())
		var before := minf(gains[p - 1] if p > 0 else gains[p], gains[p])
		var after := minf(gains[p + 1] if p + 1 < levels.size() else gains[p], gains[p])
		for i in range(first, last):
			var gain := lerpf(before, gains[p], smoothstep(0.0, 1.0, (i - first) / glide))
			gain = lerpf(after, gain, smoothstep(0.0, 1.0, (last - i) / glide))
			buffer[i] *= gain
	# The ending's tail keeps the last part's gain.
	for i in range(mini(int(bounds[bounds.size() - 1] * RATE), buffer.size()), buffer.size()):
		buffer[i] *= gains[levels.size() - 1]


## The part's melody on each of the song's voices for that lead variant.
static func _lead(song: Song, part: Part, start: float) -> void:
	var voices: Array = song.leads[part.lead % song.leads.size()]
	for voice: Array in voices:
		var delay: float = voice[4] if voice.size() > 4 else 0.0
		_melody(song.buffer, part.melody, start + delay * song.step, song.step, voice[1], voice[0], part.shift + int(voice[2]), voice[3])
	if part.has(HARMONY):
		var first: Array = voices[0]
		var steps := roundi(song.bar / song.step)
		_melody(song.buffer, _harmony(part.melody, song.key, song.minor, part.chords, steps), start, song.step, first[1] * 0.55, first[0], part.shift + int(first[2]), first[3])


## Mixes the pumped layers in, ducked after every kick.
static func _pump(song: Song) -> void:
	if song.pumped.is_empty():
		return
	var size := song.buffer.size()
	var gain := PackedFloat32Array()
	gain.resize(size)
	gain.fill(1.0)
	for kick in song.kicks:
		var first := int(kick * RATE)
		for k in int(0.4 * RATE):
			var t := float(k) / RATE
			var i := (first + k) % size
			gain[i] = minf(gain[i], 1.0 - 0.7 * smoothstep(0.0, 0.004, t) * exp(-t * 9.0))
	for i in size:
		song.buffer[i] += song.pumped[i] * gain[i]


## The final chord: held, with a last hit and a cymbal.
static func _ending(song: Song, t: float, root: int, minor: bool) -> void:
	_chord(song.buffer, t, song.bar * 1.6, root + 24, minor, 0.05, Voice.pad())
	_chord(song.buffer, t, song.bar, root + 36, minor, 0.03, Voice.bell())
	_note(song.buffer, t, song.bar * 1.4, root, 0.3, Voice.bass())
	_note(song.buffer, t, song.bar * 1.2, root, 0.18, Voice.sub())
	_kick(song.buffer, t)
	_cymbal(song.buffer, t, 0.07, song.rng)


## A snare roll over the bar's last beat, growing into the next part.
static func _fill(song: Song, bar_start: float) -> void:
	for i in 4:
		_snare(song.buffer, bar_start + song.bar - song.beat + i * song.beat / 4.0, song.rng, 0.45 + 0.2 * i)


static func _melody(buffer: PackedFloat32Array, notes: Array, start: float, step: float, amp: float, voice: Voice, transpose := 0, legato := 0.95) -> void:
	var position := 0.0
	for note: Array in notes:
		var pitch: int = note[0]
		var length: int = note[1]
		if pitch >= 0:
			_note(buffer, start + position * step, length * step * legato, pitch + transpose, amp, voice)
		position += length


## A second voice below the melody, like a choir's: under a chord tone it
## takes the next chord tone down; under a passing note it goes two steps
## down the key's scale as the bar's chord bends it (over B major in E minor
## it sings D#, not D). `chords` are per bar of `steps` melody steps; without
## them every note goes two steps down the plain key scale.
static func _harmony(notes: Array, key: int, minor: bool, chords := [], steps := 0) -> Array:
	var base := []
	for degree in ([0, 2, 3, 5, 7, 8, 10] if minor else [0, 2, 4, 5, 7, 9, 11]):
		base.append((key + degree) % 12)
	var out := []
	var position := 0
	for note: Array in notes:
		var pitch: int = note[0]
		if pitch >= 0:
			var scale := base
			var tones := []
			if not chords.is_empty() and steps > 0:
				var chord: Array = chords[(position / steps) % chords.size()]
				var root: int = chord[0]
				tones = [root % 12, (root + (3 if chord[1] else 4)) % 12, (root + 7) % 12]
				scale = _bent_scale(base, chord)
			var lower := pitch - 1
			if tones.has(pitch % 12):
				# On a chord tone: the next chord tone down, as a choir would.
				while not tones.has(lower % 12):
					lower -= 1
			else:
				# A passing note: two steps down the (bent) scale.
				var found := 1 if scale.has(lower % 12) else 0
				while found < 2:
					lower -= 1
					if scale.has(lower % 12):
						found += 1
			out.append([lower, note[1]])
		else:
			out.append(note)
		position += int(note[1])
	return out


## The scale's pitch classes with each of the chord's tones swapped in for
## the scale note a semitone from it.
static func _bent_scale(base: Array, chord: Array) -> Array:
	var scale := base.duplicate()
	var root: int = chord[0]
	for tone in [root % 12, (root + (3 if chord[1] else 4)) % 12, (root + 7) % 12]:
		if scale.has(tone):
			continue
		for neighbour in [(tone + 1) % 12, (tone + 11) % 12]:
			var at := scale.find(neighbour)
			if at >= 0:
				scale[at] = tone
				break
	return scale


## The first `length` steps of a melody played `factor` times slower.
static func _augment(notes: Array, length: int, factor: int) -> Array:
	var out := []
	var position := 0
	for note: Array in notes:
		if position >= length:
			break
		out.append([note[0], mini(int(note[1]), length - position) * factor])
		position += int(note[1])
	return out


## Each chord held for `factor` bars.
static func _stretch(chords: Array, factor: int) -> Array:
	var out := []
	for chord in chords:
		for i in factor:
			out.append(chord)
	return out


## Holds a chord for `length` seconds on the pad voice.
static func _chord(buffer: PackedFloat32Array, start: float, length: float, root: int, minor: bool, amp: float, voice: Voice) -> void:
	for interval in [0, 3 if minor else 4, 7]:
		_note(buffer, start, length, root + interval, amp, voice)


## Oom-pah bass, accordion stabs, a soft pad, sleigh bells and a flute lead.
## Theme twice (the second time on accordion with a harmony), a minor-side B
## part, a slow music-box breakdown and the theme a tone higher to finish.
static func _humppa() -> AudioStreamWAV:
	var song := Song.new(BPM, 2, 4, 7, false, 2024)
	song.leads = [
		[[Voice.lead(), 0.16, 0, 0.95], [Voice.reed(1800.0), 0.035, -12, 0.95]],
		[[Voice.reed(2400.0), 0.12, 0, 0.97], [Voice.lead(), 0.06, -12, 0.95]],
		[[Voice.lead(), 0.1, 0, 0.95], [Voice.bell(), 0.03, 12, 0.5]],
	]
	var full := DRUMS | BASS | COMP | PAD | BELLS
	var plan := [
		Part.new(4, CHORDS, [], DRUMS | BASS | COMP),
		Part.new(16, CHORDS, MELODY, full | LEAD | CRASH),
		Part.new(16, CHORDS, MELODY, full | LEAD | HARMONY, 0, 1),
		Part.new(8, HUMPPA_B_CHORDS, HUMPPA_B, full | LEAD | FILL),
		Part.new(8, _stretch(CHORDS.slice(0, 4), 2), _augment(MELODY, 32, 2), PAD | BELLS | BASS | HALF | LEAD | FILL, 0, 2),
		Part.new(16, CHORDS, MELODY, full | LEAD | HARMONY | CRASH, 2),
		Part.new(4, [[36, false], [38, false], [43, false], [43, false]], [], full | END, 2),
	]
	return _arrange(song, plan, func(s: Song, t: float, root: int, minor: bool, part: Part, _b: int) -> void:
		var e := s.step
		var third := 3 if minor else 4
		if part.has(PAD):
			_chord(s.buffer, t, s.bar, root + 24, minor, 0.03, Voice.pad())
		for beat in 4:
			var at := t + beat * e * 2.0
			if part.has(BASS):
				var bass := root if beat % 2 == 0 else root + 7
				_note(s.buffer, at, e * 1.7, bass, 0.32, Voice.bass())
				_note(s.buffer, at, e * 1.5, bass, 0.18, Voice.sub())
			if part.has(COMP):
				for interval in [12, 12 + third, 19]:
					_note(s.buffer, at + e, e * 0.8, root + interval + 12, 0.05, Voice.stab())
			if part.has(DRUMS):
				if beat % 2 == 0:
					_kick(s.buffer, at)
				else:
					_snare(s.buffer, at, s.rng)
			elif part.has(HALF) and beat == 0:
				_kick(s.buffer, at)
			if part.has(BELLS):
				_bells(s.buffer, at, 0.045, s.rng)
				_bells(s.buffer, at + e, 0.025, s.rng)
	, 0.24)


## Swedish polska in 3/4 with an accordion lead; a B part in the relative
## major and a slow breakdown before the last round.
static func _polska() -> AudioStreamWAV:
	var song := Song.new(150.0, 2, 3, 4, true, 77)
	song.leads = [
		[[Voice.reed(2600.0), 0.12, 0, 0.98], [Voice.lead(), 0.06, -12, 0.95]],
		[[Voice.lead(), 0.13, 0, 0.95], [Voice.reed(2600.0), 0.05, -12, 0.97]],
		[[Voice.lead(), 0.1, 0, 0.95], [Voice.bell(), 0.03, 12, 0.5]],
	]
	var full := DRUMS | BASS | COMP | PAD | BELLS
	var plan := [
		Part.new(4, POLSKA_CHORDS, [], DRUMS | BASS | COMP),
		Part.new(16, POLSKA_CHORDS, POLSKA_MELODY, full | LEAD | CRASH),
		Part.new(16, POLSKA_CHORDS, POLSKA_MELODY, full | LEAD | HARMONY, 0, 1),
		Part.new(8, POLSKA_B_CHORDS, POLSKA_B, full | LEAD | FILL),
		Part.new(8, _stretch(POLSKA_CHORDS.slice(0, 4), 2), _augment(POLSKA_MELODY, 24, 2), PAD | BELLS | BASS | HALF | LEAD | FILL, 0, 2),
		Part.new(16, POLSKA_CHORDS, POLSKA_MELODY, full | LEAD | HARMONY | CRASH),
		Part.new(4, [[45, true], [35, false], [40, true], [40, true]], [], full | END),
	]
	return _arrange(song, plan, func(s: Song, t: float, root: int, minor: bool, part: Part, _b: int) -> void:
		var e := s.step
		var third := 3 if minor else 4
		if part.has(PAD):
			_chord(s.buffer, t, s.bar, root + 24, minor, 0.03, Voice.pad())
		if part.has(BASS):
			_note(s.buffer, t, e * 1.8, root, 0.34, Voice.bass())
			_note(s.buffer, t, e * 1.6, root, 0.16, Voice.sub())
		if part.has(DRUMS):
			_kick(s.buffer, t)
			_snare(s.buffer, t + e * 4.0, s.rng)
		elif part.has(HALF):
			_kick(s.buffer, t)
		if part.has(COMP):
			for beat in [1, 2]:
				for interval in [12, 12 + third, 19]:
					_note(s.buffer, t + beat * e * 2.0, e * 1.2, root + interval + 12, 0.05, Voice.stab())
		if part.has(BELLS):
			for k in 6:
				_bells(s.buffer, t + k * e, 0.035 if k % 2 == 0 else 0.02, s.rng)
	, 0.28)


## Four-on-the-floor with music-box arpeggios, a wide pad and a soaring lead;
## a second theme on new chords, an arpeggio breakdown with a riser.
static func _arpeggios() -> AudioStreamWAV:
	var song := Song.new(140.0, 4, 4, 2, false, 5)
	var all := DRUMS | BASS | PAD | ARP | BELLS
	var plan := [
		Part.new(4, ARP_CHORDS, [], PAD | ARP | HALF),
		Part.new(16, ARP_CHORDS, [], all | LEAD | CRASH),
		Part.new(16, FARTVIND_B_CHORDS, [], all | LEAD | FILL, 0, 1),
		Part.new(8, ARP_CHORDS, [], PAD | ARP | RISE),
		Part.new(16, ARP_CHORDS, [], all | LEAD | HARMONY | CRASH),
		Part.new(4, [[43, false], [45, false], [38, false], [38, false]], [], all | END),
	]
	var pattern := [0, 7, 12, 16, 19, 16, 12, 7]
	return _arrange(song, plan, func(s: Song, t: float, root: int, minor: bool, part: Part, b: int) -> void:
		var sixteenth := s.step
		var third := 3 if minor else 4
		if part.has(PAD):
			_chord(s.buffer, t, s.bar, root + 24, minor, 0.04, Voice.pad())
		for step in 16:
			var at := t + step * sixteenth
			if part.has(ARP):
				var interval: int = pattern[step % pattern.size()]
				if minor and interval == 16:
					interval -= 1
				_note(s.buffer, at, sixteenth * 1.6, root + 36 + interval, 0.06, Voice.bell())
			if part.has(BASS):
				if step % 2 == 0:
					_note(s.buffer, at, sixteenth * 1.8, root + (12 if step % 4 == 2 else 0), 0.3, Voice.bass())
				if step % 4 == 0:
					_note(s.buffer, at, sixteenth * 3.0, root, 0.12, Voice.sub())
			if part.has(DRUMS):
				if step % 4 == 0:
					_kick(s.buffer, at)
				if step % 8 == 4:
					_snare(s.buffer, at, s.rng)
			elif part.has(HALF) and step % 4 == 0:
				_kick(s.buffer, at)
			if part.has(BELLS) and step % 4 == 2:
				_bells(s.buffer, at, 0.03, s.rng)
		if part.has(LEAD):
			var high := 12 if b % 16 >= 8 else 0
			var lead_a := root + 36 + third + high
			var lead_b := root + 36 + 7 + high
			if part.lead == 0:
				_note(s.buffer, t, s.bar * 0.48, lead_a, 0.12, Voice.lead())
				_note(s.buffer, t + s.bar * 0.5, s.bar * 0.48, lead_b if b % 2 == 0 else lead_a + 2, 0.12, Voice.lead())
			else:
				for beat in 4:
					_note(s.buffer, t + beat * s.beat, s.beat * 0.9, root + 36 + high + [third, 7, 12, 7][beat], 0.1, Voice.lead())
			if part.has(HARMONY):
				_note(s.buffer, t, s.bar * 0.48, lead_a - 12, 0.05, Voice.reed(2000.0))
				_note(s.buffer, t + s.bar * 0.5, s.bar * 0.48, lead_b - 12, 0.05, Voice.reed(2000.0))
	, 0.32)


## Shuffled boogie-woogie with walking bass, harmonica and sleigh bells: an
## intro, choruses with new riffs, a stop-time chorus on piano and two last
## choruses a tone higher.
static func _boogie() -> AudioStreamWAV:
	var song := Song.new(168.0, 2, 4, 9, false, 12)
	var chords := []
	for root: int in BOOGIE_CHORDS:
		chords.append([root, false])
	var full := DRUMS | BASS | PAD | BELLS
	var plan := [
		Part.new(4, [[45, false]], [], BASS | BELLS | HALF),
		Part.new(12, chords, [], full | LEAD | CRASH),
		Part.new(12, chords, [], full | LEAD, 0, 1),
		Part.new(12, chords, [], BASS | BELLS | COMP | HALF | FILL),
		Part.new(12, chords, [], full | LEAD | CRASH, 2),
		Part.new(12, chords, [], full | LEAD | FILL, 2, 1),
		Part.new(2, [[45, false]], [], full | END, 2),
	]
	var walk := [0, 4, 7, 9, 10, 9, 7, 4]
	var riff_a := [[12, 1], [15, 1], [16, 2], [19, 2], [21, 1], [19, 1]]
	var riff_b := [[22, 2], [21, 1], [19, 1], [16, 2], [12, 2]]
	return _arrange(song, plan, func(s: Song, t: float, root: int, _minor: bool, part: Part, b: int) -> void:
		var beat := s.beat
		if part.has(PAD):
			_chord(s.buffer, t, s.bar, root + 24, false, 0.025, Voice.pad())
		for k in 8:
			var swung := t + floorf(k / 2.0) * beat + (beat * 2.0 / 3.0 if k % 2 == 1 else 0.0)
			if part.has(BASS):
				_note(s.buffer, swung, beat * 0.55, root + walk[k], 0.3, Voice.bass())
			if part.has(BELLS):
				_bells(s.buffer, swung, 0.03 if k % 2 == 0 else 0.02, s.rng)
			if part.has(COMP) and k % 2 == 1:
				for interval in [16, 19, 22]:
					_note(s.buffer, swung, beat * 0.3, root + interval, 0.035, Voice.keys())
		for n in 4:
			if part.has(DRUMS):
				if n % 2 == 0:
					_kick(s.buffer, t + n * beat)
				else:
					_snare(s.buffer, t + n * beat, s.rng)
			elif part.has(HALF) and n == 0:
				_kick(s.buffer, t)
		if part.has(LEAD):
			var riffs := [riff_a, riff_b] if part.lead == 0 else [BOOGIE_RIFF_C, BOOGIE_RIFF_D]
			var position := 0.0
			for note: Array in riffs[b % 2]:
				var length: int = note[1]
				var swung_start := t + floorf(position / 2.0) * beat + (beat * 2.0 / 3.0 if int(position) % 2 == 1 else 0.0)
				_note(s.buffer, swung_start, length * beat * 0.5, root + 24 + int(note[0]), 0.11, Voice.reed(2000.0))
				position += length
	, 0.2)


## Schottis: oom on beats one and three, chords on two and four, a reedy
## accordion lead with the dotted lilt; B part, breakdown and a finale a tone up.
static func _schottis() -> AudioStreamWAV:
	var song := Song.new(148.0, 4, 4, 7, false, 31)
	song.leads = [
		[[Voice.reed(2400.0), 0.12, 0, 0.97], [Voice.lead(), 0.05, -12, 0.95]],
		[[Voice.lead(), 0.13, 0, 0.95], [Voice.reed(2400.0), 0.045, -12, 0.97]],
		[[Voice.lead(), 0.1, 0, 0.95], [Voice.bell(), 0.03, 12, 0.5]],
	]
	var full := DRUMS | BASS | COMP | PAD | BELLS
	var plan := [
		Part.new(4, SCHOTTIS_CHORDS, [], DRUMS | BASS | COMP),
		Part.new(16, SCHOTTIS_CHORDS, SCHOTTIS_MELODY, full | LEAD | CRASH),
		Part.new(16, SCHOTTIS_CHORDS, SCHOTTIS_MELODY, full | LEAD | HARMONY, 0, 1),
		Part.new(8, SCHOTTIS_B_CHORDS, SCHOTTIS_B, full | LEAD | FILL),
		Part.new(8, _stretch(SCHOTTIS_CHORDS.slice(0, 4), 2), _augment(SCHOTTIS_MELODY, 64, 2), PAD | BELLS | BASS | HALF | LEAD | FILL, 0, 2),
		Part.new(16, SCHOTTIS_CHORDS, SCHOTTIS_MELODY, full | LEAD | HARMONY | CRASH, 2),
		Part.new(4, [[36, false], [38, false], [43, false], [43, false]], [], full | END, 2),
	]
	return _arrange(song, plan, func(s: Song, t: float, root: int, minor: bool, part: Part, _b: int) -> void:
		var sixteenth := s.step
		var third := 3 if minor else 4
		if part.has(PAD):
			_chord(s.buffer, t, s.bar, root + 24, minor, 0.025, Voice.pad())
		for beat in 4:
			var at := t + beat * sixteenth * 4.0
			if beat % 2 == 0:
				if part.has(BASS):
					_note(s.buffer, at, sixteenth * 3.5, root if beat == 0 else root + 7, 0.32, Voice.bass())
					_note(s.buffer, at, sixteenth * 3.0, root, 0.14, Voice.sub())
				if part.has(DRUMS) or (part.has(HALF) and beat == 0):
					_kick(s.buffer, at)
			else:
				if part.has(COMP):
					for interval in [12, 12 + third, 19]:
						_note(s.buffer, at, sixteenth * 2.5, root + interval + 12, 0.05, Voice.stab())
				if part.has(DRUMS):
					_snare(s.buffer, at, s.rng)
			if part.has(BELLS):
				_bells(s.buffer, at, 0.03, s.rng)
				_bells(s.buffer, at + sixteenth * 3.0, 0.02, s.rng)
	, 0.26)


## A quick sledding waltz: bass on one, chords on two and three, a flute
## lead over a music-box ostinato; a B part on new chords and a finale a tone up.
static func _waltz() -> AudioStreamWAV:
	var song := Song.new(176.0, 2, 3, 2, false, 47)
	song.leads = [
		[[Voice.lead(), 0.15, 0, 0.97]],
		[[Voice.reed(2400.0), 0.11, 0, 0.97], [Voice.bell(), 0.03, 12, 0.5]],
		[[Voice.lead(), 0.1, 0, 0.95], [Voice.bell(), 0.03, 12, 0.5]],
	]
	var full := DRUMS | BASS | COMP | PAD | BELLS | ARP
	var plan := [
		Part.new(4, WALTZ_CHORDS, [], DRUMS | BASS | COMP | ARP),
		Part.new(16, WALTZ_CHORDS, WALTZ_MELODY, full | LEAD | CRASH),
		Part.new(16, WALTZ_CHORDS, WALTZ_MELODY, full | LEAD | HARMONY, 0, 1),
		Part.new(16, WALTZ_B_CHORDS, WALTZ_B + WALTZ_B, full | LEAD | FILL),
		Part.new(8, _stretch(WALTZ_CHORDS.slice(0, 4), 2), _augment(WALTZ_MELODY, 24, 2), PAD | ARP | BASS | HALF | LEAD | FILL, 0, 2),
		Part.new(16, WALTZ_CHORDS, WALTZ_MELODY, full | LEAD | HARMONY | CRASH, 2),
		Part.new(4, [[43, false], [45, false], [38, false], [38, false]], [], full | END, 2),
	]
	return _arrange(song, plan, func(s: Song, t: float, root: int, minor: bool, part: Part, _b: int) -> void:
		var e := s.step
		var third := 3 if minor else 4
		if part.has(PAD):
			_chord(s.buffer, t, s.bar, root + 24, minor, 0.03, Voice.pad())
		if part.has(BASS):
			_note(s.buffer, t, e * 1.9, root, 0.32, Voice.bass())
			_note(s.buffer, t, e * 1.6, root, 0.15, Voice.sub())
		if part.has(DRUMS) or part.has(HALF):
			_kick(s.buffer, t)
		if part.has(COMP):
			for beat in [1, 2]:
				for interval in [12, 12 + third, 19]:
					_note(s.buffer, t + beat * e * 2.0, e * 1.3, root + interval + 12, 0.04, Voice.stab())
		for k in 6:
			if part.has(ARP):
				var arp: int = [0, third, 7, 12, 7, third][k]
				_note(s.buffer, t + k * e, e * 1.5, root + 36 + arp, 0.035, Voice.bell())
			if part.has(BELLS):
				_bells(s.buffer, t + k * e, 0.02, s.rng)
	, 0.3)


## Driving minor-key storm: pumping octave bass, four on the floor, a
## harmonica lead and a pad that swells underneath; a B part and a breakdown.
static func _storm() -> AudioStreamWAV:
	var song := Song.new(162.0, 2, 4, 9, true, 53)
	song.leads = [
		[[Voice.reed(2100.0), 0.13, 0, 0.96], [Voice.lead(), 0.04, 12, 0.95]],
		[[Voice.lead(), 0.13, 0, 0.95], [Voice.reed(2100.0), 0.05, -12, 0.96]],
	]
	var full := DRUMS | BASS | PAD | BELLS | ARP
	var plan := [
		Part.new(4, STORM_CHORDS, [], BASS | HALF | ARP),
		Part.new(16, STORM_CHORDS, STORM_MELODY, full | LEAD | CRASH),
		Part.new(8, STORM_B_CHORDS, STORM_B, full | LEAD | FILL),
		Part.new(8, STORM_CHORDS, [], PAD | ARP | HALF | RISE),
		Part.new(16, STORM_CHORDS, STORM_MELODY, full | LEAD | HARMONY | CRASH, 0, 1),
		Part.new(8, STORM_B_CHORDS, STORM_B, full | LEAD | HARMONY),
		Part.new(4, [[41, false], [40, false], [45, true], [45, true]], [], full | END),
	]
	return _arrange(song, plan, func(s: Song, t: float, root: int, minor: bool, part: Part, _b: int) -> void:
		var e := s.step
		var third := 3 if minor else 4
		if part.has(PAD):
			_chord(s.buffer, t, s.bar, root + 24, minor, 0.04, Voice.pad())
		for k in 8:
			var at := t + k * e
			if part.has(BASS):
				_note(s.buffer, at, e * 0.9, root + (12 if k % 2 == 1 else 0), 0.26, Voice.bass())
			if part.has(DRUMS):
				if k % 2 == 0:
					_kick(s.buffer, at)
				if k % 4 == 2:
					_snare(s.buffer, at, s.rng)
			elif part.has(HALF) and k % 4 == 0:
				_kick(s.buffer, at)
			if part.has(BELLS):
				_bells(s.buffer, at, 0.025, s.rng)
			if part.has(ARP):
				var arp: int = [0, 7, 12, third + 12][k % 4]
				_note(s.buffer, at, e * 0.8, root + 36 + arp, 0.03, Voice.bell())
	, 0.28)


## Nordljus: synthwave at 112 BPM. Pulsing octave saw bass, a sidechained
## pad and plucked arpeggio, big gated snare and a wide saw lead.
static func _nordljus() -> AudioStreamWAV:
	var song := Song.new(112.0, 4, 4, 9, true, 808)
	song.pumping = true
	song.leads = [
		[[Voice.supersaw(), 0.09, 0, 0.97], [Voice.lead(), 0.035, 12, 0.95]],
		[[Voice.supersaw(), 0.08, 12, 0.97], [Voice.supersaw(), 0.05, 0, 0.97]],
	]
	var groove := DRUMS | BASS | PAD | ARP
	var plan := [
		Part.new(4, NORDLJUS_CHORDS, [], PAD | ARP | RISE),
		Part.new(4, NORDLJUS_CHORDS, [], groove | CRASH),
		Part.new(8, NORDLJUS_CHORDS, NORDLJUS_A, groove | LEAD),
		Part.new(8, NORDLJUS_CHORDS, NORDLJUS_A, groove | LEAD | HARMONY),
		Part.new(8, NORDLJUS_B_CHORDS, NORDLJUS_B, groove | LEAD | CRASH | FILL),
		Part.new(4, NORDLJUS_CHORDS, [], PAD | ARP | RISE),
		Part.new(8, NORDLJUS_CHORDS, NORDLJUS_A, groove | LEAD | CRASH, 0, 1),
		Part.new(8, NORDLJUS_CHORDS, NORDLJUS_A, groove | LEAD | HARMONY, 0, 1),
		Part.new(4, NORDLJUS_CHORDS, [], PAD | ARP | BASS | END),
	]
	return _arrange(song, plan, func(s: Song, t: float, root: int, minor: bool, part: Part, _b: int) -> void:
		var third := 3 if minor else 4
		var arp := [0, 7, 12, third + 12, 19, third + 12, 12, 7]
		if part.has(PAD):
			_chord(s.pumped, t, s.bar, root + 24, minor, 0.035, Voice.wide())
		for k in 16:
			var at := t + k * s.step
			if part.has(ARP):
				_note(s.pumped, at, s.step * 1.5, root + 24 + arp[k % 8], 0.045, Voice.pluck())
			if part.has(BASS) and k % 2 == 0:
				_note(s.buffer, at, s.step * 1.6, root + (12 if k % 4 == 2 else 0), 0.2, Voice.saw_bass())
				if k % 8 == 0:
					_note(s.buffer, at, s.step * 7.0, root, 0.12, Voice.sub())
			if part.has(DRUMS):
				if k % 8 == 0:
					_thump(s, at)
				if k % 8 == 4:
					_gated_snare(s.buffer, at, 0.9, s.rng)
				if k % 2 == 0:
					_hat(s.buffer, at, 0.035, false, s.rng)
	, 0.34)


## Pulkaraketen: liquid drum'n'bass at 172 BPM. Two-step breakbeat, a
## growling reese bass over a sub, airy pads and an electric piano melody.
static func _pulkaraketen() -> AudioStreamWAV:
	var song := Song.new(172.0, 4, 4, 2, true, 1172)
	song.leads = [
		[[Voice.keys(), 0.11, 0, 0.9], [Voice.bell(), 0.04, 12, 0.6]],
		[[Voice.supersaw(), 0.07, 0, 0.95], [Voice.bell(), 0.035, 12, 0.6]],
	]
	var full := DRUMS | BASS | PAD
	var plan := [
		Part.new(8, PULKA_CHORDS, [], PAD | ARP | RISE),
		Part.new(8, PULKA_CHORDS, PULKA_A, full | LEAD | CRASH),
		Part.new(8, PULKA_CHORDS, PULKA_A, full | ARP | LEAD | HARMONY),
		Part.new(8, PULKA_B_CHORDS, PULKA_B, full | LEAD | FILL, 0, 1),
		Part.new(8, PULKA_CHORDS, PULKA_A, PAD | ARP | HALF | LEAD | RISE),
		Part.new(8, PULKA_CHORDS, PULKA_A, full | LEAD | CRASH, 0, 1),
		Part.new(8, PULKA_CHORDS, PULKA_A, full | ARP | LEAD | HARMONY, 0, 1),
		Part.new(4, PULKA_CHORDS, [], PAD | BASS | ARP | END),
	]
	return _arrange(song, plan, func(s: Song, t: float, root: int, minor: bool, part: Part, b: int) -> void:
		var third := 3 if minor else 4
		if part.has(PAD):
			_chord(s.buffer, t, s.bar, root + 24, minor, 0.03, Voice.wide())
		if part.has(BASS):
			_note(s.buffer, t, s.bar * 0.48, root, 0.13, Voice.reese())
			_note(s.buffer, t + s.bar * 0.5, s.bar * 0.48, root + (7 if b % 2 == 1 else 0), 0.13, Voice.reese())
			_note(s.buffer, t, s.bar * 0.95, root, 0.16, Voice.sub())
		if part.has(ARP):
			for k in 8:
				_note(s.buffer, t + k * s.step * 2.0, s.step * 1.8, root + 36 + [0, third, 7, 12, 7, third, 0, 7][k], 0.03, Voice.bell())
		for k in 16:
			var at := t + k * s.step
			if part.has(DRUMS):
				if k == 0 or k == 10:
					_thump(s, at, 0.9)
				if k == 4 or k == 12:
					_snare(s.buffer, at, s.rng)
				elif k == 7 or k == 15:
					_snare(s.buffer, at, s.rng, 0.3)
				_hat(s.buffer, at, 0.03 if k % 2 == 0 else 0.012, false, s.rng)
			elif part.has(HALF):
				if k == 0:
					_thump(s, at, 0.8)
				if k == 8:
					_snare(s.buffer, at, s.rng, 0.8)
				if k % 2 == 0:
					_hat(s.buffer, at, 0.025, false, s.rng)
	, 0.3)


## Snöbollskrig: chiptune at 150 BPM. Square-wave lead with an echo, fast
## arpeggios, triangle bass and noise drums; the last round a tone up.
static func _snowball() -> AudioStreamWAV:
	var song := Song.new(150.0, 4, 4, 0, false, 64)
	song.leads = [
		[[Voice.chip(), 0.06, 0, 0.9], [Voice.chip(), 0.022, 0, 0.9, 3]],
		[[Voice.chip(), 0.055, 0, 0.6], [Voice.chip(), 0.03, -12, 0.9]],
	]
	var full := DRUMS | BASS | ARP
	var plan := [
		Part.new(4, SNO_CHORDS, [], ARP | BASS),
		Part.new(8, SNO_CHORDS, SNO_A, full | LEAD | CRASH),
		Part.new(8, SNO_CHORDS, SNO_A, full | LEAD | HARMONY, 0, 1),
		Part.new(8, SNO_B_CHORDS, SNO_B, full | LEAD | FILL),
		Part.new(8, SNO_CHORDS, [], ARP | HALF | RISE),
		Part.new(8, SNO_CHORDS, SNO_A, full | LEAD | CRASH, 2),
		Part.new(8, SNO_CHORDS, SNO_A, full | LEAD | HARMONY, 2, 1),
		Part.new(4, [[41, false], [43, false], [36, false], [36, false]], [], full | END, 2),
	]
	return _arrange(song, plan, func(s: Song, t: float, root: int, minor: bool, part: Part, _b: int) -> void:
		var third := 3 if minor else 4
		for k in 16:
			var at := t + k * s.step
			if part.has(ARP):
				_note(s.buffer, at, s.step * 0.9, root + 24 + [0, third, 7, 12][k % 4], 0.03, Voice.chip_arp())
			if part.has(BASS) and k % 2 == 0:
				_note(s.buffer, at, s.step * 1.7, root + (12 if k % 4 == 2 else 0), 0.24, Voice.chip_bass())
			if part.has(DRUMS):
				if k % 8 == 0:
					_kick(s.buffer, at)
				if k % 8 == 4:
					_chip_noise(s.buffer, at, 0.12, 0.22, 25.0, s.rng)
			elif part.has(HALF) and k == 0:
				_kick(s.buffer, at)
			if (part.has(DRUMS) or part.has(HALF)) and k % 2 == 0:
				_chip_noise(s.buffer, at, 0.03, 0.05, 120.0, s.rng)
	, 0.18)


## Pudersnö: house at 124 BPM. Four on the floor, claps and open hats, an
## off-beat bass, sidechained piano chords and a syncopated pluck riff.
static func _powder() -> AudioStreamWAV:
	var song := Song.new(124.0, 4, 4, 5, false, 1240)
	song.pumping = true
	song.leads = [
		[[Voice.pluck(), 0.11, 0, 0.9], [Voice.pluck(), 0.04, 12, 0.6, 3]],
		[[Voice.lead(), 0.12, 0, 0.97], [Voice.keys(), 0.05, 0, 0.9]],
	]
	var full := DRUMS | BASS | COMP | PAD
	var plan := [
		Part.new(4, PUDER_CHORDS, [], HALF | BASS),
		Part.new(8, PUDER_CHORDS, PUDER_A, DRUMS | BASS | COMP | LEAD | CRASH),
		Part.new(8, PUDER_CHORDS, PUDER_A, full | LEAD | HARMONY),
		Part.new(8, PUDER_B_CHORDS, PUDER_B, PAD | COMP | LEAD | RISE, 0, 1),
		Part.new(8, PUDER_CHORDS, PUDER_A, full | LEAD | CRASH),
		Part.new(8, PUDER_CHORDS, PUDER_A, full | LEAD | HARMONY),
		Part.new(8, PUDER_B_CHORDS, PUDER_B, full | LEAD | FILL, 0, 1),
		Part.new(4, PUDER_CHORDS, [], HALF | BASS | PAD | END),
	]
	return _arrange(song, plan, func(s: Song, t: float, root: int, minor: bool, part: Part, _b: int) -> void:
		var third := 3 if minor else 4
		if part.has(PAD):
			_chord(s.pumped, t, s.bar, root + 24, minor, 0.025, Voice.wide())
		for beat in 4:
			var on := t + beat * s.beat
			var off := on + s.beat * 0.5
			if part.has(COMP):
				for interval in [0, third, 7, 12]:
					_note(s.pumped, off, s.step * 1.6, root + 24 + interval, 0.04, Voice.keys())
			if part.has(BASS):
				_note(s.buffer, off, s.step * 1.7, root + 12, 0.2, Voice.saw_bass())
			if part.has(DRUMS) or part.has(HALF):
				_thump(s, on)
				_hat(s.buffer, off, 0.045, true, s.rng)
			if part.has(DRUMS):
				if beat % 2 == 1:
					_clap(s.buffer, on, 0.3, s.rng)
				for k in [1, 3]:
					_hat(s.buffer, on + k * s.step, 0.018, false, s.rng)
	, 0.26)


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


static func _snare(buffer: PackedFloat32Array, start: float, rng: RandomNumberGenerator, amp := 1.0) -> void:
	var first := int(start * RATE)
	var low := 0.0
	for k in int(0.16 * RATE):
		var t := float(k) / RATE
		var white := rng.randf_range(-1.0, 1.0)
		low += 0.4 * (white - low)
		buffer[(first + k) % buffer.size()] += ((white - low) * 0.3 + sin(t * TAU * 190.0) * 0.12) * exp(-t * 22.0) * amp


static func _bells(buffer: PackedFloat32Array, start: float, amp: float, rng: RandomNumberGenerator) -> void:
	var first := int((start + rng.randf_range(-0.004, 0.004)) * RATE)
	for k in int(0.11 * RATE):
		var t := float(k) / RATE
		var ring := sin(t * TAU * 2650.0) + sin(t * TAU * 3720.0) * 0.7 + sin(t * TAU * 5110.0) * 0.5
		var jingle := ring * exp(-t * 28.0) + rng.randf_range(-1.0, 1.0) * exp(-t * 60.0) * 0.6
		buffer[(maxi(first, 0) + k) % buffer.size()] += jingle * amp * 0.65

## Punchy electronic kick; also where the sidechained layers duck.
static func _thump(song: Song, start: float, amp := 1.0) -> void:
	song.kicks.append(start)
	var first := int(start * RATE)
	var size := song.buffer.size()
	var phase := 0.0
	for k in int(0.32 * RATE):
		var t := float(k) / RATE
		phase += (44.0 + 160.0 * exp(-t * 28.0)) / RATE
		var click := sin(t * TAU * 1800.0) * exp(-t * 300.0) * 0.12
		song.buffer[(first + k) % size] += (sin(phase * TAU) * exp(-t * 7.5) * 0.62 + click) * amp


## Noise hi-hat, closed or open.
static func _hat(buffer: PackedFloat32Array, start: float, amp: float, open: bool, rng: RandomNumberGenerator) -> void:
	var first := int(start * RATE)
	var size := buffer.size()
	var low := 0.0
	var fall := 14.0 if open else 70.0
	for k in int((0.25 if open else 0.05) * RATE):
		var t := float(k) / RATE
		var white := rng.randf_range(-1.0, 1.0)
		low += 0.6 * (white - low)
		buffer[(first + k) % size] += (white - low) * exp(-t * fall) * amp


## Hand clap: three quick noise bursts and a short tail.
static func _clap(buffer: PackedFloat32Array, start: float, amp: float, rng: RandomNumberGenerator) -> void:
	var first := int(start * RATE)
	var size := buffer.size()
	var low := 0.0
	var body := 0.0
	for k in int(0.2 * RATE):
		var t := float(k) / RATE
		var burst := exp(-fmod(t, 0.011) * 350.0) if t < 0.033 else exp(-(t - 0.033) * 18.0)
		var white := rng.randf_range(-1.0, 1.0)
		low += 0.3 * (white - low)
		body += 0.5 * ((white - low) - body)
		buffer[(first + k) % size] += body * burst * amp


## Long, bright crash cymbal.
static func _cymbal(buffer: PackedFloat32Array, start: float, amp: float, rng: RandomNumberGenerator) -> void:
	var first := int(start * RATE)
	var size := buffer.size()
	var low := 0.0
	for k in int(1.6 * RATE):
		var t := float(k) / RATE
		var white := rng.randf_range(-1.0, 1.0)
		low += 0.7 * (white - low)
		buffer[(first + k) % size] += (white - low) * exp(-t * 2.6) * amp


## Noise that opens up and swells into the next part.
static func _riser(buffer: PackedFloat32Array, start: float, length: float, amp: float, rng: RandomNumberGenerator) -> void:
	var first := maxi(int(start * RATE), 0)
	var size := buffer.size()
	var low := 0.0
	for k in int(length * RATE):
		var x := float(k) / (length * RATE)
		low += lerpf(0.02, 0.6, x * x) * (rng.randf_range(-1.0, 1.0) - low)
		buffer[(first + k) % size] += low * x * x * amp


## The big, abruptly cut snare of the eighties.
static func _gated_snare(buffer: PackedFloat32Array, start: float, amp: float, rng: RandomNumberGenerator) -> void:
	var first := int(start * RATE)
	var size := buffer.size()
	var low := 0.0
	for k in int(0.28 * RATE):
		var t := float(k) / RATE
		var white := rng.randf_range(-1.0, 1.0)
		low += 0.35 * (white - low)
		var gate := 1.0 if t < 0.2 else exp(-(t - 0.2) * 60.0)
		var tone := sin(t * TAU * 180.0) * exp(-t * 20.0) * 0.3
		buffer[(first + k) % size] += ((white - low) * 0.35 * (0.6 + 0.4 * exp(-t * 8.0)) * gate + tone) * amp


## Old-console noise drum: stepped random noise with a quick decay.
static func _chip_noise(buffer: PackedFloat32Array, start: float, length: float, amp: float, fall: float, rng: RandomNumberGenerator) -> void:
	var first := int(start * RATE)
	var size := buffer.size()
	var held := 0.0
	for k in int(length * RATE):
		if k % 3 == 0:
			held = rng.randf_range(-1.0, 1.0)
		buffer[(first + k) % size] += held * exp(-float(k) / RATE * fall) * amp
