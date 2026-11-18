extends SceneTree
## Real roof gaps, landing surfaces, all rides, chimney hits and recovery.
## Native --capture saves gameplay, an aerial view and a jump to /tmp.
var failures := 0

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	for seed_value in [7, 1234, 4711]:
		var field := TerrainField.new(seed_value)
		var span := _find(field)
		var tiles := field.roofs(span.x + 1)
		_check("seed %d has three roof rows" % seed_value, tiles.size() >= 15 and tiles[0].lane == -1 and tiles.back().lane == 1)
		var gaps := 0
		var alternate := true
		var roofs_match := true
		var wide := 0
		var narrow := 0
		var challenge: TerrainField.Roof
		for roof in tiles:
			var d := (roof.start + roof.finish) * 0.5
			var x := roof.center(d)
			roofs_match = roofs_match and absf(field.height(x, d) - field.roof_height(roof, x, d)) < 0.01
			if roof.lane == 0 and roof.finish < roof.district.y - 0.1:
				if roof.requires_jump:
					wide += 1
					if challenge == null: challenge = roof
				else: narrow += 1
				d = roof.finish + roof.gap_after * 0.5
				x = field.center_x(d)
				gaps += 1
				_check("gap exposes the street below", field.roof_at(x, d) == null and field.height(x, d) < field.roof_base_height(d) - 10)
				alternate = alternate and (field.roof_at(x - TerrainField.ROOF_LANE, d) != null or field.roof_at(x + TerrainField.ROOF_LANE, d) != null)
		_check("roof snow and physics use the same height", roofs_match)
		_check("staggered rows offer another roof at each centre gap", alternate and gaps >= 4)
		_check("centre route mixes small gaps and multiple wide streets", wide >= 2 and narrow >= 2)
		_check("wide gaps have no automatic launch ramp", challenge != null and challenge.kick_height == 0 and challenge.gap_after >= 14 and challenge.gap_after <= 16)
		var duplicate := TerrainField.new(seed_value).roofs(span.x + 1)
		_check("layout is deterministic", tiles[4].start == duplicate[4].start and tiles[4].cx == duplicate[4].cx and tiles[4].variant == duplicate[4].variant)
		for spec in VehicleSpec.all():
			var result := _cross(field, span, spec)
			_check("%s crosses with real airborne landings (%d)" % [spec.title, result.y], result.x > 0 and result.y >= 3)
			var active := true
			var passive := false
			for speed in [28.0, 40.0]:
				active = _gap_probe(field, challenge, spec, speed, true) and active
				passive = _gap_probe(field, challenge, spec, speed, false) or passive
			_check("%s clears the wide street with a jump" % spec.title, active)
			_check("%s cannot simply slide across the wide street" % spec.title, not passive)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_process(false)
	main.set("_autopilot", true)
	main.set("_vehicle", 0)
	main.set("_start_region", "roofs")
	main.get("_rng").seed = 4711
	main.call("_start_run")
	main.set("state", 2)
	var field: TerrainField = main.get("_field")
	var span := field.region_span(main.call("_find_region", "roofs") + 1)
	var center_roofs: Array[TerrainField.Roof] = []
	for roof in field.roofs(span.x + 1):
		if roof.lane == 0: center_roofs.append(roof)
	var tile := center_roofs[1]
	var d := (tile.start + tile.finish) * 0.5
	var sled: Sled = main.get("_sled")
	sled.frozen = false
	var world: SlopeWorld = main.get("_world")
	world.reset(field, d)
	for i in range(floori(span.x / 50), ceili(span.y / 50)): world._ensure(i)
	var pending := world.regions._roof_jobs.size()
	world.regions.prepare_floors(Time.get_ticks_usec())
	_check("roof preparation respects the frame deadline", pending > 0 and world.regions._roof_jobs.size() == pending and world.regions._roof_jobs[0].stage == 0)
	var passes := 0
	while not world.regions._roof_jobs.is_empty() and passes < 500:
		world.regions.prepare_floors(Time.get_ticks_usec() + 800)
		passes += 1
	_check("buildings prepare over several small slices", world.regions._roof_jobs.is_empty() and passes > 1)
	var removed := MeshInstance3D.new()
	var cancelled := Roofscape.BuildJob.new(field, tile)
	cancelled.target = weakref(removed)
	world.regions._roof_jobs.append(cancelled)
	removed.free()
	world.regions.prepare_floors(Time.get_ticks_usec() + 100000)
	_check("removed chunks cancel pending roof work", world.regions._roof_jobs.is_empty() and cancelled.stage == 0)
	var buildings := 0
	var chimneys: Array[Obstacle] = []
	for chunk: Chunk in world._chunks.values():
		for child in chunk.get_children():
			if child.name.begins_with("RideableRoof"): buildings += 1
		for obstacle in chunk.obstacles:
			if obstacle.kind == Obstacle.Kind.CHIMNEY: chimneys.append(obstacle)
	_check("buildings and chimney colliders stream with chunks", buildings >= 15 and buildings == chimneys.size())
	var mesh := Roofscape.house(field, tile)
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var top_count := (ceili((tile.finish - tile.start) / 1.25) + 1) * 7
	var exact := true
	for p in vertices.slice(0, top_count):
		exact = exact and absf(p.y - field.roof_height(tile, p.x, -p.z)) < 0.015
	_check("rendered snow matches the landing surface", exact)
	if OS.get_cmdline_user_args().has("--capture"): await _capture(main, tile)
	var gap := tile.finish + tile.gap_after * 0.5
	sled.place_at(gap, 0, 12)
	sled.position.y = field.roof_base_height(gap) - 3
	sled.on_ground = false
	main.call("_check_bounds")
	_check("missing a roof costs a life", sled.crashed)
	main.call("_after_crash", main.get("_players")[0])
	_check("recovery chooses a roof, never the gap", not sled.crashed and field.roof_at(sled.position.x, sled.distance()) != null and not field.below_structure(sled.position))
	sled.position.y -= 3
	sled.on_ground = false
	var below := sled.position.y
	for i in 5: sled.step(1.0 / 60, 0, false)
	_check("falling under a roof does not teleport onto it", sled.position.y < below + 0.1)
	var chimney: Obstacle
	for chunk: Chunk in world._chunks.values():
		for obstacle in chunk.obstacles:
			if obstacle.kind == Obstacle.Kind.CHIMNEY: chimney = obstacle
	sled.place_at(-chimney.position.z, chimney.position.x - field.center_x(-chimney.position.z), 24)
	sled.invulnerable_time = 0
	main.call("_check_collisions")
	_check("a chimney is a solid obstacle", sled.crashed and is_inf(chimney.mass) and not chimney.hit)
	main.queue_free()
	await process_frame
	await process_frame
	print("roofs test: %s" % ("all passed" if failures == 0 else "%d failed" % failures))
	quit(failures)

func _cross(field: TerrainField, span: Vector3, spec: VehicleSpec) -> Vector2i:
	var sled := Sled.new()
	root.add_child(sled)
	sled.field = field
	sled.set_vehicle(spec, RandomNumberGenerator.new())
	sled.place_at(span.x + 5, 0, 18)
	sled.frozen = false
	var airborne := 0
	var landings := 0
	var good := true
	for frame in 2200:
		var d := sled.distance()
		if d >= span.y - 2: break
		var slope := field.center_slope(d)
		var offset := sled.position.x - field.center_x(d)
		var drift := sled.velocity.x + sled.velocity.z * slope
		var desired := atan2(slope, 1) - clampf(offset * 0.25 + drift * 0.4, -0.7, 0.7)
		var steer := clampf(wrapf(desired - sled.yaw, -PI, PI) * 3, -1, 1)
		var roof := field.roof_at(sled.position.x, d)
		var jump := roof != null and roof.requires_jump and roof.finish - d < 1.25 and sled.on_ground
		sled.step(1.0 / 60, steer, jump)
		if not sled.on_ground: airborne += 1
		elif airborne > 0:
			if airborne > 8: landings += 1
			airborne = 0
		if field.in_rooftops(sled.distance()) and (field.below_structure(sled.position) or sled.position.y < field.roof_base_height(sled.distance()) - 2):
			good = false
			break
	var finished := good and sled.distance() >= span.y - 2
	sled.free()
	return Vector2i(int(finished), landings)

func _capture(main: Node, roof: TerrainField.Roof) -> void:
	var field: TerrainField = main.get("_field")
	var sled: Sled = main.get("_sled")
	var camera: ChaseCamera = main.get("_camera")
	main.get("_director").stop()
	main.set("_no_crash", true)
	sled.place_at(roof.start + 15, 0, 22)
	_ground_velocity(sled, 22)
	camera.mode = ChaseCamera.Mode.CHASE
	camera.snap()
	main.get("_hud").show_screen("game")
	for i in 10:
		main.call("_process", 1.0 / 60)
		await process_frame
	await _shot(main, camera, "ride")
	sled.place_at(roof.finish - 5, 0, 24)
	_ground_velocity(sled, 24)
	camera.snap()
	var frames := 0
	while sled.distance() < roof.finish + roof.gap_after * 0.45 and frames < 100:
		main.call("_process", 1.0 / 60)
		frames += 1
		await process_frame
	await _shot(main, camera, "jump")
	main.get("_hud").show_screen("")
	var world: SlopeWorld = main.get("_world")
	for i in range(floori(roof.district.x / 50), ceili(roof.district.y / 50)): world._ensure(i)
	world.regions.prepare_floors(Time.get_ticks_usec() + 1000000)
	var d := (roof.district.x + roof.district.y) * 0.5
	var target := Vector3(field.center_x(d), field.roof_base_height(d), -d)
	camera.position = target + Vector3(-105, 85, 100)
	camera.look_at(target)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 185
	await _shot(main, camera, "overview")
	main.set("_no_crash", false)

func _gap_probe(field: TerrainField, roof: TerrainField.Roof, spec: VehicleSpec, speed: float, press_jump: bool) -> bool:
	var sled := Sled.new()
	root.add_child(sled)
	sled.field = field
	sled.set_vehicle(spec, RandomNumberGenerator.new())
	sled.place_at(roof.finish - 8, 0, speed)
	_ground_velocity(sled, speed)
	sled.frozen = false
	var cleared := false
	for frame in 300:
		var d := sled.distance()
		var slope := field.center_slope(d)
		var offset := sled.position.x - field.center_x(d)
		var drift := sled.velocity.x + sled.velocity.z * slope
		var desired := atan2(slope, 1) - clampf(offset * 0.25 + drift * 0.4, -0.7, 0.7)
		var steer := clampf(wrapf(desired - sled.yaw, -PI, PI) * 3, -1, 1)
		var jump := press_jump and d < roof.finish and roof.finish - d < 1.25 and sled.on_ground
		sled.step(1.0 / 60, steer, jump)
		if field.below_structure(sled.position) or sled.position.y < field.roof_base_height(sled.distance()) - 2: break
		if sled.distance() > roof.finish + roof.gap_after and sled.on_ground:
			cleared = true
			break
	sled.free()
	return cleared

func _ground_velocity(sled: Sled, speed: float) -> void:
	# Begin already sliding along the roof, with no airborne impulse caused
	# by teleporting horizontal velocity onto a steep downhill surface.
	var n := sled.field.normal_world(sled.position.x, sled.position.z)
	var along := sled.forward()
	sled.velocity = (along - n * along.dot(n)).normalized() * speed

func _shot(main: Node, camera: Camera3D, name: String) -> void:
	main.get("_atmosphere").update_atmosphere(0, camera, 0, 0, false)
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/pulka-roofs-%s.png" % name)

func _find(field: TerrainField) -> Vector3:
	for cell in 256:
		var span := field._slot(cell)
		if int(span.z) == TerrainField.Region.ROOFS: return span
	return Vector3.ZERO

func _check(message: String, condition: bool) -> void:
	print(("  ok    " if condition else "  FAIL  ") + message)
	if not condition: failures += 1
