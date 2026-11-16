extends SceneTree
## Renders a contact sheet of models, each framed to fit its own cell, for
## reviewing how they look side by side.
## Run: Godot --path . --script res://tools/gallery.gd -- <group> <out.png>
## Groups: nature, people, vehicles, town, shops, regions, rides, pickups, all.

const CELL := 360
const COLUMNS := 6


func _initialize() -> void:
	_run.call_deferred()


static func _entries(group: String) -> Array:
	var jacket := Color(0.9, 0.3, 0.6)
	var hat := Color(0.95, 0.8, 0.1)
	var groups := {
		"nature": [
			["spruce0", func() -> Node3D: return _mesh(Props.spruce(0))],
			["spruce1", func() -> Node3D: return _mesh(Props.spruce(1))],
			["birch", func() -> Node3D: return _mesh(Props.birch())],
			["rock0", func() -> Node3D: return _mesh(Props.rock(0))],
			["rock1", func() -> Node3D: return _mesh(Props.rock(1))],
			["stump", func() -> Node3D: return _mesh(Props.stump())],
			["snowman", func() -> Node3D: return _mesh(Props.snowman())],
			["log", func() -> Node3D: return _mesh(Props.fallen_log())],
			["mushrooms", func() -> Node3D: return _mesh(Props.mushroom_ring())],
			["reeds", func() -> Node3D: return _mesh(Props.reeds())],
			["tent", func() -> Node3D: return _mesh(Props.tent())],
			["floe", func() -> Node3D: return _mesh(RegionProps.ice_floe(1))],
		],
		"people": [
			["person0", func() -> Node3D: return Props.posed(Props.person(0), 0.8)],
			["person1", func() -> Node3D: return Props.posed(Props.person(1), 2.0)],
			["bather", func() -> Node3D: return Props.posed(Props.dressed("gal_bath", Color(0.2, 0.4, 0.9), Color(0.9, 0.2, 0.2), Color.WHITE, Color.BLACK, true), 0.5)],
			["bandy", func() -> Node3D: return Props.posed(Props.dressed("gal_bandy", Color(0.9, 0.8, 0.1), Color(0.1, 0.2, 0.6), Color.WHITE, Color(0.1, 0.2, 0.6), false, true), 0.5)],
			["dog", func() -> Node3D: return Props.posed(Props.dog(), 0.8)],
			["moose", func() -> Node3D: return Props.posed(Props.moose(), 0.8)],
			["deer", func() -> Node3D: return Props.posed(Props.deer(), 0.8)],
			["hare", func() -> Node3D: return Props.posed(Props.hare(), 0.0)],
			["sleigh", func() -> Node3D: return _mesh(Props.santa_sleigh())],
			["reindeer", func() -> Node3D: return Props.posed(Props.reindeer(), 1.0)],
			["chair", func() -> Node3D: return _mesh(Props.chair(1))],
			["rider", func() -> Node3D: return _mesh(RideModels.rider(jacket, hat))],
			["face", func() -> Node3D: return _face(jacket, hat)],
		],
		"vehicles": [
			["car0", func() -> Node3D: return _mesh(Props.car(0))],
			["car3", func() -> Node3D: return _mesh(Props.car(3))],
			["plow", func() -> Node3D: return _mesh(Props.plow())],
			["truck", func() -> Node3D: return _mesh(RegionProps.truck(0))],
			["loco", func() -> Node3D: return _mesh(RegionProps.locomotive())],
			["wagon", func() -> Node3D: return _mesh(RegionProps.wagon(1))],
			["plane", func() -> Node3D: return _mesh(RegionProps.plane(0))],
			["tug", func() -> Node3D: return _mesh(RegionProps.tug())],
			["cart", func() -> Node3D: return _mesh(RegionProps.shopping_cart())],
		],
		"town": [
			["house0", func() -> Node3D: return _mesh(Props.house(0))],
			["house1", func() -> Node3D: return _mesh(Props.house(1))],
			["house3", func() -> Node3D: return _mesh(Props.house(3))],
			["townhouse0", func() -> Node3D: return _mesh(Props.town_house(0))],
			["townhouse2", func() -> Node3D: return _mesh(Props.town_house(2))],
			["lamp", func() -> Node3D: return _mesh(Props.lamp_post())],
			["fence", func() -> Node3D: return _mesh(Props.fence())],
			["yield", func() -> Node3D: return _mesh(Props.yield_sign())],
			["bin", func() -> Node3D: return _mesh(Props.bin())],
			["pole", func() -> Node3D: return _mesh(Props.edge_pole(0))],
			["flag", func() -> Node3D: return _mesh(Props.ramp_flag())],
			["bridge", func() -> Node3D: return _mesh(Props.footbridge(12))],
			["lift", func() -> Node3D: return _mesh(Props.lift_tower())],
			["lights", func() -> Node3D: return _mesh(Props.light_string(14))],
		],
		"regions": [
			["shop", func() -> Node3D: return _mesh(Shops.mall_front(0))],
			["plant", func() -> Node3D: return _mesh(RegionProps.potted_plant())],
			["fountain", func() -> Node3D: return _mesh(RegionProps.fountain())],
			["bench", func() -> Node3D: return _mesh(RegionProps.bench())],
			["mast", func() -> Node3D: return _mesh(RegionProps.catenary_mast(8))],
			["arrow", func() -> Node3D: return _mesh(RegionProps.arrow_board())],
			["gantry", func() -> Node3D: return _mesh(RegionProps.sign_gantry(30))],
			["cone", func() -> Node3D: return _mesh(RegionProps.cone())],
			["tower", func() -> Node3D: return _mesh(RegionProps.control_tower())],
			["terminal", func() -> Node3D: return _mesh(RegionProps.terminal())],
			["windsock", func() -> Node3D: return _mesh(RegionProps.windsock())],
			["jetty", func() -> Node3D: return _mesh(RegionProps.jetty())],
			["goal", func() -> Node3D: return _mesh(RegionProps.bandy_goal())],
			["flood", func() -> Node3D: return _mesh(RegionProps.floodlight())],
			["bleachers", func() -> Node3D: return _mesh(RegionProps.bleachers())],
			["edgelight", func() -> Node3D: return _mesh(RegionProps.edge_light(Color(0.2, 0.5, 1.0)))],
		],
		"rides": [],
		"pickups": [
			["gingerbread", func() -> Node3D: return _mesh(Props.gingerbread())],
			["mitten", func() -> Node3D: return _mesh(Props.mitten())],
			["wax", func() -> Node3D: return _mesh(Props.wax())],
			["gift", func() -> Node3D: return _mesh(Props.gift(0))],
			["snowball", func() -> Node3D: return _mesh(Props.snowball())],
		],
	}
	groups["shops"] = []
	for i in Shops.MALL.size():
		groups["shops"].append(["mall%d" % i, func() -> Node3D: return _front(Shops.mall_front(i))])
	for i in Shops.TOWN.size():
		groups["shops"].append(["town%d" % i, func() -> Node3D: return _front(Props.town_house(i), true)])
	for model in VehicleSpec.Model.values():
		groups["rides"].append([VehicleSpec.Model.keys()[model].to_lower(), func() -> Node3D: return _ride(model, jacket, hat)])
	if group == "all":
		var everything := []
		for key in groups:
			everything.append_array(groups[key])
		return everything
	return groups.get(group, [])


static func _mesh(mesh: Mesh) -> Node3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	return node


## A shop front seen straight on at its window.
static func _front(mesh: Mesh, town := false) -> Node3D:
	var root := _mesh(mesh)
	root.set_meta("frame", AABB(Vector3(-5.0, 0.0, -4.5 if town else 0.0), Vector3(10.0, 4.8, 1.0)) if true else AABB())
	if town:
		root.set_meta("frame", AABB(Vector3(-4.5, 0.0, -4.5), Vector3(9.0, 4.0, 1.0)))
	root.set_meta("front", true)
	return root


static func _face(jacket: Color, hat: Color) -> Node3D:
	var root := Node3D.new()
	var node := MeshInstance3D.new()
	node.mesh = RideModels.rider(jacket, hat)
	root.add_child(node)
	# Only the head: a box around it is used for framing.
	root.set_meta("frame", AABB(Vector3(-0.2, 0.68, -0.2), Vector3(0.4, 0.5, 0.4)))
	root.set_meta("front", true)
	return root


static func _ride(model: VehicleSpec.Model, jacket: Color, hat: Color) -> Node3D:
	var node := _mesh(RideModels.vehicle(model))
	var rider := MeshInstance3D.new()
	rider.mesh = RideModels.rider(jacket, hat, model)
	var spec: VehicleSpec = VehicleSpec.all()[model]
	rider.position = Vector3(0, spec.seat_height, 0.05)
	node.add_child(rider)
	return node


static func _bounds(node: Node3D) -> AABB:
	if node.has_meta("frame"):
		return node.get_meta("frame")
	var box := AABB()
	var first := true
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		stack.append_array(current.get_children())
		if current is MeshInstance3D and current.mesh != null:
			var local: AABB = (node.global_transform.affine_inverse() * current.global_transform) * current.mesh.get_aabb()
			box = local if first else box.merge(local)
			first = false
	return box


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var group := args[0] if args.size() > 0 else "all"
	var out := args[1] if args.size() > 1 else "user://gallery.png"
	var entries := _entries(group)
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.74, 0.88)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.8, 0.9)
	env.environment.ambient_light_energy = 0.7
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 35, 0)
	sun.shadow_enabled = true
	world.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 400)
	ground.mesh = plane
	ground.mesh.surface_set_material(0, _snow_material())
	world.add_child(ground)
	var camera := Camera3D.new()
	camera.fov = 35.0
	world.add_child(camera)
	camera.current = true
	root.size = Vector2i(CELL, CELL)
	var rows := ceili(entries.size() / float(COLUMNS))
	var sheet := Image.create(CELL * mini(COLUMNS, entries.size()), CELL * rows, false, Image.FORMAT_RGBA8)
	for i in entries.size():
		var builder: Callable = entries[i][1]
		var model: Node3D = builder.call()
		world.add_child(model)
		var box := _bounds(model)
		ground.position.y = minf(box.position.y, 0.0) - 0.01
		ground.visible = box.position.y > -1.0
		var centre := box.get_center()
		var radius := maxf(box.size.length() * 0.5, 0.05)
		var direction := Vector3(0.0, 0.12, -1.0) if model.has_meta("front") else Vector3(-1.0, 0.55, -1.15)
		camera.position = centre + direction.normalized() * radius / tan(deg_to_rad(camera.fov * 0.5)) * 1.05
		camera.look_at(centre)
		camera.near = radius * 0.05
		camera.far = radius * 20.0
		for frame in 3:
			await process_frame
		var shot := root.get_viewport().get_texture().get_image()
		shot.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(shot, Rect2i(0, 0, CELL, CELL), Vector2i((i % COLUMNS) * CELL, (i / COLUMNS) * CELL))
		print("%d %s %d verts" % [i, entries[i][0], _vertices(model)])
		model.queue_free()
		await process_frame
	sheet.save_png(out)
	quit()


static func _snow_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Palette.SNOW
	material.roughness = 1.0
	return material


static func _vertices(node: Node) -> int:
	var total := 0
	if node is MeshInstance3D and node.mesh != null:
		for s in node.mesh.get_surface_count():
			total += node.mesh.surface_get_array_len(s)
	for child in node.get_children():
		total += _vertices(child)
	return total
