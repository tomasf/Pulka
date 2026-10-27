class_name Takeoff
extends Node3D
## An airliner taking off down the runway just ahead of the player: it
## accelerates away, rotates and climbs out over the end of the airport.

var obstacles: Array[Obstacle] = []

var _world: SlopeWorld
var _span := Vector3.ZERO
var _plane: Obstacle
var _jet: AudioStreamPlayer3D
var _rolling := false
var _d := 0.0
var _start := 0.0
var _speed := 0.0


func setup(world: SlopeWorld, span: Vector3) -> Takeoff:
	_world = world
	_span = span
	_plane = Obstacle.new().configure(Obstacle.Kind.PLANE, Props.Rig.of(RegionProps.plane(0)), world.field)
	_plane.follow_terrain = false
	_plane.visible = false
	add_child(_plane)
	obstacles.append(_plane)
	_jet = AudioStreamPlayer3D.new()
	_jet.stream = world.jet_sound
	_jet.bus = SoundBank.SFX_BUS
	_jet.unit_size = 40.0
	_jet.max_distance = 500.0
	_plane.add_child(_jet)
	return self


func tick(delta: float, player_d: float) -> void:
	if not _rolling:
		if player_d > _span.x + 10.0 and player_d < _span.y - 150.0:
			_rolling = true
			_start = player_d + 60.0
			_d = _start
			_speed = 42.0
			_plane.visible = true
			_jet.play()
		return
	_speed += 9.0 * delta
	_d += _speed * delta
	var field := _world.field
	var climb := maxf(_d - _start - 110.0, 0.0)
	var lift := climb * climb * 0.004
	var cx := field.center_x(_d)
	var ground := Vector3(cx, field.height(cx, _d, false), -_d)
	var ahead := Vector3(field.center_x(_d + 2.0), field.height(field.center_x(_d + 2.0), _d + 2.0, false), -(_d + 2.0)) - ground
	var pitch := clampf(climb * 0.004, 0.0, 0.25)
	_plane.transform = Transform3D(Basis.looking_at(ahead, Vector3.UP) * Basis(Vector3.RIGHT, pitch), ground + Vector3.UP * lift)
	if _d > _span.y + 400.0:
		_plane.visible = false


func finished(player_d: float) -> bool:
	return player_d > _span.y + 60.0
