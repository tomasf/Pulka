extends SceneTree
## Grab tricks: holding jump through the take-off never grabs, pressing it
## again in the air does, letting go in good time lands safely, and letting
## go too late or not at all lands still in the trick. Every ride eases into
## and out of its pose.
## Godot --headless --path . --script res://tools/grab_test.gd

const DT := 1.0 / 60.0

var _failures := 0
var _landings: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _check(label: String, condition: bool) -> void:
	if not condition:
		_failures += 1
		push_error(label)


func _run() -> void:
	var field := TerrainField.new(7)
	var rng := RandomNumberGenerator.new()
	for spec: VehicleSpec in VehicleSpec.all():
		var sled := Sled.new()
		sled.field = field
		root.add_child(sled)
		await process_frame
		sled.set_vehicle(spec, rng)
		sled.frozen = false
		sled.landed.connect(func(_air: float, _impact: float, _spin: float, grab: float) -> void:
			_landings.append([grab, sled.in_trick()]))
		var name := spec.title

		# Jump held all the way: no grab.
		_start(sled)
		sled.step(DT, 0.0, true, true)
		var grabbed := false
		for i in 240:
			sled.step(DT, 0.0, false, true)
			grabbed = grabbed or sled.grabbing
			if sled.on_ground and i > 10:
				break
		_check("%s: holding jump through take-off must not grab" % name, not grabbed)

		# A long flight: press again, hold until fully in the pose and a bit
		# longer, let go in good time.
		_launch(sled)
		var peak_blend := 0.0
		var held := 0
		for i in 120:
			sled.step(DT, 0.0, false, true)
			peak_blend = maxf(peak_blend, sled.grab_blend())
			if sled.grab_blend() >= 1.0:
				held += 1
			if held > 24:
				break
		_check("%s: pressing jump again in the air eases into the pose" % name, peak_blend >= 1.0)
		for i in 240:
			sled.step(DT, 0.0, false, false)
			if sled.on_ground:
				break
		_check("%s: a grab let go in time lands safely" % name, _landings.size() >= 1 and _landings[0][0] > 0.3 and not _landings[0][1])
		for i in 10:
			sled.step(DT, 0.0, false, false)
		_check("%s: rider back in the seat after landing" % name, sled.grab_blend() == 0.0)

		# Let go a moment before touchdown: not back in the seat in time.
		_launch(sled)
		for i in 240:
			var gap := sled.position.y - field.height_world(sled.position.x, sled.position.z)
			var late := sled.velocity.y < 0.0 and gap < -sled.velocity.y * 0.12
			sled.step(DT, 0.0, false, not late)
			if sled.on_ground:
				break
		_check("%s: letting go too late lands in the trick" % name, _landings.size() >= 1 and _landings[0][1])

		# Holding on until touchdown. Without steering, nothing turns the
		# ride in the air (the saucer and wok only spin by themselves on snow).
		_launch(sled)
		var turned_alone := 0.0
		for i in 240:
			var before := float(sled.get("_spin_angle"))
			sled.step(DT, 0.0, false, true)
			if sled.on_ground:
				break
			turned_alone = maxf(turned_alone, absf(float(sled.get("_spin_angle")) - before))
		_check("%s: landing in a grab is reported" % name, _landings.size() >= 1 and _landings[0][1])
		_check("%s: the ride doesn't spin by itself in the air" % name, turned_alone == 0.0)
		sled.queue_free()
		await process_frame
	print("grab test: %s" % ("ok" if _failures == 0 else "%d failures" % _failures))
	quit(1 if _failures > 0 else 0)


## Thrown high off a smooth stretch (as off a big kicker), with the jump
## button let go so the next press grabs.
func _launch(sled: Sled) -> void:
	_start(sled)
	_landings.clear()
	sled.bounce(14.0)
	for i in 4:
		sled.step(DT, 0.0, false, false)


## At speed on a stretch smooth enough to jump from (not skipping over
## bumps), settled on the ground.
func _start(sled: Sled) -> void:
	for d in range(60, 2000, 37):
		sled.place_at(float(d), 0.0, 15.0)
		for i in 30:
			sled.step(DT, 0.0, false, false)
		if sled.on_ground and float(sled.get("_ground_time")) > 0.15:
			return
	push_error("no smooth stretch to jump from")
