class_name TerrainField
extends RefCounted
## Deterministic, analytic description of the endless slope.
##
## Distance downhill is `d = -z`. Everything — the meandering track, banks,
## bumps, roads, ramps and ice — is a pure function of (x, d) and the seed, so
## the sled physics samples exactly the same surface that the meshes show.
##
## Now and then the slope briefly gives way to a special region: a town
## street, a frozen river, a snowpark, a forest trail, a shopping mall, a rail
## yard, an airport, a lake to skim across, a bandy rink, a motorway or a
## cliff that drops away without warning. They are short and spread out, so the
## run still feels like a sledding hill.

enum Zone { OPEN, FOREST, MOGULS, VILLAGE, WILDLIFE }
enum Region { SLOPE, TOWN, RIVER, PARK, WOODS, MALL, RAIL, AIRPORT, LAKE, BANDY, HIGHWAY, CLIFF, BRIDGE, ROOFS, ICE_CAVE, HARBOR, SEWER }
## How the ground meets the edge of the track.
enum Edge { BANK, KERB, GORGE, FLOOR }

## Per region: track half width, edge shape, grip, how rough the ground stays
## (1 = like the open slope), length, and whether roads/kickers may appear.
const REGION_STYLE := {
	Region.TOWN: {"width": 9.5, "edge": Edge.KERB, "grip": 1.0, "rough": 0.15, "length": 300.0, "roads": true, "ramps": false},
	Region.RIVER: {"width": 15.0, "edge": Edge.GORGE, "grip": 0.35, "rough": 0.15, "length": 280.0, "roads": false, "ramps": false},
	Region.PARK: {"width": 27.0, "edge": Edge.BANK, "grip": 1.0, "rough": 0.15, "length": 300.0, "roads": false, "ramps": true},
	Region.WOODS: {"width": 8.5, "edge": Edge.FLOOR, "grip": 1.0, "rough": 0.6, "length": 300.0, "roads": false, "ramps": false},
	Region.MALL: {"width": 13.0, "edge": Edge.KERB, "grip": 1.0, "rough": 0.0, "length": 230.0, "roads": false, "ramps": false},
	Region.RAIL: {"width": 14.0, "edge": Edge.FLOOR, "grip": 1.0, "rough": 0.0, "length": 280.0, "roads": false, "ramps": false},
	Region.AIRPORT: {"width": 22.0, "edge": Edge.KERB, "grip": 1.0, "rough": 0.05, "length": 280.0, "roads": false, "ramps": false},
	Region.LAKE: {"width": 18.0, "edge": Edge.FLOOR, "grip": 1.0, "rough": 0.15, "length": 250.0, "roads": false, "ramps": false},
	Region.HIGHWAY: {"width": 22.0, "edge": Edge.FLOOR, "grip": 1.0, "rough": 0.0, "length": 300.0, "roads": false, "ramps": false},
	Region.BANDY: {"width": 24.0, "edge": Edge.KERB, "grip": 0.35, "rough": 0.0, "length": 200.0, "roads": false, "ramps": false},
	Region.CLIFF: {"width": 24.0, "edge": Edge.BANK, "grip": 1.0, "rough": 0.0, "length": 300.0, "roads": false, "ramps": false},
	Region.BRIDGE: {"width": 3.8, "edge": Edge.FLOOR, "grip": 0.9, "rough": 0.0, "length": 280.0, "roads": false, "ramps": false},
	Region.ROOFS: {"width": 17.5, "edge": Edge.FLOOR, "grip": 1.0, "rough": 0.0, "length": 340.0, "roads": false, "ramps": false},
	Region.ICE_CAVE: {"width": 10.5, "edge": Edge.FLOOR, "grip": 0.28, "rough": 0.0, "length": 300.0, "roads": false, "ramps": false},
	Region.HARBOR: {"width": 18.0, "edge": Edge.FLOOR, "grip": 1.0, "rough": 0.0, "length": 320.0, "roads": false, "ramps": false},
	Region.SEWER: {"width": 7.0, "edge": Edge.FLOOR, "grip": 0.75, "rough": 0.0, "length": 340.0, "roads": false, "ramps": false},
}

const ZONE_LENGTH := 280.0
const ROAD_START := 520.0
const ROAD_SPACING := 470.0
const ROAD_HALF_WIDTH := 5.0
const ROAD_BLEND := 16.0
const RAMP_CELL := 110.0
const RAMP_LENGTH := 7.0
const RAMP_HALF_WIDTH := 2.4
const RAMP_HEIGHT := 1.6
const HUMP_CELL := 70.0
const ICE_CELL := 60.0
const PARK_RAMP_CELL := 45.0
const REGION_START := 800.0
const REGION_SPACING := 1400.0
## Share of region slots that actually hold a region.
const REGION_CHANCE := 0.8
const REGION_BLEND := 40.0
## Open water in lake regions: (offset from region start, length).
const LAKE_WATER := [Vector2(70.0, 26.0), Vector2(150.0, 32.0)]
const WATER_BLEND := 14.0
## The cliff: a calm snowfield, then at CLIFF_EDGE metres into the region a
## sheer face of CLIFF_FACE metres onto a steep landing hill that drops
## CLIFF_LAND more and levels out over CLIFF_RUNOUT, like a ski jump's.
## Everything beyond stays that much lower.
const CLIFF_EDGE := 110.0
const CLIFF_FACE := 26.0
const CLIFF_LAND := 36.0
const CLIFF_RUNOUT := 100.0
## Horizontal run of the sheer face.
const CLIFF_LIP := 1.2
## Snowy approaches narrow before the suspended span. The valley floor is
## separate from the rideable deck, so going over the railing means falling.
const BRIDGE_APPROACH := 50.0
const BRIDGE_HALF_WIDTH := 3.8
const BRIDGE_DEPTH := 34.0
const BRIDGE_SAG := 2.8
const BRIDGE_RAIL_HEIGHT := 1.25

const ROOF_APPROACH := 45.0
const ROOF_PERIOD := 42.0
const ROOF_GAP := 4.2
const ROOF_WIDE_GAP_MIN := 14.0
const ROOF_WIDE_GAP_MAX := 16.0
const ROOF_LANE := 11.5
const ROOF_HALF_WIDTH := 5.35
const ROOF_STREET_DEPTH := 12.0
const CAVE_INSET := 30.0
const HARBOR_INSET := 30.0
const HARBOR_QUAY_EDGE := 20.0
const HARBOR_ROUTE_X := -7.0
const HARBOR_ROUTE_HALF_WIDTH := 2.6
const HARBOR_ROUTE_HEIGHT := 4.0
const SEWER_INSET := 30.0
const SEWER_RADIUS := 8.0
## Distance, recommended passage offset; shared by barriers and breadcrumbs.
const SEWER_PASSAGES := [Vector2(30, 0), Vector2(78, 3.6), Vector2(130, -2.8), Vector2(182, -3.6), Vector2(234, 3.6), Vector2(282, 3.6), Vector2(310, 0)]

## One building's analytic footprint and snow surface. Meshes, collisions,
## pickups and recovery all use these same immutable seeded descriptors.
class Roof:
	var start := 0.0
	var finish := 0.0
	var lane := 0
	var index := 0
	var half_width := ROOF_HALF_WIDTH
	var cx := 0.0
	var dx := 0.0
	var y := 0.0
	var dy := 0.0
	var lift := 0.0
	var district := Vector2.ZERO
	var variant := 0
	var gap_after := 0.0
	var kick_height := 0.0
	var requires_jump: bool:
		get: return gap_after >= ROOF_WIDE_GAP_MIN - 0.01

	func center(d: float) -> float: return cx + (d - start) * dx
	func base(d: float) -> float: return y + (d - start) * dy

var _rooftops: Dictionary = {}
var world_seed: int
var _noise := FastNoiseLite.new()
var _phases := PackedFloat32Array()
# Per-cell lookups are pure functions of the seed, so they are memoized.
var _region_cells: Dictionary = {}
## Region cell -> total cliff drop of all the cells before it.
var _cliff_drops: Dictionary = {0: 0.0}
## The last region cell asked about (heights come in long runs from one
## cell), its slot and the cliff drop before it.
var _last_cell := -1
var _last_slot := Vector3.ZERO
var _last_drop := 0.0
var _roads: Dictionary = {}
var _ramps: Dictionary = {}
## Region kinds in a seeded order; slots walk through it so no kind repeats
## until all have been seen.
var _region_order := PackedInt32Array()


func _init(seed_value: int) -> void:
	world_seed = seed_value
	_noise.seed = seed_value
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.04
	_noise.fractal_octaves = 2
	for i in 8:
		_phases.append(hash01(i, 101) * TAU)
	var kinds := Array(REGION_STYLE.keys())
	kinds.sort_custom(func(a: int, b: int) -> bool: return hash01(a, 41) < hash01(b, 41))
	_region_order = PackedInt32Array(kinds)


func hash01(a: int, b: int) -> float:
	return float(hash(Vector3i(a, b, world_seed)) & 0xFFFFFF) / float(0xFFFFFF)


## 0 at the top, 1 after five kilometres.
func difficulty(d: float) -> float:
	return clampf(d / 5000.0, 0.0, 1.0)


func center_x(d: float) -> float:
	var x := _slope_center(d)
	var span := region_span(d)
	if int(span.z) in [Region.BRIDGE, Region.ROOFS, Region.HARBOR, Region.SEWER]:
		var approach := BRIDGE_APPROACH if int(span.z) == Region.BRIDGE else (ROOF_APPROACH if int(span.z) == Region.ROOFS else HARBOR_INSET)
		var ends := Vector2(span.x + approach, span.y - approach)
		var t := (d - ends.x) / (ends.y - ends.x)
		var straight := lerpf(_slope_center(ends.x), _slope_center(ends.y), t)
		x = lerpf(x, straight, smoothstep(span.x, ends.x, d) * (1.0 - smoothstep(ends.y, span.y, d)))
	# Forest trails wind back and forth between the trees.
	return x + region_weight(d, Region.WOODS) * 7.0 * sin(d * 0.03 + _phases[6]) + region_weight(d, Region.ICE_CAVE) * 4.0 * sin(d * 0.025 + _phases[7]) + region_weight(d, Region.SEWER) * 3.5 * sin(d * 0.024 + _phases[6])


func _slope_center(d: float) -> float:
	var amount := smoothstep(0.0, 300.0, d)
	return amount * (34.0 * sin(d * 0.0042 + _phases[0]) + 14.0 * sin(d * 0.0105 + _phases[1]) - 34.0 * sin(_phases[0]) - 14.0 * sin(_phases[1]))


func center_slope(d: float) -> float:
	return (center_x(d + 1.0) - center_x(d - 1.0)) * 0.5


func half_width(d: float) -> float:
	var hw := 20.0 + 5.0 * sin(d * 0.0031 + _phases[2]) - 6.0 * difficulty(d)
	var span := region_span(d)
	if span.z != Region.SLOPE:
		var width: float = cave_half_width(d) if int(span.z) == Region.ICE_CAVE else style(int(span.z)).width
		hw = lerpf(hw, width, _span_weight(span, d))
	return hw


# --- Special regions ---

## (start, end, kind) of the region slot that d falls in. Kind is SLOPE when
## the slot has no region or d lies outside it.
func region_span(d: float) -> Vector3:
	var cell := _region_cell(d)
	if cell < 0:
		return Vector3(0.0, 0.0, Region.SLOPE)
	var slot := _slot(cell)
	if d < slot.x or d >= slot.y:
		return Vector3(slot.x, slot.y, Region.SLOPE)
	return slot


func _region_cell(d: float) -> int:
	return int(floorf((d - REGION_START) / REGION_SPACING))


## (start, end, kind) of the region in slot `cell`; kind is SLOPE if empty.
func _slot(cell: int) -> Vector3:
	if not _region_cells.has(cell):
		var kind := _region_order[cell % _region_order.size()] if hash01(cell, 33) < REGION_CHANCE else Region.SLOPE
		var length: float = style(kind).length if kind != Region.SLOPE else 0.0
		var first := REGION_START + cell * REGION_SPACING + hash01(cell, 31) * (REGION_SPACING - length - 200.0)
		_region_cells[cell] = Vector3(first, first + length, kind)
	return _region_cells[cell]


# --- Cliffs ---

## How far the ground has dropped over cliffs by distance d: the cliffs
## already passed plus the one d is on, if any.
func cliff_drop(d: float) -> float:
	var cell := _region_cell(d)
	if cell < 0:
		return 0.0
	if cell != _last_cell:
		_last_cell = cell
		_last_slot = _slot(cell)
		_last_drop = _cliff_drop_before(cell)
	if int(_last_slot.z) != Region.CLIFF:
		return _last_drop
	return _last_drop + cliff_profile(d - _last_slot.x - CLIFF_EDGE)


## Drop of one cliff `s` metres past its edge: the sheer face, then the
## landing hill, steep at first and level at the bottom.
func cliff_profile(s: float) -> float:
	if s <= 0.0:
		return 0.0
	var face := CLIFF_FACE * smoothstep(0.0, CLIFF_LIP, s)
	var t := clampf((s - CLIFF_LIP) / CLIFF_RUNOUT, 0.0, 1.0)
	return face + CLIFF_LAND * (1.0 - (1.0 - t) * (1.0 - t))


## Distance of the cliff edge in the region at d, or INF when there is none.
func cliff_edge(d: float) -> float:
	var cell := _region_cell(d)
	if cell < 0:
		return INF
	var slot := _slot(cell)
	return slot.x + CLIFF_EDGE if int(slot.z) == Region.CLIFF else INF


## True from a little before a cliff's edge to the bottom of its landing
## hill, where nothing should stand in the way.
func in_cliff_fall(d: float, before := 25.0) -> bool:
	var edge := cliff_edge(d)
	return d > edge - before and d < edge + CLIFF_LIP + CLIFF_RUNOUT


func _cliff_drop_before(cell: int) -> float:
	if not _cliff_drops.has(cell):
		var last := cell - 1
		while not _cliff_drops.has(last):
			last -= 1
		for c in range(last + 1, cell + 1):
			var full := CLIFF_FACE + CLIFF_LAND if int(_slot(c - 1).z) == Region.CLIFF else 0.0
			_cliff_drops[c] = float(_cliff_drops[c - 1]) + full
	return _cliff_drops[cell]


func region(d: float) -> Region:
	return int(region_span(d).z) as Region


## 0 outside `which`, rising to 1 once you are well inside it.
func region_weight(d: float, which: Region) -> float:
	var span := region_span(d)
	return _span_weight(span, d) if int(span.z) == which else 0.0


func _span_weight(span: Vector3, d: float) -> float:
	if span.z == Region.SLOPE:
		return 0.0
	return smoothstep(span.x, span.x + REGION_BLEND, d) * (1.0 - smoothstep(span.y - REGION_BLEND, span.y, d))


# --- Swept corridors: rail yards and motorways ---

const SWEEP_LENGTH := 90.0
const SWEEP_REACH := 75.0
## Half width of the strip the tracks or lanes occupy.
const CORRIDOR := {Region.RAIL: 11.0, Region.HIGHWAY: 19.0}


## Sideways offset of a swept region's tracks or lanes at distance d: far
## out to one side at the start, centred in the middle, out the other side
## at the end.
func sweep(d: float) -> float:
	var span := region_span(d)
	if not CORRIDOR.has(int(span.z)):
		return 0.0
	var side := 1.0 if hash01(int(span.x), 51) < 0.5 else -1.0
	var arriving := 1.0 - smoothstep(span.x, span.x + SWEEP_LENGTH, d)
	var leaving := smoothstep(span.y - SWEEP_LENGTH, span.y, d)
	return side * SWEEP_REACH * (arriving - leaving)


## True within `margin` metres of the tracks or lanes of a swept region.
func in_corridor(x: float, d: float, margin := 0.0) -> bool:
	var kind := int(region_span(d).z)
	if not CORRIDOR.has(kind):
		return false
	return absf(x - center_x(d) - sweep(d)) < float(CORRIDOR[kind]) + margin


func style(kind: int) -> Dictionary:
	return REGION_STYLE.get(kind, {})


# --- Suspension bridge ---

## Deck endpoints, or ZERO off a bridge region (including its approaches).
func bridge_span(d: float) -> Vector2:
	var span := region_span(d)
	return Vector2(span.x + BRIDGE_APPROACH, span.y - BRIDGE_APPROACH) if int(span.z) == Region.BRIDGE else Vector2.ZERO


func on_bridge(d: float) -> bool:
	var ends := bridge_span(d)
	return ends != Vector2.ZERO and d >= ends.x and d <= ends.y


func _bridge_alignment(span: Vector3, d: float) -> float:
	return smoothstep(span.x, span.x + BRIDGE_APPROACH, d) * (1.0 - smoothstep(span.y - BRIDGE_APPROACH, span.y, d))


func _bridge_profile(ends: Vector2, d: float) -> float:
	var t := (d - ends.x) / (ends.y - ends.x)
	return lerpf(base_height(ends.x), base_height(ends.y), t) - 4.0 * BRIDGE_SAG * t * (1.0 - t)


func bridge_height(d: float) -> float:
	var ends := bridge_span(d)
	return _bridge_profile(ends, d) + 0.025 if ends != Vector2.ZERO else base_height(d)


func _bridge_normal(d: float) -> Vector3:
	return Vector3(0, 1, (bridge_height(d + 0.1) - bridge_height(d - 0.1)) / 0.2).normalized()


# --- Rooftop district ---

func roof_span(d: float) -> Vector2:
	var span := region_span(d)
	return Vector2(span.x + ROOF_APPROACH, span.y - ROOF_APPROACH) if int(span.z) == Region.ROOFS else Vector2.ZERO


func in_rooftops(d: float) -> bool:
	var ends := roof_span(d)
	return ends != Vector2.ZERO and d >= ends.x and d < ends.y


func roof_base_height(d: float) -> float:
	var ends := roof_span(d)
	return lerpf(base_height(ends.x), base_height(ends.y), (d - ends.x) / (ends.y - ends.x)) if ends != Vector2.ZERO else base_height(d)


func _roof_rows(span: Vector3) -> Array:
	if _rooftops.has(span.x): return _rooftops[span.x]
	var ends := Vector2(span.x + ROOF_APPROACH, span.y - ROOF_APPROACH)
	var x0 := _slope_center(ends.x)
	var x1 := _slope_center(ends.y)
	var y0 := base_height(ends.x)
	var y1 := base_height(ends.y)
	var rows := []
	for lane in [-1, 0, 1]:
		var row: Array[Roof] = []
		for i in range(-1, ceili((ends.y - ends.x) / ROOF_PERIOD) + 1):
			var start: float = ends.x + lane * 14.0 + i * ROOF_PERIOD
			# Stagger the large streets too, so another row remains available.
			var gap := lerpf(ROOF_WIDE_GAP_MIN, ROOF_WIDE_GAP_MAX, hash01(i + lane * 31, 197)) if posmod(i - lane, 3) == 1 else ROOF_GAP
			var finish := minf(start + ROOF_PERIOD - gap, ends.y)
			start = maxf(start, ends.x)
			if finish - start < 8.0: continue
			var roof := Roof.new()
			roof.start = start
			roof.finish = finish
			roof.lane = lane
			roof.index = i
			roof.district = ends
			roof.variant = int(hash01(i + lane * 31, int(span.x)) * 5.99)
			roof.lift = (hash01(i + lane * 31, 193) - 0.5) * 0.22
			row.append(roof)
		# First/last buildings meet the hill, without a gap at either entrance.
		row[0].start = ends.x
		row.back().finish = ends.y
		for i in row.size() - 1:
			row[i].gap_after = row[i + 1].start - row[i].finish
		for i in row.size() - 1:
			var roof := row[i]
			if not roof.requires_jump:
				roof.kick_height = 0.20 if lane == 0 else (0.38 if lane < 0 else 0.28)
				# Land early on the next roof, leaving room to time its big jump.
				if row[i + 1].requires_jump: roof.kick_height = 0.12
		for roof in row:
			roof.dx = (x1 - x0) / (ends.y - ends.x)
			roof.dy = (y1 - y0) / (ends.y - ends.x)
			roof.cx = x0 + (roof.start - ends.x) * roof.dx + lane * ROOF_LANE
			roof.y = y0 + (roof.start - ends.x) * roof.dy
		rows.append(row)
	_rooftops[span.x] = rows
	return rows


func roofs(d: float) -> Array[Roof]:
	var result: Array[Roof] = []
	var span := region_span(d)
	if int(span.z) == Region.ROOFS:
		for row: Array in _roof_rows(span): result.append_array(row)
	return result


func roof_at(x: float, d: float) -> Roof:
	var span := region_span(d)
	if int(span.z) != Region.ROOFS or d < span.x + ROOF_APPROACH or d >= span.y - ROOF_APPROACH: return null
	var lane := roundi((x - center_x(d)) / ROOF_LANE)
	if lane < -1 or lane > 1: return null
	for roof: Roof in _roof_rows(span)[lane + 1]:
		if d >= roof.start and d < roof.finish and absf(x - roof.center(d)) <= roof.half_width:
			return roof
	return null


func roof_height(roof: Roof, x: float, d: float) -> float:
	var lateral := absf(x - roof.center(d))
	var rise := 0.85 if roof.lane == 0 else (3.0 if roof.lane < 0 else 1.7)
	var flat := 3.2 if roof.lane == 0 else (0.18 if roof.lane < 0 else 1.1)
	var cross := rise * clampf((roof.half_width - lateral) / (roof.half_width - flat), 0, 1)
	var blend := smoothstep(roof.district.x, roof.district.x + 8, d) * (1.0 - smoothstep(roof.district.y - 12, roof.district.y, d))
	var kick := 0.0
	if roof.kick_height > 0.0:
		var u := clampf((d - roof.finish + 5.0) / 5.0, 0, 1)
		kick = roof.kick_height * u * u
	return roof.base(d) + (roof.lift + cross) * blend + kick + 0.035


func _roof_surface(roof: Roof, x: float, d: float) -> Vector4:
	var e := 0.08
	var h := roof_height(roof, x, d)
	# Stay on this building's analytic surface when differentiating near a gap.
	var hx := (roof_height(roof, x + e, d) - roof_height(roof, x - e, d)) / (2 * e)
	var before := clampf(d - e, roof.start, roof.finish)
	var after := clampf(d + e, roof.start, roof.finish)
	var hd := (roof_height(roof, x, after) - roof_height(roof, x, before)) / maxf(after - before, 0.001)
	var n := Vector3(-hx, 1, hd).normalized()
	return Vector4(n.x, n.y, n.z, h)


## A falling ride must not be lifted through a bridge or a building's roof.
func below_structure(at: Vector3) -> bool:
	var d := -at.z
	var kind := region(d)
	if kind == Region.BRIDGE:
		return on_bridge(d) and at.y < bridge_height(d) - 0.5
	if kind == Region.ROOFS:
		var roof := roof_at(at.x, d)
		return roof != null and at.y < roof_height(roof, at.x, d) - 0.5
	if kind == Region.HARBOR:
		var lift := harbor_surface_lift(at.x, d)
		return lift >= 0.0 and at.y < harbor_height(d) + lift - 0.5
	return false


## Safe centre-route position after a missed jump, never in a street gap.
func roof_recovery(d: float) -> float:
	var span := region_span(d)
	if int(span.z) != Region.ROOFS: return d
	var row: Array = _roof_rows(span)[1]
	for roof: Roof in row:
		if roof.finish > d + 8.0:
			return clampf(d, roof.start + 6.0, roof.finish - 8.0)
	return span.y - ROOF_APPROACH + 2.0


# --- Ice cavern ---

func cave_span(d: float) -> Vector2:
	var span := region_span(d)
	return Vector2(span.x + CAVE_INSET, span.y - CAVE_INSET) if int(span.z) == Region.ICE_CAVE else Vector2.ZERO


func in_cave(d: float) -> bool:
	var ends := cave_span(d)
	return ends != Vector2.ZERO and d >= ends.x and d <= ends.y


func cave_weight(d: float) -> float:
	var ends := cave_span(d)
	return smoothstep(ends.x, ends.x + 10, d) * (1 - smoothstep(ends.y - 10, ends.y, d)) if ends != Vector2.ZERO else 0.0


func cave_half_width(d: float) -> float:
	return 10.0 + 1.0 * sin(d * 0.035 + _phases[7])


func cave_vault_height(d: float) -> float:
	return 9.0 + 0.7 * sin(d * 0.055 + _phases[6])


func cave_arch_height(k: float, d: float) -> float:
	var angle := PI * k / 16.0
	return (cave_vault_height(d) + 1.1 * sin(k * 2.1 + d * 0.09) + 0.4 * sin(k * 0.9 - d * 0.04)) * sin(angle)


func cave_ceiling(x: float, d: float) -> float:
	var lx := clampf((x - center_x(d)) / cave_half_width(d), -1, 1)
	var k := acos(lx) * 16 / PI
	# Linear interpolation matches the facets that the player actually sees.
	var left := floorf(k)
	var t := inverse_lerp(cos(PI * left / 16), cos(PI * minf(left + 1, 16) / 16), lx) if left < 16 else 0.0
	return height(center_x(d), d, false) + lerpf(cave_arch_height(left, d), cave_arch_height(minf(left + 1, 16), d), t)


# --- Sewer: circular floor and ceiling use the same radius as the pipe ---

func sewer_span(d: float) -> Vector2:
	var span := region_span(d)
	return Vector2(span.x + SEWER_INSET, span.y - SEWER_INSET) if int(span.z) == Region.SEWER else Vector2.ZERO


func in_sewer(d: float) -> bool:
	var ends := sewer_span(d)
	return ends != Vector2.ZERO and d >= ends.x and d <= ends.y


func sewer_weight(d: float) -> float:
	var ends := sewer_span(d)
	return smoothstep(ends.x, ends.x + 10, d) * (1 - smoothstep(ends.y - 10, ends.y, d)) if ends != Vector2.ZERO else 0.0


func sewer_height(d: float) -> float:
	var ends := sewer_span(d)
	return lerpf(base_height(ends.x), base_height(ends.y), (d - ends.x) / (ends.y - ends.x)) if ends != Vector2.ZERO else base_height(d)


func sewer_floor(x: float, d: float) -> float:
	var lx := clampf(x - center_x(d), -SEWER_RADIUS + 0.01, SEWER_RADIUS - 0.01)
	return sewer_height(d) + SEWER_RADIUS - sqrt(SEWER_RADIUS * SEWER_RADIUS - lx * lx)


func sewer_ceiling(x: float, d: float) -> float:
	var lx := x - center_x(d)
	return sewer_height(d) + SEWER_RADIUS + sqrt(maxf(0, SEWER_RADIUS * SEWER_RADIUS - lx * lx))


func sewer_surface(x: float, d: float) -> Vector4:
	var lx := clampf(x - center_x(d), -7.99, 7.99)
	var across := lx / sqrt(SEWER_RADIUS * SEWER_RADIUS - lx * lx)
	var ends := sewer_span(d)
	var slope := (base_height(ends.y) - base_height(ends.x)) / (ends.y - ends.x)
	var normal := Vector3(-across, 1, slope - center_slope(d) * across).normalized()
	return Vector4(normal.x, normal.y, normal.z, sewer_floor(x, d))


func sewer_guide(d: float) -> float:
	var span := region_span(d)
	if int(span.z) != Region.SEWER: return 0.0
	var u := d - span.x
	for i in range(1, SEWER_PASSAGES.size()):
		var next: Vector2 = SEWER_PASSAGES[i]
		var previous: Vector2 = SEWER_PASSAGES[i - 1]
		if u <= next.x:
			return lerpf(previous.y, next.y, smoothstep(previous.x + 8, next.x - 8, u))
	return 0.0


# --- Container harbour ---

func harbor_span(d: float) -> Vector2:
	var span := region_span(d)
	return Vector2(span.x + HARBOR_INSET, span.y - HARBOR_INSET) if int(span.z) == Region.HARBOR else Vector2.ZERO


func in_harbor(d: float) -> bool:
	var ends := harbor_span(d)
	return ends != Vector2.ZERO and d >= ends.x and d <= ends.y


func harbor_height(d: float) -> float:
	var ends := harbor_span(d)
	return lerpf(base_height(ends.x), base_height(ends.y), (d - ends.x) / (ends.y - ends.x)) if ends != Vector2.ZERO else base_height(d)


func harbor_route_lift(d: float) -> float:
	var span := region_span(d)
	if int(span.z) != Region.HARBOR: return -1.0
	var u := d - span.x - 70.0
	if u < 0 or u > 80 or (u > 38 and u < 42): return -1.0
	if u < 22: return HARBOR_ROUTE_HEIGHT * u / 22
	if u > 58: return HARBOR_ROUTE_HEIGHT * (80 - u) / 22
	return HARBOR_ROUTE_HEIGHT


func harbor_gangway_x(d: float) -> float:
	var u := d - region_span(d).x - 160.0
	return lerpf(16, 22, smoothstep(0, 24, u)) - 6 * smoothstep(54, 78, u)


func on_harbor_gangway(x: float, d: float) -> bool:
	var span := region_span(d)
	return int(span.z) == Region.HARBOR and d >= span.x + 160 and d <= span.x + 238 and absf(x - center_x(d) - harbor_gangway_x(d)) <= 1.701


func harbor_surface_lift(x: float, d: float) -> float:
	if not in_harbor(d): return -1.0
	if on_harbor_gangway(x, d): return 0.25
	if absf(x - center_x(d) - HARBOR_ROUTE_X) <= HARBOR_ROUTE_HALF_WIDTH + 0.001:
		return harbor_route_lift(d)
	return -1.0


func harbor_tunnel_ceiling(x: float, d: float) -> float:
	if not in_harbor(d): return INF
	var span := region_span(d)
	if absf(x - center_x(d) - 5.5) > 2.3: return INF
	var center := span.x + 78
	while center < span.y - 48:
		if absf(d - center) <= 5.2: return harbor_height(d) + 4.22
		center += 62
	return INF


func harbor_water(x: float, d: float) -> bool:
	return in_harbor(d) and x - center_x(d) > HARBOR_QUAY_EDGE


func _harbor_surface(x: float, d: float, lift: float) -> Vector4:
	var ends := harbor_span(d)
	var slope := (base_height(ends.y) - base_height(ends.x)) / (ends.y - ends.x)
	if not on_harbor_gangway(x, d):
		var u := d - region_span(d).x - 70.0
		if u < 22: slope += HARBOR_ROUTE_HEIGHT / 22
		elif u > 58: slope -= HARBOR_ROUTE_HEIGHT / 22
	var n := Vector3(0, 1, slope).normalized()
	return Vector4(n.x, n.y, n.z, harbor_height(d) + lift + 0.035)


## Grip multiplier for the surface: patchy ice is glassy, frozen rivers,
## bandy rinks and polished mall floors slippery all over.
func grip_factor(x: float, d: float) -> float:
	if in_sewer(d): return 0.55 if absf(x - center_x(d)) < 1.3 else 1.1
	if is_ice(x, d):
		return 0.12
	var kind := region(d)
	if kind != Region.SLOPE and absf(x - center_x(d)) < half_width(d):
		return style(kind).grip
	return 1.0


# --- Open water (lakes) ---

## (start, end) of the open-water strip around d, or Vector2.ZERO.
func water_strip(d: float) -> Vector2:
	var span := region_span(d)
	if span.z != Region.LAKE:
		return Vector2.ZERO
	for water: Vector2 in LAKE_WATER:
		var start := span.x + water.x
		if d > start - WATER_BLEND - 1.0 and d < start + water.y + WATER_BLEND + 1.0:
			return Vector2(start, start + water.y)
	return Vector2.ZERO


func is_water(d: float) -> bool:
	var strip := water_strip(d)
	return strip != Vector2.ZERO and d >= strip.x and d <= strip.y


## Water lies level, at the height of the slope where the strip ends.
func water_level(strip: Vector2) -> float:
	return base_height(strip.y)


func track_dir(d: float) -> Vector3:
	return Vector3(center_slope(d), 0.0, -1.0).normalized()


func zone(d: float) -> Zone:
	var cell := int(floorf(d / ZONE_LENGTH))
	if cell <= 0:
		return Zone.OPEN
	var r := hash01(cell, 3)
	if r < 0.3:
		return Zone.OPEN
	if r < 0.52:
		return Zone.FOREST
	if r < 0.6:
		return Zone.MOGULS
	if r < 0.82:
		return Zone.VILLAGE
	return Zone.WILDLIFE


## Blend weight of `which` at distance d, fading in and out at zone edges.
func zone_weight(d: float, which: Zone) -> float:
	if zone(d) != which:
		return 0.0
	var local := fposmod(d, ZONE_LENGTH)
	return smoothstep(0.0, 40.0, local) * (1.0 - smoothstep(ZONE_LENGTH - 40.0, ZONE_LENGTH, local))


func bumpiness(d: float) -> float:
	var wave := 0.5 + 0.5 * sin(d * 0.013 + _phases[3])
	return wave * wave * wave * wave


func base_height(d: float) -> float:
	var descent := 0.30 * d - 400.0 * (1.0 - exp(-d / 4000.0))
	var rolls := 7.0 * sin(d * 0.0095 + _phases[4]) + 3.0 * sin(d * 0.023 + _phases[5])
	return -descent + rolls * smoothstep(0.0, 200.0, d) - cliff_drop(d)


func height(x: float, d: float, with_ramps := true, with_structures := true) -> float:
	var span := region_span(d)
	var weight := _span_weight(span, d)
	var look := style(int(span.z))
	var rough: float = look.rough if weight > 0.0 else 1.0
	var calm := 1.0 - weight * (1.0 - rough)
	var h := base_height(d)
	# Rails and roads run on smooth ground; the banks beside them stay.
	if weight > 0.0 and in_corridor(x, d, 8.0):
		calm = 0.0
	h += _noise.get_noise_2d(x, d) * (0.25 + 0.55 * bumpiness(d)) * calm
	var moguls := zone_weight(d, Zone.MOGULS) * (1.0 - weight)
	if moguls > 0.0:
		h += moguls * 0.45 * sin(x * 0.62 + d * 0.21) * sin(d * 0.47 - x * 0.18)
	h += hump(d) * calm
	var outside := absf(x - center_x(d)) - half_width(d)
	if outside > 0.0:
		var bank := 7.0 * smoothstep(0.0, 22.0, outside) + 0.08 * outside
		if weight > 0.0:
			var edge := bank
			match int(look.edge):
				Edge.KERB:
					# A kerb up to the pavement, flat under the buildings.
					edge = 0.3 * smoothstep(0.0, 0.3, outside) + maxf(outside - 16.0, 0.0) * 0.15
				Edge.GORGE:
					edge = 9.0 * smoothstep(0.0, 9.0, outside) + 0.1 * outside
				Edge.FLOOR:
					edge = 2.5 * smoothstep(0.0, 12.0, outside) + 0.05 * outside
			bank = lerpf(bank, edge, weight)
		h += bank
	var water := water_strip(d)
	if water != Vector2.ZERO:
		var gap := maxf(maxf(water.x - d, d - water.y), 0.0)
		h = lerpf(h, water_level(water), 1.0 - smoothstep(0.0, WATER_BLEND, gap))
	var road := nearest_road(d)
	var road_gap := absf(d - road)
	if road_gap < ROAD_HALF_WIDTH + ROAD_BLEND:
		var w := 1.0 - smoothstep(ROAD_HALF_WIDTH, ROAD_HALF_WIDTH + ROAD_BLEND, road_gap)
		h = lerpf(h, road_level(road), w)
	if with_ramps:
		h += ramp_height(x, d)
	if int(span.z) == Region.BRIDGE:
		var ends := Vector2(span.x + BRIDGE_APPROACH, span.y - BRIDGE_APPROACH)
		h += (_bridge_profile(ends, d) - base_height(d)) * _bridge_alignment(span, d)
		var valley := smoothstep(ends.x, ends.x + 22.0, d) * (1.0 - smoothstep(ends.y - 22.0, ends.y, d))
		h -= BRIDGE_DEPTH * valley
		if with_structures and d >= ends.x and d <= ends.y and absf(x - center_x(d)) <= BRIDGE_HALF_WIDTH:
			h = _bridge_profile(ends, d) + 0.025
	if int(span.z) == Region.ROOFS:
		var ends := Vector2(span.x + ROOF_APPROACH, span.y - ROOF_APPROACH)
		var alignment := smoothstep(span.x, ends.x, d) * (1.0 - smoothstep(ends.y, span.y, d))
		h += (roof_base_height(d) - base_height(d)) * alignment
		h -= ROOF_STREET_DEPTH * smoothstep(ends.x, ends.x + 16, d) * (1.0 - smoothstep(ends.y - 16, ends.y, d))
		if with_structures:
			var roof := roof_at(x, d)
			if roof != null: h = roof_height(roof, x, d)
	if int(span.z) == Region.HARBOR:
		var ends := Vector2(span.x + HARBOR_INSET, span.y - HARBOR_INSET)
		var alignment := smoothstep(span.x, ends.x, d) * (1 - smoothstep(ends.y, span.y, d))
		if x - center_x(d) >= -22 and x - center_x(d) <= HARBOR_QUAY_EDGE:
			h = lerpf(h, harbor_height(d), alignment)
		else:
			h += (harbor_height(d) - base_height(d)) * alignment
		if harbor_water(x, d): h = harbor_height(d) - 6.0
		if with_structures:
			var lift := harbor_surface_lift(x, d)
			if lift >= 0: h = harbor_height(d) + lift + 0.035
	if int(span.z) == Region.SEWER and absf(x - center_x(d)) < SEWER_RADIUS + 14:
		var ends := Vector2(span.x + SEWER_INSET, span.y - SEWER_INSET)
		var alignment := smoothstep(span.x, ends.x, d) * (1 - smoothstep(ends.y, span.y, d))
		var lateral := absf(x - center_x(d))
		# Snow banks outside the pipe meet its buried lower half gradually.
		var bank_blend := smoothstep(SEWER_RADIUS - 0.05, SEWER_RADIUS + 12, lateral)
		h = lerpf(h, lerpf(sewer_floor(x, d), h, bank_blend), alignment)
		if not with_structures: h -= 0.25 * alignment * (1 - smoothstep(SEWER_RADIUS - 0.2, SEWER_RADIUS + 0.2, lateral))
	return h


func height_world(x: float, z: float, with_structures := true) -> float:
	return height(x, -z, true, with_structures)


## Height and normal at a world point together: xyz is the normal and w the
## height. Three height lookups (one-sided differences) instead of the five
## that height_world and normal_world take apart; the ride's physics uses it
## several times a frame.
func surface_world(x: float, z: float, with_structures := true) -> Vector4:
	if in_sewer(-z) and absf(x - center_x(-z)) < SEWER_RADIUS - 0.1: return sewer_surface(x, -z)
	# Finite differences must not sample the ravine beside a deck edge and
	# turn a level plank into a near-vertical collision normal.
	if with_structures and on_bridge(-z) and absf(x - center_x(-z)) <= BRIDGE_HALF_WIDTH:
		var n := _bridge_normal(-z)
		return Vector4(n.x, n.y, n.z, bridge_height(-z))
	if with_structures:
		var roof := roof_at(x, -z)
		if roof != null: return _roof_surface(roof, x, -z)
		var lift := harbor_surface_lift(x, -z)
		if lift >= 0: return _harbor_surface(x, -z, lift)
	var e := 0.35
	var h := height_world(x, z, with_structures)
	var hx := (height_world(x + e, z, with_structures) - h) / e
	var hz := (height_world(x, z + e, with_structures) - h) / e
	var n := Vector3(-hx, 1.0, -hz).normalized()
	return Vector4(n.x, n.y, n.z, h)


func normal_world(x: float, z: float) -> Vector3:
	if in_sewer(-z) and absf(x - center_x(-z)) < SEWER_RADIUS - 0.1:
		var surface := sewer_surface(x, -z)
		return Vector3(surface.x, surface.y, surface.z)
	var lift := harbor_surface_lift(x, -z)
	if lift >= 0:
		var surface := _harbor_surface(x, -z, lift)
		return Vector3(surface.x, surface.y, surface.z)
	var roof := roof_at(x, -z)
	if roof != null:
		var surface := _roof_surface(roof, x, -z)
		return Vector3(surface.x, surface.y, surface.z)
	if on_bridge(-z) and absf(x - center_x(-z)) <= BRIDGE_HALF_WIDTH:
		return _bridge_normal(-z)
	var e := 0.35
	var hx := (height_world(x + e, z) - height_world(x - e, z)) / (2.0 * e)
	var hz := (height_world(x, z + e) - height_world(x, z - e)) / (2.0 * e)
	return Vector3(-hx, 1.0, -hz).normalized()


# --- Natural humps: ridges across the slope that throw you into the air ---

func hump(d: float) -> float:
	var cell := int(floorf(d / HUMP_CELL))
	if d < 150.0 or hash01(cell, 5) > 0.45:
		return 0.0
	var center := cell * HUMP_CELL + 20.0 + hash01(cell, 6) * 30.0
	if absf(center - nearest_road(center)) < 45.0:
		return 0.0
	var top := 0.7 + 1.3 * hash01(cell, 8)
	var width := 5.0 + 4.0 * hash01(cell, 9)
	var u := (d - center) / width
	if u < -1.6 or u > 0.6:
		return 0.0
	if u < 0.0:
		return top * smoothstep(-1.6, 0.0, u)
	return top * (1.0 - smoothstep(0.0, 0.6, u))


# --- Roads crossing the slope ---

const NO_ROAD := -1.0e9


## Distance of road `index`, or NO_ROAD when that road would cut through a
## river or snowpark (towns keep theirs as cross streets).
func road_at(index: int) -> float:
	if not _roads.has(index):
		_roads[index] = _compute_road(index)
	return _roads[index]


func _compute_road(index: int) -> float:
	var road := ROAD_START + index * ROAD_SPACING + (hash01(index, 11) - 0.5) * 140.0
	for probe in [road - 40.0, road, road + 40.0]:
		var kind := region(probe)
		if kind != Region.SLOPE and not style(kind).roads:
			return NO_ROAD
	var span := region_span(road)
	if span.z == Region.TOWN and (road < span.x + 70.0 or road > span.y - 70.0):
		return NO_ROAD
	return road


func nearest_road(d: float) -> float:
	var index := maxi(0, roundi((d - ROAD_START) / ROAD_SPACING))
	var best := NO_ROAD
	for other in [index - 1, index, index + 1]:
		if other >= 0:
			var candidate := road_at(other)
			if absf(candidate - d) < absf(best - d):
				best = candidate
	return best


func roads_between(d0: float, d1: float) -> Array[float]:
	var result: Array[float] = []
	var first := maxi(0, int(floorf((d0 - ROAD_START) / ROAD_SPACING)) - 1)
	for index in range(first, first + 4):
		var road := road_at(index)
		if road >= d0 and road < d1:
			result.append(road)
	return result


func road_level(road: float) -> float:
	return base_height(road)


func near_road(d: float, margin: float) -> bool:
	return absf(d - nearest_road(d)) < ROAD_HALF_WIDTH + margin


# --- Kicker ramps placed on the track ---

## Ramp layers: 0 is the occasional kicker anywhere on the slope, 1 is the
## dense set of jumps that only exists inside snowparks.
func ramp_cell_size(layer: int) -> float:
	return RAMP_CELL if layer == 0 else PARK_RAMP_CELL


## Returns (x, start_d, 1) for the ramp in this cell or z = 0 if there is none.
func ramp_in_cell(cell: int, layer := 0) -> Vector3:
	var key := cell * 2 + layer
	if not _ramps.has(key):
		_ramps[key] = _compute_ramp(cell, layer)
	return _ramps[key]


func _compute_ramp(cell: int, layer: int) -> Vector3:
	if cell < 2:
		return Vector3.ZERO
	var size := ramp_cell_size(layer)
	var start := cell * size + 12.0 + hash01(cell, 12 + layer * 40) * (size - 25.0)
	var kind := region(start)
	if layer == 0 and (hash01(cell, 7) > 0.6 or (kind != Region.SLOPE and not style(kind).ramps)):
		return Vector3.ZERO
	if layer == 1 and (kind != Region.PARK or region(start + RAMP_LENGTH + 10.0) != Region.PARK):
		return Vector3.ZERO
	if near_road(start, 40.0):
		return Vector3.ZERO
	var lateral := (hash01(cell, 13 + layer * 40) - 0.5) * 1.3 * half_width(start)
	return Vector3(center_x(start) + lateral, start, 1.0)


func ramp_profile(u: float) -> float:
	var t := clampf(u / RAMP_LENGTH, 0.0, 1.0)
	return RAMP_HEIGHT * t * t


func ramp_height(x: float, d: float) -> float:
	var total := 0.0
	for layer in 2:
		var ramp := ramp_in_cell(int(floorf(d / ramp_cell_size(layer))), layer)
		if ramp.z == 0.0:
			continue
		var u := d - ramp.y
		if u < 0.0 or u > RAMP_LENGTH:
			continue
		var lateral := absf(x - ramp.x)
		if lateral > RAMP_HALF_WIDTH:
			continue
		total = maxf(total, ramp_profile(u) * (1.0 - smoothstep(RAMP_HALF_WIDTH - 0.25, RAMP_HALF_WIDTH, lateral)))
	return total


func near_ramp(x: float, d: float, margin: float) -> bool:
	for layer in 2:
		var cell := int(floorf(d / ramp_cell_size(layer)))
		for candidate in [cell - 1, cell, cell + 1]:
			var ramp := ramp_in_cell(candidate, layer)
			if ramp.z != 0.0 and d > ramp.y - margin * 3.0 and d < ramp.y + RAMP_LENGTH + margin and absf(x - ramp.x) < RAMP_HALF_WIDTH + margin:
				return true
	return false


# --- Ice patches: shiny, slippery, no grip ---

func is_ice(x: float, d: float) -> bool:
	var cell := int(floorf(d / ICE_CELL))
	if cell < 4 or hash01(cell, 21) > 0.3 or region(d) != Region.SLOPE:
		return false
	var center_d := cell * ICE_CELL + 15.0 + hash01(cell, 22) * 30.0
	var center := center_x(center_d) + (hash01(cell, 23) - 0.5) * half_width(center_d)
	var dx := (x - center) / 5.5
	var dd := (d - center_d) / 9.0
	return dx * dx + dd * dd < 1.0
