extends SceneTree
## Renders one model from three angles side by side.
## Run: Godot --path . --script res://tools/mesh_preview.gd -- <name> <out.png>
## Names: plane, truck, pulka, stjartlapp, snowracer, tefat, wok, rider.


func _initialize() -> void:
	_run.call_deferred()


func _model(name: String) -> Node3D:
	var node := MeshInstance3D.new()
	match name:
		"plane":
			node.mesh = RegionProps.plane(0)
		"truck":
			node.mesh = RegionProps.truck(0)
		"rider":
			node.mesh = RideModels.rider(Color(0.9, 0.3, 0.6), Color(0.95, 0.8, 0.1))
		_:
			var models := {"pulka": VehicleSpec.Model.PULKA, "stjartlapp": VehicleSpec.Model.STJARTLAPP, "snowracer": VehicleSpec.Model.SNOWRACER, "tefat": VehicleSpec.Model.TEFAT, "wok": VehicleSpec.Model.WOK}
			var model: VehicleSpec.Model = models.get(name, VehicleSpec.Model.PULKA)
			node.mesh = RideModels.vehicle(model)
			var rider := MeshInstance3D.new()
			rider.mesh = RideModels.rider(Color(0.9, 0.3, 0.6), Color(0.95, 0.8, 0.1), model)
			var seats := {"pulka": 0.16, "stjartlapp": 0.05, "snowracer": 0.42, "tefat": 0.12, "wok": 0.1}
			rider.position = Vector3(0, seats.get(name, 0.16), 0.05)
			node.add_child(rider)
	return node


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var name := args[0] if args.size() > 0 else "pulka"
	var out := args[1] if args.size() > 1 else "user://mesh.png"
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.74, 0.88)
	env.environment.ambient_light_color = Color(0.75, 0.8, 0.9)
	env.environment.ambient_light_energy = 0.7
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 35, 0)
	sun.shadow_enabled = true
	world.add_child(sun)
	var size := 40.0 if name == "plane" or name == "truck" else 1.6
	var image := Image.create(1800, 600, false, Image.FORMAT_RGBA8)
	var angles := [Vector3(1.0, 0.5, 1.0), Vector3(-1.2, 0.35, -0.6), Vector3(0.0, 0.9, 0.9)]
	var model := _model(name)
	world.add_child(model)
	var camera := Camera3D.new()
	camera.fov = 40.0
	world.add_child(camera)
	camera.current = true
	root.size = Vector2i(600, 600)
	for i in 3:
		var direction: Vector3 = angles[i]
		camera.position = direction.normalized() * size * 1.6 + Vector3.UP * size * 0.25
		camera.look_at(Vector3.UP * size * 0.2)
		for frame in 4:
			await process_frame
		var shot := root.get_viewport().get_texture().get_image()
		shot.resize(600, 600)
		shot.convert(Image.FORMAT_RGBA8)
		image.blit_rect(shot, Rect2i(0, 0, 600, 600), Vector2i(i * 600, 0))
	image.save_png(out)
	quit()
