class_name Hud
extends CanvasLayer
## All 2D interface: in-game readouts, pop-up callouts, menu, pause and the
## game-over screen. Built in code; no theme resources needed.

const WARM := Color(1.0, 0.85, 0.3)
const HOT := Color(1.0, 0.35, 0.2)
const COOL := Color(0.6, 0.9, 1.0)
const INK := Color(0.08, 0.1, 0.2)
## Seconds a pop-up message stays fully visible before fading.
const POPUP_HOLD := 2.4


class Mittens extends Control:
	var lives := 3
	var max_lives := 3

	func _draw() -> void:
		for i in max_lives:
			var origin := Vector2(i * 46.0, 0.0)
			var color := Color(0.92, 0.18, 0.2) if i < lives else Color(0.4, 0.4, 0.45, 0.5)
			draw_rect(Rect2(origin + Vector2(4, 30), Vector2(30, 10)), Color(1, 1, 1) if i < lives else color)
			draw_circle(origin + Vector2(19, 14), 15.0, color)
			draw_rect(Rect2(origin + Vector2(4, 14), Vector2(30, 18)), color)
			draw_circle(origin + Vector2(36, 20), 6.0, color)


## A splat of snow on the "lens" after a snowball hit.
class Splat extends Control:
	var blobs: Array[Vector3] = []

	func _init() -> void:
		for i in 14:
			var angle := randf() * TAU
			var reach := randf() * 110.0
			blobs.append(Vector3(cos(angle) * reach, sin(angle) * reach * 0.8, randf_range(25.0, 70.0)))

	func _draw() -> void:
		for blob in blobs:
			draw_circle(Vector2(blob.x, blob.y), blob.z, Color(1, 1, 1, 0.92))


class StatBar extends Control:
	var value := 0.5
	var tint := Color(1, 1, 1)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.15))
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * value, size.y)), tint)


var _game: Control
var _distance: Label
var _score: Label
var _speed: Label
var _speed_unit: Label
var _mittens: Mittens
var _center: Label
var _popups: Control
var _slot_free_at: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]

var _menu: Control
var _menu_vehicle: Label
var _menu_description: Label
var _menu_locked: Label
var _menu_bars: Array[StatBar] = []
var _menu_best: Label

var _pause: Control
var _over: Control
var _over_title: Label
var _over_body: Label
var _over_record: Label
var _time := 0.0

var _settings: Control
var _sliders: Array[HSlider] = []
var _covered: Array[Control] = []
## Full-screen backgrounds that must bleed past the safe area.
var _backdrops: Array[Control] = []
var _menu_column: VBoxContainer
var _menu_start: Button
var _menu_settings: Button
var _touch_mode := false
var _last_row_first: Button
## The button each screen focuses first, for keyboard and controller play.
var _default_focus: Dictionary = {}
var _menu_panel: ColorRect

## Emitted while a volume slider moves: 0 = master, 1 = music, 2 = effects.
signal volume_changed(channel: int, value: float)
## Emitted by on-screen buttons: start, previous, next, settings, pause,
## resume, menu, retry, close_settings.
signal pressed(action: StringName)

## Hint labels with a keyboard/pad text and a touch text: [label, keys, touch].
var _hints: Array = []
var _pause_button: Button
var _fullscreen_button: Button
var _fullscreen_toggle: Button

var settings_open: bool:
	get:
		return _settings.visible


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_game()
	_build_menu()
	_build_pause()
	_build_game_over()
	_build_settings()
	if OS.has_feature("web"):
		_build_fullscreen_button()
	_default_focus[_menu] = _menu_start
	# Left/right on the menu pick a ride, so focus only moves up and down there.
	for button in [_menu_start, _menu_settings]:
		button.focus_neighbor_left = button.get_path()
		button.focus_neighbor_right = button.get_path()
	_menu_start.focus_neighbor_bottom = _menu_settings.get_path()
	_menu_settings.focus_neighbor_top = _menu_start.get_path()
	show_screen("")
	get_viewport().size_changed.connect(_fit_safe_area)
	_fit_safe_area()


func _process(delta: float) -> void:
	_time += delta
	var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	if is_instance_valid(_fullscreen_toggle):
		_fullscreen_toggle.text = "På" if fullscreen else "Av"
	if is_instance_valid(_fullscreen_button):
		_fullscreen_button.text = "Fönsterläge" if fullscreen else "Fullskärm"
		_fullscreen_button.tooltip_text = "Lämna fullskärm (Esc / F)" if fullscreen else "Visa i fullskärm (F)"
	if _over.visible:
		_over_record.scale = Vector2.ONE * (1.0 + 0.06 * sin(_time * 6.0))
	if _menu.visible:
		_fit_menu()


## Shrinks the menu column to fit short screens (phones in landscape).
func _fit_menu() -> void:
	var needed := _menu_column.get_combined_minimum_size().y
	var room := _menu.size.y - _menu_column.position.y - 24.0
	var fit := clampf(room / needed, 0.5, 1.0) if needed > 0.0 else 1.0
	_menu_column.scale = Vector2.ONE * fit
	_menu_panel.offset_right = 720.0 * fit


static func label(text: String, font_size: int, color := Color(1, 1, 1), outline := 10) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	result.add_theme_color_override("font_outline_color", INK)
	result.add_theme_constant_override("outline_size", outline)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result


static func group_digits(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	while digits.length() > 3:
		out = " " + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if value < 0 else "") + digits + out


## Keeps the HUD clear of notches and rounded corners on phones.
func _fit_safe_area() -> void:
	# Only real devices: on a desktop the safe area describes the monitor.
	if not OS.has_feature("mobile"):
		return
	var window := Vector2(DisplayServer.window_get_size())
	var safe := Rect2(DisplayServer.get_display_safe_area())
	if window.x <= 0.0 or safe.size.x <= 0.0:
		return
	var scale_factor := get_viewport().get_visible_rect().size.x / window.x
	for root in [_game, _menu, _pause, _over, _settings, _popups]:
		var control := root as Control
		control.offset_left = safe.position.x * scale_factor
		control.offset_top = safe.position.y * scale_factor
		control.offset_right = -(window.x - safe.end.x) * scale_factor
		control.offset_bottom = -(window.y - safe.end.y) * scale_factor
	for backdrop in _backdrops:
		var inset := backdrop.get_parent() as Control
		backdrop.offset_left = -inset.offset_left
		backdrop.offset_top = -inset.offset_top
		backdrop.offset_bottom = -inset.offset_bottom
		if backdrop.anchor_right == 1.0:
			backdrop.offset_right = -inset.offset_right


func _full_rect() -> Control:
	var control := Control.new()
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(control)
	return control


func _dim(parent: Control, alpha: float) -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.08, 0.18, alpha)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(shade)
	_backdrops.append(shade)


func _centered_column(parent: Control, separation := 14) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(center)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", separation)
	center.add_child(column)
	return column


func _button(text: String, action: StringName, font_size := 34, accent := false, focusable := true) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL if focusable else Control.FOCUS_NONE
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.border_color = WARM if not accent else Color(1, 1, 1)
	ring.set_border_width_all(5)
	ring.set_corner_radius_all(20)
	ring.set_expand_margin_all(6)
	button.add_theme_stylebox_override("focus", ring)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", INK if accent else Color(1, 1, 1))
	button.add_theme_color_override("font_hover_color", INK if accent else WARM)
	button.add_theme_color_override("font_pressed_color", INK)
	for state in ["normal", "hover", "pressed"]:
		var box := StyleBoxFlat.new()
		var base := WARM if accent else Color(0.08, 0.1, 0.22, 0.65)
		box.bg_color = base.lightened(0.15) if state == "hover" else (WARM if state == "pressed" else base)
		box.border_color = Color(1, 1, 1, 0.5)
		box.set_border_width_all(2)
		box.set_corner_radius_all(16)
		box.content_margin_left = 26
		box.content_margin_right = 26
		box.content_margin_top = 8
		box.content_margin_bottom = 10
		button.add_theme_stylebox_override(state, box)
	button.pressed.connect(func() -> void: pressed.emit(action))
	return button


## Always available on the web, beside the pause button during a run.
func _build_fullscreen_button() -> void:
	var controls := _full_rect()
	_fullscreen_button = _button("Fullskärm", &"fullscreen", 24, false, false)
	_fullscreen_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_fullscreen_button.offset_left = -340
	_fullscreen_button.offset_right = -130
	_fullscreen_button.offset_top = 92
	_fullscreen_button.offset_bottom = 150
	controls.add_child(_fullscreen_button)


func _hint(text: String, touch_text: String, font_size: int, color: Color, outline := 8) -> Label:
	var hint := label(text, font_size, color, outline)
	_hints.append([hint, text, touch_text])
	return hint


## Swaps every hint between keyboard/pad wording and touch wording.
func set_touch_mode(touch: bool) -> void:
	_touch_mode = touch
	if touch:
		_release_focus()
	else:
		_focus_current()
	for entry: Array in _hints:
		var hint: Label = entry[0]
		hint.text = entry[2] if touch else entry[1]
		hint.visible = hint.text != ""


# --- In-game ---

func _build_game() -> void:
	_game = _full_rect()
	_distance = label("0 m", 56)
	_distance.position = Vector2(36, 22)
	_game.add_child(_distance)
	_score = label("Poäng 0", 28, WARM, 8)
	_score.position = Vector2(40, 96)
	_game.add_child(_score)

	_mittens = Mittens.new()
	_mittens.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_mittens.offset_left = -180
	_mittens.offset_right = -36
	_mittens.offset_top = 36
	_mittens.offset_bottom = 80
	_game.add_child(_mittens)

	_speed = label("0", 84, Color(1, 1, 1), 14)
	_speed.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speed.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_speed.offset_top = -150
	_speed.offset_left = -200
	_speed.offset_right = 200
	_game.add_child(_speed)
	_speed_unit = label("km/h", 26, COOL, 8)
	_speed_unit.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_speed_unit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speed_unit.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_speed_unit.offset_top = -52
	_speed_unit.offset_left = -100
	_speed_unit.offset_right = 100
	_game.add_child(_speed_unit)

	_pause_button = _button("II", &"pause", 30, false, false)
	_pause_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_pause_button.offset_left = -110
	_pause_button.offset_right = -36
	_pause_button.offset_top = 92
	_pause_button.offset_bottom = 150
	_pause_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_game.add_child(_pause_button)

	_center = label("", 150, WARM, 22)
	_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_center.pivot_offset = Vector2(800, 450)
	add_child(_center)

	_popups = _full_rect()


## `multiplier` above 1 tints the score and shows the factor (northern lights).
func update_game(distance: float, score: int, speed: float, lives: int, max_lives: int, multiplier: float) -> void:
	_distance.text = group_digits(int(distance)) + " m"
	var boosted := multiplier > 1.0
	_score.text = "Poäng " + group_digits(score) + ("  ×%d" % int(multiplier) if boosted else "")
	_score.add_theme_color_override("font_color", Color(0.5, 1.0, 0.7) if boosted else WARM)
	var kmh := int(speed * 3.6)
	_speed.text = str(kmh)
	var heat := clampf((speed - 20.0) / 30.0, 0.0, 1.0)
	_speed.add_theme_color_override("font_color", Color(1, 1, 1).lerp(HOT, heat))
	_speed.scale = Vector2.ONE
	if _mittens.lives != lives or _mittens.max_lives != max_lives:
		_mittens.lives = lives
		_mittens.max_lives = max_lives
		_mittens.queue_redraw()


func splat() -> void:
	var blot := Splat.new()
	var view := get_viewport().get_visible_rect().size
	blot.position = Vector2(randf_range(0.25, 0.75) * view.x, randf_range(0.3, 0.7) * view.y)
	blot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popups.add_child(blot)
	var tween := blot.create_tween()
	tween.tween_interval(1.0)
	tween.set_parallel(true)
	tween.tween_property(blot, "modulate:a", 0.0, 1.2)
	tween.tween_property(blot, "position:y", blot.position.y + 80.0, 1.2)
	tween.set_parallel(false)
	tween.tween_callback(blot.queue_free)


func show_center(text: String, color := WARM) -> void:
	_center.text = text
	_center.add_theme_color_override("font_color", color)
	_center.pivot_offset = _center.size * 0.5
	_center.scale = Vector2.ONE * 1.6
	_center.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(_center, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.45)
	tween.tween_property(_center, "modulate:a", 0.0, 0.25)


func popup(text: String, color := WARM, size := 44) -> void:
	var note := label(text, size, color, 12)
	note.set_anchors_preset(Control.PRESET_TOP_WIDE)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Use the slot that frees up first so long-lived notes never overlap.
	var now := Time.get_ticks_msec() / 1000.0
	var slot := 0
	for i in _slot_free_at.size():
		if _slot_free_at[i] < _slot_free_at[slot]:
			slot = i
	_slot_free_at[slot] = now + POPUP_HOLD + 0.5
	var y := 170.0 + slot * 62.0
	note.offset_top = y
	note.offset_bottom = y + 60.0
	_popups.add_child(note)
	note.pivot_offset = Vector2(get_viewport().get_visible_rect().size.x * 0.5, 30)
	note.scale = Vector2.ONE * 1.5
	var tween := note.create_tween()
	tween.tween_property(note, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(POPUP_HOLD)
	tween.set_parallel(true)
	tween.tween_property(note, "modulate:a", 0.0, 0.6)
	tween.tween_property(note, "offset_top", y - 40.0, 0.6)
	tween.set_parallel(false)
	tween.tween_callback(note.queue_free)


# --- Menu ---

func _build_menu() -> void:
	_menu = _full_rect()
	var gradient := ColorRect.new()
	gradient.color = Color(0.05, 0.08, 0.2, 0.35)
	gradient.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	gradient.offset_right = 720
	_menu.add_child(gradient)
	_backdrops.append(gradient)
	_menu_panel = gradient
	var column := VBoxContainer.new()
	_menu_column = column
	column.position = Vector2(80, 36)
	column.custom_minimum_size = Vector2(600, 0)
	column.add_theme_constant_override("separation", 9)
	_menu.add_child(column)
	var title := label("PULKA!", 100, WARM, 22)
	title.rotation = -0.05
	column.add_child(title)
	column.add_child(label("Den oändliga backen", 34, COOL, 10))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	column.add_child(spacer)
	column.add_child(label("Välj åkdon", 26, Color(1, 1, 1, 0.7), 6))
	var picker := HBoxContainer.new()
	picker.add_theme_constant_override("separation", 18)
	picker.add_child(_button("‹", &"previous", 44, false, false))
	_menu_vehicle = label("Pulka", 64, Color(1, 1, 1), 14)
	_menu_vehicle.custom_minimum_size = Vector2(330, 0)
	_menu_vehicle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	picker.add_child(_menu_vehicle)
	picker.add_child(_button("›", &"next", 44, false, false))
	column.add_child(picker)
	_menu_description = label("", 26, Color(1, 1, 1), 8)
	_menu_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_menu_description.custom_minimum_size = Vector2(600, 70)
	column.add_child(_menu_description)
	_menu_locked = label("", 28, HOT, 8)
	column.add_child(_menu_locked)
	for stat in ["Fart", "Styrning", "Grepp"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var name_label := label(stat, 26, Color(1, 1, 1), 6)
		name_label.custom_minimum_size = Vector2(150, 0)
		row.add_child(name_label)
		var bar := StatBar.new()
		bar.custom_minimum_size = Vector2(300, 20)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.tint = [HOT, COOL, WARM][_menu_bars.size()]
		row.add_child(bar)
		_menu_bars.append(bar)
		column.add_child(row)
	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 8)
	column.add_child(spacer2)
	var go_row := HBoxContainer.new()
	go_row.add_theme_constant_override("separation", 20)
	_menu_start = _button("Åk!", &"start", 44, true)
	go_row.add_child(_menu_start)
	column.add_child(go_row)
	column.add_child(_hint("Styr: A/D, pilar eller spak\nLuta fram: W / RT • Hopp: Space / A",
		"Håll vänster eller höger sida för att styra\nSvep uppåt för att hoppa", 20, Color(1, 1, 1, 0.85), 6))
	_menu_best = label("", 28, COOL, 8)
	column.add_child(_menu_best)
	var settings := _button("Inställningar", &"settings", 26)
	_menu_settings = settings
	settings.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	settings.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	settings.grow_vertical = Control.GROW_DIRECTION_BEGIN
	settings.offset_right = -36
	settings.offset_bottom = -32
	_menu.add_child(settings)


func update_menu(spec: VehicleSpec, unlocked: bool, best_distance: float, best_score: int) -> void:
	_menu_vehicle.text = spec.title
	_menu_description.text = spec.description
	_menu_locked.text = "" if unlocked else "Låst – åk %s m för att låsa upp" % group_digits(int(spec.unlock_distance))
	_menu_locked.visible = not unlocked
	var values := [spec.stat_speed, spec.stat_handling, spec.stat_grip]
	for i in _menu_bars.size():
		_menu_bars[i].value = values[i]
		_menu_bars[i].modulate.a = 1.0 if unlocked else 0.4
		_menu_bars[i].queue_redraw()
	if best_distance > 0.0:
		_menu_best.text = "Rekord: %s m  •  %s poäng" % [group_digits(int(best_distance)), group_digits(best_score)]
	else:
		_menu_best.text = "Inget rekord än. Dags att ändra på det!"


# --- Pause and game over ---

func _build_pause() -> void:
	_pause = _full_rect()
	_dim(_pause, 0.55)
	var column := _centered_column(_pause)
	var title := label("Paus", 110, WARM, 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	column.add_child(_button_row([["Fortsätt", &"resume", true], ["Börja om", &"retry", false], ["Inställningar", &"settings", false], ["Till menyn", &"menu", false]]))
	_default_focus[_pause] = _last_row_first


func _build_game_over() -> void:
	_over = _full_rect()
	_dim(_over, 0.45)
	var column := _centered_column(_over, 18)
	_over_title = label("", 84, WARM, 20)
	_over_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_over_title)
	_over_body = label("", 40, Color(1, 1, 1), 10)
	_over_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_over_body)
	_over_record = label("NYTT REKORD!", 60, HOT, 16)
	_over_record.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_over_record.pivot_offset = Vector2(300, 30)
	column.add_child(_over_record)
	column.add_child(_button_row([["Åk igen", &"retry", true], ["Meny", &"menu", false]]))
	_default_focus[_over] = _last_row_first


## A centred row of buttons from [text, action, accent] entries.
func _button_row(entries: Array) -> CenterContainer:
	var center := CenterContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	for entry: Array in entries:
		row.add_child(_button(entry[0], entry[1], 34, entry[2]))
	center.add_child(row)
	_last_row_first = row.get_child(0) as Button
	return center


func show_game_over(title: String, distance: float, score: int, best_distance: float, record: bool) -> void:
	_over_title.text = title
	_over_body.text = "Du åkte %s m\n%s poäng\nRekord: %s m" % [group_digits(int(distance)), group_digits(score), group_digits(int(best_distance))]
	_over_record.visible = record
	show_screen("over", 0.8)


# --- Settings ---

func _build_settings() -> void:
	_settings = _full_rect()
	_dim(_settings, 0.7)
	var column := _centered_column(_settings, 26)
	var title := label("Inställningar", 84, WARM, 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.25)
	track.content_margin_top = 8
	track.content_margin_bottom = 8
	track.set_corner_radius_all(6)
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = COOL
	var focused_fill := track.duplicate() as StyleBoxFlat
	focused_fill.bg_color = WARM
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = WARM
	focus.set_border_width_all(3)
	focus.set_corner_radius_all(10)
	focus.set_expand_margin_all(8)
	var channel := 0
	for name in ["Huvudvolym", "Musik", "Ljudeffekter"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 28)
		var caption := label(name, 36, Color(1, 1, 1), 8)
		caption.custom_minimum_size = Vector2(300, 0)
		row.add_child(caption)
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 5
		slider.custom_minimum_size = Vector2(440, 44)
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.add_theme_stylebox_override("slider", track)
		slider.add_theme_stylebox_override("grabber_area", fill)
		slider.add_theme_stylebox_override("grabber_area_highlight", focused_fill)
		slider.add_theme_stylebox_override("focus", focus)
		row.add_child(slider)
		var amount := label("100 %", 32, COOL, 8)
		amount.custom_minimum_size = Vector2(120, 0)
		row.add_child(amount)
		var index := channel
		slider.value_changed.connect(func(value: float) -> void:
			amount.text = "%d %%" % int(value)
			volume_changed.emit(index, value / 100.0))
		slider.focus_entered.connect(func() -> void: caption.add_theme_color_override("font_color", WARM))
		slider.focus_exited.connect(func() -> void: caption.add_theme_color_override("font_color", Color(1, 1, 1)))
		column.add_child(row)
		_sliders.append(slider)
		channel += 1
	if not Quality.is_mobile():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 28)
		var caption := label("Fullskärm", 36, Color(1, 1, 1), 8)
		caption.custom_minimum_size = Vector2(300, 0)
		row.add_child(caption)
		_fullscreen_toggle = _button("Av", &"fullscreen", 30)
		_fullscreen_toggle.custom_minimum_size = Vector2(140, 0)
		_fullscreen_toggle.focus_entered.connect(func() -> void: caption.add_theme_color_override("font_color", WARM))
		_fullscreen_toggle.focus_exited.connect(func() -> void: caption.add_theme_color_override("font_color", Color(1, 1, 1)))
		row.add_child(_fullscreen_toggle)
		column.add_child(row)
	column.add_child(_button_row([["Klar", &"close_settings", true]]))
	_settings.visible = false


func open_settings(master: float, music: float, effects: float) -> void:
	var values := [master, music, effects]
	for i in _sliders.size():
		_sliders[i].set_value_no_signal(round(values[i] * 100.0))
		var amount := _sliders[i].get_parent().get_child(2) as Label
		amount.text = "%d %%" % int(_sliders[i].value)
	_covered.clear()
	for screen in [_menu, _pause]:
		if screen.visible:
			screen.visible = false
			_covered.append(screen)
	_settings.visible = true
	if not _touch_mode:
		_sliders[0].grab_focus()


func close_settings() -> void:
	_settings.visible = false
	for screen in _covered:
		screen.visible = true
	_covered.clear()
	_focus_current()


## True while one of the on-screen buttons has keyboard/controller focus.
func owns_focus() -> bool:
	return get_viewport().gui_get_focus_owner() != null


func _release_focus() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused:
		focused.release_focus()


## Focuses the default button of the visible screen (not in touch mode).
func _focus_current() -> void:
	if _touch_mode or _settings.visible:
		return
	for screen: Control in _default_focus:
		if screen.visible:
			(_default_focus[screen] as Button).grab_focus()
			return
	_release_focus()


## Shows one of "menu", "game", "pause", "over" (or "" for nothing). Focus
## arrives after `focus_delay` so a held button cannot fire straight away.
func show_screen(screen: String, focus_delay := 0.0) -> void:
	_release_focus()
	if focus_delay > 0.0:
		get_tree().create_timer(focus_delay, true).timeout.connect(_focus_current)
	else:
		_focus_current.call_deferred()
	_menu.visible = screen == "menu"
	_game.visible = screen == "game" or screen == "pause"
	_popups.visible = screen == "game"
	_pause.visible = screen == "pause"
	_over.visible = screen == "over"
	if screen != "game":
		_center.modulate.a = 0.0
