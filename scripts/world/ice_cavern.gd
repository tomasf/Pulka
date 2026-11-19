class_name IceCavern
extends RefCounted
## A glacier tunnel buried in a snow-covered rock ridge. Ice and mountain
## share their portals; geometry is streamed in small slices.

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
	var mountain_target: WeakRef
	var mesh: ArrayMesh
	var field: TerrainField
	var span: Vector3
	var lo: float
	var hi: float
	var at: float
	var kit := MeshKit.new()
	var mountain := MeshKit.new()
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
			IceCavern._mountain_slice(mountain, field, at, next)
			at = next
			return false
		if stage == 0:
			IceCavern._portals(kit, field, lo, hi, span)
			IceCavern._mountain_portals(mountain, field, lo, hi, span)
			stage = 1
			return false
		if stage == 1:
			mesh = kit.build()
			mesh.surface_set_material(0, IceCavern.material())
			stage = 2
			return false
		var ridge: MeshInstance3D = mountain_target.get_ref()
		if ridge: ridge.mesh = mountain.build()
		return true


## Broad shoulders sink into the ordinary snow banks. At the ends the ridge
## leans back from the opening, exposing a rock face around the blue ice lip.
## All variation uses world coordinates so streamed chunks meet exactly.
static func _mountain_point(field: TerrainField, d: float, k: int) -> Vector3:
	var angle := PI * k / 16.0
	var span := field.cave_span(d)
	var t := clampf((d - span.x) / (span.y - span.x), 0, 1)
	var rise := maxf(sin(angle), 0)
	var at := d + 22 * rise * (1 - 2 * t)
	var width := 64 + 6 * sin(at * 0.019 + angle * 1.7)
	var x := field.center_x(at) + width * cos(angle) + 6 * sin(at * 0.027) * rise
	var summit := 36 + 9 * pow(sin(at * 0.032 + 0.7), 2) + 3 * sin(angle * 3 + at * 0.051)
	var y := field.height(field.center_x(at), at, false) - 4 + summit * pow(rise, 0.8)
	y = maxf(y, field.height(x, at, false, false) - 4)
	return Vector3(x, y, -at)


static func _mountain_quad(m: MeshKit, a: Vector3, b: Vector3, c: Vector3, d: Vector3, facing: Vector3) -> void:
	var first := m._vertices.size()
	quad(m, a, b, c, d, Color.WHITE, facing)
	var up := m._normals[first].y
	for i in 4:
		var p := m._vertices[first + i]
		var grain := 0.5 + 0.3 * sin(p.x * 0.17 + p.y * 0.39) * sin(p.z * 0.11 - p.x * 0.05)
		var rock := Color("4b5660").lerp(Color("87929b"), grain)
		# Snow settles on the shoulders and ledges; steep faces expose rock.
		var slope := up + 0.04 * sin(p.x * 0.3 + p.z * 0.07)
		var snow := smoothstep(0.42, 0.72, slope) if facing == Vector3.UP else 0.0
		m._colors[first + i] = rock.lerp(Palette.SNOW_PACKED, snow).srgb_to_linear()


static func _mountain_slice(m: MeshKit, field: TerrainField, d: float, next: float) -> void:
	var front := PackedVector3Array()
	var back := PackedVector3Array()
	for k in 17:
		front.append(_mountain_point(field, d, k))
		back.append(_mountain_point(field, next, k))
	for k in 16:
		_mountain_quad(m, front[k], front[k + 1], back[k + 1], back[k], Vector3.UP)


static func _lip(field: TerrainField, d: float, k: int) -> Vector3:
	return _arch(field, d, k, false).lerp(_arch(field, d, k, true), 0.4)


static func _face_point(inner: Vector3, outer: Vector3, u: float, k: int, edge: float, direction: float) -> Vector3:
	var p := inner.lerp(outer, u)
	# Broken strata, rather than large flat wedges radiating from the hole.
	var strata := 0.6 * sin(k * 1.71 + u * 11.37 + edge * 0.07) + 0.4 * sin(k * 2.41 - u * 7.61 + edge * 0.13)
	p.z += direction * 2.3 * strata * sin(u * PI)
	return p


static func _mountain_portals(m: MeshKit, field: TerrainField, lo: float, hi: float, span: Vector3) -> void:
	for edge in [span.x + TerrainField.CAVE_INSET, span.y - TerrainField.CAVE_INSET]:
		if edge < lo - 0.001 or edge > hi + 0.001: continue
		var entrance: bool = edge == span.x + TerrainField.CAVE_INSET
		if entrance and not is_equal_approx(lo, edge): continue
		if not entrance and not is_equal_approx(hi, edge): continue
		for k in 16:
			var inner_a := _lip(field, edge, k)
			var inner_b := _lip(field, edge, k + 1)
			var outer_a := _mountain_point(field, edge, k)
			var outer_b := _mountain_point(field, edge, k + 1)
			var direction := 1.0 if entrance else -1.0
			for ring in 6:
				var u := ring / 6.0
				var v := (ring + 1) / 6.0
				_mountain_quad(m, _face_point(inner_a, outer_a, u, k, edge, direction), _face_point(inner_b, outer_b, u, k + 1, edge, direction), _face_point(inner_b, outer_b, v, k + 1, edge, direction), _face_point(inner_a, outer_a, v, k, edge, direction), Vector3.BACK * direction)


static func _slice(m: MeshKit, field: TerrainField, d: float, next: float) -> void:
	# The mountain supplies the exterior; a second ice skin would protrude
	# through the broken rock face near the portals.
	var front := PackedVector3Array()
	var back := PackedVector3Array()
	for k in 17:
		front.append(_arch(field, d, k, false))
		back.append(_arch(field, next, k, false))
	var center := Vector3(field.center_x(d), field.height(field.center_x(d), d, false), -d)
	for k in 16:
		var a := front[k]
		var b := front[k + 1]
		var facing := center - (a + b) * 0.5
		var tint := 0.5 + 0.5 * sin(k * 1.9 + d * 0.15)
		quad(m, a, b, back[k + 1], back[k], Color("174c72").lerp(Color("55b6cf"), tint), facing)
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
			quad(m, _arch(field, edge, k, false), _arch(field, edge, k + 1, false), _lip(field, edge, k + 1), _lip(field, edge, k), Color("c5e5ef"), Vector3.BACK if edge == span.x + TerrainField.CAVE_INSET else Vector3.FORWARD)


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
	var mountain := MeshInstance3D.new()
	mountain.name = "CaveMountain"
	chunk.add_child(mountain)
	var job := BuildJob.new(world.field, lo, hi, span)
	job.target = weakref(skin)
	job.mountain_target = weakref(mountain)
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
		world._add_pickup(chunk, Pickup.Kind.SNOWFLAKE, field.center_x(d) + sin(d * 0.022) * 1.2 + 5.2, d)
		d += 7
