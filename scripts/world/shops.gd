class_name Shops
extends RefCounted
## The shops of the town and the mall: what each one is called, what it
## promises and what is on show in its window. Shop fronts have a deep,
## lit window you can see into, dressed with that shop's goods.

enum Kind { FASHION, SHOES, ELECTRONICS, TOYS, SWEETS, FURNITURE, BEAUTY, SALE, BAKERY, BOOKS, FLOWERS, SPORTS, HARDWARE, CAFE }

## Mall shops: name, what it sells, the slogan in the window and the
## sticker on the glass.
const MALL := [
	["Köp & Släng", Kind.FASHION, "Ny garderob varje vecka!", "-70%"],
	["Prylparadiset", Kind.ELECTRONICS, "Saker du inte visste att du behövde", "NYHET!"],
	["Onödigt AB", Kind.TOYS, "Allt du inte behöver – under ett tak", "3 för 2"],
	["Statusprylen", Kind.ELECTRONICS, "Nya modellen! (Samma som förra.)", "Bara 19 999:-"],
	["Slit & Släng", Kind.SHOES, "Håller nästan hela vägen hem", "REA"],
	["Mer Mer Mer", Kind.SALE, "Köp 3, betala för 4!", "MEGAREA"],
	["Kreditkortet", Kind.FURNITURE, "Betala nästa år. Eller året efter.", "0 kr idag!"],
	["Lyckobutiken", Kind.BEAUTY, "Lycka i flaska – 499:-", "Du är värd det"],
	["Impulsköpet", Kind.SWEETS, "Du ville ju ha den. Nyss.", "Plocka 4 hg"],
	["Black Friday Året Runt", Kind.SALE, "Sista chansen! (Igen.)", "-90%"],
	["Tomtens Outlet", Kind.TOYS, "Direkt från fabriken på Nordpolen", "Fri frakt"],
	["Pulkadepån", Kind.SPORTS, "Årets pulka – nu med wifi", "Nyhet 2026"],
]

## Town shops, one per town house variant: name, what it sells.
const TOWN := [
	["Surdegsbageriet", Kind.BAKERY], ["Pizzeria Pulka", Kind.CAFE], ["Kiosken", Kind.SWEETS],
	["Café Snöbollen", Kind.CAFE], ["Bokhandeln", Kind.BOOKS], ["Influencerbutiken", Kind.BEAUTY],
	["Järnhandeln", Kind.HARDWARE], ["Blommor & Bling", Kind.FLOWERS], ["Konditori Grädde", Kind.BAKERY],
	["Sportaffären", Kind.SPORTS], ["Leksakslådan", Kind.TOYS], ["Second hand – Förra säsongen", Kind.FASHION],
]

## Hanging banners down the middle of the mall.
const BANNERS := [
	"KÖP NU – TÄNK SEN", "REA! REA! REA!", "DU ÄR VAD DU KÖPER", "BLACK WEEK – HELA ÅRET",
	"LYCKA FINNS PÅ PLAN 2", "SPARA GENOM ATT HANDLA MER", "FLER PRYLAR = MER JUL", "BEHÖVER? NEJ. VILL HA? JA!",
]

const INK := Color(0.12, 0.12, 0.14)


## A mall shop front 10 m wide along local X, facing -Z: a facade with a
## deep window opening, the shop lit up behind it, goods on display and a
## coloured name band above.
static func mall_front(index: int) -> ArrayMesh:
	return Props.cached_mesh("mallshop%d" % index, func() -> ArrayMesh:
		var kit := MeshKit.new()
		var shop: Array = MALL[index % MALL.size()]
		var band: Color = Palette.JACKETS[index % Palette.JACKETS.size()]
		var facade := Color(0.9, 0.88, 0.84)
		var frame := Color(0.82, 0.83, 0.86)
		var deep := 1.4
		kit.box(Vector3(10.0, 11.0, 6.0 - deep), Vector3(0, 3.0, deep + (6.0 - deep) * 0.5), facade)
		kit.box(Vector3(10.0, 5.0, deep), Vector3(0, 6.0, deep * 0.5), facade)
		kit.box(Vector3(10.0, 2.85, deep), Vector3(0, -1.075, deep * 0.5), facade)
		for side in [-1.0, 1.0]:
			kit.box(Vector3(0.4, 3.15, deep), Vector3(side * 4.8, 1.925, deep * 0.5), facade)
		# Inside: a softly lit back wall, a floor and a ceiling with spots.
		var glow := band.lerp(Color(1, 1, 1), 0.7)
		glow.a = 0.82
		kit.box(Vector3(9.2, 3.15, 0.05), Vector3(0, 1.925, deep - 0.02), glow)
		_back_wall(kit, shop[1], Vector3(0, 0.4, deep - 0.05), 9.0, band, index)
		kit.box(Vector3(9.2, 0.05, deep), Vector3(0, 0.37, deep * 0.5), Color(0.75, 0.72, 0.68))
		for k in 4:
			kit.box(Vector3(0.3, 0.04, 0.3), Vector3(-3.3 + k * 2.2, 3.47, deep * 0.5), Color(1.0, 0.97, 0.9, 0.0))
		display(kit, shop[1], Vector3(0, 0.4, 0.15), 9.0, deep - 0.25, index)
		# Window frame: thin mullions, a sill and a door at one end.
		kit.box(Vector3(9.4, 0.12, 0.16), Vector3(0, 3.44, -0.02), frame)
		kit.box(Vector3(9.4, 0.18, 0.2), Vector3(0, 0.35, -0.02), frame)
		for k in 3:
			kit.box(Vector3(0.08, 3.1, 0.12), Vector3(-2.3 + k * 2.3, 1.9, -0.02), frame)
		# A big lit billboard on the facade for the slogan, in a colour that
		# clashes with the name band.
		var board: Color = Palette.JACKETS[(index + 3) % Palette.JACKETS.size()]
		kit.box(Vector3(7.4, 2.4, 0.12), Vector3(0, 6.35, -0.06), board.darkened(0.15))
		kit.box(Vector3(7.0, 2.0, 0.13), Vector3(0, 6.35, -0.065), board)
		for y in [5.15, 7.55]:
			kit.box(Vector3(7.5, 0.08, 0.16), Vector3(0, y, -0.08), Color(1.0, 0.98, 0.9, 0.2))
		for x in [-3.72, 3.72]:
			kit.box(Vector3(0.08, 2.48, 0.16), Vector3(x, 6.35, -0.08), Color(1.0, 0.98, 0.9, 0.2))
		kit.box(Vector3(1.4, 1.4, 0.14), Vector3(2.6, 6.35, -0.07), Color(1.0, 0.9, 0.1), Vector3(0, 0, 0.4))
		# Name band with a light strip under it, and two flags of ads.
		kit.box(Vector3(10.0, 1.1, 0.25), Vector3(0, 4.05, -0.1), band)
		kit.box(Vector3(10.0, 0.08, 0.3), Vector3(0, 3.5, -0.12), Color(1.0, 0.98, 0.9, 0.0))
		for side in [-1.0, 1.0]:
			kit.box(Vector3(0.06, 1.6, 0.9), Vector3(side * 4.75, 5.6, -0.5), band.lightened(0.2))
			kit.box(Vector3(0.05, 0.05, 1.0), Vector3(side * 4.75, 6.42, -0.45), INK)
		return kit.build())


## The back wall behind the goods: shelves stacked with stock for shops
## that sell lots of little things, posters for the rest.
static func _back_wall(kit: MeshKit, kind: Kind, origin: Vector3, width: float, band: Color, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 17 + 3
	var colors: Array = Palette.JACKETS
	if kind in [Kind.TOYS, Kind.SWEETS, Kind.SALE, Kind.SHOES]:
		for shelf in 2:
			var y := 1.75 + shelf * 0.6
			kit.box(Vector3(width * 0.95, 0.04, 0.3), origin + Vector3(0, y, -0.15), Color(0.95, 0.95, 0.95))
			var x := -width * 0.46
			while x < width * 0.46:
				var size := Vector3(rng.randf_range(0.15, 0.35), rng.randf_range(0.2, 0.45), 0.22)
				kit.box(size, origin + Vector3(x + size.x * 0.5, y + size.y * 0.5 + 0.02, -0.15), colors[rng.randi_range(0, colors.size() - 1)])
				x += size.x + 0.03
	else:
		for side in [-1.0, 1.0]:
			var at: Vector3 = origin + Vector3(side * width * 0.3, 2.2, -0.03)
			kit.box(Vector3(2.0, 1.3, 0.03), at, band.darkened(0.3))
			kit.box(Vector3(1.8, 1.1, 0.035), at, colors[(seed + 2 + int(side)) % colors.size()])
			kit.sphere(0.35, at + Vector3(-0.4, 0, -0.03), Palette.SKINS[posmod(seed * 3 + int(side), Palette.SKINS.size())], Vector3(0.8, 1, 0.1), 12, 6)
			kit.box(Vector3(0.8, 0.12, 0.04), at + Vector3(0.45, 0.25, -0.03), Color(1, 1, 1))
			kit.box(Vector3(0.6, 0.08, 0.04), at + Vector3(0.45, 0.0, -0.03), Color(1, 1, 1))


## What a kind of shop puts in its window. `origin` is the middle of the
## window's front edge at floor level; goods fill `width` across and
## `depth` back from there (towards +Z).
static func display(kit: MeshKit, kind: Kind, origin: Vector3, width: float, depth: float, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 131 + kind
	var at := func(x: float, y: float, z: float) -> Vector3: return origin + Vector3(x, y, z)
	var colors: Array = Palette.JACKETS
	var half := width * 0.5
	match kind:
		Kind.FASHION:
			var count := int(width / 1.6)
			for i in count:
				var x := -half + (i + 0.5) * width / count
				_mannequin(kit, at.call(x, 0, depth * 0.45), colors[(seed + i) % colors.size()], colors[(seed + i + 3) % colors.size()], rng.randf_range(-0.4, 0.4))
			_rack(kit, at.call(0, 0, depth * 0.9), width * 0.8, rng)
		Kind.SHOES:
			for tier in 3:
				var y := 0.3 + tier * 0.45
				var z := depth * (0.25 + tier * 0.25)
				kit.box(Vector3(width * 0.9, 0.05, 0.4), at.call(0, y, z), Color(0.95, 0.95, 0.95))
				kit.box(Vector3(width * 0.9, y, 0.05), at.call(0, y * 0.5, z + 0.2), Color(0.85, 0.85, 0.87))
				var pairs := int(width / 0.9)
				for i in pairs:
					var x := -half * 0.85 + (i + 0.5) * width * 0.85 / pairs
					var shoe: Color = colors[rng.randi_range(0, colors.size() - 1)]
					for side in [-1.0, 1.0]:
						kit.ellipsoid(Vector3(0.07, 0.06, 0.15), at.call(x + side * 0.09, y + 0.07, z), shoe)
						kit.box(Vector3(0.14, 0.025, 0.3), at.call(x + side * 0.09, y + 0.03, z), Color(0.95, 0.95, 0.95))
		Kind.ELECTRONICS:
			# A wall of screens all showing the same bright advert.
			var screen: Color = [Color(0.2, 0.6, 1.0, 0.25), Color(1.0, 0.3, 0.6, 0.25), Color(0.3, 1.0, 0.6, 0.25)][seed % 3]
			for row in 2:
				for col in 4:
					var x := -half * 0.75 + col * width * 0.25
					var y := 1.1 + row * 1.05
					kit.box(Vector3(1.5, 0.9, 0.08), at.call(x, y, depth), INK)
					kit.box(Vector3(1.38, 0.78, 0.09), at.call(x, y, depth - 0.01), screen.lerp(Color(1, 1, 1, 0.25), 0.15 * ((row + col) % 2)))
			# Phones on little stands along the front.
			for i in 7:
				var x := -half * 0.8 + i * width * 0.8 / 6.0
				kit.box(Vector3(0.3, 0.3, 0.3), at.call(x, 0.15, depth * 0.3), Color(0.95, 0.95, 0.96))
				kit.box(Vector3(0.12, 0.24, 0.015), at.call(x, 0.42, depth * 0.3), INK, Vector3(-0.25, 0, 0))
				kit.box(Vector3(0.1, 0.2, 0.016), at.call(x, 0.42, depth * 0.3 - 0.004), screen, Vector3(-0.25, 0, 0))
		Kind.TOYS:
			for i in 14:
				var size := Vector3(rng.randf_range(0.3, 0.7), rng.randf_range(0.3, 0.8), rng.randf_range(0.25, 0.5))
				var x := rng.randf_range(-half * 0.9, half * 0.9)
				kit.box(size, at.call(x, size.y * 0.5, rng.randf_range(0.3, depth)), colors[rng.randi_range(0, colors.size() - 1)], Vector3(0, rng.randf_range(-0.4, 0.4), 0))
			for i in 2:
				_teddy(kit, at.call(-half * 0.5 + i * half, 0, depth * 0.4), Color(0.6, 0.4, 0.22) if i == 0 else Color(0.95, 0.9, 0.85))
			for i in 4:
				kit.sphere(0.18, at.call(rng.randf_range(-half, half) * 0.8, 0.18, depth * 0.15), colors[rng.randi_range(0, colors.size() - 1)], Vector3.ONE, 10, 6)
		Kind.SWEETS:
			for i in int(width / 0.8):
				var x := -half * 0.9 + i * 0.8
				var jar := Vector3(x, 0.55, depth * 0.55)
				kit.cylinder(0.25, 0.04, at.call(jar.x, 0.3, jar.z), Color(0.9, 0.9, 0.92), 12)
				kit.cylinder(0.22, 0.5, at.call(jar.x, jar.y, jar.z), Color(0.8, 0.9, 1.0, 0.85), 12)
				for k in 5:
					kit.sphere(0.06, at.call(jar.x + rng.randf_range(-0.12, 0.12), 0.38 + k * 0.06, jar.z + rng.randf_range(-0.12, 0.12)), colors[rng.randi_range(0, colors.size() - 1)], Vector3.ONE, 6, 4)
				kit.cylinder(0.2, 0.08, at.call(jar.x, 0.84, jar.z), colors[i % colors.size()], 12)
			for i in 5:
				var x := -half * 0.7 + i * width * 0.35
				kit.capsule_between(at.call(x, 0.0, depth * 0.2), at.call(x, 1.1, depth * 0.2), 0.015, Color(1, 1, 1), 4)
				kit.cylinder(0.22, 0.05, at.call(x, 1.25, depth * 0.2), colors[(i + seed) % colors.size()], 14, Vector3(PI / 2, 0, 0))
				kit.cylinder(0.12, 0.06, at.call(x, 1.25, depth * 0.2 - 0.01), Color(1, 1, 1), 14, Vector3(PI / 2, 0, 0))
		Kind.FURNITURE:
			var sofa: Color = colors[seed % colors.size()].darkened(0.2)
			kit.box(Vector3(2.4, 0.45, 0.9), at.call(-1.2, 0.3, depth * 0.55), sofa)
			kit.box(Vector3(2.4, 0.6, 0.25), at.call(-1.2, 0.75, depth * 0.55 + 0.35), sofa)
			for side in [-1.0, 1.0]:
				kit.box(Vector3(0.22, 0.6, 0.9), at.call(-1.2 + side * 1.2, 0.45, depth * 0.55), sofa.darkened(0.1))
			kit.box(Vector3(3.2, 0.02, 1.6), at.call(-1.0, 0.01, depth * 0.5), Color(0.85, 0.75, 0.6))
			kit.box(Vector3(0.7, 0.05, 0.5), at.call(0.7, 0.45, depth * 0.3), Color(0.55, 0.38, 0.24))
			kit.cylinder(0.04, 0.45, at.call(0.7, 0.22, depth * 0.3), INK, 6)
			kit.cylinder(0.03, 1.6, at.call(2.2, 0.8, depth * 0.7), INK, 6)
			kit.cylinder(0.3, 0.35, at.call(2.2, 1.7, depth * 0.7), Color(1.0, 0.9, 0.7, 0.3), 12, Vector3.ZERO, 0.2)
			kit.box(Vector3(1.2, 0.8, 0.05), at.call(-1.2, 1.9, depth - 0.02), colors[(seed + 2) % colors.size()])
			kit.box(Vector3(1.0, 1.4, 0.4), at.call(3.6, 0.7, depth * 0.6), Color(0.95, 0.95, 0.94))
		Kind.BEAUTY:
			for i in 5:
				var x := -half * 0.8 + i * width * 0.2
				var tall := 0.5 + (i % 3) * 0.3
				kit.box(Vector3(0.55, tall, 0.55), at.call(x, tall * 0.5, depth * 0.5), Color(0.97, 0.96, 0.95))
				var glass: Color = [Color(1.0, 0.75, 0.85, 0.6), Color(0.75, 0.85, 1.0, 0.6), Color(1.0, 0.9, 0.55, 0.6)][i % 3]
				kit.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.14, 0.0), Vector2(0.16, 0.18), Vector2(0.08, 0.26), Vector2(0.05, 0.3)]), Transform3D(Basis.IDENTITY, at.call(x, tall, depth * 0.5)), glass, 10)
				kit.cylinder(0.06, 0.12, at.call(x, tall + 0.36, depth * 0.5), Color(0.85, 0.75, 0.3), 8)
			# A big glossy poster: a smiling face in soft focus.
			var poster: Vector3 = at.call(0, 2.0, depth - 0.02)
			kit.box(Vector3(2.4, 1.6, 0.04), poster, Color(1.0, 0.85, 0.85))
			kit.sphere(0.5, poster + Vector3(0, 0, -0.05), Palette.SKINS[posmod(seed * 5 + 2, Palette.SKINS.size())], Vector3(0.8, 1, 0.1), 14, 8)
			kit.ellipsoid(Vector3(0.18, 0.05, 0.02), poster + Vector3(0, -0.2, -0.1), Color(0.85, 0.15, 0.3))
		Kind.SALE:
			for i in 3:
				var x := -half * 0.6 + i * half * 0.6
				kit.box(Vector3(1.6, 0.5, 0.9), at.call(x, 0.25, depth * 0.5), Color(0.9, 0.1, 0.1))
				for k in 10:
					kit.box(Vector3(rng.randf_range(0.15, 0.4), rng.randf_range(0.1, 0.3), rng.randf_range(0.15, 0.3)), at.call(x + rng.randf_range(-0.7, 0.7), 0.55 + rng.randf() * 0.2, depth * 0.5 + rng.randf_range(-0.35, 0.35)), colors[rng.randi_range(0, colors.size() - 1)], Vector3(rng.randf(), rng.randf(), rng.randf()))
			for i in 2:
				var x := -half * 0.5 + i * half
				kit.box(Vector3(1.6, 1.1, 0.06), at.call(x, 2.1, depth - 0.05), Color(1.0, 0.85, 0.1), Vector3(0, 0, 0.12 - i * 0.24))
				kit.box(Vector3(1.4, 0.9, 0.07), at.call(x, 2.1, depth - 0.06), Color(0.9, 0.1, 0.1), Vector3(0, 0, 0.12 - i * 0.24))
		Kind.BAKERY:
			for tier in 2:
				var y := 0.45 + tier * 0.55
				var z := depth * (0.35 + tier * 0.35)
				kit.box(Vector3(width * 0.9, 0.05, 0.45), at.call(0, y, z), Color(0.55, 0.38, 0.24))
				for i in int(width / 0.45):
					var x := -half * 0.85 + i * 0.45
					if (i + tier) % 3 == 0:
						kit.cylinder(0.17, 0.12, at.call(x, y + 0.08, z), Color(0.98, 0.95, 0.9), 12)
						kit.cylinder(0.15, 0.06, at.call(x, y + 0.17, z), Color(0.95, 0.5, 0.6), 12)
						kit.sphere(0.03, at.call(x, y + 0.22, z), Color(0.85, 0.1, 0.1), Vector3.ONE, 6, 4)
					else:
						kit.ellipsoid(Vector3(0.18, 0.09, 0.1), at.call(x, y + 0.1, z), Color(0.72, 0.45, 0.2).darkened(rng.randf() * 0.15))
			# A three-tier cake as the showpiece.
			for k in 3:
				kit.cylinder(0.45 - k * 0.12, 0.28, at.call(half * 0.6, 0.15 + k * 0.28, depth * 0.2), Color(0.98, 0.96, 0.92), 16)
			kit.sphere(0.07, at.call(half * 0.6, 1.0, depth * 0.2), Color(0.85, 0.1, 0.15), Vector3.ONE, 8, 5)
		Kind.BOOKS:
			for tier in 3:
				var y := 0.25 + tier * 0.6
				var z := depth * 0.75
				kit.box(Vector3(width * 0.9, 0.04, 0.35), at.call(0, y, z), Color(0.5, 0.35, 0.22))
				var x := -half * 0.88
				while x < half * 0.88:
					var thick := rng.randf_range(0.05, 0.12)
					var tall := rng.randf_range(0.3, 0.48)
					kit.box(Vector3(thick, tall, 0.28), at.call(x + thick * 0.5, y + tall * 0.5, z), colors[rng.randi_range(0, colors.size() - 1)].darkened(rng.randf() * 0.4))
					x += thick + 0.01
			for i in 4:
				var x := -half * 0.6 + i * width * 0.2
				kit.box(Vector3(0.35, 0.5, 0.06), at.call(x, 0.3, depth * 0.25), colors[(i + seed) % colors.size()], Vector3(-0.3, 0, 0))
		Kind.FLOWERS:
			for i in int(width / 0.7):
				var x := -half * 0.9 + i * 0.7
				var z := depth * (0.3 + (i % 2) * 0.35)
				kit.cylinder(0.18, 0.4, at.call(x, 0.2, z), Color(0.35, 0.38, 0.42), 10, Vector3.ZERO, 0.22)
				var bloom: Color = [Color(0.95, 0.2, 0.3), Color(1.0, 0.85, 0.2), Color(0.95, 0.5, 0.7), Color(1, 1, 1), Color(0.6, 0.3, 0.8)][rng.randi_range(0, 4)]
				for k in 6:
					var top: Vector3 = at.call(x + rng.randf_range(-0.15, 0.15), rng.randf_range(0.75, 1.05), z + rng.randf_range(-0.15, 0.15))
					kit.capsule_between(at.call(x, 0.35, z), top, 0.01, Color(0.25, 0.5, 0.25), 3)
					kit.sphere(0.07, top, bloom, Vector3.ONE, 6, 4)
		Kind.SPORTS:
			# Skis standing in a rack, a sledge on show and a racer in a suit.
			for i in 8:
				var x := -half * 0.85 + i * 0.3
				var color: Color = colors[(i + seed) % colors.size()]
				kit.box(Vector3(0.09, 1.7, 0.03), at.call(x, 0.85, depth * 0.8), color, Vector3(0, 0, 0.05))
			_display_sled(kit, at.call(0.4, 0.0, depth * 0.45))
			_mannequin(kit, at.call(half * 0.65, 0, depth * 0.5), colors[(seed + 1) % colors.size()], Color(0.15, 0.15, 0.2), -0.3)
			for i in 3:
				kit.sphere(0.15, at.call(-half * 0.2 + i * 0.4, 0.15, depth * 0.15), colors[(i + 4) % colors.size()], Vector3(1, 0.8, 1.1), 10, 5, true)
		Kind.HARDWARE:
			for i in 5:
				var x := -half * 0.8 + i * 0.45
				kit.capsule_between(at.call(x, 0.4, depth * 0.7), at.call(x + 0.1, 1.6, depth * 0.75), 0.02, Color(0.55, 0.38, 0.24), 4)
				kit.box(Vector3(0.45, 0.04, 0.4), at.call(x, 0.25, depth * 0.65), colors[(i + 2) % colors.size()], Vector3(0.4, 0, 0))
			for i in 9:
				kit.cylinder(0.14, 0.22, at.call(0.4 + (i % 3) * 0.32, 0.11 + (i / 3) * 0.23, depth * 0.5), [Color(0.85, 0.85, 0.87), Color(0.62, 0.13, 0.1), Color(0.2, 0.4, 0.8)][i % 3], 10)
			for side in [-1.0, 1.0]:
				kit.box(Vector3(0.05, 1.8, 0.05), at.call(half * 0.6 + side * 0.2, 0.9, depth * 0.75), Color(0.75, 0.77, 0.8))
			for k in 6:
				kit.box(Vector3(0.4, 0.04, 0.04), at.call(half * 0.6, 0.2 + k * 0.3, depth * 0.75), Color(0.75, 0.77, 0.8))
		Kind.CAFE:
			for i in 2:
				var x := -half * 0.5 + i * half
				kit.cylinder(0.35, 0.04, at.call(x, 0.72, depth * 0.45), Color(0.97, 0.97, 0.95), 14)
				kit.cylinder(0.04, 0.7, at.call(x, 0.36, depth * 0.45), INK, 6)
				for side in [-1.0, 1.0]:
					kit.box(Vector3(0.38, 0.05, 0.38), at.call(x + side * 0.55, 0.45, depth * 0.45), Color(0.55, 0.38, 0.24))
					kit.box(Vector3(0.38, 0.45, 0.05), at.call(x + side * 0.55, 0.7, depth * 0.45 + 0.18), Color(0.55, 0.38, 0.24))
				kit.cylinder(0.05, 0.09, at.call(x + 0.1, 0.79, depth * 0.45), Color(1, 1, 1), 8)
				kit.cylinder(0.12, 0.02, at.call(x - 0.1, 0.75, depth * 0.45), Color(1, 1, 1), 10)
				kit.cylinder(0.08, 0.06, at.call(x - 0.1, 0.79, depth * 0.45), Color(0.72, 0.45, 0.2), 10)
			kit.box(Vector3(width * 0.5, 1.0, 0.5), at.call(0, 0.5, depth * 0.9), Color(0.45, 0.3, 0.2))
			kit.cylinder(0.25, 0.4, at.call(half * 0.2, 1.2, depth * 0.9), Color(0.8, 0.82, 0.85), 10)


## A banner hung across the mall from the ceiling, `width` metres wide,
## its middle at the origin: a bright cloth with a dark border on cords.
static func banner(width: int, index: int) -> ArrayMesh:
	return Props.cached_mesh("banner%d_%d" % [width, index % 4], func() -> ArrayMesh:
		var kit := MeshKit.new()
		var cloth: Color = [Color(0.9, 0.1, 0.15), Color(1.0, 0.8, 0.1), Color(0.1, 0.35, 0.85), Color(0.95, 0.3, 0.6)][index % 4]
		kit.box(Vector3(width, 1.3, 0.04), Vector3.ZERO, cloth)
		kit.box(Vector3(width + 0.1, 0.1, 0.06), Vector3(0, 0.68, 0), INK)
		kit.box(Vector3(width + 0.1, 0.1, 0.06), Vector3(0, -0.68, 0), INK)
		for side in [-1.0, 1.0]:
			kit.capsule_between(Vector3(side * width * 0.45, 0.7, 0), Vector3(side * width * 0.45, 2.2, 0), 0.015, INK, 3)
		return kit.build())


## A display mannequin: a featureless white figure on a stand, wearing a
## top and trousers, turned a little.
static func _mannequin(kit: MeshKit, base: Vector3, top: Color, legs: Color, turn: float) -> void:
	var white := Color(0.95, 0.95, 0.95)
	var facing := Basis(Vector3.UP, turn)
	kit.cylinder(0.25, 0.04, base + Vector3(0, 0.02, 0), INK, 12)
	kit.cylinder(0.025, 0.3, base + Vector3(0, 0.17, 0), Color(0.7, 0.7, 0.72), 6)
	for side in [-1.0, 1.0]:
		kit.capsule_between(base + facing * Vector3(side * 0.09, 0.95, 0), base + facing * Vector3(side * 0.1, 0.3, 0), 0.075, legs, 8)
	kit.capsule(0.19, 0.6, base + Vector3(0, 1.25, 0), top, facing.get_euler(), Vector3(1, 1, 0.7))
	for side in [-1.0, 1.0]:
		kit.capsule_between(base + facing * Vector3(side * 0.24, 1.45, 0), base + facing * Vector3(side * 0.3, 0.98, -0.05), 0.06, top, 8)
		kit.sphere(0.05, base + facing * Vector3(side * 0.31, 0.93, -0.05), white, Vector3.ONE, 6, 4)
	kit.cylinder(0.05, 0.1, base + Vector3(0, 1.6, 0), white, 8)
	kit.sphere(0.12, base + Vector3(0, 1.75, 0), white, Vector3(0.9, 1.15, 0.95), 10, 6)


## A clothes rail along X with garments hanging from it.
static func _rack(kit: MeshKit, centre: Vector3, length: float, rng: RandomNumberGenerator) -> void:
	var steel := Color(0.75, 0.77, 0.8)
	kit.capsule_between(centre + Vector3(-length * 0.5, 1.5, 0), centre + Vector3(length * 0.5, 1.5, 0), 0.02, steel, 5)
	for side in [-1.0, 1.0]:
		kit.capsule_between(centre + Vector3(side * length * 0.5, 0.0, 0), centre + Vector3(side * length * 0.5, 1.5, 0), 0.02, steel, 5)
	var x := -length * 0.48
	while x < length * 0.48:
		kit.box(Vector3(0.06, 0.8, 0.45), centre + Vector3(x, 1.08, 0), Palette.JACKETS[rng.randi_range(0, Palette.JACKETS.size() - 1)])
		x += rng.randf_range(0.09, 0.16)


static func _teddy(kit: MeshKit, base: Vector3, fur: Color) -> void:
	kit.sphere(0.3, base + Vector3(0, 0.32, 0), fur, Vector3(1, 1.1, 0.9), 10, 6)
	kit.sphere(0.22, base + Vector3(0, 0.78, 0), fur, Vector3.ONE, 10, 6)
	kit.sphere(0.09, base + Vector3(0, 0.74, -0.18), fur.lightened(0.3), Vector3.ONE, 8, 4)
	kit.sphere(0.035, base + Vector3(0, 0.77, -0.27), INK, Vector3.ONE, 6, 3)
	for side in [-1.0, 1.0]:
		kit.sphere(0.08, base + Vector3(side * 0.17, 0.97, 0), fur, Vector3(1, 1, 0.6), 8, 4)
		kit.sphere(0.03, base + Vector3(side * 0.08, 0.84, -0.19), INK, Vector3.ONE, 6, 3)
		kit.sphere(0.11, base + Vector3(side * 0.28, 0.42, -0.05), fur, Vector3.ONE, 8, 4)
		kit.sphere(0.12, base + Vector3(side * 0.15, 0.08, -0.15), fur, Vector3.ONE, 8, 4)
	kit.ellipsoid(Vector3(0.12, 0.03, 0.06), base + Vector3(0, 0.62, -0.17), Color(0.85, 0.1, 0.15))


## A red plastic sledge standing on a plinth, tilted to show it off.
static func _display_sled(kit: MeshKit, base: Vector3) -> void:
	kit.box(Vector3(1.2, 0.3, 0.8), base + Vector3(0, 0.15, 0), Color(0.95, 0.95, 0.96))
	var red := Color(0.86, 0.1, 0.12)
	var tilt := Basis(Vector3.RIGHT, -0.5)
	var at := base + Vector3(0, 0.75, 0)
	kit.ellipsoid(Vector3(0.38, 0.12, 0.65), at, red, tilt.get_euler())
	kit.ellipsoid(Vector3(0.3, 0.06, 0.55), at + tilt * Vector3(0, 0.08, 0), red.lightened(0.2), tilt.get_euler())
	kit.capsule_between(at + tilt * Vector3(-0.2, 0.15, -0.62), at + tilt * Vector3(0.2, 0.15, -0.62), 0.02, Color(1.0, 0.82, 0.15), 5)


## A text sign: a flat, unlit label.
## Fit every shop name inside its five-metre sign, including long names.
static func town_sign(index: int) -> Label3D:
	var sign := label(TOWN[index % TOWN.size()][0], 64, 0.009, Color(1, 0.95, 0.75))
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(sign.text, HORIZONTAL_ALIGNMENT_LEFT, -1, sign.font_size).x
	sign.pixel_size = minf(sign.pixel_size, 4.5 / maxf(width, 1))
	return sign


static func label(text: String, size: int, pixel: float, color := Color(1, 1, 1)) -> Label3D:
	var sign := Label3D.new()
	sign.text = text
	sign.font_size = size
	sign.pixel_size = pixel
	sign.outline_size = 0
	sign.modulate = color
	sign.shaded = false
	sign.double_sided = false
	return sign
