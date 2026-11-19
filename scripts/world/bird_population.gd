class_name BirdPopulation
extends RefCounted
## Seeded separately from obstacles: adding wildlife never moves a tree,
## snowflake or ramp. Real mesh anchors keep perched feet on visible surfaces.

static func ground_allowed(field: TerrainField, x: float, d: float) -> bool:
	if field.region(d) not in [TerrainField.Region.SLOPE, TerrainField.Region.WOODS, TerrainField.Region.PARK, TerrainField.Region.TOWN, TerrainField.Region.HARBOR]: return false
	if field.near_road(d, 14) or field.in_corridor(x, d, 3) or field.near_ramp(x, d, 3): return false
	if field.in_cliff_fall(d) or field.is_water(d, x) or field.harbor_water(x, d): return false
	return absf(x - field.center_x(d)) < field.half_width(d) * 0.85 and field.harbor_surface_lift(x, d) < 0


static func populate(world: SlopeWorld, chunk: Chunk, decor: Dictionary, d0: float, d1: float) -> void:
	if d1 < 30: return
	var field := world.field
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(field.world_seed, chunk.index, 8721))
	var candidates: Array[Vector3] = []
	var outward: Array[Vector3] = []
	# Scenery trees and decorative boulders live in the MultiMesh batches.
	for mesh: Mesh in decor:
		if not mesh.has_meta(&"bird_perches"): continue
		var anchors: PackedVector3Array = mesh.get_meta(&"bird_perches")
		for at: Transform3D in decor[mesh]:
			var d := -at.origin.z
			if not _outdoors(field, d): continue
			if absf(at.origin.x - field.center_x(d)) > field.half_width(d) + 7: continue
			var seat := at * anchors[rng.randi_range(0, anchors.size() - 1)]
			candidates.append(seat)
			var out := seat - at.origin
			out.y = 0
			outward.append(out.normalized())
	# Obstacles carry their own rotated/scaled visual (rocks, stumps and
	# the occasional tree in the track), unlike the invisible edge colliders.
	for obstacle in chunk.obstacles:
		if obstacle.kind not in [Obstacle.Kind.TREE, Obstacle.Kind.ROCK, Obstacle.Kind.STUMP]: continue
		var mesh := obstacle.visual.mesh
		if mesh == null or not mesh.has_meta(&"bird_perches"): continue
		if not _outdoors(field, -obstacle.position.z): continue
		var anchors: PackedVector3Array = mesh.get_meta(&"bird_perches")
		var seat := obstacle.transform * obstacle.visual.transform * anchors[rng.randi_range(0, anchors.size() - 1)]
		# Near-track rocks/stumps are especially good places to spot a bird.
		candidates.push_front(seat)
		outward.push_front(Vector3.ZERO)
	var perches := mini(candidates.size(), rng.randi_range(1, 2))
	for i in perches:
		var choice := 0 if i == 0 else rng.randi_range(0, candidates.size() - 1)
		var at := candidates[choice]
		var out := outward[choice]
		candidates.remove_at(choice)
		outward.remove_at(choice)
		var species: BirdMeshes.Species = BirdMeshes.Species.BULLFINCH if rng.randf() < 0.4 else BirdMeshes.Species.MAGPIE
		_add(chunk, field, at, species, rng, true, out)
	# Small loose groups forage and walk on the snow, leaving a clear run
	# through dangerous/indoor regions rather than spawning on unseen floors.
	if rng.randf() > 0.6: return
	var d := rng.randf_range(maxf(d0 + 5, 30), d1 - 5)
	var cx := field.center_x(d) + rng.randf_range(-0.55, 0.55) * field.half_width(d)
	var species: BirdMeshes.Species = BirdMeshes.Species.CROW if rng.randf() < 0.65 else BirdMeshes.Species.MAGPIE
	for i in rng.randi_range(2, 4):
		var x := cx + rng.randf_range(-2.5, 2.5)
		var along := d + rng.randf_range(-3, 3)
		if not ground_allowed(field, x, along): continue
		var at := Vector3(x, field.height(x, along) + 0.015, -along)
		var clear := true
		for obstacle in chunk.obstacles:
			if obstacle.overlaps(at + Vector3.UP * 0.2, 0.8):
				clear = false
				break
		for bird in chunk.birds:
			if bird.position.distance_squared_to(at) < 0.8: clear = false
		if clear: _add(chunk, field, at, species, rng)


static func _outdoors(field: TerrainField, d: float) -> bool:
	return field.region(d) in [TerrainField.Region.SLOPE, TerrainField.Region.WOODS, TerrainField.Region.PARK, TerrainField.Region.TOWN, TerrainField.Region.RIVER]


static func _add(chunk: Chunk, field: TerrainField, at: Vector3, species: BirdMeshes.Species, rng: RandomNumberGenerator, perched := false, outward := Vector3.ZERO) -> void:
	var bird := AmbientBird.new().configure(field, at, species, rng.randi(), perched, outward, chunk.obstacles)
	chunk.add_child(bird)
	chunk.birds.append(bird)
