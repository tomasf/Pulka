class_name BirdMeshes
extends RefCounted
## Shared geometry: tapered bodies, layered folded wings, feathered flight
## wings and a separate head/feet. Forward is -Z; the feet rest at Y = 0.
enum Species { CROW, MAGPIE, BULLFINCH }
const SIZES := [1.0, 0.9, 0.62]
const FEATHERS := [Color("303844"), Color("243340"), Color("718092")]
const WINGS := [Color("222a36"), Color("193944"), Color("2b3442")]


static func body(species: Species, flying := false) -> ArrayMesh:
	return Props.cached_mesh("bird_body_%d_%s" % [species, flying], func() -> ArrayMesh:
		var m := MeshKit.new()
		var rings: Array[PackedVector3Array] = []
		# radius X, radius Y, centre Y, Z: the breast is deep and the rump
		# narrows into the tail, rather than a string of spheres.
		for section in [Vector4(0.012, 0.025, 0.34, -0.25), Vector4(0.105, 0.13, 0.30, -0.17), Vector4(0.15, 0.175, 0.25, 0.015), Vector4(0.11, 0.12, 0.22, 0.20), Vector4(0.025, 0.045, 0.19, 0.31)]:
			var ring := PackedVector3Array()
			for i in 12:
				var angle := TAU * i / 12
				ring.append(Vector3(cos(angle) * section.x, section.z + sin(angle) * section.y, section.w))
			rings.append(ring)
		m.loft(rings, PackedFloat32Array([1, 1, 1, 1, 1]), Transform3D.IDENTITY, FEATHERS[species])
		if species == Species.MAGPIE:
			m.ellipsoid(Vector3(0.12, 0.12, 0.19), Vector3(0, 0.18, -0.035), Color("e1e7e6"), Vector3(0.25, 0, 0))
		elif species == Species.BULLFINCH:
			m.ellipsoid(Vector3(0.125, 0.135, 0.13), Vector3(0, 0.25, -0.105), Color("c9584b"), Vector3(0.3, 0, 0))
		# Thin overlapping tail feathers, with a longer iridescent magpie tail.
		var length := 0.53 if species == Species.MAGPIE else 0.32
		for i in 5:
			var x := (i - 2) * (0.035 if flying else 0.022)
			var spread := x * (1.4 if flying else 0.7)
			var end := 0.28 + length - absf(i - 2) * 0.018
			_polygon(m, PackedVector3Array([Vector3(x - 0.027, 0.22, 0.22), Vector3(x + 0.027, 0.22, 0.22), Vector3(spread + 0.032, 0.16, end), Vector3(spread - 0.032, 0.16, end)]), WINGS[species].lightened(0.025 * (i % 2)))
		if not flying:
			for side in [-1.0, 1.0]:
				# Shoulder coverts and overlapping long flight feathers lie
				# against the flank until the wings open at takeoff.
				m.ellipsoid(Vector3(0.045, 0.10, 0.22), Vector3(side * 0.13, 0.28, 0.08), WINGS[species], Vector3(0.2, side * 0.12, 0))
				for i in 4:
					var x: float = side * (0.14 - i * 0.008)
					_polygon(m, PackedVector3Array([Vector3(x, 0.32 - i * 0.025, -0.05), Vector3(x + side * 0.02, 0.30 - i * 0.026, -0.03), Vector3(x, 0.19 - i * 0.01, 0.30 - i * 0.025)]), WINGS[species].lightened(0.06 * (i % 2)))
				if species != Species.CROW:
					m.ellipsoid(Vector3(0.012, 0.035, 0.10), Vector3(side * 0.167, 0.30, 0.04), Color("e0e7e8"), Vector3(0.3, 0, 0))
		return m.build())


static func head(species: Species) -> ArrayMesh:
	return Props.cached_mesh("bird_head_%d" % species, func() -> ArrayMesh:
		var m := MeshKit.new()
		var cap := Color("1b2430")
		m.ellipsoid(Vector3(0.105, 0.11, 0.12), Vector3(0, 0.065, -0.025), cap, Vector3(0.18, 0, 0))
		m.ellipsoid(Vector3(0.07, 0.08, 0.075), Vector3(0, -0.015, 0.025), FEATHERS[species], Vector3.ZERO)
		var beak_length := 0.085 if species == Species.BULLFINCH else 0.145
		var beak_color := Color("49545e") if species == Species.BULLFINCH else Color("252e38")
		# A closed wedge, pointed forward, with a visible lower mandible.
		m.slab(PackedVector2Array([Vector2(-0.045, -0.025), Vector2(0.045, -0.025), Vector2(0.032, 0.035), Vector2(-0.032, 0.035)]), 0.08, Transform3D(Basis.IDENTITY, Vector3(0, 0.055, -0.115)), beak_color)
		var tip := Vector3(0, 0.047, -0.12 - beak_length)
		for side in [-1.0, 1.0]:
			_polygon(m, PackedVector3Array([Vector3(side * 0.038, 0.08, -0.13), tip, Vector3(side * 0.044, 0.035, -0.13)]), beak_color.lightened(0.04))
			m.ellipsoid(Vector3(0.013, 0.017, 0.019), Vector3(side * 0.098, 0.09, -0.063), Color("090f16"), Vector3.ZERO)
			m.ellipsoid(Vector3(0.003, 0.005, 0.005), Vector3(side * 0.109, 0.095, -0.07), Color("a6b4bd"), Vector3.ZERO)
		_polygon(m, PackedVector3Array([Vector3(-0.038, 0.08, -0.13), Vector3(0.038, 0.08, -0.13), tip]), beak_color.lightened(0.09))
		_polygon(m, PackedVector3Array([Vector3(-0.044, 0.035, -0.13), tip, Vector3(0.044, 0.035, -0.13)]), beak_color.darkened(0.15))
		return m.build())


static func foot() -> ArrayMesh:
	return Props.cached_mesh("bird_foot", func() -> ArrayMesh:
		var m := MeshKit.new()
		var claw := Color("40424a")
		m.cylinder(0.012, 0.12, Vector3(0, -0.045, 0), claw, 5)
		for i in 3:
			m.box(Vector3(0.012, 0.012, 0.08), Vector3((i - 1) * 0.018, -0.105, -0.025), claw, Vector3(0, (i - 1) * -0.25, 0))
		m.box(Vector3(0.012, 0.012, 0.045), Vector3(0, -0.105, 0.028), claw)
		return m.build())


static func wing(species: Species, side: int) -> ArrayMesh:
	return Props.cached_mesh("bird_wing_%d_%d" % [species, side], func() -> ArrayMesh:
		var m := MeshKit.new()
		var outline := PackedVector3Array([Vector3(0, 0, -0.10), Vector3(0.22, 0.025, -0.15), Vector3(0.46, 0.005, -0.065), Vector3(0.62, -0.015, 0.07), Vector3(0.30, -0.025, 0.23), Vector3(0.07, -0.015, 0.19)])
		for i in outline.size(): outline[i].x *= side
		_polygon(m, outline, WINGS[species])
		# Separated primary tips read as feathers in silhouette at speed.
		for i in 7:
			var x := 0.25 + i * 0.043
			var z := 0.15 - i * 0.017
			var length := 0.22 - absf(i - 3) * 0.018
			_polygon(m, PackedVector3Array([Vector3(side * x, 0, z - 0.06), Vector3(side * (x + 0.053), 0, z - 0.07), Vector3(side * (x + 0.17), -0.015, z + length * 0.7), Vector3(side * (x + 0.13), -0.02, z + length)]), WINGS[species].lightened(0.04 * (i % 2)))
		if species != Species.CROW:
			_polygon(m, PackedVector3Array([Vector3(side * 0.12, 0.012, -0.08), Vector3(side * 0.33, 0.032, -0.10), Vector3(side * 0.46, 0.018, -0.02), Vector3(side * 0.22, 0.015, 0.12)]), Color("dce5e7"))
		return m.build())


static func _polygon(m: MeshKit, points: PackedVector3Array, color: Color) -> void:
	var start := m._vertices.size()
	var n := (points[1] - points[0]).cross(points[2] - points[0]).normalized()
	if n.y < 0: n = -n
	for p in points:
		m._vertices.append(p)
		m._normals.append(n)
		m._colors.append(color.srgb_to_linear())
	for i in range(1, points.size() - 1): m._triangle_facing(start, start + i, start + i + 1)
