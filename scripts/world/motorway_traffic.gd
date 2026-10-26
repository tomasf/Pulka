class_name MotorwayTraffic
extends Node3D
## Cars and lorries on a swept motorway: two lanes roll downhill a little
## slower than you, two come the other way. They join and leave with the
## road as it sweeps in and out from the side.

var obstacles: Array[Obstacle] = []

var _world: SlopeWorld
var _span := Vector3.ZERO
## Parallel to `obstacles`: lane index and current distance of each vehicle.
var _lanes := PackedInt32Array()
var _ds := PackedFloat32Array()
var _speeds := PackedFloat32Array()
var _honked: Array[bool] = []


func setup(world: SlopeWorld, span: Vector3) -> MotorwayTraffic:
	_world = world
	_span = span
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(world.field.world_seed, int(span.x) + 7))
	var length := span.y - span.x
	for lane in RegionBuilder.MOTORWAY_LANES.size():
		var info: Array = RegionBuilder.MOTORWAY_LANES[lane]
		var d := span.x + rng.randf_range(0.0, 30.0)
		while d < span.y:
			var lorry := rng.randf() < 0.3
			var mesh := RegionProps.truck(rng.randi_range(0, 2)) if lorry else Props.car(rng.randi_range(0, Palette.CARS.size() - 1))
			var vehicle := Obstacle.new().configure(Obstacle.Kind.TRUCK if lorry else Obstacle.Kind.CAR, Props.Rig.of(mesh), world.field)
			vehicle.follow_terrain = false
			if rng.randf() < 0.4:
				var hum := AudioStreamPlayer3D.new()
				hum.stream = world.engine_sound
				hum.bus = SoundBank.SFX_BUS
				hum.pitch_scale = rng.randf_range(0.6, 0.8) if lorry else rng.randf_range(0.9, 1.3)
				hum.unit_size = 7.0
				hum.max_distance = 100.0
				hum.autoplay = true
				vehicle.add_child(hum)
			add_child(vehicle)
			obstacles.append(vehicle)
			_lanes.append(lane)
			_ds.append(d)
			_speeds.append(rng.randf_range(float(info[2]), float(info[3])))
			_honked.append(false)
			d += rng.randf_range(25.0, 60.0) + (12.0 if lorry else 0.0)
	_place_all()
	return self


func tick(delta: float, player_d: float) -> void:
	for i in obstacles.size():
		var info: Array = RegionBuilder.MOTORWAY_LANES[_lanes[i]]
		var direction: float = info[1]
		_ds[i] += direction * _speeds[i] * delta
		# Off the end of the motorway: rejoin at the other end.
		if direction > 0.0 and _ds[i] > _span.y:
			_ds[i] -= _span.y - _span.x
			_honked[i] = false
		elif direction < 0.0 and _ds[i] < _span.x:
			_ds[i] += _span.y - _span.x
			_honked[i] = false
		var gap := _ds[i] - player_d
		if direction < 0.0 and not _honked[i] and gap > 0.0 and gap < 45.0:
			var car := obstacles[i]
			var lateral := absf(car.position.x - _world.regions.lane_x(0.0, player_d) - float(info[0]))
			if lateral < 30.0:
				_honked[i] = true
				_world.honk(car.global_position)
	_place_all()


func finished(player_d: float) -> bool:
	return player_d > _span.y + 80.0


func _place_all() -> void:
	var regions := _world.regions
	for i in obstacles.size():
		var info: Array = RegionBuilder.MOTORWAY_LANES[_lanes[i]]
		var d := _ds[i]
		var vehicle := obstacles[i]
		vehicle.visible = d > _span.x + 2.0 and d < _span.y - 2.0
		vehicle.transform = Transform3D(regions.lane_basis(float(info[0]), d, float(info[1])), regions.lane_point(float(info[0]), d, 0.02))
