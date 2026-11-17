class_name AmbientBird
extends Node3D
## Decorative wildlife, never a crash obstacle. One tick drives both movement
## and the visible rig, so takeoff starts exactly at the resting feet.
enum State { RESTING, WALKING, ALERT, FLYING, GONE }

var state := State.RESTING
var species := BirdMeshes.Species.CROW
var perched := false
var velocity := Vector3.ZERO
var flight_time := 0.0
var scare_radius := 13.0
var _field: TerrainField
var _rng := RandomNumberGenerator.new()
var _home := Vector3.ZERO
var _outward := Vector3.ZERO
var _escape := Vector3.ZERO
var _walk_to := Vector3.ZERO
var _solids: Array[Obstacle] = []
var _time := 0.0
var _phase := 0.0
var _decision := 0.0
var _alert_time := 0.0
var _scan_in := 0.0
var _nearby := false
var _threat := Vector3.ZERO
var _flight_mesh: Mesh
var _body: MeshInstance3D
var _head: MeshInstance3D
var _feet: Array[MeshInstance3D] = []
var _wings: Array[MeshInstance3D] = []


func configure(terrain: TerrainField, at: Vector3, which: BirdMeshes.Species, seed_value: int, on_perch := false, outward := Vector3.ZERO, solids: Array[Obstacle] = []) -> AmbientBird:
	_field = terrain
	species = which
	perched = on_perch
	_solids = solids
	_rng.seed = seed_value
	_phase = _rng.randf() * TAU
	_time = _phase
	_home = at
	position = at
	_outward = outward
	rotation.y = _rng.randf() * TAU
	var size: float = BirdMeshes.SIZES[species] * _rng.randf_range(0.9, 1.12)
	scale = Vector3.ONE * size
	scare_radius = _rng.randf_range(11, 15)
	_decision = _rng.randf_range(0.5, 2.5)
	_flight_mesh = BirdMeshes.body(species, true)
	_body = _instance(BirdMeshes.body(species))
	_head = _instance(BirdMeshes.head(species))
	_head.position = Vector3(0, 0.39, -0.19)
	for side in [-1, 1]:
		var foot := _instance(BirdMeshes.foot())
		foot.position = Vector3(side * 0.055, 0.112, -0.015)
		_feet.append(foot)
		var wing := _instance(BirdMeshes.wing(species, side))
		wing.position = Vector3(side * 0.115, 0.33, -0.025)
		wing.visible = false
		_wings.append(wing)
	_pose(0)
	return self


func _instance(mesh: Mesh) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.visibility_range_end = 110
	node.visibility_range_end_margin = 15
	add_child(node)
	return node


func tick(delta: float, observers: PackedVector3Array, speeds := PackedFloat32Array()) -> void:
	if state == State.GONE: return
	_time += delta
	if state == State.FLYING:
		_fly(delta)
		_pose(delta)
		return
	_scan_in -= delta
	if _scan_in <= 0:
		_scan_in = 0.075
		var nearest := INF
		var speed := 0.0
		for i in observers.size():
			var distance := position.distance_squared_to(observers[i] + Vector3.UP * 0.5)
			if distance < nearest:
				nearest = distance
				_threat = observers[i]
				speed = speeds[i] if i < speeds.size() else 0.0
		# Fast riders give a slightly earlier warning, rather than running
		# through a bird before its next low-frequency awareness check.
		var radius := scare_radius + minf(speed * 0.20, 7)
		if nearest < radius * radius and state != State.ALERT:
			state = State.ALERT
			_alert_time = 0.0 if nearest < 16 else minf(_rng.randf_range(0.06, 0.22), sqrt(nearest) / maxf(speed, 1) * 0.25)
		_nearby = nearest <= 10000
	if not _nearby: return
	if state == State.ALERT:
		_alert_time -= delta
		if _alert_time <= 0: startle(_threat)
	elif state == State.WALKING:
		_walk(delta)
	else:
		_decision -= delta
		if _decision <= 0:
			_decision = _rng.randf_range(1.2, 3.5)
			if not perched: _choose_walk()
	_pose(delta)


func _choose_walk() -> void:
	var angle := _rng.randf() * TAU
	_walk_to = _home + Vector3(sin(angle), 0, cos(angle)) * _rng.randf_range(0.4, 1.8)
	var d := -_walk_to.z
	if not BirdPopulation.ground_allowed(_field, _walk_to.x, d): return
	_walk_to.y = _field.height_world(_walk_to.x, _walk_to.z) + 0.015
	for obstacle in _solids:
		if is_instance_valid(obstacle) and obstacle.overlaps(_walk_to + Vector3.UP * 0.2, 0.5): return
	state = State.WALKING


func _walk(delta: float) -> void:
	var toward := _walk_to - position
	toward.y = 0
	if toward.length_squared() < 0.008:
		state = State.RESTING
		velocity = Vector3.ZERO
		return
	var direction := toward.normalized()
	rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), 1 - exp(-9 * delta))
	velocity = direction * (0.42 if species == BirdMeshes.Species.BULLFINCH else 0.6)
	position += velocity * minf(delta, toward.length() / velocity.length())
	position.y = _field.height_world(position.x, position.z) + 0.015


func startle(from: Vector3) -> void:
	if state in [State.FLYING, State.GONE]: return
	state = State.FLYING
	flight_time = 0
	var away := position - from
	away.y = 0
	if away.length_squared() < 0.01: away = Vector3(sin(_phase), 0, cos(_phase))
	_escape = (away.normalized() + _outward * 0.6).rotated(Vector3.UP, _rng.randf_range(-0.4, 0.4)).normalized()
	# A push from the feet, followed by acceleration and continuous flapping.
	velocity = Vector3(_escape.x, 3.2, _escape.z)
	_body.mesh = _flight_mesh
	for wing in _wings: wing.visible = true


func _fly(delta: float) -> void:
	flight_time += delta
	var speed := 8.0 if species == BirdMeshes.Species.BULLFINCH else 10.5
	var clearance := _field.height_world(position.x, position.z) + 2.5 - position.y
	var climb := maxf(2.8, minf(8, clearance * 3))
	var desired := _escape * speed + Vector3.UP * climb
	var previous := velocity
	velocity = velocity.lerp(desired, 1 - exp(-3 * delta))
	position += (previous + velocity) * (delta * 0.5)
	var yaw := atan2(-velocity.x, -velocity.z)
	rotation.y = lerp_angle(rotation.y, yaw, 1 - exp(-10 * delta))
	rotation.x = lerpf(rotation.x, 0.1 - atan2(velocity.y, Vector2(velocity.x, velocity.z).length()) * 0.35, 1 - exp(-5 * delta))
	rotation.z = sin(flight_time * 1.6 + _phase) * 0.10 * minf(flight_time, 1)
	if flight_time > 4:
		var fade := clampf((flight_time - 4) / 1.2, 0, 1)
		for child in get_children():
			if child is GeometryInstance3D: child.transparency = fade
	if flight_time > 5.2:
		state = State.GONE
		visible = false


func _pose(delta: float) -> void:
	var flying := state == State.FLYING
	var walking := state == State.WALKING
	var bob := absf(sin(_time * 10)) * 0.015 if walking else sin(_time * 2) * 0.003
	_body.position.y = bob
	_head.position = Vector3(0, 0.39 + bob, -0.19)
	var peck := pow(maxf(0, sin(_time * 1.7 + _phase)), 18) if state == State.RESTING and not perched else 0.0
	_head.rotation.x = lerpf(_head.rotation.x, -peck * 0.9, 1 - exp(-14 * delta))
	_head.position.y -= peck * 0.08
	_head.rotation.y = 0 if flying else sin(_time * 1.4 + _phase) * 0.38
	for i in _feet.size():
		_feet[i].rotation.x = 1.0 if flying else sin(_time * 10 + i * PI) * (0.5 if walking else 0)
		_feet[i].position.y = 0.112 + (0.05 if flying else 0)
	if flying:
		var frequency := 11.5 if species == BirdMeshes.Species.BULLFINCH else 8.5
		var flap := sin(flight_time * frequency * TAU + 0.45 + _phase * 0.6)
		for i in _wings.size():
			var side := -1.0 if i == 0 else 1.0
			_wings[i].rotation.z = side * (flap * 0.88 + 0.12)
			_wings[i].rotation.y = side * (0.08 + maxf(0, -flap) * 0.20)
