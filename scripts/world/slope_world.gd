class_name SlopeWorld
extends Node3D
## Streams chunks of the endless slope in and out around the player.

const CHUNK_LENGTH := 50.0
const CHUNKS_BEHIND := 2
const ROW_STEP := 50.0 / 30.0
const SAFE_START := 160.0

const ZONE_SIGNS := {
	TerrainField.Zone.OPEN: ["Öppen backe. Inga ursäkter.", Color(0.15, 0.45, 0.8)],
	TerrainField.Zone.FOREST: ["Skogen: många träd, lite förstånd", Color(0.15, 0.45, 0.25)],
	TerrainField.Zone.MOGULS: ["Puckelpist! Håll i mössan", Color(0.75, 0.3, 0.1)],
	TerrainField.Zone.VILLAGE: ["Välkommen till Pulkaby", Color(0.6, 0.12, 0.12)],
	TerrainField.Zone.WILDLIFE: ["Varning för älg (och hare)", Color(0.85, 0.65, 0.05)],
}

var field: TerrainField
var engine_sound: AudioStream
## Extra sounds for region traffic (train horns, jets), set by the game.
var horn_sound: AudioStream
var car_horn_sound: AudioStream
var jet_sound: AudioStream
var regions: RegionBuilder
## Distance of the player, for things that react to them (trains, planes).
var player_d := 0.0
## Moving things that are not tied to one chunk (trains run through many).
var _free: Array[Node] = []
var _free_obstacles: Array[Obstacle] = []
var _chunks: Dictionary = {}
var _columns := PackedFloat32Array()
var _chunks_ahead := Quality.chunks_ahead()


func _init() -> void:
	regions = RegionBuilder.new(self)
	var x := -150.0
	while x < -30.0:
		_columns.append(x)
		x += 8.0
	x = -30.0
	while x <= 30.0:
		_columns.append(x)
		x += 1.5
	x = 38.0
	while x <= 150.0:
		_columns.append(x)
		x += 8.0


func reset(new_field: TerrainField, start_d: float) -> void:
	for chunk: Chunk in _chunks.values():
		chunk.queue_free()
	_chunks.clear()
	for node in _free:
		node.queue_free()
	_free.clear()
	_free_obstacles.clear()
	field = new_field
	var first := int(floorf(start_d / CHUNK_LENGTH))
	for i in range(first - CHUNKS_BEHIND, first + 5):
		_ensure(i)


func update_world(player_distance: float, delta: float, build_budget := 1) -> void:
	player_d = player_distance
	var current := int(floorf(player_d / CHUNK_LENGTH))
	for key: int in _chunks.keys():
		if key < current - CHUNKS_BEHIND or key > current + _chunks_ahead + 1:
			(_chunks[key] as Chunk).queue_free()
			_chunks.erase(key)
	var built := 0
	for i in range(current - CHUNKS_BEHIND, current + _chunks_ahead + 1):
		if built >= build_budget:
			break
		if not _chunks.has(i):
			_ensure(i)
			built += 1
	for chunk: Chunk in _chunks.values():
		chunk.tick(delta)
	for node in _free.duplicate():
		node.call(&"tick", delta, player_d)
		if node.call(&"finished", player_d):
			for obstacle: Obstacle in node.get(&"obstacles"):
				_free_obstacles.erase(obstacle)
			_free.erase(node)
			node.queue_free()


## A horn from passing traffic, played where it happens.
func honk(at: Vector3) -> void:
	if car_horn_sound == null:
		return
	var horn := AudioStreamPlayer3D.new()
	horn.stream = car_horn_sound
	horn.bus = SoundBank.SFX_BUS
	horn.unit_size = 15.0
	horn.max_distance = 200.0
	horn.position = at
	horn.finished.connect(horn.queue_free)
	add_child(horn)
	horn.play()


## Adds something that moves through many chunks (a train, an airfield).
## It must offer tick(delta, player_d), finished(player_d) and `obstacles`.
func add_free(node: Node) -> void:
	add_child(node)
	_free.append(node)
	_free_obstacles.append_array(node.get(&"obstacles"))


func obstacles_near(d: float) -> Array[Obstacle]:
	var result: Array[Obstacle] = []
	var current := int(floorf(d / CHUNK_LENGTH))
	for i in range(current - 1, current + 2):
		if _chunks.has(i):
			result.append_array((_chunks[i] as Chunk).obstacles)
	for obstacle in _free_obstacles:
		if absf(-obstacle.position.z - d) < 60.0:
			result.append(obstacle)
	return result


func pickups_near(d: float) -> Array[Pickup]:
	var result: Array[Pickup] = []
	var current := int(floorf(d / CHUNK_LENGTH))
	for i in range(current - 1, current + 2):
		if _chunks.has(i):
			result.append_array((_chunks[i] as Chunk).pickups)
	return result


func _ensure(index: int) -> void:
	if _chunks.has(index):
		return
	var chunk := Chunk.new()
	chunk.index = index
	add_child(chunk)
	_chunks[index] = chunk
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(field.world_seed, index))
	var d0 := index * CHUNK_LENGTH
	var d1 := d0 + CHUNK_LENGTH
	var decor := {}
	_build_terrain(chunk, d0)
	_place_edges(decor, d0, d1)
	_place_scenery(chunk, decor, rng, d0, d1)
	_place_ramps(chunk, d0, d1)
	_place_roads(chunk, decor, rng, d0, d1)
	_place_obstacles(chunk, rng, d0, d1)
	_place_pickups(chunk, rng, d0, d1)
	_flush_decor(chunk, decor)


# --- Terrain ---

func _build_terrain(chunk: Chunk, d0: float) -> void:
	var rows := int(round(CHUNK_LENGTH / ROW_STEP)) + 1
	var cols := _columns.size()
	# One extra row on each side so normals agree across chunk seams.
	var grid := PackedVector3Array()
	grid.resize((rows + 2) * cols)
	for r in rows + 2:
		var d := d0 + (r - 1) * ROW_STEP
		var cx := field.center_x(d)
		for c in cols:
			var x := cx + _columns[c]
			grid[r * cols + c] = Vector3(x, field.height(x, d, false), -d)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	vertices.resize(rows * cols)
	normals.resize(rows * cols)
	colors.resize(rows * cols)
	for r in rows:
		var g := r + 1
		var d := d0 + r * ROW_STEP
		var hw := field.half_width(d)
		var kind := field.region(d)
		for c in cols:
			var p := grid[g * cols + c]
			var across := grid[g * cols + mini(c + 1, cols - 1)] - grid[g * cols + maxi(c - 1, 0)]
			var along := grid[(g - 1) * cols + c] - grid[(g + 1) * cols + c]
			var n := along.cross(across).normalized()
			if n.y < 0.0:
				n = -n
			vertices[r * cols + c] = p
			normals[r * cols + c] = n
			colors[r * cols + c] = _snow_color(p.x, _columns[c], d, hw, kind)
	var indices := PackedInt32Array()
	for r in rows - 1:
		for c in cols - 1:
			var a := r * cols + c
			indices.append_array([a, a + cols, a + 1, a + 1, a + cols, a + cols + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, Palette.surface())
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	chunk.add_child(instance)


func _snow_color(x: float, lx: float, d: float, hw: float, kind: TerrainField.Region) -> Color:
	var outside := absf(lx) - hw
	var color := Palette.SNOW
	if kind != TerrainField.Region.SLOPE:
		color = regions.ground_color(kind, x, lx, d, hw)
	elif outside < -0.5:
		color = Palette.ICE if field.is_ice(x, d) else Palette.SNOW_PACKED
	elif outside < 2.5:
		color = Palette.SNOW_EDGE
	var linear := color.srgb_to_linear()
	linear.a = 1.0
	return linear


func triangle(vertices: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var n := (c - a).cross(b - a).normalized()
	if n.y < 0.0:
		n = -n
	vertices.append(a)
	vertices.append(b)
	vertices.append(c)
	for i in 3:
		normals.append(n)
		colors.append(color)


# --- Decor (batched into MultiMeshes) ---

func add_decor(decor: Dictionary, mesh: Mesh, xform: Transform3D) -> void:
	if not decor.has(mesh):
		decor[mesh] = []
	(decor[mesh] as Array).append(xform)


func _flush_decor(chunk: Chunk, decor: Dictionary) -> void:
	for mesh: Mesh in decor:
		var xforms: Array = decor[mesh]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = mesh
		multimesh.instance_count = xforms.size()
		for i in xforms.size():
			multimesh.set_instance_transform(i, xforms[i])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multimesh
		chunk.add_child(instance)


func ground_xform(x: float, d: float, yaw: float, size := 1.0, sink := 0.0) -> Transform3D:
	var rotated := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * size)
	return Transform3D(rotated, Vector3(x, field.height(x, d, false) - sink, -d))


## Placement that follows the track: -Z points down the slope (pitched with
## it and turned with the meander), then `turn` spins around that tilted up.
func slope_xform(x: float, d: float, turn: float, size := 1.0, sink := 0.0) -> Transform3D:
	var lateral := x - field.center_x(d)
	var ahead := _track_point(lateral, d + 1.5) - _track_point(lateral, d - 1.5)
	var rotated := (Basis.looking_at(ahead, Vector3.UP) * Basis(Vector3.UP, turn)).scaled(Vector3.ONE * size)
	return Transform3D(rotated, Vector3(x, field.height(x, d, false) - sink, -d))


func _track_point(lateral: float, d: float) -> Vector3:
	var x := field.center_x(d) + lateral
	return Vector3(x, field.height(x, d, false), -d)


func _place_edges(decor: Dictionary, d0: float, d1: float) -> void:
	var d := ceilf(d0 / 12.0) * 12.0
	while d < d1:
		var kind := field.region(d)
		if not field.near_road(d, 2.0) and (kind == TerrainField.Region.SLOPE or kind == TerrainField.Region.PARK):
			var cx := field.center_x(d)
			var hw := field.half_width(d)
			var variant := int(d / 12.0) % 2
			add_decor(decor, Props.edge_pole(variant), ground_xform(cx - hw - 1.2, d, 0.0))
			add_decor(decor, Props.edge_pole(variant), ground_xform(cx + hw + 1.2, d, 0.0))
		d += 12.0


func street_yaw(d: float) -> float:
	var dir := field.track_dir(d)
	return atan2(dir.x, -dir.z)


func _place_scenery(chunk: Chunk, decor: Dictionary, rng: RandomNumberGenerator, d0: float, d1: float) -> void:
	regions.place_scenery(chunk, decor, rng, d0, d1)
	var zone := field.zone((d0 + d1) * 0.5)
	var forest := zone == TerrainField.Zone.FOREST
	var village := zone == TerrainField.Zone.VILLAGE
	var trees := 40 if forest else (14 if village else 24)
	for i in trees:
		var d := rng.randf_range(d0, d1)
		if field.near_road(d, 4.0):
			continue
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var hw := field.half_width(d)
		var kind := field.region(d)
		var nearest := 22.0 if kind == TerrainField.Region.TOWN else (7.0 if kind == TerrainField.Region.RIVER else 3.0)
		var lx := side * (hw + rng.randf_range(nearest, 90.0 if not forest else 60.0))
		var mesh: Mesh = Props.birch() if rng.randf() < 0.12 else Props.spruce(rng.randi_range(0, 2))
		add_decor(decor, mesh, ground_xform(field.center_x(d) + lx, d, rng.randf() * TAU, rng.randf_range(0.8, 1.7), 0.2))
	var houses := 3 if village else (1 if rng.randf() < 0.7 else 0)
	for i in houses:
		var d := rng.randf_range(d0 + 6.0, d1 - 6.0)
		if field.near_road(d, 12.0) or field.region(d) != TerrainField.Region.SLOPE:
			continue
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var hw := field.half_width(d)
		var lx := side * (hw + rng.randf_range(16.0 if village else 24.0, 70.0))
		var x := field.center_x(d) + lx
		var yaw := (PI / 2.0 if side > 0.0 else -PI / 2.0) + rng.randf_range(-0.3, 0.3)
		add_decor(decor, Props.house(rng.randi_range(0, 9)), ground_xform(x, d, yaw, 1.0, 0.4))
		if rng.randf() < 0.5:
			for f in 3:
				var fd := d - 6.0 + f * 4.2
				add_decor(decor, Props.fence(), ground_xform(x - side * 7.0, fd, PI / 2.0))
	if village and field.region((d0 + d1) * 0.5) == TerrainField.Region.SLOPE:
		var d := d0 + 10.0
		while d < d1:
			if not field.near_road(d, 3.0):
				var hw := field.half_width(d)
				add_decor(decor, Props.lamp_post(), ground_xform(field.center_x(d) + hw + 4.0, d, -PI / 2.0))
				add_decor(decor, Props.lamp_post(), ground_xform(field.center_x(d) - hw - 4.0, d, PI / 2.0))
			d += 25.0
	var zone_start := ceilf(d0 / TerrainField.ZONE_LENGTH) * TerrainField.ZONE_LENGTH
	if zone_start >= d0 and zone_start < d1 and zone_start > 0.0 and field.region(zone_start) == TerrainField.Region.SLOPE:
		var info: Array = ZONE_SIGNS[field.zone(zone_start + 1.0)]
		add_sign(chunk, str(info[0]), info[1], zone_start, 1.0)


func add_sign(chunk: Chunk, text: String, color: Color, d: float, side: float) -> void:
	var board := Props.sign_node(text, color)
	var x := field.center_x(d) + side * (field.half_width(d) + 3.5)
	board.position = Vector3(x, field.height(x, d, false) - 0.2, -d)
	board.rotation.y = -side * 0.35
	chunk.add_child(board)


func _place_ramps(chunk: Chunk, d0: float, d1: float) -> void:
	for layer in 2:
		var size := field.ramp_cell_size(layer)
		for cell in range(int(floorf(d0 / size)), int(floorf(d1 / size)) + 1):
			var ramp := field.ramp_in_cell(cell, layer)
			if ramp.z == 0.0 or ramp.y < d0 or ramp.y >= d1:
				continue
			chunk.add_child(_ramp_mesh(ramp.x, ramp.y))


func _ramp_mesh(x: float, start: float) -> MeshInstance3D:
	var top := Color(0.8, 0.9, 1.0).srgb_to_linear()
	var side := Color(0.62, 0.78, 0.95).srgb_to_linear()
	var stripe := Color(0.95, 0.2, 0.25).srgb_to_linear()
	top.a = 1.0
	side.a = 1.0
	stripe.a = 1.0
	var hw := TerrainField.RAMP_HALF_WIDTH
	var steps := 8
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var point := func(lx: float, u: float, lifted: bool) -> Vector3:
		var d := start + u
		var px := x + lx
		var base := field.height(px, d, false)
		return Vector3(px, base + (field.ramp_profile(u) + 0.03 if lifted else -0.2), -d)
	for i in steps:
		var u0 := TerrainField.RAMP_LENGTH * i / steps
		var u1 := TerrainField.RAMP_LENGTH * (i + 1) / steps
		var color := stripe if i == steps - 1 else top
		var a: Vector3 = point.call(-hw, u0, true)
		var b: Vector3 = point.call(hw, u0, true)
		var e: Vector3 = point.call(-hw, u1, true)
		var f: Vector3 = point.call(hw, u1, true)
		triangle(vertices, normals, colors, a, e, b, color)
		triangle(vertices, normals, colors, b, e, f, color)
		for s in [-hw, hw]:
			var ta: Vector3 = point.call(s, u0, true)
			var tb: Vector3 = point.call(s, u1, true)
			var ba: Vector3 = point.call(s, u0, false)
			var bb: Vector3 = point.call(s, u1, false)
			triangle(vertices, normals, colors, ba, ta, tb, side)
			triangle(vertices, normals, colors, ba, tb, bb, side)
	var end_u := TerrainField.RAMP_LENGTH
	var la: Vector3 = point.call(-hw, end_u, true)
	var lb: Vector3 = point.call(hw, end_u, true)
	var ga: Vector3 = point.call(-hw, end_u, false)
	var gb: Vector3 = point.call(hw, end_u, false)
	triangle(vertices, normals, colors, ga, la, lb, side)
	triangle(vertices, normals, colors, ga, lb, gb, side)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, Palette.surface())
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	for s in [-1.0, 1.0]:
		var flag := MeshInstance3D.new()
		flag.mesh = Props.ramp_flag()
		var fx: float = x + s * (hw + 0.4)
		var fd := start + end_u
		flag.position = Vector3(fx, field.height(fx, fd, false), -fd)
		instance.add_child(flag)
	return instance


func _place_roads(chunk: Chunk, decor: Dictionary, rng: RandomNumberGenerator, d0: float, d1: float) -> void:
	for road_d in field.roads_between(d0, d1):
		var road := RoadCrossing.new().setup(field, road_d, rng, engine_sound)
		chunk.add_child(road)
		chunk.roads.append(road)
		chunk.obstacles.append_array(road.cars)
		for side in [-1.0, 1.0]:
			var hw := field.half_width(road_d)
			for k in 2:
				var lx: float = side * (hw + 6.0 + k * 22.0)
				add_decor(decor, Props.lamp_post(), ground_xform(field.center_x(road_d) + lx, road_d - TerrainField.ROAD_HALF_WIDTH - 1.5, PI))
			# Give-way signs facing the sledders just before the road.
			var sign_d := road_d - TerrainField.ROAD_HALF_WIDTH - 2.0
			var sign_x: float = field.center_x(sign_d) + side * (field.half_width(sign_d) + 1.0)
			add_decor(decor, Props.yield_sign(), ground_xform(sign_x, sign_d, -street_yaw(sign_d)))
	for road_d in field.roads_between(d0 + 70.0, d1 + 70.0):
		add_sign(chunk, "VÄG! Se upp för bilar", Color(0.85, 0.1, 0.1), road_d - 70.0, -1.0)


# --- Gameplay objects ---

func obstacle_rig(kind: Obstacle.Kind, rng: RandomNumberGenerator) -> Props.Rig:
	match kind:
		Obstacle.Kind.TREE:
			return Props.Rig.of(Props.spruce(rng.randi_range(0, 2)))
		Obstacle.Kind.ROCK:
			return Props.Rig.of(Props.rock(rng.randi_range(0, 1)))
		Obstacle.Kind.STUMP:
			return Props.Rig.of(Props.stump())
		Obstacle.Kind.SNOWMAN:
			return Props.Rig.of(Props.snowman())
		Obstacle.Kind.PERSON, Obstacle.Kind.KID:
			return Props.person(rng.randi_range(0, 7))
		Obstacle.Kind.DOG:
			return Props.dog()
		Obstacle.Kind.MOOSE:
			return Props.moose()
		Obstacle.Kind.DEER:
			return Props.deer()
		Obstacle.Kind.BIN:
			return Props.Rig.of(Props.bin())
		Obstacle.Kind.TENT:
			return Props.Rig.of(Props.tent())
		Obstacle.Kind.CAR:
			return Props.Rig.of(Props.car(rng.randi_range(0, Palette.CARS.size() - 1)))
		Obstacle.Kind.LOG:
			return Props.Rig.of(Props.fallen_log())
		Obstacle.Kind.CART:
			return Props.Rig.of(RegionProps.shopping_cart())
		Obstacle.Kind.PLANT:
			return Props.Rig.of(RegionProps.potted_plant())
		Obstacle.Kind.FOUNTAIN:
			return Props.Rig.of(RegionProps.fountain())
		Obstacle.Kind.CONE:
			return Props.Rig.of(RegionProps.cone())
		Obstacle.Kind.GOAL:
			return Props.Rig.of(RegionProps.bandy_goal())
		_:
			return Props.hare()


func _pick_kind(zone: TerrainField.Zone, kind: TerrainField.Region, rng: RandomNumberGenerator) -> Obstacle.Kind:
	var table := regions.obstacle_table(kind)
	if table.is_empty():
		match zone:
			TerrainField.Zone.FOREST:
				table = [[Obstacle.Kind.TREE, 8], [Obstacle.Kind.STUMP, 2], [Obstacle.Kind.ROCK, 1], [Obstacle.Kind.DEER, 1]]
			TerrainField.Zone.MOGULS:
				table = [[Obstacle.Kind.ROCK, 2], [Obstacle.Kind.SNOWMAN, 1], [Obstacle.Kind.PERSON, 1]]
			TerrainField.Zone.VILLAGE:
				table = [[Obstacle.Kind.PERSON, 4], [Obstacle.Kind.KID, 3], [Obstacle.Kind.SNOWMAN, 3], [Obstacle.Kind.DOG, 2]]
			TerrainField.Zone.WILDLIFE:
				table = [[Obstacle.Kind.MOOSE, 2], [Obstacle.Kind.DEER, 3], [Obstacle.Kind.HARE, 4], [Obstacle.Kind.TREE, 2]]
			_:
				table = [[Obstacle.Kind.ROCK, 3], [Obstacle.Kind.SNOWMAN, 3], [Obstacle.Kind.TREE, 2], [Obstacle.Kind.PERSON, 1], [Obstacle.Kind.STUMP, 1]]
	var total := 0
	for entry: Array in table:
		total += int(entry[1])
	var roll := rng.randi_range(0, total - 1)
	for entry: Array in table:
		roll -= int(entry[1])
		if roll < 0:
			return entry[0]
	return Obstacle.Kind.ROCK


func _place_obstacles(chunk: Chunk, rng: RandomNumberGenerator, d0: float, d1: float) -> void:
	if d1 < SAFE_START:
		return
	var zone := field.zone((d0 + d1) * 0.5)
	var region_kind := field.region((d0 + d1) * 0.5)
	var density := {
		TerrainField.Zone.OPEN: 0.9, TerrainField.Zone.FOREST: 1.7, TerrainField.Zone.MOGULS: 0.5,
		TerrainField.Zone.VILLAGE: 1.3, TerrainField.Zone.WILDLIFE: 1.0,
	}
	var amount: float = density[zone]
	if region_kind != TerrainField.Region.SLOPE:
		amount = regions.density(region_kind)
		regions.place_fixed_obstacles(chunk, rng, d0, d1)
	var count := int(round(lerpf(2.5, 8.0, field.difficulty(d0)) * amount))
	for i in count:
		var d := rng.randf_range(maxf(d0, SAFE_START), d1)
		if field.near_road(d, 22.0) or field.water_strip(d) != Vector2.ZERO:
			continue
		var here := field.region(d)
		var cx := field.center_x(d)
		var hw := field.half_width(d)
		var x := cx + rng.randf_range(-hw * 0.95, hw * 0.95)
		if field.near_ramp(x, d, 4.0):
			continue
		var kind := _pick_kind(zone, here, rng)
		var rig := regions.rig_for(kind, here, rng)
		var obstacle := Obstacle.new().configure(kind, rig if rig else obstacle_rig(kind, rng), field)
		obstacle.position = Vector3(x, field.height(x, d), -d)
		obstacle.rotation.y = rng.randf() * TAU
		if not regions.setup_obstacle(obstacle, here, rng, cx, hw):
			_setup_obstacle(obstacle, rng, cx, hw)
		chunk.add_child(obstacle)
		chunk.obstacles.append(obstacle)
		if obstacle.velocity != Vector3.ZERO or kind == Obstacle.Kind.PERSON or kind == Obstacle.Kind.KID:
			chunk.movers.append(obstacle)


## Default behaviour for obstacles on the open slope (and in most regions).
func _setup_obstacle(obstacle: Obstacle, rng: RandomNumberGenerator, cx: float, hw: float) -> void:
	var d := -obstacle.position.z
	match obstacle.kind:
		Obstacle.Kind.TREE:
			obstacle.scale = Vector3.ONE * rng.randf_range(0.9, 1.4)
		Obstacle.Kind.PERSON, Obstacle.Kind.KID:
			if obstacle.kind == Obstacle.Kind.KID:
				obstacle.scale = Vector3.ONE * 0.62
			if rng.randf() < 0.5:
				obstacle.patrol(rng.randf_range(1.2, 2.5) * random_sign(rng), cx - hw, cx + hw)
			else:
				obstacle.rotation.y = rng.randf_range(-0.6, 0.6)
		Obstacle.Kind.DOG:
			obstacle.patrol(rng.randf_range(4.0, 7.0) * random_sign(rng), cx - hw, cx + hw)
		Obstacle.Kind.MOOSE:
			obstacle.patrol(rng.randf_range(1.5, 2.6) * random_sign(rng), cx - hw - 10.0, cx + hw + 10.0)
		Obstacle.Kind.DEER:
			obstacle.patrol(rng.randf_range(4.0, 6.5) * random_sign(rng), cx - hw - 6.0, cx + hw + 6.0)
		Obstacle.Kind.HARE:
			obstacle.patrol(rng.randf_range(2.5, 4.5) * random_sign(rng), cx - hw, cx + hw)
		Obstacle.Kind.CAR, Obstacle.Kind.CART, Obstacle.Kind.CONE, Obstacle.Kind.PLANT:
			obstacle.rotation.y = -street_yaw(d) + rng.randf_range(-0.4, 0.4)


func random_sign(rng: RandomNumberGenerator) -> float:
	return -1.0 if rng.randf() < 0.5 else 1.0


func _place_pickups(chunk: Chunk, rng: RandomNumberGenerator, d0: float, d1: float) -> void:
	if d1 < 60.0:
		return
	if rng.randf() < 0.65:
		var start := rng.randf_range(d0, d1 - 25.0)
		var offset := rng.randf_range(-0.6, 0.6)
		var wiggle := rng.randf_range(0.0, 0.3)
		for k in 6:
			var d := start + k * 4.5
			if field.near_road(d, 2.0):
				continue
			var hw := field.half_width(d)
			var x := field.center_x(d) + (offset + sin(k * 0.8) * wiggle) * hw
			_add_pickup(chunk, Pickup.Kind.GINGERBREAD, x, d)
	if d0 > 300.0 and rng.randf() < 0.07:
		var d := rng.randf_range(d0, d1)
		_add_pickup(chunk, Pickup.Kind.COCOA, field.center_x(d) + rng.randf_range(-0.8, 0.8) * field.half_width(d), d)
	if d0 > 200.0 and rng.randf() < 0.1:
		var d := rng.randf_range(d0, d1)
		_add_pickup(chunk, Pickup.Kind.WAX, field.center_x(d) + rng.randf_range(-0.8, 0.8) * field.half_width(d), d)


func _add_pickup(chunk: Chunk, kind: Pickup.Kind, x: float, d: float) -> void:
	var pickup := Pickup.new().configure(kind, Vector3(x, field.height(x, d) + 0.9, -d))
	chunk.add_child(pickup)
	chunk.pickups.append(pickup)
