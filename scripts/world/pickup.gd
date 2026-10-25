class_name Pickup
extends Node3D
## Collectibles: gingerbread for points, hot cocoa for an extra life and
## turbo wax for a burst of speed.

enum Kind { GINGERBREAD, COCOA, WAX }

const RADIUS := 1.3

var kind: Kind
var collected := false
var _time := 0.0
var _base_y := 0.0
var _visual: MeshInstance3D


func configure(which: Kind, at: Vector3) -> Pickup:
	kind = which
	position = at
	_base_y = at.y
	_time = at.z * 0.3
	_visual = MeshInstance3D.new()
	match which:
		Kind.GINGERBREAD:
			_visual.mesh = Props.gingerbread()
		Kind.COCOA:
			_visual.mesh = Props.cocoa()
			_visual.scale = Vector3.ONE * 1.6
		Kind.WAX:
			_visual.mesh = Props.wax()
			_visual.scale = Vector3.ONE * 1.6
			_visual.rotation.z = 0.5
	add_child(_visual)
	return self


func tick(delta: float) -> void:
	if collected:
		return
	_time += delta
	rotation.y = _time * 2.5
	position.y = _base_y + sin(_time * 3.0) * 0.15


func touches(p: Vector3) -> bool:
	return not collected and p.distance_squared_to(position) < RADIUS * RADIUS * 1.8


func collect() -> void:
	collected = true
	visible = false
