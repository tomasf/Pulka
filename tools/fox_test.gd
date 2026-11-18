extends SceneTree
## Actual fox skin/animations, streamed placement, patrol and body-centred flight.
## godot --headless --path . --script res://tools/fox_test.gd
## Native --capture also saves a fox in the real streamed landscape.

var failures := 0

func _initialize() -> void: _run.call_deferred()

func _check(label: String, condition: bool) -> void:
	if not condition:
		failures += 1
		push_error(label)
	else:
		print("PASS ", label)

func _run() -> void:
	var fox := CreatureRig.new("fox")
	root.add_child(fox)
	var weights_ok := true
	var vertices := 0
	for part in fox._meshes:
		for surface in part.mesh.get_surface_count():
			var arrays := part.mesh.surface_get_arrays(surface)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var per := weights.size() / points.size()
			vertices += points.size()
			for i in points.size():
				var total := 0.0
				for k in per: total += weights[i * per + k]
				weights_ok = weights_ok and absf(total - 1.0) < 0.002 and points[i].is_finite()
	_check("exported skin has finite geometry and normalized bone weights", weights_ok)
	_check("fox stays within the moving-animal mesh budget", vertices < 15000)
	var poses := []
	for clip in [&"idle", &"walk", &"flail"]:
		_check("fox has the %s animation" % clip, fox.has(clip))
		var finite := true
		for step in 8:
			var mesh := fox.bake(clip, step / 8.0)
			var box := mesh.get_aabb()
			finite = finite and box.position.is_finite() and box.size.is_finite() and box.size.length() < 3.0
			if clip == &"walk": poses.append(box)
		_check("%s poses retain plausible bounds without stray vertices" % clip, finite)
	_check("travelling fox changes its pose across the stride", poses[0] != poses[2])
	fox.free()
	var world := SlopeWorld.new()
	root.add_child(world)
	var natural_count := 0
	var forest_count := 0
	var wildlife_count := 0
	var moving := true
	for seed_value in [7, 1234, 4711]:
		world.field = TerrainField.new(seed_value)
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		for i in 1000:
			if world._pick_kind(TerrainField.Zone.FOREST, TerrainField.Region.SLOPE, rng) == Obstacle.Kind.FOX: forest_count += 1
			if world._pick_kind(TerrainField.Zone.WILDLIFE, TerrainField.Region.SLOPE, rng) == Obstacle.Kind.FOX: wildlife_count += 1
		var span := Vector3.ZERO
		for cell in 256:
			var candidate := world.field._slot(cell)
			if int(candidate.z) == TerrainField.Region.WOODS:
				span = candidate
				break
		for index in range(ceili(span.x / 50), floori(span.y / 50)):
			var chunk := Chunk.new()
			world.add_child(chunk)
			world._place_obstacles(chunk, rng, index * 50, (index + 1) * 50)
			for obstacle in chunk.obstacles:
				if obstacle.kind != Obstacle.Kind.FOX: continue
				natural_count += 1
				moving = moving and obstacle in chunk.movers and obstacle._creature != null and obstacle.velocity.length() > 1.0
			chunk.free()
	_check("forest and wildlife tables naturally choose foxes", forest_count > 100 and wildlife_count > 100)
	_check("real woods chunks spawn moving, animated foxes", natural_count > 0 and moving)
	print("Naturally spawned foxes in woods: ", natural_count)
	var animal := Obstacle.new().configure(Obstacle.Kind.FOX, world.obstacle_rig(Obstacle.Kind.FOX, RandomNumberGenerator.new()), world.field)
	root.add_child(animal)
	animal.position = Vector3(world.field.center_x(300), 0, -300)
	var centre := animal.position.x
	animal.patrol(2.5, centre - 3, centre + 3)
	var reversals := 0
	var grounded := true
	for frame in 600:
		var before := animal.velocity.x
		animal.tick(1.0 / 60)
		if before * animal.velocity.x < 0: reversals += 1
		grounded = grounded and absf(animal.position.y - world.field.height_world(animal.position.x, animal.position.z)) < 0.001
	_check("fox traverses real terrain and turns at both patrol bounds", reversals >= 3 and grounded and (-animal.basis.z).dot(animal.velocity.normalized()) > 0.99)
	_check("fox participates in ordinary animal collision rules", animal.is_creature() and animal.movable() and not animal.soft)
	_check("fox collider follows the animal's height", animal.overlaps(animal.position + Vector3.UP * 0.5, 0.2) and not animal.overlaps(animal.position + Vector3.UP * 1.2, 0.2))
	animal.position.y += 100
	var initial := animal.transform
	var velocity := Vector3(3, 6, -8)
	animal.launch(velocity)
	animal.set_process(false)
	_check("launch keeps the fox in place", animal.transform.is_equal_approx(initial))
	var expected := animal.transform * animal._flight_pivot
	var stable := true
	for frame in 60:
		velocity.y -= 15.0 / 60
		expected += velocity / 60
		animal._process(1.0 / 60)
		animal.tick(1.0 / 60)
		stable = stable and (animal.transform * animal._flight_pivot).distance_to(expected) < 0.001
	_check("thrown fox rotates around its body and keeps flailing", stable and animal._creature._current == &"flail")
	animal.free()
	world.free()
	await process_frame
	if OS.get_cmdline_user_args().has("--capture"): await _capture()
	print("fox test: %s" % ("all passed" if failures == 0 else "%d failed" % failures))
	quit(failures)

func _capture() -> void:
	root.size = Vector2i(1600, 1000)
	var stage := Node3D.new()
	root.add_child(stage)
	var world := SlopeWorld.new()
	stage.add_child(world)
	var field := TerrainField.new(4711)
	var distance := 350.0
	while field.region(distance) != TerrainField.Region.SLOPE or field.zone(distance) != TerrainField.Zone.FOREST or field.near_road(distance, 40): distance += 5
	world.reset(field, distance)
	var at := Vector3(field.center_x(distance), 0, -distance)
	at.y = field.height_world(at.x, at.z)
	for chunk: Chunk in world._chunks.values():
		for obstacle in chunk.obstacles:
			if obstacle.position.distance_to(at) < 6: obstacle.visible = false
	var fox := Props.fox().make()
	stage.add_child(fox)
	fox.position = at
	fox.rotation.y = 0.4
	(fox as CreatureRig).freeze(&"idle", 0)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = at + Vector3(-2.3, 1.45, -2.8)
	camera.look_at(at + Vector3(0, 0.4, 0.05))
	camera.fov = 36
	camera.current = true
	var atmosphere := Atmosphere.new()
	stage.add_child(atmosphere)
	atmosphere.update_atmosphere(0, camera, 0, distance, false)
	for frame in 12: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/pulka-fox-landscape.png")
	stage.queue_free()
	await process_frame
