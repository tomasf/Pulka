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
enum Region { SLOPE, TOWN, RIVER, PARK, WOODS, MALL, RAIL, AIRPORT, LAKE, BANDY, HIGHWAY, CLIFF }
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
	var amount := smoothstep(0.0, 300.0, d)
	var x := amount * (34.0 * sin(d * 0.0042 + _phases[0]) + 14.0 * sin(d * 0.0105 + _phases[1]) - 34.0 * sin(_phases[0]) - 14.0 * sin(_phases[1]))
	# Forest trails wind back and forth between the trees.
	return x + region_weight(d, Region.WOODS) * 7.0 * sin(d * 0.03 + _phases[6])


func center_slope(d: float) -> float:
	return (center_x(d + 1.0) - center_x(d - 1.0)) * 0.5


func half_width(d: float) -> float:
	var hw := 20.0 + 5.0 * sin(d * 0.0031 + _phases[2]) - 6.0 * difficulty(d)
	var span := region_span(d)
	if span.z != Region.SLOPE:
		hw = lerpf(hw, style(int(span.z)).width, _span_weight(span, d))
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


## Grip multiplier for the surface: patchy ice is glassy, frozen rivers,
## bandy rinks and polished mall floors slippery all over.
func grip_factor(x: float, d: float) -> float:
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


func height(x: float, d: float, with_ramps := true) -> float:
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
	return h


func height_world(x: float, z: float) -> float:
	return height(x, -z)


## Height and normal at a world point together: xyz is the normal and w the
## height. Three height lookups (one-sided differences) instead of the five
## that height_world and normal_world take apart; the ride's physics uses it
## several times a frame.
func surface_world(x: float, z: float) -> Vector4:
	var e := 0.35
	var h := height_world(x, z)
	var hx := (height_world(x + e, z) - h) / e
	var hz := (height_world(x, z + e) - h) / e
	var n := Vector3(-hx, 1.0, -hz).normalized()
	return Vector4(n.x, n.y, n.z, h)


func normal_world(x: float, z: float) -> Vector3:
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
