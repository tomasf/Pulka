class_name VehicleSpec
extends RefCounted
## Handling characteristics for each ride.

enum Model { PULKA, STJARTLAPP, SNOWRACER, TEFAT }

var id := ""
var model := Model.PULKA
var title := ""
var description := ""
## Turn rate in radians per second at full stick.
var steer := 1.6
## How quickly sideways sliding is killed (per second).
var grip := 3.0
## Speed lost per radian the velocity is swung round by carving.
var scrub := 0.2
var drag := 0.0022
var friction := 0.035
var brake := 9.0
var jump := 6.0
## How strongly the nose swings back to the direction of travel.
var self_align := 1.5
## Random yaw wobble, for rides that refuse to go straight.
var wobble := 0.0
## Visual spin of the whole ride (the saucer never stops turning).
var visual_spin := 0.0
var air_spin := 5.0
var air_gravity := 1.0
var seat_height := 0.22
var unlock_distance := 0.0
var stat_speed := 0.5
var stat_handling := 0.5
var stat_grip := 0.5


static func all() -> Array[VehicleSpec]:
	var list: Array[VehicleSpec] = []

	var pulka := VehicleSpec.new()
	pulka.id = "pulka"
	pulka.model = Model.PULKA
	pulka.title = "Pulka"
	pulka.description = "Klassisk röd plastpulka. Stabil, pålitlig och lite tråkig – som en gammal Volvo."
	pulka.steer = 1.8
	pulka.grip = 7.0
	pulka.scrub = 0.2
	pulka.drag = 0.0021
	pulka.friction = 0.034
	pulka.jump = 6.5
	pulka.self_align = 1.2
	pulka.seat_height = 0.16
	pulka.stat_speed = 0.55
	pulka.stat_handling = 0.6
	pulka.stat_grip = 0.65
	list.append(pulka)

	var lapp := VehicleSpec.new()
	lapp.id = "stjartlapp"
	lapp.model = Model.STJARTLAPP
	lapp.title = "Stjärtlapp"
	lapp.description = "Snabb som en hal tvål. Snurrar gärna – med eller utan din tillåtelse."
	lapp.steer = 2.6
	lapp.grip = 3.5
	lapp.scrub = 0.12
	lapp.drag = 0.0017
	lapp.friction = 0.022
	lapp.jump = 5.2
	lapp.self_align = 0.4
	lapp.wobble = 1.3
	lapp.air_spin = 7.0
	lapp.seat_height = 0.05
	lapp.stat_speed = 0.8
	lapp.stat_handling = 0.75
	lapp.stat_grip = 0.25
	list.append(lapp)

	var racer := VehicleSpec.new()
	racer.id = "snowracer"
	racer.model = Model.SNOWRACER
	racer.title = "Snowracer"
	racer.description = "Ratt, skidor och attityd. Greppar som en dröm men är tung i luften."
	racer.steer = 1.45
	racer.grip = 11.0
	racer.scrub = 0.15
	racer.drag = 0.0023
	racer.friction = 0.03
	racer.jump = 7.5
	racer.self_align = 2.6
	racer.air_spin = 4.0
	racer.air_gravity = 1.15
	racer.seat_height = 0.42
	racer.stat_speed = 0.6
	racer.stat_handling = 0.5
	racer.stat_grip = 0.95
	list.append(racer)

	var saucer := VehicleSpec.new()
	saucer.id = "tefat"
	saucer.model = Model.TEFAT
	saucer.title = "Tefat"
	saucer.description = "Ett snurrande plastfat. Snabbast i backen, sämst på allt annat."
	saucer.steer = 2.1
	saucer.grip = 2.2
	saucer.scrub = 0.08
	saucer.drag = 0.0015
	saucer.friction = 0.018
	saucer.jump = 5.5
	saucer.self_align = 0.15
	saucer.wobble = 2.2
	saucer.visual_spin = 2.5
	saucer.air_spin = 9.0
	saucer.seat_height = 0.12
	saucer.unlock_distance = 1500.0
	saucer.stat_speed = 0.95
	saucer.stat_handling = 0.4
	saucer.stat_grip = 0.1
	list.append(saucer)

	return list
