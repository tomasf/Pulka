extends SceneTree
## Validate the repaired props and check the actual front-most plough
## triangles: its chassis must not poke through the continuous blade.
var failures := 0

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	# Exercise the builders, not a possibly stale archive from an earlier export.
	Props.use_baked_world = false
	var models := {"plough": Props.plow(), "snowflake": Props.snowflake(), "cinnamon_bun": Props.cinnamon_bun(), "reeds": Props.reeds(), "lamp": SewerPipe.lamp(), "locomotive": RegionProps.locomotive(), "ship": ContainerHarbor.ship(), "rat0": SewerRat.body(0), "rat1": SewerRat.body(1), "paw": SewerRat.paw()}
	for i in 3: models["tail%d" % i] = SewerRat.tail_piece(i)
	for name: String in models:
		var mesh: ArrayMesh = models[name]
		var valid := mesh.get_surface_count() == 1
		var arrays := mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		valid = valid and vertices.size() == normals.size() and indices.size() % 3 == 0
		for i in vertices.size(): valid = valid and vertices[i].is_finite() and normals[i].is_finite() and absf(normals[i].length() - 1) < 0.01
		for index in indices: valid = valid and index >= 0 and index < vertices.size()
		_check("%s: valid opaque mesh (%d triangles)" % [name, indices.size() / 3], valid)
	var plough: ArrayMesh = models.plough
	var arrays := plough.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var solid := true
	for x in [-1.5, -1.1, -0.6, 0.0, 0.6, 1.1, 1.5]:
		for y in [0.3, 0.6, 0.9, 1.2]:
			var origin := Vector3(x, y, -10)
			var closest := INF
			var colour := Color.BLACK
			for triangle in range(0, indices.size(), 3):
				var hit: Variant = Geometry3D.ray_intersects_triangle(origin, Vector3.BACK, vertices[indices[triangle]], vertices[indices[triangle + 1]], vertices[indices[triangle + 2]])
				if hit != null and origin.distance_to(hit) < closest:
					closest = origin.distance_to(hit)
					colour = colours[indices[triangle]].linear_to_srgb()
			solid = solid and closest < 8 and colour.r > 0.9 and colour.g > 0.4 and colour.b < 0.15
	_check("blade is continuous orange steel across its face, without exposed chassis", solid)
	for i in Shops.TOWN.size():
		var sign := Shops.town_sign(i)
		var width := ThemeDB.fallback_font.get_string_size(sign.text, HORIZONTAL_ALIGNMENT_LEFT, -1, sign.font_size).x * sign.pixel_size
		_check("shop %d fits inside its sign" % i, width <= 4.501)
		sign.free()
	print("model detail test: %s" % ("all passed" if failures == 0 else "%d failed" % failures))
	quit(failures)

func _check(message: String, condition: bool) -> void:
	print(("  ok    " if condition else "  FAIL  ") + message)
	if not condition: failures += 1
