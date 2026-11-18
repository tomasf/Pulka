class_name LakeWater
extends RefCounted
## One broad winter lake, with a seeded ice rim and a submerged basin.
const SEGMENTS := 64
const RINGS := [0.0, 0.30, 0.55, 0.75, 0.88, 0.95, 1.0]
const WARNING_DISTANCE := 32.0
static var _material: ShaderMaterial

static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = preload("res://shaders/lake_water.gdshader")
	return _material

static func _point(field: TerrainField, strip: Vector2, radius: float, angle: float) -> Vector3:
	var mid := (strip.x + strip.y) * 0.5
	var edge := field.lake_edge(strip, angle)
	var d := lerpf(mid, -edge.z, radius)
	var lateral := edge.x - field.center_x(-edge.z)
	return Vector3(field.center_x(d) + radius * lateral, field.water_level(strip) + 0.035, -d)

static func water_mesh(field: TerrainField, strip: Vector2) -> ArrayMesh:
	var kit := MeshKit.new()
	# Adjacent rings share their vertices. Sampling the shore and track for
	# every quad corner repeated the same expensive terrain work four times.
	kit._vertices.append(_point(field, strip, 0, 0))
	kit._normals.append(Vector3.UP)
	kit._colors.append(Color(1, 1, 1, 1))
	for ring in range(1, RINGS.size()):
		for i in SEGMENTS:
			var at := _point(field, strip, RINGS[ring], TAU * i / SEGMENTS)
			kit._vertices.append(at)
			kit._normals.append(Vector3.UP)
			kit._colors.append(Color(1, 1, 1, clampf(field.lake_shore_distance(at.x, -at.z) / 6, 0, 1)))
	for ring in range(1, RINGS.size()):
		for i in SEGMENTS:
			var next := (i + 1) % SEGMENTS
			var p := 0 if ring == 1 else 1 + (ring - 2) * SEGMENTS + i
			var q := 1 + (ring - 1) * SEGMENTS + i
			var r := 1 + (ring - 1) * SEGMENTS + next
			var s := 0 if ring == 1 else 1 + (ring - 2) * SEGMENTS + next
			kit._triangle_facing(p, q, r)
			if ring > 1: kit._triangle_facing(p, r, s)
	var mesh := kit.build()
	mesh.surface_set_material(0, material())
	return mesh

static func ice_mesh(field: TerrainField, strip: Vector2) -> ArrayMesh:
	var kit := MeshKit.new()
	var mid := (strip.x + strip.y) * 0.5
	for i in SEGMENTS:
		var corners: Array[Vector3] = []
		for j in [i, i + 1]:
			var angle: float = TAU * j / SEGMENTS
			var edge := field.lake_edge(strip, angle)
			var normal := Vector3(sin(angle) / TerrainField.LAKE_HALF_WIDTH, 0, cos(angle) / ((strip.y - strip.x) * 0.5)).normalized()
			var reach := 1.5 + field.hash01(j % SEGMENTS, int(mid)) * 2.1
			corners.append(edge - normal * 0.15 + Vector3.UP * 0.12)
			corners.append(edge + normal * reach + Vector3.UP * 0.19)
		IceCavern.quad(kit, corners[0], corners[2], corners[3], corners[1], Color("bad7e4"), Vector3.UP)
		var inward := Vector3(field.center_x(mid), field.water_level(strip), -mid) - (corners[0] + corners[2]) * 0.5
		IceCavern.quad(kit, corners[0] - Vector3.UP * 0.40, corners[2] - Vector3.UP * 0.40, corners[2], corners[0], Color("6199b3"), inward)
		if i % 3 != 0:
			IceCavern.quad(kit, corners[0].lerp(corners[1], 0.45) + Vector3.UP * 0.012, corners[2].lerp(corners[3], 0.45) + Vector3.UP * 0.012, corners[3] + Vector3.UP * 0.012, corners[1] + Vector3.UP * 0.012, Palette.SNOW, Vector3.UP)
	return kit.build()

static func populate(world: SlopeWorld, chunk: Chunk, decor: Dictionary, lo: float, hi: float, span: Vector3) -> void:
	var field := world.field
	for water: Vector2 in TerrainField.LAKE_WATER:
		var strip := Vector2(span.x + water.x, span.x + water.x + water.y)
		# Own the warnings by their approach chunk, independently of the
		# water mesh's chunk. A pair is readable from either player's side.
		var warning_d := strip.x - WARNING_DISTANCE
		if warning_d >= lo and warning_d < hi:
			for side in [-1.0, 1.0]:
				var x: float = field.center_x(warning_d) + side * (field.half_width(warning_d) + 1.2)
				world.add_decor(decor, Props.water_warning_sign(), world.ground_xform(x, warning_d, -world.street_yaw(warning_d)))
		if strip.x < lo or strip.x >= hi: continue
		var surface := MeshInstance3D.new()
		surface.name = "LakeWater"
		surface.mesh = water_mesh(field, strip)
		surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		chunk.add_child(surface)
		var ice := MeshInstance3D.new()
		ice.name = "LakeShoreIce"
		ice.mesh = ice_mesh(field, strip)
		chunk.add_child(ice)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(Vector2i(field.world_seed, int(strip.x)))
		for i in 14:
			var d := rng.randf_range(strip.x + 7, strip.y - 7)
			var width := field.lake_half_width(d)
			var side := -1.0 if i % 2 == 0 else 1.0
			var x := field.center_x(d) + side * rng.randf_range(27, maxf(28, width - 9))
			if not field.is_water(d, x): continue
			world.add_decor(decor, RegionProps.ice_floe(i % 3), Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.6, 1.2)), Vector3(x, field.water_level(strip), -d)))
		# A sauna and a real jetty on the near shore give the water scale.
		var jetty_x := field.center_x(strip.x) - 28
		world.add_decor(decor, RegionProps.jetty(), Transform3D(Basis.IDENTITY, Vector3(jetty_x, field.water_level(strip), -(strip.x + 0.5))))
		world.add_decor(decor, Props.house(0), world.ground_xform(jetty_x - 9, strip.x - 3, PI / 2, 0.55, 0.3))
		for k in 2:
			var bather := Props.posed(Props.dressed("bather%d" % k, Palette.JACKETS[k + 2], Palette.JACKETS[k + 5], Color.WHITE, Color.WHITE, true), k * 1.5, true)
			bather.position = Vector3(jetty_x + (k - 0.5) * 0.8, field.water_level(strip) + 0.75, -(strip.x + 5 + k * 1.2))
			bather.rotation.y = PI * 0.5 * (k * 2 - 1)
			chunk.add_child(bather)
	var reed := ceilf(lo / 8) * 8
	while reed < hi:
		var width := field.lake_half_width(reed)
		if width > 20:
			for side in [-1.0, 1.0]:
				var x: float = field.center_x(reed) + side * (width + 3)
				world.add_decor(decor, Props.reeds(), world.ground_xform(x, reed, 0, 1.2))
		reed += 8
