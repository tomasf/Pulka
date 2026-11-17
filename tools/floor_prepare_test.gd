extends SceneTree
## Painted floors must keep their original geometry while work is deferred.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var world := SlopeWorld.new()
	root.add_child(world)
	world.field = TerrainField.new(4711)
	var lo := 100.0
	var hi := 110.0
	var floor_mesh: MeshInstance3D = world.regions._floor(lo, hi, func(lx: float, _d: float, _hw: float) -> Color: return Color.RED if lx < 0 else Color.BLUE)
	world.add_child(floor_mesh)
	assert(floor_mesh.mesh == null)
	world.regions.prepare_floors(Time.get_ticks_usec())
	assert(floor_mesh.mesh == null, "Respect the deadline")
	world.regions.prepare_floors(Time.get_ticks_usec() + 1000000)
	assert(floor_mesh.mesh != null and floor_mesh.mesh.get_surface_count() == 1)
	var hw := world.field.half_width((lo + hi) / 2)
	var cols := int(hw * 2)
	var arrays := floor_mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	assert(vertices.size() == int(hi - lo) * cols * 6)
	# Original surface sampled a grid at whole metres with a 3 cm offset.
	var expected := Vector3(world.field.center_x(lo) - hw, 0, -lo)
	expected.y = world.field.height(expected.x, lo, false) + 0.03
	assert(vertices[0].distance_to(expected) < 0.0001)
	assert(colors.has(Color.RED.srgb_to_linear()) and colors.has(Color.BLUE.srgb_to_linear()))
	assert(world.regions._floor_jobs.is_empty())
	var removed: MeshInstance3D = world.regions._floor(200, 210, func(_x: float, _d: float, _w: float) -> Color: return Color.WHITE)
	removed.free()
	world.regions.prepare_floors(Time.get_ticks_usec() + 100000)
	assert(world.regions._floor_jobs.is_empty())
	world.queue_free()
	await process_frame
	print("floor prepare test: all passed")
	quit()
