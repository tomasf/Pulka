extends SceneTree
## Drives the menus with synthetic gamepad input and checks focus and actions.
## Run: Godot --headless --path . --script res://tools/controller_menu_test.gd


var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	_check("A is on ui_accept", _has_joy_button(&"ui_accept", JOY_BUTTON_A))
	var hud: Hud = main.get("_hud")
	main.set("_autopilot", true)
	main.set("_vehicle", 0)
	main.call("_enter_menu")
	await _frames(25)
	_check("player choice focuses solo", root.gui_get_focus_owner() == hud._menu.solo)
	await _tap(JOY_BUTTON_DPAD_RIGHT)
	_check("right reaches two players", root.gui_get_focus_owner() == hud._menu.duo)
	await _tap(JOY_BUTTON_DPAD_LEFT)
	_check("left returns to solo", root.gui_get_focus_owner() == hud._menu.solo)
	await _tap(JOY_BUTTON_DPAD_UP)
	if Quality.is_desktop(): await _tap(JOY_BUTTON_DPAD_RIGHT)
	_check("the top row reaches About", root.gui_get_focus_owner() == hud._menu.about_button)
	await _tap(JOY_BUTTON_A)
	_check("A opens About without starting a run", hud.about_open and int(main.get("state")) == 0)
	await _tap(JOY_BUTTON_DPAD_LEFT)
	await _tap(JOY_BUTTON_A)
	_check("licenses open with the gamepad", hud.about_open and hud._about_licenses)
	await _tap(JOY_BUTTON_DPAD_DOWN)
	_check("the d-pad scrolls licenses", hud._about_text.get_v_scroll_bar().value > 0)
	await _tap(JOY_BUTTON_B)
	_check("B returns from licenses to About", hud.about_open and not hud._about_licenses)
	await _tap(JOY_BUTTON_B)
	_check("B closes About and restores its menu button", not hud.about_open and root.gui_get_focus_owner() == hud._menu.about_button)
	await _tap(JOY_BUTTON_DPAD_DOWN)
	if Quality.is_desktop():
		await _tap(JOY_BUTTON_DPAD_UP)
		_check("up reaches Avsluta on desktop", root.gui_get_focus_owner() == hud._menu.quit_button)
		await _tap(JOY_BUTTON_DPAD_RIGHT)
		_check("right from Avsluta reaches About", root.gui_get_focus_owner() == hud._menu.about_button)
		await _tap(JOY_BUTTON_DPAD_RIGHT)
		_check("right from About reaches settings", root.gui_get_focus_owner() == hud._menu.settings)
		await _tap(JOY_BUTTON_DPAD_LEFT)
		_check("left from settings reaches About", root.gui_get_focus_owner() == hud._menu.about_button)
		await _tap(JOY_BUTTON_DPAD_LEFT)
		_check("left from About returns to Avsluta", root.gui_get_focus_owner() == hud._menu.quit_button)
		await _tap(JOY_BUTTON_DPAD_DOWN)
		_check("down from Avsluta returns to player selection", root.gui_get_focus_owner() == hud._menu.duo)
		await _tap(JOY_BUTTON_DPAD_LEFT)
	await _tap(JOY_BUTTON_A)
	_check("A opens the ride picker without starting", int(main.get("state")) == 6)
	await _frames(20)
	_check("picker focuses the start button", root.gui_get_focus_owner() == hud._menu.start)
	# Past the picker's short guard against a held button (real time, which
	# headless frames outrun).
	await create_timer(0.3).timeout
	await _tap(JOY_BUTTON_Y)
	_check("Y opens settings", hud.settings_open)
	await _tap(JOY_BUTTON_B)
	await _frames(15)
	_check("B closes settings", not hud.settings_open)
	_check("focus returns to start", root.gui_get_focus_owner() == hud._menu.start)
	await create_timer(0.3).timeout
	var vehicle: int = main.get("_vehicle")
	await _tap(JOY_BUTTON_DPAD_RIGHT)
	_check("right changes ride and keeps focus on start", main.get("_vehicle") != vehicle and root.gui_get_focus_owner() == hud._menu.start)
	await _tap(JOY_BUTTON_A)
	_check("A starts a run exactly once", int(main.get("state")) == 1)
	await create_timer(4.5).timeout
	await _tap(JOY_BUTTON_START)
	_check("Start pauses", int(main.get("state")) == 3)
	await _frames(2)
	_check("pause focuses Fortsätt", _focused_text() == "Fortsätt")
	var field: TerrainField = main.get("_field")
	await _tap(JOY_BUTTON_B)
	_check("B dismisses pause and resumes the same run", int(main.get("state")) == 2 and not paused and main.get("_field") == field and not hud._pause.visible)
	await _tap(JOY_BUTTON_START)
	await _frames(2)
	await _tap(JOY_BUTTON_Y)
	_check("Y opens settings over pause", hud.settings_open and paused)
	await _tap(JOY_BUTTON_B)
	await _frames(15)
	_check("B in settings returns to pause without resuming", not hud.settings_open and paused and int(main.get("state")) == 3 and hud._pause.visible)
	await _tap(JOY_BUTTON_A)
	_check("A resumes", int(main.get("state")) == 2)
	await _tap(JOY_BUTTON_START)
	await _frames(2)
	await _tap(JOY_BUTTON_DPAD_RIGHT)
	_check("right on the wide Fortsätt stays put", _focused_text() == "Fortsätt")
	await _tap(JOY_BUTTON_DPAD_DOWN)
	_check("down reaches Börja om", _focused_text() == "Börja om")
	await _tap(JOY_BUTTON_DPAD_RIGHT)
	_check("right reaches Inställningar beside it", _focused_text() == "Inställningar")
	await _tap(JOY_BUTTON_DPAD_UP)
	_check("up from Inställningar returns to Fortsätt", _focused_text() == "Fortsätt")
	await _tap(JOY_BUTTON_DPAD_DOWN)
	await _tap(JOY_BUTTON_DPAD_RIGHT)
	await _tap(JOY_BUTTON_DPAD_DOWN)
	_check("down from Inställningar goes down, to Till menyn", _focused_text() == "Till menyn")
	await _tap(JOY_BUTTON_DPAD_DOWN)
	_check("down from the bottom wraps to Fortsätt", _focused_text() == "Fortsätt")
	await _tap(JOY_BUTTON_DPAD_UP)
	_check("up from the top wraps to Till menyn", _focused_text() == "Till menyn")
	# The stick: one clean step per push, however it wobbles at the edge or
	# springs back past the middle.
	await _stick(Vector2(0, -0.62))
	await _stick(Vector2(0, -0.58))
	await _stick(Vector2(0, -0.63))
	await _stick(Vector2(0, -0.55))
	_check("a stick wobbling at the edge moves up once", _focused_text() == "Börja om")
	await _stick(Vector2(0, 0.0))
	await _stick(Vector2(0, 0.7))
	_check("springing back past the middle doesn't move down", _focused_text() == "Börja om")
	await _stick(Vector2(0, 0.0))
	await create_timer(0.3).timeout
	await _stick(Vector2(0, 0.9))
	_check("a real push down after letting go moves down", _focused_text() == "Till menyn")
	await _stick(Vector2(0, 0.0))
	await create_timer(0.3).timeout
	await _stick(Vector2(0.7, 0.62))
	_check("an unclear diagonal doesn't move", _focused_text() == "Till menyn")
	await _stick(Vector2(0, 0.0))
	await create_timer(0.3).timeout
	var moves := [0]
	var count := func(_control: Control) -> void: moves[0] += 1
	root.gui_focus_changed.connect(count)
	await _stick(Vector2(0, -0.9))
	await create_timer(1.0).timeout
	root.gui_focus_changed.disconnect(count)
	_check("holding the stick repeats after a pause (%d steps in a second)" % moves[0], moves[0] >= 4 and moves[0] <= 7)
	await _stick(Vector2(0, 0.0))
	await create_timer(0.3).timeout
	while _focused_text() != "Till menyn":
		await _tap(JOY_BUTTON_DPAD_DOWN)
	await _tap(JOY_BUTTON_A)
	_check("A on Till menyn returns to menu", int(main.get("state")) == 0)
	await _frames(25)
	await _tap(JOY_BUTTON_A)
	await _frames(20)
	await _tap(JOY_BUTTON_A)
	await create_timer(4.5).timeout
	await _tap(JOY_BUTTON_START)
	await _frames(2)
	await _tap(JOY_BUTTON_DPAD_DOWN)
	await _tap(JOY_BUTTON_A)
	_check("Börja om restarts the run", int(main.get("state")) == 1 and not paused)
	# Game over: the retry button is focused at once, so one press of A
	# retries, but not a press that arrives right as the screen appears.
	await create_timer(4.5).timeout
	var rider: Player = main.get("_players")[0]
	rider.lives = 1
	main.call("_crash", "Test", rider)
	while int(main.get("state")) != 4:
		await _frames(1)
	await _frames(3)
	_check("game over focuses Åk igen straight away", _focused_text() == "Åk igen")
	await _tap(JOY_BUTTON_A)
	_check("A right as game over appears is ignored", int(main.get("state")) == 4)
	await create_timer(Hud.OVER_GUARD).timeout
	await _tap(JOY_BUTTON_A)
	_check("one press of A then retries", int(main.get("state")) == 1)
	print("controller menu test: %s" % ("all passed" if _failures == 0 else "%d failed" % _failures))
	main.queue_free()
	await process_frame
	await process_frame
	quit(_failures)


func _tap(button: JoyButton) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		await _frames(2)


## Holds the left stick at `at` for `count` frames.
func _stick(at: Vector2, count := 3) -> void:
	for axis in [[JOY_AXIS_LEFT_X, at.x], [JOY_AXIS_LEFT_Y, at.y]]:
		var event := InputEventJoypadMotion.new()
		event.axis = axis[0]
		event.axis_value = axis[1]
		event.device = 0
		Input.parse_input_event(event)
	await _frames(count)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _focused_text() -> String:
	var focused := root.gui_get_focus_owner()
	return (focused as Button).text if focused is Button else str(focused)


func _has_joy_button(action: StringName, button: JoyButton) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == button:
			return true
	return false


func _check(what: String, ok: bool) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what + ("" if ok else "   (focus: %s)" % _focused_text()))
	if not ok:
		_failures += 1
