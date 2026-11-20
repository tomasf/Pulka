class_name ShaderWarmup
extends RefCounted
## Starts compiling every game shader before any mesh exists.
##
## Godot's mobile renderer can deadlock when a mesh is created while its
## shader is still compiling: the creating thread waits for the compile while
## holding the scene shader lock, and if every worker thread is already busy
## with pipeline jobs that need that same lock, the compile never gets a
## thread. That happens on a first launch (empty shader cache) on devices
## with few cores, such as an iPad mini, while the baked world cache loads:
## its materials only create their shaders as they are deserialized, between
## meshes that have already queued pipeline jobs.
##
## A shader's compile is queued as soon as its rendering-server shader
## exists, so creating them all up front puts every compile ahead of any
## pipeline job.

const SHADER_DIR := "res://shaders/"
## Every distinct material in the baked world cache, written by
## tools/bake_world_meshes.gd. Small enough to load before anything else.
const BAKED_MATERIALS := "res://generated/world_meshes/materials.res"

static var _keep: Array = []


static func start() -> void:
	if not _keep.is_empty():
		return
	for file in ResourceLoader.list_directory(SHADER_DIR):
		if file.ends_with(".gdshader"):
			var shader := load(SHADER_DIR + file) as Shader
			if shader != null:
				# The rendering server only sees the code once the RID exists.
				shader.get_rid()
				_keep.append(shader)
	if ResourceLoader.exists(BAKED_MATERIALS):
		var archive: Resource = load(BAKED_MATERIALS)
		for material: Material in archive.get_meta("materials", []):
			# A StandardMaterial3D generates and submits its shader here;
			# the cache's copies share it through the same feature key.
			material.get_rid()
			_keep.append(material)


## The distinct materials on every mesh in `value`, searching nested
## dictionaries and arrays.
static func collect_materials(value: Variant, into: Array[Material] = []) -> Array[Material]:
	if value is Mesh:
		var mesh := value as Mesh
		for surface in mesh.get_surface_count():
			var material := mesh.surface_get_material(surface)
			if material != null and not into.has(material):
				into.append(material)
	elif value is Dictionary:
		for item in (value as Dictionary).values():
			collect_materials(item, into)
	elif value is Array:
		for item in value:
			collect_materials(item, into)
	return into
