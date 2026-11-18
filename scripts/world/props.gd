class_name Props
extends RefCounted
## Procedural models. Every model is built once per variant, cached and
## shared. Convention: origin at ground level, front facing -Z.

static var _cache: Dictionary = {}
const BAKED_WORLD := "res://generated/world_meshes/cache.res"
static var use_baked_world := true
static var _checked_world_cache := false
static var _pipeline_meshes: Array = []
static var _effects := {}


static func _load_world_cache() -> void:
	if _checked_world_cache or not use_baked_world: return
	_checked_world_cache = true
	if ResourceLoader.exists(BAKED_WORLD):
		var archive: Resource = load(BAKED_WORLD)
		_cache.merge(archive.get_meta("meshes", {}), false)
		_baked.merge(archive.get_meta("poses", {}), false)
		_crowd.merge(archive.get_meta("crowd", {}), false)
		_pipeline_meshes = archive.get_meta("pipeline_meshes", [])
		_effects = archive.get_meta("effects", {})


static func cached_mesh(key: String, builder: Callable) -> ArrayMesh:
	_load_world_cache()
	if not _cache.has(key):
		_cache[key] = builder.call()
	return _cache[key]


# --- Rigs: a body plus jointed limbs that obstacles can animate ---

## A limb hangs from `pivot` (in body space) and swings around its local X.
## It may have a lower part (shin, forearm) hanging from `joint` in the
## limb's own space, which bends by `rest` plus `bend` as the limb swings
## forward: knees fold on the way through, elbows crook.
class Limb:
	var mesh: ArrayMesh
	var pivot: Vector3
	var phase: float
	var swing: float
	## Waves instead of swinging when its owner stands still.
	var waves: bool
	var lower: ArrayMesh
	var joint := Vector3.ZERO
	var rest := 0.0
	var bend := 0.0

	func _init(limb_mesh: ArrayMesh, at: Vector3, limb_phase: float, amount: float, waving := false) -> void:
		mesh = limb_mesh
		pivot = at
		phase = limb_phase
		swing = amount
		waves = waving

	func with_lower(lower_mesh: ArrayMesh, at: Vector3, resting: float, bending: float) -> Limb:
		lower = lower_mesh
		joint = at
		rest = resting
		bend = bending
		return self

	## Swing of the upper part and bend of the lower at gait phase g.
	func pose(g: float) -> Vector2:
		var swung := sin(g + phase) * swing
		var folding := maxf(cos(g + phase), 0.0) if bend < 0.0 else maxf(sin(g + phase), 0.0)
		return Vector2(swung, rest + bend * folding)


class Rig:
	var body: ArrayMesh
	var limbs: Array[Limb] = []
	## Gait cycle in radians per metre travelled.
	var stride := 0.0
	## A person or animal made in Blender (models/<kind>.glb) instead of a
	## body and limbs: its colours by material name, the metres one cycle
	## of its gait covers, the gait (walk, hop) and whether it waves when
	## standing still.
	var kind := ""
	var colours := {}
	var pace := 1.4
	var gait := &"walk"
	var waves := false
	## Something held (a bandy stick), in the model's space, following a bone.
	var held: ArrayMesh
	var held_bone := ""

	static func of(mesh: ArrayMesh) -> Rig:
		var rig := Rig.new()
		rig.body = mesh
		return rig

	static func creature(model: String, dress: Dictionary, metres: float) -> Rig:
		var rig := Rig.new()
		rig.kind = model
		rig.colours = dress
		rig.pace = metres
		return rig

	## The Blender-made figure for this rig, dressed and holding its things.
	func make() -> CreatureRig:
		var figure := CreatureRig.new(kind)
		figure.dress(colours)
		if held != null:
			figure.attach_at(held, held_bone, Transform3D.IDENTITY)
		return figure


static var _rigs: Dictionary = {}


static func cached_rig(key: String, builder: Callable) -> Rig:
	if not _rigs.has(key):
		_rigs[key] = builder.call()
	return _rigs[key]


## Four legs in a trotting gait (diagonal pairs move together). With a
## `lower` part, front knees fold forward and hind hocks backward.
static func _legs(rig: Rig, leg: ArrayMesh, half_width: float, front_z: float, back_z: float, hip_y: float, swing: float, lower: ArrayMesh = null, joint := Vector3.ZERO, bend := 0.0) -> void:
	for spec in [[-half_width, front_z, 0.0, -1.0], [half_width, front_z, PI, -1.0], [-half_width, back_z, PI, 1.0], [half_width, back_z, 0.0, 1.0]]:
		var limb := Limb.new(leg, Vector3(spec[0], hip_y, spec[1]), spec[2], swing)
		if lower != null:
			limb.with_lower(lower, joint, 0.0, bend * spec[3])
		rig.limbs.append(limb)


# --- Nature ---

static func spruce(variant: int) -> ArrayMesh:
	return cached_mesh("spruce%d" % variant, func() -> ArrayMesh:
		var kit := MeshKit.new()
		var perches := PackedVector3Array()
		var green: Color = Palette.SPRUCE[variant % Palette.SPRUCE.size()]
		kit.cylinder(0.17, 1.6, Vector3(0, 0.8, 0), Palette.TRUNK, 8, Vector3.ZERO, 0.1)
		# Tiers of drooping branches, each a skirt whose rim goes in and out
		# round the branch tips, snow lying along the tops of the branches.
		var tiers := 7 + variant % 2
		var top := 6.0 + variant * 0.25
		var crown := 0.0
		for i in tiers:
			var f := float(i) / tiers
			var radius := lerpf(1.9, 0.38, pow(f, 0.85))
			var y := lerpf(0.8, top - 0.9, f)
			var rise := lerpf(0.75, 0.6, f)
			var droop := lerpf(0.4, 0.14, f)
			var lobes := 10 - i / 2
			var seed := variant * 31 + i * 7
			var shade := green.darkened(0.1 * (1.0 - f)).lerp(Color(0.1, 0.22, 0.2), 0.15 * float(i % 2))
			# Radius (as a fraction), height and how deep the rim dips
			# between branch tips, from the drooping tips in to the trunk.
			var shape := [[1.0, -droop, 0.34], [0.64, rise * 0.35, 0.24], [0.3, rise * 0.72, 0.12], [0.03, rise, 0.0]]
			var skirt: Array[PackedVector3Array] = []
			var snow: Array[PackedVector3Array] = []
			for ring in shape:
				skirt.append(MeshKit.lobed(radius * ring[0], y + ring[1], lobes, ring[2], seed, 0.25))
			# Snow lies along the tops of the branches, a little in from the
			# tips; between them it sinks out of sight under the needles.
			for k in shape.size():
				var ring: Array = shape[k]
				var inset := 0.9 if k == 0 else 1.0
				var height: float = ring[1] + (droop * 0.25 if k == 0 else 0.0) + 0.09
				snow.append(MeshKit.lobed(radius * ring[0] * inset, y + height, lobes, ring[2] + 0.06, seed, 0.25))
			kit.loft(skirt, PackedFloat32Array([1, 1, 1, 1]), Transform3D.IDENTITY, shade)
			var under: Array[PackedVector3Array] = [MeshKit.lobed(0.12, y + 0.12, lobes, 0.0, seed), skirt[0]]
			kit.loft(under, PackedFloat32Array([1, 1]), Transform3D.IDENTITY, shade.darkened(0.35))
			if i in [1, 3, 4]: perches.append(snow[0][(i * 4) % snow[0].size()] + Vector3.UP * 0.02)
			kit.loft(snow, PackedFloat32Array([1, 1, 1, 1]), Transform3D.IDENTITY, Palette.SNOW)
			crown = y + rise
		# The leader shoot at the very top, capped with snow.
		kit.cone(0.12, 0.8, Vector3(0, crown + 0.3, 0), green, 6)
		kit.cone(0.09, 0.3, Vector3(0, crown + 0.6, 0), Palette.SNOW, 6)
		var mesh := kit.build()
		mesh.set_meta(&"bird_perches", perches)
		return mesh)


static func birch() -> ArrayMesh:
	return cached_mesh("birch", func() -> ArrayMesh:
		var kit := MeshKit.new()
		var perches := PackedVector3Array()
		var bark := Color(0.93, 0.92, 0.88)
		var black := Color(0.13, 0.12, 0.12)
		var rng := RandomNumberGenerator.new()
		rng.seed = 4711
		# A trunk that leans and wanders a little on its way up, tapering,
		# rough and dark at the foot.
		var spine: Array[Vector3] = []
		for i in 6:
			var t := i / 5.0
			spine.append(Vector3(sin(t * 2.6) * 0.12, t * 5.6, cos(t * 1.9) * 0.06 - t * 0.08))
		for i in spine.size() - 1:
			var radius := lerpf(0.17, 0.05, i / 5.0)
			kit.capsule_between(spine[i], spine[i + 1], radius, bark, 10)
		kit.cylinder(0.2, 0.8, Vector3(0, 0.35, 0), Color(0.22, 0.2, 0.19), 10, Vector3.ZERO, 0.165)
		# Black lenticels: short dashes part of the way round the trunk.
		for i in 26:
			var t := rng.randf_range(0.18, 0.8)
			var at := _along(spine, t)
			var radius := lerpf(0.17, 0.05, t) + 0.006
			var angle := rng.randf() * TAU
			var dash := Vector3(cos(angle), 0, sin(angle)) * radius
			kit.box(Vector3(rng.randf_range(0.06, 0.16), rng.randf_range(0.02, 0.05), 0.02), at + dash, black, Vector3(0, -angle + PI / 2.0, 0))
		# Branches arch up and out from the trunk, and from them the fine
		# twigs hang straight down in curtains, white with hoarfrost.
		var frost := Color(0.93, 0.95, 1.0)
		var strand := SphereMesh.new()
		strand.radius = 1.0
		strand.height = 2.0
		strand.radial_segments = 5
		strand.rings = 3
		for i in 16:
			var t := lerpf(0.28, 0.96, i / 15.0)
			var start := _along(spine, t)
			var angle := i * 2.4 + rng.randf_range(-0.3, 0.3)
			var out := Vector3(cos(angle), 0, sin(angle))
			var reach := lerpf(1.6, 0.55, i / 15.0) * rng.randf_range(0.85, 1.1)
			var elbow := start + out * reach * 0.55 + Vector3.UP * reach * 0.45
			var tip := elbow + out * reach * 0.5 + Vector3.UP * reach * 0.05
			kit.capsule_between(start, elbow, 0.035, frost.darkened(0.25), 5)
			if i in [2, 5, 9]: perches.append(tip + Vector3.UP * 0.025)
			kit.capsule_between(elbow, tip, 0.022, frost.darkened(0.15), 4)
			for k in 9:
				var along := lerpf(0.3, 1.0, k / 8.0)
				var from := start.lerp(elbow, along * 2.0) if along < 0.5 else elbow.lerp(tip, along * 2.0 - 1.0)
				var hang := rng.randf_range(0.35, 0.75) * lerpf(0.6, 1.0, along) * (1.0 - t * 0.3)
				var side := out.cross(Vector3.UP) * rng.randf_range(-0.2, 0.2)
				var width := rng.randf_range(0.05, 0.08)
				kit.add(strand, Transform3D(Basis.from_euler(Vector3(0, angle, 0)) * Basis.from_scale(Vector3(width, hang, width * 0.7)), from + side + Vector3.DOWN * hang * 0.85), frost.darkened(rng.randf() * 0.06))
		# A frosty tuft at the top.
		for k in 4:
			var lean := Vector3(cos(k * 1.6) * 0.15, 0, sin(k * 1.6) * 0.15)
			var top_at := spine[spine.size() - 1] + lean + Vector3.DOWN * 0.25
			kit.add(strand, Transform3D(Basis.from_scale(Vector3(0.08, 0.35, 0.06)), top_at), frost)
		kit.ellipsoid(Vector3(0.07, 0.04, 0.07), spine[spine.size() - 1], Palette.SNOW)
		var mesh := kit.build()
		mesh.set_meta(&"bird_perches", perches)
		return mesh)


## Point a fraction t of the way along a polyline of evenly spaced points.
static func _along(points: Array[Vector3], t: float) -> Vector3:
	var scaled := clampf(t, 0.0, 1.0) * (points.size() - 1)
	var i := mini(int(scaled), points.size() - 2)
	return points[i].lerp(points[i + 1], scaled - i)


static func rock(variant: int) -> ArrayMesh:
	return cached_mesh("rock%d" % variant, func() -> ArrayMesh:
		var kit := MeshKit.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 900 + variant
		# A glacial boulder: a cluster of blunt, faceted lumps of granite,
		# speckled with lichen, snow settled in a cushion on top.
		var main := Vector3(1.15, 0.72, 0.95) if variant == 0 else Vector3(0.9, 0.85, 1.1)
		var lumps := [
			[main, Vector3(0, 0.3, 0)],
			[main * Vector3(0.6, 0.7, 0.65), Vector3(0.55, 0.22, 0.35)],
			[main * Vector3(0.55, 0.55, 0.6), Vector3(-0.5, 0.12, -0.3)],
			[main * Vector3(0.45, 0.4, 0.45), Vector3(0.2, 0.08, -0.7)],
		]
		for i in lumps.size():
			var lump: Array = lumps[i]
			var tone := Palette.ROCK.lerp(Color(0.52, 0.5, 0.47), rng.randf() * 0.6).darkened(rng.randf() * 0.12)
			_facet(kit, lump[0], lump[1], tone, Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.2, 0.2)))
		for i in 7:
			var angle := rng.randf() * TAU
			var at := Vector3(cos(angle) * main.x * 0.8, rng.randf_range(0.05, 0.5), sin(angle) * main.z * 0.8)
			kit.ellipsoid(Vector3(0.12, 0.08, 0.02) * rng.randf_range(0.6, 1.4), at, Color(0.62, 0.66, 0.42), Vector3(0, -angle + PI / 2.0, 0))
		kit.ellipsoid(Vector3(main.x * 0.82, 0.24, main.z * 0.76), Vector3(0.05, 0.84, 0), Palette.SNOW, Vector3(0.08, variant, 0.05))
		kit.ellipsoid(Vector3(main.x * 0.4, 0.14, main.z * 0.35), Vector3(0.55, 0.62, 0.3), Palette.SNOW)
		var mesh := kit.build()
		mesh.set_meta(&"bird_perches", PackedVector3Array([Vector3(0.05, 1.08, 0)]))
		return mesh)


## A low-poly lump with flat facets, like broken stone.
static func _facet(kit: MeshKit, radii: Vector3, at: Vector3, color: Color, rot: Vector3) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 7
	mesh.rings = 4
	kit.add(mesh, Transform3D(Basis.from_euler(rot) * Basis.from_scale(radii), at), color)


static func stump() -> ArrayMesh:
	return cached_mesh("stump", func() -> ArrayMesh:
		var kit := MeshKit.new()
		var bark := Palette.TRUNK
		# Sawn off at a slight slant: ridged bark round a pale cut face with
		# rings, roots spreading into the snow.
		var profile := PackedVector2Array([Vector2(0.5, -0.05), Vector2(0.44, 0.12), Vector2(0.4, 0.3), Vector2(0.4, 0.52)])
		kit.lathe(profile, Transform3D.IDENTITY, bark, 14)
		for i in 10:
			var angle := TAU * i / 10.0
			kit.box(Vector3(0.05, 0.5, 0.05), Vector3(cos(angle) * 0.41, 0.28, sin(angle) * 0.41), bark.darkened(0.25), Vector3(0, -angle, 0))
		var cut := Transform3D(Basis(Vector3.RIGHT, 0.08), Vector3(0, 0.53, 0))
		kit.add(_disc(0.39, 0.03), cut, Color(0.82, 0.68, 0.48))
		for r in [0.28, 0.17, 0.07]:
			kit.add(_disc(r, 0.035), cut, Color(0.7, 0.55, 0.36) if r != 0.17 else Color(0.84, 0.7, 0.5))
		kit.ellipsoid(Vector3(0.3, 0.07, 0.24), Vector3(0.06, 0.58, 0.05), Palette.SNOW)
		for i in 5:
			var angle := i * 1.3 + 0.4
			var out := Vector3(cos(angle), 0, sin(angle))
			kit.capsule_between(out * 0.36 + Vector3.UP * 0.08, out * (0.58 + 0.08 * (i % 2)) + Vector3.DOWN * 0.02, 0.075 - (i % 2) * 0.015, bark, 7)
		kit.ellipsoid(Vector3(0.75, 0.12, 0.75), Vector3(0, -0.02, 0), Palette.SNOW)
		var mesh := kit.build()
		mesh.set_meta(&"bird_perches", PackedVector3Array([Vector3(0.06, 0.65, 0.05)]))
		return mesh)


static func _taper(bottom: float, top: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = 12
	mesh.rings = 0
	return mesh


static func _disc(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 14
	mesh.rings = 0
	return mesh


static func snowman() -> ArrayMesh:
	return cached_mesh("snowman", func() -> ArrayMesh:
		var kit := MeshKit.new()
		var coal := Color(0.06, 0.06, 0.07)
		var packed := Palette.SNOW.darkened(0.04)
		# Rolled snowballs: a little squashed under their own weight and
		# lumpy, with a ring of packed snow where each one sits on the next.
		kit.sphere(0.6, Vector3(0, 0.5, 0), Palette.SNOW, Vector3(1.0, 0.88, 0.96), 16, 9)
		kit.sphere(0.25, Vector3(0.35, 0.65, -0.2), Palette.SNOW, Vector3.ONE, 8, 5)
		kit.torus(0.3, 0.42, Transform3D(Basis.IDENTITY, Vector3(0, 0.96, 0)), packed, 16, 6)
		kit.sphere(0.44, Vector3(0.02, 1.25, 0), Palette.SNOW, Vector3(1.0, 0.92, 0.98), 16, 9)
		kit.sphere(0.31, Vector3(0, 1.78, -0.01), Palette.SNOW, Vector3.ONE, 16, 9)
		kit.ellipsoid(Vector3(0.75, 0.1, 0.75), Vector3(0, 0.0, 0), packed)
		# Carrot nose, coal eyes and a coal smile.
		kit.cone(0.055, 0.34, Vector3(0, 1.76, -0.44), Color(1.0, 0.48, 0.08), 8, Vector3(-PI / 2 + 0.12, 0, 0))
		for side in [-1.0, 1.0]:
			kit.sphere(0.042, Vector3(0.11 * side, 1.87, -0.27), coal, Vector3(1, 1, 0.6), 8, 5)
		for k in 5:
			var t := (k - 2.0) / 2.0
			kit.sphere(0.022, Vector3(t * 0.12, 1.66 + t * t * 0.035, -0.285 + t * t * 0.02), coal, Vector3.ONE, 6, 4)
		for i in 3:
			kit.sphere(0.045, Vector3(0, 1.05 + i * 0.18, -0.43 + absf(i - 1) * 0.02), coal, Vector3(1, 1, 0.6), 8, 5)
		# Twig arms with forked fingers.
		for side in [-1.0, 1.0]:
			var shoulder := Vector3(0.36 * side, 1.38, 0)
			var hand := Vector3(0.95 * side, 1.62 + side * 0.08, -0.05)
			kit.capsule_between(shoulder, hand, 0.022, Palette.TRUNK, 5)
			for f in 3:
				var bend := Vector3(0.15 * side, 0.1 * (f - 1) + 0.05, -0.05 * (f - 1))
				kit.capsule_between(hand, hand + bend, 0.012, Palette.TRUNK, 4)
			kit.capsule_between(shoulder.lerp(hand, 0.55), shoulder.lerp(hand, 0.55) + Vector3(0.05 * side, 0.18, 0), 0.012, Palette.TRUNK, 4)
		# Knitted scarf with a hanging end, and a top hat with a band.
		var red := Color(0.85, 0.15, 0.15)
		kit.torus(0.27, 0.36, Transform3D(Basis.IDENTITY, Vector3(0, 1.5, 0)), red, 16, 6)
		kit.capsule_between(Vector3(0.16, 1.48, -0.28), Vector3(0.22, 1.12, -0.36), 0.06, red, 8)
		for f in 3:
			kit.box(Vector3(0.025, 0.08, 0.02), Vector3(0.18 + f * 0.035, 1.04, -0.37), Color(1, 1, 1))
		var hat := Color(0.08, 0.08, 0.1)
		kit.cylinder(0.34, 0.04, Vector3(0, 2.02, 0), hat, 16, Vector3(0.0, 0, 0.1))
		kit.cylinder(0.2, 0.38, Vector3(0.02, 2.22, 0), hat, 16, Vector3(0.0, 0, 0.1), 0.21)
		kit.cylinder(0.205, 0.07, Vector3(0.013, 2.08, 0), Color(0.6, 0.1, 0.12), 16, Vector3(0.0, 0, 0.1))
		return kit.build())


# --- People and animals ---

static func person(variant: int) -> Rig:
	var jacket: Color = Palette.JACKETS[variant % Palette.JACKETS.size()]
	var hat: Color = Palette.JACKETS[(variant + 3) % Palette.JACKETS.size()]
	var scarf: Color = Palette.JACKETS[(variant + 5) % Palette.JACKETS.size()]
	var pants := Color(0.12, 0.14, 0.25) if variant % 2 == 0 else Color(0.25, 0.2, 0.18)
	return dressed("person%d" % variant, jacket, hat, scarf, pants)


## A person in the given clothes. `bathing` swaps the winter gear for bare
## skin and trunks (in the jacket's colour); `stick` puts a bandy stick in
## the right hand. Hat colour goes for the mittens too.
static func dressed(key: String, jacket: Color, hat: Color, scarf: Color, pants: Color, bathing := false, stick := false) -> Rig:
	return cached_rig(key, func() -> Rig:
		var skin := Palette.SKIN
		var colours := {
			"jacket": jacket, "jacket_trim": jacket.lightened(0.35), "pants": pants, "trunks": pants,
			"hat": hat, "hat_cuff": hat.darkened(0.2), "scarf": scarf,
		}
		if bathing:
			colours = {
				"jacket": skin, "jacket_trim": skin, "pants": skin, "trunks": jacket, "boots": skin,
				"sole": skin.darkened(0.15), "scarf": skin, "hat": hat, "hat_cuff": hat.darkened(0.2),
			}
		var rig := Rig.creature("person", colours, 1.4)
		rig.waves = not stick
		if stick:
			rig.held = _bandy_stick()
			rig.held_bone = "forearm.R"
		return rig)


## A bandy stick in a right hand hanging at the side, its curved blade
## down by the ice in front (model space of the person).
static func _bandy_stick() -> ArrayMesh:
	return cached_mesh("bandy_stick", func() -> ArrayMesh:
		var kit := MeshKit.new()
		var wood := Color(0.6, 0.45, 0.25)
		kit.capsule_between(Vector3(0.28, 1.0, 0.08), Vector3(0.3, 0.08, -0.6), 0.02, wood, 6)
		kit.capsule_between(Vector3(0.3, 0.08, -0.6), Vector3(0.3, 0.04, -0.85), 0.03, wood, 6)
		kit.box(Vector3(0.05, 0.04, 0.12), Vector3(0.285, 0.75, -0.1), Color(0.1, 0.1, 0.12), Vector3(0.9, 0, 0))
		return kit.build())


static func dog() -> Rig:
	return cached_rig("dog", func() -> Rig: return Rig.creature("dog", {}, 0.9))


## Winter red fox with a continuous coat and a white-tipped brush.
static func fox() -> Rig:
	return cached_rig("fox", func() -> Rig: return Rig.creature("fox", {}, 0.9))


## Grey tabby, ginger tabby or dark tuxedo; bib and socks stay pale.
static func cat(variant := 0) -> Rig:
	var coat: Color = [Color.WHITE, Color(1.0, 0.69, 0.37), Color(0.27, 0.29, 0.33)][posmod(variant, 3)]
	return cached_rig("cat%d" % posmod(variant, 3), func() -> Rig: return Rig.creature("cat", {"cat coat": coat}, 0.65))


static func moose() -> Rig:
	return cached_rig("moose", func() -> Rig: return Rig.creature("moose", {}, 2.6))


## A brown bear, lumbering across the slope.
static func bear() -> Rig:
	# The walk covers 0.6 / 0.62 metres in 40 frames at 24 fps.
	return cached_rig("bear", func() -> Rig: return Rig.creature("bear", {}, 0.581))


static func deer() -> Rig:
	return cached_rig("deer", func() -> Rig: return Rig.creature("deer", {}, 1.6))


## A mountain hare in its white winter coat, black tips to its ears: it
## gets about in hops.
static func hare() -> Rig:
	return cached_rig("hare", func() -> Rig:
		var rig := Rig.creature("hare", {}, 0.9)
		rig.gait = &"hop"
		return rig)


# --- Vehicles on the roads ---

## Detailed cars, nose towards -Z, cached by independent body/paint variant.
static func car(variant: int) -> ArrayMesh:
	variant = posmod(variant, CarModels.variant_count())
	return cached_mesh("car_v3_%d" % variant, func() -> ArrayMesh: return CarModels.build(variant))


## A road wheel turned to roll along Z: a tyre, a rim and a hub cap.
static func wheel(kit: MeshKit, at: Vector3, radius: float, width: float, rim: Color) -> void:
	var axle := Vector3(0, 0, PI / 2)
	var outward := signf(at.x) if at.x != 0.0 else 1.0
	kit.cylinder(radius, width, at, Color(0.06, 0.06, 0.07), 16, axle)
	kit.cylinder(radius * 0.62, width + 0.02, at, rim, 12, axle)
	kit.cylinder(radius * 0.22, width + 0.04, at + Vector3(0.01 * outward, 0, 0), rim.darkened(0.3), 8, axle)


## A municipal snow plough: a big orange cab, a curved angled blade, a
## grit spreader body and beacons on the roof.
static func plow() -> ArrayMesh:
	return cached_mesh("plow", func() -> ArrayMesh:
		var kit := MeshKit.new()
		var orange := Color(1.0, 0.55, 0.05)
		var glass := Color(0.16, 0.22, 0.3)
		var black := Color(0.1, 0.1, 0.11)
		var lengthwise := Basis(Vector3.UP, -PI / 2.0)
		# Keep the chassis behind even the swept-back end of the angled blade.
		kit.box(Vector3(2.5, 0.45, 6.65), Vector3(0, 0.85, 0.475), black)
		# Cab: a tall box with a raked windscreen and side windows.
		kit.slab(PackedVector2Array([Vector2(-0.6, 0.9), Vector2(-0.6, 3.2), Vector2(-2.3, 3.2), Vector2(-2.75, 2.2), Vector2(-2.8, 0.9)]), 2.45, Transform3D(lengthwise, Vector3.ZERO), orange)
		kit.slab(PackedVector2Array([Vector2(-0.9, 2.05), Vector2(-0.9, 2.95), Vector2(-2.44, 2.95), Vector2(-2.77, 2.2), Vector2(-2.7, 2.05)]), 2.5, Transform3D(lengthwise, Vector3.ZERO), glass)
		kit.box(Vector3(0.1, 0.9, 0.12), Vector3(1.24, 2.5, -1.7), orange)
		kit.box(Vector3(0.1, 0.9, 0.12), Vector3(-1.24, 2.5, -1.7), orange)
		kit.box(Vector3(2.0, 0.6, 0.05), Vector3(0, 1.4, -2.83), Color(0.2, 0.2, 0.22))
		for side in [-1.0, 1.0]:
			kit.box(Vector3(0.35, 0.2, 0.05), Vector3(0.85 * side, 1.25, -2.83), Palette.HEADLIGHT)
			kit.box(Vector3(0.06, 0.4, 0.25), Vector3(1.4 * side, 2.6, -2.0), black)
			kit.box(Vector3(0.3, 0.12, 0.05), Vector3(0.7 * side, 3.3, -2.25), Palette.HEADLIGHT)
		# Beacons and a light bar on the roof.
		kit.box(Vector3(1.6, 0.12, 0.3), Vector3(0, 3.27, -1.4), black)
		for side in [-1.0, 1.0]:
			kit.cylinder(0.13, 0.22, Vector3(0.65 * side, 3.43, -1.4), Color(1.0, 0.55, 0.0, 0.0), 10)
		# Grit spreader body behind the cab.
		kit.slab(PackedVector2Array([Vector2(3.6, 1.1), Vector2(3.8, 3.0), Vector2(-0.3, 3.0), Vector2(-0.2, 1.1)]), 2.4, Transform3D(lengthwise, Vector3.ZERO), Color(0.35, 0.36, 0.38))
		kit.box(Vector3(2.45, 0.12, 4.1), Vector3(0, 2.95, 1.75), Color(0.25, 0.26, 0.28))
		kit.box(Vector3(2.3, 0.2, 4.0), Vector3(0, 3.06, 1.75), Palette.SNOW)
		kit.cylinder(0.35, 0.2, Vector3(0, 0.8, 3.9), black, 12)
		for side in [-1.0, 1.0]:
			for axle in [-1.8, 1.4, 2.9]:
				wheel(kit, Vector3(1.05 * side, 0.55, axle), 0.55, 0.42, Color(0.85, 0.85, 0.82))
		# A continuous rolled steel blade, with thickness and closed ends.
		# All panels share their boundary positions, unlike the old loose strips.
		var blade := Transform3D(Basis(Vector3.UP, 0.35), Vector3(0, 0, -3.5))
		for k in 10:
			var a := k / 10.0
			var b := (k + 1) / 10.0
			var p := Vector3(0, 0.15 + a * 1.2, -sin(a * PI * 0.8) * 0.3 + a * 0.17)
			var q := Vector3(0, 0.15 + b * 1.2, -sin(b * PI * 0.8) * 0.3 + b * 0.17)
			for front in [true, false]:
				var offset := Vector3(0, 0, -0.04 if front else 0.06)
				kit.quad(blade * (p + Vector3.LEFT * 1.8 + offset), blade * (p + Vector3.RIGHT * 1.8 + offset), blade * (q + Vector3.RIGHT * 1.8 + offset), blade * (q + Vector3.LEFT * 1.8 + offset), orange, blade.basis * (Vector3.FORWARD if front else Vector3.BACK))
			for side in [-1.0, 1.0]:
				var edge := Vector3(side * 1.8, 0, 0)
				kit.quad(blade * (p + edge + Vector3.FORWARD * 0.04), blade * (q + edge + Vector3.FORWARD * 0.04), blade * (q + edge + Vector3.BACK * 0.06), blade * (p + edge + Vector3.BACK * 0.06), orange.darkened(0.15), blade.basis * Vector3.RIGHT * side)
			if k == 0 or k == 9:
				var end := p if k == 0 else q
				kit.quad(blade * (end + Vector3(-1.8, 0, -0.04)), blade * (end + Vector3(1.8, 0, -0.04)), blade * (end + Vector3(1.8, 0, 0.06)), blade * (end + Vector3(-1.8, 0, 0.06)), orange, Vector3.DOWN if k == 0 else Vector3.UP)
		kit.box(Vector3(3.7, 0.10, 0.14), blade * Vector3(0, 0.15, 0), Color(0.3, 0.3, 0.32), Vector3(0, 0.35, 0))
		kit.box(Vector3(0.2, 0.2, 1.0), Vector3(0, 0.7, -3.0), black)
		for side in [-1.0, 1.0]:
			kit.cylinder(0.04, 1.1, blade * Vector3(1.6 * side, 1.4, -0.1), black, 6)
			kit.sphere(0.06, blade * Vector3(1.6 * side, 1.95, -0.1), Color(1.0, 0.3, 0.1))
		return kit.build())


# --- Buildings and roadside furniture ---

## A Swedish wooden house: board-clad walls on a stone plinth, white
## corners, windows with glazing bars, a front door with a porch roof and
## steps, a chimney and snow lying thick on the roof.
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
		var plinth := 0.45
		kit.box(Vector3(width + 0.12, plinth - bottom, depth + 0.12), Vector3(0, (plinth + bottom) * 0.5, 0), Color(0.5, 0.5, 0.52))
		kit.box(Vector3(width, wall_h - plinth, depth), Vector3(0, (wall_h + plinth) * 0.5, 0), walls)
		# Vertical boarding: a shadow line between boards on the long walls.
		var boards := int(width / 0.55)
		for i in boards:
			var x := -width * 0.5 + (i + 0.5) * width / boards
			for face in [-1.0, 1.0]:
				kit.box(Vector3(0.03, wall_h - plinth, 0.03), Vector3(x, (wall_h + plinth) * 0.5, face * (depth * 0.5 + 0.01)), walls.darkened(0.25))
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				kit.box(Vector3(0.22, wall_h - plinth, 0.22), Vector3(sx * width * 0.5, (wall_h + plinth) * 0.5, sz * depth * 0.5), trim)
		# Roof with eaves overhanging the walls, a white barge board along
		# each gable and snow on top.
		var roof_h := 2.4 + width * 0.08
		kit.prism(Vector3(depth + 0.9, roof_h, width + 0.7), Vector3(0, wall_h + roof_h * 0.5, 0), Color(0.22, 0.22, 0.26), Vector3(0, PI / 2, 0))
		for gable in [-1.0, 1.0]:
			var slope := atan2(roof_h, depth * 0.5 + 0.45)
			var run := Vector2(depth * 0.5 + 0.45, roof_h).length()
			for side in [-1.0, 1.0]:
				kit.box(Vector3(0.08, 0.2, run), Vector3(gable * (width * 0.5 + 0.36), wall_h + roof_h * 0.5 - 0.05, side * (depth * 0.25 + 0.22)), trim, Vector3(side * slope, 0, 0))
		roof_snow(kit, width + 0.8, depth + 0.9, roof_h, wall_h)
		var chimney := Vector3(width * 0.25, wall_h + roof_h * 0.75, 0.6)
		kit.box(Vector3(0.7, 1.7, 0.7), chimney, Color(0.55, 0.2, 0.15))
		kit.box(Vector3(0.85, 0.12, 0.85), chimney + Vector3(0, 0.8, 0), Color(0.35, 0.33, 0.33))
		kit.box(Vector3(0.8, 0.22, 0.8), chimney + Vector3(0, 0.95, 0), Palette.SNOW)
		# Front door: panelled, framed, with a little gabled porch roof and
		# stone steps.
		var front := -depth * 0.5
		kit.box(Vector3(1.3, 2.2, 0.1), Vector3(0, plinth + 1.1, front - 0.03), trim)
		kit.box(Vector3(1.0, 2.0, 0.12), Vector3(0, plinth + 1.0, front - 0.04), walls.darkened(0.45) if variant % 5 != 0 and variant % 5 != 4 else Color(0.2, 0.32, 0.25))
		for py in [0.55, 1.45]:
			kit.box(Vector3(0.7, 0.6, 0.14), Vector3(0, plinth + py, front - 0.05), walls.darkened(0.55) if variant % 5 != 0 and variant % 5 != 4 else Color(0.16, 0.26, 0.2))
		kit.sphere(0.04, Vector3(0.38, plinth + 1.0, front - 0.13), Color(0.85, 0.75, 0.4), Vector3.ONE, 6, 4)
		kit.box(Vector3(1.6, 0.06, 0.04), Vector3(0, plinth + 2.25, front - 0.06), trim)
		kit.prism(Vector3(1.9, 0.55, 1.0), Vector3(0, plinth + 2.55, front - 0.5), Color(0.22, 0.22, 0.26))
		kit.prism(Vector3(1.95, 0.3, 1.05), Vector3(0, plinth + 2.78, front - 0.5), Palette.SNOW)
		for step in 2:
			kit.box(Vector3(1.6 - step * 0.3, 0.2, 0.9 - step * 0.35), Vector3(0, 0.1 + step * 0.2, front - 0.5 + step * 0.17), Color(0.6, 0.6, 0.62))
		kit.box(Vector3(1.6, 0.06, 0.9), Vector3(0, 0.23, front - 0.5), Palette.SNOW)
		for floor_index in floors:
			var y := 1.75 + floor_index * 2.4
			for wx in [-width * 0.32, width * 0.32]:
				for face in [-1.0, 1.0]:
					window(kit, Vector3(wx, y, face * depth * 0.5), Vector3(0, 0, face), Vector2(0.95, 1.05), trim, true)
			for face in [-1.0, 1.0]:
				window(kit, Vector3(face * width * 0.5, y, 0), Vector3(face, 0, 0), Vector2(0.95, 1.05), trim, (variant + floor_index) % 2 == 0)
		return kit.build())


## A window set into a wall whose outside faces `out`: a frame, glass
## (lit from inside or dark), white glazing bars crossing it and a sill
## with a little snow on it. `centre` is on the wall's surface.
static func window(kit: MeshKit, centre: Vector3, out: Vector3, size: Vector2, trim: Color, lit: bool) -> void:
	var basis := Basis.looking_at(-out, Vector3.UP)
	var place := func(local: Vector3) -> Vector3: return centre + basis * local
	var glass := Palette.WINDOW_LIGHT if lit else Color(0.25, 0.3, 0.42)
	kit.box(Vector3(size.x + 0.18, size.y + 0.18, 0.08), place.call(Vector3(0, 0, 0.03)), trim, basis.get_euler())
	kit.box(Vector3(size.x, size.y, 0.1), place.call(Vector3(0, 0, 0.04)), glass, basis.get_euler())
	kit.box(Vector3(0.05, size.y, 0.12), place.call(Vector3(0, 0, 0.05)), trim, basis.get_euler())
	kit.box(Vector3(size.x, 0.05, 0.12), place.call(Vector3(0, size.y * 0.1, 0.05)), trim, basis.get_euler())
	kit.box(Vector3(size.x + 0.32, 0.07, 0.2), place.call(Vector3(0, -size.y * 0.5 - 0.12, 0.08)), trim, basis.get_euler())
	kit.box(Vector3(size.x + 0.26, 0.05, 0.16), place.call(Vector3(0, -size.y * 0.5 - 0.06, 0.1)), Palette.SNOW, basis.get_euler())


static func edge_pole(variant: int) -> ArrayMesh:
	return cached_mesh("pole%d" % variant, func() -> ArrayMesh:
		var kit := MeshKit.new()
		var color := Color(1.0, 0.42, 0.05) if variant == 0 else Color(0.1, 0.35, 0.95)
		kit.cylinder(0.05, 1.6, Vector3(0, 0.8, 0), color, 5)
		kit.cylinder(0.055, 0.2, Vector3(0, 1.35, 0), Color(1, 1, 1), 5)
		return kit.build())


## A street lamp: a tapered pole on a base, an arm curving out over the
## road and a lamp head glowing underneath.
static func lamp_post() -> ArrayMesh:
	return cached_mesh("lamp", func() -> ArrayMesh:
		var kit := MeshKit.new()
		var metal := Color(0.32, 0.35, 0.38)
		kit.cylinder(0.16, 0.6, Vector3(0, 0.3, 0), metal.darkened(0.2), 8, Vector3.ZERO, 0.12)
		kit.cylinder(0.1, 4.6, Vector3(0, 2.8, 0), metal, 8, Vector3.ZERO, 0.06)
		var arm: Array[Vector3] = [Vector3(0, 4.9, 0), Vector3(0, 5.15, -0.3), Vector3(0, 5.25, -0.7), Vector3(0, 5.2, -1.15)]
		for i in arm.size() - 1:
			kit.capsule_between(arm[i], arm[i + 1], 0.05, metal, 6)
		var head := Vector3(0, 5.12, -1.3)
		kit.ellipsoid(Vector3(0.22, 0.1, 0.38), head, metal.darkened(0.15))
		kit.ellipsoid(Vector3(0.17, 0.04, 0.3), head + Vector3(0, -0.07, 0), Color(1.0, 0.85, 0.55, 0.0))
		kit.ellipsoid(Vector3(0.2, 0.07, 0.34), head + Vector3(0, 0.08, 0), Palette.SNOW)
		return kit.build())


static func fence() -> ArrayMesh:
	return cached_mesh("fence", func() -> ArrayMesh:
		var kit := MeshKit.new()
		var wood := Color(0.55, 0.47, 0.38)
		var bark := Color(0.45, 0.38, 0.3)
		# A gärdsgård: pairs of upright stakes bound with withies, slender
		# poles laid slanting between them, snow on the top edges.
		for i in 3:
			var x := -2.0 + i * 2.0
			for side in [-1.0, 1.0]:
				kit.capsule_between(Vector3(x, -0.1, side * 0.07), Vector3(x + 0.03, 1.25, side * 0.07), 0.045, bark, 6)
			for band in [0.35, 0.95]:
				kit.torus(0.07, 0.11, Transform3D(Basis.IDENTITY, Vector3(x + 0.01, band, 0)), Color(0.35, 0.3, 0.22), 10, 4)
		for k in 8:
			var x := -2.1 + k * 0.42
			var a := Vector3(x, 0.08, 0)
			var b := Vector3(x + 1.25, 1.1, 0)
			kit.capsule_between(a, b, 0.04, wood if k % 2 == 0 else bark, 6)
			kit.capsule_between(b.lerp(a, 0.35) + Vector3(0, 0.045, 0), b + Vector3(0, 0.04, 0), 0.03, Palette.SNOW, 5)
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


## A5-1 proportions: rounded aluminium plate, broad red rim and the original
## bold, symmetric narrowing symbol. Source contours use a 456 x 405 face.
## https://www.transportstyrelsen.se/sv/vagtrafik/trafikregler-och-vagmarken/vagmarken/varningsmarken/varning-for-avsmalnande-vag/
## Front faces +Z, toward riders coming down the slope.
static func road_narrows_sign() -> ArrayMesh:
	return cached_mesh("road_narrows_sign", func() -> ArrayMesh:
		var kit := MeshKit.new()
		_warning_sign_plate(kit)
		# Convex pieces meet on the reference outline. Reflect their points,
		# rather than the mesh basis, to keep both strokes' winding consistent.
		var stroke := [
			PackedVector2Array([Vector2(145.937, 56.6941), Vector2(179.953, 56.6941), Vector2(179.953, 119.055), Vector2(145.937, 130.394)]),
			PackedVector2Array([Vector2(145.937, 130.394), Vector2(179.953, 119.055), Vector2(216.803, 164.409), Vector2(179.953, 175.748)]),
			PackedVector2Array([Vector2(179.953, 175.748), Vector2(216.803, 164.409), Vector2(216.803, 232.441), Vector2(179.953, 232.441)]),
		]
		for side in [-1.0, 1.0]:
			for piece: PackedVector2Array in stroke:
				var polygon := piece.duplicate()
				for i in polygon.size():
					polygon[i] = Vector2((polygon[i].x - 228.142) * side, polygon[i].y) * 0.004
				if side < 0: polygon.reverse()
				kit.slab(polygon, 0.002, Transform3D(Basis.IDENTITY, Vector3(0, 2.05, 0.020)), Color("111111"))
		return kit.build())


## Common Swedish warning plate: same contours, colours, pole and brackets
## for the A5-inspired bridge warning and the playful A7 lake warning.
static func _warning_sign_plate(kit: MeshKit) -> void:
	var steel := Color("929b9f")
	kit.cylinder(0.035, 2.85, Vector3(0, 1.425, -0.055), steel, 10)
	for y in [2.40, 2.85]:
		kit.box(Vector3(0.22, 0.055, 0.025), Vector3(0, y, -0.017), steel)
	# Six cubic arcs round the three corners without stretching the face.
	var arcs := [
		[Vector2(4.93711, 55.2762), Vector2(-1.6457, 43.8738), Vector2(-1.6457, 29.8262), Vector2(4.93711, 18.425)],
		[Vector2(4.93711, 18.425), Vector2(11.5195, 7.02422), Vector2(23.6852, 0), Vector2(36.8508, 0)],
		[Vector2(419.433, 0), Vector2(432.598, 0), Vector2(444.764, 7.02422), Vector2(451.346, 18.425)],
		[Vector2(451.346, 18.425), Vector2(457.929, 29.8262), Vector2(457.929, 43.8738), Vector2(451.346, 55.2762)],
		[Vector2(260.055, 386.602), Vector2(253.473, 398.004), Vector2(241.307, 405.027), Vector2(228.142, 405.027)],
		[Vector2(228.142, 405.027), Vector2(214.977, 405.027), Vector2(202.811, 398.004), Vector2(196.229, 386.602)],
	]
	var outline := PackedVector2Array()
	for arc: Array in arcs:
		for i in 9:
			var point: Vector2 = (arc[0] as Vector2).bezier_interpolate(arc[1], arc[2], arc[3], i / 8.0)
			point = (point - Vector2(228.142, 0)) * 0.004
			if outline.is_empty() or outline[-1].distance_squared_to(point) > 0.00000001:
				outline.append(point)
	kit.slab(outline, 0.012, Transform3D(Basis.IDENTITY, Vector3(0, 2.05, 0)), steel)
	kit.slab(outline, 0.002, Transform3D(Basis.IDENTITY, Vector3(0, 2.05, 0.010)), Color("e4002b"))
	var yellow := PackedVector2Array([Vector2(-181.4721, 42.5199), Vector2(181.472, 42.5199), Vector2(0, 356.838)])
	for i in yellow.size(): yellow[i] *= 0.004
	kit.slab(yellow, 0.002, Transform3D(Basis.IDENTITY, Vector3(0, 2.05, 0.015)), Color("ffcd00"))


## A7-inspired quay warning, with a three-ski snowracer instead of a car.
## Front faces +Z. The symbol is printed flat, not a miniature 3D vehicle.
## https://www.transportstyrelsen.se/sv/vagtrafik/trafikregler-och-vagmarken/vagmarken/varningsmarken/varning-for-kaj/
static func water_warning_sign() -> ArrayMesh:
	return cached_mesh("water_warning_sign", func() -> ArrayMesh:
		var kit := MeshKit.new()
		_warning_sign_plate(kit)
		# Keep the quay edge and two bold ripples from the reference's layout.
		_warning_ink(kit, PackedVector2Array([Vector2(136, 210), Vector2(196, 210), Vector2(196, 362.5), Vector2(46.7, 362.5)]))
		var inside := PackedVector2Array([Vector2(228.142, 48.189), Vector2(409.614, 362.507), Vector2(46.670, 362.507)])
		for y in [292.0, 328.0]:
			var wave := PackedVector2Array()
			for i in 81:
				var x := 195.0 + i * 3
				wave.append(Vector2(x, y + sin((x - 196) / 52 * TAU) * 4.5 - 7))
			for i in range(80, -1, -1):
				var x := 195.0 + i * 3
				wave.append(Vector2(x, y + sin((x - 196) / 52 * TAU) * 4.5 + 7))
			for clipped: PackedVector2Array in Geometry2D.intersect_polygons(wave, inside): _warning_ink(kit, clipped)
		# Tilt nose-first beyond the quay. The long saddle, open triangular
		# frame, steering wheel and three separate skis identify a snowracer.
		var tilt := Transform2D(deg_to_rad(29), Vector2(240, 207)).scaled_local(Vector2.ONE * 0.92)
		_warning_ink(kit, tilt * PackedVector2Array([Vector2(-55, -24), Vector2(1, -24), Vector2(5, -20), Vector2(3, -12), Vector2(-55, -12), Vector2(-58, -16)]))
		_warning_line(kit, PackedVector2Array([Vector2(-37, 23), Vector2(-29, -12), Vector2(42.5, -11), Vector2(7, 23), Vector2(-37, 23)]), 5.5, tilt)
		_warning_line(kit, PackedVector2Array([Vector2(-29, -12), Vector2(7, 23)]), 5.5, tilt)
		_warning_line(kit, PackedVector2Array([Vector2(51, 23), Vector2(35, -41)]), 6, tilt)
		_warning_line(kit, PackedVector2Array([Vector2(-65, 24), Vector2(-58, 26), Vector2(2, 26), Vector2(15, 20)]), 7, tilt)
		_warning_line(kit, PackedVector2Array([Vector2(-63, 33), Vector2(-55, 35), Vector2(2, 35), Vector2(14, 29)]), 5, tilt)
		for x in [-43.0, -3.0]:
			_warning_line(kit, PackedVector2Array([Vector2(x, 26), Vector2(x + 2, 35)]), 4, tilt)
		_warning_line(kit, PackedVector2Array([Vector2(37, 26), Vector2(72, 26), Vector2(82, 19), Vector2(83, 13)]), 7, tilt)
		# A real hole in the wheel lets the yellow face show through.
		for i in 24:
			var a := Vector2.from_angle(TAU * i / 24)
			var b := Vector2.from_angle(TAU * (i + 1) / 24)
			var center := Vector2(35, -41)
			_warning_ink(kit, tilt * PackedVector2Array([center + a * Vector2(15, 7), center + b * Vector2(15, 7), center + b * Vector2(11, 3), center + a * Vector2(11, 3)]))
		_warning_line(kit, PackedVector2Array([Vector2(24, -41), Vector2(46, -41)]), 3, tilt)
		return kit.build())


## Reference-image coordinates (456 x 405, Y down) to the plate's face.
## Triangulate the concave waves; a convex fan would fill their troughs.
static func _warning_ink(kit: MeshKit, polygon: PackedVector2Array) -> void:
	var indices := Geometry2D.triangulate_polygon(polygon)
	assert(not indices.is_empty(), "Invalid warning pictogram contour")
	var start := kit._vertices.size()
	for point in polygon:
		kit._vertices.append(Vector3((point.x - 228.142) * 0.004, 2.05 + (405.027 - point.y) * 0.004, 0.020))
		kit._normals.append(Vector3.BACK)
		kit._colors.append(Color("111111").srgb_to_linear())
	for i in range(0, indices.size(), 3): kit._triangle_facing(start + indices[i], start + indices[i + 1], start + indices[i + 2])


static func _warning_line(kit: MeshKit, path: PackedVector2Array, width: float, xform: Transform2D) -> void:
	for i in path.size() - 1:
		var a := path[i]
		var b := path[i + 1]
		var offset := (b - a).orthogonal().normalized() * width * 0.5
		_warning_ink(kit, xform * PackedVector2Array([a - offset, a + offset, b + offset, b - offset]))
	for point in path:
		var cap := PackedVector2Array()
		for k in 12: cap.append(xform * (point + Vector2.from_angle(TAU * k / 12) * width * 0.5))
		_warning_ink(kit, cap)


static func ramp_flag() -> ArrayMesh:
	return cached_mesh("flag", func() -> ArrayMesh:
		var kit := MeshKit.new()
		kit.cylinder(0.04, 2.0, Vector3(0, 1.0, 0), Color(0.9, 0.9, 0.9), 5)
		kit.box(Vector3(0.03, 0.4, 0.6), Vector3(0, 1.75, 0.3), Color(0.95, 0.15, 0.2))
		return kit.build())


# --- Town ---

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
		# The ground floor's front is a metre-deep shop window: the walls
		# are built round the opening, lit up inside and dressed with goods.
		var deep := 1.0
		var shop: Array = Shops.TOWN[variant % Shops.TOWN.size()]
		kit.box(Vector3(width, wall_h - bottom, depth - deep), Vector3(0, (wall_h + bottom) * 0.5, deep * 0.5), walls)
		kit.box(Vector3(width, wall_h - 2.45, deep), Vector3(0, (wall_h + 2.45) * 0.5, front + deep * 0.5), walls)
		kit.box(Vector3(width, 0.35 - bottom, deep), Vector3(0, (0.35 + bottom) * 0.5, front + deep * 0.5), walls)
		kit.box(Vector3(0.8, 2.1, deep), Vector3(-4.1, 1.4, front + deep * 0.5), walls)
		kit.box(Vector3(2.6, 2.1, deep), Vector3(3.2, 1.4, front + deep * 0.5), walls)
		kit.box(Vector3(5.6, 2.1, 0.04), Vector3(-0.9, 1.4, front + deep - 0.02), Color(1.0, 0.92, 0.75, 0.8))
		kit.box(Vector3(5.6, 0.04, deep), Vector3(-0.9, 0.37, front + deep * 0.5), Color(0.6, 0.5, 0.4))
		Shops.display(kit, shop[1], Vector3(-0.9, 0.39, front + 0.08), 5.3, deep - 0.15, variant)
		for f in floors:
			kit.box(Vector3(width + 0.15, 0.18, depth + 0.15), Vector3(0, 3.0 * (f + 1) - 0.1, 0), trim)
		for sx in [-1.0, 1.0]:
			kit.box(Vector3(0.3, wall_h - bottom, 0.3), Vector3(sx * width * 0.5, (wall_h + bottom) * 0.5, front), trim)
		# Window frame with an awning over it.
		var frame := Color(0.2, 0.18, 0.18)
		kit.box(Vector3(5.7, 0.12, 0.14), Vector3(-0.9, 2.45, front - 0.02), frame)
		kit.box(Vector3(5.7, 0.14, 0.2), Vector3(-0.9, 0.35, front - 0.03), frame)
		for k in 3:
			kit.box(Vector3(0.06, 2.1, 0.1), Vector3(-3.7 + (k + 1) * 1.4, 1.4, front - 0.02), frame)
		kit.box(Vector3(5.6, 0.35, 0.14), Vector3(-0.9, 0.15, front - 0.05), Color(0.45, 0.45, 0.48))
		# Shop door: a glazed door in a frame, a step in front.
		kit.box(Vector3(1.3, 2.4, 0.12), Vector3(3.1, 1.2, front - 0.03), trim)
		kit.box(Vector3(1.05, 2.2, 0.14), Vector3(3.1, 1.1, front - 0.04), Color(0.3, 0.2, 0.15))
		kit.box(Vector3(0.7, 1.2, 0.16), Vector3(3.1, 1.35, front - 0.05), Color(1.0, 0.88, 0.62, 0.0))
		kit.box(Vector3(1.4, 0.15, 0.6), Vector3(3.1, 0.07, front - 0.3), Color(0.6, 0.6, 0.62))
		# A stone plinth and a cornice under the eaves.
		kit.box(Vector3(width + 0.06, 0.4, depth + 0.06), Vector3(0, 0.0, 0), Color(0.5, 0.5, 0.52))
		kit.box(Vector3(width + 0.3, 0.3, depth + 0.3), Vector3(0, wall_h - 0.1, 0), trim)
		var stripe_a := Palette.JACKETS[variant % Palette.JACKETS.size()] as Color
		for i in 7:
			var stripe := stripe_a if i % 2 == 0 else Color(0.97, 0.97, 0.95)
			kit.box(Vector3(0.82, 0.08, 1.3), Vector3(-3.36 + i * 0.82, 2.75, front - 0.55), stripe, Vector3(-0.35, 0, 0))
		kit.box(Vector3(5.8, 0.08, 1.35), Vector3(-0.9, 2.86, front - 0.52), Palette.SNOW, Vector3(-0.35, 0, 0))
		kit.box(Vector3(5.0, 0.7, 0.1), Vector3(-0.9, 3.4, front - 0.05), Color(0.15, 0.17, 0.25))
		for f in range(1, floors):
			for i in 3:
				var lit := (variant + f + i) % 3 != 0
				var wx := -2.8 + i * 2.8
				window(kit, Vector3(wx, 3.0 * f + 1.5, front), Vector3(0, 0, -1), Vector2(1.05, 1.4), trim, lit)
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


## A green park litter bin on a post, with a hooded lid and a snow cap.
static func bin() -> ArrayMesh:
	return cached_mesh("bin", func() -> ArrayMesh:
		var kit := MeshKit.new()
		var green := Color(0.15, 0.42, 0.25)
		kit.cylinder(0.05, 1.0, Vector3(0, 0.5, 0.36), Color(0.3, 0.32, 0.34), 6)
		kit.cylinder(0.3, 0.75, Vector3(0, 0.55, 0), green, 14, Vector3.ZERO, 0.32)
		for band in [0.3, 0.8]:
			kit.cylinder(0.325, 0.04, Vector3(0, band, 0), green.darkened(0.25), 14)
		kit.sphere(0.34, Vector3(0, 0.95, 0), green.darkened(0.15), Vector3(1, 0.45, 1), 14, 6, true)
		kit.box(Vector3(0.24, 0.12, 0.03), Vector3(0, 0.82, -0.315), Color(0.05, 0.05, 0.05))
		kit.ellipsoid(Vector3(0.3, 0.09, 0.3), Vector3(0, 1.08, 0), Palette.SNOW)
		return kit.build())


# --- Forest trail ---

## A fallen trunk lying along local X, low enough to jump.
static func fallen_log() -> ArrayMesh:
	return cached_mesh("log", func() -> ArrayMesh:
		var kit := MeshKit.new()
		var bark := Palette.TRUNK
		var across := Vector3(0, 0, PI / 2)
		kit.cylinder(0.3, 6.0, Vector3(0, 0.28, 0), bark, 12, across, 0.26)
		# Furrows in the bark along the trunk.
		for i in 8:
			var angle := TAU * i / 8.0 + 0.2
			kit.box(Vector3(5.9, 0.04, 0.04), Vector3(0, 0.28 + sin(angle) * 0.28, cos(angle) * 0.28), bark.darkened(0.3), Vector3(angle, 0, 0))
		# Sawn ends showing their rings.
		for end in [-1.0, 1.0]:
			var face := Transform3D(Basis.from_euler(across), Vector3(end * 3.0, 0.28, 0))
			kit.add(_disc(0.27, 0.03), face, Color(0.8, 0.64, 0.44))
			kit.add(_disc(0.18, 0.04), face, Color(0.7, 0.52, 0.34))
			kit.add(_disc(0.08, 0.05), face, Color(0.84, 0.68, 0.47))
		# Broken-off branch stubs, one still reaching up.
		kit.cylinder(0.08, 0.9, Vector3(0.8, 0.6, 0.12), bark, 6, Vector3(0.5, 0, 0.4), 0.03)
		kit.capsule_between(Vector3(-1.4, 0.4, -0.2), Vector3(-1.55, 0.45, -0.5), 0.06, bark, 6)
		kit.capsule_between(Vector3(1.9, 0.45, 0.15), Vector3(2.0, 0.65, 0.35), 0.05, bark, 6)
		# Snow along the top, and drifted against one side.
		kit.ellipsoid(Vector3(2.85, 0.11, 0.22), Vector3(0, 0.56, 0), Palette.SNOW)
		kit.ellipsoid(Vector3(2.6, 0.22, 0.35), Vector3(0.2, 0.02, 0.3), Palette.SNOW)
		return kit.build())


static func mushroom_ring() -> ArrayMesh:
	return cached_mesh("mushrooms", func() -> ArrayMesh:
		var kit := MeshKit.new()
		for i in 5:
			var angle := i * 1.3
			var at := Vector3(cos(angle) * 0.5, 0, sin(angle) * 0.4)
			kit.cylinder(0.04, 0.18, at + Vector3(0, 0.09, 0), Color(0.95, 0.93, 0.88), 8)
			kit.sphere(0.11, at + Vector3(0, 0.18, 0), Color(0.85, 0.12, 0.1), Vector3(1, 0.6, 1), 10, 5, true)
			for spot in 4:
				var around := spot * 1.7 + i
				kit.sphere(0.018, at + Vector3(cos(around) * 0.06, 0.235 - (spot % 2) * 0.02, sin(around) * 0.06), Color(1, 1, 1), Vector3.ONE, 6, 3)
			kit.cylinder(0.055, 0.02, at + Vector3(0, 0.13, 0), Color(0.95, 0.93, 0.88), 8)
			kit.sphere(0.07, at + Vector3(0.02, 0.0, 0.03), Palette.SNOW, Vector3(1.4, 0.5, 1.4), 8, 4)
		return kit.build())


# --- Frozen river ---

## A pop-up ice-fishing tent: a cube of fabric pulled out at the corners
## by its poles so the walls bow in, guy lines pegged into the snow.
static func tent() -> ArrayMesh:
	return cached_mesh("tent", func() -> ArrayMesh:
		var kit := MeshKit.new()
		var fabric := Color(0.85, 0.15, 0.12)
		var rings: Array[PackedVector3Array] = []
		for level in [[0.0, 1.0], [0.6, 0.93], [1.25, 0.9], [1.6, 0.75], [1.72, 0.0]]:
			var ring := MeshKit.superellipse(1.1 * level[1], 1.1 * level[1], level[0], 24, 1.4)
			rings.append(ring)
		kit.loft(rings, PackedFloat32Array([1, 1, 1, 1, 1]), Transform3D.IDENTITY, fabric)
		# Black hub seams up each corner, a zipped door and a snow skirt.
		for i in 4:
			var angle := TAU * i / 4.0 + PI / 4.0
			var out := Vector3(cos(angle), 0, sin(angle))
			kit.capsule_between(out * 0.97 + Vector3.UP * 0.02, out * 0.68 + Vector3.UP * 1.6, 0.03, Color(0.12, 0.12, 0.14), 5)
			kit.capsule_between(out * 0.82 + Vector3.UP * 1.2, out * 1.9, 0.008, Color(0.9, 0.9, 0.85), 3)
			kit.cylinder(0.02, 0.2, out * 1.9 + Vector3.UP * 0.05, Color(0.6, 0.6, 0.62), 4)
		kit.box(Vector3(0.7, 1.15, 0.04), Vector3(0, 0.62, -1.05), Color(0.42, 0.08, 0.06), Vector3(0.06, 0, 0))
		kit.box(Vector3(0.025, 1.1, 0.05), Vector3(0, 0.62, -1.07), Color(0.1, 0.1, 0.1), Vector3(0.06, 0, 0))
		kit.box(Vector3(0.3, 0.22, 0.04), Vector3(1.03, 1.0, 0), Color(0.3, 0.38, 0.45), Vector3(0, PI / 2.0, 0.08))
		kit.ellipsoid(Vector3(1.2, 0.18, 1.2), Vector3(0, 0.0, 0), Palette.SNOW)
		kit.ellipsoid(Vector3(0.5, 0.06, 0.5), Vector3(0, 1.7, 0), Palette.SNOW)
		# An ice drill left leaning by the door.
		kit.capsule_between(Vector3(0.75, 0.0, -1.35), Vector3(0.8, 1.1, -1.12), 0.025, Color(0.6, 0.6, 0.65), 5)
		kit.capsule_between(Vector3(0.6, 1.02, -1.12), Vector3(1.0, 1.18, -1.12), 0.03, Color(0.15, 0.3, 0.75), 5)
		return kit.build())


static func reeds() -> ArrayMesh:
	return cached_mesh("reeds", func() -> ArrayMesh:
		var kit := MeshKit.new()
		for i in 9:
			var angle := i * 2.4
			var r := 0.15 + (i % 3) * 0.12
			var tall := 1.0 + (i % 4) * 0.25
			var base := Vector3(cos(angle) * r, 0, sin(angle) * r)
			var lean := Vector3(sin(angle) * 0.15, 0, cos(angle) * 0.15)
			var along := Basis.from_euler(lean) * Vector3.UP
			kit.cylinder(0.018, tall, base + along * tall * 0.5, Color(0.75, 0.62, 0.38), 5, lean)
			kit.capsule(0.04, 0.22, base + along * (tall - 0.04), Color(0.45, 0.3, 0.18), lean)
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

## A chairlift tower: a tapered steel column with a ladder, a cross-arm
## carrying a sheave train on each side and a maintenance catwalk.
static func lift_tower() -> ArrayMesh:
	return cached_mesh("lift", func() -> ArrayMesh:
		var kit := MeshKit.new()
		var steel := Color(0.55, 0.58, 0.62)
		var dark := Color(0.2, 0.2, 0.22)
		kit.cylinder(0.6, 0.5, Vector3(0, 0.0, 0), Color(0.6, 0.6, 0.6), 12)
		kit.cylinder(0.3, 9.0, Vector3(0, 4.5, 0), steel, 12, Vector3.ZERO, 0.2)
		for k in 16:
			kit.box(Vector3(0.3, 0.03, 0.03), Vector3(0, 1.0 + k * 0.5, 0.3 - k * 0.006), dark)
		for side in [-1.0, 1.0]:
			kit.box(Vector3(0.03, 8.0, 0.03), Vector3(0.15 * side, 5.0, 0.27), dark)
		kit.box(Vector3(4.2, 0.35, 0.35), Vector3(0, 9.0, 0), steel)
		kit.box(Vector3(4.0, 0.06, 0.8), Vector3(0, 8.75, 0.5), Color(0.4, 0.42, 0.45))
		for side in [-1.0, 1.0]:
			var x: float = 1.8 * side
			kit.box(Vector3(0.2, 0.25, 1.6), Vector3(x, 8.75, 0), dark)
			for k in 4:
				kit.cylinder(0.14, 0.1, Vector3(x, 8.62, -0.6 + k * 0.4), Color(0.12, 0.12, 0.13), 10, Vector3(0, 0, PI / 2))
			kit.capsule_between(Vector3(x * 0.6, 9.1, 0), Vector3(x, 8.85, 0), 0.06, steel, 6)
		kit.box(Vector3(4.3, 0.12, 0.45), Vector3(0, 9.23, 0), Palette.SNOW)
		kit.ellipsoid(Vector3(0.8, 0.15, 0.8), Vector3(0, 0.1, 0), Palette.SNOW)
		return kit.build())


## A unit-length cable segment along X; scale it to span between towers.
static func cable() -> ArrayMesh:
	return cached_mesh("cable", func() -> ArrayMesh:
		return MeshKit.new().box(Vector3(1.0, 0.05, 0.05), Vector3.ZERO, Color(0.15, 0.15, 0.15)).build())


## A two-seat chair hanging from the lift cable by its grip: a bent
## hanger, slatted seat and back, a safety bar with a footrest.
static func chair(variant: int) -> ArrayMesh:
	return cached_mesh("chair%d" % variant, func() -> ArrayMesh:
		var kit := MeshKit.new()
		var metal := Color(0.3, 0.3, 0.33)
		var seat := Color(0.15, 0.35, 0.75)
		kit.box(Vector3(0.3, 0.18, 0.2), Vector3(0, -0.05, 0), Color(0.2, 0.2, 0.22))
		kit.capsule_between(Vector3(0, -0.1, 0), Vector3(0, -1.5, 0.35), 0.04, metal, 6)
		kit.capsule_between(Vector3(0, -1.5, 0.35), Vector3(0, -1.95, 0.3), 0.04, metal, 6)
		kit.capsule_between(Vector3(-0.72, -1.95, 0.25), Vector3(0.72, -1.95, 0.25), 0.035, metal, 6)
		for side in [-1.0, 1.0]:
			kit.capsule_between(Vector3(0.72 * side, -1.95, 0.25), Vector3(0.72 * side, -2.0, -0.25), 0.03, metal, 6)
		for k in 3:
			kit.box(Vector3(1.4, 0.05, 0.14), Vector3(0, -1.98, 0.14 - k * 0.16), seat)
			kit.box(Vector3(1.4, 0.14, 0.04), Vector3(0, -1.8 + k * 0.17, 0.3 + k * 0.03), seat, Vector3(-0.2, 0, 0))
		# Safety bar folded down with a footrest.
		kit.capsule_between(Vector3(-0.72, -1.55, 0.25), Vector3(-0.72, -1.6, -0.4), 0.025, metal, 6)
		kit.capsule_between(Vector3(-0.72, -1.6, -0.4), Vector3(0.6, -1.6, -0.4), 0.025, metal, 6)
		kit.capsule_between(Vector3(0.0, -1.6, -0.4), Vector3(0.0, -2.35, -0.45), 0.02, metal, 6)
		kit.box(Vector3(1.1, 0.03, 0.18), Vector3(0, -2.36, -0.45), metal)
		kit.box(Vector3(1.4, 0.05, 0.4), Vector3(0, -1.94, 0.05), Palette.SNOW)
		if variant == 1:
			var jacket: Color = Palette.JACKETS[2]
			var at := Vector3(-0.35, -1.95, 0.1)
			kit.capsule(0.17, 0.5, at + Vector3(0, 0.33, 0.04), jacket, Vector3(-0.15, 0, 0))
			RideModels.head(kit, at + Vector3(0, 0.73, 0.0), Palette.JACKETS[4])
			for side in [-1.0, 1.0]:
				var hip := at + Vector3(0.09 * side, 0.08, -0.02)
				kit.capsule_between(hip, hip + Vector3(0, 0.0, -0.4), 0.075, RideModels.PANTS)
				kit.capsule_between(hip + Vector3(0, 0, -0.4), hip + Vector3(0, -0.4, -0.45), 0.065, RideModels.PANTS)
				kit.box(Vector3(0.11, 0.08, 0.5), hip + Vector3(0, -0.44, -0.6), Color(0.85, 0.2, 0.15))
				kit.capsule_between(at + Vector3(0.18 * side, 0.5, 0.02), at + Vector3(0.2 * side, 0.32, -0.35), 0.055, jacket)
		return kit.build())


# --- Event visitors ---

## Santa's sleigh: a curved red body with gold trim on runners that curl up
## at the front, Santa at the reins and a sack of presents behind him.
static func santa_sleigh() -> ArrayMesh:
	return cached_mesh("sleigh", func() -> ArrayMesh:
		var kit := MeshKit.new()
		var red := Color(0.78, 0.07, 0.1)
		var gold := Color(1.0, 0.78, 0.2)
		var wood := Color(0.42, 0.22, 0.12)
		# Body, side view in Z/Y: a low prow sweeping up to a tall back.
		var side_view := PackedVector2Array([
			Vector2(1.3, 0.45), Vector2(1.35, 1.55), Vector2(1.0, 1.75), Vector2(0.2, 1.1),
			Vector2(-0.9, 0.95), Vector2(-1.35, 0.75), Vector2(-1.25, 0.45),
		])
		var across := Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3.ZERO)
		kit.slab(side_view, 1.4, across, red)
		kit.box(Vector3(1.2, 0.08, 2.3), Vector3(0, 1.0, 0.05), Color(0.35, 0.05, 0.06))
		for x in [-0.72, 0.72]:
			kit.slab(PackedVector2Array([Vector2(1.0, 1.78), Vector2(0.2, 1.13), Vector2(-0.9, 0.98), Vector2(-1.38, 0.78), Vector2(-1.38, 0.7), Vector2(-0.9, 0.9), Vector2(0.2, 1.05), Vector2(1.0, 1.7)]), 0.05, Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(x, 0, 0)), gold)
		# Swirl ornaments on the sides.
		for side in [-1.0, 1.0]:
			kit.torus(0.14, 0.2, Transform3D(Basis(Vector3.FORWARD, PI / 2.0), Vector3(0.71 * side, 0.75, 0.6)), gold, 16, 5)
			kit.torus(0.08, 0.12, Transform3D(Basis(Vector3.FORWARD, PI / 2.0), Vector3(0.71 * side, 0.7, -0.4)), gold, 14, 5)
		# Runners: struts down to rails that sweep forward and curl up.
		for side in [-1.0, 1.0]:
			var x: float = 0.62 * side
			var rail: Array[Vector3] = [Vector3(x, 0.12, 1.3), Vector3(x, 0.05, 0.6), Vector3(x, 0.05, -0.8), Vector3(x, 0.12, -1.5), Vector3(x, 0.4, -1.9), Vector3(x, 0.72, -1.85), Vector3(x, 0.78, -1.6)]
			for i in rail.size() - 1:
				kit.capsule_between(rail[i], rail[i + 1], 0.05, gold, 7)
			for z in [-0.9, 0.0, 0.9]:
				kit.capsule_between(Vector3(x, 0.07, z), Vector3(x * 0.9, 0.5, z), 0.035, gold, 6)
		# Reins forward to the reindeer.
		for side in [-1.0, 1.0]:
			kit.capsule_between(Vector3(0.25 * side, 1.45, -0.05), Vector3(0.7 * side, 1.2, -3.0), 0.012, wood, 3)
		# Santa: a round red coat with white trim and a black belt.
		var coat := PackedVector2Array([Vector2(0.0, 1.0), Vector2(0.4, 1.02), Vector2(0.46, 1.3), Vector2(0.42, 1.6), Vector2(0.3, 1.85), Vector2(0.0, 1.9)])
		kit.lathe(coat, Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.45)), red, 16)
		kit.cylinder(0.465, 0.12, Vector3(0, 1.38, 0.45), Color(0.08, 0.06, 0.05), 16)
		kit.box(Vector3(0.16, 0.14, 0.04), Vector3(0, 1.38, -0.02), gold)
		kit.box(Vector3(0.1, 0.5, 0.04), Vector3(0, 1.6, 0.04), Color(1, 1, 1), Vector3(-0.35, 0, 0))
		kit.sphere(0.24, Vector3(0, 2.08, 0.42), Palette.SKIN, Vector3.ONE, 14, 8)
		kit.ellipsoid(Vector3(0.24, 0.3, 0.18), Vector3(0, 1.9, 0.3), Color(1, 1, 1))
		kit.ellipsoid(Vector3(0.14, 0.05, 0.06), Vector3(0, 2.0, 0.19), Color(1, 1, 1))
		kit.sphere(0.055, Vector3(0, 2.07, 0.17), Color(1.0, 0.6, 0.55), Vector3.ONE, 8, 5)
		for side in [-1.0, 1.0]:
			kit.sphere(0.03, Vector3(0.08 * side, 2.15, 0.2), Color(0.05, 0.05, 0.05), Vector3.ONE, 8, 4)
			kit.box(Vector3(0.09, 0.025, 0.03), Vector3(0.085 * side, 2.2, 0.2), Color(1, 1, 1))
			var shoulder := Vector3(0.38 * side, 1.7, 0.42)
			var hand := Vector3(0.25 * side, 1.45, -0.05)
			kit.capsule_between(shoulder, hand, 0.1, red, 8)
			kit.cylinder(0.11, 0.07, hand.lerp(shoulder, 0.15), Color(1, 1, 1), 10, Vector3(1.0, 0, 0))
			kit.sphere(0.075, hand, Color(0.1, 0.08, 0.06), Vector3.ONE, 8, 5)
		# Hat: straight up from the fur brim, its tip flopping over backwards
		# with the pom-pom hanging at the end.
		kit.cylinder(0.23, 0.36, Vector3(0, 2.42, 0.42), red, 14, Vector3.ZERO, 0.13)
		var flop := Vector3(0, cos(1.1), sin(1.1))
		var bend := Vector3(0, 2.6, 0.44)
		kit.sphere(0.13, bend, red, Vector3.ONE, 10, 6)
		kit.add(_taper(0.13, 0.03, 0.38), Transform3D(Basis(Vector3.RIGHT, 1.1), bend + flop * 0.19), red)
		kit.torus(0.18, 0.28, Transform3D(Basis.IDENTITY, Vector3(0, 2.25, 0.42)), Color(1, 1, 1), 16, 6)
		kit.sphere(0.08, bend + flop * 0.4, Color(1, 1, 1), Vector3.ONE, 8, 5)
		# Sack of presents, ribboned boxes peeking out of the top.
		kit.sphere(0.55, Vector3(0.05, 1.55, 1.05), Color(0.55, 0.38, 0.22), Vector3(1, 1.05, 0.85), 14, 8)
		kit.cylinder(0.2, 0.14, Vector3(0.05, 2.08, 1.05), Color(0.5, 0.34, 0.2), 10, Vector3.ZERO, 0.15)
		for present in [[Vector3(-0.15, 2.25, 1.0), Color(0.2, 0.6, 0.3), Vector3(0.3, 0.4, 0)], [Vector3(0.25, 2.2, 1.0), Color(0.25, 0.4, 0.9), Vector3(0, 0.8, 0.25)]]:
			kit.box(Vector3(0.3, 0.3, 0.3), present[0], present[1], present[2])
			kit.box(Vector3(0.31, 0.31, 0.06), present[0], gold, present[2])
		return kit.build())


## Santa's reindeer: sturdier than a roe deer, dark with a pale mane and
## great branching antlers; it gallops through the air.
static func reindeer() -> Rig:
	return cached_rig("reindeer", func() -> Rig:
		var rig := Rig.creature("reindeer", {}, 2.0)
		rig.gait = &"gallop"
		return rig)


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


## A static copy of a rig with its limbs frozen at the given gait phase.
## A Blender-made person stands about (its idle, at that phase) and an
## animal is caught mid-stride, baked into a plain mesh (see `baked`).
static func posed(rig: Rig, phase: float, prepare_ahead := false) -> Node3D:
	if rig.kind != "":
		var still := MeshInstance3D.new()
		var key := _pose_key(rig, phase)
		if prepare_ahead and not _baked.has(key):
			if not _pose_jobs.has(key):
				_pose_jobs[key] = {"rig": rig, "phase": phase, "waiters": []}
				_pose_order.append(key)
			(_pose_jobs[key].waiters as Array).append({"node": weakref(still), "rig": rig})
		else:
			still.mesh = baked(rig, phase)
			CreatureRig.dress_mesh(still, rig.colours)
		return still
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	body.mesh = rig.body
	root.add_child(body)
	for limb in rig.limbs:
		var joint := Node3D.new()
		joint.position = limb.pivot
		var mesh := MeshInstance3D.new()
		mesh.mesh = limb.mesh
		joint.add_child(mesh)
		if limb.lower != null:
			var lower := Node3D.new()
			lower.position = limb.joint
			var lower_mesh := MeshInstance3D.new()
			lower_mesh.mesh = limb.lower
			lower.add_child(lower_mesh)
			joint.add_child(lower)
		root.add_child(joint)
	repose(root, rig, phase)
	return root


## Geometry is shared by model, clip and eighth of a cycle. Clothes are
## surface overrides on each instance, so eight outfits need no extra skinning.
static var _baked := {}
static var _crowd := {}
static var _pose_jobs := {}
static var _pose_order: Array[String] = []


static func _pose_key(rig: Rig, phase: float) -> String:
	var step := posmod(roundi(phase / TAU * 8.0), 8)
	var clip := &"idle" if rig.kind == "person" else rig.gait
	return "%s_%s_%d" % [rig.kind, clip, step]


## Static spectators keep the same eight poses and individual outfits, but
## each uses one draw instead of a separate surface for every material.
static func crowd(rig: Rig, phase: float) -> MeshInstance3D:
	var still := MeshInstance3D.new()
	_load_world_cache()
	var key := _pose_key(rig, phase)
	if _crowd.has(key):
		still.mesh = _crowd[key]
		CrowdMesh.dress(still, rig.colours)
	else:
		if not _pose_jobs.has(key):
			_pose_jobs[key] = {"rig": rig, "phase": phase, "waiters": []}
			_pose_order.append(key)
		(_pose_jobs[key].waiters as Array).append({"node": weakref(still), "rig": rig, "crowd": true})
	return still


static func crowd_mesh(rig: Rig, phase: float) -> ArrayMesh:
	_load_world_cache()
	var key := _pose_key(rig, phase)
	if not _crowd.has(key): _crowd[key] = CrowdMesh.build(baked(rig, phase))
	return _crowd[key]


## Synchronous for tools and figures that need to appear immediately.
static func baked(rig: Rig, phase: float) -> ArrayMesh:
	_load_world_cache()
	var key := _pose_key(rig, phase)
	if not _baked.has(key):
		var step := posmod(roundi(phase / TAU * 8.0), 8)
		var figure := CreatureRig.new(rig.kind)
		_baked[key] = figure.bake(&"idle" if rig.kind == "person" else rig.gait, step / 8.0)
		figure.free()
	return _baked[key]


## Prepare at most one pose this frame, ahead of the player. Weak references
## let a removed chunk cancel its pending figures without retaining nodes.
static func prepare_poses(deadline: int) -> void:
	while not _pose_order.is_empty() and deadline - Time.get_ticks_usec() >= 1000:
		var key: String = _pose_order.pop_front()
		var job: Dictionary = _pose_jobs[key]
		_pose_jobs.erase(key)
		var live: Array = (job.waiters as Array).filter(func(entry: Dictionary) -> bool:
			return (entry.node as WeakRef).get_ref() != null)
		if live.is_empty():
			continue
		var mesh := baked(job.rig, job.phase)
		for entry: Dictionary in live:
			var node := (entry.node as WeakRef).get_ref() as MeshInstance3D
			if entry.get("crowd", false):
				node.mesh = crowd_mesh(entry.rig, job.phase)
				CrowdMesh.dress(node, (entry.rig as Rig).colours)
			else:
				node.mesh = mesh
				CreatureRig.dress_mesh(node, (entry.rig as Rig).colours)
		return


static func repose(root: Node3D, rig: Rig, phase: float) -> void:
	if root is CreatureRig:
		(root as CreatureRig).freeze(&"idle" if rig.kind == "person" else rig.gait, phase / TAU)
		return
	for i in rig.limbs.size():
		var limb := rig.limbs[i]
		var angles := limb.pose(phase)
		var joint := root.get_child(i + 1) as Node3D
		joint.rotation.x = angles.x * 1.4
		if limb.lower != null:
			(joint.get_child(1) as Node3D).rotation.x = angles.y


## The finish of a race: an inflatable arch `width` metres across the
## track, chequered along the top, sponsor stripes down the legs.
static func finish_arch(width: int) -> ArrayMesh:
	return cached_mesh("finish%d" % width, func() -> ArrayMesh:
		var kit := MeshKit.new()
		var red := Color(0.9, 0.12, 0.15)
		var half := width * 0.5
		for side in [-1.0, 1.0]:
			kit.capsule_between(Vector3(side * half, 0.0, 0), Vector3(side * half, 5.2, 0), 0.55, red, 12)
			for k in 3:
				kit.cylinder(0.57, 0.3, Vector3(side * half, 1.0 + k * 1.4, 0), Color(1, 1, 1), 12)
			kit.ellipsoid(Vector3(0.9, 0.25, 0.9), Vector3(side * half, 0.0, 0), Palette.SNOW)
		kit.capsule_between(Vector3(-half, 5.6, 0), Vector3(half, 5.6, 0), 0.6, red, 12)
		# A chequered banner hanging under the top tube.
		var squares := int(width / 0.6)
		for i in squares:
			for row in 2:
				var x := -half + 0.6 + (i + 0.5) * (width - 1.2) / squares
				var dark := (i + row) % 2 == 0
				kit.box(Vector3((width - 1.2) / squares, 0.4, 0.06), Vector3(x, 4.75 - row * 0.4, 0), Color(0.08, 0.08, 0.1) if dark else Color(1, 1, 1))
		kit.box(Vector3(width * 0.6, 1.4, 0.08), Vector3(0, 5.9, 0), Color(0.95, 0.75, 0.1))
		return kit.build())


# --- Pickups ---

## A gingerbread man facing -Z, piped with white icing: eyes, a smile,
## buttons and zigzags at his wrists and ankles.
static func gingerbread() -> ArrayMesh:
	return cached_mesh("ginger", func() -> ArrayMesh:
		var kit := MeshKit.new()
		var dough := Color(0.72, 0.4, 0.16)
		var icing := Color(1, 1, 1)
		var flat := Vector3(1, 1, 0.4)
		kit.sphere(0.13, Vector3(0, 0.2, 0), dough, flat, 14, 8)
		kit.capsule(0.12, 0.3, Vector3(0, -0.02, 0), dough, Vector3.ZERO, flat)
		for side in [-1.0, 1.0]:
			kit.capsule(0.06, 0.26, Vector3(0.15 * side, 0.03, 0), dough, Vector3(0, 0, side * 1.1), flat)
			kit.capsule(0.065, 0.28, Vector3(0.07 * side, -0.2, 0), dough, Vector3(0, 0, side * 0.35), flat)
			# Icing: eyes, a zigzag at each wrist and ankle.
			kit.sphere(0.017, _ginger_point(Vector2(0.045 * side, 0.23)), icing, Vector3(1, 1, 0.5), 8, 4)
			for limb in [Vector3(0.15 * side, 0.03, side * 1.1), Vector3(0.07 * side, -0.2, side * 0.35)]:
				var along := Vector2(-sin(limb.z), cos(limb.z))
				var across := Vector2(cos(limb.z), sin(limb.z))
				var center := Vector2(limb.x, limb.y) - along * 0.07
				for k in 4:
					var a: Vector2 = center + across * (-0.04 + k * 0.02) + along * (0.01 if k % 2 else 0)
					var b: Vector2 = center + across * (-0.04 + (k + 1) * 0.02) + along * (0 if k % 2 else 0.01)
					kit.capsule_between(_ginger_point(a), _ginger_point(b), 0.006, icing, 6)
		for k in 5:
			var t := (k - 2.0) / 2.0
			kit.sphere(0.009, _ginger_point(Vector2(t * 0.045, 0.165 + t * t * 0.015)), icing, Vector3.ONE, 8, 4)
		for k in 3:
			kit.sphere(0.02, _ginger_point(Vector2(0, 0.07 - k * 0.07)), [Color(0.95, 0.15, 0.15), icing, Color(0.2, 0.65, 0.3)][k], Vector3(1, 1, 0.5), 8, 4)
		return kit.build())


## Project icing onto the actual flattened capsule/sphere surface. The
## wrist and ankle decorations use the same rotated axes as the biscuit.
static func _ginger_point(point: Vector2) -> Vector3:
	var depth := 0.0
	for part in [Vector4(0, 0.2, 0.13, 0.26), Vector4(0, -0.02, 0.12, 0.3), Vector4(-0.15, 0.03, 0.06, 0.26), Vector4(0.15, 0.03, 0.06, 0.26), Vector4(-0.07, -0.2, 0.065, 0.28), Vector4(0.07, -0.2, 0.065, 0.28)]:
		var angle := 0.0
		if absf(part.x) > 0.1: angle = signf(part.x) * 1.1
		elif part.x != 0: angle = signf(part.x) * 0.35
		var along := Vector2(-sin(angle), cos(angle))
		var local := point - Vector2(part.x, part.y)
		var half := maxf(part.w * 0.5 - part.z, 0)
		var distance := (local - along * clampf(local.dot(along), -half, half)).length_squared()
		depth = maxf(depth, sqrt(maxf(0, part.z * part.z - distance)) * 0.4)
	return Vector3(point.x, point.y, -depth + 0.002)


## A red knitted mitten like the ones counting your lives: a rounded palm,
## a thumb sticking out, white stripes and a fluffy cuff.
static func mitten() -> ArrayMesh:
	return cached_mesh("mitten", func() -> ArrayMesh:
		var kit := MeshKit.new()
		var wool := Color(0.92, 0.18, 0.2)
		var white := Color(1, 1, 1)
		kit.ellipsoid(Vector3(0.21, 0.25, 0.12), Vector3(0, 0.1, 0), wool)
		kit.ellipsoid(Vector3(0.185, 0.18, 0.11), Vector3(0, -0.06, 0), wool)
		kit.capsule(0.065, 0.26, Vector3(0.21, 0.03, 0), wool, Vector3(0, 0, -0.55))
		# Stripes wrap round the hand, poking just through its surface.
		kit.ellipsoid(Vector3(0.216, 0.038, 0.124), Vector3(0, 0.1, 0), white)
		kit.ellipsoid(Vector3(0.208, 0.038, 0.12), Vector3(0, 0.0, 0), white)
		# A straight ribbed cuff, flattened like the hand.
		var cuff := CylinderMesh.new()
		cuff.top_radius = 1.0
		cuff.bottom_radius = 1.0
		cuff.height = 0.14
		cuff.radial_segments = 16
		cuff.rings = 1
		kit.add(cuff, Transform3D(Basis.from_scale(Vector3(0.2, 1.0, 0.125)), Vector3(0, -0.21, 0)), white)
		return kit.build())


## A tin of turbo wax: a squat blue tin with a yellow label band, a
## lightning bolt and a silver lid.
static func wax() -> ArrayMesh:
	return cached_mesh("wax", func() -> ArrayMesh:
		var kit := MeshKit.new()
		kit.lathe(PackedVector2Array([Vector2(0.0, -0.3), Vector2(0.15, -0.3), Vector2(0.16, -0.27), Vector2(0.16, 0.2), Vector2(0.14, 0.24)]), Transform3D.IDENTITY, Color(0.15, 0.4, 0.95), 16)
		kit.cylinder(0.163, 0.22, Vector3(0, -0.04, 0), Color(1.0, 0.85, 0.1), 16)
		kit.lathe(PackedVector2Array([Vector2(0.15, 0.22), Vector2(0.165, 0.24), Vector2(0.165, 0.32), Vector2(0.14, 0.35), Vector2(0.0, 0.36)]), Transform3D.IDENTITY, Color(0.85, 0.87, 0.9), 16)
		var bolt := PackedVector2Array([Vector2(0.02, 0.09), Vector2(-0.05, -0.02), Vector2(0.0, -0.02), Vector2(-0.03, -0.12), Vector2(0.05, 0.02), Vector2(0.0, 0.02)])
		for i in bolt.size():
			var a := bolt[i]
			var b := bolt[(i + 1) % bolt.size()]
			kit.capsule_between(Vector3(a.x, a.y - 0.04, -0.168), Vector3(b.x, b.y - 0.04, -0.168), 0.008, Color(0.9, 0.15, 0.1), 4)
		return kit.build())


# --- The player ---
