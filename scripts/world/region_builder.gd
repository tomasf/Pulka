class_name RegionBuilder
extends RefCounted
## Builds the special regions of the slope: their scenery, ground markings,
## obstacles and traffic. SlopeWorld calls in here for every chunk that lies
## inside a region.

var world: SlopeWorld
var field: TerrainField:
	get:
		return world.field


func _init(owner: SlopeWorld) -> void:
	world = owner


func place_scenery(chunk: Chunk, decor: Dictionary, rng: RandomNumberGenerator, d0: float, d1: float) -> void:
	var span := field.region_span(d0)
	var kind := int(field.region_span(span.x + 1.0).z)
	if kind == TerrainField.Region.SLOPE or span.y <= d0 or span.x >= d1:
		return
	# No banner or warning: regions just happen.
	if span.x >= d0 and span.x < d1:
		_spawn_traffic(kind, span)
	var lo := maxf(d0, span.x + 6.0)
	var hi := minf(d1, span.y - 6.0)
	match kind:
		TerrainField.Region.TOWN:
			_place_town(chunk, decor, rng, lo, hi)
		TerrainField.Region.RIVER:
			_place_river(decor, rng, lo, hi, span)
		TerrainField.Region.PARK:
			_place_park(chunk, decor, rng, lo, hi, span)
		TerrainField.Region.WOODS:
			_place_woods(chunk, decor, rng, lo, hi)
		TerrainField.Region.MALL:
			_place_mall(chunk, decor, rng, lo, hi, span)
		TerrainField.Region.RAIL:
			_place_rail(chunk, decor, lo, hi, span)
			_place_turn_off_arrows(decor, lo, hi, span)
		TerrainField.Region.AIRPORT:
			_place_airport(chunk, decor, rng, lo, hi, span)
		TerrainField.Region.LAKE:
			_place_lake(chunk, decor, rng, lo, hi, span)
		TerrainField.Region.BANDY:
			_place_bandy(chunk, decor, rng, lo, hi, span)
		TerrainField.Region.HIGHWAY:
			_place_motorway(chunk, decor, rng, lo, hi, span)
			_place_turn_off_arrows(decor, lo, hi, span)
		TerrainField.Region.CLIFF:
			_place_cliff(chunk, decor, rng, lo, hi, span)


func _place_town(chunk: Chunk, decor: Dictionary, rng: RandomNumberGenerator, lo: float, hi: float) -> void:
	for side in [-1.0, 1.0]:
		var d: float = ceilf((lo - side * 3.0) / 9.6) * 9.6 + side * 3.0
		while d < hi:
			if field.near_road(d, 6.0):
				d += 9.6
				continue
			var yaw := world.street_yaw(d)
			var variant := rng.randi_range(0, 11)
			var lx: float = side * (field.half_width(d) + 3.0 + 4.5)
			var x := field.center_x(d) + lx
			var facing: float = (PI / 2.0 if side > 0.0 else -PI / 2.0) - yaw
			var xform := Transform3D(Basis(Vector3.UP, facing), Vector3(x, field.height(x, d, false) - 0.1, -d))
			world.add_decor(decor, Props.town_house(variant), xform)
			var sign := Label3D.new()
			sign.text = Props.SHOP_NAMES[rng.randi_range(0, Props.SHOP_NAMES.size() - 1)]
			sign.font_size = 64
			sign.pixel_size = 0.009
			sign.outline_size = 0
			sign.modulate = Color(1.0, 0.95, 0.75)
			sign.shaded = false
			sign.double_sided = false
			sign.transform = xform * Transform3D(Basis(Vector3.UP, PI), Vector3(-0.9, 3.4, -4.62))
			chunk.add_child(sign)
			d += 9.6
	var lamp := ceilf(lo / 18.0) * 18.0
	while lamp < hi:
		if not field.near_road(lamp, 3.0):
			var hw := field.half_width(lamp)
			var cx := field.center_x(lamp)
			var yaw := world.street_yaw(lamp)
			world.add_decor(decor, Props.lamp_post(), world.ground_xform(cx + hw + 0.8, lamp, PI / 2.0 - yaw))
			world.add_decor(decor, Props.lamp_post(), world.ground_xform(cx - hw - 0.8, lamp, -PI / 2.0 - yaw))
			if int(lamp / 18.0) % 2 == 0:
				var span_width := int(hw * 2.0 + 2.0)
				var lights := Transform3D(Basis(Vector3.UP, -yaw), Vector3(cx, field.height(cx, lamp, false) + 6.8, -lamp))
				world.add_decor(decor, Props.light_string(span_width), lights)
		lamp += 18.0


func _place_woods(chunk: Chunk, decor: Dictionary, rng: RandomNumberGenerator, lo: float, hi: float) -> void:
	for i in int((hi - lo) * 2.2):
		var d := rng.randf_range(lo, hi)
		var side := world.random_sign(rng)
		var gap := rng.randf_range(0.9, 30.0)
		gap = gap * gap / 30.0 + 0.9
		var x := field.center_x(d) + side * (field.half_width(d) + gap)
		var mesh: Mesh = Props.birch() if rng.randf() < 0.15 else Props.spruce(rng.randi_range(0, 2))
		world.add_tree(chunk, decor, mesh, world.ground_xform(x, d, rng.randf() * TAU, rng.randf_range(1.0, 2.0), 0.2))
	for i in int((hi - lo) / 12.0):
		var d := rng.randf_range(lo, hi)
		var side := world.random_sign(rng)
		var x := field.center_x(d) + side * (field.half_width(d) + rng.randf_range(1.0, 8.0))
		var pick := rng.randf()
		if pick < 0.4:
			world.add_decor(decor, Props.mushroom_ring(), world.ground_xform(x, d, rng.randf() * TAU, rng.randf_range(0.8, 1.4)))
		elif pick < 0.7:
			world.add_decor(decor, Props.fallen_log(), world.ground_xform(x, d, rng.randf() * TAU, rng.randf_range(0.7, 1.1), 0.1))
		else:
			world.add_decor(decor, Props.rock(rng.randi_range(0, 1)), world.ground_xform(x, d, rng.randf() * TAU, rng.randf_range(0.8, 1.6), 0.3))


func _place_river(decor: Dictionary, rng: RandomNumberGenerator, lo: float, hi: float, span: Vector3) -> void:
	for i in int((hi - lo) / 3.0):
		var d := rng.randf_range(lo, hi)
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var hw := field.half_width(d)
		var lx := side * (hw + rng.randf_range(0.5, 6.0))
		world.add_decor(decor, Props.rock(rng.randi_range(0, 1)), world.ground_xform(field.center_x(d) + lx, d, rng.randf() * TAU, rng.randf_range(1.2, 2.8), 0.5))
		if rng.randf() < 0.6:
			var reed_x := field.center_x(d) + side * (hw - rng.randf_range(0.2, 1.2))
			world.add_decor(decor, Props.reeds(), world.ground_xform(reed_x, d + rng.randf_range(-3.0, 3.0), rng.randf() * TAU, rng.randf_range(0.8, 1.3)))
	var middle := (span.x + span.y) * 0.5
	if middle >= lo and middle < hi:
		var cx := field.center_x(middle)
		var hw := field.half_width(middle)
		var deck := field.height(cx + hw + 8.0, middle, false) + 0.5
		var bridge := Transform3D(Basis(Vector3.UP, -world.street_yaw(middle)), Vector3(cx, deck, -middle))
		world.add_decor(decor, Props.footbridge(int(hw * 2.0 + 16.0)), bridge)


func _place_park(chunk: Chunk, decor: Dictionary, rng: RandomNumberGenerator, lo: float, hi: float, span: Vector3) -> void:
	var step := 40.0
	var tower := ceilf(lo / step) * step
	while tower < hi:
		var top := _lift_top(tower)
		world.add_decor(decor, Props.lift_tower(), Transform3D(Basis(Vector3.UP, -world.street_yaw(tower)), top - Vector3(0, 9.0, 0)))
		var next := tower + step
		if next < span.y - 6.0:
			var next_top := _lift_top(next)
			for side in [-1.0, 1.0]:
				var offset := Vector3(1.8 * side, -0.2, 0)
				var a := top + offset
				var b := next_top + offset
				var along := b - a
				var cable_basis := Basis.looking_at(along.normalized(), Vector3.UP) * Basis(Vector3.UP, PI / 2.0)
				world.add_decor(decor, Props.cable(), Transform3D(cable_basis.scaled_local(Vector3(along.length(), 1, 1)), (a + b) * 0.5))
				for k in 3:
					var t := (k + 0.5 + (0.3 if side > 0.0 else 0.0)) / 3.0
					var hang := a.lerp(b, t)
					world.add_decor(decor, Props.chair(rng.randi_range(0, 1)), Transform3D(Basis(Vector3.UP, -world.street_yaw(tower)), hang))
		tower = next
	var lodge_d := span.x + 30.0
	if lodge_d >= lo and lodge_d < hi:
		var x := field.center_x(lodge_d) - field.half_width(lodge_d) - 14.0
		var xform := Transform3D(Basis(Vector3.UP, -PI / 2.0 - world.street_yaw(lodge_d)), Vector3(x, field.height(x, lodge_d, false) - 0.2, -lodge_d))
		world.add_decor(decor, Props.town_house(3), xform)
		var sign := Label3D.new()
		sign.text = "Stugan – Våfflor 25:-"
		sign.font_size = 64
		sign.pixel_size = 0.009
		sign.modulate = Color(1.0, 0.95, 0.75)
		sign.shaded = false
		sign.double_sided = false
		sign.transform = xform * Transform3D(Basis(Vector3.UP, PI), Vector3(-0.9, 3.4, -4.62))
		chunk.add_child(sign)


func _lift_top(d: float) -> Vector3:
	var x := field.center_x(d) + field.half_width(d) + 7.0
	return Vector3(x, field.height(x, d, false) + 9.0, -d)


## Cars parked along the kerbs of a town street. Landing on their roofs works too.
func _park_cars(chunk: Chunk, rng: RandomNumberGenerator, d0: float, d1: float) -> void:
	for i in rng.randi_range(2, 4):
		var d := rng.randf_range(d0, d1)
		if field.near_road(d, 12.0) or field.region(d) != TerrainField.Region.TOWN:
			continue
		var side := world.random_sign(rng)
		var x := field.center_x(d) + side * (field.half_width(d) - 1.3)
		var car := Obstacle.new().configure(Obstacle.Kind.CAR, world.obstacle_rig(Obstacle.Kind.CAR, rng), field)
		car.position = Vector3(x, field.height(x, d), -d)
		car.rotation.y = -world.street_yaw(d) + (PI if rng.randf() < 0.5 else 0.0)
		chunk.add_child(car)
		chunk.obstacles.append(car)


# --- Ground ---

## sRGB ground colour inside region `kind` (lx is the offset from the track
## centre, outside > 0 beyond the edge).
func ground_color(kind: TerrainField.Region, x: float, lx: float, d: float, hw: float) -> Color:
	var outside := absf(lx) - hw
	match kind:
		TerrainField.Region.TOWN:
			if outside < -0.2:
				return Color(0.66, 0.66, 0.7) if absf(absf(lx) - 3.2) < 0.7 else Color(0.8, 0.8, 0.83)
			if outside < 3.0:
				return Color(0.88, 0.88, 0.9)
		TerrainField.Region.RIVER:
			if outside < -0.3:
				return Palette.ICE.lerp(Color(0.85, 0.93, 1.0), 0.5 + 0.5 * sin(x * 0.3 + d * 0.11))
			if outside < 9.0:
				return Color(0.72, 0.74, 0.8)
		TerrainField.Region.PARK:
			if outside < -0.5:
				return Color(0.95, 0.97, 1.0) if int(d * 0.8) % 2 == 0 else Color(0.91, 0.94, 0.99)
			if outside < 2.5:
				return Palette.SNOW_EDGE
		TerrainField.Region.WOODS:
			return Color(0.88, 0.88, 0.9) if outside < -0.3 else Color(0.84, 0.89, 0.97)
		TerrainField.Region.MALL:
			if outside < 0.0:
				var tile := (int(floorf(lx / 2.0)) + int(floorf(d / 2.0))) % 2 == 0
				return Color(0.88, 0.84, 0.76) if tile else Color(0.72, 0.68, 0.62)
			return Color(0.6, 0.58, 0.55)
		TerrainField.Region.RAIL:
			for lane in RAIL_LANES:
				if absf(lx - lane - sweep(d)) < 1.7:
					return Color(0.55, 0.52, 0.5)
			if outside < 0.0:
				return Color(0.9, 0.92, 0.96)
		TerrainField.Region.AIRPORT:
			if outside < 0.0:
				var local := d - field.region_span(d).x
				var paint := absf(lx) < 0.4 and fmod(local, 24.0) < 12.0
				paint = paint or absf(absf(lx) - (hw - 1.2)) < 0.35
				paint = paint or (local > 20.0 and local < 38.0 and absf(lx) < hw - 3.0 and fposmod(lx, 3.0) < 1.6)
				return Color(0.93, 0.93, 0.9) if paint else Color(0.44, 0.46, 0.5)
		TerrainField.Region.LAKE:
			var strip := field.water_strip(d)
			if strip != Vector2.ZERO:
				if d >= strip.x and d <= strip.y:
					return Color(0.25, 0.35, 0.45)
				return Palette.ICE
		TerrainField.Region.BANDY:
			if outside < 0.0:
				var span := field.region_span(d)
				var middle := (span.x + span.y) * 0.5
				var line := absf(d - middle) < 0.45
				for goal in [span.x + BANDY_GOAL_INSET, span.y - BANDY_GOAL_INSET]:
					var g: float = goal
					line = line or absf(d - g) < 0.35
					var arc := Vector2(lx, d - g).length()
					var inside := d > g if g < middle else d < g
					line = line or (inside and absf(arc - 17.0) < 0.4)
				return Color(0.85, 0.15, 0.2) if line else Color(0.86, 0.92, 1.0)
		TerrainField.Region.CLIFF:
			# Bare rock down the sheer face.
			var s := d - field.cliff_edge(d)
			if s > -0.3 and s < TerrainField.CLIFF_LIP + 1.8:
				return Palette.ROCK
	return Palette.SNOW


# --- Obstacles ---

const RAIL_LANES := [-8.0, -2.7, 2.7, 8.0]
const TRAIN_LANES := [-8.0, 8.0]
## Motorway lanes: [offset from the median, direction (+1 downhill), speed range].
## Right-hand traffic: downhill on the right (+x as you ride), slow lane outermost.
const MOTORWAY_LANES := [[13.0, 1.0, 13.0, 17.0], [6.5, 1.0, 16.0, 21.0], [-6.5, -1.0, 21.0, 26.0], [-13.0, -1.0, 18.0, 23.0]]
## Half width of the snowy median strip between the carriageways.
const MOTORWAY_MEDIAN := 2.6
const MOTORWAY_EDGE := 17.0
const SWEEP_LENGTH := TerrainField.SWEEP_LENGTH


func sweep(d: float) -> float:
	return field.sweep(d)


## World X of a lane (offset from the middle of the bundle) at distance d.
func lane_x(lane: float, d: float) -> float:
	return field.center_x(d) + lane + sweep(d)


func lane_point(lane: float, d: float, lift := 0.0) -> Vector3:
	var x := lane_x(lane, d)
	return Vector3(x, field.height(x, d, false) + lift, -d)


## Orientation along a swept lane, nose towards decreasing d when `direction` is +1.
func lane_basis(lane: float, d: float, direction := 1.0) -> Basis:
	var ahead := (lane_point(lane, d + 1.5) - lane_point(lane, d - 1.5)) * direction
	return Basis.looking_at(ahead, Vector3.UP)
const BANDY_GOAL_INSET := 14.0


func obstacle_table(kind: TerrainField.Region) -> Array:
	match kind:
		TerrainField.Region.TOWN:
			return [[Obstacle.Kind.PERSON, 5], [Obstacle.Kind.KID, 2], [Obstacle.Kind.DOG, 2], [Obstacle.Kind.BIN, 2], [Obstacle.Kind.SNOWMAN, 1]]
		TerrainField.Region.RIVER:
			return [[Obstacle.Kind.TENT, 3], [Obstacle.Kind.PERSON, 4], [Obstacle.Kind.ROCK, 2]]
		TerrainField.Region.PARK:
			return [[Obstacle.Kind.PERSON, 2], [Obstacle.Kind.SNOWMAN, 2], [Obstacle.Kind.KID, 1]]
		TerrainField.Region.WOODS:
			return [[Obstacle.Kind.LOG, 3], [Obstacle.Kind.TREE, 1], [Obstacle.Kind.STUMP, 1], [Obstacle.Kind.DEER, 1], [Obstacle.Kind.MOOSE, 1], [Obstacle.Kind.HARE, 2]]
		TerrainField.Region.MALL:
			return [[Obstacle.Kind.PERSON, 5], [Obstacle.Kind.KID, 2], [Obstacle.Kind.CART, 1], [Obstacle.Kind.PLANT, 2]]
		TerrainField.Region.RAIL:
			return [[Obstacle.Kind.PERSON, 1]]
		TerrainField.Region.AIRPORT:
			return [[Obstacle.Kind.CONE, 4], [Obstacle.Kind.PERSON, 1]]
		TerrainField.Region.LAKE:
			return [[Obstacle.Kind.ROCK, 1], [Obstacle.Kind.SNOWMAN, 1], [Obstacle.Kind.PERSON, 1]]
		TerrainField.Region.BANDY:
			return [[Obstacle.Kind.PERSON, 1]]
		TerrainField.Region.HIGHWAY:
			return [[Obstacle.Kind.CONE, 1]]
		TerrainField.Region.CLIFF:
			return [[Obstacle.Kind.PERSON, 1], [Obstacle.Kind.SNOWMAN, 1]]
	return []


func density(kind: TerrainField.Region) -> float:
	match kind:
		TerrainField.Region.MALL:
			return 0.8
		TerrainField.Region.RAIL:
			return 0.25
		TerrainField.Region.AIRPORT:
			return 0.5
		TerrainField.Region.LAKE:
			return 0.35
		TerrainField.Region.BANDY:
			return 0.7
		TerrainField.Region.HIGHWAY:
			return 0.3
		TerrainField.Region.CLIFF:
			return 0.3
		TerrainField.Region.PARK:
			return 0.5
		TerrainField.Region.WOODS:
			return 0.8
	return 0.9


## A special look for an obstacle in this region (bandy teams), or null.
func rig_for(kind: Obstacle.Kind, region: TerrainField.Region, rng: RandomNumberGenerator) -> Props.Rig:
	if region == TerrainField.Region.BANDY and kind == Obstacle.Kind.PERSON:
		var red := rng.randf() < 0.5
		var shirt := Color(0.85, 0.1, 0.12) if red else Color(0.1, 0.3, 0.8)
		return Props.dressed("bandy_red" if red else "bandy_blue", shirt, shirt.darkened(0.3), Color(1, 1, 1), Color(0.1, 0.1, 0.12), false, true)
	return null


## Region-specific behaviour. Returns false to fall back to the defaults.
func setup_obstacle(obstacle: Obstacle, region: TerrainField.Region, rng: RandomNumberGenerator, cx: float, hw: float) -> bool:
	var d := -obstacle.position.z
	match region:
		TerrainField.Region.RIVER:
			if obstacle.kind == Obstacle.Kind.PERSON and rng.randf() < 0.6:
				obstacle.patrol(rng.randf_range(4.0, 6.5) * world.random_sign(rng), cx - hw, cx + hw)
				return true
		TerrainField.Region.WOODS:
			if obstacle.kind == Obstacle.Kind.LOG:
				# Always off to one side, so there is a way round as well as over.
				obstacle.rotation.y = -world.street_yaw(d) + rng.randf_range(-0.25, 0.25)
				obstacle.scale = Vector3(0.75, 0.75, 0.8)
				obstacle.position.x = cx + world.random_sign(rng) * rng.randf_range(hw * 0.35, hw * 0.6)
				obstacle.position.y = field.height(obstacle.position.x, d)
				return true
		TerrainField.Region.MALL:
			if obstacle.kind == Obstacle.Kind.PERSON or obstacle.kind == Obstacle.Kind.KID:
				if obstacle.kind == Obstacle.Kind.KID:
					obstacle.scale = Vector3.ONE * 0.62
				obstacle.patrol(rng.randf_range(0.9, 1.8) * world.random_sign(rng), cx - hw + 1.0, cx + hw - 1.0)
				return true
		TerrainField.Region.BANDY:
			if obstacle.kind == Obstacle.Kind.PERSON:
				obstacle.patrol(rng.randf_range(5.0, 8.5) * world.random_sign(rng), cx - hw + 1.5, cx + hw - 1.5)
				return true
	return false


## Things that always stand in the same place: parked cars, the mall
## fountain, the bandy goals.
func place_fixed_obstacles(chunk: Chunk, rng: RandomNumberGenerator, d0: float, d1: float) -> void:
	var span := field.region_span((d0 + d1) * 0.5)
	match int(span.z):
		TerrainField.Region.TOWN:
			_park_cars(chunk, rng, d0, d1)
		TerrainField.Region.MALL:
			var middle := (span.x + span.y) * 0.5
			if middle >= d0 and middle < d1:
				_fixed(chunk, Obstacle.Kind.FOUNTAIN, middle, 0.0, 0.0, rng)
		TerrainField.Region.BANDY:
			for goal in [span.x + BANDY_GOAL_INSET, span.y - BANDY_GOAL_INSET]:
				var g: float = goal
				if g >= d0 and g < d1:
					_fixed(chunk, Obstacle.Kind.GOAL, g, 0.0, 0.0 if g < (span.x + span.y) * 0.5 else PI, rng)


func _fixed(chunk: Chunk, kind: Obstacle.Kind, d: float, lateral: float, turn: float, rng: RandomNumberGenerator) -> void:
	var obstacle := Obstacle.new().configure(kind, world.obstacle_rig(kind, rng), field)
	var x := field.center_x(d) + lateral
	obstacle.position = Vector3(x, field.height(x, d), -d)
	obstacle.rotation.y = -world.street_yaw(d) + turn
	chunk.add_child(obstacle)
	chunk.obstacles.append(obstacle)


# --- Cliff ---

const CLIFF_SIGNS := ["Stup ↓", "Oj.", "Håll i mössan"]


## A wall of rock along the edge (the boulders' snow caps make the cornice),
## a sign that comes far too late and a crowd at the bottom of the landing.
func _place_cliff(chunk: Chunk, decor: Dictionary, rng: RandomNumberGenerator, lo: float, hi: float, span: Vector3) -> void:
	var edge := span.x + TerrainField.CLIFF_EDGE
	if edge >= lo - 6.0 and edge < hi + 6.0:
		var cx := field.center_x(edge)
		var reach := field.half_width(edge) + 90.0
		var x := cx - reach
		while x < cx + reach:
			var below := field.height(x, edge + TerrainField.CLIFF_LIP + 0.6, false)
			var top := field.height(x, edge - 0.5, false)
			# A boulder spans about -0.4 to 1.05 (its snow cap) times its scale:
			# stretch it so the cap sits on the lip and the foot at the bottom.
			var tall := (top - below) / 1.45
			var shape := Basis(Vector3.UP, rng.randf_range(-0.4, 0.4)).scaled(Vector3(rng.randf_range(3.0, 4.5), tall, rng.randf_range(2.0, 3.0)))
			world.add_decor(decor, Props.rock(rng.randi_range(0, 1)), Transform3D(shape, Vector3(x, top - tall * 1.2, -(edge + 2.6))))
			x += rng.randf_range(4.5, 6.5)
		world.add_sign(chunk, CLIFF_SIGNS[rng.randi_range(0, CLIFF_SIGNS.size() - 1)], Color(0.85, 0.15, 0.1), edge - 3.0, world.random_sign(rng))
	# Spectators either side of where the landing hill levels out.
	var crowd := edge + TerrainField.CLIFF_LIP + TerrainField.CLIFF_RUNOUT * 0.8
	if crowd >= lo and crowd < hi:
		for side in [-1.0, 1.0]:
			for k in 7:
				var d := crowd + rng.randf_range(-14.0, 14.0)
				var lx: float = side * (field.half_width(d) + rng.randf_range(2.0, 7.0))
				var fan := Props.posed(Props.person(rng.randi_range(0, 7)), rng.randf() * TAU)
				fan.transform = world.ground_xform(field.center_x(d) + lx, d, (-PI / 2.0 if side > 0.0 else PI / 2.0) - world.street_yaw(d))
				chunk.add_child(fan)


# --- Traffic that lives as long as the region ---

func _spawn_traffic(kind: int, span: Vector3) -> void:
	match kind:
		TerrainField.Region.RAIL:
			world.add_free(TrainLine.new().setup(world, span, TRAIN_LANES[0], 1.0, 15.0, 5, 60.0))
			world.add_free(TrainLine.new().setup(world, span, TRAIN_LANES[1], -1.0, 24.0, 4, 0.0))
		TerrainField.Region.HIGHWAY:
			world.add_free(MotorwayTraffic.new().setup(world, span))
		TerrainField.Region.AIRPORT:
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(Vector2i(field.world_seed, int(span.x)))
			for offset in [95.0, 195.0]:
				var d: float = span.x + offset
				if d < span.y - 30.0:
					world.add_free(AirportTaxiway.new().setup(world, d, rng, offset < 100.0))
			world.add_free(Flyover.new().setup(world, span))
			world.add_free(Takeoff.new().setup(world, span))


# --- Mall ---

## Indoor mall: shop fronts on both sides, a ceiling with skylights,
## entrance walls at both ends and a tiled floor (which rides like snow).
func _place_mall(chunk: Chunk, decor: Dictionary, rng: RandomNumberGenerator, lo: float, hi: float, span: Vector3) -> void:
	var inside_from := span.x + MALL_INSET
	var inside_to := span.y - MALL_INSET
	chunk.add_child(_floor(maxf(lo, inside_from), minf(hi, inside_to), _mall_tile))
	for side in [-1.0, 1.0]:
		var d: float = ceilf((lo - side * 2.5) / 10.0) * 10.0 + side * 2.5
		while d < hi:
			if d < inside_from or d > inside_to:
				d += 10.0
				continue
			var x: float = field.center_x(d) + side * (field.half_width(d) + 0.3)
			var xform := world.slope_xform(x, d, PI / 2.0 if side > 0.0 else -PI / 2.0)
			world.add_decor(decor, RegionProps.shopfront(rng.randi_range(0, 7)), xform)
			var sign := Label3D.new()
			sign.text = RegionProps.MALL_SHOPS[rng.randi_range(0, RegionProps.MALL_SHOPS.size() - 1)]
			sign.font_size = 72
			sign.pixel_size = 0.008
			sign.outline_size = 0
			sign.modulate = Color(1, 1, 1)
			sign.shaded = false
			sign.double_sided = false
			sign.transform = xform * Transform3D(Basis(Vector3.UP, PI), Vector3(0, 4.0, -0.2))
			chunk.add_child(sign)
			d += 10.0
	var roof := ceilf(lo / 10.0) * 10.0
	while roof < hi:
		if roof > inside_from and roof < inside_to:
			var cx := field.center_x(roof)
			var width := int((field.half_width(roof) + 0.6) * 2.0)
			_add_unshadowed(chunk, RegionProps.mall_ceiling(width), world.slope_xform(cx, roof, 0.0))
		roof += 10.0
	for end in [inside_from, inside_to]:
		var e: float = end
		if e >= lo and e < hi:
			var width := int(field.half_width(e) * 2.0 + 1.0)
			var xform := world.slope_xform(field.center_x(e), e, 0.0 if e < (span.x + span.y) * 0.5 else PI)
			world.add_decor(decor, RegionProps.mall_entrance(width), xform)
			var sign := Label3D.new()
			sign.text = "PULKA GALLERIAN" if e < (span.x + span.y) * 0.5 else "Välkommen åter!"
			sign.font_size = 120
			sign.pixel_size = 0.012
			sign.outline_size = 0
			sign.shaded = false
			sign.double_sided = false
			sign.transform = xform * Transform3D(Basis(Vector3.UP, PI), Vector3(0, 8.4, -0.75))
			chunk.add_child(sign)


const MALL_INSET := 6.0


## True while d is under the mall roof.
func indoors(d: float) -> bool:
	var span := field.region_span(d)
	return span.z == TerrainField.Region.MALL and d > span.x + MALL_INSET and d < span.y - MALL_INSET


func _mall_tile(lx: float, d: float, hw: float) -> Color:
	if absf(lx) > hw - 1.5:
		return Color(0.45, 0.42, 0.4)
	var checker := (int(floorf(lx / 2.0)) + int(floorf(d / 2.0))) % 2 == 0
	if absf(lx) < 1.0:
		return Color(0.62, 0.45, 0.4)
	return Color(0.92, 0.89, 0.83) if checker else Color(0.78, 0.74, 0.68)


func _add_unshadowed(chunk: Chunk, mesh: Mesh, xform: Transform3D) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.transform = xform
	# The ceiling must not shade the hall: the sun stands in for indoor lights.
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chunk.add_child(instance)


## A crisp painted surface over the track between lo and hi, one-metre
## cells that follow the ground. `painter(lx, d, half_width) -> Color`.
func _floor(lo: float, hi: float, painter: Callable) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var first := floorf(lo)
	var last := ceilf(hi)
	if last - first < 1.0:
		return instance
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var hw := field.half_width((first + last) * 0.5)
	var columns := int(hw * 2.0)
	var rows := int(last - first)
	var grid := PackedVector3Array()
	grid.resize((rows + 1) * (columns + 1))
	for r in rows + 1:
		var d := first + r
		var cx := field.center_x(d)
		for c in columns + 1:
			var x := cx - hw + c * (hw * 2.0 / columns)
			grid[r * (columns + 1) + c] = Vector3(x, field.height(x, d, false) + 0.03, -d)
	for r in rows:
		for c in columns:
			var a := grid[r * (columns + 1) + c]
			var b := grid[r * (columns + 1) + c + 1]
			var e := grid[(r + 1) * (columns + 1) + c]
			var f := grid[(r + 1) * (columns + 1) + c + 1]
			var lx := -hw + (c + 0.5) * (hw * 2.0 / columns)
			var color: Color = painter.call(lx, first + r + 0.5, hw)
			var linear := color.srgb_to_linear()
			linear.a = 1.0
			world.triangle(vertices, normals, colors, a, e, b, linear)
			world.triangle(vertices, normals, colors, b, e, f, linear)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, Palette.surface())
	instance.mesh = mesh
	return instance


# --- Rail yard ---

func _place_rail(chunk: Chunk, decor: Dictionary, lo: float, hi: float, _span: Vector3) -> void:
	chunk.add_child(_track_mesh(lo, hi))
	var mast := ceilf(lo / 25.0) * 25.0
	while mast < hi:
		for side in [-1.0, 1.0]:
			var lane: float = side * 10.5
			# Masts stand upright; only their heading follows the tracks.
			var ahead := lane_point(lane, mast + 1.5) - lane_point(lane, mast - 1.5)
			var heading := atan2(-ahead.x, -ahead.z)
			var turn: float = 0.0 if side > 0.0 else PI
			world.add_decor(decor, RegionProps.catenary_mast(9), world.ground_xform(lane_x(lane, mast), mast, turn + heading))
		mast += 25.0


## Continuous rails and sleepers that follow the ground, sampled every metre
## on whole-metre distances so neighbouring chunks join seamlessly.
func _track_mesh(lo: float, hi: float) -> MeshInstance3D:
	var steel := Color(0.5, 0.52, 0.55).srgb_to_linear()
	steel.a = 1.0
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var sleepers := MeshKit.new()
	var sleeper := BoxMesh.new()
	sleeper.size = Vector3(2.4, 0.12, 0.25)
	var first := floorf(lo)
	var last := ceilf(hi)
	for lane: float in RAIL_LANES:
		var previous: Array[Vector3] = []
		var d := first
		while d <= last:
			var center := _track_point(lane, d)
			var ahead := (_track_point(lane, d + 0.5) - _track_point(lane, d - 0.5)).normalized()
			var across := ahead.cross(Vector3.UP).normalized()
			var up := across.cross(ahead).normalized()
			# Rail profile: left/right top corners and feet for both rails.
			var profile: Array[Vector3] = []
			for side in [-0.72, 0.72]:
				var foot: Vector3 = center + across * float(side)
				profile.append(foot + across * -0.04 + up * 0.0)
				profile.append(foot + across * -0.04 + up * 0.16)
				profile.append(foot + across * 0.04 + up * 0.16)
				profile.append(foot + across * 0.04 + up * 0.0)
			if not previous.is_empty():
				for rail in 2:
					var o := rail * 4
					for face in 3:
						var a := previous[o + face]
						var b := previous[o + face + 1]
						var c := profile[o + face]
						var e := profile[o + face + 1]
						world.triangle(vertices, normals, colors, a, c, b, steel)
						world.triangle(vertices, normals, colors, b, c, e, steel)
			previous = profile
			if d < last:
				for offset in [0.0, 0.5]:
					var at := _track_point(lane, d + offset) - up * 0.02
					sleepers.add(sleeper, Transform3D(Basis.looking_at(ahead, up), at), Color(0.35, 0.27, 0.2))
			d += 1.0
	var instance := MeshInstance3D.new()
	if vertices.is_empty():
		return instance
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := sleepers.build()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(mesh.get_surface_count() - 1, Palette.surface())
	instance.mesh = mesh
	return instance


func _track_point(lane: float, d: float) -> Vector3:
	return lane_point(lane, d, 0.06)


# --- Airport ---

func _place_airport(chunk: Chunk, decor: Dictionary, rng: RandomNumberGenerator, lo: float, hi: float, span: Vector3) -> void:
	chunk.add_child(_floor(lo, hi, _runway_paint))
	var d := ceilf(lo / 15.0) * 15.0
	while d < hi:
		var hw := field.half_width(d)
		for side in [-1.0, 1.0]:
			var x: float = field.center_x(d) + side * (hw + 0.8)
			world.add_decor(decor, RegionProps.edge_light(Color(0.3, 0.6, 1.0)), world.ground_xform(x, d, 0.0))
		d += 15.0
	var hw0 := field.half_width(span.x + 60.0)
	# [distance, lateral, mesh, turn, size, follows the slope]
	var features := [
		[span.x + 45.0, -(hw0 + 18.0), RegionProps.control_tower(), 0.0, 1.35, false],
		[span.x + 150.0, -(hw0 + 34.0), RegionProps.terminal(), -PI / 2.0, 1.0, true],
		[span.x + 30.0, hw0 + 9.0, RegionProps.windsock(), 0.0, 1.0, false],
	]
	for i in 3:
		features.append([span.x + 115.0 + i * 38.0, -(hw0 + 14.0), RegionProps.plane(rng.randi_range(0, 2)), -PI / 2.0, 1.0, true])
		features.append([span.x + 60.0 + i * 70.0, hw0 + 24.0, RegionProps.plane(rng.randi_range(0, 2)), PI / 2.0, 1.0, true])
	for feature: Array in features:
		var at: float = feature[0]
		if at >= lo and at < hi:
			var x: float = field.center_x(at) + float(feature[1])
			var turn: float = feature[3]
			var size: float = feature[4]
			var xform := world.slope_xform(x, at, turn, size, 0.5) if feature[5] else world.ground_xform(x, at, turn - world.street_yaw(at), size)
			world.add_decor(decor, feature[2], xform)
	var numbers := span.x + 44.0
	if numbers >= lo and numbers < hi:
		var label := Label3D.new()
		label.text = "01"
		label.font_size = 420
		label.pixel_size = 0.022
		label.outline_size = 0
		label.modulate = Color(0.95, 0.95, 0.92)
		label.shaded = true
		label.double_sided = false
		var flat := Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3(0, 0.07, 0))
		label.transform = world.slope_xform(field.center_x(numbers), numbers, 0.0) * flat
		chunk.add_child(label)


func _runway_paint(lx: float, d: float, hw: float) -> Color:
	var local := d - field.region_span(d).x
	var white := Color(0.94, 0.94, 0.92)
	if absf(lx) < 0.5 and fposmod(local, 24.0) < 12.0:
		return white
	if absf(absf(lx) - (hw - 1.5)) < 0.5:
		return white
	if local > 18.0 and local < 34.0 and absf(lx) < hw - 3.5 and fposmod(lx + 0.5, 3.0) < 1.5:
		return white
	if absf(lx) < hw - 2.5 and fposmod(local - 60.0, 120.0) < 18.0 and absf(absf(lx) - 5.0) < 1.5:
		return white
	return Color(0.4, 0.42, 0.46) if (int(floorf(d / 3.0)) + int(floorf(lx / 3.0))) % 2 == 0 else Color(0.42, 0.44, 0.48)


# --- Lake ---

func _place_lake(chunk: Chunk, decor: Dictionary, rng: RandomNumberGenerator, lo: float, hi: float, span: Vector3) -> void:
	for water: Vector2 in TerrainField.LAKE_WATER:
		var start := span.x + water.x
		if start < lo or start >= hi:
			continue
		var strip := Vector2(start, start + water.y)
		chunk.add_child(_water_mesh(strip))
		var cx := field.center_x(strip.x)
		var hw := field.half_width(strip.x)
		var level := field.water_level(strip)
		for i in 6:
			var fx := cx + rng.randf_range(-hw - 30.0, hw + 30.0)
			var fd := rng.randf_range(strip.x + 2.0, strip.y - 2.0)
			if absf(fx - field.center_x(fd)) < hw + 2.0:
				continue
			world.add_decor(decor, RegionProps.ice_floe(rng.randi_range(0, 2)), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(fx, level, -fd)))
		# Ragged shelves of ice where the open water meets the snow.
		for edge in [strip.x, strip.y]:
			var e: float = edge
			var x := field.center_x(e) - hw - 40.0
			while x < field.center_x(e) + hw + 40.0:
				var width := rng.randf_range(2.0, 5.0)
				var reach := rng.randf_range(0.8, 2.6) * (1.0 if e == strip.x else -1.0)
				var shelf := Basis(Vector3.UP, rng.randf_range(-0.2, 0.2)).scaled(Vector3(width, 1.0, absf(reach) * 2.0))
				world.add_decor(decor, RegionProps.ice_shelf(), Transform3D(shelf, Vector3(x, level + 0.05, -(e + reach * 0.5))))
				x += width * 0.9
		var jetty_x := cx - hw - 4.0
		world.add_decor(decor, RegionProps.jetty(), Transform3D(Basis(Vector3.UP, -world.street_yaw(strip.x)), Vector3(jetty_x, level, -(strip.x - 1.0))))
		world.add_decor(decor, Props.house(0), world.ground_xform(jetty_x - 9.0, strip.x - 10.0, PI / 2.0, 0.55, 0.3))
		for k in 2:
			var bather := Props.posed(Props.dressed("bather%d" % k, Palette.JACKETS[k + 2], Palette.JACKETS[k + 5], Color.WHITE, Color.WHITE, true), k * 1.5)
			bather.position = Vector3(jetty_x + (k - 0.5) * 0.8, level + 0.72, -(strip.x + 5.0 + k * 1.2))
			bather.rotation.y = PI * 0.5 * (k * 2 - 1)
			chunk.add_child(bather)
	var reed := ceilf(lo / 6.0) * 6.0
	while reed < hi:
		var strip := field.water_strip(reed)
		if strip != Vector2.ZERO and (reed < strip.x or reed > strip.y):
			for side in [-1.0, 1.0]:
				var x: float = field.center_x(reed) + side * (field.half_width(reed) + rng.randf_range(0.5, 4.0))
				world.add_decor(decor, Props.reeds(), world.ground_xform(x, reed, rng.randf() * TAU, rng.randf_range(0.8, 1.3)))
		reed += 6.0


func _water_mesh(strip: Vector2) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	var length := strip.y - strip.x + 6.0
	mesh.size = Vector2(240.0, length)
	mesh.subdivide_width = 24
	mesh.subdivide_depth = 6
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/water.gdshader")
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	var middle := (strip.x + strip.y) * 0.5
	instance.position = Vector3(field.center_x(middle), field.water_level(strip) + 0.04, -middle)
	instance.rotation.y = -world.street_yaw(middle)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


# --- Bandy rink ---

func _place_bandy(chunk: Chunk, decor: Dictionary, rng: RandomNumberGenerator, lo: float, hi: float, span: Vector3) -> void:
	chunk.add_child(_floor(lo, hi, _rink_paint))
	var d := ceilf(lo / 4.0) * 4.0
	while d < hi:
		var hw := field.half_width(d)
		for side in [-1.0, 1.0]:
			var x: float = field.center_x(d) + side * (hw + 0.15)
			world.add_decor(decor, RegionProps.boards(), world.slope_xform(x, d, 0.0))
		d += 4.0
	var stand := ceilf(lo / 14.0) * 14.0
	while stand < hi:
		var hw := field.half_width(stand)
		for side in [-1.0, 1.0]:
			var x: float = field.center_x(stand) + side * (hw + 2.5)
			var stands := world.slope_xform(x, stand, 0.0 if side > 0.0 else PI)
			world.add_decor(decor, RegionProps.bleachers(), stands)
			for k in 5:
				var row := rng.randi_range(0, 3)
				var fan := Props.posed(Props.person(rng.randi_range(0, 7)), rng.randf() * TAU)
				# Seated on the stand's steps, facing the ice.
				fan.transform = stands * Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(row * 1.0, 0.45 * (row + 1), rng.randf_range(-5.5, 5.5)))
				chunk.add_child(fan)
		stand += 14.0
	for corner in [span.x + 8.0, span.y - 8.0]:
		var c: float = corner
		if c < lo - 6.0 or c >= hi + 6.0:
			continue
		for side in [-1.0, 1.0]:
			var x: float = field.center_x(c) + side * (field.half_width(c) + 6.0)
			world.add_decor(decor, RegionProps.floodlight(), world.ground_xform(x, c, (PI / 2.0 if side > 0.0 else -PI / 2.0) - world.street_yaw(c)))


func _rink_paint(lx: float, d: float, hw: float) -> Color:
	var span := field.region_span(d)
	var middle := (span.x + span.y) * 0.5
	var red := Color(0.85, 0.12, 0.18)
	var ice := Color(0.88, 0.94, 1.0) if (int(d * 0.5) + int(lx * 0.5)) % 2 == 0 else Color(0.86, 0.93, 1.0)
	if absf(d - middle) < 0.5 or absf(absf(lx) - (hw - 0.6)) < 0.5:
		return red
	for goal in [span.x + BANDY_GOAL_INSET, span.y - BANDY_GOAL_INSET]:
		var g: float = goal
		if absf(d - g) < 0.5:
			return red
		var inside := d > g if g < middle else d < g
		if inside and absf(Vector2(lx, d - g).length() - 17.0) < 0.5:
			return red
	if Vector2(lx, d - middle).length() < 1.0:
		return red
	return ice


## Arrows pointing straight down the hill where the tracks or lanes start
## to veer away, on whichever edges are clear of them.
func _place_turn_off_arrows(decor: Dictionary, lo: float, hi: float, span: Vector3) -> void:
	for offset in [12.0, 32.0, 52.0]:
		var at: float = span.y - SWEEP_LENGTH + offset
		if at < lo or at >= hi:
			continue
		for side in [-1.0, 1.0]:
			var x: float = field.center_x(at) + side * (field.half_width(at) + 3.0)
			if not field.in_corridor(x, at, 3.0):
				world.add_decor(decor, RegionProps.arrow_board(), world.ground_xform(x, at, -world.street_yaw(at)))


# --- Motorway ---

const MOTORWAY_SIGNS := [
	["E4 Backen", "Nedåt ↓"], ["Pulkastad 2", "Utfart 42"], ["Kiosken 500 m", "Glögg & korv"],
	["Alla riktningar", "Utom uppåt"], ["Tomteland 7", "Nordpolen 2 400"],
]


func _place_motorway(chunk: Chunk, decor: Dictionary, rng: RandomNumberGenerator, lo: float, hi: float, span: Vector3) -> void:
	var asphalt := Color(0.33, 0.34, 0.37)
	var white := Color(0.92, 0.92, 0.9)
	chunk.add_child(_ribbon(lo, hi, -MOTORWAY_EDGE - 0.4, MOTORWAY_EDGE + 0.4, 0.03, asphalt))
	# Swedish markings, all white: a wide broken edge line (1 m + 2 m) by the
	# hard shoulder, a solid line along the median and 3 m + 9 m lane lines.
	chunk.add_child(_ribbon(lo, hi, -MOTORWAY_MEDIAN, MOTORWAY_MEDIAN, 0.04, Color(0.86, 0.88, 0.93)))
	for side in [-1.0, 1.0]:
		var s: float = side
		var shoulder := s * (MOTORWAY_EDGE - 0.6)
		chunk.add_child(_ribbon(lo, hi, shoulder - 0.15, shoulder + 0.15, 0.05, white, 1.0, 2.0))
		var inner := s * (MOTORWAY_MEDIAN + 0.5)
		chunk.add_child(_ribbon(lo, hi, inner - 0.1, inner + 0.1, 0.05, white))
		var divider := s * 9.75
		chunk.add_child(_ribbon(lo, hi, divider - 0.08, divider + 0.08, 0.05, white, 3.0, 9.0))
	var gantry := ceilf((lo - span.x) / 75.0) * 75.0 + span.x
	while gantry < hi:
		var local := gantry - span.x
		if local > SWEEP_LENGTH and local < span.y - span.x - SWEEP_LENGTH:
			var xform := Transform3D(lane_basis(0.0, gantry), lane_point(0.0, gantry))
			world.add_decor(decor, RegionProps.sign_gantry(int(MOTORWAY_EDGE * 2.0 + 3.0)), xform)
			var texts: Array = MOTORWAY_SIGNS[rng.randi_range(0, MOTORWAY_SIGNS.size() - 1)]
			for k in 2:
				var sign := Label3D.new()
				sign.text = "%s\n%s" % [texts[0], texts[1]] if k == 0 else "%s" % texts[1]
				sign.font_size = 64
				sign.pixel_size = 0.012
				sign.outline_size = 0
				sign.shaded = false
				sign.double_sided = false
				sign.transform = xform * Transform3D(Basis.IDENTITY, Vector3(9.75 if k == 0 else -9.75, 7.3, 0.12))
				chunk.add_child(sign)
		gantry += 75.0


## A painted band along the swept motorway, between two lateral offsets,
## following the ground. `dash` and `gap` (metres) make it dashed.
func _ribbon(lo: float, hi: float, from: float, to: float, lift: float, color: Color, dash := 0.0, gap := 0.0) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var linear := color.srgb_to_linear()
	linear.a = 1.0
	var step := 1.0
	var d := floorf(lo)
	while d < ceilf(hi):
		var painted := dash <= 0.0 or fposmod(d, dash + gap) < dash
		if painted:
			var a := lane_point(from, d, lift)
			var b := lane_point(to, d, lift)
			var e := lane_point(from, d + step, lift)
			var f := lane_point(to, d + step, lift)
			world.triangle(vertices, normals, colors, a, e, b, linear)
			world.triangle(vertices, normals, colors, b, e, f, linear)
		d += step
	if vertices.is_empty():
		return instance
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, Palette.surface())
	instance.mesh = mesh
	return instance
