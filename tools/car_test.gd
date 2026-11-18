extends SceneTree
## Validate the rendered fleet, collider bounds and a large seeded spawn sample.
var failures := 0

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var field := TerrainField.new(4711)
	var max_triangles := 0
	for variant in CarModels.variant_count():
		var mesh := Props.car(variant)
		var valid := mesh.get_surface_count() == 1
		var arrays := mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var wheels: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM0]
		valid = valid and vertices.size() == normals.size() and indices.size() % 3 == 0
		valid = valid and wheels.size() == vertices.size() * 4
		var centers := {}
		for i in vertices.size():
			valid = valid and vertices[i].is_finite() and normals[i].is_finite() and absf(normals[i].length() - 1.0) < 0.01
			if wheels[i * 4 + 3] > 0.5:
				var center := Vector3(wheels[i * 4], wheels[i * 4 + 1], wheels[i * 4 + 2])
				centers[center] = true
				# Each rotating vertex belongs to a real wheel, not its arch
				# or the bodywork. Its radius must stay within the tyre.
				valid = valid and Vector2(vertices[i].y - center.y, vertices[i].z - center.z).length() <= center.y + 0.002
		valid = valid and centers.size() == 4
		for index in indices: valid = valid and index >= 0 and index < vertices.size()
		var bounds := mesh.get_aabb()
		valid = valid and bounds.position.y >= -0.001 and bounds.size.y > 1.4 and bounds.size.y < 2.5
		var obstacle := Obstacle.new().configure(Obstacle.Kind.CAR, Props.Rig.of(mesh), field)
		# Bumpers must fit inside the traffic spacing, and the collision roof
		# must follow each cabin rather than the height of the old shared car.
		valid = valid and TrafficLane.vehicle_half_length(obstacle) >= maxf(absf(bounds.position.z), bounds.end.z) - 0.001
		valid = valid and absf(obstacle.top - float(mesh.get_meta("roof_height"))) < 0.001
		valid = valid and obstacle.top <= bounds.end.y + 0.03
		_check("variant %d has valid geometry and matching collision/traffic bounds" % variant, valid)
		max_triangles = maxi(max_triangles, indices.size() / 3)
		obstacle.free()
	var hatch := Props.car(CarModels.Body.HATCHBACK)
	var estate := Props.car(CarModels.Body.ESTATE)
	var suv := Props.car(CarModels.Body.SUV)
	var van := Props.car(CarModels.Body.VAN)
	_check("compact, estate and tall bodies retain different proportions", hatch.get_aabb().size.z < estate.get_aabb().size.z - 0.5 and suv.get_aabb().size.y > estate.get_aabb().size.y + 0.2 and van.get_aabb().size.y > suv.get_aabb().size.y + 0.1)
	for body in CarModels.BODY_NAMES.size():
		var mesh := Props.car(body)
		var radius := float(mesh.get_meta("wheel_radius"))
		var a := Obstacle.new().configure(Obstacle.Kind.CAR, Props.Rig.of(mesh), field)
		var b := Obstacle.new().configure(Obstacle.Kind.CAR, Props.Rig.of(mesh), field)
		a.roll_wheels(radius * PI / 2)
		var contact := Basis(Vector3.RIGHT, a._wheel_angle) * Vector3.DOWN * radius
		_check("%s wheels roll forward without sliding" % CarModels.BODY_NAMES[body], absf(angle_difference(a._wheel_angle, -PI / 2)) < 0.00001 and contact.distance_to(Vector3(0, 0, radius)) < 0.00001 and is_equal_approx(float(a.visual.get_instance_shader_parameter(&"wheel_angle")), a._wheel_angle))
		a.roll_wheels(0)
		_check("stationary wheels retain their phase independently of other cars", absf(angle_difference(a._wheel_angle, -PI / 2)) < 0.00001 and b._wheel_angle == 0 and a.visual.mesh == b.visual.mesh)
		a.roll_wheels(-radius * PI / 2)
		_check("reversing retraces the same wheel rotation", absf(angle_difference(a._wheel_angle, 0)) < 0.00001)
		a.roll_wheels(radius * TAU * 1000000 + radius * PI / 3)
		_check("long drives retain a bounded wheel angle", a._wheel_angle >= 0 and a._wheel_angle < TAU and absf(angle_difference(a._wheel_angle, -PI / 3)) < 0.001)
		a.free()
		b.free()
	var rng := RandomNumberGenerator.new()
	var replay := RandomNumberGenerator.new()
	rng.seed = 4711
	replay.seed = 4711
	var bodies := PackedInt32Array()
	var paints := PackedInt32Array()
	var combinations := PackedInt32Array()
	bodies.resize(7)
	paints.resize(7)
	combinations.resize(CarModels.variant_count())
	var deterministic := true
	const SAMPLES := 200000
	for i in SAMPLES:
		var variant := CarModels.pick(rng)
		deterministic = deterministic and variant == CarModels.pick(replay)
		bodies[variant % 7] += 1
		paints[variant / 7] += 1
		combinations[variant] += 1
	_check("fleet generation is reproducible from the terrain seed", deterministic)
	var distribution := true
	var independent := true
	for body in 7:
		var share := bodies[body] * 100.0 / SAMPLES
		print("  %s: %.2f%%" % [CarModels.BODY_NAMES[body], share])
		distribution = distribution and absf(share - CarModels.BODY_WEIGHTS[body]) < 0.5
		for paint in 7:
			var expected := bodies[body] * paints[paint] / float(SAMPLES)
			independent = independent and absf(combinations[body + paint * 7] - expected) < maxf(20, expected * 0.25)
	_check("common Swedish body types dominate and pickups remain rare", distribution)
	_check("paint and body type vary independently", independent)
	_check("neutral paint dominates and yellow remains occasional", (paints[2] + paints[3] + paints[6]) * 100.0 / SAMPLES > 65 and paints[5] * 100.0 / SAMPLES < 1.3)
	print("car test: %s; max %d triangles/car, one opaque surface" % ["all passed" if failures == 0 else "%d failed" % failures, max_triangles])
	quit(failures)

func _check(message: String, condition: bool) -> void:
	print(("  ok    " if condition else "  FAIL  ") + message)
	if not condition: failures += 1
