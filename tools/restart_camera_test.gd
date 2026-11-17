extends SceneTree
## A retry relocates to a fresh start before recording the local intro arc.
## The first start from a live picker must still keep its exact camera pose.
var failures := 0

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_process(false)
	main.set("_autopilot", true)
	main.set("_vehicle", 0)
	main.call("_enter_menu")
	main.call("_choose_solo")
	var players: Array = main.get("_players")
	var camera: ChaseCamera = players[0].camera
	var preview := camera.transform
	main.call("_start_run")
	_check("normal picker start preserves the exact preview pose", camera.transform.is_equal_approx(preview))
	for old_state in [3, 4]:
		for distance in [800.0, 50000.0]:
			var p: Player = players[0]
			p.sled.place_at(distance, 0, 30)
			p.camera.position = p.sled.position + Vector3(4, 3, 6)
			p.camera.mode = ChaseCamera.Mode.CRASH
			p.camera.add_shake(1)
			main.set("state", old_state)
			main.call("_start_run")
			_check("solo retry from state %d / %.0f m starts beside the rider" % [old_state, distance], _near_start(p) and p.camera._shake == 0 and main.get("state") == 1 and p.sled.frozen)
			_check("retry has no long flight on the first frame", _intro_stays_local(main, players))
	main.call("_enter_menu")
	main.call("_on_hud_pressed", &"duo")
	players = main.get("_players")
	var previews: Array[Transform3D] = []
	for p in players: previews.append(p.camera.transform)
	main.call("_start_run")
	var preserved := players.size() == 2
	for i in players.size(): preserved = preserved and players[i].camera.transform.is_equal_approx(previews[i])
	_check("normal race start preserves both preview cameras", preserved)
	for old_state in [3, 4]:
		for p: Player in players:
			p.sled.place_at(4000 + p.index * 600, 0, 25)
			p.camera.position = p.sled.position + Vector3(5, 3, 8)
			p.camera.mode = ChaseCamera.Mode.CRASH
			p.camera.add_shake(1)
		main.set("state", old_state)
		main.call("_start_run")
		var local := true
		for p: Player in players: local = local and _near_start(p) and absf(p.camera._start_offset) < 0.001 and p.camera._shake == 0
		_check("race retry from state %d resets both cameras to their own riders" % old_state, local)
		_check("both race intro arcs stay near the new start", _intro_stays_local(main, players))
	main.queue_free()
	await process_frame
	await process_frame
	print("restart camera test: %s" % ("all passed" if failures == 0 else "%d failed" % failures))
	quit(failures)

func _near_start(p: Player) -> bool:
	return p.camera.position.distance_to(p.sled.position) < 8 and p.camera._start_relative.length() < 8 and p.camera.mode == ChaseCamera.Mode.START

func _intro_stays_local(main: Node, players: Array) -> bool:
	var smooth := true
	for frame in 70:
		for p: Player in players:
			var old := p.camera.position
			p.camera.update_camera(1.0 / 60)
			smooth = smooth and p.camera.position.distance_to(old) < 0.4 and p.camera.position.distance_to(p.sled.position) < 8
	return smooth

func _check(message: String, condition: bool) -> void:
	print(("  ok    " if condition else "  FAIL  ") + message)
	if not condition: failures += 1
