class_name SoundBank
extends Node
## Owns every sound the game makes: one-shot effects, the speed-dependent wind
## and runner scrape loops, and the music (rendered in the background).
## Music and effects play on their own buses so their volumes can be set apart.

const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"
const WEB_AUDIO := "res://generated/web_audio/"

var engine_sound: AudioStreamWAV
var music_player: AudioStreamPlayer

var _effects: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _wind: AudioStreamPlayer
var _scrape: AudioStreamPlayer
## 0–1 blizzard strength; howls the wind regardless of speed.
var storm := 0.0
var _wind_level := 0.0
var _scrape_level := 0.0
var _music_threads: Array[Thread] = []
var _songs: Dictionary = {}
var _song := -1
var _song_plays := 0
var _first_song := 0


func _ready() -> void:
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)
	if OS.has_feature("web"):
		_effects = load(WEB_AUDIO + "effects.res").get_meta(&"streams")
		engine_sound = load(WEB_AUDIO + "engine.res")
	else:
		_effects = Synth.effects()
		engine_sound = Synth.engine()
	for i in 14:
		var player := AudioStreamPlayer.new()
		player.bus = SFX_BUS
		add_child(player)
		_players.append(player)
	_wind = _loop(load(WEB_AUDIO + "wind.res") if OS.has_feature("web") else Synth.wind())
	_scrape = _loop(load(WEB_AUDIO + "scrape.res") if OS.has_feature("web") else Synth.scrape())
	music_player = AudioStreamPlayer.new()
	music_player.volume_db = -8.0
	music_player.bus = MUSIC_BUS
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(music_player)
	music_player.finished.connect(_next_song)
	_first_song = randi() % MusicComposer.SONG_COUNT
	# The single-threaded web build loads audio baked by tools/export_web.sh.
	# Rendering songs here would block the browser's main thread for seconds.
	if OS.has_feature("web"):
		for i in MusicComposer.SONG_COUNT:
			_songs[i] = load(WEB_AUDIO + "song_%d.res" % i)
		return
	for i in MusicComposer.SONG_COUNT:
		var index := (_first_song + i) % MusicComposer.SONG_COUNT
		var thread := Thread.new()
		thread.start(func() -> AudioStreamWAV: return MusicComposer.render(index))
		thread.set_meta(&"song", index)
		_music_threads.append(thread)


func _exit_tree() -> void:
	for thread in _music_threads:
		thread.wait_to_finish()
	_music_threads.clear()


func _process(_delta: float) -> void:
	for thread in _music_threads.duplicate():
		if not thread.is_alive():
			_songs[int(thread.get_meta(&"song"))] = thread.wait_to_finish()
			_music_threads.erase(thread)
	if _song < 0 and _songs.has(_first_song):
		_song = _first_song
		_start_song()


## Each tune plays twice, then the next finished tune takes over.
func _next_song() -> void:
	_song_plays += 1
	if _song_plays >= 2:
		for step in range(1, MusicComposer.SONG_COUNT + 1):
			var candidate := (_song + step) % MusicComposer.SONG_COUNT
			if _songs.has(candidate):
				_song = candidate
				break
		_song_plays = 0
	_start_song()


func _start_song() -> void:
	music_player.stream = _songs[_song]
	music_player.play()


func _loop(stream: AudioStream) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = -80.0
	player.bus = SFX_BUS
	player.autoplay = true
	add_child(player)
	return player


static func _ensure_bus(bus: StringName) -> void:
	if AudioServer.get_bus_index(bus) != -1:
		return
	# Godot 4.7's Web Sample backend misorders buses when add_bus() appends
	# with index -1, disconnecting Master. Growing bus_count preserves routing.
	# https://github.com/godotengine/godot/issues/119026
	AudioServer.bus_count += 1
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus)
	AudioServer.set_bus_send(index, &"Master")


## Applies volumes in the 0–1 range to the master, music and effects buses.
static func apply_volumes(master: float, music: float, effects: float) -> void:
	for pair in [[&"Master", master], [MUSIC_BUS, music], [SFX_BUS, effects]]:
		var index := AudioServer.get_bus_index(pair[0])
		var level: float = pair[1]
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(level * level, 0.0001)))
		AudioServer.set_bus_mute(index, level <= 0.0)


func stream(effect: String) -> AudioStream:
	return _effects.get(effect)


func play(effect: String, volume_db := 0.0, pitch := 1.0) -> void:
	var stream: AudioStream = _effects.get(effect)
	if stream == null:
		return
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()


## Feeds the motion loops. `active` is false in menus.
func set_motion(delta: float, speed: float, grounded: bool, active: bool) -> void:
	var sf := clampf(speed / 45.0, 0.0, 1.3)
	var wind_target := maxf((0.08 + 0.9 * sf) if active else 0.05, storm * 1.1)
	var scrape_target := (0.15 + 0.7 * minf(sf, 1.0)) if active and grounded and speed > 1.0 else 0.0
	_wind_level = lerpf(_wind_level, wind_target, 1.0 - exp(-4.0 * delta))
	_scrape_level = lerpf(_scrape_level, scrape_target, 1.0 - exp(-14.0 * delta))
	_wind.volume_db = linear_to_db(maxf(_wind_level, 0.0001)) - 4.0
	_wind.pitch_scale = 0.7 + 0.6 * sf
	_scrape.volume_db = linear_to_db(maxf(_scrape_level, 0.0001)) - 6.0
	_scrape.pitch_scale = 0.75 + 0.55 * minf(sf, 1.0)


func set_music_ducked(ducked: bool) -> void:
	music_player.volume_db = -16.0 if ducked else -8.0
