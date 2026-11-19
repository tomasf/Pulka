extends SceneTree
## Bake the exact existing procedural models and crowd poses ahead of device
## export. A cache miss still uses the normal procedural builder at runtime.
func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	Props.use_baked_world = false
	Props._cache.clear()
	Props._baked.clear()
	Props._crowd.clear()
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
		var rig := Props.person(i % Palette.JACKETS.size(), i)
		Props.baked(rig, i * TAU / 8)
		Props.crowd_mesh(rig, i * TAU / 8)
	# Generate distance LODs offline. Keep the original near geometry and all
	# placement metadata, and never simplify custom vertex animation formats.
	var lod_count := 0
	for key in Props._cache:
		var source: ArrayMesh = Props._cache[key]
		if source.get_surface_count() != 1 or source.surface_get_format(0) & Mesh.ARRAY_FORMAT_CUSTOM0: continue
		var importer := ImporterMesh.new()
		importer.add_surface(source.surface_get_primitive_type(0), source.surface_get_arrays(0), [], {}, source.surface_get_material(0))
		importer.generate_lods(25, 60, [])
		var optimized := importer.get_mesh()
		optimized.shadow_mesh = _shadow_mesh(importer)
		var before := source.surface_get_arrays(0)
		var after := optimized.surface_get_arrays(0)
		# Packed normals/tangents can round again when ArrayMesh re-encodes
		# them. Geometry, colours and near-detail indices stay identical.
		for attribute in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_COLOR, Mesh.ARRAY_INDEX]:
			assert(before[attribute] == after[attribute], str(key, " ", attribute))
		var normals: PackedVector3Array = before[Mesh.ARRAY_NORMAL]
		var encoded: PackedVector3Array = after[Mesh.ARRAY_NORMAL]
		for i in normals.size(): assert(normals[i].distance_to(encoded[i]) < 0.001, key)
		for meta in source.get_meta_list(): optimized.set_meta(meta, source.get_meta(meta))
		Props._cache[key] = optimized
		if importer.get_surface_lod_count(0) > 0: lod_count += 1
	print("Prepared distance LODs for ", lod_count, " shared meshes")
	for key in Props._crowd:
		var source: ArrayMesh = Props._crowd[key]
		var importer := ImporterMesh.new()
		importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, source.surface_get_arrays(0), [], {}, source.surface_get_material(0), "", Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		importer.generate_lods(25, 60, [])
		var optimized := importer.get_mesh()
		optimized.shadow_mesh = _shadow_mesh(importer)
		Props._crowd[key] = optimized
	var archive := Resource.new()
	archive.set_meta("meshes", Props._cache)
	archive.set_meta("poses", Props._baked)
	archive.set_meta("crowd", Props._crowd)
	var splash := Splash.prepared_resources()
	archive.set_meta("effects", {"splash": splash})
	# Deserializing ArrayMeshes requests their render pipelines in Godot.
	# Include the terrain-specific materials too, ahead of first visibility.
	var pipeline_meshes: Array[ArrayMesh] = []
	for primitive: PrimitiveMesh in [splash.drop, splash.ring]:
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, primitive.get_mesh_arrays())
		mesh.surface_set_material(0, primitive.material)
		pipeline_meshes.append(mesh)
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
	for category in ["meshes", "poses", "crowd"]:
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


## Depth-only geometry can share coincident vertices across colour/normal
## seams. Remap every LOD too, retaining the exact shadow silhouette.
func _shadow_mesh(importer: ImporterMesh) -> ArrayMesh:
	var source := importer.get_surface_arrays(0)
	var vertices: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
	var unique := {}
	var positions := PackedVector3Array()
	var remap := PackedInt32Array()
	for point in vertices:
		if not unique.has(point):
			unique[point] = positions.size()
			positions.append(point)
		remap.append(unique[point])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_INDEX] = _remap_indices(source[Mesh.ARRAY_INDEX], remap)
	var lods := {}
	for lod in importer.get_surface_lod_count(0):
		lods[importer.get_surface_lod_size(0, lod)] = _remap_indices(importer.get_surface_lod_indices(0, lod), remap)
	var shadow := ArrayMesh.new()
	shadow.add_surface_from_arrays(importer.get_surface_primitive_type(0), arrays, [], lods)
	return shadow


func _remap_indices(indices: PackedInt32Array, remap: PackedInt32Array) -> PackedInt32Array:
	var result := PackedInt32Array()
	result.resize(indices.size())
	for i in indices.size(): result[i] = remap[indices[i]]
	return result
