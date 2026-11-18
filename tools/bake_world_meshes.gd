extends SceneTree
## Bake the exact existing procedural models and crowd poses ahead of device
## export. A cache miss still uses the normal procedural builder at runtime.
func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	Props.use_baked_world = false
	Props._cache.clear()
	Props._baked.clear()
	var world := SlopeWorld.new()
	root.add_child(world)
	for seed_value in [7, 1234, 4711]:
		var field := TerrainField.new(seed_value)
		for kind in TerrainField.REGION_STYLE:
			var span := Vector3.ZERO
			for cell in 256:
				var candidate := field._slot(cell)
				if int(candidate.z) == kind:
					span = candidate
					break
			assert(span != Vector3.ZERO)
			world.reset(field, span.x - 100)
			for i in range(floori((span.x - 100) / 50), ceili((span.y + 100) / 50)): world._ensure(i)
			while not Props._pose_order.is_empty(): Props.prepare_poses(Time.get_ticks_usec() + 1000000)
			# Floor/pipe meshes are unique to their terrain, so do not store
			# them. Only shared props and frozen crowd poses enter the archive.
			print("Baked ", seed_value, " ", TerrainField.Region.keys()[kind], " meshes=", Props._cache.size(), " poses=", Props._baked.size())
			await process_frame
	# Cover the finite decorative variant sets independently of the seeds.
	for variant in 12: Props.town_house(variant)
	for variant in 10: Props.house(variant)
	for variant in CarModels.variant_count(): Props.car(variant)
	for span_width in range(7, 49):
		Props.light_string(span_width)
		Props.footbridge(span_width)
	for variant in 2: SewerRat.body(variant)
	for i in 8:
		var rig := Props.person(i % Palette.JACKETS.size())
		Props.baked(rig, i * TAU / 8)
	var archive := Resource.new()
	archive.set_meta("meshes", Props._cache)
	archive.set_meta("poses", Props._baked)
	# Deserializing ArrayMeshes requests their render pipelines in Godot.
	# Include the terrain-specific materials too, ahead of first visibility.
	var pipeline_meshes: Array[ArrayMesh] = []
	for material in [IceCavern.material(), ContainerHarbor.water_material(), LakeWater.material(), SewerPipe.concrete(), SewerPipe.sewage(), SewerPipe.earth()]:
		var m := MeshKit.new()
		m.box(Vector3.ONE, Vector3.ZERO, Color.WHITE)
		var mesh := m.build()
		mesh.surface_set_material(0, material)
		pipeline_meshes.append(mesh)
	var aurora := ShaderMaterial.new()
	aurora.shader = load("res://shaders/aurora.gdshader")
	for material in [ContainerHarbor.water_material(), aurora]:
		var plane := PlaneMesh.new()
		# PrimitiveMesh uses uncompressed arrays, unlike imported meshes.
		for flags in [0, Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES]:
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, plane.get_mesh_arrays(), [], {}, flags)
			mesh.surface_set_material(0, material)
			pipeline_meshes.append(mesh)
	# Match Label3D's spatial text material and vertex format, including the
	# shaded runway numbers. Shader variants otherwise compile on first use.
	for shaded in [false, true]:
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL if shaded else BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.vertex_color_is_srgb = true
		material.vertex_color_use_as_albedo = true
		material.texture_repeat = false
		var plane := PlaneMesh.new()
		var arrays := plane.get_mesh_arrays()
		arrays[Mesh.ARRAY_COLOR] = PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, material)
		pipeline_meshes.append(mesh)
	archive.set_meta("pipeline_meshes", pipeline_meshes)
	DirAccess.make_dir_recursive_absolute("res://generated/world_meshes")
	var error := ResourceSaver.save(archive, Props.BAKED_WORLD, ResourceSaver.FLAG_COMPRESS)
	assert(error == OK, error_string(error))
	# Verify that serialization preserves rendered vertex/index data and the
	# material-name metadata used to dress each crowd member individually.
	var loaded: Resource = ResourceLoader.load(Props.BAKED_WORLD, "", ResourceLoader.CACHE_MODE_IGNORE)
	for category in ["meshes", "poses"]:
		var original: Dictionary = archive.get_meta(category)
		var restored: Dictionary = loaded.get_meta(category)
		assert(original.size() == restored.size())
		for key in original:
			var a: ArrayMesh = original[key]
			var b: ArrayMesh = restored[key]
			assert(a.get_surface_count() == b.get_surface_count(), key)
			for surface in a.get_surface_count():
				assert(a.surface_get_arrays(surface) == b.surface_get_arrays(surface), key)
			for meta in a.get_meta_list(): assert(a.get_meta(meta) == b.get_meta(meta), str(key, " ", meta))
	print("World cache verified: ", Props._cache.size(), " meshes, ", Props._baked.size(), " poses")
	world.queue_free()
	await process_frame
	quit()
