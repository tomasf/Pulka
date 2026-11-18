extends SceneTree
## Basin geometry, shoreline contact, all rides skimming, sinking, and
## split-screen streaming. Native --capture saves fixed review views.
var failures := 0

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	for seed_value in [7, 1234, 4711]:
		var field := TerrainField.new(seed_value)
		var span := _find(field)
		var strip := field.water_strip(span.x + 100)
		var mid := (strip.x + strip.y) * 0.5
		var x := field.center_x(mid)
		_check("seed %d has one broad, level lake" % seed_value, TerrainField.LAKE_WATER.size() == 1 and field.lake_half_width(mid) > 95 and strip.y - strip.x >= 75 and absf(field.height(x, mid) - field.water_level(strip)) < 0.001)
		_check("lake bed is below even the lowest wave", field.height(x, mid, false, false) < field.water_level(strip) - 2)
		_check("dry shoreline is not treated as water", field.is_water(mid, x) and not field.is_water(mid, x + field.lake_half_width(mid) + 1))
		var mesh := LakeWater.water_mesh(field, strip)
		var arrays := mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var valid := mesh.get_surface_count() == 1
		var edge_vertices := 0
		var deep_vertices := 0
		for i in vertices.size():
			var at := vertices[i]
			valid = valid and at.is_finite() and absf(at.y - field.water_level(strip) - 0.035) < 0.004 and field.lake_shore_distance(at.x, -at.z) > -0.05
			if colors[i].a < 0.01: edge_vertices += 1
			if colors[i].a > 0.99: deep_vertices += 1
		for i in range(0, indices.size(), 3):
			var a := vertices[indices[i]]
			var b := vertices[indices[i + 1]]
			var c := vertices[indices[i + 2]]
			valid = valid and (c - a).cross(b - a).y > 0
		_check("lake mesh is level, correctly wound and inside its shore", valid and edge_vertices > 50 and deep_vertices > 100)
		for spec in VehicleSpec.all():
			var sled := Sled.new()
			root.add_child(sled)
			sled.field = field
			sled.set_vehicle(spec, RandomNumberGenerator.new())
			sled.place_at(strip.x - 25, 0, 25)
			sled.frozen = false
			var events := {"skim": 0, "sink": 0}
			var exit_air := 0.0
			sled.skimmed.connect(func(_speed: float) -> void: events.skim += 1)
			sled.sank.connect(func() -> void: events.sink += 1)
			for frame in 1500:
				var d := sled.distance()
				if d > span.y + 20 or events.sink > 0: break
				var offset := sled.position.x - field.center_x(d)
				var drift := sled.velocity.x + sled.velocity.z * field.center_slope(d)
				var desired := atan2(field.center_slope(d), 1) - clampf(offset * 0.25 + drift * 0.4, -0.7, 0.7)
				sled.step(1.0 / 60, clampf(wrapf(desired - sled.yaw, -PI, PI) * 3, -1, 1), false)
				if sled.distance() > strip.y + 12 and sled.distance() < strip.y + TerrainField.LAKE_EXIT:
					exit_air = maxf(exit_air, sled.position.y - field.height(sled.position.x, sled.distance()))
			_check("seed %d: %s skims and reaches the downhill slope (%d splashes)" % [seed_value, spec.title, events.skim], sled.distance() > span.y + 20 and events.sink == 0 and events.skim > 0)
			_check("%s leaves the lake without a high fall (%.2f m)" % [spec.title, exit_air], exit_air < 1.0)
			sled.place_at(mid, 0, 3)
			sled.step(1.0 / 120, 0, false)
			_check("slow %s still sinks" % spec.title, events.sink > 0)
			sled.free()
		for speed in [25.0, 40.0]:
			var sled := Sled.new()
			root.add_child(sled)
			sled.field = field
			sled.set_vehicle(VehicleSpec.all()[0], RandomNumberGenerator.new())
			sled.place_at(strip.y + 1, 0, speed)
			sled.frozen = false
			var air := 0.0
			for frame in 600:
				var d := sled.distance()
				if d > strip.y + TerrainField.LAKE_EXIT: break
				var offset := sled.position.x - field.center_x(d)
				var drift := sled.velocity.x + sled.velocity.z * field.center_slope(d)
				var desired := atan2(field.center_slope(d), 1) - clampf(offset * 0.25 + drift * 0.4, -0.7, 0.7)
				sled.step(1.0 / 60, clampf(wrapf(desired - sled.yaw, -PI, PI) * 3, -1, 1), false)
				if sled.distance() < strip.y + TerrainField.LAKE_EXIT:
					air = maxf(air, sled.position.y - field.height(sled.position.x, sled.distance()))
			_check("seed %d: exit keeps ground contact at %d km/h (%.3f m)" % [seed_value, speed * 3.6, air], sled.distance() > strip.y + TerrainField.LAKE_EXIT and air < 0.03)
			sled.free()
		var ordered := TerrainField.new(seed_value)
		var continuous := true
		for cell in 48:
			var slot := field._slot(cell)
			var before := field.base_height(slot.x - 0.01)
			var after := field.base_height(slot.x + 0.01)
			continuous = continuous and absf(before - after) < 0.05 and absf(field.base_height(slot.y + 10) - ordered.base_height(slot.y + 10)) < 0.00001
		for cell in range(47, -1, -1):
			var slot := field._slot(cell)
			continuous = continuous and absf(field.base_height(slot.y + 10) - ordered.base_height(slot.y + 10)) < 0.00001
		_check("lake terraces stay continuous and independent of sampling order", continuous)
		var world := SlopeWorld.new()
		root.add_child(world)
		world.reset(field, strip.x - 30)
		for index in range(floori((strip.x - 30) / 50), ceili((strip.y + 30) / 50)): world._ensure(index)
		var worst_bed := -INF
		for station in 21:
			var d := lerpf(strip.x + 5, strip.y - 5, station / 20.0)
			var chunk: Chunk = world._chunks[floori(d / 50)]
			var ground: Array = chunk.get_child(0).mesh.surface_get_arrays(0)
			var bed: PackedVector3Array = ground[Mesh.ARRAY_VERTEX]
			var triangles: PackedInt32Array = ground[Mesh.ARRAY_INDEX]
			var row := mini(floori((d - chunk.index * 50) / SlopeWorld.ROW_STEP), SlopeWorld.TERRAIN_ROWS - 2)
			var first := row * (world._columns.size() - 1) * 6
			for fraction in [-0.8, -0.4, 0.0, 0.4, 0.8]:
				var at := Vector2(field.center_x(d) + field.lake_half_width(d) * fraction, -d)
				for i in range(first, first + (world._columns.size() - 1) * 6, 3):
					var height := _triangle_height(bed[triangles[i]], bed[triangles[i + 1]], bed[triangles[i + 2]], at)
					if is_finite(height): worst_bed = maxf(worst_bed, height - field.water_level(strip))
		_check("actual terrain triangles stay below the waves (%.2f m)" % worst_bed, worst_bed < -0.06)
		world.update_world(strip.y + 45, 0, 0, PackedFloat32Array([strip.x + 8]))
		var surfaces := world.find_children("LakeWater", "MeshInstance3D", true, false)
		_check("two riders keep the entire lake streamed until both leave", surfaces.size() == 1)
		if seed_value == 4711 and OS.get_cmdline_user_args().has("--capture"):
			await _capture(world, span, strip)
		world.free()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_process(false)
	main.set("_autopilot", true)
	main.set("_two_players", true)
	main.set("_start_region", "lake")
	main.get("_rng").seed = 4711
	main.call("_start_run")
	main.set("state", 2)
	main.get("_director").stop()
	var field: TerrainField = main.get("_field")
	var strip := field.water_strip(_find(field).x + 100)
	var players: Array = main.get("_players")
	for player: Player in players:
		player.sled.place_at((strip.x + strip.y) * 0.5, 0, 3)
		main.call("_after_crash", player)
		_check("player %d recovers safely beyond the lake" % (player.index + 1), player.sled.distance() > strip.y and not field.is_water(player.sled.distance(), player.sled.position.x) and player.sled.position.distance_to(player.camera.position) < 35)
	var first_splash := Splash.spawn(root, Vector3.ZERO, Vector3(0, 0, -30), .8)
	var second_splash := Splash.spawn(root, Vector3.ZERO, Vector3.ZERO, 1.8)
	first_splash._process(.6)
	_check("overlapping splashes fade independently", first_splash._ring_material.albedo_color.a < .2 and second_splash._ring_material.albedo_color.a > .5)
	_check("splash rings retain their speed-dependent stretch", first_splash._stretch > second_splash._stretch)
	first_splash.free()
	second_splash.free()
	main.queue_free()
	await process_frame
	await process_frame
	print("lake test: %s" % ("all passed" if failures == 0 else "%d failed" % failures))
	quit(failures)

func _find(field: TerrainField) -> Vector3:
	for cell in 256:
		var span := field._slot(cell)
		if int(span.z) == TerrainField.Region.LAKE: return span
	return Vector3.ZERO

func _triangle_height(a: Vector3, b: Vector3, c: Vector3, p: Vector2) -> float:
	var start := Vector2(a.x, a.z)
	var ab := Vector2(b.x, b.z) - start
	var ac := Vector2(c.x, c.z) - start
	var denominator := ab.cross(ac)
	if absf(denominator) < 0.000001: return -INF
	var u := (p - start).cross(ac) / denominator
	var v := ab.cross(p - start) / denominator
	if u < -0.00001 or v < -0.00001 or u + v > 1.00001: return -INF
	return a.y * (1 - u - v) + b.y * u + c.y * v

func _capture(world: SlopeWorld, _span: Vector3, strip: Vector2) -> void:
	root.size = Vector2i(1600, 1000)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	environment.environment.sky = sky
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -25, 0)
	world.add_child(sun)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	var mid := (strip.x + strip.y) * 0.5
	var target := Vector3(world.field.center_x(mid), world.field.water_level(strip), -mid)
	camera.position = target + Vector3(85, 60, 95)
	camera.look_at(target)
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/pulka-lake-overview.png")

func _check(message: String, condition: bool) -> void:
	print(("  ok    " if condition else "  FAIL  ") + message)
	if not condition: failures += 1
