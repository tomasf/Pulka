extends SceneTree
## Outfit sharing, merged geometry, cancellable cache misses and native
## pixel comparison against the original materials. Add -- --capture.
var failures := 0

func _initialize() -> void: _run.call_deferred()

func _check(label: String, condition: bool) -> void:
	if not condition:
		failures += 1
		push_error(label)
	else: print("PASS ", label)

func _run() -> void:
	for step in 8:
		var a := Props.crowd_mesh(Props.person(0, 0), step * TAU / 8)
		var b := Props.crowd_mesh(Props.person(1, 1), step * TAU / 8)
		_check("pose %d shares one surface across outfits" % step, a == b and a.get_surface_count() == 1)
		var original := Props.baked(Props.person(0, 0), step * TAU / 8)
		var vertices := 0
		var indices := 0
		for surface in original.get_surface_count():
			vertices += original.surface_get_array_len(surface)
			indices += original.surface_get_array_index_len(surface)
		_check("pose %d retains the original geometry" % step, a.surface_get_array_len(0) == vertices and a.surface_get_array_index_len(0) == indices and a.get_aabb().is_equal_approx(original.get_aabb()))
	var key := Props._pose_key(Props.person(0, 0), 0)
	Props._crowd.erase(key)
	var pending := Props.crowd(Props.person(0, 0), 0)
	var blue := Props.crowd(Props.person(1, 1), 0)
	_check("crowd cache misses coalesce without work during scenery placement", pending.mesh == null and blue.mesh == null and Props._pose_order.size() == 1)
	Props.prepare_poses(Time.get_ticks_usec())
	_check("expired budget leaves the crowd queued", pending.mesh == null)
	Props.prepare_poses(Time.get_ticks_usec() + 1000000)
	_check("prepared crowd shares geometry and keeps separate colours", pending.mesh == blue.mesh and pending.get_instance_shader_parameter("jacket") == Props.person(0, 0).colours.jacket and blue.get_instance_shader_parameter("jacket") == Props.person(1, 1).colours.jacket)
	pending.free()
	blue.free()
	Props._crowd.erase(key)
	var removed := Props.crowd(Props.person(0, 0), 0)
	removed.free()
	Props.prepare_poses(Time.get_ticks_usec() + 1000000)
	_check("removed chunks cancel pending crowd work", not Props._crowd.has(key) and Props._pose_order.is_empty())
	if DisplayServer.get_name() != "headless": await _compare()
	print("crowd test: %s" % ("all passed" if failures == 0 else "%d failed" % failures))
	quit(failures)

func _compare() -> void:
	var views: Array[SubViewport] = []
	for i in 2:
		var view := SubViewport.new()
		view.size = Vector2i(512, 512)
		view.own_world_3d = true
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(view)
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_COLOR
		env.environment.background_color = Color(.3, .4, .5)
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color = Color.WHITE
		env.environment.ambient_light_energy = .6
		view.add_child(env)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-45, -30, 0)
		view.add_child(sun)
		var camera := Camera3D.new()
		view.add_child(camera)
		camera.position = Vector3(-1.4, 1.3, -3.4)
		camera.look_at(Vector3(0, 1, 0))
		camera.fov = 35
		camera.current = true
		views.append(view)
	for sample in 9:
		var outfit := sample if sample < 8 else 3
		var far := sample == 8
		if far:
			for view in views:
				var camera := view.get_camera_3d()
				camera.position = Vector3(-5.6, 2.2, -13.6)
				camera.look_at(Vector3(0, 1, 0))
		var phase := outfit * TAU / 8
		var original := Props.posed(Props.person(outfit, outfit), phase)
		var merged := Props.crowd(Props.person(outfit, outfit), phase)
		Props.prepare_poses(Time.get_ticks_usec() + 1000000)
		views[0].add_child(original)
		views[1].add_child(merged)
		for frame in 4: await process_frame
		await RenderingServer.frame_post_draw
		var before := views[0].get_texture().get_image()
		var after := views[1].get_texture().get_image()
		var error := 0.0
		for y in before.get_height():
			for x in before.get_width():
				var a := before.get_pixel(x, y)
				var b := after.get_pixel(x, y)
				error += (absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)) / 3
		error /= before.get_width() * before.get_height()
		var label := "outfit %d%s" % [outfit, " distant LOD" if far else ""]
		print("%s mean pixel difference %.6f" % [label, error])
		_check("%s preserves its rendered appearance" % label, error < .004)
		if OS.get_cmdline_user_args().has("--capture"):
			before.save_png("/tmp/pulka-crowd-before-%d.png" % sample)
			after.save_png("/tmp/pulka-crowd-after-%d.png" % sample)
		original.free()
		merged.free()
	for view in views: view.queue_free()
	await process_frame
