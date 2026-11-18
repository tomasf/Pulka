class_name CrowdMesh
extends RefCounted
## Merge a baked person into one surface without duplicating outfit geometry.
## Normally baked at export; the same builder handles a missing local cache.
const CLOTHES := ["jacket", "jacket_trim", "pants", "trunks", "hat", "hat_cuff", "scarf"]
static var _material: ShaderMaterial

static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = preload("res://shaders/crowd.gdshader")
	return _material

static func build(source: ArrayMesh) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var custom := PackedFloat32Array()
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var shade := source.surface_get_material(surface) as StandardMaterial3D
		assert(shade != null and shade.albedo_texture == null)
		var slot := CLOTHES.find(shade.resource_name) + 1
		var colour := shade.albedo_color.srgb_to_linear()
		var painted: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var offset := vertices.size()
		vertices.append_array(points)
		normals.append_array(arrays[Mesh.ARRAY_NORMAL])
		for i in points.size():
			# Retain the source colours even for overridden clothing: the
			# offline LOD simplifier uses them to preserve material seams.
			colors.append(colour * (painted[i] if shade.vertex_color_use_as_albedo and not painted.is_empty() else Color.WHITE))
			custom.append_array(PackedFloat32Array([slot, 0, 0, 0]))
		var source_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if source_indices.is_empty():
			for i in points.size(): indices.append(offset + i)
		else:
			for i in source_indices: indices.append(offset + i)
	var joined := []
	joined.resize(Mesh.ARRAY_MAX)
	joined[Mesh.ARRAY_VERTEX] = vertices
	joined[Mesh.ARRAY_NORMAL] = normals
	joined[Mesh.ARRAY_COLOR] = colors
	joined[Mesh.ARRAY_INDEX] = indices
	joined[Mesh.ARRAY_CUSTOM0] = custom
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, joined, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	mesh.surface_set_material(0, material())
	return mesh

static func dress(instance: MeshInstance3D, clothes: Dictionary) -> void:
	for name: String in CLOTHES:
		if clothes.has(name): instance.set_instance_shader_parameter(name, clothes[name])
