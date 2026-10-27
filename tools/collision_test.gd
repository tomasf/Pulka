extends SceneTree
## Checks which collisions crash and which you survive.
## Run: Godot --headless --path . --script res://tools/collision_test.gd -- --mute
## Repeat with --no-crash to check that jumps survive while crashes are disabled.


var _failures := 0
var _flew := false
## Whether the last _try made any contact at all (a hit or a knock).
var _touched := false


## The same hit on a person at 14 m/s: survived on a pulka, a crash on a tefat.
func _protection_matters(main: Node, sled: Sled) -> bool:
	var specs := VehicleSpec.all()
	var rng := RandomNumberGenerator.new()
	sled.set_vehicle(specs[0], rng)
	var pulka := await _try(main, sled, Obstacle.Kind.PERSON, Props.person(3), 0.0, true, false, 14.0)
	sled.set_vehicle(specs[3], rng)
	var tefat := await _try(main, sled, Obstacle.Kind.PERSON, Props.person(4), 0.0, true, false, 14.0)
	sled.set_vehicle(specs[0], rng)
	return not pulka and tefat


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
	_check("ground collisions respect --no-crash", await _try(main, sled, Obstacle.Kind.PERSON, Props.person(1), 0.0, true, no_crash, 25.0) == not no_crash)
	if not no_crash:
		_check("hitting a person at speed crashes", await _try(main, sled, Obstacle.Kind.PERSON, Props.person(2), 0.0, true, false, 25.0))
		_check("a person you hit goes flying", _flew)
		_check("nudging a dog slowly is just a bump", not await _try(main, sled, Obstacle.Kind.DOG, Props.dog(), 0.0, true, false, 4.0))
		_check("a slow knock into a spruce is survived", not await _try(main, sled, Obstacle.Kind.TREE, Props.Rig.of(Props.spruce(0)), 0.0, true, false, 6.0))
		_check("a fast hit on a spruce trunk crashes", await _try(main, sled, Obstacle.Kind.TREE, Props.Rig.of(Props.spruce(0)), 0.0, true, false, 20.0))
		_check("brushing a spruce's top branches is survived", not await _try(main, sled, Obstacle.Kind.TREE, Props.Rig.of(Props.spruce(0)), 5.0, false, false, 20.0))
		_check("riding under a spruce's low branches is felt", not await _try(main, sled, Obstacle.Kind.TREE, Props.Rig.of(Props.spruce(0)), 0.0, true, false, 15.0, 1.6) and _touched)
		_check("trees beside the track can be hit", _edge_trees_are_solid(main))
		_check("cones are harmless", not await _try(main, sled, Obstacle.Kind.CONE, Props.Rig.of(RegionProps.cone()), 0.0, true, false, 25.0) and _flew)
		_check("landing on a rock is survived", not await _try(main, sled, Obstacle.Kind.ROCK, Props.Rig.of(Props.rock(0)), 0.8, false))
		_check("a pulka shrugs off what floors a tefat", await _protection_matters(main, sled))
	_check("sliding into a log bumps you over it", await _try(main, sled, Obstacle.Kind.LOG, Props.Rig.of(Props.fallen_log()), 0.0, true) == false and not sled.on_ground)
	_check("a small hop clears a log", await _try(main, sled, Obstacle.Kind.LOG, Props.Rig.of(Props.fallen_log()), 0.3, false) == false)
	sled.place_at(8.0, 0.0, 15.0)
	sled.step(1.0 / 60.0, 0.0, 0.0, true)
	_check("jump input still leaves the ground", not sled.on_ground)
	if no_crash:
		var lives: int = main.get("_lives")
		main.call("_crash", "Test")
		_check("other crash causes are disabled", not sled.crashed and main.get("_lives") == lives)
	print("collision test: %s" % ("all passed" if _failures == 0 else "%d failed" % _failures))
	quit(_failures)


## Puts an obstacle right under the sled at `height` above its base and
## reports whether that made the sled crash.
func _try(main: Node, sled: Sled, kind: Obstacle.Kind, rig: Props.Rig, height: float, grounded: bool, ignored := false, speed := 15.0, aside := 0.0) -> bool:
	sled.place_at(sled.distance() + 30.0, 0.0, speed)
	sled.invulnerable_time = 0.0
	var field: TerrainField = main.get("_field")
	var obstacle := Obstacle.new().configure(kind, rig, field)
	var ground := field.height_world(sled.position.x, sled.position.z)
	obstacle.position = Vector3(sled.position.x + aside, field.height_world(sled.position.x + aside, sled.position.z), sled.position.z)
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
	_flew = obstacle.flying
	_touched = obstacle.hit or sled.velocity != velocity
	chunk.obstacles.erase(obstacle)
	obstacle.queue_free()
	if crashed:
		await create_timer(3.0).timeout
		main.set("_lives", 3)
	return crashed


## The batched trees just outside the track edge carry colliders too.
func _edge_trees_are_solid(main: Node) -> bool:
	var field: TerrainField = main.get("_field")
	var world: SlopeWorld = main.get("_world")
	for child in world.get_children():
		if child is Chunk:
			for obstacle in (child as Chunk).obstacles:
				var d := -obstacle.position.z
				if obstacle.kind == Obstacle.Kind.TREE and absf(obstacle.position.x - field.center_x(d)) > field.half_width(d) + 2.0:
					return true
	return false


func _check(what: String, ok: bool) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		_failures += 1
