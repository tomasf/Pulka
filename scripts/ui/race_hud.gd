class_name RaceHud
extends Control
## One player's half of a split-screen race: who they are, their place,
## how far is left to the finish and how fast they go, with their own
## call-outs, splats and flashes.

const ROWS := 3
const ROW_HEIGHT := 44.0
const ROW_TOP := 150.0
const HOLD := 1.6

var _tag: Label
var _place: Label
var _left: Label
var _speed: Label
var _center: CountdownDisplay
## The ride picker shown on this half before a race.
var _lobby: Control
var _lobby_ride: Label
var _lobby_who: Label
var _lobby_bars: Array[MenuFlow.Stat] = []
var _lobby_preview: TextureRect
var _ready_button: Button
signal lobby_action(action: StringName)
var _lobby_controls: Label
var _lobby_status: Label
var _flash: ColorRect
var _notes: Array[Label] = []
var _shown_place := 0


func setup(index: int, color: Color) -> RaceHud:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 1, 1, 0)
	add_child(_flash)
	_tag = Hud.label("Spelare %d" % (index + 1), 30, color, 8)
	_tag.position = Vector2(28, 18)
	add_child(_tag)
	_place = Hud.label("", 64, Hud.WARM, 14)
	_place.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_place.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_place.offset_left = -200
	_place.offset_right = -28
	_place.offset_top = 10
	add_child(_place)
	_left = Hud.label("", 34, Color(1, 1, 1), 8)
	_left.position = Vector2(28, 58)
	add_child(_left)
	_speed = Hud.label("0", 40, Color(1, 1, 1), 10)
	_speed.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_speed.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_speed.offset_top = -70
	_speed.offset_left = -260
	_speed.offset_right = -28
	add_child(_speed)
	_center = CountdownDisplay.new()
	add_child(_center)
	_build_lobby()
	return self


## A panel at the bottom of the half: the ride with arrows either side,
## what it is like, its stats, the controls and whether this player is set.
func _build_lobby() -> void:
	_lobby = Control.new()
	_lobby.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lobby.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lobby.visible = false
	add_child(_lobby)
	var canvas := Control.new()
	canvas.size = Vector2(800, 900)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lobby.add_child(canvas)
	var fit := func() -> void:
		var factor := minf(size.x / 800.0, size.y / 900.0)
		canvas.scale = Vector2.ONE * factor
		canvas.position = (size - Vector2(800, 900) * factor) * 0.5
	resized.connect(fit)
	fit.call_deferred()
	var badge := Panel.new()
	badge.position = Vector2(34, 108)
	badge.size = Vector2(180, 42)
	badge.add_theme_stylebox_override("panel", MenuFlow.style(Color(0.055, 0.07, 0.15, 0.88), Color.TRANSPARENT, 14))
	canvas.add_child(badge)
	_lobby_who = MenuFlow.caption(_tag.text.to_upper(), 20, _tag.get_theme_color("font_color"))
	_lobby_who.position = Vector2(48, 116)
	canvas.add_child(_lobby_who)
	var panel := Panel.new()
	panel.position = Vector2(34, 654)
	panel.size = Vector2(732, 218)
	panel.add_theme_stylebox_override("panel", MenuFlow.style(Color(0.055, 0.07, 0.15, 0.94), Color(1, 1, 1, 0.18), 24))
	canvas.add_child(panel)
	_lobby_ride = MenuFlow.caption("", 38, Color.WHITE, true)
	_lobby_ride.position = Vector2(120, 682)
	_lobby_ride.size.x = 340
	_lobby_ride.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	canvas.add_child(_lobby_ride)
	for side in [-1, 1]:
		var arrow := Button.new()
		arrow.text = "‹" if side < 0 else "›"
		arrow.position = Vector2(52 if side < 0 else 466, 681)
		arrow.size = Vector2(56, 58)
		MenuFlow.skin(arrow)
		arrow.focus_mode = Control.FOCUS_NONE
		var action := &"previous" if side < 0 else &"next"
		arrow.pressed.connect(func() -> void: lobby_action.emit(action))
		canvas.add_child(arrow)
	_lobby_preview = TextureRect.new()
	_lobby_preview.position = Vector2(540, 664)
	_lobby_preview.size = Vector2(210, 112)
	_lobby_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_lobby_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_lobby_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_lobby_preview)
	for i in 3:
		var name_label := MenuFlow.caption(["Fart", "Styrning", "Grepp"][i], 16, MenuFlow.MUTED)
		name_label.position = Vector2(64, 750 + i * 28)
		canvas.add_child(name_label)
		var bar := MenuFlow.Stat.new()
		bar.position = Vector2(174, 756 + i * 28)
		bar.size = Vector2(170, 12)
		bar.tint = [MenuFlow.CORAL, MenuFlow.ICE, MenuFlow.LIME][i]
		canvas.add_child(bar)
		_lobby_bars.append(bar)
	_ready_button = Button.new()
	_ready_button.text = "KLAR  ✓"
	_ready_button.position = Vector2(538, 783)
	_ready_button.size = Vector2(206, 64)
	_ready_button.focus_mode = Control.FOCUS_NONE
	MenuFlow.skin(_ready_button, true)
	_ready_button.pressed.connect(func() -> void: lobby_action.emit(&"ready"))
	canvas.add_child(_ready_button)
	_lobby_controls = MenuFlow.caption("", 15, MenuFlow.MUTED)
	_lobby_controls.position = Vector2(64, 843)
	canvas.add_child(_lobby_controls)
	_lobby_status = MenuFlow.caption("", 16, MenuFlow.ICE)
	_lobby_status.position = Vector2(378, 795)
	canvas.add_child(_lobby_status)


func show_lobby(spec: VehicleSpec, controls: String, ready: bool) -> void:
	_lobby.modulate.a = 1.0
	_lobby_ride.text = spec.title
	_lobby_preview.texture = MenuFlow.vehicle_texture(spec.model)
	var values := [spec.stat_speed, spec.stat_handling, spec.stat_grip]
	for i in _lobby_bars.size():
		_lobby_bars[i].value = values[i]
		_lobby_bars[i].queue_redraw()
	_lobby_controls.text = controls.replace("tangentbordet", "A/D, Space").replace("Styr med ", "")
	_lobby_status.text = "Väntar…" if ready else ""
	_ready_button.text = "✓  REDO" if ready else "KLAR  ✓"
	_lobby.visible = true
	_tag.visible = false
	_left.visible = false
	_speed.visible = false
	_place.visible = false


func hide_lobby() -> void:
	var fade := create_tween()
	fade.tween_property(_lobby, "modulate:a", 0.0, 0.25)
	fade.tween_callback(_lobby.hide)
	_tag.visible = false
	_left.visible = false
	_speed.visible = false
	_place.visible = false


func show_race() -> void:
	for readout in [_tag, _left, _speed, _place]: readout.visible = true


## `left` is metres still to go; `place` is 1 or 2.
func update_race(left: float, speed: float, place: int, finished: bool) -> void:
	_left.text = "I mål!" if finished else Hud.group_digits(int(ceilf(maxf(left, 0.0)))) + " m kvar"
	_speed.text = "%d km/h" % int(speed * 3.6)
	var text := "1:a" if place == 1 else "2:a"
	if place != _shown_place:
		_shown_place = place
		_place.text = text
		_place.add_theme_color_override("font_color", Hud.WARM if place == 1 else Color(0.8, 0.85, 0.95))
		_place.pivot_offset = Vector2(_place.size.x, 32)
		_place.scale = Vector2.ONE * 1.4
		create_tween().tween_property(_place, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A call-out under the ones already up; a full stack drops its oldest.
func popup(text: String, color := Hud.WARM, size := 44, hold := HOLD) -> void:
	if _notes.size() >= ROWS:
		_retire(_notes[0])
	var note := Hud.label(text, roundi(size * 0.75), color, 8)
	note.set_anchors_preset(Control.PRESET_TOP_WIDE)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.offset_top = ROW_TOP + _notes.size() * ROW_HEIGHT
	note.offset_bottom = note.offset_top + ROW_HEIGHT
	add_child(note)
	_notes.append(note)
	var life := note.create_tween()
	life.tween_interval(hold)
	life.tween_callback(_retire.bind(note))


func _retire(note: Label) -> void:
	if not _notes.has(note):
		return
	_notes.erase(note)
	var fade := note.create_tween()
	fade.tween_property(note, "modulate:a", 0.0, 0.3)
	fade.tween_callback(note.queue_free)
	for i in _notes.size():
		_notes[i].create_tween().tween_property(_notes[i], "offset_top", ROW_TOP + i * ROW_HEIGHT, 0.2)
		_notes[i].offset_bottom = ROW_TOP + i * ROW_HEIGHT + ROW_HEIGHT


func show_center(text: String, color := Color.WHITE, hold := 0.65) -> void:
	_center.show_count(text, color, hold)


func flash(color: Color, amount := 0.6) -> void:
	_flash.color = Color(color, amount * 0.6)
	create_tween().tween_property(_flash, "color:a", 0.0, 0.35)


func splat() -> void:
	var blot := Hud.Splat.new()
	blot.position = Vector2(randf_range(0.25, 0.75) * size.x, randf_range(0.3, 0.7) * size.y)
	blot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(blot)
	var tween := blot.create_tween()
	tween.tween_interval(1.0)
	tween.tween_property(blot, "modulate:a", 0.0, 1.2)
	tween.tween_callback(blot.queue_free)


func clear() -> void:
	for note in _notes:
		note.queue_free()
	_notes.clear()
	_center.clear()
	_shown_place = 0
