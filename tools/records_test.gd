extends SceneTree
## Exercises the real settings flow against an isolated save, never the user's.
const TEST_SAVE := "user://records-test.cfg"
var main: Node
var failures := 0

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	root.size = Vector2i(960, 540) if OS.get_cmdline_user_args().has("--compact") else Vector2i(1600, 900)
	# Legacy save has no separate unlock progress.
	var legacy := ConfigFile.new()
	legacy.set_value("records", "best_distance", 4300.0)
	legacy.set_value("records", "best_score", 7654)
	legacy.set_value("settings", "vehicle", "wok")
	legacy.set_value("audio", "music", 0.35)
	legacy.save(TEST_SAVE)
	var data := SaveData.load_saved(TEST_SAVE)
	_check("legacy distance migrates to unlock progress", data.unlocked_distance == 4300.0)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_process(false)
	main.set("_autopilot", true)
	main.set("_save", data)
	var hud: Hud = main.get("_hud")
	main.call("_refresh_menu")
	main.call("_on_hud_pressed", &"settings")
	await _tick(20)
	main.call("_on_hud_pressed", &"reset_records")
	_check("reset requires confirmation", data.best_score == 7654)
	hud._reset_button.pressed.emit()
	await _tick(2)
	_check("confirmation defaults to Cancel", hud.reset_pending and root.gui_get_focus_owner() == hud._reset_cancel)
	if OS.get_cmdline_user_args().has("--capture"):
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/pulka-reset-confirm.png")
	await _back()
	_check("Back cancels without closing settings or clearing records", hud.settings_open and not hud.reset_pending and data.best_score == 7654)
	hud._reset_button.pressed.emit()
	hud._reset_yes.pressed.emit()
	await _tick(2)
	var reloaded := SaveData.load_saved(TEST_SAVE)
	_check("confirmed reset persists both records", reloaded.best_distance == 0.0 and reloaded.best_score == 0)
	_check("reset preserves unlocked rides and preferences", reloaded.unlocked_distance == 4300.0 and reloaded.vehicle_id == "wok" and is_equal_approx(reloaded.music_volume, 0.35))
	_check("all previously unlocked rides remain selectable", main.call("_is_unlocked", VehicleSpec.all().back()))
	_check("unlocked cards stay undimmed", hud._menu.cards.back().modulate.a == 1.0)
	_check("success returns focus to Done", not hud.reset_pending and root.gui_get_focus_owner() == hud._settings_done)
	# The same confirmation works over pause without resuming or restarting.
	hud.close_settings()
	main.call("_choose_solo")
	main.call("_start_run")
	while main.get("state") == 1: await _tick(1)
	main.call("_set_paused", true)
	var sled: Sled = main.get("_sled")
	var stopped := sled.position
	main.call("_on_hud_pressed", &"settings")
	hud._reset_button.pressed.emit()
	await _back()
	_check("Back cancels confirmation while keeping the run paused", paused and hud.settings_open and sled.position == stopped)
	await _back()
	_check("next Back returns to pause", paused and hud._pause.visible and not hud.settings_open)
	main.call("_on_hud_pressed", &"resume")
	# A shorter run can beat the points record; a longer one can miss it.
	data.best_distance = 4300.0
	data.best_score = 7654
	await _finish_run(1200.0, 8200)
	reloaded = SaveData.load_saved(TEST_SAVE)
	_check("shorter run persists a new points record independently", reloaded.best_distance == 4300.0 and reloaded.best_score == 8200)
	_check("points record gets its own announcement", hud._over_record.visible and hud._over_record.text == "NYTT POÄNGREKORD!")
	_check("results have two rows with the run's distance and points", hud._over_rows.get_child_count() == 2 and _result_value(hud, 0) == "1 200 m" and _result_value(hud, 1) == "8 200")
	_check("each result shows its saved record underneath", _result_record(hud, 0) == "REKORD: 4 300 m" and _result_record(hud, 1) == "REKORD: 8 200")
	if OS.get_cmdline_user_args().has("--capture"):
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/pulka-score-record.png")
	await _finish_run(1200.0, 8200)
	_check("tying the points record does not announce a new one", not hud._over_record.visible)
	await _finish_run(5000.0, 5000)
	reloaded = SaveData.load_saved(TEST_SAVE)
	_check("longer run preserves the higher points record", reloaded.best_distance == 5000.0 and reloaded.best_score == 8200)
	_check("distance record gets its own announcement", hud._over_record.visible and hud._over_record.text == "NYTT DISTANSREKORD!")
	await _finish_run(6000.0, 9000)
	reloaded = SaveData.load_saved(TEST_SAVE)
	_check("one run can beat both records", reloaded.best_distance == 6000.0 and reloaded.best_score == 9000 and hud._over_record.text == "NYA REKORD!")
	main.queue_free()
	await process_frame
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(data.window_settings_path()))
	print("records test: %s" % ("all passed" if failures == 0 else "%d failed" % failures))
	quit(failures)

func _finish_run(distance: float, score: int) -> void:
	var player: Player = main.get("_players")[0]
	player.run_distance = distance
	player.bonus = score - int(distance)
	# _save points to TEST_SAVE, so exercise the real persistence path.
	main.set("_autopilot", false)
	main.call("_game_over")
	main.set("_autopilot", true)
	await _tick(2)

func _result_value(hud: Hud, row: int) -> String:
	return hud._over_rows.get_child(row).get_child(0).get_child(0).get_child(1).text

func _result_record(hud: Hud, row: int) -> String:
	return hud._over_rows.get_child(row).get_child(0).get_child(1).text

func _back() -> void:
	await _tick(20)
	Input.action_press(&"back")
	await _tick(1)
	Input.action_release(&"back")
	await _tick(2)

func _tick(frames: int) -> void:
	for frame in frames:
		main.call("_process", 1.0 / 60.0)
		await process_frame

func _check(message: String, condition: bool) -> void:
	print(("  ok    " if condition else "  FAIL  ") + message)
	if not condition: failures += 1
