class_name Obstacle
extends Node3D
## Something on the slope you can hit. Collision is analytic: a vertical
## cylinder (or a box for vehicles) with a top you can jump over.

enum Kind { TREE, ROCK, STUMP, SNOWMAN, PERSON, KID, DOG, MOOSE, DEER, HARE, CAR, PLOW, BIN, TENT, LOG }

var kind: Kind
var radius := 0.6
var top := 2.0
## Non-zero for box colliders: half size along local x and z.
var half_extents := Vector2.ZERO
## Soft obstacles do not crash you; they just get in the way.
var soft := false
var velocity := Vector3.ZERO
var min_x := -INF
var max_x := INF
var follow_terrain := true
var field: TerrainField
var hit := false
var close_call := false
var near_miss_done := false
var visual: MeshInstance3D

var _limbs: Array[Node3D] = []
var _limb_specs: Array[Props.Limb] = []
var _stride := 0.0
var _gait := 0.0
var _time := 0.0
var _hop_rate := 0.0
var _hop_height := 0.0


func configure(which: Kind, rig: Props.Rig, terrain: TerrainField) -> Obstacle:
	kind = which
	field = terrain
	visual = MeshInstance3D.new()
	visual.mesh = rig.body
	add_child(visual)
	_stride = rig.stride
	for spec in rig.limbs:
		var joint := Node3D.new()
		joint.position = spec.pivot
		var limb := MeshInstance3D.new()
		limb.mesh = spec.mesh
		joint.add_child(limb)
		visual.add_child(joint)
		_limbs.append(joint)
		_limb_specs.append(spec)
	match which:
		Kind.TREE:
			radius = 0.75
			top = 7.0
		Kind.ROCK:
			radius = 0.95
			top = 0.95
		Kind.STUMP:
			radius = 0.5
			top = 0.6
		Kind.SNOWMAN:
			radius = 0.6
			top = 2.2
			soft = true
		Kind.PERSON:
			radius = 0.45
			top = 1.9
		Kind.KID:
			radius = 0.35
			top = 1.2
		Kind.DOG:
			radius = 0.5
			top = 0.9
		Kind.MOOSE:
			radius = 1.3
			top = 2.9
		Kind.DEER:
			radius = 0.7
			top = 1.9
		Kind.HARE:
			radius = 0.35
			top = 0.5
			soft = true
			_hop_rate = 8.0
			_hop_height = 0.4
		Kind.BIN:
			radius = 0.4
			top = 1.1
		Kind.TENT:
			radius = 1.0
			top = 1.7
		Kind.LOG:
			# The mesh is shrunk to 75 % where logs are placed (SlopeWorld).
			half_extents = Vector2(2.25, 0.28)
			top = 0.45
			# Riding into a log throws you over it instead of ending the run.
			soft = true
		Kind.CAR:
			half_extents = Vector2(0.95, 2.25)
			top = 1.7
			follow_terrain = false
		Kind.PLOW:
			half_extents = Vector2(1.8, 3.6)
			top = 3.0
			follow_terrain = false
	return self


## People and animals: landing on top of them is survivable.
func is_creature() -> bool:
	return kind in [Kind.PERSON, Kind.KID, Kind.DOG, Kind.MOOSE, Kind.DEER, Kind.HARE]


func is_vehicle() -> bool:
	return kind == Kind.CAR or kind == Kind.PLOW


func patrol(speed: float, lo: float, hi: float) -> void:
	velocity = Vector3(speed, 0.0, 0.0)
	min_x = lo
	max_x = hi
	_face_velocity()


func tick(delta: float) -> void:
	_time += delta
	if hit and not soft:
		return
	if velocity != Vector3.ZERO:
		position += velocity * delta
		if (position.x < min_x and velocity.x < 0.0) or (position.x > max_x and velocity.x > 0.0):
			velocity.x = -velocity.x
			_face_velocity()
		if follow_terrain:
			position.y = field.height_world(position.x, position.z)
		if _hop_rate > 0.0:
			visual.position.y = absf(sin(_time * _hop_rate)) * _hop_height
		_gait += velocity.length() * _stride * delta
		for i in _limbs.size():
			_limbs[i].rotation = Vector3(sin(_gait + _limb_specs[i].phase) * _limb_specs[i].swing, 0.0, 0.0)
		if not _limbs.is_empty():
			visual.position.y = absf(sin(_gait)) * 0.04
	else:
		for i in _limbs.size():
			if _limb_specs[i].waves:
				_limbs[i].rotation = Vector3(0.0, 0.0, 2.5 + 0.35 * sin(_time * 9.0 + position.x))


func _face_velocity() -> void:
	if velocity.length_squared() > 0.0001:
		rotation.y = atan2(-velocity.x, -velocity.z)


## Horizontal offset from the obstacle's surface to point p (0 when inside).
func clearance(p: Vector3) -> float:
	var dx := p.x - position.x
	var dz := p.z - position.z
	if half_extents != Vector2.ZERO:
		var c := cos(rotation.y)
		var s := sin(rotation.y)
		var lx := absf(dx * c - dz * s) - half_extents.x
		var lz := absf(dx * s + dz * c) - half_extents.y
		return Vector2(maxf(lx, 0.0), maxf(lz, 0.0)).length()
	return maxf(sqrt(dx * dx + dz * dz) - radius, 0.0)


func overlaps(p: Vector3, r: float) -> bool:
	if hit or p.y > position.y + top or p.y < position.y - 1.5:
		return false
	return clearance(p) < r


## Called when the sled ploughs into this obstacle.
func react_to_hit(impact_velocity: Vector3) -> void:
	hit = true
	match kind:
		Kind.SNOWMAN:
			visible = false
		Kind.HARE:
			velocity = Vector3(signf(randf() - 0.5) * 9.0, 0.0, 0.0)
			min_x = -INF
			max_x = INF
			_hop_height = 1.6
			_hop_rate = 6.0
			_face_velocity()
		Kind.PERSON, Kind.KID, Kind.DEER, Kind.DOG:
			visual.rotation.x = -PI / 2.0 * 0.9
			visual.position.y = 0.25
			rotation.y = atan2(-impact_velocity.x, -impact_velocity.z) + PI
