class_name Sled
extends Node3D
## The player's ride. Physics is custom and analytic: the sled slides on the
## TerrainField surface, leaves it whenever the ground curves away faster than
## gravity can pull it down, and lands back on it.

signal jumped
signal landed(air_time: float, impact: float, spin: float)
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
var boost_time := 0.0
var invulnerable_time := 0.0
var crashed := false
var frozen := true
var steer_visual := 0.0
## Sideways drift from wind gusts, in metres per second.
var wind_drift := Vector3.ZERO

var _ground_time := 0.0
var _air_since := 0.0
var _wobble_time := 0.0
var _up := Vector3.UP
var _body: Node3D
var _vehicle_mesh: MeshInstance3D
var _rider: MeshInstance3D
var _rider_velocity := Vector3.ZERO
var _rider_spin := Vector3.ZERO
var _spray: GPUParticles3D
var _puff: GPUParticles3D
var _visual_spin := 0.0


func _ready() -> void:
	_body = Node3D.new()
	add_child(_body)
	_vehicle_mesh = MeshInstance3D.new()
	_body.add_child(_vehicle_mesh)
	_rider = MeshInstance3D.new()
	_body.add_child(_rider)
	_spray = _make_snow_particles(220, 0.45, false)
	_spray.position = Vector3(0, 0.1, 0.6)
	add_child(_spray)
	_puff = _make_snow_particles(60, 0.8, true)
	add_child(_puff)


func set_vehicle(new_spec: VehicleSpec, rng: RandomNumberGenerator) -> void:
	spec = new_spec
	_vehicle_mesh.mesh = RideModels.vehicle(spec.model)
	_rider.mesh = RideModels.rider(Palette.pick(Palette.JACKETS, rng), Palette.pick(Palette.JACKETS, rng), spec.model)
	_reset_rider()


func distance() -> float:
	return -position.z


func speed() -> float:
	return travel_velocity().length()


func travel_velocity() -> Vector3:
	return velocity if crashed else Vector3(velocity.x * speed_multiplier, velocity.y, velocity.z * speed_multiplier)


func forward() -> Vector3:
	return Vector3(sin(yaw), 0.0, -cos(yaw))


func rider_position() -> Vector3:
	return _rider.global_position


func place_at(d: float, lateral := 0.0, start_speed := 0.0) -> void:
	var x := field.center_x(d) + lateral
	position = Vector3(x, field.height(x, d), -d)
	var direction := field.track_dir(d)
	yaw = atan2(direction.x, -direction.z)
	velocity = direction * start_speed
	on_ground = true
	crashed = false
	air_time = 0.0
	air_spin = 0.0
	boost_time = 0.0
	_ground_time = 1.0
	_up = field.normal_world(position.x, position.z)
	_reset_rider()
	_update_visual(1.0)


func step(delta: float, steer: float, tuck: float, jump: bool) -> void:
	steer_visual = lerpf(steer_visual, steer, 1.0 - exp(-8.0 * delta))
	if frozen:
		_update_visual(delta)
		return
	var remaining := delta
	var first := true
	while remaining > 0.0:
		var dt := minf(remaining, MAX_STEP)
		remaining -= dt
		if crashed:
			_step_crash(dt)
		else:
			_step_physics(dt, steer, tuck, jump and first)
		first = false
	boost_time = maxf(0.0, boost_time - delta)
	invulnerable_time = maxf(0.0, invulnerable_time - delta)
	_update_visual(delta)
	_update_particles()


func _step_physics(dt: float, steer: float, tuck: float, jump: bool) -> void:
	var gravity := GRAVITY
	if on_ground:
		_ground_time += dt
		_air_since = 0.0
	else:
		_air_since += dt
		air_time += dt
	# Tiny hops over bumps keep full control for a moment ("coyote time").
	if on_ground or _air_since < 0.1:
		var n := field.normal_world(position.x, position.z)
		var current := velocity.length()
		var surface_grip := field.grip_factor(position.x, -position.z)
		on_ice = surface_grip < 0.9
		var steer_rate := spec.steer * lerpf(1.25, 0.75, clampf(current / 45.0, 0.0, 1.0))
		steer_rate *= lerpf(0.3, 1.0, surface_grip)
		var downhill := field.track_dir(-position.z)
		var fall_yaw := atan2(downhill.x, -downhill.z)
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
		var drag := spec.drag * (1.0 - 0.4 * tuck) * current * current
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
			planar_speed = maxf(0.0, scrubbed - (drag + friction) * dt)
			planar = Vector2(cos(turned), sin(turned)) * planar_speed
		velocity = along * planar.x + side * planar.y + n * normal_speed
		if boost_time > 0.0:
			velocity += along * 16.0 * dt
		if jump and on_ground and _ground_time > 0.12:
			velocity += n * spec.jump
			on_ground = false
			_ground_time = 0.0
			_air_since = 1.0
			air_time = 0.0
			air_spin = 0.0
			jumped.emit()
	else:
		# Spins are for real jumps, not for hops over every little bump.
		if _air_since > 0.25:
			var spin := steer * spec.air_spin * dt
			yaw += spin
			air_spin += spin
		velocity *= 1.0 - spec.drag * 0.5 * velocity.length() * dt
		gravity *= spec.air_gravity
	velocity.y -= gravity * dt
	position += (travel_velocity() + wind_drift) * dt
	_resolve_ground()


func _resolve_ground() -> void:
	var h := field.height_world(position.x, position.z)
	var gap := position.y - h
	if gap <= 0.0 or (on_ground and gap < 0.002):
		if field.is_water(-position.z):
			position.y = h
			_touch_water()
			return
		var n := field.normal_world(position.x, position.z)
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
			landed.emit(air_time, maxf(-into, 0.0), air_spin)
	elif on_ground:
		on_ground = false
		air_time = 0.0
		air_spin = 0.0


func _touch_water() -> void:
	var current := velocity.length()
	if current < SKIM_SPEED:
		velocity *= 0.2
		on_ground = true
		sank.emit()
		return
	velocity *= 0.93
	velocity.y = 2.4 + current * 0.035
	on_ground = false
	_air_since = 1.0
	_ground_time = 0.0
	air_time = 0.0
	air_spin = 0.0
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
	velocity.y = maxf(velocity.y, 0.0) + upward
	on_ground = false
	_air_since = 1.0
	_ground_time = 0.0
	air_time = 0.0
	air_spin = 0.0
	_puff.restart()


func crash() -> void:
	if crashed:
		return
	var impact_velocity := travel_velocity()
	crashed = true
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
	_rider.rotate_x(_rider_spin.x * dt)
	_rider.rotate_y(_rider_spin.y * dt)
	_rider.rotate_z(_rider_spin.z * dt)
	velocity.y -= GRAVITY * dt
	position += velocity * dt
	yaw += 4.0 * dt
	var ground := field.height_world(position.x, position.z)
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
	var target_up := field.normal_world(position.x, position.z) if on_ground or crashed else Vector3.UP
	_up = _up.lerp(target_up, 1.0 - exp(-14.0 * delta)).normalized()
	var ahead := forward()
	ahead = (ahead - _up * ahead.dot(_up)).normalized()
	var right := ahead.cross(_up)
	basis = Basis(right, _up, -ahead)
	_body.rotation.z = -steer_visual * 0.22
	_body.rotation.x = 0.0 if on_ground else clampf(velocity.y * 0.02, -0.3, 0.3)
	# The ride's pose is rebuilt from scratch every frame so nothing a
	# previous ride left behind can turn it. Only the saucer spins; its rider
	# keeps facing downhill.
	var spinning := spec != null and spec.visual_spin > 0.0
	_visual_spin = wrapf(_visual_spin + spec.visual_spin * delta, 0.0, TAU) if spinning else 0.0
	_vehicle_mesh.transform = Transform3D(Basis(Vector3.UP, _visual_spin), Vector3.ZERO)
	if not crashed and _rider:
		_rider.rotation.z = -steer_visual * 0.25
		_rider.rotation.x = 0.0
		_rider.rotation.y = sin(_visual_spin * 0.5) * 0.12 if spinning else 0.0
	_body.visible = invulnerable_time <= 0.0 or fmod(invulnerable_time, 0.2) < 0.12


func _update_particles() -> void:
	var current := speed()
	_spray.emitting = on_ground and not crashed and current > 6.0
	_spray.amount_ratio = clampf(current / 40.0 + absf(steer_visual) * 0.4, 0.15, 1.0)
	var process := _spray.process_material as ParticleProcessMaterial
	process.direction = (-velocity.normalized() + Vector3.UP * 0.8).normalized() * global_basis
	process.initial_velocity_min = current * 0.05
	process.initial_velocity_max = current * 0.15


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
