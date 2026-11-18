class_name CreatureRig
extends Node3D
## A person or animal made in Blender (models/<kind>.glb, built by
## tools/blender/creatures.py): a smooth skinned body with looping
## animations (walk, idle, and wave, gallop or hop as the kind has them,
## and a flail for flying through the air), wearing the colours it is given.

## Animations that repeat.
const LOOPS := ["walk", "idle", "wave", "gallop", "hop", "flail"]

## Load model resources with the game scripts, before the run starts.
## Lazy loading the rare bear alone cost about 10 ms in the streaming trace.
static var _scenes := {
	"person": preload("res://models/person.glb"),
	"moose": preload("res://models/moose.glb"),
	"bear": preload("res://models/bear.glb"),
	"deer": preload("res://models/deer.glb"),
	"reindeer": preload("res://models/reindeer.glb"),
	"dog": preload("res://models/dog.glb"),
	"hare": preload("res://models/hare.glb"),
	"fox": preload("res://models/fox.glb"),
	"cat": preload("res://models/cat.glb"),
}
## Reuse clothing materials across moving and baked figures.
static var _dressed_materials := {}

var _player: AnimationPlayer
var _skeleton: Skeleton3D
var _meshes: Array[MeshInstance3D] = []
var _current := &""


func _init(kind: String) -> void:
	if not _scenes.has(kind):
		var scene: PackedScene = load("res://models/%s.glb" % kind)
		_scenes[kind] = scene
	var model: Node3D = (_scenes[kind] as PackedScene).instantiate()
	add_child(model)
	_skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
	_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_meshes.append(mesh)
		# Painted bodies (a bear's shaded coat) carry their colours in the
		# vertices; the import leaves the material ignoring them.
		for surface in mesh.mesh.get_surface_count():
			var original := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if original != null and mesh.mesh.surface_get_format(surface) & Mesh.ARRAY_FORMAT_COLOR:
				# Vertex colours belong to the asset, so all instances can use
				# the shared material. Per-instance overrides here also leave
				# transient material RIDs behind when a baked pose is freed.
				original.vertex_color_use_as_albedo = true
	for name: String in LOOPS:
		if _player.has_animation(name):
			_player.get_animation(name).loop_mode = Animation.LOOP_LINEAR


## A stable body pivot, unaffected by waving arms, antlers or flailing.
## Model origins are at the feet; the spine root is inside the torso.
func tumble_center() -> Vector3:
	var bone := _skeleton.find_bone("spine")
	if bone < 0:
		bone = _skeleton.find_bone("hips")
	if bone < 0:
		return Vector3.ZERO
	var center := _skeleton.get_bone_global_rest(bone).origin
	var node: Node3D = _skeleton
	while node != self:
		center = node.transform * center
		node = node.get_parent() as Node3D
	return center


func has(animation: StringName) -> bool:
	return _player.has_animation(animation)


## Recolours the materials named in `colours` (material name -> colour).
func dress(colours: Dictionary) -> void:
	for mesh in _meshes:
		dress_mesh(mesh, colours)


## Apply clothing without copying geometry or allocating a material per fan.
static func dress_mesh(mesh: MeshInstance3D, colours: Dictionary) -> void:
	for surface in mesh.mesh.get_surface_count():
		var original := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
		if original == null or not colours.has(original.resource_name):
			continue
		var key := original.get_instance_id()
		var palette: Dictionary = _dressed_materials.get(key, {})
		var colour: Color = colours[original.resource_name]
		if not palette.has(colour):
			var dressed := original.duplicate() as StandardMaterial3D
			dressed.albedo_color = colour
			palette[colour] = dressed
			_dressed_materials[key] = palette
		mesh.set_surface_override_material(surface, palette[colour])


## Plays an animation (blending from the last) at `speed` times its pace.
func play(animation: StringName, speed := 1.0) -> void:
	if animation != _current and _player.has_animation(animation):
		_current = animation
		_player.play(animation, 0.2)
	_player.speed_scale = speed


## Holds the animation still at `fraction` (0..1) of the way through.
func freeze(animation: StringName, fraction: float) -> void:
	if not _player.has_animation(animation):
		return
	_current = animation
	_player.play(animation)
	_player.seek(fposmod(fraction, 1.0) * _player.get_animation(animation).length, true)
	_player.pause()


## Fixes a mesh to `bone` so it moves with it (a bandy stick in the right
## hand, Rudolph's nose). `place` puts the mesh in the model's own space as
## it stands at rest.
func attach_at(mesh: Mesh, bone: String, place: Transform3D) -> void:
	var index := _skeleton.find_bone(bone)
	if index < 0:
		return
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = bone
	_skeleton.add_child(attachment)
	var held := MeshInstance3D.new()
	held.mesh = mesh
	held.transform = _skeleton.get_bone_global_rest(index).affine_inverse() * place
	attachment.add_child(held)


## The creature as it stands frozen part way through an animation, baked
## into one plain mesh (skinned on the CPU, colours kept): cheap enough to
## put dozens of onlookers on a stand.
func bake(animation: StringName, fraction: float) -> ArrayMesh:
	var globals := _pose_at(animation, fraction)
	var baked := ArrayMesh.new()
	for mesh in _meshes:
		var skin := mesh.skin
		var to_skeleton := _relative_to_skeleton(mesh)
		var joints: Array[Transform3D] = []
		if skin != null:
			for bind in skin.get_bind_count():
				var bone := skin.get_bind_bone(bind)
				if bone < 0:
					bone = _skeleton.find_bone(skin.get_bind_name(bind))
				joints.append(globals[bone] * skin.get_bind_pose(bind))
		for surface in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var bones = arrays[Mesh.ARRAY_BONES]
			var weights = arrays[Mesh.ARRAY_WEIGHTS]
			if skin != null and bones != null and weights != null:
				var per := (bones as PackedInt32Array).size() / vertices.size()
				for v in vertices.size():
					var blend := Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO)
					for k in per:
						var w: float = weights[v * per + k]
						if w <= 0.0:
							continue
						var joint := joints[bones[v * per + k]]
						blend.basis.x += joint.basis.x * w
						blend.basis.y += joint.basis.y * w
						blend.basis.z += joint.basis.z * w
						blend.origin += joint.origin * w
					vertices[v] = blend * vertices[v]
					normals[v] = (blend.basis * normals[v]).normalized()
			else:
				for v in vertices.size():
					vertices[v] = to_skeleton * vertices[v]
					normals[v] = (to_skeleton.basis * normals[v]).normalized()
			var plain := []
			plain.resize(Mesh.ARRAY_MAX)
			plain[Mesh.ARRAY_VERTEX] = vertices
			plain[Mesh.ARRAY_NORMAL] = normals
			plain[Mesh.ARRAY_INDEX] = arrays[Mesh.ARRAY_INDEX]
			plain[Mesh.ARRAY_COLOR] = arrays[Mesh.ARRAY_COLOR]
			baked.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, plain)
			var material := mesh.get_surface_override_material(surface)
			baked.surface_set_material(baked.get_surface_count() - 1, material if material != null else mesh.mesh.surface_get_material(surface))
	return baked


## Each bone's pose in skeleton space at `fraction` of an animation, worked
## out from its tracks (no scene tree needed, so this runs mid-build).
func _pose_at(animation: StringName, fraction: float) -> Array[Transform3D]:
	var count := _skeleton.get_bone_count()
	var rotations: Array[Quaternion] = []
	var positions: Array[Vector3] = []
	var scales: Array[Vector3] = []
	for bone in count:
		var rest := _skeleton.get_bone_rest(bone)
		rotations.append(rest.basis.get_rotation_quaternion())
		positions.append(rest.origin)
		scales.append(rest.basis.get_scale())
	if _player.has_animation(animation):
		var clip := _player.get_animation(animation)
		var time := fposmod(fraction, 1.0) * clip.length
		for track in clip.get_track_count():
			var bone := _skeleton.find_bone(String(clip.track_get_path(track).get_concatenated_subnames()))
			if bone < 0:
				continue
			match clip.track_get_type(track):
				Animation.TYPE_ROTATION_3D:
					rotations[bone] = clip.rotation_track_interpolate(track, time)
				Animation.TYPE_POSITION_3D:
					positions[bone] = clip.position_track_interpolate(track, time)
				Animation.TYPE_SCALE_3D:
					scales[bone] = clip.scale_track_interpolate(track, time)
	var globals: Array[Transform3D] = []
	globals.resize(count)
	for bone in count:
		var local := Transform3D(Basis(rotations[bone]).scaled(scales[bone]), positions[bone])
		var parent := _skeleton.get_bone_parent(bone)
		globals[bone] = local if parent < 0 else globals[parent] * local
	return globals


## A node's transform in its skeleton's space, walking up the parents.
func _relative_to_skeleton(node: Node3D) -> Transform3D:
	var xform := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != _skeleton and current is Node3D:
		xform = (current as Node3D).transform * xform
		current = current.get_parent()
	return xform
