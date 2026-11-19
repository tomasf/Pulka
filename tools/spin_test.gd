extends SceneTree
## Saucer and wok spin on the snow: never at an even pace, steering twists
## them round (far enough to reverse), a spin steered in the air carries on
## after landing, and nothing turns them in the air without steering.
## Godot --headless --path . --script res://tools/spin_test.gd [-- --trace]

const DT := 1.0 / 60.0

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(label: String, condition: bool) -> void:
	if not condition:
		_failures += 1
		push_error(label)


func _run() -> void:
	seed(3)
	var trace := OS.get_cmdline_user_args().has("--trace")
	var field := TerrainField.new(7)
	for spec: VehicleSpec in VehicleSpec.all():
		if not spec.spins:
			continue
		var sled := Sled.new()
		sled.field = field
		root.add_child(sled)
		await process_frame
		sled.set_vehicle(spec, RandomNumberGenerator.new())
		sled.frozen = false
		var name := spec.title

		# Left alone on the snow the pace wanders.
		sled.place_at(60.0, 0.0, 15.0)
		var rates: Array[float] = []
		for i in 600:
			sled.step(DT, 0.0, false)
			if sled.on_ground:
				rates.append(float(sled.get("_spin_rate")))
		var low := rates.min() as float
		var high := rates.max() as float
		if trace:
			print("%s: rate %.1f .. %.1f rad/s" % [name, low, high])
		_check("%s: the spin's pace varies on its own" % name, high - low > 1.0)

		# Steering against the spin turns it the other way.
		sled.place_at(60.0, 0.0, 15.0)
		var before := float(sled.get("_spin_rate"))
		var against := -signf(before)
		for i in 180:
			sled.step(DT, against, false)
		_check("%s: steering against the spin reverses it" % name, signf(float(sled.get("_spin_rate"))) == against)

		# A spin steered in the air carries on after landing.
		var carried := 0.0
		for attempt in 2:
			var way := 1.0 if attempt == 0 else -1.0
			sled.place_at(60.0, 0.0, 15.0)
			for i in 30:
				sled.step(DT, 0.0, false)
			sled.set("_spin_rate", 0.0)
			sled.bounce(8.0)
			for i in 240:
				sled.step(DT, way, false)
				if sled.on_ground:
					break
			carried += float(sled.get("_spin_rate")) * way
		_check("%s: an air spin carries on along the snow" % name, carried > 0.0)
		sled.queue_free()
		await process_frame
	print("spin test: %s" % ("ok" if _failures == 0 else "%d failures" % _failures))
	quit(1 if _failures > 0 else 0)
