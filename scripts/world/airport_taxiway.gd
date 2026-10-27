class_name AirportTaxiway
extends Node3D
## A taxiway across the runway: an airliner rolls slowly across while
## baggage tractors zip the other way. Slide under the wings if you dare.

const REACH := 110.0

var obstacles: Array[Obstacle] = []

var _world: SlopeWorld
var _d := 0.0
var _center := 0.0


func setup(world: SlopeWorld, at_d: float, rng: RandomNumberGenerator, with_plane: bool) -> AirportTaxiway:
	_world = world
	_d = at_d
	var field := world.field
	_center = field.center_x(at_d)
	add_child(_surface(field, -7.0, 7.0, 0.04, Color(0.38, 0.4, 0.44)))
	add_child(_surface(field, -0.18, 0.18, 0.06, Color(1.0, 0.8, 0.1)))
	if with_plane:
		_add(Obstacle.Kind.PLANE, RegionProps.plane(rng.randi_range(0, 2)), rng.randf_range(-REACH, REACH), 6.0 * (1.0 if rng.randf() < 0.5 else -1.0), -1.5)
	for i in 2:
		_add(Obstacle.Kind.TUG, RegionProps.tug(), rng.randf_range(-REACH, REACH), 10.0 * (1.0 if i == 0 else -1.0), 3.5 * (1.0 if i == 0 else -1.0))
	return self


## A strip across the slope between two distance offsets, following the
## ground (the slope drops several metres across a taxiway's width).
func _surface(field: TerrainField, from: float, to: float, lift: float, color: Color) -> MeshInstance3D:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var linear := color.srgb_to_linear()
	linear.a = 1.0
	var x := -REACH
	while x < REACH:
		var corners: Array[Vector3] = []
		for offset in [from, to]:
			for step in [0.0, 4.0]:
				var px: float = _center + x + step
				var d: float = _d + offset
				corners.append(Vector3(px, field.height(px, d, false) + lift, -d))
		_world.triangle(vertices, normals, colors, corners[0], corners[1], corners[2], linear)
		_world.triangle(vertices, normals, colors, corners[1], corners[3], corners[2], linear)
		x += 4.0
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, Palette.surface())
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	return instance


func _add(kind: Obstacle.Kind, mesh: Mesh, lateral: float, speed: float, lane: float) -> void:
	var vehicle := Obstacle.new().configure(kind, Props.Rig.of(mesh), _world.field)
	vehicle.follow_terrain = false
	vehicle.velocity = Vector3(speed, 0.0, 0.0)
	vehicle.position = Vector3(_center + lateral, 0.0, -(_d + lane))
	vehicle.rotation.y = atan2(-signf(speed), 0.0)
	var hum := AudioStreamPlayer3D.new()
	hum.stream = _world.engine_sound
	hum.bus = SoundBank.SFX_BUS
	hum.pitch_scale = 1.4 if kind == Obstacle.Kind.TUG else 0.7
	hum.unit_size = 6.0
	hum.max_distance = 90.0
	hum.autoplay = true
	vehicle.add_child(hum)
	add_child(vehicle)
	obstacles.append(vehicle)


func tick(delta: float, _player_d: float) -> void:
	var field := _world.field
	for vehicle in obstacles:
		vehicle.position.x += vehicle.velocity.x * delta
		if vehicle.velocity.x > 0.0 and vehicle.position.x > _center + REACH:
			vehicle.position.x -= REACH * 2.0
		elif vehicle.velocity.x < 0.0 and vehicle.position.x < _center - REACH:
			vehicle.position.x += REACH * 2.0
		vehicle.position.y = field.height(vehicle.position.x, -vehicle.position.z, false)


func finished(player_d: float) -> bool:
	return player_d > _d + 80.0
