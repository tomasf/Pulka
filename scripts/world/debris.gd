class_name Debris
extends Node3D
## A short-lived burst of tumbling chunks (exploding snowmen, snow clods).

const LIFETIME := 2.2

var _field: TerrainField
var _pieces: Array[MeshInstance3D] = []
var _velocities: Array[Vector3] = []
var _spins: Array[Vector3] = []
var _age := 0.0

static var _chunk_mesh: ArrayMesh


static func burst(parent: Node, field: TerrainField, at: Vector3, carry: Vector3, count := 10, size := 0.3) -> Debris:
	if _chunk_mesh == null:
		_chunk_mesh = MeshKit.new().sphere(1.0, Vector3.ZERO, Palette.SNOW, Vector3.ONE, 6, 3).build()
	var debris := Debris.new()
	debris._field = field
	parent.add_child(debris)
	for i in count:
		var piece := MeshInstance3D.new()
		piece.mesh = _chunk_mesh
		piece.scale = Vector3.ONE * size * randf_range(0.5, 1.4)
		piece.position = at + Vector3(randf_range(-0.4, 0.4), randf_range(0.2, 1.6), randf_range(-0.4, 0.4))
		debris.add_child(piece)
		debris._pieces.append(piece)
		debris._velocities.append(carry * randf_range(0.5, 1.0) + Vector3(randf_range(-5, 5), randf_range(3, 9), randf_range(-5, 5)))
		debris._spins.append(Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8)))
	return debris


func _process(delta: float) -> void:
	_age += delta
	if _age > LIFETIME:
		queue_free()
		return
	for i in _pieces.size():
		var piece := _pieces[i]
		_velocities[i].y -= 15.0 * delta
		piece.position += _velocities[i] * delta
		piece.rotation += _spins[i] * delta
		var ground := _field.height_world(piece.position.x, piece.position.z)
		if piece.position.y < ground:
			piece.position.y = ground
			_velocities[i] *= Vector3(0.6, -0.3, 0.6)
		if _age > LIFETIME - 0.5:
			piece.scale *= 1.0 - delta * 4.0
