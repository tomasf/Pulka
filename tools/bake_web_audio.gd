extends SceneTree
## Prepares synthesized audio for the Web, Apple TV and macOS exports
## (see SoundBank.uses_baked_audio). Songs become Ogg Vorbis through ffmpeg
## when it is installed. Run an import afterwards (the export scripts do).

const OUTPUT := "res://generated/web_audio/"


func _initialize() -> void:
	var error := DirAccess.make_dir_recursive_absolute(OUTPUT)
	if error != OK:
		push_error("Cannot create web audio directory: %s" % error_string(error))
		quit(1)
		return
	var effects := Resource.new()
	effects.set_meta(&"streams", Synth.effects())
	if not _save(effects, "effects") or not _save(Synth.engine(), "engine"):
		return
	if not _save(Synth.wind(), "wind") or not _save(Synth.scrape(), "scrape"):
		return
	# Songs render side by side (each takes a while at 44.1 kHz stereo).
	var threads: Array[Thread] = []
	for i in MusicComposer.SONG_COUNT:
		var thread := Thread.new()
		thread.start(MusicComposer.render.bind(i))
		threads.append(thread)
	var encoder := _vorbis_encoder()
	for i in MusicComposer.SONG_COUNT:
		var stream: AudioStreamWAV = threads[i].wait_to_finish()
		print("Preparing web audio: ", MusicComposer.title(i))
		if not _save_song(stream, i, encoder):
			return
	quit()


## Saves a song as Ogg Vorbis when ffmpeg is at hand (far smaller and better
## sounding than the import's own compression), otherwise as WAV.
func _save_song(stream: AudioStreamWAV, index: int, encoder: String) -> bool:
	var wav := ProjectSettings.globalize_path(OUTPUT + "song_%d.wav" % index)
	var ogg := ProjectSettings.globalize_path(OUTPUT + "song_%d.ogg" % index)
	var saved := stream.save_to_wav(wav)
	if saved != OK:
		push_error("Cannot save %s: %s" % [wav, error_string(saved)])
		quit(1)
		return false
	for stale in [ogg, ogg + ".import"] if encoder == "" else [wav + ".import"]:
		DirAccess.remove_absolute(stale)
	if encoder == "":
		return true
	var output := []
	if OS.execute(encoder, ["-loglevel", "error", "-y", "-i", wav, "-c:a", "libvorbis", "-q:a", "5", ogg], output, true) != 0:
		push_error("ffmpeg could not encode %s: %s" % [wav, "".join(output)])
		quit(1)
		return false
	DirAccess.remove_absolute(wav)
	return true


## ffmpeg's path, or "" when it isn't installed.
func _vorbis_encoder() -> String:
	for candidate in ["ffmpeg", "/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg"]:
		if OS.execute(candidate, ["-version"], [], false) == 0:
			return candidate
	print("ffmpeg not found: songs are saved as WAV")
	return ""


func _save(resource: Resource, name: String) -> bool:
	var error := ResourceSaver.save(resource, OUTPUT + name + ".res", ResourceSaver.FLAG_COMPRESS)
	if error != OK:
		push_error("Cannot save %s: %s" % [name, error_string(error)])
		quit(1)
		return false
	return true
