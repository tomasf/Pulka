class_name RiderRig
extends Node3D
## The rider made in Blender (models/rider.glb, built by
## tools/blender/rider.py): one smooth skinned body on a skeleton. It sits
## the way each ride needs (a pose per ride, read from the file), wears the
## colours it is given, and moves with the ride: leaning into turns,
## throwing its arms up in the air, flailing in a crash.

const SCENE := preload("res://models/rider.glb")
## Pose names in the file, in VehicleSpec.Model order.
const RIDES := ["pulka", "stjartlapp", "snowracer", "tefat", "wok"]
## From the elbow joint to the middle of the mitten's grip.
const HAND_REACH := 0.25

## Per ride: bone index -> rotation sitting on it. Read once from the file.
static var _poses: Array = []

var _skeleton: Skeleton3D
var _meshes: Array[MeshInstance3D] = []
var _base: Dictionary = {}
var _bone := {}
var _time := 0.0
## Eased 0..1: how far the arms are up (cheering in a long jump).
var _cheer := 0.0
var _air_time := 0.0


func _init() -> void:
	var scene: Node3D = SCENE.instantiate()
	add_child(scene)
	_skeleton = scene.find_child("Skeleton3D", true, false) as Skeleton3D
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		_meshes.append(node as MeshInstance3D)
	for i in _skeleton.get_bone_count():
		_bone[_skeleton.get_bone_name(i)] = i
	var player := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _poses.is_empty():
		RiderRig._read_poses(player, _skeleton)
	if player != null:
		player.queue_free()
	set_ride(VehicleSpec.Model.PULKA)


## Each ride's sitting pose, from the single-frame animations in the file.
static func _read_poses(player: AnimationPlayer, skeleton: Skeleton3D) -> void:
	for ride: String in RIDES:
		var pose := {}
		if player != null and player.has_animation(ride):
			var animation := player.get_animation(ride)
			for track in animation.get_track_count():
				if animation.track_get_type(track) != Animation.TYPE_ROTATION_3D:
					continue
				var bone := skeleton.find_bone(String(animation.track_get_path(track).get_concatenated_subnames()))
				if bone >= 0:
					pose[bone] = animation.rotation_track_interpolate(track, 0.0)
		_poses.append(pose)


func set_ride(model: VehicleSpec.Model) -> void:
	_base = _poses[model]
	_cheer = 0.0
	_apply({})


## Dresses the rider: jacket, hat (and mittens) and scarf; the trim, hat
## cuff follow from them. `look` picks skin and hair (see Palette.look).
func dress(jacket: Color, hat: Color, look := 1) -> void:
	var scarf := jacket.lerp(Color(1, 1, 1), 0.15).inverted().lerp(hat, 0.5)
	var colours := {
		"jacket": jacket, "jacket_trim": jacket.lightened(0.35), "hat": hat,
		"hat_cuff": hat.darkened(0.2), "scarf": scarf,
	}
	colours.merge(Palette.look(look))
	for mesh in _meshes:
		for surface in mesh.mesh.get_surface_count():
			var original := mesh.mesh.surface_get_material(surface)
			if original == null or not colours.has(original.resource_name):
				continue
			var dressed := (original as StandardMaterial3D).duplicate() as StandardMaterial3D
			dressed.albedo_color = colours[original.resource_name]
			mesh.set_surface_override_material(surface, dressed)


## Moves with the ride each frame. `steer` is -1..1;
## `airborne` while the ride is off the ground. `grab` (0..1) blends into
## the stiff pose of a grab `trick`.
func animate(delta: float, steer: float, airborne: bool, grab := 0.0, trick: GrabTrick = null) -> void:
	_time += delta
	_air_time = _air_time + delta if airborne else 0.0
	var cheering := _air_time > 0.45 and grab <= 0.0
	_cheer = move_toward(_cheer, 1.0 if cheering else 0.0, delta * (4.0 if cheering else 6.0))
	var extra := {}
	# Lean into the turn, with the head held level against it.
	_add(extra, "spine", Quaternion(Vector3.FORWARD, steer * 0.18))
	_add(extra, "head", Quaternion(Vector3.FORWARD, -steer * 0.12))
	_apply(extra)
	# Arms up in a long jump, in a V out over the shoulders (aimed in the
	# rider's own space, clear of the head), then back to the handles.
	if _cheer > 0.0:
		var wave := sin(_time * 9.0) * 0.12
		for side in [["L", -1.0], ["R", 1.0]]:
			var out: float = side[1]
			_aim(extra, "upper_arm." + side[0], Vector3(out * (0.55 + wave), 1.0, -0.1), _cheer)
			_apply(extra)
			_aim(extra, "forearm." + side[0], Vector3(out * 0.3, 1.0, -0.05), _cheer)
		_apply(extra)
	if trick != null and grab > 0.0:
		for bone: Array in trick.pose:
			if bone.size() > 2:
				_aim_via(extra, bone[0], bone[2], bone[1], grab)
			else:
				_aim(extra, bone[0], bone[1], grab)
			_apply(extra)


## Where the right mitten holds on, in the rider's own space.
func hand_position() -> Vector3:
	var forearm: int = _bone["forearm.R"]
	var pose := _skeleton.get_bone_global_pose(forearm)
	var hand := pose.origin + pose.basis.y.normalized() * HAND_REACH
	return _skeleton_from_rider().inverse() * hand


## A crash: limbs thrown about as the rider tumbles.
func flail(delta: float) -> void:
	_time += delta
	_cheer = 0.0
	var extra := {}
	var k := 0
	for name in ["upper_arm.L", "upper_arm.R", "forearm.L", "forearm.R", "thigh.L", "thigh.R", "shin.L", "shin.R", "spine", "head"]:
		k += 1
		var swing := 0.9 if name.begins_with("upper") or name.begins_with("thigh") else 0.6
		_add(extra, name, Quaternion(Vector3(sin(k * 1.7), cos(k * 2.3), sin(k)).normalized(), sin(_time * (11.0 + k) + k) * swing))
	_apply(extra)


## Turns a bone (by `amount`, 0..1) so it points along `direction` in the
## rider's own space, whatever its parents are doing.
func _aim(extra: Dictionary, name: String, direction: Vector3, amount: float) -> void:
	if not _bone.has(name):
		return
	var bone: int = _bone[name]
	var parent := _skeleton.get_bone_parent(bone)
	var parent_rotation := _skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion() if parent >= 0 else Quaternion.IDENTITY
	var local: Quaternion = _base.get(bone, _skeleton.get_bone_rest(bone).basis.get_rotation_quaternion())
	var pointing := (parent_rotation * local) * _along(bone)
	var turn := Quaternion(pointing.normalized(), (_skeleton_from_rider() * direction).normalized())
	var wanted := parent_rotation.inverse() * turn * parent_rotation * local
	extra[bone] = (local.inverse() * wanted).slerp(Quaternion.IDENTITY, 1.0 - amount)


## Like `_aim`, but the bone swings from its sitting direction through `via`
## (halfway, at `amount` 0.5) to `direction`, instead of the shortest way:
## a limb that would cut through the ride goes round it.
func _aim_via(extra: Dictionary, name: String, via: Vector3, direction: Vector3, amount: float) -> void:
	if not _bone.has(name):
		return
	var bone: int = _bone[name]
	var parent := _skeleton.get_bone_parent(bone)
	var parent_rotation := _skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion() if parent >= 0 else Quaternion.IDENTITY
	var local: Quaternion = _base.get(bone, _skeleton.get_bone_rest(bone).basis.get_rotation_quaternion())
	var sitting := (_skeleton_from_rider().inverse() * ((parent_rotation * local) * _along(bone))).normalized()
	var mid := via.normalized()
	var toward := sitting.slerp(mid, amount * 2.0) if amount < 0.5 else mid.slerp(direction.normalized(), amount * 2.0 - 1.0)
	_aim(extra, name, toward, 1.0)


## Turns directions in the rider's space into the skeleton's (the glTF
## armature can sit rotated inside the model).
func _skeleton_from_rider() -> Basis:
	var basis := Basis.IDENTITY
	var node: Node = _skeleton
	while node != null and node != self:
		if node is Node3D:
			basis = (node as Node3D).transform.basis * basis
		node = node.get_parent()
	return basis.inverse()


## The direction a bone runs in its own frame: towards its child joint, or
## for a last bone (the forearm) the same way as its parent runs.
func _along(bone: int) -> Vector3:
	for child in _skeleton.get_bone_children(bone):
		var offset := _skeleton.get_bone_rest(child).origin
		if offset.length() > 0.001:
			return offset.normalized()
	var parent := _skeleton.get_bone_parent(bone)
	return _along(parent) if parent >= 0 else Vector3.UP


func _add(extra: Dictionary, name: String, turn: Quaternion) -> void:
	if _bone.has(name):
		extra[_bone[name]] = turn


func _apply(extra: Dictionary) -> void:
	for bone in _skeleton.get_bone_count():
		var rest: Quaternion = _base.get(bone, _skeleton.get_bone_rest(bone).basis.get_rotation_quaternion())
		var turn: Quaternion = extra.get(bone, Quaternion.IDENTITY)
		_skeleton.set_bone_pose_rotation(bone, rest * turn)
