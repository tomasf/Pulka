class_name CatPopulation
extends RefCounted
## House-bound pets. No zone table can spawn a cat without a real home.
## Independent seeding keeps the existing scenery and obstacle layout intact.

const HOME_RADIUS := 14.0
const PER_CHUNK := 2

static func populate(world: SlopeWorld, chunk: Chunk) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(world.field.world_seed, chunk.index, 19453))
	var count := 0
	var homes := chunk.homes.duplicate()
	for i in range(homes.size() - 1, 0, -1):
		var other := rng.randi_range(0, i)
		var previous: Transform3D = homes[i]
		homes[i] = homes[other]
		homes[other] = previous
	for home: Transform3D in homes:
		if count >= PER_CHUNK: break
		var boosted := world.forced_kind == Obstacle.Kind.CAT
		if not boosted and rng.randf() > 0.32: continue
		# The front of both house types is local -Z. Leave room for steps
		# and the porch, rather than putting the cat inside the building.
		var point := home * Vector3(rng.randf_range(-2, 2), 0, -7)
		if not allowed(world, chunk, point, home): continue
		point.y = world.field.height_world(point.x, point.z)
		var cat := Obstacle.new().configure(Obstacle.Kind.CAT, Props.cat(rng.randi_range(0, 2)), world.field)
		cat.position = point
		cat.rotation.y = rng.randf_range(-PI, PI)
		# Walk a short, checked stretch outside this home. Neither end may
		# enter a house, a crossing or another region as the cat wanders.
		var lo := point.x
		var hi := point.x
		for step in 7:
			var next := Vector3(lo - 0.5, point.y, point.z)
			if not allowed(world, chunk, next, home): break
			lo = next.x
		for step in 7:
			var next := Vector3(hi + 0.5, point.y, point.z)
			if not allowed(world, chunk, next, home): break
			hi = next.x
		# Leave a little stopping room at each end for the discrete tick.
		if hi - lo >= 1.5 and rng.randf() < 0.75:
			cat.patrol(rng.randf_range(0.65, 1.05) * (-1 if rng.randf() < 0.5 else 1), lo + 0.2, hi - 0.2)
		chunk.add_child(cat)
		chunk.obstacles.append(cat)
		chunk.movers.append(cat) # Standing cats also receive idle animation.
		count += 1


static func allowed(world: SlopeWorld, chunk: Chunk, point: Vector3, home: Transform3D) -> bool:
	var field := world.field
	var d := -point.z
	if d < SlopeWorld.SAFE_START or field.region(d) not in [TerrainField.Region.SLOPE, TerrainField.Region.TOWN]: return false
	if Vector2(point.x - home.origin.x, point.z - home.origin.z).length() > HOME_RADIUS: return false
	if absf(point.x - field.center_x(d)) > field.half_width(d) + 14: return false
	if field.near_road(d, 14) or field.in_corridor(point.x, d, 2) or field.near_ramp(point.x, d, 3): return false
	if field.is_water(d, point.x): return false
	for building in chunk.homes:
		var local := building.affine_inverse() * point
		# A conservative footprint for both wooden houses and town blocks.
		if absf(local.x) < 5.7 and absf(local.z) < 5.7: return false
	for obstacle in chunk.obstacles:
		if obstacle.clearance(point) < 0.6: return false
	return true
