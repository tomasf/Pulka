extends SceneTree
## Checks which collisions crash and which you survive.
## Run: Godot --headless --path . --script res://tools/collision_test.gd -- --mute
## Repeat with --no-crash to check that jumps survive while crashes are disabled.


var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.call("_start_run")
	await create_timer(3.5).timeout
	var sled: Sled = main.get("_sled")
	var no_crash := OS.get_cmdline_user_args().has("--no-crash")
	_check("landing on a head is survived", await _try(main, sled, Obstacle.Kind.PERSON, Props.person(0), 1.75, false) == false)
	_check("landing on a head still bounces", not sled.on_ground and sled.velocity.y > 0.0)
	_check("landing on a moose is survived", await _try(main, sled, Obstacle.Kind.MOOSE, Props.moose(), 2.6, false) == false)
	_check("landing on a car roof is survived", await _try(main, sled, Obstacle.Kind.CAR, Props.Rig.of(Props.car(0)), 1.5, false) == false)
	_check("landing on a car roof still bounces", not sled.on_ground and sled.velocity.y > 0.0)
	_check("ground collisions respect --no-crash", await _try(main, sled, Obstacle.Kind.PERSON, Props.person(1), 0.0, true, no_crash) == not no_crash)
	_check("sliding into a log bumps you over it", await _try(main, sled, Obstacle.Kind.LOG, Props.Rig.of(Props.fallen_log()), 0.0, true) == false and not sled.on_ground)
	_check("a small hop clears a log", await _try(main, sled, Obstacle.Kind.LOG, Props.Rig.of(Props.fallen_log()), 0.3, false) == false)
	sled.place_at(8.0, 0.0, 15.0)
	sled.step(1.0 / 60.0, 0.0, 0.0, 0.0, true)
	_check("jump input still leaves the ground", not sled.on_ground)
	if no_crash:
		var lives: int = main.get("_lives")
		main.call("_crash", "Test")
		_check("other crash causes are disabled", not sled.crashed and main.get("_lives") == lives)
	print("collision test: %s" % ("all passed" if _failures == 0 else "%d failed" % _failures))
	quit(_failures)


## Puts an obstacle right under the sled at `height` above its base and
## reports whether that made the sled crash.
func _try(main: Node, sled: Sled, kind: Obstacle.Kind, rig: Props.Rig, height: float, grounded: bool, ignored := false) -> bool:
	sled.place_at(sled.distance() + 30.0, 0.0, 15.0)
	sled.invulnerable_time = 0.0
	var field: TerrainField = main.get("_field")
	var obstacle := Obstacle.new().configure(kind, rig, field)
	var ground := field.height_world(sled.position.x, sled.position.z)
	obstacle.position = Vector3(sled.position.x, ground, sled.position.z)
	sled.position.y = ground + height
	sled.on_ground = grounded
	var world: SlopeWorld = main.get("_world")
	world.add_child(obstacle)
	var chunk := world.get_child(world.get_child_count() - 2) as Chunk
	for child in world.get_children():
		if child is Chunk and (child as Chunk).index == int(floorf(sled.distance() / SlopeWorld.CHUNK_LENGTH)):
			chunk = child
	chunk.obstacles.append(obstacle)
	var velocity := sled.velocity
	var lives: int = main.get("_lives")
	main.call("_check_collisions")
	if ignored:
		_check("ignored obstacles have no impact", not obstacle.hit and sled.velocity == velocity and main.get("_lives") == lives)
	var crashed := sled.crashed
	chunk.obstacles.erase(obstacle)
	obstacle.queue_free()
	if crashed:
		await create_timer(2.6).timeout
		main.set("_lives", 3)
	return crashed


func _check(what: String, ok: bool) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		_failures += 1
