extends SceneTree
## Real house anchors, seeded streaming, bounded roaming and cat animations.
## Native --capture saves the actual spawned cats beside their homes.
var failures := 0

func _initialize() -> void: _run.call_deferred()

func _check(label: String, condition: bool) -> void:
	if not condition:
		failures += 1
		push_error(label)
	else: print("PASS ", label)

func _run() -> void:
	var shades := []
	for variant in 3:
		var cat := Props.cat(variant).make()
		root.add_child(cat)
		var skin_ok := true
		var painted_bib := false
		var vertices := 0
		for part in cat._meshes:
			for surface in part.mesh.get_surface_count():
				var arrays := part.mesh.surface_get_arrays(surface)
				var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
				var per := weights.size() / points.size()
				vertices += points.size()
				for i in points.size():
					var total := 0.0
					for k in per: total += weights[i * per + k]
					skin_ok = skin_ok and points[i].is_finite() and absf(total - 1) < 0.002
				var material := part.get_active_material(surface) as StandardMaterial3D
				if material.resource_name == "cat coat": shades.append(material.albedo_color)
				if material.resource_name == "cat white":
					var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
					var dim := 1.0
					var bright := 0.0
					for colour in colours:
						dim = minf(dim, colour.r)
						bright = maxf(bright, colour.r)
					painted_bib = material.vertex_color_use_as_albedo and bright - dim > .2
		_check("cat %d has a finite normalized skin within the animal mesh budget" % variant, skin_ok and vertices < 15000)
		_check("cat %d retains painted shading across the pale coat" % variant, painted_bib)
		for clip in [&"idle", &"walk", &"flail"]:
			var poses_ok := cat.has(clip)
			for step in 8:
				var box := cat.bake(clip, step / 8.0).get_aabb()
				poses_ok = poses_ok and box.position.is_finite() and box.size.is_finite() and box.size.length() < 1.7
			_check("cat %d %s poses keep all parts with the body" % [variant, clip], poses_ok)
		cat.free()
	_check("all three cats have distinct coats", shades.size() == 3 and shades[0] != shades[1] and shades[1] != shades[2])
	var world := SlopeWorld.new()
	root.add_child(world)
	var total := 0
	var walkers := 0
	var still := 0
	for seed_value in [7, 1234, 4711]:
		var field := TerrainField.new(seed_value)
		var town := _span(field, TerrainField.Region.TOWN)
		world.reset(field, town.x + 100)
		for i in range(ceili(town.x / 50), floori(town.y / 50)): world._ensure(i)
		var signature := _signature(world)
		_check("town seed %d spawns cats beside actual homes" % seed_value, not signature.is_empty())
		var valid := true
		var collision := true
		for chunk: Chunk in world._chunks.values():
			for cat in chunk.obstacles:
				if cat.kind != Obstacle.Kind.CAT: continue
				total += 1
				if cat.velocity == Vector3.ZERO: still += 1
				else: walkers += 1
				collision = collision and cat in chunk.movers and cat.is_creature() and cat.movable() and cat.overlaps(cat.position + Vector3.UP * .3, .2) and not cat.overlaps(cat.position + Vector3.UP, .2)
				for frame in 900:
					cat.tick(1.0 / 30)
					valid = valid and _near_home(cat.position, chunk) and _outside_homes(cat.position, chunk) and cat.position.is_finite()
					valid = valid and absf(cat.position.y - field.height_world(cat.position.x, cat.position.z)) < .001
		_check("seed %d cats stay near houses and on the ground through repeated turns" % seed_value, valid)
		_check("seed %d cats use the shared movement and collision lists" % seed_value, collision)
		world.reset(field, town.x + 100)
		for i in range(ceili(town.x / 50), floori(town.y / 50)): world._ensure(i)
		_check("seed %d reproduces the same cats after rebuilding" % seed_value, signature == _signature(world))
	_check("town population mixes wandering and stationary cats", total > 4 and walkers > 0 and still > 0)
	# A test override may raise their frequency, but must not create cats in
	# the wilderness, shops, tunnels or roof region without ground-level homes.
	world.forced_kind = Obstacle.Kind.CAT
	var forbidden := 0
	for kind in [TerrainField.Region.WOODS, TerrainField.Region.MALL, TerrainField.Region.SEWER, TerrainField.Region.ICE_CAVE, TerrainField.Region.ROOFS]:
		var span := _span(world.field, kind)
		world.reset(world.field, span.x + 100)
		for chunk: Chunk in world._chunks.values():
			for cat in chunk.obstacles:
				if cat.kind == Obstacle.Kind.CAT and world.field.region(-cat.position.z) == kind: forbidden += 1
	_check("even --spawn=cat respects the residential-only rule", forbidden == 0)
	# Exercise the actual rural wooden-house scenery path too.
	var rural := 0
	for seed_value in [7, 1234, 4711]:
		world.field = TerrainField.new(seed_value)
		for index in range(4, 40):
			if world.field.region(index * 50 + 25) != TerrainField.Region.SLOPE: continue
			var chunk := Chunk.new()
			chunk.index = index
			world.add_child(chunk)
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(Vector2i(seed_value, index))
			world._place_scenery(chunk, {}, rng, index * 50, (index + 1) * 50)
			CatPopulation.populate(world, chunk)
			for cat in chunk.obstacles:
				if cat.kind == Obstacle.Kind.CAT:
					rural += 1
					_check("rural cat is tied to a placed wooden house", _near_home(cat.position, chunk) and _outside_homes(cat.position, chunk))
			chunk.free()
	_check("rural houses can have cats too", rural > 0)
	world.forced_kind = -1
	if OS.get_cmdline_user_args().has("--capture"):
		var town := _span(world.field, TerrainField.Region.TOWN)
		world.reset(world.field, town.x + 100)
		for i in range(ceili(town.x / 50), floori(town.y / 50)): world._ensure(i)
		await _capture(world)
	world.free()
	await process_frame
	print("cat test: %s (%d town, %d rural)" % ["all passed" if failures == 0 else "%d failed" % failures, total, rural])
	quit(failures)

func _span(field: TerrainField, kind: TerrainField.Region) -> Vector3:
	for cell in 256:
		var candidate := field._slot(cell)
		if int(candidate.z) == kind: return candidate
	return Vector3.ZERO

func _near_home(point: Vector3, chunk: Chunk) -> bool:
	for home in chunk.homes:
		if Vector2(point.x - home.origin.x, point.z - home.origin.z).length() <= CatPopulation.HOME_RADIUS + .05: return true
	return false

func _outside_homes(point: Vector3, chunk: Chunk) -> bool:
	for home in chunk.homes:
		var local := home.affine_inverse() * point
		if absf(local.x) < 5.5 and absf(local.z) < 5.5: return false
	return true

func _signature(world: SlopeWorld) -> Array:
	var result := []
	var indices := world._chunks.keys()
	indices.sort()
	for index in indices:
		for cat in (world._chunks[index] as Chunk).obstacles:
			if cat.kind == Obstacle.Kind.CAT: result.append([index, cat.position, cat.velocity, cat._rig.colours])
	return result

func _capture(world: SlopeWorld) -> void:
	root.size = Vector2i(1600, 1000)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	var atmosphere := Atmosphere.new()
	root.add_child(atmosphere)
	for chunk: Chunk in world._chunks.values():
		for cat in chunk.obstacles:
			if cat.kind != Obstacle.Kind.CAT: continue
			var home := chunk.homes[0]
			var nearest := INF
			for candidate in chunk.homes:
				var distance := candidate.origin.distance_to(cat.position)
				if distance < nearest:
					nearest = distance
					home = candidate
			cat._creature.freeze(&"idle", 0)
			cat.rotation.y = home.basis.get_euler().y
			for shot in 2:
				var offset := Vector3(-1.4, .85, -2.0) if shot == 0 else Vector3(-6, 3, -8)
				camera.position = cat.position + home.basis * offset
				camera.look_at(cat.position + Vector3.UP * (.3 if shot == 0 else 1.5))
				camera.fov = 40
				atmosphere.update_atmosphere(0, camera, 0, -cat.position.z, false)
				for frame in 10: await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("/tmp/pulka-cat-home-%d.png" % shot)
			camera.free()
			atmosphere.free()
			return
