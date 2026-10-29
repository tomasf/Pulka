class_name SnowTrail
extends Node3D
## Tracks the ride leaves in the snow: a groove per runner or ski, laid on
## the ground as strips of pressed-down snow. Finished stretches are frozen into
## meshes of their own, so only the newest few metres are rebuilt as you
## ride, and the oldest are dropped far behind.

## Metres travelled between trail samples.
const SPACING := 0.4
## Samples per frozen stretch, and how many stretches are kept.
const SEGMENT := 16
const SEGMENTS := 14
## Height above the ground, against flicker where the terrain mesh dips.
const LIFT := 0.035
## Across a groove, in half widths from its middle: where each strip edge
## lies, its colour and how opaque it is. Snow is pushed up into a bright
## lip on either side, the walls down into the groove catch a little shadow
## and the floor is pressed smooth, hardly darker than the slope.
const PROFILE := [
	[-1.3, Color(1.0, 1.0, 1.0), 0.0], [-1.12, Color(1.0, 1.0, 1.0), 0.5],
	[-1.0, Color(0.55, 0.62, 0.8), 0.45], [-0.82, Color(0.82, 0.86, 0.96), 0.3],
	[0.82, Color(0.82, 0.86, 0.96), 0.3], [1.0, Color(0.55, 0.62, 0.8), 0.45],
	[1.12, Color(1.0, 1.0, 1.0), 0.5], [1.3, Color(1.0, 1.0, 1.0), 0.0],
]

static var _material: StandardMaterial3D

## Per groove: (offset to the right of the ride's centre, half width).
var _grooves: Array[Vector2] = []
var _points := PackedVector3Array()
var _rights := PackedVector3Array()
var _ups := PackedVector3Array()
var _strengths := PackedFloat32Array()
## Whether a sample continues the strip from the one before it.
var _joined := PackedByteArray()
var _live: MeshInstance3D
var _frozen: Array[MeshInstance3D] = []
var _gap := true


func _ready() -> void:
	top_level = true
	_live = _strip()


## Grooves each ride presses into the snow: one per runner or ski, or one
## as broad as a flat bottom where it touches the snow.
static func grooves(model: VehicleSpec.Model) -> Array[Vector2]:
	match model:
		VehicleSpec.Model.PULKA:
			return [Vector2(-0.26, 0.09), Vector2(0.26, 0.09)]
		VehicleSpec.Model.SNOWRACER:
			return [Vector2(-0.32, 0.08), Vector2(0.0, 0.09), Vector2(0.32, 0.08)]
		VehicleSpec.Model.STJARTLAPP:
			return [Vector2(0.0, 0.27)]
		VehicleSpec.Model.TEFAT:
			return [Vector2(0.0, 0.55)]
		_:
			# The wok only touches with the flat of its base.
			return [Vector2(0.0, 0.26)]


func set_model(model: VehicleSpec.Model) -> void:
	_grooves = SnowTrail.grooves(model)
	clear()


## Wipes the trail, for a new run or a ride put somewhere else.
func clear() -> void:
	for stretch in _frozen:
		stretch.queue_free()
	_frozen.clear()
	_reset_live()
	_gap = true


## The ride left the snow (a jump, a crash, a floor that takes no tracks):
## the next sample starts a new strip.
func lift() -> void:
	_gap = true


## The ride is on the snow at `at`, its runners lying along `right`.
## `strength` is how deep the tracks look, 0 to 1.
func record(at: Vector3, right: Vector3, up: Vector3, strength: float) -> void:
	if not _gap and at.distance_squared_to(_points[_points.size() - 1]) < SPACING * SPACING:
		return
	_points.append(at)
	_rights.append(right)
	_ups.append(up)
	_strengths.append(strength)
	_joined.append(0 if _gap else 1)
	_gap = false
	if _points.size() <= SEGMENT:
		_live.mesh = _build()
		return
	var stretch := _strip()
	stretch.mesh = _build()
	_frozen.append(stretch)
	if _frozen.size() > SEGMENTS:
		_frozen.pop_front().queue_free()
	# The last sample starts the next stretch, so the strip runs on unbroken.
	var last := _points.size() - 1
	var keep := [_points[last], _rights[last], _ups[last], _strengths[last]]
	_reset_live()
	_points.append(keep[0])
	_rights.append(keep[1])
	_ups.append(keep[2])
	_strengths.append(keep[3])
	_joined.append(0)


func _reset_live() -> void:
	_points.clear()
	_rights.clear()
	_ups.clear()
	_strengths.clear()
	_joined.clear()
	_live.mesh = null


func _strip() -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.material_override = SnowTrail.material()
	add_child(instance)
	return instance


## Each groove is a strip laid out by PROFILE, faded at its outer edges
## so it blends into the snow around it.
func _build() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for i in range(1, _points.size()):
		if _joined[i] == 0:
			continue
		for groove in _grooves:
			for k in PROFILE.size() - 1:
				for corner in [[0, k], [1, k], [0, k + 1], [0, k + 1], [1, k], [1, k + 1]]:
					var sample: int = i - 1 + corner[0]
					var edge: Array = PROFILE[corner[1]]
					vertices.append(_points[sample] + _ups[sample] * LIFT + _rights[sample] * (groove.x + groove.y * float(edge[0])))
					normals.append(_ups[sample])
					colors.append(Color(edge[1] as Color, float(edge[2]) * _strengths[sample]))
	var mesh := ArrayMesh.new()
	if vertices.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_material.roughness = 1.0
	return _material
