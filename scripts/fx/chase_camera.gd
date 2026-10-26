class_name ChaseCamera
extends Camera3D
## Third-person camera tuned for a sense of speed: it drops lower, pulls in and
## widens its field of view as you go faster, and shakes on bumps and impacts.

enum Mode { ORBIT, CHASE, CRASH }

var mode := Mode.ORBIT
var target: Sled
var field: TerrainField

var _look_dir := Vector3.FORWARD
var _shake := 0.0
var _time := 0.0
var _orbit_angle := 0.6
var _noise := FastNoiseLite.new()


func _ready() -> void:
	_noise.frequency = 0.9
	fov = 70.0
	near = 0.1
	far = 900.0


func add_shake(amount: float) -> void:
	_shake = minf(_shake + amount, 1.2)


func snap() -> void:
	_look_dir = target.forward()
	update_camera(1.0)


func update_camera(delta: float) -> void:
	_time += delta
	_shake = maxf(0.0, _shake - delta * 2.2)
	match mode:
		Mode.ORBIT:
			_update_orbit(delta)
		Mode.CHASE:
			_update_chase(delta)
		Mode.CRASH:
			_update_crash(delta)


func _speed_factor() -> float:
	return clampf(target.speed() / 45.0, 0.0, 1.3)


func _update_chase(delta: float) -> void:
	var velocity := target.travel_velocity()
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var dir := flat.normalized() if flat.length() > 2.0 else target.forward()
	dir = dir.lerp(target.forward(), 0.3).normalized()
	_look_dir = _look_dir.lerp(dir, 1.0 - exp(-5.0 * delta)).normalized()
	var sf := _speed_factor()
	var zoom := Quality.camera_zoom()
	var distance := lerpf(6.8, 5.0, minf(sf, 1.0)) * zoom
	# High enough that the rider sits low in the frame and the way ahead shows.
	var height := lerpf(4.5, 3.6, minf(sf, 1.0)) * zoom
	var desired := target.position - _look_dir * distance + Vector3.UP * height
	desired.y = maxf(desired.y, field.height_world(desired.x, desired.z) + 1.0)
	var follow := 1.0 - exp(-12.0 * delta)
	position = Vector3(lerpf(position.x, desired.x, follow), lerpf(position.y, desired.y, 1.0 - exp(-8.0 * delta)), lerpf(position.z, desired.z, follow))
	var look := target.position + _look_dir * 12.0
	if position.distance_squared_to(look) > 0.01:
		look_at(look, Vector3.UP)
	rotate_object_local(Vector3.BACK, -target.steer_visual * 0.06 * minf(sf, 1.0))
	var boost := 10.0 if target.boost_time > 0.0 else 0.0
	var wide := (68.0 + 34.0 * pow(minf(sf, 1.2), 1.3) + boost) * Quality.fov_scale()
	fov = lerpf(fov, wide, 1.0 - exp(-3.0 * delta))
	# Rumble grows with speed, so a ride standing still (countdown) is calm.
	var bumps := 0.04 if target.on_ground and field.bumpiness(target.distance()) > 0.5 else 0.0
	_apply_shake(minf(sf, 1.0) * (0.012 + bumps) + sf * sf * 0.05)


func _update_orbit(delta: float) -> void:
	_orbit_angle += delta * 0.2
	var center := target.position + Vector3.UP * 0.6
	var angle := 0.5 + sin(_orbit_angle) * 0.9
	position = center + Vector3(sin(angle) * 4.8, 1.5, cos(angle) * 4.8 - 0.5)
	look_at(center + Vector3(0, 0.2, -1.0), Vector3.UP)
	fov = 60.0
	# Keep the rider in the right half of the screen, clear of the menu panel.
	h_offset = -1.7
	v_offset = 0.0


func _update_crash(delta: float) -> void:
	var focus := target.rider_position()
	var desired := focus + Vector3(4.0, 3.5, 6.0)
	desired.y = maxf(desired.y, field.height_world(desired.x, desired.z) + 1.5)
	position = position.lerp(desired, 1.0 - exp(-2.5 * delta))
	look_at(focus, Vector3.UP)
	fov = lerpf(fov, 55.0, 1.0 - exp(-2.0 * delta))
	_apply_shake(0.0)


func _apply_shake(base: float) -> void:
	var amount := base + _shake * 0.35
	h_offset = _noise.get_noise_2d(_time * 30.0, 0.0) * amount
	v_offset = _noise.get_noise_2d(0.0, _time * 30.0) * amount
