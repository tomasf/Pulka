extends SceneTree
## Offline review of the actual game assets. Run with the mobile renderer:
## godot --path . --script res://tools/model_atlas.gd -- /absolute/output [512]
## Then run compose_model_atlas.py on that output directory.
## Bake the world cache first with tools/bake_world_meshes.gd after model edits.
## ATLAS_RESUME=1 reuses existing frames after an interrupted render.
## ATLAS_ONLY=41,42 renders only the requested review numbers.
const Gallery = preload("res://tools/gallery.gd")
var entries: Array[Dictionary] = []
var field := TerrainField.new(4711)
var spans := {}


func _initialize() -> void:
	_run.call_deferred()


func _add(key: String, label: String, group: String, builder: Callable) -> void:
	entries.append({"key": key, "label": label, "group": group, "builder": builder})


func _figure(rig: Props.Rig, animation: String, fraction := 0.25) -> Node3D:
	var node := rig.make()
	assert(node.has(animation), "%s missing %s" % [rig.kind, animation])
	node.set_meta("after_add", func() -> void: node.freeze(animation, fraction))
	return node


func _bird(species: int, flying: bool) -> Node3D:
	var bird := AmbientBird.new().configure(field, Vector3.ZERO, species, 4711)
	bird.transform = Transform3D.IDENTITY
	if flying:
		bird.state = AmbientBird.State.FLYING
		bird._body.mesh = bird._flight_mesh
		for wing in bird._wings: wing.visible = true
		bird.flight_time = 0.10
		bird._phase = 0
		bird._pose(0)
	return bird


func _rat(variant: int) -> Node3D:
	var span: Vector3 = spans[TerrainField.Region.SEWER]
	var d := span.x + 100
	var x := field.center_x(d)
	var rat := SewerRat.new().configure(field, Vector3(x, field.sewer_floor(x, d), -d), 4711, [])
	rat._body.mesh = SewerRat.body(variant)
	rat.transform = Transform3D.IDENTITY
	return rat


func _region(kind: int) -> Node3D:
	var model := SlopeWorld.new()
	model.field = field
	var span: Vector3 = spans[kind]
	# A real streamed section, with the same meshes, scenery and obstacles as play.
	# Starting at the entrance makes cave/sewer portals visible as well.
	var first := floori((span.x + 15) / SlopeWorld.CHUNK_LENGTH)
	for i in range(first, first + 3): model._ensure(i)
	for actor in model._free:
		# Taxiway vehicles receive their ground height on the first game tick.
		if actor is AirportTaxiway: actor.tick(0, span.x)
	for i in 500:
		model.regions.prepare_floors(Time.get_ticks_usec() + 1000000)
		Props.prepare_poses(Time.get_ticks_usec() + 1000000)
	model.set_meta("overview", true)
	return model


func _scenery(key: String, mesh: Mesh) -> Node3D:
	var node := Gallery._mesh(mesh)
	var facing := Basis(Vector3.UP, PI)
	if key.begins_with("mallshop"):
		var shop: Array = Shops.MALL[int(key.trim_prefix("mallshop"))]
		var sign := Shops.label(shop[0], 72, 0.008)
		sign.transform = Transform3D(facing, Vector3(0, 4.05, -0.25))
		node.add_child(sign)
		var slogan := Shops.label(shop[2], 60, 0.009, Color.WHITE)
		slogan.outline_size = 18
		slogan.outline_modulate = Color(0.1, 0.1, 0.15)
		slogan.width = 560
		slogan.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		slogan.transform = Transform3D(facing, Vector3(-0.5, 6.35, -0.16))
		node.add_child(slogan)
		var sticker := Shops.label(shop[3], 72, 0.008, Color(1, 0.9, 0.1))
		sticker.outline_size = 24
		sticker.outline_modulate = Color(0.85, 0.05, 0.1)
		sticker.transform = Transform3D(facing * Basis(Vector3.BACK, 0.18), Vector3(-3.3, 1, -0.12))
		node.add_child(sticker)
	elif key.begins_with("townhouse"):
		var sign := Shops.town_sign(int(key.trim_prefix("townhouse")))
		sign.transform = Transform3D(facing, Vector3(-0.9, 3.4, -4.62))
		node.add_child(sign)
	elif key.begins_with("banner"):
		var index := int(key.get_slice("_", 1))
		for angle in [0.0, PI]:
			var sign := Shops.label(Shops.BANNERS[index], 96, 0.009, Color.WHITE)
			sign.outline_size = 16
			sign.outline_modulate = Shops.INK
			sign.transform = Transform3D(Basis(Vector3.UP, angle), Vector3(0, 0, 0.04 if angle == 0 else -0.04))
			node.add_child(sign)
	return node


func _registry() -> void:
	assert(ResourceLoader.exists(Props.BAKED_WORLD), "Run tools/bake_world_meshes.gd before generating the atlas")
	for cell in 256:
		var span := field._slot(cell)
		if int(span.z) != TerrainField.Region.SLOPE and not spans.has(int(span.z)):
			spans[int(span.z)] = span
	for i in 8:
		_add("person_%d" % i, "Vinterkläder %d · vinkar" % (i + 1), "Människor", func() -> Node3D: return _figure(Props.person(i), "wave", 0.2))
	for clip in ["idle", "walk", "flail"]:
		_add("person_" + clip, "Person · " + clip, "Människor", func() -> Node3D: return _figure(Props.person(0), clip))
	_add("child", "Barn", "Människor", func() -> Node3D:
		var child := _figure(Props.person(3), "wave")
		child.scale = Vector3.ONE * 0.62
		return child)
	for i in 2:
		_add("bandy_%d" % i, "Bandyspelare · lag %d" % (i + 1), "Människor", func() -> Node3D:
			return _figure(Props.dressed("atlas_bandy%d" % i, Color("e9c824") if i == 0 else Color("315bba"), Color("203c83"), Color.WHITE, Color("203c83"), false, true), "walk"))
		_add("bather_%d" % i, "Vinterbadare %d" % (i + 1), "Människor", func() -> Node3D:
			return _figure(Props.dressed("atlas_bath%d" % i, Color("315bba") if i == 0 else Color("d94050"), Color("d94050"), Color.WHITE, Color.BLACK, true), "idle"))
	var animals := {"dog": ["Hund", Props.dog()], "moose": ["Älg", Props.moose()], "bear": ["Björn", Props.bear()], "deer": ["Rådjur", Props.deer()], "hare": ["Hare", Props.hare()], "reindeer": ["Ren", Props.reindeer()]}
	for kind: String in animals:
		var rig: Props.Rig = animals[kind][1]
		for clip in ["idle", String(rig.gait), "flail"]:
			_add(kind + "_" + clip, animals[kind][0] + " · " + clip, "Djur", func() -> Node3D: return _figure(rig, clip))
	for species in 3:
		for flying in [false, true]:
			_add("bird_%d_%s" % [species, flying], ["Kråka", "Skata", "Domherre"][species] + (" · flyger" if flying else " · sitter"), "Djur", func() -> Node3D: return _bird(species, flying))
	for i in 2:
		_add("rat_%d" % i, "Råtta %d · sammansatt" % (i + 1), "Djur", func() -> Node3D: return _rat(i))
	for ride in VehicleSpec.Model.values():
		var title: String = VehicleSpec.all()[ride].title
		_add("ride_%d" % ride, title, "Åkdon och åkare", func() -> Node3D: return Gallery._mesh(RideModels.vehicle(ride)))
		_add("rider_%d" % ride, title + " · med åkare", "Åkdon och åkare", func() -> Node3D: return Gallery._ride3d(ride))
	for pose in Gallery._entries("riderpose"):
		_add("rider_pose_" + pose[0], "Åkare · " + pose[0], "Åkdon och åkare", pose[1])
	Props._load_world_cache()
	Props.santa_sleigh()
	for i in 4: Props.gift(i)
	Props.snowball()
	Props.finish_arch(24)
	var keys: Array = Props._cache.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)
	for key: String in keys:
		var mesh: Mesh = Props._cache[key]
		var label := key
		var group := "Miljö och rekvisita"
		if key.begins_with("car_v3_"):
			var variant := int(key.trim_prefix("car_v3_"))
			label = ["Klassisk kombi", "Modern kombi", "Halvkombi", "Sedan", "SUV", "Skåpbil", "Pickup"][variant % 7] + " · " + ["röd", "blå", "vit", "svart", "grön", "gul", "silver"][variant / 7]
			group = "Bilar · alla karosser och lacker"
		elif key.begins_with("house") or key.begins_with("townhouse") or key.begins_with("mallshop"):
			group = "Hus och butiker"
			if key.begins_with("mallshop"): label = Shops.MALL[int(key.trim_prefix("mallshop"))][0]
			if key.begins_with("townhouse"): label = Shops.TOWN[int(key.trim_prefix("townhouse"))][0]
		elif key.begins_with("bridge") or key.begins_with("lights") or key.begins_with("ceiling") or key.begins_with("entrance"):
			group = "Moduler · breddvarianter"
		elif key.begins_with("bird_") or key.begins_with("rat_") or key.begins_with("sewer_rat_") or key == "bandy_stick":
			group = "Figurdelar"
			if key.begins_with("sewer_rat_"): label = "Råtta %d · enbart kroppen" % (int(key.trim_prefix("sewer_rat_")) + 1)
		_add(key, label, group, func() -> Node3D: return _scenery(key, mesh))
	# Roof houses are generated from descriptors, rather than the shared cache.
	var roof_span: Vector3 = spans[TerrainField.Region.ROOFS]
	var seen := {}
	for d in range(int(roof_span.x), int(roof_span.y), 5):
		for lane in [-1, 0, 1]:
			var roof: TerrainField.Roof = field.roof_at(field.center_x(d) + lane * TerrainField.ROOF_LANE, d)
			if roof == null or seen.has(roof.variant % 6): continue
			seen[roof.variant % 6] = true
			_add("roof_house_%d" % (roof.variant % 6), "Takhus · fasad %d" % (roof.variant % 6 + 1), "Hus och butiker", func() -> Node3D: return Gallery._mesh(Roofscape.house(field, roof)))
	for kind: int in spans:
		_add("region_%d" % kind, TerrainField.Region.keys()[kind] + " · banutsnitt", "Regioner · exempel från banan", func() -> Node3D: return _region(kind))
	# Keep each section together without changing the original order inside it.
	var order := ["Människor", "Djur", "Åkdon och åkare", "Bilar · alla karosser och lacker", "Hus och butiker", "Miljö och rekvisita", "Regioner · exempel från banan", "Figurdelar", "Moduler · breddvarianter"]
	var sorted: Array[Dictionary] = []
	for group: String in order:
		for entry in entries:
			if entry.group == group: sorted.append(entry)
	entries = sorted


func _bounds(model: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var pending: Array[Node] = [model]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		pending.append_array(node.get_children())
		if node is GeometryInstance3D:
			node.visibility_range_begin = 0
			node.visibility_range_end = 0
		var mesh_box: AABB
		if node is MeshInstance3D and node.mesh != null and node.is_visible_in_tree():
			mesh_box = node.mesh.get_aabb()
			if node.skin != null:
				var posed: ArrayMesh = node.bake_mesh_from_current_skeleton_pose()
				if posed != null: mesh_box = posed.get_aabb()
		elif node is MultiMeshInstance3D and node.multimesh != null:
			mesh_box = node.multimesh.get_aabb()
		elif node is Label3D:
			mesh_box = node.get_aabb()
		else: continue
		var local: AABB = (model.global_transform.affine_inverse() * node.global_transform) * mesh_box
		box = local if first else box.merge(local)
		first = false
	assert(not first and box.size.length() > 0, "Empty model")
	return model.global_transform * box


func _frame(camera: Camera3D, box: AABB, direction: Vector3) -> void:
	var center := box.get_center()
	var radius := maxf(box.size.length(), 0.05)
	camera.position = center + direction.normalized() * radius * 2
	camera.look_at(center)
	var width := 0.0
	var height := 0.0
	for corner in 8:
		var offset := box.get_endpoint(corner) - center
		width = maxf(width, absf(offset.dot(camera.basis.x)) * 2)
		height = maxf(height, absf(offset.dot(camera.basis.y)) * 2)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = maxf(width, height) * 1.12
	camera.near = radius * 0.001
	camera.far = radius * 8


func _run() -> void:
	AudioServer.set_bus_mute(0, true)
	var args := OS.get_cmdline_user_args()
	assert(args.size() > 0, "An output directory is required")
	var out := args[0]
	var pixels := int(args[1]) if args.size() > 1 else 512
	DirAccess.make_dir_recursive_absolute(out.path_join("frames"))
	_registry()
	var manifest: Array[Dictionary] = []
	for i in entries.size():
		var entry := entries[i].duplicate()
		entry.erase("builder")
		entry["number"] = i + 1
		manifest.append(entry)
	var file := FileAccess.open(out.path_join("manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"pixels": pixels, "entries": manifest, "seed": 4711}, "\t"))
	file.close()
	var world := Node3D.new()
	root.add_child(world)
	root.size = Vector2i(pixels, pixels)
	root.msaa_3d = Viewport.MSAA_4X
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("d6e0eb")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("c7d8ed")
	env.environment.ambient_light_energy = 0.65
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -35, 0)
	sun.light_energy = 1.1
	world.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 145, 0)
	fill.light_energy = 0.35
	world.add_child(fill)
	var camera := Camera3D.new()
	camera.current = true
	world.add_child(camera)
	var limit := int(OS.get_environment("ATLAS_LIMIT"))
	var resume := OS.get_environment("ATLAS_RESUME") == "1"
	var only := OS.get_environment("ATLAS_ONLY").split(",", false)
	for i in entries.size():
		if limit > 0 and i >= limit: break
		if not only.is_empty() and not only.has(str(i + 1)): continue
		if resume and FileAccess.file_exists(out.path_join("frames/%03d_0.png" % (i + 1))) and FileAccess.file_exists(out.path_join("frames/%03d_1.png" % (i + 1))): continue
		var entry := entries[i]
		var model: Node3D = entry.builder.call()
		world.add_child(model)
		if model.has_meta("after_add"): (model.get_meta("after_add") as Callable).call()
		for frame in 3: await process_frame
		var box := _bounds(model)
		var directions := [Vector3(-1, 0.45, -1.25), Vector3(1, 0.35, 1.25)]
		if model.has_meta("overview"): directions = [Vector3(-0.7, 1.2, 1.3), Vector3(0.7, 0.75, -1.3)]
		for view in 2:
			_frame(camera, box, directions[view])
			for frame in 3: await process_frame
			var shot := root.get_texture().get_image()
			assert(shot.save_png(out.path_join("frames/%03d_%d.png" % [i + 1, view])) == OK)
		print("ATLAS %03d/%d %s | %s" % [i + 1, entries.size(), entry.key, box])
		model.queue_free()
		await process_frame
	print("ATLAS DONE ", entries.size())
	quit()
