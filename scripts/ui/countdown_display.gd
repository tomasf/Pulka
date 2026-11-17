class_name CountdownDisplay
extends Control
## One replaceable animation: the outgoing number cannot fade the new one.
const BEAT_SECONDS := 0.7
var text := ""
var tint := Color.WHITE
var progress := 0.0
var pulse := 1.0
var _animation: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modulate.a = 0.0

func show_count(message: String, color := Color.WHITE, hold := 0.65) -> void:
	if _animation != null: _animation.kill()
	if message.is_valid_int(): hold = BEAT_SECONDS - 0.18
	text = message
	tint = color
	progress = 0.0
	pulse = 0.82
	modulate.a = 1.0
	_animation = create_tween().set_parallel(true)
	_animation.tween_property(self, "pulse", 1.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_animation.tween_property(self, "progress", 1.0, maxf(hold + 0.18, 0.3))
	_animation.tween_property(self, "modulate:a", 0.0, 0.18).set_delay(hold)

func clear() -> void:
	if _animation != null: _animation.kill()
	text = ""
	modulate.a = 0.0

func _process(_delta: float) -> void:
	if modulate.a > 0: queue_redraw()

func _draw() -> void:
	if text == "": return
	var center := size * 0.5
	var radius := minf(size.x * 0.16, size.y * 0.15)
	var numeric := text.is_valid_int()
	if numeric:
		draw_circle(center, radius + 10, Color(0.04, 0.07, 0.14, 0.60))
		draw_arc(center, radius, -PI / 2, TAU - PI / 2, 90, Color(1, 1, 1, 0.15), 3, true)
		draw_arc(center, radius, -PI / 2, -PI / 2 + TAU * (1.0 - progress), 90, MenuFlow.LIME, 5, true)
	var points := roundi(radius * (1.25 if numeric else 0.95) * pulse)
	var face := MenuFlow.font(true)
	var width := face.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, points).x
	if not numeric:
		var plate := MenuFlow.style(Color(0.04, 0.07, 0.14, 0.76), Color.TRANSPARENT, 24)
		draw_style_box(plate, Rect2(center + Vector2(-width * 0.5 - 32, -points * 0.65), Vector2(width + 64, points * 1.3)))
	draw_string(face, center + Vector2(-width * 0.5, points * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, points, tint)
