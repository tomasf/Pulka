class_name PlayerControls
extends RefCounted
## What one player steers with. Alone, a player has every key and pad (the
## input actions). Two players each get their own pad, or one half of the
## keyboard: A/D and Space, or Left/Right and Enter.

## ALL is every key and pad through the input actions (one player);
## KEYBOARD is both halves of the keyboard but no pad.
enum Keys { ALL, KEYBOARD, LEFT, RIGHT, NONE }

const DEADZONE := 0.18

var keys := Keys.ALL
## Joypad device this player owns, or -1 for none of their own.
var pad := -1
var _jump_held := false
var _jumped := false


static func everything() -> PlayerControls:
	return PlayerControls.new()


## Who gets what when two play: with two pads each player has one (and a
## keyboard half too); with one pad the first player has the keyboard and
## the second the pad; with none they share the keyboard.
static func for_two(index: int) -> PlayerControls:
	var controls := PlayerControls.new()
	var pads := Input.get_connected_joypads()
	if pads.size() >= 2:
		controls.pad = pads[index]
		controls.keys = Keys.LEFT if index == 0 else Keys.RIGHT
	elif pads.size() == 1:
		controls.pad = -1 if index == 0 else pads[0]
		controls.keys = Keys.KEYBOARD if index == 0 else Keys.NONE
	else:
		controls.keys = Keys.LEFT if index == 0 else Keys.RIGHT
	return controls


## How the controls are described on the start screen.
func describe() -> String:
	var parts: Array[String] = []
	if pad >= 0:
		parts.append("handkontroll %d" % (pad + 1))
	match keys:
		Keys.LEFT:
			parts.append("A/D, Space")
		Keys.RIGHT:
			parts.append("←/→, Enter")
		Keys.KEYBOARD, Keys.ALL:
			parts.append("tangentbordet")
	return " eller ".join(parts)


## Reads the jump button once per frame, so a press is seen exactly once.
func poll() -> void:
	var held := _jump_down()
	_jumped = held and not _jump_held
	_jump_held = held


func steer() -> float:
	if keys == Keys.ALL:
		return Input.get_axis(&"steer_left", &"steer_right")
	var value := 0.0
	if keys == Keys.KEYBOARD:
		value += _key_axis([KEY_A, KEY_LEFT], [KEY_D, KEY_RIGHT])
	elif keys == Keys.LEFT:
		value += _key_axis([KEY_A], [KEY_D])
	elif keys == Keys.RIGHT:
		value += _key_axis([KEY_LEFT], [KEY_RIGHT])
	if pad >= 0:
		var axis := Input.get_joy_axis(pad, JOY_AXIS_LEFT_X)
		if absf(axis) > DEADZONE:
			value += (absf(axis) - DEADZONE) / (1.0 - DEADZONE) * signf(axis)
		if Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_LEFT):
			value -= 1.0
		if Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_RIGHT):
			value += 1.0
	return clampf(value, -1.0, 1.0)


func jump() -> bool:
	if keys == Keys.ALL:
		return Input.is_action_just_pressed(&"jump")
	return _jumped


## Whether jump is held down right now (grab tricks in the air).
func jump_held() -> bool:
	if keys == Keys.ALL:
		return Input.is_action_pressed(&"jump")
	return _jump_held


## Shakes this player's own pad (or every pad when they have them all).
func rumble(weak: float, strong: float, duration: float) -> void:
	if pad >= 0:
		Input.start_joy_vibration(pad, weak, strong, duration)
	elif keys == Keys.ALL:
		for device in Input.get_connected_joypads():
			Input.start_joy_vibration(device, weak, strong, duration)


func _jump_down() -> bool:
	if (keys == Keys.KEYBOARD or keys == Keys.LEFT) and Input.is_physical_key_pressed(KEY_SPACE):
		return true
	if (keys == Keys.KEYBOARD or keys == Keys.RIGHT) and (Input.is_physical_key_pressed(KEY_ENTER) or Input.is_physical_key_pressed(KEY_KP_ENTER)):
		return true
	return pad >= 0 and Input.is_joy_button_pressed(pad, JOY_BUTTON_A)


static func _key_axis(negative: Array, positive: Array) -> float:
	var value := 0.0
	for key: Key in negative:
		if Input.is_physical_key_pressed(key):
			value -= 1.0
			break
	for key: Key in positive:
		if Input.is_physical_key_pressed(key):
			value += 1.0
			break
	return value
