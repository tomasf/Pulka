extends SceneTree
## Headless check: how often does the ride face away from where it is going?
## Run: Godot --headless --path . --script res://tools/heading_test.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for digital in [false, true]:
		print("--- ", "keyboard (full lock)" if digital else "analog")
		_simulate(digital)
	print("--- holding a full turn for 6 s")
	_hold_turn()
	print("--- switching rides after the saucer")
	_switch_rides()
	quit()


## Changing ride must never leave the new one turned from where you face,
## whatever the previous ride (the saucer spins) left behind.
func _switch_rides() -> void:
	var field := TerrainField.new(7)
	var sled := Sled.new()
	root.add_child(sled)
	sled.field = field
	var saucer: VehicleSpec
	for spec in VehicleSpec.all():
		if spec.visual_spin > 0.0:
			saucer = spec
	var failures := 0
	for spec in VehicleSpec.all():
		sled.set_vehicle(saucer, RandomNumberGenerator.new())
		sled.place_at(8.0, 0.0, 9.0)
		sled.frozen = false
		for frame in 47:
			sled.step(1.0 / 60.0, 0.0, 0.0, false)
		sled.set_vehicle(spec, RandomNumberGenerator.new())
		sled.place_at(8.0, 0.0, 9.0)
		sled.step(1.0 / 60.0, 0.0, 0.0, false)
		var ride: Node3D = sled.get("_vehicle_mesh")
		var nose := -ride.global_basis.z
		var off := rad_to_deg(nose.signed_angle_to(sled.forward(), Vector3.UP))
		var turned := spec.visual_spin == 0.0 and absf(off) > 15.0
		failures += int(turned)
		print("%-10s ride nose vs facing=%4d°  %s" % [spec.title, int(off), "TURNED" if turned else "ok"])
	print("heading test: ", "all passed" if failures == 0 else "%d FAILED" % failures)
	sled.queue_free()


## A player holding one direction must never end up facing uphill.
func _hold_turn() -> void:
	for spec in VehicleSpec.all():
		var field := TerrainField.new(99)
		var sled := Sled.new()
		root.add_child(sled)
		sled.field = field
		sled.set_vehicle(spec, RandomNumberGenerator.new())
		sled.place_at(8.0, 0.0, 9.0)
		sled.frozen = false
		var worst := 0.0
		for frame in 60 * 6:
			sled.step(1.0 / 60.0, 1.0, 0.0, false)
			var fall := field.track_dir(sled.distance())
			var off := absf(wrapf(sled.yaw - atan2(fall.x, -fall.z), -PI, PI))
			worst = maxf(worst, off)
		print("%-10s nose vs downhill worst=%3d°  %s" % [spec.title, int(rad_to_deg(worst)), "BACKWARDS" if worst > PI / 2 else "ok"])
		sled.queue_free()


func _simulate(digital: bool) -> void:
	for spec in VehicleSpec.all():
		var field := TerrainField.new(1234)
		var sled := Sled.new()
		root.add_child(sled)
		sled.field = field
		sled.set_vehicle(spec, RandomNumberGenerator.new())
		sled.place_at(8.0, 0.0, 9.0)
		sled.frozen = false
		var dt := 1.0 / 60.0
		var sideways := 0
		var grounded_sideways := 0
		var backwards := 0
		var samples := 0
		var worst := 0.0
		for frame in 60 * 60:
			var t := frame * dt
			var d := sled.distance()
			var target := field.center_x(d + 20.0) + sin(t * 0.9) * field.half_width(d) * 0.6
			var desired := atan2(target - sled.position.x, 20.0)
			var steer := clampf(wrapf(desired - sled.yaw, -PI, PI) * 3.0, -1.0, 1.0)
			if digital:
				steer = signf(steer) if absf(steer) > 0.15 else 0.0
			sled.step(dt, steer, 1.0, false)
			if sled.crashed:
				break
			var v := sled.velocity
			if Vector2(v.x, v.z).length() > 5.0:
				var mismatch := absf(wrapf(atan2(v.x, -v.z) - sled.yaw, -PI, PI))
				worst = maxf(worst, mismatch)
				samples += 1
				if mismatch > deg_to_rad(45.0):
					sideways += 1
					if sled.on_ground:
						grounded_sideways += 1
				if mismatch > deg_to_rad(100.0):
					backwards += 1
		print("%-10s dist=%5d m  speed=%3d km/h  sideways>45°: %4.1f%%  backwards>100°: %4.1f%%  worst=%3d° (on ground: %4.1f%%)" % [
			spec.title, int(sled.distance()), int(sled.speed() * 3.6),
			100.0 * sideways / maxi(samples, 1), 100.0 * backwards / maxi(samples, 1), int(rad_to_deg(worst)), 100.0 * grounded_sideways / maxi(samples, 1)])
		sled.queue_free()
