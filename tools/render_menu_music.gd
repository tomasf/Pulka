extends SceneTree
## Rebuild with: godot --headless --path . --script res://tools/render_menu_music.gd
## Then: ffmpeg -y -i /tmp/pulka-menu.wav -c:a libvorbis -q:a 6 audio/menu_snodag.ogg
func _initialize() -> void:
	var music := MusicComposer.render_menu()
	music.save_to_wav("/tmp/pulka-menu.wav")
	print("Snödag: %.2f seconds" % music.get_length())
	quit()
