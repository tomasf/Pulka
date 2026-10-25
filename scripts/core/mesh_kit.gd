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
