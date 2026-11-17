extends SceneTree
## Cached unit shapes must keep the positions, normals and winding of the
## original sized primitives, including rotated/nonuniformly scaled shapes.

func _initialize() -> void:
	var size := Vector3(0.3, 2.7, 8.0)
	var pos := Vector3(4.0, -2.0, 6.0)
	var rot := Vector3(0.4, -0.7, 1.2)
	var box := BoxMesh.new()
	box.size = size
	_compare(MeshKit.new().box(size, pos, Color.CORAL, rot), MeshKit.new().add(box, Transform3D(Basis.from_euler(rot), pos), Color.CORAL))
	for hemisphere in [false, true]:
		var sphere := SphereMesh.new()
		sphere.radius = 0.37
		sphere.height = 0.37 * (1.0 if hemisphere else 2.0)
		sphere.radial_segments = 14
		sphere.rings = 8
		sphere.is_hemisphere = hemisphere
		_compare(MeshKit.new().sphere(0.37, pos, Color.CORAL, size, 14, 8, hemisphere), MeshKit.new().add(sphere, Transform3D(Basis.from_scale(size), pos), Color.CORAL))
	var unit := SphereMesh.new()
	unit.radius = 1.0
	unit.height = 2.0
	unit.radial_segments = 14
	unit.rings = 8
	_compare(MeshKit.new().ellipsoid(size, pos, Color.CORAL, rot), MeshKit.new().add(unit, Transform3D(Basis.from_euler(rot) * Basis.from_scale(size), pos), Color.CORAL))
	for top in [0.0, 0.3, 0.55]:
		var cylinder := CylinderMesh.new()
		cylinder.bottom_radius = 0.3
		cylinder.top_radius = top
		cylinder.height = 1.8
		cylinder.radial_segments = 12
		cylinder.rings = 0
		_compare(MeshKit.new().cylinder(0.3, 1.8, pos, Color.CORAL, 12, rot, top), MeshKit.new().add(cylinder, Transform3D(Basis.from_euler(rot), pos), Color.CORAL))
	print("mesh kit test: all passed")
	quit()

func _compare(actual: MeshKit, expected: MeshKit) -> void:
	assert(actual._indices == expected._indices)
	assert(actual._colors == expected._colors)
	assert(actual._vertices.size() == expected._vertices.size())
	for i in actual._vertices.size():
		assert(actual._vertices[i].distance_to(expected._vertices[i]) < 0.0001, "Primitive position changed")
		# RenderingServer packs normals when reading a primitive back.
		assert(actual._normals[i].distance_to(expected._normals[i]) < 0.001, "Primitive normal changed")
