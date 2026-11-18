class_name SewerPipe
extends RefCounted
## Round concrete trunk sewer. The shared radius drives the shell, rideable
## curved floor, barriers, rat paths, ceiling checks and portal collars.
static var _concrete: ShaderMaterial
static var _water: ShaderMaterial
static var _earth: StandardMaterial3D
const R := TerrainField.SEWER_RADIUS
const SEGMENTS := 40
const SLICE_LENGTH := 2.5
## Centre X, half width, half depth, top above the sewer datum.
const BARRIERS := [Vector4(-3.1, 3.7, 0.26, 9), Vector4(3.4, 1.65, 0.8, 1.95), Vector4(3.1, 3.7, 0.26, 9), Vector4(-0.8, 1.65, 0.8, 1.95), Vector4(-2.8, 3.4, 0.43, 1.43)]


## Test/demo driver: steer in the pipe's tangent plane. A flat heading
## projected onto a steep curved wall points farther uphill than expected.
static func autopilot(sled: Sled) -> float:
	var field := sled.field
	var d := sled.distance()
	var slope := field.center_slope(d) + (field.sewer_guide(d + 1) - field.sewer_guide(d - 1)) * 0.5
	var ahead := d + 8
	var ahead_slope := field.center_slope(ahead) + (field.sewer_guide(ahead + 1) - field.sewer_guide(ahead - 1)) * 0.5
	var offset := sled.position.x - field.center_x(d) - field.sewer_guide(d)
	var drift := sled.velocity.x + sled.velocity.z * slope
	var heading := atan2(ahead_slope, 1) - clampf(offset * 0.24 + drift * 0.30, -0.65, 0.65)
	if sled.sewer_active:
		var frame := sled.sewer_frame()
		var flat := Vector3(sin(heading), 0, -cos(heading))
		# Choose the tangent direction with this horizontal heading.
		var rise := -frame.y.dot(flat) / frame.y.y
		var desired := atan2((flat + Vector3.UP * rise).dot(frame.x), (flat + Vector3.UP * rise).dot(-frame.z))
		var error := wrapf(desired - sled._sewer_heading, -PI, PI)
		if sled.spec.spins: return clampf(desired / (sled.spec.steer * 2.5) + error * 3, -1, 1)
		var rate := sled.spec.steer * lerpf(1.25, 0.75, clampf(sled.speed() / 45, 0, 1)) * lerpf(0.3, 1, field.grip_factor(sled.position.x, d))
		var travel := atan2(sled.velocity.dot(frame.x), sled.velocity.dot(-frame.z))
		return clampf((error * 4 - sled.spec.self_align * wrapf(travel - sled._sewer_heading, -PI, PI)) / rate, -1, 1)
	var normal := field.normal_world(sled.position.x, sled.position.z)
	var flat := Vector3(sin(heading), 0, -cos(heading))
	var rise := -normal.dot(flat) / normal.y
	var compensated := flat + Vector3.UP * rise - normal * (rise / normal.y)
	var desired := atan2(compensated.x, -compensated.z)
	var error := wrapf(desired - sled.yaw, -PI, PI)
	if sled.spec.spins:
		return clampf(wrapf(desired - atan2(field.center_slope(d), 1), -PI, PI) / sled.spec.steer + error * 3, -1, 1)
	var turn_rate := sled.spec.steer * lerpf(1.25, 0.75, clampf(sled.speed() / 45, 0, 1))
	turn_rate *= lerpf(0.3, 1, field.grip_factor(sled.position.x, d))
	var travel := atan2(sled.velocity.x, -sled.velocity.z)
	return clampf((error * 4 - sled.spec.self_align * wrapf(travel - sled.yaw, -PI, PI)) / turn_rate, -1, 1)


static func concrete() -> ShaderMaterial:
	if _concrete == null:
		_concrete = ShaderMaterial.new()
		_concrete.shader = load("res://shaders/sewer_surface.gdshader")
	return _concrete


static func sewage() -> ShaderMaterial:
	if _water == null:
		_water = ShaderMaterial.new()
		_water.shader = load("res://shaders/sewage.gdshader")
	return _water


static func earth() -> StandardMaterial3D:
	if _earth == null:
		_earth = StandardMaterial3D.new()
		_earth.vertex_color_use_as_albedo = true
		_earth.roughness = 1
		_earth.metallic_specular = 0
	return _earth


class BuildJob:
	var target: WeakRef
	var water_target: WeakRef
	var earth_target: WeakRef
	var mesh: ArrayMesh
	var field: TerrainField
	var at: float
	var finish: float
	var skin := MeshKit.new()
	var water := MeshKit.new()
	var embankment := MeshKit.new()
	var stage := 0

	func _init(terrain: TerrainField, first: float, last: float) -> void:
		field = terrain
		at = first
		finish = last

	func step() -> bool:
		if at < finish - 0.001:
			var next := minf(finish, (floorf(at / SewerPipe.SLICE_LENGTH) + 1) * SewerPipe.SLICE_LENGTH)
			SewerPipe._slice(skin, water, field, at, next)
			SewerPipe._earth_slice(embankment, field, at, next)
			at = next
			return false
		if stage == 0:
			mesh = skin.build()
			mesh.surface_set_material(0, SewerPipe.concrete())
			stage = 1
			return false
		if stage == 1:
			var stream: MeshInstance3D = water_target.get_ref()
			if stream:
				stream.mesh = water.build()
				stream.material_override = SewerPipe.sewage()
			stage = 2
			return false
		var bank: MeshInstance3D = earth_target.get_ref()
		if bank:
			bank.mesh = embankment.build()
			bank.material_override = SewerPipe.earth()
		return true


## A broad earth ridge buries the whole pipe. The sloping portal faces have
## a circular hole, so terrain above the tunnel never fills its interior.
static func _earth_point(field: TerrainField, d: float, angle: float) -> Vector3:
	var ends := field.sewer_span(d)
	var t := clampf((d - ends.x) / (ends.y - ends.x), 0, 1)
	var ridge := maxf(0, -cos(angle))
	var at := d - 12 * cos(angle) * (1 - 2 * t)
	var x := field.center_x(at) + sin(angle) * (40 + 2 * sin(at * 0.018 + angle * 2))
	# Bury the perimeter below the coarse terrain mesh: a coincident edge
	# exposes thin triangular flaps as the ordinary snow banks curve away.
	var y := field.height(x, at, false, false) - 2
	if ridge > 0: y = maxf(y, field.sewer_height(at) + (25 + sin(at * 0.04 + angle * 1.6)) * pow(ridge, 0.8))
	return Vector3(x, y, -at)


static func _earth_slice(m: MeshKit, field: TerrainField, d: float, next: float) -> void:
	for k in range(SEGMENTS / 4, SEGMENTS * 3 / 4):
		var a := TAU * k / SEGMENTS
		var b := TAU * (k + 1) / SEGMENTS
		_earth_quad(m, _earth_point(field, d, a), _earth_point(field, d, b), _earth_point(field, next, b), _earth_point(field, next, a), false, Vector3.UP)
	var ends := field.sewer_span(d)
	if absf(d - ends.x) < 0.001: _earth_portal(m, field, ends.x, 1)
	if absf(next - ends.y) < 0.001: _earth_portal(m, field, ends.y, -1)


static func _earth_portal(m: MeshKit, field: TerrainField, d: float, direction: float) -> void:
	for k in SEGMENTS:
		var a := TAU * k / SEGMENTS
		var b := TAU * (k + 1) / SEGMENTS
		var base := Vector3(field.center_x(d), field.sewer_height(d) + R, -d - direction * 0.5)
		var inner_a := base + Vector3(sin(a), -cos(a), 0) * 8.85
		var inner_b := base + Vector3(sin(b), -cos(b), 0) * 8.85
		var outer_a := _earth_point(field, d, a)
		var outer_b := _earth_point(field, d, b)
		for ring in 3:
			var u := ring / 3.0
			var v := (ring + 1) / 3.0
			_earth_quad(m, inner_a.lerp(outer_a, u), inner_b.lerp(outer_b, u), inner_b.lerp(outer_b, v), inner_a.lerp(outer_a, v), true, Vector3.BACK * direction)


static func _earth_quad(m: MeshKit, a: Vector3, b: Vector3, c: Vector3, d: Vector3, face: bool, facing: Vector3) -> void:
	var start := m._vertices.size()
	IceCavern.quad(m, a, b, c, d, Color.WHITE, facing)
	for i in 4:
		var p: Vector3 = m._vertices[start + i]
		var tint := 0.5 + 0.25 * sin(p.x * 0.18 + p.y * 0.31) * sin(p.z * 0.13 - p.x * 0.06)
		var color := Palette.SNOW_EDGE.lerp(Palette.SNOW_PACKED, 0.55 + tint * 0.4)
		if not face: color = color.lerp(Palette.SNOW_PACKED, 0.75)
		m._colors[start + i] = color.srgb_to_linear()


static func _slice(skin: MeshKit, water: MeshKit, field: TerrainField, d: float, next: float) -> void:
	var front := Vector3(field.center_x(d), field.sewer_height(d) + R, -d)
	var back := Vector3(field.center_x(next), field.sewer_height(next) + R, -next)
	for outer in [false, true]:
		var radius := R + 0.65 if outer else R
		for k in SEGMENTS:
			var angle := TAU * k / SEGMENTS
			var next_angle := TAU * (k + 1) / SEGMENTS
			var a := Vector3(sin(angle), -cos(angle), 0) * radius
			var b := Vector3(sin(next_angle), -cos(next_angle), 0) * radius
			var tint := 0.5 + sin(d * 0.071 + k * 1.7) * 0.10
			var color := Color("52574b").lerp(Color("73715f"), tint)
			if not outer:
				color = Color("404637").lerp(Color("686351"), tint)
				if cos(angle + PI / SEGMENTS) > 0.5:
					color = color.lerp(Color("35452b"), 0.65)
					color.a = 0.25
				else: color.a = 0.85
			# Nudge the floor into the void so it never fights the terrain.
			var lift := Vector3.UP * 0.025 if not outer else Vector3.ZERO
			IceCavern.quad(skin, front + a + lift, front + b + lift, back + b + lift, back + a + lift, color, (a + b) * (1 if outer else -1))
	var a := Vector3(field.center_x(d), field.sewer_height(d) + 0.19, -d)
	var b := Vector3(field.center_x(next), field.sewer_height(next) + 0.19, -next)
	IceCavern.quad(water, a - Vector3.RIGHT * 1.3, a + Vector3.RIGHT * 1.3, b + Vector3.RIGHT * 1.3, b - Vector3.RIGHT * 1.3, Color.WHITE, Vector3.UP)


static func collar() -> ArrayMesh:
	return Props.cached_mesh("sewer_collar", func() -> ArrayMesh:
		var m := MeshKit.new()
		var face := Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, R, 0))
		m.torus(7.95, 9.1, face, Color("777569"), 48, 8)
		for i in 20:
			var a := TAU * i / 20
			var p := Vector3(sin(a) * 8.5, R - cos(a) * 8.5, 0.53)
			m.cylinder(0.13, 0.1, p, Color("725b42"), 6, Vector3(PI / 2, 0, 0))
		return m.build())


static func rib() -> ArrayMesh:
	return Props.cached_mesh("sewer_joint", func() -> ArrayMesh:
		var m := MeshKit.new()
		m.torus(7.86, 8.10, Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, R, 0)), Color("4e5a53"), 40, 5)
		return m.build())


static func grate(right: bool) -> ArrayMesh:
	return Props.cached_mesh("sewer_grate_%s" % right, func() -> ArrayMesh:
		var m := MeshKit.new()
		var side := 1.0 if right else -1.0
		var rust := Color("a76b40")
		var x := -0.6
		while x <= 6.8:
			var bottom := R - sqrt(R * R - x * x)
			m.box(Vector3(0.09, 8.5 - bottom, 0.14), Vector3(side * x, (8.5 + bottom) * 0.5, 0), rust)
			x += 0.38
		for y in [4.5, 8.45]: m.box(Vector3(7.6, 0.18, 0.20), Vector3(side * 3.1, y, 0), rust.darkened(0.2))
		m.box(Vector3(0.30, 8.1, 0.28), Vector3(side * -0.6, 4.45, 0), Color("414b47"))
		for i in 12:
			m.box(Vector3(0.32, 0.24, 0.31), Vector3(side * -0.6, 0.65 + i * 0.62, 0), Color("dab35b") if i % 2 == 0 else Color("2b3431"))
		return m.build())


static func debris() -> ArrayMesh:
	return Props.cached_mesh("sewer_debris", func() -> ArrayMesh:
		var m := MeshKit.new()
		for info in [Vector3(-0.65, 0.55, 0), Vector3(0.5, 0.55, 0.25), Vector3(-0.3, 1.4, 0.1)]:
			m.box(Vector3(1.05, 0.95, 1.05), info, Color("8d7350"))
			for y in [-0.32, 0.32]: m.box(Vector3(1.09, 0.10, 1.09), info + Vector3.UP * y, Color("514f40"))
			m.box(Vector3(0.12, 0.9, 1.10), info, Color("c2a675"), Vector3(0, 0, 0.7))
		m.ellipsoid(Vector3(0.46, 0.36, 0.48), Vector3(1.15, 0.35, -0.3), Color("3d4840"))
		m.cone(0.12, 0.15, Vector3(1.15, 0.74, -0.3), Color("4b5644"), 7)
		return m.build())


static func low_pipe() -> ArrayMesh:
	return Props.cached_mesh("sewer_low_pipe", func() -> ArrayMesh:
		var m := MeshKit.new()
		m.cylinder(0.42, 6.8, Vector3(0, 1.0, 0), Color("8a613e"), 16, Vector3(0, 0, PI / 2))
		for x in [-3.2, -1.7, 1.7, 3.2]:
			m.cylinder(0.49, 0.15, Vector3(x, 1, 0), Color("b29058"), 16, Vector3(0, 0, PI / 2))
		return m.build())


static func lamp() -> ArrayMesh:
	return Props.cached_mesh("sewer_lamp", func() -> ArrayMesh:
		var m := MeshKit.new()
		# Origin is on the concrete. The rear of the bolted mounting plate
		# sinks slightly into it; brackets carry the lamp on the inward side.
		m.box(Vector3(0.54, 0.94, 0.07), Vector3(0, 0, 0.005), Color("51574d"))
		for y in [-0.25, 0.25]:
			m.box(Vector3(0.10, 0.13, 0.15), Vector3(0, y, -0.09), Color("5f6252"))
		for x in [-0.22, 0.22]:
			for y in [-0.40, 0.40]:
				m.cylinder(0.033, 0.035, Vector3(x, y, -0.045), Color("969680"), 6, Vector3(PI / 2, 0, 0))
		m.box(Vector3(0.38, 0.76, 0.20), Vector3(0, 0, -0.23), Color("454c46"))
		m.ellipsoid(Vector3(0.17, 0.26, 0.14), Vector3(0, 0, -0.33), Color(1, 0.68, 0.20, 0.35))
		var cage := Color("4e5143")
		for y in [-0.28, 0.28]:
			m.box(Vector3(0.39, 0.035, 0.035), Vector3(0, y, -0.49), cage)
			for x in [-0.18, 0.18]:
				m.capsule_between(Vector3(x, y, -0.26), Vector3(x, y, -0.49), 0.018, cage, 6)
		for x in [-0.16, 0, 0.16]: m.box(Vector3(0.025, 0.56, 0.035), Vector3(x, 0, -0.49), cage)
		return m.build())


## Mount on the actual faceted inner skin, including its grade and bends.
## Local +Z goes into the wall; the lamp and its light face inward along -Z.
static func lamp_transform(field: TerrainField, d: float, side: float) -> Transform3D:
	var ends := field.sewer_span(d)
	var lo := maxf(ends.x, floorf(d / SLICE_LENGTH) * SLICE_LENGTH)
	var hi := minf(ends.y, (floorf(d / SLICE_LENGTH) + 1) * SLICE_LENGTH)
	var front := Vector3(field.center_x(lo), field.sewer_height(lo) + R + 0.025, -lo)
	var back := Vector3(field.center_x(hi), field.sewer_height(hi) + R + 0.025, -hi)
	# Centre of the 63–72 degree facet, comfortably below the ceiling.
	var a := Vector3(side * sin(7 * TAU / SEGMENTS), -cos(7 * TAU / SEGMENTS), 0) * R
	var b := Vector3(side * sin(8 * TAU / SEGMENTS), -cos(8 * TAU / SEGMENTS), 0) * R
	var up := (b - a).normalized()
	var outward := up.cross(back - front).normalized() * -side
	var right := up.cross(outward).normalized()
	up = outward.cross(right).normalized()
	var at := front.lerp(back, inverse_lerp(lo, hi, d)) + (a + b) * 0.5
	return Transform3D(Basis(right, up, outward), at)


static func inlet() -> ArrayMesh:
	return Props.cached_mesh("sewer_inlet", func() -> ArrayMesh:
		var m := MeshKit.new()
		m.cylinder(1.0, 0.65, Vector3.ZERO, Color("3c443d"), 20, Vector3(0, 0, PI / 2))
		m.torus(0.91, 1.18, Transform3D(Basis(Vector3.BACK, PI / 2), Vector3(0.36, 0, 0)), Color("946b46"), 24, 7)
		for k in [-0.6, -0.3, 0.0, 0.3, 0.6]:
			m.box(Vector3(0.04, sqrt(1 - k * k) * 1.8, 0.07), Vector3(0.4, 0, k), Color("677261"))
		return m.build())


static func populate(world: SlopeWorld, chunk: Chunk, decor: Dictionary, lo: float, hi: float, span: Vector3) -> void:
	lo = maxf(lo, span.x + TerrainField.SEWER_INSET)
	hi = minf(hi, span.y - TerrainField.SEWER_INSET)
	if hi <= lo: return
	var field := world.field
	var shell := MeshInstance3D.new()
	shell.name = "SewerPipe"
	chunk.add_child(shell)
	var stream := MeshInstance3D.new()
	stream.name = "SewerStream"
	stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chunk.add_child(stream)
	var job := BuildJob.new(field, lo, hi)
	var bank := MeshInstance3D.new()
	bank.name = "SewerEmbankment"
	chunk.add_child(bank)
	job.target = weakref(shell)
	job.water_target = weakref(stream)
	job.earth_target = weakref(bank)
	world.regions._region_jobs.append(job)
	for d in [span.x + TerrainField.SEWER_INSET, span.y - TerrainField.SEWER_INSET]:
		if d >= lo and d < hi + 0.001:
			world.add_decor(decor, collar(), Transform3D(Basis.IDENTITY, Vector3(field.center_x(d), field.sewer_height(d), -d)))
	var d := ceilf(lo / 12) * 12
	while d < hi:
		world.add_decor(decor, rib(), Transform3D(Basis.IDENTITY, Vector3(field.center_x(d), field.sewer_height(d), -d)))
		d += 12
	for i in 5:
		d = span.x + TerrainField.SEWER_PASSAGES[i + 1].x
		if d < lo or d >= hi: continue
		var obstacle := Obstacle.new().configure(Obstacle.Kind.SEWER_DEBRIS, Props.Rig.of(null), field)
		var spec: Vector4 = BARRIERS[i]
		var x := spec.x
		obstacle.half_extents = Vector2(spec.y, spec.z)
		obstacle.top = spec.w
		var y := field.sewer_height(d)
		match i:
			0, 2:
				var right := i == 2
				world.add_decor(decor, grate(right), Transform3D(Basis.IDENTITY, Vector3(field.center_x(d), y, -d)))
			1, 3:
				y = field.sewer_floor(field.center_x(d) + x, d)
				world.add_decor(decor, debris(), Transform3D(Basis.IDENTITY, Vector3(field.center_x(d) + x, y, -d)))
			4:
				world.add_decor(decor, low_pipe(), Transform3D(Basis.IDENTITY, Vector3(field.center_x(d) + x, y, -d)))
		obstacle.position = Vector3(field.center_x(d) + x, y, -d)
		chunk.add_child(obstacle)
		chunk.obstacles.append(obstacle)
	d = ceilf(lo / 22) * 22
	while d < hi:
		var side := 1.0 if int(d / 22) % 2 == 0 else -1.0
		var mounting := lamp_transform(field, d, side)
		world.add_decor(decor, lamp(), mounting)
		var light := OmniLight3D.new()
		light.position = mounting * Vector3(0, 0, -0.68)
		light.light_color = Color("ffd58a")
		light.light_energy = 2.0
		light.omni_range = 18
		light.distance_fade_enabled = true
		light.distance_fade_begin = 65
		light.distance_fade_length = 20
		chunk.add_child(light)
		if int(d / 22) % 3 == 0:
			var inlet_at := Vector3(field.center_x(d + 5) + side * 7.5, field.sewer_height(d + 5) + 6.7, -(d + 5))
			world.add_decor(decor, inlet(), Transform3D(Basis(Vector3.UP, PI if side > 0 else 0), inlet_at))
		d += 22
	d = ceilf(lo / 7) * 7
	while d < hi:
		world._add_pickup(chunk, Pickup.Kind.GINGERBREAD, field.center_x(d) + field.sewer_guide(d), d)
		d += 7
	d = ceilf(lo / 15) * 15
	while d < hi:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(Vector2i(field.world_seed, int(d)))
		var lx := rng.randf_range(-5.8, 5.8)
		var at := Vector3(field.center_x(d) + lx, field.sewer_floor(field.center_x(d) + lx, d) + 0.02, -d)
		if SewerRat.clear_at(field, at, chunk.obstacles):
			var rat := SewerRat.new().configure(field, at, rng.randi(), chunk.obstacles)
			chunk.add_child(rat)
			chunk.rats.append(rat)
		d += 15
