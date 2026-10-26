extends SceneTree
## Feeds synthetic touches through TouchControls and checks the result.
## Run: Godot --headless --path . --script res://tools/touch_test.gd


var _touch: TouchControls


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var touch := TouchControls.new()
	_touch = touch
	root.add_child(touch)
	var view := root.get_visible_rect().size
	var left := Vector2(view.x * 0.2, view.y * 0.7)
	var right := Vector2(view.x * 0.8, view.y * 0.7)
	var failures := 0
	_press(0, left, true)
	failures += _check("left half steers left", touch.steer == -1.0)
	_press(1, right, true)
	failures += _check("both halves cancel out", touch.steer == 0.0)
	_press(0, left, false)
	failures += _check("right half steers right", touch.steer == 1.0)
	_press(1, right, false)
	failures += _check("released means straight", touch.steer == 0.0 and touch.tuck() == 1.0)
	_press(2, right, true)
	var drag := InputEventScreenDrag.new()
	drag.index = 2
	drag.position = right - Vector2(0, view.y * 0.1)
	root.push_input(drag, true)
	failures += _check("swipe up jumps once", touch.consume_jump() and not touch.consume_jump())
	failures += _check("swiping finger stops steering", touch.steer == 0.0)
	_press(2, right, false)
	_press(3, Vector2(view.x * 0.9, view.y * 0.05), true)
	failures += _check("touch in HUD strip is ignored", touch.steer == 0.0)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_A
	key.pressed = true
	root.push_input(key, true)
	failures += _check("keyboard leaves touch mode", not touch.touch_mode)
	print("touch test: %s" % ("all passed" if failures == 0 else "%d failed" % failures))
	quit(failures)


func _press(index: int, at: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = down
	root.push_input(event, true)


func _check(what: String, ok: bool) -> int:
	print(("  ok    " if ok else "  FAIL  ") + what + "   steer=%s" % _touch.steer)
	return 0 if ok else 1
