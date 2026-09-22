class_name Inventory
extends RefCounted
## Inventory: the DATA for what the player is carrying. No visuals in here.
##
## There are 10 slots and each holds at most ONE item (no stacking). A slot is
## just a String: the item's id (like "raw_copper"), or "" when empty.
## The hotbar (hotbar.gd) watches the `changed` signal and redraws itself, so
## anything that changes the inventory only has to change the data here.

## Emitted whenever slot contents OR the selected slot change.
signal changed

## How many slots there are. The hotbar draws this many boxes.
const SLOT_COUNT := 10

## The contents. slots[0] is the leftmost slot. "" means empty.
var slots: Array[String] = []

## Index (0-9) of the highlighted slot.
var selected: int = 0


func _init() -> void:
	# Make SLOT_COUNT entries, all empty.
	slots.resize(SLOT_COUNT)
	slots.fill("")


## Puts one item in the first empty slot.
## Returns true if it fit, false if every slot is full (nothing is changed).
func add_item(item_id: String) -> bool:
	for i in SLOT_COUNT:
		if slots[i] == "":
			slots[i] = item_id
			changed.emit()
			return true
	return false


## True if at least one slot is empty (so add_item would succeed).
func has_room() -> bool:
	return "" in slots


## The item id in a slot ("" if empty).
func get_item(index: int) -> String:
	return slots[index]


## Removes and returns the item in a slot ("" if it was already empty).
func take_item(index: int) -> String:
	var item_id: String = slots[index]
	if item_id != "":
		slots[index] = ""
		changed.emit()
	return item_id


## Highlights a slot. Ignores numbers outside 0..SLOT_COUNT-1.
func select(index: int) -> void:
	if index < 0 or index >= SLOT_COUNT or index == selected:
		return
	selected = index
	changed.emit()
