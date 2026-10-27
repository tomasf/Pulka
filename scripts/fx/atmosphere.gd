class_name Atmosphere
extends Node3D
## Sky, sun, fog, falling snow and the full-screen speed effect. The time of day
## drifts with distance, from crisp morning through sunset into a starry evening.

## [sky_top, horizon, sun color, sun energy, ambient energy, sun pitch (deg)]
const TIMES := [
	[Color(0.28, 0.5, 0.86), Color(0.78, 0.86, 0.95), Color(1.0, 0.96, 0.88), 1.5, 0.5, -38.0],
	[Color(0.35, 0.48, 0.8), Color(0.98, 0.82, 0.62), Color(1.0, 0.8, 0.55), 1.4, 0.45, -22.0],
	[Color(0.3, 0.25, 0.55), Color(1.0, 0.55, 0.45), Color(1.0, 0.55, 0.4), 0.8, 0.55, -10.0],
	[Color(0.04, 0.06, 0.18), Color(0.2, 0.25, 0.45), Color(0.55, 0.65, 1.0), 0.35, 0.45, -50.0],
	[Color(0.18, 0.26, 0.55), Color(0.95, 0.7, 0.7), Color(1.0, 0.75, 0.65), 0.8, 0.6, -15.0],
]
const CYCLE_LENGTH := 6000.0
## The sky is only repainted after this many metres, or a noticeable change
## in storm or night. Every change re-renders and filters the sky's lighting
## map, which costs a phone or Apple TV GPU dearly when done each frame.
const SKY_STEP := 15.0
const SKY_EVENT_STEP := 0.03

var overlay: ShaderMaterial
## 0–1, driven by events: blizzard thickness and how dark the sky is pulled
## towards night (for the northern lights).
var storm := 0.0
var night_override := 0.0
var aurora := 0.0
## Sideways wind direction for the snowfall (world X).
var wind := 1.0
## Under a roof (the mall): no snow falls.
var indoor := false
var _environment: Environment
var _sky: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _snow: GPUParticles3D
var _flash := 0.0
var _snow_process: ParticleProcessMaterial
var _aurora: Array[MeshInstance3D] = []
var _intensity := 0.0
## Distance, storm and night the sky was last painted for.
var _sky_state := Vector3(-INF, 0.0, 0.0)


func _ready() -> void:
	_sky = ProceduralSkyMaterial.new()
	_sky.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = _sky
	if Quality.reduced_effects():
		# Spread the occasional repaint over several frames.
		sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_SKY
	_environment.sky = sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_environment.tonemap_white = 6.0
	_environment.fog_enabled = true
	_environment.fog_density = 0.0028
	_environment.fog_aerial_perspective = 0.6
	_environment.fog_sky_affect = 0.15
	_environment.glow_enabled = Quality.glow()
	_environment.glow_intensity = 0.6
	_environment.glow_bloom = 0.05
	var world_env := WorldEnvironment.new()
	world_env.environment = _environment
	add_child(world_env)

	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = true
	_sun.rotation_degrees = Vector3(-40.0, 35.0, 0.0)
	add_child(_sun)

	_snow = _make_snowfall()
	add_child(_snow)
	_snow_process = _snow.process_material as ParticleProcessMaterial
	for i in 2:
		var curtain := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(700.0, 160.0)
		plane.orientation = PlaneMesh.FACE_Z
		plane.subdivide_width = 40
		curtain.mesh = plane
		var material := ShaderMaterial.new()
		material.shader = load("res://shaders/aurora.gdshader")
		material.set_shader_parameter("seed", i * 3.7)
		curtain.material_override = material
		curtain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		curtain.visible = false
		add_child(curtain)
		_aurora.append(curtain)

	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay = ShaderMaterial.new()
	overlay.shader = load("res://shaders/speed_overlay.gdshader")
	rect.material = overlay
	layer.add_child(rect)
	apply_quality()
	set_time_of_day(0.0)


## Picks up the graphics level (Quality.level), also when it changes.
func apply_quality() -> void:
	_sun.directional_shadow_max_distance = Quality.shadow_distance()
	_sun.directional_shadow_mode = Quality.shadow_mode()
	_snow.amount = maxi(Quality.snowflakes(), 1)


func flash(color: Color, amount := 0.6) -> void:
	_flash = amount
	overlay.set_shader_parameter("flash_color", color)


func update_atmosphere(delta: float, camera: Camera3D, distance: float, speed_factor: float, boosting: bool) -> void:
	_snow.global_position = camera.global_position - camera.global_basis.z * 16.0 + Vector3.UP * 5.0
	if _sky_needs_repaint(Vector3(distance, storm, night_override)):
		set_time_of_day(distance)
	_snow.amount_ratio = 0.0 if indoor else 0.25 + 0.75 * storm
	_snow_process.gravity = Vector3(wind * storm * 14.0, -1.5 - storm * 4.0, 0.0)
	_environment.fog_density = Quality.base_fog() + storm * 0.032
	_update_aurora(camera)
	var target := clampf((speed_factor - 0.35) * 1.4, 0.0, 1.3) + (0.35 if boosting else 0.0)
	_intensity = lerpf(_intensity, target, 1.0 - exp(-4.0 * delta))
	overlay.set_shader_parameter("intensity", _intensity)
	_flash = maxf(0.0, _flash - delta * 2.5)
	overlay.set_shader_parameter("flash", _flash)


func set_time_of_day(distance: float) -> void:
	var phase := fposmod(distance / CYCLE_LENGTH, 1.0) * TIMES.size()
	var a: Array = TIMES[int(phase) % TIMES.size()]
	var b: Array = TIMES[(int(phase) + 1) % TIMES.size()]
	var t := smoothstep(0.0, 1.0, phase - floorf(phase))
	var top: Color = (a[0] as Color).lerp(b[0], t)
	var horizon: Color = (a[1] as Color).lerp(b[1], t)
	_sky.sky_top_color = top
	_sky.sky_horizon_color = horizon
	_sky.ground_horizon_color = horizon
	_sky.ground_bottom_color = horizon.darkened(0.3)
	_sun.light_color = (a[2] as Color).lerp(b[2], t)
	_sun.light_energy = lerpf(a[3], b[3], t)
	_environment.ambient_light_energy = lerpf(a[4], b[4], t)
	_sun.rotation_degrees.x = lerpf(a[5], b[5], t)
	if night_override > 0.0:
		var night: Array = TIMES[3]
		_sky.sky_top_color = _sky.sky_top_color.lerp(night[0], night_override)
		horizon = horizon.lerp(night[1], night_override)
		_sky.sky_horizon_color = horizon
		_sky.ground_horizon_color = horizon
		_sun.light_color = _sun.light_color.lerp(night[2], night_override)
		_sun.light_energy = lerpf(_sun.light_energy, night[3], night_override)
		_environment.ambient_light_energy = lerpf(_environment.ambient_light_energy, night[4], night_override)
	if storm > 0.0:
		var murk := Color(0.72, 0.75, 0.8)
		_sky.sky_top_color = _sky.sky_top_color.lerp(murk, storm * 0.8)
		horizon = horizon.lerp(murk, storm * 0.8)
		_sky.sky_horizon_color = horizon
		_sky.ground_horizon_color = horizon
		_sun.light_energy *= 1.0 - 0.55 * storm
	_environment.fog_light_color = horizon


## True (and remembered) when the sky has drifted far enough from how it was
## last painted. Storms and nights always repaint as they end, so no trace of
## them lingers.
func _sky_needs_repaint(state: Vector3) -> bool:
	var moved := absf(state.x - _sky_state.x) >= SKY_STEP
	for i in [1, 2]:
		moved = moved or absf(state[i] - _sky_state[i]) >= SKY_EVENT_STEP
		moved = moved or (state[i] == 0.0 and _sky_state[i] != 0.0)
	if moved:
		_sky_state = state
	return moved


func _update_aurora(camera: Camera3D) -> void:
	for i in _aurora.size():
		var curtain := _aurora[i]
		curtain.visible = aurora > 0.01
		if not curtain.visible:
			continue
		var ahead := -camera.global_basis.z
		ahead.y = 0.0
		ahead = ahead.normalized()
		var side := ahead.cross(Vector3.UP)
		var at := camera.global_position + ahead * (420.0 + i * 120.0) + side * (i * 160.0 - 80.0) + Vector3.UP * (150.0 + i * 30.0)
		curtain.global_position = at
		curtain.look_at(camera.global_position + Vector3.UP * (150.0 + i * 30.0), Vector3.UP)
		(curtain.material_override as ShaderMaterial).set_shader_parameter("strength", aurora)


func _make_snowfall() -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = Quality.snowflakes()
	particles.lifetime = 3.0
	particles.preprocess = 3.0
	particles.local_coords = false
	particles.visibility_aabb = AABB(Vector3(-60, -40, -60), Vector3(120, 80, 120))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(28.0, 10.0, 28.0)
	process.direction = Vector3(0.2, -1.0, 0.0)
	process.spread = 15.0
	process.initial_velocity_min = 1.5
	process.initial_velocity_max = 3.5
	process.gravity = Vector3(0, -1.5, 0)
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.6
	process.scale_min = 0.5
	process.scale_max = 1.2
	particles.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.14, 0.14)
	quad.material = Sled.soft_flake_material()
	particles.draw_pass_1 = quad
	return particles
