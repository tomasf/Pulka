class_name Sled
extends Node3D
## The player's ride. Physics is custom and analytic: the sled slides on the
## TerrainField surface, leaves it whenever the ground curves away faster than
## gravity can pull it down, and lands back on it.

signal jumped
## `grab` is how long a grab was held in the flight (see `grabbing`).
signal landed(air_time: float, impact: float, spin: float, grab: float)
## A flight ended in a new one instead of a landing (a bounce off
## something, a skip across water): the tricks so far still count.
signal tricked(air_time: float, spin: float, grab: float)
## Skipped across open water like a flat stone.
signal skimmed(speed: float)
## Too slow on open water: in you go.
signal sank

const GRAVITY := 15.0
const RIDER_MASS := 60.0
const RADIUS := 0.55
const MAX_STEP := 1.0 / 120.0
## Below this speed (m/s) open water swallows you instead of throwing you on.
const SKIM_SPEED := 12.0
## How far the nose may turn away from straight downhill. Sleds can't carve
## uphill, so holding a turn ends in a hard traverse instead of a U-turn.
const MAX_TURN := deg_to_rad(75.0)
## Seconds to get into a grab's pose, and back to the seat after letting go.
const GRAB_IN := 0.55
const GRAB_OUT := 0.45
## How far into the pose (0..1) a rider can still land safely, once the
## trick has been fully pulled off in that flight.
const GRAB_SAFE := 0.15
## How long jump must be held before a grab starts, so a quick tap in the
## air does nothing.
const GRAB_COMMIT := 0.15

var spec: VehicleSpec
var field: TerrainField
var velocity := Vector3.ZERO
## Testing aid: scale horizontal travel without changing jump impulses or gravity.
var speed_multiplier := 1.0
var yaw := 0.0
var on_ground := true
var on_ice := false
var air_time := 0.0
var air_spin := 0.0
## Holding a grab trick right now (jump pressed again and held in the air).
var grabbing := false
## Seconds of grab in the current flight.
var grab_time := 0.0
var boost_time := 0.0
var invulnerable_time := 0.0
var crashed := false
var frozen := true
var steer_visual := 0.0
## Sideways drift from wind gusts, in metres per second.
var wind_drift := Vector3.ZERO
## Pull from another rider's slipstream, in m/s² (races only).
var draft := 0.0
## Braking, in m/s²: a rider past the finish digs in their heels.
var brake := 0.0

var _ground_time := 0.0
var _air_since := 0.0
var _wobble_time := 0.0
## How far a spinning ride (saucer, wok) leans off the fall line.
var _lean := 0.0
var _up := Vector3.UP
var _body: Node3D
var _vehicle_mesh: MeshInstance3D
var _rider: RiderRig
var _rider_velocity := Vector3.ZERO
var _rider_spin := Vector3.ZERO
var _spray: GPUParticles3D
var _puff: GPUParticles3D
var _trail: SnowTrail
## Saucer and wok: which way the ride itself points (a heading like `yaw`)
## and how fast it turns, in rad/s. Nothing keeps it turning evenly: speed,
## steering, bumps and landings all push it about.
var _spin_angle := 0.0
var _spin_rate := 0.0
## How fast steering was turning the ride in the air (carried into landing).
var _air_rate := 0.0
var _trick: GrabTrick
## The jump button has been let go since take-off, so holding it now grabs.
var _grab_armed := false
## How long jump has been held since it armed a grab.
var _grab_hold := 0.0
## The pose was fully reached in this flight: from then on, landing before
## the rider is back in the seat is a crash.
var _grab_done := false
## Eased 0..1: how far into the trick pose the rider is.
var _grab_blend := 0.0
## How squashed the rider is from a landing; springs back to 0.
var _squash := 0.0
var _squash_speed := 0.0
## Running clock for the rider's small shakes over the snow.
var _rumble := 0.0
## The ground under the ride (normal, height) and where it was sampled; the
## physics and the visuals ask for the same spot several times a frame.
var _ground := Vector4.ZERO
var _ground_at := Vector2.INF
var _ground_below_structure := false
## Heading in the pipe's tangent plane; positive turns around its right wall.
var sewer_active := false
var _sewer_heading := 0.0
var _sewer_forward := Vector3.FORWARD
var _sewer_up := Vector3.UP


func _ready() -> void:
	_body = Node3D.new()
	add_child(_body)
	_vehicle_mesh = MeshInstance3D.new()
	_body.add_child(_vehicle_mesh)
	_rider = RiderRig.new()
	_body.add_child(_rider)
	_spray = _make_snow_particles(220, 0.45, false)
	_spray.position = Vector3(0, 0.1, 0.6)
	add_child(_spray)
	_puff = _make_snow_particles(60, 0.8, true)
	add_child(_puff)
	_trail = SnowTrail.new()
	add_child(_trail)


## `jacket` dresses the rider in a given colour (each racer in their own);
## otherwise jacket and hat are picked at random.
func set_vehicle(new_spec: VehicleSpec, rng: RandomNumberGenerator, jacket := Color.TRANSPARENT) -> void:
	spec = new_spec
	_vehicle_mesh.mesh = RideModels.vehicle(spec.model)
	_trail.set_model(spec.model)
	_trick = GrabTrick.for_model(spec.model)
	var coat := Palette.pick(Palette.JACKETS, rng) if jacket.a == 0.0 else jacket
	_rider.set_ride(spec.model)
	_rider.dress(coat, Palette.pick(Palette.JACKETS, rng))
	_reset_rider()


func distance() -> float:
	return -position.z


func speed() -> float:
	return travel_velocity().length()


func travel_velocity() -> Vector3:
	return velocity if crashed else Vector3(velocity.x * speed_multiplier, velocity.y, velocity.z * speed_multiplier)


func forward() -> Vector3:
	if sewer_active: return _sewer_forward
	return Vector3(sin(yaw), 0.0, -cos(yaw))


func sewer_up() -> Vector3:
	return _sewer_up if sewer_active and on_ground else _up


func rider_position() -> Vector3:
	return _rider.global_position


## `keep_trail` leaves the tracks so far (back on the slope after a crash).
func place_at(d: float, lateral := 0.0, start_speed := 0.0, keep_trail := false) -> void:
	sewer_active = false
	var x := field.center_x(d) + lateral
	position = Vector3(x, field.height(x, d), -d)
	var direction := field.track_dir(d)
	yaw = atan2(direction.x, -direction.z)
	velocity = direction * start_speed
	on_ground = true
	crashed = false
	air_time = 0.0
	air_spin = 0.0
	grab_time = 0.0
	boost_time = 0.0
	_lean = 0.0
	_spin_angle = yaw
	_spin_rate = spec.visual_spin * 0.6 * (1.0 if randf() < 0.5 else -1.0) if spec else 0.0
	_air_rate = 0.0
	_ground_time = 1.0
	_up = field.normal_world(position.x, position.z)
	if keep_trail:
		_trail.lift()
	else:
		_trail.clear()
	_reset_rider()
	_update_visual(1.0)


## `grab` is whether the jump button is held down (for grab tricks).
func step(delta: float, steer: float, jump: bool, grab := false) -> void:
	steer_visual = lerpf(steer_visual, steer, 1.0 - exp(-8.0 * delta))
	if frozen:
		_update_visual(delta)
		return
	_update_grab(delta, grab)
	var remaining := delta
	var first := true
	while remaining > 0.0:
		var dt := minf(remaining, MAX_STEP)
		remaining -= dt
		if crashed:
			_step_crash(dt)
		else:
			_step_physics(dt, steer, jump and first)
		first = false
	boost_time = maxf(0.0, boost_time - delta)
	invulnerable_time = maxf(0.0, invulnerable_time - delta)
	_update_visual(delta)
	_update_particles()
	_update_trail()


## A grab starts when jump is pressed again in a real flight and lasts while
## it is held; the press that jumped doesn't count, so holding it through
## the take-off never grabs by accident. Getting into the pose and back to
## the seat takes a while, and only time spent fully in it counts.
func _update_grab(delta: float, held: bool) -> void:
	if on_ground or crashed:
		grabbing = false
		_grab_armed = false
		_grab_hold = 0.0
		_grab_done = false
	elif not held:
		grabbing = false
		_grab_armed = true
		_grab_hold = 0.0
	elif _grab_armed and _air_since > 0.2:
		_grab_hold += delta
		grabbing = grabbing or _grab_hold >= GRAB_COMMIT
	# A trick cut short by the snow is dropped quickly.
	var out := GRAB_OUT * (0.4 if on_ground else 1.0)
	_grab_blend = move_toward(_grab_blend, 1.0 if grabbing else 0.0, delta / (GRAB_IN if grabbing else out))
	if grabbing and _grab_blend >= 1.0:
		_grab_done = true
		grab_time += delta


## Eased 0..1: how far into the trick pose the rider is.
func grab_blend() -> float:
	return _grab_blend


## Too far into a finished grab to land on the ride (a crash if it touches
## down). A grab that never got all the way in is just dropped on landing,
## so a stray press of jump doesn't spoil a run.
func in_trick() -> bool:
	return _grab_done and _grab_blend > GRAB_SAFE


func _step_physics(dt: float, steer: float, jump: bool) -> void:
	if field.in_sewer(distance()):
		_step_sewer(dt, steer, jump)
		return
	sewer_active = false
	var gravity := GRAVITY
	if on_ground:
		_ground_time += dt
		_air_since = 0.0
	else:
		_air_since += dt
		air_time += dt
	# Tiny hops over bumps keep full control for a moment ("coyote time").
	if on_ground or _air_since < 0.1:
		var n := _surface_normal()
		var current := velocity.length()
		var surface_grip := field.grip_factor(position.x, -position.z)
		on_ice = surface_grip < 0.9
		var steer_rate := spec.steer * lerpf(1.25, 0.75, clampf(current / 45.0, 0.0, 1.0))
		steer_rate *= lerpf(0.3, 1.0, surface_grip)
		var downhill := field.track_dir(-position.z)
		var fall_yaw := atan2(downhill.x, -downhill.z)
		if spec.spins:
			# A saucer goes where the hill goes; steering only leans it a little
			# off the fall line, and letting go lets it drift back.
			_lean = lerpf(_lean, steer * spec.steer, 1.0 - exp(-2.5 * dt * lerpf(0.3, 1.0, surface_grip)))
			yaw = fall_yaw + _lean
			_spin_on_snow(dt, steer, current, surface_grip)
		else:
			var off := wrapf(yaw - fall_yaw, -PI, PI)
			if absf(off) >= MAX_TURN and signf(steer) == signf(off):
				steer = 0.0
			yaw += steer * steer_rate * dt
			off = wrapf(yaw - fall_yaw, -PI, PI)
			if absf(off) > MAX_TURN:
				yaw -= (absf(off) - MAX_TURN) * signf(off) * (1.0 - exp(-8.0 * dt))
			if Vector2(velocity.x, velocity.z).length() > 1.5:
				var travel_yaw := atan2(velocity.x, -velocity.z)
				yaw += wrapf(travel_yaw - yaw, -PI, PI) * (1.0 - exp(-spec.self_align * dt))
			if spec.wobble > 0.0:
				_wobble_time += dt
				yaw += sin(_wobble_time * 1.7) * sin(_wobble_time * 0.63 + 1.0) * spec.wobble * dt * clampf(current / 20.0, 0.0, 1.0)
		var along := forward()
		along = (along - n * along.dot(n)).normalized()
		var side := along.cross(n)
		var forward_speed := velocity.dot(along)
		var side_speed := velocity.dot(side)
		var normal_speed := velocity.dot(n)
		var drag := spec.drag * current * current
		var friction := spec.friction * GRAVITY * maxf(n.y, 0.2) * (0.5 if on_ice else 1.0)
		var planar := Vector2(forward_speed, side_speed)
		var planar_speed := planar.length()
		# Arcade carving: the velocity swings round to follow the nose instead of
		# the ride skidding sideways down the hill. Low grip means a lazier swing.
		var grip := spec.grip * surface_grip
		if planar_speed > 0.5:
			var slip := atan2(side_speed, forward_speed)
			var turned := slip * exp(-grip * dt)
			var scrubbed := planar_speed * (1.0 - absf(slip - turned) * spec.scrub)
			planar_speed = maxf(0.0, scrubbed - (drag + friction + brake) * dt)
			planar = Vector2(cos(turned), sin(turned)) * planar_speed
		velocity = along * planar.x + side * planar.y + n * normal_speed
		if boost_time > 0.0:
			velocity += along * 16.0 * dt
		if draft > 0.0:
			velocity += along * draft * dt
		if jump and on_ground and _ground_time > 0.12:
			velocity += n * spec.jump
			on_ground = false
			_ground_time = 0.0
			_air_since = 1.0
			air_time = 0.0
			air_spin = 0.0
			grab_time = 0.0
			jumped.emit()
	else:
		# Spins are for real jumps, not for hops over every little bump.
		_air_rate = 0.0
		if _air_since > 0.25:
			var spin := steer * spec.air_spin * dt
			yaw += spin
			air_spin += spin
			_spin_angle += spin
			_air_rate = steer * spec.air_spin
		velocity *= 1.0 - spec.drag * 0.5 * velocity.length() * dt
		gravity *= spec.air_gravity
	velocity.y -= gravity * dt
	position += (travel_velocity() + wind_drift) * dt
	_resolve_ground()


## Orthonormal frame of the circular surface: X goes around the pipe,
## Y points inward, -Z runs downhill. It works above the centreline too.
func sewer_frame() -> Basis:
	var d := distance()
	var center := Vector2(field.center_x(d), field.sewer_height(d) + TerrainField.SEWER_RADIUS)
	var radial := (Vector2(position.x, position.y) - center).normalized()
	if radial == Vector2.ZERO: radial = Vector2(0, -1)
	var ends := field.sewer_span(d)
	var grade := (field.base_height(ends.y) - field.base_height(ends.x)) / (ends.y - ends.x)
	var inward := -Vector3(radial.x, radial.y, radial.x * field.center_slope(d) + radial.y * grade).normalized()
	var around := Vector3(-radial.y, radial.x, 0)
	return Basis(around, inward, around.cross(inward))


## A pipe's normal force does no work. Transport tangent velocity between
## frames instead of repeatedly projecting it and losing speed on the curve.
## At the roof v_around²/r must beat gravity, otherwise contact releases.
func _step_sewer(dt: float, steer: float, jump: bool) -> void:
	var frame := sewer_frame()
	var along := -frame.z
	var around_speed := velocity.dot(frame.x)
	if not sewer_active:
		var nose := forward()
		_sewer_heading = atan2(nose.dot(frame.x), nose.dot(along))
		sewer_active = true
	var supported := around_speed * around_speed / TerrainField.SEWER_RADIUS + GRAVITY * frame.y.y
	if on_ground and supported < -0.05: _sewer_takeoff()
	if on_ground:
		_ground_time += dt
		_air_since = 0
		var current := velocity.length()
		var grip := field.grip_factor(position.x, distance())
		if frame.y.y < 0.8: grip = 1.1 # The wet channel is only on the bottom.
		on_ice = grip < 0.9
		var turn_rate := spec.steer * lerpf(1.25, 0.75, clampf(current / 45, 0, 1)) * lerpf(0.3, 1, grip)
		if spec.spins:
			# The tube supports a much deeper bank than an open hill, including
			# the normally gently-steering saucer and wok.
			_lean = lerpf(_lean, steer * spec.steer * 2.5, 1 - exp(-2.5 * dt * lerpf(0.3, 1, grip)))
			_sewer_heading = _lean
			_spin_on_snow(dt, steer, current, grip)
		else:
			_sewer_heading = clampf(_sewer_heading + steer * turn_rate * dt, -MAX_TURN, MAX_TURN)
			if current > 1.5:
				var travel := atan2(around_speed, velocity.dot(along))
				_sewer_heading += wrapf(travel - _sewer_heading, -PI, PI) * (1 - exp(-spec.self_align * dt))
			if spec.wobble > 0:
				_wobble_time += dt
				_sewer_heading += sin(_wobble_time * 1.7) * sin(_wobble_time * 0.63 + 1) * spec.wobble * dt * clampf(current / 20, 0, 1)
		_sewer_forward = along * cos(_sewer_heading) + frame.x * sin(_sewer_heading)
		var side := _sewer_forward.cross(frame.y)
		var planar := Vector2(velocity.dot(_sewer_forward), velocity.dot(side))
		var planar_speed := planar.length()
		if planar_speed > 0.5:
			var slip := atan2(planar.y, planar.x)
			var turned := slip * exp(-spec.grip * grip * dt)
			# Concrete is smooth: steering still scrubs, scraping doesn't apply
			# the old heavy per-second wall brake.
			var drag := spec.drag * current * current
			var friction := spec.friction * GRAVITY * 0.35
			planar_speed = maxf(0, planar_speed * (1 - absf(slip - turned) * spec.scrub) - (drag + friction + brake) * dt)
			planar = Vector2(cos(turned), sin(turned)) * planar_speed
		velocity = _sewer_forward * planar.x + side * planar.y
		var gravity := Vector3.DOWN * GRAVITY
		velocity += (gravity - frame.y * gravity.dot(frame.y)) * dt
		if boost_time > 0: velocity += _sewer_forward * 16 * dt
		if draft > 0: velocity += _sewer_forward * draft * dt
		if jump and _ground_time > 0.12:
			velocity += frame.y * spec.jump
			_sewer_takeoff()
			jumped.emit()
	else:
		_air_since += dt
		air_time += dt
		_air_rate = 0.0
		if _air_since > 0.25:
			var spin := steer * spec.air_spin * dt
			_sewer_heading += spin
			air_spin += spin
			_spin_angle += spin
			_air_rate = steer * spec.air_spin
		velocity *= 1 - spec.drag * 0.5 * velocity.length() * dt
		velocity.y -= GRAVITY * spec.air_gravity * dt
	var was_grounded := on_ground
	var tangent_speed := Vector2(velocity.dot(frame.x), velocity.dot(along))
	position += travel_velocity() * dt
	var d := distance()
	if not field.in_sewer(d):
		sewer_active = false
		yaw = atan2(_sewer_forward.x, -_sewer_forward.z)
		on_ground = false
		return
	var center := Vector2(field.center_x(d), field.sewer_height(d) + TerrainField.SEWER_RADIUS)
	var radial := Vector2(position.x, position.y) - center
	if was_grounded or radial.length_squared() >= TerrainField.SEWER_RADIUS * TerrainField.SEWER_RADIUS:
		radial = radial.normalized() * TerrainField.SEWER_RADIUS
		position.x = center.x + radial.x
		position.y = center.y + radial.y
		var next := sewer_frame()
		if was_grounded:
			velocity = next.x * tangent_speed.x - next.z * tangent_speed.y
		else:
			var into := velocity.dot(next.y)
			if into < 0: velocity -= next.y * into
			var circum := velocity.dot(next.x)
			if circum * circum / TerrainField.SEWER_RADIUS + GRAVITY * next.y.y >= 0:
				on_ground = true
				_ground_time = 0
				_squash_speed -= clampf(maxf(-into, 0) * 0.12, 0.3, 2.2)
				if absf(air_spin) > 0.3:
					_sewer_heading = atan2(circum, velocity.dot(-next.z))
				_spin_on_landing(maxf(-into, 0))
				landed.emit(air_time, maxf(-into, 0), air_spin, grab_time)
		frame = next
	_sewer_up = frame.y
	_sewer_forward = -frame.z * cos(_sewer_heading) + frame.x * sin(_sewer_heading)
	yaw = atan2(_sewer_forward.x, -_sewer_forward.z)


## Saucer and wok on snow: the spin drifts toward a pace set by speed but
## keeps whichever way it is going, steering twists it (hard enough and it
## turns the other way), and bumps nudge it at random, more the faster you
## go. A slippery ride (low `spin_settle`) holds on to every push.
func _spin_on_snow(dt: float, steer: float, current: float, grip: float) -> void:
	var pace := clampf(current / 25.0, 0.0, 1.0)
	var natural := spec.visual_spin * (0.3 + 0.9 * pace)
	var way := 1.0 if _spin_rate >= 0.0 else -1.0
	_spin_rate += (natural * way - _spin_rate) * (1.0 - exp(-spec.spin_settle * lerpf(0.4, 1.0, grip) * dt))
	_spin_rate += steer * spec.spin_steer * dt
	_spin_rate += randfn(0.0, 1.0) * spec.spin_jitter * pace * sqrt(dt)
	var most := spec.visual_spin * 2.5
	_spin_rate = clampf(_spin_rate, -most, most)
	_spin_angle = wrapf(_spin_angle + _spin_rate * dt, -PI, PI)


## Touching down: a spin steered in the air carries on along the snow, and a
## hard landing knocks the ride round a bit either way.
func _spin_on_landing(impact: float) -> void:
	if spec.spins:
		_spin_rate += _air_rate * 0.6 + randf_range(-1.0, 1.0) * minf(impact, 10.0) * 0.3
		var most := spec.visual_spin * 2.5
		_spin_rate = clampf(_spin_rate, -most, most)
	_air_rate = 0.0


func _sewer_takeoff() -> void:
	on_ground = false
	_ground_time = 0
	_air_since = 1
	air_time = 0
	air_spin = 0
	grab_time = 0.0


## The ground's normal and height under the ride, sampled once per spot.
func _surface() -> Vector4:
	var at := Vector2(position.x, position.z)
	var below_structure := _below_structure()
	if at != _ground_at or below_structure != _ground_below_structure:
		_ground = field.surface_world(at.x, at.y, not below_structure)
		_ground_at = at
		_ground_below_structure = below_structure
	return _ground


func _below_structure() -> bool:
	return field.below_structure(position)


func _surface_normal() -> Vector3:
	if sewer_active and field.in_sewer(distance()): return sewer_frame().y
	var ground := _surface()
	return Vector3(ground.x, ground.y, ground.z)


func _resolve_ground() -> void:
	var h := _surface().w
	var gap := position.y - h
	if gap <= 0.0 or (on_ground and gap < 0.002):
		if field.is_water(-position.z, position.x):
			position.y = h
			_touch_water()
			return
		var n := _surface_normal()
		var into := velocity.dot(n)
		position.y = h
		if into < 0.0:
			velocity -= n * into
		if not on_ground:
			on_ground = true
			_ground_time = 0.0
			if absf(air_spin) > 0.3:
				# Land tricks cleanly: the nose snaps to the direction of travel.
				yaw += wrapf(atan2(velocity.x, -velocity.z) - yaw, -PI, PI)
			# The rider sinks into the landing, harder the harder it was.
			_squash_speed -= clampf(maxf(-into, 0.0) * 0.12, 0.3, 2.2)
			_spin_on_landing(maxf(-into, 0.0))
			landed.emit(air_time, maxf(-into, 0.0), air_spin, grab_time)
	elif on_ground:
		on_ground = false
		air_time = 0.0
		air_spin = 0.0
		grab_time = 0.0


func _touch_water() -> void:
	var current := velocity.length()
	if current < SKIM_SPEED:
		velocity *= 0.2
		on_ground = true
		sank.emit()
		return
	# Preserve momentum across the broad lake; repeated skips should not
	# swallow a clean, fast crossing before the far shore is reachable.
	velocity *= 0.97
	velocity.y = 2.4 + current * 0.035
	_bank_tricks()
	on_ground = false
	_air_since = 1.0
	_ground_time = 0.0
	air_time = 0.0
	air_spin = 0.0
	grab_time = 0.0
	skimmed.emit(current)


func total_mass() -> float:
	return RIDER_MASS + spec.mass


## Bumped by something: pushed along `normal` (away from what was hit),
## nudged out of it, optionally spun round.
func knock(normal: Vector3, push: float, separation: float, spin := 0.0) -> void:
	velocity += normal * push
	position += normal * separation
	yaw += spin


## Springs the ride back into the air, e.g. off a car roof.
func bounce(upward: float) -> void:
	_bank_tricks()
	velocity.y = maxf(velocity.y, 0.0) + upward
	on_ground = false
	_air_since = 1.0
	_ground_time = 0.0
	air_time = 0.0
	air_spin = 0.0
	grab_time = 0.0
	_puff.restart()


## Hands on the spin and grab of a flight that is about to restart.
func _bank_tricks() -> void:
	if not on_ground and not crashed and (absf(air_spin) > 0.3 or grab_time > 0.0):
		tricked.emit(air_time, air_spin, grab_time)


func crash() -> void:
	if crashed:
		return
	var impact_velocity := travel_velocity()
	crashed = true
	grabbing = false
	_grab_blend = 0.0
	_grab_done = false
	_vehicle_mesh.transform = Transform3D.IDENTITY
	_rider.scale = Vector3.ONE
	_squash = 0.0
	_squash_speed = 0.0
	var xform := _rider.global_transform
	_rider.top_level = true
	_rider.global_transform = xform
	_rider_velocity = impact_velocity * 0.85 + Vector3.UP * 6.0
	_rider_spin = Vector3(randf_range(-9, 9), randf_range(-5, 5), randf_range(-9, 9))
	velocity = impact_velocity * -0.15 + Vector3.UP * 3.0
	on_ground = false
	_puff.restart()


func _step_crash(dt: float) -> void:
	_rider_velocity.y -= GRAVITY * dt
	var p := _rider.global_position + _rider_velocity * dt
	var h := field.height_world(p.x, p.z) + 0.25
	if p.y < h:
		p.y = h
		if _rider_velocity.y < 0.0:
			_rider_velocity.y *= -0.35
		_rider_velocity.x *= 0.82
		_rider_velocity.z *= 0.82
		_rider_spin *= 0.75
	_rider.global_position = p
	_rider.flail(dt)
	_rider.rotate_x(_rider_spin.x * dt)
	_rider.rotate_y(_rider_spin.y * dt)
	_rider.rotate_z(_rider_spin.z * dt)
	velocity.y -= GRAVITY * dt
	position += velocity * dt
	yaw += 4.0 * dt
	var ground := field.height_world(position.x, position.z, not _below_structure())
	if position.y < ground:
		position.y = ground
		velocity.y = maxf(velocity.y, 0.0)
		velocity *= 0.97


func _reset_rider() -> void:
	if _rider == null:
		return
	_rider.top_level = false
	_rider.transform = Transform3D(Basis.IDENTITY, Vector3(0, spec.seat_height if spec else 0.2, 0.05))


func _update_visual(delta: float) -> void:
	var target_up := _surface_normal() if on_ground or crashed else Vector3.UP
	var blend := 1.0 - exp(-14.0 * delta)
	if _up.dot(target_up) < -0.999:
		_up = _up.rotated(forward().normalized(), PI * blend).normalized()
	elif _up.dot(target_up) > 0.999:
		# A nearly parallel cross product is too small for slerp's axis on
		# a flat lake. Interpolation also avoids sudden numerical rotations.
		_up = _up.lerp(target_up, blend).normalized()
	else:
		_up = _up.slerp(target_up, blend).normalized()
	var ahead := forward()
	ahead = (ahead - _up * ahead.dot(_up)).normalized()
	if ahead.length_squared() < 0.01: ahead = _up.cross(Vector3.RIGHT).normalized()
	var right := ahead.cross(_up)
	basis = Basis(right, _up, -ahead)
	_body.rotation.z = -steer_visual * 0.22
	_body.rotation.x = 0.0 if on_ground else clampf(velocity.y * 0.02, -0.3, 0.3)
	# The ride's pose is rebuilt from scratch every frame so nothing a
	# previous ride left behind can turn it.
	# The body is turned from the way the ride travels to the way it points.
	var spinning := spec != null and spec.spins
	_body.rotation.y = wrapf(yaw - _spin_angle, -PI, PI) if spinning else 0.0
	_vehicle_mesh.transform = Transform3D.IDENTITY
	if not crashed and _rider:
		# A damped spring brings a squashed rider back up after a landing.
		_squash_speed += (-_squash * 260.0 - _squash_speed * 16.0) * delta
		_squash = clampf(_squash + _squash_speed * delta, -0.3, 0.15)
		var rattle := 0.0
		if on_ground and spec != null:
			_rumble += delta * (30.0 + speed() * 0.8)
			rattle = (sin(_rumble) * 0.6 + sin(_rumble * 2.3) * 0.4) * clampf(speed() / 40.0, 0.0, 1.0) * 0.006
		var seat := spec.seat_height if spec else 0.2
		_rider.position = Vector3(0, seat + rattle + _squash * 0.2, 0.05)
		_rider.scale = Vector3(1.0 - _squash * 0.4, 1.0 + _squash, 1.0 - _squash * 0.4)
		# Lean into turns; pitch follows the flight automatically.
		var pitch := 0.0
		if not on_ground:
			pitch += clampf(velocity.y * 0.025, -0.2, 0.2)
		_rider.rotation.z = -steer_visual * 0.12
		_rider.rotation.x = pitch * 0.4
		_rider.rotation.y = 0.0
		var trick := _trick if _grab_blend > 0.0 else null
		var shown := smoothstep(0.0, 1.0, _grab_blend)
		if trick != null:
			trick.place_rider(_rider, shown)
		# The body bends into the turn and raises its arms in a long jump.
		_rider.animate(delta, steer_visual, not on_ground, shown, trick)
		if trick != null:
			trick.hold(_rider, _vehicle_mesh, shown)
	_body.visible = invulnerable_time <= 0.0 or fmod(invulnerable_time, 0.2) < 0.12


func _update_particles() -> void:
	var current := speed()
	_spray.emitting = on_ground and not crashed and current > 6.0
	_spray.amount_ratio = clampf(current / 40.0 + absf(steer_visual) * 0.4, 0.15, 1.0)
	var process := _spray.process_material as ParticleProcessMaterial
	var up := sewer_up() if sewer_active else Vector3.UP
	process.direction = (-velocity.normalized() + up * 0.8).normalized() * global_basis
	process.color = Color(0.50, 0.60, 0.35, 0.7) if field.in_sewer(distance()) else Color.WHITE
	process.initial_velocity_min = current * 0.05
	process.initial_velocity_max = current * 0.15


## Tracks in the snow wherever the ride touches it, but not on water or
## the mall's tiled floor. Ice only takes faint scratches.
## Forgets the tracks that end before distance `d` (behind everyone).
func prune_trail(d: float) -> void:
	_trail.prune(d)


func _update_trail() -> void:
	var d := distance()
	if not on_ground or crashed or field.is_water(d, position.x) or field.region(d) in [TerrainField.Region.MALL, TerrainField.Region.ICE_CAVE, TerrainField.Region.SEWER] or field.on_bridge(d) or field.harbor_surface_lift(position.x, d) >= 0:
		_trail.lift()
		return
	# A spinning ride smears along where it is going, not where it points.
	var along := forward()
	if spec.spins and Vector2(velocity.x, velocity.z).length() > 1.0:
		along = Vector3(velocity.x, 0.0, velocity.z).normalized()
	var up := _surface_normal()
	_trail.record(position, along.cross(up).normalized(), up, 0.4 if on_ice else 1.0)


func puff() -> void:
	_puff.restart()


## Round, soft, unshaded billboard that fades out close to the camera.
static func soft_flake_material() -> StandardMaterial3D:
	var dot := GradientTexture2D.new()
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(0.5, 0.0)
	dot.width = 32
	dot.height = 32
	var falloff := Gradient.new()
	falloff.set_color(0, Color(1, 1, 1, 1))
	falloff.set_color(1, Color(1, 1, 1, 0))
	dot.gradient = falloff
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = dot
	material.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	material.distance_fade_min_distance = 0.8
	material.distance_fade_max_distance = 3.0
	return material


func _make_snow_particles(amount: int, lifetime: float, one_shot: bool) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = lifetime
	particles.one_shot = one_shot
	particles.explosiveness = 0.9 if one_shot else 0.0
	particles.emitting = false
	particles.local_coords = false
	particles.visibility_aabb = AABB(Vector3(-20, -10, -20), Vector3(40, 20, 40))
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0, 1, 1)
	process.spread = 35.0 if not one_shot else 80.0
	process.initial_velocity_min = 2.0
	process.initial_velocity_max = 6.0 if not one_shot else 9.0
	process.gravity = Vector3(0, -9.0, 0)
	process.damping_min = 2.0
	process.damping_max = 4.0
	process.scale_min = 0.6
	process.scale_max = 1.6
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(0.35, 0.05, 0.2)
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.9))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	process.color_ramp = ramp
	particles.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.22, 0.22)
	quad.material = soft_flake_material()
	particles.draw_pass_1 = quad
	return particles
