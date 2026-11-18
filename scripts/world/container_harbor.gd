class_name ContainerHarbor
extends RefCounted
## Corrugated cargo, a rideable container lane and a narrow waterside detour.
const COLORS := [Color("b5483e"), Color("2d7890"), Color("d49d39"), Color("42826c"), Color("49659b"), Color("a35b41")]
static var _water: ShaderMaterial


static func cargo(variant: int, open_ends := false) -> ArrayMesh:
	return Props.cached_mesh("cargo_%d_%s" % [variant % COLORS.size(), open_ends], func() -> ArrayMesh:
		var m := MeshKit.new()
		var paint: Color = COLORS[variant % COLORS.size()]
		var frame := paint.darkened(0.25)
		# Unit footprint 5.2 x 16, base at zero, roof at four metres.
		for side in [-1.0, 1.0]:
			m.box(Vector3(0.1, 3.8, 15.8), Vector3(side * 2.55, 2, 0), paint)
			for i in 16:
				m.box(Vector3(0.12, 3.35, 0.17), Vector3(side * 2.61, 2, -7.6 + i * 0.99), paint.lightened(0.09))
			for y in [0.12, 3.88]:
				m.box(Vector3(0.22, 0.24, 16), Vector3(side * 2.5, y, 0), frame)
			for z in [-7.85, 7.85]:
				m.box(Vector3(0.22, 4, 0.3), Vector3(side * 2.5, 2, z), frame)
				for y in [0.2, 3.8]:
					m.box(Vector3(0.28, 0.28, 0.36), Vector3(side * 2.5, y, z), Color("a6aeb5"))
		m.box(Vector3(5, 0.03 if open_ends else 0.12, 16), Vector3(0, 0.015 if open_ends else 0.06, 0), Color("727375"))
		m.box(Vector3(5.2, 0.16, 16), Vector3(0, 3.92, 0), paint)
		m.box(Vector3(5, 0.06, 15.6), Vector3(0, 4.01, 0), Color("dce7eb"))
		for z in [-7.94, 7.94]:
			m.box(Vector3(5.2, 0.22, 0.22), Vector3(0, 3.9, z), frame)
			if open_ends: continue
			for side in [-1.0, 1.0]:
				m.box(Vector3(2.4, 3.7, 0.12), Vector3(side * 1.23, 2, z), paint)
				for bar in [0.55, 1.85]:
					m.box(Vector3(0.06, 3.3, 0.08), Vector3(side * bar, 2, z + signf(z) * 0.09), Color("a6afb6"))
				m.box(Vector3(0.4, 0.09, 0.13), Vector3(side * 1.85, 1.65, z + signf(z) * 0.14), Color("d0d5d7"))
				m.box(Vector3(0.62, 0.42, 0.03), Vector3(side * 1.1, 3.0, z + signf(z) * 0.13), Color("e3e3cf"))
		return m.build())


static func transform_at(field: TerrainField, d: float, lx: float, size := Vector3.ONE, lift := 0.0) -> Transform3D:
	# Shear follows the analytic quay exactly: container tops, ramp endpoints
	# and their collision surface meet even on a steep part of the descent.
	var slope := (field.harbor_height(d + 0.5) - field.harbor_height(d - 0.5))
	var basis := Basis(Vector3.RIGHT, Vector3.UP, Vector3(-field.center_slope(d), -slope, 1))
	return Transform3D(basis.scaled_local(size), Vector3(field.center_x(d) + lx, field.harbor_height(d) + lift, -d))


static func _fixed(world: SlopeWorld, chunk: Chunk, mesh: Mesh, at: Transform3D, half: Vector2, height: float) -> void:
	var box := Obstacle.new().configure(Obstacle.Kind.CONTAINER, Props.Rig.of(mesh), world.field)
	box.position = at.origin
	box.visual.basis = at.basis
	box.half_extents = half
	box.top = height
	box.collision_sweep = world.field.center_slope(-at.origin.z)
	box.collision_slope = (world.field.harbor_height(-at.origin.z + 0.5) - world.field.harbor_height(-at.origin.z - 0.5))
	chunk.add_child(box)
	chunk.obstacles.append(box)


static func populate(world: SlopeWorld, chunk: Chunk, decor: Dictionary, lo: float, hi: float, span: Vector3) -> void:
	var field := world.field
	lo = maxf(lo, span.x + TerrainField.HARBOR_INSET)
	hi = minf(hi, span.y - TerrainField.HARBOR_INSET)
	if hi <= lo: return
	var quay := MeshInstance3D.new()
	quay.name = "HarborRoutes"
	chunk.add_child(quay)
	var sea := MeshInstance3D.new()
	sea.name = "HarborWater"
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chunk.add_child(sea)
	var job := BuildJob.new(field, lo, hi, span)
	job.target = weakref(quay)
	job.sea_target = weakref(sea)
	world.regions._region_jobs.append(job)
	var d := lo
	# The raised lane is part of the height field. Crossing its side below
	# the roof is caught by below_structure rather than snapping onto cargo.
	for offset in [100.0, 120.0]:
		d = span.x + offset
		if d >= lo and d < hi:
			world.add_decor(decor, cargo(2 if offset < 110 else 1), transform_at(field, d, -7))
	d = ceilf(lo / 26) * 26
	while d < hi:
		for side in [-1.0, 1.0]:
			if side > 0 and (absf(d - span.x - 160) < 14 or absf(d - span.x - 238) < 14): continue
			var index := int(floorf(d / 26))
			var lx: float = -17.0 if side < 0 else 14.5
			var variant := posmod(index + (2 if side > 0 else 0), COLORS.size())
			var at := transform_at(field, d, lx, Vector3(0.8, 0.8, 0.75))
			_fixed(world, chunk, cargo(variant), at, Vector2(2.08, 6), 6.4 if index % 3 != 0 else 3.2)
			if index % 3 != 0:
				world.add_decor(decor, cargo((variant + 2) % COLORS.size()), transform_at(field, d, lx, Vector3(0.8, 0.8, 0.75), 3.2))
		d += 26
	# Open cargo tunnels: clear through the middle, solid along both walls.
	d = span.x + 78
	while d < span.y - 48:
		if d >= lo and d < hi:
			world.add_decor(decor, cargo(3, true), transform_at(field, d, 5.5, Vector3(0.9, 1.1, 0.65)))
			for side in [-1.0, 1.0]:
				var wall := Obstacle.new().configure(Obstacle.Kind.CONTAINER, Props.Rig.of(null), field)
				wall.position = Vector3(field.center_x(d) + 5.5 + side * 2.3, field.harbor_height(d), -d)
				wall.half_extents = Vector2(0.14, 5.2)
				wall.top = 4.4
				wall.collision_sweep = field.center_slope(d)
				wall.collision_slope = field.harbor_height(d + 0.5) - field.harbor_height(d - 0.5)
				chunk.add_child(wall)
				chunk.obstacles.append(wall)
		d += 62
	d = ceilf(lo / 8) * 8
	while d < hi:
		var u := d - span.x
		world._add_pickup(chunk, Pickup.Kind.GINGERBREAD, field.center_x(d), d)
		if u >= 72 and u < 150 and field.harbor_route_lift(d) >= 0:
			world._add_pickup(chunk, Pickup.Kind.GINGERBREAD, field.center_x(d) - 7, d)
		if u >= 160 and u <= 238:
			world._add_pickup(chunk, Pickup.Kind.GINGERBREAD, field.center_x(d) + field.harbor_gangway_x(d), d)
		d += 8
	var ship_d := span.x + 146
	if ship_d >= lo and ship_d < hi:
		world.add_decor(decor, ship(), transform_at(field, ship_d, 48, Vector3.ONE, -2.8))
	# Dockside lamps and rubber fenders make the water's edge legible at speed.
	d = ceilf(lo / 16) * 16
	while d < hi:
		world.add_decor(decor, Props.lamp_post(), transform_at(field, d, -22))
		world.add_decor(decor, fender(), transform_at(field, d, 20.3, Vector3.ONE, -1.2))
		d += 16


class BuildJob:
	var target: WeakRef
	var sea_target: WeakRef
	var mesh: ArrayMesh
	var field: TerrainField
	var span: Vector3
	var hi: float
	var at: float
	var geometry := MeshKit.new()
	var water := MeshKit.new()
	var stage := 0

	func _init(terrain: TerrainField, first: float, last: float, region: Vector3) -> void:
		field = terrain
		span = region
		at = first
		hi = last

	func step() -> bool:
		if at < hi - 0.001:
			var next := minf(hi, (floorf(at / 2) + 1) * 2)
			# Put vertices on every ramp/deck boundary, even when the seeded
			# region starts between the regular two-metre terrain rows.
			for offset in [70.0, 92.0, 128.0, 150.0, 160.0, 184.0, 214.0, 238.0]:
				var boundary: float = span.x + offset
				if boundary > at + 0.001: next = minf(next, boundary)
			ContainerHarbor._slice(geometry, water, field, at, next, span)
			at = next
			return false
		if stage == 0:
			mesh = geometry.build()
			stage = 1
			return false
		var sea: MeshInstance3D = sea_target.get_ref()
		if sea:
			sea.mesh = water.build()
			sea.material_override = ContainerHarbor.water_material()
		return true


static func water_material() -> ShaderMaterial:
	if _water == null:
		_water = ShaderMaterial.new()
		_water.shader = load("res://shaders/water.gdshader")
	return _water


static func _slice(geometry: MeshKit, water: MeshKit, field: TerrainField, d: float, next: float, span: Vector3) -> void:
	var a := Vector3(field.center_x(d) + 20, field.harbor_height(d), -d)
	var b := Vector3(field.center_x(next) + 20, field.harbor_height(next), -next)
	# Concrete quay face and its yellow safety line.
	IceCavern.quad(geometry, a, b, b - Vector3.UP * 6, a - Vector3.UP * 6, Color("656d79"), Vector3.RIGHT)
	IceCavern.quad(geometry, a + Vector3(-0.55, 0.03, 0), a + Vector3.UP * 0.03, b + Vector3.UP * 0.03, b + Vector3(-0.55, 0.03, 0), Color("e7bb53"), Vector3.UP)
	IceCavern.quad(water, a - Vector3.UP * 2.8, a + Vector3(105, -2.8, 0), b + Vector3(105, -2.8, 0), b - Vector3.UP * 2.8, Color.WHITE, Vector3.UP)
	# Both ramps sample the exact height used by the sled.
	var mid := (d + next) * 0.5
	var u := mid - span.x - 70
	if (u >= 0 and u < 22) or (u > 58 and u <= 80):
		var corners: Array[Vector3] = []
		for pair in [Vector2(d, -2.6), Vector2(d, 2.6), Vector2(next, 2.6), Vector2(next, -2.6)]:
			var x: float = field.center_x(pair.x) - 7 + pair.y
			var y := field.harbor_height(pair.x) + maxf(0, field.harbor_route_lift(pair.x)) + 0.035
			corners.append(Vector3(x, y, -pair.x))
		IceCavern.quad(geometry, corners[0], corners[1], corners[2], corners[3], Color("778593"), Vector3.UP)
		for side in [0, 1]:
			var e: Vector3 = corners[side]
			var f: Vector3 = corners[3 - side]
			IceCavern.quad(geometry, e, f, f - Vector3.UP * 0.25, e - Vector3.UP * 0.25, Color("e8b344"), Vector3.RIGHT)
	# A plank walkway bends out above the water and rejoins the quay.
	if mid >= span.x + 160 and mid <= span.x + 238:
		var p := Vector3(field.center_x(d) + field.harbor_gangway_x(d), field.harbor_height(d) + 0.285, -d)
		var q := Vector3(field.center_x(next) + field.harbor_gangway_x(next), field.harbor_height(next) + 0.285, -next)
		IceCavern.quad(geometry, p - Vector3.RIGHT * 1.7, p + Vector3.RIGHT * 1.7, q + Vector3.RIGHT * 1.7, q - Vector3.RIGHT * 1.7, Color("b29972") if int(d) % 4 == 0 else Color("c8af89"), Vector3.UP)
		for side in [-1.0, 1.0]:
			IceCavern.quad(geometry, p + Vector3(side * 1.7, 0, 0), q + Vector3(side * 1.7, 0, 0), q + Vector3(side * 1.7, -0.3, 0), p + Vector3(side * 1.7, -0.3, 0), Color("d6ae52"), Vector3.RIGHT)


static func fender() -> ArrayMesh:
	return Props.cached_mesh("harbor_fender", func() -> ArrayMesh:
		var m := MeshKit.new()
		m.cylinder(0.65, 2.4, Vector3.ZERO, Color("252b36"), 10)
		m.box(Vector3(0.65, 0.16, 1.5), Vector3(-0.3, 1.3, 0), Color("e1b542"))
		return m.build())


## Compact feeder vessel: flared hull, working deck, corrugated cargo,
## accommodation and a bridge with proper windows, rails and deck equipment.
static func ship() -> ArrayMesh:
	return Props.cached_mesh("container_ship", func() -> ArrayMesh:
		var m := MeshKit.new()
		var hull := Color("263f55")
		var steel := Color("b5c3c9")
		var dark := Color("25323a")
		var deck := Color("775b4a")
		var rings: Array[PackedVector3Array] = []
		for level in [Vector2(-3, 0.76), Vector2(-0.45, 0.97), Vector2(2.15, 1)]:
			var ring := PackedVector3Array()
			for p in [Vector2(-7.5, -26), Vector2(-4.8, -32), Vector2(0, -35), Vector2(4.8, -32), Vector2(7.5, -26), Vector2(7.5, 26), Vector2(6, 29), Vector2(-6, 29), Vector2(-7.5, 26)]:
				var sheer := clampf((-p.y - 22) / 13, 0, 1) * 0.65
				ring.append(Vector3(p.x * level.y, level.x + sheer, p.y * (0.94 if level.x < -1 else 1)))
			rings.append(ring)
		m.loft([rings[0], rings[1]], PackedFloat32Array([1, 1]), Transform3D.IDENTITY, Color("724638"))
		m.loft([rings[1], rings[2]], PackedFloat32Array([1, 1]), Transform3D.IDENTITY, hull, true)
		# Deck cap follows the bow instead of projecting through its sides.
		var edge := rings[2]
		for i in edge.size():
			var a := edge[i]
			var b := edge[(i + 1) % edge.size()]
			m.quad(a + Vector3.UP * 0.02, b + Vector3.UP * 0.02, b * Vector3(0.92, 1, 0.97) + Vector3.UP * 0.02, a * Vector3(0.92, 1, 0.97) + Vector3.UP * 0.02, deck, Vector3.UP)
			_ship_rail(m, a, b, steel)
		m.box(Vector3(13.8, 0.12, 45), Vector3(0, 2.22, -2.5), deck)
		for side in [-1.0, 1.0]:
			m.box(Vector3(0.05, 0.12, 48), Vector3(side * 7.48, 1.50, 0), Color("cfdae0"))
			for z in [-20.0, -4.0, 12.0, 24.0]:
				m.box(Vector3(0.12, 0.18, 0.8), Vector3(side * 7.49, 0.35, z), hull.darkened(0.3))
		# Lashings, distinct doors and ribs make the cargo read as containers.
		for lane in 2:
			for bay in 3:
				var x := -3.55 + lane * 7.1
				var z := -18.5 + bay * 12.7
				var stacks := 1 if bay == 0 else 2
				for level in stacks:
					_ship_container(m, Vector3(x, 2.31 + level * 3.47, z), COLORS[(lane + bay * 2 + level * 3) % COLORS.size()])
		# Accommodation block, distinct deck levels and projecting wheelhouse.
		m.box(Vector3(10.6, 7.7, 8.7), Vector3(0, 6.15, 23.2), Color("d5dcd9"))
		for y in [4.9, 7.4, 10.0]:
			m.box(Vector3(10.85, 0.15, 8.95), Vector3(0, y, 23.2), steel)
		for side in [-1.0, 1.0]:
			for y in [4.0, 6.5, 8.8]:
				for z in [20.6, 23.0, 25.4]:
					m.cylinder(0.31, 0.08, Vector3(side * 5.33, y, z), steel.darkened(0.25), 12, Vector3(0, 0, PI / 2))
					m.cylinder(0.24, 0.09, Vector3(side * 5.36, y, z), Color("304c61"), 12, Vector3(0, 0, PI / 2))
			# Wall ladder, firmly mounted at both rails and each rung.
			for z in [26.0, 26.6]: m.cylinder_between(Vector3(side * 5.48, 2.3, z), Vector3(side * 5.48, 10.05, z), 0.045, steel, 6)
			for step in 21: m.cylinder_between(Vector3(side * 5.48, 2.6 + step * 0.35, 26), Vector3(side * 5.48, 2.6 + step * 0.35, 26.6), 0.035, steel, 6)
			for y in [3.0, 6.0, 9.0]:
				for z in [26.0, 26.6]: m.cylinder_between(Vector3(side * 5.3, y, z), Vector3(side * 5.48, y, z), 0.045, steel, 6)
		m.box(Vector3(13.7, 0.18, 10.8), Vector3(0, 10.07, 23.2), steel)
		m.box(Vector3(12.9, 2.1, 9.5), Vector3(0, 11.2, 23.2), Color("e5e9e0"))
		m.box(Vector3(13.6, 0.22, 10.1), Vector3(0, 12.37, 23.2), steel)
		m.box(Vector3(12.7, 0.08, 9.4), Vector3(0, 12.52, 23.2), Palette.SNOW)
		for end in [-1.0, 1.0]:
			for i in 7:
				m.box(Vector3(1.49, 1.03, 0.08), Vector3(-5.22 + i * 1.74, 11.55, 23.2 + end * 4.79), dark)
				m.box(Vector3(1.34, 0.87, 0.09), Vector3(-5.22 + i * 1.74, 11.55, 23.2 + end * 4.82), Color("345d70"))
			_ship_rail(m, Vector3(-6.7, 10.17, 23.2 + end * 5.25), Vector3(6.7, 10.17, 23.2 + end * 5.25), steel, 0.8)
		for side in [-1.0, 1.0]:
			for i in 4:
				m.box(Vector3(0.08, 1.03, 1.6), Vector3(side * 6.48, 11.55, 20.1 + i * 2.0), dark)
				m.box(Vector3(0.09, 0.87, 1.43), Vector3(side * 6.52, 11.55, 20.1 + i * 2.0), Color("345d70"))
			_ship_rail(m, Vector3(side * 6.7, 10.17, 17.95), Vector3(side * 6.7, 10.17, 28.45), steel, 0.8)
			# Rescue boat in its cradle, with supporting davits.
			var boat := Vector3(side * 6.2, 6.0, 23.2)
			m.ellipsoid(Vector3(0.8, 0.65, 2.25), boat, Color("dc702e"))
			m.ellipsoid(Vector3(0.63, 0.40, 1.3), boat + Vector3(0, 0.42, -0.2), Color("df8e45"))
			m.box(Vector3(1.25, 0.3, 0.9), boat + Vector3(0, 0.5, -0.65), Color("3c535e"))
			for z in [21.6, 24.8]:
				m.cylinder_between(Vector3(side * 5.2, 4.95, z), Vector3(side * 7.0, 5.55, z), 0.09, steel, 8)
				m.cylinder_between(Vector3(side * 5.2, 7.45, z), Vector3(side * 6.3, 7.45, z), 0.08, steel, 8)
				m.cylinder_between(Vector3(side * 6.3, 7.45, z), Vector3(side * 6.3, 6.3, z), 0.028, dark, 6)
		# Funnel, radar, navigation lights, mast and aerials.
		m.box(Vector3(2.5, 3.3, 2.6), Vector3(2.4, 14.0, 25.3), Color("b75a3c"))
		m.box(Vector3(2.6, 0.55, 2.7), Vector3(2.4, 15.65, 25.3), dark)
		m.box(Vector3(0.9, 0.25, 0.9), Vector3(-1.2, 12.65, 22.7), steel)
		m.cylinder_between(Vector3(-1.2, 12.65, 22.7), Vector3(-1.2, 18.5, 22.7), 0.085, steel, 8)
		for y in [15.0, 16.5, 17.5]: m.box(Vector3(3.2 - (y - 15) * 0.6, 0.07, 0.08), Vector3(-1.2, y, 22.7), steel)
		m.box(Vector3(1.5, 0.16, 0.3), Vector3(-1.2, 15.1, 22.7), Color("e7e9e3"))
		m.sphere(0.18, Vector3(-1.2, 18.55, 22.7), Color("e5e9df"), Vector3.ONE, 10, 6)
		for side in [-1.0, 1.0]:
			m.cylinder_between(Vector3(-1.2, 17.0, 22.7), Vector3(side * 4.5, 12.6, 26), 0.018, dark, 6)
			m.box(Vector3(0.45, 0.35, 0.5), Vector3(side * 6.3, 12.65, 20), Color("a94b42") if side < 0 else Color("4d9d73"))
		# Working bow: anchor windlass, mooring bitts and a short foremast.
		m.box(Vector3(1.1, 0.24, 1.05), Vector3(0, 2.62, -28.3), steel)
		m.cylinder(0.42, 0.55, Vector3(0, 3.0, -28.3), dark, 12)
		m.cylinder(0.55, 0.8, Vector3(0, 3.36, -28.3), steel, 12, Vector3(0, 0, PI / 2))
		for side in [-1.0, 1.0]:
			for z in [-27.5, 26.5]:
				var base := 2.43 if z < 0 else 2.21
				m.box(Vector3(1.3, 0.12, 0.8), Vector3(side * 4.3, base, z), dark)
				for x in [-0.35, 0.35]:
					m.cylinder(0.15, 0.65, Vector3(side * 4.3 + x, base + 0.33, z), dark, 10)
					m.cylinder(0.23, 0.08, Vector3(side * 4.3 + x, base + 0.67, z), steel, 10)
		m.cylinder_between(Vector3(0, 2.64, -32), Vector3(0, 7.0, -32), 0.065, steel, 8)
		m.box(Vector3(1.5, 0.07, 0.1), Vector3(0, 6.6, -32), steel)
		return m.build())


static func _ship_container(m: MeshKit, base: Vector3, paint: Color) -> void:
	m.box(Vector3(6.65, 3.4, 12.2), base + Vector3.UP * 1.7, paint)
	var trim := paint.darkened(0.22)
	for side in [-1.0, 1.0]:
		for rib in 15:
			m.box(Vector3(0.08, 2.95, 0.12), base + Vector3(side * 3.34, 1.7, -5.8 + rib * 0.83), paint.lightened(0.08))
		for y in [0.10, 3.30]: m.box(Vector3(0.12, 0.18, 12.2), base + Vector3(side * 3.30, y, 0), trim)
		for z in [-6.02, 6.02]: m.box(Vector3(0.15, 3.4, 0.18), base + Vector3(side * 3.26, 1.7, z), trim)
	for end in [-1.0, 1.0]:
		m.box(Vector3(0.045, 3.15, 0.06), base + Vector3(0, 1.7, end * 6.13), trim)
		for x in [-2.6, -0.7, 0.7, 2.6]:
			m.box(Vector3(0.055, 2.95, 0.08), base + Vector3(x, 1.7, end * 6.15), Color("aeb8bd"))
			m.box(Vector3(0.28, 0.06, 0.12), base + Vector3(x, 1.25, end * 6.17), Color("c6ccce"))
	m.box(Vector3(6.5, 0.055, 11.9), base + Vector3(0, 3.43, 0), Palette.SNOW)


static func _ship_rail(m: MeshKit, a: Vector3, b: Vector3, color: Color, height := 0.85) -> void:
	for y in [height * 0.50, height]: m.cylinder_between(a + Vector3.UP * y, b + Vector3.UP * y, 0.03, color, 6)
	var posts := ceili(a.distance_to(b) / 2.5)
	for i in posts + 1:
		var at := a.lerp(b, i / float(posts))
		m.cylinder_between(at, at + Vector3.UP * height, 0.04, color, 6)
