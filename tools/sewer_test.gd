extends SceneTree
## Circular driving surface, fair passages, all rides, rats and streamed
## geometry. Native --capture saves real entrance/gameplay/rat review images.
var failures := 0

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var world := SlopeWorld.new()
	root.add_child(world)
	for seed_value in [7, 1234, 4711]:
		var field := TerrainField.new(seed_value)
		var span := _find(field)
		_check("seed %d includes a sewer" % seed_value, span != Vector3.ZERO)
		var middle := span.x + 155
		var cx := field.center_x(middle)
		_check("a round 16 m pipe with a banked bottom", absf(field.sewer_ceiling(cx, middle) - field.height(cx, middle) - 16) < 0.01 and field.height(cx + 5, middle) - field.height(cx, middle) > 1.7)
		_check("wet channel is slippery, shoulders have more grip", field.grip_factor(cx, middle) < 0.6 and field.grip_factor(cx + 4, middle) > 1)
		var smooth := true
		for d in [span.x, span.x + 30, span.y - 30, span.y]:
			smooth = smooth and absf(field.height(field.center_x(d - 0.01), d - 0.01) - field.height(field.center_x(d + 0.01), d + 0.01)) < 0.05
		_check("entry and exit join the slope continuously", smooth)
		world.reset(field, span.x + 120)
		for i in range(floori(span.x / 50), ceili(span.y / 50)): world._ensure(i)
		var pending := world.regions._region_jobs.size()
		world.regions.prepare_floors(Time.get_ticks_usec())
		_check("pipe preparation respects the frame deadline", pending > 0 and pending == world.regions._region_jobs.size())
		var passes := 0
		while not world.regions._region_jobs.is_empty() and passes < 1500:
			world.regions.prepare_floors(Time.get_ticks_usec() + 800)
			passes += 1
		_check("pipe and stream build in small slices", world.regions._region_jobs.is_empty() and passes > 1)
		var obstacles: Array[Obstacle] = []
		var rats: Array[SewerRat] = []
		for chunk: Chunk in world._chunks.values():
			for obstacle in chunk.obstacles:
				if obstacle.kind == Obstacle.Kind.SEWER_DEBRIS: obstacles.append(obstacle)
			rats.append_array(chunk.rats)
		_check("five barriers and scurrying rats are streamed", obstacles.size() == 5 and rats.size() >= 12)
		var route_clear := true
		for obstacle in obstacles:
			var d := -obstacle.position.z
			var x := field.center_x(d) + field.sewer_guide(d)
			route_clear = route_clear and not obstacle.overlaps(Vector3(x, field.height(x, d) + 0.3, -d), Sled.RADIUS)
		_check("every barrier has a real open passage", route_clear)
		for spec in VehicleSpec.all():
			_check("%s can navigate the whole sewer" % spec.title, _cross(field, span, spec, obstacles))
			_check("%s can steer back from either wall" % spec.title, _scrape(field, span, spec))
		var rat := rats[rats.size() / 2]
		var old := rat.position
		var stayed_clear := true
		for frame in 240:
			rat.tick(1.0 / 60, PackedVector3Array([old + Vector3(30, 0, 0)]))
			stayed_clear = stayed_clear and SewerRat.clear_at(field, rat.position) and absf(rat.position.y - field.sewer_floor(rat.position.x, -rat.position.z) - 0.02) < 0.005
		_check("rat runs on the floor without crossing a barrier", stayed_clear and old.distance_to(rat.position) > 0.2)
		var threat := rat.position + Vector3(1, 0, 0)
		for frame in 20: rat.tick(1.0 / 60, PackedVector3Array([old + Vector3(50, 0, 0), threat]))
		_check("rats flee either split-screen rider", rat.frightened)
	world.queue_free()
	await process_frame
	await process_frame
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_process(false)
	main.set("_autopilot", true)
	main.set("_vehicle", 0)
	main.set("_start_region", "sewer")
	main.get("_rng").seed = 4711
	main.call("_start_run")
	main.set("state", 2)
	main.get("_director").stop()
	var field: TerrainField = main.get("_field")
	var span := _find(field)
	var live: SlopeWorld = main.get("_world")
	live.reset(field, span.x + 120)
	for i in range(floori(span.x / 50), ceili(span.y / 50)): live._ensure(i)
	live.regions.prepare_floors(Time.get_ticks_usec() + 1000000)
	var sled: Sled = main.get("_sled")
	main.get("_players")[0].lives = 10
	sled.place_at(span.x + 100, 7.6, 25)
	sled.velocity = Vector3(18, 0, -20)
	sled.frozen = false
	sled.step(0.1, 1, 0, false)
	main.call("_check_bounds")
	_check("scraping the pipe costs no life", not sled.crashed and main.get("_players")[0].lives == 10)
	var barrier: Obstacle
	for obstacle in live.obstacles_near(span.x + 78):
		if obstacle.kind == Obstacle.Kind.SEWER_DEBRIS and absf(-obstacle.position.z - span.x - 78) < 1: barrier = obstacle
	sled.place_at(-barrier.position.z - 0.1, -3, 25)
	sled.invulnerable_time = 0
	main.call("_check_collisions")
	_check("the rusty grate stops a rider", sled.crashed)
	main.call("_after_crash", main.get("_players")[0])
	_check("recovery returns to a safe passage", not sled.crashed and absf(sled.position.x - field.center_x(sled.distance()) - field.sewer_guide(sled.distance())) < 0.01)
	var atmo: Atmosphere = main.get("_atmosphere")
	atmo.indoor = true
	atmo.sewer = 1
	atmo.update_atmosphere(0, main.get("_camera"), 0, 0, false)
	_check("indoor lighting and no falling snow", not atmo._snow.visible and atmo._environment.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR)
	_check("subdued sewer light without sky reflections", atmo._environment.ambient_light_energy < 0.35 and atmo._sun.light_energy < atmo._day_sun_energy * 0.1 and atmo._environment.reflected_light_source == Environment.REFLECTION_SOURCE_DISABLED)
	atmo.indoor = false
	atmo.sewer = 0
	atmo.update_atmosphere(0, main.get("_camera"), 0, 0, false)
	_check("daylight returns outside", atmo._snow.visible and atmo._environment.ambient_light_source == Environment.AMBIENT_SOURCE_SKY)
	_check("sunlight is restored on exit", is_equal_approx(atmo._sun.light_energy, atmo._day_sun_energy))
	if OS.get_cmdline_user_args().has("--capture"): await _capture(main, span)
	main.queue_free()
	await process_frame
	await process_frame
	print("sewer test: %s" % ("all passed" if failures == 0 else "%d failed" % failures))
	quit(failures)

func _cross(field: TerrainField, span: Vector3, spec: VehicleSpec, obstacles: Array[Obstacle]) -> bool:
	var sled := Sled.new()
	root.add_child(sled)
	sled.field = field
	sled.set_vehicle(spec, RandomNumberGenerator.new())
	sled.place_at(span.x + 1, 0, 20)
	var n := field.normal_world(sled.position.x, sled.position.z)
	sled.velocity = (sled.forward() - n * sled.forward().dot(n)).normalized() * 20
	sled.frozen = false
	var safe := true
	for frame in 2200:
		var d := sled.distance()
		if d >= span.y - 2: break
		var steer := SewerPipe.autopilot(sled)
		sled.step(1.0 / 60, steer, 1.0, false)
		for obstacle in obstacles:
			if obstacle.overlaps(sled.position + Vector3.UP * 0.3, Sled.RADIUS): safe = false
		if field.in_sewer(sled.distance()):
			var radial := Vector2(sled.position.x - field.center_x(sled.distance()), sled.position.y - field.sewer_height(sled.distance()) - TerrainField.SEWER_RADIUS)
			if radial.length() > TerrainField.SEWER_RADIUS + 0.02: safe = false
		if not safe: break
	var passed := safe and sled.distance() >= span.y - 2
	if not passed: print("    stopped at offset=%.1f x=%.2f speed=%.1f" % [sled.distance() - span.x, sled.position.x - field.center_x(sled.distance()), sled.speed()])
	sled.free()
	return passed


func _scrape(field: TerrainField, span: Vector3, spec: VehicleSpec) -> bool:
	var sled := Sled.new()
	root.add_child(sled)
	sled.field = field
	sled.set_vehicle(spec, RandomNumberGenerator.new())
	var safe := true
	for side in [-1.0, 1.0]:
		var max_radius := 0.0
		var nearest_center := INF
		sled.place_at(span.x + 98, side * 7.6, 20)
		sled.velocity = Vector3(side * 24, 3, -20)
		sled.frozen = false
		for frame in 240:
			var steer: float = -side * 0.7 if frame >= 30 and nearest_center > 4 else 0.0
			sled.step(1.0 / 60, steer, 0, false)
			var d := sled.distance()
			var radial := Vector2(sled.position.x - field.center_x(d), sled.position.y - field.sewer_height(d) - TerrainField.SEWER_RADIUS)
			max_radius = maxf(max_radius, radial.length())
			nearest_center = minf(nearest_center, absf(radial.x))
			safe = safe and radial.length() < TerrainField.SEWER_RADIUS + 0.02 and not sled.crashed
		safe = safe and nearest_center < 4 and -sled.velocity.z > 2
		if not safe: print("    wall side=%d radius=%.3f offset=%.2f speed=%.2f" % [side, max_radius, sled.position.x - field.center_x(sled.distance()), -sled.velocity.z])
	# A jump into the roof also produces contact rather than an escape/crash.
	sled.place_at(span.x + 98, 0, 20)
	sled.position.y = field.sewer_ceiling(sled.position.x, sled.distance()) - 0.8
	sled.velocity = Vector3(0, 12, -20)
	sled.on_ground = false
	sled.step(0.1, 0, 0, false)
	safe = safe and not sled.crashed and not sled.on_ground and sled.velocity.dot(sled.sewer_frame().y) >= 0 and sled.position.y <= field.sewer_ceiling(sled.position.x, sled.distance()) + 0.01
	sled.free()
	return safe

func _capture(main: Node, span: Vector3) -> void:
	var field: TerrainField = main.get("_field")
	var camera: ChaseCamera = main.get("_camera")
	var sled: Sled = main.get("_sled")
	var atmo: Atmosphere = main.get("_atmosphere")
	main.get("_hud").show_screen("game")
	main.get("_hud")._popups.visible = false
	atmo._flash = 0
	atmo.cave = 0
	atmo.sewer = 1
	atmo.storm = 0
	atmo.indoor = true
	sled._spray.visible = false
	sled._puff.visible = false
	sled.invulnerable_time = 0
	sled.place_at(span.x + 17, 0, 0)
	camera.mode = ChaseCamera.Mode.CHASE
	camera.snap()
	atmo.sewer = 0
	atmo.indoor = false
	atmo.update_atmosphere(0, camera, 0, 0, false)
	await _shot("approach")
	atmo.sewer = 1
	atmo.indoor = true
	sled.place_at(span.x + 54, 1.8, 0)
	camera.mode = ChaseCamera.Mode.CHASE
	camera.snap()
	atmo.update_atmosphere(0, camera, 0, 0, false)
	await _shot("ride")
	# Reach the roof with actual steering, then capture its real chase pose.
	sled.place_at(span.x + 42, 0, 48)
	sled.velocity = -sled.sewer_frame().z * 48
	camera.snap()
	for i in 360:
		sled.step(1.0 / 60, 1, 1, false)
		camera.update_camera(1.0 / 60)
		if sled.on_ground and sled.basis.y.y < -0.8:
			_check("ceiling rider stays visible to the chase camera", camera.is_position_in_frustum(sled.position + sled.basis.y * 0.8))
			main.get("_hud").update_game(sled.distance() - span.x, 0, sled.speed(), 3, 3, 1)
			await _shot("ceiling")
			break
	main.get("_hud").show_screen("")
	var d := span.x + TerrainField.SEWER_INSET
	var target := Vector3(field.center_x(d), field.sewer_height(d) + 5, -d)
	camera.position = target + Vector3(-12, 22, 28)
	camera.look_at(target)
	camera.fov = 58
	atmo.sewer = 0
	atmo.indoor = false
	atmo.update_atmosphere(0, camera, 0, 0, false)
	await _shot("entrance")
	d = span.x + 110
	var at := Vector3(field.center_x(d) + 3.7, field.sewer_floor(field.center_x(d) + 3.7, d), -d)
	var rat := SewerRat.new().configure(field, at + Vector3.UP * 0.02, 86, [])
	main.get("_world").add_child(rat)
	rat.rotation.y = -0.65
	camera.position = at + Vector3(1.6, 0.9, 1.7)
	camera.position.y = maxf(camera.position.y, field.height_world(camera.position.x, camera.position.z) + 0.65)
	camera.look_at(at + Vector3.UP * 0.15)
	camera.fov = 45
	atmo.sewer = 1
	atmo.indoor = true
	atmo.update_atmosphere(0, camera, 0, 0, false)
	await _shot("rat")

func _shot(name: String) -> void:
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/pulka-sewer-%s.png" % name)

func _find(field: TerrainField) -> Vector3:
	for cell in 256:
		var span := field._slot(cell)
		if int(span.z) == TerrainField.Region.SEWER: return span
	return Vector3.ZERO

func _check(message: String, condition: bool) -> void:
	print(("  ok    " if condition else "  FAIL  ") + message)
	if not condition: failures += 1
