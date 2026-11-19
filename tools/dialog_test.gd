extends SceneTree
## Checks settings, pause/resume and the shorter countdown. Optional native
## --capture saves screenshots; --compact checks the fitted mobile layout.
var main: Node
var failures := 0
var compact := false
var capture := false
var steps: Array[int] = []

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	compact = OS.get_cmdline_user_args().has("--compact")
	capture = OS.get_cmdline_user_args().has("--capture")
	root.size = Vector2i(960, 540) if compact else Vector2i(1600, 900)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_process(false)
	main.set("_autopilot", true)
	main.set("_no_crash", true)
	var hud: Hud = main.get("_hud")
	await _tick(25)
	# The menu appears on real time, which headless frames can outrun.
	while not hud._menu.visible:
		await _tick(1)
	hud.open_settings(0.6, 0.4, 0.8)
	await _tick(20)
	_check("settings keeps the main menu background and hides its controls", hud.settings_open and hud._menu._background.is_visible_in_tree() and not hud._menu.canvas.visible)
	_check("volume values initialise without emitting changes", hud._sliders[0].value == 60 and hud._sliders[1].value == 40 and hud._sliders[2].value == 80)
	_check("settings initially focuses master volume", root.gui_get_focus_owner() == hud._sliders[0])
	await _shot("settings-focus-master")
	await _key(KEY_DOWN)
	_check("Down moves focus to the music slider", root.gui_get_focus_owner() == hud._sliders[1])
	await _key(KEY_RIGHT)
	_check("slider updates its value label", hud._sliders[1].get_parent().get_child(2).text == "45 %")
	_check("slider changes the audio bus", absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(SoundBank.MUSIC_BUS)) - linear_to_db(0.45 * 0.45)) < 0.01)
	await _shot("settings")
	# Close through HUD to avoid writing test volume changes to the user's save.
	hud.close_settings()
	await _tick(2)
	_check("closing settings returns to player choice", hud._menu.visible and hud._menu.canvas.visible and not hud.settings_open)
	main.call("_choose_solo")
	# The ride picker uses the actual slope, so keep that background there.
	await _tick(25)
	await create_timer(0.4, true).timeout
	hud.open_settings(0.6, 0.45, 0.8)
	_check("picker settings preserve the slope background", hud.settings_open and not hud._menu._background.visible and not hud._menu.canvas.visible)
	hud.close_settings()
	_check("closing picker settings restores its controls", hud._menu.picker.visible and hud._menu.canvas.visible)
	main.call("_start_run")
	var frames := 0
	while main.get("state") == 1 and frames < 240:
		await _tick(1)
		frames += 1
	_check("short countdown keeps 3, 2, 1 in order", steps == [3, 2, 1])
	_check("camera plus countdown takes about 3.2 seconds", frames >= 191 and frames <= 194 and main.get("state") == 2)
	main.call("_set_paused", true)
	var sled: Sled = main.get("_sled")
	var stopped := sled.position
	await _tick(20)
	# The fade runs on real time, which headless frames outrun.
	await create_timer(0.25, true).timeout
	_check("pause fades in while the tree is paused", paused and hud._pause.visible and hud._pause.modulate.a > 0.99)
	_check("pause focuses Continue", root.gui_get_focus_owner() is Button and root.gui_get_focus_owner().text == "Fortsätt")
	await _shot("pause")
	main.call("_on_hud_pressed", &"settings")
	await _tick(20)
	_check("settings preserves the paused game", paused and hud.settings_open and not hud._pause.visible and sled.position == stopped)
	hud.close_settings()
	await _tick(20)
	_check("closing settings restores pause and focus", paused and hud._pause.visible and root.gui_get_focus_owner().text == "Fortsätt")
	main.call("_on_hud_pressed", &"resume")
	await _tick(2)
	_check("Continue resumes play", not paused and main.get("state") == 2)
	main.queue_free()
	await process_frame
	await process_frame
	print("dialog test: %s" % ("all passed" if failures == 0 else "%d failed" % failures))
	quit(failures)

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await _tick(2)

func _tick(frames: int) -> void:
	for frame in frames:
		main.call("_process", 1.0 / 60.0)
		if main.get("state") == 1:
			var step: int = main.get("_countdown_step")
			if step > 0 and not steps.has(step): steps.append(step)
		await process_frame

func _shot(name: String) -> void:
	if capture:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/pulka-dialog-%s%s.png" % ["compact-" if compact else "", name])

func _check(message: String, condition: bool) -> void:
	print(("  ok    " if condition else "  FAIL  ") + message)
	if not condition: failures += 1
