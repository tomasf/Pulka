class_name InputSetup
extends RefCounted
## Registers all input actions in code so keyboard and gamepad bindings live in
## one readable place instead of serialized events in project.godot.


static func configure() -> void:
	_action(&"steer_left", [
		_key(KEY_A), _key(KEY_LEFT),
		_axis(JOY_AXIS_LEFT_X, -1.0), _button(JOY_BUTTON_DPAD_LEFT),
	], 0.15)
	_action(&"steer_right", [
		_key(KEY_D), _key(KEY_RIGHT),
		_axis(JOY_AXIS_LEFT_X, 1.0), _button(JOY_BUTTON_DPAD_RIGHT),
	], 0.15)
	_action(&"tuck", [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)], 0.1)
	_action(&"jump", [_key(KEY_SPACE), _button(JOY_BUTTON_A)])
	_action(&"confirm", [_key(KEY_ENTER), _key(KEY_KP_ENTER), _key(KEY_SPACE), _button(JOY_BUTTON_A), _button(JOY_BUTTON_START)])
	_action(&"back", [_key(KEY_BACKSPACE), _key(KEY_Q), _button(JOY_BUTTON_B)])
	_action(&"pause", [_key(KEY_ESCAPE), _key(KEY_P), _button(JOY_BUTTON_START)])
	_action(&"menu_left", [_key(KEY_A), _key(KEY_LEFT), _button(JOY_BUTTON_DPAD_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)], 0.5)
	_action(&"menu_right", [_key(KEY_D), _key(KEY_RIGHT), _button(JOY_BUTTON_DPAD_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)], 0.5)
	_action(&"start", [_button(JOY_BUTTON_START)])
	# On-screen buttons are pressed through ui_accept; make the pad's A count.
	if not InputMap.action_has_event(&"ui_accept", _button(JOY_BUTTON_A)):
		InputMap.action_add_event(&"ui_accept", _button(JOY_BUTTON_A))
	_action(&"settings", [_key(KEY_TAB), _key(KEY_O), _button(JOY_BUTTON_Y)])
	_action(&"fullscreen", [_key(KEY_F11), _key(KEY_F)])


static func _action(action: StringName, events: Array, deadzone := 0.5) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action, deadzone)
	for event: InputEvent in events:
		InputMap.action_add_event(action, event)


static func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event


static func _button(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.device = -1
	return event


static func _axis(axis: JoyAxis, direction: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = direction
	event.device = -1
	return event
