extends SceneTree
## Mixed-speed queues, bumper clearance through loop seams and long frames,
## both real road types, and collision velocities after slowing down.
var failures := 0

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var flow := TrafficLane.new(200)
	flow.add(100, 30, 2.25)
	flow.add(180, 8, 5)
	flow.add(80, 20, 8)
	var clear := true
	var gentle := true
	for frame in 10800:
		var previous := flow.speeds[0]
		flow.step(1.0 / 60)
		clear = clear and _clear(flow)
		gentle = gentle and absf(flow.speeds[0] - previous) <= TrafficLane.BRAKING / 60 + 0.001
	_check("faster cars queue behind a slower plow for three minutes", clear and flow.speeds[0] < 8.1 and flow.cruise[0] == 30)
	_check("cars slow down gradually", gentle)
	for frame in 100:
		flow.step(1.3)
		clear = clear and _clear(flow)
	_check("long frames and repeated wraps keep bumper clearance", clear)
	flow.cruise[1] = 30
	for frame in 600: flow.step(1.0 / 60)
	_check("cars accelerate again when the queue moves", flow.speeds[0] > 10)
	flow.step(0)
	_check("zero-time updates stay finite", is_finite(flow.speeds[0]) and _clear(flow))
	var world := SlopeWorld.new()
	root.add_child(world)
	world.field = TerrainField.new(4711)
	for seed_value in [7, 1234, 4711]:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var road := RoadCrossing.new().setup(world.field, 8500, rng, null)
		world.add_child(road)
		var road_clear := true
		var velocities := true
		for frame in 7200:
			var before := PackedFloat64Array()
			for car in road.cars: before.append(car.position.x)
			road.tick(1.0 / 30)
			for lane in road._flows: road_clear = road_clear and _clear(lane)
			for i in road.cars.size():
				var dx := road.cars[i].position.x - before[i]
				if absf(dx) < 100:
					velocities = velocities and absf(dx * 30 - road.cars[i].velocity.x) < 0.04
		_check("crossing seed %d keeps both lanes separated through wraps" % seed_value, road_clear)
		_check("crossing collision velocities match movement", velocities)
		road.free()
		world.field = TerrainField.new(seed_value)
		var span := Vector3.ZERO
		for cell in 256:
			var candidate := world.field._slot(cell)
			if int(candidate.z) == TerrainField.Region.HIGHWAY:
				span = candidate
				break
		var motorway := MotorwayTraffic.new().setup(world, span)
		world.add_child(motorway)
		var motorway_clear := true
		var directions := true
		for frame in 1800:
			motorway.tick(0.1 if frame % 120 else 0.8, -1000)
			for lane in motorway._flows: motorway_clear = motorway_clear and _clear(lane)
			for i in motorway.obstacles.size():
				var direction: float = RegionBuilder.MOTORWAY_LANES[motorway._lanes[i]][1]
				directions = directions and motorway.obstacles[i].velocity.z * direction < 0
		_check("motorway seed %d keeps cars and trucks separated" % seed_value, motorway_clear)
		_check("motorway collision velocities follow the correct direction", directions)
		motorway.free()
	world.queue_free()
	await process_frame
	await process_frame
	print("traffic test: %s" % ("all passed" if failures == 0 else "%d failed" % failures))
	quit(failures)

func _clear(flow: TrafficLane) -> bool:
	for i in flow.positions.size():
		var leader := flow._leaders[i]
		if leader == i: continue
		var gap := fposmod(flow.positions[leader] - flow.positions[i], flow.length) - flow.half_lengths[i] - flow.half_lengths[leader]
		if gap < TrafficLane.CLEARANCE - 0.002 or not is_finite(gap): return false
	return true

func _check(message: String, condition: bool) -> void:
	print(("  ok    " if condition else "  FAIL  ") + message)
	if not condition: failures += 1
