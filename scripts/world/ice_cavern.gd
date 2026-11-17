class_name IceCavern
extends RefCounted
## The inner and outer glacier skins share their portals and the analytic
## vault used for rider/camera clearance. Geometry is streamed in small slices.

static var _ice: ShaderMaterial

static func material() -> ShaderMaterial:
	if _ice == null:
		_ice = ShaderMaterial.new()
		_ice.shader = load("res://shaders/cave_ice.gdshader")
	return _ice


static func quad(m: MeshKit, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, facing: Vector3) -> void:
	var start := m._vertices.size()
	var n := (b - a).cross(c - a).normalized()
	if n.dot(facing) < 0: n = -n
	for p in [a, b, c, d]:
		m._vertices.append(p)
		m._normals.append(n)
		m._colors.append(color.srgb_to_linear())
	m._triangle_facing(start, start + 1, start + 2)
	m._triangle_facing(start, start + 2, start + 3)


static func _arch(field: TerrainField, d: float, k: int, outer: bool) -> Vector3:
	var angle := PI * k / 16.0
	var extra := 4.5 if outer else 0.0
	var hw := field.cave_half_width(d) + extra
	var h := field.cave_vault_height(d) + extra
	# Facets follow a continuous sinusoid so adjacent chunks meet exactly.
	var ripple := sin(k * 1.3 + d * 0.055) * 0.8
	var lift := (h + ripple) * sin(angle) if outer else field.cave_arch_height(k, d)
	return Vector3(field.center_x(d) + hw * cos(angle), field.height(field.center_x(d), d, false) + lift, -d)


class BuildJob:
	var target: WeakRef
	var mesh: ArrayMesh
	var field: TerrainField
	var span: Vector3
	var lo: float
	var hi: float
	var at: float
	var kit := MeshKit.new()
	var stage := 0

	func _init(terrain: TerrainField, first: float, last: float, region: Vector3) -> void:
		field = terrain
		span = region
		lo = maxf(first, span.x + TerrainField.CAVE_INSET)
		hi = minf(last, span.y - TerrainField.CAVE_INSET)
		at = lo

	func step() -> bool:
		if at < hi - 0.001:
			var next := minf(hi, (floorf(at / 3.0) + 1) * 3)
			IceCavern._slice(kit, field, at, next)
			at = next
			return false
		if stage == 0:
			IceCavern._portals(kit, field, lo, hi, span)
			stage = 1
			return false
		mesh = kit.build()
		mesh.surface_set_material(0, IceCavern.material())
		return true


static func _slice(m: MeshKit, field: TerrainField, d: float, next: float) -> void:
	for outer in [false, true]:
		var front := PackedVector3Array()
		var back := PackedVector3Array()
		for k in 17:
			front.append(_arch(field, d, k, outer))
			back.append(_arch(field, next, k, outer))
		for k in 16:
			var a := front[k]
			var b := front[k + 1]
			var c := back[k + 1]
			var e := back[k]
			var center := Vector3(field.center_x(d), field.height(field.center_x(d), d, false), -d)
			var facing := (a + b) * 0.5 - center
			var tint := 0.5 + 0.5 * sin(k * 1.9 + d * 0.15)
			var color := Color("e6f4fa").lerp(Color("a3c9df"), tint * 0.4) if outer else Color("174c72").lerp(Color("55b6cf"), tint)
			quad(m, a, b, c, e, color, facing if outer else -facing)
	# Glossy floor follows the same heights as the sled.
	for k in 8:
		var corners: Array[Vector3] = []
		for pair in [Vector2(d, k), Vector2(d, k + 1), Vector2(next, k + 1), Vector2(next, k)]:
			var x: float = field.center_x(pair.x) + field.cave_half_width(pair.x) * (pair.y / 4.0 - 1)
			corners.append(Vector3(x, field.height(x, pair.x, false) + 0.025, -pair.x))
		quad(m, corners[0], corners[1], corners[2], corners[3], Color("74bfd6").lerp(Color("b2e1ec"), (k % 3) * 0.22), Vector3.UP)


static func _portals(m: MeshKit, field: TerrainField, lo: float, hi: float, span: Vector3) -> void:
	for edge in [span.x + TerrainField.CAVE_INSET, span.y - TerrainField.CAVE_INSET]:
		if edge < lo - 0.001 or edge > hi + 0.001: continue
		# Only one chunk owns a portal if the end is on a chunk boundary.
		if edge == span.x + TerrainField.CAVE_INSET and not is_equal_approx(lo, edge): continue
		if edge == span.y - TerrainField.CAVE_INSET and not is_equal_approx(hi, edge): continue
		for k in 16:
			quad(m, _arch(field, edge, k, false), _arch(field, edge, k + 1, false), _arch(field, edge, k + 1, true), _arch(field, edge, k, true), Color("8bd3e4"), Vector3.BACK if edge == span.x + TerrainField.CAVE_INSET else Vector3.FORWARD)


static func pillar() -> ArrayMesh:
	return Props.cached_mesh("cave_pillar", func() -> ArrayMesh:
		var m := MeshKit.new()
		m.lathe(PackedVector2Array([Vector2(1.45, 0), Vector2(1.25, 0.6), Vector2(0.75, 2.6), Vector2(0.9, 4.6), Vector2(1.3, 7.2), Vector2(1.6, 8.8)]), Transform3D.IDENTITY, Color("80cce1"), 9)
		var mesh := m.build()
		mesh.surface_set_material(0, material())
		return mesh)


static func icicles() -> ArrayMesh:
	return Props.cached_mesh("cave_icicles", func() -> ArrayMesh:
		var m := MeshKit.new()
		for i in 5:
			var length := 1.2 + fposmod(i * 1.73, 1.8)
			m.cone(0.22 + i * 0.035, length, Vector3((i - 2) * 0.65, -length * 0.5, sin(i * 2.0)), Color("94d6ea"), 6, Vector3(PI, 0, 0))
		var mesh := m.build()
		mesh.surface_set_material(0, material())
		return mesh)


static func populate(world: SlopeWorld, chunk: Chunk, decor: Dictionary, lo: float, hi: float, span: Vector3) -> void:
	if hi <= span.x + TerrainField.CAVE_INSET or lo >= span.y - TerrainField.CAVE_INSET: return
	var skin := MeshInstance3D.new()
	skin.name = "IceCavern"
	var job := BuildJob.new(world.field, lo, hi, span)
	job.target = weakref(skin)
	world.regions._region_jobs.append(job)
	chunk.add_child(skin)
	var field := world.field
	lo = maxf(lo, span.x + TerrainField.CAVE_INSET)
	hi = minf(hi, span.y - TerrainField.CAVE_INSET)
	var d := ceilf(lo / 35) * 35
	while d < hi:
		if d > span.x + 52 and d < span.y - 48:
			var lx := sin(floorf(d / 35) * 2.4) * 3.4
			var x := field.center_x(d) + lx
			var height := field.cave_ceiling(x, d) - field.height(x, d) + 0.3
			var column := Obstacle.new().configure(Obstacle.Kind.ICE_PILLAR, Props.Rig.of(pillar()), field)
			column.position = Vector3(x, field.height(x, d), -d)
			column.visual.scale.y = height / 8.8
			column.top = height
			chunk.add_child(column)
			chunk.obstacles.append(column)
		d += 35
	d = ceilf(lo / 12) * 12
	while d < hi:
		var lx := sin(d * 0.21) * 5.8
		var x := field.center_x(d) + lx
		world.add_decor(decor, icicles(), Transform3D(Basis.IDENTITY, Vector3(x, field.cave_ceiling(x, d) + 0.1, -d)))
		d += 12
	d = ceilf(lo / 32) * 32
	while d < hi:
		var light := OmniLight3D.new()
		light.position = Vector3(field.center_x(d), field.height(field.center_x(d), d) + 5.5, -d)
		light.light_color = Color("67cbed")
		light.light_energy = 2.0
		light.omni_range = 19
		light.distance_fade_enabled = true
		light.distance_fade_begin = 65
		light.distance_fade_length = 20
		chunk.add_child(light)
		d += 32
	d = ceilf(lo / 7) * 7
	while d < hi:
		world._add_pickup(chunk, Pickup.Kind.GINGERBREAD, field.center_x(d) + sin(d * 0.022) * 1.2 + 5.2, d)
		d += 7
