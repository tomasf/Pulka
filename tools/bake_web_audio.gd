extends SceneTree
## Prepares synthesized audio for the single-threaded Web export.

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
	for i in MusicComposer.SONG_COUNT:
		print("Preparing web audio: ", MusicComposer.title(i))
		if not _save(MusicComposer.render(i), "song_%d" % i):
			return
	quit()


func _save(resource: Resource, name: String) -> bool:
	var error := ResourceSaver.save(resource, OUTPUT + name + ".res", ResourceSaver.FLAG_COMPRESS)
	if error != OK:
		push_error("Cannot save %s: %s" % [name, error_string(error)])
		quit(1)
		return false
	return true
