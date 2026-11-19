class_name StickNavigator
extends Node
## Turns gamepad sticks into clean, single menu presses. A stick only counts
## as pressed well past the middle and only lets go close to it again, so it
## can't flicker on the edge; it picks the clearly dominant direction, ignores
## the stick springing back past centre after a release, and repeats evenly
## while held. Presses arrive as the usual ui_* (and menu_left/right) actions,
## so focus moves and sliders work as with the d-pad.

## Stick deflection that presses, and the one it must fall below to let go.
const PRESS := 0.6
const RELEASE := 0.3
## A diagonal only counts once one axis is clearly ahead of the other.
const CLEAR := 1.4
## Held: first repeat after DELAY, then every REPEAT seconds.
const DELAY := 0.42
const REPEAT := 0.13
## How long after a release a press the opposite way is taken as a rebound.
const REBOUND := 0.2

## Per joypad device: the direction held, time to its next repeat, and the
## last direction let go and when.
var _held := {}
var _repeat := {}
var _released := {}
var _released_at := {}
## Presses made this frame, per device (for menus each player drives).
var _taps := {}
var _pending: Array[StringName] = []
var _clock := 0.0
## Devices whose stick has moved (besides the connected pads).
var _seen := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Before anything reads this frame's actions.
	process_priority = -100


## Takes the sticks out of the ui_* and menu_left/right actions; this node
## presses those instead.
static func claim_actions() -> void:
	for action: StringName in [&"ui_left", &"ui_right", &"ui_up", &"ui_down", &"menu_left", &"menu_right"]:
		if not InputMap.has_action(action):
			continue
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadMotion:
				InputMap.action_erase_event(action, event)


## The direction `device`'s stick pressed this frame (zero if none).
func tap(device: int) -> Vector2i:
	return _taps.get(device, Vector2i.ZERO)


## The direction any stick pressed this frame.
func any_tap() -> Vector2i:
	for device: int in _taps:
		return _taps[device]
	return Vector2i.ZERO


func _process(delta: float) -> void:
	_clock += delta
	for action in _pending:
		_send(action, false)
	_pending.clear()
	_taps.clear()
	var devices := _seen.duplicate()
	for device in Input.get_connected_joypads():
		devices[device] = true
	for device: int in devices:
		feed(device, Vector2(Input.get_joy_axis(device, JOY_AXIS_LEFT_X), Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)), delta)


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion:
		_seen[event.device] = true


## One frame of `device`'s stick at `stick` (public for tests).
func feed(device: int, stick: Vector2, delta: float) -> void:
	var held: Vector2i = _held.get(device, Vector2i.ZERO)
	var direction := _direction(stick, held)
	if direction == Vector2i.ZERO:
		if held != Vector2i.ZERO:
			_released[device] = held
			_released_at[device] = _clock
		_held[device] = Vector2i.ZERO
		return
	if direction == held:
		_repeat[device] = float(_repeat.get(device, DELAY)) - delta
		if _repeat[device] <= 0.0:
			_repeat[device] = REPEAT
			_press(device, direction)
		return
	# A stick springing back past the middle is not a press the other way.
	var rebound: bool = held == Vector2i.ZERO and direction == -(_released.get(device, Vector2i.ZERO) as Vector2i) \
		and _clock - float(_released_at.get(device, -10.0)) < REBOUND
	if rebound:
		return
	_held[device] = direction
	_repeat[device] = DELAY
	_press(device, direction)


func _direction(stick: Vector2, held: Vector2i) -> Vector2i:
	var length := stick.length()
	if held != Vector2i.ZERO:
		if length < RELEASE:
			return Vector2i.ZERO
		var turned := _dominant(stick)
		return turned if turned != held and length >= PRESS and _clear(stick) else held
	if length < PRESS or not _clear(stick):
		return Vector2i.ZERO
	return _dominant(stick)


static func _dominant(stick: Vector2) -> Vector2i:
	if absf(stick.x) > absf(stick.y):
		return Vector2i(int(signf(stick.x)), 0)
	return Vector2i(0, int(signf(stick.y)))


static func _clear(stick: Vector2) -> bool:
	return maxf(absf(stick.x), absf(stick.y)) > CLEAR * minf(absf(stick.x), absf(stick.y))


func _press(device: int, direction: Vector2i) -> void:
	_taps[device] = direction
	var actions: Array[StringName] = []
	match direction:
		Vector2i.LEFT:
			actions = [&"ui_left", &"menu_left"]
		Vector2i.RIGHT:
			actions = [&"ui_right", &"menu_right"]
		Vector2i.UP:
			actions = [&"ui_up"]
		Vector2i.DOWN:
			actions = [&"ui_down"]
	for action in actions:
		_send(action, true)
		_pending.append(action)


func _send(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)
