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
		return kit.build())


# --- Pulka: moulded plastic tub with a curled-up bow and a tow rope ---

static func _pulka(kit: MeshKit) -> void:
	var red := Color(0.86, 0.1, 0.12)
	var inside := Color(0.95, 0.25, 0.25)
	var rings: Array[PackedVector3Array] = [
		_tub_ring(0.84, 0.02, 0.10), _tub_ring(0.96, 0.12, 0.16), _tub_ring(1.0, 0.23, 0.17),
		_tub_ring(1.03, 0.27, 0.17), _tub_ring(0.95, 0.285, 0.17), _tub_ring(0.91, 0.22, 0.15),
		_tub_ring(0.84, 0.07, 0.08),
	]
	kit.loft(rings.slice(0, 4), PackedFloat32Array([1, 1, 1, 1]), Transform3D.IDENTITY, red)
	kit.loft(rings.slice(3, 5), PackedFloat32Array([1, 1]), Transform3D.IDENTITY, red.darkened(0.12))
	kit.loft(rings.slice(4, 7), PackedFloat32Array([-1, -1, -1]), Transform3D.IDENTITY, inside, true)
	# Moulded runners underneath.
	for side in [-1.0, 1.0]:
		kit.capsule(0.03, 1.05, Vector3(0.2 * side, 0.025, 0.06), red.darkened(0.25), Vector3(PI / 2, 0, 0))
	# Tow rope from two holes in the bow, looping forward.
	var rope := Color(1.0, 0.82, 0.15)
	var loop: Array[Vector3] = []
	for i in 9:
		var t := float(i) / 8.0
		var angle := PI * t
		loop.append(Vector3(-cos(angle) * 0.2, 0.38 + sin(angle) * 0.03, -0.66 - sin(angle) * 0.3))
	for i in loop.size() - 1:
		_capsule_between(kit, loop[i], loop[i + 1], 0.016, rope)
	for side in [-1.0, 1.0]:
		kit.cylinder(0.03, 0.04, Vector3(0.2 * side, 0.38, -0.66), red.darkened(0.4), 10, Vector3(PI / 2.5, 0, 0))


## One outline of the tub: a rounded oval whose front half rises into the bow.
static func _tub_ring(size: float, y: float, bow: float) -> PackedVector3Array:
	var ring := MeshKit.superellipse(0.37 * size, 0.66 * size, y, 32, 3.2)
	for i in ring.size():
		var p := ring[i]
		var front := clampf(-p.z / (0.66 * size), 0.0, 1.0)
		p.y += bow * pow(smoothstep(0.3, 1.0, front), 2.0)
		ring[i] = p
	return ring


# --- Stjärtlapp: a padded seat with a handle ---

static func _pad(kit: MeshKit) -> void:
	var blue := Color(0.15, 0.48, 0.95)
	var rings: Array[PackedVector3Array] = [
		MeshKit.superellipse(0.22, 0.28, 0.0, 28), MeshKit.superellipse(0.25, 0.31, 0.022, 28),
		MeshKit.superellipse(0.235, 0.295, 0.045, 28),
	]
	kit.loft(rings, PackedFloat32Array([1, 1, 1]), Transform3D.IDENTITY, blue, true)
	kit.box(Vector3(0.38, 0.006, 0.06), Vector3(0, 0.047, -0.05), Color(1, 1, 1))
	kit.box(Vector3(0.38, 0.006, 0.03), Vector3(0, 0.047, 0.05), Color(1.0, 0.82, 0.15))
	kit.torus(0.05, 0.075, Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, 0.05, -0.33)), Color(1.0, 0.82, 0.15), 18, 6)


# --- Snowracer: tubular frame, seat, steering wheel and three skis ---

static func _snowracer(kit: MeshKit) -> void:
	var red := Color(0.88, 0.1, 0.1)
	var steel := Color(0.78, 0.8, 0.83)
	var black := Color(0.1, 0.1, 0.12)
	for side in [-1.0, 1.0]:
		_ski(kit, Vector3(0.32 * side, 0.0, 0.25), 1.1, steel)
		_capsule_between(kit, Vector3(0.32 * side, 0.06, 0.05), Vector3(0.12 * side, 0.3, 0.1), 0.025, black)
		_capsule_between(kit, Vector3(0.32 * side, 0.06, 0.5), Vector3(0.12 * side, 0.3, 0.42), 0.025, black)
	_ski(kit, Vector3(0, 0.0, -0.92), 0.8, steel)
	_capsule_between(kit, Vector3(0, 0.06, -0.92), Vector3(0, 0.3, -0.72), 0.03, black)
	# Frame spine and rear axle bar.
	_capsule_between(kit, Vector3(0, 0.3, 0.48), Vector3(0, 0.33, -0.72), 0.045, red)
	_capsule_between(kit, Vector3(-0.14, 0.3, 0.26), Vector3(0.14, 0.3, 0.26), 0.04, red)
	# Front fairing with a racing stripe.
	kit.ellipsoid(Vector3(0.17, 0.11, 0.42), Vector3(0, 0.38, -0.42), red)
	kit.ellipsoid(Vector3(0.05, 0.112, 0.38), Vector3(0, 0.385, -0.42), Color(1, 1, 1))
	# Seat with a backrest.
	kit.capsule(0.11, 0.5, Vector3(0, 0.42, 0.2), black, Vector3(PI / 2, 0, 0), Vector3(1.6, 1.0, 0.45))
	kit.capsule(0.08, 0.36, Vector3(0, 0.6, 0.47), black, Vector3(0, 0, PI / 2), Vector3(1.0, 1.0, 0.55))
	# Steering column and wheel facing the rider.
	_capsule_between(kit, Vector3(0, 0.36, -0.72), Vector3(0, 0.72, -0.6), 0.025, black)
	var wheel := Transform3D(Basis(Vector3.RIGHT, PI / 2.0 - 0.55), Vector3(0, 0.74, -0.59))
	kit.torus(0.15, 0.2, wheel, Color(1.0, 0.8, 0.1), 24, 8)
	for i in 3:
		var angle := TAU * i / 3.0
		var spoke := Vector3(cos(angle) * 0.16, sin(angle) * 0.16, 0)
		_capsule_between(kit, wheel * Vector3.ZERO, wheel * Vector3(spoke.x, 0, spoke.y), 0.012, black)
	kit.sphere(0.035, wheel * Vector3.ZERO, black, Vector3.ONE, 10, 6)


static func _ski(kit: MeshKit, at: Vector3, length: float, color: Color) -> void:
	kit.box(Vector3(0.13, 0.035, length), at + Vector3(0, 0.02, 0), color)
	var tip := at + Vector3(0, 0.02, -length * 0.5)
	_capsule_between(kit, tip, tip + Vector3(0, 0.1, -0.12), 0.03, color)
	kit.box(Vector3(0.1, 0.03, length * 0.9), at + Vector3(0, 0.045, 0), Color(0.2, 0.2, 0.22))


# --- Tefat: a dished plastic saucer with a rolled rim and handles ---

static func _saucer(kit: MeshKit) -> void:
	var green := Color(0.15, 0.8, 0.35)
	var dish := PackedVector2Array([
		Vector2(0.0, 0.03), Vector2(0.15, 0.032), Vector2(0.3, 0.042), Vector2(0.42, 0.065),
		Vector2(0.52, 0.11), Vector2(0.58, 0.16),
	])
	kit.lathe(dish, Transform3D.IDENTITY, green, 28)
	kit.torus(0.565, 0.625, Transform3D(Basis.IDENTITY, Vector3(0, 0.165, 0)), green.darkened(0.15), 32, 8)
	for side in [-1.0, 1.0]:
		var handle := Transform3D(Basis(Vector3.FORWARD, PI / 2.0), Vector3(0.6 * side, 0.2, 0))
		kit.torus(0.06, 0.085, handle, Color(1.0, 0.82, 0.15), 16, 6)
	kit.lathe(PackedVector2Array([Vector2(0.0, 0.034), Vector2(0.18, 0.036)]), Transform3D.IDENTITY, Color(1, 1, 1), 20)


# --- Rider ---

## The rider sitting on `model`: arms reach for the rope, wheel, pad strap
## or saucer handles, and legs sit the way that ride needs.
static func rider(jacket: Color, hat: Color, model := VehicleSpec.Model.PULKA) -> ArrayMesh:
	var kit := MeshKit.new()
	var scarf: Color = jacket.lerp(Color(1, 1, 1), 0.15).inverted().lerp(hat, 0.5)
	var hands: Vector3 = [Vector3(0.32, 0.24, -0.34), Vector3(0.14, 0.32, -0.6), Vector3(0.08, 0.06, -0.36), Vector3(0.5, 0.06, 0.0)][model]
	var knees: Vector3 = [Vector3(0.13, 0.24, -0.3), Vector3(0.16, 0.12, -0.32), Vector3(0.12, 0.3, -0.24), Vector3(0.3, 0.16, -0.18)][model]
	var feet: Vector3 = [Vector3(0.13, 0.1, -0.5), Vector3(0.2, -0.24, -0.62), Vector3(0.12, 0.04, -0.5), Vector3(0.1, 0.05, -0.34)][model]
	for side in [-1.0, 1.0]:
		var mirror := Vector3(side, 1, 1)
		var hip := Vector3(0.11 * side, 0.1, 0.0)
		var knee: Vector3 = knees * mirror
		var foot: Vector3 = feet * mirror
		_capsule_between(kit, hip, knee, 0.085, PANTS)
		_capsule_between(kit, knee, foot + Vector3(0, 0.06, 0), 0.075, PANTS)
		kit.sphere(0.08, knee, PANTS.lightened(0.08), Vector3(1, 0.9, 1), 10, 6)
		kit.ellipsoid(Vector3(0.075, 0.075, 0.12), foot + Vector3(0, 0.02, -0.03), BOOTS)
		kit.box(Vector3(0.15, 0.03, 0.25), foot + Vector3(0, -0.045, -0.03), SOLE)
		var shoulder := Vector3(0.22 * side, 0.58, 0.02)
		var hand: Vector3 = hands * mirror
		var elbow := shoulder.lerp(hand, 0.5) + Vector3(0.07 * side, -0.07, 0.04)
		_capsule_between(kit, shoulder, elbow, 0.07, jacket)
		_capsule_between(kit, elbow, hand, 0.062, jacket)
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
		_capsule_between(kit, start, end, 0.035, scarf if tail == 0 else Color(1, 1, 1))
		for f in 3:
			kit.box(Vector3(0.012, 0.012, 0.06), end + Vector3(-0.02 + f * 0.02, 0, 0.05), scarf)
	_head(kit, Vector3(0, 0.86, 0), hat)
	return kit.build()


static func _head(kit: MeshKit, at: Vector3, hat: Color) -> void:
	var skin := Palette.SKIN
	kit.sphere(0.15, at, skin, Vector3(1.0, 1.02, 0.97), 16, 10)
	for side in [-1.0, 1.0]:
		kit.sphere(0.035, at + Vector3(0.148 * side, -0.01, 0.0), skin.darkened(0.05), Vector3(0.6, 1, 1), 8, 5)
		var eye := at + Vector3(0.055 * side, 0.02, -0.128)
		kit.sphere(0.03, eye, Color(1, 1, 1), Vector3(1, 1.1, 0.6), 10, 6)
		kit.sphere(0.018, eye + Vector3(0, -0.002, -0.014), INK, Vector3.ONE, 8, 5)
		kit.sphere(0.006, eye + Vector3(-0.007 * side, 0.008, -0.03), Color(1, 1, 1, 0.0), Vector3.ONE, 6, 4)
		kit.box(Vector3(0.05, 0.012, 0.015), eye + Vector3(0.0, 0.045, -0.002), HAIR, Vector3(0, 0, -0.18 * side))
		kit.sphere(0.03, at + Vector3(0.095 * side, -0.045, -0.105), Color(1.0, 0.58, 0.58), Vector3(1, 0.7, 0.5), 8, 5)
		kit.ellipsoid(Vector3(0.05, 0.03, 0.04), at + Vector3(0.12 * side, 0.03, 0.04), HAIR)
	kit.ellipsoid(Vector3(0.028, 0.032, 0.04), at + Vector3(0, -0.015, -0.15), skin.darkened(0.08))
	for k in 5:
		var t := (k - 2) / 2.0
		kit.sphere(0.008, at + Vector3(t * 0.035, -0.07 + t * t * 0.015, -0.135), INK, Vector3.ONE, 6, 4)
	# Beanie with a folded cuff and a fluffy pom-pom.
	kit.sphere(0.162, at + Vector3(0, 0.035, 0.005), hat, Vector3(1, 1.18, 1), 16, 8, true)
	kit.cylinder(0.166, 0.075, at + Vector3(0, 0.055, 0.005), hat.darkened(0.2), 20)
	for i in 8:
		var angle := TAU * i / 8.0
		kit.box(Vector3(0.012, 0.07, 0.01), at + Vector3(cos(angle) * 0.167, 0.055, sin(angle) * 0.167), hat.darkened(0.3), Vector3(0, -angle, 0))
	var pom := at + Vector3(0, 0.235, 0.01)
	for offset in [Vector3.ZERO, Vector3(0.03, -0.01, 0), Vector3(-0.025, 0.0, 0.02), Vector3(0, 0.02, -0.025)]:
		kit.sphere(0.045, pom + offset, Color(1, 1, 1), Vector3.ONE, 8, 5)


## A capsule spanning from a to b.
static func _capsule_between(kit: MeshKit, a: Vector3, b: Vector3, radius: float, color: Color) -> void:
	var span := b - a
	if span.length() < 0.001:
		return
	var turn := Basis(Quaternion(Vector3.UP, span.normalized()))
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = span.length() + radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 3
	kit.add(mesh, Transform3D(turn, (a + b) * 0.5), color)
