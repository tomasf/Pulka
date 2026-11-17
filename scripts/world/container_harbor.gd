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


static func ship() -> ArrayMesh:
	return Props.cached_mesh("container_ship", func() -> ArrayMesh:
		var m := MeshKit.new()
		var rings: Array[PackedVector3Array] = []
		for y in [-3.0, -0.8, 1.5, 2.0]:
			var ring := PackedVector3Array()
			var width := 5.5 if y < -1 else 7.5
			for p in [Vector2(-width, -27), Vector2(0, -35), Vector2(width, -27), Vector2(width, 29), Vector2(-width, 29)]:
				ring.append(Vector3(p.x, y, p.y))
			rings.append(ring)
		m.loft(rings, PackedFloat32Array([1, 1, 1, 1]), Transform3D.IDENTITY, Color("263b51"), true)
		m.box(Vector3(14, 0.4, 50), Vector3(0, 2.1, 0), Color("a45840"))
		for x in [-3.7, 3.7]:
			for z in [-18.0, -5.0, 8.0]:
				m.box(Vector3(6.8, 4.5, 12), Vector3(x, 4.5, z), COLORS[posmod(int(x + z), COLORS.size())])
				m.box(Vector3(6.8, 0.15, 12), Vector3(x, 6.8, z), Color("dae7eb"))
		m.box(Vector3(12, 8, 9), Vector3(0, 6, 23), Color("d9e3e8"))
		m.box(Vector3(13, 2.8, 10), Vector3(0, 11.2, 23), Color("ecf0e8"))
		m.box(Vector3(11.8, 1.3, 0.12), Vector3(0, 11.4, 17.94), Color("35536a"))
		m.box(Vector3(2.8, 5, 3), Vector3(2, 13.5, 25), Color("bf6943"))
		m.cylinder(0.1, 7, Vector3(-3, 15.5, 22), Color("c4d2d9"), 6)
		return m.build())
