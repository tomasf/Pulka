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
var _ds := PackedFloat64Array()
var _flows: Array[TrafficLane] = []
var _flow_indices := PackedInt32Array()
var _honked: Array[bool] = []


func setup(world: SlopeWorld, span: Vector3) -> MotorwayTraffic:
	_world = world
	_span = span
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(world.field.world_seed, int(span.x) + 7))
	var length := span.y - span.x
	for lane in RegionBuilder.MOTORWAY_LANES.size():
		var info: Array = RegionBuilder.MOTORWAY_LANES[lane]
		var direction: float = info[1]
		var flow := TrafficLane.new(length)
		_flows.append(flow)
		# Uniform spacing with small jitter also leaves room across the seam
		# where the last vehicle rejoins ahead of the first one.
		var count := rng.randi_range(2, 4)
		var spacing := length / count
		var offset := rng.randf_range(0, spacing)
		for i in count:
			var progress := fposmod(offset + i * spacing + rng.randf_range(-8, 8), length)
			var d := span.x + progress if direction > 0 else span.y - progress
			var lorry := rng.randf() < 0.25
			var mesh := RegionProps.truck(rng.randi_range(0, 2)) if lorry else Props.car(CarModels.pick(rng))
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
			_flow_indices.append(flow.add(progress, rng.randf_range(float(info[2]), float(info[3])), TrafficLane.vehicle_half_length(vehicle)))
			_honked.append(false)
	_place_all()
	return self


func tick(delta: float, player_d: float) -> void:
	for flow in _flows: flow.step(delta)
	for i in obstacles.size():
		var info: Array = RegionBuilder.MOTORWAY_LANES[_lanes[i]]
		var direction: float = info[1]
		var old := _ds[i]
		var progress := _flows[_lanes[i]].positions[_flow_indices[i]]
		_ds[i] = _span.x + progress if direction > 0 else _span.y - progress
		if (direction > 0 and _ds[i] < old) or (direction < 0 and _ds[i] > old): _honked[i] = false
		var gap := _ds[i] - player_d
		if direction < 0.0 and not _honked[i] and gap > 0.0 and gap < 45.0:
			var car := obstacles[i]
			var lateral := absf(car.position.x - _world.regions.lane_x(0.0, player_d) - float(info[0]))
			if lateral < 30.0:
				_honked[i] = true
				_world.honk(car.global_position)
	_place_all()
	for vehicle in obstacles:
		vehicle.roll_wheels(vehicle.velocity.length() * delta)


func finished(player_d: float) -> bool:
	return player_d > _span.y + 80.0


func _place_all() -> void:
	var regions := _world.regions
	for i in obstacles.size():
		var info: Array = RegionBuilder.MOTORWAY_LANES[_lanes[i]]
		var d := _ds[i]
		var vehicle := obstacles[i]
		vehicle.visible = d > _span.x + 6.0 and d < _span.y - 6.0
		var tangent := regions.lane_point(float(info[0]), d + float(info[1]) * 1.5) - regions.lane_point(float(info[0]), d - float(info[1]) * 1.5)
		var normal := _world.field.motorway_normal(d)
		vehicle.transform = Transform3D(Basis.looking_at(tangent, normal), regions.lane_point(float(info[0]), d, 0.015))
		vehicle.velocity = tangent / 3 * _flows[_lanes[i]].speeds[_flow_indices[i]]
