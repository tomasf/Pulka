class_name SewerRat
extends Node3D
## Small, harmless wildlife. Four alternating feet and an articulated bare
## tail make the scurrying silhouette distinct from the outdoor animals.
var frightened := false
var velocity := Vector3.ZERO
var _field: TerrainField
var _rng := RandomNumberGenerator.new()
var _home := Vector3.ZERO
var _goal := Vector3.ZERO
var _time := 0.0
var _next_goal := 0.0
var _panic := 0.0
var _scan_in := 0.0
var _awake := false
var _solids: Array[Obstacle] = []
var _feet: Array[MeshInstance3D] = []
var _tail: Array[Node3D] = []
var _body: MeshInstance3D


func configure(field: TerrainField, at: Vector3, seed_value: int, solids: Array[Obstacle]) -> SewerRat:
	_field = field
	_rng.seed = seed_value
	_solids = solids
	_home = at
	_goal = at
	position = at
	_time = _rng.randf() * TAU
	_next_goal = 0
	_body = _mesh(body(_rng.randi_range(0, 1)))
	for i in 4:
		var foot := _mesh(paw())
		foot.position = Vector3(-0.11 if i % 2 == 0 else 0.11, 0.10, -0.19 if i < 2 else 0.18)
		_feet.append(foot)
	var parent: Node3D = self
	for i in 3:
		var joint := Node3D.new()
		joint.position = Vector3(0, 0.12, 0.26) if i == 0 else Vector3(0, -0.015, 0.22)
		parent.add_child(joint)
		var piece := MeshInstance3D.new()
		piece.mesh = tail_piece(i)
		joint.add_child(piece)
		_tail.append(joint)
		parent = joint
	rotation.y = _rng.randf() * TAU
	var surface := field.sewer_surface(at.x, -at.z)
	var up := Vector3(surface.x, surface.y, surface.z)
	var facing := -basis.z
	basis = Basis.looking_at((facing - up * facing.dot(up)).normalized(), up)
	return self


func _mesh(shape: Mesh) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = shape
	instance.visibility_range_end = 90
	instance.visibility_range_end_margin = 15
	add_child(instance)
	return instance


static func clear_at(field: TerrainField, at: Vector3, solids: Array[Obstacle] = []) -> bool:
	var d := -at.z
	if not field.in_sewer(d) or absf(at.x - field.center_x(d)) > 6.5: return false
	var span := field.region_span(d)
	# Also consider the next chunk's barriers, even before it is streamed.
	for i in SewerPipe.BARRIERS.size():
		var barrier: Vector4 = SewerPipe.BARRIERS[i]
		if absf(d - span.x - TerrainField.SEWER_PASSAGES[i + 1].x) < barrier.z + 0.30:
			if absf(at.x - field.center_x(d) - barrier.x) < barrier.y + 0.30: return false
	for obstacle in solids:
		if is_instance_valid(obstacle) and obstacle.overlaps(at + Vector3.UP * 0.15, 0.28): return false
	return true


func tick(delta: float, observers: PackedVector3Array) -> void:
	_scan_in -= delta
	if _scan_in <= 0:
		_scan_in = 0.10
		var closest := INF
		var threat := Vector3.ZERO
		for observer in observers:
			var distance := position.distance_squared_to(observer)
			if distance < closest:
				closest = distance
				threat = observer
		_awake = closest < 70 * 70
		if closest < 8 * 8:
			frightened = true
			_panic = 1.5
			_pick_goal(threat)
	if not _awake: return
	_time += delta
	_next_goal -= delta
	_panic = maxf(0, _panic - delta)
	if _panic == 0: frightened = false
	if _next_goal <= 0 or position.distance_squared_to(_goal) < 0.15: _pick_goal()
	var toward := _goal - position
	toward.y = 0
	if toward.length_squared() > 0.01:
		var direction := toward.normalized()
		velocity = direction * (5.4 if frightened else 2.3)
		var next := position + velocity * minf(delta, toward.length() / velocity.length())
		next.y = _field.sewer_floor(next.x, -next.z) + 0.02
		if clear_at(_field, next, _solids):
			position = next
			var surface := _field.sewer_surface(position.x, -position.z)
			var up := Vector3(surface.x, surface.y, surface.z)
			var along := (direction - up * direction.dot(up)).normalized()
			basis = basis.slerp(Basis.looking_at(along, up), 1 - exp(-14 * delta))
		else:
			velocity = Vector3.ZERO
			_pick_goal()
	var running := velocity.length() > 0.1
	var phase := _time * (22 if frightened else 15)
	_body.position.y = absf(sin(phase)) * 0.02 if running else 0
	for i in _feet.size():
		_feet[i].rotation.x = sin(phase + (0 if i in [0, 3] else PI)) * 0.6 if running else 0
	for i in _tail.size(): _tail[i].rotation.y = sin(phase * 0.45 - i * 0.8) * 0.20


func _pick_goal(threat := Vector3.INF) -> void:
	_next_goal = _rng.randf_range(0.6, 1.4)
	for attempt in 8:
		var direction := Vector3(sin(_rng.randf() * TAU), 0, cos(_rng.randf() * TAU)).normalized()
		if threat != Vector3.INF:
			direction = position - threat
			direction.y = 0
			if direction.length_squared() < 0.01: direction = Vector3.RIGHT
			direction = direction.normalized().rotated(Vector3.UP, _rng.randf_range(-0.8, 0.8))
		var target := position + direction * _rng.randf_range(2, 4)
		if absf(target.z - _home.z) > 10: target.z = _home.z
		target.y = _field.sewer_floor(target.x, -target.z) + 0.02
		if clear_at(_field, target, _solids):
			_goal = target
			return
	_goal = position


static func body(variant: int) -> ArrayMesh:
	return Props.cached_mesh("sewer_rat_%d" % variant, func() -> ArrayMesh:
		var m := MeshKit.new()
		var coat := Color("968674") if variant == 0 else Color("7b8580")
		var rings: Array[PackedVector3Array] = []
		# One continuous arched back tapers through the shoulders and skull
		# into the narrow muzzle, rather than separate round body lumps.
		for section in [Vector4(0.025, 0.07, 0.18, 0.30), Vector4(0.14, 0.15, 0.20, 0.16), Vector4(0.135, 0.15, 0.21, 0.02), Vector4(0.115, 0.115, 0.22, -0.16), Vector4(0.105, 0.10, 0.235, -0.25), Vector4(0.06, 0.055, 0.18, -0.37), Vector4(0.018, 0.022, 0.16, -0.48)]:
			var ring := PackedVector3Array()
			for k in 14:
				var angle := TAU * k / 14
				ring.append(Vector3(cos(angle) * section.x, section.z + sin(angle) * section.y, section.w))
			rings.append(ring)
		m.loft(rings, PackedFloat32Array([1, 1, 1, 1, 1, 1, 1]), Transform3D.IDENTITY, coat)
		m.ellipsoid(Vector3(0.027, 0.022, 0.018), Vector3(0, 0.16, -0.48), Color("bd8c7d"))
		for side in [-1.0, 1.0]:
			m.ellipsoid(Vector3(0.052, 0.07, 0.025), Vector3(side * 0.11, 0.33, -0.20), coat, Vector3(0, side * 0.4, side * -0.25))
			m.ellipsoid(Vector3(0.036, 0.049, 0.012), Vector3(side * 0.114, 0.335, -0.222), Color("b58d80"))
			m.sphere(0.019, Vector3(side * 0.10, 0.255, -0.315), Color("121b18"), Vector3.ONE, 8, 4)
			m.sphere(0.005, Vector3(side * 0.111, 0.263, -0.327), Color("d2d3b5"), Vector3.ONE, 6, 3)
			for i in 3:
				m.box(Vector3(0.13, 0.004, 0.004), Vector3(side * 0.11, 0.17 + i * 0.012, -0.41), Color("b9b7a0"), Vector3(0, side * (i - 1) * 0.4, 0))
		return m.build())


static func paw() -> ArrayMesh:
	return Props.cached_mesh("rat_paw", func() -> ArrayMesh:
		var m := MeshKit.new()
		m.ellipsoid(Vector3(0.026, 0.055, 0.028), Vector3(0, -0.035, 0), Color("9d8171"))
		m.ellipsoid(Vector3(0.04, 0.017, 0.06), Vector3(0, -0.084, -0.025), Color("c29a86"))
		return m.build())


static func tail_piece(index: int) -> ArrayMesh:
	return Props.cached_mesh("rat_tail_%d" % index, func() -> ArrayMesh:
		var m := MeshKit.new()
		m.cylinder(0.025 - index * 0.006, 0.23, Vector3(0, 0, 0.11), Color("b28d7c"), 7, Vector3(PI / 2, 0, 0), 0.020 - index * 0.006)
		return m.build())
