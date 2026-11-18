extends SceneTree
## The waving arm must not drag trousers, coat hem or opposite sleeve.
## Checks the exported skin and the same CPU poses used for static crowds.
var failures := 0

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var person := CreatureRig.new("person")
	var skeleton: Skeleton3D = person._skeleton
	var garments := 0
	var clean := true
	var triangles := 0
	for mesh in person._meshes:
		for surface in mesh.mesh.get_surface_count(): triangles += mesh.mesh.surface_get_array_index_len(surface) / 3
		var allowed: Array[String] = []
		if mesh.name == "pants": allowed = ["hips", "thigh.L", "thigh.R", "shin.L", "shin.R"]
		elif mesh.name == "jacket_body": allowed = ["hips", "spine", "neck"]
		elif mesh.name.begins_with("sleeve_"):
			var side := String(mesh.name).get_slice("_", 1)
			allowed = ["upper_arm." + side, "forearm." + side]
		if allowed.is_empty(): continue
		garments += 1
		for surface in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			for i in bones.size():
				if weights[i] < 0.0001: continue
				var bone := mesh.skin.get_bind_bone(bones[i])
				if bone < 0: bone = skeleton.find_bone(mesh.skin.get_bind_name(bones[i]))
				clean = clean and allowed.has(skeleton.get_bone_name(bone))
	_check("all four garments bind only to their own anatomical joints", garments == 4 and clean)
	_check("smooth trousers keep the crowd model below 14000 triangles (%d)" % triangles, triangles <= 14000)
	var reference := person.bake(&"wave", 0)
	var fixed_surfaces: Array[int] = []
	var surface_index := 0
	for mesh in person._meshes:
		for surface in mesh.mesh.get_surface_count():
			if mesh.name in ["pants", "jacket_body", "trunks", "scarf", "hood"]: fixed_surfaces.append(surface_index)
			surface_index += 1
	var stays_put := true
	var natural_height := true
	var all_finite := true
	for clip in [&"wave", &"walk", &"idle", &"flail"]:
		_check("person retains the %s animation" % clip, person.has(clip))
		for step in 8:
			var baked := person.bake(clip, step / 8.0)
			for surface in baked.get_surface_count():
				var vertices: PackedVector3Array = baked.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				for v in vertices: all_finite = all_finite and v.is_finite()
				if clip == &"wave" and fixed_surfaces.has(surface):
					var rest: PackedVector3Array = reference.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
					for i in vertices.size(): stays_put = stays_put and vertices[i].distance_to(rest[i]) < 0.0001
					var material := baked.surface_get_material(surface) as StandardMaterial3D
					if material.resource_name in ["pants", "trunks"]:
						for v in vertices: natural_height = natural_height and v.y < 1.1
	_check("waist, trousers, scarf and hood stay put throughout a wave", stays_put and fixed_surfaces.size() >= 5)
	_check("waving cannot stretch trousers up to the shoulder", natural_height)
	_check("all animated poses have finite geometry", all_finite)
	person.free()
	print("person pose test: %s" % ("all passed" if failures == 0 else "%d failed" % failures))
	quit(failures)

func _check(message: String, condition: bool) -> void:
	print(("  ok    " if condition else "  FAIL  ") + message)
	if not condition: failures += 1
