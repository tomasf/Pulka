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
	await _tap(JOY_BUTTON_A)
	_check("A opens the ride picker without starting", int(main.get("state")) == 6)
	await _frames(20)
	_check("picker focuses the start button", root.gui_get_focus_owner() == hud._menu.start)
	await _tap(JOY_BUTTON_Y)
	_check("Y opens settings", hud.settings_open)
	await _tap(JOY_BUTTON_B)
	await _frames(15)
	_check("B closes settings", not hud.settings_open)
	_check("focus returns to start", root.gui_get_focus_owner() == hud._menu.start)
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
	await _tap(JOY_BUTTON_A)
	_check("A resumes", int(main.get("state")) == 2)
	await _tap(JOY_BUTTON_START)
	await _frames(2)
	await _tap(JOY_BUTTON_DPAD_RIGHT)
	_check("right reaches Börja om", _focused_text() == "Börja om")
	await _tap(JOY_BUTTON_DPAD_RIGHT)
	await _tap(JOY_BUTTON_DPAD_RIGHT)
	_check("right twice more reaches Till menyn", _focused_text() == "Till menyn")
	await _tap(JOY_BUTTON_A)
	_check("A on Till menyn returns to menu", int(main.get("state")) == 0)
	await _frames(25)
	await _tap(JOY_BUTTON_A)
	await _frames(20)
	await _tap(JOY_BUTTON_A)
	await create_timer(4.5).timeout
	await _tap(JOY_BUTTON_START)
	await _frames(2)
	await _tap(JOY_BUTTON_DPAD_RIGHT)
	await _tap(JOY_BUTTON_A)
	_check("Börja om restarts the run", int(main.get("state")) == 1 and not paused)
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
