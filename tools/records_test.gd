extends SceneTree
## Exercises the real settings flow against an isolated save, never the user's.
const TEST_SAVE := "user://records-test.cfg"
var main: Node
var failures := 0

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
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
	main.queue_free()
	await process_frame
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	print("records test: %s" % ("all passed" if failures == 0 else "%d failed" % failures))
	quit(failures)

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
