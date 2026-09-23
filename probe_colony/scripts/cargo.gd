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
##
## EVERYTHING HERE IS MEASURED IN LITRES, because the hold is a physical tank and
## volume is what runs out. MASS is a separate consequence: materials have wildly
## different densities (regolith 1.5 kg/L, hematite 5.3), so two full holds can
## differ in weight by a factor of three. Volume stops you loading more; mass
## decides whether you can still move, and whether you can take off at all.

## Emitted whenever the contents change. The cargo meter redraws on it.
signal changed

## Volumes smaller than this are treated as nothing, so rounding dust from a
## partial pickup can't leave a material sitting in the hold at 0.000001 litres.
const MIN_LITRES := 0.0001

## How many litres fit in total, counting every material together.
## The player sets this from its own cargo_capacity (upgrades raise it).
var capacity: float = 1500.0

## material id -> litres held. A material at zero is removed, not kept at 0.
var amounts: Dictionary = {}


## Litres held right now, all materials added together.
func total() -> float:
	var sum := 0.0
	for material_id in amounts:
		sum += amounts[material_id]
	return sum


## Litres of room left.
func free_space() -> float:
	return maxf(capacity - total(), 0.0)


## Is there room for anything at all? Drops check this before flying to you.
func has_room() -> bool:
	return free_space() > MIN_LITRES


## What everything in the hold WEIGHS, in kilograms.
##
## Nothing here caps or checks it. The rover adds this to its own dry mass and
## lives with the result (see player.total_mass), which is the whole point: a
## hold can be perfectly legal by volume and still be too heavy to lift off.
func mass() -> float:
	var kg := 0.0
	for material_id in amounts:
		kg += amounts[material_id] * MaterialTable.density(material_id)
	return kg


## How full we are BY VOLUME, 0.0 to 1.0. This is what the meter's tank draws.
func fill_fraction() -> float:
	if capacity <= 0.0:
		return 1.0
	return clampf(total() / capacity, 0.0, 1.0)


## Litres of one material (0.0 if we have none).
func amount_of(material_id: String) -> float:
	return amounts.get(material_id, 0.0)


## Pours in a mixture ({ material id : litres }, as MaterialTable.sample_gravel
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
	if incoming <= MIN_LITRES:
		return {}

	var accepted_fraction: float = minf(free_space() / incoming, 1.0)
	var leftover := {}

	for material_id in mixture:
		var offered: float = mixture[material_id]
		var taken: float = offered * accepted_fraction
		if taken > MIN_LITRES:
			amounts[material_id] = amount_of(material_id) + taken
		var rest: float = offered - taken
		if rest > MIN_LITRES:
			leftover[material_id] = rest

	if accepted_fraction > 0.0:
		changed.emit()
	return leftover


## Takes litres of one material back out (for dumping, or later for feeding a
## smelter). Returns how much was actually removed, which is less than asked for
## if we did not have that much.
func take(material_id: String, litres: float) -> float:
	var held: float = amount_of(material_id)
	var removed: float = minf(litres, held)
	if removed <= MIN_LITRES:
		return 0.0

	if held - removed <= MIN_LITRES:
		amounts.erase(material_id)  # don't leave rounding dust behind
	else:
		amounts[material_id] = held - removed

	changed.emit()
	return removed


## Removes `litres` of material and returns what came out. The mirror of
## add_mixture: it takes proportionally from EVERYTHING in the hold, so pouring
## some of a mixed load out gives you a scoop of that mixture rather than
## whichever material happened to be first in the dictionary.
func take_mixture(litres: float) -> Dictionary:
	var held: float = total()
	if held <= MIN_LITRES or litres <= MIN_LITRES:
		return {}

	var fraction: float = minf(litres / held, 1.0)
	var out := {}

	for material_id in amounts.keys():
		var taken: float = amounts[material_id] * fraction
		if taken <= MIN_LITRES:
			continue
		out[material_id] = taken

		var left: float = amounts[material_id] - taken
		if left <= MIN_LITRES:
			amounts.erase(material_id)  # don't leave rounding dust behind
		else:
			amounts[material_id] = left

	if not out.is_empty():
		changed.emit()
	return out


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
