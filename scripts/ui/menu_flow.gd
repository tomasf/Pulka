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

signal pressed(action: StringName)

const DISPLAY_FONT := preload("res://fonts/FugazOne-Regular.ttf")
const BODY_FONT := preload("res://fonts/Nunito.ttf")
static var _bold: FontVariation
static var _vehicle_textures := {}
var canvas: Control
var players: Control
var picker: Control
var solo: Button
var duo: Button
var start: Button
var settings: Button
var back: Button
var cards: Array[Button] = []
var _name: Label
var _tagline: Label
var _locked: Label
var _stats: Array[Control] = []
var _record: Label
var _picker_hint: Label
var _start_hint: Label
var _controls_hint: Label
var _background: WinterBackdrop
var _transition: Tween
var _thumb_views: Array[SubViewport] = []


class WinterBackdrop extends Control:
	var clock := 0.0
	func _process(delta: float) -> void:
		if not is_visible_in_tree(): return
		clock += delta
		queue_redraw()
	func _draw() -> void:
		var s := size
		draw_rect(Rect2(Vector2.ZERO, s), Color("101329"))
		# Wide, quiet bands of moonlight behind the snow-capped ridge.
		for i in 28:
			var t := i / 27.0
			draw_rect(Rect2(0, s.y * t, s.x, s.y / 27.0 + 1), Color("101329").lerp(Color("29334e"), t * 0.85))
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


static func style(fill: Color, border := Color.TRANSPARENT, radius := 20) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 22
	box.content_margin_right = 22
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box


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
	var ring := style(Color.TRANSPARENT, LIME)
	ring.draw_center = false
	ring.set_border_width_all(3)
	ring.set_expand_margin_all(5)
	button.add_theme_stylebox_override("focus", ring)
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


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background = WinterBackdrop.new()
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)
	canvas = Control.new()
	canvas.size = DESIGN
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	players = _page()
	picker = _page()
	_build_players()
	_build_picker()
	settings = _button("⚙", &"settings", Vector2(1444, 42), Vector2(76, 64))
	settings.tooltip_text = "Inställningar"
	settings.accessibility_name = "Inställningar"
	gear_icon(settings)
	canvas.add_child(settings)
	resized.connect(_fit)
	_fit()


func _page() -> Control:
	var page := Control.new()
	page.size = DESIGN
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(page)
	return page


func _fit() -> void:
	var fit := minf(size.x / DESIGN.x, size.y / DESIGN.y)
	canvas.scale = Vector2.ONE * fit
	canvas.position = (size - DESIGN * fit) * 0.5


func _text(parent: Control, text: String, points: int, at: Vector2, tint := WHITE, display := false) -> Label:
	var label := caption(text, points, tint, display)
	label.position = at
	parent.add_child(label)
	return label


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
	_text(players, "PULKA!", 44, Vector2(80, 42), WHITE, true)
	_text(players, "01  /  VÄLJ SPELARE", 16, Vector2(1120, 64), MUTED)
	var headline := _text(players, "UT I\nBACKEN.", 112, Vector2(120, 230), WHITE, true)
	headline.add_theme_constant_override("line_spacing", -30)
	_text(players, "Snö i nacken. Ett åk till.", 26, Vector2(126, 521), ICE)
	solo = _player_card(1, Vector2(756, 234), CORAL)
	duo = _player_card(2, Vector2(1108, 278), ICE)
	duo.disabled = Quality.is_mobile()
	duo.tooltip_text = "Två spelare på samma skärm" if not duo.disabled else "Två spelare kräver tangentbord eller handkontroller"
	_record = _text(players, "", 19, Vector2(126, 736), MUTED)
	_text(players, "♫  Snödag", 17, Vector2(126, 818), MUTED)
	_text(players, "Välj ditt sällskap. Resten går utför.", 17, Vector2(948, 818), MUTED)
	solo.focus_neighbor_right = duo.get_path()
	duo.focus_neighbor_left = solo.get_path()


func _player_card(count: int, at: Vector2, tint: Color) -> Button:
	var button := _button("", &"solo" if count == 1 else &"duo", at, Vector2(310, 390))
	button.tooltip_text = "%d spelare" % count
	button.accessibility_name = button.tooltip_text
	players.add_child(button)
	var number := _text(button, "0%d" % count, 18, Vector2(28, 24), tint)
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text(button, "SOLO" if count == 1 else "DUELL", 14, Vector2(214, 28), MUTED)
	var preview := _preview(VehicleSpec.Model.PULKA if count == 1 else VehicleSpec.Model.SNOWRACER, count, true)
	preview.position = Vector2(-10, 60)
	preview.size = Vector2(330, 226)
	button.add_child(preview)
	_text(button, "%d spelare" % count, 31, Vector2(28, 292), WHITE, true)
	_text(button, "En oändlig backe" if count == 1 else "Först till mål", 18, Vector2(30, 340), MUTED)
	_text(button, "↗", 30, Vector2(252, 291), LIME)
	return button


func _build_picker() -> void:
	# A soft veil keeps the title readable without covering the 3D rider.
	var shade := TextureRect.new()
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.04, 0.07, 0.15, 0.88), Color(0.04, 0.07, 0.15, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2.ZERO
	texture.fill_to = Vector2.RIGHT
	shade.texture = texture
	shade.size = Vector2(900, 900)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picker.add_child(shade)
	back = _button("‹  Spelare", &"players", Vector2(80, 42), Vector2(190, 64))
	picker.add_child(back)
	_text(picker, "PULKA!", 44, Vector2(702, 44), WHITE, true)
	_text(picker, "02  /  VÄLJ ÅKDON", 16, Vector2(1120, 64), WHITE)
	_text(picker, "DITT ÅK BÖRJAR HÄR", 16, Vector2(84, 198), LIME)
	_name = _text(picker, "Pulka", 76, Vector2(80, 228), WHITE, true)
	_tagline = _text(picker, "Den röda klassikern.", 25, Vector2(84, 332), ICE)
	for i in 3:
		_text(picker, ["Fart", "Styrning", "Grepp"][i], 18, Vector2(86, 408 + i * 38), WHITE)
		var stat := Stat.new()
		stat.position = Vector2(214, 417 + i * 38)
		stat.size = Vector2(170, 12)
		stat.tint = [CORAL, ICE, LIME][i]
		picker.add_child(stat)
		_stats.append(stat)
	_locked = _text(picker, "", 20, Vector2(84, 550), CORAL)
	_controls_hint = _text(picker, "", 17, Vector2(84, 596), WHITE)
	var dock := Panel.new()
	dock.position = Vector2(60, 666)
	dock.size = Vector2(1480, 170)
	dock.add_theme_stylebox_override("panel", style(Color(0.055, 0.07, 0.15, 0.95), Color(1, 1, 1, 0.15), 26))
	picker.add_child(dock)
	var specs := VehicleSpec.all()
	for i in specs.size():
		var button := _button("", StringName("vehicle_%d" % i), Vector2(82 + i * 192, 684), Vector2(176, 134))
		button.tooltip_text = specs[i].title
		button.accessibility_name = specs[i].title
		picker.add_child(button)
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
	picker.add_child(start)
	_picker_hint = _text(picker, "", 16, Vector2(84, 851), WHITE)
	_start_hint = _text(picker, "", 16, Vector2(1320, 851), WHITE)
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
			person.dress(CORAL if i == 0 else ICE, Color("38548c") if i == 0 else CORAL)
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


func show_players() -> void:
	players.visible = true
	picker.visible = false
	_enter(players)


func show_picker() -> void:
	players.visible = false
	picker.visible = true
	_enter(picker)


func dismiss() -> void:
	if _transition != null: _transition.kill()
	_transition = create_tween()
	_transition.tween_property(self, "modulate:a", 0.0, 0.28)
	_transition.tween_callback(hide)


func _enter(page: Control) -> void:
	if _transition != null: _transition.kill()
	modulate.a = 1.0
	page.modulate.a = 0.0
	if not _background.visible: _background.modulate.a = 0.0
	_background.show()
	_transition = create_tween().set_parallel(true)
	_transition.tween_property(page, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE)
	_transition.tween_property(_background, "modulate:a", 1.0 if page == players else 0.0, 0.35).set_trans(Tween.TRANS_SINE)
	if page == picker: _transition.chain().tween_callback(_background.hide)


func update_vehicle(spec: VehicleSpec, unlocked: bool, best_distance: float, best_score: int) -> void:
	_name.text = spec.title
	_tagline.text = ["Den röda klassikern.", "Lätt. Hal. Härligt ostyrig.", "Ratt, skidor och attityd.", "Ett varv till.", "Från köket till backen."][int(spec.model)]
	_locked.text = "Åk %s m för att låsa upp" % Hud.group_digits(int(spec.unlock_distance)) if not unlocked else ""
	start.disabled = not unlocked
	start.text = "NU ÅKER VI  →" if unlocked else "LÅST"
	var values := [spec.stat_speed, spec.stat_handling, spec.stat_grip]
	for i in _stats.size():
		_stats[i].value = values[i]
		_stats[i].queue_redraw()
	for i in cards.size():
		var chosen := i == int(spec.model)
		cards[i].add_theme_stylebox_override("normal", style(Color("364461") if chosen else Color("22273d"), LIME if chosen else Color(1, 1, 1, 0.08), 16))
		cards[i].modulate.a = 1.0 if best_distance >= VehicleSpec.all()[i].unlock_distance else 0.42
	_record.text = "REKORD   %s m   /   %s poäng" % [Hud.group_digits(int(best_distance)), Hud.group_digits(best_score)] if best_distance > 0 else "5 ÅKDON"
	start.accessibility_name = start.text


func set_touch_mode(touch: bool) -> void:
	_picker_hint.text = "Tryck på ett åkdon" if touch else "←  →  Välj åkdon"
	_start_hint.text = "Tryck för att åka" if touch else "Enter / A  Åk"
	_controls_hint.text = "← →  Styr     Space / A  Hoppa     W / RT  Luta"
	if touch:
		_controls_hint.text = "Tryck på sidorna  Styr     ↑ Svep  Hoppa"
	elif Quality.is_tv():
		_controls_hint.text = "Svep / spak  Styr     Klick / A  Hoppa"


func default_focus() -> Button:
	return solo if players.visible else (start if not start.disabled else back)
