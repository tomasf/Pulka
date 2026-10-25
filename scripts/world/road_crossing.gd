class_name RoadCrossing
extends Node3D
## A plowed road straight across the slope with traffic in both directions.
## The terrain is flattened around it, so the downhill edge works as a kicker.

const REACH := 190.0
const LANE_OFFSET := 2.2

var road_d := 0.0
var cars: Array[Obstacle] = []
var _center := 0.0
var _level := 0.0


func setup(field: TerrainField, at_d: float, rng: RandomNumberGenerator, engine_sound: AudioStream) -> RoadCrossing:
	road_d = at_d
	_center = field.center_x(at_d)
	_level = field.road_level(at_d)
	_build_surface()
	var difficulty := field.difficulty(at_d)
	for lane in 2:
		var direction := 1.0 if lane == 0 else -1.0
		var z := -(at_d + (LANE_OFFSET if lane == 0 else -LANE_OFFSET))
		var count := 2 + int(round(difficulty * 2.0)) + rng.randi_range(0, 1)
		var speed := rng.randf_range(11.0, 16.0) + difficulty * 7.0
		var spacing := REACH * 2.0 / count
		var offset := rng.randf_range(0.0, spacing)
		for i in count:
			var is_plow := rng.randf() < 0.12
			var mesh := Props.plow() if is_plow else Props.car(rng.randi_range(0, Palette.CARS.size() - 1))
			var car := Obstacle.new().configure(Obstacle.Kind.PLOW if is_plow else Obstacle.Kind.CAR, Props.Rig.of(mesh), field)
			car.position = Vector3(_center - REACH + offset + i * spacing + rng.randf_range(-8.0, 8.0), _level, z)
			car.velocity = Vector3(direction * speed * (0.6 if is_plow else 1.0), 0.0, 0.0)
			car.rotation.y = atan2(-direction, 0.0)
			var hum := AudioStreamPlayer3D.new()
			hum.stream = engine_sound
			hum.bus = SoundBank.SFX_BUS
			hum.unit_size = 5.0
			hum.max_distance = 90.0
			hum.volume_db = -8.0 if not is_plow else -3.0
			hum.pitch_scale = rng.randf_range(0.85, 1.2) * (0.7 if is_plow else 1.0)
			hum.autoplay = true
			car.add_child(hum)
			add_child(car)
			cars.append(car)
	return self


func tick(delta: float) -> void:
	for car in cars:
		car.position += car.velocity * delta
		if car.velocity.x > 0.0 and car.position.x > _center + REACH:
			car.position.x -= REACH * 2.0
		elif car.velocity.x < 0.0 and car.position.x < _center - REACH:
			car.position.x += REACH * 2.0


func _build_surface() -> void:
	var kit := MeshKit.new()
	var width := TerrainField.ROAD_HALF_WIDTH * 2.0
	var y := _level + 0.04
	kit.box(Vector3(REACH * 2.0 + 40.0, 0.08, width), Vector3(_center, y - 0.04, -road_d), Palette.ASPHALT)
	for side in [-1.0, 1.0]:
		kit.box(Vector3(REACH * 2.0 + 40.0, 0.09, 0.15), Vector3(_center, y - 0.03, -road_d + side * (width * 0.5 - 0.4)), Color(0.9, 0.9, 0.9))
		kit.box(Vector3(REACH * 2.0 + 40.0, 0.5, 0.9), Vector3(_center, y + 0.05, -road_d + side * (width * 0.5 + 0.2)), Palette.SNOW_EDGE)
	var dash := -REACH
	while dash < REACH:
		kit.box(Vector3(3.0, 0.09, 0.15), Vector3(_center + dash, y - 0.03, -road_d), Color(0.95, 0.95, 0.95))
		dash += 9.0
	var mesh := MeshInstance3D.new()
	mesh.mesh = kit.build()
	add_child(mesh)
