extends SceneTree
## Whole menu → live preview → camera → countdown → run, for both modes.
## Add --capture with the native renderer to save the review screenshots.
var main: Node
var failures := 0
var capture := false
var steps: Array[int] = []
var max_camera_step := 0.0
var max_camera_angle := 0.0
var min_camera_radius := INF
var compact := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	compact = OS.get_cmdline_user_args().has("--compact")
	root.size = Vector2i(960, 540) if compact else Vector2i(1600, 900)
	capture = OS.get_cmdline_user_args().has("--capture")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_process(false)
	main.set("_autopilot", true) # Never write test choices to the player's save.
	main.set("_no_crash", true)
	main.get("_save").best_distance = 0
	main.get("_save").unlocked_distance = 0
	main.set("_vehicle", 0)
	main.call("_enter_menu")
	var hud: Hud = main.get("_hud")
	if Quality.is_mobile(): hud.set_touch_mode(true)
	await _tick(35)
	_check("first screen only chooses players", main.get("state") == 0 and hud._menu.players.visible and not hud._menu.picker.visible)
	_check("menu theme is a separate playing loop", main.get("_sound")._in_menu and main.get("_sound")._menu_player.playing)
	var fitted := Rect2(hud._menu.canvas.position, MenuFlow.DESIGN * hud._menu.canvas.scale)
	_check("fitted menu stays inside the viewport", fitted.position.x >= -1 and fitted.position.y >= -1 and fitted.end.x <= hud._menu.size.x + 1 and fitted.end.y <= hud._menu.size.y + 1)
	_check("menu fonts contain Swedish letters", MenuFlow.font(true).has_char(197) and MenuFlow.font().has_char(228))
	await _shot("players")
	var field: TerrainField = main.get("_field")
	main.call("_on_hud_pressed", &"solo")
	await _tick(8)
	await _shot("transition-early")
	await _tick(16)
	await _shot("transition-middle")
	await _tick(24)
	_check("solo opens ride selection", main.get("state") == 6 and hud._menu.picker.visible)
	_check("selection keeps the preview world", main.get("_field") == field)
	var first_preview_color: Color = main.get("_players")[0].color
	_check("picker settles with its panels in place and background hidden", not hud._menu.players.visible and not hud._menu._background.visible and hud._menu._picker_details.position == Vector2.ZERO and hud._menu._picker_dock.position == Vector2.ZERO)
	_check("solo logo is centered on the screen", is_equal_approx(hud._menu._brand.get_global_rect().get_center().x, hud._menu.get_global_rect().get_center().x))
	if not Quality.is_mobile():
		await _prompt_switching(hud)
	var preview_pose: Transform3D = main.get("_camera").transform
	main.call("_on_hud_pressed", &"players")
	_check("Back preserves the preview world and camera", main.get("_field") == field and main.get("_camera").transform == preview_pose)
	await _tick(8)
	await _shot("transition-back")
	# A quick change of mind must cancel outgoing hide callbacks too.
	var detail_before := hud._menu._picker_details.position
	var opacity_before := hud._menu.picker.modulate.a
	main.call("_on_hud_pressed", &"solo")
	_check("reversing direction preserves the current pose and opacity", hud._menu._picker_details.position == detail_before and is_equal_approx(hud._menu.picker.modulate.a, opacity_before))
	_check("reopening selection chooses a different jacket", main.get("_players")[0].color != first_preview_color)
	await _tick(48)
	_check("interrupted return settles on the picker", main.get("state") == 6 and hud._menu.picker.visible and not hud._menu.players.visible and not hud._menu._background.visible and hud._menu._picker_dock.position == Vector2.ZERO)
	_check("entrances preserve locked card dimming", is_equal_approx(hud._menu.cards.back().modulate.a, 0.42))
	var solo_color: Color = main.get("_players")[0].color
	main.call("_on_hud_pressed", &"vehicle_3")
	_check("locked rides can be previewed but not started", hud._menu.start.disabled and main.get("_vehicle") == 3)
	main.call("_start_run")
	_check("locked ride stays in the picker", main.get("state") == 6)
	main.call("_on_hud_pressed", &"vehicle_2")
	_check("solo ride selection preserves the randomized jacket", main.get("_players")[0].color == solo_color and Palette.JACKETS.has(solo_color))
	await _tick(15)
	await _shot("vehicle")
	var sled: Sled = main.get("_sled")
	var camera: ChaseCamera = main.get("_camera")
	var before := camera.transform
	var position := sled.position
	var body: Mesh = sled.get("_vehicle_mesh").mesh
	var chunk_ids := []
	for chunk in main.get("_world")._chunks.values(): chunk_ids.append(chunk.get_instance_id())
	var start_began := Time.get_ticks_usec()
	main.call("_start_run")
	_check("solo start keeps the preview's jacket", main.get("_players")[0].color == solo_color)
	print("solo start CPU: %.2f ms" % ((Time.get_ticks_usec() - start_began) / 1000.0))
	_check("start keeps world, mesh and rider position", main.get("_field") == field and sled.get("_vehicle_mesh").mesh == body and sled.position == position)
	_check("start does not snap the camera", camera.transform.is_equal_approx(before) and camera.mode == ChaseCamera.Mode.START)
	for chunk in main.get("_world")._chunks.values():
		_check("start retains each visible chunk", chunk_ids.has(chunk.get_instance_id()))
	await _tick(25)
	_check("rider waits while the camera turns", sled.frozen and main.get("_countdown_step") == 0)
	await _shot("camera")
	await _tick(44)
	_check("countdown starts with three after the camera arrives", main.get("_countdown_step") == 3 and camera.mode == ChaseCamera.Mode.CHASE)
	await _shot("countdown")
	await _tick(180)
	_check("countdown shows every number in order", steps == [3, 2, 1])
	_check("camera has no position jumps", max_camera_step < 0.4)
	_check("camera turns without rotation jumps", max_camera_angle < 0.15)
	_check("camera stays outside the rider", min_camera_radius > 4.0)
	print("camera: max step %.3f m, max turn %.2f degrees, min radius %.2f m" % [max_camera_step, rad_to_deg(max_camera_angle), min_camera_radius])
	_check("go releases the rider and hides selection", main.get("state") == 2 and not sled.frozen and not hud._menu.visible)
	_check("run crossfades away from menu music", not main.get("_sound")._in_menu and not main.get("_sound")._menu_player.playing)
	await _shot("ride")

	# Replacing a number must cancel the old number's delayed fade.
	var number := CountdownDisplay.new()
	root.add_child(number)
	number.show_count("3")
	await _tick(30)
	number.show_count("2")
	await _tick(14)
	_check("old number cannot fade a new number", number.text == "2" and number.modulate.a > 0.99)
	number.queue_free()
	if Quality.is_mobile():
		_check("phone shows touch instructions", hud._menu._controls_hint.accessibility_name.contains("Svep"))
		main.queue_free()
		await process_frame
		print("menu flow mobile test: %s" % ("all passed" if failures == 0 else "%d failed" % failures))
		quit(failures)
		return

	main.call("_enter_menu")
	await _tick(25)
	field = main.get("_field")
	main.call("_on_hud_pressed", &"duo")
	await _tick(8)
	await _shot("duo-transition-early")
	await _tick(42)
	var racers: Array = main.get("_players")
	_check("two players choose rides in a split preview", main.get("state") == 5 and racers.size() == 2)
	_check("duo selection uses the same world", main.get("_field") == field)
	_check("duo shares the animated menu header", hud._menu.visible and hud._menu.lobby.visible and not hud._menu._background.visible)
	_check("duo logo is centered on the screen divider", is_equal_approx(hud._menu._brand.get_global_rect().get_center().x, hud._menu.get_global_rect().get_center().x))
	_check("both player panels settle in place", racers[0].race_hud._lobby_content.position == Vector2.ZERO and racers[1].race_hud._lobby_content.position == Vector2.ZERO)
	_check("shared confirm has no focused lobby navigation button", root.gui_get_focus_owner() == null)
	var old_split: CanvasLayer = main.get("_split")
	main.call("_on_hud_pressed", &"players")
	_check("Back covers the existing split before removing it", main.get("_split") == old_split and hud._menu._background.visible)
	await _tick(30)
	_check("covered return removes split and restores the main menu", main.get("state") == 0 and main.get("_split") == null and hud._menu.players.visible)
	field = main.get("_field")
	main.call("_on_hud_pressed", &"duo")
	await _tick(50)
	racers = main.get("_players")
	_check("duo can reopen during the return animation", main.get("state") == 5 and hud._menu.lobby.visible and not hud._menu.players.visible and not hud._menu._background.visible and main.get("_field") == field)
	await _split_prompts(racers)
	var second_ride: int = racers[1].vehicle
	main.call("_on_lobby_action", &"next", racers[0])
	_check("each player's picker is independent", racers[1].vehicle == second_ride)
	await _shot("duo")
	main.call("_on_lobby_action", &"ready", racers[0])
	await _tick(2)
	_check("one ready waits for the other", main.get("state") == 5)
	main.call("_on_lobby_action", &"ready", racers[1])
	await _tick(2)
	_check("both ready starts one countdown on the same world", main.get("state") == 1 and main.get("_field") == field)
	await _tick(252)
	_check("both players start together", main.get("state") == 2 and not racers[0].sled.frozen and not racers[1].sled.frozen)
	_check("both intro cameras remain smooth", max_camera_step < 0.4 and max_camera_angle < 0.15)
	_camera_angles_test(racers[0].sled, racers[0].camera)
	main.queue_free()
	await process_frame
	await process_frame
	print("menu flow test: %s" % ("all passed" if failures == 0 else "%d failed" % failures))
	quit(failures)

func _camera_angles_test(sled: Sled, camera: ChaseCamera) -> void:
	sled.frozen = true
	sled.velocity = Vector3.ZERO
	for phase in [0.0, PI * 0.5, PI - 0.001, PI, PI + 0.001, TAU - 0.001]:
		camera.set("_orbit_angle", phase)
		camera.mode = ChaseCamera.Mode.ORBIT
		camera.update_camera(0.0)
		camera.begin_run()
		var smooth := true
		for frame in 70:
			var position := camera.position
			var rotation := camera.quaternion
			camera.update_camera(1.0 / 60.0)
			var towards := (sled.position + Vector3.UP * 0.8 - camera.position).normalized()
			smooth = smooth and position.distance_to(camera.position) < 0.4 and rotation.angle_to(camera.quaternion) < 0.15 and (-camera.basis.z).dot(towards) > 0.9
		_check("camera keeps the rider framed from %.1f degrees" % rad_to_deg(phase), smooth)


func _prompt_switching(hud: Hud) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SHIFT
	key.pressed = true
	await _send(key)
	_check("keyboard prompts show Space and Enter without pad alternatives", hud._menu._controls_hint.accessibility_name == "← → Styr Space Hoppa" and hud._menu._start_hint.accessibility_name == "Enter Åk")
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_LEFT_SHOULDER
	pad.pressed = true
	await _send(pad)
	var pad_controls := "Svep / spak Styr Klick / A Hoppa" if Quality.is_tv() else "spak Styr A Hoppa"
	_check("pad input switches every solo prompt", hud._menu._controls_hint.accessibility_name == pad_controls and hud._menu._picker_hint.accessibility_name == "spak Välj åkdon" and hud._menu._start_hint.accessibility_name == "A Åk")
	await _shot("gamepad-hints")
	key.pressed = false
	await _send(key)
	await _send(InputEventMouseMotion.new())
	_check("key releases and mouse movement preserve pad prompts", hud._menu._start_hint.accessibility_name == "A Åk")
	key.pressed = true
	await _send(key)
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_RIGHT_X
	stick.axis_value = 0.12
	await _send(stick)
	pad.pressed = false
	await _send(pad)
	_check("stick drift and pad releases preserve keyboard prompts", hud._menu._start_hint.accessibility_name == "Enter Åk")
	stick.axis_value = 0.8
	await _send(stick)
	_check("deliberate stick movement selects pad prompts", hud._menu._start_hint.accessibility_name == "A Åk")
	stick.axis_value = 0.0
	await _send(stick)
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	await _send(touch)
	_check("touch replaces button prompts with gestures", hud._menu._controls_hint.accessibility_name.contains("Svep"))
	touch.pressed = false
	await _send(touch)
	key.pressed = true
	await _send(key)
	_check("keyboard use restores keycaps after touch", hud._menu._start_hint.accessibility_name == "Enter Åk" and not hud._touch_mode)
	key.pressed = false
	await _send(key)


func _split_prompts(racers: Array) -> void:
	var original := [racers[0].controls, racers[1].controls]
	# Synthetic pads make this independent of hardware on the test machine.
	for i in 2:
		var controls := PlayerControls.new()
		controls.keys = PlayerControls.Keys.LEFT if i == 0 else PlayerControls.Keys.RIGHT
		controls.pad = 6 + i
		racers[i].controls = controls
		racers[i].race_hud.update_control_hint(controls)
	await _tick(2)
	var first: MenuFlow.InputHint = racers[0].race_hud._lobby_controls
	var second: MenuFlow.InputHint = racers[1].race_hud._lobby_controls
	var panel: Panel = racers[0].race_hud._lobby_content.get_child(0)
	_check("lobby control tips have bottom padding", panel.position.y + panel.size.y - first.position.y - first.size.y >= 18)
	var pad := InputEventJoypadButton.new()
	pad.device = 6
	pad.button_index = JOY_BUTTON_LEFT_SHOULDER
	pad.pressed = true
	await _send(pad)
	_check("first pad updates only its player's prompts", first.accessibility_name == "spak Styr A Hoppa" and second.accessibility_name == "← → Styr Enter Hoppa")
	pad.device = 7
	await _send(pad)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_D
	key.pressed = true
	await _send(key)
	_check("shared keyboard updates only the matching player's prompts", first.accessibility_name == "A D Styr Space Hoppa" and second.accessibility_name == "spak Styr A Hoppa")
	key.pressed = false
	await _send(key)
	for device in [6, 7]:
		pad.device = device
		pad.pressed = false
		await _send(pad)
	for i in 2:
		racers[i].controls = original[i]
		racers[i].race_hud.update_control_hint(original[i])


func _send(event: InputEvent) -> void:
	Input.parse_input_event(event)
	await process_frame
	await process_frame


func _tick(frames: int) -> void:
	for frame in frames:
		var cameras: Array[ChaseCamera] = []
		var positions: Array[Vector3] = []
		var orientations: Array[Quaternion] = []
		for player in main.get("_players"):
			cameras.append(player.camera)
			positions.append(player.camera.position)
			orientations.append(player.camera.quaternion)
		var state_before: int = main.get("state")
		var began := Time.get_ticks_usec()
		main.call("_process", 1.0 / 60.0)
		if state_before == 5 and main.get("state") == 1:
			print("race start CPU: %.2f ms" % ((Time.get_ticks_usec() - began) / 1000.0))
		if main.get("state") == 1:
			for i in cameras.size():
				var camera := cameras[i]
				max_camera_step = maxf(max_camera_step, positions[i].distance_to(camera.position))
				max_camera_angle = maxf(max_camera_angle, orientations[i].angle_to(camera.quaternion))
				if camera.mode == ChaseCamera.Mode.START:
					var relative := camera.position - camera.target.position
					min_camera_radius = minf(min_camera_radius, Vector2(relative.x, relative.z).length())
			var step: int = main.get("_countdown_step")
			if step > 0 and not steps.has(step): steps.append(step)
		await process_frame

func _shot(name: String) -> void:
	if capture:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/pulka-menu-%s%s.png" % ["compact-" if compact else "", name])

func _check(message: String, condition: bool) -> void:
	print(("  ok    " if condition else "  FAIL  ") + message)
	if not condition: failures += 1
