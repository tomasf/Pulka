extends SceneTree
## Cold streaming trace, with a fixed seed and no preloading of a target region.
## Godot --headless --path . --script res://tools/stream_profile.gd -- [frames]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var frames := int(args[0]) if args.size() else 12000
	var world := SlopeWorld.new()
	root.add_child(world)
	var field := TerrainField.new(4711)
	world.reset(field, 0)
	world.profile_builds = true
	var times: Array[float] = []
	var cold: Array[Dictionary] = []
	for frame in frames:
		var d := frame * 0.6
		var began := Time.get_ticks_usec()
		world.update_world(d, 1.0 / 60)
		var us := Time.get_ticks_usec() - began
		times.append(us / 1000.0)
		if us > 8000:
			cold.append({"d": d, "ms": us / 1000.0, "region": TerrainField.Region.keys()[field.region(d)]})
		await process_frame
	times.sort()
	world.build_profile.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.us > b.us)
	print("stream seed=4711 frames=", frames, " distance=", frames * 0.6)
	print("world median %.2f p99 %.2f max %.2f ms" % [times[frames/2], times[int(frames*.99)], times.back()])
	print("frames over 8 ms: ", cold.size())
	for spike in cold: print(spike)
	print("slowest chunk stages (0 heights, 1 surface, 2 scenery, 3 roads, 4 obstacles):")
	for i in mini(20, world.build_profile.size()):
		var event := world.build_profile[i]
		print("chunk %d stage %d %.2f ms region %s" % [event.index, event.stage, event.us/1000.0, TerrainField.Region.keys()[field.region(event.index * SlopeWorld.CHUNK_LENGTH)]])
	world.queue_free()
	await process_frame
	quit()
