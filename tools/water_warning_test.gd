extends SceneTree
## Warning face, unchanged bridge sign and deterministic approach placement.
## Run natively with -- --capture to save face/context images under /tmp.
var failures := 0

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	AudioServer.set_bus_mute(0, true)
	Props.use_baked_world = false
	var sign := Props.water_warning_sign()
	var arrays := sign.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var inside := true
	var ink_vertices := 0
	for i in vertices.size():
		inside = inside and vertices[i].is_finite() and normals[i].is_finite()
		if colours[i].r > 0.02 or colours[i].g > 0.02 or colours[i].b > 0.02: continue
		ink_vertices += 1
		var p := Vector2(vertices[i].x, vertices[i].y - 2.05)
		# Independent half-plane bounds of the existing yellow triangular face.
		var t := (p.y - 42.5199 * 0.004) / ((356.838 - 42.5199) * 0.004)
		inside = inside and t >= -0.0001 and t <= 1.0001 and absf(p.x) <= (1 - t) * 181.4721 * 0.004 + 0.0001
		inside = inside and normals[i].dot(Vector3.BACK) > 0.999
	_check("all snowracer/quay/wave ink faces riders and fits inside yellow", inside and ink_vertices > 500)
	if ResourceLoader.exists(Props.BAKED_WORLD):
		var archive: Resource = load(Props.BAKED_WORLD)
		var old: ArrayMesh = archive.get_meta("meshes")["road_narrows_sign"]
		var reference := old.surface_get_arrays(0)
		var current := Props.road_narrows_sign().surface_get_arrays(0)
		_check("shared warning plate preserves the bridge sign exactly", reference == current)
	var review: SlopeWorld
	var review_strip := Vector2.ZERO
	for seed_value in [7, 1234, 4711]:
		var field := TerrainField.new(seed_value)
		var span := Vector3.ZERO
		for cell in 256:
			var candidate := field._slot(cell)
			if int(candidate.z) == TerrainField.Region.LAKE:
				span = candidate
				break
		var strip := field.water_strip(span.x + 100)
		var d := strip.x - LakeWater.WARNING_DISTANCE
		var world := SlopeWorld.new()
		root.add_child(world)
		world.field = field
		var chunk := Chunk.new()
		world.add_child(chunk)
		var decor := {}
		LakeWater.populate(world, chunk, decor, d - 0.5, d + 0.5, span)
		var placements: Array = decor.get(sign, [])
		var valid := placements.size() == 2
		var sides := 0.0
		for at: Transform3D in placements:
			var point := at.origin
			var lateral := point.x - field.center_x(-point.z)
			sides += signf(lateral)
			valid = valid and absf(-point.z - d) < 0.01 and absf(absf(lateral) - field.half_width(d) - 1.2) < 0.001
			valid = valid and not field.is_water(d, point.x) and absf(point.y - field.height(point.x, d, false)) < 0.001
			valid = valid and at.basis.z.dot(Vector3(-field.center_slope(d), 0, 1).normalized()) > 0.99
		_check("seed %d: grounded warnings flank the track 32 m before water" % seed_value, valid and sides == 0)
		var adjacent := {}
		LakeWater.populate(world, chunk, adjacent, d - 50, d, span)
		LakeWater.populate(world, chunk, adjacent, d + 0.01, d + 1, span)
		_check("adjacent chunks do not duplicate warnings", not adjacent.has(sign))
		world.reset(field, d)
		var count := 0
		for tile: Chunk in world._chunks.values():
			for child in tile.get_children():
				if child is MultiMeshInstance3D and child.multimesh.mesh == sign: count += child.multimesh.instance_count
		_check("actual streamed world contains the pair", count == 2)
		if seed_value == 4711:
			review = world
			review_strip = strip
		else: world.free()
	if OS.get_cmdline_user_args().has("--capture"): await _capture(review, review_strip, sign)
	review.free()
	await process_frame
	print("water warning test: %s" % ("all passed" if failures == 0 else "%d failed" % failures))
	quit(failures)


func _capture(world: SlopeWorld, strip: Vector2, mesh: Mesh) -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(900, 900)
	root.msaa_3d = Viewport.MSAA_4X
	world.visible = false
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("edf1f5")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.8
	root.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -25, 0)
	sun.light_energy = 0.8
	root.add_child(sun)
	var face := MeshInstance3D.new()
	face.mesh = mesh
	root.add_child(face)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.04
	camera.position = Vector3(0, 2.86, 5)
	camera.look_at(Vector3(0, 2.86, 0))
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/pulka-water-warning-front.png")
	face.free()
	world.visible = true
	root.size = Vector2i(1600, 1000)
	environment.environment.background_mode = Environment.BG_SKY
	environment.environment.sky = Sky.new()
	environment.environment.sky.sky_material = ProceduralSkyMaterial.new()
	for i in 100: world.regions.prepare_floors(Time.get_ticks_usec() + 100000)
	var d := strip.x - LakeWater.WARNING_DISTANCE
	var x := world.field.center_x(d) + world.field.half_width(d) + 1.2
	var target := Vector3(x, world.field.height(x, d, false) + 2.80, -d)
	var facing := Basis(Vector3.UP, -world.street_yaw(d))
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 55
	camera.position = target + facing * Vector3(-3.5, 0.4, 8.5)
	camera.look_at(target + facing * Vector3(-1.5, 0, -1))
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/pulka-water-warning-lake.png")
	camera.free()
	sun.free()
	environment.free()


func _check(message: String, condition: bool) -> void:
	print(("  ok    " if condition else "  FAIL  ") + message)
	if not condition: failures += 1
