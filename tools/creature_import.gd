@tool
extends EditorScenePostImport
## Store painted material flags in the imported scene. Switching these on
## only at the first spawn otherwise compiles fresh pipelines during play.
func _post_import(scene: Node) -> Object:
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		for surface in instance.mesh.get_surface_count():
			if not instance.mesh.surface_get_format(surface) & Mesh.ARRAY_FORMAT_COLOR: continue
			var material := instance.mesh.surface_get_material(surface) as StandardMaterial3D
			if material != null: material.vertex_color_use_as_albedo = true
	return scene
