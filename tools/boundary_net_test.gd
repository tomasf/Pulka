extends SceneTree
## Real crash limits, gradual reveal, terrain alignment and per-camera nets.
## Native --capture writes solo/split review images and checks render isolation.
var failures := 0

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_process(false)
	main.set("_autopilot", true)
	main.set("_vehicle", 0)
	main.get("_rng").seed = 4711
	main.call("_start_run")
	main.set("state", 2)
	main.get("_director").stop()
	var field: TerrainField = main.get("_field")
	var p: Player = main.get("_players")[0]
	p.lives = 100
	for entry in [[TerrainField.Region.SLOPE, 30.0], [TerrainField.Region.WOODS, 2.8], [TerrainField.Region.TOWN, 3.2]]:
		var d := 200.0 if entry[0] == TerrainField.Region.SLOPE else _find(field, entry[0]).x + 120
		var bounds := field.warning_bounds(d)
		_check("original %s crash margin stays unchanged" % TerrainField.Region.keys()[entry[0]], is_equal_approx(bounds.y - field.half_width(d), entry[1]))
		for side in [-1.0, 1.0]:
			p.sled.place_at(d, side * (bounds.y - 0.05))
			main.call("_check_bounds", p)
			_check("inside the warning net is in bounds", not p.sled.crashed)
			p.boundary_net.update_net(field, p.sled, 1, true)
			_check("the approached side reveals its net", p.boundary_net.strength[0 if side < 0 else 1] > 0.99)
			p.sled.place_at(d, side * (bounds.y + 0.05))
			main.call("_check_bounds", p)
			_check("crossing that same net triggers the real crash", p.sled.crashed)
		p.sled.place_at(d, 0)
		var before := maxf(p.boundary_net.strength.x, p.boundary_net.strength.y)
		p.boundary_net.update_net(field, p.sled, 1.0 / 60, true)
		_check("moving away fades rather than instantly hiding", p.boundary_net.visible and maxf(p.boundary_net.strength.x, p.boundary_net.strength.y) < before)
		for i in 60: p.boundary_net.update_net(field, p.sled, 1.0 / 60, true)
		_check("the centre of the track stays clear", not p.boundary_net.visible)
	for kind in [TerrainField.Region.BRIDGE, TerrainField.Region.ICE_CAVE, TerrainField.Region.SEWER, TerrainField.Region.ROOFS, TerrainField.Region.MALL, TerrainField.Region.BANDY]:
		var d := _find(field, kind).x + 120
		_check("%s keeps its existing physical edges" % TerrainField.Region.keys()[kind], field.warning_bounds(d) == Vector2(-INF, INF))
	var harbor_d := _find(field, TerrainField.Region.HARBOR).x + 80
	_check("harbor warns only at the unmarked left boundary", field.warning_bounds(harbor_d) == Vector2(-22, INF))
	for lateral in [-21.95, -22.05]:
		p.sled.place_at(harbor_d, lateral)
		main.call("_check_bounds", p)
		_check("harbor left boundary still matches its crash", p.sled.crashed == (lateral < -22))
	var town_start := _find(field, TerrainField.Region.TOWN).x
	var approach := town_start - 6
	p.sled.place_at(approach, field.half_width(approach) + 14, 24)
	p.boundary_net.update_net(field, p.sled, 1, true)
	_check("approaching a tighter region warns before its boundary", p.boundary_net.strength.y > 0.9)
	var stations := p.boundary_net._stations(field, town_start - 10, town_start + 10)
	_check("a change in the limit keeps its exact corner", stations.has(town_start - 0.01) and stations.has(town_start + 0.01))
	var d := 200.0
	var edge := field.warning_bounds(d).y
	p.sled.place_at(d, edge - 2)
	p.boundary_net.update_net(field, p.sled, 1, true)
	var aligned := true
	var count := 0
	for side in 2:
		var net_mesh: MeshInstance3D = p.boundary_net._sides[side]
		var points: PackedVector3Array = net_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for vertex in points:
			var at: Vector3 = net_mesh.global_transform * vertex
			aligned = aligned and absf(at.x - field.center_x(-at.z) - field.warning_bounds(-at.z)[side]) < 0.001
			count += 1
	_check("both curved strips follow the real limit along the terrain", aligned and count > 100)
	if OS.get_cmdline_user_args().has("--capture"): await _solo_capture(main, d, edge)
	main.call("_build_split")
	var players: Array = main.get("_players")
	for rider: Player in players:
		rider.sled.set_vehicle(VehicleSpec.all()[0], RandomNumberGenerator.new(), Player.COLORS[rider.index])
		rider.sled.place_at(d, edge - 2 if rider.index == 0 else 0)
	main.call("_update_atmospheres", 1.0)
	_check("only the player near the boundary sees a net", players[0].boundary_net.visible and not players[1].boundary_net.visible)
	for rider: Player in players:
		var other: Player = players[1 - rider.index]
		for net: MeshInstance3D in rider.boundary_net._sides:
			_check("warning net belongs only to its player's camera", (net.layers & rider.camera.cull_mask) != 0 and (net.layers & other.camera.cull_mask) == 0)
	if OS.get_cmdline_user_args().has("--capture"): await _split_capture(main, players)
	var removed: WeakRef = weakref(players[1].boundary_net)
	main.call("_enter_menu")
	await process_frame
	await process_frame
	_check("leaving split-screen removes the second net", removed.get_ref() == null)
	main.call("_update_atmospheres", 1)
	_check("menus do not display warning nets", not p.boundary_net.visible)
	main.queue_free()
	await process_frame
	await process_frame
	print("boundary net test: %s" % ("all passed" if failures == 0 else "%d failed" % failures))
	quit(failures)

func _solo_capture(main: Node, d: float, edge: float) -> void:
	var field: TerrainField = main.get("_field")
	main.get("_world").reset(field, d)
	var p: Player = main.get("_players")[0]
	p.sled.frozen = true
	p.camera.mode = ChaseCamera.Mode.CHASE
	main.get("_hud").show_screen("game")
	main.get("_hud").get("_popups").visible = false
	for gap in [6.0, 2.0]:
		p.sled.place_at(d, edge - gap)
		p.sled.frozen = true
		p.camera.snap()
		p.camera.snap()
		p.atmosphere._flash = 0
		p.atmosphere.set_time_of_day(0)
		main.call("_update_atmospheres", 1)
		await _shot("/tmp/pulka-boundary-net-%d.png" % int(gap))

func _split_capture(main: Node, players: Array) -> void:
	for rider: Player in players:
		rider.camera.mode = ChaseCamera.Mode.CHASE
		rider.camera.snap()
		rider.camera.snap()
		rider.atmosphere._flash = 0
		rider.atmosphere.set_time_of_day(0)
	main.call("_update_atmospheres", 1)
	await _shot("/tmp/pulka-boundary-net-split.png")
	# Freeze animated scenery and flakes, then compare the actual second
	# viewport while toggling the first player's net in their shared world.
	main.get("_world_root").process_mode = Node.PROCESS_MODE_DISABLED
	for rider: Player in players: rider.atmosphere._snow.visible = false
	players[0].boundary_net.visible = false
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	var before: Image = players[1].camera.get_viewport().get_texture().get_image()
	players[0].boundary_net.visible = true
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	var after: Image = players[1].camera.get_viewport().get_texture().get_image()
	_check("the other viewport's pixels are unaffected by the net", before.get_data() == after.get_data())
	main.get("_world_root").process_mode = Node.PROCESS_MODE_INHERIT

func _shot(path: String) -> void:
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func _find(field: TerrainField, kind: int) -> Vector3:
	for cell in 256:
		var span := field._slot(cell)
		if int(span.z) == kind: return span
	return Vector3.ZERO

func _check(message: String, condition: bool) -> void:
	print(("  ok    " if condition else "  FAIL  ") + message)
	if not condition: failures += 1
