extends SceneTree
## Regression checks for thrown obstacles rotating around their body.
## Godot --headless --path . --script res://tools/tumble_test.gd

class FlatField extends TerrainField:
	func height_world(_x: float, _z: float, _include_ramps := true) -> float:
		return 0.0

var _failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(label: String, condition: bool) -> void:
	if not condition:
		_failures += 1
		push_error(label)

func _run() -> void:
	var terrain := FlatField.new(1)
	# Geometry-only fixture: clothing overrides do not affect the pivot.
	var person_rig := Props.Rig.creature("person", {}, 1.4)
	# Model-space torso positions, independent of the obstacle's foot origin.
	for entry in [
		[Obstacle.Kind.PERSON, person_rig, Vector3(0, 1.05, 0), 1.0],
		[Obstacle.Kind.KID, person_rig, Vector3(0, 1.05, 0), 0.62],
		[Obstacle.Kind.BEAR, Props.bear(), Vector3(0, 0.97, 0.05), 1.0],
	]:
		var obstacle := Obstacle.new().configure(entry[0], entry[1], terrain)
		root.add_child(obstacle)
		await process_frame
		obstacle.scale = Vector3.ONE * entry[3]
		obstacle.rotation = Vector3(0.12, 0.7, -0.04)
		obstacle.position = Vector3(4, 100, -3)
		obstacle.visual.position.y = 0.025
		var local_center: Vector3 = entry[2] + Vector3(0, 0.025, 0)
		var expected := obstacle.transform * local_center
		var original := obstacle.transform
		var flight := Vector3(3, 5, -6)
		obstacle.launch(flight)
		obstacle.set_process(false)
		_check("launch must not move or rotate the figure", obstacle.transform.is_equal_approx(original))
		obstacle.set("_spin", Vector3(5, 3, -4))
		var max_error := 0.0
		for step in 120:
			flight.y -= 15.0 / 60.0
			expected += flight / 60.0
			obstacle._process(1.0 / 60.0)
			max_error = maxf(max_error, (obstacle.transform * local_center).distance_to(expected))
		_check("torso must follow the ballistic path while tumbling", max_error < 0.002)
		_check("tumbling preserves the child's scale", absf(obstacle.scale.x - float(entry[3])) < 0.0001)
		obstacle.queue_free()
		await process_frame

	# A rotated prop must bounce when its surface reaches snow, rather than
	# waiting for its original bottom point to cross the ground.
	var cone := Obstacle.new().configure(Obstacle.Kind.CONE, Props.Rig.of(RegionProps.cone()), terrain)
	root.add_child(cone)
	await process_frame
	cone.position.y = 0.1
	cone.rotation.z = PI / 2
	cone.launch(Vector3(0, -1, 0))
	cone.set_process(false)
	cone.set("_spin", Vector3.ZERO)
	cone._process(0.01)
	_check("sideways prop contacts the ground at its surface", (cone.get("_fly") as Vector3).y > 0)
	cone.queue_free()
	await process_frame

	var person := Obstacle.new().configure(Obstacle.Kind.PERSON, person_rig, terrain)
	root.add_child(person)
	await process_frame
	person.launch(Vector3(0, 1, 0))
	person.set_process(false)
	person.set("_spin", Vector3(4, 2, 3))
	for step in 1200:
		if not person.flying:
			break
		person._process(1.0 / 60.0)
	_check("a thrown person comes to rest", not person.flying)
	_check("the resting body meets the snow", absf(person.call("_ground_penetration")) < 0.0001)
	person.queue_free()
	await process_frame

	var hare := Obstacle.new().configure(Obstacle.Kind.HARE, Props.hare(), terrain)
	root.add_child(hare)
	await process_frame
	hare.position.y = 10
	hare.launch(Vector3.UP)
	hare.set_process(false)
	hare._process(0.01)
	hare.tick(0.01)
	var creature := hare.get("_creature") as CreatureRig
	_check("patrol tick must not replace the airborne flail with idle", creature.get("_current") == &"flail")
	hare.queue_free()
	await process_frame
	print("tumble test: ", "all passed" if _failures == 0 else "%d failed" % _failures)
	quit(_failures)
