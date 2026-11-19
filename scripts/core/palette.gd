class_name Palette
extends RefCounted
## Shared colors and the single vertex-colored material used by all geometry.

const SNOW := Color(0.97, 0.98, 1.0)
const SNOW_PACKED := Color(0.9, 0.93, 0.98)
const SNOW_EDGE := Color(0.84, 0.89, 0.97)
const ICE := Color(0.66, 0.82, 0.97)
const TRUNK := Color(0.36, 0.24, 0.16)
const SPRUCE := [Color(0.13, 0.33, 0.22), Color(0.1, 0.28, 0.2), Color(0.17, 0.38, 0.24)]
const ROCK := Color(0.45, 0.46, 0.5)
## Skin tones from very fair to deep brown, and hair colours. A look pairs
## one of each (see `look`).
const SKINS := [
	Color(0.98, 0.85, 0.75), Color(0.96, 0.78, 0.66), Color(0.9, 0.7, 0.56), Color(0.82, 0.6, 0.45),
	Color(0.72, 0.5, 0.35), Color(0.6, 0.4, 0.27), Color(0.47, 0.3, 0.2), Color(0.36, 0.23, 0.15),
]
const HAIR := [
	Color(0.07, 0.05, 0.04), Color(0.18, 0.11, 0.07), Color(0.42, 0.26, 0.14),
	Color(0.72, 0.56, 0.32), Color(0.62, 0.27, 0.12), Color(0.62, 0.62, 0.64),
]
const LOOK_COUNT := 48
const FALU_RED := Color(0.62, 0.13, 0.1)
const WINDOW_LIGHT := Color(1.0, 0.82, 0.45, 0.0)
const HEADLIGHT := Color(1.0, 0.97, 0.85, 0.0)
const TAILLIGHT := Color(1.0, 0.1, 0.05, 0.0)
const ASPHALT := Color(0.24, 0.25, 0.28)
const JACKETS := [
	Color(0.9, 0.2, 0.2), Color(0.15, 0.45, 0.85), Color(0.98, 0.75, 0.1), Color(0.2, 0.7, 0.35),
	Color(0.85, 0.35, 0.75), Color(1.0, 0.5, 0.1), Color(0.15, 0.75, 0.8), Color(0.35, 0.3, 0.75),
]
const CARS := [
	Color(0.8, 0.12, 0.1), Color(0.12, 0.3, 0.7), Color(0.92, 0.92, 0.9), Color(0.15, 0.15, 0.17),
	Color(0.2, 0.55, 0.3), Color(0.95, 0.7, 0.1), Color(0.55, 0.6, 0.65),
]

static var _surface: ShaderMaterial


static func surface() -> ShaderMaterial:
	if _surface == null:
		_surface = ShaderMaterial.new()
		_surface.shader = load("res://shaders/surface.gdshader")
	return _surface


## Skin, cheek and hair colours for look `index` (any int, wrapping round
## LOOK_COUNT), by the people models' material names.
static func look(index: int) -> Dictionary:
	var skin: Color = SKINS[posmod(index, SKINS.size())]
	var hair: Color = HAIR[posmod(index / SKINS.size(), HAIR.size())]
	return {"skin": skin, "cheek": skin.lerp(Color(0.92, 0.42, 0.4), 0.3), "hair": hair}


static func random_look(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(0, LOOK_COUNT - 1)


static func pick(colors: Array, rng: RandomNumberGenerator) -> Color:
	return colors[rng.randi_range(0, colors.size() - 1)]
