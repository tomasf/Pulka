class_name TouchControls
extends Node
## Phone and tablet controls: hold the left or right half of the screen to
## steer, swipe upwards to jump. A quick swipe to the right anywhere on the
## screen goes back. Touch mode turns itself on with the first touch and off
## again when a key or pad is used.

## Upward travel, as a fraction of screen height, that counts as a swipe.
const SWIPE_DISTANCE := 0.06
const SWIPE_TIME := 0.4
## Touches starting in this top strip belong to the HUD (pause button).
const HUD_STRIP := 0.18
## Rightward travel, as a fraction of screen width, that goes back.
const BACK_DISTANCE := 0.12
const BACK_TIME := 0.5


class Finger:
	var start: Vector2
	var position: Vector2
	var started_at: float
	var swiped := false
	## Started in the HUD strip: it can go back but neither steers nor jumps.
	var in_hud := false
	## Started on a slider or scroll area, whose own drags must not go back.
	var dragging_control := false
	var went_back := false


signal mode_changed(touch: bool)
## A swipe to the right, once per swipe.
signal back_swiped

var steer := 0.0
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


func reset() -> void:
	_fingers.clear()
	_jump_pending = false
	steer = 0.0


func _input(event: InputEvent) -> void:
	var view := get_viewport().get_visible_rect().size
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		touch_mode = true
		if touch.pressed:
			var finger := Finger.new()
			finger.start = touch.position
			finger.position = touch.position
			finger.started_at = _now()
			finger.in_hud = touch.position.y < view.y * HUD_STRIP
			_fingers[touch.index] = finger
			# The GUI sees the press after this; ask what it landed on then.
			_check_dragging_control.call_deferred(finger)
		else:
			_fingers.erase(touch.index)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if not _fingers.has(drag.index):
			return
		var finger: Finger = _fingers[drag.index]
		finger.position = drag.position
		var travel := finger.position - finger.start
		var age := _now() - finger.started_at
		if not finger.swiped and not finger.in_hud and -travel.y > view.y * SWIPE_DISTANCE and age < SWIPE_TIME:
			finger.swiped = true
			_jump_pending = true
		if not finger.went_back and not finger.dragging_control and travel.x > view.x * BACK_DISTANCE and travel.x > absf(travel.y) * 2.0 and age < BACK_TIME:
			finger.went_back = true
			finger.swiped = true
			back_swiped.emit()
	elif PlayerControls.prompt_kind(event) != PlayerControls.Prompt.NONE:
		touch_mode = false
	_update_steering(view)


func _update_steering(view: Vector2) -> void:
	var left := false
	var right := false
	for finger: Finger in _fingers.values():
		if finger.swiped or finger.in_hud:
			continue
		if finger.position.x < view.x * 0.5:
			left = true
		else:
			right = true
	steer = 0.0 if left == right else (-1.0 if left else 1.0)


func _check_dragging_control(finger: Finger) -> void:
	var control := get_viewport().gui_get_hovered_control()
	var focused := get_viewport().gui_get_focus_owner()
	# A slider takes focus when pressed, also where hover is not tracked.
	if focused is Range and focused.get_global_rect().has_point(finger.start):
		control = focused
	while control != null:
		if control is Range or control is ScrollContainer:
			finger.dragging_control = true
			return
		control = control.get_parent_control()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
