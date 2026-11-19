extends Node
## Exportable, opt-in profiler. tools/ is deliberately excluded from device
## builds. Launch with PULKA_DEVICE_PROFILE=1 and optional PULKA_PROFILE_ARGS JSON.
## No fixed FPS: wall intervals measure the device's real frame pacing.
const CASES := ["slope", "town", "river", "park", "woods", "mall", "rail", "airport", "lake", "bandy", "highway", "cliff", "bridge", "roofs", "cave", "harbor", "sewer", "woods/blizzard", "slope/aurora"]
var _main: Node
var _seconds := 20.0
var _cases: Array = CASES.duplicate()
var _modes := [1, 2]
var _results: Array[Dictionary] = []
var _info: Dictionary = {}
var _complete := false
var root: Window
var _status: Label
var _legacy_sky := false
var _shadow_mode := -1
var _shadows := true
var _scale := -1.0
var _radiance := -1
var _shadow_distance := -1.0
var _freeze_sky := false

func run(main: Node) -> void:
	root = get_tree().root
	_main = main
	var layer := CanvasLayer.new()
	layer.layer = 99
	add_child(layer)
	_status = Label.new()
	_status.position = Vector2(20, 110)
	_status.add_theme_font_size_override("font_size", 24)
	_status.add_theme_color_override("font_outline_color", Color.BLACK)
	_status.add_theme_constant_override("outline_size", 6)
	layer.add_child(_status)
	_status.text = "Profilering · ljud av"
	var config = JSON.parse_string(OS.get_environment("PULKA_PROFILE_ARGS"))
	if config is Dictionary:
		_seconds = maxf(2, float(config.get("seconds", _seconds)))
		_cases = config.get("cases", _cases)
		_modes.assign(config.get("modes", _modes))
		_legacy_sky = bool(config.get("legacy_sky", false))
		_shadow_mode = int(config.get("shadow_mode", -1))
		_shadows = bool(config.get("shadows", true))
		_scale = float(config.get("scale", -1))
		_radiance = int(config.get("radiance", -1))
		_shadow_distance = float(config.get("shadow_distance", -1))
		_freeze_sky = bool(config.get("freeze_sky", false))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--profile-seconds="): _seconds = maxf(2, float(arg.get_slice("=", 1)))
		if arg.begins_with("--profile-cases="): _cases = Array(arg.get_slice("=", 1).split(","))
		if arg == "--profile-solo": _modes = [1]
		if arg == "--profile-duo": _modes = [2]
	_main.get("_hud").set_fps_visible(false)
	_info = {"os": OS.get_name(), "model": OS.get_model_name(), "renderer": RenderingServer.get_current_rendering_method(), "driver": RenderingServer.get_current_rendering_driver_name(), "screen": str(DisplayServer.screen_get_size()), "window": str(root.size), "refresh_hz": DisplayServer.screen_get_refresh_rate(), "quality": Quality.LEVEL_NAMES[Quality.level], "scale": root.scaling_3d_scale, "muted": AudioServer.is_bus_mute(0), "baked_audio": SoundBank.uses_baked_audio()}
	print("DEVICE_PROFILE_INFO ", JSON.stringify(_info))
	_info["baked_world"] = ResourceLoader.exists(Props.BAKED_WORLD)
	_info["build"] = OS.get_environment("PULKA_PROFILE_BUILD")
	_info["legacy_sky"] = _legacy_sky
	_info["shadow_mode_override"] = _shadow_mode
	_info["shadows"] = _shadows
	_info["scale_override"] = _scale
	_info["sky_radiance"] = 256
	_info["radiance_override"] = _radiance
	_info["shadow_distance_override"] = _shadow_distance
	_info["freeze_sky"] = _freeze_sky
	_save_results()
	for count in _modes:
		for name in _cases:
			await _case(str(name), count)
	_complete = true
	_status.text = "Profilering klar · %d fall · ljud av" % _results.size()
	_save_results()
	print("DEVICE_PROFILE_DONE ", JSON.stringify({"cases": _results.size(), "muted": AudioServer.is_bus_mute(0)}))
	get_tree().quit()

func _case(name: String, count: int) -> void:
	_status.text = "Profilering · %s · %d spelare · ljud av" % [name, count]
	print("DEVICE_PROFILE_START ", JSON.stringify({"case": name, "players": count}))
	_main.set("_start_region", "")
	_main.call("_enter_menu")
	await get_tree().process_frame
	_main.set("_two_players", count == 2)
	_main.set("_start_event", name.get_slice("/", 1))
	_main.set("_vehicle", 0)
	_main.get("_rng").seed = 4711
	var setup_at := Time.get_ticks_usec()
	_main.call("_start_run")
	var setup_ms := (Time.get_ticks_usec() - setup_at) / 1000.0
	var players: Array = _main.get("_players")
	for p: Player in players:
		p.atmosphere._environment.sky.sky_material = p.atmosphere._sky if _legacy_sky else p.atmosphere._day_sky
		p.atmosphere._sun.shadow_enabled = _shadows
		if _shadow_mode >= 0: p.atmosphere._sun.directional_shadow_mode = _shadow_mode
		if _scale > 0: p.camera.get_viewport().scaling_3d_scale = _scale
		if _radiance >= 0: p.atmosphere._environment.sky.radiance_size = _radiance as Sky.RadianceSize
		if _shadow_distance > 0: p.atmosphere._sun.directional_shadow_max_distance = _shadow_distance
	var world: SlopeWorld = _main.get("_world")
	world.profile_builds = true
	world.build_profile.clear()
	while _main.get("state") == 1: await get_tree().process_frame
	# Reset after the countdown, far enough ahead that the target region has
	# not been built. Its cold preparation now happens during the sample.
	var target := 328.0 if name.get_slice("/", 0) == "slope" else float(_main.call("_find_region", name.get_slice("/", 0)))
	var start := target - 320
	_main.set("_start_d", start)
	setup_at = Time.get_ticks_usec()
	world.reset(_main.get("_field"), start)
	_main.get("_director").reset(start)
	if name.get_slice("/", 1) == "": _main.get("_director").stop()
	else: _main.call("_force_event")
	for p: Player in players:
		var d := start - (65 if p.index == 1 else 0)
		p.sled.set_vehicle(VehicleSpec.all()[0], RandomNumberGenerator.new(), p.color)
		p.sled.place_at(d, -1.6 if p.index == 0 else 1.6, 32)
		p.sled.frozen = false
		p.sled.invulnerable_time = 1000
		p.camera.snap()
		p.camera.snap()
	setup_ms += (Time.get_ticks_usec() - setup_at) / 1000.0
	var views: Array[Viewport] = [root]
	for p: Player in players:
		var view := p.camera.get_viewport()
		if not views.has(view): views.append(view)
	for view in views: RenderingServer.viewport_set_measure_render_time(view.get_viewport_rid(), true)
	# Let queued old chunks retire; no long region-warming delay.
	await get_tree().process_frame
	var wall: Array[float] = []
	var logic: Array[float] = []
	var generation: Array[float] = []
	var cpu: Array[float] = []
	var gpu: Array[float] = []
	var draws: Array[float] = []
	var primitives: Array[float] = []
	var spikes: Array[Dictionary] = []
	var regions: Dictionary = {}
	var mixed_indoor := 0
	var previous_pipelines := _pipelines()
	var previous := Time.get_ticks_usec()
	var until := previous + int(_seconds * 1000000)
	FpsMeter._logic_usec = 0
	world.build_profile.clear()
	while Time.get_ticks_usec() < until:
		await get_tree().process_frame
		if _freeze_sky:
			for p: Player in players: p.atmosphere._sky_state = Vector3(p.sled.distance(), p.atmosphere.storm, p.atmosphere.night_override)
		var now := Time.get_ticks_usec()
		var elapsed := (now - previous) / 1000.0
		var pipelines := _pipelines()
		previous = now
		wall.append(elapsed)
		logic.append(FpsMeter._logic_usec / 1000.0)
		FpsMeter._logic_usec = 0
		generation.append(world.last_update_us / 1000.0)
		var render_cpu := RenderingServer.get_frame_setup_time_cpu()
		var render_gpu := 0.0
		for view in views:
			render_cpu += RenderingServer.viewport_get_measured_render_time_cpu(view.get_viewport_rid())
			render_gpu += RenderingServer.viewport_get_measured_render_time_gpu(view.get_viewport_rid())
		cpu.append(render_cpu)
		gpu.append(render_gpu)
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		for p: Player in players:
			var region_name: String = TerrainField.Region.keys()[p.sled.field.region(p.sled.distance())]
			regions[region_name] = int(regions.get(region_name, 0)) + 1
		if players.size() == 2 and players[0].atmosphere.indoor != players[1].atmosphere.indoor: mixed_indoor += 1
		if elapsed > 25 and spikes.size() < 60:
			spikes.append({"ms": elapsed, "d": players[0].sled.distance(), "world_ms": world.last_update_us / 1000.0, "pipelines": pipelines - previous_pipelines, "builds": world.build_profile.duplicate()})
		previous_pipelines = pipelines
		world.build_profile.clear()
	var result := {"case": name, "players": count, "setup_ms": setup_ms, "frame": _stats(wall), "logic": _stats(logic), "world": _stats(generation), "render_cpu": _stats(cpu), "gpu": _stats(gpu), "draw_calls": _stats(draws), "primitives": _stats(primitives), "regions": regions, "mixed_indoor_frames": mixed_indoor, "distance": players[0].run_distance, "memory_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, "spikes": spikes}
	_results.append(result)
	print("DEVICE_PROFILE_RESULT ", JSON.stringify(result))
	_save_results()

func _save_results() -> void:
	var directory := OS.get_cache_dir() if Quality.is_tv() else OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(directory.path_join("pulka_device_profile.json"), FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"device": _info, "results": _results, "complete": _complete}, "\t"))
	else: _status.text += " · filfel %s" % error_string(FileAccess.get_open_error())

func _stats(samples: Array[float]) -> Dictionary:
	samples.sort()
	if samples.is_empty(): return {}
	var over20 := 0
	var over34 := 0
	var over50 := 0
	for sample in samples:
		if sample > 20: over20 += 1
		if sample > 34: over34 += 1
		if sample > 50: over50 += 1
	return {"n": samples.size(), "median": samples[samples.size() / 2], "p95": samples[int(samples.size() * 0.95)], "p99": samples[int(samples.size() * 0.99)], "max": samples.back(), "over20": over20, "over34": over34, "over50": over50}

func _pipelines() -> int:
	var count := 0
	for monitor in [Performance.PIPELINE_COMPILATIONS_MESH, Performance.PIPELINE_COMPILATIONS_SURFACE, Performance.PIPELINE_COMPILATIONS_DRAW, Performance.PIPELINE_COMPILATIONS_SPECIALIZATION]:
		count += int(Performance.get_monitor(monitor))
	return count
