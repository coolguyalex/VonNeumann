class_name Cargo
extends RefCounted
## Cargo: the hold that gathered material is poured into. DATA only, no visuals.
##
## The hotbar (inventory.gd) and the hold are two different things on purpose:
##   hotbar - 10 slots, one TOOL or item each. You pick things up and carry them.
##   hold   - a TANK. Gravel from mining goes in here and stacks up as a level,
##            not as slots, so a few pebbles can never fill your tool bar.
##
## There is one running total per material and ONE capacity they all share, so
## filling up on regolith really does leave no room for copper. Nothing in here
## knows what any material IS, so a new ore needs no change in this file.

## Emitted whenever the contents change. The cargo meter redraws on it.
signal changed

## Amounts smaller than this are treated as nothing, so rounding dust from a
## partial pickup can't leave a material sitting in the hold at 0.000001 units.
const MIN_UNITS := 0.0001

## How many units fit in total, counting every material together.
## The player sets this from its own cargo_capacity (upgrades raise it).
var capacity: float = 150.0

## material id -> units held. A material at zero is removed, not kept at 0.
var amounts: Dictionary = {}


## Units held right now, all materials added together.
func total() -> float:
	var sum := 0.0
	for material_id in amounts:
		sum += amounts[material_id]
	return sum


## Units of room left.
func free_space() -> float:
	return maxf(capacity - total(), 0.0)


## Is there room for anything at all? Drops check this before flying to you.
func has_room() -> bool:
	return free_space() > MIN_UNITS


## How full we are, 0.0 to 1.0. This is what the meter draws.
func fill_fraction() -> float:
	if capacity <= 0.0:
		return 1.0
	return clampf(total() / capacity, 0.0, 1.0)


## Units of one material (0.0 if we have none).
func amount_of(material_id: String) -> float:
	return amounts.get(material_id, 0.0)


## Pours in a mixture ({ material id : units }, as MaterialTable.sample_gravel
## builds it) and returns WHATEVER DID NOT FIT, in the same form. An empty
## return means all of it went in.
##
## When the hold is nearly full, every material in the load is cut back by the
## SAME proportion. Taking "whatever fits, first material first" would quietly
## sort the load by dictionary order and hand the player pure regolith on the
## last scoop; scaling the whole load keeps a scoop of gravel a scoop of gravel.
func add_mixture(mixture: Dictionary) -> Dictionary:
	var incoming := 0.0
	for material_id in mixture:
		incoming += mixture[material_id]
	if incoming <= MIN_UNITS:
		return {}

	var accepted_fraction: float = minf(free_space() / incoming, 1.0)
	var leftover := {}

	for material_id in mixture:
		var offered: float = mixture[material_id]
		var taken: float = offered * accepted_fraction
		if taken > MIN_UNITS:
			amounts[material_id] = amount_of(material_id) + taken
		var rest: float = offered - taken
		if rest > MIN_UNITS:
			leftover[material_id] = rest

	if accepted_fraction > 0.0:
		changed.emit()
	return leftover


## Takes units of one material back out (for dumping, or later for feeding a
## smelter). Returns how much was actually removed, which is less than asked for
## if we did not have that much.
func take(material_id: String, units: float) -> float:
	var held: float = amount_of(material_id)
	var removed: float = minf(units, held)
	if removed <= MIN_UNITS:
		return 0.0

	if held - removed <= MIN_UNITS:
		amounts.erase(material_id)  # don't leave rounding dust behind
	else:
		amounts[material_id] = held - removed

	changed.emit()
	return removed


## The materials we hold, in a STABLE draw order: regolith first (it is the bulk,
## so it sits at the bottom of the tank), then everything else alphabetically.
## Without a fixed order the bands in the meter would shuffle on every pickup.
func sorted_materials() -> Array:
	var ores: Array = []
	for material_id in amounts:
		if material_id != MaterialTable.REGOLITH:
			ores.append(material_id)
	ores.sort()

	if amounts.has(MaterialTable.REGOLITH):
		ores.push_front(MaterialTable.REGOLITH)
	return ores
