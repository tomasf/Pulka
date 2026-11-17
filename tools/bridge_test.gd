extends SceneTree
## Analytic surface, streamed deck seams, all rides, rail hits and recovery.
## Native --capture also saves overview and gameplay images to /tmp.
var failures := 0

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	for seed_value in [7, 1234, 4711]:
		var field := TerrainField.new(seed_value)
		var span := _find(field)
		_check("seed %d includes a bridge" % seed_value, span.z == TerrainField.Region.BRIDGE)
		var ends := field.bridge_span(span.x + 1)
		var middle := (ends.x + ends.y) * 0.5
		var cx := field.center_x(middle)
		_check("bridge narrows to 7.6 m", is_equal_approx(field.half_width(middle), 3.8) and field.half_width(span.x - 1) > 10)
		_check("deck spans a real ravine", field.height(cx, middle) - field.height(cx, middle, false, false) > 30 and field.height(cx + 4.1, middle) < field.bridge_height(middle) - 30)
		_check("edge normals stay on the deck", field.surface_world(cx + 3.75, -middle).y > 0.9)
		_check("bridge centre is straight", absf(field.center_x(middle) - (field.center_x(ends.x) + field.center_x(ends.y)) * 0.5) < 0.001)
		_check("no road or ramp crosses the deck", not field.near_road(middle, 30) and not field.near_ramp(cx, middle, 4))
		for d in [span.x, ends.x, ends.y, span.y]:
			_check("continuous entry/exit at %.1f" % d, absf(field.height(field.center_x(d - 0.01), d - 0.01) - field.height(field.center_x(d + 0.01), d + 0.01)) < 0.05 and absf(field.center_x(d - 0.01) - field.center_x(d + 0.01)) < 0.04)
		for spec in VehicleSpec.all():
			var sled := Sled.new()
			root.add_child(sled)
			sled.field = field
			sled.set_vehicle(spec, RandomNumberGenerator.new())
			sled.place_at(span.x + 1, 0, 18)
			sled.frozen = false
			var lateral := 0.0
			for frame in 2000:
				var d := sled.distance()
				if d >= span.y - 1: break
				var slope := field.center_slope(d)
				var offset := sled.position.x - field.center_x(d)
				var drift := sled.velocity.x + sled.velocity.z * slope
				var desired := atan2(slope, 1) - clampf(offset * 0.25 + drift * 0.40, -0.7, 0.7)
				var steer := clampf(wrapf(desired - sled.yaw, -PI, PI) * 3, -1, 1)
				sled.step(1.0 / 60, steer, 1, false)
				if field.on_bridge(sled.distance()):
					lateral = maxf(lateral, absf(sled.position.x - field.center_x(sled.distance())))
			_check("%s enters, crosses and exits (%.2f m)" % [spec.title, lateral], sled.distance() >= span.y - 1 and lateral < 3.3)
			sled.free()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_process(false)
	main.set("_autopilot", true)
	main.set("_vehicle", 0)
	main.set("_start_region", "bridge")
	main.call("_start_run")
	main.set("state", 2)
	var field: TerrainField = main.get("_field")
	var ends := field.bridge_span(main.call("_find_region", "bridge"))
	var middle := (ends.x + ends.y) * 0.5
	var sled: Sled = main.get("_sled")
	sled.frozen = false
	var world: SlopeWorld = main.get("_world")
	world.reset(field, middle)
	for i in range(floori(ends.x / 50) - 1, ceili(ends.y / 50) + 1): world._ensure(i)
	var boards := 0
	var blocked := false
	for chunk: Chunk in world._chunks.values():
		for child in chunk.get_children():
			if child is MeshInstance3D and child.name == "SuspensionBridge":
				boards += 1
				var verts: PackedVector3Array = child.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				# First box's top board corners are precisely on the physics deck.
				var matches := 0
				for p in verts.slice(0, 24):
					if absf(p.y - field.bridge_height(-p.z)) < 0.004: matches += 1
				_check("streamed plank top matches collision", matches >= 4)
		for obstacle in chunk.obstacles:
			blocked = blocked or (field.on_bridge(-obstacle.position.z) and absf(obstacle.position.x - field.center_x(-obstacle.position.z)) < 3.8)
	_check("no obstacles obstruct the suspended deck", not blocked)
	_check("bridge is streamed across several chunks", boards >= 3)
	if OS.get_cmdline_user_args().has("--capture"):
		await _capture(main, ends)
	sled.place_at(middle, 3.5, 18)
	main.call("_check_bounds")
	_check("hitting a railing crashes", sled.crashed)
	main.call("_after_crash", main.get("_players")[0])
	_check("recovery returns to the deck", not sled.crashed and absf(sled.position.x - field.center_x(sled.distance())) < 0.1 and absf(sled.position.y - field.bridge_height(sled.distance())) < 0.01)
	sled.place_at(middle, 4.3, 18)
	sled.position.y = field.bridge_height(middle) + 2
	sled.on_ground = false
	main.call("_check_bounds")
	_check("a jump may clear the railing", not sled.crashed)
	var airborne_y := sled.position.y
	for i in 90: sled.step(1.0 / 60, 0, 0, false)
	_check("leaving the deck falls toward the ravine", not sled.on_ground and sled.position.y < airborne_y - 1)
	main.call("_check_bounds")
	_check("falling beyond the railing costs a life", sled.crashed)
	# A fall can drift under the span. The deck must not pull you back up.
	sled.place_at(middle, 0, 12)
	sled.position.y = field.bridge_height(middle) - 2
	sled.on_ground = false
	for i in 5: sled.step(1.0 / 60, 0, 0, false)
	_check("a fall underneath the deck stays in the ravine", sled.position.y < field.bridge_height(sled.distance()) - 1)
	main.call("_check_bounds")
	_check("falling under the deck is still a crash", sled.crashed)
	main.queue_free()
	await process_frame
	await process_frame
	print("bridge test: %s" % ("all passed" if failures == 0 else "%d failed" % failures))
	quit(failures)

func _capture(main: Node, ends: Vector2) -> void:
	var field: TerrainField = main.get("_field")
	var camera: ChaseCamera = main.get("_camera")
	var middle := (ends.x + ends.y) * 0.5
	var sled: Sled = main.get("_sled")
	sled.place_at(ends.x + 20, 0, 18)
	main.get("_hud").show_screen("game")
	main.get("_director").stop()
	camera.mode = ChaseCamera.Mode.CHASE
	camera.snap()
	for i in 10:
		main.call("_process", 1.0 / 60)
		await process_frame
	# Fixed morning light makes the review images comparable across seeds.
	main.get("_atmosphere").update_atmosphere(0, camera, 0, 0, false)
	for i in 10: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/pulka-bridge-ride.png")
	main.get("_hud").show_screen("")
	var target := Vector3(field.center_x(middle), field.bridge_height(middle) + 2, -middle)
	camera.position = target + Vector3(-115, 58, 28)
	camera.look_at(target)
	camera.fov = 65
	main.get("_atmosphere").update_atmosphere(0, camera, 0, 0, false)
	for i in 10: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/pulka-bridge-overview.png")

func _find(field: TerrainField) -> Vector3:
	for d in range(800, 60000, 25):
		var span := field.region_span(d)
		if span.z == TerrainField.Region.BRIDGE: return span
	return Vector3.ZERO

func _check(message: String, condition: bool) -> void:
	print(("  ok    " if condition else "  FAIL  ") + message)
	if not condition: failures += 1
