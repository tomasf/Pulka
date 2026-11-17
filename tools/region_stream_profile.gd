extends SceneTree
## Profile cold entry, traversal and exit with normal frame budgets.
## -- cave / -- harbor / -- sewer; world-only, independent of saved ride selection.
func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var kind: int = {"cave": TerrainField.Region.ICE_CAVE, "harbor": TerrainField.Region.HARBOR, "sewer": TerrainField.Region.SEWER}.get(args[0] if not args.is_empty() else "cave", TerrainField.Region.ICE_CAVE)
	var field := TerrainField.new(4711)
	var span := Vector3.ZERO
	for cell in 256:
		var candidate := field._slot(cell)
		if int(candidate.z) == kind:
			span = candidate
			break
	assert(span != Vector3.ZERO)
	var world := SlopeWorld.new()
	root.add_child(world)
	world.reset(field, span.x - 230)
	world.profile_builds = true
	var times: Array[float] = []
	var worst := Vector2.ZERO
	var missing := false
	for frame in 1000:
		var d := span.x - 230 + frame * 0.65
		world.bird_observers = PackedVector3Array([Vector3(field.center_x(d), field.height(field.center_x(d), d), -d)])
		world.bird_speeds = PackedFloat32Array([39])
		var started := Time.get_ticks_usec()
		world.update_world(d, 1.0 / 60)
		var ms := (Time.get_ticks_usec() - started) / 1000.0
		times.append(ms)
		if ms > worst.y: worst = Vector2(d - span.x, ms)
		# Surfaces must be visible before the rider reaches them.
		var chunk: Chunk = world._chunks.get(floori(d / 50))
		if chunk:
			for child in chunk.get_children():
				if child is MeshInstance3D and child.name in ["IceCavern", "HarborRoutes", "HarborWater", "SewerPipe", "SewerStream", "SewerEmbankment"] and child.mesh == null:
					missing = true
		await process_frame
	times.sort()
	print("%s streaming: median %.2f p99 %.2f max %.2f ms at region offset %.1f" % [TerrainField.Region.keys()[kind], times[500], times[990], times.back(), worst.x])
	print("surfaces ready before arrival: ", not missing)
	world.build_profile.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.us > b.us)
	for event in world.build_profile.slice(0, 5):
		print("  stage %d %.2f ms offset %.1f" % [event.stage, event.us / 1000.0, event.index * 50 - span.x])
	world.queue_free()
	await process_frame
	await process_frame
	quit(1 if missing else 0)
