extends Node3D
## Game flow: players → live ride selection → camera turn → countdown → run.
## The preview and the run share a world. With two players, each picks their
## ride in split screen before racing; crashes then only cost time.

enum State { MENU, COUNTDOWN, PLAYING, PAUSED, GAME_OVER, LOBBY, SELECT }

const START_LIVES := 3
const MAX_LIVES := 5
const RESPAWN_DELAY := 2.8
## How long a crash line stays readable.
const CRASH_LINE_HOLD := 2.3
const START_D := 8.0
## Two-player races: metres from the start to the finish line.
const RACE_LENGTH := 3000.0
## Once the winner is home, how long the other has before the results.
const FINISH_GRACE := 20.0
## Slipstream: close behind the other rider you are pulled along.
const DRAFT_RANGE := 30.0
const DRAFT_WIDTH := 3.5
const DRAFT_PUSH := 3.0
## Grab tricks: shortest grab that counts (fully in the pose), points per
## second held, and the multiplier when a grab and a spin land together.
const GRAB_MIN := 0.25
const GRAB_POINTS := 250.0
const GRAB_COMBO := 1.5
## Spins count in half turns from a full turn up, when the ride gets within
## SPIN_MARGIN of one. A full turn is worth SPIN_POINTS and more turns grow
## faster than linearly (turns ^ SPIN_GROWTH), so four turns are worth
## about six single ones.
const SPIN_MARGIN := deg_to_rad(30.0)
const SPIN_POINTS := 360.0
const SPIN_GROWTH := 1.3
const GRAB_CRASH_LINES := ["Glömde sätta sig!", "Landade mitt i tricket.", "Glömde landa först.", "Stel som en pinne. Landade som en."]

const CRASH_LINES := {
	Obstacle.Kind.TREE: ["Granen vann.", "Trädkramare!", "Barr i munnen.", "Granen stod där först."],
	Obstacle.Kind.ROCK: ["Stenhårt!", "Stenen rörde sig inte en millimeter.", "Aj, aj, sten!"],
	Obstacle.Kind.STUMP: ["Stubben var där först.", "Stubbad!"],
	Obstacle.Kind.SEWER_DEBRIS: ["Stopp i avloppet!", "Du fastnade i gallret!"],
	Obstacle.Kind.ICE_PILLAR: ["Ispelaren stod stadigt.", "Iskallt möte!"],
	Obstacle.Kind.CONTAINER: ["Containern vann.", "Du blev fraktgods!"],
	Obstacle.Kind.CHIMNEY: ["Skorstenen vann.", "Sotare för en dag!", "Rakt in i skorstenen!"],
	Obstacle.Kind.PERSON: [
		"Ursäkta! Ursäkta!", "%s såg dig inte komma.", "%s tappade termosen!", "%s spillde ut hela kaffet.",
		"Förlåt, %s!", "%s ska ringa kommunen om det här.", "%s skakar på huvudet.", "%s hade precis borstat av sig.",
		"Strike på %s!", "%s skriver ett argt inlägg i Facebookgruppen.", "%s hör av sig till länsstyrelsen."],
	Obstacle.Kind.KID: [
		"Barnet skrattade. Du grät.", "%s vann den duellen.", "%s ska skvallra för fröken.", "%s vill åka en gång till!",
		"%s tappade vanten.", "%s står kvar. Du ligger ner."],
	Obstacle.Kind.DOG: ["Voff!", "Hunden trodde du var en pinne.", "Taxen tog ingen skada. Du däremot..."],
	Obstacle.Kind.FOX: ["Räven vann den här gången.", "Listig, men inte osynlig.", "Du tog fel väg till grytet."],
	Obstacle.Kind.CAT: ["Mjau!", "Katten hade företräde.", "Nio liv. Inget tålamod."],
	Obstacle.Kind.MOOSE: ["Älgen är okej. Det är inte du.", "Skogens konung vinner alltid.", "Du blev älgad."],
	Obstacle.Kind.DEER: ["Rådjuret blev mest förvånat.", "Bambi: 1, Du: 0"],
	Obstacle.Kind.BEAR: [
		"Du väckte björnen. Grattis.", "Björnen ville bara sova.", "Det var inte Nalle Puh.",
		"Skogens tyngsta kram.", "Björnen har inte gått i ide än. Nu vet du varför.", "Mästerbrumm vann."],
	Obstacle.Kind.CAR: ["Tuuut! Bilen hade företräde.", "Titta åt båda hållen nästa gång!", "Pulka mot bil. Bil vann."],
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
## Who you ran into: filled into the `%s` of a person's or child's crash line.
const PERSON_NAMES := [
	"Farbror Bengt", "Mormor", "Morfar", "Tant Gunnel", "Farmor Ingrid", "Gunnar från bastuklubben", "Kent-Åke",
	"Stig-Bruno", "Birgitta i kiosken", "Lasse från lagret", "Rektorn", "Pastor Lennart", "Kerstin med staven",
	"Sture", "Agneta", "Leif-Olle", "Grannen Ulla", "Ronny", "Lisbeth", "Börje", "Gröt-Robert", "Göran från styrelsen",
	"Tant Margit", "Kalle på macken", "Yvonne", "Benny", "Morbror Jan", "Gudrun", "Lars-Erik", "Pirjo", "Ahmed",
	"Jukka", "Svetlana", "Pappa", "Mamma", "Liftskötaren Roger", "Konditorn Sven", "Fiskaren Torbjörn",
]
const KID_NAMES := [
	"Lilla Elsa", "Lilla Alice", "Lille Nils", "Saga", "Wilma", "Elton", "Liam", "Maja", "Hugo", "Ebba",
	"Theo", "Selma", "Olle", "My", "Vincent", "Freja", "Melvin", "Tindra", "Noah", "Alva", "Kevin", "Isak",
]
const BIRCH_CRASH_LINES := ["Björken vann.", "Trädkramare!", "Näver i munnen.", "Björken stod där först.", "Björken rörde inte en kvist."]
const GAME_OVER_LINES := [
	"Pulkan har talat.", "Nu får du gå upp igen.", "Snö i nacken, snö i själen.",
	"Mamma ropar på middag!", "Vantarna är slut.", "Det var ändå ett bra åk.",
]

var state := State.MENU

var _save: SaveData
var _specs: Array[VehicleSpec] = []
var _vehicle := 0
var _rng := RandomNumberGenerator.new()
var _field: TerrainField
var _world_root: Node3D
var _world: SlopeWorld
var _atmosphere: Atmosphere
var _sound: SoundBank
var _hud: Hud

var _countdown := 0.0
var _countdown_step := 0
var _intro_remaining := 0.0
var _input_cooldown := 0.0
## Set when the ride goes over a cliff edge, until it lands.
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
## Clean menu presses from the gamepad sticks.
var _sticks: StickNavigator
var _start_vehicle := -1
## Testing aid: a kind of obstacle made common (Obstacle.Kind), or -1.
var _spawn_kind := -1
## Everyone riding: one player alone, two in a split-screen race.
## Seconds since the mouse last moved; while riding, a still mouse hides.
var _mouse_still := 0.0
var _players: Array[Player] = []
## Two-player mode is chosen on the menu; a race is on while it is set.
var _two_players := false
var _racing := false
var _race_length := RACE_LENGTH
var _race_time := 0.0
## Seconds left for the second rider once the first is home, or -1.
var _grace := -1.0
var _ready_flags: Array[bool] = [false, false]
var _split: CanvasLayer
var _finish_line: Node3D

## The first player's ride, camera and lives (tests reach in for these).
var _sled: Sled:
	get:
		return _players[0].sled
var _camera: ChaseCamera:
	get:
		return _players[0].camera
var _lives: int:
	get:
		return _players[0].lives
	set(value):
		_players[0].lives = value


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputSetup.configure()
	_sticks = StickNavigator.new()
	add_child(_sticks)
	_parse_args()
	var device_profile := OS.get_environment("PULKA_DEVICE_PROFILE") == "1"
	if device_profile:
		_autopilot = true
		_muted = true
		_no_crash = true
	# Silence automation before any looping audio players are constructed.
	if _muted: AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Master"), true)
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
	_world.forced_kind = _spawn_kind
	_world_root.add_child(_world)
	var camera := ChaseCamera.new()
	var first := _make_player(0, camera, PlayerControls.everything())
	_director = EventDirector.new()
	_director.sled = first.sled
	_director.sleds = [first.sled]
	_director.atmosphere = _atmosphere
	_director.sound = _sound
	_world_root.add_child(_director)
	_director.snowball_hit.connect(_on_snowball_hit)
	_director.gift_collected.connect(_on_gift_collected)
	camera.target = first.sled
	_world_root.add_child(camera)
	camera.current = true
	_hud = Hud.new()
	add_child(_hud)
	_hud.pressed.connect(_on_hud_pressed)
	first.hud = _hud
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
	var launch_duo := _two_players
	_enter_menu()
	if launch_duo:
		_two_players = true
		if not _autopilot: _enter_lobby()
	if _open_settings_at_start:
		_hud.open_settings(_save.master_volume, _save.music_volume, _save.effects_volume)
	if device_profile:
		var profiler: Node = load("res://scripts/debug/device_profile.gd").new()
		add_child(profiler)
		profiler.run.call_deferred(self)
	elif _autopilot:
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
		elif arg.begins_with("--spawn="):
			# Testing aid: makes a kind of obstacle common (--spawn=bear).
			var wanted := arg.get_slice("=", 1).to_upper()
			if Obstacle.Kind.has(wanted):
				_spawn_kind = Obstacle.Kind[wanted]
			else:
				push_warning("--spawn: no obstacle called '%s'; try one of %s." % [wanted.to_lower(), ", ".join(Obstacle.Kind.keys()).to_lower()])
		elif arg == "--players=2":
			_two_players = true
		elif arg.begins_with("--race-length="):
			_race_length = maxf(float(arg.get_slice("=", 1)), 50.0)


## Browsers require fullscreen requests to run inside the input event itself.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"fullscreen") and not event.is_echo():
		_toggle_fullscreen()
		get_viewport().set_input_as_handled()


func _toggle_fullscreen() -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_mouse_still = 0.0
	var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
	_remember_fullscreen()


## Stores the current window mode so the next launch starts the same way.
func _remember_fullscreen() -> void:
	if _autopilot or Quality.is_mobile():
		return
	_save.fullscreen = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	_save.store()


## Hides the mouse pointer during a ride once the mouse has been still for a
## moment; moving it brings it back (for the pause button), and menus always
## show it.
const CURSOR_HIDE_AFTER := 1.5


func _update_cursor(delta: float) -> void:
	_mouse_still += delta
	var riding := state == State.COUNTDOWN or state == State.PLAYING
	var hide := riding and _mouse_still > CURSOR_HIDE_AFTER and not _hud.settings_open
	var mode := Input.MOUSE_MODE_HIDDEN if hide else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != mode:
		Input.mouse_mode = mode


## Desktop only: browsers refuse fullscreen without a click, phones always are.
func _restore_fullscreen() -> void:
	if _save.fullscreen and not _autopilot and _screenshot_path == "" and not OS.has_feature("web") and not Quality.is_mobile():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _process(delta: float) -> void:
	var started := Time.get_ticks_usec()
	_elapsed += delta
	_input_cooldown = maxf(0.0, _input_cooldown - delta)
	for p in _players:
		p.controls.poll()
	_update_settings_input()
	_update_go_back()
	match state:
		State.MENU:
			_update_menu(delta)
		State.LOBBY:
			_update_lobby(delta)
		State.SELECT:
			_update_selection(delta)
		State.COUNTDOWN:
			_update_countdown(delta)
		State.PLAYING:
			_update_playing(delta)
		State.PAUSED:
			_update_paused()
		State.GAME_OVER:
			_update_game_over(delta)
	if state != State.PAUSED:
		var lead := _leader()
		var playing := state == State.PLAYING and not lead.sled.crashed
		_director.sled = lead.sled
	_update_cursor(delta)
		_director.update(delta, playing)
		_update_atmospheres(delta)
		_sound.set_motion(delta, lead.sled.speed(), lead.sled.on_ground, state == State.PLAYING and not lead.sled.crashed)
	FpsMeter.record_logic(Time.get_ticks_usec() - started)
	_maybe_screenshot()


func _update_atmospheres(delta: float) -> void:
	for p in _players:
		var atmosphere := p.atmosphere
		if atmosphere != _atmosphere: atmosphere.copy_weather(_atmosphere)
		var d := p.sled.distance()
		atmosphere.indoor = _world.regions.indoors(d)
		atmosphere.cave = _field.cave_weight(d)
		atmosphere.sewer = _field.sewer_weight(d)
		p.camera.update_camera(delta)
		var playing := state == State.PLAYING and not p.sled.crashed
		var rush := p.sled.speed() / 45.0 if playing and not _racing else 0.0
		atmosphere.update_atmosphere(delta, p.camera, d, rush, p.sled.boost_time > 0.0 and not _racing)
		p.boundary_net.update_net(_field, p.sled, delta, state == State.PLAYING)


## The rider out in front: the one events and shared game audio follow.
func _leader() -> Player:
	var lead := _players[0]
	for p in _players:
		if p.sled.distance() > lead.sled.distance():
			lead = p
	return lead


func _player_of(sled: Sled) -> Player:
	for p in _players:
		if p.sled == sled:
			return p
	return _players[0]


## A rider with their sled in the world. The camera is placed by the caller.
func _make_player(index: int, camera: ChaseCamera, controls: PlayerControls) -> Player:
	var sled := Sled.new()
	sled.speed_multiplier = _speed_multiplier
	_world_root.add_child(sled)
	var p := Player.new(index, sled, camera, controls)
	p.atmosphere = _atmosphere
	if index > 0:
		p.atmosphere = Atmosphere.new()
		p.atmosphere.view_index = index
		_world_root.add_child(p.atmosphere)
	p.atmosphere.bind_camera(camera)
	p.boundary_net = BoundaryNet.new()
	p.boundary_net.view_layer = p.atmosphere.view_layer()
	p.atmosphere.add_child(p.boundary_net)
	p.rumbles = not (_autopilot or _muted or DisplayServer.get_name() == "headless")
	p.vehicle = _vehicle
	sled.jumped.connect(_on_jumped.bind(p))
	sled.landed.connect(_on_landed.bind(p))
	sled.tricked.connect(_on_tricked.bind(p))
	sled.skimmed.connect(_on_skimmed.bind(p))
	sled.sank.connect(_on_sank.bind(p))
	camera.target = sled
	if _field:
		sled.field = _field
		camera.field = _field
	_players.append(p)
	return p


# --- States ---

func _new_world() -> void:
	_field = TerrainField.new(_rng.randi())
	_world.reset(_field, START_D)
	for p in _players:
		p.sled.field = _field
		p.camera.field = _field
	_director.field = _field


func _enter_menu() -> void:
	get_tree().paused = false
	_hud.close_settings()
	_leave_split()
	_two_players = false
	state = State.MENU
	_prepare_preview_world()
	var p := _players[0]
	p.sled.set_vehicle(_specs[_vehicle], _rng, Player.COLORS[0])
	p.sled.frozen = true
	p.sled.place_at(_start_d)
	p.camera.mode = ChaseCamera.Mode.ORBIT
	p.camera.centered = false
	p.camera.update_camera(0.0)
	_hud.show_screen("players")
	_refresh_menu()
	_sound.set_music_ducked(false)
	_sound.set_menu_music(true)
	_input_cooldown = 0.3


func _prepare_preview_world() -> void:
	_new_world()
	_start_d = START_D
	if _start_region != "":
		_start_d = _find_region(_start_region) - 120.0
		_world.reset(_field, _start_d)
	_director.reset(_start_d)
	_director.stop()


func _choose_solo() -> void:
	_two_players = false
	state = State.SELECT
	_hud.show_screen("menu")
	_refresh_menu()
	_sound.play("whoosh", -6.0, 1.2)
	_input_cooldown = 0.2


func _refresh_menu() -> void:
	var spec := _specs[_vehicle]
	_hud.update_menu(spec, _is_unlocked(spec), _save.best_distance, _save.best_score, _save.unlocked_distance)


func _is_unlocked(spec: VehicleSpec) -> bool:
	return maxf(_save.best_distance, _save.unlocked_distance) >= spec.unlock_distance


func _update_menu(delta: float) -> void:
	_update_world(delta)
	_players[0].sled.step(delta, 0.0, false)
	if _input_cooldown > 0.0 or _hud.settings_open:
		return
	if _confirm_pressed():
		_choose_solo()


func _update_selection(delta: float) -> void:
	_update_world(delta)
	_players[0].sled.step(delta, 0.0, false)
	if _input_cooldown > 0.0 or _hud.settings_open:
		return
	if Input.is_action_just_pressed(&"back") or Input.is_action_just_pressed(&"pause"):
		_enter_menu()
		return
	if Input.is_action_just_pressed(&"menu_left"):
		_change_vehicle(-1)
	elif Input.is_action_just_pressed(&"menu_right"):
		_change_vehicle(1)
	if _confirm_pressed():
		_start_run()


func _change_vehicle(step: int) -> void:
	var p := _players[0]
	_vehicle = (_vehicle + step + _specs.size()) % _specs.size()
	p.vehicle = _vehicle
	p.sled.set_vehicle(_specs[_vehicle], _rng, Player.COLORS[0])
	p.sled.place_at(_start_d)
	_refresh_menu()
	_sound.play("whoosh", -6.0, 1.4)


func _start_run() -> void:
	if _two_players:
		_start_race()
		return
	get_tree().paused = false
	var spec := _specs[_vehicle]
	if not _is_unlocked(spec):
		_sound.play("oops")
		return
	_save.vehicle_id = spec.id
	if not _autopilot:
		_save.store()
	# Starting from the picker keeps the exact world, rider and camera.
	# Retry and automation prepare a fresh starting point before the intro.
	var p := _players[0]
	if state != State.SELECT:
		_prepare_preview_world()
		p.sled.set_vehicle(spec, _rng, Player.COLORS[0])
		p.sled.place_at(_start_d)
		p.camera.reset_preview()
	p.sled.frozen = true
	p.sled.invulnerable_time = 0.0
	_reset_player(p)
	_director.reset(_start_d)
	_force_event()
	_touch.reset()
	_begin_countdown()


func _begin_countdown() -> void:
	for p in _players:
		p.camera.begin_run()
	_countdown = 3.0 * CountdownDisplay.BEAT_SECONDS
	_countdown_step = 0
	_intro_remaining = ChaseCamera.START_SECONDS
	state = State.COUNTDOWN
	_hud.show_screen("countdown")
	_sound.set_music_ducked(false)
	# Fade the menu arrangement while the camera turns. The riding track
	# arrives before the countdown ends, with no abrupt audio cut.
	_sound.set_menu_music(false)


func _reset_player(p: Player) -> void:
	p.over_cliff = false
	p.lives = START_LIVES
	p.bonus = 0
	p.bonus_fraction = 0.0
	p.run_distance = 0.0
	p.cookie_streak = 0
	p.cookie_timer = 0.0
	p.crash_timer = 0.0
	p.finish_time = -1.0
	p.sled.draft = 0.0
	p.sled.brake = 0.0
	p.camera.centered = false


func _force_event() -> void:
	if _start_event != "":
		var kinds := {"blizzard": EventDirector.Kind.BLIZZARD, "snowballs": EventDirector.Kind.SNOWBALLS, "santa": EventDirector.Kind.SANTA, "aurora": EventDirector.Kind.AURORA}
		_director.force_next(kinds.get(_start_event, EventDirector.Kind.BLIZZARD), _start_d)


func _update_countdown(delta: float) -> void:
	_update_world(delta)
	for p in _players:
		p.sled.step(delta, 0.0, false)
	var remaining := delta
	if _intro_remaining > 0.0:
		var used := minf(remaining, _intro_remaining)
		_intro_remaining -= used
		remaining -= used
		if _intro_remaining > 0.0:
			return
	if _countdown_step == 0:
		_countdown_step = 3
		_show_center("3")
		_sound.play("beep")
	_countdown = maxf(0.0, _countdown - remaining)
	var step := ceili(_countdown / CountdownDisplay.BEAT_SECONDS)
	if step != _countdown_step and step > 0:
		_countdown_step = step
		_show_center(str(step))
		_sound.play("beep")
	if _countdown <= 0.0:
		state = State.PLAYING
		for p in _players:
			p.sled.frozen = false
			p.sled.velocity = _field.track_dir(_start_d) * 9.0
			if _racing: p.race_hud.show_race()
		_hud.show_screen("race" if _racing else "game")
		_show_center("ÅK!", MenuFlow.LIME)
		_sound.play("go")
	_update_hud()


## Big text in the middle of every player's screen.
func _show_center(text: String, color := Color.WHITE) -> void:
	if _racing:
		for p in _players:
			p.race_hud.show_center(text, color)
	else:
		_hud.show_center(text, color)


func _update_playing(delta: float) -> void:
	if Input.is_action_just_pressed(&"pause"):
		_set_paused(true)
		return
	if _racing:
		_race_time += delta
		_update_drafts()
	var before: Array[float] = []
	for p in _players:
		before.append(p.sled.distance())
		var steer := p.controls.steer()
		var jump := p.controls.jump()
		var grab := p.controls.jump_held()
		if p.finished():
			_coast_home(p, delta)
			continue
		if not _racing:
			steer = clampf(steer + _touch.steer, -1.0, 1.0)
			jump = jump or _touch.consume_jump()
		if _autopilot:
			steer = _autopilot_steer(p)
			var roof := _field.roof_at(p.sled.position.x, p.sled.distance())
			jump = roof != null and roof.requires_jump and roof.finish - p.sled.distance() < 1.25 and p.sled.on_ground
			grab = false
		p.sled.step(delta, steer, jump, grab)
	_update_world(delta)
	for i in _players.size():
		_update_player(_players[i], before[i], delta)
	if _racing:
		_bump_riders()
		_update_race(delta)
	else:
		_update_hud()


## Tracks stay this far behind the rearmost rider, then go.
const TRAIL_BEHIND := 120.0


func _update_world(delta: float, build_ms := SlopeWorld.BUILD_MS) -> void:
	var lead := _leader()
	var others := PackedFloat32Array()
	_world.bird_observers.clear()
	_world.bird_speeds.clear()
	var last := lead.sled.distance()
	for p in _players:
		_world.bird_observers.append(p.sled.position)
		_world.bird_speeds.append(p.sled.speed())
		if p != lead:
			others.append(p.sled.distance())
		last = minf(last, p.sled.distance())
	_world.update_world(lead.sled.distance(), delta, build_ms, others)
	for p in _players:
		p.sled.prune_trail(last - TRAIL_BEHIND)


func _update_player(p: Player, before: float, delta: float) -> void:
	if p.finished():
		return
	_check_cliff(p, before)
	p.cookie_timer = maxf(0.0, p.cookie_timer - delta)
	if p.cookie_timer == 0.0:
		p.cookie_streak = 0
	if p.sled.crashed:
		p.crash_timer -= delta
		if p.crash_timer <= 0.0:
			_after_crash(p)
	else:
		var travelled := maxf(p.sled.distance() - _start_d, p.run_distance)
		_add_distance_bonus(p, travelled - p.run_distance)
		p.run_distance = travelled
		_check_collisions(p)
		_check_pickups(p)
		_check_bounds(p)


## Going over a cliff edge: a scream, and a reward if you land it.
func _check_cliff(p: Player, before: float) -> void:
	var edge := _field.cliff_edge(before)
	if p.sled.crashed or before >= edge or p.sled.distance() < edge:
		return
	p.over_cliff = true
	p.say("AAAAAAAH!", Hud.HOT, 84, 1.7)
	_sound.play("whoosh", 0.0, 0.7)
	p.camera.add_shake(0.25)


func _update_hud() -> void:
	if _racing:
		_update_race_hud()
		return
	var p := _players[0]
	_hud.update_game(p.run_distance, p.score(), p.sled.speed(), p.lives, maxi(START_LIVES, p.lives), _director.multiplier)


# --- Two-player race ---

## Where each rider stands across the slope at the start.
func _lane(p: Player) -> float:
	return -2.2 if p.index == 0 else 2.2


## Before a race: both riders stand side by side, each on their own half of
## the screen, picking a ride and saying when they are ready.
func _enter_lobby() -> void:
	get_tree().paused = false
	_build_split()
	_director.reset(_start_d)
	_director.stop()
	state = State.LOBBY
	_ready_flags = [false, false]
	for p in _players:
		p.sled.set_vehicle(_specs[p.vehicle], _rng, Player.COLORS[p.index])
		p.sled.frozen = true
		p.sled.place_at(_start_d, _lane(p))
		p.camera.mode = ChaseCamera.Mode.ORBIT
		p.camera.centered = true
		p.camera.update_camera(0.0)
		p.race_hud.clear()
		_show_lobby(p)
	_hud.show_screen("lobby")
	# Prepare the finish while choosing rides, so Ready has no mesh-building
	# work to interrupt the camera's first frame.
	_place_finish_line()
	_input_cooldown = 0.4


func _update_lobby(delta: float) -> void:
	_update_world(delta)
	for p in _players:
		p.sled.step(delta, 0.0, false)
	if _input_cooldown > 0.0 or _hud.settings_open:
		return
	if Input.is_action_just_pressed(&"back") or Input.is_action_just_pressed(&"pause"):
		_back_to_solo()
		return
	for p in _players:
		var step := p.controls.menu_step(_sticks)
		if step != 0 and not _ready_flags[p.index]:
			_pick(p, step)
		if p.controls.jump():
			_ready_flags[p.index] = not _ready_flags[p.index]
			_sound.play("beep" if _ready_flags[p.index] else "whoosh", -4.0, 1.3)
			_show_lobby(p)
	if not _ready_flags.has(false):
		_start_race()


func _on_lobby_action(action: StringName, p: Player) -> void:
	if state != State.LOBBY or _hud.settings_open or _input_cooldown > 0.0:
		return
	if action == &"ready":
		_ready_flags[p.index] = not _ready_flags[p.index]
		_sound.play("beep", -4.0, 1.3)
		_show_lobby(p)
	elif not _ready_flags[p.index]:
		_pick(p, -1 if action == &"previous" else 1)


## From the split-screen menu back to the menu for one.
func _back_to_solo() -> void:
	_two_players = false
	_sound.play("whoosh", -6.0, 0.9)
	_enter_menu()


## The next (or previous) ride this player has unlocked.
func _pick(p: Player, step: int) -> void:
	p.vehicle = _next_unlocked(p.vehicle, step)
	p.sled.set_vehicle(_specs[p.vehicle], _rng, Player.COLORS[p.index])
	p.sled.place_at(_start_d, _lane(p))
	_show_lobby(p)
	_sound.play("whoosh", -6.0, 1.4)


func _next_unlocked(from: int, step: int) -> int:
	var index := from
	for i in _specs.size():
		index = (index + step + _specs.size()) % _specs.size()
		if _is_unlocked(_specs[index]):
			return index
	return from


func _show_lobby(p: Player) -> void:
	p.race_hud.show_lobby(_specs[p.vehicle], p.controls.describe(), _ready_flags[p.index])


## Splits the screen in two, left for the first player and right for the
## second, each with their own camera on the same world and their own HUD.
func _build_split() -> void:
	if _split != null:
		return
	if _players.size() < 2:
		var second := _make_player(1, ChaseCamera.new(), PlayerControls.for_two(1))
		second.vehicle = _next_unlocked(_vehicle, 1)
		second.hud = _hud
	_players[0].controls = PlayerControls.for_two(0)
	_split = CanvasLayer.new()
	_split.layer = 0
	var backing := ColorRect.new()
	backing.color = Color(0.02, 0.02, 0.05)
	backing.set_anchors_preset(Control.PRESET_FULL_RECT)
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_split.add_child(backing)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_split.add_child(row)
	var world := get_viewport().find_world_3d()
	for p in _players:
		var half := Control.new()
		half.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		half.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var container := SubViewportContainer.new()
		container.stretch = true
		container.set_anchors_preset(Control.PRESET_FULL_RECT)
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var view := SubViewport.new()
		view.world_3d = world
		view.audio_listener_enable_3d = p.index == 0
		view.scaling_3d_mode = Quality.scaling_mode()
		view.scaling_3d_scale = Quality.render_scale()
		view.msaa_3d = get_viewport().msaa_3d
		view.screen_space_aa = get_viewport().screen_space_aa
		container.add_child(view)
		half.add_child(container)
		if p.camera.get_parent() != null:
			p.camera.get_parent().remove_child(p.camera)
		view.add_child(p.camera)
		p.camera.current = true
		p.race_hud = RaceHud.new().setup(p.index, Player.COLORS[p.index])
		p.race_hud.lobby_action.connect(_on_lobby_action.bind(p))
		half.add_child(p.race_hud)
		row.add_child(half)
	add_child(_split)
	_racing = true
	_hud.racing = true
	var sleds: Array[Sled] = []
	for p in _players:
		sleds.append(p.sled)
	_director.sleds = sleds
	for p in _players:
		p.atmosphere.apply_quality(true)


## Back to one player on the whole screen.
func _leave_split() -> void:
	if _finish_line != null:
		_finish_line.queue_free()
		_finish_line = null
	if _split == null:
		return
	var first := _players[0]
	first.camera.get_parent().remove_child(first.camera)
	_world_root.add_child(first.camera)
	first.camera.current = true
	first.controls = PlayerControls.everything()
	first.race_hud = null
	while _players.size() > 1:
		var other: Player = _players.pop_back()
		other.sled.queue_free()
		other.camera.queue_free()
		other.atmosphere.queue_free()
	_split.queue_free()
	_split = null
	_racing = false
	_hud.racing = false
	_director.sleds = [first.sled]
	first.atmosphere.apply_quality(false)


func _start_race() -> void:
	get_tree().paused = false
	_build_split()
	var reuse_preview := state == State.LOBBY
	if not reuse_preview:
		_prepare_preview_world()
	for p in _players:
		if not reuse_preview:
			p.sled.set_vehicle(_specs[p.vehicle], _rng, Player.COLORS[p.index])
			p.sled.place_at(_start_d, _lane(p))
			p.camera.reset_preview(true)
		p.sled.frozen = true
		p.sled.invulnerable_time = 0.0
		_reset_player(p)
		p.race_hud.clear()
		p.race_hud.hide_lobby()
	_director.reset(_start_d)
	_force_event()
	_race_time = 0.0
	_grace = -1.0
	if not reuse_preview or _finish_line == null:
		_place_finish_line()
	_begin_countdown()


## An inflatable arch across the track at the finish.
func _place_finish_line() -> void:
	if _finish_line != null:
		_finish_line.queue_free()
	var goal := _start_d + _race_length
	var x := _field.center_x(goal)
	var dir := _field.track_dir(goal)
	var width := int(_field.half_width(goal) * 2.0 + 3.0)
	_finish_line = Node3D.new()
	_finish_line.position = Vector3(x, _field.height(x, goal), -goal)
	_finish_line.rotation.y = atan2(-dir.x, -dir.z)
	var arch := MeshInstance3D.new()
	arch.mesh = Props.finish_arch(width)
	_finish_line.add_child(arch)
	for face in [0.0, PI]:
		var label := Shops.label("MÅL", 160, 0.012, Color(1, 1, 1))
		label.outline_size = 24
		label.outline_modulate = Color(0.1, 0.1, 0.15)
		label.transform = Transform3D(Basis(Vector3.UP, face), Vector3(0, 5.9, 0.45 if face == 0.0 else -0.45))
		_finish_line.add_child(label)
	_world_root.add_child(_finish_line)


## Close behind the other rider and in line with them, you are pulled along
## in their slipstream.
func _update_drafts() -> void:
	for p in _players:
		var pull := 0.0
		for other in _players:
			if other == p or other.sled.crashed or p.sled.crashed or not p.sled.on_ground or p.finished():
				continue
			var gap := other.sled.distance() - p.sled.distance()
			if gap > 1.5 and gap < DRAFT_RANGE and absf(other.sled.position.x - p.sled.position.x) < DRAFT_WIDTH:
				pull = DRAFT_PUSH * (1.0 - 0.5 * gap / DRAFT_RANGE)
		if pull > 0.0 and p.sled.draft == 0.0 and _race_time - p.draft_said > 6.0:
			p.draft_said = _race_time
			p.say("Bakvind!", Hud.COOL, 36, 0.8)
		p.sled.draft = pull


func _update_race(delta: float) -> void:
	var goal := _start_d + _race_length
	for p in _players:
		if p.finished() or p.sled.distance() < goal:
			continue
		p.finish_time = _race_time
		var first := _finished_count() == 1
		p.race_hud.show_center("VINST!" if first else "I mål!", Hud.HOT if first else Hud.WARM, 1.6)
		p.flash(Hud.WARM, 0.5)
		p.rumble(0.5, 0.6, 0.3)
		_sound.play("trick" if first else "go")
		if first:
			_grace = FINISH_GRACE
			for other in _players:
				if other != p:
					other.say("Spelare %d är i mål! %d s kvar" % [p.index + 1, int(FINISH_GRACE)], Hud.HOT, 44, 2.5)
	if _grace > 0.0:
		_grace -= delta
	_update_race_hud()
	if _finished_count() == _players.size() or (_grace <= 0.0 and _grace > -1.0):
		_end_race()


## Past the finish the race is run: the rider steers for their own side of
## the track (out of the way of the other) and brakes to a stop, and the
## camera swings round to them.
func _coast_home(p: Player, delta: float) -> void:
	if p.sled.crashed:
		return
	p.sled.brake = 16.0
	p.sled.draft = 0.0
	var d := p.sled.distance()
	var look := d + 12.0
	var side := _field.center_x(look) + _lane(p) * 1.5
	var steer := clampf(wrapf(atan2(side - p.sled.position.x, look - d) - p.sled.yaw, -PI, PI) * 2.5, -1.0, 1.0)
	p.sled.step(delta, steer, false)
	if p.sled.speed() < 3.0 and p.camera.mode != ChaseCamera.Mode.ORBIT:
		p.camera.centered = true
		p.camera.mode = ChaseCamera.Mode.ORBIT


## Riders who meet bounce off each other: a shove, not a crash.
func _bump_riders() -> void:
	var a := _players[0]
	var b := _players[1]
	if a.sled.crashed or b.sled.crashed:
		return
	var apart := a.sled.position - b.sled.position
	var flat := Vector3(apart.x, 0.0, apart.z)
	var reach := Sled.RADIUS * 2.0
	if flat.length() >= reach or absf(apart.y) > 1.0:
		return
	var normal := flat.normalized() if flat.length() > 0.01 else Vector3.RIGHT
	var closing := maxf((b.sled.velocity - a.sled.velocity).dot(normal), 0.0)
	var push := 1.5 + closing * 0.6
	var separation := (reach - flat.length()) * 0.5 + 0.02
	a.sled.knock(normal, push, separation)
	b.sled.knock(-normal, push, separation)
	if closing > 1.0:
		_sound.play("land", -2.0, 1.2)
		for p in [a, b]:
			p.camera.add_shake(0.25)
			p.rumble(0.3, 0.3, 0.12)


func _finished_count() -> int:
	var count := 0
	for p in _players:
		if p.finished():
			count += 1
	return count


## 1 for the rider in front: home first, or further down the hill.
func _place_of(p: Player) -> int:
	var place := 1
	for other in _players:
		if other == p:
			continue
		if other.finished():
			if not p.finished() or other.finish_time < p.finish_time:
				place += 1
		elif not p.finished() and other.sled.distance() > p.sled.distance():
			place += 1
	return place


func _update_race_hud() -> void:
	var goal := _start_d + _race_length
	for p in _players:
		p.race_hud.update_race(goal - p.sled.distance(), p.sled.speed(), _place_of(p), p.finished())


func _end_race() -> void:
	state = State.GAME_OVER
	_director.stop()
	var order := _players.duplicate()
	order.sort_custom(func(a: Player, b: Player) -> bool: return _place_of(a) < _place_of(b))
	var winner: Player = order[0]
	var goal := _start_d + _race_length
	var rows := []
	for p: Player in order:
		var result := _race_clock(p.finish_time) if p.finished() else "%s m kvar" % Hud.group_digits(int(goal - p.sled.distance()))
		rows.append(["%d. Spelare %d" % [_place_of(p), p.index + 1], result, Player.COLORS[p.index]])
	_hud.show_race_result("Spelare %d vinner!" % (winner.index + 1), rows)
	_sound.set_music_ducked(true)
	_input_cooldown = Hud.OVER_GUARD


## A race time as minutes, seconds and tenths: 1:23,4.
static func _race_clock(seconds: float) -> String:
	var tenths := int(roundf(seconds * 10.0))
	return "%d:%02d,%d" % [tenths / 600, (tenths / 10) % 60, tenths % 10]


func _add_bonus(p: Player, points: int) -> void:
	p.bonus += roundi(points * _director.multiplier)


## Distance counts extra while a score multiplier is active.
func _add_distance_bonus(p: Player, metres: float) -> void:
	p.bonus_fraction += metres * (_director.multiplier - 1.0)
	var whole := floori(p.bonus_fraction)
	p.bonus += whole
	p.bonus_fraction -= whole


func _on_snowball_hit(sled: Sled) -> void:
	var p := _player_of(sled)
	p.splat()
	_sound.play("splat", 2.0, _rng.randf_range(0.9, 1.3))
	p.sled.velocity *= 0.92
	p.camera.add_shake(0.35)
	p.rumble(0.3, 0.3, 0.15)


## What is in one of Santa's parcels: usually something useful, now and
## then a bag of points, once in a while a lump of coal.
func _on_gift_collected(sled: Sled) -> void:
	var p := _player_of(sled)
	var roll := _rng.randf()
	if roll < 0.25 and p.lives < MAX_LIVES and not _racing:
		p.lives += 1
		p.say("Ett par vantar! Extraliv!", Hud.HOT)
		_sound.play("cocoa")
	elif roll < 0.5:
		p.sled.boost_time = maxf(p.sled.boost_time, 2.5)
		p.say("Turbovalla!", Hud.COOL)
		_sound.play("boost")
		p.flash(Color(0.6, 0.85, 1.0), 0.35)
		p.camera.add_shake(0.4)
	elif roll < 0.68:
		p.sled.invulnerable_time = maxf(p.sled.invulnerable_time, 5.0)
		p.say("Tomtens skydd! Inget kan stoppa dig.", Hud.COOL)
		_sound.play("cocoa", -2.0, 1.25)
	elif roll < 0.92:
		_add_bonus(p, 250)
		p.say("En burk pepparkakor! +250", Hud.WARM)
		_sound.play("coin", -2.0, 1.2)
	else:
		_add_bonus(p, 1)
		p.say(["Kol. Du har varit stygg i år.", "Ett par raggsockor. +1", "Ett mjukt paket. +1"][_rng.randi_range(0, 2)], Hud.WARM)
		_sound.play("cocoa", -6.0, 0.7)


func _set_paused(paused: bool) -> void:
	get_tree().paused = paused
	state = State.PAUSED if paused else State.PLAYING
	_hud.show_screen("pause" if paused else ("race" if _racing else "game"))
	_sound.set_music_ducked(paused)


func _update_paused() -> void:
	if _input_cooldown > 0.0 or _hud.settings_open:
		return
	if Input.is_action_just_pressed(&"pause") or Input.is_action_just_pressed(&"back") or _confirm_pressed():
		_set_paused(false)


func _update_game_over(delta: float) -> void:
	_update_world(delta)
	for p in _players:
		if _racing:
			_coast_home(p, delta)
		else:
			p.sled.step(delta, 0.0, false)
	if _racing:
		_update_race_hud()
	if _input_cooldown > 0.0:
		return
	if _confirm_pressed():
		_start_run()
	if paused:
		_hud.set_song(_sound.song_title())
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
	if String(action).begins_with("vehicle_") and state == State.SELECT:
		var index := String(action).trim_prefix("vehicle_").to_int()
		if index >= 0 and index < _specs.size():
			_change_vehicle(index - _vehicle)
		return
	match action:
		&"fullscreen":
			_toggle_fullscreen()
		&"show_fps":
			_save.show_fps = not _save.show_fps
			_hud.set_fps_visible(_save.show_fps)
		&"start":
			if state == State.SELECT:
				_start_run()
		&"duo":
			if state == State.MENU and not Quality.is_mobile():
				_two_players = true
				_sound.play("whoosh", -6.0, 1.2)
				_enter_lobby()
		&"solo":
			if state == State.MENU:
				_choose_solo()
		&"players":
			if state == State.SELECT or state == State.LOBBY:
				_enter_menu()
		&"previous", &"next":
			if state == State.SELECT:
				_change_vehicle(-1 if action == &"previous" else 1)
		&"settings":
			if state in [State.MENU, State.SELECT, State.PAUSED, State.LOBBY]:
				_hud.open_settings(_save.master_volume, _save.music_volume, _save.effects_volume)
		&"close_settings":
			_close_settings()
		&"ask_reset_records":
			if _hud.settings_open: _hud.ask_record_reset()
		&"cancel_reset_records":
			if _hud.settings_open: _hud.cancel_record_reset()
		&"reset_records":
			if _hud.settings_open and _hud.reset_pending:
				_save.reset_records()
				_save.store()
				_refresh_menu()
				_hud.records_cleared()
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
	for p in _players:
		p.atmosphere.apply_quality(_players.size() > 1)
		var half := p.camera.get_viewport()
		if half != viewport:
			half.scaling_3d_mode = Quality.scaling_mode()
			half.scaling_3d_scale = Quality.render_scale()


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
			if _hud.reset_pending:
				_hud.cancel_record_reset()
				_input_cooldown = 0.2
			else:
				_close_settings()
	elif (state in [State.MENU, State.SELECT, State.PAUSED, State.LOBBY]) and _input_cooldown <= 0.0 and Input.is_action_just_pressed(&"settings"):
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


func _check_collisions(p: Player = null) -> void:
	if p == null:
		p = _players[0]
	var up := p.sled.sewer_up() if p.sled.sewer_active else Vector3.UP
	var probe := p.sled.position + up * 0.3
	var d := p.sled.distance()
	for obstacle in _world.obstacles_near(d):
		if not obstacle.visible or obstacle.hit:
			continue
		if obstacle.is_vehicle() and _on_roof(p, obstacle, probe):
			_roof_bounce(p, obstacle)
			continue
		if obstacle.landable and _on_top(p, obstacle, probe):
			_top_hop(p, obstacle)
			continue
		var contact := _contact(obstacle, probe, up)
		if p.sled.invulnerable_time <= 0.0 and contact != Vector3.INF:
			_impact(p, obstacle, contact)
			if p.sled.crashed:
				return
			continue
		if obstacle.near_miss_done:
			continue
		if obstacle.clearance(probe) < 1.7 and probe.y < obstacle.position.y + obstacle.height() + 0.8:
			obstacle.close_call = true
		if obstacle.close_call and -obstacle.position.z < d - 1.5:
			obstacle.near_miss_done = true
			_near_miss(p, obstacle)


## Where the ride touches `obstacle`, or INF. Spruces are also checked at
## the rider's chest, which brushes the low branches the sled slips under.
func _contact(obstacle: Obstacle, probe: Vector3, up := Vector3.UP) -> Vector3:
	if obstacle.overlaps(probe, Sled.RADIUS):
		return probe
	var chest := probe + up * RIDER_CHEST
	if obstacle.kind in [Obstacle.Kind.TREE, Obstacle.Kind.CONTAINER] and obstacle.overlaps(chest, Sled.RADIUS * 0.6):
		return chest
	return Vector3.INF


## Coming down from above onto a car is a trampoline, not a crash.
func _on_roof(p: Player, obstacle: Obstacle, probe: Vector3) -> bool:
	var roof := obstacle.position.y + obstacle.top
	return p.sled.velocity.y < 1.0 and probe.y > roof - 0.9 and probe.y < roof + 0.8 and obstacle.clearance(probe) < Sled.RADIUS


## Coming down from the air onto the top of something (a head, a rock).
func _on_top(p: Player, obstacle: Obstacle, probe: Vector3) -> bool:
	var top := obstacle.position.y + obstacle.height()
	return not p.sled.on_ground and p.sled.velocity.y < 1.0 and probe.y > top - obstacle.height() * 0.45 and probe.y < top + 0.8 and obstacle.clearance(probe) < Sled.RADIUS


## Not a crash: people and animals topple, you get a small hop and lose a
## little speed. Hard things just give you something to bounce off.
func _top_hop(p: Player, obstacle: Obstacle) -> void:
	obstacle.near_miss_done = true
	p.sled.bounce(3.5)
	p.sled.velocity *= 0.88
	p.camera.add_shake(0.3)
	p.rumble(0.3, 0.3, 0.15)
	if obstacle.is_creature():
		obstacle.launch(p.sled.travel_velocity() * 0.25 + Vector3.UP * 2.0)
		_add_bonus(p, 30)
		p.say("Hoppsan! +30", Hud.WARM)
		_sound.play("moose" if obstacle.kind == Obstacle.Kind.MOOSE or obstacle.kind == Obstacle.Kind.BEAR else "oops", 0.0, _rng.randf_range(0.6, 0.7) if obstacle.kind == Obstacle.Kind.BEAR else _rng.randf_range(1.0, 1.3))
	else:
		_sound.play("land", 0.0, 1.2)


func _roof_bounce(p: Player, obstacle: Obstacle) -> void:
	obstacle.near_miss_done = true
	p.sled.bounce(8.5)
	p.sled.velocity += Vector3(obstacle.velocity.x * 0.3, 0.0, 0.0)
	var points := 400 if obstacle.kind == Obstacle.Kind.PLOW else 250
	_add_bonus(p, points)
	p.say("Taklandning! +%d" % points, Hud.HOT, 60)
	_sound.play("horn", 0.0, 1.15)
	_sound.play("jump", 0.0, 0.8)
	p.camera.add_shake(0.5)
	p.flash(Hud.WARM, 0.25)
	p.rumble(0.5, 0.4, 0.2)


## Shaving past something: points, a whoosh and a little push, but no
## call-out (they came too often to be worth reading).
func _near_miss(p: Player, obstacle: Obstacle) -> void:
	var points := 100 if obstacle.is_vehicle() else 50
	_add_bonus(p, points)
	_sound.play("whoosh", 0.0, _rng.randf_range(0.9, 1.2))
	if obstacle.is_vehicle():
		_sound.play("horn", -4.0)
	p.sled.boost_time = maxf(p.sled.boost_time, 0.5)
	p.camera.add_shake(0.2)


## A collision, judged by physics: how fast you close on the obstacle,
## shared out by the two masses and softened by the ride's protection.
func _impact(p: Player, obstacle: Obstacle, probe: Vector3) -> void:
	if _no_crash and not obstacle.soft and not obstacle.harmless:
		return
	if obstacle.in_branches(probe):
		_brush(obstacle)
		return
	var travel := p.sled.travel_velocity()
	var heading := Vector3(travel.x, 0.0, travel.z)
	var normal := obstacle.push_normal(probe, -heading.normalized() if heading.length() > 0.1 else Vector3.BACK)
	var relative := travel - obstacle.velocity
	relative.y = 0.0
	var closing := maxf(-relative.dot(normal), 0.0)
	var rider := p.sled.total_mass()
	var share := 1.0 if is_inf(obstacle.mass) else obstacle.mass / (obstacle.mass + rider)
	if obstacle.movable():
		var thrown := travel * 0.35 - normal * closing * rider / (obstacle.mass + rider) * 1.6
		obstacle.launch(thrown + Vector3.UP * (2.0 + closing * 0.25))
	if obstacle.harmless:
		_sound.play("poff", -6.0, 1.4)
		return
	if obstacle.soft:
		_soft_hit(p, obstacle)
		return
	var severity := closing * share / p.sled.spec.protection
	var separation := Sled.RADIUS - obstacle.clearance(probe) + 0.05
	if severity >= CRASH_SEVERITY:
		_crash_into(p, obstacle)
	elif severity >= WIPEOUT_SEVERITY:
		p.sled.knock(normal, closing * share * 1.2, separation, _rng.randf_range(1.0, 2.0) * (1.0 if _rng.randf() < 0.5 else -1.0))
		p.sled.velocity *= 0.45
		p.sled.bounce(2.0)
		_sound.play("oops", 0.0, 0.9)
		_sound.play("land", 2.0, 0.8)
		p.camera.add_shake(0.7)
		p.rumble(0.6, 0.7, 0.3)
		p.say(WIPEOUT_LINES[_rng.randi_range(0, WIPEOUT_LINES.size() - 1)], Hud.WARM, 52)
	else:
		p.sled.knock(normal, closing * share * 1.3, separation)
		p.sled.velocity *= 0.92
		_sound.play("land", -2.0, 1.1)
		p.camera.add_shake(clampf(severity * 0.1, 0.1, 0.4))
		p.rumble(0.3, 0.2, 0.1)


## Spruce branches are soft: you ride straight through with a rustle
## against the jacket. Only the trunk is hard.
func _brush(obstacle: Obstacle) -> void:
	if obstacle.brushed:
		return
	obstacle.brushed = true
	_sound.play("rustle", -3.0, _rng.randf_range(0.9, 1.15))


func _soft_hit(p: Player, obstacle: Obstacle) -> void:
	obstacle.react_to_hit(p.sled.velocity)
	match obstacle.kind:
		Obstacle.Kind.SNOWMAN:
			Debris.burst(_world_root, _field, obstacle.position, p.sled.velocity * 0.6, 14, 0.28)
			_sound.play("poff", 2.0)
			p.sled.velocity *= 0.82
			_add_bonus(p, 25)
			p.say("Snögubbe-strike! +25", Hud.WARM)
			p.camera.add_shake(0.5)
			p.rumble(0.4, 0.2, 0.2)
		Obstacle.Kind.LOG:
			p.sled.bounce(4.5)
			p.sled.velocity *= 0.75
			_sound.play("land", 2.0, 0.8)
			p.camera.add_shake(0.6)
			p.rumble(0.5, 0.6, 0.2)
		_:
			_sound.play("oops")
			p.say("Haren hoppade undan!", Hud.COOL)


func _crash_into(p: Player, obstacle: Obstacle) -> void:
	match obstacle.kind:
		Obstacle.Kind.MOOSE:
			_sound.play("moose", 2.0)
		Obstacle.Kind.BEAR:
			_sound.play("moose", 4.0, 0.6)
		Obstacle.Kind.CAR, Obstacle.Kind.PLOW, Obstacle.Kind.TRUCK:
			_sound.play("horn")
		Obstacle.Kind.PERSON, Obstacle.Kind.KID:
			_sound.play("oops", 0.0, 1.3)
	var lines := _crash_lines(obstacle)
	var line: String = lines[_rng.randi_range(0, lines.size() - 1)]
	if line.contains("%s"):
		var names: Array = KID_NAMES if obstacle.kind == Obstacle.Kind.KID else PERSON_NAMES
		line = line % names[_rng.randi_range(0, names.size() - 1)]
	_crash(line, p)


func _crash_lines(obstacle: Obstacle) -> Array:
	return BIRCH_CRASH_LINES if obstacle.birch else CRASH_LINES.get(obstacle.kind, ["Krasch!"])


func _crash(line: String, p: Player = null) -> void:
	if p == null:
		p = _players[0]
	if _no_crash:
		return
	if _autopilot:
		print("crash at %d m: %s" % [int(p.run_distance), line])
	p.sled.crash()
	if not _racing:
		p.lives -= 1
	p.crash_timer = RESPAWN_DELAY
	_sound.play("crash")
	p.camera.mode = ChaseCamera.Mode.CRASH
	p.camera.add_shake(1.0)
	p.flash(Color(1, 1, 1), 0.55)
	p.rumble(0.8, 1.0, 0.45)
	p.last_crash_line = line
	p.say(line, Hud.HOT, 56, CRASH_LINE_HOLD)


func _after_crash(p: Player) -> void:
	if p.lives <= 0 and not _racing:
		_game_over()
		return
	var d := p.sled.distance() + 4.0
	var water := _field.water_strip(d)
	if water != Vector2.ZERO:
		d = water.y + TerrainField.WATER_BLEND + 6.0
	if _field.near_road(d, 8.0):
		d = _field.nearest_road(d) + TerrainField.ROAD_HALF_WIDTH + 20.0
	if _field.in_rooftops(d): d = _field.roof_recovery(d)
	# A fixed clear line through the cave avoids respawning inside a column.
	var lateral := _field.sewer_guide(d) if _field.in_sewer(d) else (-5.3 if _field.in_cave(d) else 0.0)
	p.sled.place_at(d, lateral, 12.0, true)
	p.sled.invulnerable_time = 2.5
	p.camera.mode = ChaseCamera.Mode.CHASE
	p.camera.snap()


func _game_over() -> void:
	var p := _players[0]
	state = State.GAME_OVER
	_director.stop()
	var record := p.run_distance > _save.best_distance
	if record:
		_save.best_distance = p.run_distance
	_save.best_score = maxi(_save.best_score, p.score())
	_save.unlocked_distance = maxf(_save.unlocked_distance, p.run_distance)
	if not _autopilot:
		_save.store()
	_hud.show_game_over(GAME_OVER_LINES[_rng.randi_range(0, GAME_OVER_LINES.size() - 1)], p.last_crash_line, p.run_distance, p.score(), _save.best_distance, record)
	_sound.set_music_ducked(true)
	_input_cooldown = Hud.OVER_GUARD


func _check_bounds(p: Player = null) -> void:
	if p == null:
		p = _players[0]
	var d := p.sled.distance()
	var outside := absf(p.sled.position.x - _field.center_x(d)) - _field.half_width(d)
	var kind := _field.region(d)
	if _field.in_sewer(d):
		# The pipe is a sliding contact resolved during each physics substep.
		return
	if _field.in_cave(d):
		if outside > -0.65 or p.sled.position.y + 1.25 > _field.cave_ceiling(p.sled.position.x, d):
			_crash("Rakt in i isväggen!", p)
		return
	if _field.in_harbor(d):
		if _field.below_structure(p.sled.position) or p.sled.position.y + 1.25 > _field.harbor_tunnel_ceiling(p.sled.position.x, d):
			_crash("Rakt in i containern!", p)
		elif _field.harbor_water(p.sled.position.x, d) and p.sled.position.y < _field.harbor_height(d) - 0.7:
			_crash("Plums mellan kajerna!", p)
		elif p.sled.position.x - _field.center_x(d) < TerrainField.HARBOR_LEFT_BOUND:
			_crash("Fel väg till lagret!", p)
		return
	if _field.in_rooftops(d):
		if _field.below_structure(p.sled.position) or p.sled.position.y < _field.roof_base_height(d) - 2.0:
			_crash("Du missade taket!", p)
		return
	if _field.on_bridge(d):
		var lateral := absf(p.sled.position.x - _field.center_x(d))
		var above_deck := p.sled.position.y - _field.bridge_height(d)
		if above_deck < -0.5 or (lateral > TerrainField.BRIDGE_HALF_WIDTH - 0.40 and above_deck < TerrainField.BRIDGE_RAIL_HEIGHT):
			_crash("Du ramlade av bron!" if above_deck < -0.5 else "Rakt in i broräcket!", p)
		return
	if outside <= _field.side_margin(d): return
	_hit_side(p, d, outside - _field.side_margin(d))


## Riding into the course's side limit (where the net shows), judged like any
## other collision: by how fast you close on it, softened by the ride's
## protection. A gentle touch bounces you back in, a firmer one throws you off
## balance, and only a hard hit crashes. `depth` is how far past it you are.
func _hit_side(p: Player, d: float, depth: float) -> void:
	var side := signf(p.sled.position.x - _field.center_x(d))
	var track := _field.track_dir(d)
	var outward := Vector3(-track.z, 0.0, track.x).normalized() * side
	# Where the course narrows the limit closes in on you too.
	var limit := _field.half_width(d) + _field.side_margin(d)
	var limit_ahead := _field.half_width(d + 1.0) + _field.side_margin(d + 1.0)
	var travel := p.sled.travel_velocity()
	var closing := maxf(travel.dot(outward) + (limit - limit_ahead) * maxf(-travel.z, 0.0), 0.0)
	var severity := closing / p.sled.spec.protection
	if severity >= CRASH_SEVERITY and not _no_crash:
		_crash(_side_crash_line(_field.region(d)), p)
		return
	var now := Time.get_ticks_msec() / 1000.0
	var fresh := now - p.side_bump_at > 0.4
	p.side_bump_at = now
	# Turned a little away from the side, so holding on into it isn't a
	# string of bumps.
	var away := -side * 0.2
	if severity >= WIPEOUT_SEVERITY:
		p.sled.knock(-outward, closing * 1.2, depth + 0.05, away * 3.0)
		p.sled.velocity *= 0.6
		p.sled.bounce(1.5)
		_sound.play("oops", 0.0, 0.9)
		_sound.play("land", 2.0, 0.8)
		p.camera.add_shake(0.6)
		p.rumble(0.6, 0.6, 0.3)
		p.say(WIPEOUT_LINES[_rng.randi_range(0, WIPEOUT_LINES.size() - 1)], Hud.WARM, 52)
	else:
		# Scraping along costs a little speed, a square knock more.
		p.sled.knock(-outward, closing * 1.3 + 0.5, depth + 0.05, away)
		p.sled.velocity *= 1.0 - minf(closing * 0.03, 0.2)
		if fresh:
			_sound.play("land", -4.0, 1.2)
			p.camera.add_shake(clampf(severity * 0.08, 0.1, 0.35))
			p.rumble(0.3, 0.2, 0.1)


func _side_crash_line(kind: TerrainField.Region) -> String:
	match kind:
		TerrainField.Region.MALL:
			return ["Rakt in i skyltfönstret!", "Du provade en tröja. Med ansiktet.", "Öppet köp gäller inte."][_rng.randi_range(0, 2)]
		TerrainField.Region.BANDY:
			return ["In i sargen!", "Utvisning, tio minuter!"][_rng.randi_range(0, 1)]
		TerrainField.Region.WOODS:
			return ["In i granskogen!", "Barr överallt.", "Skogen tog dig."][_rng.randi_range(0, 2)]
		TerrainField.Region.TOWN:
			return ["Rakt in i skyltfönstret!", "Du handlade lite på vägen.", "Butiken har stängt. Nu."][_rng.randi_range(0, 2)]
	return "Vilse i villaområdet!"


func _check_pickups(p: Player = null) -> void:
	if p == null:
		p = _players[0]
	var probe := p.sled.position + (p.sled.sewer_up() if p.sled.sewer_active else Vector3.UP) * 0.6
	for pickup in _world.pickups_near(p.sled.distance()):
		if not pickup.touches(probe):
			continue
		pickup.collect()
		match pickup.kind:
			Pickup.Kind.GINGERBREAD:
				p.cookie_streak += 1
				p.cookie_timer = 1.5
				_add_bonus(p, 10 * mini(p.cookie_streak, 6))
				_sound.play("coin", -4.0, 1.0 + 0.06 * mini(p.cookie_streak, 8))
			Pickup.Kind.MITTEN:
				if _racing:
					# No lives in a race: warm hands go faster.
					p.sled.boost_time = maxf(p.sled.boost_time, 1.2)
					p.say("Varma vantar, mer fart!", Hud.COOL)
				else:
					p.lives = mini(p.lives + 1, MAX_LIVES)
				_sound.play("cocoa")
			Pickup.Kind.WAX:
				p.sled.boost_time = 2.5
				_sound.play("boost")
				p.flash(Color(0.6, 0.85, 1.0), 0.35)
				p.camera.add_shake(0.4)


func _on_skimmed(speed: float, p: Player) -> void:
	if state != State.PLAYING:
		return
	_sound.play("splash", 0.0, _rng.randf_range(0.9, 1.15))
	Splash.spawn(_world_root, p.sled.position, p.sled.velocity, 0.8)
	p.camera.add_shake(0.25)
	p.rumble(0.2, 0.3, 0.1)
	_add_bonus(p, int(speed))


func _on_sank(p: Player) -> void:
	if state != State.PLAYING or p.sled.crashed:
		return
	_sound.play("splash", 4.0, 0.75)
	Splash.spawn(_world_root, p.sled.position, Vector3.ZERO, 1.8)
	_crash(["Plask!", "Blöta byxor!", "Isvak!", "För lite fart, för mycket vatten."][_rng.randi_range(0, 3)], p)


func _on_jumped(_p: Player) -> void:
	_sound.play("jump", -4.0)


func _on_landed(air_time: float, impact: float, spin: float, grab: float, p: Player) -> void:
	if state != State.PLAYING or p.sled.crashed:
		return
	# Landing before the rider is back in the seat: a stiff rider can't take it.
	if p.sled.in_trick():
		_crash(GRAB_CRASH_LINES[_rng.randi_range(0, GRAB_CRASH_LINES.size() - 1)], p)
		return
	if impact > 4.0:
		_sound.play("land", linear_to_db(clampf(impact / 14.0, 0.2, 1.0)))
		p.camera.add_shake(clampf(impact * 0.04, 0.0, 0.8))
		p.sled.puff()
		p.rumble(0.3, clampf(impact / 20.0, 0.1, 0.8), 0.15)
	if p.over_cliff:
		p.over_cliff = false
		var points := CLIFF_BONUS + int(air_time * 40.0)
		_add_bonus(p, points)
		p.say("Du överlevde stupet! +%d" % points, Hud.WARM, 60, 2.0)
		_sound.play("trick")
		p.camera.add_shake(0.8)
		p.sled.puff()
		p.rumble(0.6, 0.9, 0.35)
		# Tricks over the cliff count on top.
		_score_tricks(p, spin, grab)
		return
	if _score_tricks(p, spin, grab):
		return
	if air_time > 0.35 and _field.in_rooftops(p.sled.distance()):
		_add_bonus(p, 50)
		p.say("Takhopp! +50", Hud.WARM)
		_sound.play("trick", -4.0)
	elif air_time > 0.7:
		# Short hops still score, but only real flights get a call-out.
		var points := int(air_time * 40.0)
		_add_bonus(p, points)
		if air_time >= 2.0:
			p.say("Luftfärd! %s s +%d" % [("%.1f" % air_time).replace(".", ","), points], Hud.WARM)


## A flight that ended in a bounce or a skip on water: its spin and grab
## count as on a landing (no crash for a grab still held: it carries on).
func _on_tricked(_air_time: float, spin: float, grab: float, p: Player) -> void:
	if state == State.PLAYING and not p.sled.crashed:
		_score_tricks(p, spin, grab)


## Scores a flight's spin and grab, alone or together; false if neither counts.
func _score_tricks(p: Player, spin: float, grab: float) -> bool:
	var grab_points := int(grab * GRAB_POINTS) if grab >= GRAB_MIN else 0
	var grab_title := GrabTrick.for_model(p.sled.spec.model).title
	var trick := _spin_trick(spin)
	if trick.x > 0 and grab_points > 0:
		var points := int((trick.y + grab_points) * GRAB_COMBO)
		_add_bonus(p, points)
		p.say("%s %d°! +%d" % [grab_title, trick.x, points], Hud.HOT, 60)
	elif trick.x > 0:
		_add_bonus(p, trick.y)
		p.say("%d°! +%d" % [trick.x, trick.y], Hud.HOT, 60)
	elif grab_points > 0:
		_add_bonus(p, grab_points)
		p.say("%s! +%d" % [grab_title, grab_points], Hud.HOT, 56)
	else:
		return false
	_sound.play("trick")
	return true


## A landed spin of `spin` radians: (degrees credited, points), or zero
## when it is short of a full turn.
static func _spin_trick(spin: float) -> Vector2i:
	var halves := floori((absf(spin) + SPIN_MARGIN) / PI)
	if halves < 2:
		return Vector2i.ZERO
	var points := SPIN_POINTS * pow(halves / 2.0, SPIN_GROWTH)
	return Vector2i(halves * 180, roundi(points / 10.0) * 10)


# --- Testing helpers ---

func _autopilot_steer(p: Player = null) -> float:
	if p == null:
		p = _players[0]
	var d := p.sled.distance()
	var look := d + 22.0
	if not _reckless and (_field.in_sewer(d) or _field.in_sewer(look)): return SewerPipe.autopilot(p.sled)
	var target_x := _field.center_x(look)
	if _field.in_sewer(look): target_x += _field.sewer_guide(look)
	if _reckless:
		return clampf(wrapf(atan2(target_x - p.sled.position.x, look - d) - p.sled.yaw, -PI, PI) * 3.0, -1.0, 1.0)
	for obstacle in _world.obstacles_near(d + 20.0):
		var od := -obstacle.position.z
		if od > d and od < d + 30.0 and absf(obstacle.position.x - target_x) < 3.5:
			target_x = obstacle.position.x + (4.5 if obstacle.position.x < target_x else -4.5)
	var desired := atan2(target_x - p.sled.position.x, look - d)
	return clampf(wrapf(desired - p.sled.yaw, -PI, PI) * 3.0, -1.0, 1.0)


## Testing aid: distance where the first region of the named kind begins.
func _find_region(name: String) -> float:
	var wanted := {
		"town": TerrainField.Region.TOWN, "river": TerrainField.Region.RIVER, "park": TerrainField.Region.PARK,
		"woods": TerrainField.Region.WOODS, "mall": TerrainField.Region.MALL, "rail": TerrainField.Region.RAIL,
		"airport": TerrainField.Region.AIRPORT, "highway": TerrainField.Region.HIGHWAY, "lake": TerrainField.Region.LAKE, "bandy": TerrainField.Region.BANDY, "cliff": TerrainField.Region.CLIFF,
		"bridge": TerrainField.Region.BRIDGE,
		"roofs": TerrainField.Region.ROOFS,
		"cave": TerrainField.Region.ICE_CAVE, "harbor": TerrainField.Region.HARBOR, "sewer": TerrainField.Region.SEWER,
	}.get(name, TerrainField.Region.TOWN) as TerrainField.Region
	# A region can be skipped for a whole seeded cycle. Search slots directly
	# and return the exact start, rather than silently falling back at 40 km.
	for cell in 256:
		var span := _field._slot(cell)
		if int(span.z) == wanted:
			return span.x
	return START_D


func _maybe_screenshot() -> void:
	if _screenshot_path == "" or _elapsed < _screenshot_times[_screenshot_index]:
		return
	var path := _screenshot_path.replace(".png", "_%d.png" % _screenshot_index) if _screenshot_times.size() > 1 else _screenshot_path
	get_viewport().get_texture().get_image().save_png(path)
	var p := _players[0]
	print("Saved ", path, " distance=", int(p.run_distance), " speed=", int(p.sled.speed() * 3.6), " km/h fps=", Engine.get_frames_per_second(), " lives=", p.lives, " state=", State.keys()[state])
	_screenshot_index += 1
	if _screenshot_index >= _screenshot_times.size():
		_screenshot_path = ""
		get_tree().quit()
