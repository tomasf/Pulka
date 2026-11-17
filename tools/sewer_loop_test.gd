extends SceneTree
## Real controls, all rides, both directions; roof grip depends on speed.
var failures := 0

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	for seed_value in [7, 1234, 4711]: _cases(seed_value)
	print("sewer loop test: %s" % ("all passed" if failures == 0 else "%d failed" % failures))
	quit(failures)

func _cases(seed_value: int) -> void:
	print("loop seed ", seed_value)
	var field := TerrainField.new(seed_value)
	var span := Vector3.ZERO
	for cell in 256:
		var candidate := field._slot(cell)
		if int(candidate.z) == TerrainField.Region.SEWER:
			span = candidate
			break
	for spec in VehicleSpec.all():
		for side in [-1.0, 1.0]:
			var sled := _sled(field, spec, span.x + 42, 48)
			var camera := ChaseCamera.new()
			root.add_child(camera)
			camera.field = field
			camera.target = sled
			camera.mode = ChaseCamera.Mode.CHASE
			camera.snap()
			var previous := 0.0
			var swept := 0.0
			var roof := false
			var inverted := false
			var contained := true
			var visible_rider := true
			var level_horizon := true
			for i in 420:
				sled.step(1.0 / 60, side, 1, false)
				camera.update_camera(1.0 / 60)
				level_horizon = level_horizon and absf(camera.basis.x.dot(Vector3.UP)) < 0.001
				visible_rider = visible_rider and camera.is_position_in_frustum(sled.position + sled.basis.y * 0.8) and camera.basis.is_finite()
				if not field.in_sewer(sled.distance()): break
				var radial := Vector2(sled.position.x - field.center_x(sled.distance()), sled.position.y - field.sewer_height(sled.distance()) - TerrainField.SEWER_RADIUS)
				var angle := atan2(radial.x, -radial.y)
				swept += wrapf(angle - previous, -PI, PI) * side
				previous = angle
				contained = contained and radial.length() <= TerrainField.SEWER_RADIUS + 0.025
				if radial.y > 6 and sled.on_ground:
					roof = true
					inverted = inverted or sled.basis.y.y < -0.5
				if swept > TAU: break
			var passed := swept > TAU and roof and inverted and contained and not sled.crashed
			_check("%s circles %s with normal steering" % [spec.title, "left" if side < 0 else "right"], passed)
			_check("chase camera follows the whole loop", visible_rider)
			_check("camera horizon stays level through the whole loop", level_horizon)
			if not passed: print("    swept=%.2f roof=%s inverted=%s contained=%s speed=%.1f d=%.1f" % [swept, roof, inverted, contained, sled.speed(), sled.distance() - span.x])
			sled.free()
			camera.free()
	var ideal := VehicleSpec.all()[0]
	ideal.drag = 0
	ideal.friction = 0
	ideal.scrub = 0
	ideal.grip = 0
	ideal.self_align = 0
	var coast := _sled(field, ideal, span.x + 42, 0)
	var coast_frame := coast.sewer_frame()
	coast.velocity = coast_frame.x * 32 - coast_frame.z * 28
	coast.sewer_active = true
	coast._sewer_heading = atan2(32, 28)
	var initial_energy := coast.velocity.length_squared() * 0.5
	var initial_height := coast.position.y
	for i in 120: coast.step(1.0 / 60, 0, 0, false)
	var energy := coast.velocity.length_squared() * 0.5 + Sled.GRAVITY * (coast.position.y - initial_height)
	_check("curving around the wall preserves energy without drag", absf(energy - initial_energy) / initial_energy < 0.02)
	coast.free()
	# Axial speed alone cannot stick you to the roof: only speed around it
	# supplies the required centripetal acceleration.
	for circum_speed in [0.0, 6.0, 18.0]:
		var sled := _sled(field, VehicleSpec.all()[0], span.x + 100, 0)
		sled.position.y = field.sewer_ceiling(sled.position.x, sled.distance())
		var frame := sled.sewer_frame()
		sled.velocity = -frame.z * 40 + frame.x * circum_speed
		sled.sewer_active = true
		sled._sewer_heading = atan2(circum_speed, 40)
		sled.step(1.0 / 60, 0, 0, false)
		_check("roof contact at %.0f m/s around the pipe" % circum_speed, sled.on_ground == (circum_speed > 11))
		if circum_speed < 11:
			for i in 60: sled.step(1.0 / 60, 0, 0, false)
			_check("slow roof ride falls inward", sled.position.y < field.sewer_height(sled.distance()) + 14 and not sled.crashed)
		else:
			sled._ground_time = 1
			sled.step(1.0 / 60, 0, 0, true)
			_check("jumping releases roof contact", not sled.on_ground and sled.velocity.dot(sled.sewer_frame().y) > 1)
		sled.free()
	var exit_ride := _sled(field, VehicleSpec.all()[0], span.y - TerrainField.SEWER_INSET - 3, 0)
	exit_ride.position.y = field.sewer_ceiling(exit_ride.position.x, exit_ride.distance())
	var exit_frame := exit_ride.sewer_frame()
	exit_ride.velocity = exit_frame.x * 15 - exit_frame.z * 40
	exit_ride.sewer_active = true
	exit_ride._sewer_heading = atan2(15, 40)
	exit_ride._sewer_forward = exit_ride.velocity.normalized()
	exit_ride._sewer_up = exit_frame.y
	exit_ride._up = exit_frame.y
	exit_ride._update_visual(1)
	var exit_camera := ChaseCamera.new()
	root.add_child(exit_camera)
	exit_camera.field = field
	exit_camera.target = exit_ride
	exit_camera.mode = ChaseCamera.Mode.CHASE
	exit_camera.snap()
	var stable_exit := true
	var biggest_turn := 0.0
	var biggest_distance := 0.0
	var touched_snow := false
	for i in 180:
		var old_rotation := exit_camera.basis.get_rotation_quaternion()
		exit_ride.step(1.0 / 60, 0, 0, false)
		exit_camera.update_camera(1.0 / 60)
		touched_snow = touched_snow or (not exit_ride.sewer_active and exit_ride.on_ground)
		var turn := old_rotation.angle_to(exit_camera.basis.get_rotation_quaternion())
		biggest_turn = maxf(biggest_turn, turn)
		biggest_distance = maxf(biggest_distance, exit_camera.position.distance_to(exit_ride.position))
		stable_exit = stable_exit and exit_camera.basis.is_finite() and turn < 0.6 and exit_camera.position.distance_to(exit_ride.position) < 10
	_check("inverted exit returns smoothly to outdoor physics and camera", stable_exit and not exit_ride.sewer_active and touched_snow)
	if not stable_exit or exit_ride.sewer_active or not touched_snow:
		print("    exit turn=%.3f distance=%.2f active=%s grounded=%s gap=%.2f" % [biggest_turn, biggest_distance, exit_ride.sewer_active, exit_ride.on_ground, exit_ride.position.y - field.height(exit_ride.position.x, exit_ride.distance())])
	exit_ride.free()
	exit_camera.free()

func _sled(field: TerrainField, spec: VehicleSpec, d: float, speed: float) -> Sled:
	var sled := Sled.new()
	root.add_child(sled)
	sled.field = field
	sled.set_vehicle(spec, RandomNumberGenerator.new())
	sled.place_at(d, 0, speed)
	var frame := sled.sewer_frame()
	sled.velocity = -frame.z * speed
	sled.frozen = false
	return sled

func _check(message: String, condition: bool) -> void:
	print(("  ok    " if condition else "  FAIL  ") + message)
	if not condition: failures += 1
