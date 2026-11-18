class_name RegionProps
extends RefCounted
## Models for the special regions: mall, rail yard, airport, lake and bandy
## rink. Same conventions as Props: origin at ground level, front facing -Z.


# --- Shopping mall ---

## Ten metres of mall ceiling, `span` metres wide (along X): a slab with a
## skylight down the middle and rows of ceiling lights.
static func mall_ceiling(span: int) -> ArrayMesh:
	return Props.cached_mesh("ceiling%d" % span, func() -> ArrayMesh:
		var kit := MeshKit.new()
		var slab := Color(0.93, 0.92, 0.9)
		var side := (span - 4.0) * 0.5
		for sx in [-1.0, 1.0]:
			kit.box(Vector3(side, 0.4, 10.05), Vector3(sx * (2.0 + side * 0.5), 8.6, 0), slab)
		kit.box(Vector3(4.0, 0.1, 10.05), Vector3(0, 8.75, 0), Color(0.75, 0.88, 1.0, 0.55))
		for sx in [-1.0, 1.0]:
			kit.box(Vector3(0.25, 0.5, 10.05), Vector3(sx * 2.0, 8.5, 0), Color(0.55, 0.58, 0.62))
			for k in 2:
				kit.box(Vector3(1.6, 0.06, 0.6), Vector3(sx * (2.0 + side * 0.5), 8.37, -2.5 + k * 5.0), Color(1.0, 0.97, 0.9, 0.0))
		kit.box(Vector3(span, 0.6, 0.4), Vector3(0, 8.1, 4.8), Color(0.85, 0.84, 0.82))
		return kit.build())


## Entrance wall across the mall, `span` wide inside, with a sign band.
static func mall_entrance(span: int) -> ArrayMesh:
	return Props.cached_mesh("entrance%d" % span, func() -> ArrayMesh:
		var kit := MeshKit.new()
		var wall := Color(0.82, 0.8, 0.78)
		for sx in [-1.0, 1.0]:
			kit.box(Vector3(30.0, 13.0, 1.2), Vector3(sx * (span * 0.5 + 15.0), 4.0, 0), wall)
			kit.box(Vector3(1.2, 13.0, 1.4), Vector3(sx * span * 0.5, 4.0, 0), Color(0.55, 0.15, 0.5))
		kit.box(Vector3(span, 4.5, 1.2), Vector3(0, 8.85, 0), wall)
		kit.box(Vector3(span * 0.8, 1.6, 0.2), Vector3(0, 8.4, -0.62), Color(0.55, 0.15, 0.5))
		kit.box(Vector3(span + 62.0, 0.4, 1.6), Vector3(0, 10.7, 0), Palette.SNOW)
		return kit.build())


## A wire shopping trolley: a tapered basket of bars on a chassis with
## castors, a red handle and something orange in it.
static func shopping_cart() -> ArrayMesh:
	return Props.cached_mesh("cart", func() -> ArrayMesh:
		var kit := MeshKit.new()
		var wire := Color(0.78, 0.8, 0.83)
		var red := Color(0.9, 0.1, 0.1)
		# Basket corners: wider at the back (+Z) where the handle is.
		var lo := [Vector3(-0.24, 0.55, -0.45), Vector3(0.24, 0.55, -0.45), Vector3(0.28, 0.55, 0.45), Vector3(-0.28, 0.55, 0.45)]
		var hi := [Vector3(-0.28, 1.0, -0.5), Vector3(0.28, 1.0, -0.5), Vector3(0.32, 1.0, 0.5), Vector3(-0.32, 1.0, 0.5)]
		for i in 4:
			var j := (i + 1) % 4
			kit.capsule_between(lo[i], lo[j], 0.012, wire, 4)
			kit.capsule_between(hi[i], hi[j], 0.015, wire, 4)
			kit.capsule_between(lo[i], hi[i], 0.012, wire, 4)
			for k in range(1, 6):
				var t := k / 6.0
				kit.capsule_between(lo[i].lerp(lo[j], t), hi[i].lerp(hi[j], t), 0.007, wire, 3)
			kit.capsule_between(lo[i].lerp(hi[i], 0.5), lo[j].lerp(hi[j], 0.5), 0.007, wire, 3)
		kit.box(Vector3(0.48, 0.02, 0.9), Vector3(0, 0.55, 0), Color(0.6, 0.62, 0.65))
		kit.capsule_between(Vector3(-0.33, 1.08, 0.58), Vector3(0.33, 1.08, 0.58), 0.025, red, 8)
		for side in [-1.0, 1.0]:
			kit.capsule_between(Vector3(0.3 * side, 1.0, 0.5), Vector3(0.32 * side, 1.08, 0.58), 0.015, wire, 4)
			kit.capsule_between(Vector3(0.22 * side, 0.1, -0.4), Vector3(0.26 * side, 0.55, 0.4), 0.018, wire, 4)
			kit.capsule_between(Vector3(0.24 * side, 0.1, 0.4), Vector3(0.26 * side, 0.55, 0.4), 0.018, wire, 4)
			kit.capsule_between(Vector3(0.22 * side, 0.1, -0.4), Vector3(0.24 * side, 0.1, 0.4), 0.018, wire, 4)
			for z in [-0.4, 0.4]:
				kit.cylinder(0.055, 0.04, Vector3(0.23 * side, 0.055, z), Color(0.1, 0.1, 0.1), 10, Vector3(0, 0, PI / 2))
		kit.box(Vector3(0.3, 0.25, 0.25), Vector3(0.05, 0.7, -0.1), Color(1.0, 0.6, 0.1), Vector3(0, 0.3, 0))
		kit.box(Vector3(0.2, 0.3, 0.12), Vector3(-0.1, 0.72, 0.2), Color(0.2, 0.5, 0.85))
		return kit.build())


## A ficus in a big planter: a twisting trunk and a crown of leaf clumps.
static func potted_plant() -> ArrayMesh:
	return Props.cached_mesh("plant", func() -> ArrayMesh:
		var kit := MeshKit.new()
		kit.lathe(PackedVector2Array([Vector2(0.32, 0.0), Vector2(0.4, 0.05), Vector2(0.47, 0.66), Vector2(0.5, 0.7), Vector2(0.44, 0.72)]), Transform3D.IDENTITY, Color(0.85, 0.84, 0.8), 14)
		kit.cylinder(0.43, 0.04, Vector3(0, 0.66, 0), Color(0.3, 0.22, 0.15), 14)
		kit.capsule_between(Vector3(0, 0.65, 0), Vector3(0.08, 1.4, 0.05), 0.06, Palette.TRUNK, 6)
		kit.capsule_between(Vector3(0.08, 1.4, 0.05), Vector3(-0.05, 1.9, 0), 0.05, Palette.TRUNK, 6)
		var rng := RandomNumberGenerator.new()
		rng.seed = 42
		for i in 11:
			var angle := i * 2.4
			var r := rng.randf_range(0.25, 0.6)
			var at := Vector3(cos(angle) * r, 2.0 + rng.randf_range(-0.4, 0.45), sin(angle) * r)
			var green := Color(0.2, 0.5, 0.25).lerp(Color(0.32, 0.6, 0.28), rng.randf()).darkened(0.15 * (1.0 - (at.y - 1.6)))
			kit.sphere(rng.randf_range(0.25, 0.38), at, green, Vector3(1, 0.8, 1), 8, 5)
		return kit.build())


## A stone fountain: a wide basin of water, a bowl on a column and a jet
## falling back in a bell of spray.
static func fountain() -> ArrayMesh:
	return Props.cached_mesh("fountain", func() -> ArrayMesh:
		var kit := MeshKit.new()
		var stone := Color(0.8, 0.8, 0.82)
		kit.lathe(PackedVector2Array([Vector2(2.1, 0.0), Vector2(2.25, 0.05), Vector2(2.25, 0.55), Vector2(2.35, 0.62), Vector2(2.0, 0.65), Vector2(1.95, 0.3)]), Transform3D.IDENTITY, stone, 24)
		kit.cylinder(1.97, 0.04, Vector3(0, 0.5, 0), Color(0.42, 0.62, 0.82), 24)
		kit.lathe(PackedVector2Array([Vector2(0.45, 0.5), Vector2(0.3, 0.7), Vector2(0.22, 1.6), Vector2(0.3, 1.75)]), Transform3D.IDENTITY, stone, 12)
		kit.lathe(PackedVector2Array([Vector2(0.2, 1.75), Vector2(0.6, 1.85), Vector2(0.95, 2.05), Vector2(0.98, 2.15), Vector2(0.85, 2.12)]), Transform3D.IDENTITY, stone, 16)
		kit.cylinder(0.86, 0.03, Vector3(0, 2.08, 0), Color(0.42, 0.62, 0.82), 16)
		# A jet straight up, and arcs of droplets falling from the bowl's rim.
		kit.cylinder(0.035, 0.8, Vector3(0, 2.45, 0), Color(0.8, 0.92, 1.0, 0.6), 6)
		kit.sphere(0.07, Vector3(0, 2.86, 0), Color(0.8, 0.92, 1.0, 0.6), Vector3.ONE, 8, 4)
		for arc in 8:
			var angle := TAU * arc / 8.0
			var out := Vector3(cos(angle), 0, sin(angle))
			for k in 5:
				var t := k / 4.0
				kit.sphere(0.035, out * (0.98 + t * 0.45) + Vector3.UP * (2.12 - t * t * 1.55), Color(0.8, 0.92, 1.0, 0.6), Vector3(1, 1.6, 1), 6, 3)
		return kit.build())


## A park bench: slats on cast-iron ends.
static func bench() -> ArrayMesh:
	return Props.cached_mesh("bench", func() -> ArrayMesh:
		var kit := MeshKit.new()
		var wood := Color(0.55, 0.38, 0.24)
		var iron := Color(0.15, 0.16, 0.17)
		for k in 4:
			kit.box(Vector3(1.8, 0.04, 0.09), Vector3(0, 0.45, -0.17 + k * 0.11), wood.darkened(0.05 * (k % 2)))
		for k in 3:
			kit.box(Vector3(1.8, 0.09, 0.04), Vector3(0, 0.62 + k * 0.13, 0.24 + k * 0.025), wood, Vector3(-0.2, 0, 0))
		for side in [-0.75, 0.75]:
			kit.capsule_between(Vector3(side, 0.0, -0.2), Vector3(side, 0.43, -0.18), 0.03, iron, 6)
			kit.capsule_between(Vector3(side, 0.0, 0.2), Vector3(side, 0.95, 0.3), 0.03, iron, 6)
			kit.capsule_between(Vector3(side, 0.43, -0.22), Vector3(side, 0.43, 0.24), 0.025, iron, 6)
			kit.capsule_between(Vector3(side, 0.43, -0.22), Vector3(side, 0.62, -0.25), 0.025, iron, 6)
			kit.capsule_between(Vector3(side, 0.62, -0.25), Vector3(side, 0.62, 0.1), 0.025, iron, 6)
		return kit.build())


# --- Rail yard ---

## Overhead-line mast with an arm reaching `reach` metres over the tracks.
static func catenary_mast(reach: int) -> ArrayMesh:
	return Props.cached_mesh("mast%d" % reach, func() -> ArrayMesh:
		var kit := MeshKit.new()
		var steel := Color(0.45, 0.48, 0.5)
		kit.box(Vector3(0.3, 7.5, 0.3), Vector3(0, 3.75, 0), steel)
		kit.box(Vector3(reach, 0.2, 0.2), Vector3(-reach * 0.5, 7.0, 0), steel)
		kit.box(Vector3(reach, 0.04, 0.04), Vector3(-reach * 0.5, 6.4, 0), Color(0.15, 0.15, 0.15))
		kit.box(Vector3(0.4, 0.1, 0.4), Vector3(0, 7.55, 0), Palette.SNOW)
		return kit.build())


## Wooden sleeper under a track, laid out by the thousand.
static func sleeper() -> ArrayMesh:
	return Props.cached_mesh("sleeper", func() -> ArrayMesh:
		return MeshKit.new().box(Vector3(2.4, 0.12, 0.25), Vector3.ZERO, Color(0.35, 0.27, 0.2)).build())


## Electric locomotive with its cab facing -Z: a flat nose that leans back
## a little, a raked windscreen, buffers and lamps, a pantograph on the roof.
## Rc-inspired twin-cab electric locomotive. Panels, equipment and running
## gear remain merged into one opaque mesh, as with the road vehicles.
static func locomotive() -> ArrayMesh:
	return Props.cached_mesh("loco", func() -> ArrayMesh:
		var kit := MeshKit.new()
		var paint := Color("b9362b")
		var dark := Color("293139")
		var metal := Color("9da8aa")
		var cream := Color("e9e2cf")
		var glass := Color("233e50")
		var profile := PackedVector2Array([Vector2(7.6, 0.9), Vector2(7.6, 2.5), Vector2(7.15, 3.7), Vector2(6.9, 3.88), Vector2(-6.9, 3.88), Vector2(-7.15, 3.7), Vector2(-7.6, 2.5), Vector2(-7.6, 0.9)])
		kit.slab(profile, 3.0, Transform3D(Basis(Vector3.UP, -PI / 2), Vector3.ZERO), paint)
		kit.box(Vector3(3.02, 0.42, 14.6), Vector3(0, 1.05, 0), dark)
		kit.box(Vector3(2.4, 0.45, 6.5), Vector3(0, 0.6, 0), dark)
		# Curved roof shoulders and narrow strips of settled snow.
		var roof: Array[PackedVector3Array] = []
		for z in [-6.95, 6.95]:
			roof.append(PackedVector3Array([Vector3(-1.5, 3.68, z), Vector3(-1.32, 3.97, z), Vector3(-0.95, 4.08, z), Vector3(0.95, 4.08, z), Vector3(1.32, 3.97, z), Vector3(1.5, 3.68, z)]))
		for i in 5: kit.quad(roof[0][i], roof[1][i], roof[1][i + 1], roof[0][i + 1], dark, Vector3.UP)
		for side in [-1.0, 1.0]:
			kit.box(Vector3(0.22, 0.045, 12.6), Vector3(side * 1.04, 4.085, 0), Palette.SNOW)
			kit.box(Vector3(0.045, 0.17, 14.8), Vector3(side * 1.51, 1.95, 0), cream)
			kit.box(Vector3(0.045, 0.10, 13.5), Vector3(side * 1.51, 3.66, 0), cream)
			# Corrugations and roof-level intake grilles.
			for row in 11:
				var y := 1.27 + row * 0.205
				if absf(y - 1.95) < 0.18: continue
				kit.box(Vector3(0.025, 0.023, 8.1), Vector3(side * 1.514, y, 0), paint.lightened(0.09))
			for z in [-3.1, -1.05, 1.05, 3.1]:
				kit.cylinder(0.31, 0.035, Vector3(side * 1.535, 2.83, z), dark, 16, Vector3(0, 0, PI / 2))
				kit.cylinder(0.255, 0.045, Vector3(side * 1.55, 2.83, z), glass, 16, Vector3(0, 0, PI / 2))
				kit.box(Vector3(0.045, 0.31, 1.55), Vector3(side * 1.52, 3.43, z), dark)
				for slat in 7:
					kit.box(Vector3(0.03, 0.23, 0.035), Vector3(side * 1.55, 3.43, z - 0.64 + slat * 0.21), metal.darkened(0.45))
			for end in [-1.0, 1.0]:
				# Cab side glass, access door, handle, steps and grab rails.
				kit.box(Vector3(0.04, 0.94, 1.32), Vector3(side * 1.52, 3.10, end * 5.95), cream)
				kit.box(Vector3(0.045, 0.80, 1.17), Vector3(side * 1.55, 3.10, end * 5.95), glass)
				kit.box(Vector3(0.04, 2.42, 0.88), Vector3(side * 1.525, 2.18, end * 4.75), dark)
				kit.box(Vector3(0.045, 2.32, 0.78), Vector3(side * 1.55, 2.18, end * 4.75), paint)
				kit.box(Vector3(0.05, 0.70, 0.53), Vector3(side * 1.58, 2.96, end * 4.75), glass)
				kit.box(Vector3(0.06, 0.06, 0.18), Vector3(side * 1.60, 2.15, end * 4.99), metal)
				for step in 3: kit.box(Vector3(0.30, 0.09, 0.72), Vector3(side * 1.50, 0.65 + step * 0.22, end * 4.75), metal.darkened(0.2))
				for z in [end * 4.19, end * 5.31]:
					kit.cylinder_between(Vector3(side * 1.62, 1.30, z), Vector3(side * 1.62, 2.55, z), 0.026, cream, 6)
					for y in [1.3, 2.55]: kit.cylinder_between(Vector3(side * 1.5, y, z), Vector3(side * 1.62, y, z), 0.026, cream, 6)
				# Visible springs and axle-box covers on each bogie.
				for axle in [-0.75, 0.75]:
					var z: float = end * 5.3 + axle
					kit.box(Vector3(0.18, 0.30, 0.40), Vector3(side * 1.05, 0.48, z), metal.darkened(0.4))
					for coil in 4: kit.cylinder(0.13, 0.045, Vector3(side * 1.04, 0.72 + coil * 0.065, z), dark.lightened(0.16), 8)
		for end in [-1.0, 1.0]:
			_loco_cab(kit, end, paint, cream, metal, glass, dark)
			# Two jointed diamond pantographs with insulators, not a loose pole.
			var z: float = end * 3.55
			kit.box(Vector3(1.25, 0.12, 1.8), Vector3(0, 4.17, z), dark)
			for x in [-0.46, 0.46]:
				for offset in [-0.62, 0.62]:
					kit.cylinder(0.10, 0.25, Vector3(x, 4.35, z + offset), Color("796050"), 10)
					var foot := Vector3(x, 4.48, z + offset)
					var elbow := Vector3(x, 5.02, z + signf(offset) * 0.91)
					var top := Vector3(x, 5.65, z)
					kit.cylinder_between(foot, elbow, 0.033, metal, 6)
					kit.cylinder_between(elbow, top, 0.028, metal, 6)
					kit.sphere(0.06, elbow, dark, Vector3.ONE, 8, 4)
			kit.box(Vector3(1.8, 0.06, 0.18), Vector3(0, 5.65, z), dark)
			kit.box(Vector3(1.2, 0.05, 0.16), Vector3(0, 4.48, z), metal)
		for z in [-1.4, 0, 1.4]:
			kit.cylinder(0.12, 0.3, Vector3(0, 4.25, z), Color("795844"), 10)
		kit.cylinder_between(Vector3(0, 4.42, -3.55), Vector3(0, 4.42, 3.55), 0.025, Color("a26746"), 6)
		_bogies(kit, 15)
		return kit.build())


static func _loco_cab(kit: MeshKit, end: float, paint: Color, cream: Color, metal: Color, glass: Color, dark: Color) -> void:
	var nose := func(x: float, y: float, offset := 0.0) -> Vector3:
		return Vector3(x, y, end * (7.6 - maxf(y - 2.5, 0) * 0.375 + offset))
	for side in [-1.0, 1.0]:
		var left := 0.055 if side > 0 else -1.30
		var right := 1.30 if side > 0 else -0.055
		kit.quad(nose.call(left, 2.65, 0.012), nose.call(right, 2.65, 0.012), nose.call(right, 3.58, 0.012), nose.call(left, 3.58, 0.012), dark, Vector3.BACK * end)
		kit.quad(nose.call(left + 0.055, 2.71, 0.022), nose.call(right - 0.055, 2.71, 0.022), nose.call(right - 0.055, 3.52, 0.022), nose.call(left + 0.055, 3.52, 0.022), glass, Vector3.BACK * end)
		kit.cylinder_between(nose.call(side * 0.34, 2.71, 0.035), nose.call(side * 0.82, 3.05, 0.035), 0.017, dark, 6)
		kit.cylinder(0.20, 0.10, Vector3(side * 1.05, 1.65, end * 7.63), metal, 14, Vector3(PI / 2, 0, 0))
		kit.cylinder(0.15, 0.11, Vector3(side * 1.05, 1.65, end * 7.65), Palette.HEADLIGHT, 14, Vector3(PI / 2, 0, 0))
		kit.cylinder(0.14, 0.33, Vector3(side * 0.95, 0.68, end * 7.70), metal.darkened(0.3), 12, Vector3(PI / 2, 0, 0))
		kit.cylinder(0.25, 0.09, Vector3(side * 0.95, 0.68, end * 7.89), dark, 14, Vector3(PI / 2, 0, 0))
		kit.cylinder_between(Vector3(side * 1.28, 2.25, end * 7.64), Vector3(side * 0.12, 1.99, end * 7.64), 0.055, cream, 6)
		kit.box(Vector3(0.16, 0.08, 0.19), Vector3(side * 0.48, 3.93, end * 6.94), paint)
		kit.cylinder(0.09, 0.12, Vector3(side * 0.48, 4.02, end * 6.94), Palette.HEADLIGHT, 12, Vector3(PI / 2, 0, 0))
	kit.box(Vector3(2.7, 0.17, 0.16), Vector3(0, 1.02, end * 7.64), cream)
	kit.box(Vector3(3.05, 0.20, 0.35), Vector3(0, 0.82, end * 7.45), dark)
	kit.box(Vector3(0.25, 0.25, 0.62), Vector3(0, 0.68, end * 7.85), metal.darkened(0.4))
	kit.cylinder_between(Vector3(0.25, 1.16, end * 7.64), Vector3(0.32, 0.55, end * 7.84), 0.045, dark, 8)


## A passenger coach: a rounded roof, a band of lit windows, doors at
## each end, bellows between the cars and gear slung underneath.
static func wagon(variant: int) -> ArrayMesh:
	return Props.cached_mesh("wagon%d" % variant, func() -> ArrayMesh:
		var kit := MeshKit.new()
		var paint: Color = [Color(0.2, 0.3, 0.55), Color(0.75, 0.12, 0.12), Color(0.6, 0.62, 0.65)][variant % 3]
		var dark := Color(0.12, 0.12, 0.13)
		kit.box(Vector3(3.0, 2.7, 14.0), Vector3(0, 2.05, 0), paint)
		var roof := CylinderMesh.new()
		roof.top_radius = 1.0
		roof.bottom_radius = 1.0
		roof.height = 14.0
		roof.radial_segments = 16
		roof.rings = 0
		kit.add(roof, Transform3D(Basis.from_euler(Vector3(PI / 2, 0, 0)) * Basis.from_scale(Vector3(1.5, 1.0, 0.35)), Vector3(0, 3.4, 0)), Color(0.55, 0.57, 0.6))
		kit.box(Vector3(3.04, 0.18, 14.0), Vector3(0, 1.45, 0), Color(0.95, 0.95, 0.95))
		for side in [-1.0, 1.0]:
			var x: float = 1.52 * side
			for w in 7:
				var z := -4.5 + w * 1.5
				kit.box(Vector3(0.06, 0.95, 1.2), Vector3(x, 2.55, z), Color(0.85, 0.86, 0.88))
				kit.box(Vector3(0.08, 0.8, 1.05), Vector3(x, 2.55, z), Color(1.0, 0.88, 0.6, 0.0))
			for end in [-1.0, 1.0]:
				var z: float = end * 6.2
				kit.box(Vector3(0.06, 2.1, 0.95), Vector3(x, 1.95, z), Color(0.85, 0.86, 0.88))
				kit.box(Vector3(0.08, 0.6, 0.35), Vector3(x, 2.55, z - 0.22), Color(1.0, 0.88, 0.6, 0.0))
				kit.box(Vector3(0.08, 0.6, 0.35), Vector3(x, 2.55, z + 0.22), Color(1.0, 0.88, 0.6, 0.0))
		for end in [-1.0, 1.0]:
			kit.box(Vector3(1.6, 2.3, 0.3), Vector3(0, 2.0, end * 7.12), Color(0.25, 0.25, 0.27))
			for k in 5:
				kit.box(Vector3(1.66, 0.06, 0.32), Vector3(0, 1.0 + k * 0.48, end * 7.12), Color(0.15, 0.15, 0.16))
		kit.box(Vector3(2.4, 0.5, 6.0), Vector3(0, 0.55, 0), dark)
		kit.box(Vector3(3.1, 0.25, 14.2), Vector3(0, 3.78, 0), Palette.SNOW)
		_bogies(kit, 14.0)
		return kit.build())


static func _bogies(kit: MeshKit, length: float) -> void:
	var dark := Color(0.12, 0.12, 0.13)
	for end in [-1.0, 1.0]:
		var z: float = end * (length * 0.5 - 2.2)
		kit.box(Vector3(2.2, 0.35, 2.8), Vector3(0, 0.6, z), dark)
		for side in [-1.0, 1.0]:
			kit.box(Vector3(0.12, 0.45, 2.6), Vector3(0.95 * side, 0.45, z), Color(0.18, 0.18, 0.2))
			kit.cylinder(0.14, 0.4, Vector3(1.0 * side, 0.85, z), Color(0.7, 0.2, 0.1), 8)
			for axle in [-0.75, 0.75]:
				kit.cylinder(0.42, 0.12, Vector3(0.75 * side, 0.42, z + axle), Color(0.08, 0.08, 0.08), 14, Vector3(0, 0, PI / 2))
				kit.cylinder(0.2, 0.16, Vector3(0.78 * side, 0.42, z + axle), Color(0.45, 0.45, 0.48), 8, Vector3(0, 0, PI / 2))


## Yellow board with a black arrow pointing straight on, facing +Z.
static func arrow_board() -> ArrayMesh:
	return Props.cached_mesh("arrow", func() -> ArrayMesh:
		var kit := MeshKit.new()
		for side in [-1.0, 1.0]:
			kit.cylinder(0.07, 2.6, Vector3(side * 0.8, 1.3, 0), Color(0.5, 0.52, 0.55), 6)
		kit.box(Vector3(2.0, 2.0, 0.08), Vector3(0, 2.6, 0), Color(1.0, 0.82, 0.05))
		kit.box(Vector3(0.36, 1.0, 0.1), Vector3(0, 2.35, 0.03), Color(0.05, 0.05, 0.05))
		kit.prism(Vector3(1.1, 0.7, 0.1), Vector3(0, 3.15, 0.03), Color(0.05, 0.05, 0.05))
		kit.box(Vector3(2.1, 0.12, 0.25), Vector3(0, 3.65, 0), Palette.SNOW)
		return kit.build())


# --- Motorway ---

## Articulated lorry, nose towards -Z.
static func truck(variant: int) -> ArrayMesh:
	return Props.cached_mesh("truck%d" % variant, func() -> ArrayMesh:
		var kit := MeshKit.new()
		var cab: Color = [Color(0.85, 0.15, 0.12), Color(0.15, 0.3, 0.65), Color(0.95, 0.95, 0.95)][variant % 3]
		var trailer: Color = [Color(0.92, 0.92, 0.9), Color(0.8, 0.6, 0.15), Color(0.3, 0.45, 0.35)][variant % 3]
		var glass := Color(0.16, 0.22, 0.3)
		var dark := Color(0.12, 0.12, 0.13)
		var lengthwise := Basis(Vector3.UP, -PI / 2.0)
		# Cab-over tractor: a tall cab with a raked windscreen and a wind
		# deflector on the roof.
		kit.slab(PackedVector2Array([Vector2(-5.4, 0.9), Vector2(-5.4, 3.5), Vector2(-6.0, 3.65), Vector2(-7.45, 3.6), Vector2(-7.8, 2.9), Vector2(-7.85, 0.9)]), 2.5, Transform3D(lengthwise, Vector3.ZERO), cab)
		kit.slab(PackedVector2Array([Vector2(-6.2, 2.15), Vector2(-6.2, 3.3), Vector2(-7.5, 3.3), Vector2(-7.83, 2.75), Vector2(-7.82, 2.15)]), 2.54, Transform3D(lengthwise, Vector3.ZERO), glass)
		kit.slab(PackedVector2Array([Vector2(-5.4, 3.5), Vector2(-5.5, 4.3), Vector2(-5.9, 4.3), Vector2(-6.9, 3.6)]), 2.4, Transform3D(lengthwise, Vector3.ZERO), cab)
		kit.box(Vector3(2.3, 0.15, 0.6), Vector3(0, 3.55, -7.75), cab.darkened(0.2), Vector3(0.3, 0, 0))
		kit.box(Vector3(1.8, 0.9, 0.05), Vector3(0, 1.65, -7.88), Color(0.18, 0.18, 0.2))
		for k in 5:
			kit.box(Vector3(1.75, 0.04, 0.07), Vector3(0, 1.3 + k * 0.18, -7.9), Color(0.5, 0.52, 0.55))
		kit.box(Vector3(2.55, 0.4, 0.3), Vector3(0, 0.95, -7.85), dark)
		for side in [-1.0, 1.0]:
			kit.box(Vector3(0.4, 0.25, 0.08), Vector3(0.95 * side, 1.0, -8.0), Palette.HEADLIGHT)
			kit.box(Vector3(0.05, 0.55, 0.3), Vector3(1.45 * side, 2.7, -7.3), dark)
			kit.capsule_between(Vector3(1.25 * side, 3.0, -7.2), Vector3(1.45 * side, 3.0, -7.3), 0.03, dark, 5)
			kit.box(Vector3(0.05, 1.0, 0.8), Vector3(1.26 * side, 1.5, -6.2), cab.darkened(0.15))
			kit.box(Vector3(0.3, 0.12, 0.6), Vector3(1.2 * side, 0.8, -5.9), Color(0.7, 0.72, 0.75))
			kit.box(Vector3(0.18, 0.12, 0.05), Vector3(0.9 * side, 3.62, -7.5), Color(1.0, 0.55, 0.0, 0.0))
		kit.cylinder(0.3, 1.0, Vector3(-0.95, 1.0, -4.7), Color(0.7, 0.72, 0.75), 12, Vector3(PI / 2, 0, 0))
		# Box trailer with ribs, an underrun guard and rear doors.
		kit.box(Vector3(2.6, 3.0, 12.0), Vector3(0, 2.6, 0.8), trailer)
		for k in 13:
			for side in [-1.0, 1.0]:
				kit.box(Vector3(0.04, 3.0, 0.08), Vector3(1.31 * side, 2.6, -5.2 + k * 1.0), trailer.darkened(0.12))
		for side in [-1.0, 1.0]:
			kit.box(Vector3(0.05, 0.1, 6.0), Vector3(1.2 * side, 0.85, 0.5), Color(0.6, 0.6, 0.62))
			kit.box(Vector3(0.05, 0.12, 12.0), Vector3(1.32 * side, 1.2, 0.8), Color(1.0, 0.75, 0.1))
		kit.box(Vector3(0.04, 2.9, 0.05), Vector3(0, 2.6, 6.83), trailer.darkened(0.3))
		kit.box(Vector3(2.5, 0.15, 0.1), Vector3(0, 0.75, 6.9), dark)
		for side in [-1.0, 1.0]:
			kit.box(Vector3(0.3, 0.15, 0.05), Vector3(1.0 * side, 1.0, 6.82), Palette.TAILLIGHT)
		kit.box(Vector3(2.7, 0.2, 12.1), Vector3(0, 4.2, 0.8), Palette.SNOW)
		kit.box(Vector3(2.4, 0.4, 14.5), Vector3(0, 0.75, -0.6), dark)
		for z in [-6.4, -2.0, -0.9, 4.5, 5.9]:
			for side in [-1.0, 1.0]:
				Props.wheel(kit, Vector3(1.05 * side, 0.5, z), 0.5, 0.36, Color(0.75, 0.75, 0.72))
		return kit.build())


# --- Airport ---

## Airliner, nose towards -Z, wheels on the ground: a turned fuselage that
## tapers up into the tail, swept wings and fin, engines under the wings.
static func plane(variant: int) -> ArrayMesh:
	return Props.cached_mesh("plane%d" % variant, func() -> ArrayMesh:
		var kit := MeshKit.new()
		var white := Color(0.95, 0.96, 0.97)
		var livery: Color = [Color(0.1, 0.3, 0.7), Color(0.85, 0.15, 0.15), Color(0.95, 0.7, 0.1)][variant % 3]
		var grey := Color(0.72, 0.74, 0.78)
		# Fuselage along -Z: turn the lathe so its axis (local Y) points forward.
		var body := PackedVector2Array([
			Vector2(0.0, -16.0), Vector2(0.9, -15.6), Vector2(1.5, -14.6), Vector2(1.85, -12.5),
			Vector2(1.95, -9.0), Vector2(1.95, 8.0), Vector2(1.7, 11.5), Vector2(1.1, 14.5), Vector2(0.35, 16.5), Vector2(0.0, 16.8),
		])
		var along := Basis(Vector3.RIGHT, PI / 2.0)
		kit.lathe(body, Transform3D(along, Vector3(0, 3.2, 0)), white, 18)
		for side in [-1.0, 1.0]:
			kit.box(Vector3(0.1, 0.45, 20.0), Vector3(1.9 * side, 3.65, -1.0), Color(0.2, 0.25, 0.35))
			kit.box(Vector3(0.1, 0.25, 24.0), Vector3(1.88 * side, 3.05, -0.5), livery)
		kit.ellipsoid(Vector3(1.2, 0.42, 0.9), Vector3(0, 4.05, -13.8), Color(0.15, 0.2, 0.3), Vector3(0.45, 0, 0))
		# Swept wings (plan view in X/Z, extruded thin in Y).
		var wing := PackedVector2Array([Vector2(1.5, -3.5), Vector2(15.0, 2.5), Vector2(15.0, 4.0), Vector2(1.5, 2.0)])
		var flat := Basis(Vector3.RIGHT, PI / 2.0)
		for side in [-1.0, 1.0]:
			kit.slab(_mirrored(wing, side), 0.35, Transform3D(flat, Vector3(0, 2.4, 0)), white)
			kit.cylinder(0.85, 3.2, Vector3(6.3 * side, 1.6, -2.0), grey, 14, Vector3(PI / 2, 0, 0))
			kit.cylinder(0.65, 0.1, Vector3(6.3 * side, 1.6, -3.62), Color(0.1, 0.1, 0.1), 14, Vector3(PI / 2, 0, 0))
			kit.box(Vector3(0.25, 0.9, 1.2), Vector3(6.3 * side, 2.2, -1.3), grey)
			var stabiliser := PackedVector2Array([Vector2(0.5, 12.5), Vector2(6.0, 15.5), Vector2(6.0, 16.6), Vector2(0.5, 15.6)])
			kit.slab(_mirrored(stabiliser, side), 0.25, Transform3D(flat, Vector3(0, 4.1, 0)), white)
			kit.box(Vector3(0.3, 1.4, 0.3), Vector3(2.1 * side, 0.7, 1.5), Color(0.2, 0.2, 0.22))
			kit.cylinder(0.5, 0.55, Vector3(2.1 * side, 0.5, 1.5), Color(0.08, 0.08, 0.08), 14, Vector3(0, 0, PI / 2))
		# Swept fin, side view in Z/Y.
		var fin := PackedVector2Array([Vector2(10.5, 0.0), Vector2(16.5, 0.0), Vector2(17.5, 6.5), Vector2(15.0, 6.5)])
		kit.slab(fin, 0.35, Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(0, 4.6, 0)), livery)
		kit.box(Vector3(0.3, 1.5, 0.3), Vector3(0, 0.75, -11.5), Color(0.2, 0.2, 0.22))
		kit.cylinder(0.38, 0.45, Vector3(0, 0.4, -11.5), Color(0.08, 0.08, 0.08), 12, Vector3(0, 0, PI / 2))
		kit.box(Vector3(1.6, 0.15, 22.0), Vector3(0, 5.16, -1.0), Palette.SNOW)
		return kit.build())


## The polygon as is (side +1) or mirrored across X with its winding kept.
static func _mirrored(polygon: PackedVector2Array, side: float) -> PackedVector2Array:
	if side > 0.0:
		return polygon
	var flipped := PackedVector2Array()
	for i in range(polygon.size() - 1, -1, -1):
		flipped.append(Vector2(-polygon[i].x, polygon[i].y))
	return flipped


## Baggage tractor pulling two carts, nose towards -Z.
## Baggage tractor pulling two carts of suitcases, nose towards -Z.
static func tug() -> ArrayMesh:
	return Props.cached_mesh("tug", func() -> ArrayMesh:
		var kit := MeshKit.new()
		var yellow := Color(1.0, 0.75, 0.05)
		var dark := Color(0.15, 0.15, 0.16)
		kit.box(Vector3(1.6, 0.8, 2.4), Vector3(0, 0.7, -2.4), yellow)
		kit.box(Vector3(1.5, 0.3, 0.9), Vector3(0, 1.15, -3.1), yellow.darkened(0.1), Vector3(0.2, 0, 0))
		# Open cab: a roof on four posts, a seat and a wheel.
		for x in [-0.7, 0.7]:
			for z in [-2.6, -1.4]:
				kit.box(Vector3(0.06, 1.0, 0.06), Vector3(x, 1.6, z), dark)
		kit.box(Vector3(1.6, 0.08, 1.4), Vector3(0, 2.12, -2.0), yellow)
		kit.box(Vector3(0.6, 0.12, 0.5), Vector3(0, 1.2, -1.8), dark)
		kit.box(Vector3(0.6, 0.5, 0.1), Vector3(0, 1.45, -1.55), dark)
		kit.torus(0.13, 0.17, Transform3D(Basis(Vector3.RIGHT, 0.9), Vector3(0, 1.5, -2.45)), dark, 14, 5)
		kit.cylinder(0.12, 0.2, Vector3(0, 2.25, -2.0), Color(1.0, 0.5, 0.0, 0.0), 8)
		for side in [-1.0, 1.0]:
			kit.box(Vector3(0.25, 0.15, 0.05), Vector3(0.55 * side, 0.85, -3.62), Palette.HEADLIGHT)
		kit.box(Vector3(0.1, 0.1, 0.8), Vector3(0, 0.45, -0.85), dark)
		var luggage := [Color(0.2, 0.3, 0.7), Color(0.75, 0.2, 0.2), Color(0.15, 0.15, 0.17), Color(0.35, 0.55, 0.3), Color(0.85, 0.65, 0.2)]
		for cart in 2:
			var z := 0.2 + cart * 2.6
			kit.box(Vector3(1.6, 0.15, 2.2), Vector3(0, 0.6, z), Color(0.35, 0.36, 0.38))
			for x in [-0.78, 0.78]:
				kit.box(Vector3(0.05, 1.2, 2.2), Vector3(x, 1.25, z), Color(0.5, 0.52, 0.55, 1.0))
			kit.box(Vector3(1.6, 0.06, 2.2), Vector3(0, 1.85, z), Color(0.3, 0.45, 0.65))
			for bag in 4:
				var color: Color = luggage[(bag + cart * 2) % luggage.size()]
				kit.box(Vector3(0.5, 0.65, 0.3), Vector3(-0.35 + (bag % 2) * 0.7, 1.0, z - 0.5 + (bag / 2) * 0.9), color, Vector3(0, 0.1 * bag, 0))
				kit.box(Vector3(0.14, 0.04, 0.04), Vector3(-0.35 + (bag % 2) * 0.7, 1.35, z - 0.5 + (bag / 2) * 0.9), Color(0.1, 0.1, 0.1))
			kit.box(Vector3(1.62, 0.08, 2.22), Vector3(0, 1.91, z), Palette.SNOW)
		for z in [-3.2, -1.6, -0.4, 0.8, 2.2, 3.4]:
			for side in [-1.0, 1.0]:
				Props.wheel(kit, Vector3(0.75 * side, 0.3, z), 0.3, 0.2, Color(0.75, 0.75, 0.72))
		return kit.build())


## A traffic cone on a square base, with two reflective white bands.
static func cone() -> ArrayMesh:
	return Props.cached_mesh("cone", func() -> ArrayMesh:
		var kit := MeshKit.new()
		var orange := Color(1.0, 0.38, 0.05)
		kit.box(Vector3(0.46, 0.04, 0.46), Vector3(0, 0.02, 0), Color(0.12, 0.12, 0.13))
		kit.lathe(PackedVector2Array([Vector2(0.2, 0.04), Vector2(0.17, 0.25), Vector2(0.06, 0.73), Vector2(0.04, 0.76), Vector2(0.0, 0.77)]), Transform3D.IDENTITY, orange, 14)
		kit.lathe(PackedVector2Array([Vector2(0.162, 0.3), Vector2(0.135, 0.42)]), Transform3D(Basis.from_scale(Vector3(1.04, 1, 1.04)), Vector3.ZERO), Color(0.95, 0.95, 0.95), 14)
		kit.lathe(PackedVector2Array([Vector2(0.112, 0.5), Vector2(0.09, 0.6)]), Transform3D(Basis.from_scale(Vector3(1.06, 1, 1.06)), Vector3.ZERO), Color(0.95, 0.95, 0.95), 14)
		return kit.build())


static func control_tower() -> ArrayMesh:
	return Props.cached_mesh("tower", func() -> ArrayMesh:
		var kit := MeshKit.new()
		kit.cylinder(4.0, 4.0, Vector3(0, 2.0, 0), Color(0.8, 0.8, 0.82), 16)
		kit.box(Vector3(0.5, 2.2, 0.1), Vector3(0, 1.1, -4.0), Color(0.3, 0.3, 0.35))
		kit.cylinder(1.6, 22.0, Vector3(0, 11.0, 0), Color(0.88, 0.88, 0.9), 16, Vector3.ZERO, 1.2)
		for i in 5:
			kit.box(Vector3(0.6, 0.9, 0.1), Vector3(0, 5.0 + i * 3.5, -1.45), Color(0.3, 0.45, 0.6, 0.6))
		kit.cylinder(3.4, 3.0, Vector3(0, 23.5, 0), Color(0.3, 0.45, 0.6, 0.4), 12, Vector3.ZERO, 3.8)
		kit.cylinder(3.9, 0.5, Vector3(0, 25.2, 0), Color(0.85, 0.86, 0.88), 12)
		kit.cylinder(3.9, 0.3, Vector3(0, 25.55, 0), Palette.SNOW, 12)
		kit.cylinder(0.1, 3.0, Vector3(0, 27.0, 0), Color(0.3, 0.3, 0.3), 6)
		kit.sphere(0.25, Vector3(0, 28.6, 0), Color(1.0, 0.1, 0.1, 0.0))
		return kit.build())


static func terminal() -> ArrayMesh:
	return Props.cached_mesh("terminal", func() -> ArrayMesh:
		var kit := MeshKit.new()
		kit.box(Vector3(60.0, 9.0, 16.0), Vector3(0, 2.5, 0), Color(0.85, 0.86, 0.88))
		kit.box(Vector3(58.0, 4.0, 0.2), Vector3(0, 3.5, -8.05), Color(0.55, 0.75, 0.9, 0.5))
		for i in 12:
			kit.box(Vector3(0.25, 4.2, 0.3), Vector3(-27.5 + i * 5.0, 3.5, -8.1), Color(0.5, 0.52, 0.55))
		kit.box(Vector3(61.0, 0.5, 17.0), Vector3(0, 7.25, 0), Palette.SNOW)
		return kit.build())


static func edge_light(color: Color) -> ArrayMesh:
	return Props.cached_mesh("edgelight%s" % color.to_html(), func() -> ArrayMesh:
		var kit := MeshKit.new()
		kit.cylinder(0.05, 0.4, Vector3(0, 0.2, 0), Color(0.3, 0.3, 0.3), 6)
		kit.sphere(0.12, Vector3(0, 0.45, 0), Color(color.r, color.g, color.b, 0.0))
		return kit.build())


## An airfield windsock: a mast with a hoop holding a striped sock that
## tapers and droops in the wind.
static func windsock() -> ArrayMesh:
	return Props.cached_mesh("windsock", func() -> ArrayMesh:
		var kit := MeshKit.new()
		kit.cylinder(0.08, 5.0, Vector3(0, 2.5, 0), Color(0.8, 0.8, 0.8), 8, Vector3.ZERO, 0.05)
		kit.capsule_between(Vector3(0, 4.7, 0), Vector3(0.25, 4.7, 0), 0.03, Color(0.4, 0.4, 0.42), 5)
		kit.torus(0.33, 0.37, Transform3D(Basis(Vector3.FORWARD, PI / 2.0 + 0.1), Vector3(0.28, 4.7, 0)), Color(0.4, 0.4, 0.42), 16, 4)
		for i in 5:
			var color := Color(1.0, 0.4, 0.05) if i % 2 == 0 else Color(1, 1, 1)
			var r := 0.34 - i * 0.045
			kit.cylinder(r, 0.5, Vector3(0.55 + i * 0.5, 4.68 - i * i * 0.025, 0), color, 12, Vector3(0, 0, PI / 2 + 0.06 + i * 0.03), r - 0.045)
		return kit.build())


# --- Lake ---

## A wooden jetty reaching 8 m out along -Z.
static func jetty() -> ArrayMesh:
	return Props.cached_mesh("jetty", func() -> ArrayMesh:
		var kit := MeshKit.new()
		var wood := Color(0.55, 0.4, 0.26)
		kit.box(Vector3(2.2, 0.15, 8.0), Vector3(0, 0.6, -4.0), wood)
		kit.box(Vector3(2.3, 0.08, 8.0), Vector3(0, 0.71, -4.0), Palette.SNOW)
		for z in [-0.5, -4.0, -7.5]:
			for side in [-1.0, 1.0]:
				kit.cylinder(0.1, 1.6, Vector3(0.95 * side, 0.0, z), Palette.TRUNK, 6)
		kit.box(Vector3(0.08, 1.2, 0.08), Vector3(0.6, 1.3, -7.6), Color(0.7, 0.7, 0.72))
		kit.box(Vector3(0.6, 0.06, 0.06), Vector3(0.3, 1.9, -7.6), Color(0.7, 0.7, 0.72))
		return kit.build())


static func ice_floe(variant: int) -> ArrayMesh:
	return Props.cached_mesh("floe%d" % variant, func() -> ArrayMesh:
		var kit := MeshKit.new()
		kit.cylinder(1.6 + variant * 0.6, 0.25, Vector3(0, 0.05, 0), Color(0.88, 0.94, 1.0), 6 + variant)
		return kit.build())


# --- Bandy rink ---

## A bandy goal: red posts and crossbar, a net stretched back to a frame
## on the ice, its mesh drawn as a grid of cords.
static func bandy_goal() -> ArrayMesh:
	return Props.cached_mesh("goal", func() -> ArrayMesh:
		var kit := MeshKit.new()
		var post := Color(0.85, 0.1, 0.1)
		var net := Color(0.95, 0.95, 0.95)
		for side in [-1.0, 1.0]:
			kit.cylinder(0.06, 2.1, Vector3(1.75 * side, 1.05, 0), post, 8)
			kit.capsule_between(Vector3(1.75 * side, 0.03, 0), Vector3(1.75 * side, 0.03, 1.2), 0.03, Color(0.9, 0.9, 0.9), 5)
			kit.capsule_between(Vector3(1.75 * side, 2.08, 0), Vector3(1.75 * side, 0.6, 1.2), 0.02, Color(0.9, 0.9, 0.9), 5)
		kit.cylinder(0.06, 3.6, Vector3(0, 2.1, 0), post, 8, Vector3(0, 0, PI / 2))
		kit.capsule_between(Vector3(-1.75, 0.03, 1.2), Vector3(1.75, 0.03, 1.2), 0.03, Color(0.9, 0.9, 0.9), 5)
		# Back of the net: from the crossbar sloping down to the ground frame.
		for k in 15:
			var x := -1.75 + k * 0.25
			kit.capsule_between(Vector3(x, 2.08, 0), Vector3(x, 0.6, 1.2), 0.008, net, 3)
			kit.capsule_between(Vector3(x, 0.6, 1.2), Vector3(x, 0.03, 1.2), 0.008, net, 3)
		for k in 9:
			var t := k / 8.0
			var y := lerpf(2.08, 0.6, t)
			var z := lerpf(0.0, 1.2, t)
			kit.capsule_between(Vector3(-1.75, y, z), Vector3(1.75, y, z), 0.008, net, 3)
		for k in 3:
			var y := 0.15 + k * 0.17
			kit.capsule_between(Vector3(-1.75, y, 1.2), Vector3(1.75, y, 1.2), 0.008, net, 3)
		return kit.build())


## A four-metre stretch of the low boards (sarg) around the rink, along Z.
static func boards() -> ArrayMesh:
	return Props.cached_mesh("boards", func() -> ArrayMesh:
		var kit := MeshKit.new()
		kit.box(Vector3(0.12, 0.45, 4.02), Vector3(0, 0.22, 0), Color(0.15, 0.3, 0.7))
		kit.box(Vector3(0.14, 0.06, 4.02), Vector3(0, 0.47, 0), Color(1, 1, 1))
		return kit.build())


## A floodlight mast: a lattice tower with a rack of lamps at the top.
static func floodlight() -> ArrayMesh:
	return Props.cached_mesh("flood", func() -> ArrayMesh:
		var kit := MeshKit.new()
		var steel := Color(0.6, 0.62, 0.65)
		var corners := [Vector3(-0.4, 0, -0.4), Vector3(0.4, 0, -0.4), Vector3(0.4, 0, 0.4), Vector3(-0.4, 0, 0.4)]
		for i in 4:
			var c: Vector3 = corners[i]
			kit.capsule_between(c, c * 0.35 + Vector3.UP * 15.5, 0.05, steel, 5)
		for k in 8:
			var y0 := k * 1.95
			var y1 := y0 + 1.95
			var s0 := lerpf(1.0, 0.35, y0 / 15.5)
			var s1 := lerpf(1.0, 0.35, y1 / 15.5)
			for i in 4:
				var a: Vector3 = corners[i]
				var b: Vector3 = corners[(i + 1) % 4]
				kit.capsule_between(a * s0 + Vector3.UP * y0, b * s1 + Vector3.UP * y1, 0.02, steel, 3)
		kit.box(Vector3(3.2, 0.1, 0.5), Vector3(0, 15.5, 0), steel)
		for row in 2:
			for col in 4:
				var at := Vector3(-1.2 + col * 0.8, 15.9 + row * 0.7, -0.05)
				kit.box(Vector3(0.7, 0.6, 0.35), at, Color(0.25, 0.25, 0.27), Vector3(0.3, 0, 0))
				kit.box(Vector3(0.6, 0.5, 0.05), at + Vector3(0, -0.06, -0.18), Color(1.0, 0.97, 0.85, 0.0), Vector3(0.3, 0, 0))
		kit.box(Vector3(3.3, 0.08, 0.45), Vector3(0, 17.0, 0.05), Palette.SNOW)
		return kit.build())


## Low stands of wooden benches on a concrete stepped base, along Z.
static func bleachers() -> ArrayMesh:
	return Props.cached_mesh("bleachers", func() -> ArrayMesh:
		var kit := MeshKit.new()
		for row in 4:
			kit.box(Vector3(1.0, 0.45 * (row + 1), 12.0), Vector3(row * 1.0, 0.225 * (row + 1), 0), Color(0.6, 0.6, 0.62))
			kit.box(Vector3(0.35, 0.06, 12.0), Vector3(row * 1.0 + 0.15, 0.45 * (row + 1) + 0.25, 0), Color(0.55, 0.38, 0.24))
			for z in [-5.5, -1.8, 1.8, 5.5]:
				kit.box(Vector3(0.06, 0.25, 0.06), Vector3(row * 1.0 + 0.15, 0.45 * (row + 1) + 0.12, z), Color(0.2, 0.2, 0.22))
			kit.box(Vector3(0.55, 0.06, 12.0), Vector3(row * 1.0 - 0.2, 0.45 * (row + 1) + 0.03, 0), Palette.SNOW)
			kit.box(Vector3(0.3, 0.05, 12.0), Vector3(row * 1.0 + 0.15, 0.45 * (row + 1) + 0.3, 0), Palette.SNOW)
		kit.box(Vector3(0.05, 1.0, 12.0), Vector3(3.5, 2.3, 0), Color(0.4, 0.42, 0.45))
		return kit.build())


static func _rng(value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = value * 7919
	return rng
