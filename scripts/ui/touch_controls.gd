class_name TouchControls
extends Node
## Phone and tablet controls: hold the left or right half of the screen to
## steer, hold both halves to brake, swipe upwards to jump. Touch mode turns
## itself on with the first touch and off again when a key or pad is used.

## Upward travel, as a fraction of screen height, that counts as a swipe.
const SWIPE_DISTANCE := 0.06
const SWIPE_TIME := 0.4
## Touches starting in this top strip belong to the HUD (pause button).
const HUD_STRIP := 0.18


class Finger:
	var start: Vector2
	var position: Vector2
	var started_at: float
	var swiped := false


signal mode_changed(touch: bool)

var steer := 0.0
var brake := 0.0
var touch_mode := false:
	set(value):
		if value != touch_mode:
			touch_mode = value
			mode_changed.emit(value)

var _fingers: Dictionary = {}
var _jump_pending := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## True once per swipe.
func consume_jump() -> bool:
	var jumped := _jump_pending
	_jump_pending = false
	return jumped


## While touching, the ride tucks automatically whenever you are not steering.
func tuck() -> float:
	return 1.0 if touch_mode and steer == 0.0 and brake == 0.0 else 0.0


func reset() -> void:
	_fingers.clear()
	_jump_pending = false
	steer = 0.0
	brake = 0.0


func _input(event: InputEvent) -> void:
	var view := get_viewport().get_visible_rect().size
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		touch_mode = true
		if touch.pressed:
			if touch.position.y < view.y * HUD_STRIP:
				return
			var finger := Finger.new()
			finger.start = touch.position
			finger.position = touch.position
			finger.started_at = _now()
			_fingers[touch.index] = finger
		else:
			_fingers.erase(touch.index)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if not _fingers.has(drag.index):
			return
		var finger: Finger = _fingers[drag.index]
		finger.position = drag.position
		var rise := finger.start.y - finger.position.y
		if not finger.swiped and rise > view.y * SWIPE_DISTANCE and _now() - finger.started_at < SWIPE_TIME:
			finger.swiped = true
			_jump_pending = true
	elif event is InputEventKey or event is InputEventJoypadButton:
		touch_mode = false
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5:
		touch_mode = false
	_update_steering(view)


func _update_steering(view: Vector2) -> void:
	var left := false
	var right := false
	for finger: Finger in _fingers.values():
		if finger.swiped:
			continue
		if finger.position.x < view.x * 0.5:
			left = true
		else:
			right = true
	brake = 1.0 if left and right else 0.0
	steer = 0.0 if left == right else (-1.0 if left else 1.0)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
