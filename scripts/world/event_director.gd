class_name EventDirector
extends Node3D
## Random happenings during a run: blizzards with no visibility, snowball
## fights, Santa flying over dropping presents, and northern lights that
## double your points. One event at a time, spaced out along the slope.

signal snowball_hit
signal gift_collected

enum Kind { NONE, BLIZZARD, SNOWBALLS, SANTA, AURORA }

const FIRST_EVENT := 450.0
const GAP_MIN := 500.0
const GAP_MAX := 900.0
const GRAVITY := 15.0
const SLEIGH_HEIGHT := 7.0
const GIFTS_PER_FLIGHT := 8


## Something airborne: a snowball or a falling present.
class Flying:
	var node: Node3D
	var velocity := Vector3.ZERO
	var landed := false
	var age := 0.0


var sled: Sled
var field: TerrainField
var atmosphere: Atmosphere
var sound: SoundBank
var active := Kind.NONE
## Score multiplier while the northern lights are out.
var multiplier := 1.0

var _rng := RandomNumberGenerator.new()
var _time_left := 0.0
var _next_at := 0.0
var _last := Kind.NONE
var _forced := Kind.NONE
var _clock := 0.0
var _storm := 0.0
var _night := 0.0
var _aurora := 0.0
var _wind_side := 1.0
var _throw_timer := 0.0
var _snowballs: Array[Flying] = []
var _throwers: Array[Node3D] = []
var _gifts: Array[Flying] = []
var _sleigh: Node3D
var _sleigh_d := 0.0
var _sleigh_speed := 0.0
var _drops := 0
var _drop_timer := 0.0
var _jingle_timer := 0.0
var _caught := 0
var _sleigh_age := 0.0


func _ready() -> void:
	_rng.randomize()


func reset(start_d: float) -> void:
	_clear()
	active = Kind.NONE
	multiplier = 1.0
	_storm = 0.0
	_night = 0.0
	_aurora = 0.0
	_last = Kind.NONE
	_next_at = start_d + FIRST_EVENT + _rng.randf_range(0.0, 200.0)
	_apply_atmosphere()


## Testing aid: make `kind` the next event, starting almost right away.
func force_next(kind: Kind, start_d: float) -> void:
	_forced = kind
	_next_at = start_d + 30.0


## Ends whatever is going on; visuals fade out by themselves.
func stop() -> void:
	if active != Kind.NONE:
		_finish()
	_next_at = INF


func update(delta: float, playing: bool) -> void:
	_clock += delta
	var d := sled.distance()
	if playing and active == Kind.NONE and d >= _next_at:
		_start(_forced if _forced != Kind.NONE else _pick())
		_forced = Kind.NONE
	if active != Kind.NONE:
		_time_left -= delta
		match active:
			Kind.SNOWBALLS:
				_throw_timer -= delta
				if _throw_timer <= 0.0 and playing:
					_throw()
					_throw_timer = _rng.randf_range(0.45, 0.9)
			Kind.SANTA:
				if _sleigh == null and _gifts.is_empty():
					_finish()
		if _time_left <= 0.0 and active != Kind.SANTA:
			_finish()
	_storm = move_toward(_storm, 1.0 if active == Kind.BLIZZARD else 0.0, delta / 3.0)
	_night = move_toward(_night, 1.0 if active == Kind.AURORA else 0.0, delta / 3.0)
	_aurora = move_toward(_aurora, 1.0 if active == Kind.AURORA and _night > 0.6 else 0.0, delta / 2.5)
	_apply_atmosphere()
	_update_wind()
	_update_snowballs(delta)
	_update_sleigh(delta)
	_update_gifts(delta)
	for thrower: Node3D in _throwers.duplicate():
		if thrower.position.z > sled.position.z + 40.0:
			_throwers.erase(thrower)
			thrower.queue_free()


func _pick() -> Kind:
	var options: Array[Kind] = [Kind.BLIZZARD, Kind.SNOWBALLS, Kind.SANTA, Kind.AURORA]
	options.erase(_last)
	return options[_rng.randi_range(0, options.size() - 1)]


func _start(kind: Kind) -> void:
	active = kind
	match kind:
		Kind.BLIZZARD:
			_time_left = 18.0
			_wind_side = -1.0 if _rng.randf() < 0.5 else 1.0
		Kind.SNOWBALLS:
			_time_left = 14.0
			_throw_timer = 1.0
		Kind.SANTA:
			_time_left = INF
			_caught = 0
			_spawn_sleigh()
			sound.play("hohoho", 2.0)
		Kind.AURORA:
			_time_left = 22.0
			multiplier = 2.0


func _finish() -> void:
	_last = active
	active = Kind.NONE
	multiplier = 1.0
	_next_at = sled.distance() + _rng.randf_range(GAP_MIN, GAP_MAX)


func _clear() -> void:
	for flying: Flying in _snowballs + _gifts:
		flying.node.queue_free()
	_snowballs.clear()
	_gifts.clear()
	for thrower in _throwers:
		thrower.queue_free()
	_throwers.clear()
	if _sleigh:
		_sleigh.queue_free()
		_sleigh = null


func _apply_atmosphere() -> void:
	atmosphere.storm = _storm
	atmosphere.night_override = _night * 0.85
	atmosphere.aurora = _aurora
	atmosphere.wind = _wind_side
	sound.storm = _storm


# --- Blizzard ---

func _update_wind() -> void:
	if _storm <= 0.0:
		sled.wind_drift = Vector3.ZERO
		return
	var gust := 0.35 + 0.65 * absf(sin(_clock * 0.8) * sin(_clock * 0.31 + 1.0))
	var across := field.track_dir(sled.distance()).cross(Vector3.UP)
	sled.wind_drift = across * _wind_side * gust * 5.5 * _storm


# --- Snowball fight ---

func _throw() -> void:
	var flight := 0.9
	var target := sled.position + sled.velocity * flight + Vector3(_rng.randf_range(-1.2, 1.2), 0.5, _rng.randf_range(-1.0, 1.0))
	var target_d := -target.z
	var side := -1.0 if _rng.randf() < 0.5 else 1.0
	var launch_d := target_d + _rng.randf_range(-2.0, 8.0)
	var x := field.center_x(launch_d) + side * (field.half_width(launch_d) + _rng.randf_range(1.0, 3.5))
	var ground := field.height(x, launch_d)
	var thrower := Props.posed(Props.person(_rng.randi_range(0, 7)), 1.0)
	thrower.scale = Vector3.ONE * 0.62
	thrower.position = Vector3(x, ground, -launch_d)
	var aim := target - thrower.position
	thrower.rotation.y = atan2(-aim.x, -aim.z)
	add_child(thrower)
	_throwers.append(thrower)
	var ball := Flying.new()
	ball.node = MeshInstance3D.new()
	(ball.node as MeshInstance3D).mesh = Props.snowball()
	ball.node.position = thrower.position + Vector3(0, 1.1, 0)
	ball.velocity = (target - ball.node.position) / flight + Vector3(0, 0.5 * GRAVITY * flight, 0)
	add_child(ball.node)
	_snowballs.append(ball)


func _update_snowballs(delta: float) -> void:
	var body := sled.position + Vector3.UP * 0.6
	for ball: Flying in _snowballs.duplicate():
		ball.age += delta
		ball.velocity.y -= GRAVITY * delta
		ball.node.position += ball.velocity * delta
		var hit := not sled.crashed and ball.node.position.distance_to(body) < 1.0
		var ground := field.height_world(ball.node.position.x, ball.node.position.z)
		if hit or ball.node.position.y < ground or ball.age > 3.0:
			if hit:
				snowball_hit.emit()
			Debris.burst(get_parent(), field, ball.node.position - Vector3(0, 0.6, 0), ball.velocity * 0.2, 5, 0.12)
			ball.node.queue_free()
			_snowballs.erase(ball)


# --- Santa's sleigh ---

func _spawn_sleigh() -> void:
	_sleigh = Node3D.new()
	var sleigh := MeshInstance3D.new()
	sleigh.mesh = Props.santa_sleigh()
	_sleigh.add_child(sleigh)
	for row in 2:
		for side in [-1.0, 1.0]:
			var deer := Props.posed(Props.deer(), row * 1.3 + (0.0 if side < 0.0 else 0.6))
			deer.position = Vector3(0.75 * side, 0.1, -3.4 - row * 2.4)
			_sleigh.add_child(deer)
			if row == 1 and side < 0.0:
				var nose := MeshInstance3D.new()
				nose.mesh = MeshKit.new().sphere(0.07, Vector3(0, 1.57, -0.95), Color(1.0, 0.1, 0.1, 0.0)).build()
				deer.add_child(nose)
	add_child(_sleigh)
	# Swoops in from high up ahead of the player, then leads the way.
	_sleigh_d = sled.distance() + 40.0
	_sleigh_speed = maxf(sled.speed() + 3.0, 22.0)
	_sleigh_age = 0.0
	_drops = 0
	_drop_timer = 0.0
	_place_sleigh()


func _place_sleigh() -> void:
	var x := field.center_x(_sleigh_d) + sin(_sleigh_d * 0.02) * field.half_width(_sleigh_d) * 0.4
	var swoop := 1.0 - smoothstep(0.0, 2.5, _sleigh_age)
	var y := field.height(x, _sleigh_d, false) + SLEIGH_HEIGHT + swoop * 30.0 + sin(_clock * 2.0) * 0.8
	_sleigh.position = Vector3(x, y, -_sleigh_d)
	var dir := field.track_dir(_sleigh_d)
	_sleigh.rotation = Vector3(sin(_clock * 2.0) * 0.06, atan2(-dir.x, -dir.z), sin(_clock * 1.3) * 0.08)


func _update_sleigh(delta: float) -> void:
	if _sleigh == null:
		return
	_sleigh_age += delta
	var lead := maxf(sled.speed() + (2.0 if _drops < GIFTS_PER_FLIGHT else 12.0), 22.0)
	_sleigh_speed = lerpf(_sleigh_speed, lead, 1.0 - exp(-0.5 * delta))
	_sleigh_d += _sleigh_speed * delta
	_place_sleigh()
	_jingle_timer -= delta
	if _jingle_timer <= 0.0:
		_jingle_timer = 1.5
		var distance := _sleigh.position.distance_to(sled.position)
		sound.play("jingle", clampf(4.0 - distance * 0.12, -24.0, 4.0))
	var ahead := _sleigh_d - sled.distance()
	if ahead > 12.0 and _sleigh_age > 2.0 and _drops < GIFTS_PER_FLIGHT:
		_drop_timer -= delta
		if _drop_timer <= 0.0:
			_drop_timer = 0.8
			_drop_gift()
	if _drops >= GIFTS_PER_FLIGHT and ahead > 260.0:
		_sleigh.queue_free()
		_sleigh = null


func _drop_gift() -> void:
	_drops += 1
	var gift := Flying.new()
	gift.node = MeshInstance3D.new()
	(gift.node as MeshInstance3D).mesh = Props.gift(_rng.randi_range(0, 3))
	gift.node.scale = Vector3.ONE * 1.4
	gift.node.position = _sleigh.position + Vector3(0, 0.8, 1.2)
	var dir := field.track_dir(_sleigh_d)
	gift.velocity = dir * _sleigh_speed * 0.35 + dir.cross(Vector3.UP) * _rng.randf_range(-3.0, 3.0)
	add_child(gift.node)
	_gifts.append(gift)


func _update_gifts(delta: float) -> void:
	for gift: Flying in _gifts.duplicate():
		gift.age += delta
		if not gift.landed:
			gift.velocity.y -= GRAVITY * 0.7 * delta
			gift.node.position += gift.velocity * delta
			gift.node.rotation += Vector3(2.0, 3.0, 1.0) * delta
			var ground := field.height_world(gift.node.position.x, gift.node.position.z)
			if gift.node.position.y <= ground:
				gift.landed = true
				gift.node.position.y = ground
				gift.node.rotation = Vector3(0, gift.node.rotation.y, 0)
		else:
			gift.node.rotation.y += delta * 1.5
		var offset := gift.node.position - sled.position
		if not sled.crashed and Vector2(offset.x, offset.z).length() < 1.9 and absf(offset.y) < 2.5:
			_caught += 1
			gift_collected.emit()
			gift.node.queue_free()
			_gifts.erase(gift)
		elif gift.node.position.z > sled.position.z + 30.0:
			gift.node.queue_free()
			_gifts.erase(gift)
