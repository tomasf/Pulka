extends SceneTree
## Switches the real settings UI, with an isolated save. Add --capture for
## native review screenshots, or --compact --mobile-preview for phone layout.
var test_save := OS.get_temp_dir().path_join("pulka-localization-test-%d.cfg" % OS.get_process_id())
var main: Node
var failures := 0
var capture := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	capture = OS.get_cmdline_user_args().has("--capture")
	if OS.get_cmdline_user_args().has("--compact"): root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(960, 540) if OS.get_cmdline_user_args().has("--compact") else Vector2i(1600, 900)
	_check_catalog()
	var legacy := ConfigFile.new()
	legacy.save(test_save)
	_check("legacy saves default to Swedish", SaveData.load_saved(test_save).language == "sv")
	legacy.set_value("settings", "language", "de")
	legacy.save(test_save)
	var data := SaveData.load_saved(test_save)
	_check("unsupported saved languages fall back to Swedish", data.language == "sv")
	data.best_distance = 1234
	data.best_score = 5678
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_process(false)
	main.set("_autopilot", true)
	main.set("_save", data)
	main.set("_vehicle", 0)
	TranslationServer.set_locale("sv")
	main.call("_enter_menu")
	await _tick(50)
	var hud: Hud = main.get("_hud")
	hud.open_settings(0.6, 0.4, 0.8)
	await _tick(20)
	hud._language_buttons[0].grab_focus()
	await _key(KEY_RIGHT)
	_check("keyboard can reach English", root.gui_get_focus_owner() == hud._language_buttons[1])
	await _key(KEY_ENTER)
	await _tick(3)
	_check("language changes immediately inside settings", data.language == "en" and TranslationServer.get_locale() == "en" and hud._settings_done.tr(hud._settings_done.text) == "Done")
	_check("language choices show their native names and selected state", hud._language_buttons[0].text == "Svenska" and hud._language_buttons[1].text == "English" and hud._language_buttons[1].button_pressed and not hud._language_buttons[0].button_pressed)
	_check("language buttons fit their row", hud._language_buttons[1].get_rect().end.y <= hud._language_buttons[1].get_parent().size.y)
	await _shot("settings-en")
	main.call("_close_settings")
	_check("language is persisted with the existing preferences", SaveData.load_saved(test_save).language == "en" and SaveData.load_saved(test_save).best_score == 5678)
	await _tick(50)
	var headline: Label = hud._menu.players.get_child(0)
	_check("English headline fits before the player cards", headline.get_rect().end.x < hud._menu.solo.position.x - 20)
	_check("formatted menu records are English", hud._menu._record.text.begins_with("BEST") and hud._menu._record.text.contains("points"))
	await _shot("menu-en")
	hud.open_about()
	await _tick(20)
	_check("About translates its rich text and preserves the creator", hud._about_text.get_parsed_text().contains("CREATED BY") and hud._about_text.get_parsed_text().contains("Tomas Wincent Franzén"))
	await _shot("about-en")
	hud.close_about()
	main.call("_choose_solo")
	await _tick(50)
	_check("keyboard hints translate their spoken action names", hud._menu._controls_hint.accessibility_name == "← → Steer Space Jump")
	_check("ride names retain their Swedish names", hud._menu._name.text == "Pulka" and TranslationServer.translate("Stjärtlapp") == "Stjärtlapp" and TranslationServer.translate("Wokpanna") == "Wokpanna")
	main.call("_on_hud_pressed", &"vehicle_4")
	_check("unlock instruction translates before formatting", hud._menu._locked.text.begins_with("Ride ") and hud._menu._locked.text.ends_with(" to unlock"))
	await _shot("picker-en")
	main.call("_on_hud_pressed", &"vehicle_0")
	main.call("_start_run")
	await _tick(195)
	main.call("_set_paused", true)
	await _tick(20)
	_check("pause buttons translate", root.gui_get_focus_owner().tr(root.gui_get_focus_owner().text) == "Continue")
	await _shot("pause-en")
	hud.open_settings(0.6, 0.4, 0.8)
	hud._language_buttons[0].pressed.emit()
	await _tick(3)
	_check("switching back to Swedish preserves the paused run", data.language == "sv" and paused and hud._settings_done.tr(hud._settings_done.text) == "Klar" and hud._menu._controls_hint.accessibility_name == "← → Styr Space Hoppa")
	hud._language_buttons[1].pressed.emit()
	await _tick(3)
	hud.close_settings()
	main.call("_set_paused", false)
	hud.show_game_over("Vantarna är slut.", "Granen vann.", 1234, 5678, 4321, 9876, false, true)
	_check("result records are translated before formatting", hud._over_rows.get_child(0).get_child(0).get_child(1).text == "BEST: 4 321 m")
	await _tick(20)
	await _shot("results-en")
	_check("crash messages translate around unchanged Swedish names", (TranslationServer.translate("%s tappade termosen!") % "Farbror Bengt") == "Farbror Bengt dropped the thermos!")
	_check("race clock uses the language's decimal separator", main.call("_race_clock", 83.4) == "1:23.4")
	_check("world signage is excluded from translation", main.get("_world_root").auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED)
	main.call("_enter_menu")
	await _tick(50)
	if not Quality.is_mobile():
		main.call("_on_hud_pressed", &"duo")
		await _tick(50)
		var racers: Array = main.get("_players")
		_check("split-screen tips use English actions", racers[0].race_hud._lobby_controls.accessibility_name.contains("Steer"))
		await _shot("duo-en")
		racers[0].race_hud.update_race(1234, 10, 1, false)
		_check("race distance and placing translate", racers[0].race_hud._left.text == "1 234 m left" and racers[0].race_hud._place.text == "1st")
		racers[0].finish_time = 83.4
		main.call("_end_race")
		_check("race results translate player numbers and winner", hud._over_title.text == "Player 1 wins!")
		await _tick(20)
		await _shot("race-results-en")
		main.call("_enter_menu")
		await _tick(50)
	hud.open_settings(0.6, 0.4, 0.8)
	hud._language_buttons[0].pressed.emit()
	await _tick(3)
	main.call("_close_settings")
	_check("Swedish can be restored and saved", SaveData.load_saved(test_save).language == "sv" and hud._menu._record.text.begins_with("REKORD"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(data.window_settings_path()))
	main.queue_free()
	await process_frame
	await process_frame
	print("localization test: %s" % ("all passed" if failures == 0 else "%d failed" % failures))
	quit(failures)


func _tick(frames: int) -> void:
	for frame in frames:
		main.call("_process", 1.0 / 60.0)
		await process_frame


func _check_catalog() -> void:
	var english := load("res://translations/en.po") as Translation
	var placeholder := RegEx.create_from_string("%[0-9.]*[sdf]")
	var valid := true
	for source in english.get_message_list():
		var translated := String(english.get_message(source))
		var original_parts: Array[String] = []
		var translated_parts: Array[String] = []
		for part in placeholder.search_all(source): original_parts.append(part.get_string())
		for part in placeholder.search_all(translated): translated_parts.append(part.get_string())
		if translated.is_empty() or original_parts != translated_parts:
			valid = false
			print("Invalid translation: ", source)
	_check("all translations preserve their formatting placeholders", valid)
	var names_preserved := true
	for spec in VehicleSpec.all():
		if english.get_message(spec.title) != &"" or english.get_message(GrabTrick.for_model(spec.model).title) != &"":
			names_preserved = false
	_check("ride and trick names are excluded from the catalog", names_preserved)


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await _tick(2)


func _shot(name: String) -> void:
	if capture:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/pulka-language-%s%s.png" % ["compact-" if OS.get_cmdline_user_args().has("--compact") else "", name])


func _check(message: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", message])
	if not ok: failures += 1
