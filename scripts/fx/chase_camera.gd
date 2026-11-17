class_name ChaseCamera
extends Camera3D
## Third-person camera tuned for a sense of speed: it drops lower, pulls in and
## widens its field of view as you go faster, and shakes on bumps and impacts.

enum Mode { ORBIT, CHASE, CRASH, START }
const START_SECONDS := 1.1

var mode := Mode.ORBIT
## Orbit with the rider in the middle of the view (a racer who has won),
## not off to the right of the menu panel.
var centered := false
var target: Sled
var field: TerrainField

var _look_dir := Vector3.FORWARD
var _shake := 0.0
var _time := 0.0
var _orbit_angle := 2.4
var _noise := FastNoiseLite.new()
var _start_fov := 60.0
var _start_offset := 0.0
var _start_vertical := 0.0
var _start_elapsed := 0.0
var _start_duration := START_SECONDS
var _start_relative := Vector3.ZERO
var _start_angles := Vector3.ZERO
var _end_angles := Vector3.ZERO


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


## Keep the live preview's exact pose, then ease into the riding camera.
func begin_run(seconds := START_SECONDS) -> void:
	_start_fov = fov
	_start_offset = h_offset
	_start_vertical = v_offset
	_start_relative = position - target.position
	_start_angles = basis.get_rotation_quaternion().get_euler()
	_start_elapsed = 0.0
	_start_duration = seconds
	_look_dir = target.forward()
	var destination := target.position - _look_dir * 4.4 + Vector3.UP * 2.9
	destination.y = maxf(destination.y, field.height_world(destination.x, destination.z) + 1.0)
	_end_angles = Basis.looking_at(target.position + _look_dir * 12.0 - destination, Vector3.UP).get_euler()
	mode = Mode.START


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
		Mode.START:
			_update_start(delta)


func _update_start(delta: float) -> void:
	_start_elapsed += delta
	var t := smoothstep(0.0, 1.0, minf(_start_elapsed / _start_duration, 1.0))
	# Travel around the rider, never on a chord through their body when the
	# preview happens to be facing them from the front.
	var from_angle := atan2(_start_relative.x, _start_relative.z)
	var to_angle := atan2(-_look_dir.x, -_look_dir.z)
	var angle := lerp_angle(from_angle, to_angle, t)
	var radius := lerpf(Vector2(_start_relative.x, _start_relative.z).length(), 4.4, t)
	position = target.position + Vector3(sin(angle) * radius, lerpf(_start_relative.y, 2.9, t), cos(angle) * radius)
	position.y = maxf(position.y, field.height_world(position.x, position.z) + lerpf(0.65, 1.0, t))
	# Drive heading along the same arc as position. Two independently chosen
	# shortest rotations can disagree when the preview is almost head-on.
	var from_heading := wrapf(_start_angles.y - from_angle, -PI, PI)
	var to_heading := wrapf(_end_angles.y - to_angle, -PI, PI)
	basis = Basis.from_euler(Vector3(lerpf(_start_angles.x, _end_angles.x, t), angle + lerpf(from_heading, to_heading, t), lerpf(_start_angles.z, _end_angles.z, t)))
	fov = lerpf(_start_fov, 53.0, t)
	h_offset = lerpf(_start_offset, 0.0, t)
	v_offset = lerpf(_start_vertical, 0.0, t)
	if _start_elapsed >= _start_duration:
		mode = Mode.CHASE


func _speed_factor() -> float:
	return clampf(target.speed() / 45.0, 0.0, 1.3)


func _update_chase(delta: float) -> void:
	var velocity := target.travel_velocity()
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var dir := flat.normalized() if flat.length() > 2.0 else target.forward()
	dir = dir.lerp(target.forward(), 0.3).normalized()
	_look_dir = _look_dir.lerp(dir, 1.0 - exp(-5.0 * delta)).normalized()
	var sf := _speed_factor()
	# Close in, so the ride and what is ahead look big even on a phone or
	# a TV across the room.
	var distance := lerpf(4.4, 3.25, minf(sf, 1.0))
	# High enough that the rider sits low in the frame and the way ahead shows.
	var height := lerpf(2.9, 2.35, minf(sf, 1.0))
	var desired := target.position - _look_dir * distance + Vector3.UP * height
	desired.y = maxf(desired.y, field.height_world(desired.x, desired.z) + 1.0)
	var follow := 1.0 - exp(-12.0 * delta)
	position = Vector3(lerpf(position.x, desired.x, follow), lerpf(position.y, desired.y, 1.0 - exp(-8.0 * delta)), lerpf(position.z, desired.z, follow))
	var look := target.position + _look_dir * 12.0
	if position.distance_squared_to(look) > 0.01:
		look_at(look, Vector3.UP)
	rotate_object_local(Vector3.BACK, -target.steer_visual * 0.06 * minf(sf, 1.0))
	var boost := 8.0 if target.boost_time > 0.0 else 0.0
	var wide := 53.0 + 26.5 * pow(minf(sf, 1.2), 1.3) + boost
	fov = lerpf(fov, wide, 1.0 - exp(-3.0 * delta))
	# Rumble grows with speed, so a ride standing still (countdown) is calm.
	var bumps := 0.04 if target.on_ground and field.bumpiness(target.distance()) > 0.5 else 0.0
	_apply_shake(minf(sf, 1.0) * (0.012 + bumps) + sf * sf * 0.05)


func _update_orbit(delta: float) -> void:
	_orbit_angle += delta * 0.2
	var center := target.position + Vector3.UP * 0.6
	var angle := _orbit_angle - target.yaw
	position = center + Vector3(sin(angle) * 4.8, 1.5, cos(angle) * 4.8)
	position.y = maxf(position.y, field.height_world(position.x, position.z) + 0.65)
	look_at(center + Vector3.UP * 0.2 + target.forward() * 0.15, Vector3.UP)
	fov = 60.0
	# Keep the rider in the right half of the screen, clear of the menu panel.
	h_offset = 0.0 if centered else -1.1
	v_offset = 0.0 if centered else -0.18


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
