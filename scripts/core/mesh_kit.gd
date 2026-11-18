class_name MeshKit
extends RefCounted
## Merges transformed, vertex-colored primitives into a single ArrayMesh so a
## whole prop (tree, house, car...) renders as one draw call.

var _vertices := PackedVector3Array()
var _normals := PackedVector3Array()
var _colors := PackedColorArray()
var _indices := PackedInt32Array()
## Arrays of primitives already added, so one added many times (sleepers,
## fence posts) is only generated once.
var _arrays := {}
## Reading a PrimitiveMesh back can synchronize with the GPU. Keep CPU
## geometry for the common unit shapes, then size it with the transform.
static var _unit_box: Array = []
static var _unit_spheres := {}
static var _unit_cylinders := {}


func add(mesh: PrimitiveMesh, xform: Transform3D, color: Color) -> MeshKit:
	var arrays: Array = _arrays.get(mesh, [])
	if arrays.is_empty():
		arrays = mesh.get_mesh_arrays()
		_arrays[mesh] = arrays
	return _add_arrays(arrays, xform, color)


func _add_arrays(arrays: Array, xform: Transform3D, color: Color) -> MeshKit:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var base := _vertices.size()
	var normal_basis := xform.basis.inverse().transposed()
	var linear := color.srgb_to_linear()
	linear.a = color.a
	for i in vertices.size():
		_vertices.append(xform * vertices[i])
		_normals.append((normal_basis * normals[i]).normalized())
		_colors.append(linear)
	if indices.is_empty():
		for i in vertices.size():
			_indices.append(base + i)
	else:
		for index in indices:
			_indices.append(base + index)
	return self


func box(size: Vector3, pos: Vector3, color: Color, rot := Vector3.ZERO) -> MeshKit:
	if _unit_box.is_empty():
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		_unit_box = mesh.get_mesh_arrays()
	return _add_arrays(_unit_box, Transform3D(Basis.from_euler(rot) * Basis.from_scale(size), pos), color)


## A planar panel, with its front facing the requested side.
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, facing: Vector3) -> MeshKit:
	var normal := (b - a).cross(c - a).normalized()
	if normal.dot(facing) < 0: normal = -normal
	var first := _vertices.size()
	for point in [a, b, c, d]:
		_vertices.append(point)
		_normals.append(normal)
		_colors.append(color.srgb_to_linear())
	_triangle_facing(first, first + 1, first + 2)
	_triangle_facing(first, first + 2, first + 3)
	return self


func cylinder(radius: float, height: float, pos: Vector3, color: Color, segments := 12, rot := Vector3.ZERO, top_radius := -1.0) -> MeshKit:
	var top := radius if top_radius < 0.0 else top_radius
	# Keep the original path for degenerate shapes with no invertible scale.
	if radius <= 0.0 or height <= 0.0:
		var mesh := CylinderMesh.new()
		mesh.bottom_radius = radius
		mesh.top_radius = top
		mesh.height = height
		mesh.radial_segments = segments
		mesh.rings = 0
		return add(mesh, Transform3D(Basis.from_euler(rot), pos), color)
	var key := Vector2(segments, top / radius)
	if not _unit_cylinders.has(key):
		var mesh := CylinderMesh.new()
		mesh.bottom_radius = 1.0
		mesh.top_radius = top / radius
		mesh.height = 1.0
		mesh.radial_segments = segments
		mesh.rings = 0
		_unit_cylinders[key] = mesh.get_mesh_arrays()
	return _add_arrays(_unit_cylinders[key], Transform3D(Basis.from_euler(rot) * Basis.from_scale(Vector3(radius, height, radius)), pos), color)


func cone(radius: float, height: float, pos: Vector3, color: Color, segments := 12, rot := Vector3.ZERO) -> MeshKit:
	return cylinder(radius, height, pos, color, segments, rot, 0.0)


func sphere(radius: float, pos: Vector3, color: Color, scale := Vector3.ONE, segments := 14, rings := 8, hemisphere := false) -> MeshKit:
	return _add_arrays(_sphere_arrays(segments, rings, hemisphere), Transform3D(Basis.from_scale(scale * radius), pos), color)


static func _sphere_arrays(segments: int, rings: int, hemisphere := false) -> Array:
	var key := Vector3i(segments, rings, int(hemisphere))
	if not _unit_spheres.has(key):
		var mesh := SphereMesh.new()
		mesh.radius = 1.0
		mesh.height = 1.0 if hemisphere else 2.0
		mesh.radial_segments = segments
		mesh.rings = rings
		mesh.is_hemisphere = hemisphere
		_unit_spheres[key] = mesh.get_mesh_arrays()
	return _unit_spheres[key]


## Rounded limb or torso: a capsule along local Y, optionally rotated and squashed.
func capsule(radius: float, height: float, pos: Vector3, color: Color, rot := Vector3.ZERO, scale := Vector3.ONE) -> MeshKit:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(height, radius * 2.0)
	mesh.radial_segments = 12
	mesh.rings = 4
	return add(mesh, Transform3D(Basis.from_euler(rot) * Basis.from_scale(scale), pos), color)


## A straight metal rail with flat ends, cheaper than a rounded capsule.
func cylinder_between(a: Vector3, b: Vector3, radius: float, color: Color, segments := 6) -> MeshKit:
	var span := b - a
	if span.length_squared() < 0.000001: return self
	var turn := Basis(Quaternion(Vector3.UP, span.normalized()))
	return cylinder(radius, span.length(), (a + b) * 0.5, color, segments, turn.get_euler())


## A capsule spanning from a to b: a limb, a tube, a branch.
func capsule_between(a: Vector3, b: Vector3, radius: float, color: Color, segments := 10) -> MeshKit:
	var span := b - a
	if span.length() < 0.001:
		return self
	var turn := Basis(Quaternion(Vector3.UP, span.normalized()))
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = span.length() + radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = 3 if segments >= 8 else 1
	return add(mesh, Transform3D(turn, (a + b) * 0.5), color)


## Ellipsoid: a sphere stretched by `radii` and rotated by `rot`.
func ellipsoid(radii: Vector3, pos: Vector3, color: Color, rot := Vector3.ZERO) -> MeshKit:
	return _add_arrays(_sphere_arrays(14, 8), Transform3D(Basis.from_euler(rot) * Basis.from_scale(radii), pos), color)


## Surface of revolution around local Y from a profile of (radius, height)
## points, bottom to top; smooth normals from the profile slope.
func lathe(profile: PackedVector2Array, xform: Transform3D, color: Color, segments := 16) -> MeshKit:
	var base := _vertices.size()
	var linear := color.srgb_to_linear()
	linear.a = color.a
	var normal_basis := xform.basis.inverse().transposed()
	for i in profile.size():
		var previous := profile[maxi(i - 1, 0)]
		var following := profile[mini(i + 1, profile.size() - 1)]
		var tangent := following - previous
		var outward := Vector2(tangent.y, -tangent.x).normalized()
		for k in segments + 1:
			var angle := TAU * k / segments
			var around := Vector3(cos(angle), 0.0, sin(angle))
			_vertices.append(xform * (around * profile[i].x + Vector3.UP * profile[i].y))
			_normals.append((normal_basis * (around * outward.x + Vector3.UP * outward.y)).normalized())
			_colors.append(linear)
	for i in profile.size() - 1:
		for k in segments:
			var a := base + i * (segments + 1) + k
			var b := a + segments + 1
			_indices.append_array([a, a + 1, b, a + 1, b + 1, b])
	return self


## A convex, counter-clockwise polygon in the local XY plane, extruded
## `thickness` along Z.
func slab(polygon: PackedVector2Array, thickness: float, xform: Transform3D, color: Color) -> MeshKit:
	var linear := color.srgb_to_linear()
	linear.a = color.a
	var normal_basis := xform.basis.inverse().transposed()
	var half := thickness * 0.5
	var count := polygon.size()
	for face in [-1.0, 1.0]:
		var base := _vertices.size()
		for point in polygon:
			_vertices.append(xform * Vector3(point.x, point.y, half * face))
			_normals.append((normal_basis * Vector3(0, 0, face)).normalized())
			_colors.append(linear)
		# Godot treats clockwise triangles as front faces.
		for i in range(1, count - 1):
			if face > 0.0:
				_indices.append_array([base, base + i + 1, base + i])
			else:
				_indices.append_array([base, base + i, base + i + 1])
	for i in count:
		var p0 := polygon[i]
		var p1 := polygon[(i + 1) % count]
		var outward := Vector2(p1.y - p0.y, p0.x - p1.x).normalized()
		var base := _vertices.size()
		for corner in [Vector3(p0.x, p0.y, -half), Vector3(p1.x, p1.y, -half), Vector3(p1.x, p1.y, half), Vector3(p0.x, p0.y, half)]:
			_vertices.append(xform * corner)
			_normals.append((normal_basis * Vector3(outward.x, outward.y, 0)).normalized())
			_colors.append(linear)
		_indices.append_array([base, base + 2, base + 1, base, base + 3, base + 2])
	return self


## Skins a series of closed rings (equal point counts) into one surface.
## `outward` holds, per ring, +1 if its surface faces away from the ring's
## centre (an outer wall) or -1 if it faces inwards (an inner wall).
## `cap_last` closes the final ring with a fan facing up (a floor).
func loft(rings: Array[PackedVector3Array], outward: PackedFloat32Array, xform: Transform3D, color: Color, cap_last := false) -> MeshKit:
	var linear := color.srgb_to_linear()
	linear.a = color.a
	var normal_basis := xform.basis.inverse().transposed()
	var count := rings[0].size()
	var base := _vertices.size()
	for r in rings.size():
		var ring := rings[r]
		var centre := Vector3.ZERO
		for p in ring:
			centre += p
		centre /= count
		var previous := rings[maxi(r - 1, 0)]
		var following := rings[mini(r + 1, rings.size() - 1)]
		for k in count:
			var along := ring[(k + 1) % count] - ring[(k - 1 + count) % count]
			var across := following[k] - previous[k]
			var n := along.cross(across).normalized()
			var away := (ring[k] - centre) * outward[r]
			if n.dot(away) < 0.0:
				n = -n
			_vertices.append(xform * ring[k])
			_normals.append((normal_basis * n).normalized())
			_colors.append(linear)
	for r in rings.size() - 1:
		for k in count:
			var a := base + r * count + k
			var b := base + r * count + (k + 1) % count
			var c := base + (r + 1) * count + k
			var e := base + (r + 1) * count + (k + 1) % count
			_triangle_facing(a, c, b)
			_triangle_facing(b, c, e)
	if cap_last:
		var last := rings[rings.size() - 1]
		var centre := Vector3.ZERO
		for p in last:
			centre += p
		centre /= count
		var middle := _vertices.size()
		_vertices.append(xform * centre)
		_normals.append((normal_basis * Vector3.UP).normalized())
		_colors.append(linear)
		var start := _vertices.size()
		for p in last:
			_vertices.append(xform * p)
			_normals.append((normal_basis * Vector3.UP).normalized())
			_colors.append(linear)
		for k in count:
			_triangle_facing(middle, start + k, start + (k + 1) % count)
	return self


## Adds triangle a-b-c wound so Godot sees its front on the side its vertex
## normals point to (Godot front faces are clockwise).
func _triangle_facing(a: int, b: int, c: int) -> void:
	var facing := (_vertices[c] - _vertices[a]).cross(_vertices[b] - _vertices[a])
	var wanted := _normals[a] + _normals[b] + _normals[c]
	if facing.dot(wanted) >= 0.0:
		_indices.append_array([a, b, c])
	else:
		_indices.append_array([a, c, b])


func torus(inner: float, outer: float, xform: Transform3D, color: Color, rings := 24, sides := 8) -> MeshKit:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = rings
	mesh.ring_segments = sides
	return add(mesh, xform, color)


## Closed outline of a rounded rectangle (superellipse), counter-clockwise
## seen from above, in the XZ plane at height y.
static func superellipse(half_x: float, half_z: float, y: float, points := 28, power := 4.0) -> PackedVector3Array:
	var ring := PackedVector3Array()
	for i in points:
		var angle := TAU * i / points
		var c := cos(angle)
		var s := sin(angle)
		ring.append(Vector3(signf(c) * pow(absf(c), 2.0 / power) * half_x, y, signf(s) * pow(absf(s), 2.0 / power) * half_z))
	return ring


## Closed outline in the XZ plane at height y whose radius goes in and out
## `lobes` times round, like the tips of branches round a spruce tier.
## `depth` is how far in (0 to 1) the radius dips between lobes; `jitter`
## varies each lobe's reach, from `seed`, so no two look alike.
static func lobed(radius: float, y: float, lobes: int, depth: float, seed: int, jitter := 0.0, droop := 0.0) -> PackedVector3Array:
	var ring := PackedVector3Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var reach := PackedFloat32Array()
	for i in lobes:
		reach.append(1.0 - rng.randf() * jitter)
	var twist := rng.randf() * TAU
	for i in lobes * 2:
		var angle := twist + PI * i / lobes
		var tip := i % 2 == 0
		var r := radius * (reach[i / 2] if tip else 1.0 - depth)
		ring.append(Vector3(cos(angle) * r, y - (droop * reach[i / 2] if tip else 0.0), sin(angle) * r))
	return ring


func prism(size: Vector3, pos: Vector3, color: Color, rot := Vector3.ZERO) -> MeshKit:
	var mesh := PrismMesh.new()
	mesh.size = size
	return add(mesh, Transform3D(Basis.from_euler(rot), pos), color)


## Optional float4 vertex data for props animated inside their shared shader.
func build(custom0 := PackedFloat32Array()) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_COLOR] = _colors
	arrays[Mesh.ARRAY_INDEX] = _indices
	var flags := 0
	if not custom0.is_empty():
		assert(custom0.size() == _vertices.size() * 4)
		arrays[Mesh.ARRAY_CUSTOM0] = custom0
		flags = Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	mesh.surface_set_material(0, Palette.surface())
	return mesh
