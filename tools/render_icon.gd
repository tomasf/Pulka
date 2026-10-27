extends SceneTree
## Renders the app icons from the game's own models: the rider on a red pulka
## flying down the slope towards you at dusk.
## Run (with a window, not headless): Godot --path . --script res://tools/render_icon.gd
## Writes icon.png (1024², iOS/web) and, in icons/, the Apple TV app icon as
## a back and a front layer (for tvOS's parallax) plus the Top Shelf images.

const JACKET := Color(0.12, 0.45, 0.95)
const HAT := Color(1.0, 0.78, 0.1)
## Slope of the hill in radians: downhill is towards +Z, the camera.
const SLOPE := 0.2
## Distance up the hill to its crest, where the sky takes over.
const CREST := 24.0

var _world: Node3D
var _camera: Camera3D
var _ride: Node3D
var _background: Array[Node3D] = []
var _foreground: Array[Node3D] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_build_scene()
	await _render("icon.png", Vector2i(1024, 1024), "all")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://icons"))
	for size in [Vector2i(1280, 768), Vector2i(400, 240)]:
		var suffix := "%dx%d" % [size.x, size.y]
		await _render("icons/tv_icon_back_%s.png" % suffix, size, "back")
		await _render("icons/tv_icon_front_%s.png" % suffix, size, "front")
	await _render("icons/top_shelf_1920x720.png", Vector2i(1920, 720), "all", true)
	await _render("icons/top_shelf_wide_2320x720.png", Vector2i(2320, 720), "all", true)
	quit()


func _build_scene() -> void:
	_world = Node3D.new()
	root.add_child(_world)
	var environment := Environment.new()
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color(0.16, 0.3, 0.62)
	sky.sky_horizon_color = Color(1.0, 0.66, 0.52)
	sky.sky_curve = 0.12
	sky.ground_horizon_color = Color(1.0, 0.75, 0.62)
	sky.ground_bottom_color = Color(0.5, 0.55, 0.7)
	sky.sun_angle_max = 8.0
	environment.sky = Sky.new()
	environment.sky.sky_material = sky
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.9
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_white = 1.4
	environment.glow_enabled = true
	environment.glow_intensity = 0.35
	environment.fog_enabled = true
	environment.fog_light_color = Color(1.0, 0.8, 0.72)
	environment.fog_density = 0.006
	environment.fog_sky_affect = 0.0
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	_world.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.86, 0.7)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	sun.rotation = Vector3(-0.55, 0.75, 0.0)
	_world.add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(1.0, 0.6, 0.5)
	rim.light_energy = 0.6
	rim.rotation = Vector3(-0.25, PI + 0.6, 0.0)
	_world.add_child(rim)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, CREST + 40.0)
	plane.material = _snow_material()
	ground.mesh = plane
	ground.position = _on_ground(Vector3(0, 0, 20.0 - CREST * 0.5))
	ground.rotation.x = SLOPE
	_background.append(ground)
	_world.add_child(ground)
	# A few drifts so the snow is not a flat sheet.
	for drift in [Vector3(-3.5, 0, -6), Vector3(4.5, 0, -9), Vector3(-1.0, 0, -16), Vector3(6, 0, 1.5)]:
		_add_background(_drift(drift))
	# Spruces line the run behind the rider.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 22:
		var side := -1.0 if i % 2 == 0 else 1.0
		var at := Vector3(side * rng.randf_range(6.0, 18.0), 0, -rng.randf_range(6.0, CREST - 2.0))
		if i >= 8:
			# A row along the crest, dark against the sky.
			at = Vector3(rng.randf_range(-24.0, 24.0), 0, -CREST + rng.randf_range(0.5, 2.0))
		var tree := MeshInstance3D.new()
		tree.mesh = Props.spruce(rng.randi_range(0, 2))
		tree.position = _on_ground(at)
		tree.rotation.y = rng.randf() * TAU
		tree.scale = Vector3.ONE * rng.randf_range(1.0, 1.8)
		_add_background(tree)

	# The ride, mid-air off a bump, banking into a turn.
	var ride := Node3D.new()
	ride.position = _on_ground(Vector3.ZERO) + Vector3.UP * 0.45
	ride.rotation = Vector3(0.1, PI - 0.45, 0.1)
	var sled := MeshInstance3D.new()
	sled.mesh = RideModels.vehicle(VehicleSpec.Model.PULKA)
	ride.add_child(sled)
	var rider := MeshInstance3D.new()
	rider.mesh = RideModels.rider(JACKET, HAT, VehicleSpec.Model.PULKA)
	rider.position = Vector3(0, 0.16, 0.05)
	rider.rotation.z = -0.1
	ride.add_child(rider)
	_ride = ride
	_foreground.append(ride)
	_world.add_child(ride)
	# Snow kicked up behind and beside the ride.
	for i in 60:
		var puff := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		var radius := rng.randf_range(0.02, 0.07)
		sphere.radius = radius
		sphere.height = radius * 2.0
		sphere.material = _snow_material()
		puff.mesh = sphere
		var back := rng.randf_range(0.4, 2.6)
		var spread := 0.25 + back * 0.3
		puff.position = _on_ground(Vector3(rng.randf_range(-spread, spread), 0, -back)) + Vector3.UP * rng.randf_range(0.05, 0.25 + back * 0.25)
		_foreground.append(puff)
		_world.add_child(puff)

	_camera = Camera3D.new()
	_world.add_child(_camera)
	_camera.current = true


func _add_background(node: Node3D) -> void:
	_background.append(node)
	_world.add_child(node)


## A point on the slope at x, z.
func _on_ground(at: Vector3) -> Vector3:
	return Vector3(at.x, -at.z * tan(SLOPE), at.z)


func _drift(at: Vector3) -> MeshInstance3D:
	var drift := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.material = _snow_material()
	drift.mesh = sphere
	drift.position = _on_ground(at) + Vector3.DOWN * 0.55
	drift.scale = Vector3(3.0, 0.8, 2.0)
	return drift


func _snow_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Palette.SNOW
	material.roughness = 0.85
	return material


## Renders the scene at `size`. `layer` picks what is drawn: everything, only
## the scenery and the ride's shadow ("back") or only the ride on a
## transparent background ("front").
## Top Shelf banners frame the ride to the right with the title on the left.
func _render(path: String, size: Vector2i, layer: String, banner := false) -> void:
	root.size = size
	root.transparent_bg = layer == "front"
	for node in _background:
		node.visible = layer != "front"
	# The back layer keeps the ride's shadow on the snow, just not the ride.
	var casting := GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if layer == "back" else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for node in _foreground:
		for mesh in [node] + node.get_children():
			if mesh is GeometryInstance3D:
				(mesh as GeometryInstance3D).cast_shadow = casting
	var environment: Environment = (_world.get_child(0) as WorldEnvironment).environment
	environment.background_mode = Environment.BG_CLEAR_COLOR if layer == "front" else Environment.BG_SKY
	var aspect := float(size.x) / size.y
	_camera.fov = 30.0
	# Front-right of the ride and a little above it; banners slide the ride
	# to the right third to leave room for the title.
	var center := _ride.position + Vector3.UP * 0.45
	var eye := center + Vector3(1.5, -0.4, 3.5) * (1.15 if aspect < 1.2 else 1.1)
	var right := (center - eye).cross(Vector3.UP).normalized()
	var target := center - right * (1.5 if banner else 0.35)
	_camera.look_at_from_position(eye, target)
	var title: Label = null
	if banner:
		var canvas := CanvasLayer.new()
		root.add_child(canvas)
		title = Hud.label("PULKA!", int(size.y * 0.3), Hud.WARM, int(size.y * 0.03))
		title.position = Vector2(size.x * 0.07, size.y * 0.24)
		canvas.add_child(title)
	for i in 6:
		await process_frame
	var image := root.get_texture().get_image()
	if layer != "front":
		image.convert(Image.FORMAT_RGB8)
	image.save_png(ProjectSettings.globalize_path("res://" + path))
	print("Saved ", path)
	if title:
		title.get_parent().queue_free()
