extends SceneTree
## Actual asphalt/snow triangles versus the ride surface, including swept
## approaches, chunk seams and traffic support. --capture saves review images.
var failures := 0

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	for seed_value in [7, 1234, 4711]:
		var field := TerrainField.new(seed_value)
		var span := Vector3.ZERO
		for cell in 256:
			var candidate := field._slot(cell)
			if int(candidate.z) == TerrainField.Region.HIGHWAY:
				span = candidate
				break
		assert(span != Vector3.ZERO)
		_check("seed %d: motorway ends outside the playable hillside" % seed_value, absf(field.sweep(span.x + 6)) - TerrainField.MOTORWAY_EDGE > field.half_width(span.x + 6) + field.side_margin(span.x + 6) + 50 and absf(field.sweep(span.y - 6)) - TerrainField.MOTORWAY_EDGE > field.half_width(span.y - 6) + field.side_margin(span.y - 6) + 50)
		var world := SlopeWorld.new()
		root.add_child(world)
		world.reset(field, span.x)
		for index in range(floori(span.x / 50), ceili(span.y / 50)):
			world._ensure(index)
		var review := Chunk.new()
		world.regions._place_motorway(review, span.x + 6, span.y - 6)
		var road := review.get_child(0) as MeshInstance3D
		var asphalt: PackedVector3Array = road.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var worst_gap := 0.0
		var worst_snow := -INF
		var normals_match := true
		for station in 105:
			var d := lerpf(span.x + 7, span.y - 7, station / 104.0)
			var road_row := (floori(d) - floori(span.x + 6)) * 6
			var chunk: Chunk = world._chunks[floori(d / 50)]
			var ground: ArrayMesh = chunk.get_child(0).mesh
			var arrays := ground.surface_get_arrays(0)
			var snow: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var row := mini(floori((d - chunk.index * 50) / SlopeWorld.ROW_STEP), SlopeWorld.TERRAIN_ROWS - 2)
			var first := row * (world._columns.size() - 1) * 6
			for lateral in [-16.8, -13.0, -6.5, 0.0, 6.5, 13.0, 16.8]:
				var x := world.regions.lane_x(lateral, d)
				var point := Vector2(x, -d)
				var road_y := maxf(_triangle_height(asphalt[road_row], asphalt[road_row + 1], asphalt[road_row + 2], point), _triangle_height(asphalt[road_row + 3], asphalt[road_row + 4], asphalt[road_row + 5], point))
				assert(is_finite(road_y))
				worst_gap = maxf(worst_gap, absf(road_y - field.height(x, d)))
				var surface := field.surface_world(x, -d)
				normals_match = normals_match and Vector3(surface.x, surface.y, surface.z).dot(field.motorway_normal(d)) > 0.999
				for i in range(first, first + (world._columns.size() - 1) * 6, 3):
					var snow_y := _triangle_height(snow[indices[i]], snow[indices[i + 1]], snow[indices[i + 2]], point)
					if is_finite(snow_y): worst_snow = maxf(worst_snow, snow_y - road_y)
		_check("seed %d: physics follows asphalt (worst %.3f m)" % [seed_value, worst_gap], worst_gap < 0.025)
		_check("seed %d: snow stays below asphalt (worst %.3f m)" % [seed_value, worst_snow], worst_snow < 0.004)
		_check("seed %d: road collision normals follow the asphalt" % seed_value, normals_match)
		var traffic := MotorwayTraffic.new().setup(world, span)
		world.add_child(traffic)
		var contact := Vector2(INF, -INF)
		var matching_normals := true
		for station in 40:
			var d := lerpf(span.x + 16, span.y - 16, station / 39.0)
			for i in traffic._ds.size(): traffic._ds[i] = d
			traffic._place_all()
			for car in traffic.obstacles:
				var axles: Array = [-6.4, -2.0, -0.9, 4.5, 5.9]
				var track := 1.05
				if car.kind == Obstacle.Kind.CAR:
					var shape := CarModels.shape(int(car.visual.mesh.get_meta("body_kind")))
					axles = [shape.axles.x, shape.axles.y]
					track = shape.half_width - 0.02
				for side in [-1.0, 1.0]:
					for axle: float in axles:
						var foot := car.transform * Vector3(side * track, 0, axle)
						var gap := foot.y - field.motorway_height(-foot.z)
						contact.x = minf(contact.x, gap)
						contact.y = maxf(contact.y, gap)
				matching_normals = matching_normals and car.basis.y.dot(field.motorway_normal(d)) > 0.999
		_check("seed %d: cars and lorries stay on their tyres (%.3f..%.3f m)" % [seed_value, contact.x, contact.y], contact.x > -0.12 and contact.y < 0.15 and matching_normals)
		traffic.free()
		for spec in VehicleSpec.all():
			var sled := Sled.new()
			root.add_child(sled)
			sled.field = field
			sled.set_vehicle(spec, RandomNumberGenerator.new())
			sled.place_at(span.x - 25, 0, 18)
			sled.frozen = false
			var sink := 0.0
			var road_frames := 0
			for frame in 1800:
				var d := sled.distance()
				if d > span.y + 15: break
				var slope := field.center_slope(d)
				var offset := sled.position.x - field.center_x(d)
				var drift := sled.velocity.x + sled.velocity.z * slope
				var desired := atan2(slope, 1) - clampf(offset * 0.25 + drift * 0.4, -0.7, 0.7)
				var steer := clampf(wrapf(desired - sled.yaw, -PI, PI) * 3, -1, 1)
				sled.step(1.0 / 60, steer, false)
				d = sled.distance()
				if d > span.x + 7 and d < span.y - 7 and absf(sled.position.x - world.regions.lane_x(0, d)) < 17.3:
					road_frames += 1
					sink = maxf(sink, field.motorway_height(d) - sled.position.y)
			_check("seed %d: %s enters, crosses and exits without sinking (%.3f m)" % [seed_value, spec.title, sink], sled.distance() > span.y + 15 and sink < 0.004 and road_frames > 30)
			sled.free()
		if seed_value == 4711 and OS.get_cmdline_user_args().has("--capture"):
			await _capture(world, span)
		review.free()
		world.free()
	print("motorway test: %s" % ("all passed" if failures == 0 else "%d failed" % failures))
	quit(failures)

func _triangle_height(a: Vector3, b: Vector3, c: Vector3, p: Vector2) -> float:
	var start := Vector2(a.x, a.z)
	var ab := Vector2(b.x, b.z) - start
	var ac := Vector2(c.x, c.z) - start
	var v := p - start
	var denominator := ab.cross(ac)
	if absf(denominator) < 0.000001: return -INF
	var u := v.cross(ac) / denominator
	var w := ab.cross(v) / denominator
	if u < -0.00001 or w < -0.00001 or u + w > 1.00001: return -INF
	return a.y * (1 - u - w) + b.y * u + c.y * w

func _capture(world: SlopeWorld, span: Vector3) -> void:
	root.size = Vector2i(1600, 1000)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("b6cadd")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("bdccdf")
	environment.environment.ambient_light_energy = 0.7
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -30, 0)
	sun.shadow_enabled = true
	world.add_child(sun)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	var prefix := "/tmp/pulka-motorway"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): prefix = arg.trim_prefix("--output=")
	for i in 3:
		var d: float = span.x + [45.0, 150.0, 255.0][i]
		var center := Vector3(world.regions.lane_x(0, d), world.field.base_height(d), -d)
		var camera_d := d - 38
		camera.position = Vector3(world.regions.lane_x(0, camera_d) + 25, world.field.base_height(camera_d) + 18, -camera_d)
		camera.look_at(center + Vector3(0, -3, -12))
		for frame in 8: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s-%d.png" % [prefix, i])

func _check(message: String, condition: bool) -> void:
	print(("  ok    " if condition else "  FAIL  ") + message)
	if not condition: failures += 1
