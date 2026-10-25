class_name Quality
extends RefCounted
## Rendering budget per platform: phones and tablets get a shorter view
## distance, fewer snowflakes and thicker fog to hide the horizon.


## Testing aid: preview phone settings on the desktop (--mobile-preview).
static var force_mobile := false


static func is_mobile() -> bool:
	return force_mobile or OS.has_feature("mobile")


static func chunks_ahead() -> int:
	return 9 if is_mobile() else 14


static func snowflakes() -> int:
	return 2500 if is_mobile() else 6000


static func shadow_distance() -> float:
	return 80.0 if is_mobile() else 140.0


static func base_fog() -> float:
	return 0.0042 if is_mobile() else 0.0028


## Phones have small screens: pull the chase camera in and narrow the view.
static func camera_zoom() -> float:
	return 0.78 if is_mobile() else 1.0


static func fov_scale() -> float:
	return 0.86 if is_mobile() else 1.0


## Larger interface on phones, where the canvas is otherwise tiny.
static func ui_scale() -> float:
	return 1.35 if is_mobile() else 1.0
