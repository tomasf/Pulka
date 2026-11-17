class_name HarborCrane
extends Node3D
## One regional actor owns the load, trolley and cables. Both riders see
## the same motion; it survives until the last rider has passed the port.
var obstacles: Array[Obstacle] = []
var _field: TerrainField
var _span := Vector3.ZERO
var _d := 0.0
var _time := 0.0
var _load: Obstacle
var _trolley: MeshInstance3D
var _cables: Array[MeshInstance3D] = []


func setup(world: SlopeWorld, span: Vector3) -> HarborCrane:
	_field = world.field
	_span = span
	_d = span.x + 232
	_time = _field.hash01(int(span.x), 832) * TAU
	var tower := MeshInstance3D.new()
	tower.mesh = gantry()
	tower.position = Vector3(_field.center_x(_d), _field.harbor_height(_d), -_d)
	add_child(tower)
	_load = Obstacle.new().configure(Obstacle.Kind.CONTAINER, Props.Rig.of(ContainerHarbor.cargo(0)), _field)
	_load.follow_terrain = false
	_load.visual.scale = Vector3(0.8, 0.75, 0.4)
	_load.half_extents = Vector2(2.08, 3.2)
	_load.top = 3.0
	add_child(_load)
	obstacles.append(_load)
	_trolley = MeshInstance3D.new()
	_trolley.mesh = trolley()
	add_child(_trolley)
	for i in 4:
		var cable := MeshInstance3D.new()
		cable.mesh = rope()
		add_child(cable)
		_cables.append(cable)
	_place()
	return self


func tick(delta: float, _player_d: float) -> void:
	var old := _load.position
	_time += delta
	_place()
	_load.velocity = (_load.position - old) / maxf(delta, 0.0001)


func finished(last_rider_d: float) -> bool:
	return last_rider_d > _span.y + 80


func _place() -> void:
	var x := _field.center_x(_d) + sin(_time * 0.48) * 8.5
	var base := _field.harbor_height(_d)
	_load.position = Vector3(x, base + 2.7 + sin(_time * 0.61) * 1.8, -_d)
	_trolley.position = Vector3(x, base + 14.2, -_d)
	for i in 4:
		var at := _load.position + Vector3(-1.7 if i % 2 == 0 else 1.7, 3, -2.7 if i < 2 else 2.7)
		var length := base + 14.2 - at.y
		_cables[i].position = at + Vector3.UP * length * 0.5
		_cables[i].scale.y = length


static func gantry() -> ArrayMesh:
	return Props.cached_mesh("harbor_gantry", func() -> ArrayMesh:
		var m := MeshKit.new()
		var orange := Color("d78d38")
		for x in [-23.0, 24.0]:
			for z in [-5.0, 5.0]:
				m.box(Vector3(1, 15, 1.1), Vector3(x, 6.5, z), orange)
				m.box(Vector3(1.6, 1, 2), Vector3(x, 0.5, z), Color("354451"))
			m.box(Vector3(1.1, 1, 12), Vector3(x, 8.3, 0), orange)
			m.box(Vector3(0.45, 12, 0.45), Vector3(x, 6.5, 0), orange, Vector3(0.7, 0, 0))
		for z in [-4.0, 4.0]:
			m.box(Vector3(51, 1.4, 0.8), Vector3(0, 14.5, z), orange)
			m.box(Vector3(51, 0.25, 0.3), Vector3(0, 16, z), Color("e7c185"))
			for x in range(-24, 25, 4):
				m.box(Vector3(0.12, 1.4, 0.12), Vector3(x, 15.4, z), Color("e7c185"))
		m.box(Vector3(4, 3, 3), Vector3(-18, 12, 0), orange)
		m.box(Vector3(3.6, 1.5, 0.1), Vector3(-18, 12.5, 1.55), Color("304b64"))
		return m.build())


static func trolley() -> ArrayMesh:
	return Props.cached_mesh("harbor_trolley", func() -> ArrayMesh:
		var m := MeshKit.new()
		m.box(Vector3(5, 0.8, 8), Vector3.ZERO, Color("3d4f5d"))
		return m.build())


static func rope() -> ArrayMesh:
	return Props.cached_mesh("harbor_rope", func() -> ArrayMesh:
		var m := MeshKit.new()
		m.cylinder(0.035, 1, Vector3.ZERO, Color("7c8b98"), 5)
		return m.build())
