class_name Flyover
extends Node3D
## An airliner roaring low across the airport just ahead of the player,
## again and again while they are on the runway. Scenery only.

var obstacles: Array[Obstacle] = []

var _world: SlopeWorld
var _span := Vector3.ZERO
var _plane: Node3D
var _jet: AudioStreamPlayer3D
var _heading := 1.0
var _d := 0.0
var _x := 0.0
var _idle := 0.0


func setup(world: SlopeWorld, span: Vector3) -> Flyover:
	_world = world
	_span = span
	_plane = MeshInstance3D.new()
	(_plane as MeshInstance3D).mesh = RegionProps.plane(1)
	_plane.visible = false
	add_child(_plane)
	_jet = AudioStreamPlayer3D.new()
	_jet.stream = world.jet_sound
	_jet.bus = SoundBank.SFX_BUS
	_jet.unit_size = 45.0
	_jet.max_distance = 500.0
	_plane.add_child(_jet)
	return self


func tick(delta: float, player_d: float) -> void:
	if not _plane.visible:
		_idle -= delta
		if _idle <= 0.0 and player_d > _span.x - 40.0 and player_d < _span.y - 120.0:
			_launch(player_d)
		return
	_x += _heading * 85.0 * delta
	var field := _world.field
	var center := field.center_x(_d)
	_plane.position = Vector3(center + _x, field.height(center, _d, false) + 26.0, -_d)
	if absf(_x) > 450.0:
		_plane.visible = false
		_idle = 5.0


func _launch(player_d: float) -> void:
	_heading = -1.0 if randf() < 0.5 else 1.0
	_x = -_heading * 450.0
	_d = player_d + 160.0
	_plane.rotation = Vector3(0.12, atan2(-_heading, 0.0), 0.0)
	_plane.visible = true
	_jet.play()


func finished(player_d: float) -> bool:
	return player_d > _span.y + 60.0
