extends SceneTree
## A reproducible seven-car review on snow, each with a different paint.
## --rear shows the same lineup from the other end.
func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var output := args[0] if not args.is_empty() else "/tmp/pulka-cars.png"
	root.size = Vector2i(1800, 1000)
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var material := ProceduralSkyMaterial.new()
	material.sky_top_color = Color("799bc4")
	material.sky_horizon_color = Color("d6e0e8")
	sky.sky_material = material
	environment.environment.sky = sky
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b1c9e1")
	environment.environment.ambient_light_energy = 0.6
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	light.light_energy = 1.2
	light.shadow_enabled = true
	world.add_child(light)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	floor_mesh.mesh = plane
	var snow := StandardMaterial3D.new()
	snow.albedo_color = Palette.SNOW_PACKED
	snow.roughness = 1
	floor_mesh.material_override = snow
	world.add_child(floor_mesh)
	var cars: Array[MeshInstance3D] = []
	for i in 7:
		var car := MeshInstance3D.new()
		car.mesh = Props.car(i * (CarModels.BODY_NAMES.size() + 1))
		car.position = Vector3((i % 4 - 1.5) * 5.2, 0, (i / 4 - 0.5) * 7.5)
		world.add_child(car)
		cars.append(car)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 15
	camera.position = Vector3(13, 15, 22 if args.has("--rear") else -22)
	world.add_child(camera)
	camera.look_at(Vector3(0, 0.4, 0))
	camera.current = true
	var labels := CanvasLayer.new()
	root.add_child(labels)
	for i in cars.size():
		var label := Label.new()
		label.text = str(cars[i].mesh.get_meta("body_name", "Bil %d" % (i + 1)))
		label.add_theme_font_size_override("font_size", 26)
		label.add_theme_color_override("font_color", Color("263948"))
		var at := camera.unproject_position(cars[i].position + Vector3(0, 0, -2.8 if not args.has("--rear") else 2.8))
		label.position = at - Vector2(90, -12)
		labels.add_child(label)
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output)
	world.queue_free()
	labels.queue_free()
	await process_frame
	quit()
