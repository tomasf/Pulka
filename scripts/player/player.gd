class_name Player
extends RefCounted
## One rider in a run: their sled and camera, what they steer with, and
## how their run is going (lives, points, crashes). Alone, a player shares
## the full-screen HUD; in a split-screen race each has a half of their own.

const COLORS := [Color(1.0, 0.55, 0.2), Color(0.45, 0.8, 1.0)]

var index := 0
var sled: Sled
var camera: ChaseCamera
var controls: PlayerControls
## The full-screen HUD (one player) or this player's half (a race).
var hud: Hud
var race_hud: RaceHud
var atmosphere: Atmosphere
var boundary_net: BoundaryNet
## Off for test runs: no pad rumble.
var rumbles := true

var lives := 0
var bonus := 0
var bonus_fraction := 0.0
var run_distance := 0.0
var crash_timer := 0.0
var cookie_streak := 0
var cookie_timer := 0.0
var over_cliff := false
var last_crash_line := ""
## Race time when this player crossed the finish line, or -1.
var finish_time := -1.0
var vehicle := 0
## Race time of the last "Bakvind!" call-out, so it is not repeated.
var draft_said := -100.0


func _init(number: int, ride: Sled, view: ChaseCamera, input: PlayerControls) -> void:
	index = number
	sled = ride
	camera = view
	controls = input


func score() -> int:
	return int(run_distance) + bonus


func finished() -> bool:
	return finish_time >= 0.0


## A call-out on this player's screen.
func say(text: String, color := Hud.WARM, size := 44, hold := Hud.POPUP_HOLD) -> void:
	if race_hud != null:
		race_hud.popup(text, color, size, hold)
	else:
		hud.popup(text, color, size, hold)


func flash(color: Color, amount := 0.6) -> void:
	if race_hud != null:
		race_hud.flash(color, amount)
	else:
		atmosphere.flash(color, amount)


func splat() -> void:
	if race_hud != null:
		race_hud.splat()
	else:
		hud.splat()


func rumble(weak: float, strong: float, duration: float) -> void:
	if rumbles:
		controls.rumble(weak, strong, duration)
