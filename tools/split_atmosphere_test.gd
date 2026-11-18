extends SceneTree
## Mixed indoor/outdoor states use the real split-screen cameras and Main's
## update path. Native --capture also renders the two views side by side.
var failures := 0

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_process(false)
	main.set("_autopilot", true)
	main.set("_vehicle", 0)
	main.get("_rng").seed = 4711
	main.call("_build_split")
	main.call("_new_world")
	main.get("_director").stop()
	var players: Array = main.get("_players")
	var first: Player = players[0]
	var second: Player = players[1]
	_check("split-screen applies the platform shadow budget", first.atmosphere._sun.directional_shadow_mode == Quality.shadow_mode(true) and second.atmosphere._sun.directional_shadow_mode == Quality.shadow_mode(true))
	for p: Player in players:
		p.sled.set_vehicle(VehicleSpec.all()[0], RandomNumberGenerator.new(), Player.COLORS[p.index])
		p.sled.frozen = true
		p.camera.mode = ChaseCamera.Mode.CHASE
	var field: TerrainField = main.get("_field")
	_check("each view owns its environment, sky, sun and snow material", first.atmosphere != second.atmosphere and first.atmosphere._environment != second.atmosphere._environment and first.atmosphere._sky != second.atmosphere._sky and first.atmosphere._sun != second.atmosphere._sun and first.atmosphere._snow_process != second.atmosphere._snow_process)
	for kind in [TerrainField.Region.SEWER, TerrainField.Region.ICE_CAVE, TerrainField.Region.MALL]:
		var span := _find(field, kind)
		_check("region exists: %s" % TerrainField.Region.keys()[kind], span != Vector3.ZERO)
		# Both orders, both indoors, then the leader exits while the other
		# is still inside. This also covers player 2 taking the lead.
		for offsets in [Vector2(-60, -80), Vector2(100, -60), Vector2(-60, 100), Vector2(100, 120), Vector2(span.y - span.x + 60, 100), Vector2(100, span.y - span.x + 60), Vector2(span.y - span.x + 80, span.y - span.x + 60)]:
			first.sled.place_at(span.x + offsets.x)
			second.sled.place_at(span.x + offsets.y)
			for p: Player in players: p.camera.snap()
			main.call("_update_atmospheres", 1.0 / 60)
			var expected := Vector2i(1 if offsets.x > 0 and offsets.x < span.y - span.x else 0, 1 if offsets.y > 0 and offsets.y < span.y - span.x else 0)
			var valid := true
			for p: Player in players:
				var indoor := expected[p.index] == 1
				var atmo := p.atmosphere
				valid = valid and atmo.indoor == indoor and atmo._snow.visible == not indoor and ((atmo._snow.amount_ratio == 0) == indoor)
				valid = valid and p.camera.environment == atmo._environment
				if kind == TerrainField.Region.SEWER:
					valid = valid and is_equal_approx(atmo.sewer, float(indoor)) and ((atmo._environment.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR) == indoor)
					valid = valid and is_equal_approx(atmo._sun.light_energy / atmo._day_sun_energy, 0.08 if indoor else 1.0)
			_check("%s indoor states %s stay independent" % [TerrainField.Region.keys()[kind], expected], valid)
	for p: Player in players:
		var other: Player = players[1 - p.index]
		_check("player %d only renders their own sun, snow and aurora" % (p.index + 1), (p.camera.cull_mask & p.atmosphere.view_layer()) != 0 and (p.camera.cull_mask & other.atmosphere.view_layer()) == 0 and p.atmosphere._sun.layers == p.atmosphere.view_layer() and p.atmosphere._snow.layers == p.atmosphere.view_layer() and p.atmosphere._aurora[0].layers == p.atmosphere.view_layer())
	first.atmosphere.storm = 0.7
	first.atmosphere.wind = -1
	main.call("_update_atmospheres", 0)
	_check("both outdoor views share the blizzard", is_equal_approx(second.atmosphere.storm, 0.7) and second.atmosphere.wind == -1 and is_equal_approx(second.atmosphere._snow.amount_ratio, first.atmosphere._snow.amount_ratio))
	if OS.get_cmdline_user_args().has("--capture"): await _capture(main, _find(field, TerrainField.Region.SEWER))
	var removed: WeakRef = weakref(second.atmosphere)
	main.call("_enter_menu")
	await process_frame
	await process_frame
	_check("solo keeps its own environment and removes the second weather", removed.get_ref() == null and first.camera.environment == first.atmosphere._environment and main.get("_players").size() == 1)
	_check("solo restores its full shadow budget", first.atmosphere._sun.directional_shadow_mode == Quality.shadow_mode(false))
	main.call("_build_split")
	_check("a new race creates fresh independent weather", main.get("_players")[1].atmosphere != first.atmosphere and main.get("_players")[1].camera.environment != first.camera.environment)
	main.call("_enter_menu")
	main.queue_free()
	await process_frame
	await process_frame
	print("split atmosphere test: %s" % ("all passed" if failures == 0 else "%d failed" % failures))
	quit(failures)

func _capture(main: Node, span: Vector3) -> void:
	var field: TerrainField = main.get("_field")
	var world: SlopeWorld = main.get("_world")
	world.reset(field, span.x + 70)
	for i in range(floori((span.x - 180) / 50), ceili((span.y + 120) / 50)): world._ensure(i)
	while not world.regions._region_jobs.is_empty(): world.regions.prepare_floors(Time.get_ticks_usec() + 5000)
	var players: Array = main.get("_players")
	main.get("_hud").show_screen("")
	players[0].atmosphere.storm = 0
	for swap in [false, true]:
		for p: Player in players:
			var inside: bool = (p.index == 0) != swap
			p.sled.place_at(span.x + (100 if inside else -60), 1.8)
			p.camera.snap()
			p.atmosphere.copy_weather(players[0].atmosphere)
			p.atmosphere.set_time_of_day(0)
			p.atmosphere._sky_state = Vector3(p.sled.distance(), 0, 0)
		main.call("_update_atmospheres", 0)
		for i in 20:
			main.call("_update_atmospheres", 1.0 / 60)
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/pulka-split-atmosphere-%d.png" % int(swap))
	# Compare the actual outdoor render before/after the other rider enters.
	# Hide moving flakes for this measurement; the same geometry and camera
	# must keep the same illumination, including direct sunlight.
	for observer in [0, 1]:
		players[observer].sled.place_at(span.x - 60, 1.8)
		players[1 - observer].sled.place_at(span.x - 90, 1.8)
		for p: Player in players:
			p.camera.snap()
			p.camera.snap()
			p.atmosphere.set_time_of_day(0)
			p.atmosphere._sky_state = Vector3(p.sled.distance(), 0, 0)
		main.call("_update_atmospheres", 0)
		for p: Player in players: p.atmosphere._snow.visible = false
		for i in 8: await process_frame
		await RenderingServer.frame_post_draw
		var before: Image = players[observer].camera.get_viewport().get_texture().get_image()
		players[1 - observer].sled.place_at(span.x + 100, 1.8)
		main.call("_update_atmospheres", 0)
		for p: Player in players: p.atmosphere._snow.visible = false
		for i in 8: await process_frame
		await RenderingServer.frame_post_draw
		var after: Image = players[observer].camera.get_viewport().get_texture().get_image()
		var difference := 0.0
		var samples := 0
		for y in range(before.get_height() * 0.4, before.get_height() * 0.8, 4):
			for x in range(before.get_width() * 0.15, before.get_width() * 0.85, 4):
				var a := before.get_pixel(x, y)
				var b := after.get_pixel(x, y)
				difference += (absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)) / 3
				samples += 1
		difference /= samples
		_check("player %d outdoor pixels keep their lighting when the other enters" % (observer + 1), difference < 0.003)
		print("    mean pixel difference: %.6f" % difference)

func _find(field: TerrainField, kind: int) -> Vector3:
	for cell in 256:
		var span := field._slot(cell)
		if int(span.z) == kind: return span
	return Vector3.ZERO

func _check(message: String, condition: bool) -> void:
	print(("  ok    " if condition else "  FAIL  ") + message)
	if not condition: failures += 1
