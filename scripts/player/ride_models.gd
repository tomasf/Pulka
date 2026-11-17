class_name RideModels
extends RefCounted
## The rides and the rider: the models seen front and centre all game, so
## they get more care than the scenery. Origin at the ground, front at -Z.

const PANTS := Color(0.14, 0.17, 0.3)
const BOOTS := Color(0.28, 0.17, 0.1)
const SOLE := Color(0.08, 0.07, 0.07)
const HAIR := Color(0.42, 0.26, 0.14)
const INK := Color(0.06, 0.05, 0.05)


static func vehicle(model: VehicleSpec.Model) -> ArrayMesh:
	return Props.cached_mesh("ride%d" % model, func() -> ArrayMesh:
		var kit := MeshKit.new()
		match model:
			VehicleSpec.Model.PULKA:
				_pulka(kit)
			VehicleSpec.Model.STJARTLAPP:
				_pad(kit)
			VehicleSpec.Model.SNOWRACER:
				_snowracer(kit)
			VehicleSpec.Model.TEFAT:
				_saucer(kit)
			VehicleSpec.Model.WOK:
				_wok(kit)
		var mesh := kit.build()
		mesh.surface_set_material(0, _material())
		return mesh)


# Materials share one opaque surface/draw call. Alpha is a material code in
# this shader (never transparency): polished metal < .4, plastic/wood >= .4.
static var _ride_material: ShaderMaterial

static func _material() -> ShaderMaterial:
	if _ride_material == null:
		_ride_material = ShaderMaterial.new()
		_ride_material.shader = load("res://shaders/ride.gdshader")
	return _ride_material


# --- Pulka: a long injection-moulded hull, raised seat and hand brakes ---

static func _pulka(kit: MeshKit) -> void:
	var red := Color(0.86, 0.085, 0.055, 0.65)
	var inner := Color(0.96, 0.16, 0.09, 0.72)
	var dark := Color(0.065, 0.075, 0.09)
	var rings: Array[PackedVector3Array] = [
		_tub_ring(0.83, 0.012), _tub_ring(0.91, 0.055), _tub_ring(0.99, 0.205),
		_tub_ring(1.02, 0.231), _tub_ring(1.02, 0.248), _tub_ring(0.97, 0.258),
		_tub_ring(0.94, 0.232), _tub_ring(0.86, 0.075),
	]
	kit.loft(rings.slice(0, 4), PackedFloat32Array([1, 1, 1, 1]), Transform3D.IDENTITY, red)
	kit.loft(rings.slice(3, 6), PackedFloat32Array([1, 1, 1]), Transform3D.IDENTITY, red.lightened(0.05))
	kit.loft(rings.slice(5, 8), PackedFloat32Array([-1, -1, -1]), Transform3D.IDENTITY, inner, true)
	# Close the underside and mould the two running channels into it.
	kit.loft([_tub_ring(0.01, 0.012), rings[0]], PackedFloat32Array([1, 1]), Transform3D.IDENTITY, red.darkened(0.15))
	for side in [-1.0, 1.0]:
		var runner := PackedVector3Array([Vector3(side * 0.23, 0.028, 0.58), Vector3(side * 0.23, 0.005, 0.38), Vector3(side * 0.23, 0.005, -0.42), Vector3(side * 0.22, 0.08, -0.65)])
		_tube(kit, runner, 0.022, red.darkened(0.13))
	# Raised rear seat, with shallow longitudinal non-slip moulding.
	_plate(kit, Vector2(0.29, 0.24), Vector3(0, 0.125, 0.20), 0.045, inner)
	for i in 7:
		_tube(kit, PackedVector3Array([Vector3((i - 3) * 0.073, 0.171, 0.36), Vector3((i - 3) * 0.073, 0.171, 0.06)]), 0.006, red, 6)
	for side in [-1.0, 1.0]:
		# Pivoting brake levers sit outside the rolled lip, with toothed paddles.
		var pivot := Vector3(side * 0.40, 0.245, 0.16)
		_tube(kit, PackedVector3Array([pivot, Vector3(side * 0.36, 0.37, -0.10), Vector3(side * 0.34, 0.39, -0.36)]), 0.021, dark)
		kit.cylinder(0.032, 0.025, pivot, dark, 12, Vector3(0, 0, PI / 2))
		kit.box(Vector3(0.035, 0.11, 0.13), pivot + Vector3(side * 0.012, -0.075, 0.015), dark)
		for tooth in 4:
			kit.box(Vector3(0.037, 0.035, 0.014), pivot + Vector3(side * 0.012, -0.142, -0.04 + tooth * 0.032), dark)
		# Rear reflectors, set into little plastic housings.
		kit.box(Vector3(0.105, 0.045, 0.019), Vector3(side * 0.23, 0.29, 0.755), red.darkened(0.3))
		kit.box(Vector3(0.085, 0.028, 0.021), Vector3(side * 0.23, 0.29, 0.757), Color(0.96, 0.69, 0.21, 0.5))
	# Braided tow cord: two eyelets, a loose loop and a transverse grip.
	var rope := Color(0.94, 0.86, 0.58)
	_tube(kit, PackedVector3Array([Vector3(-0.17, 0.30, -0.73), Vector3(-0.22, 0.26, -0.85), Vector3(-0.15, 0.20, -1.01), Vector3(0, 0.19, -1.06), Vector3(0.18, 0.22, -0.97), Vector3(0.19, 0.30, -0.73)]), 0.009, rope)
	for side in [-1.0, 1.0]:
		kit.torus(0.012, 0.022, Transform3D(Basis(Vector3.RIGHT, 0.3), Vector3(side * 0.18, 0.30, -0.73)), red.darkened(0.3), 12, 6)
	_tube(kit, PackedVector3Array([Vector3(-0.075, 0.20, -1.055), Vector3(0.075, 0.20, -1.055)]), 0.019, dark)


static func _tub_ring(size: float, y: float) -> PackedVector3Array:
	var ring := MeshKit.superellipse(0.39 * size, 0.79 * size, y, 48, 3.0)
	for i in ring.size():
		var p := ring[i]
		var front := clampf(-p.z / (0.79 * size), 0.0, 1.0)
		var back := clampf(p.z / (0.79 * size), 0.0, 1.0)
		p.x *= 1.0 - 0.16 * smoothstep(0.30, 1.0, front)
		p.y += 0.072 * smoothstep(0.48, 1.0, front) + 0.095 * smoothstep(0.52, 1.0, back)
		ring[i] = p
	return ring


# --- Stjärtlapp: thin, scooped pear-shaped seat and integral shovel handle ---

static func _pad(kit: MeshKit) -> void:
	var blue := Color(0.08, 0.40, 0.89, 0.62)
	var outline := _smooth_path(PackedVector3Array([
		Vector3(-0.065, 0, -0.23), Vector3(-0.16, 0, -0.15), Vector3(-0.29, 0, -0.06),
		Vector3(-0.34, 0, 0.12), Vector3(-0.29, 0, 0.30), Vector3(-0.14, 0, 0.37),
		Vector3(0, 0, 0.33), Vector3(0.14, 0, 0.37), Vector3(0.29, 0, 0.30),
		Vector3(0.34, 0, 0.12), Vector3(0.29, 0, -0.06), Vector3(0.16, 0, -0.15), Vector3(0.065, 0, -0.23),
	]), true, 4)
	for i in outline.size():
		outline[i].z += 0.10 * smoothstep(0, 0.23, -outline[i].z)
	var top: Array[PackedVector3Array] = []
	var bottom: Array[PackedVector3Array] = []
	for r in 17:
		var t := maxf(float(r) / 16, 0.001)
		var upper := PackedVector3Array()
		var lower := PackedVector3Array()
		for p in outline:
			var lift := 0.01 + 0.035 * pow(absf(p.x) / 0.34, 3) + 0.03 * smoothstep(0.1, 0.37, p.z) + 0.035 * smoothstep(0.10, 0.23, -p.z)
			var point := p * t
			point.y = 0.032 + lift * t * t * t
			upper.append(point)
			lower.append(point - Vector3(0, 0.012, 0))
		top.append(upper)
		bottom.append(lower)
	_sheet(kit, top, blue, true)
	_sheet(kit, bottom, blue, false)
	kit.loft([bottom.back(), top.back()], PackedFloat32Array([1, 1]), Transform3D.IDENTITY, blue)
	# Stem rises from the scoop into a broad grip with a genuine opening.
	var neck_rings: Array[PackedVector3Array] = []
	var neck_outward := PackedFloat32Array()
	for section in _smooth_path(PackedVector3Array([Vector3(0.07, 0.04, -0.10), Vector3(0.065, 0.07, -0.15), Vector3(0.07, 0.13, -0.19), Vector3(0.08, 0.187, -0.214)])):
		var ring := PackedVector3Array()
		for k in 16:
			var angle := TAU * k / 16
			ring.append(Vector3(cos(angle) * section.x, section.y + sin(angle) * 0.014, section.z))
		neck_rings.append(ring)
		neck_outward.append(1)
	kit.loft(neck_rings, neck_outward, Transform3D.IDENTITY, blue)
	var handle := Transform3D(Basis(Vector3.RIGHT, -0.40), Vector3(0, 0.15, -0.32))
	_handle(kit, handle, Vector2(0.15, 0.12), Vector2(0.108, 0.079), 0.028, blue)
	for i in 5:
		_tube(kit, PackedVector3Array([handle * Vector3(-0.075 + i * 0.0375, 0.017, -0.113), handle * Vector3(-0.075 + i * 0.0375, 0.017, -0.09)]), 0.003, blue.lightened(0.14), 6)
	# Shallow strengthening ribs beneath, visible during jumps and tumbles.
	for side in [-1.0, 1.0]:
		_tube(kit, PackedVector3Array([Vector3(side * 0.16, 0.015, 0.25), Vector3(side * 0.10, 0.012, 0.02), Vector3(side * 0.035, 0.022, -0.10)]), 0.009, blue.darkened(0.12), 6)


# --- Snowracer: bent steel frame, moulded saddle, three upturned skis ---

static func _snowracer(kit: MeshKit) -> void:
	var red := Color(0.90, 0.075, 0.055, 0.55)
	var steel := Color(0.58, 0.63, 0.68, 0.24)
	var black := Color(0.065, 0.073, 0.09, 0.78)
	for side in [-1.0, 1.0]:
		_ski(kit, Vector3(side * 0.34, 0, 0.22), 1.15, black)
		# One continuous, bent rear leg, rather than separate sticks and balls.
		_tube(kit, PackedVector3Array([Vector3(side * 0.34, 0.085, -0.14), Vector3(side * 0.34, 0.085, 0.59), Vector3(side * 0.31, 0.14, 0.64), Vector3(side * 0.13, 0.35, 0.48), Vector3(side * 0.12, 0.36, 0.30)]), 0.025, red)
		_tube(kit, PackedVector3Array([Vector3(side * 0.12, 0.35, 0.30), Vector3(side * 0.12, 0.29, -0.04), Vector3(side * 0.06, 0.29, -0.58)]), 0.026, red)
		_tube(kit, PackedVector3Array([Vector3(side * 0.34, 0.085, -0.14), Vector3(side * 0.12, 0.29, -0.04)]), 0.022, red)
		# Ski mounting shoes, through bolts and their washers.
		for z in [-0.12, 0.52]:
			kit.box(Vector3(0.078, 0.045, 0.12), Vector3(side * 0.34, 0.061, z), black.lightened(0.06))
			kit.cylinder(0.014, 0.09, Vector3(side * 0.34, 0.086, z), steel, 10, Vector3(0, 0, PI / 2))
		# Foot rests line up with the rider's boots; toothed brake paddles beside them.
		kit.box(Vector3(0.15, 0.026, 0.19), Vector3(side * 0.21, 0.145, -0.55), black)
		_tube(kit, PackedVector3Array([Vector3(side * 0.06, 0.28, -0.50), Vector3(side * 0.21, 0.14, -0.55)]), 0.018, red)
		kit.box(Vector3(0.095, 0.018, 0.19), Vector3(side * 0.21, 0.18, -0.27), steel.darkened(0.3), Vector3(-0.3, 0, 0))
		for tooth in 4:
			kit.box(Vector3(0.018, 0.045, 0.025), Vector3(side * 0.21 - 0.032 + tooth * 0.022, 0.14, -0.18), steel.darkened(0.3))
	_tube(kit, PackedVector3Array([Vector3(-0.31, 0.10, 0.36), Vector3(0.31, 0.10, 0.36)]), 0.023, red)
	_tube(kit, PackedVector3Array([Vector3(-0.23, 0.18, -0.26), Vector3(0.23, 0.18, -0.26)]), 0.016, steel)
	# Flat, ribbed saddle with chamfered edges. No motorcycle fairing/backrest.
	_plate(kit, Vector2(0.166, 0.34), Vector3(0, 0.371, 0.23), 0.052, black)
	for rib in 13:
		_tube(kit, PackedVector3Array([Vector3(-0.135, 0.426, -0.045 + rib * 0.044), Vector3(0.135, 0.426, -0.045 + rib * 0.044)]), 0.004, black.lightened(0.07), 6)
	_ski(kit, Vector3(0, 0, -0.76), 0.74, black)
	# Fork, head tube, steering column and a three-spoke wheel.
	_tube(kit, PackedVector3Array([Vector3(0, 0.078, -0.76), Vector3(0, 0.33, -0.63)]), 0.027, steel)
	kit.cylinder(0.047, 0.11, Vector3(0, 0.31, -0.63), red, 16, Vector3(0.48, 0, 0))
	_tube(kit, PackedVector3Array([Vector3(0, 0.35, -0.62), Vector3(0, 0.75, -0.394)]), 0.023, black)
	for side in [-1.0, 1.0]:
		kit.box(Vector3(0.022, 0.08, 0.10), Vector3(side * 0.04, 0.10, -0.76), black)
	kit.cylinder(0.017, 0.11, Vector3(0, 0.12, -0.76), steel, 10, Vector3(0, 0, PI / 2))
	var wheel := Transform3D(Basis(Vector3.RIGHT, PI / 2 - 0.55), Vector3(0, 0.767, -0.394))
	kit.torus(0.152, 0.188, wheel, black, 40, 10)
	for i in 3:
		var angle := TAU * i / 3.0 + PI / 2
		var tip := Vector3(cos(angle) * 0.155, 0, sin(angle) * 0.155)
		_tube(kit, PackedVector3Array([wheel.origin, wheel * tip]), 0.016, black, 8, false)
	kit.cylinder(0.045, 0.025, wheel.origin, black, 16, Vector3(PI / 2 - 0.55, 0, 0))
	kit.cylinder(0.024, 0.029, wheel.origin, red, 16, Vector3(PI / 2 - 0.55, 0, 0))
	# Small tow cord tucked around the steering ski.
	_tube(kit, PackedVector3Array([Vector3(-0.035, 0.11, -0.96), Vector3(-0.08, 0.08, -1.12), Vector3(0, 0.08, -1.18), Vector3(0.08, 0.08, -1.12), Vector3(0.035, 0.11, -0.96)]), 0.006, Color(0.77, 0.77, 0.71))


static func _ski(kit: MeshKit, at: Vector3, length: float, color: Color) -> void:
	var rings: Array[PackedVector3Array] = []
	for spec in [Vector3(0.006, 0.024, 0.50), Vector3(0.065, 0.016, 0.45), Vector3(0.071, 0.016, 0.27), Vector3(0.070, 0.018, -0.30), Vector3(0.067, 0.034, -0.44), Vector3(0.057, 0.078, -0.53), Vector3(0.036, 0.127, -0.58), Vector3(0.003, 0.146, -0.60)]:
		var ring := PackedVector3Array()
		for k in 12:
			var a := TAU * k / 12
			ring.append(at + Vector3(cos(a) * spec.x, spec.y + sin(a) * 0.013, spec.z * length))
		rings.append(ring)
	kit.loft(rings, PackedFloat32Array([1, 1, 1, 1, 1, 1, 1, 1]), Transform3D.IDENTITY, color)
	# Two longitudinal moulded ridges taper into the upswept nose.
	for side in [-1.0, 1.0]:
		_tube(kit, PackedVector3Array([at + Vector3(side * 0.032, 0.032, length * 0.40), at + Vector3(side * 0.032, 0.035, -length * 0.30), at + Vector3(side * 0.026, 0.055, -length * 0.44), at + Vector3(side * 0.015, 0.12, -length * 0.55)]), 0.008, color.lightened(0.035), 6)


# --- Tefat: a low dished shell with broad lip and integral side grips ---

static func _saucer(kit: MeshKit) -> void:
	var green := Color(0.10, 0.69, 0.26, 0.62)
	var profile := PackedVector2Array([
		Vector2(0, 0.012), Vector2(0.22, 0.012), Vector2(0.34, 0.029), Vector2(0.45, 0.065),
		Vector2(0.54, 0.125), Vector2(0.59, 0.17), Vector2(0.615, 0.179), Vector2(0.623, 0.194),
		Vector2(0.614, 0.207), Vector2(0.58, 0.200), Vector2(0.535, 0.151), Vector2(0.44, 0.090),
		Vector2(0.32, 0.052), Vector2(0.20, 0.037), Vector2(0, 0.037),
	])
	kit.lathe(profile, Transform3D.IDENTITY, green, 64)
	for side in [-1.0, 1.0]:
		# A flat moulded bridge over the hand opening, not an upright torus.
		var grip := Transform3D(Basis(Vector3.FORWARD, side * 0.26), Vector3(side * 0.535, 0.205, 0))
		_handle(kit, grip, Vector2(0.072, 0.155), Vector2(0.037, 0.109), 0.026, green.darkened(0.10))
		for rib in 6:
			_tube(kit, PackedVector3Array([grip * Vector3(side * 0.041, 0.017, -0.085 + rib * 0.034), grip * Vector3(side * 0.065, 0.017, -0.085 + rib * 0.034)]), 0.003, green.lightened(0.10), 6)
	# Embossed centre and underside stiffening; all the same moulded plastic.
	kit.lathe(PackedVector2Array([Vector2(0, 0.038), Vector2(0.22, 0.038), Vector2(0.26, 0.043), Vector2(0.28, 0.047)]), Transform3D.IDENTITY, green.darkened(0.04), 48)
	for i in 12:
		var a := TAU * i / 12
		var axis := Vector3(cos(a), 0, sin(a))
		_tube(kit, PackedVector3Array([axis * 0.28 + Vector3(0, 0.012, 0), axis * 0.41 + Vector3(0, 0.047, 0), axis * 0.53 + Vector3(0, 0.113, 0)]), 0.008, green.darkened(0.10), 6)


# --- Wok: a spun carbon-steel bowl, riveted tang and turned wooden grips ---

static func _wok(kit: MeshKit) -> void:
	var steel := Color(0.27, 0.29, 0.31, 0.33)
	var bright := Color(0.58, 0.61, 0.63, 0.22)
	var profile := PackedVector2Array([
		Vector2(0, 0.014), Vector2(0.15, 0.014), Vector2(0.23, 0.027), Vector2(0.31, 0.057),
		Vector2(0.39, 0.108), Vector2(0.46, 0.171), Vector2(0.52, 0.238), Vector2(0.555, 0.29),
		Vector2(0.555, 0.298), Vector2(0.547, 0.30), Vector2(0.539, 0.288), Vector2(0.507, 0.240),
		Vector2(0.447, 0.176), Vector2(0.379, 0.116), Vector2(0.302, 0.068), Vector2(0.225, 0.039),
		Vector2(0.15, 0.027), Vector2(0, 0.027),
	])
	kit.lathe(profile, Transform3D.IDENTITY, steel, 80)
	kit.torus(0.545, 0.556, Transform3D(Basis.IDENTITY, Vector3(0, 0.296, 0)), bright, 80, 6)
	# The tang follows the wall before turning out into the ferrule.
	for side in [-1.0, 1.0]:
		_tube(kit, PackedVector3Array([Vector3(side * 0.044, 0.229, 0.48), Vector3(side * 0.036, 0.30, 0.56), Vector3(side * 0.025, 0.335, 0.64)]), 0.012, bright)
		kit.sphere(0.012, Vector3(side * 0.044, 0.235, 0.475), bright, Vector3(1, 1, 0.55), 10, 5)
	var wood := Color(0.66, 0.43, 0.23, 0.95)
	var handle := Transform3D(Basis(Vector3.RIGHT, PI / 2 - 0.16), Vector3(0, 0.33, 0.63))
	var grip_profile := PackedVector2Array([Vector2(0, 0), Vector2(0.040, 0), Vector2(0.043, 0.045), Vector2(0.047, 0.16), Vector2(0.044, 0.34), Vector2(0.040, 0.46), Vector2(0.031, 0.48), Vector2(0, 0.48)])
	kit.lathe(grip_profile, handle, wood, 24)
	kit.lathe(PackedVector2Array([Vector2(0.043, 0), Vector2(0.044, 0.045)]), handle, bright, 24)
	# Subtle longitudinal wood grain along the visible half of the handle.
	for i in 7:
		var a := PI * i / 6.0
		var grain := PackedVector3Array()
		for k in 9:
			var y := 0.065 + k * 0.047
			var radius := 0.046 - 0.006 * pow((y - 0.19) / 0.30, 2)
			grain.append(handle * Vector3(cos(a + sin(k * 0.6 + i) * 0.035) * radius, y, sin(a) * radius))
		_tube(kit, grain, 0.0011, wood.darkened(0.19), 5, false)
	var hanger := handle * Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0.50, 0))
	kit.torus(0.019, 0.024, hanger, bright, 20, 6)
	# Helper grip: two riveted steel lugs, bent arms and a short wooden bar.
	for side in [-1.0, 1.0]:
		_tube(kit, PackedVector3Array([Vector3(side * 0.09, 0.24, -0.48), Vector3(side * 0.12, 0.32, -0.57), Vector3(side * 0.11, 0.35, -0.67)]), 0.012, bright)
		kit.sphere(0.012, Vector3(side * 0.09, 0.243, -0.47), bright, Vector3(1, 1, 0.55), 10, 5)
	kit.capsule_between(Vector3(-0.10, 0.35, -0.67), Vector3(0.10, 0.35, -0.67), 0.025, wood, 12)


# --- Shared construction details ---

## Scooped sheets need a consistent up/down orientation even where a
## concave outline makes a radial normal test ambiguous near the neck.
static func _sheet(kit: MeshKit, rings: Array[PackedVector3Array], color: Color, up: bool) -> void:
	var base := kit._vertices.size()
	var count := rings[0].size()
	var linear := color.srgb_to_linear()
	linear.a = color.a
	for r in rings.size():
		for k in count:
			var along := rings[r][(k + 1) % count] - rings[r][(k - 1 + count) % count]
			var across := rings[mini(r + 1, rings.size() - 1)][k] - rings[maxi(r - 1, 0)][k]
			var n := along.cross(across).normalized()
			if (n.y < 0) == up: n = -n
			kit._vertices.append(rings[r][k])
			kit._normals.append(n)
			kit._colors.append(linear)
	for r in rings.size() - 1:
		for k in count:
			var a := base + r * count + k
			var b := base + r * count + (k + 1) % count
			var c := a + count
			var d := b + count
			kit._triangle_facing(a, c, b)
			kit._triangle_facing(b, c, d)


## Continuous rounded tubing, with no spheres or overlapping capsule joints.
static func _tube(kit: MeshKit, points: PackedVector3Array, radius: float, color: Color, sides := 8, smooth := true) -> void:
	var path := _smooth_path(points, false, 4) if smooth and points.size() > 2 else points
	var rings: Array[PackedVector3Array] = []
	var outward := PackedFloat32Array()
	for i in path.size():
		var tangent := (path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]).normalized()
		var basis := Basis(Quaternion(Vector3.UP, tangent))
		var ring := PackedVector3Array()
		for k in sides:
			var angle := TAU * k / sides
			ring.append(path[i] + basis * Vector3(cos(angle) * radius, 0, sin(angle) * radius))
		rings.append(ring)
		outward.append(1)
	kit.loft(rings, outward, Transform3D.IDENTITY, color)


static func _smooth_path(points: PackedVector3Array, closed := false, steps := 4) -> PackedVector3Array:
	var result := PackedVector3Array()
	var count := points.size()
	for i in count if closed else count - 1:
		var p0 := points[(i - 1 + count) % count] if closed else points[maxi(i - 1, 0)]
		var p1 := points[i]
		var p2 := points[(i + 1) % count]
		var p3 := points[(i + 2) % count] if closed else points[mini(i + 2, count - 1)]
		for j in steps:
			var t := float(j) / steps
			result.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t))
	if not closed: result.append(points[count - 1])
	return result


## A solid chamfered, rounded rectangle, specified by half extents in XZ.
static func _plate(kit: MeshKit, half: Vector2, at: Vector3, height: float, color: Color, rotation := Vector3.ZERO) -> void:
	var rings: Array[PackedVector3Array] = []
	for spec in [Vector2(0.01, 0), Vector2(0.92, 0), Vector2(1, height * 0.20), Vector2(1, height * 0.70), Vector2(0.93, height)]:
		rings.append(MeshKit.superellipse(half.x * spec.x, half.y * spec.x, spec.y, 32, 5.0))
	kit.loft(rings, PackedFloat32Array([1, 1, 1, 1, 1]), Transform3D(Basis.from_euler(rotation), at), color, true)


## Thick rounded rectangular loop with an actual opening, in the XZ plane.
static func _handle(kit: MeshKit, at: Transform3D, outer: Vector2, inner: Vector2, thickness: float, color: Color) -> void:
	var rings: Array[PackedVector3Array] = [
		MeshKit.superellipse(outer.x, outer.y, -thickness * 0.3, 40, 4),
		MeshKit.superellipse(outer.x, outer.y, thickness * 0.3, 40, 4),
		MeshKit.superellipse(outer.x * 0.97, outer.y * 0.97, thickness * 0.5, 40, 4),
		MeshKit.superellipse(inner.x, inner.y, thickness * 0.5, 40, 4),
		MeshKit.superellipse(inner.x, inner.y, -thickness * 0.5, 40, 4),
		MeshKit.superellipse(outer.x, outer.y, -thickness * 0.3, 40, 4),
	]
	kit.loft(rings, PackedFloat32Array([1, 1, 1, -1, -1, 1]), at, color)


# --- Rider ---

## The rider sitting on `model`: arms reach for the rope, wheel, pad strap
## or saucer handles, and legs sit the way that ride needs.
static func rider(jacket: Color, hat: Color, model := VehicleSpec.Model.PULKA) -> ArrayMesh:
	var kit := MeshKit.new()
	var scarf: Color = jacket.lerp(Color(1, 1, 1), 0.15).inverted().lerp(hat, 0.5)
	# Per VehicleSpec.Model: pulka (rope), stjärtlapp (strap), snowracer
	# (wheel), tefat and wok (rim).
	var hands: Vector3 = [Vector3(0.32, 0.24, -0.34), Vector3(0.08, 0.06, -0.36), Vector3(0.14, 0.32, -0.6), Vector3(0.5, 0.06, 0.0), Vector3(0.44, 0.12, 0.0)][model]
	var knees: Vector3 = [Vector3(0.11, 0.26, -0.27), Vector3(0.12, 0.3, -0.24), Vector3(0.16, 0.12, -0.32), Vector3(0.3, 0.16, -0.18), Vector3(0.28, 0.2, -0.16)][model]
	var feet: Vector3 = [Vector3(0.09, 0.1, -0.44), Vector3(0.12, 0.04, -0.5), Vector3(0.2, -0.24, -0.62), Vector3(0.1, 0.05, -0.34), Vector3(0.1, 0.08, -0.32)][model]
	for side in [-1.0, 1.0]:
		var mirror := Vector3(side, 1, 1)
		var hip := Vector3(0.11 * side, 0.1, 0.0)
		var knee: Vector3 = knees * mirror
		var foot: Vector3 = feet * mirror
		kit.capsule_between(hip, knee, 0.085, PANTS)
		kit.capsule_between(knee, foot + Vector3(0, 0.06, 0), 0.075, PANTS)
		kit.sphere(0.08, knee, PANTS.lightened(0.08), Vector3(1, 0.9, 1), 10, 6)
		kit.ellipsoid(Vector3(0.075, 0.075, 0.12), foot + Vector3(0, 0.02, -0.03), BOOTS)
		kit.box(Vector3(0.15, 0.03, 0.25), foot + Vector3(0, -0.045, -0.03), SOLE)
		var shoulder := Vector3(0.22 * side, 0.58, 0.02)
		var hand: Vector3 = hands * mirror
		var elbow := shoulder.lerp(hand, 0.5) + Vector3(0.07 * side, -0.07, 0.04)
		kit.capsule_between(shoulder, elbow, 0.07, jacket)
		kit.capsule_between(elbow, hand, 0.062, jacket)
		kit.cylinder(0.068, 0.05, hand.lerp(elbow, 0.12), jacket.lightened(0.3), 10)
		kit.sphere(0.07, hand, hat, Vector3(1, 0.85, 1.2), 10, 6)
		kit.sphere(0.03, hand + Vector3(-0.05 * side, 0.03, -0.02), hat, Vector3.ONE, 8, 4)
	# Puffer jacket: a padded torso with quilt seams, collar and zip.
	kit.capsule(0.2, 0.56, Vector3(0, 0.37, 0.03), jacket, Vector3(0.1, 0, 0), Vector3(1.0, 1.0, 0.85))
	for band in [0.26, 0.4, 0.52]:
		var y: float = band
		kit.cylinder(0.205, 0.025, Vector3(0, y, 0.035 + (y - 0.37) * 0.1), jacket.darkened(0.18), 18)
	kit.box(Vector3(0.025, 0.34, 0.02), Vector3(0, 0.39, -0.16), jacket.lightened(0.45))
	kit.cylinder(0.12, 0.09, Vector3(0, 0.63, 0.02), jacket.darkened(0.1), 16)
	# Striped scarf with tails fluttering behind.
	kit.cylinder(0.135, 0.05, Vector3(0, 0.675, 0.01), scarf, 16)
	kit.cylinder(0.133, 0.035, Vector3(0, 0.715, 0.01), Color(1, 1, 1), 16)
	for tail in 2:
		var start := Vector3(0.05 + tail * 0.04, 0.66, 0.12)
		var end := start + Vector3(0.04 + tail * 0.05, -0.22 - tail * 0.06, 0.24)
		kit.capsule_between(start, end, 0.035, scarf if tail == 0 else Color(1, 1, 1))
		for f in 3:
			kit.box(Vector3(0.012, 0.012, 0.06), end + Vector3(-0.02 + f * 0.02, 0, 0.05), scarf)
	head(kit, Vector3(0, 0.86, 0), hat)
	return kit.build()


## A simple round cartoon face: dark oval eyes with a glint, a small nose
## and smile, hair round the back and a beanie that sits above the eyes.
static func head(kit: MeshKit, at: Vector3, hat: Color) -> void:
	var skin := Palette.SKIN
	kit.sphere(0.15, at, skin, Vector3(1.0, 1.02, 0.97), 16, 10)
	kit.ellipsoid(Vector3(0.152, 0.125, 0.122), at + Vector3(0, 0.012, 0.042), HAIR)
	for side in [-1.0, 1.0]:
		kit.sphere(0.032, at + Vector3(0.147 * side, -0.02, 0.012), skin.darkened(0.05), Vector3(0.55, 1, 0.9), 8, 5)
		var eye := at + Vector3(0.056 * side, 0.002, -0.13)
		kit.ellipsoid(Vector3(0.017, 0.024, 0.01), eye, INK)
		kit.sphere(0.006, eye + Vector3(0.005, 0.009, -0.009), Color(1, 1, 1, 0.0), Vector3.ONE, 6, 4)
		kit.box(Vector3(0.042, 0.009, 0.012), at + Vector3(0.058 * side, 0.042, -0.128), HAIR)
		kit.sphere(0.03, at + Vector3(0.088 * side, -0.042, -0.097), skin.lerp(Color(1.0, 0.5, 0.5), 0.45), Vector3(1, 0.65, 0.3), 8, 5)
	kit.ellipsoid(Vector3(0.019, 0.017, 0.022), at + Vector3(0, -0.022, -0.146), skin.lerp(Color(1.0, 0.55, 0.5), 0.2))
	for k in 6:
		var t := (k - 2.5) / 2.5
		kit.box(Vector3(0.0135, 0.0075, 0.006), at + Vector3(t * 0.03, -0.07 + t * t * 0.012, -0.128 + t * t * 0.006), INK, Vector3(0, 0, atan(0.8 * t)))
	# Beanie with a folded cuff and a fluffy pom-pom.
	kit.sphere(0.15, at + Vector3(0, 0.072, 0.003), hat, Vector3(1, 1.12, 1), 16, 8, true)
	kit.cylinder(0.153, 0.066, at + Vector3(0, 0.09, 0.003), hat.darkened(0.2), 20)
	for i in 8:
		var angle := TAU * i / 8.0
		kit.box(Vector3(0.008, 0.062, 0.006), at + Vector3(cos(angle) * 0.153, 0.09, 0.003 + sin(angle) * 0.153), hat.darkened(0.3), Vector3(0, -angle, 0))
	var pom := at + Vector3(0, 0.26, 0.01)
	for offset in [Vector3.ZERO, Vector3(0.03, -0.01, 0), Vector3(-0.025, 0.0, 0.02), Vector3(0, 0.02, -0.025)]:
		kit.sphere(0.045, pom + offset, Color(1, 1, 1), Vector3.ONE, 8, 5)

