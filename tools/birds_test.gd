extends SceneTree
## Foot anchors, foraging, proximity/flight, both riders, seeded streaming
## and native review images. Run with -- --autopilot [--capture].
var failures := 0

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var field := TerrainField.new(4711)
	var d := 300.0
	while not BirdPopulation.ground_allowed(field, field.center_x(d), d): d += 3
	var at := Vector3(field.center_x(d), field.height(field.center_x(d), d) + 0.015, -d)
	var bird := AmbientBird.new().configure(field, at, BirdMeshes.Species.CROW, 8)
	root.add_child(bird)
	var away := PackedVector3Array([at + Vector3(40, 0, 0)])
	var walked := false
	var grounded := true
	for i in 600:
		bird.tick(1.0 / 60, away)
		walked = walked or bird.state == AmbientBird.State.WALKING
		grounded = grounded and absf(bird.position.y - field.height_world(bird.position.x, bird.position.z) - 0.015) < 0.005
	_check("foraging birds walk on the real ground", walked and grounded and bird.position.distance_to(at) > 0.1)
	_check("distant riders do not flush birds", bird.state not in [AmbientBird.State.FLYING, AmbientBird.State.GONE])
	var foot_position := bird.position
	var second := PackedVector3Array([at + Vector3(60, 0, 0), foot_position + Vector3(2, 0, 0)])
	for i in 20:
		bird.tick(1.0 / 60, second, PackedFloat32Array([15, 25]))
		if bird.state == AmbientBird.State.FLYING: break
	_check("either split-screen rider triggers takeoff", bird.state == AmbientBird.State.FLYING)
	_check("takeoff starts at the feet without teleporting", bird.position.distance_to(foot_position) < 0.02)
	var wing_pose := bird._wings[0].rotation.z
	for i in 60: bird.tick(1.0 / 60, second)
	_check("bird climbs and flies away from the approaching rider", bird.position.y > foot_position.y + 2 and bird.position.x < foot_position.x - 3)
	_check("flight uses animated feathered wings", bird._wings[0].visible and absf(bird._wings[0].rotation.z - wing_pose) > 0.01)
	for i in 300: bird.tick(1.0 / 60, second)
	_check("departing birds fade out and stop updating", bird.state == AmbientBird.State.GONE and not bird.visible)
	bird.free()
	var high := AmbientBird.new().configure(field, at + Vector3.UP * 28, BirdMeshes.Species.MAGPIE, 18, true)
	root.add_child(high)
	for i in 40: high.tick(1.0 / 60, PackedVector3Array([at]), PackedFloat32Array([40]))
	_check("height matters when a rider passes far below", high.state == AmbientBird.State.RESTING)
	high.free()
	var world := SlopeWorld.new()
	root.add_child(world)
	world.field = field
	for mesh in [Props.spruce(0), Props.birch(), Props.rock(0), Props.stump()]:
		var chunk := Chunk.new()
		chunk.index = 6
		world.add_child(chunk)
		var anchors: PackedVector3Array = mesh.get_meta(&"bird_perches", PackedVector3Array())
		_check("natural prop has real perch anchors", not anchors.is_empty())
		var xform := Transform3D(Basis(Vector3.UP, 0.6).scaled(Vector3.ONE * 1.3), at)
		var decor := {mesh: [xform]}
		BirdPopulation.populate(world, chunk, decor, d - 10, d + 10)
		var feet_match := true
		var perched := 0
		for seated in chunk.birds:
			if not seated.perched: continue
			perched += 1
			var nearest := INF
			for anchor in anchors: nearest = minf(nearest, seated.position.distance_to(xform * anchor))
			feet_match = feet_match and nearest < 0.002
		_check("perched feet match rotated and scaled scenery", perched > 0 and feet_match)
		chunk.free()
	world.reset(field, 350)
	for i in range(3, 28): world._ensure(i)
	var signature := _signature(world)
	_check("streaming populates several flocks", signature.size() > 15)
	var harmless := true
	for chunk: Chunk in world._chunks.values():
		var collider_ids := {}
		for obstacle in chunk.obstacles: collider_ids[obstacle.get_instance_id()] = true
		for member in chunk.birds:
			harmless = harmless and not collider_ids.has(member.get_instance_id())
	_check("birds do not enter the crash-collision lists", harmless)
	world.reset(TerrainField.new(4711), 350)
	for i in range(3, 28): world._ensure(i)
	_check("bird placement is deterministic", signature == _signature(world))
	for kind in [TerrainField.Region.ICE_CAVE, TerrainField.Region.MALL]:
		var span := Vector3.ZERO
		for cell in 256:
			var candidate := field._slot(cell)
			if int(candidate.z) == kind:
				span = candidate
				break
		world.reset(field, span.x + 100)
		var indoor_birds := 0
		for chunk: Chunk in world._chunks.values():
			for member in chunk.birds:
				if field.region(-member.position.z) == kind: indoor_birds += 1
		_check("no birds spawn inside %s" % TerrainField.Region.keys()[kind], indoor_birds == 0)
	world.queue_free()
	await process_frame
	await process_frame
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_process(false)
	main.set("_vehicle", 0)
	main.set("_autopilot", true)
	main.set("state", 0)
	main.call("_on_hud_pressed", &"duo")
	main.call("_update_world", 1.0 / 60)
	var live: SlopeWorld = main.get("_world")
	var players: Array = main.get("_players")
	_check("live game supplies both riders' real positions", players.size() == 2 and live.bird_observers.size() == 2 and live.bird_observers[1] == players[1].sled.position)
	var sample := AmbientBird.new().configure(live.field, players[0].sled.position + Vector3.RIGHT * 2, BirdMeshes.Species.CROW, 80)
	var owner_chunk: Chunk = live._chunks[floori(players[0].sled.distance() / 50)]
	owner_chunk.add_child(sample)
	owner_chunk.birds.append(sample)
	main.call("_update_world", 1.0 / 60)
	_check("live streamed wildlife reacts to the riders", sample.state == AmbientBird.State.FLYING)
	var before_pause := sample.position
	main.set("state", 3)
	main.call("_process", 0.25)
	_check("pausing also freezes the birds", sample.position == before_pause)
	main.queue_free()
	await process_frame
	await process_frame
	if OS.get_cmdline_user_args().has("--capture"): await _capture(field, at)
	print("birds test: %s" % ("all passed" if failures == 0 else "%d failed" % failures))
	quit(failures)

func _signature(world: SlopeWorld) -> Array:
	var result := []
	var keys := world._chunks.keys()
	keys.sort()
	for key in keys:
		for bird in (world._chunks[key] as Chunk).birds:
			result.append([bird.position, bird.rotation.y, bird.species, bird.perched])
	return result

func _capture(field: TerrainField, at: Vector3) -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var atmosphere := Atmosphere.new()
	stage.add_child(atmosphere)
	var world := SlopeWorld.new()
	stage.add_child(world)
	world.reset(field, -at.z)
	# Keep this review clearing quiet: the real streamed forest remains behind.
	for chunk: Chunk in world._chunks.values():
		for member in chunk.birds: member.visible = false
		for obstacle in chunk.obstacles:
			if obstacle.position.distance_to(at) < 8: obstacle.visible = false
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.current = true
	camera.position = at + Vector3(3.7, 2.0, 4.8)
	camera.look_at(at + Vector3(0, 0.65, -0.4))
	camera.fov = 46
	var birds: Array[AmbientBird] = []
	for info in [[Props.stump(), Vector3(-1.6, 0, -0.2), BirdMeshes.Species.BULLFINCH], [Props.rock(0), Vector3(1.1, 0, -1.5), BirdMeshes.Species.MAGPIE]]:
		var mesh: Mesh = info[0]
		var offset: Vector3 = info[1]
		var base := at + offset
		base.y = field.height_world(base.x, base.z)
		var prop := MeshInstance3D.new()
		prop.mesh = mesh
		prop.position = base
		stage.add_child(prop)
		var anchors: PackedVector3Array = mesh.get_meta(&"bird_perches")
		var member := AmbientBird.new().configure(field, base + anchors[0], info[2], 41 + birds.size(), true)
		member.rotation.y = -0.8
		stage.add_child(member)
		birds.append(member)
	var tree := MeshInstance3D.new()
	tree.mesh = Props.spruce(0)
	tree.position = at + Vector3(-3.1, 0, -2.8)
	tree.position.y = field.height_world(tree.position.x, tree.position.z)
	tree.scale = Vector3.ONE * 0.8
	stage.add_child(tree)
	var tree_anchors: PackedVector3Array = tree.mesh.get_meta(&"bird_perches")
	var branch := tree.transform * tree_anchors[0]
	var tree_bird := AmbientBird.new().configure(field, branch, BirdMeshes.Species.BULLFINCH, 4, true, Vector3.LEFT)
	tree_bird.rotation.y = -0.6
	stage.add_child(tree_bird)
	birds.append(tree_bird)
	for i in 3:
		var base := at + Vector3((i - 1) * 0.75, 0, 0.6 + (i % 2) * 0.5)
		base.y = field.height_world(base.x, base.z) + 0.015
		var member := AmbientBird.new().configure(field, base, BirdMeshes.Species.CROW, 51 + i)
		stage.add_child(member)
		member.rotation.y = -0.7 + i * 0.4
		birds.append(member)
	atmosphere.indoor = true # No near-camera flakes obscuring the review.
	atmosphere.update_atmosphere(0, camera, 0, 0, false)
	for i in 20: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/pulka-birds-resting.png")
	if OS.get_cmdline_user_args().has("--video"):
		DirAccess.make_dir_recursive_absolute("/tmp/pulka-bird-frames")
		for frame in 120:
			var distance := maxf(3, 26 - maxf(0, frame / 30.0 - 0.5) * 16)
			var observer := PackedVector3Array([at + Vector3(0, 0, distance)])
			for substep in 2:
				for member in birds: member.tick(1.0 / 60, observer, PackedFloat32Array([16]))
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/pulka-bird-frames/%04d.png" % frame)
	else:
		for member in birds: member.startle(at + Vector3(0, 0, 3))
	for i in 27:
		for member in birds: member.tick(1.0 / 60, PackedVector3Array())
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/pulka-birds-takeoff.png")
	stage.queue_free()
	await process_frame
	await process_frame

func _check(message: String, condition: bool) -> void:
	print(("  ok    " if condition else "  FAIL  ") + message)
	if not condition: failures += 1
