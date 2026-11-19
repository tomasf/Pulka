class_name GrabTrick
extends RefCounted
## A grab: holding jump in the air puts the rider into a stiff trick pose
## for their ride. Saucer and wok are swung round at arm's length, the
## stjärtlapp is held up high; on the pulka and snowracer the rider lets the
## body fly out behind or to the side while one hand keeps hold.

## Shown in the call-out when the trick lands.
var title := ""
## Bones and where they point (in the rider's own space: +Y up, -Z ahead,
## +X right), parents before children. An optional third vector is a
## direction to pass through halfway, so a limb goes round the ride.
var pose: Array = []
## How the whole rider is turned in the trick, about the hips.
var body := Basis.IDENTITY
## How far the hips are raised (a standing rider needs room for the legs).
var lift := 0.0
## True: the ride follows the right hand. False: the right hand stays on the
## ride and the rider is moved to keep it there.
var carries := false
## The point of the ride the right hand holds, in the ride's own space.
var grip := Vector3.ZERO
## How the ride is turned while carried.
var carry := Basis.IDENTITY

static var _tricks: Array[GrabTrick] = []

## Legs together and straight, the spine and head stiff: a plank.
const _STIFF := [
	["spine", Vector3(0, 1, 0)], ["head", Vector3(0, 1, 0)],
	["thigh.L", Vector3(-0.04, -1, 0)], ["shin.L", Vector3(-0.04, -1, 0)],
	["thigh.R", Vector3(0.04, -1, 0)], ["shin.R", Vector3(0.04, -1, 0)],
]


static func for_model(model: VehicleSpec.Model) -> GrabTrick:
	if _tricks.is_empty():
		_tricks = [_superman(), _statue(), _flag(), _spinner("Karusellen", true), _spinner("Flygande Jakob", false)]
	return _tricks[model]


## Turns and raises the rider (`blend` 0..1 of the way) before the limbs
## are posed. The rider's own sitting transform should already be set.
func place_rider(rider: Node3D, blend: float) -> void:
	rider.quaternion = rider.quaternion * Quaternion.IDENTITY.slerp(Quaternion(body), blend)
	rider.position.y += lift * blend


## Once posed, keeps the right hand and the ride together: the ride follows
## the hand, or the rider is moved so the hand stays on the ride. Rider and
## ride share a parent.
func hold(rider: RiderRig, ride: Node3D, blend: float) -> void:
	var hand := rider.transform * rider.hand_position()
	if carries:
		var held := Transform3D(carry, hand) * Transform3D(Basis.IDENTITY, -grip)
		ride.transform = Transform3D.IDENTITY.interpolate_with(held, blend)
	else:
		rider.position += (grip - hand) * blend


## Pulka: the body stretched out flat behind, both hands on the front.
static func _superman() -> GrabTrick:
	var trick := GrabTrick.new()
	trick.title = "Stålmannen"
	# Halfway the rider pushes up on straight arms and kneels in the tub
	# (thighs down, shins back along the bottom) before kicking out, so the
	# body rises clear and the legs never sweep through it.
	trick.pose = [
		["spine", Vector3(0, 1, 0)], ["head", Vector3(0, 1, 0)],
		["thigh.L", Vector3(-0.04, -1, 0), Vector3(-0.04, -0.73, -0.72)], ["shin.L", Vector3(-0.04, -1, 0), Vector3(-0.04, -0.83, 0.56)],
		["thigh.R", Vector3(0.04, -1, 0), Vector3(0.04, -0.73, -0.72)], ["shin.R", Vector3(0.04, -1, 0), Vector3(0.04, -0.83, 0.56)],
		["upper_arm.L", Vector3(0.12, 1, -0.05), Vector3(0.1, -0.56, -0.83)], ["forearm.L", Vector3(0.12, 1, -0.05), Vector3(0.1, -0.56, -0.83)],
		["upper_arm.R", Vector3(-0.12, 1, -0.05), Vector3(-0.1, -0.56, -0.83)], ["forearm.R", Vector3(-0.12, 1, -0.05), Vector3(-0.1, -0.56, -0.83)],
	]
	# Tipped past flat so the legs fly up and clear of the tub.
	trick.body = Basis(Vector3.RIGHT, -PI / 2 - 0.4)
	trick.grip = Vector3(0.17, 0.32, -0.74)
	return trick


## Stjärtlapp: standing bolt upright, the lapp held high by its handle.
static func _statue() -> GrabTrick:
	var trick := GrabTrick.new()
	trick.title = "Frihetsgudinnan"
	trick.pose = _STIFF + [
		["upper_arm.L", Vector3(-1, -0.25, 0)], ["forearm.L", Vector3(-1, -0.15, 0)],
		["upper_arm.R", Vector3(0.12, 1, 0)], ["forearm.R", Vector3(0.05, 1, 0)],
	]
	trick.lift = 0.6
	trick.carries = true
	trick.grip = Vector3(0, 0.17, -0.42)
	trick.carry = Basis(Vector3.RIGHT, -PI / 2)
	return trick


## Snowracer: one hand on the wheel, the body sticking straight out
## sideways like a flag.
static func _flag() -> GrabTrick:
	var trick := GrabTrick.new()
	trick.title = "Flaggan"
	trick.pose = _STIFF + [
		["upper_arm.L", Vector3(-1, 0.1, 0)], ["forearm.L", Vector3(-1, 0.2, 0)],
		["upper_arm.R", Vector3(0, 1, 0)], ["forearm.R", Vector3(0, 1, 0)],
	]
	trick.body = Basis(Vector3.BACK, -PI / 2)
	trick.grip = Vector3(0.16, 0.8, -0.38)
	return trick


## Saucer and wok: lying stiff and flat, the ride swung out at arm's length
## (the saucer by its side grip, the wok by its handle).
static func _spinner(title: String, saucer: bool) -> GrabTrick:
	var trick := GrabTrick.new()
	trick.title = title
	trick.pose = _STIFF + [
		["upper_arm.L", Vector3(-0.15, -1, 0.1)], ["forearm.L", Vector3(-0.1, -1, 0.1)],
		["upper_arm.R", Vector3(1, 0, 0)], ["forearm.R", Vector3(1, 0, 0)],
	]
	trick.body = Basis(Vector3.RIGHT, -PI / 2)
	trick.lift = 0.15
	trick.carries = true
	if saucer:
		trick.grip = Vector3(-0.54, 0.2, 0)
	else:
		trick.grip = Vector3(0, 0.37, 0.88)
		trick.carry = Basis(Vector3.UP, -PI / 2)
	return trick
