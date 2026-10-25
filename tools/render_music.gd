extends SceneTree
## Renders every song to a WAV file for listening outside the game.
## Run: Godot --headless --path . --script res://tools/render_music.gd -- <output dir>


func _initialize() -> void:
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
	for i in MusicComposer.SONG_COUNT:
		var started := Time.get_ticks_msec()
		var stream := MusicComposer.render(i)
		var seconds := stream.data.size() / 2.0 / stream.mix_rate
		var path := "%s/%d_%s.wav" % [out, i + 1, MusicComposer.title(i).replace(" ", "_")]
		stream.save_to_wav(path)
		print("%-18s %5.1f s  rendered in %d ms  -> %s" % [MusicComposer.title(i), seconds, Time.get_ticks_msec() - started, path])
	quit()
