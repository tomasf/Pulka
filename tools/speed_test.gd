extends SceneTree
## Run: Godot --headless --path . --script res://tools/speed_test.gd
## Check parsing: append -- --speed-multiplier=2 --expected-multiplier=2

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var expected := 1.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--expected-multiplier="):
			expected = float(arg.trim_prefix("--expected-multiplier="))
	var main: Node = load("res://scripts/main.gd").new()
	main.call("_parse_args")
	_check("command line multiplier", is_equal_approx(main.get("_speed_multiplier"), expected))
	main.free()

	var normal := _flight(1.0)
	for multiplier in [0.5, 2.0]:
		var scaled := _flight(multiplier)
		_check("horizontal travel scales by %s" % multiplier, is_equal_approx(scaled.x, normal.x * multiplier))
		_check("vertical flight is unchanged at %s" % multiplier, is_equal_approx(scaled.y, normal.y))
		_check("air steering is unchanged at %s" % multiplier, is_equal_approx(scaled.z, normal.z))

	for multiplier in [0.5, 1.0, 2.0]:
		var sled := _sled(multiplier)
		sled.velocity = Vector3(3.0, 0.0, -4.0)
		_check("speed display scales by %s" % multiplier, is_equal_approx(sled.speed(), 5.0 * multiplier))
		sled.place_at(8.0, 0.0, 15.0)
		_check("placement preserves multiplier", sled.speed_multiplier == multiplier)
		sled.step(1.0 / 60.0, 0.0, 0.0, 0.0, true)
		_check("jump still works at %s" % multiplier, not sled.on_ground)
		sled.free()
	print("speed test: %s" % ("all passed" if _failures == 0 else "%d failed" % _failures))
	quit(_failures)


func _sled(multiplier: float) -> Sled:
	var sled := Sled.new()
	root.add_child(sled)
	sled.field = TerrainField.new(1234)
	sled.set_vehicle(VehicleSpec.all()[0], RandomNumberGenerator.new())
	sled.speed_multiplier = multiplier
	sled.frozen = false
	return sled


## Identical airborne motion above terrain isolates travel from ground contacts.
func _flight(multiplier: float) -> Vector3:
	var sled := _sled(multiplier)
	sled.place_at(8.0)
	sled.position.y += 1000.0
	sled.spec.drag = 0.0
	sled.bounce(0.0)
	sled.velocity = Vector3(4.0, 6.5, -15.0)
	var start := sled.position
	for frame in 60:
		sled.step(1.0 / 60.0, 0.3, 0.0, 0.0, false)
	var result := Vector3(sled.position.z - start.z, sled.position.y - start.y, sled.yaw)
	sled.free()
	return result


func _check(what: String, ok: bool) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		_failures += 1
