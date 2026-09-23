class_name MaterialTable
extends RefCounted
## MaterialTable: what a mined rock is actually made of.
##
## A tile does not drop "one lump of copper". It breaks into GRAVEL: a mixture of
## worthless regolith plus some share of a target mineral. Copper comes from
## malachite, iron from hematite, and so on, so what you dig up is never the
## finished material -- refining it is a later job for a smelter rover.
##
## The KEY into this table is the tile's "drop_item_id" custom data, which the
## TileSet already carries. Adding a new ore stays a TileSet edit plus one line
## here; no other file needs to know the new material exists.

## The worthless bulk that every rock is mostly made of.
const REGOLITH := "regolith"

## Jetpack propellant. It is not dug up -- it is manufactured, and it lives in
## its own tank rather than the cargo hold -- but it is listed here with the
## rest so that its density and colour come from the same place as everything
## else, and so a future refinery can produce it as an ordinary material.
const PROPELLANT := "propellant"

## tile drop_item_id -> { material id : share of the rock, 0.0 to 1.0 }.
## Only the ore shares are listed: whatever is left over is regolith, so these
## do not have to add up to 1 by hand. A rock missing from this table is treated
## as pure regolith.
const COMPOSITIONS := {
	"regolith": {},
	"raw_copper": {"malachite": 0.25},
	"raw_iron": {"hematite": 0.30},
	"raw_cobalt": {"cobaltite": 0.15},
	"raw_carbon": {"graphite": 0.40},
}

## material id -> density in kg per litre (i.e. tonnes per m³), real values.
##
## This is the table that makes a full hold a DECISION rather than a number. The
## worthless bulk is light and the valuable ore is heavy, so a hold full of
## regolith still flies and a hold full of hematite pins you to the ground. Any
## sorting or concentrating the player does later makes the load MORE valuable
## and HEAVIER at the same time.
const DENSITIES := {
	"regolith": 1.5,   # loose, unconsolidated
	"graphite": 2.2,
	"malachite": 4.0,
	"hematite": 5.3,
	"cobaltite": 6.3,
	"propellant": 0.83,  # methalox at its usual mixture ratio: light, but not free
}

## Density for a material this table has never heard of: assume light rubble.
const UNKNOWN_DENSITY := 2.0

## material id -> the colour it shows as in the cargo meter.
const COLORS := {
	"regolith": Color(0.44, 0.39, 0.34),
	"malachite": Color(0.16, 0.66, 0.47),
	"hematite": Color(0.68, 0.26, 0.21),
	"cobaltite": Color(0.38, 0.48, 0.78),
	"graphite": Color(0.38, 0.38, 0.42),
	"propellant": Color(0.95, 0.62, 0.20),
}

## Colour for a material this table has never heard of.
const UNKNOWN_COLOR := Color(0.6, 0.6, 0.62)


## The ore shares of one rock type ({} for plain regolith). READ ONLY: this is
## the const dictionary itself, not a copy. Use sample_gravel() to get gravel
## you can keep.
static func ore_shares(rock_id: String) -> Dictionary:
	return COMPOSITIONS.get(rock_id, {})


## The colour a material draws as.
static func color(material_id: String) -> Color:
	return COLORS.get(material_id, UNKNOWN_COLOR)


## How heavy one litre of a material is, in kilograms.
static func density(material_id: String) -> float:
	return DENSITIES.get(material_id, UNKNOWN_DENSITY)


## "hematite" -> "Hematite". Godot's capitalize() also turns "raw_copper" into
## "Raw Copper", so ids never need a second table just to be readable.
static func display_name(material_id: String) -> String:
	return material_id.capitalize()


## Builds ONE rock's worth of gravel: a fresh { material id : units }.
##   rock_id     - the tile's drop_item_id
##   total_units - how much gravel a whole rock is worth (world.gravel_per_tile)
##   variation   - 0.0 to 1.0. How much richer or poorer THIS rock may be than
##                 the table says, so two tiles of the same ore are not identical.
##                 The regolith takes up whatever slack is left.
static func sample_gravel(rock_id: String, total_units: float, variation: float = 0.0) -> Dictionary:
	var shares: Dictionary = ore_shares(rock_id)
	var gravel := {}

	# Roll each ore's share for this particular rock.
	var ore_total := 0.0
	for material_id in shares:
		var share: float = float(shares[material_id])
		if variation > 0.0:
			share *= randf_range(1.0 - variation, 1.0 + variation)
		share = maxf(share, 0.0)
		gravel[material_id] = share
		ore_total += share

	# A lucky roll could push the ore past 100% of the rock. Scale it back so the
	# shares still describe one whole rock.
	if ore_total > 1.0:
		for material_id in gravel:
			gravel[material_id] = gravel[material_id] / ore_total
		ore_total = 1.0

	# Everything that is not ore is regolith.
	if ore_total < 1.0:
		gravel[REGOLITH] = 1.0 - ore_total

	# Turn shares (fractions of a rock) into units of gravel.
	for material_id in gravel:
		gravel[material_id] = gravel[material_id] * total_units

	return gravel
