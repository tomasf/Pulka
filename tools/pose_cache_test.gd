extends SceneTree
## Shared crowd geometry, separate outfits, and cancellable ahead-of-player jobs.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var red := Props.person(0)
	var blue := Props.person(1)
	var a := Props.posed(red, 0.0) as MeshInstance3D
	var b := Props.posed(blue, 0.0) as MeshInstance3D
	assert(a.mesh == b.mesh, "Clothing variants must share skinned geometry")
	var checked := false
	for surface in a.mesh.get_surface_count():
		var original := a.mesh.surface_get_material(surface) as StandardMaterial3D
		if original.resource_name == "jacket":
			assert(a.get_active_material(surface).albedo_color == red.colours.jacket)
			assert(b.get_active_material(surface).albedo_color == blue.colours.jacket)
			assert(a.get_active_material(surface) != b.get_active_material(surface))
			checked = true
	assert(checked)
	a.free()
	b.free()
	# Deliberately make these two poses misses even when an export cache is
	# present, so the deferred fallback and cancellation are still exercised.
	Props._baked.erase(Props._pose_key(red, TAU * 0.25))
	Props._baked.erase(Props._pose_key(red, TAU * 0.5))

	var pending := Props.posed(red, TAU * 0.25, true) as MeshInstance3D
	var same := Props.posed(blue, TAU * 0.25, true) as MeshInstance3D
	assert(pending.mesh == null and same.mesh == null, "Scenery creation must not skin a missing pose synchronously")
	assert(Props._pose_order.size() == 1, "Identical poses must coalesce")
	Props.prepare_poses(Time.get_ticks_usec())
	assert(pending.mesh == null, "Do not start preparation after the deadline")
	Props.prepare_poses(Time.get_ticks_usec() + 100000)
	assert(pending.mesh != null and pending.mesh == same.mesh)
	assert(Props._pose_order.is_empty())
	pending.free()
	same.free()

	var removed := Props.posed(red, TAU * 0.5, true)
	removed.free()
	Props.prepare_poses(Time.get_ticks_usec() + 100000)
	assert(Props._pose_order.is_empty() and Props._pose_jobs.is_empty(), "Removed chunks must not leave pending nodes")
	assert(not Props._baked.has(Props._pose_key(red, TAU * 0.5)), "Cancelled poses must not be baked")
	print("pose cache test: all passed")
	quit()
