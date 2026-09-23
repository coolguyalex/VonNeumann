class_name Units
extends RefCounted
## Units: the one place that decides how big the world is.
##
## The game is tuned in REAL units -- metres, seconds, kilograms, newtons -- and
## only converts to pixels at the last moment. That way a mass or a thrust in the
## Inspector means something you can sanity-check against a real machine, instead
## of being a magic pixel number.
##
## THE SCALE
##   One tile is 40 pixels and represents HALF A METRE, so there are 80 pixels to
##   the metre. That number is not arbitrary: it is what makes the mass system
##   work. At 1 tile = 1m a tile of regolith would weigh 1.5 tonnes -- more than
##   the whole rover -- so a hold big enough to be fun would need a 40-tonne
##   mining truck to carry it. At half a metre a tile is about 190kg, the rover
##   is a believable 1.4m machine, and a hold still takes a dozen tiles.
##
## To change the world's scale or gravity, change it HERE and nowhere else.

## How many pixels represent one metre.
const PIXELS_PER_METER := 80.0

## One tile's edge length, in metres. (Tiles are 40px; 40 / 80 = 0.5.)
const TILE_METERS := 0.5

## Surface gravity, m/s². Mars is 3.71; Earth is 9.81, Luna 1.62.
const GRAVITY_MS2 := 3.71

## The same gravity in pixels/s², which is what the movement code actually uses.
const GRAVITY_PX := GRAVITY_MS2 * PIXELS_PER_METER


## Metres -> pixels. Use for distances and speeds read from the Inspector.
static func m_to_px(meters: float) -> float:
	return meters * PIXELS_PER_METER


## Pixels -> metres. Use when reporting a distance to the player or a program.
static func px_to_m(pixels: float) -> float:
	return pixels / PIXELS_PER_METER


## An acceleration in m/s² -> pixels/s², e.g. thrust/mass before applying it.
static func accel_to_px(meters_per_s2: float) -> float:
	return meters_per_s2 * PIXELS_PER_METER


## Volume of one whole tile in LITRES: the amount of gravel a mined rock is
## worth. (0.5m cubed = 0.125 m³ = 125 litres.)
static func tile_liters() -> float:
	return TILE_METERS * TILE_METERS * TILE_METERS * 1000.0


## Kilograms as a short human string: "820 kg" under a tonne, "3.45 t" above.
static func mass_text(kg: float) -> String:
	if kg < 1000.0:
		return "%d kg" % roundi(kg)
	return "%.2f t" % (kg / 1000.0)
