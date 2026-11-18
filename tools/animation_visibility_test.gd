extends SceneTree
## Visibility culling must combine the two split-screen cameras.
func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var fox := Props.fox().make()
	stage.add_child(fox)
	fox.play(&"walk")
	var views: Array[SubViewport] = []
	var cameras: Array[Camera3D] = []
	for index in 2:
		var view := SubViewport.new()
		view.size = Vector2i(640, 480)
		view.world_3d = stage.get_world_3d()
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(view)
		var camera := Camera3D.new()
		view.add_child(camera)
		camera.position = Vector3(0, 1, -5)
		camera.look_at(Vector3(0, .4, 0))
		camera.current = true
		views.append(view)
		cameras.append(camera)
	for frame in 5: await process_frame
	assert(fox._player.can_process(), "Visible animals must animate")
	for camera in cameras: camera.look_at(Vector3(100, 1, -20))
	for frame in 5: await process_frame
	assert(not fox._player.can_process(), "Fully off-screen animals should stop uploading bones")
	var paused_position := fox.position
	var paused_clip := fox._current
	cameras[1].look_at(Vector3(0, .4, 0))
	for frame in 5: await process_frame
	assert(fox._player.can_process(), "Player 2 alone must keep an animal animated")
	assert(fox.position == paused_position and fox._current == paused_clip, "Visibility must not move the animal or change its animation")
	fox.set_animation_near(false)
	assert(not fox._player.can_process(), "Tiny distant silhouettes should not upload bones")
	fox.set_animation_near(true)
	assert(fox._player.can_process(), "Approaching either rider resumes the same animation")
	cameras[1].look_at(Vector3(100, 1, -20))
	cameras[0].look_at(Vector3(0, .4, 0))
	for frame in 5: await process_frame
	assert(fox._player.can_process(), "Player 1 alone must also animate the animal")
	for view in views: view.free()
	stage.free()
	await process_frame
	print("animation visibility test: all passed")
	quit()
