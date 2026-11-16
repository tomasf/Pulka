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
var _center: Label
## The ride picker shown on this half before a race.
var _lobby: Control
var _lobby_ride: Label
var _lobby_who: Label
var _lobby_about: Label
var _lobby_bars: Array[Hud.StatBar] = []
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
	_center = Hud.label("", 110, Hud.WARM, 18)
	_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_center.modulate.a = 0.0
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
	var panel := ColorRect.new()
	panel.color = Color(0.05, 0.08, 0.2, 0.45)
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -340
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lobby.add_child(panel)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BEGIN
	column.offset_bottom = -30
	column.custom_minimum_size = Vector2(560, 0)
	column.offset_left = -280
	column.offset_right = 280
	column.add_theme_constant_override("separation", 4)
	_lobby.add_child(column)
	_lobby_who = Hud.label(_tag.text, 28, _tag.get_theme_color("font_color"), 8)
	_lobby_who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_lobby_who)
	_lobby_ride = Hud.label("", 48, Color(1, 1, 1), 12)
	_lobby_ride.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_lobby_ride)
	_lobby_about = Hud.label("", 22, Color(1, 1, 1, 0.9), 6)
	_lobby_about.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lobby_about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lobby_about.custom_minimum_size = Vector2(560, 50)
	column.add_child(_lobby_about)
	for stat in ["Fart", "Styrning", "Grepp"]:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 14)
		var name_label := Hud.label(stat, 22, Color(1, 1, 1), 6)
		name_label.custom_minimum_size = Vector2(120, 0)
		row.add_child(name_label)
		var bar := Hud.StatBar.new()
		bar.custom_minimum_size = Vector2(260, 16)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.tint = [Hud.HOT, Hud.COOL, Hud.WARM][_lobby_bars.size()]
		row.add_child(bar)
		_lobby_bars.append(bar)
		column.add_child(row)
	_lobby_controls = Hud.label("", 22, Hud.COOL, 6)
	_lobby_controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_lobby_controls)
	_lobby_status = Hud.label("", 36, Color(1, 1, 1), 10)
	_lobby_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_lobby_status)


## Before the race: the ride this player has picked, how they steer and
## whether they are ready. The race readouts are hidden meanwhile.
func show_lobby(spec: VehicleSpec, controls: String, ready: bool) -> void:
	_lobby_ride.text = spec.title if ready else "‹  %s  ›" % spec.title
	_lobby_about.text = spec.description
	var values := [spec.stat_speed, spec.stat_handling, spec.stat_grip]
	for i in _lobby_bars.size():
		_lobby_bars[i].value = values[i]
		_lobby_bars[i].queue_redraw()
	_lobby_controls.text = "Styr med %s" % controls
	_lobby_status.text = "KLAR! Väntar på den andra…" if ready else "Styr för att byta • Hoppa när du är klar"
	_lobby_status.add_theme_color_override("font_color", Hud.WARM if ready else Color(1, 1, 1))
	_lobby.visible = true
	_tag.visible = false
	_left.visible = false
	_speed.visible = false
	_place.visible = false


func hide_lobby() -> void:
	_lobby.visible = false
	_tag.visible = true
	_left.visible = true
	_speed.visible = true
	_place.visible = true


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


func show_center(text: String, color := Hud.WARM, hold := 0.6) -> void:
	_center.text = text
	_center.add_theme_color_override("font_color", color)
	_center.pivot_offset = size * 0.5
	_center.scale = Vector2.ONE * 1.5
	_center.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(_center, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if hold > 0.0:
		tween.tween_interval(hold)
		tween.tween_property(_center, "modulate:a", 0.0, 0.25)


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
	_center.modulate.a = 0.0
	_shown_place = 0
