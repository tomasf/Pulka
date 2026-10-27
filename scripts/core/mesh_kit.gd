class_name MeshKit
extends RefCounted
## Merges transformed, vertex-colored primitives into a single ArrayMesh so a
## whole prop (tree, house, car...) renders as one draw call.

var _vertices := PackedVector3Array()
var _normals := PackedVector3Array()
var _colors := PackedColorArray()
var _indices := PackedInt32Array()


func add(mesh: PrimitiveMesh, xform: Transform3D, color: Color) -> MeshKit:
	var arrays := mesh.get_mesh_arrays()
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
	var mesh := BoxMesh.new()
	mesh.size = size
	return add(mesh, Transform3D(Basis.from_euler(rot), pos), color)


func cylinder(radius: float, height: float, pos: Vector3, color: Color, segments := 12, rot := Vector3.ZERO, top_radius := -1.0) -> MeshKit:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 0
	return add(mesh, Transform3D(Basis.from_euler(rot), pos), color)


func cone(radius: float, height: float, pos: Vector3, color: Color, segments := 12, rot := Vector3.ZERO) -> MeshKit:
	return cylinder(radius, height, pos, color, segments, rot, 0.0)


func sphere(radius: float, pos: Vector3, color: Color, scale := Vector3.ONE, segments := 14, rings := 8, hemisphere := false) -> MeshKit:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * (1.0 if hemisphere else 2.0)
	mesh.radial_segments = segments
	mesh.rings = rings
	mesh.is_hemisphere = hemisphere
	return add(mesh, Transform3D(Basis.from_scale(scale), pos), color)


## Rounded limb or torso: a capsule along local Y, optionally rotated and squashed.
func capsule(radius: float, height: float, pos: Vector3, color: Color, rot := Vector3.ZERO, scale := Vector3.ONE) -> MeshKit:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(height, radius * 2.0)
	mesh.radial_segments = 12
	mesh.rings = 4
	return add(mesh, Transform3D(Basis.from_euler(rot) * Basis.from_scale(scale), pos), color)


## Ellipsoid: a sphere stretched by `radii` and rotated by `rot`.
func ellipsoid(radii: Vector3, pos: Vector3, color: Color, rot := Vector3.ZERO) -> MeshKit:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 14
	mesh.rings = 8
	return add(mesh, Transform3D(Basis.from_euler(rot) * Basis.from_scale(radii), pos), color)


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


func prism(size: Vector3, pos: Vector3, color: Color, rot := Vector3.ZERO) -> MeshKit:
	var mesh := PrismMesh.new()
	mesh.size = size
	return add(mesh, Transform3D(Basis.from_euler(rot), pos), color)


func build() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_COLOR] = _colors
	arrays[Mesh.ARRAY_INDEX] = _indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, Palette.surface())
	return mesh
