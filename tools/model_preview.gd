extends SceneTree
## Renders the animated creatures side by side and saves a screenshot.
## Run: Godot --path . --script res://tools/model_preview.gd -- out.png


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://preview.png"
	var field := TerrainField.new(1)
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.6, 0.75, 0.9)
	env.environment.ambient_light_color = Color(0.7, 0.75, 0.85)
	env.environment.ambient_light_energy = 0.6
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.shadow_enabled = true
	world.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	ground.mesh = plane
	var snow := StandardMaterial3D.new()
	snow.albedo_color = Color(0.92, 0.94, 1.0)
	ground.material_override = snow
	world.add_child(ground)
	var rigs := [
		[Obstacle.Kind.MOOSE, Props.moose()], [Obstacle.Kind.DEER, Props.deer()], [Obstacle.Kind.DOG, Props.dog()],
		[Obstacle.Kind.PERSON, Props.person(1)], [Obstacle.Kind.PERSON, Props.person(4)], [Obstacle.Kind.HARE, Props.hare()],
	]
	var walkers: Array[Obstacle] = []
	for i in rigs.size():
		var o := Obstacle.new().configure(rigs[i][0], rigs[i][1], field)
		o.follow_terrain = false
		o.position = Vector3(-7.5 + i * 3.0, 0, 0)
		o.rotation.y = -PI / 2 + 0.5
		world.add_child(o)
		walkers.append(o)
	var sled := MeshInstance3D.new()
	sled.mesh = RideModels.vehicle(VehicleSpec.Model.PULKA)
	sled.position = Vector3(2, 0, 3)
	sled.rotation.y = -0.8
	world.add_child(sled)
	var rider := MeshInstance3D.new()
	rider.mesh = RideModels.rider(Color(0.9, 0.3, 0.7), Color(0.95, 0.8, 0.1))
	rider.position = Vector3(0, 0.16, 0.05)
	sled.add_child(rider)
	var give_way := MeshInstance3D.new()
	give_way.mesh = Props.yield_sign()
	give_way.position = Vector3(5.5, 0, 2)
	world.add_child(give_way)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 3.2, 9.5)
	world.add_child(camera)
	camera.look_at(Vector3(0, 1.0, 0))
	camera.current = true
	for frame in 20:
		for i in walkers.size():
			var o := walkers[i]
			if i != 4:
				o.velocity = Vector3(0.001, 0, 0)
			o._gait = 0.9
			o.tick(0.016)
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
