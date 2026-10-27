extends SceneTree
## Where does a frame's game logic go? Runs an autopilot ride headless and
## times the main per-frame steps separately, with the Apple TV settings.
## Run: Godot --headless --path . --script res://tools/profile.gd


const FRAMES := 1500
const DT := 1.0 / 60.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Quality.force_mobile = true
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.set("_autopilot", true)
	main.set("_no_crash", true)
	main.call("_start_run")
	main.set("state", 2)  # PLAYING, skipping the countdown.
	var sled: Sled = main.get("_sled")
	sled.frozen = false
	# Drive the frames by hand so each step can be timed on its own.
	main.process_mode = Node.PROCESS_MODE_DISABLED
	var world: SlopeWorld = main.get("_world")
	var times := {"sled": 0, "world": 0, "collisions": 0, "pickups+bounds": 0, "hud": 0, "atmosphere+camera": 0, "engine (nodes, physics)": 0}
	var worst := {}
	for key in times:
		worst[key] = 0
	var atmosphere: Atmosphere = main.get("_atmosphere")
	var camera: ChaseCamera = main.get("_camera")
	var director: Node = main.get("_director")
	var sound: SoundBank = main.get("_sound")
	for frame in FRAMES:
		var steps := {
			"sled": func() -> void: sled.step(DT, main.call("_autopilot_steer"), 1.0, false),
			"world": func() -> void: world.update_world(sled.distance(), DT),
			"collisions": func() -> void: main.call("_check_collisions"),
			"pickups+bounds": func() -> void:
				main.call("_check_pickups")
				main.call("_check_bounds"),
			"hud": func() -> void: main.call("_update_hud"),
			"atmosphere+camera": func() -> void:
				director.call("update", DT, true)
				atmosphere.indoor = world.regions.indoors(sled.distance())
				camera.update_camera(DT)
				atmosphere.update_atmosphere(DT, camera, sled.distance(), sled.speed() / 45.0, false)
				sound.set_motion(DT, sled.speed(), sled.on_ground, true),
		}
		for key in steps:
			var start := Time.get_ticks_usec()
			(steps[key] as Callable).call()
			var spent := Time.get_ticks_usec() - start
			times[key] += spent
			worst[key] = maxi(worst[key], spent)
		# Everything else the engine does in a frame: node _process callbacks
		# (movers, pickups, particles), physics and the scene tree.
		var start_engine := Time.get_ticks_usec()
		await process_frame
		var engine_spent := Time.get_ticks_usec() - start_engine
		times["engine (nodes, physics)"] += engine_spent
		worst["engine (nodes, physics)"] = maxi(worst["engine (nodes, physics)"], engine_spent)
		if sled.crashed:
			sled.place_at(sled.distance() + 5.0, 0.0, 20.0)
	print("Ride: %d m, %d obstacles near the end" % [int(sled.distance()), world.obstacles_near(sled.distance()).size()])
	var total := 0
	for key in times:
		total += times[key]
		print("  %-18s avg %6.2f ms   worst %6.1f ms" % [key, times[key] / 1000.0 / FRAMES, worst[key] / 1000.0])
	print("  %-18s avg %6.2f ms" % ["total", total / 1000.0 / FRAMES])
	quit()
