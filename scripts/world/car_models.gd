class_name CarModels
extends RefCounted
## Seven recognizable body shapes, with independent paint and trim. All
## details are merged into one opaque surface per car, including its glass.
enum Body { CLASSIC_ESTATE, ESTATE, HATCHBACK, SALOON, SUV, VAN, PICKUP }
const BODY_NAMES := ["Klassisk kombi", "Modern kombi", "Halvkombi", "Sedan", "SUV", "Skåpbil", "Pickup"]
## A plausible mixed Swedish road fleet, deliberately not a claim of exact
## official market shares. Pickups and yellow paint are occasional sightings.
const BODY_WEIGHTS := [8, 25, 24, 12, 25, 5, 1]
const PAINT_WEIGHTS := [10, 14, 27, 23, 5, 1, 20]
const GLASS := Color(0.12, 0.23, 0.32, 0.75)
const RUBBER := Color(0.045, 0.052, 0.061, 0.5)
const TRIM := Color(0.085, 0.10, 0.12, 0.5)
const METAL := Color(0.65, 0.70, 0.75, 0.25)
const SNOW := Color(0.92, 0.95, 0.98, 0.5)
static var _material: ShaderMaterial

class Shape:
	var half_length := 2.4
	var half_width := 0.90
	var belt := 0.98
	var roof := 1.55
	var cowl := -1.15
	var roof_front := -0.48
	var roof_rear := 1.45
	var cabin_rear := 2.05
	var roof_width := 0.72
	var wheel_radius := 0.34
	var axles := Vector2(-1.45, 1.45)
	func _init(values: Dictionary) -> void:
		for key: String in values: set(key, values[key])

static func variant_count() -> int: return BODY_NAMES.size() * Palette.CARS.size()

static func pick(rng: RandomNumberGenerator) -> int:
	# One random draw preserves the spawning cadence. Its two independent
	# percentile digits select body and paint rather than tying them together.
	var ticket := rng.randi_range(0, 9999)
	return _weighted(ticket / 100, BODY_WEIGHTS) + BODY_NAMES.size() * _weighted(ticket % 100, PAINT_WEIGHTS)

static func _weighted(ticket: int, weights: Array) -> int:
	for i in weights.size():
		ticket -= int(weights[i])
		if ticket < 0: return i
	return weights.size() - 1

static func shape(body: int) -> Shape:
	match body:
		Body.CLASSIC_ESTATE:
			return Shape.new({"half_length": 2.46, "belt": 0.96, "roof": 1.57, "cowl": -1.18, "roof_front": -0.72, "roof_rear": 1.87, "cabin_rear": 2.22, "roof_width": 0.77, "axles": Vector2(-1.45, 1.43)})
		Body.ESTATE:
			return Shape.new({"half_length": 2.43, "half_width": 0.92, "roof": 1.53, "roof_front": -0.43, "roof_rear": 1.45, "cabin_rear": 2.13, "axles": Vector2(-1.52, 1.49)})
		Body.HATCHBACK:
			return Shape.new({"half_length": 1.97, "half_width": 0.85, "belt": 0.91, "roof": 1.50, "cowl": -1.10, "roof_front": -0.48, "roof_rear": 0.94, "cabin_rear": 1.66, "roof_width": 0.68, "wheel_radius": 0.31, "axles": Vector2(-1.24, 1.23)})
		Body.SALOON:
			return Shape.new({"half_length": 2.38, "belt": 0.96, "roof": 1.48, "roof_front": -0.46, "roof_rear": 0.96, "cabin_rear": 1.64, "roof_width": 0.70, "axles": Vector2(-1.49, 1.48)})
		Body.SUV:
			return Shape.new({"half_length": 2.46, "half_width": 0.97, "belt": 1.15, "roof": 1.88, "cowl": -1.24, "roof_front": -0.48, "roof_rear": 1.42, "cabin_rear": 2.13, "roof_width": 0.77, "wheel_radius": 0.40, "axles": Vector2(-1.54, 1.52)})
		Body.VAN:
			return Shape.new({"half_length": 2.50, "half_width": 0.97, "belt": 1.08, "roof": 2.08, "cowl": -2.13, "roof_front": -1.57, "roof_rear": 2.05, "cabin_rear": 2.27, "roof_width": 0.84, "wheel_radius": 0.38, "axles": Vector2(-1.64, 1.62)})
		_:
			return Shape.new({"half_length": 2.64, "half_width": 0.97, "belt": 1.12, "roof": 1.87, "cowl": -1.40, "roof_front": -0.82, "roof_rear": 0.61, "cabin_rear": 0.92, "roof_width": 0.76, "wheel_radius": 0.41, "axles": Vector2(-1.65, 1.56)})

static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = preload("res://shaders/car_surface.gdshader")
	return _material

static func build(variant: int) -> ArrayMesh:
	var body := posmod(variant, BODY_NAMES.size())
	var paint_index := posmod(variant / BODY_NAMES.size(), Palette.CARS.size())
	var s := shape(body)
	var paint: Color = Palette.CARS[paint_index]
	var m := MeshKit.new()
	_body(m, s, body, paint)
	_cabin(m, s, body, paint)
	_details(m, s, body, paint)
	var wheel_centers := PackedFloat32Array()
	for side in [-1.0, 1.0]:
		for axle in [s.axles.x, s.axles.y]:
			var center := Vector3(side * (s.half_width - 0.02), s.wheel_radius, axle)
			var first := m._vertices.size()
			_wheel(m, center, s.wheel_radius, side, body == Body.CLASSIC_ESTATE or body == Body.VAN)
			wheel_centers.resize(m._vertices.size() * 4)
			for vertex in range(first, m._vertices.size()):
				wheel_centers[vertex * 4] = center.x
				wheel_centers[vertex * 4 + 1] = center.y
				wheel_centers[vertex * 4 + 2] = center.z
				wheel_centers[vertex * 4 + 3] = 1.0
			_arch(m, s, axle, side, body in [Body.SUV, Body.PICKUP])
	if body == Body.PICKUP: _bed(m, s, paint)
	_snow(m, s, body, paint_index)
	# Unmarked body/arch vertices stay fixed; only the four complete wheels
	# (tyres, rims and spokes) rotate around their own axle centers.
	wheel_centers.resize(m._vertices.size() * 4)
	var mesh := m.build(wheel_centers)
	mesh.surface_set_material(0, material())
	mesh.set_meta("body_name", BODY_NAMES[body])
	mesh.set_meta("body_kind", body)
	mesh.set_meta("paint_index", paint_index)
	mesh.set_meta("collision_extents", Vector2(s.half_width + 0.04, s.half_length + 0.06))
	mesh.set_meta("roof_height", s.roof + 0.055)
	mesh.set_meta("wheel_radius", s.wheel_radius)
	mesh.set_meta("axle_reach", maxf(absf(s.axles.x), s.axles.y))
	mesh.set_meta("track_half_width", s.half_width - 0.02)
	return mesh

static func _face(m: MeshKit, points: PackedVector3Array, color: Color, facing: Vector3) -> void:
	var n := (points[1] - points[0]).cross(points[2] - points[0]).normalized()
	if n.dot(facing) < 0: n = -n
	var first := m._vertices.size()
	for p in points:
		m._vertices.append(p)
		m._normals.append(n)
		m._colors.append(color.srgb_to_linear())
	for i in range(1, points.size() - 1): m._triangle_facing(first, first + i, first + i + 1)

static func _bar(m: MeshKit, a: Vector3, b: Vector3, width: float, color: Color) -> void:
	var along := b - a
	var rotation := Basis(Quaternion(Vector3.UP, along.normalized()))
	m.box(Vector3(width, along.length(), width), (a + b) * 0.5, color, rotation.get_euler())

static func _ring(s: Shape, z: float) -> PackedVector3Array:
	var end := smoothstep(s.half_length - 0.5, s.half_length, absf(z))
	var w := s.half_width * lerpf(1, 0.91, end)
	var top := s.belt - end * 0.12
	var bottom := _body_bottom(s, z)
	var bevel := minf(0.075, (top - bottom) * 0.3)
	return PackedVector3Array([Vector3(-w * 0.88, bottom, z), Vector3(-w, bottom + bevel, z), Vector3(-w, top - bevel, z), Vector3(-w * 0.89, top, z), Vector3(w * 0.89, top, z), Vector3(w, top - bevel, z), Vector3(w, bottom + bevel, z), Vector3(w * 0.88, bottom, z)])

static func _body_bottom(s: Shape, z: float) -> float:
	var bottom := 0.28 if s.wheel_radius < 0.37 else 0.36
	for axle in [s.axles.x, s.axles.y]:
		var r := s.wheel_radius + 0.065
		var offset: float = absf(z - axle)
		if offset <= r: bottom = maxf(bottom, s.wheel_radius + sqrt(maxf(0, r * r - offset * offset)))
	return bottom

static func _roof_edge(s: Shape, t: float, side: float) -> Vector3:
	return Vector3(side * s.roof_width * (0.97 + 0.03 * sin(t * PI)), s.roof - 0.07 + 0.04 * sin(t * PI), lerpf(s.roof_front, s.roof_rear, t))

static func _body(m: MeshKit, s: Shape, body: int, paint: Color) -> void:
	var cuts := {-s.half_length: true, -s.half_length + 0.20: true, s.cowl: true, s.cabin_rear: true, s.half_length - 0.18: true, s.half_length: true}
	for axle in [s.axles.x, s.axles.y]:
		var r := s.wheel_radius + 0.065
		cuts[axle - r - 0.002] = true
		cuts[axle + r + 0.002] = true
		for i in 13: cuts[axle - r * cos(PI * i / 12.0)] = true
	var zs: Array = cuts.keys()
	zs.sort()
	for i in range(1, zs.size()):
		var a := _ring(s, zs[i - 1])
		var b := _ring(s, zs[i])
		for j in 8:
			if body == Body.PICKUP and j == 3 and zs[i - 1] >= s.cabin_rear: continue
			var k := (j + 1) % 8
			var outward := Vector3((a[j].x + a[k].x) * 0.5, (a[j].y + a[k].y) * 0.5 - s.belt * 0.65, 0)
			_face(m, PackedVector3Array([a[j], a[k], b[k], b[j]]), paint.darkened(0.13) if j == 7 else paint, outward)
	_face(m, _ring(s, -s.half_length), paint, Vector3.FORWARD)
	_face(m, _ring(s, s.half_length), paint, Vector3.BACK)
	# A dark undertray is visible inside the genuine wheel openings.
	m.box(Vector3(s.half_width * 1.35, 0.18, s.half_length * 1.75), Vector3(0, 0.34, 0), TRIM)

static func _cabin(m: MeshKit, s: Shape, body: int, paint: Color) -> void:
	var w := s.half_width * 0.88
	var r := s.roof_width
	var across := [-1.0, -0.72, 0.72, 1.0]
	var along := [0.0, 0.125, 0.25, 0.375, 0.50, 0.625, 0.75, 0.875, 1.0]
	var division := 0.28 if body == Body.VAN else 0.40
	if body == Body.VAN:
		along.append(division)
		along.sort()
	# The roof has a shallow crown both across and along the car. Its glass
	# and pillars follow those same edges instead of forming a square box.
	for i in range(along.size() - 1):
		for j in 3:
			var corners := PackedVector3Array()
			for pair: Vector2 in [Vector2(along[i], across[j]), Vector2(along[i], across[j + 1]), Vector2(along[i + 1], across[j + 1]), Vector2(along[i + 1], across[j])]:
				var point := _roof_edge(s, pair.x, signf(pair.y))
				point.x *= absf(pair.y)
				if absf(pair.y) < 0.9: point.y += 0.07
				corners.append(point)
			_face(m, corners, paint, Vector3.UP)
	for end in [0.0, 1.0]:
		var base_z := s.cowl if end == 0 else s.cabin_rear
		for i in 3:
			var a: float = across[i]
			var b: float = across[i + 1]
			var top_a := _roof_edge(s, end, signf(a))
			var top_b := _roof_edge(s, end, signf(b))
			top_a.x *= absf(a)
			top_b.x *= absf(b)
			if absf(a) < 0.9: top_a.y += 0.07
			if absf(b) < 0.9: top_b.y += 0.07
			_face(m, PackedVector3Array([Vector3(w * a, s.belt, base_z), Vector3(w * b, s.belt, base_z), top_b, top_a]), GLASS, Vector3.FORWARD if end == 0 else Vector3.BACK)
			_bar(m, top_a, top_b, 0.045, paint)
	for side in [-1.0, 1.0]:
		var bottom_front := Vector3(side * w, s.belt, s.cowl)
		var bottom_back := Vector3(side * w, s.belt, s.cabin_rear)
		var top_front := _roof_edge(s, 0, side)
		var top_back := _roof_edge(s, 1, side)
		for i in range(along.size() - 1):
			var a: float = along[i]
			var b: float = along[i + 1]
			var panel_color := paint if body == Body.VAN and a >= division else GLASS
			_face(m, PackedVector3Array([bottom_front.lerp(bottom_back, a), bottom_front.lerp(bottom_back, b), _roof_edge(s, b, side), _roof_edge(s, a, side)]), panel_color, Vector3.RIGHT * side)
			_bar(m, _roof_edge(s, a, side), _roof_edge(s, b, side), 0.055, paint)
		_bar(m, bottom_front, top_front, 0.065, paint)
		_bar(m, bottom_back, top_back, 0.085 if body != Body.SALOON else 0.12, paint)
		_bar(m, bottom_front, bottom_back, 0.035, METAL if body == Body.CLASSIC_ESTATE else TRIM)
		for t in [division, 0.76] if body in [Body.CLASSIC_ESTATE, Body.ESTATE, Body.SUV] else [division]:
			_bar(m, bottom_front.lerp(bottom_back, t), _roof_edge(s, t, side), 0.070, paint if body == Body.CLASSIC_ESTATE else TRIM)
		# Proper mirrors on short stalks, with a separate reflective face.
		var mirror_z := s.cowl + 0.14
		_bar(m, Vector3(side * w, s.belt + 0.08, mirror_z), Vector3(side * (s.half_width + 0.12), s.belt + 0.10, mirror_z), 0.045, TRIM)
		m.box(Vector3(0.15, 0.13, 0.22), Vector3(side * (s.half_width + 0.11), s.belt + 0.12, mirror_z + 0.02), paint)
		m.box(Vector3(0.13, 0.10, 0.01), Vector3(side * (s.half_width + 0.11), s.belt + 0.12, mirror_z + 0.135), GLASS.lightened(0.18))
		# Door cuts and handles stop at the metal shoulder below the glass.
		for t in [0.04, division, 0.84]:
			var z: float = lerpf(s.cowl, s.cabin_rear, t)
			var bottom := maxf(0.38, _body_bottom(s, z) + 0.025)
			m.box(Vector3(0.012, s.belt - bottom, 0.014), Vector3(side * (s.half_width + 0.004), (s.belt + bottom) * 0.5, z), paint.darkened(0.38))
		for t in [division - 0.07, 0.76]:
			m.box(Vector3(0.025, 0.038, 0.16), Vector3(side * (s.half_width + 0.014), s.belt - 0.13, lerpf(s.cowl, s.cabin_rear, t)), METAL if body == Body.CLASSIC_ESTATE else paint.lightened(0.10))
		if body in [Body.CLASSIC_ESTATE, Body.ESTATE, Body.SUV]:
			for z in [s.roof_front + 0.2, s.roof_rear - 0.2]:
				m.box(Vector3(0.045, 0.07, 0.12), Vector3(side * r * 0.83, s.roof + 0.045, z), TRIM)
			m.box(Vector3(0.055, 0.045, s.roof_rear - s.roof_front - 0.2), Vector3(side * r * 0.83, s.roof + 0.095, (s.roof_rear + s.roof_front) * 0.5), METAL if body == Body.CLASSIC_ESTATE else TRIM)
		if body == Body.VAN:
			m.box(Vector3(0.018, 0.026, 2.1), Vector3(side * (s.half_width + 0.012), s.belt - 0.10, 0.65), METAL)
	# Windscreen wipers rest on the glass, parallel to its lower edge.
	for side in [-1.0, 1.0]:
		var base := Vector3(side * 0.28, s.belt + 0.07, lerpf(s.cowl, s.roof_front, 0.07 / (s.roof - s.belt)))
		_bar(m, base + Vector3(-0.25, 0, -0.012), base + Vector3(0.25, 0.02, -0.012), 0.018, TRIM)

static func _arch(m: MeshKit, s: Shape, axle: float, side: float, cladding: bool) -> void:
	var inner := s.wheel_radius + 0.060
	var outer := inner + (0.065 if cladding else 0.026)
	for i in 12:
		var a := PI * i / 12.0
		var b := PI * (i + 1) / 12.0
		var points := PackedVector3Array()
		for p in [Vector2(a, inner), Vector2(a, outer), Vector2(b, outer), Vector2(b, inner)]:
			points.append(Vector3(side * (s.half_width + 0.008), s.wheel_radius + sin(p.x) * p.y, axle + cos(p.x) * p.y))
		_face(m, points, TRIM if cladding else METAL.darkened(0.25), Vector3.RIGHT * side)

static func _wheel(m: MeshKit, at: Vector3, radius: float, side: float, steel: bool) -> void:
	var rotation := Basis(Vector3(0, 0, 1), PI / 2)
	m.lathe(PackedVector2Array([Vector2(radius * 0.65, -0.11), Vector2(radius * 0.91, -0.11), Vector2(radius, -0.07), Vector2(radius, 0.07), Vector2(radius * 0.91, 0.11), Vector2(radius * 0.65, 0.11)]), Transform3D(rotation, at), RUBBER, 16)
	m.cylinder(radius * 0.67, 0.23, at, METAL, 16, Vector3(0, 0, PI / 2))
	var face := at + Vector3(side * 0.124, 0, 0)
	m.cylinder(radius * 0.55, 0.018, face, TRIM, 16, Vector3(0, 0, PI / 2))
	if steel:
		m.cylinder(radius * 0.44, 0.025, face + Vector3(side * 0.008, 0, 0), METAL, 12, Vector3(0, 0, PI / 2))
	else:
		for i in 5:
			var angle := TAU * i / 5.0
			_bar(m, face + Vector3(side * 0.015, sin(angle) * radius * 0.13, cos(angle) * radius * 0.13), face + Vector3(side * 0.015, sin(angle + 0.13) * radius * 0.58, cos(angle + 0.13) * radius * 0.58), 0.045, METAL)
	m.cylinder(radius * 0.17, 0.040, face + Vector3(side * 0.02, 0, 0), METAL.darkened(0.25), 10, Vector3(0, 0, PI / 2))

static func _details(m: MeshKit, s: Shape, body: int, paint: Color) -> void:
	var front := -s.half_length
	var rear := s.half_length
	var classic := body == Body.CLASSIC_ESTATE
	var bumper_y := 0.46 if s.wheel_radius < 0.37 else 0.55
	for z in [front - 0.025, rear + 0.025]:
		m.box(Vector3(s.half_width * 1.87, 0.17, 0.13), Vector3(0, bumper_y, z), TRIM if classic or body in [Body.VAN, Body.PICKUP] else paint.darkened(0.2))
		m.box(Vector3(0.50, 0.115, 0.018), Vector3(0, bumper_y + 0.07, z + signf(z) * 0.075), Color("e9ece8"))
		m.box(Vector3(0.055, 0.115, 0.021), Vector3(-0.22, bumper_y + 0.07, z + signf(z) * 0.078), Color("204581"))
		for i in 6:
			m.box(Vector3(0.018, 0.040, 0.024), Vector3(-0.14 + i * 0.052, bumper_y + 0.07, z + signf(z) * 0.080), TRIM)
	var lamp_y := s.belt - 0.19
	if classic:
		m.box(Vector3(0.83, 0.25, 0.035), Vector3(0, lamp_y - 0.02, front - 0.017), TRIM)
		for i in 5:
			m.box(Vector3(0.025, 0.19, 0.045), Vector3(-0.34 + i * 0.17, lamp_y - 0.02, front - 0.022), METAL)
	elif body in [Body.HATCHBACK, Body.SALOON]:
		m.box(Vector3(s.half_width * 1.55, 0.08, 0.035), Vector3(0, lamp_y + 0.02, front - 0.017), TRIM)
		_face(m, PackedVector3Array([Vector3(-0.46, lamp_y - 0.12, front - 0.02), Vector3(0.46, lamp_y - 0.12, front - 0.02), Vector3(0.38, lamp_y - 0.30, front - 0.02), Vector3(-0.38, lamp_y - 0.30, front - 0.02)]), TRIM, Vector3.FORWARD)
		m.cylinder(0.044, 0.024, Vector3(0, lamp_y + 0.02, front - 0.035), METAL, 12, Vector3(PI / 2, 0, 0))
	else:
		var width := 0.53 if body in [Body.SUV, Body.PICKUP] else 0.45
		_face(m, PackedVector3Array([Vector3(-width, lamp_y + 0.08, front - 0.02), Vector3(width, lamp_y + 0.08, front - 0.02), Vector3(width * 0.80, lamp_y - 0.25, front - 0.02), Vector3(-width * 0.80, lamp_y - 0.25, front - 0.02)]), TRIM, Vector3.FORWARD)
		for i in 3:
			m.box(Vector3(width * 1.72, 0.022, 0.035), Vector3(0, lamp_y + 0.025 - i * 0.085, front - 0.03), METAL)
	for side in [-1.0, 1.0]:
		var x: float = side * s.half_width * 0.70
		if classic or body in [Body.VAN, Body.PICKUP]:
			m.box(Vector3(0.37, 0.22, 0.045), Vector3(x, lamp_y, front - 0.022), TRIM)
			m.box(Vector3(0.29, 0.16, 0.052), Vector3(x, lamp_y + 0.025, front - 0.027), Palette.HEADLIGHT)
		else:
			_face(m, PackedVector3Array([Vector3(side * s.half_width * 0.43, lamp_y + 0.10, front - 0.025), Vector3(side * s.half_width * 0.94, lamp_y + 0.06, front - 0.025), Vector3(side * s.half_width * 0.89, lamp_y - 0.085, front - 0.025), Vector3(side * s.half_width * 0.48, lamp_y - 0.065, front - 0.025)]), GLASS, Vector3.FORWARD)
			_bar(m, Vector3(side * s.half_width * 0.48, lamp_y + 0.055, front - 0.04), Vector3(side * s.half_width * 0.88, lamp_y + 0.02, front - 0.04), 0.027, Palette.HEADLIGHT)
			if body in [Body.ESTATE, Body.SUV]:
				_bar(m, Vector3(x, lamp_y + 0.055, front - 0.04), Vector3(x, lamp_y - 0.065, front - 0.04), 0.026, Palette.HEADLIGHT)
		if body in [Body.SUV, Body.PICKUP, Body.VAN]:
			m.cylinder(0.065, 0.024, Vector3(side * s.half_width * 0.70, bumper_y - 0.015, front - 0.105), Palette.HEADLIGHT, 10, Vector3(PI / 2, 0, 0))
		m.box(Vector3(0.065, 0.12, 0.049), Vector3(side * s.half_width * 0.92, lamp_y, front - 0.022), Color(1, 0.45, 0.04, 0))
		var vertical := body in [Body.CLASSIC_ESTATE, Body.ESTATE, Body.SUV, Body.VAN, Body.PICKUP]
		m.box(Vector3(0.13 if vertical else 0.38, 0.32 if vertical else 0.12, 0.035), Vector3(side * s.half_width * 0.80, s.belt - 0.18, rear + 0.02), Palette.TAILLIGHT)
		m.box(Vector3(0.11, 0.055, 0.039), Vector3(side * s.half_width * 0.80, s.belt - 0.12, rear + 0.024), Color(1, 0.48, 0.035, 0))
		if body in [Body.ESTATE, Body.SUV]:
			_bar(m, Vector3(side * s.roof_width, s.roof - 0.07, s.roof_rear + 0.03), Vector3(side * s.half_width * 0.88, s.belt + 0.05, s.cabin_rear + 0.03), 0.06, Palette.TAILLIGHT)
		m.box(Vector3(0.018, 0.07, s.axles.y - s.axles.x - 2 * (s.wheel_radius + 0.08)), Vector3(side * (s.half_width + 0.009), 0.50, (s.axles.y + s.axles.x) * 0.5), TRIM if classic or body in [Body.SUV, Body.PICKUP] else paint.darkened(0.23))
	# Rear hatch handle, demister lines and a rear wiper distinguish estates.
	m.box(Vector3(0.22, 0.035, 0.028), Vector3(0, s.belt - 0.03, rear + 0.026), TRIM)
	if body != Body.SALOON and body != Body.PICKUP:
		var rear_glass := Vector3(0, lerpf(s.belt, s.roof, 0.23), lerpf(s.cabin_rear, s.roof_rear, 0.23))
		_bar(m, rear_glass + Vector3(-0.28, 0, 0.015), rear_glass + Vector3(0.25, 0.02, 0.015), 0.018, TRIM)
	if body == Body.VAN:
		_bar(m, Vector3(0, s.belt, s.cabin_rear + 0.02), Vector3(0, s.roof, s.roof_rear + 0.02), 0.06, paint)

static func _bed(m: MeshKit, s: Shape, paint: Color) -> void:
	var first := s.cabin_rear + 0.05
	var end := s.half_length - 0.08
	var middle := (first + end) * 0.5
	m.box(Vector3(s.half_width * 1.75, 0.06, end - first), Vector3(0, 0.73, middle), TRIM)
	for side in [-1.0, 1.0]:
		m.box(Vector3(0.055, s.belt - 0.73, end - first), Vector3(side * s.half_width * 0.88, (s.belt + 0.73) * 0.5, middle), paint.darkened(0.25))
		m.box(Vector3(0.14, 0.045, end - first), Vector3(side * s.half_width * 0.88, s.belt + 0.018, middle), TRIM)
		m.box(Vector3(0.24, 0.20, 0.94), Vector3(side * 0.66, 0.84, s.axles.y), TRIM)
	m.box(Vector3(s.half_width * 1.75, 0.38, 0.05), Vector3(0, 0.92, first), paint.darkened(0.25))
	for i in 7:
		m.box(Vector3(0.025, 0.018, end - first - 0.1), Vector3(-0.6 + i * 0.2, 0.77, middle), TRIM.lightened(0.08))

static func _snow(m: MeshKit, s: Shape, body: int, paint_index: int) -> void:
	# Thin, irregular cleared patches leave the windscreen and body lines
	# readable. A few family cars carry skis on the roof rack.
	var front := s.roof_front + 0.15
	var rear := s.roof_rear - 0.12
	var width := s.roof_width * (0.62 if paint_index % 2 == 0 else 0.48)
	for i in 3:
		var za := lerpf(front, rear, i / 3.0)
		var zb := lerpf(front, rear, (i + 1) / 3.0)
		var ya := _roof_edge(s, inverse_lerp(s.roof_front, s.roof_rear, za), 1).y + 0.083
		var yb := _roof_edge(s, inverse_lerp(s.roof_front, s.roof_rear, zb), 1).y + 0.083
		_face(m, PackedVector3Array([Vector3(-width - 0.04, ya, za), Vector3(width - 0.04, ya, za), Vector3(width - 0.06, yb, zb), Vector3(-width - 0.06, yb, zb)]), SNOW, Vector3.UP)
	if s.cowl > -s.half_length + 0.6:
		var first := -s.half_length + 0.24
		var last := s.cowl - 0.10
		for i in 3:
			var za := lerpf(first, last, i / 3.0)
			var zb := lerpf(first, last, (i + 1) / 3.0)
			var ya := s.belt - 0.12 * smoothstep(s.half_length - 0.5, s.half_length, absf(za)) + 0.014
			var yb := s.belt - 0.12 * smoothstep(s.half_length - 0.5, s.half_length, absf(zb)) + 0.014
			_face(m, PackedVector3Array([Vector3(-s.half_width * 0.65, ya, za), Vector3(s.half_width * 0.62, ya, za), Vector3(s.half_width * 0.64, yb, zb), Vector3(-s.half_width * 0.64, yb, zb)]), SNOW, Vector3.UP)
	if body in [Body.CLASSIC_ESTATE, Body.ESTATE, Body.SUV] and paint_index % 3 == 1:
		for z in [front + 0.15, rear - 0.15]:
			m.box(Vector3(s.roof_width * 1.8, 0.045, 0.075), Vector3(0, s.roof + 0.12, z), TRIM)
		for x in [-0.18, 0.18]:
			m.box(Vector3(0.13, 0.04, 2.55), Vector3(x, s.roof + 0.16, 0.3), Color("bd4436"))
			m.box(Vector3(0.08, 0.075, 0.28), Vector3(x, s.roof + 0.21, 0.28), TRIM)
