class_name Pickup
extends Node3D
## Collectibles: gingerbread for points, a mitten for an extra life and
## turbo wax for a burst of speed.

enum Kind { GINGERBREAD, MITTEN, WAX }

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
		Kind.MITTEN:
			_visual.mesh = Props.mitten()
			_visual.scale = Vector3.ONE * 1.6
			_visual.rotation.z = 0.2
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
	# Turning slowly, bobbing and rocking a little, as if it floated.
	rotation.y = _time * 2.5
	rotation.x = sin(_time * 1.7) * 0.12
	position.y = _base_y + sin(_time * 3.0) * 0.15


func touches(p: Vector3) -> bool:
	return not collected and p.distance_squared_to(position) < RADIUS * RADIUS * 1.8


## Picked up: it gives a little hop and a spin and shrinks away.
func collect() -> void:
	collected = true
	if not is_inside_tree():
		visible = false
		return
	var pop := create_tween()
	pop.tween_property(self, "scale", Vector3.ONE * 1.2, 0.05).set_ease(Tween.EASE_OUT)
	pop.parallel().tween_property(self, "position:y", position.y + 0.5, 0.18).set_ease(Tween.EASE_OUT)
	pop.parallel().tween_property(self, "rotation:y", rotation.y + TAU, 0.18)
	pop.tween_property(self, "scale", Vector3.ONE * 0.01, 0.13).set_ease(Tween.EASE_IN)
	pop.tween_callback(func() -> void: visible = false)
