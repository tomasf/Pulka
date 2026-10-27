class_name FpsMeter
extends Label
## Frame rate readout for checking performance on a device: frames per
## second, the slowest frame lately, the renderer in use and the resolution
## the 3D scene is drawn at, then where a frame's time goes: game logic
## (scripts and physics), the renderer's CPU work and the GPU. Turned on
## under Inställningar.

const REFRESH := 0.5

## Game logic time reported by the main loop since the last readout.
static var _logic_usec := 0

var _elapsed := 0.0
var _frames := 0
var _slowest := 0.0
var _render_cpu := 0.0
var _gpu := 0.0


func _ready() -> void:
	add_theme_font_size_override("font_size", 22)
	add_theme_color_override("font_outline_color", Hud.INK)
	add_theme_constant_override("outline_size", 6)
	# Bottom left is free during a run (the speed sits bottom centre).
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 36)
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	visibility_changed.connect(func() -> void:
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), visible))


## The main loop reports how long its frame's game logic took.
static func record_logic(usec: int) -> void:
	_logic_usec += usec


func _process(delta: float) -> void:
	if not visible:
		return
	_elapsed += delta
	_frames += 1
	_slowest = maxf(_slowest, delta)
	var viewport := get_viewport().get_viewport_rid()
	_render_cpu += RenderingServer.viewport_get_measured_render_time_cpu(viewport) + RenderingServer.get_frame_setup_time_cpu()
	_gpu += RenderingServer.viewport_get_measured_render_time_gpu(viewport)
	if _elapsed < REFRESH:
		return
	var fps := _frames / _elapsed
	# Green when smooth, yellow when it starts to stutter, red when it crawls.
	var color := Color(0.5, 1.0, 0.55) if fps >= 55.0 else (Hud.WARM if fps >= 30.0 else Color(1.0, 0.45, 0.4))
	add_theme_color_override("font_color", color)
	text = "%d FPS · skärm %d Hz · värst %.0f ms · %s · 3D %s\nlogik %.1f ms · rendering %.1f ms · GPU %.1f ms · %d ritanrop · %d objekt" % [
		roundi(fps), roundi(DisplayServer.screen_get_refresh_rate()), _slowest * 1000.0, _renderer(), _resolution(),
		_logic_usec / 1000.0 / _frames, _render_cpu / _frames, _gpu / _frames,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)]
	_elapsed = 0.0
	_frames = 0
	_slowest = 0.0
	_logic_usec = 0
	_render_cpu = 0.0
	_gpu = 0.0


func _renderer() -> String:
	var method := RenderingServer.get_current_rendering_method()
	var names := {"forward_plus": "Forward+", "mobile": "Mobile", "gl_compatibility": "Compatibility"}
	return "%s (%s)" % [names.get(method, method), RenderingServer.get_current_rendering_driver_name()]


func _resolution() -> String:
	var viewport := get_viewport()
	var size := Vector2(viewport.get_visible_rect().size)
	if viewport is Window:
		size = Vector2((viewport as Window).size)
	size *= viewport.scaling_3d_scale
	return "%d×%d" % [roundi(size.x), roundi(size.y)]
