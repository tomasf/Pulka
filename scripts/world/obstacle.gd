class_name Obstacle
extends Node3D
## Something on the slope you can hit. Collision is analytic: a vertical
## cylinder (or a box for vehicles, a cone for spruces) with a top you can
## jump over or land on. Mass decides how hard a hit is and whether the
## obstacle goes flying.

enum Kind { TREE, ROCK, STUMP, SNOWMAN, PERSON, KID, DOG, MOOSE, DEER, HARE, CAR, PLOW, BIN, TENT, LOG, CART, PLANT, FOUNTAIN, CONE, TRAIN, PLANE, TUG, GOAL, TRUCK, BEAR, CHIMNEY, ICE_PILLAR, CONTAINER, SEWER_DEBRIS, FOX, CAT }

## Weight in kilograms; INF for things rooted to the ground.
const MASS := {
	Kind.TREE: INF, Kind.ROCK: INF, Kind.STUMP: INF, Kind.SNOWMAN: 80.0, Kind.PERSON: 75.0,
	Kind.KID: 30.0, Kind.DOG: 18.0, Kind.MOOSE: 450.0, Kind.DEER: 60.0, Kind.HARE: 3.0,
	Kind.CAR: 1300.0, Kind.PLOW: 9000.0, Kind.BIN: 25.0, Kind.TENT: 35.0, Kind.LOG: INF,
	Kind.CART: 30.0, Kind.PLANT: 45.0, Kind.FOUNTAIN: INF, Kind.CONE: 2.0, Kind.TRAIN: INF,
	Kind.PLANE: INF, Kind.TUG: 2500.0, Kind.GOAL: 70.0, Kind.TRUCK: 15000.0,
	Kind.BEAR: 250.0, Kind.CHIMNEY: INF, Kind.ICE_PILLAR: INF, Kind.CONTAINER: INF, Kind.SEWER_DEBRIS: INF,
	# A big winter fox: a solid knock, not far off a small dog.
	Kind.FOX: 12.0,
	Kind.CAT: 4.5,
}
## Heavier than this and a hit does not move it.
const MOVABLE_MASS := 1000.0
## Spruces: a slim trunk up to here, then a cone of branches.
const BRANCHES_FROM := 0.9

var kind: Kind
var mass := INF
## Harmless clutter (cones): knocked away without slowing you down.
var harmless := false
## Whether you can come down on top of it and carry on.
var landable := true
## True while tumbling through the air after being hit.
var flying := false
## Set once the ride has rustled through this spruce's branches.
var brushed := false
var birch := false
var radius := 0.6
var top := 2.0
## How far a spruce's lowest branches reach out (the base of its cone).
var branch_reach := 1.6
## Non-zero for box colliders: half size along local x and z.
var half_extents := Vector2.ZERO
## Soft obstacles do not crash you; they just get in the way.
var soft := false
var velocity := Vector3.ZERO
var min_x := -INF
var max_x := INF
var follow_terrain := true
## Static dock cargo follows the quay plane rather than a level Y box.
var collision_slope := 0.0
var collision_sweep := 0.0
## Grounded props tolerate terrain irregularities; suspended cargo does not.
var bottom_margin := 1.5
var field: TerrainField
var hit := false
var close_call := false
var near_miss_done := false
var visual: MeshInstance3D
var _wheel_radius := 0.0
var _wheel_angle := 0.0

var _limbs: Array[Node3D] = []
## A Blender-made person or animal, animated instead of swinging limbs.
var _creature: CreatureRig
var _rig: Props.Rig
## Per limb, the joint of its lower part (knee, elbow), or null.
var _lowers: Array[Node3D] = []
var _limb_specs: Array[Props.Limb] = []
var _stride := 0.0
var _gait := 0.0
var _time := 0.0
var _hop_rate := 0.0
var _hop_height := 0.0
var _fly := Vector3.ZERO
var _spin := Vector3.ZERO
var _airtime := 0.0
var _flight_pivot := Vector3.ZERO
var _flight_bounds := AABB()


func configure(which: Kind, rig: Props.Rig, terrain: TerrainField) -> Obstacle:
	kind = which
	field = terrain
	visual = MeshInstance3D.new()
	visual.mesh = rig.body
	add_child(visual)
	_stride = rig.stride
	_rig = rig
	if rig.kind != "":
		_creature = rig.make()
		visual.add_child(_creature)
		_creature.play(&"wave" if rig.waves else &"idle")
	for spec in rig.limbs:
		var joint := Node3D.new()
		joint.position = spec.pivot
		var limb := MeshInstance3D.new()
		limb.mesh = spec.mesh
		joint.add_child(limb)
		var lower: Node3D = null
		if spec.lower != null:
			lower = Node3D.new()
			lower.position = spec.joint
			lower.rotation.x = spec.rest
			var lower_mesh := MeshInstance3D.new()
			lower_mesh.mesh = spec.lower
			lower.add_child(lower_mesh)
			joint.add_child(lower)
		visual.add_child(joint)
		_limbs.append(joint)
		_lowers.append(lower)
		_limb_specs.append(spec)
	match which:
		Kind.TREE:
			radius = 0.45
			top = 7.0
			landable = false
			fit_spruce(rig.body)
		Kind.ROCK:
			radius = 0.95
			top = rig.body.get_meta(&"obstacle_top", 0.95) if rig.body != null else 0.95
		Kind.STUMP:
			radius = 0.5
			top = 0.6
		Kind.SEWER_DEBRIS:
			landable = false
		Kind.ICE_PILLAR:
			radius = 1.35
			top = 9.0
			landable = false
		Kind.CONTAINER:
			bottom_margin = 0
			half_extents = Vector2(2.6, 8)
			top = 4
			landable = false
		Kind.CHIMNEY:
			half_extents = Vector2(0.60, 0.55)
			top = 1.75
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
		Kind.FOX:
			radius = 0.40
			top = 0.9
		Kind.CAT:
			radius = 0.27
			top = 0.53
		Kind.MOOSE:
			radius = 1.3
			top = 2.9
		Kind.BEAR:
			radius = 0.95
			top = 1.25
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
		Kind.CART:
			half_extents = Vector2(0.35, 0.5)
			top = 1.2
		Kind.PLANT:
			radius = 0.5
			top = 2.6
			landable = false
		Kind.FOUNTAIN:
			radius = 2.2
			top = 1.0
		Kind.CONE:
			radius = 0.28
			top = 0.8
			harmless = true
		Kind.TRAIN:
			half_extents = Vector2(1.6, 7.4)
			top = 4.0
		Kind.PLANE:
			half_extents = Vector2(2.1, 15.0)
			top = 5.2
		Kind.TUG:
			half_extents = Vector2(0.9, 3.8)
			top = 2.3
		Kind.TRUCK:
			half_extents = Vector2(1.3, 7.8)
			top = 4.2
			follow_terrain = false
		Kind.GOAL:
			half_extents = Vector2(1.9, 0.7)
			top = 2.1
		Kind.CAR:
			half_extents = rig.body.get_meta("collision_extents", Vector2(0.95, 2.25)) if rig.body else Vector2(0.95, 2.25)
			top = float(rig.body.get_meta("roof_height", 1.7)) if rig.body else 1.7
			_wheel_radius = float(rig.body.get_meta("wheel_radius", 0.0)) if rig.body else 0.0
			follow_terrain = false
		Kind.PLOW:
			half_extents = Vector2(1.8, 3.6)
			top = 3.0
			follow_terrain = false
	mass = MASS.get(which, INF)
	if _creature != null:
		# The hare's hops are in its animation.
		_hop_rate = 0.0
		_hop_height = 0.0
	set_process(false)
	return self


func movable() -> bool:
	return mass < MOVABLE_MASS


## Signed distance along the vehicle's forward direction, independent of
## world position: wrapping a traffic lane must not spin the wheels wildly.
func roll_wheels(distance: float) -> void:
	if _wheel_radius <= 0.0 or is_zero_approx(distance): return
	_wheel_angle = fposmod(_wheel_angle - distance / _wheel_radius, TAU)
	visual.set_instance_shader_parameter(&"wheel_angle", _wheel_angle)


## Height of the obstacle's top above its base, allowing for scaling (trees).
func height() -> float:
	return top * (scale.y if kind == Kind.TREE else 1.0)


## Sizes a spruce's trunk-and-cone collider to the silhouette it shows.
func fit_spruce(mesh: Mesh) -> void:
	if mesh == null or not mesh.has_meta(&"spruce_top"): return
	top = mesh.get_meta(&"spruce_top")
	branch_reach = mesh.get_meta(&"spruce_reach")


## A tree that is a birch rather than a spruce: a slim bare trunk with no
## skirt of branches to ride through.
func make_birch() -> void:
	birch = true
	radius = 0.22
	top = 5.0


## True if p is up among a spruce's branches rather than at its trunk.
func in_branches(p: Vector3) -> bool:
	return kind == Kind.TREE and not birch and p.y - position.y > BRANCHES_FROM * scale.y


## Horizontal direction from the obstacle towards p (the way a hit pushes).
func push_normal(p: Vector3, fallback: Vector3) -> Vector3:
	var away := Vector3(p.x - position.x, 0.0, p.z - position.z)
	return away.normalized() if away.length() > 0.05 else fallback


## Sends the obstacle tumbling with this velocity: a simple ragdoll that
## spins, flails its limbs, bounces and comes to rest.
func launch(push: Vector3) -> void:
	_flight_bounds = _visual_bounds()
	_flight_pivot = _flight_bounds.get_center()
	if _creature != null:
		_flight_pivot = visual.transform * (_creature.transform * _creature.tumble_center())
	hit = true
	flying = true
	velocity = Vector3.ZERO
	_fly = push
	_spin = Vector3(randf_range(-1.0, 1.0), randf_range(-0.6, 0.6), randf_range(-1.0, 1.0)) * clampf(push.length() * 0.8, 2.0, 12.0)
	_airtime = 0.0
	set_process(true)


func _process(delta: float) -> void:
	if not flying:
		set_process(false)
		return
	_airtime += delta
	if _creature != null:
		_creature.play(&"flail", 1.6)
	_fly.y -= 15.0 * delta
	position += _fly * delta
	var center := transform * _flight_pivot
	rotate_object_local(Vector3.RIGHT, _spin.x * delta)
	rotate_object_local(Vector3.UP, _spin.y * delta)
	rotate_object_local(Vector3.BACK, _spin.z * delta)
	# Keep the torso on its ballistic path while the foot-origin orbits it.
	position += center - transform * _flight_pivot
	for i in _limbs.size():
		_limbs[i].rotation = Vector3(sin(_airtime * 17.0 + i) * 1.3, 0.0, cos(_airtime * 13.0 + i * 2.0) * 0.8)
		if _lowers[i] != null:
			_lowers[i].rotation.x = sin(_airtime * 11.0 + i * 1.7) * 0.9
	var penetration := _ground_penetration()
	if penetration > 0.0:
		position.y += penetration
		if _fly.y >= 0.0:
			return
		_fly = Vector3(_fly.x * 0.6, -_fly.y * 0.3, _fly.z * 0.6)
		_spin *= 0.55
		if _fly.length() < 1.2 and _airtime > 0.6:
			flying = false
			# Lie on the side around the same pivot, then lower onto the snow.
			center = transform * _flight_pivot
			rotation = Vector3(0.0, rotation.y, PI / 2.0 if kind != Kind.CONE else PI / 2.2)
			position += center - transform * _flight_pivot
			position.y += _ground_penetration()
			if _creature != null:
				_creature.play(&"flail", 0.25)


## Rest mesh bounds, including child scale and limb placements. Sampled only
## at launch; a full skinned mesh evaluation every frame would be expensive.
func _visual_bounds() -> AABB:
	var bounds := AABB()
	var first := true
	var stack: Array[Node3D] = [visual]
	var transforms: Array[Transform3D] = [visual.transform]
	while not stack.is_empty():
		var node := stack.pop_back() as Node3D
		var to_obstacle: Transform3D = transforms.pop_back()
		if node is MeshInstance3D and node.mesh != null:
			var box: AABB = to_obstacle * node.mesh.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
		for child in node.get_children():
			if child is Node3D:
				stack.append(child)
				transforms.append(to_obstacle * child.transform)
	return bounds


## Positive while the rotated bounds penetrate the terrain. Unlike testing
## the foot-origin, this also works when the figure is upside down or prone.
func _ground_penetration() -> float:
	var penetration := -INF
	for corner in 8:
		var point := transform * _flight_bounds.get_endpoint(corner)
		penetration = maxf(penetration, field.height_world(point.x, point.z) - point.y)
	return penetration


## People and animals: landing on top of them is survivable.
func is_creature() -> bool:
	return kind in [Kind.PERSON, Kind.KID, Kind.DOG, Kind.MOOSE, Kind.DEER, Kind.HARE, Kind.BEAR, Kind.FOX, Kind.CAT]


func is_vehicle() -> bool:
	return kind in [Kind.CAR, Kind.PLOW, Kind.TRAIN, Kind.PLANE, Kind.TUG, Kind.TRUCK]


func patrol(speed: float, lo: float, hi: float) -> void:
	velocity = Vector3(speed, 0.0, 0.0)
	min_x = lo
	max_x = hi
	_face_velocity()


func tick(delta: float) -> void:
	_time += delta
	if flying or (hit and not soft):
		return
	if velocity != Vector3.ZERO:
		if _wheel_radius > 0.0: roll_wheels(-basis.z.dot(velocity) * delta)
		position += velocity * delta
		if (position.x < min_x and velocity.x < 0.0) or (position.x > max_x and velocity.x > 0.0):
			velocity.x = -velocity.x
			_face_velocity()
		if follow_terrain:
			position.y = field.height_world(position.x, position.z)
		if _hop_rate > 0.0:
			visual.position.y = absf(sin(_time * _hop_rate)) * _hop_height
		_gait += velocity.length() * _stride * delta
		if _creature != null:
			_creature.play(_rig.gait, velocity.length() / _rig.pace)
		for i in _limbs.size():
			var angles := _limb_specs[i].pose(_gait)
			_limbs[i].rotation = Vector3(angles.x, 0.0, 0.0)
			if _lowers[i] != null:
				_lowers[i].rotation.x = angles.y
		if not _limbs.is_empty():
			# The body rises over each step and rolls a little from foot to foot.
			visual.position.y = absf(cos(_gait)) * 0.035
			visual.rotation.z = sin(_gait) * 0.035
	else:
		if _creature != null:
			_creature.play(&"wave" if _rig.waves else &"idle")
		for i in _limbs.size():
			if _limb_specs[i].waves:
				_limbs[i].rotation = Vector3(0.0, 0.0, 2.5 + 0.35 * sin(_time * 9.0 + position.x))
				if _lowers[i] != null:
					_lowers[i].rotation.x = 0.3 + 0.25 * sin(_time * 9.0 + position.x + 0.8)
		if not _limbs.is_empty() and _hop_rate == 0.0:
			# Standing about: breathing, shifting weight now and then.
			visual.position.y = sin(_time * 1.6 + position.x) * 0.008
			visual.rotation.z = sin(_time * 0.4 + position.z) * 0.02


func _face_velocity() -> void:
	if velocity.length_squared() > 0.0001:
		rotation.y = atan2(-velocity.x, -velocity.z)


## Horizontal offset from the obstacle's surface to point p (0 when inside).
func clearance(p: Vector3) -> float:
	var dx := p.x - position.x
	var dz := p.z - position.z
	dx += collision_sweep * dz
	if kind == Kind.TREE:
		var h := (p.y - position.y) / scale.y
		var reach := radius * scale.x
		if h > BRANCHES_FROM and not birch:
			reach = branch_reach * scale.x * maxf(1.0 - (h - BRANCHES_FROM) / (top - BRANCHES_FROM), 0.0)
		return maxf(sqrt(dx * dx + dz * dz) - reach, 0.0)
	if half_extents != Vector2.ZERO:
		var c := cos(rotation.y)
		var s := sin(rotation.y)
		var lx := absf(dx * c - dz * s) - half_extents.x
		var lz := absf(dx * s + dz * c) - half_extents.y
		return Vector2(maxf(lx, 0.0), maxf(lz, 0.0)).length()
	return maxf(sqrt(dx * dx + dz * dz) - radius, 0.0)


func overlaps(p: Vector3, r: float) -> bool:
	var base := position.y - collision_slope * (p.z - position.z)
	if hit or p.y > base + height() or p.y < base - bottom_margin:
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
		Kind.PERSON, Kind.KID, Kind.DEER, Kind.DOG, Kind.FOX, Kind.CAT:
			visual.rotation.x = -PI / 2.0 * 0.9
			visual.position.y = 0.25
			rotation.y = atan2(-impact_velocity.x, -impact_velocity.z) + PI
