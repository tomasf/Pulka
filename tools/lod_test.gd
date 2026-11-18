extends SceneTree
## Baked detail levels, exact depth silhouettes and pre-imported paint flags.
## Native -- --capture compares a static forest with LODs disabled/enabled.
var failures := 0

func _initialize() -> void: _run.call_deferred()

func _check(label: String, condition: bool) -> void:
	if not condition:
		failures += 1
		push_error(label)
	else: print("PASS ", label)

func _run() -> void:
	for kind in ["moose", "deer", "reindeer", "dog", "hare", "bear", "fox", "cat", "person", "rider"]:
		var scene: PackedScene = load("res://models/%s.glb" % kind)
		var model := scene.instantiate()
		var ready := true
		for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			for surface in part.mesh.get_surface_count():
				if part.mesh.surface_get_format(surface) & Mesh.ARRAY_FORMAT_COLOR:
					ready = ready and (part.mesh.surface_get_material(surface) as StandardMaterial3D).vertex_color_use_as_albedo
		_check("%s paint is ready before the first CreatureRig is created" % kind, ready)
		model.free()
	for mesh: ArrayMesh in [Props.spruce(0), Props.spruce(1), Props.birch(), Props.house(0), Props.town_house(0), Props.crowd_mesh(Props.person(0), 0)]:
		var importer := ImporterMesh.from_mesh(mesh)
		var shadow := mesh.shadow_mesh
		_check("exported mesh has lower-detail indices and welded depth geometry", importer.get_surface_lod_count(0) > 0 and shadow != null)
		if shadow == null: continue
		var source := mesh.surface_get_arrays(0)
		var depth := shadow.surface_get_arrays(0)
		var points: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
		var positions: PackedVector3Array = depth[Mesh.ARRAY_VERTEX]
		var a: PackedInt32Array = source[Mesh.ARRAY_INDEX]
		var b: PackedInt32Array = depth[Mesh.ARRAY_INDEX]
		var exact := a.size() == b.size()
		for i in a.size(): exact = exact and points[a[i]] == positions[b[i]]
		_check("depth mesh retains the full-detail triangle silhouette", exact and positions.size() <= points.size())
		var depth_importer := ImporterMesh.from_mesh(shadow)
		var lods := importer.get_surface_lod_count(0)
		var valid := depth_importer.get_surface_lod_count(0) == lods
		for lod in lods:
			a = importer.get_surface_lod_indices(0, lod)
			b = depth_importer.get_surface_lod_indices(0, lod)
			valid = valid and a.size() == b.size() and a.size() < source[Mesh.ARRAY_INDEX].size()
			for i in a.size(): valid = valid and points[a[i]] == positions[b[i]]
		_check("every lower-detail shadow matches its colour pass", valid)
	_check("animated car custom attributes keep their original mesh path", Props.car(0).surface_get_format(0) & Mesh.ARRAY_FORMAT_CUSTOM0 and Props.car(0).shadow_mesh == null)
	if DisplayServer.get_name() != "headless" and OS.get_cmdline_user_args().has("--capture"): await _capture()
	print("LOD test: %s" % ("all passed" if failures == 0 else "%d failed" % failures))
	quit(failures)

func _capture() -> void:
	Quality.force_tv = true
	root.size = Vector2i(1600, 900)
	var field := TerrainField.new(4711)
	var distance := 0.0
	for slot in 256:
		var span := field._slot(slot)
		if int(span.z) == TerrainField.Region.WOODS:
			distance = span.x + 50
			break
	var world := SlopeWorld.new()
	root.add_child(world)
	world.reset(field, distance)
	for index in range(floori(distance / 50), floori(distance / 50) + 11): world._ensure(index)
	for chunk: Chunk in world._chunks.values():
		for obstacle in chunk.obstacles:
			if obstacle._creature != null: obstacle._creature.freeze(&"idle", 0)
	var camera := Camera3D.new()
	root.add_child(camera)
	var at := Vector3(field.center_x(distance), field.height(field.center_x(distance), distance), -distance)
	camera.position = at + Vector3(0, 3.5, 7)
	var ahead := Vector3(field.center_x(distance + 18), field.height(field.center_x(distance + 18), distance + 18) + 1, -distance - 18)
	camera.look_at(ahead)
	camera.fov = 60
	camera.current = true
	var atmosphere := Atmosphere.new()
	root.add_child(atmosphere)
	atmosphere.update_atmosphere(0, camera, distance, 0, false)
	atmosphere._snow.emitting = false
	atmosphere._snow.visible = false
	for frame in 30: await process_frame
	var shots: Array[Image] = []
	var triangles := []
	for threshold in [0, 1]:
		root.mesh_lod_threshold = threshold
		for frame in 8: await process_frame
		await RenderingServer.frame_post_draw
		shots.append(root.get_texture().get_image())
		triangles.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		shots.back().save_png("/tmp/pulka-forest-lod-%d.png" % threshold)
	var difference := 0.0
	for y in shots[0].get_height():
		for x in shots[0].get_width():
			var a := shots[0].get_pixel(x, y)
			var b := shots[1].get_pixel(x, y)
			difference += (absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)) / 3
	difference /= shots[0].get_width() * shots[0].get_height()
	print("forest LOD comparison: triangles ", triangles, " mean pixel difference ", difference)
	_check("distance details reduce rendered geometry", triangles[1] < triangles[0] * .8)
	_check("distance simplification retains the forest appearance", difference < .01)
	world.free()
	atmosphere.free()
	camera.free()
	await process_frame
