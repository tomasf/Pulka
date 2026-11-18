class_name BoundaryNet
extends Node3D
## A local, per-camera safety net at the actual invisible crash boundary.
## Curved strips are rebuilt only while visible and after moving four metres.
const FADE_DISTANCE := 10.0
const FULL_DISTANCE := 2.0
const HEIGHT := 3.0
const BEHIND := 18.0
const AHEAD := 58.0
const STEP := 2.0
const SHADER := preload("res://shaders/boundary_net.gdshader")

var view_layer := 1
var strength := Vector2.ZERO
var _sides: Array[MeshInstance3D] = []
var _materials: Array[ShaderMaterial] = []
var _field: TerrainField
var _built_d := INF


func _ready() -> void:
	for i in 2:
		var material := ShaderMaterial.new()
		material.shader = SHADER
		var side := MeshInstance3D.new()
		side.layers = view_layer
		side.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(side)
		_sides.append(side)
		_materials.append(material)
		# Match the real strip's format to prepare its shader during startup,
		# before the first approach to a boundary during play.
		_set_mesh(i, PackedVector3Array([Vector3.ZERO, Vector3.UP, Vector3(0, 1, 1), Vector3(0, 0, 1)]), PackedVector2Array([Vector2.ZERO, Vector2.UP, Vector2.ONE, Vector2.RIGHT]), PackedInt32Array([0, 1, 2, 0, 2, 3]))
	hide()


func update_net(field: TerrainField, sled: Sled, delta: float, enabled: bool) -> void:
	if not enabled or field == null:
		strength = Vector2.ZERO
		_field = null
		hide()
		return
	var d := sled.distance()
	var lateral := sled.position.x - field.center_x(d)
	var bounds := field.warning_bounds(d)
	var gaps := Vector2(lateral - bounds.x, bounds.y - lateral)
	# Also warn before riding into a bend or a region whose limit is tighter.
	var future_d := d + clampf(-sled.velocity.z * 0.5, 0, 24)
	var future_x := sled.position.x + sled.velocity.x * 0.5 - field.center_x(future_d)
	var future_bounds := field.warning_bounds(future_d)
	gaps.x = minf(gaps.x, future_x - future_bounds.x)
	gaps.y = minf(gaps.y, future_bounds.y - future_x)
	for i in 2:
		var target := 0.0 if is_inf(gaps[i]) else 1.0 - smoothstep(FULL_DISTANCE, FADE_DISTANCE, gaps[i])
		strength[i] = lerpf(strength[i], target, 1.0 - exp(-10.0 * delta))
		_sides[i].visible = strength[i] > 0.005
		_materials[i].set_shader_parameter("strength", strength[i])
		_materials[i].set_shader_parameter("rider_position", sled.position)
	visible = strength.x > 0.005 or strength.y > 0.005
	if not visible: return
	if field != _field or absf(d - _built_d) >= 4.0:
		_field = field
		_built_d = floorf(d / 4.0) * 4.0
		_rebuild(field, _built_d)


func _rebuild(field: TerrainField, d: float) -> void:
	global_position = Vector3(field.center_x(d), field.height(field.center_x(d), d, false), -d)
	var first := d - BEHIND
	var stations := _stations(field, first, d + AHEAD)
	var bounds: Array[Vector2] = []
	for at in stations: bounds.append(field.warning_bounds(at))
	for side in 2:
		var vertices := PackedVector3Array()
		var uv := PackedVector2Array()
		var indices := PackedInt32Array()
		for station in range(1, stations.size()):
			var at := stations[station - 1]
			var next := stations[station]
			var a := bounds[station - 1][side]
			var b := bounds[station][side]
			if not is_inf(a) and not is_inf(b):
				var base := vertices.size()
				for sample: Vector2 in [Vector2(at, a), Vector2(next, b)]:
					var x: float = field.center_x(sample.x) + sample.y
					var bottom := Vector3(x, field.height(x, sample.x, false) - 0.15, -sample.x) - global_position
					vertices.append(bottom)
					vertices.append(bottom + Vector3.UP * HEIGHT)
					# 52 m is a common period of the net cells and 4 m posts.
					var u := fposmod(first, 52.0) + sample.x - first
					uv.append(Vector2(u, 0))
					uv.append(Vector2(u, HEIGHT))
				indices.append_array([base, base + 1, base + 2, base + 2, base + 1, base + 3])
		_set_mesh(side, vertices, uv, indices)


func _stations(field: TerrainField, first: float, last: float) -> Array[float]:
	var cuts := {first: true, last: true}
	var spans := {}
	var at := first
	while at < last:
		cuts[at] = true
		var span := field.region_span(at)
		if span.y > span.x and not spans.has(span.x):
			spans[span.x] = true
			var edges := [span.x, span.y]
			var inset: float = {TerrainField.Region.BRIDGE: TerrainField.BRIDGE_APPROACH, TerrainField.Region.ROOFS: TerrainField.ROOF_APPROACH, TerrainField.Region.ICE_CAVE: TerrainField.CAVE_INSET, TerrainField.Region.SEWER: TerrainField.SEWER_INSET, TerrainField.Region.HARBOR: TerrainField.HARBOR_INSET}.get(field.region(span.x + 0.01), 0)
			if inset > 0: edges.append_array([span.x + inset, span.y - inset])
			for edge: float in edges:
				# Preserve sudden changes in the real limit, rather than cutting
				# diagonally across several metres of otherwise safe snow.
				for offset in [-0.01, 0.01]:
					if edge + offset > first and edge + offset < last: cuts[edge + offset] = true
		at += STEP
	var result: Array[float] = []
	result.assign(cuts.keys())
	result.sort()
	return result


func _set_mesh(side: int, vertices: PackedVector3Array, uv: PackedVector2Array, indices: PackedInt32Array) -> void:
	var mesh := _sides[side].mesh as ArrayMesh
	if mesh == null: mesh = ArrayMesh.new()
	else: mesh.clear_surfaces()
	if not vertices.is_empty():
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_INDEX] = indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, _materials[side])
	_sides[side].mesh = mesh
