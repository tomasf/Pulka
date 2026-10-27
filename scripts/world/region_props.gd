class_name RegionProps
extends RefCounted
## Models for the special regions: mall, rail yard, airport, lake and bandy
## rink. Same conventions as Props: origin at ground level, front facing -Z.


# --- Shopping mall ---

const MALL_SHOPS := [
	"Mössor & Vantar", "Glöggbaren", "Pulkadepån", "Skidbutiken", "Pepparkakshuset", "Tomteverkstan",
	"Ylle & Co", "Godisbutiken", "Kaffestugan", "Leksakslådan", "Sportlovet", "Vinterskor",
]


## A glass shop front, 10 m wide along local X, facing -Z.
static func shopfront(variant: int) -> ArrayMesh:
	return Props.cached_mesh("shop%d" % variant, func() -> ArrayMesh:
		var kit := MeshKit.new()
		var band: Color = Palette.JACKETS[variant % Palette.JACKETS.size()]
		var frame := Color(0.85, 0.86, 0.88)
		kit.box(Vector3(10.0, 11.0, 6.0), Vector3(0, 3.0, 3.0), Color(0.9, 0.88, 0.84))
		kit.box(Vector3(9.6, 3.2, 0.1), Vector3(0, 1.7, -0.02), Color(1.0, 0.9, 0.7, 0.0))
		for i in 5:
			kit.box(Vector3(0.12, 3.4, 0.16), Vector3(-4.8 + i * 2.4, 1.7, -0.05), frame)
		kit.box(Vector3(10.0, 0.14, 0.18), Vector3(0, 3.35, -0.05), frame)
		kit.box(Vector3(10.0, 1.0, 0.2), Vector3(0, 4.0, -0.08), band)
		kit.box(Vector3(10.0, 0.08, 0.3), Vector3(0, 0.04, -0.1), frame)
		for i in 3:
			kit.box(Vector3(0.6, 0.9, 0.5), Vector3(-3.0 + i * 3.0, 0.45, 0.6), Palette.pick(Palette.JACKETS, _rng(variant + i)))
		return kit.build())


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


static func shopping_cart() -> ArrayMesh:
	return Props.cached_mesh("cart", func() -> ArrayMesh:
		var kit := MeshKit.new()
		var wire := Color(0.75, 0.78, 0.8)
		kit.box(Vector3(0.6, 0.5, 0.9), Vector3(0, 0.75, 0), Color(0.75, 0.78, 0.8, 1.0))
		kit.box(Vector3(0.52, 0.42, 0.82), Vector3(0, 0.79, 0), Color(0.3, 0.32, 0.36))
		kit.cylinder(0.025, 0.62, Vector3(0, 1.1, 0.5), Color(0.9, 0.1, 0.1), 6, Vector3(0, 0, PI / 2))
		for sx in [-0.25, 0.25]:
			for sz in [-0.35, 0.35]:
				kit.cylinder(0.06, 0.04, Vector3(sx, 0.06, sz), Color(0.1, 0.1, 0.1), 8, Vector3(0, 0, PI / 2))
				kit.box(Vector3(0.03, 0.5, 0.03), Vector3(sx, 0.3, sz), wire)
		kit.box(Vector3(0.3, 0.25, 0.25), Vector3(0.1, 1.12, -0.1), Color(1.0, 0.6, 0.1))
		return kit.build())


static func potted_plant() -> ArrayMesh:
	return Props.cached_mesh("plant", func() -> ArrayMesh:
		var kit := MeshKit.new()
		kit.cylinder(0.45, 0.7, Vector3(0, 0.35, 0), Color(0.75, 0.4, 0.25), 12, Vector3.ZERO, 0.35)
		kit.cylinder(0.08, 1.2, Vector3(0, 1.2, 0), Palette.TRUNK, 6)
		kit.sphere(0.75, Vector3(0, 2.1, 0), Color(0.2, 0.5, 0.25), Vector3(1, 0.9, 1))
		kit.sphere(0.45, Vector3(0.4, 1.7, 0.2), Color(0.25, 0.55, 0.28))
		return kit.build())


static func fountain() -> ArrayMesh:
	return Props.cached_mesh("fountain", func() -> ArrayMesh:
		var kit := MeshKit.new()
		var stone := Color(0.8, 0.8, 0.82)
		kit.cylinder(2.2, 0.6, Vector3(0, 0.3, 0), stone, 20)
		kit.cylinder(2.0, 0.08, Vector3(0, 0.58, 0), Color(0.45, 0.65, 0.85), 20)
		kit.cylinder(0.3, 1.6, Vector3(0, 1.2, 0), stone, 12)
		kit.cylinder(0.9, 0.2, Vector3(0, 2.0, 0), stone, 16)
		kit.sphere(0.25, Vector3(0, 2.4, 0), Color(0.7, 0.85, 1.0, 0.3), Vector3(1, 1.6, 1))
		return kit.build())


static func bench() -> ArrayMesh:
	return Props.cached_mesh("bench", func() -> ArrayMesh:
		var kit := MeshKit.new()
		var wood := Color(0.55, 0.38, 0.24)
		kit.box(Vector3(1.8, 0.08, 0.45), Vector3(0, 0.45, 0), wood)
		kit.box(Vector3(1.8, 0.4, 0.06), Vector3(0, 0.75, 0.22), wood)
		for side in [-0.8, 0.8]:
			kit.box(Vector3(0.06, 0.45, 0.45), Vector3(side, 0.22, 0), Color(0.2, 0.2, 0.22))
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


static func locomotive() -> ArrayMesh:
	return Props.cached_mesh("loco", func() -> ArrayMesh:
		var kit := MeshKit.new()
		var paint := Color(0.75, 0.12, 0.12)
		kit.box(Vector3(3.0, 3.2, 15.0), Vector3(0, 2.3, 0.5), paint)
		kit.box(Vector3(3.0, 2.2, 1.6), Vector3(0, 1.8, -7.6), paint, Vector3(-0.35, 0, 0))
		kit.box(Vector3(2.6, 0.9, 0.1), Vector3(0, 3.1, -7.06), Color(0.2, 0.28, 0.38))
		kit.box(Vector3(3.05, 0.5, 0.2), Vector3(0, 1.2, -8.3), Color(1.0, 0.85, 0.1))
		for side in [-1.0, 1.0]:
			kit.box(Vector3(0.35, 0.25, 0.1), Vector3(0.95 * side, 1.65, -8.35), Palette.HEADLIGHT)
		kit.box(Vector3(3.1, 0.25, 15.2), Vector3(0, 3.95, 0.5), Palette.SNOW)
		_bogies(kit, 15.0)
		return kit.build())


static func wagon(variant: int) -> ArrayMesh:
	return Props.cached_mesh("wagon%d" % variant, func() -> ArrayMesh:
		var kit := MeshKit.new()
		var paint: Color = [Color(0.2, 0.3, 0.55), Color(0.75, 0.12, 0.12), Color(0.6, 0.62, 0.65)][variant % 3]
		kit.box(Vector3(3.0, 3.0, 14.0), Vector3(0, 2.2, 0), paint)
		for side in [-1.0, 1.0]:
			kit.box(Vector3(0.08, 0.8, 12.0), Vector3(1.51 * side, 2.7, 0), Color(1.0, 0.88, 0.6, 0.0))
		kit.box(Vector3(3.1, 0.25, 14.2), Vector3(0, 3.75, 0), Palette.SNOW)
		_bogies(kit, 14.0)
		return kit.build())


static func _bogies(kit: MeshKit, length: float) -> void:
	for end in [-1.0, 1.0]:
		kit.box(Vector3(2.4, 0.6, 2.6), Vector3(0, 0.45, end * (length * 0.5 - 2.2)), Color(0.12, 0.12, 0.13))
		for axle in [-0.7, 0.7]:
			for side in [-1.0, 1.0]:
				kit.cylinder(0.4, 0.15, Vector3(0.75 * side, 0.4, end * (length * 0.5 - 2.2) + axle), Color(0.08, 0.08, 0.08), 12, Vector3(0, 0, PI / 2))


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

## Overhead sign gantry `span` metres across the motorway, signs facing +Z.
static func sign_gantry(span: int) -> ArrayMesh:
	return Props.cached_mesh("gantry%d" % span, func() -> ArrayMesh:
		var kit := MeshKit.new()
		var steel := Color(0.55, 0.58, 0.6)
		var half := span * 0.5
		for side in [-1.0, 1.0]:
			kit.box(Vector3(0.45, 8.5, 0.45), Vector3(side * half, 4.25, 0), steel)
			kit.box(Vector3(7.2, 2.6, 0.15), Vector3(side * 9.75, 7.3, 0.05), Color(0.1, 0.32, 0.7))
			kit.box(Vector3(7.4, 0.1, 0.4), Vector3(side * 9.75, 8.66, 0.05), Palette.SNOW)
		kit.box(Vector3(span, 0.5, 0.5), Vector3(0, 8.5, 0), steel)
		kit.box(Vector3(span, 0.15, 0.7), Vector3(0, 8.82, 0), Palette.SNOW)
		return kit.build())


## Articulated lorry, nose towards -Z.
static func truck(variant: int) -> ArrayMesh:
	return Props.cached_mesh("truck%d" % variant, func() -> ArrayMesh:
		var kit := MeshKit.new()
		var cab: Color = [Color(0.85, 0.15, 0.12), Color(0.15, 0.3, 0.65), Color(0.95, 0.95, 0.95)][variant % 3]
		var trailer: Color = [Color(0.92, 0.92, 0.9), Color(0.8, 0.6, 0.15), Color(0.3, 0.45, 0.35)][variant % 3]
		kit.box(Vector3(2.5, 2.6, 2.4), Vector3(0, 2.1, -6.6), cab)
		kit.box(Vector3(2.4, 0.9, 0.1), Vector3(0, 2.8, -7.82), Color(0.2, 0.28, 0.38))
		for side in [-1.0, 1.0]:
			kit.box(Vector3(0.35, 0.25, 0.1), Vector3(0.9 * side, 1.2, -7.85), Palette.HEADLIGHT)
		kit.box(Vector3(2.6, 3.0, 12.0), Vector3(0, 2.6, 0.8), trailer)
		kit.box(Vector3(2.7, 0.2, 12.1), Vector3(0, 4.2, 0.8), Palette.SNOW)
		kit.box(Vector3(2.4, 0.4, 14.5), Vector3(0, 0.75, -0.6), Color(0.12, 0.12, 0.13))
		for z in [-6.4, -2.0, 4.5, 5.9]:
			for side in [-1.0, 1.0]:
				kit.cylinder(0.5, 0.35, Vector3(1.05 * side, 0.5, z), Color(0.06, 0.06, 0.07), 14, Vector3(0, 0, PI / 2))
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
static func tug() -> ArrayMesh:
	return Props.cached_mesh("tug", func() -> ArrayMesh:
		var kit := MeshKit.new()
		var yellow := Color(1.0, 0.75, 0.05)
		kit.box(Vector3(1.6, 1.0, 2.4), Vector3(0, 0.8, -2.4), yellow)
		kit.box(Vector3(1.4, 0.8, 1.0), Vector3(0, 1.7, -2.0), Color(0.2, 0.28, 0.38))
		kit.box(Vector3(0.3, 0.2, 0.3), Vector3(0, 2.2, -2.0), Color(1.0, 0.5, 0.0, 0.0))
		for cart in 2:
			var z := 0.2 + cart * 2.6
			kit.box(Vector3(1.6, 0.2, 2.2), Vector3(0, 0.6, z), Color(0.3, 0.3, 0.32))
			kit.box(Vector3(1.4, 0.9, 1.6), Vector3(0, 1.15, z), [Color(0.2, 0.3, 0.7), Color(0.75, 0.2, 0.2)][cart])
		for z in [-3.2, -1.6, 0.2, 2.8]:
			for side in [-1.0, 1.0]:
				kit.cylinder(0.3, 0.2, Vector3(0.75 * side, 0.3, z), Color(0.08, 0.08, 0.08), 10, Vector3(0, 0, PI / 2))
		return kit.build())


static func cone() -> ArrayMesh:
	return Props.cached_mesh("cone", func() -> ArrayMesh:
		var kit := MeshKit.new()
		kit.box(Vector3(0.5, 0.05, 0.5), Vector3(0, 0.025, 0), Color(1.0, 0.4, 0.05))
		kit.cone(0.22, 0.75, Vector3(0, 0.42, 0), Color(1.0, 0.4, 0.05), 12)
		kit.cylinder(0.15, 0.12, Vector3(0, 0.45, 0), Color(1, 1, 1), 12, Vector3.ZERO, 0.12)
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


static func windsock() -> ArrayMesh:
	return Props.cached_mesh("windsock", func() -> ArrayMesh:
		var kit := MeshKit.new()
		kit.cylinder(0.06, 5.0, Vector3(0, 2.5, 0), Color(0.8, 0.8, 0.8), 6)
		for i in 4:
			var color := Color(1.0, 0.4, 0.05) if i % 2 == 0 else Color(1, 1, 1)
			kit.cylinder(0.35 - i * 0.05, 0.6, Vector3(0.3 + i * 0.6, 4.7 - i * 0.12, 0), color, 10, Vector3(0, 0, PI / 2 + 0.15), 0.3 - i * 0.05)
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


## A unit slab of shore ice; scale it in X and Z where it is placed.
static func ice_shelf() -> ArrayMesh:
	return Props.cached_mesh("shelf", func() -> ArrayMesh:
		return MeshKit.new().box(Vector3(1.0, 0.18, 1.0), Vector3.ZERO, Color(0.86, 0.93, 1.0)).build())


# --- Bandy rink ---

static func bandy_goal() -> ArrayMesh:
	return Props.cached_mesh("goal", func() -> ArrayMesh:
		var kit := MeshKit.new()
		var post := Color(0.85, 0.1, 0.1)
		for side in [-1.0, 1.0]:
			kit.cylinder(0.06, 2.1, Vector3(1.75 * side, 1.05, 0), post, 8)
			kit.box(Vector3(0.05, 2.0, 1.2), Vector3(1.75 * side, 1.0, 0.6), Color(0.9, 0.9, 0.9, 1.0))
		kit.cylinder(0.06, 3.6, Vector3(0, 2.1, 0), post, 8, Vector3(0, 0, PI / 2))
		kit.box(Vector3(3.5, 2.0, 0.05), Vector3(0, 1.0, 1.2), Color(0.9, 0.9, 0.9))
		kit.box(Vector3(3.5, 0.05, 1.2), Vector3(0, 2.05, 0.6), Color(0.9, 0.9, 0.9))
		return kit.build())


## A four-metre stretch of the low boards (sarg) around the rink, along Z.
static func boards() -> ArrayMesh:
	return Props.cached_mesh("boards", func() -> ArrayMesh:
		var kit := MeshKit.new()
		kit.box(Vector3(0.12, 0.45, 4.02), Vector3(0, 0.22, 0), Color(0.15, 0.3, 0.7))
		kit.box(Vector3(0.14, 0.06, 4.02), Vector3(0, 0.47, 0), Color(1, 1, 1))
		return kit.build())


static func floodlight() -> ArrayMesh:
	return Props.cached_mesh("flood", func() -> ArrayMesh:
		var kit := MeshKit.new()
		kit.cylinder(0.2, 16.0, Vector3(0, 8.0, 0), Color(0.6, 0.62, 0.65), 8)
		kit.box(Vector3(3.0, 1.6, 0.4), Vector3(0, 16.3, 0), Color(0.3, 0.3, 0.32))
		kit.box(Vector3(2.8, 1.4, 0.1), Vector3(0, 16.3, -0.22), Color(1.0, 0.97, 0.85, 0.0))
		return kit.build())


static func bleachers() -> ArrayMesh:
	return Props.cached_mesh("bleachers", func() -> ArrayMesh:
		var kit := MeshKit.new()
		for row in 4:
			kit.box(Vector3(1.0, 0.45 * (row + 1), 12.0), Vector3(row * 1.0, 0.225 * (row + 1), 0), Color(0.5, 0.52, 0.56))
			kit.box(Vector3(1.0, 0.06, 12.0), Vector3(row * 1.0, 0.45 * (row + 1) + 0.03, 0), Palette.SNOW)
		return kit.build())


static func _rng(value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = value * 7919
	return rng
