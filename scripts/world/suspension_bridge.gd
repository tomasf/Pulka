class_name SuspensionBridge
extends RefCounted
## Streamed pieces of a timber suspension bridge. Every piece uses the same
## analytic deck profile as the sled, including at chunk boundaries.

const BOARD_STEP := 0.50
const POST_STEP := 3.0
const CABLE_HEIGHT := 10.0
const WOOD := Color(0.48, 0.35, 0.24)
const TIMBER := Color(0.27, 0.23, 0.21)
const WIRE := Color(0.28, 0.34, 0.38)


static func build(field: TerrainField, lo: float, hi: float, ends: Vector2) -> ArrayMesh:
	var kit := MeshKit.new()
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	var first := maxi(0, floori((lo - ends.x) / BOARD_STEP))
	var last := ceili((minf(hi, ends.y) - ends.x) / BOARD_STEP)
	for i in range(first, last):
		var a := ends.x + i * BOARD_STEP
		var b := minf(a + BOARD_STEP, ends.y)
		var middle := (a + b) * 0.5
		if middle < lo or middle >= hi or b <= a: continue
		var color := WOOD.lightened(field.hash01(i, 181) * 0.18)
		_prism(kit, cube, _point(field, a + 0.009), _point(field, b - 0.009), TerrainField.BRIDGE_HALF_WIDTH * 2, 0.17, -0.085, color)
		# Thin snow left along the outer edges still leaves the wood readable.
		if i % 5 != 0:
			for side in [-1.0, 1.0]:
				var offset := Vector3(side * (TerrainField.BRIDGE_HALF_WIDTH - 0.15), 0.006, 0)
				_prism(kit, cube, _point(field, a) + offset, _point(field, b) + offset, 0.22, 0.012, 0, Palette.SNOW)
	# Railings, deck girders, hangers and the parabolic main cables are cut
	# exactly at chunk edges. No whole-span object vanishes halfway across.
	var begin := maxf(lo, ends.x)
	var finish := minf(hi, ends.y)
	var d := begin
	while d < finish - 0.001:
		var next := minf(finish, ends.x + (floorf((d - ends.x) / POST_STEP + 0.001) + 1) * POST_STEP)
		var a := _point(field, d)
		var b := _point(field, next)
		for side in [-1.0, 1.0]:
			var offset := Vector3(side * TerrainField.BRIDGE_HALF_WIDTH, 0, 0)
			for y in [0.25, 0.72, TerrainField.BRIDGE_RAIL_HEIGHT]:
				_bar(kit, a + offset + Vector3.UP * y, b + offset + Vector3.UP * y, 0.035 if y > 1 else 0.018, WIRE)
			_bar(kit, a + offset + Vector3.UP * 0.25, b + offset + Vector3.UP * TerrainField.BRIDGE_RAIL_HEIGHT, 0.013, WIRE, 5)
			_bar(kit, a + offset + Vector3.UP * TerrainField.BRIDGE_RAIL_HEIGHT, b + offset + Vector3.UP * 0.25, 0.013, WIRE, 5)
			_bar(kit, _cable(field, ends, d, side), _cable(field, ends, next, side), 0.075, WIRE, 8)
			var girder := Vector3(side * (TerrainField.BRIDGE_HALF_WIDTH - 0.35), 0, 0)
			_prism(kit, cube, a + girder, b + girder, 0.18, 0.35, -0.35, TIMBER)
		d = next
	var post := maxi(0, ceili((begin - ends.x) / POST_STEP - 0.00001))
	while ends.x + post * POST_STEP < finish:
		d = ends.x + post * POST_STEP
		var p := _point(field, d)
		for side in [-1.0, 1.0]:
			var at := p + Vector3(side * TerrainField.BRIDGE_HALF_WIDTH, 0, 0)
			kit.box(Vector3(0.12, 1.35, 0.12), at + Vector3.UP * 0.57, TIMBER)
			kit.box(Vector3(0.16, 0.045, 0.17), at + Vector3.UP * 1.267, Palette.SNOW)
			_bar(kit, at + Vector3.UP * 0.12, _cable(field, ends, d, side), 0.025, WIRE)
		if post % 2 == 0:
			kit.box(Vector3(TerrainField.BRIDGE_HALF_WIDTH * 2 + 0.45, 0.22, 0.22), p - Vector3.UP * 0.26, TIMBER)
		post += 1
	# Anchor cables and their concrete blocks live with their own abutment.
	for end in [ends.x, ends.y]:
		if end < lo or end >= hi: continue
		var direction := -1.0 if end == ends.x else 1.0
		for side in [-1.0, 1.0]:
			var ad: float = end + direction * 18.0
			var x: float = field.center_x(ad) + side * (TerrainField.BRIDGE_HALF_WIDTH + 2.0)
			var anchor := Vector3(x, field.height(x, ad, false) + 0.4, -ad)
			kit.box(Vector3(1.2, 0.8, 1.8), anchor - Vector3.UP * 0.3, Color(0.53, 0.56, 0.60))
			_bar(kit, anchor, _cable(field, ends, end, side), 0.075, WIRE, 8)
	return kit.build() if not kit._vertices.is_empty() else null


static func tower() -> ArrayMesh:
	return Props.cached_mesh("suspension_tower", func() -> ArrayMesh:
		var kit := MeshKit.new()
		var x := TerrainField.BRIDGE_HALF_WIDTH + 0.45
		for side in [-1.0, 1.0]:
			kit.box(Vector3(0.5, 10.7, 0.65), Vector3(side * x, 4.85, 0), TIMBER)
			kit.box(Vector3(1.0, 0.65, 1.25), Vector3(side * x, -0.33, 0), Color(0.53, 0.56, 0.60))
			for y in [0.7, 7.7, 9.5]:
				kit.box(Vector3(0.56, 0.17, 0.70), Vector3(side * x, y, 0), WIRE)
			kit.box(Vector3(0.60, 0.10, 0.78), Vector3(side * x, 10.24, 0), Palette.SNOW)
		kit.box(Vector3(x * 2 + 1, 0.48, 0.7), Vector3(0, 9.8, 0), TIMBER)
		kit.box(Vector3(x * 2 + 1.05, 0.09, 0.80), Vector3(0, 10.08, 0), Palette.SNOW)
		for side in [-1.0, 1.0]:
			_bar(kit, Vector3(side * x, 7.5, 0), Vector3(side * (x - 2.1), 9.8, 0), 0.12, TIMBER, 6)
		return kit.build())


static func _point(field: TerrainField, d: float) -> Vector3:
	return Vector3(field.center_x(d), field.bridge_height(d), -d)


static func _cable(field: TerrainField, ends: Vector2, d: float, side: float) -> Vector3:
	var t := (d - ends.x) / (ends.y - ends.x)
	return _point(field, d) + Vector3(side * (TerrainField.BRIDGE_HALF_WIDTH + 0.45), CABLE_HEIGHT - 7.2 * 4 * t * (1 - t), 0)


## A sheared box keeps the plank ends at the exact deck samples, including
## the diagonal centre line. All its top vertices match the collision plane.
static func _prism(kit: MeshKit, cube: BoxMesh, a: Vector3, b: Vector3, width: float, height: float, lift: float, color: Color) -> void:
	var basis := Basis(Vector3(width, 0, 0), Vector3(0, height, 0), a - b)
	kit.add(cube, Transform3D(basis, (a + b) * 0.5 + Vector3.UP * lift), color)


static func _bar(kit: MeshKit, a: Vector3, b: Vector3, radius: float, color: Color, sides := 6) -> void:
	var span := b - a
	if span.length_squared() < 0.000001: return
	var rotation := Basis(Quaternion(Vector3.UP, span.normalized())).get_euler()
	kit.cylinder(radius, span.length(), (a + b) * 0.5, color, sides, rotation)
