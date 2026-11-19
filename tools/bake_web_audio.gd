extends SceneTree
## Prepares synthesized audio for the Web, Apple TV and macOS exports
## (see SoundBank.uses_baked_audio). Run an import afterwards (the export
## scripts do) so the songs get compressed.

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
	# Songs are written as WAV so the import step compresses them (QOA);
	# uncompressed they would add tens of megabytes to the exports.
	for i in MusicComposer.SONG_COUNT:
		print("Preparing web audio: ", MusicComposer.title(i))
		var path := OUTPUT + "song_%d.wav" % i
		var saved := MusicComposer.render(i).save_to_wav(ProjectSettings.globalize_path(path))
		if saved != OK:
			push_error("Cannot save %s: %s" % [path, error_string(saved)])
			quit(1)
			return
	quit()


func _save(resource: Resource, name: String) -> bool:
	var error := ResourceSaver.save(resource, OUTPUT + name + ".res", ResourceSaver.FLAG_COMPRESS)
	if error != OK:
		push_error("Cannot save %s: %s" % [name, error_string(error)])
		quit(1)
		return false
	return true
