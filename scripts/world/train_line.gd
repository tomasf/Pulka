class_name TrainLine
extends Node3D
## A train shuttling along one track of a rail yard. It drives out of one
## tunnel, through the yard and into the other, then comes round again.

const CAR_LENGTH := 15.0

var obstacles: Array[Obstacle] = []

var _world: SlopeWorld
var _span := Vector3.ZERO
var _lane := 0.0
var _direction := 1.0
var _speed := 15.0
var _head := 0.0
var _wait := 0.0
var _honked := false
var _horn: AudioStreamPlayer3D


## `direction` +1 runs downhill (you can overtake it), -1 comes at you.
func setup(world: SlopeWorld, span: Vector3, lane: float, direction: float, speed: float, cars: int, head_start: float) -> TrainLine:
	_world = world
	_span = span
	_lane = lane
	_direction = direction
	_speed = speed
	for i in cars:
		var mesh := RegionProps.locomotive() if i == 0 else RegionProps.wagon(i)
		var car := Obstacle.new().configure(Obstacle.Kind.TRAIN, Props.Rig.of(mesh), world.field)
		car.follow_terrain = false
		add_child(car)
		obstacles.append(car)
	var hum := AudioStreamPlayer3D.new()
	hum.stream = world.engine_sound
	hum.bus = SoundBank.SFX_BUS
	hum.pitch_scale = 0.55
	hum.unit_size = 10.0
	hum.max_distance = 140.0
	hum.autoplay = true
	obstacles[0].add_child(hum)
	_horn = AudioStreamPlayer3D.new()
	_horn.stream = world.horn_sound
	_horn.bus = SoundBank.SFX_BUS
	_horn.unit_size = 25.0
	_horn.max_distance = 300.0
	obstacles[0].add_child(_horn)
	_head = (span.x + head_start) if direction > 0.0 else (span.y - head_start)
	_place()
	return self


func tick(delta: float, player_d: float) -> void:
	if _wait > 0.0:
		_wait -= delta
	else:
		_head += _direction * _speed * delta
	var tail := _head - _direction * obstacles.size() * CAR_LENGTH
	if (_direction > 0.0 and tail > _span.y) or (_direction < 0.0 and tail < _span.x):
		_head = _span.x - 2.0 if _direction > 0.0 else _span.y + 2.0
		_wait = randf_range(1.0, 4.0)
		_honked = false
	var approaching := (_head - player_d) * -_direction > 0.0
	if not _honked and approaching and absf(_head - player_d) < 90.0 and obstacles[0].visible:
		_honked = true
		_horn.play()
	_place()


func finished(player_d: float) -> bool:
	return player_d > _span.y + 80.0


func _place() -> void:
	for i in obstacles.size():
		var car := obstacles[i]
		var d := _head - _direction * (i * CAR_LENGTH + CAR_LENGTH * 0.5)
		car.visible = d > _span.x + 5.0 and d < _span.y - 5.0
		# Rest the car on its two bogies so it pitches and turns with the track.
		var front := _rail_point(d + _direction * 5.0)
		var back := _rail_point(d - _direction * 5.0)
		car.transform = Transform3D(Basis.looking_at(front - back, Vector3.UP), (front + back) * 0.5)


## Top of the rails on this train's track at distance d.
func _rail_point(d: float) -> Vector3:
	return _world.regions.lane_point(_lane, d, 0.22)
