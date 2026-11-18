class_name Splash
extends Node3D
## A burst of water: droplets thrown up and out, plus a ring spreading on
## the surface. Frees itself when done.

const LIFETIME := 1.2

static var _droplet_material: StandardMaterial3D
static var _ring_mesh: TorusMesh
static var _droplet_mesh: QuadMesh
static var _process_material: ParticleProcessMaterial
static var _ring_template: StandardMaterial3D


## Kept in the world archive so the exact particle and ring vertex formats
## are loaded before the first skim, rather than compiling during the splash.
static func prepared_resources() -> Dictionary:
	if _droplet_mesh != null:
		return {"drop": _droplet_mesh, "ring": _ring_mesh, "process": _process_material, "ring_material": _ring_template}
	Props._load_world_cache()
	var saved: Dictionary = Props._effects.get("splash", {})
	if not saved.is_empty():
		_droplet_mesh = saved.drop
		_ring_mesh = saved.ring
		_process_material = saved.process
		_ring_template = saved.ring_material
		return saved
	_droplet_material = Sled.soft_flake_material().duplicate()
	_droplet_material.albedo_color = Color(0.62, 0.85, 1.0)
	_droplet_mesh = QuadMesh.new()
	_droplet_mesh.size = Vector2(0.18, 0.18)
	_droplet_mesh.material = _droplet_material
	_ring_mesh = TorusMesh.new()
	_ring_mesh.inner_radius = 0.97
	_ring_mesh.outer_radius = 1.0
	_ring_mesh.rings = 24
	_ring_mesh.ring_segments = 4
	_ring_template = StandardMaterial3D.new()
	_ring_template.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_template.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_template.albedo_color = Color(0.82, 0.94, 1.0, 0.55)
	_ring_mesh.material = _ring_template
	_process_material = _make_process_material()
	return {"drop": _droplet_mesh, "ring": _ring_mesh, "process": _process_material, "ring_material": _ring_template}


static func spawn(parent: Node, at: Vector3, carry: Vector3, size := 1.0) -> Splash:
	var splash := Splash.new()
	parent.add_child(splash)
	splash.global_position = at
	splash._build(carry, size)
	return splash


var _ring: MeshInstance3D
var _ring_material: StandardMaterial3D
var _age := 0.0
var _size := 1.0
var _stretch := 1.0


func _build(carry: Vector3, size: float) -> void:
	_size = size
	_stretch = 1.0 + minf(Vector2(carry.x, carry.z).length() / 35, 1.0)
	prepared_resources()
	var drops := GPUParticles3D.new()
	drops.amount = int(70 * size)
	drops.lifetime = 0.9
	drops.one_shot = true
	drops.explosiveness = 0.95
	drops.local_coords = false
	var process := _process_material.duplicate() as ParticleProcessMaterial
	process.initial_velocity_min = 3.0 * size
	process.initial_velocity_max = 9.0 * size
	drops.process_material = process
	drops.draw_pass_1 = _droplet_mesh
	drops.position = carry * 0.05
	add_child(drops)
	drops.emitting = true
	_ring = MeshInstance3D.new()
	_ring.mesh = _ring_mesh
	_ring_material = _ring_template.duplicate()
	_ring.material_override = _ring_material
	_ring.scale = Vector3(1.0, 0.05, _stretch) * size
	if Vector2(carry.x, carry.z).length() > 0.01:
		_ring.rotation.y = atan2(-carry.x, -carry.z)
	_ring.position.y = 0.06
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)


static func _make_process_material() -> ParticleProcessMaterial:
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0, 1, 0)
	process.spread = 55.0
	process.initial_velocity_min = 3.0
	process.initial_velocity_max = 9.0
	process.gravity = Vector3(0, -16, 0)
	process.inherit_velocity_ratio = 0.0
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.5
	process.scale_min = 0.4
	process.scale_max = 1.3
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.95))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	process.color_ramp = ramp
	return process


func _process(delta: float) -> void:
	_age += delta
	var t := _age / LIFETIME
	var reach := (1.0 + t * 3.0) * _size
	_ring.scale = Vector3(reach, 0.05, reach * _stretch)
	_ring_material.albedo_color.a = 0.55 * pow(maxf(1.0 - t, 0), 2)
	if _age > LIFETIME:
		queue_free()
