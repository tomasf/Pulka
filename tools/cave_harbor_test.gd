extends SceneTree
## Real surfaces, all rides, solid ice/cargo, water recovery, shared crane
## motion and cold streaming. Native --capture writes review images to /tmp.
var failures := 0

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	for seed_value in [7, 1234, 4711]:
		var field := TerrainField.new(seed_value)
		for kind in [TerrainField.Region.ICE_CAVE, TerrainField.Region.HARBOR]:
			var span := _find(field, kind)
			_check("seed %d includes %s" % [seed_value, TerrainField.Region.keys()[kind]], span != Vector3.ZERO)
			for d in [span.x, span.x + 30, span.y - 30, span.y]:
				_check("continuous floor at %.1f" % d, absf(field.height(field.center_x(d - 0.01), d - 0.01) - field.height(field.center_x(d + 0.01), d + 0.01)) < 0.08)
			var d := span.x + 140
			if kind == TerrainField.Region.ICE_CAVE:
				_check("ice grip, high vault, portal fades", field.grip_factor(field.center_x(d), d) < 0.3 and field.cave_ceiling(field.center_x(d), d) - field.height(field.center_x(d), d) > 7.5 and field.cave_weight(span.x + 29) == 0 and field.cave_weight(d) == 1)
			else:
				d = span.x + 190
				var x := field.center_x(d) + field.harbor_gangway_x(d)
				_check("gangway is supported over real water", field.harbor_water(x, d) and field.height(x, d) - field.height(x, d, false, false) > 6 and field.surface_world(x + 1.65, -d).y > 0.9)
				_check("cargo lane has a real gap", field.harbor_route_lift(span.x + 109) < 0 and field.harbor_route_lift(span.x + 100) == 4)
			for spec in VehicleSpec.all():
				_check("%s crosses %s" % [spec.title, TerrainField.Region.keys()[kind]], _cross(field, span, spec, false))
				if kind == TerrainField.Region.HARBOR:
					_check("%s crosses container ramps and gap" % spec.title, _cross(field, span, spec, true))
					_check("%s crosses waterside gangway" % spec.title, _gangway(field, span, spec))
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_process(false)
	main.set("_autopilot", true)
	main.set("_vehicle", 0)
	main.get("_rng").seed = 4711
	main.call("_start_run")
	main.set("state", 2)
	main.get("_director").stop()
	var field: TerrainField = main.get("_field")
	var world: SlopeWorld = main.get("_world")
	var sled: Sled = main.get("_sled")
	var camera: ChaseCamera = main.get("_camera")
	for kind in [TerrainField.Region.ICE_CAVE, TerrainField.Region.HARBOR]:
		var span := _find(field, kind)
		main.get("_players")[0].lives = 10
		var middle := span.x + 130
		world.reset(field, span.x - 100)
		world.profile_builds = true
		world.build_profile.clear()
		for i in range(floori(span.x / 50), ceili(span.y / 50)): world._ensure(i)
		var pending := world.regions._region_jobs.size()
		world.regions.prepare_floors(Time.get_ticks_usec())
		_check("new region work respects the frame deadline", pending > 0 and world.regions._region_jobs.size() == pending)
		var passes := 0
		while not world.regions._region_jobs.is_empty() and passes < 2000:
			world.regions.prepare_floors(Time.get_ticks_usec() + 800)
			passes += 1
		_check("new region geometry prepares in small slices", world.regions._region_jobs.is_empty() and passes > 1)
		var matches := true
		var sampled := 0
		for chunk: Chunk in world._chunks.values():
			for child in chunk.get_children():
				if not child is MeshInstance3D or child.mesh == null or child.name not in ["HarborRoutes", "IceCavern"]: continue
				var arrays: Array = child.mesh.surface_get_arrays(0)
				var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				for i in points.size():
					var p := points[i]
					if kind == TerrainField.Region.ICE_CAVE and normals[i].y < -0.1:
						matches = matches and absf(p.y - field.cave_ceiling(p.x, -p.z)) < 0.025
						sampled += 1
					elif kind == TerrainField.Region.HARBOR and normals[i].y > 0.8 and absf(p.x - field.center_x(-p.z) + 7) < 2.65 and p.y > field.harbor_height(-p.z) + 0.1:
						if matches and absf(p.y - field.height(p.x, -p.z)) >= 0.025:
							print("    ramp mismatch at ", p, " offset=", -p.z - span.x, " expected=", field.height(p.x, -p.z))
						matches = matches and absf(p.y - field.height(p.x, -p.z)) < 0.025
						sampled += 1
		_check("rendered vault/ramps match physical surfaces", matches and sampled > 50)
		world.build_profile.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.us > b.us)
		for event in world.build_profile.slice(0, 3):
			print("  cold %s stage %d %.2f ms" % [TerrainField.Region.keys()[kind], event.stage, event.us / 1000.0])
		if kind == TerrainField.Region.ICE_CAVE:
			var pillar: Obstacle
			for chunk: Chunk in world._chunks.values():
				for obstacle in chunk.obstacles:
					if obstacle.kind == Obstacle.Kind.ICE_PILLAR: pillar = obstacle
			_check("solid columns reach the vault", pillar != null and pillar.top > 7 and pillar.overlaps(pillar.position + Vector3.UP * 3, 0.5) and not pillar.landable)
			sled.place_at(middle, field.cave_half_width(middle) - 0.3, 20)
			main.call("_check_bounds")
			_check("ice wall crashes", sled.crashed)
			main.call("_after_crash", main.get("_players")[0])
			var blocked := false
			for obstacle in world.obstacles_near(sled.distance()): blocked = blocked or obstacle.overlaps(sled.position + Vector3.UP * 0.3, Sled.RADIUS)
			_check("cave recovery avoids columns", not sled.crashed and not blocked)
			sled.place_at(middle, 0, 20)
			sled.position.y = field.cave_ceiling(sled.position.x, middle) - 0.5
			main.call("_check_bounds")
			_check("vault has real head clearance", sled.crashed)
			var atmo: Atmosphere = main.get("_atmosphere")
			atmo.indoor = true
			atmo.cave = 1
			atmo.update_atmosphere(0, camera, 0, 0, false)
			_check("no snowfall under the glacier", atmo._snow.amount_ratio == 0 and atmo._environment.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR)
			atmo.indoor = false
			atmo.cave = 0
			atmo.update_atmosphere(0, camera, 0, 0, false)
			_check("daylight and snow return on exit", atmo._snow.amount_ratio > 0 and atmo._environment.ambient_light_source == Environment.AMBIENT_SOURCE_SKY)
		else:
			sled.place_at(span.x + 190, 27, 20)
			main.call("_check_bounds")
			_check("falling off the quay crashes", sled.crashed)
			main.call("_after_crash", main.get("_players")[0])
			_check("water recovery returns to dry quay", not sled.crashed and not field.harbor_water(sled.position.x, sled.distance()))
			sled.place_at(span.x + 100, -7, 20)
			sled.position.y -= 2
			main.call("_check_bounds")
			_check("cargo sides cannot teleport you onto the roof", sled.crashed)
			var crane: HarborCrane
			for actor in world._free:
				if actor is HarborCrane: crane = actor
			var old := crane.obstacles[0].position
			crane.tick(0.5, middle)
			_check("crane load and collision move together", old.distance_to(crane.obstacles[0].position) > 0.05 and crane.obstacles[0].velocity.length() > 0.1 and not crane.finished(span.y - 1) and crane.finished(span.y + 81))
			var load_box := crane.obstacles[0]
			var head_probe := load_box.position - Vector3.UP * 0.5
			_check("hanging load detects the rider's head", main.call("_contact", load_box, head_probe) != Vector3.INF)
			_check("high cargo leaves clear space underneath", main.call("_contact", load_box, load_box.position - Vector3.UP * 1.1) == Vector3.INF)
		if OS.get_cmdline_user_args().has("--capture"):
			await _capture(main, span, kind)
	main.queue_free()
	await process_frame
	await process_frame
	print("cave/harbor test: %s" % ("all passed" if failures == 0 else "%d failed" % failures))
	quit(failures)

func _cross(field: TerrainField, span: Vector3, spec: VehicleSpec, raised: bool) -> bool:
	var sled := Sled.new()
	root.add_child(sled)
	sled.field = field
	sled.set_vehicle(spec, RandomNumberGenerator.new())
	var start := span.x + 52 if raised else span.x + 1
	var finish := span.x + 158 if raised else span.y - 1
	var lateral := -7.0 if raised else 0.0
	sled.place_at(start, lateral, 22)
	_ground_velocity(sled, 22)
	sled.frozen = false
	var safe := true
	var highest := 0.0
	for frame in 3000:
		var d := sled.distance()
		if d >= finish: break
		var slope := field.center_slope(d)
		var offset := sled.position.x - field.center_x(d) - lateral
		var drift := sled.velocity.x + sled.velocity.z * slope
		var desired := atan2(slope, 1) - clampf(offset * 0.25 + drift * 0.4, -0.7, 0.7)
		var steer := clampf(wrapf(desired - sled.yaw, -PI, PI) * 3, -1, 1)
		# Jump from the ramp lip: on steep quays its natural launch can land
		# inside the gap, so waiting until the gap itself is too late.
		var ramp_lip := span.x + 92
		var gap_start := span.x + 108
		var jump := raised and sled.on_ground and ((d < ramp_lip and ramp_lip - d < 1.25) or (d < gap_start and gap_start - d < 1.25))
		sled.step(1.0 / 60, steer, 1, jump)
		highest = maxf(highest, sled.position.y - field.harbor_height(sled.distance()))
		if field.below_structure(sled.position) or (field.in_cave(sled.distance()) and absf(offset) > 7):
			safe = false
			break
	var result := safe and sled.distance() >= finish and (not raised or highest > 3.8)
	if not result: print("    stopped d=%.1f goal=%.1f high=%.2f offset=%.2f" % [sled.distance(), finish, highest, sled.position.x - field.center_x(sled.distance()) - lateral])
	sled.free()
	return result

func _gangway(field: TerrainField, span: Vector3, spec: VehicleSpec) -> bool:
	var sled := Sled.new()
	root.add_child(sled)
	sled.field = field
	sled.set_vehicle(spec, RandomNumberGenerator.new())
	sled.place_at(span.x + 155, 16, 15)
	_ground_velocity(sled, 15)
	sled.frozen = false
	var safe := true
	var error := 0.0
	for frame in 1000:
		var d := sled.distance()
		if d >= span.x + 242: break
		var ahead := d + 10
		var target := field.center_x(ahead) + field.harbor_gangway_x(ahead)
		var desired := atan2(target - sled.position.x, 10)
		var steer := clampf(wrapf(desired - sled.yaw, -PI, PI) * 4, -1, 1)
		if spec.spins:
			steer = clampf(wrapf(desired - atan2(field.center_slope(d), 1), -PI, PI) / spec.steer + wrapf(desired - sled.yaw, -PI, PI) * 3, -1, 1)
		sled.step(1.0 / 60, steer, 0, false)
		var lateral := absf(sled.position.x - field.center_x(d) - field.harbor_gangway_x(d))
		error = maxf(error, lateral)
		if field.harbor_water(sled.position.x, sled.distance()) and sled.position.y < field.harbor_height(sled.distance()) - 0.6:
			safe = false
			break
	var passed := safe and sled.distance() >= span.x + 242
	if not passed: print("    gangway stopped offset=%.1f max error=%.2f" % [sled.distance() - span.x, error])
	sled.free()
	return passed

func _ground_velocity(sled: Sled, speed: float) -> void:
	var n := sled.field.normal_world(sled.position.x, sled.position.z)
	var along := sled.forward()
	sled.velocity = (along - n * along.dot(n)).normalized() * speed

func _capture(main: Node, span: Vector3, kind: int) -> void:
	var field: TerrainField = main.get("_field")
	var camera: ChaseCamera = main.get("_camera")
	var sled: Sled = main.get("_sled")
	var cave := kind == TerrainField.Region.ICE_CAVE
	var d := span.x + 85 if cave else span.x + 65
	sled.place_at(d, -2 if cave else 0, 0)
	sled.get("_spray").visible = false
	sled.get("_puff").visible = false
	camera.mode = ChaseCamera.Mode.CHASE
	camera.snap()
	main.get("_hud").show_screen("game")
	main.get("_hud").get("_popups").visible = false
	var atmo: Atmosphere = main.get("_atmosphere")
	atmo.storm = 0
	atmo.night_override = 0
	atmo._flash = 0
	atmo.overlay.set_shader_parameter("flash", 0)
	atmo.indoor = cave
	atmo.cave = 1 if cave else 0
	atmo.update_atmosphere(0, camera, 0, 0, false)
	await _shot("cave-ride" if cave else "harbor-ride")
	main.get("_hud").show_screen("")
	d = span.x + 35 if cave else span.x + 150
	var target := Vector3(field.center_x(d), field.height(field.center_x(d), d) + 3, -d)
	camera.position = target + (Vector3(-18, 12, 38) if cave else Vector3(-75, 60, 95))
	camera.look_at(target)
	camera.fov = 64
	atmo.indoor = false
	atmo.cave = 0
	atmo.update_atmosphere(0, camera, 0, 0, false)
	await _shot("cave-entry" if cave else "harbor-overview")
	if cave:
		camera.position = target + Vector3(-72, 52, 100)
		camera.look_at(target + Vector3.UP * 8)
		atmo.update_atmosphere(0, camera, 0, 0, false)
		await _shot("cave-mountain")
		d = span.y - TerrainField.CAVE_INSET
		target = Vector3(field.center_x(d), field.height(field.center_x(d), d) + 3, -d)
		camera.position = target + Vector3(18, 12, -38)
		camera.look_at(target)
		atmo.update_atmosphere(0, camera, 0, 0, false)
		await _shot("cave-exit")
	else:
		d = span.x + 205
		sled.place_at(d, 0, 0)
		camera.mode = ChaseCamera.Mode.CHASE
		camera.snap()
		await _shot("harbor-crane")

func _shot(name: String) -> void:
	for i in 15: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/pulka-%s.png" % name)

func _find(field: TerrainField, kind: int) -> Vector3:
	for cell in 256:
		var span := field._slot(cell)
		if int(span.z) == kind: return span
	return Vector3.ZERO

func _check(message: String, condition: bool) -> void:
	print(("  ok    " if condition else "  FAIL  ") + message)
	if not condition: failures += 1
