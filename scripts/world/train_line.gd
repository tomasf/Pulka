class_name TrainLine
extends Node3D
## A train shuttling along one track of a rail yard. It drives out of one
## tunnel, through the yard and into the other, then comes round again.

## From a car's middle to its front and rear ends, the locomotive's cab
## reaching a little further forward; and the gap at each coupling.
const LOCO_FRONT := 7.6
const LOCO_REAR := 8.0
const WAGON_HALF := 7.0
const COUPLING := 0.8
## Bogie pivots this far either side of a car's middle.
const BOGIE := 5.0
## Further than this from the player (along the slope) a train is out of
## sight: its cars are hidden and not laid out on the track.
const SIGHT := 260.0

var obstacles: Array[Obstacle] = []

var _world: SlopeWorld
var _span := Vector3.ZERO
var _lane := 0.0
var _direction := 1.0
var _speed := 15.0
var _head := 0.0
## Distance along the slope where the last car ends.
var _tail := 0.0
## Per car, how far (down the slope) it is moved to close its coupling:
## measured each frame and used the next, as bends change slowly.
var _nudge := PackedFloat32Array()
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
	if (_direction > 0.0 and _tail > _span.y) or (_direction < 0.0 and _tail < _span.x):
		_head = _span.x - 2.0 if _direction > 0.0 else _span.y + 2.0
		_wait = randf_range(1.0, 4.0)
		_honked = false
	var approaching := (_head - player_d) * -_direction > 0.0
	if not _honked and approaching and absf(_head - player_d) < 90.0 and obstacles[0].visible:
		_honked = true
		_horn.play()
	if _in_sight(player_d):
		_place()
	else:
		_hide()


## Near any rider (the one in front, or another further back).
func _in_sight(player_d: float) -> bool:
	var riders := _world.rider_ds if not _world.rider_ds.is_empty() else PackedFloat32Array([player_d])
	for d in riders:
		if absf(_head - d) < SIGHT or absf(_tail - d) < SIGHT:
			return true
	return false


func finished(player_d: float) -> bool:
	return player_d > _span.y + 80.0


## Lays the cars out back from the head of the train. Cars are spaced by
## length along the track, which winds across the slope and so runs longer
## than the distance down it; each car is also nudged so the gap to the one
## ahead really is a coupling where the track bends.
func _place() -> void:
	_nudge.resize(obstacles.size())
	var d := _head
	var stretch := _stretch(d)
	var rear := Vector3.INF
	var backward := Vector3.ZERO
	for i in obstacles.size():
		var car := obstacles[i]
		var front_half := LOCO_FRONT if i == 0 else WAGON_HALF
		var middle := d - _direction * front_half / stretch + _nudge[i]
		stretch = _stretch(middle)
		_set_car(car, middle, stretch)
		if rear != Vector3.INF:
			# Signed: negative where the cars overlap.
			var gap := (car.transform * Vector3(0, 0, -front_half) - rear).dot(backward)
			_nudge[i] = clampf(_nudge[i] + _direction * (gap - COUPLING) / stretch, -6.0, 6.0)
		var rear_half := LOCO_REAR if i == 0 else WAGON_HALF
		rear = car.transform * Vector3(0, 0, rear_half)
		backward = car.transform.basis.z.normalized()
		d = middle - _direction * (rear_half + COUPLING) / stretch
	_tail = d


## Out of sight: only the tail is kept moving, at the train's length down
## the slope (shorter than along the track, so it comes round a bit early).
func _hide() -> void:
	for car in obstacles:
		car.visible = false
	var length := LOCO_FRONT + LOCO_REAR + (obstacles.size() - 1) * WAGON_HALF * 2.0 + obstacles.size() * COUPLING
	_tail = _head - _direction * length


## Rests a car on its two bogies so it pitches and turns with the track.
func _set_car(car: Obstacle, d: float, stretch: float) -> void:
	car.visible = d > _span.x + 5.0 and d < _span.y - 5.0
	var front := _rail_point(d + _direction * BOGIE / stretch)
	var back := _rail_point(d - _direction * BOGIE / stretch)
	car.transform = Transform3D(Basis.looking_at(front - back, Vector3.UP), (front + back) * 0.5)


## Metres of track per metre down the slope at distance d.
func _stretch(d: float) -> float:
	return maxf(_rail_point(d + 1.0).distance_to(_rail_point(d - 1.0)) * 0.5, 1.0)


## Top of the rails on this train's track at distance d.
func _rail_point(d: float) -> Vector3:
	return _world.regions.lane_point(_lane, d, 0.22)
