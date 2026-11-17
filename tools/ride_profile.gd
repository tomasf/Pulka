extends SceneTree
## Real rendering and game logic, rather than just chunk generation.
## Godot --path . --fixed-fps 60 --script res://tools/ride_profile.gd -- bandy --mute

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	var args := OS.get_cmdline_user_args()
	main.set("_start_region", args[0] if args.size() else "bandy")
	root.add_child(main)
	# _ready randomizes the RNG, so choose the seed afterwards.
	(main.get("_rng") as RandomNumberGenerator).seed = 4711
	main.set("_autopilot", true)
	main.set("_no_crash", true)
	main.call("_start_run")
	var world: SlopeWorld = main.get("_world")
	world.profile_builds = true
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var wall: Array[float] = []
	var previous := Time.get_ticks_usec()
	var spikes: Array[Dictionary] = []
	var gpu: Array[float] = []
	var pipeline_counts := _pipelines()
	for frame in 1500:
		await process_frame
		var now := Time.get_ticks_usec()
		var elapsed := (now - previous) / 1000.0
		previous = now
		var pipelines := _pipelines()
		if frame >= 180:
			wall.append(elapsed)
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
			if elapsed > 16.7:
				spikes.append({"frame": frame, "ms": elapsed, "d": (main.get("_sled") as Sled).distance(), "world_ms": world.last_update_us / 1000.0, "pipelines": pipelines - pipeline_counts, "builds": world.build_profile.duplicate()})
		pipeline_counts = pipelines
		world.build_profile.clear()
		if frame == 600 and args.has("--capture"):
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/pulka-profile-ride.png")
			# Synchronous screenshot readback is outside the ride measurement.
			previous = Time.get_ticks_usec()

	wall.sort()
	gpu.sort()
	print("native ride seed=4711 region=", main.get("_start_region"))
	print("rendered frame median %.2f p99 %.2f max %.2f ms" % [wall[wall.size()/2], wall[int(wall.size()*.99)], wall.back()])
	print("frames over 16.7 ms: ", spikes.size())
	print("baked audio: ", SoundBank.uses_baked_audio())
	for spike in spikes: print(spike)
	if gpu.back() > 0:
		print("GPU frame median %.2f p99 %.2f max %.2f ms" % [gpu[gpu.size()/2], gpu[int(gpu.size()*.99)], gpu.back()])
	else:
		print("GPU timing unavailable on this renderer")
	main.queue_free()
	await process_frame
	quit()

func _pipelines() -> int:
	var count := 0
	for monitor in [Performance.PIPELINE_COMPILATIONS_MESH, Performance.PIPELINE_COMPILATIONS_SURFACE, Performance.PIPELINE_COMPILATIONS_DRAW, Performance.PIPELINE_COMPILATIONS_SPECIALIZATION]:
		count += int(Performance.get_monitor(monitor))
	return count
