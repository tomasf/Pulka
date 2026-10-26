class_name Splash
extends Node3D
## A burst of water: droplets thrown up and out, plus a ring spreading on
## the surface. Frees itself when done.

const LIFETIME := 1.2

static var _droplet_material: StandardMaterial3D
static var _ring_mesh: TorusMesh


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


func _build(carry: Vector3, size: float) -> void:
	_size = size
	if _droplet_material == null:
		_droplet_material = Sled.soft_flake_material()
		_droplet_material.albedo_color = Color(0.85, 0.93, 1.0)
		_ring_mesh = TorusMesh.new()
		_ring_mesh.inner_radius = 0.85
		_ring_mesh.outer_radius = 1.0
		_ring_mesh.rings = 24
		_ring_mesh.ring_segments = 4
	var drops := GPUParticles3D.new()
	drops.amount = int(70 * size)
	drops.lifetime = 0.9
	drops.one_shot = true
	drops.explosiveness = 0.95
	drops.local_coords = false
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0, 1, 0)
	process.spread = 55.0
	process.initial_velocity_min = 3.0 * size
	process.initial_velocity_max = 9.0 * size
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
	drops.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.18, 0.18)
	quad.material = _droplet_material
	drops.draw_pass_1 = quad
	drops.position = carry * 0.05
	add_child(drops)
	drops.emitting = true
	_ring = MeshInstance3D.new()
	_ring.mesh = _ring_mesh
	_ring_material = StandardMaterial3D.new()
	_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_material.albedo_color = Color(0.9, 0.96, 1.0, 0.8)
	_ring.material_override = _ring_material
	_ring.scale = Vector3(1.0, 0.05, 1.0) * size
	_ring.position.y = 0.06
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)


func _process(delta: float) -> void:
	_age += delta
	var t := _age / LIFETIME
	var reach := (1.0 + t * 4.0) * _size
	_ring.scale = Vector3(reach, 0.05, reach)
	_ring_material.albedo_color.a = 0.8 * (1.0 - t)
	if _age > LIFETIME:
		queue_free()
