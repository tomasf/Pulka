class_name Hud
extends CanvasLayer
## All 2D interface: in-game readouts, pop-up callouts, menu, pause and the
## game-over screen. Built in code; no theme resources needed.

const WARM := Color(1.0, 0.85, 0.3)
const HOT := Color(1.0, 0.35, 0.2)
const COOL := Color(0.6, 0.9, 1.0)
const INK := Color(0.08, 0.1, 0.2)
## Seconds a pop-up message stays fully visible before fading.
const POPUP_HOLD := 1.6
## Pop-ups stack in at most this many rows, so they never cover the game.
const POPUP_ROWS := 3
const POPUP_TOP := 170.0
const POPUP_ROW_SPACING := 54.0
const POPUP_ROW_HEIGHT := 52.0
## Share of a pop-up's asked-for font size it is drawn at.
const POPUP_TEXT_SCALE := 0.85


class Mittens extends Control:
	var lives := 3
	var max_lives := 3

	## Drawn from the right edge, so extra mittens grow the row leftwards.
	func _draw() -> void:
		for i in max_lives:
			var origin := Vector2(size.x - (max_lives - i) * 46.0, 0.0)
			var color := Color(0.92, 0.18, 0.2) if i < lives else Color(0.4, 0.4, 0.45, 0.5)
			draw_rect(Rect2(origin + Vector2(4, 30), Vector2(30, 10)), Color(1, 1, 1) if i < lives else color)
			draw_circle(origin + Vector2(19, 14), 15.0, color)
			draw_rect(Rect2(origin + Vector2(4, 14), Vector2(30, 18)), color)
			# The same white stripes as the mittens you pick up on the slope.
			var stripe := Color(1, 1, 1) if i < lives else color.lightened(0.3)
			draw_rect(Rect2(origin + Vector2(4, 16), Vector2(30, 3)), stripe)
			draw_rect(Rect2(origin + Vector2(4, 23), Vector2(30, 3)), stripe)
			draw_circle(origin + Vector2(36, 20), 6.0, color)


## One pop-up line and what is animating it.
class PopupNote extends RefCounted:
	var label: Label
	var life: Tween
	var slide: Tween


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
var _center: CountdownDisplay
var _popups: Control
## The pop-ups on screen, oldest (top row) first.
var _notes: Array[PopupNote] = []

var _menu: MenuFlow

var _pause: Control
var _over: Control
var _over_title: Label
var _over_cause: Label
var _over_body: Label
var _over_record: Label
var _time := 0.0

var _settings: Control
var _sliders: Array[HSlider] = []
var _covered: Array[Control] = []
var _reset_button: Button
var _reset_confirm: Control
var _reset_note: Label
var _settings_done: Button
var _reset_cancel: Button
var _reset_yes: Button
var reset_pending: bool:
	get: return _reset_confirm.visible
## Full-screen backgrounds that must bleed past the safe area.
var _backdrops: Array[Control] = []
## Over the split-screen menu: the players choice and how to go back.
var _lobby_bar: Control
## In a split-screen race each player has their own HUD; this one only
## shows menus, pause and results.
var racing := false
var _touch_mode := false
var _last_row_first: Button
## The button each screen focuses first, for keyboard and controller play.
var _default_focus: Dictionary = {}

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
var _fps_toggle: Button
var _fps_meter: FpsMeter

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
	_build_lobby_bar()
	_build_settings()
	if OS.has_feature("web"):
		_build_fullscreen_button()
	_fps_meter = FpsMeter.new()
	add_child(_fps_meter)
	show_screen("")
	get_viewport().size_changed.connect(_fit_safe_area)
	_fit_safe_area()


func _process(delta: float) -> void:
	_time += delta
	var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	if is_instance_valid(_fullscreen_toggle):
		_update_toggle(_fullscreen_toggle, fullscreen)
	_update_toggle(_fps_toggle, _fps_meter.visible)
	if is_instance_valid(_fullscreen_button):
		_fullscreen_button.text = "Fönsterläge" if fullscreen else "Fullskärm"
		_fullscreen_button.tooltip_text = "Lämna fullskärm (Esc / F)" if fullscreen else "Visa i fullskärm (F)"
	if _over.visible:
		_over_record.scale = Vector2.ONE * (1.0 + 0.06 * sin(_time * 6.0))


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
	button.add_theme_stylebox_override("focus", MenuFlow.focus_ring(button.get_theme_stylebox("normal") as StyleBoxFlat, WARM if not accent else Color.WHITE, 6.0, 5))
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
	_menu.set_touch_mode(touch)
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

	_center = CountdownDisplay.new()
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
	tween.tween_property(blot, "modulate:a", 0.0, 1.2)
	tween.parallel().tween_property(blot, "position:y", blot.position.y + 80.0, 1.2)
	tween.tween_callback(blot.queue_free)


func show_center(text: String, color := Color.WHITE) -> void:
	_center.show_count(text, color)


## Shows a callout under the ones already up, the oldest at the top. A full
## stack pushes its oldest out, and the rest move up as each one leaves.
func popup(text: String, color := WARM, size := 44, hold := POPUP_HOLD) -> void:
	if _notes.size() >= POPUP_ROWS:
		_retire_note(_notes[0])
	var note := PopupNote.new()
	note.label = label(text, roundi(size * POPUP_TEXT_SCALE), color, 10)
	note.label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	note.label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var y := _note_y(_notes.size())
	note.label.offset_top = y
	note.label.offset_bottom = y + POPUP_ROW_HEIGHT
	_popups.add_child(note.label)
	_notes.append(note)
	note.label.pivot_offset = Vector2(get_viewport().get_visible_rect().size.x * 0.5, POPUP_ROW_HEIGHT * 0.5)
	note.label.scale = Vector2.ONE * 1.5
	note.life = note.label.create_tween()
	note.life.tween_property(note.label, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	note.life.tween_interval(hold)
	note.life.tween_callback(_retire_note.bind(note))


## Takes a note out of the stack: it fades away upwards as the rest close up.
func _retire_note(note: PopupNote) -> void:
	_notes.erase(note)
	note.life.kill()
	note.label.scale = Vector2.ONE
	_slide_note(note, note.label.offset_top - POPUP_ROW_HEIGHT, 0.4)
	note.life = note.label.create_tween()
	note.life.tween_property(note.label, "modulate:a", 0.0, 0.4)
	note.life.tween_callback(note.label.queue_free)
	for i in _notes.size():
		_slide_note(_notes[i], _note_y(i), 0.2)


func _slide_note(note: PopupNote, y: float, seconds: float) -> void:
	if note.slide != null:
		note.slide.kill()
	note.slide = note.label.create_tween()
	note.slide.tween_property(note.label, "offset_top", y, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	note.slide.parallel().tween_property(note.label, "offset_bottom", y + POPUP_ROW_HEIGHT, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _note_y(row: int) -> float:
	return POPUP_TOP + row * POPUP_ROW_SPACING


# --- Menu ---

func _build_menu() -> void:
	_menu = MenuFlow.new()
	add_child(_menu)
	_menu.pressed.connect(func(action: StringName) -> void: pressed.emit(action))


func _build_lobby_bar() -> void:
	_lobby_bar = _full_rect()
	var back := _button("‹  Spelare", &"players", 24)
	MenuFlow.skin(back)
	back.position = Vector2(30, 24)
	_lobby_bar.add_child(back)
	var title := MenuFlow.caption("PULKA!", 40, Color.WHITE, true)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_left = -100
	title.offset_right = 100
	title.offset_top = 24
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lobby_bar.add_child(title)
	var settings := _button("⚙", &"settings", 26)
	MenuFlow.skin(settings)
	settings.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	settings.offset_left = -110
	settings.offset_right = -30
	settings.offset_top = 24
	settings.offset_bottom = 80
	settings.tooltip_text = "Inställningar"
	settings.accessibility_name = "Inställningar"
	MenuFlow.gear_icon(settings)
	_lobby_bar.add_child(settings)
	# Each rider's A/Space readies their own side; this bar has no default
	# focus so a shared ui_accept cannot also activate Back.
	back.focus_mode = Control.FOCUS_NONE
	settings.focus_mode = Control.FOCUS_NONE


func update_menu(spec: VehicleSpec, unlocked: bool, best_distance: float, best_score: int, unlocked_distance := -1.0) -> void:
	_menu.update_vehicle(spec, unlocked, best_distance, best_score, unlocked_distance)


# --- Pause and game over ---

## Dialogs share the menu's fitted canvas, fonts, card surfaces and lime
## focus/primary actions, including when the game tree itself is paused.
func _dialog_canvas(parent: Control) -> Control:
	var canvas := Control.new()
	canvas.size = MenuFlow.DESIGN
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(canvas)
	var fit := func() -> void:
		var factor := minf(parent.size.x / MenuFlow.DESIGN.x, parent.size.y / MenuFlow.DESIGN.y)
		canvas.scale = Vector2.ONE * factor
		canvas.position = (parent.size - MenuFlow.DESIGN * factor) * 0.5
	parent.resized.connect(fit)
	fit.call_deferred()
	return canvas


func _dialog_panel(canvas: Control, rect: Rect2) -> void:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	var box := MenuFlow.style(Color(0.055, 0.07, 0.15, 0.98), Color(1, 1, 1, 0.15), 28)
	box.shadow_color = Color(0, 0, 0, 0.28)
	box.shadow_size = 28
	box.shadow_offset = Vector2(0, 14)
	panel.add_theme_stylebox_override("panel", box)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(panel)


func _dialog_label(canvas: Control, text: String, points: int, at: Vector2, color := MenuFlow.WHITE, display := false) -> Label:
	var title := MenuFlow.caption(text, points, color, display)
	title.position = at
	canvas.add_child(title)
	return title


func _dialog_button(canvas: Control, text: String, action: StringName, rect: Rect2, accent := false) -> Button:
	var button := Button.new()
	button.text = text
	button.accessibility_name = text
	button.position = rect.position
	button.size = rect.size
	MenuFlow.skin(button, accent)
	button.pressed.connect(func() -> void: pressed.emit(action))
	canvas.add_child(button)
	return button


func _animate_dialog(screen: Control) -> void:
	if screen.has_meta(&"fade"):
		(screen.get_meta(&"fade") as Tween).kill()
	screen.modulate.a = 0.0
	var fade := create_tween()
	fade.tween_property(screen, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_SINE)
	screen.set_meta(&"fade", fade)


func _build_pause() -> void:
	_pause = _full_rect()
	_dim(_pause, 0.64)
	var canvas := _dialog_canvas(_pause)
	_dialog_panel(canvas, Rect2(450, 166, 700, 542))
	_dialog_label(canvas, "PULKA!", 20, Vector2(490, 197), MenuFlow.LIME, true)
	_dialog_label(canvas, "Paus", 76, Vector2(486, 233), MenuFlow.WHITE, true)
	var resume := _dialog_button(canvas, "Fortsätt", &"resume", Rect2(490, 358, 620, 84), true)
	var retry := _dialog_button(canvas, "Börja om", &"retry", Rect2(490, 460, 300, 72))
	var settings := _dialog_button(canvas, "Inställningar", &"settings", Rect2(810, 460, 300, 72))
	var menu := _dialog_button(canvas, "Till menyn", &"menu", Rect2(490, 550, 620, 64))
	var arrow := MenuFlow.caption("→", 30, MenuFlow.NIGHT)
	arrow.position = Vector2(564, 18)
	resume.add_child(arrow)
	# Keep the ordered actions reachable both vertically and horizontally.
	var buttons: Array[Button] = [resume, retry, settings, menu]
	for i in buttons.size():
		var previous := buttons[posmod(i - 1, buttons.size())].get_path()
		var next := buttons[(i + 1) % buttons.size()].get_path()
		buttons[i].focus_neighbor_top = previous
		buttons[i].focus_neighbor_left = previous
		buttons[i].focus_neighbor_bottom = next
		buttons[i].focus_neighbor_right = next
	_default_focus[_pause] = resume


func _build_game_over() -> void:
	_over = _full_rect()
	_dim(_over, 0.45)
	var column := _centered_column(_over, 18)
	_over_cause = label("", 40, HOT, 12)
	_over_cause.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_over_cause)
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


## Results of a two-player race: who won, and each rider's time.
func show_race_result(title: String, body: String) -> void:
	_over_cause.visible = false
	_over_title.text = title
	_over_body.text = body
	_over_record.visible = false
	show_screen("over", 0.8)


## `cause` is the line from the final crash, shown above the title.
func show_game_over(title: String, cause: String, distance: float, score: int, best_distance: float, record: bool) -> void:
	_over_cause.text = cause
	_over_cause.visible = cause != ""
	_over_title.text = title
	_over_body.text = "Du åkte %s m\n%s poäng\nRekord: %s m" % [group_digits(int(distance)), group_digits(score), group_digits(int(best_distance))]
	_over_record.visible = record
	show_screen("over", 0.8)


# --- Settings ---

func _build_settings() -> void:
	_settings = _full_rect()
	_dim(_settings, 0.7)
	var canvas := _dialog_canvas(_settings)
	_dialog_panel(canvas, Rect2(310, 100, 980, 700))
	_dialog_label(canvas, "PULKA!", 20, Vector2(350, 130), MenuFlow.LIME, true)
	_dialog_label(canvas, "Inställningar", 60, Vector2(346, 164), MenuFlow.WHITE, true)
	var track := MenuFlow.style(Color("3d465e"), Color.TRANSPARENT, 5)
	track.set_border_width_all(0)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = MenuFlow.LIME
	var focused_fill := track.duplicate() as StyleBoxFlat
	focused_fill.bg_color = MenuFlow.ICE
	var focus := MenuFlow.style(Color.TRANSPARENT, MenuFlow.LIME, 12)
	focus.draw_center = false
	focus.set_border_width_all(2)
	focus.set_expand_margin_all(5)
	var thumb := _slider_thumb(MenuFlow.WHITE)
	var highlighted_thumb := _slider_thumb(MenuFlow.LIME)
	for channel in 3:
		var panel := PanelContainer.new()
		panel.position = Vector2(350, 272 + channel * 80)
		panel.size = Vector2(900, 72)
		panel.add_theme_stylebox_override("panel", MenuFlow.style(MenuFlow.PANEL, Color(1, 1, 1, 0.06), 16))
		canvas.add_child(panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 24)
		panel.add_child(row)
		var caption := MenuFlow.caption(["Huvudvolym", "Musik", "Ljudeffekter"][channel], 24)
		caption.custom_minimum_size = Vector2(240, 0)
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(caption)
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 5
		slider.accessibility_name = caption.text
		slider.custom_minimum_size = Vector2(440, 44)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		slider.add_theme_stylebox_override("slider", track)
		slider.add_theme_stylebox_override("grabber_area", fill)
		slider.add_theme_stylebox_override("grabber_area_highlight", focused_fill)
		slider.add_theme_stylebox_override("focus", focus)
		slider.add_theme_icon_override("grabber", thumb)
		slider.add_theme_icon_override("grabber_highlight", highlighted_thumb)
		row.add_child(slider)
		var amount := MenuFlow.caption("100 %", 24, MenuFlow.ICE)
		amount.custom_minimum_size = Vector2(100, 0)
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(amount)
		var index := channel
		slider.value_changed.connect(func(value: float) -> void:
			amount.text = "%d %%" % int(value)
			volume_changed.emit(index, value / 100.0))
		slider.focus_entered.connect(func() -> void: caption.add_theme_color_override("font_color", MenuFlow.LIME))
		slider.focus_exited.connect(func() -> void: caption.add_theme_color_override("font_color", MenuFlow.WHITE))
		_sliders.append(slider)
	var desktop := not Quality.is_mobile() and not Quality.is_tv()
	if desktop:
		_fullscreen_toggle = _settings_toggle(canvas, "Fullskärm", &"fullscreen", Rect2(350, 536, 438, 64))
	_fps_toggle = _settings_toggle(canvas, "Visa FPS", &"show_fps", Rect2(812 if desktop else 350, 536, 438 if desktop else 900, 64))
	var done := _dialog_button(canvas, "Klar", &"close_settings", Rect2(990, 680, 260, 76), true)
	_settings_done = done
	_reset_button = _dialog_button(canvas, "Nollställ high score", &"ask_reset_records", Rect2(350, 680, 450, 76))
	_reset_button.add_theme_color_override("font_color", MenuFlow.CORAL)
	_reset_note = _dialog_label(canvas, "", 22, Vector2(350, 630), MenuFlow.MUTED)
	_reset_confirm = Control.new()
	canvas.add_child(_reset_confirm)
	_reset_cancel = _dialog_button(_reset_confirm, "Avbryt", &"cancel_reset_records", Rect2(350, 680, 240, 76))
	_reset_yes = _dialog_button(_reset_confirm, "Ja, nollställ", &"reset_records", Rect2(610, 680, 340, 76))
	_reset_yes.add_theme_color_override("font_color", MenuFlow.CORAL)
	_reset_cancel.focus_neighbor_right = _reset_yes.get_path()
	_reset_yes.focus_neighbor_left = _reset_cancel.get_path()
	_reset_yes.focus_neighbor_right = done.get_path()
	for button in [_reset_button, _reset_cancel, _reset_yes]:
		button.focus_neighbor_top = (_fullscreen_toggle if desktop else _fps_toggle).get_path()
		button.focus_neighbor_bottom = _sliders[0].get_path()
	_reset_button.focus_neighbor_right = done.get_path()
	_reset_confirm.hide()
	for i in _sliders.size():
		_sliders[i].focus_neighbor_top = (_sliders[i - 1] if i > 0 else done).get_path()
		_sliders[i].focus_neighbor_bottom = (_sliders[i + 1] if i < _sliders.size() - 1 else (_fullscreen_toggle if desktop else _fps_toggle)).get_path()
	_fps_toggle.focus_neighbor_top = _sliders.back().get_path()
	_fps_toggle.focus_neighbor_bottom = done.get_path()
	if desktop:
		_fullscreen_toggle.focus_neighbor_top = _sliders.back().get_path()
		_fullscreen_toggle.focus_neighbor_right = _fps_toggle.get_path()
		_fullscreen_toggle.focus_neighbor_bottom = _reset_button.get_path()
		_fps_toggle.focus_neighbor_left = _fullscreen_toggle.get_path()
	done.focus_neighbor_top = _fps_toggle.get_path()
	done.focus_neighbor_bottom = _sliders[0].get_path()
	done.focus_neighbor_left = _reset_button.get_path()
	_settings.visible = false


func _slider_thumb(color: Color) -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.84, 1.0])
	gradient.colors = PackedColorArray([color, color, Color(color, 0.0)])
	var texture := GradientTexture2D.new()
	texture.width = 28
	texture.height = 28
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.gradient = gradient
	return texture


func _settings_toggle(canvas: Control, text: String, action: StringName, rect: Rect2) -> Button:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel", MenuFlow.style(MenuFlow.PANEL, Color(1, 1, 1, 0.06), 16))
	canvas.add_child(panel)
	_dialog_label(panel, text, 22, Vector2(22, 16))
	var toggle := _dialog_button(panel, "Av", action, Rect2(rect.size.x - 112, 10, 92, 44))
	toggle.add_theme_font_size_override("font_size", 22)
	toggle.accessibility_name = text
	return toggle


func _update_toggle(button: Button, on: bool) -> void:
	if button.has_meta(&"on") and bool(button.get_meta(&"on")) == on: return
	button.set_meta(&"on", on)
	button.text = "På" if on else "Av"
	var color := MenuFlow.NIGHT if on else MenuFlow.WHITE
	for state in ["normal", "hover", "pressed"]:
		var fill := MenuFlow.LIME if on else Color("343950")
		var box := MenuFlow.style(fill.lightened(0.08) if state == "hover" else fill, Color.TRANSPARENT, 12)
		box.content_margin_top = 4
		box.content_margin_bottom = 4
		button.add_theme_stylebox_override(state, box)
	button.add_theme_stylebox_override("focus", MenuFlow.focus_ring(button.get_theme_stylebox("normal") as StyleBoxFlat))
	for key in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(key, color)


func set_fps_visible(on: bool) -> void:
	_fps_meter.visible = on


func open_settings(master: float, music: float, effects: float) -> void:
	cancel_record_reset()
	_reset_note.text = ""
	var values := [master, music, effects]
	for i in _sliders.size():
		_sliders[i].set_value_no_signal(round(values[i] * 100.0))
		var amount := _sliders[i].get_parent().get_child(2) as Label
		amount.text = "%d %%" % int(_sliders[i].value)
	_covered.clear()
	for screen in [_menu, _pause, _lobby_bar]:
		if screen.visible:
			screen.visible = false
			_covered.append(screen)
	_settings.visible = true
	_animate_dialog(_settings)
	if not _touch_mode:
		_sliders[0].grab_focus()


func close_settings() -> void:
	cancel_record_reset()
	_settings.visible = false
	for screen in _covered:
		screen.visible = true
		if screen == _pause: _animate_dialog(_pause)
	_covered.clear()
	_focus_current()


func ask_record_reset() -> void:
	_reset_button.hide()
	_reset_confirm.show()
	_reset_note.text = "Nollställa poäng och distans? Åkdonen behålls."
	_settings_done.focus_neighbor_left = _reset_yes.get_path()
	if _fullscreen_toggle: _fullscreen_toggle.focus_neighbor_bottom = _reset_cancel.get_path()
	if not _touch_mode: _reset_cancel.grab_focus()


func cancel_record_reset() -> void:
	_reset_confirm.hide()
	_reset_button.show()
	_reset_note.text = ""
	_settings_done.focus_neighbor_left = _reset_button.get_path()
	if _fullscreen_toggle: _fullscreen_toggle.focus_neighbor_bottom = _reset_button.get_path()
	if _settings.visible and not _touch_mode: _reset_button.grab_focus()


func records_cleared() -> void:
	cancel_record_reset()
	_reset_note.text = "High score nollställd."
	if not _touch_mode: _settings_done.grab_focus()


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
	if _menu.visible:
		_menu.default_focus().grab_focus()
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
	if screen == "countdown" and _menu.visible:
		_menu.dismiss()
	else:
		_menu.visible = screen == "menu" or screen == "players"
		if screen == "menu": _menu.show_picker()
		elif screen == "players": _menu.show_players()
	_game.visible = (screen == "game" or screen == "pause") and not racing
	_lobby_bar.visible = screen == "lobby"
	_popups.visible = screen == "game"
	_pause.visible = screen == "pause"
	if screen == "pause": _animate_dialog(_pause)
	_over.visible = screen == "over"
	if screen not in ["game", "race", "countdown"]:
		_center.clear()
