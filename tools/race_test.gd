extends SceneTree
## Runs a two-player race from the menu to the results with synthetic
## keyboard input (no pads: the keyboard is split between the players),
## then checks the game goes back to one player cleanly.
## Run: Godot --headless --fixed-fps 60 --path . --script res://tools/race_test.gd

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	main.set("_muted", true)
	main.set("_no_crash", true)
	# Return to player choice even when --autopilot started a run in _ready.
	# Keep test results out of the player's saved records in either case.
	main.set("_autopilot", true)
	main.call("_enter_menu")
	main.call("_on_hud_pressed", &"duo")
	await _frames(3)
	var players: Array = main.get("_players")
	# This fixture shares the keyboard, regardless of any physical pads
	# connected to the development machine (which otherwise claim player 2).
	for i in players.size():
		var controls := PlayerControls.new()
		controls.keys = PlayerControls.Keys.LEFT if i == 0 else PlayerControls.Keys.RIGHT
		players[i].controls = controls
	_check("choosing two players splits the menu", int(main.get("state")) == 5 and main.get("_two_players"))
	_check("two players in the lobby", players.size() == 2)
	_check("the screen is split", main.get("_split") != null)
	if players.size() != 2:
		main.queue_free()
		quit(1)
		return
	_check("the players start on different rides", players[0].vehicle != players[1].vehicle)
	_check("jackets use distinct palette colors", players[0].color != players[1].color and Palette.JACKETS.has(players[0].color) and Palette.JACKETS.has(players[1].color))
	_check("both visible jackets match their players", _matches_player_color(players[0]) and _matches_player_color(players[1]))
	var first_color: Color = players[0].color
	var second_color: Color = players[1].color
	await create_timer(0.5).timeout
	var before: int = players[0].vehicle
	await _key(KEY_D)
	_check("D picks the first player's next ride", players[0].vehicle != before)
	_check("changing rides preserves both jacket colors", players[0].color == first_color and players[1].color == second_color and _matches_player_color(players[0]))
	before = players[1].vehicle
	await _key(KEY_D)
	_check("D leaves the second player's ride alone", players[1].vehicle == before)
	await _key(KEY_SPACE)
	_check("Space readies the first player", main.get("_ready_flags")[0] and int(main.get("state")) == 5)
	await _key(KEY_ENTER)
	_check("both ready starts the countdown", int(main.get("state")) == 1)
	_check("starting keeps the chosen jacket colors", players[0].color == first_color and players[1].color == second_color)
	await create_timer(4.5).timeout
	_check("the race is on", int(main.get("state")) == 2)
	var field: TerrainField = main.get("_field")
	await _key(KEY_ESCAPE)
	_check("race pauses", paused and int(main.get("state")) == 3)
	for down in [true, false]:
		var back := InputEventJoypadButton.new()
		back.button_index = JOY_BUTTON_B
		back.pressed = down
		Input.parse_input_event(back)
		await _frames(2)
	_check("B resumes the same race with both riders", not paused and int(main.get("state")) == 2 and main.get("_field") == field and players.size() == 2 and main.get("_split") != null)
	var goal: float = float(main.get("_start_d")) + float(main.get("_race_length"))
	var first: Sled = players[0].sled
	first.place_at(goal - 3.0, 0.0, 20.0)
	await _frames(30)
	_check("the first player crosses the line", players[0].finished() and not players[1].finished())
	_check("the second player gets a grace period", float(main.get("_grace")) > 0.0)
	# The finish may be on a jump: the brakes bite once the ride lands.
	await create_timer(5.0).timeout
	_check("the winner brakes to a stop past the line", players[0].sled.speed() < 6.0 and not players[0].sled.crashed)
	players[1].sled.place_at(goal - 3.0, 0.0, 20.0)
	await _frames(30)
	_check("both home ends the race", int(main.get("state")) == 4)
	_check("the first home is first", main.call("_place_of", players[0]) == 1)
	main.call("_start_run")
	_check("race retries keep jackets distinct and match their players", players[0].color != players[1].color and _matches_player_color(players[0]) and _matches_player_color(players[1]))
	main.call("_enter_menu")
	await _frames(3)
	_check("menu after a race returns to player choice", int(main.get("state")) == 0)
	main.call("_on_hud_pressed", &"duo")
	await _frames(3)
	await create_timer(0.5).timeout
	await _key(KEY_ESCAPE)
	await create_timer(0.45).timeout
	_check("back to one player", (main.get("_players") as Array).size() == 1 and main.get("_split") == null)
	var camera: Camera3D = main.get("_camera")
	_check("the first camera is back on the whole screen", camera.get_viewport() == root and camera.current)
	_check("Esc in the split menu goes back to one player", int(main.get("state")) == 0 and not main.get("_two_players"))
	main.call("_start_run")
	await _frames(3)
	_check("a run alone still starts", int(main.get("state")) == 1 and not main.get("_racing"))
	print("race test: %s" % ("all passed" if _failures == 0 else "%d failed" % _failures))
	main.queue_free()
	await process_frame
	await process_frame
	quit(_failures)


func _matches_player_color(player: Player) -> bool:
	for mesh in player.sled._rider._meshes:
		for surface in mesh.mesh.get_surface_count():
			if mesh.mesh.surface_get_material(surface).resource_name == "jacket":
				return mesh.get_surface_override_material(surface).albedo_color == player.color
	return false


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await _frames(3)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _check(name: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("  %s  %s" % ["ok  " if ok else "FAIL", name])
