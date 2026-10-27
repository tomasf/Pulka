class_name Quality
extends RefCounted
## Rendering budget per platform: phones and tablets get a shorter view
## distance, fewer snowflakes and thicker fog to hide the horizon. Browsers
## and Apple TV use the same rendering budget, keeping the desktop camera and
## UI since they show on big screens.


## Graphics level on top of the platform budget. Always Hög for now; lower
## levels are there for slower hardware (and --graphics=låg|medel to test).
enum Level { LOW, MEDIUM, HIGH }
const LEVEL_NAMES := ["Låg", "Medel", "Hög"]

## Testing aid: preview phone settings on the desktop (--mobile-preview).
static var force_mobile := false
## Testing aid: preview Apple TV settings on the desktop (--tv-preview).
static var force_tv := false
static var level := default_level()


## Everything starts at Hög; Apple TV 4K manages it at 1080p.
static func default_level() -> Level:
	return Level.HIGH


## Phones and tablets. Apple TV counts as mobile to Godot but sits under a
## big screen, so it is not one here.
static func is_mobile() -> bool:
	return force_mobile or (OS.has_feature("mobile") and not is_tv())


## Apple TV: played from the sofa with the Siri Remote or a game controller.
static func is_tv() -> bool:
	return force_tv or OS.has_feature("tvos")


static func reduced_effects() -> bool:
	return is_mobile() or is_tv() or OS.has_feature("web")


static func chunks_ahead() -> int:
	return 9 if reduced_effects() else 14


static func snowflakes() -> int:
	var count := 1200 if is_tv() else (2500 if reduced_effects() else 6000)
	return int(count * [0.4, 0.7, 1.0][level])


## Bloom costs several full-screen passes, too many for Apple TV's GPU.
static func glow() -> bool:
	return not is_tv()


static func shadow_distance() -> float:
	return (80.0 if reduced_effects() else 140.0) * [0.6, 0.8, 1.0][level]


## Two cascades keep shadows sharp up close and reaching far, at twice the
## shadow drawing; lower levels make do with one.
static func shadow_mode() -> DirectionalLight3D.ShadowMode:
	return DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if level == Level.HIGH else DirectionalLight3D.SHADOW_ORTHOGONAL


static func base_fog() -> float:
	return 0.0042 if reduced_effects() else 0.0028


## Phones have small screens and a TV is far away across the room: pull the
## chase camera in and narrow the view so the ride and what is ahead look big.
static func camera_zoom() -> float:
	if is_tv():
		return 0.85
	return 0.78 if is_mobile() else 1.0


static func fov_scale() -> float:
	if is_tv():
		return 0.9
	return 0.86 if is_mobile() else 1.0


## Share of the screen resolution the 3D scene renders at, the interface
## staying sharp. Apple TV 4K would otherwise draw four times the pixels of
## 1080p; lower graphics levels go below that.
static func render_scale() -> float:
	var scale := 1.0
	if is_tv():
		scale = clampf(1920.0 / maxf(DisplayServer.screen_get_size().x, 1.0), 0.5, 1.0)
	return scale * [0.7, 0.85, 1.0][level]


## FSR upscaling looks better than plain stretching, but the Compatibility
## renderer only has the latter.
static func scaling_mode() -> Viewport.Scaling3DMode:
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		return Viewport.SCALING_3D_MODE_BILINEAR
	return Viewport.SCALING_3D_MODE_FSR


## Larger interface on phones, where the canvas is otherwise tiny.
static func ui_scale() -> float:
	return 1.35 if is_mobile() else 1.0
