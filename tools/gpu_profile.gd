extends SceneTree
## What does each effect cost the GPU? Runs an autopilot ride with the Mobile
## renderer at 1080p and switches one effect off at a time, timing the GPU.
## Run (with a window): Godot --path . --rendering-method mobile --script res://tools/gpu_profile.gd

const SECONDS := 3.0

var _main: Node
var _atmosphere: Atmosphere


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	await process_frame
	_main.set("_autopilot", true)
	_main.set("_no_crash", true)
	_main.set("_muted", true)
	AudioServer.set_bus_mute(0, true)
	_main.call("_start_run")
	_atmosphere = _main.get("_atmosphere")
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	await _measure(4.0)  # Warm up: countdown, shaders, first chunks.
	var base := await _measure(SECONDS)
	print("baseline: GPU %.2f ms" % base)
	var environment: Environment = _atmosphere.get("_environment")
	var sun: DirectionalLight3D = _atmosphere.get("_sun")
	var snow: GPUParticles3D = _atmosphere.get("_snow")
	var sky_material: ProceduralSkyMaterial = _atmosphere.get("_sky")
	var tests := {
		"sky colours left alone": [
			func() -> void: _atmosphere.set("_sky", ProceduralSkyMaterial.new()),
			func() -> void: _atmosphere.set("_sky", sky_material)],
		"sky radiance 32 px": [
			func() -> void: environment.sky.radiance_size = Sky.RADIANCE_SIZE_32,
			func() -> void: environment.sky.radiance_size = Sky.RADIANCE_SIZE_256],
		"sky incremental updates": [
			func() -> void: environment.sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL,
			func() -> void: environment.sky.process_mode = Sky.PROCESS_MODE_AUTOMATIC],
		"no glow": [func() -> void: environment.glow_enabled = false, func() -> void: environment.glow_enabled = true],
		"no shadows": [func() -> void: sun.shadow_enabled = false, func() -> void: sun.shadow_enabled = true],
		"no snowfall": [func() -> void: snow.visible = false, func() -> void: snow.visible = true],
		"no fog": [func() -> void: environment.fog_enabled = false, func() -> void: environment.fog_enabled = true],
		"3D at 75 %": [func() -> void: root.scaling_3d_scale = 0.75, func() -> void: root.scaling_3d_scale = 1.0],
	}
	for name: String in tests:
		(tests[name][0] as Callable).call()
		await _measure(0.5)
		var spent := await _measure(SECONDS)
		(tests[name][1] as Callable).call()
		print("%-34s GPU %.2f ms (%+.0f %%)" % [name, spent, (spent / base - 1.0) * 100.0])
	quit()


## Average GPU time per frame over `seconds`.
func _measure(seconds: float) -> float:
	var total := 0.0
	var frames := 0
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
		total += RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
		frames += 1
	return total / maxi(frames, 1)
