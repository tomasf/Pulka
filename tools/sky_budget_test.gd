extends SceneTree
## Compare environment maps, or --shadows for two versus one shadow cascade.
## Same-frame Mobile renders over water; -- --capture saves the two views.
func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	Quality.force_tv = true
	var shadows := OS.get_cmdline_user_args().has("--shadows")
	RenderingServer.directional_shadow_atlas_set_size(2048, true)
	var field := TerrainField.new(4711)
	var distance := 0.0
	for slot in 256:
		var span := field._slot(slot)
		if int(span.z) == TerrainField.Region.LAKE:
			distance = span.x + 65
			break
	var world := SlopeWorld.new()
	root.add_child(world)
	world.reset(field, distance)
	var views: Array[SubViewport] = []
	var skies: Array[Atmosphere] = []
	for index in 2:
		var view := SubViewport.new()
		view.size = Vector2i(960, 600)
		view.world_3d = world.get_world_3d()
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(view)
		var camera := Camera3D.new()
		view.add_child(camera)
		camera.position = Vector3(field.center_x(distance), field.height(field.center_x(distance), distance) + 4, -distance + 4)
		camera.look_at(Vector3(field.center_x(distance + 35), field.height(field.center_x(distance + 35), distance + 35) + 1, -distance - 35))
		camera.fov = 65
		camera.current = true
		var atmosphere := Atmosphere.new()
		atmosphere.view_index = index
		root.add_child(atmosphere)
		atmosphere._environment.sky.radiance_size = Sky.RADIANCE_SIZE_256 if shadows or index == 0 else Sky.RADIANCE_SIZE_64
		if shadows:
			atmosphere._sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if index == 0 else DirectionalLight3D.SHADOW_ORTHOGONAL
		atmosphere.update_atmosphere(0, camera, distance, 0, false)
		atmosphere._snow.visible = false
		atmosphere._snow.emitting = false
		views.append(view)
		skies.append(atmosphere)
	for frame in 60: await process_frame
	await RenderingServer.frame_post_draw
	var before := views[0].get_texture().get_image()
	var after := views[1].get_texture().get_image()
	var difference := 0.0
	for y in before.get_height():
		for x in before.get_width():
			var a := before.get_pixel(x, y)
			var b := after.get_pixel(x, y)
			difference += (absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)) / 3
	difference /= before.get_width() * before.get_height()
	print("%s mean pixel difference: %.6f" % ["two -> one shadow cascade" if shadows else "environment map 256 -> 64", difference])
	if OS.get_cmdline_user_args().has("--capture"):
		before.save_png("/tmp/pulka-shadow-2.png" if shadows else "/tmp/pulka-sky-256.png")
		after.save_png("/tmp/pulka-shadow-1.png" if shadows else "/tmp/pulka-sky-64.png")
	for view in views: view.free()
	for atmosphere in skies: atmosphere.free()
	world.free()
	await process_frame
	if difference >= .005: push_error("Lighting-budget change is too visible")
	quit(0 if difference < .005 else 1)
