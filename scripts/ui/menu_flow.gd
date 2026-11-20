class_name MenuFlow
extends Control
## Two deliberately small choices: who is riding, then what they ride.
## UI uses a fitted design canvas; previews are actual game models, rendered
## once into small viewports rather than animated extra worlds during play.

const NIGHT := Color("101329")
const PANEL := Color("232442")
const LIME := Color("c9f36b")
const ICE := Color("a9dcf5")
const CORAL := Color("ff907d")
const MUTED := Color("a2accb")
const WHITE := Color("f6f8ff")
const DESIGN := Vector2(1600, 900)
const PICKER_SHADE := Color(0.04, 0.07, 0.15, 0.88)
const PAGE_SECONDS := 0.72

signal pressed(action: StringName)

const DISPLAY_FONT := preload("res://fonts/FugazOne-Regular.ttf")
const BODY_FONT := preload("res://fonts/Nunito.ttf")
static var _bold: FontVariation
static var _vehicle_textures := {}
var canvas: Control
var players: Control
var picker: Control
## The shared header; each player's actual picker lives in RaceHud.
var lobby: Control
var solo: Button
var _duo_subtitle: Label
var _duo_arrow: Label
var _duo_preview: Control
var duo: Button
var start: Button
var settings: Button
var quit_button: Button
var about_button: Button
var back: Button
var cards: Array[Button] = []
var _name: Label
var _tagline: Label
var _locked: Label
var _stats: Array[Control] = []
var _record: Label
var _picker_hint: InputHint
var _start_hint: InputHint
var _controls_hint: InputHint
var _touch_mode := false
var _gamepad_mode := false
var _background: WinterBackdrop
## The full-screen winter backdrop, which the HUD stretches past safe-area
## insets so the world never shows round the menu.
var backdrop: Control:
	get:
		return _background
var _picker_shade: TextureRect
var _picker_fill: ColorRect
var _transition: Tween
var _current_page: Control
var _dismissed := false
var _brand: Label
var _picker_details: Control
var _picker_dock: Control
var _thumb_views: Array[SubViewport] = []


## Keyboard keys have a raised edge; controller buttons are round.
## Plain strings are action names, arrays are [kind, key], and null adds space.
class InputHint extends HBoxContainer:
	var _parts: Array = []
	var _points := 17

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_theme_constant_override("separation", 6)

	func set_parts(parts: Array, points := 17) -> void:
		_parts = parts
		_points = points
		for child in get_children():
			remove_child(child)
			child.queue_free()
		var spoken: Array[String] = []
		for part in parts:
			if part == null:
				var gap := Control.new()
				gap.custom_minimum_size.x = points * 0.65
				gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
				add_child(gap)
			elif part is String:
				var word := MenuFlow.caption(part, points)
				word.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				add_child(word)
				spoken.append(TranslationServer.translate(part))
			else:
				var kind: String = part[0]
				var key: String = part[1]
				var height := roundf(points * 1.65)
				if kind == "pad":
					var button := PadIcon.new()
					button.letter = key
					button.points = points
					button.custom_minimum_size = Vector2(height, height)
					button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
					add_child(button)
					spoken.append(key)
					continue
				if kind == "stick":
					var stick := StickIcon.new()
					stick.custom_minimum_size = Vector2(height, height)
					stick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
					add_child(stick)
					spoken.append(TranslationServer.translate("spak"))
					continue
				var cap := PanelContainer.new()
				cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
				cap.custom_minimum_size = Vector2(height, height)
				var surface := StyleBoxFlat.new()
				surface.bg_color = Color(1, 1, 1, 0.09)
				surface.border_color = Color(1, 1, 1, 0.5)
				surface.set_border_width_all(1)
				surface.border_width_bottom = 2
				surface.set_corner_radius_all(5)
				surface.content_margin_left = 7 if key.length() > 1 else 3
				surface.content_margin_right = surface.content_margin_left
				cap.add_theme_stylebox_override("panel", surface)
				var glyph := MenuFlow.caption("↵" if key == "Enter" else key, points)
				glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				cap.add_child(glyph)
				spoken.append(key)
				add_child(cap)
		accessibility_name = " ".join(spoken)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_TRANSLATION_CHANGED and not _parts.is_empty():
			set_parts.call_deferred(_parts, _points)

	func set_player(controls: PlayerControls) -> void:
		var parts: Array = []
		if controls.gamepad_hints:
			parts.append(["stick", ""])
		else:
			var letters := controls.keys in [PlayerControls.Keys.LEFT, PlayerControls.Keys.KEYBOARD]
			parts.append_array([["key", "A" if letters else "←"], ["key", "D" if letters else "→"]])
		parts.append_array(["Styr", null])
		if controls.gamepad_hints:
			parts.append(["pad", "A"])
		else:
			parts.append(["key", "Enter" if controls.keys == PlayerControls.Keys.RIGHT else "Space"])
		parts.append("Hoppa")
		set_parts(parts, 15)


## An analog stick seen from above, standing on its own (no keycap) and
## scaled to its box: the well as a ring, the thumb cap nudged forward.
class StickIcon extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.5
		# Same well as PadIcon's button, so the two hints weigh the same.
		draw_circle(center, radius - 0.5, Color(1, 1, 1, 0.09), true, -1.0, true)
		draw_arc(center, radius - 0.75, 0, TAU, 64, Color(1, 1, 1, 0.5), 1.5, true)
		draw_circle(center + Vector2(0, -radius * 0.32), radius * 0.38, WHITE, true, -1.0, true)


## A round controller button, drawn rather than a StyleBoxFlat: a stadium box
## leaves bright seams where its corner arcs meet, and a keycap's thicker bottom
## edge pushes the letter off centre. The letter is centred on its cap height.
class PadIcon extends Control:
	## Nunito's cap height, in em.
	const CAP_HEIGHT := 0.705
	var letter := ""
	var points := 17
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.5
		draw_circle(center, radius - 0.5, Color(1, 1, 1, 0.09), true, -1.0, true)
		draw_arc(center, radius - 0.75, 0, TAU, 64, Color(1, 1, 1, 0.5), 1.5, true)
		var font := MenuFlow.font()
		var width := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, points).x
		var baseline := Vector2(center.x - width * 0.5, center.y + points * CAP_HEIGHT * 0.5)
		draw_string(font, baseline, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, points, WHITE)


class WinterBackdrop extends Control:
	var clock := 0.0
	var rush := 0.0
	var sky: GradientTexture2D
	func _ready() -> void:
		var gradient := Gradient.new()
		gradient.colors = PackedColorArray([NIGHT, NIGHT.lerp(Color("29334e"), 0.85)])
		sky = GradientTexture2D.new()
		sky.width = 8
		sky.height = 256
		sky.fill_from = Vector2.ZERO
		sky.fill_to = Vector2.DOWN
		sky.gradient = gradient
	func _process(delta: float) -> void:
		if not is_visible_in_tree(): return
		clock += delta * (1.0 + rush * 5.0)
		queue_redraw()
	func _draw() -> void:
		var s := size
		# One continuous gradient avoids dark seams while fading and zooming.
		draw_texture_rect(sky, Rect2(Vector2.ZERO, s), false)
		for layer in 3:
			var ridge := PackedVector2Array([Vector2(0, s.y)])
			for i in 18:
				var x := i / 17.0 * s.x
				var y := s.y * (0.59 + layer * 0.11) + sin(i * 1.71 + layer * 2.0) * s.y * 0.075
				ridge.append(Vector2(x, y))
			ridge.append(s)
			draw_colored_polygon(ridge, [Color("34405b"), Color("26334e"), Color("1c2942")][layer])
		for i in 70:
			var x := fposmod(i * 347.7 + clock * (3.0 + i % 3), s.x)
			var y := fposmod(i * 179.3 + clock * (8.0 + i % 5), s.y)
			draw_circle(Vector2(x, y), 1.0 + i % 3 * 0.5, Color(0.85, 0.94, 1, 0.12 + i % 4 * 0.04))
			if rush > 0.01:
				draw_line(Vector2(x, y), Vector2(x + rush * 8, y - rush * (12 + i % 4 * 5)), Color(0.85, 0.94, 1, rush * 0.16), 1.0, true)
		# Two tracks curling down the far side of the hill.
		for side in [-1.0, 1.0]:
			var trail := PackedVector2Array()
			for i in 50:
				var t := i / 49.0
				trail.append(Vector2(s.x * (0.46 + t * 0.22 + sin(t * 7.0) * 0.06) + side * (3 + t * 10), s.y * (0.56 + t * 0.5)))
			draw_polyline(trail, Color(0.75, 0.86, 1, 0.12), 2, true)


class Stat extends Control:
	var value := 0.5
	var tint := ICE
	func _draw() -> void:
		for i in 10:
			var box := StyleBoxFlat.new()
			box.bg_color = tint if i < roundi(value * 10) else Color(1, 1, 1, 0.1)
			box.set_corner_radius_all(3)
			draw_style_box(box, Rect2(i * 17, 0, 12, 12))


class Gear extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var center := size * 0.5
		for i in 8:
			var direction := Vector2.from_angle(i * TAU / 8)
			draw_line(center + direction * 8, center + direction * 12, WHITE, 3, true)
		draw_arc(center, 8, 0, TAU, 32, WHITE, 3, true)
		draw_circle(center, 3, WHITE)


class Info extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var center := size * 0.5
		draw_arc(center, 12, 0, TAU, 48, WHITE, 2.5, true)
		draw_circle(center + Vector2(0, -6), 1.8, WHITE)
		draw_line(center + Vector2(0, -1), center + Vector2(0, 7), WHITE, 3, true)
		draw_line(center + Vector2(-3, 7), center + Vector2(3, 7), WHITE, 2.5, true)


static func font(display := false) -> Font:
	if display:
		return DISPLAY_FONT
	if _bold == null:
		_bold = FontVariation.new()
		_bold.base_font = BODY_FONT
		var weight := TextServerManager.get_primary_interface().name_to_tag("wght")
		_bold.variation_opentype = {weight: 700}
	return _bold


static func caption(text: String, points: int, tint := WHITE, display := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font(display))
	label.add_theme_font_size_override("font_size", points)
	label.add_theme_color_override("font_color", tint)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## A translucent border would show the backdrop instead of the surface, and
## where its anti-aliased inner edge overlaps the fill's it leaves a bright
## seam. So the border is the fill with the tint mixed in, as opaque as the fill.
static func style(fill: Color, border := Color.TRANSPARENT, radius := 20) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	if border.a > 0.0:
		var edge := Color(fill, 1.0).blend(border)
		box.border_color = Color(edge, fill.a)
		box.set_border_width_all(2)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 22
	box.content_margin_right = 22
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box


## Expanded outlines need a larger outer radius to keep their corner centres
## aligned with the button, including surfaces with individually rounded corners.
static func focus_ring(surface: StyleBoxFlat, tint := LIME, margin := 5.0, width := 3) -> StyleBoxFlat:
	var ring := surface.duplicate() as StyleBoxFlat
	ring.draw_center = false
	ring.border_color = tint
	ring.set_border_width_all(width)
	ring.set_expand_margin_all(margin)
	for corner in 4:
		ring.set_corner_radius(corner, surface.get_corner_radius(corner) + roundi(margin))
	return ring


static func skin(button: Button, accent := false) -> void:
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", font())
	button.add_theme_font_size_override("font_size", 26)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var fill := LIME if accent else PANEL
		if state == "hover": fill = fill.lightened(0.1)
		if state == "pressed": fill = fill.darkened(0.15)
		if state == "disabled": fill = Color("42465b")
		button.add_theme_stylebox_override(state, style(fill, Color(1, 1, 1, 0.10)))
		button.add_theme_color_override("font_" + (state + "_" if state != "normal" else "") + "color", NIGHT if accent else WHITE)
	button.add_theme_color_override("font_focus_color", NIGHT if accent else WHITE)
	button.add_theme_color_override("font_hover_pressed_color", NIGHT if accent else WHITE)
	button.add_theme_stylebox_override("focus", focus_ring(button.get_theme_stylebox("normal") as StyleBoxFlat))
	button.mouse_entered.connect(func() -> void: _hover(button, true))
	button.mouse_exited.connect(func() -> void: _hover(button, false))


static func _hover(button: Button, over: bool) -> void:
	if button.disabled: return
	if button.has_meta(&"hover_tween"):
		(button.get_meta(&"hover_tween") as Tween).kill()
	button.pivot_offset = button.size * 0.5
	var tween := button.create_tween()
	tween.tween_property(button, "scale", Vector2.ONE * (1.025 if over else 1.0), 0.16).set_trans(Tween.TRANS_SINE)
	button.set_meta(&"hover_tween", tween)


static func gear_icon(button: Button) -> void:
	button.text = ""
	var icon := Gear.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.add_child(icon)


static func info_icon(button: Button) -> void:
	button.text = ""
	var icon := Info.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.add_child(icon)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background = WinterBackdrop.new()
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.resized.connect(func() -> void: _background.pivot_offset = _background.size * 0.5)
	add_child(_background)
	canvas = Control.new()
	canvas.size = DESIGN
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	players = _page()
	picker = _page()
	lobby = _page()
	_build_players()
	_build_picker()
	_brand = _text(canvas, "PULKA!", 44, Vector2(80, 42), WHITE, true)
	_brand.add_theme_color_override("font_shadow_color", Color(NIGHT, 0.28))
	_brand.add_theme_constant_override("shadow_offset_x", 0)
	_brand.add_theme_constant_override("shadow_offset_y", 3)
	settings = _button("⚙", &"settings", Vector2(1444, 42), Vector2(76, 64))
	settings.tooltip_text = "Inställningar"
	settings.accessibility_name = "Inställningar"
	gear_icon(settings)
	canvas.add_child(settings)
	about_button = _button("Om spelet", &"about", Vector2(1344, 42), Vector2(76, 64))
	about_button.tooltip_text = "Om spelet"
	info_icon(about_button)
	players.add_child(about_button)
	solo.focus_neighbor_top = about_button.get_path()
	duo.focus_neighbor_top = about_button.get_path()
	about_button.focus_neighbor_bottom = solo.get_path()
	about_button.focus_neighbor_right = settings.get_path()
	settings.focus_neighbor_left = about_button.get_path()
	if Quality.is_desktop():
		quit_button = _button("Avsluta", &"quit", Vector2(1108, 42), Vector2(210, 64))
		players.add_child(quit_button)
		solo.focus_neighbor_top = quit_button.get_path()
		quit_button.focus_neighbor_bottom = duo.get_path()
		quit_button.focus_neighbor_right = about_button.get_path()
		about_button.focus_neighbor_left = quit_button.get_path()
	resized.connect(_fit)
	_fit()


func _page() -> Control:
	var page := Control.new()
	page.size = DESIGN
	page.pivot_offset = DESIGN * 0.5
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(page)
	return page


func _fit() -> void:
	var fit := minf(size.x / DESIGN.x, size.y / DESIGN.y)
	if fit <= 0.0: return
	canvas.scale = Vector2.ONE * fit
	canvas.position = (size - DESIGN * fit) * 0.5
	if is_instance_valid(_picker_shade):
		# Keep the existing fade beside the text; continue its leftmost tint
		# across the extra viewport space outside the fitted design canvas,
		# and past any safe-area inset the HUD gives the menu.
		var before := (canvas.position + Vector2(offset_left, offset_top)) / fit
		var below := (canvas.position.y - offset_bottom) / fit
		var height := DESIGN.y + before.y + below
		_picker_fill.position = -before
		_picker_fill.size = Vector2(before.x, height)
		_picker_shade.position.y = -before.y
		_picker_shade.size.y = height


func _text(parent: Control, text: String, points: int, at: Vector2, tint := WHITE, display := false) -> Label:
	var label := caption(text, points, tint, display)
	label.position = at
	parent.add_child(label)
	return label


func _input_hint(parent: Control, at: Vector2) -> InputHint:
	var hint := InputHint.new()
	hint.position = at
	parent.add_child(hint)
	return hint


func _button(text: String, action: StringName, at: Vector2, dimensions: Vector2, accent := false) -> Button:
	var button := Button.new()
	button.text = text
	button.accessibility_name = text
	button.position = at
	button.size = dimensions
	skin(button, accent)
	button.pressed.connect(func() -> void: pressed.emit(action))
	return button


func _build_players() -> void:
	var headline := _text(players, "UT I\nBACKEN.", 112, Vector2(120, 230), WHITE, true)
	headline.add_theme_constant_override("line_spacing", -30)
	_text(players, "Snö i nacken. Ett åk till.", 26, Vector2(126, 521), ICE)
	solo = _player_card(1, Vector2(756, 234))
	duo = _player_card(2, Vector2(1108, 278))
	_update_duo()
	Input.joy_connection_changed.connect(func(_device: int, _connected: bool) -> void: _update_duo())
	_record = _text(players, "", 19, Vector2(126, 736), MUTED)
	solo.focus_neighbor_right = duo.get_path()
	duo.focus_neighbor_left = solo.get_path()


func _player_card(count: int, at: Vector2) -> Button:
	var button := _button("", &"solo" if count == 1 else &"duo", at, Vector2(310, 390))
	button.tooltip_text = "1 spelare" if count == 1 else "2 spelare"
	button.accessibility_name = button.tooltip_text
	players.add_child(button)
	_text(button, "SOLO" if count == 1 else "DUELL", 14, Vector2(214, 28), MUTED)
	var preview := _preview(VehicleSpec.Model.PULKA if count == 1 else VehicleSpec.Model.SNOWRACER, count, true)
	preview.position = Vector2(-10, 60)
	preview.size = Vector2(330, 226)
	button.add_child(preview)
	if count == 2:
		_duo_preview = preview
		# Unavailable reads as see-through rather than as a different grey.
		button.add_theme_stylebox_override("disabled", style(Color(PANEL, 0.3), Color(1, 1, 1, 0.10)))
	_text(button, "1 spelare" if count == 1 else "2 spelare", 31, Vector2(28, 292), WHITE, true)
	var subtitle := _text(button, "En oändlig backe" if count == 1 else "Först till mål", 18, Vector2(30, 340), MUTED)
	if count == 2:
		_duo_subtitle = subtitle
	# Right-aligned so the arrow keeps the card's 28 px right margin.
	var arrow := _text(button, "→", 30, Vector2(222, 291), LIME)
	arrow.size.x = 60
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if count == 2:
		_duo_arrow = arrow
	return button


## On phones and tablets the duel needs two controllers; say so on the card,
## since a disabled button otherwise just ignores taps.
func _update_duo() -> void:
	var available := PlayerControls.two_can_play()
	duo.disabled = not available
	duo.tooltip_text = "Två spelare på samma skärm" if available else "Anslut två handkontroller"
	_duo_subtitle.text = "Först till mål" if available else "Anslut två handkontroller"
	_duo_arrow.visible = available
	_duo_preview.modulate.a = 1.0 if available else 0.3


func _build_picker() -> void:
	# A soft veil keeps the title readable without covering the 3D rider.
	_picker_fill = ColorRect.new()
	_picker_fill.color = PICKER_SHADE
	_picker_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picker.add_child(_picker_fill)
	var shade := TextureRect.new()
	_picker_shade = shade
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([PICKER_SHADE, Color(PICKER_SHADE, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2.ZERO
	texture.fill_to = Vector2.RIGHT
	shade.texture = texture
	shade.size = Vector2(900, 900)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picker.add_child(shade)
	back = _button("‹  Spelare", &"players", Vector2(80, 42), Vector2(190, 64))
	canvas.add_child(back)
	_picker_details = Control.new()
	_picker_details.size = DESIGN
	_picker_details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picker.add_child(_picker_details)
	_name = _text(_picker_details, "Pulka", 76, Vector2(80, 228), WHITE, true)
	_tagline = _text(_picker_details, "Den röda klassikern.", 25, Vector2(84, 332), ICE)
	for i in 3:
		_text(_picker_details, ["Fart", "Styrning", "Grepp"][i], 18, Vector2(86, 408 + i * 38), WHITE)
		var stat := Stat.new()
		stat.position = Vector2(214, 417 + i * 38)
		stat.size = Vector2(170, 12)
		stat.tint = [CORAL, ICE, LIME][i]
		_picker_details.add_child(stat)
		_stats.append(stat)
	_locked = _text(_picker_details, "", 20, Vector2(84, 550), CORAL)
	_controls_hint = _input_hint(_picker_details, Vector2(84, 596))
	_picker_dock = Control.new()
	_picker_dock.size = DESIGN
	_picker_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picker.add_child(_picker_dock)
	var dock := Panel.new()
	dock.position = Vector2(60, 666)
	dock.size = Vector2(1480, 170)
	dock.add_theme_stylebox_override("panel", style(Color(0.055, 0.07, 0.15, 0.95), Color(1, 1, 1, 0.15), 26))
	_picker_dock.add_child(dock)
	var specs := VehicleSpec.all()
	for i in specs.size():
		var button := _button("", StringName("vehicle_%d" % i), Vector2(82 + i * 192, 684), Vector2(176, 134))
		button.tooltip_text = specs[i].title
		button.accessibility_name = specs[i].title
		_picker_dock.add_child(button)
		var preview := _preview(specs[i].model, 1, false)
		preview.position = Vector2(7, 4)
		preview.size = Vector2(162, 88)
		button.add_child(preview)
		var name_label := _text(button, specs[i].title, 18, Vector2(0, 95))
		name_label.size.x = 176
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cards.append(button)
	start = _button("NU ÅKER VI  →", &"start", Vector2(1100, 702), Vector2(412, 98), true)
	start.add_theme_font_size_override("font_size", 28)
	_picker_dock.add_child(start)
	_picker_hint = _input_hint(_picker_dock, Vector2(84, 851))
	_start_hint = _input_hint(_picker_dock, Vector2(1320, 851))
	set_touch_mode(false)
	for i in cards.size():
		# Horizontal navigation picks a ride in Main; keep native focus on
		# the start button so A/Enter cannot accidentally click another card.
		cards[i].focus_mode = Control.FOCUS_NONE
	start.focus_neighbor_left = start.get_path()
	start.focus_neighbor_right = start.get_path()


func _preview(model: VehicleSpec.Model, count: int, rider: bool) -> TextureRect:
	var view := SubViewport.new()
	view.size = Vector2i(500, 340) if rider else Vector2i(300, 170)
	view.own_world_3d = true
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	view.msaa_3d = Viewport.MSAA_2X
	add_child(view)
	_thumb_views.append(view)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0, 0, 0, 0)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("ccdfff")
	environment.environment.ambient_light_energy = 0.8
	view.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.6
	view.add_child(sun)
	for i in count:
		var body := Node3D.new()
		body.position.x = (i - (count - 1) * 0.5) * 1.3
		body.rotation.y = -0.35 if i == 0 else 0.2
		view.add_child(body)
		var mesh := MeshInstance3D.new()
		mesh.mesh = RideModels.vehicle(model)
		body.add_child(mesh)
		if rider:
			var person := RiderRig.new()
			person.set_ride(model)
			person.dress(CORAL if i == 0 else ICE, Color("38548c") if i == 0 else CORAL, 13 if i == 0 else 26)
			person.position.y = VehicleSpec.all()[int(model)].seat_height
			body.add_child(person)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = (1.9 if count == 1 else 2.8) if rider else 1.7
	view.add_child(camera)
	camera.position = Vector3(2.5, 2.2, -4.0) if rider else Vector3(2.5, 2.6, -4.0)
	camera.look_at(Vector3(0, 0.55 if rider else 0.15, 0))
	if not rider:
		# Each silhouette fills its tile, including the very flat seat pad.
		var bounds: AABB = Transform3D(Basis(Vector3.UP, -0.35), Vector3.ZERO) * RideModels.vehicle(model).get_aabb()
		var focus := bounds.get_center()
		camera.position = focus + Vector3(3.8, 2.7, -2.6)
		camera.look_at(focus)
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for corner in 8:
			var local := camera.basis.inverse() * (bounds.get_endpoint(corner) - focus)
			lo = lo.min(Vector2(local.x, local.y))
			hi = hi.max(Vector2(local.x, local.y))
		camera.keep_aspect = Camera3D.KEEP_HEIGHT
		camera.size = maxf(hi.y - lo.y, (hi.x - lo.x) / (float(view.size.x) / view.size.y)) * 1.15
	var texture := TextureRect.new()
	texture.texture = view.get_texture()
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not rider: _vehicle_textures[model] = view.get_texture()
	return texture


static func vehicle_texture(model: VehicleSpec.Model) -> Texture2D:
	return _vehicle_textures.get(model)


## Settings cover the controls while keeping the current menu background.
func set_covered(covered: bool) -> void:
	canvas.visible = not covered


func show_players() -> void:
	_enter(players)


func show_picker() -> void:
	_enter(picker)


func show_lobby() -> void:
	_enter(lobby)


func dismiss() -> void:
	if _transition != null: _transition.kill()
	_dismissed = true
	_background.rush = 0.0
	_transition = create_tween()
	_transition.tween_property(self, "modulate:a", 0.0, 0.28)
	_transition.tween_callback(hide)


func _enter(page: Control) -> void:
	if _transition != null: _transition.kill()
	var changing := _current_page != null and _current_page != page and not _dismissed
	var continuing := changing and page.visible
	_current_page = page
	_dismissed = false
	modulate.a = 1.0
	canvas.show()
	page.show()
	back.focus_mode = Control.FOCUS_NONE if page == lobby else Control.FOCUS_ALL
	settings.focus_mode = back.focus_mode
	if not continuing:
		page.position = Vector2.ZERO
		page.scale = Vector2.ONE
		page.modulate.a = 1.0
	_background.show()
	_transition = create_tween().set_parallel(true)
	var centered_brand := Vector2((DESIGN.x - _brand.get_minimum_size().x) * 0.5, 44)
	_transition.tween_property(_brand, "position", Vector2(80, 42) if page == players else centered_brand, 0.62 if changing else 0.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_transition.tween_method(func(t: float) -> void: _background.rush = sin(t * PI) * (0.8 if page != players else 0.4), 0.0, 1.0, PAGE_SECONDS)
	if page != players:
		back.show()
		_transition.tween_property(page, "modulate:a", 1.0, 0.2)
		if changing:
			_transition.tween_property(players, "position", Vector2(-64, 0), 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			_transition.tween_property(players, "scale", Vector2.ONE * 0.98, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			_transition.tween_property(players, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_SINE)
			_transition.tween_callback(players.hide).set_delay(0.24)
		else:
			players.hide()
		_arrive(back, Vector2(-18, 0), 0.16, 0.36, continuing)
		if page == picker:
			_arrive(_picker_details, Vector2(-36, 0), 0.18, 0.5, continuing)
			_arrive(_picker_dock, Vector2(0, 72), 0.14, 0.52, continuing)
			for i in cards.size():
				_slide_in(cards[i], Vector2(0, 22), 0.2 + i * 0.025, 0.42, continuing)
		else:
			picker.hide()
		_transition.tween_property(_background, "scale", Vector2.ONE * 1.045, 0.62).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		_transition.tween_property(_background, "modulate:a", 0.0, 0.52).set_delay(0.1).set_trans(Tween.TRANS_SINE)
	else:
		_transition.tween_property(back, "modulate:a", 0.0, 0.16)
		_transition.tween_callback(back.hide).set_delay(0.2)
		if changing:
			_transition.tween_property(_picker_details, "position", Vector2(-28, 0), 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			_transition.tween_property(_picker_dock, "position", Vector2(0, 64), 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			_transition.tween_property(picker, "modulate:a", 0.0, 0.18)
			_transition.tween_callback(picker.hide).set_delay(0.2)
		else:
			picker.hide()
			_background.modulate.a = 1.0
		_arrive(players, Vector2(48, 0), 0.14 if changing else 0.0, 0.48, continuing)
		_transition.tween_property(players, "scale", Vector2.ONE, 0.48).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		_transition.tween_property(_background, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_transition.tween_property(_background, "modulate:a", 1.0, 0.36).set_trans(Tween.TRANS_SINE)
	_transition.finished.connect(_settle_page.bind(page))


## Animate parents' opacity so locked cards keep their own dimming.
func _arrive(control: Control, offset: Vector2, delay: float, duration: float, continuing := false) -> void:
	_slide_in(control, offset, delay, duration, continuing)
	if not continuing: control.modulate.a = 0.0
	_transition.tween_property(control, "modulate:a", 1.0, duration * 0.75).set_delay(delay).set_trans(Tween.TRANS_SINE)


func _slide_in(control: Control, offset: Vector2, delay: float, duration: float, continuing := false) -> void:
	var rest: Vector2 = control.get_meta(&"rest_position", control.position)
	control.set_meta(&"rest_position", rest)
	if not continuing: control.position = rest + offset
	_transition.tween_property(control, "position", rest, duration).set_delay(delay).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)


func _settle_page(page: Control) -> void:
	players.visible = page == players
	picker.visible = page == picker
	lobby.visible = page == lobby
	_background.rush = 0.0
	_background.visible = page == players


func update_vehicle(spec: VehicleSpec, unlocked: bool, best_distance: float, best_score: int, unlocked_distance := -1.0) -> void:
	_name.text = spec.title
	_tagline.text = ["Den röda klassikern.", "Lätt. Hal. Härligt ostyrig.", "Ratt, skidor och attityd.", "Ett varv till.", "Från köket till backen."][int(spec.model)]
	_locked.text = tr("Åk %s m för att låsa upp") % Hud.group_digits(int(spec.unlock_distance)) if not unlocked else ""
	start.disabled = not unlocked
	start.text = "NU ÅKER VI  →" if unlocked else "LÅST"
	var values := [spec.stat_speed, spec.stat_handling, spec.stat_grip]
	for i in _stats.size():
		_stats[i].value = values[i]
		_stats[i].queue_redraw()
	for i in cards.size():
		var chosen := i == int(spec.model)
		var surface := style(Color("364461") if chosen else Color("22273d"), LIME if chosen else Color(1, 1, 1, 0.08), 16)
		cards[i].add_theme_stylebox_override("normal", surface)
		cards[i].add_theme_stylebox_override("focus", focus_ring(surface))
		cards[i].modulate.a = 1.0 if maxf(best_distance, unlocked_distance) >= VehicleSpec.all()[i].unlock_distance else 0.42
	_record.text = tr("REKORD   %s m   /   %s poäng") % [Hud.group_digits(int(best_distance)), Hud.group_digits(best_score)] if best_distance > 0 else "5 ÅKDON"
	start.accessibility_name = start.text


func set_touch_mode(touch: bool) -> void:
	_touch_mode = touch
	_update_hints()


func set_gamepad_mode(gamepad: bool) -> void:
	if _gamepad_mode == gamepad: return
	_gamepad_mode = gamepad
	_update_hints()


func _update_hints() -> void:
	if _touch_mode:
		_picker_hint.set_parts(["Tryck på ett åkdon"], 16)
		_start_hint.set_parts(["Tryck för att åka"], 16)
		_controls_hint.set_parts(["Tryck på sidorna  Styr", null, "↑ Svep  Hoppa"])
	elif _gamepad_mode:
		_picker_hint.set_parts([["stick", ""], "Välj åkdon"], 16)
		_start_hint.set_parts([["pad", "A"], "Åk"], 16)
		_controls_hint.set_parts([["stick", ""], "Styr", null, ["pad", "A"], "Hoppa"])
		if Quality.is_tv():
			_controls_hint.set_parts(["Svep /", ["stick", ""], "Styr", null, "Klick /", ["pad", "A"], "Hoppa"])
	else:
		_picker_hint.set_parts([["key", "←"], ["key", "→"], "Välj åkdon"], 16)
		_start_hint.set_parts([["key", "Enter"], "Åk"], 16)
		_controls_hint.set_parts([["key", "←"], ["key", "→"], "Styr", null, ["key", "Space"], "Hoppa"])


func default_focus() -> Button:
	if _current_page == lobby: return null
	return solo if _current_page == players else (start if not start.disabled else back)
