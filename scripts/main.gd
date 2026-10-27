extends Node3D
## Game flow: menu → countdown → run (crashes cost a mitten) → game over.

enum State { MENU, COUNTDOWN, PLAYING, PAUSED, GAME_OVER }

const START_LIVES := 3
const MAX_LIVES := 5
const RESPAWN_DELAY := 2.8
## How long a crash line stays readable.
const CRASH_LINE_HOLD := 3.4
const START_D := 8.0

const CRASH_LINES := {
	Obstacle.Kind.TREE: ["Granen vann.", "Trädkramare!", "Barr i munnen.", "Granen stod där först."],
	Obstacle.Kind.ROCK: ["Stenhårt!", "Stenen rörde sig inte en millimeter.", "Aj, aj, sten!"],
	Obstacle.Kind.STUMP: ["Stubben var där först.", "Stubbad!"],
	Obstacle.Kind.PERSON: ["Ursäkta! Ursäkta!", "Farbror Bengt såg dig inte komma.", "Mormor tappade termosen!"],
	Obstacle.Kind.KID: ["Barnet skrattade. Du grät.", "Lilla Elsa vann den duellen."],
	Obstacle.Kind.DOG: ["Voff!", "Hunden trodde du var en pinne.", "Taxen tog ingen skada. Du däremot..."],
	Obstacle.Kind.MOOSE: ["Älgen är okej. Det är inte du.", "Skogens konung vinner alltid.", "Du blev älgad."],
	Obstacle.Kind.DEER: ["Rådjuret blev mest förvånat.", "Bambi: 1, Du: 0"],
	Obstacle.Kind.CAR: ["Tuuut! Bilen hade företräde.", "Titta åt båda hållen nästa gång!", "Pulka mot Volvo. Volvo vann."],
	Obstacle.Kind.PLOW: ["Plogbilen plogade dig.", "Du blev en snövall."],
	Obstacle.Kind.BIN: ["Soptunnan tog hand om dig.", "Rätt i återvinningen!"],
	Obstacle.Kind.CART: ["Kundvagnen vann.", "Du blev handlad.", "Kassa 3 är stängd."],
	Obstacle.Kind.PLANT: ["Fikusen överlevde.", "Rakt in i grönskan."],
	Obstacle.Kind.FOUNTAIN: ["Plask i fontänen!", "Önska något!"],
	Obstacle.Kind.CONE: ["Konen stod där av en anledning.", "Pling, kon!"],
	Obstacle.Kind.TRAIN: ["Tåget går inte att stoppa.", "Fel spår!", "Inte ens försenat."],
	Obstacle.Kind.PLANE: ["Flyget väntar inte på någon.", "Försenad avgång."],
	Obstacle.Kind.TUG: ["Bagaget kom fram. Du inte.", "Bagagebandet nästa!"],
	Obstacle.Kind.TRUCK: ["Långtradaren vann.", "Fel fil!", "Chauffören fick en historia att berätta."],
	Obstacle.Kind.GOAL: ["Självmål!", "Rakt i nätet!"],
	Obstacle.Kind.TENT: ["Pimpelfiskaren är inte glad.", "Abborrarna skrattar åt dig."],
}
const GAME_OVER_LINES := [
	"Pulkan har talat.", "Nu får du gå upp igen.", "Snö i nacken, snö i själen.",
	"Mamma ropar på middag!", "Vantarna är slut.", "Det var ändå ett bra åk.",
]
const NEAR_MISS_LINES := ["Nära ögat!", "Puh!", "Hårsmån!", "Snyggt!", "Oj oj oj!"]

var state := State.MENU

var _save: SaveData
var _specs: Array[VehicleSpec] = []
var _vehicle := 0
var _rng := RandomNumberGenerator.new()
var _field: TerrainField
var _world_root: Node3D
var _world: SlopeWorld
var _sled: Sled
var _camera: ChaseCamera
var _atmosphere: Atmosphere
var _sound: SoundBank
var _hud: Hud

var _lives := START_LIVES
var _bonus := 0
var _run_distance := 0.0
var _countdown := 0.0
var _countdown_step := 0
var _crash_timer := 0.0
var _input_cooldown := 0.0
var _cookie_streak := 0
var _cookie_timer := 0.0
## Set when the ride goes over a cliff edge, until it lands.
var _over_cliff := false
var _elapsed := 0.0

var _autopilot := false
var _screenshot_path := ""
var _screenshot_times: Array[float] = [6.0]
var _screenshot_index := 0
var _reckless := false
var _no_crash := false
var _speed_multiplier := 1.0
var _muted := false
var _open_settings_at_start := false
## Testing aid: show the frame rate without changing the saved setting.
var _show_fps := false
## Testing aid: a graphics level (Quality.Level) other than the default.
var _graphics_override := -1
var _start_region := ""
var _start_d := START_D
var _start_event := ""
var _director: EventDirector
var _touch: TouchControls
var _bonus_fraction := 0.0
var _last_crash_line := ""
var _start_vehicle := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputSetup.configure()
	_parse_args()
	get_window().content_scale_factor = Quality.ui_scale()
	_save = SaveData.load_saved()
	if _graphics_override >= 0:
		Quality.level = _graphics_override as Quality.Level
	_specs = VehicleSpec.all()
	for i in _specs.size():
		if _specs[i].id == _save.vehicle_id:
			_vehicle = i
	if _start_vehicle >= 0:
		_vehicle = clampi(_start_vehicle, 0, _specs.size() - 1)
	_rng.randomize()

	_world_root = Node3D.new()
	_world_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_world_root)
	_sound = SoundBank.new()
	_sound.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_sound)
	_atmosphere = Atmosphere.new()
	_world_root.add_child(_atmosphere)
	_world = SlopeWorld.new()
	_world.engine_sound = _sound.engine_sound
	_world.horn_sound = _sound.stream("train_horn")
	_world.jet_sound = _sound.stream("jet")
	_world.car_horn_sound = _sound.stream("horn")
	_world_root.add_child(_world)
	_sled = Sled.new()
	_sled.speed_multiplier = _speed_multiplier
	_world_root.add_child(_sled)
	_sled.jumped.connect(_on_jumped)
	_sled.landed.connect(_on_landed)
	_sled.skimmed.connect(_on_skimmed)
	_sled.sank.connect(_on_sank)
	_director = EventDirector.new()
	_director.sled = _sled
	_director.atmosphere = _atmosphere
	_director.sound = _sound
	_world_root.add_child(_director)
	_director.snowball_hit.connect(_on_snowball_hit)
	_director.gift_collected.connect(_on_gift_collected)
	_camera = ChaseCamera.new()
	_camera.target = _sled
	_world_root.add_child(_camera)
	_camera.current = true
	_hud = Hud.new()
	add_child(_hud)
	_hud.pressed.connect(_on_hud_pressed)
	_touch = TouchControls.new()
	add_child(_touch)
	_touch.mode_changed.connect(_hud.set_touch_mode)
	_hud.set_touch_mode(DisplayServer.is_touchscreen_available() and Quality.is_mobile())
	_hud.volume_changed.connect(_on_volume_changed)
	SoundBank.apply_volumes(_save.master_volume, _save.music_volume, _save.effects_volume)
	if _muted:
		AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Master"), true)

	_restore_fullscreen.call_deferred()
	_hud.set_fps_visible(_save.show_fps or _show_fps)
	_apply_graphics()
	_enter_menu()
	if _open_settings_at_start:
		_hud.open_settings(_save.master_volume, _save.music_volume, _save.effects_volume)
	if _autopilot:
		_start_run()


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--autopilot":
			_autopilot = true
			_muted = true
		elif arg == "--mobile-preview":
			Quality.force_mobile = true
		elif arg == "--tv-preview":
			Quality.force_tv = true
			Quality.level = Quality.default_level()
		elif arg == "--mute":
			_muted = true
		elif arg.begins_with("--screenshot="):
			_screenshot_path = arg.get_slice("=", 1)
		elif arg.begins_with("--shot-at="):
			_screenshot_times.clear()
			for time in arg.get_slice("=", 1).split(","):
				_screenshot_times.append(float(time))
		elif arg.begins_with("--start-region="):
			_start_region = arg.get_slice("=", 1)
		elif arg.begins_with("--event="):
			_start_event = arg.get_slice("=", 1)
		elif arg.begins_with("--graphics="):
			_graphics_override = Quality.LEVEL_NAMES.find(arg.get_slice("=", 1).capitalize())
		elif arg == "--show-fps":
			_show_fps = true
		elif arg == "--settings":
			_open_settings_at_start = true
		elif arg == "--reckless":
			_reckless = true
		elif arg == "--no-crash":
			_no_crash = true
		elif arg.begins_with("--speed-multiplier="):
			var value := arg.trim_prefix("--speed-multiplier=")
			var multiplier := value.to_float() if value.is_valid_float() else 0.0
			if is_finite(multiplier) and multiplier > 0.0:
				_speed_multiplier = multiplier
			else:
				push_warning("--speed-multiplier requires a positive, finite number; ignoring '%s'." % value)
		elif arg.begins_with("--vehicle="):
			_start_vehicle = int(arg.get_slice("=", 1))


## Browsers require fullscreen requests to run inside the input event itself.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"fullscreen") and not event.is_echo():
		_toggle_fullscreen()
		get_viewport().set_input_as_handled()


func _toggle_fullscreen() -> void:
	var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
	_remember_fullscreen()


## Stores the current window mode so the next launch starts the same way.
func _remember_fullscreen() -> void:
	if _autopilot or Quality.is_mobile():
		return
	_save.fullscreen = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	_save.store()


## Desktop only: browsers refuse fullscreen without a click, phones always are.
func _restore_fullscreen() -> void:
	if _save.fullscreen and not _autopilot and _screenshot_path == "" and not OS.has_feature("web") and not Quality.is_mobile():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _process(delta: float) -> void:
	var started := Time.get_ticks_usec()
	_elapsed += delta
	_input_cooldown = maxf(0.0, _input_cooldown - delta)
	_update_settings_input()
	_update_go_back()
	match state:
		State.MENU:
			_update_menu(delta)
		State.COUNTDOWN:
			_update_countdown(delta)
		State.PLAYING:
			_update_playing(delta)
		State.PAUSED:
			_update_paused()
		State.GAME_OVER:
			_update_game_over(delta)
	if state != State.PAUSED:
		var playing := state == State.PLAYING and not _sled.crashed
		_director.update(delta, playing)
		_atmosphere.indoor = _world.regions.indoors(_sled.distance())
		_camera.update_camera(delta)
		_atmosphere.update_atmosphere(delta, _camera, _sled.distance(), _sled.speed() / 45.0 if playing else 0.0, _sled.boost_time > 0.0)
		_sound.set_motion(delta, _sled.speed(), _sled.on_ground, playing)
	FpsMeter.record_logic(Time.get_ticks_usec() - started)
	_maybe_screenshot()


# --- States ---

func _new_world() -> void:
	_field = TerrainField.new(_rng.randi())
	_world.reset(_field, START_D)
	_sled.field = _field
	_camera.field = _field
	_director.field = _field


func _enter_menu() -> void:
	get_tree().paused = false
	if _director.field:
		_director.reset(START_D)
		_director.stop()
	_hud.close_settings()
	state = State.MENU
	_new_world()
	_sled.set_vehicle(_specs[_vehicle], _rng)
	_sled.frozen = true
	_sled.place_at(START_D)
	_camera.mode = ChaseCamera.Mode.ORBIT
	_hud.show_screen("menu")
	_refresh_menu()
	_sound.set_music_ducked(false)
	_input_cooldown = 0.3


func _refresh_menu() -> void:
	var spec := _specs[_vehicle]
	_hud.update_menu(spec, _is_unlocked(spec), _save.best_distance, _save.best_score)


func _is_unlocked(spec: VehicleSpec) -> bool:
	return _save.best_distance >= spec.unlock_distance


func _update_menu(delta: float) -> void:
	_world.update_world(_sled.distance(), delta)
	_sled.step(delta, 0.0, 0.0, false)
	if _input_cooldown > 0.0 or _hud.settings_open:
		return
	if Input.is_action_just_pressed(&"menu_left"):
		_change_vehicle(-1)
	elif Input.is_action_just_pressed(&"menu_right"):
		_change_vehicle(1)
	if _confirm_pressed():
		_start_run()


func _change_vehicle(step: int) -> void:
	_vehicle = (_vehicle + step + _specs.size()) % _specs.size()
	_sled.set_vehicle(_specs[_vehicle], _rng)
	_sled.place_at(START_D)
	_refresh_menu()
	_sound.play("whoosh", -6.0, 1.4)


func _start_run() -> void:
	get_tree().paused = false
	var spec := _specs[_vehicle]
	if not _is_unlocked(spec):
		_sound.play("oops")
		return
	_save.vehicle_id = spec.id
	if not _autopilot:
		_save.store()
	_new_world()
	_start_d = START_D
	if _start_region != "":
		_start_d = _find_region(_start_region) - 120.0
		_world.reset(_field, _start_d)
	_sled.set_vehicle(spec, _rng)
	_sled.frozen = true
	_sled.place_at(_start_d)
	_sled.invulnerable_time = 0.0
	_over_cliff = false
	_lives = START_LIVES
	_bonus = 0
	_bonus_fraction = 0.0
	_director.reset(_start_d)
	if _start_event != "":
		var kinds := {"blizzard": EventDirector.Kind.BLIZZARD, "snowballs": EventDirector.Kind.SNOWBALLS, "santa": EventDirector.Kind.SANTA, "aurora": EventDirector.Kind.AURORA}
		_director.force_next(kinds.get(_start_event, EventDirector.Kind.BLIZZARD), _start_d)
	_run_distance = 0.0
	_cookie_streak = 0
	_touch.reset()
	_camera.mode = ChaseCamera.Mode.CHASE
	_camera.snap()
	_countdown = 3.0
	_countdown_step = 4
	state = State.COUNTDOWN
	_hud.show_screen("game")
	_sound.set_music_ducked(false)


func _update_countdown(delta: float) -> void:
	# The countdown stands still, so it can afford to build more ahead.
	_world.update_world(_sled.distance(), delta, 8.0)
	_sled.step(delta, 0.0, 0.0, false)
	_countdown -= delta
	var step := ceili(_countdown)
	if step != _countdown_step and step > 0:
		_countdown_step = step
		_hud.show_center(str(step))
		_sound.play("beep")
	if _countdown <= 0.0:
		state = State.PLAYING
		_sled.frozen = false
		_sled.velocity = _field.track_dir(_start_d) * 9.0
		_hud.show_center("ÅK!", Hud.HOT)
		_sound.play("go")
	_update_hud()


func _update_playing(delta: float) -> void:
	if Input.is_action_just_pressed(&"pause"):
		_set_paused(true)
		return
	var steer := clampf(Input.get_axis(&"steer_left", &"steer_right") + _touch.steer, -1.0, 1.0)
	var tuck := maxf(Input.get_action_strength(&"tuck"), _touch.tuck())
	var jump := Input.is_action_just_pressed(&"jump") or _touch.consume_jump()
	if _autopilot:
		steer = _autopilot_steer()
		tuck = 1.0
	var before := _sled.distance()
	_sled.step(delta, steer, tuck, jump)
	_world.update_world(_sled.distance(), delta)
	_check_cliff(before)
	_cookie_timer = maxf(0.0, _cookie_timer - delta)
	if _cookie_timer == 0.0:
		_cookie_streak = 0
	if _sled.crashed:
		_crash_timer -= delta
		if _crash_timer <= 0.0:
			_after_crash()
	else:
		var travelled := maxf(_sled.distance() - _start_d, _run_distance)
		_add_distance_bonus(travelled - _run_distance)
		_run_distance = travelled
		_check_collisions()
		_check_pickups()
		_check_bounds()
	_update_hud()


## Going over a cliff edge: a scream, and a reward if you land it.
func _check_cliff(before: float) -> void:
	var edge := _field.cliff_edge(before)
	if _sled.crashed or before >= edge or _sled.distance() < edge:
		return
	_over_cliff = true
	_hud.popup("AAAAAAAH!", Hud.HOT, 84, 2.5)
	_sound.play("whoosh", 0.0, 0.7)
	_camera.add_shake(0.25)


func _update_hud() -> void:
	_hud.update_game(_run_distance, _score(), _sled.speed(), _lives, maxi(START_LIVES, _lives), _director.multiplier)


func _add_bonus(points: int) -> void:
	_bonus += roundi(points * _director.multiplier)


## Distance counts extra while a score multiplier is active.
func _add_distance_bonus(metres: float) -> void:
	_bonus_fraction += metres * (_director.multiplier - 1.0)
	var whole := floori(_bonus_fraction)
	_bonus += whole
	_bonus_fraction -= whole


func _on_snowball_hit() -> void:
	_hud.splat()
	_sound.play("splat", 2.0, _rng.randf_range(0.9, 1.3))
	_sled.velocity *= 0.92
	_camera.add_shake(0.35)
	_rumble(0.3, 0.3, 0.15)


func _on_gift_collected() -> void:
	_add_bonus(100)
	_hud.popup("+100", Hud.HOT)
	_sound.play("cocoa", -2.0, _rng.randf_range(0.95, 1.15))


func _score() -> int:
	return int(_run_distance) + _bonus


func _set_paused(paused: bool) -> void:
	get_tree().paused = paused
	state = State.PAUSED if paused else State.PLAYING
	_hud.show_screen("pause" if paused else "game")
	_sound.set_music_ducked(paused)


func _update_paused() -> void:
	if _input_cooldown > 0.0 or _hud.settings_open:
		return
	if Input.is_action_just_pressed(&"pause") or _confirm_pressed():
		_set_paused(false)
	elif Input.is_action_just_pressed(&"back"):
		_enter_menu()


func _update_game_over(delta: float) -> void:
	_world.update_world(_sled.distance(), delta)
	_sled.step(delta, 0.0, 0.0, false)
	if _input_cooldown > 0.0:
		return
	if _confirm_pressed():
		_start_run()
	elif Input.is_action_just_pressed(&"back"):
		_enter_menu()


## Start always confirms; Enter/Space/A only when no on-screen button has
## focus (otherwise the focused button handles the press itself).
func _confirm_pressed() -> bool:
	if Input.is_action_just_pressed(&"start"):
		return true
	return Input.is_action_just_pressed(&"confirm") and not _hud.owns_focus()


# --- On-screen buttons and app lifecycle ---

func _on_hud_pressed(action: StringName) -> void:
	match action:
		&"fullscreen":
			_toggle_fullscreen()
		&"show_fps":
			_save.show_fps = not _save.show_fps
			_hud.set_fps_visible(_save.show_fps)
		&"start":
			if state == State.MENU:
				_start_run()
		&"previous", &"next":
			if state == State.MENU:
				_change_vehicle(-1 if action == &"previous" else 1)
		&"settings":
			if state == State.MENU or state == State.PAUSED:
				_hud.open_settings(_save.master_volume, _save.music_volume, _save.effects_volume)
		&"close_settings":
			_close_settings()
		&"pause":
			if state == State.PLAYING:
				_set_paused(true)
		&"resume":
			if state == State.PAUSED:
				_set_paused(false)
		&"menu":
			if state == State.PAUSED or state == State.GAME_OVER:
				_enter_menu()
		&"retry":
			if state == State.GAME_OVER or state == State.PAUSED:
				_start_run()


## Applies the graphics level to the 3D view, the light and the snowfall.
func _apply_graphics() -> void:
	var viewport := get_viewport()
	viewport.scaling_3d_mode = Quality.scaling_mode()
	viewport.scaling_3d_scale = Quality.render_scale()
	_atmosphere.apply_quality()


func _close_settings() -> void:
	_hud.close_settings()
	_save.store()
	_input_cooldown = 0.2


## Phones: leaving the app (call, home button) pauses the run. Closing the
## window remembers fullscreen (the window button may have changed it).
## Apple TV's Menu button pauses or goes back a step.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_remember_fullscreen()
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if state == State.PLAYING and not _autopilot:
			_set_paused(true)


## Menu on the Siri Remote: pause a run, otherwise act as the back button.
## In the main menu it goes to the Apple TV home screen instead, as tvOS
## expects (see _update_go_back).
func _go_back() -> void:
	if state == State.PLAYING:
		_set_paused(true)
		return
	var press := InputEventAction.new()
	press.action = &"back"
	press.pressed = true
	Input.parse_input_event(press)
	var release := press.duplicate() as InputEventAction
	release.pressed = false
	Input.parse_input_event.call_deferred(release)


## Only the top level hands Menu back to the system.
func _update_go_back() -> void:
	if Quality.is_tv():
		get_tree().quit_on_go_back = state == State.MENU and not _hud.settings_open


# --- Settings ---

func _update_settings_input() -> void:
	if _hud.settings_open:
		if Input.is_action_just_pressed(&"back") or Input.is_action_just_pressed(&"pause") or Input.is_action_just_pressed(&"settings"):
			_close_settings()
	elif (state == State.MENU or state == State.PAUSED) and _input_cooldown <= 0.0 and Input.is_action_just_pressed(&"settings"):
		_hud.open_settings(_save.master_volume, _save.music_volume, _save.effects_volume)


func _on_volume_changed(channel: int, value: float) -> void:
	match channel:
		0:
			_save.master_volume = value
		1:
			_save.music_volume = value
		2:
			_save.effects_volume = value
	SoundBank.apply_volumes(_save.master_volume, _save.music_volume, _save.effects_volume)
	if channel == 2:
		_sound.play("coin", -4.0)


# --- Gameplay events ---

## Velocity change (m/s, after the ride's protection) that knocks you off
## balance, and that ends in a crash costing a mitten.
const WIPEOUT_SEVERITY := 3.5
## Height of the rider's chest above the collision probe.
const RIDER_CHEST := 0.75
const CRASH_SEVERITY := 7.5
## Points for landing a cliff, on top of the air time.
const CLIFF_BONUS := 500
const WIPEOUT_LINES := ["Vurpa!", "Hoppla!", "Puh, klarade mig!", "Det där gjorde ont i stoltheten."]


func _check_collisions() -> void:
	var probe := _sled.position + Vector3.UP * 0.3
	var d := _sled.distance()
	for obstacle in _world.obstacles_near(d):
		if not obstacle.visible or obstacle.hit:
			continue
		if obstacle.is_vehicle() and _on_roof(obstacle, probe):
			_roof_bounce(obstacle)
			continue
		if obstacle.landable and _on_top(obstacle, probe):
			_top_hop(obstacle)
			continue
		var contact := _contact(obstacle, probe)
		if _sled.invulnerable_time <= 0.0 and contact != Vector3.INF:
			_impact(obstacle, contact)
			if _sled.crashed:
				return
			continue
		if obstacle.near_miss_done:
			continue
		if obstacle.clearance(probe) < 1.7 and probe.y < obstacle.position.y + obstacle.height() + 0.8:
			obstacle.close_call = true
		if obstacle.close_call and -obstacle.position.z < d - 1.5:
			obstacle.near_miss_done = true
			_near_miss(obstacle)


## Where the ride touches `obstacle`, or INF. Spruces are also checked at
## the rider's chest, which brushes the low branches the sled slips under.
func _contact(obstacle: Obstacle, probe: Vector3) -> Vector3:
	if obstacle.overlaps(probe, Sled.RADIUS):
		return probe
	var chest := probe + Vector3.UP * RIDER_CHEST
	if obstacle.kind == Obstacle.Kind.TREE and obstacle.overlaps(chest, Sled.RADIUS * 0.6):
		return chest
	return Vector3.INF


## Coming down from above onto a car is a trampoline, not a crash.
func _on_roof(obstacle: Obstacle, probe: Vector3) -> bool:
	var roof := obstacle.position.y + obstacle.top
	return _sled.velocity.y < 1.0 and probe.y > roof - 0.9 and probe.y < roof + 0.8 and obstacle.clearance(probe) < Sled.RADIUS


## Coming down from the air onto the top of something (a head, a rock).
func _on_top(obstacle: Obstacle, probe: Vector3) -> bool:
	var top := obstacle.position.y + obstacle.height()
	return not _sled.on_ground and _sled.velocity.y < 1.0 and probe.y > top - obstacle.height() * 0.45 and probe.y < top + 0.8 and obstacle.clearance(probe) < Sled.RADIUS


## Not a crash: people and animals topple, you get a small hop and lose a
## little speed. Hard things just give you something to bounce off.
func _top_hop(obstacle: Obstacle) -> void:
	obstacle.near_miss_done = true
	_sled.bounce(3.5)
	_sled.velocity *= 0.88
	_camera.add_shake(0.3)
	_rumble(0.3, 0.3, 0.15)
	if obstacle.is_creature():
		obstacle.launch(_sled.travel_velocity() * 0.25 + Vector3.UP * 2.0)
		_add_bonus(30)
		_hud.popup("Hoppsan! +30", Hud.WARM)
		_sound.play("moose" if obstacle.kind == Obstacle.Kind.MOOSE else "oops", 0.0, _rng.randf_range(1.0, 1.3))
	else:
		_sound.play("land", 0.0, 1.2)


func _roof_bounce(obstacle: Obstacle) -> void:
	obstacle.near_miss_done = true
	_sled.bounce(8.5)
	_sled.velocity += Vector3(obstacle.velocity.x * 0.3, 0.0, 0.0)
	var points := 400 if obstacle.kind == Obstacle.Kind.PLOW else 250
	_add_bonus(points)
	_hud.popup("Taklandning! +%d" % points, Hud.HOT, 60)
	_sound.play("horn", 0.0, 1.15)
	_sound.play("jump", 0.0, 0.8)
	_camera.add_shake(0.5)
	_atmosphere.flash(Hud.WARM, 0.25)
	_rumble(0.5, 0.4, 0.2)


func _near_miss(obstacle: Obstacle) -> void:
	var points := 100 if obstacle.is_vehicle() else 50
	_add_bonus(points)
	_hud.popup("%s +%d" % [NEAR_MISS_LINES[_rng.randi_range(0, NEAR_MISS_LINES.size() - 1)], points], Hud.COOL)
	_sound.play("whoosh", 0.0, _rng.randf_range(0.9, 1.2))
	if obstacle.is_vehicle():
		_sound.play("horn", -4.0)
	_sled.boost_time = maxf(_sled.boost_time, 0.5)
	_camera.add_shake(0.2)


## A collision, judged by physics: how fast you close on the obstacle,
## shared out by the two masses and softened by the ride's protection.
func _impact(obstacle: Obstacle, probe: Vector3) -> void:
	if _no_crash and not obstacle.soft and not obstacle.harmless:
		return
	if obstacle.in_branches(probe):
		_brush(obstacle)
		return
	var travel := _sled.travel_velocity()
	var heading := Vector3(travel.x, 0.0, travel.z)
	var normal := obstacle.push_normal(probe, -heading.normalized() if heading.length() > 0.1 else Vector3.BACK)
	var relative := travel - obstacle.velocity
	relative.y = 0.0
	var closing := maxf(-relative.dot(normal), 0.0)
	var rider := _sled.total_mass()
	var share := 1.0 if is_inf(obstacle.mass) else obstacle.mass / (obstacle.mass + rider)
	if obstacle.movable():
		var thrown := travel * 0.35 - normal * closing * rider / (obstacle.mass + rider) * 1.6
		obstacle.launch(thrown + Vector3.UP * (2.0 + closing * 0.25))
	if obstacle.harmless:
		_sound.play("poff", -6.0, 1.4)
		return
	if obstacle.soft:
		_soft_hit(obstacle)
		return
	var severity := closing * share / _sled.spec.protection
	var separation := Sled.RADIUS - obstacle.clearance(probe) + 0.05
	if severity >= CRASH_SEVERITY:
		_crash_into(obstacle)
	elif severity >= WIPEOUT_SEVERITY:
		_sled.knock(normal, closing * share * 1.2, separation, _rng.randf_range(1.0, 2.0) * (1.0 if _rng.randf() < 0.5 else -1.0))
		_sled.velocity *= 0.45
		_sled.bounce(2.0)
		_sound.play("oops", 0.0, 0.9)
		_sound.play("land", 2.0, 0.8)
		_camera.add_shake(0.7)
		_rumble(0.6, 0.7, 0.3)
		_hud.popup(WIPEOUT_LINES[_rng.randi_range(0, WIPEOUT_LINES.size() - 1)], Hud.WARM, 52)
	else:
		_sled.knock(normal, closing * share * 1.3, separation)
		_sled.velocity *= 0.92
		_sound.play("land", -2.0, 1.1)
		_camera.add_shake(clampf(severity * 0.1, 0.1, 0.4))
		_rumble(0.3, 0.2, 0.1)


## Spruce branches are soft: you ride straight through with a rustle
## against the jacket. Only the trunk is hard.
func _brush(obstacle: Obstacle) -> void:
	if obstacle.brushed:
		return
	obstacle.brushed = true
	_sound.play("rustle", -3.0, _rng.randf_range(0.9, 1.15))


func _soft_hit(obstacle: Obstacle) -> void:
	obstacle.react_to_hit(_sled.velocity)
	match obstacle.kind:
		Obstacle.Kind.SNOWMAN:
			Debris.burst(_world_root, _field, obstacle.position, _sled.velocity * 0.6, 14, 0.28)
			_sound.play("poff", 2.0)
			_sled.velocity *= 0.82
			_add_bonus(25)
			_hud.popup("Snögubbe-strike! +25", Hud.WARM)
			_camera.add_shake(0.5)
			_rumble(0.4, 0.2, 0.2)
		Obstacle.Kind.LOG:
			_sled.bounce(4.5)
			_sled.velocity *= 0.75
			_sound.play("land", 2.0, 0.8)
			_camera.add_shake(0.6)
			_rumble(0.5, 0.6, 0.2)
		_:
			_sound.play("oops")
			_hud.popup("Haren hoppade undan!", Hud.COOL)


func _crash_into(obstacle: Obstacle) -> void:
	match obstacle.kind:
		Obstacle.Kind.MOOSE:
			_sound.play("moose", 2.0)
		Obstacle.Kind.CAR, Obstacle.Kind.PLOW, Obstacle.Kind.TRUCK:
			_sound.play("horn")
		Obstacle.Kind.PERSON, Obstacle.Kind.KID:
			_sound.play("oops", 0.0, 1.3)
	var lines: Array = CRASH_LINES.get(obstacle.kind, ["Krasch!"])
	_crash(lines[_rng.randi_range(0, lines.size() - 1)])


func _crash(line: String) -> void:
	if _no_crash:
		return
	if _autopilot:
		print("crash at %d m: %s" % [int(_run_distance), line])
	_sled.crash()
	_lives -= 1
	_crash_timer = RESPAWN_DELAY
	_sound.play("crash")
	_camera.mode = ChaseCamera.Mode.CRASH
	_camera.add_shake(1.0)
	_atmosphere.flash(Color(1, 1, 1), 0.55)
	_rumble(0.8, 1.0, 0.45)
	_last_crash_line = line
	_hud.popup(line, Hud.HOT, 56, CRASH_LINE_HOLD)


func _after_crash() -> void:
	if _lives <= 0:
		_game_over()
		return
	var d := _sled.distance() + 4.0
	var water := _field.water_strip(d)
	if water != Vector2.ZERO:
		d = water.y + TerrainField.WATER_BLEND + 6.0
	if _field.near_road(d, 8.0):
		d = _field.nearest_road(d) + TerrainField.ROAD_HALF_WIDTH + 20.0
	_sled.place_at(d, 0.0, 12.0)
	_sled.invulnerable_time = 2.5
	_camera.mode = ChaseCamera.Mode.CHASE
	_camera.snap()


func _game_over() -> void:
	state = State.GAME_OVER
	_director.stop()
	var record := _run_distance > _save.best_distance
	if record:
		_save.best_distance = _run_distance
	_save.best_score = maxi(_save.best_score, _score())
	if not _autopilot:
		_save.store()
	_hud.show_game_over(GAME_OVER_LINES[_rng.randi_range(0, GAME_OVER_LINES.size() - 1)], _last_crash_line, _run_distance, _score(), _save.best_distance, record)
	_sound.set_music_ducked(true)
	_input_cooldown = 0.8


func _check_bounds() -> void:
	var d := _sled.distance()
	var outside := absf(_sled.position.x - _field.center_x(d)) - _field.half_width(d)
	var in_town := _field.region(d) == TerrainField.Region.TOWN
	var kind := _field.region(d)
	if kind == TerrainField.Region.MALL and outside > 2.0:
		_crash(["Rakt in i skyltfönstret!", "Du provade en tröja. Med ansiktet.", "Öppet köp gäller inte."][_rng.randi_range(0, 2)])
		return
	if kind == TerrainField.Region.BANDY and outside > 1.0:
		_crash(["In i sargen!", "Utvisning, tio minuter!"][_rng.randi_range(0, 1)])
		return
	var in_woods := _field.region(d) == TerrainField.Region.WOODS
	if in_woods and outside > 2.8:
		_crash(["In i granskogen!", "Barr överallt.", "Skogen tog dig."][_rng.randi_range(0, 2)])
	elif in_town and outside > 3.2:
		_crash(["Rakt in i skyltfönstret!", "Du handlade lite på vägen.", "Butiken har stängt. Nu."][_rng.randi_range(0, 2)])
	elif outside > 30.0:
		_crash("Vilse i villaområdet!")


func _check_pickups() -> void:
	var probe := _sled.position + Vector3.UP * 0.6
	for pickup in _world.pickups_near(_sled.distance()):
		if not pickup.touches(probe):
			continue
		pickup.collect()
		match pickup.kind:
			Pickup.Kind.GINGERBREAD:
				_cookie_streak += 1
				_cookie_timer = 1.5
				_add_bonus(10 * mini(_cookie_streak, 6))
				_sound.play("coin", -4.0, 1.0 + 0.06 * mini(_cookie_streak, 8))
			Pickup.Kind.COCOA:
				_lives = mini(_lives + 1, MAX_LIVES)
				_sound.play("cocoa")
			Pickup.Kind.WAX:
				_sled.boost_time = 2.5
				_sound.play("boost")
				_atmosphere.flash(Color(0.6, 0.85, 1.0), 0.35)
				_camera.add_shake(0.4)


func _on_skimmed(speed: float) -> void:
	if state != State.PLAYING:
		return
	_sound.play("splash", 0.0, _rng.randf_range(0.9, 1.15))
	Splash.spawn(_world_root, _sled.position, _sled.velocity, 0.8)
	_camera.add_shake(0.25)
	_rumble(0.2, 0.3, 0.1)
	_add_bonus(int(speed))


func _on_sank() -> void:
	if state != State.PLAYING or _sled.crashed:
		return
	_sound.play("splash", 4.0, 0.75)
	Splash.spawn(_world_root, _sled.position, Vector3.ZERO, 1.8)
	_crash(["Plask!", "Blöta byxor!", "Isvak!", "För lite fart, för mycket vatten."][_rng.randi_range(0, 3)])


func _on_jumped() -> void:
	_sound.play("jump", -4.0)


func _on_landed(air_time: float, impact: float, spin: float) -> void:
	if state != State.PLAYING or _sled.crashed:
		return
	if impact > 4.0:
		_sound.play("land", linear_to_db(clampf(impact / 14.0, 0.2, 1.0)))
		_camera.add_shake(clampf(impact * 0.04, 0.0, 0.8))
		_sled.puff()
		_rumble(0.3, clampf(impact / 20.0, 0.1, 0.8), 0.15)
	if _over_cliff:
		_over_cliff = false
		var points := CLIFF_BONUS + int(air_time * 40.0)
		_add_bonus(points)
		_hud.popup("Du överlevde stupet! +%d" % points, Hud.WARM, 60, 3.0)
		_sound.play("trick")
		_camera.add_shake(0.8)
		_sled.puff()
		_rumble(0.6, 0.9, 0.35)
		return
	var turns := roundi(absf(spin) / PI)
	if turns >= 2:
		var degrees := turns * 180
		_add_bonus(degrees)
		_hud.popup("%d°! +%d" % [degrees, degrees], Hud.HOT, 60)
		_sound.play("trick")
	elif air_time > 0.7:
		# Short hops still score, but only real flights get a call-out.
		var points := int(air_time * 40.0)
		_add_bonus(points)
		if air_time >= 2.0:
			_hud.popup("Luftfärd! %s s +%d" % [("%.1f" % air_time).replace(".", ","), points], Hud.WARM)


## Test runs (autopilot, --mute, headless) never shake a connected pad.
func _rumble(weak: float, strong: float, duration: float) -> void:
	if _autopilot or _muted or DisplayServer.get_name() == "headless":
		return
	for device in Input.get_connected_joypads():
		Input.start_joy_vibration(device, weak, strong, duration)


# --- Testing helpers ---

func _autopilot_steer() -> float:
	var d := _sled.distance()
	var look := d + 22.0
	var target_x := _field.center_x(look)
	if _reckless:
		return clampf(wrapf(atan2(target_x - _sled.position.x, look - d) - _sled.yaw, -PI, PI) * 3.0, -1.0, 1.0)
	for obstacle in _world.obstacles_near(d + 20.0):
		var od := -obstacle.position.z
		if od > d and od < d + 30.0 and absf(obstacle.position.x - target_x) < 3.5:
			target_x = obstacle.position.x + (4.5 if obstacle.position.x < target_x else -4.5)
	var desired := atan2(target_x - _sled.position.x, look - d)
	return clampf(wrapf(desired - _sled.yaw, -PI, PI) * 3.0, -1.0, 1.0)


## Testing aid: distance where the first region of the named kind begins.
func _find_region(name: String) -> float:
	var wanted := {
		"town": TerrainField.Region.TOWN, "river": TerrainField.Region.RIVER, "park": TerrainField.Region.PARK,
		"woods": TerrainField.Region.WOODS, "mall": TerrainField.Region.MALL, "rail": TerrainField.Region.RAIL,
		"airport": TerrainField.Region.AIRPORT, "highway": TerrainField.Region.HIGHWAY, "lake": TerrainField.Region.LAKE, "bandy": TerrainField.Region.BANDY, "cliff": TerrainField.Region.CLIFF,
	}.get(name, TerrainField.Region.TOWN) as TerrainField.Region
	var d := 0.0
	while d < 40000.0:
		if _field.region(d) == wanted:
			return d
		d += 25.0
	return START_D


func _maybe_screenshot() -> void:
	if _screenshot_path == "" or _elapsed < _screenshot_times[_screenshot_index]:
		return
	var path := _screenshot_path.replace(".png", "_%d.png" % _screenshot_index) if _screenshot_times.size() > 1 else _screenshot_path
	get_viewport().get_texture().get_image().save_png(path)
	print("Saved ", path, " distance=", int(_run_distance), " speed=", int(_sled.speed() * 3.6), " km/h fps=", Engine.get_frames_per_second(), " lives=", _lives, " state=", State.keys()[state])
	_screenshot_index += 1
	if _screenshot_index >= _screenshot_times.size():
		_screenshot_path = ""
		get_tree().quit()
