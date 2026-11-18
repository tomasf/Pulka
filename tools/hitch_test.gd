extends SceneTree
## Where does the ride stutter? Runs an autopilot ride headless into a region
## and reports every frame whose world update or game logic takes long.
## Run: Godot --headless --path . --script res://tools/hitch_test.gd -- [region]

const FRAMES := 1800
const DT := 1.0 / 60.0
const SPIKE_MS := 4.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Quality.force_tv = true
	var args := OS.get_cmdline_user_args()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.set("_autopilot", true)
	main.set("_no_crash", true)
	main.set("_muted", true)
	main.set("_start_region", args[0] if args.size() > 0 else "rail")
	main.call("_start_run")
	main.set("state", 2)  # PLAYING, skipping the countdown.
	var sled: Sled = main.get("_sled")
	sled.frozen = false
	sled.place_at(sled.distance() - 380.0)
	main.process_mode = Node.PROCESS_MODE_DISABLED
	var world: SlopeWorld = main.get("_world")
	var spikes := 0
	var worst := 0
	for frame in FRAMES:
		sled.step(DT, main.call("_autopilot_steer"), false)
		var start := Time.get_ticks_usec()
		world.update_world(sled.distance(), DT)
		var spent := Time.get_ticks_usec() - start
		start = Time.get_ticks_usec()
		await process_frame
		var engine := Time.get_ticks_usec() - start
		worst = maxi(worst, spent)
		if spent > SPIKE_MS * 1000.0:
			spikes += 1
			print("%5d m  world %5.1f ms  engine %5.1f ms  %s" % [int(sled.distance()), spent / 1000.0, engine / 1000.0, TerrainField.Region.keys()[world.field.region(sled.distance())]])
	print("%d spikes, worst world update %.1f ms" % [spikes, worst / 1000.0])
	quit()
