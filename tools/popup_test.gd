extends SceneTree
## Fires pop-ups at the HUD and checks how they stack and how long they stay.
## Run: Godot --headless --path . --script res://tools/popup_test.gd


var _hud: Hud
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	_hud = main.get("_hud")
	(_hud.get("_popups") as Control).visible = true
	_hud.popup("ett", Hud.WARM, 44, 0.5)
	_hud.popup("två", Hud.WARM, 44, 0.5)
	await _seconds(0.3)
	_check("a note is still fully visible during its hold", _rows() == ["ett", "två"] and _alpha("ett") == 1.0)
	await _seconds(1.0)
	_check("notes leave when their hold is over", _rows().is_empty())
	await _seconds(0.5)
	_check("they are gone from the screen after fading", _on_screen() == 0)
	for text in ["a", "b", "c", "d", "e"]:
		_hud.popup(text, Hud.WARM, 44, 5.0)
	_check("only three rows, the oldest pushed out", _rows() == ["c", "d", "e"])
	await _seconds(0.6)
	_check("pushed-out notes have left the screen", _on_screen() == 3)
	_check("the rows sit in order from the top", _row_y("c") < _row_y("d") and _row_y("d") < _row_y("e"))
	_check("the top row is at the top of the stack", is_equal_approx(_row_y("c"), Hud.POPUP_TOP))
	_hud.popup("f", Hud.WARM, 44, 0.2)
	_hud.popup("g", Hud.WARM, 44, 5.0)
	await _seconds(0.1)
	_check("a short note under long ones", _rows() == ["e", "f", "g"])
	await _seconds(0.6)
	_check("the ones below close up when one leaves", _rows() == ["e", "g"] and is_equal_approx(_row_y("g"), Hud.POPUP_TOP + Hud.POPUP_ROW_SPACING))
	print("popup test: all passed" if _failures == 0 else "popup test: %d FAILED" % _failures)
	quit(_failures)


func _seconds(seconds: float) -> void:
	await create_timer(seconds).timeout


func _rows() -> Array[String]:
	var rows: Array[String] = []
	for note: Hud.PopupNote in _hud.get("_notes"):
		rows.append(note.label.text)
	return rows


func _labels() -> Array[Label]:
	var labels: Array[Label] = []
	for child in (_hud.get("_popups") as Control).get_children():
		if child is Label:
			labels.append(child)
	return labels


func _on_screen() -> int:
	return _labels().size()


func _find(text: String) -> Label:
	for note in _labels():
		if note.text == text:
			return note
	return null


func _alpha(text: String) -> float:
	return _find(text).modulate.a


func _row_y(text: String) -> float:
	return _find(text).offset_top


func _check(what: String, passed: bool) -> void:
	print("  %s  %s" % ["ok  " if passed else "FAIL", what])
	if not passed:
		_failures += 1
