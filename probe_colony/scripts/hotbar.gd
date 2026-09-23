class_name Hotbar
extends CanvasLayer
## Hotbar: the row of 10 inventory slots along the top of the screen.
##
## A CanvasLayer draws on top of the game and does NOT move with the camera,
## which is what we want for UI. This script only DISPLAYS the inventory
## (inventory.gd) and turns the hotbar_* actions (number keys) into "select slot" calls.
##
## This is a real node in player.tscn, so the settings below show in the Inspector.
## Everything is built in code, using plain colored boxes as placeholders.
## TO USE REAL ART LATER: in _make_slot(), swap the StyleBoxFlat boxes for
## StyleBoxTexture ones (one texture for normal, one for selected).

# --- Look (adjustable in the Inspector) --------------------------------------
@export var slot_size: float = 56.0        # each square slot, in pixels
@export var slot_gap: float = 6.0          # space between slots
@export var top_margin: float = 10.0       # space above the row
@export var icon_padding: float = 6.0      # space between slot edge and icon
@export var normal_color: Color = Color(0.35, 0.35, 0.4)   # border, unselected
@export var selected_color: Color = Color(1.0, 0.85, 0.2)  # border, selected

# --- Internals ---------------------------------------------------------------
var _inventory: Inventory = null
var _slot_panels: Array[Panel] = []        # the box for each slot
var _slot_icons: Array[TextureRect] = []   # the item picture inside each slot
var _normal_style: StyleBoxFlat            # box style for an unselected slot
var _selected_style: StyleBoxFlat          # box style for the selected slot


## Call once (the player does this) to attach this hotbar to an inventory.
func setup(inventory: Inventory) -> void:
	_inventory = inventory
	_make_styles()
	_build_slots()
	# Whenever the inventory data changes, redraw.
	_inventory.changed.connect(_refresh)

	# DEFERRED on purpose. Icons come from the World, which joins the "world"
	# group in its own _ready() -- and a parent's _ready() runs AFTER its
	# children's, so during our setup the World cannot be found yet and every
	# icon would resolve to null. Deferring puts this first draw after the whole
	# tree is ready. (Without it the slots looked empty until you pressed a
	# number key, because only the next inventory change redrew them.)
	_refresh.call_deferred()


# ---------------------------------------------------------------------------
# Building the UI (runs once)
# ---------------------------------------------------------------------------

# Creates the two box looks: normal and selected. They differ only in border color.
func _make_styles() -> void:
	_normal_style = _make_box(normal_color)
	_selected_style = _make_box(selected_color)


# One slot box: dark translucent fill with a coloured border and rounded corners.
func _make_box(border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.08, 0.08, 0.1, 0.8)
	box.border_color = border
	box.set_border_width_all(3)
	box.set_corner_radius_all(4)
	return box


func _build_slots() -> void:
	# A full-screen invisible Control gives us something to anchor the row to.
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE  # don't eat mouse clicks
	add_child(root)

	# HBoxContainer lines its children up left-to-right for us.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(slot_gap))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(row)

	for i in Inventory.SLOT_COUNT:
		row.add_child(_make_slot(i))

	# Pin the row to the top-centre of the screen. Done AFTER adding the slots so
	# the row already knows its own width when it centres itself.
	row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, int(top_margin))


# Builds one slot: a box, the item picture inside it, and the key number label.
func _make_slot(index: int) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(slot_size, slot_size)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _normal_style)

	# The item picture. Filled in by _refresh(). NEAREST keeps pixel art crisp.
	var icon := TextureRect.new()
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, int(icon_padding))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(icon)

	# The key number in the corner. Slot 0 is key "1", ..., slot 9 is key "0".
	var label := Label.new()
	label.text = str((index + 1) % 10)
	label.position = Vector2(5, 1)
	label.add_theme_font_size_override("font_size", 12)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)

	_slot_panels.append(panel)
	_slot_icons.append(icon)
	return panel


# ---------------------------------------------------------------------------
# Updating the UI (runs whenever the inventory changes)
# ---------------------------------------------------------------------------

func _refresh() -> void:
	# Icons come from the world (see world.item_icon). Looked up here rather than
	# stored, so it works no matter which node finished loading first.
	var world := get_tree().get_first_node_in_group("world")

	for i in Inventory.SLOT_COUNT:
		# Show the item's picture, or nothing if the slot is empty.
		var item_id := _inventory.get_item(i)
		_slot_icons[i].texture = world.item_icon(item_id) if (world != null and item_id != "") else null

		# Highlight the selected slot by swapping its box style.
		var style := _selected_style if i == _inventory.selected else _normal_style
		_slot_panels[i].add_theme_stylebox_override("panel", style)


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

# Godot calls this for input nothing else has used. The actions hotbar_1 ...
# hotbar_10 are defined in Project Settings > Input Map (keys 1-9 and 0), so they
# can be rebound without touching this code.
func _unhandled_input(event: InputEvent) -> void:
	for i in Inventory.SLOT_COUNT:
		# "hotbar_" + (i + 1): slot 0 listens for hotbar_1, slot 9 for hotbar_10.
		if event.is_action_pressed("hotbar_%d" % (i + 1)):
			_inventory.select(i)
			return
