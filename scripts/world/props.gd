class_name Props
extends RefCounted
## Procedural models. Every model is built once per variant, cached and
## shared. Convention: origin at ground level, front facing -Z.

static var _cache: Dictionary = {}


static func cached_mesh(key: String, builder: Callable) -> ArrayMesh:
	if not _cache.has(key):
		_cache[key] = builder.call()
	return _cache[key]


# --- Rigs: a body plus jointed limbs that obstacles can animate ---

## A limb hangs from `pivot` (in body space) and swings around its local X.
class Limb:
	var mesh: ArrayMesh
	var pivot: Vector3
	var phase: float
	var swing: float
	## Waves instead of swinging when its owner stands still.
	var waves: bool

	func _init(limb_mesh: ArrayMesh, at: Vector3, limb_phase: float, amount: float, waving := false) -> void:
		mesh = limb_mesh
		pivot = at
		phase = limb_phase
		swing = amount
		waves = waving


class Rig:
	var body: ArrayMesh
	var limbs: Array[Limb] = []
	## Gait cycle in radians per metre travelled.
	var stride := 0.0

	static func of(mesh: ArrayMesh) -> Rig:
		var rig := Rig.new()
		rig.body = mesh
		return rig


static var _rigs: Dictionary = {}


static func cached_rig(key: String, builder: Callable) -> Rig:
	if not _rigs.has(key):
		_rigs[key] = builder.call()
	return _rigs[key]


## Four legs in a trotting gait (diagonal pairs move together).
static func _legs(rig: Rig, leg: ArrayMesh, half_width: float, front_z: float, back_z: float, hip_y: float, swing: float) -> void:
	rig.limbs.append(Limb.new(leg, Vector3(-half_width, hip_y, front_z), 0.0, swing))
	rig.limbs.append(Limb.new(leg, Vector3(half_width, hip_y, front_z), PI, swing))
	rig.limbs.append(Limb.new(leg, Vector3(-half_width, hip_y, back_z), PI, swing))
	rig.limbs.append(Limb.new(leg, Vector3(half_width, hip_y, back_z), 0.0, swing))


# --- Nature ---

static func spruce(variant: int) -> ArrayMesh:
	return cached_mesh("spruce%d" % variant, func() -> ArrayMesh:
		var kit := MeshKit.new()
		var green: Color = Palette.SPRUCE[variant % Palette.SPRUCE.size()]
		kit.cylinder(0.18, 1.4, Vector3(0, 0.7, 0), Palette.TRUNK, 8, Vector3.ZERO, 0.12)
		var tiers := 5 + variant % 2
		for i in tiers:
			var f := float(i) / tiers
			var radius := lerpf(1.75, 0.45, f)
			var tall := lerpf(1.7, 0.9, f)
			var y := 0.8 + i * 0.78
			var twist := Vector3(0.04 * sin(i * 2.3), i * 0.7, 0.04 * cos(i * 1.7))
			kit.cone(radius, tall, Vector3(0, y + tall * 0.5, 0), green.darkened(0.08 * (1.0 - f)), 11, twist)
			kit.cone(radius * 0.7, tall * 0.5, Vector3(0, y + tall * 0.42 + tall * 0.25, 0), Palette.SNOW, 11, twist)
		kit.cone(0.3, 0.7, Vector3(0, 0.8 + tiers * 0.78 + 0.25, 0), Palette.SNOW, 9)
		return kit.build())


static func birch() -> ArrayMesh:
	return cached_mesh("birch", func() -> ArrayMesh:
		var kit := MeshKit.new()
		var bark := Color(0.93, 0.92, 0.88)
		var twig := Color(0.45, 0.38, 0.32)
		kit.cylinder(0.15, 5.0, Vector3(0, 2.5, 0), bark, 10, Vector3.ZERO, 0.07)
		for i in 6:
			kit.cylinder(0.15 - i * 0.012, 0.07, Vector3(0, 0.5 + i * 0.75, 0), Color(0.15, 0.14, 0.13), 10, Vector3(0.1 * sin(i * 3.0), 0, 0.1 * cos(i * 2.0)))
		for i in 5:
			var angle := i * 2.4
			var height := 2.6 + i * 0.5
			var dir := Vector3(cos(angle), 0, sin(angle))
			kit.cylinder(0.035, 1.5 - i * 0.15, Vector3(0, height, 0) + dir * 0.55, twig, 6, Vector3(dir.z * 0.9, 0, -dir.x * 0.9), 0.01)
		kit.ellipsoid(Vector3(0.18, 0.08, 0.18), Vector3(0, 5.0, 0), Palette.SNOW)
		return kit.build())


static func rock(variant: int) -> ArrayMesh:
	return cached_mesh("rock%d" % variant, func() -> ArrayMesh:
		var kit := MeshKit.new()
		var main := Vector3(1.15, 0.7, 0.95) if variant == 0 else Vector3(0.9, 0.85, 1.1)
		kit.ellipsoid(main, Vector3(0, 0.3, 0), Palette.ROCK, Vector3(0.1, variant, 0.05))
		kit.ellipsoid(main * 0.55, Vector3(0.6, 0.15, 0.4), Palette.ROCK.darkened(0.1), Vector3(0.3, 1.0, 0))
		kit.ellipsoid(Vector3(main.x * 0.85, 0.3, main.z * 0.8), Vector3(0, 0.75, 0), Palette.SNOW, Vector3(0.1, variant, 0.05))
		return kit.build())


static func stump() -> ArrayMesh:
	return cached_mesh("stump", func() -> ArrayMesh:
		var kit := MeshKit.new()
		kit.cylinder(0.42, 0.55, Vector3(0, 0.27, 0), Palette.TRUNK, 12, Vector3.ZERO, 0.38)
		kit.ellipsoid(Vector3(0.42, 0.1, 0.42), Vector3(0, 0.56, 0), Palette.SNOW)
		for i in 3:
			var angle := i * 2.1
			kit.capsule(0.08, 0.6, Vector3(cos(angle) * 0.4, 0.06, sin(angle) * 0.4), Palette.TRUNK, Vector3(0, -angle, PI / 2.2))
		return kit.build())


static func snowman() -> ArrayMesh:
	return cached_mesh("snowman", func() -> ArrayMesh:
		var kit := MeshKit.new()
		kit.sphere(0.58, Vector3(0, 0.5, 0), Palette.SNOW)
		kit.sphere(0.43, Vector3(0, 1.2, 0), Palette.SNOW)
		kit.sphere(0.31, Vector3(0, 1.72, 0), Palette.SNOW)
		kit.cone(0.06, 0.38, Vector3(0, 1.72, -0.45), Color(1.0, 0.5, 0.1), 8, Vector3(-PI / 2, 0, 0))
		for side in [-1.0, 1.0]:
			kit.sphere(0.04, Vector3(0.11 * side, 1.82, -0.27), Color(0.05, 0.05, 0.05))
			kit.cylinder(0.025, 0.9, Vector3(0.68 * side, 1.35, 0), Palette.TRUNK, 6, Vector3(0, 0, -side * 1.0), 0.012)
		for i in 3:
			kit.sphere(0.045, Vector3(0, 1.0 + i * 0.17, -0.42 + absf(i - 1) * 0.02), Color(0.05, 0.05, 0.05))
		kit.cylinder(0.34, 0.08, Vector3(0, 1.46, 0), Color(0.85, 0.15, 0.15), 14)
		kit.capsule(0.06, 0.4, Vector3(0.15, 1.3, -0.3), Color(0.85, 0.15, 0.15), Vector3(-0.3, 0, 0.2))
		kit.cylinder(0.33, 0.04, Vector3(0, 1.98, 0), Color(0.08, 0.08, 0.1), 14)
		kit.cylinder(0.2, 0.34, Vector3(0, 2.15, 0), Color(0.08, 0.08, 0.1), 14)
		return kit.build())


# --- People and animals ---

static func person(variant: int) -> Rig:
	var jacket: Color = Palette.JACKETS[variant % Palette.JACKETS.size()]
	var hat: Color = Palette.JACKETS[(variant + 3) % Palette.JACKETS.size()]
	var scarf: Color = Palette.JACKETS[(variant + 5) % Palette.JACKETS.size()]
	var pants := Color(0.12, 0.14, 0.25) if variant % 2 == 0 else Color(0.25, 0.2, 0.18)
	return dressed("person%d" % variant, jacket, hat, scarf, pants)


## A person in the given clothes. `bathing` swaps the winter gear for a
## swimsuit; `stick` adds a bandy stick in the right hand.
static func dressed(key: String, jacket: Color, hat: Color, scarf: Color, pants: Color, bathing := false, stick := false) -> Rig:
	return cached_rig(key, func() -> Rig:
		var skin := Palette.SKIN
		var top := skin if bathing else jacket
		var legs := skin if bathing else pants
		var kit := MeshKit.new()
		kit.capsule(0.21, 0.74, Vector3(0, 1.2, 0), top, Vector3.ZERO, Vector3(1, 1, 0.8))
		kit.ellipsoid(Vector3(0.19, 0.13, 0.15), Vector3(0, 0.92, 0), jacket if bathing else pants)
		kit.sphere(0.15, Vector3(0, 1.72, 0), skin)
		kit.ellipsoid(Vector3(0.03, 0.035, 0.045), Vector3(0, 1.7, -0.15), skin.darkened(0.1))
		for side in [-1.0, 1.0]:
			kit.sphere(0.022, Vector3(0.055 * side, 1.75, -0.135), Color(0.05, 0.05, 0.05))
			kit.sphere(0.03, Vector3(0.09 * side, 1.68, -0.12), Color(1.0, 0.6, 0.6))
		kit.sphere(0.16, Vector3(0, 1.75, 0), hat, Vector3(1, 1.15, 1), 14, 6, true)
		kit.cylinder(0.163, 0.07, Vector3(0, 1.77, 0), hat.darkened(0.2), 14)
		kit.sphere(0.065, Vector3(0, 1.95, 0), Color(1, 1, 1))
		if not bathing:
			kit.cylinder(0.14, 0.09, Vector3(0, 1.55, 0), scarf, 14)
			kit.capsule(0.04, 0.32, Vector3(0.08, 1.4, -0.14), scarf, Vector3(0.1, 0, 0.1))
		var rig := Rig.of(kit.build())
		rig.stride = 4.0
		var leg := MeshKit.new()
		leg.capsule(0.085, 0.86, Vector3(0, -0.43, 0), legs)
		leg.ellipsoid(Vector3(0.08, 0.07, 0.13), Vector3(0, -0.86, -0.04), skin if bathing else Color(0.2, 0.13, 0.1))
		var leg_mesh := leg.build()
		var arm := MeshKit.new()
		arm.capsule(0.065, 0.58, Vector3(0, -0.26, 0), top)
		arm.sphere(0.075, Vector3(0, -0.57, 0), skin if bathing else hat)
		var arm_mesh := arm.build()
		var right_arm := arm_mesh
		if stick:
			var holding := MeshKit.new()
			holding.capsule(0.065, 0.58, Vector3(0, -0.26, 0), top)
			holding.sphere(0.075, Vector3(0, -0.57, 0), hat)
			holding.cylinder(0.025, 1.1, Vector3(0, -0.6, -0.45), Color(0.6, 0.45, 0.25), 6, Vector3(PI / 2.4, 0, 0))
			holding.box(Vector3(0.08, 0.06, 0.3), Vector3(0, -0.85, -0.95), Color(0.6, 0.45, 0.25), Vector3(0.4, 0, 0))
			right_arm = holding.build()
		rig.limbs.append(Limb.new(leg_mesh, Vector3(-0.1, 0.92, 0), 0.0, 0.55))
		rig.limbs.append(Limb.new(leg_mesh, Vector3(0.1, 0.92, 0), PI, 0.55))
		rig.limbs.append(Limb.new(arm_mesh, Vector3(-0.27, 1.45, 0), PI, 0.45))
		rig.limbs.append(Limb.new(right_arm, Vector3(0.27, 1.45, 0), 0.0, 0.45, not stick))
		return rig)


static func dog() -> Rig:
	return cached_rig("dog", func() -> Rig:
		var fur := Color(0.62, 0.42, 0.22)
		var dark := Color(0.42, 0.27, 0.14)
		var kit := MeshKit.new()
		kit.ellipsoid(Vector3(0.18, 0.18, 0.4), Vector3(0, 0.5, 0.02), fur)
		kit.ellipsoid(Vector3(0.17, 0.2, 0.18), Vector3(0, 0.55, -0.28), fur)
		kit.capsule(0.09, 0.3, Vector3(0, 0.66, -0.38), fur, Vector3(-0.7, 0, 0))
		kit.sphere(0.14, Vector3(0, 0.78, -0.47), fur)
		kit.ellipsoid(Vector3(0.075, 0.065, 0.12), Vector3(0, 0.74, -0.61), Color(0.8, 0.65, 0.45))
		kit.sphere(0.035, Vector3(0, 0.77, -0.72), Color(0.05, 0.05, 0.05))
		for side in [-1.0, 1.0]:
			kit.sphere(0.022, Vector3(0.06 * side, 0.83, -0.58), Color(0.05, 0.05, 0.05))
			kit.ellipsoid(Vector3(0.04, 0.12, 0.07), Vector3(0.12 * side, 0.74, -0.44), dark, Vector3(0, 0, side * 0.35))
		kit.capsule(0.035, 0.36, Vector3(0, 0.66, 0.46), fur, Vector3(0.8, 0, 0))
		kit.cylinder(0.105, 0.05, Vector3(0, 0.64, -0.37), Color(0.9, 0.1, 0.1), 14, Vector3(-0.7, 0, 0))
		var rig := Rig.of(kit.build())
		rig.stride = 4.0
		var leg := MeshKit.new()
		leg.capsule(0.05, 0.42, Vector3(0, -0.2, 0), fur)
		leg.sphere(0.055, Vector3(0, -0.41, -0.02), dark)
		_legs(rig, leg.build(), 0.1, -0.27, 0.27, 0.45, 0.6)
		return rig)


static func moose() -> Rig:
	return cached_rig("moose", func() -> Rig:
		var fur := Color(0.3, 0.2, 0.13)
		var face := Color(0.26, 0.17, 0.11)
		var antler := Color(0.86, 0.79, 0.62)
		var kit := MeshKit.new()
		kit.ellipsoid(Vector3(0.55, 0.6, 1.2), Vector3(0, 1.75, 0), fur)
		kit.ellipsoid(Vector3(0.5, 0.55, 0.6), Vector3(0, 2.05, -0.65), fur)
		kit.ellipsoid(Vector3(0.48, 0.5, 0.55), Vector3(0, 1.75, 0.75), fur)
		kit.capsule(0.25, 0.95, Vector3(0, 2.05, -1.25), fur, Vector3(-1.1, 0, 0))
		kit.ellipsoid(Vector3(0.22, 0.26, 0.42), Vector3(0, 2.15, -1.8), face, Vector3(0.35, 0, 0))
		kit.ellipsoid(Vector3(0.2, 0.22, 0.28), Vector3(0, 1.98, -2.12), face.darkened(0.15))
		kit.ellipsoid(Vector3(0.06, 0.2, 0.08), Vector3(0, 1.8, -1.78), face)
		for side in [-1.0, 1.0]:
			kit.sphere(0.035, Vector3(0.08 * side, 1.98, -2.38), Color(0.02, 0.02, 0.02))
			kit.sphere(0.04, Vector3(0.2 * side, 2.25, -1.85), Color(0.02, 0.02, 0.02))
			kit.ellipsoid(Vector3(0.06, 0.18, 0.1), Vector3(0.22 * side, 2.42, -1.62), fur, Vector3(0, 0, side * 0.7))
			kit.capsule(0.05, 0.4, Vector3(0.18 * side, 2.45, -1.68), antler, Vector3(0, 0, -side * 1.1))
			kit.ellipsoid(Vector3(0.48, 0.05, 0.3), Vector3(0.55 * side, 2.62, -1.62), antler, Vector3(0.15, 0, side * 0.35))
			for tine in 4:
				var x: float = (0.35 + tine * 0.17) * side
				kit.cone(0.04, 0.28, Vector3(x, 2.72 + tine * 0.06, -1.45 - tine * 0.05), antler, 7, Vector3(0.3, 0, -side * 0.2))
		kit.capsule(0.06, 0.2, Vector3(0, 1.95, 1.3), fur, Vector3(0.5, 0, 0))
		var rig := Rig.of(kit.build())
		rig.stride = 2.2
		var leg := MeshKit.new()
		var shin := Color(0.58, 0.5, 0.42)
		leg.capsule(0.15, 0.8, Vector3(0, -0.3, 0), fur)
		leg.capsule(0.075, 0.9, Vector3(0, -1.0, 0), shin)
		leg.cylinder(0.085, 0.12, Vector3(0, -1.47, -0.02), Color(0.12, 0.1, 0.08), 10)
		_legs(rig, leg.build(), 0.3, -0.75, 0.8, 1.55, 0.45)
		return rig)


static func deer() -> Rig:
	return cached_rig("deer", func() -> Rig:
		var fur := Color(0.64, 0.43, 0.26)
		var kit := MeshKit.new()
		kit.ellipsoid(Vector3(0.24, 0.27, 0.55), Vector3(0, 1.05, 0), fur)
		kit.ellipsoid(Vector3(0.18, 0.15, 0.1), Vector3(0, 1.08, 0.5), Color(0.97, 0.96, 0.93))
		kit.capsule(0.1, 0.6, Vector3(0, 1.38, -0.5), fur, Vector3(-0.6, 0, 0))
		kit.ellipsoid(Vector3(0.12, 0.13, 0.22), Vector3(0, 1.62, -0.72), fur, Vector3(0.3, 0, 0))
		kit.sphere(0.03, Vector3(0, 1.57, -0.93), Color(0.05, 0.05, 0.05))
		for side in [-1.0, 1.0]:
			kit.sphere(0.025, Vector3(0.09 * side, 1.66, -0.78), Color(0.05, 0.05, 0.05))
			kit.ellipsoid(Vector3(0.04, 0.12, 0.07), Vector3(0.13 * side, 1.76, -0.66), fur, Vector3(0, 0, side * 0.6))
			kit.capsule(0.022, 0.32, Vector3(0.06 * side, 1.86, -0.68), Color(0.45, 0.35, 0.25), Vector3(0, 0, -side * 0.3))
		var rig := Rig.of(kit.build())
		rig.stride = 2.4
		var leg := MeshKit.new()
		leg.capsule(0.07, 0.5, Vector3(0, -0.2, 0), fur)
		leg.capsule(0.04, 0.55, Vector3(0, -0.62, 0), fur.darkened(0.1))
		leg.cylinder(0.045, 0.06, Vector3(0, -0.9, 0), Color(0.1, 0.08, 0.06), 8)
		_legs(rig, leg.build(), 0.14, -0.38, 0.38, 0.95, 0.6)
		return rig)


static func hare() -> Rig:
	return cached_rig("hare", func() -> Rig:
		var fur := Color(0.92, 0.92, 0.95)
		var kit := MeshKit.new()
		kit.ellipsoid(Vector3(0.18, 0.18, 0.27), Vector3(0, 0.22, 0.05), fur)
		kit.ellipsoid(Vector3(0.12, 0.11, 0.2), Vector3(0, 0.16, 0.2), fur)
		kit.sphere(0.12, Vector3(0, 0.38, -0.24), fur)
		kit.sphere(0.022, Vector3(0, 0.37, -0.36), Color(0.9, 0.55, 0.6))
		for side in [-1.0, 1.0]:
			kit.ellipsoid(Vector3(0.04, 0.17, 0.025), Vector3(0.05 * side, 0.6, -0.2), fur, Vector3(0.25, 0, side * 0.2))
			kit.sphere(0.02, Vector3(0.075 * side, 0.41, -0.33), Color(0.05, 0.05, 0.05))
			kit.ellipsoid(Vector3(0.04, 0.03, 0.09), Vector3(0.08 * side, 0.03, -0.12), fur)
		kit.sphere(0.06, Vector3(0, 0.27, 0.33), Color(1, 1, 1))
		return Rig.of(kit.build()))


# --- Vehicles on the roads ---

static func car(variant: int) -> ArrayMesh:
	return cached_mesh("car%d" % variant, func() -> ArrayMesh:
		var kit := MeshKit.new()
		var paint: Color = Palette.CARS[variant % Palette.CARS.size()]
		var glass := Color(0.2, 0.28, 0.38)
		kit.box(Vector3(1.8, 0.65, 4.4), Vector3(0, 0.62, 0), paint)
		kit.box(Vector3(1.7, 0.62, 2.7), Vector3(0, 1.25, 0.45), paint)
		kit.box(Vector3(1.72, 0.48, 2.5), Vector3(0, 1.24, 0.45), glass)
		kit.box(Vector3(1.6, 0.12, 2.5), Vector3(0, 1.6, 0.45), Palette.SNOW)
		kit.box(Vector3(1.85, 0.2, 4.45), Vector3(0, 0.36, 0), Color(0.12, 0.12, 0.13))
		for side in [-1.0, 1.0]:
			kit.box(Vector3(0.38, 0.2, 0.05), Vector3(0.6 * side, 0.72, -2.21), Palette.HEADLIGHT)
			kit.box(Vector3(0.3, 0.2, 0.05), Vector3(0.65 * side, 0.75, 2.21), Palette.TAILLIGHT)
			for axle in [-1.35, 1.35]:
				kit.cylinder(0.36, 0.28, Vector3(0.8 * side, 0.36, axle), Color(0.06, 0.06, 0.07), 16, Vector3(0, 0, PI / 2))
		return kit.build())


static func plow() -> ArrayMesh:
	return cached_mesh("plow", func() -> ArrayMesh:
		var kit := MeshKit.new()
		var yellow := Color(1.0, 0.72, 0.05)
		kit.box(Vector3(2.4, 1.6, 2.2), Vector3(0, 1.75, -1.6), yellow)
		kit.box(Vector3(2.3, 0.7, 2.0), Vector3(0, 2.1, -1.7), Color(0.2, 0.28, 0.38))
		kit.box(Vector3(2.4, 1.3, 4.2), Vector3(0, 1.4, 1.7), Color(0.3, 0.3, 0.32))
		kit.box(Vector3(2.5, 0.4, 7.0), Vector3(0, 0.75, 0.3), Color(0.12, 0.12, 0.13))
		kit.box(Vector3(3.6, 1.1, 0.25), Vector3(0, 0.6, -3.4), Color(0.9, 0.35, 0.05), Vector3(0, 0.35, 0))
		kit.box(Vector3(0.4, 0.22, 0.4), Vector3(0, 2.65, -1.6), Color(1.0, 0.55, 0.0, 0.0))
		for side in [-1.0, 1.0]:
			kit.box(Vector3(0.35, 0.2, 0.05), Vector3(0.85 * side, 1.25, -2.72), Palette.HEADLIGHT)
			for axle in [-1.6, 1.0, 2.6]:
				kit.cylinder(0.55, 0.4, Vector3(1.15 * side, 0.55, axle), Color(0.06, 0.06, 0.07), 16, Vector3(0, 0, PI / 2))
		return kit.build())


# --- Buildings and roadside furniture ---

static func house(variant: int) -> ArrayMesh:
	return cached_mesh("house%d" % variant, func() -> ArrayMesh:
		var kit := MeshKit.new()
		var walls: Color = [Palette.FALU_RED, Color(0.95, 0.8, 0.35), Color(0.93, 0.92, 0.86), Color(0.55, 0.7, 0.85), Palette.FALU_RED][variant % 5]
		var trim := Color(0.97, 0.97, 0.95) if variant % 5 != 2 else Color(0.35, 0.4, 0.5)
		var width := 7.5 + (variant % 3) * 1.3
		var depth := 6.5 + (variant % 2) * 1.0
		var wall_h := 3.0 + (variant % 2) * 2.4
		var floors := 1 if wall_h < 4.0 else 2
		var bottom := -2.5
		var wall_size := Vector3(width, wall_h - bottom, depth)
		kit.box(wall_size, Vector3(0, (wall_h + bottom) * 0.5, 0), walls)
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				kit.box(Vector3(0.22, wall_h - bottom, 0.22), Vector3(sx * width * 0.5, (wall_h + bottom) * 0.5, sz * depth * 0.5), trim)
		var roof_h := 2.4 + width * 0.08
		kit.prism(Vector3(depth + 0.9, roof_h, width + 0.7), Vector3(0, wall_h + roof_h * 0.5, 0), Color(0.22, 0.22, 0.26), Vector3(0, PI / 2, 0))
		roof_snow(kit, width + 0.8, depth + 0.9, roof_h, wall_h)
		kit.box(Vector3(0.7, 1.6, 0.7), Vector3(width * 0.25, wall_h + roof_h * 0.75, 0.6), Color(0.55, 0.2, 0.15))
		kit.box(Vector3(0.8, 0.2, 0.8), Vector3(width * 0.25, wall_h + roof_h * 0.75 + 0.85, 0.6), Palette.SNOW)
		kit.box(Vector3(1.0, 2.0, 0.1), Vector3(0, 1.0, -depth * 0.5 - 0.03), Color(0.3, 0.2, 0.15))
		kit.box(Vector3(1.3, 0.1, 0.3), Vector3(0, 2.1, -depth * 0.5 - 0.1), trim)
		for floor_index in floors:
			var y := 1.5 + floor_index * 2.4
			for wx in [-width * 0.32, width * 0.32]:
				for face in [-1.0, 1.0]:
					var z: float = face * (depth * 0.5 + 0.04)
					kit.box(Vector3(1.2, 1.1, 0.1), Vector3(wx, y, z), trim)
					kit.box(Vector3(0.95, 0.85, 0.12), Vector3(wx, y, z), Palette.WINDOW_LIGHT)
			for face in [-1.0, 1.0]:
				kit.box(Vector3(0.1, 1.1, 1.2), Vector3(face * (width * 0.5 + 0.04), y, 0), trim)
				kit.box(Vector3(0.12, 0.85, 0.95), Vector3(face * (width * 0.5 + 0.04), y, 0), Palette.WINDOW_LIGHT)
		return kit.build())


static func edge_pole(variant: int) -> ArrayMesh:
	return cached_mesh("pole%d" % variant, func() -> ArrayMesh:
		var kit := MeshKit.new()
		var color := Color(1.0, 0.42, 0.05) if variant == 0 else Color(0.1, 0.35, 0.95)
		kit.cylinder(0.05, 1.6, Vector3(0, 0.8, 0), color, 5)
		kit.cylinder(0.055, 0.2, Vector3(0, 1.35, 0), Color(1, 1, 1), 5)
		return kit.build())


static func lamp_post() -> ArrayMesh:
	return cached_mesh("lamp", func() -> ArrayMesh:
		var kit := MeshKit.new()
		var metal := Color(0.2, 0.22, 0.25)
		kit.cylinder(0.09, 5.0, Vector3(0, 2.5, 0), metal, 6)
		kit.box(Vector3(0.1, 0.1, 1.3), Vector3(0, 4.95, -0.6), metal)
		kit.box(Vector3(0.35, 0.18, 0.6), Vector3(0, 4.85, -1.2), metal)
		kit.box(Vector3(0.3, 0.06, 0.5), Vector3(0, 4.74, -1.2), Color(1.0, 0.85, 0.55, 0.0))
		kit.box(Vector3(0.36, 0.08, 0.62), Vector3(0, 4.98, -1.2), Palette.SNOW)
		return kit.build())


static func fence() -> ArrayMesh:
	return cached_mesh("fence", func() -> ArrayMesh:
		var kit := MeshKit.new()
		var wood := Color(0.55, 0.38, 0.24)
		for i in 5:
			kit.box(Vector3(0.1, 1.1, 0.1), Vector3(-2.0 + i, 0.55, 0), wood)
		kit.box(Vector3(4.2, 0.1, 0.06), Vector3(0, 0.75, 0), wood)
		kit.box(Vector3(4.2, 0.1, 0.06), Vector3(0, 0.35, 0), wood)
		kit.box(Vector3(4.2, 0.08, 0.14), Vector3(0, 0.82, 0), Palette.SNOW)
		return kit.build())


## Swedish give-way sign: a downward triangle, yellow with a red border.
static func yield_sign() -> ArrayMesh:
	return cached_mesh("yield", func() -> ArrayMesh:
		var kit := MeshKit.new()
		kit.cylinder(0.05, 2.2, Vector3(0, 1.1, 0), Color(0.55, 0.57, 0.6), 8)
		var flip := Vector3(0, 0, PI)
		kit.prism(Vector3(1.0, 0.87, 0.04), Vector3(0, 2.25, 0.05), Color(0.85, 0.1, 0.1), flip)
		kit.prism(Vector3(0.68, 0.59, 0.05), Vector3(0, 2.34, 0.06), Color(1.0, 0.82, 0.1), flip)
		kit.prism(Vector3(1.0, 0.87, 0.04), Vector3(0, 2.25, 0.0), Color(0.6, 0.62, 0.65), flip)
		kit.box(Vector3(1.0, 0.06, 0.12), Vector3(0, 2.7, 0.03), Palette.SNOW)
		return kit.build())


static func ramp_flag() -> ArrayMesh:
	return cached_mesh("flag", func() -> ArrayMesh:
		var kit := MeshKit.new()
		kit.cylinder(0.04, 2.0, Vector3(0, 1.0, 0), Color(0.9, 0.9, 0.9), 5)
		kit.box(Vector3(0.03, 0.4, 0.6), Vector3(0, 1.75, 0.3), Color(0.95, 0.15, 0.2))
		return kit.build())


static func sign_node(text: String, color: Color) -> Node3D:
	var root := Node3D.new()
	var kit := MeshKit.new()
	kit.cylinder(0.07, 2.4, Vector3(-1.2, 1.2, 0), Color(0.5, 0.5, 0.55), 5)
	kit.cylinder(0.07, 2.4, Vector3(1.2, 1.2, 0), Color(0.5, 0.5, 0.55), 5)
	kit.box(Vector3(3.0, 1.2, 0.08), Vector3(0, 2.4, 0), color)
	kit.box(Vector3(3.1, 0.12, 0.2), Vector3(0, 3.06, 0), Palette.SNOW)
	var mesh := MeshInstance3D.new()
	mesh.mesh = kit.build()
	root.add_child(mesh)
	var label := Label3D.new()
	label.text = text
	label.font_size = 48
	label.pixel_size = 0.0075
	label.outline_size = 0
	label.modulate = Color(1, 1, 1)
	label.position = Vector3(0, 2.4, 0.06)
	label.width = 380.0
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.double_sided = false
	label.shaded = false
	root.add_child(label)
	return root


# --- Town ---

const SHOP_NAMES := [
	"Bageri", "Pizzeria Pulka", "Kiosk", "Frisör Lugg & Klipp", "Bokhandel", "Café Snöbollen",
	"Järnhandel", "Blommor", "Gatukök", "Sportaffär", "Leksaker", "Konditori", "Optiker", "Second hand",
]


static func town_house(variant: int) -> ArrayMesh:
	return cached_mesh("townhouse%d" % variant, func() -> ArrayMesh:
		var kit := MeshKit.new()
		var walls: Color = [
			Color(0.95, 0.82, 0.5), Color(0.93, 0.68, 0.62), Color(0.78, 0.86, 0.94),
			Color(0.96, 0.94, 0.88), Color(0.72, 0.42, 0.3), Color(0.62, 0.76, 0.6),
		][variant % 6]
		var trim := Color(0.97, 0.96, 0.92) if variant % 6 != 3 else Color(0.5, 0.55, 0.62)
		var width := 9.0
		var depth := 9.0
		var floors := 2 + variant % 3
		var wall_h := floors * 3.0
		var bottom := -2.5
		var front := -depth * 0.5
		kit.box(Vector3(width, wall_h - bottom, depth), Vector3(0, (wall_h + bottom) * 0.5, 0), walls)
		for f in floors:
			kit.box(Vector3(width + 0.15, 0.18, depth + 0.15), Vector3(0, 3.0 * (f + 1) - 0.1, 0), trim)
		for sx in [-1.0, 1.0]:
			kit.box(Vector3(0.3, wall_h - bottom, 0.3), Vector3(sx * width * 0.5, (wall_h + bottom) * 0.5, front), trim)
		# Shop front with awning.
		kit.box(Vector3(5.6, 2.2, 0.12), Vector3(-0.9, 1.35, front - 0.03), Color(0.2, 0.18, 0.18))
		kit.box(Vector3(5.2, 1.9, 0.14), Vector3(-0.9, 1.35, front - 0.04), Color(1.0, 0.88, 0.62, 0.0))
		kit.box(Vector3(1.1, 2.2, 0.14), Vector3(3.1, 1.1, front - 0.04), Color(0.3, 0.2, 0.15))
		var stripe_a := Palette.JACKETS[variant % Palette.JACKETS.size()] as Color
		for i in 7:
			var stripe := stripe_a if i % 2 == 0 else Color(0.97, 0.97, 0.95)
			kit.box(Vector3(0.82, 0.08, 1.3), Vector3(-3.36 + i * 0.82, 2.75, front - 0.55), stripe, Vector3(-0.35, 0, 0))
		kit.box(Vector3(5.8, 0.08, 1.35), Vector3(-0.9, 2.86, front - 0.52), Palette.SNOW, Vector3(-0.35, 0, 0))
		kit.box(Vector3(5.0, 0.7, 0.1), Vector3(-0.9, 3.4, front - 0.05), Color(0.15, 0.17, 0.25))
		for f in range(1, floors):
			for i in 3:
				var lit := (variant + f + i) % 3 != 0
				var glass := Color(1.0, 0.85, 0.55, 0.0) if lit else Color(0.25, 0.3, 0.42)
				var wx := -2.8 + i * 2.8
				kit.box(Vector3(1.3, 1.6, 0.1), Vector3(wx, 3.0 * f + 1.5, front - 0.03), trim)
				kit.box(Vector3(1.05, 1.35, 0.12), Vector3(wx, 3.0 * f + 1.5, front - 0.04), glass)
				kit.box(Vector3(1.4, 0.1, 0.3), Vector3(wx, 3.0 * f + 0.7, front - 0.12), Palette.SNOW)
		var roof_h := 3.0
		var roof := Color(0.45, 0.16, 0.12) if variant % 2 == 0 else Color(0.22, 0.22, 0.26)
		kit.prism(Vector3(depth + 0.8, roof_h, width + 0.2), Vector3(0, wall_h + roof_h * 0.5, 0), roof, Vector3(0, PI / 2, 0))
		roof_snow(kit, width + 0.3, depth + 0.8, roof_h, wall_h)
		kit.box(Vector3(0.7, 1.5, 0.7), Vector3(2.5, wall_h + roof_h * 0.8, 1.2), Color(0.5, 0.25, 0.2))
		return kit.build())


## A blanket of snow lying on both slopes of a gabled roof whose ridge runs
## along X: `span` eave to eave, `rise` from eaves to ridge.
static func roof_snow(kit: MeshKit, length: float, span: float, rise: float, eaves_y: float) -> void:
	var thickness := 0.22
	var slope := Vector2(span * 0.5, rise).length()
	for side in [-1.0, 1.0]:
		var normal := Vector3(0, span * 0.5, side * rise) / slope
		var down := Vector3(0, -rise, side * span * 0.5) / slope
		var middle := Vector3(0, eaves_y + rise * 0.5, side * span * 0.25)
		var basis := Basis(Vector3.RIGHT, normal, Vector3.RIGHT.cross(normal))
		var mesh := BoxMesh.new()
		mesh.size = Vector3(length, thickness, slope + 0.1)
		kit.add(mesh, Transform3D(basis, middle + normal * thickness * 0.5 + down * 0.05), Palette.SNOW)
	kit.cylinder(thickness * 0.9, length, Vector3(0, eaves_y + rise + thickness * 0.35, 0), Palette.SNOW, 10, Vector3(0, 0, PI / 2))


## Christmas lights strung across the street, `span` metres wide.
static func light_string(span: int) -> ArrayMesh:
	return cached_mesh("lights%d" % span, func() -> ArrayMesh:
		var kit := MeshKit.new()
		var bulbs := [Color(1.0, 0.25, 0.2, 0.0), Color(0.3, 1.0, 0.4, 0.0), Color(1.0, 0.85, 0.3, 0.0), Color(0.35, 0.6, 1.0, 0.0)]
		var count := int(span / 0.9)
		var previous := Vector3(-span * 0.5, 0, 0)
		for i in count + 1:
			var x := -span * 0.5 + i * span / float(count)
			var t := x / (span * 0.5)
			var point := Vector3(x, -0.9 * (1.0 - t * t), 0)
			if i > 0:
				var mid := (previous + point) * 0.5
				var tilt := atan2(point.y - previous.y, point.x - previous.x)
				kit.box(Vector3(previous.distance_to(point), 0.025, 0.025), mid, Color(0.1, 0.1, 0.1), Vector3(0, 0, tilt))
			kit.sphere(0.08, point + Vector3(0, -0.08, 0), bulbs[i % bulbs.size()], Vector3.ONE, 8, 4)
			previous = point
		return kit.build())


static func bin() -> ArrayMesh:
	return cached_mesh("bin", func() -> ArrayMesh:
		var kit := MeshKit.new()
		kit.cylinder(0.32, 0.95, Vector3(0, 0.48, 0), Color(0.15, 0.45, 0.25), 14)
		kit.cylinder(0.35, 0.08, Vector3(0, 0.98, 0), Color(0.1, 0.32, 0.18), 14)
		kit.ellipsoid(Vector3(0.33, 0.08, 0.33), Vector3(0, 1.04, 0), Palette.SNOW)
		return kit.build())


# --- Forest trail ---

## A fallen trunk lying along local X, low enough to jump.
static func fallen_log() -> ArrayMesh:
	return cached_mesh("log", func() -> ArrayMesh:
		var kit := MeshKit.new()
		kit.cylinder(0.3, 6.0, Vector3(0, 0.28, 0), Palette.TRUNK, 12, Vector3(0, 0, PI / 2), 0.26)
		for end in [-1.0, 1.0]:
			kit.cylinder(0.27, 0.04, Vector3(end * 3.0, 0.28, 0), Color(0.78, 0.62, 0.42), 12, Vector3(0, 0, PI / 2))
		kit.ellipsoid(Vector3(2.8, 0.1, 0.24), Vector3(0, 0.56, 0), Palette.SNOW)
		kit.cylinder(0.08, 0.9, Vector3(0.8, 0.55, 0.15), Palette.TRUNK, 6, Vector3(0.6, 0, 0.4), 0.03)
		return kit.build())


static func mushroom_ring() -> ArrayMesh:
	return cached_mesh("mushrooms", func() -> ArrayMesh:
		var kit := MeshKit.new()
		for i in 5:
			var angle := i * 1.3
			var at := Vector3(cos(angle) * 0.5, 0, sin(angle) * 0.4)
			kit.cylinder(0.04, 0.18, at + Vector3(0, 0.09, 0), Color(0.95, 0.93, 0.88), 8)
			kit.sphere(0.11, at + Vector3(0, 0.18, 0), Color(0.85, 0.12, 0.1), Vector3(1, 0.6, 1), 10, 5, true)
			kit.sphere(0.02, at + Vector3(0.04, 0.24, 0.02), Color(1, 1, 1))
		return kit.build())


# --- Frozen river ---

static func tent() -> ArrayMesh:
	return cached_mesh("tent", func() -> ArrayMesh:
		var kit := MeshKit.new()
		kit.cone(1.15, 1.7, Vector3(0, 0.85, 0), Color(0.85, 0.15, 0.12), 4, Vector3(0, PI / 4, 0))
		kit.cone(0.4, 0.6, Vector3(0, 1.45, 0), Palette.SNOW, 4, Vector3(0, PI / 4, 0))
		kit.box(Vector3(0.6, 0.9, 0.05), Vector3(0, 0.45, -0.58), Color(0.35, 0.08, 0.06))
		kit.cylinder(0.04, 0.5, Vector3(0.9, 0.25, -0.6), Color(0.6, 0.6, 0.65), 6)
		return kit.build())


static func reeds() -> ArrayMesh:
	return cached_mesh("reeds", func() -> ArrayMesh:
		var kit := MeshKit.new()
		for i in 9:
			var angle := i * 2.4
			var r := 0.15 + (i % 3) * 0.12
			var tall := 1.0 + (i % 4) * 0.25
			var base := Vector3(cos(angle) * r, tall * 0.5, sin(angle) * r)
			kit.cylinder(0.018, tall, base, Color(0.75, 0.62, 0.38), 5, Vector3(sin(angle) * 0.15, 0, cos(angle) * 0.15))
			kit.capsule(0.04, 0.22, base + Vector3(0, tall * 0.5, 0), Color(0.45, 0.3, 0.18))
		return kit.build())


static func footbridge(span: int) -> ArrayMesh:
	return cached_mesh("bridge%d" % span, func() -> ArrayMesh:
		var kit := MeshKit.new()
		var wood := Color(0.5, 0.33, 0.2)
		var dark := Color(0.32, 0.2, 0.12)
		kit.box(Vector3(span, 0.35, 2.4), Vector3(0, 0, 0), wood)
		kit.box(Vector3(span, 0.1, 2.5), Vector3(0, 0.22, 0), Palette.SNOW)
		for side in [-1.0, 1.0]:
			kit.box(Vector3(span, 0.12, 0.12), Vector3(0, 1.1, side * 1.15), dark)
			var post := -span * 0.5
			while post <= span * 0.5:
				kit.box(Vector3(0.12, 1.0, 0.12), Vector3(post, 0.6, side * 1.15), dark)
				post += 2.0
		for end in [-1.0, 1.0]:
			kit.box(Vector3(0.8, 14.0, 2.6), Vector3(end * (span * 0.5 - 0.4), -7.0, 0), Color(0.55, 0.55, 0.58))
		return kit.build())


# --- Snowpark ---

static func lift_tower() -> ArrayMesh:
	return cached_mesh("lift", func() -> ArrayMesh:
		var kit := MeshKit.new()
		var steel := Color(0.55, 0.58, 0.62)
		kit.cylinder(0.25, 9.0, Vector3(0, 4.5, 0), steel, 10, Vector3.ZERO, 0.18)
		kit.box(Vector3(4.0, 0.3, 0.35), Vector3(0, 9.0, 0), steel)
		for side in [-1.0, 1.0]:
			kit.cylinder(0.25, 0.15, Vector3(1.8 * side, 8.8, 0), Color(0.2, 0.2, 0.22), 12, Vector3(PI / 2, 0, 0))
		kit.box(Vector3(4.1, 0.1, 0.45), Vector3(0, 9.2, 0), Palette.SNOW)
		return kit.build())


## A unit-length cable segment along X; scale it to span between towers.
static func cable() -> ArrayMesh:
	return cached_mesh("cable", func() -> ArrayMesh:
		return MeshKit.new().box(Vector3(1.0, 0.05, 0.05), Vector3.ZERO, Color(0.15, 0.15, 0.15)).build())


static func chair(variant: int) -> ArrayMesh:
	return cached_mesh("chair%d" % variant, func() -> ArrayMesh:
		var kit := MeshKit.new()
		var metal := Color(0.3, 0.3, 0.33)
		kit.box(Vector3(0.06, 2.0, 0.06), Vector3(0, -1.0, 0), metal)
		kit.box(Vector3(1.4, 0.1, 0.55), Vector3(0, -2.0, 0), Color(0.15, 0.35, 0.75))
		kit.box(Vector3(1.4, 0.6, 0.08), Vector3(0, -1.7, 0.25), Color(0.15, 0.35, 0.75))
		if variant == 1:
			kit.capsule(0.18, 0.55, Vector3(-0.3, -1.6, 0.05), Palette.JACKETS[2])
			kit.sphere(0.14, Vector3(-0.3, -1.15, 0.05), Palette.SKIN)
			kit.sphere(0.15, Vector3(-0.3, -1.1, 0.05), Palette.JACKETS[4], Vector3.ONE, 12, 6, true)
		return kit.build())


# --- Event visitors ---

static func santa_sleigh() -> ArrayMesh:
	return cached_mesh("sleigh", func() -> ArrayMesh:
		var kit := MeshKit.new()
		var red := Color(0.8, 0.08, 0.1)
		var gold := Color(1.0, 0.78, 0.2)
		kit.box(Vector3(1.4, 0.7, 2.2), Vector3(0, 0.75, 0.1), red)
		kit.box(Vector3(1.45, 0.12, 2.3), Vector3(0, 1.12, 0.1), gold)
		kit.box(Vector3(1.4, 0.9, 0.3), Vector3(0, 1.2, 1.1), red, Vector3(-0.3, 0, 0))
		kit.capsule(0.35, 1.3, Vector3(0, 0.75, -1.05), red, Vector3(0, 0, PI / 2))
		for side in [-1.0, 1.0]:
			kit.capsule(0.05, 2.6, Vector3(0.6 * side, 0.12, 0.0), gold, Vector3(-PI / 2, 0, 0))
			kit.capsule(0.05, 0.6, Vector3(0.6 * side, 0.32, -1.25), gold, Vector3(-0.6, 0, 0))
			kit.capsule(0.04, 0.5, Vector3(0.6 * side, 0.35, 0.6), gold)
		# Santa
		kit.capsule(0.38, 0.9, Vector3(0, 1.45, 0.45), red, Vector3.ZERO, Vector3(1, 1, 0.9))
		kit.cylinder(0.4, 0.12, Vector3(0, 1.25, 0.45), Color(0.1, 0.08, 0.06), 14)
		kit.sphere(0.25, Vector3(0, 2.05, 0.4), Palette.SKIN)
		kit.ellipsoid(Vector3(0.24, 0.26, 0.15), Vector3(0, 1.88, 0.25), Color(1, 1, 1))
		kit.sphere(0.06, Vector3(0, 2.05, 0.15), Color(1.0, 0.55, 0.55))
		kit.cone(0.24, 0.55, Vector3(0, 2.42, 0.42), red, 12, Vector3(0.4, 0, 0))
		kit.cylinder(0.26, 0.1, Vector3(0, 2.22, 0.4), Color(1, 1, 1), 14)
		kit.sphere(0.08, Vector3(0, 2.6, 0.62), Color(1, 1, 1))
		for side in [-1.0, 1.0]:
			kit.capsule(0.1, 0.6, Vector3(0.38 * side, 1.5, 0.15), red, Vector3(1.0, 0, 0))
			kit.sphere(0.035, Vector3(0.08 * side, 2.12, 0.17), Color(0.05, 0.05, 0.05))
		# Sack of presents
		kit.sphere(0.5, Vector3(0.1, 1.45, 1.0), Color(0.55, 0.38, 0.22), Vector3(1, 1.1, 0.9))
		kit.box(Vector3(0.35, 0.35, 0.35), Vector3(-0.2, 1.95, 1.0), Color(0.2, 0.6, 0.3), Vector3(0.3, 0.4, 0))
		kit.box(Vector3(0.3, 0.3, 0.3), Vector3(0.3, 1.95, 0.95), Color(0.25, 0.4, 0.9), Vector3(0, 0.8, 0.2))
		return kit.build())


static func gift(variant: int) -> ArrayMesh:
	return cached_mesh("gift%d" % variant, func() -> ArrayMesh:
		var kit := MeshKit.new()
		var paper: Color = [Color(0.85, 0.1, 0.12), Color(0.15, 0.55, 0.25), Color(0.2, 0.35, 0.85), Color(0.95, 0.75, 0.15)][variant % 4]
		var ribbon: Color = [Color(1.0, 0.85, 0.2), Color(0.95, 0.1, 0.1), Color(1, 1, 1), Color(0.8, 0.1, 0.5)][variant % 4]
		kit.box(Vector3(0.6, 0.5, 0.6), Vector3(0, 0.25, 0), paper)
		kit.box(Vector3(0.62, 0.52, 0.12), Vector3(0, 0.25, 0), ribbon)
		kit.box(Vector3(0.12, 0.52, 0.62), Vector3(0, 0.25, 0), ribbon)
		for side in [-1.0, 1.0]:
			kit.ellipsoid(Vector3(0.12, 0.08, 0.05), Vector3(0.1 * side, 0.55, 0), ribbon, Vector3(0, 0, side * 0.5))
		return kit.build())


static func snowball() -> ArrayMesh:
	return cached_mesh("snowball", func() -> ArrayMesh:
		return MeshKit.new().sphere(0.2, Vector3.ZERO, Color(1, 1, 1), Vector3.ONE, 10, 6).build())


## A static copy of a rig with its limbs frozen at the given swing phase.
static func posed(rig: Rig, phase: float) -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	body.mesh = rig.body
	root.add_child(body)
	for limb in rig.limbs:
		var joint := Node3D.new()
		joint.position = limb.pivot
		joint.rotation.x = sin(phase + limb.phase) * limb.swing * 1.4
		var mesh := MeshInstance3D.new()
		mesh.mesh = limb.mesh
		joint.add_child(mesh)
		root.add_child(joint)
	return root


# --- Pickups ---

static func gingerbread() -> ArrayMesh:
	return cached_mesh("ginger", func() -> ArrayMesh:
		var kit := MeshKit.new()
		var dough := Color(0.72, 0.38, 0.14)
		kit.cylinder(0.32, 0.08, Vector3.ZERO, dough, 6, Vector3(PI / 2, 0, 0))
		kit.cylinder(0.26, 0.09, Vector3.ZERO, Color(0.95, 0.95, 0.95), 6, Vector3(PI / 2, 0, 0), 0.25)
		kit.cylinder(0.22, 0.1, Vector3.ZERO, dough, 6, Vector3(PI / 2, 0, 0))
		return kit.build())


static func cocoa() -> ArrayMesh:
	return cached_mesh("cocoa", func() -> ArrayMesh:
		var kit := MeshKit.new()
		kit.cylinder(0.25, 0.45, Vector3.ZERO, Color(0.9, 0.15, 0.2), 8)
		kit.cylinder(0.22, 0.02, Vector3(0, 0.22, 0), Color(0.4, 0.22, 0.1), 8)
		kit.sphere(0.12, Vector3(0.05, 0.27, 0), Color(1, 1, 1), Vector3(1, 0.6, 1), 6, 3)
		kit.box(Vector3(0.08, 0.28, 0.06), Vector3(0.3, 0, 0), Color(0.95, 0.95, 0.95))
		return kit.build())


static func wax() -> ArrayMesh:
	return cached_mesh("wax", func() -> ArrayMesh:
		var kit := MeshKit.new()
		kit.cylinder(0.14, 0.6, Vector3.ZERO, Color(0.2, 0.5, 1.0, 0.6), 8)
		kit.cylinder(0.145, 0.15, Vector3(0, 0.1, 0), Color(1.0, 0.85, 0.1), 8)
		kit.cylinder(0.1, 0.1, Vector3(0, 0.35, 0), Color(0.9, 0.9, 0.95), 8)
		return kit.build())


# --- The player ---
