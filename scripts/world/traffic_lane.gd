class_name TrafficLane
extends RefCounted
## Vehicles advance around one periodic lane in travel order. A follower
## approaches its preferred speed only while there is room ahead of it.
const CLEARANCE := 3.0
const HEADWAY := 1.0
const ACCELERATION := 2.0
const BRAKING := 6.0

var length: float
var positions := PackedFloat64Array()
var speeds := PackedFloat64Array()
var cruise := PackedFloat64Array()
var half_lengths := PackedFloat64Array()
var _leaders := PackedInt32Array()
var _moves := PackedFloat64Array()
var _dirty := true


func _init(period: float) -> void:
	length = period


func add(at: float, preferred_speed: float, half_length: float) -> int:
	var index := positions.size()
	positions.append(fposmod(at, length))
	speeds.append(preferred_speed)
	cruise.append(preferred_speed)
	half_lengths.append(half_length)
	_moves.append(0)
	_leaders.append(index)
	_dirty = true
	return index


static func vehicle_half_length(vehicle: Obstacle) -> float:
	var half := vehicle.half_extents.y
	if vehicle.visual.mesh:
		var bounds := vehicle.visual.mesh.get_aabb()
		half = maxf(half, maxf(absf(bounds.position.z), absf(bounds.end.z)))
	return half


func step(delta: float) -> void:
	if delta <= 0 or positions.is_empty(): return
	if _dirty:
		var order := range(positions.size())
		order.sort_custom(func(a: int, b: int) -> bool: return positions[a] < positions[b])
		for i in order.size(): _leaders[order[i]] = order[(i + 1) % order.size()]
		_dirty = false
	# Read the same old positions for every car. Updating the lead car first
	# must not grant one follower a different amount of room this frame.
	for i in positions.size():
		var target := cruise[i]
		var room := INF
		var leader := _leaders[i]
		if leader != i:
			var gap := fposmod(positions[leader] - positions[i], length) - half_lengths[i] - half_lengths[leader]
			room = maxf(0, gap - CLEARANCE)
			# Leave time to react as well as enough distance to brake from
			# our speed to the leader's speed. This starts slowing a fast
			# follower before it reaches the slower vehicle's bumper.
			var reaction := BRAKING * HEADWAY
			var safe_speed := sqrt(reaction * reaction + speeds[leader] * speeds[leader] + 2 * BRAKING * room) - reaction
			target = minf(target, maxf(0, safe_speed))
		var rate := ACCELERATION if target > speeds[i] else BRAKING
		var next_speed := move_toward(speeds[i], target, rate * delta)
		# Also enforce a hard bumper gap for long frames and loop boundaries.
		_moves[i] = minf(next_speed * delta, room)
	for i in positions.size():
		speeds[i] = _moves[i] / delta
		positions[i] = fposmod(positions[i] + _moves[i], length)
