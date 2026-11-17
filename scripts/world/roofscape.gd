class_name Roofscape
extends RefCounted
## Snow-covered, rideable city roofs. One merged mesh per building; owning
## a building by its midpoint keeps both ends alive across chunk seams.

const WALLS := [Color("b66e50"), Color("d0b68c"), Color("91a6a2"), Color("c6b9a2"), Color("a58d84"), Color("c7b27d")]
const TILES := [Color("713d35"), Color("424f5b"), Color("596158")]
const TRIM := Color("ded8ca")
const GLASS := Color(0.96, 0.80, 0.51, 0.86)


class BuildJob:
	var field: TerrainField
	var roof: TerrainField.Roof
	var target: WeakRef
	var kit := MeshKit.new()
	var mesh: ArrayMesh
	var stage := 0

	func _init(terrain: TerrainField, tile: TerrainField.Roof) -> void:
		field = terrain
		roof = tile

	## Each step is a small part of a building, within the streaming budget.
	func step() -> bool:
		match stage:
			0: Roofscape._surface(kit, field, roof)
			1: Roofscape._walls(kit, field, roof)
			2: Roofscape._facade(kit, field, roof)
			3: Roofscape._details(kit, field, roof)
			4:
				mesh = kit.build()
				return true
		stage += 1
		return false


static func house(field: TerrainField, roof: TerrainField.Roof) -> ArrayMesh:
	var job := BuildJob.new(field, roof)
	while not job.step(): pass
	return job.mesh


static func _cross_sections(roof: TerrainField.Roof) -> PackedFloat32Array:
	return PackedFloat32Array([-roof.half_width, -roof.half_width + 0.18, -3.2 if roof.lane == 0 else (-0.18 if roof.lane < 0 else -1.1), 0, 3.2 if roof.lane == 0 else (0.18 if roof.lane < 0 else 1.1), roof.half_width - 0.18, roof.half_width])


static func _surface(kit: MeshKit, field: TerrainField, roof: TerrainField.Roof) -> void:
	var xs := _cross_sections(roof)
	var rows := ceili((roof.finish - roof.start) / 1.25)
	var base := kit._vertices.size()
	for r in rows + 1:
		var d := lerpf(roof.start, roof.finish, float(r) / rows)
		for lx in xs:
			var x := roof.center(d) + lx
			var surface := field._roof_surface(roof, x, d)
			kit._vertices.append(Vector3(x, surface.w, -d))
			kit._normals.append(Vector3(surface.x, surface.y, surface.z))
			kit._colors.append(Palette.SNOW.srgb_to_linear())
	for r in rows:
		for c in xs.size() - 1:
			var a := base + r * xs.size() + c
			kit._triangle_facing(a, a + xs.size(), a + 1)
			kit._triangle_facing(a + 1, a + xs.size(), a + xs.size() + 1)


static func _walls(kit: MeshKit, field: TerrainField, roof: TerrainField.Roof) -> void:
	var wall: Color = WALLS[roof.variant % WALLS.size()]
	var tile: Color = TILES[roof.variant % TILES.size()]
	var xs := _cross_sections(roof)
	var rows := ceili((roof.finish - roof.start) / 1.25)
	# Fascia shows the underlying tile/metal roof beneath the snow blanket.
	for side in [-1.0, 1.0]:
		var previous := _top(field, roof, roof.start, side * roof.half_width)
		for r in range(1, rows + 1):
			var d := lerpf(roof.start, roof.finish, float(r) / rows)
			var next := _top(field, roof, d, side * roof.half_width)
			_quad(kit, previous, next, next - Vector3.UP * 0.24, previous - Vector3.UP * 0.24, tile, Vector3(side, 0, 0))
			var a := previous - Vector3.UP * 0.24
			var b := next - Vector3.UP * 0.24
			var foot_a := field.height(a.x, -a.z, false, false) - 0.15
			var foot_b := field.height(b.x, -b.z, false, false) - 0.15
			_quad(kit, a, b, Vector3(b.x, minf(foot_b, b.y - 0.1), b.z), Vector3(a.x, minf(foot_a, a.y - 0.1), a.z), wall, Vector3(side, 0, 0))
			previous = next
	for d in [roof.start, roof.finish]:
		var facing := Vector3(0, 0, 1 if d == roof.start else -1)
		for i in xs.size() - 1:
			var a := _top(field, roof, d, xs[i])
			var b := _top(field, roof, d, xs[i + 1])
			_quad(kit, a, b, b - Vector3.UP * 0.24, a - Vector3.UP * 0.24, tile, facing)
			var fa := minf(field.height(a.x, d, false, false) - 0.15, a.y - 0.4)
			var fb := minf(field.height(b.x, d, false, false) - 0.15, b.y - 0.4)
			_quad(kit, a - Vector3.UP * 0.24, b - Vector3.UP * 0.24, Vector3(b.x, fb, b.z), Vector3(a.x, fa, a.z), wall, facing)


static func _details(kit: MeshKit, field: TerrainField, roof: TerrainField.Roof) -> void:
	var tile: Color = TILES[roof.variant % TILES.size()]
	# Low skylights and a TV aerial sit off the broad central riding line.
	var detail_d := lerpf(roof.start, roof.finish, 0.36)
	var side := -1.0 if roof.variant % 2 == 0 else 1.0
	var x := roof.center(detail_d) + side * 4.35
	var surface := field._roof_surface(roof, x, detail_d)
	var up := Vector3(surface.x, surface.y, surface.z)
	var basis := Basis(Quaternion(Vector3.UP, up))
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	var at := Vector3(x, surface.w, -detail_d)
	kit.add(cube, Transform3D(basis.scaled_local(Vector3(1.1, 0.10, 1.65)), at + up * 0.06), tile)
	kit.add(cube, Transform3D(basis.scaled_local(Vector3(0.87, 0.03, 1.40)), at + up * 0.13), Color("7c9baa"))
	var mast_d := lerpf(roof.start, roof.finish, 0.72)
	var mast := _top(field, roof, mast_d, -side * (roof.half_width - 0.35))
	kit.cylinder(0.018, 1.5, mast + Vector3.UP * 0.75, Color("626e78"), 6)
	for i in 3:
		kit.box(Vector3(0.85 - i * 0.16, 0.024, 0.024), mast + Vector3(0, 1.1 + i * 0.14, 0), Color("626e78"))


static func _facade(kit: MeshKit, field: TerrainField, roof: TerrainField.Roof) -> void:
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	for d in [roof.start, roof.finish]:
		var sign_z := 1.0 if d == roof.start else -1.0
		for column in [-3.5, 0.0, 3.5]:
			for level in [3.0, 6.6, 10.0]:
				var p := Vector3(roof.center(d) + column, roof.base(d) - level, -d + sign_z * 0.025)
				if p.y < field.height(p.x, d, false, false) + 1.0: continue
				_window(kit, cube, p, Vector3.RIGHT, Vector3(0, 0, sign_z), roof.variant + int(column + level))
	for side in [-1.0, 1.0]:
		var along := Vector3(roof.dx, 0, -1).normalized()
		var outward: Vector3 = Vector3(-along.z, 0, along.x) * side
		for i in 4:
			var d := lerpf(roof.start, roof.finish, (i + 0.5) / 4.0)
			for level in [3.0, 6.6, 10.0]:
				var p: Vector3 = Vector3(roof.center(d) + side * roof.half_width, roof.base(d) - level, -d) + outward * 0.03
				if p.y < field.height(p.x, d, false, false) + 1.0: continue
				_window(kit, cube, p, along, outward, roof.variant + i + int(level))


static func _window(kit: MeshKit, cube: BoxMesh, p: Vector3, along: Vector3, outward: Vector3, variant: int) -> void:
	var basis := Basis(along, Vector3.UP, outward)
	kit.add(cube, Transform3D(basis.scaled_local(Vector3(1.45, 1.75, 0.09)), p), TRIM)
	kit.add(cube, Transform3D(basis.scaled_local(Vector3(1.19, 1.47, 0.04)), p + outward * 0.065), GLASS if variant % 3 != 0 else Color("52616e"))
	kit.add(cube, Transform3D(basis.scaled_local(Vector3(0.06, 1.48, 0.045)), p + outward * 0.09), TRIM)


static func chimney() -> ArrayMesh:
	return Props.cached_mesh("roof_chimney", func() -> ArrayMesh:
		var kit := MeshKit.new()
		var brick := Color("934f40")
		var mortar := Color("b09b84")
		kit.box(Vector3(1.1, 1.35, 1.0), Vector3(0, 0.675, 0), brick)
		for row in 7:
			var y := 0.09 + row * 0.18
			for side in [-1.0, 1.0]:
				kit.box(Vector3(1.105, 0.018, 0.012), Vector3(0, y, side * 0.502), mortar)
				kit.box(Vector3(0.012, 0.018, 1.005), Vector3(side * 0.552, y, 0), mortar)
				kit.box(Vector3(0.018, 0.18, 0.012), Vector3(0.19 if row % 2 == 0 else -0.19, y, side * 0.505), mortar)
		kit.box(Vector3(1.35, 0.16, 1.2), Vector3(0, 1.35, 0), Color("5a5655"))
		kit.box(Vector3(1.37, 0.07, 1.22), Vector3(0, 1.455, 0), Palette.SNOW)
		for x in [-0.3, 0.3]:
			kit.cylinder(0.16, 0.32, Vector3(x, 1.58, 0), brick, 12)
			kit.cylinder(0.115, 0.015, Vector3(x, 1.745, 0), Color("29282b"), 12)
		return kit.build())


static func _top(field: TerrainField, roof: TerrainField.Roof, d: float, lx: float) -> Vector3:
	var x := roof.center(d) + lx
	return Vector3(x, field.roof_height(roof, x, d), -d)


static func _quad(kit: MeshKit, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, outward: Vector3) -> void:
	var base := kit._vertices.size()
	var n := (b - a).cross(c - a).normalized()
	if n.dot(outward) < 0: n = -n
	var linear := color.srgb_to_linear()
	linear.a = color.a
	for p in [a, b, c, d]:
		kit._vertices.append(p)
		kit._normals.append(n)
		kit._colors.append(linear)
	kit._triangle_facing(base, base + 1, base + 2)
	kit._triangle_facing(base, base + 2, base + 3)
