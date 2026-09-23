class_name CargoMeter
extends CanvasLayer
## CargoMeter: the cargo hold drawn as a TANK in the bottom-left of the screen.
##
## The hold is not a grid of slots, so it is deliberately not drawn like one.
## Material stacks up in coloured bands -- regolith at the bottom, ore above it
## -- and the level SLIDES up to meet the real number instead of jumping, so
## mining looks like sand being tipped into a tank. A legend beside the tank
## says which band is what.
##
## Display only: this reads cargo.gd and never changes it. Colours come from
## MaterialTable, so a new ore gets a band with no change here.
##
## Like the hotbar, everything is built in code out of plain rectangles. To use
## real art later, draw a tank texture in _on_draw() before the bands.

# --- Look (adjustable in the Inspector) --------------------------------------
## Whole widget, in pixels. The legend draws one line per material held and
## quietly stops at the bottom edge, so make this taller if you add enough ores
## to run out of room.
@export var panel_size: Vector2 = Vector2(216.0, 172.0)
@export var screen_margin: float = 16.0   # gap from the bottom-left corner
@export var padding: float = 10.0         # gap between panel edge and contents
@export var tank_width: float = 46.0
@export var legend_gap: float = 14.0      # space between tank and legend
@export var legend_line_height: float = 19.0

## How fast the drawn level chases the real one, in units per second. Lower =
## a slower, more visible pour. This is pure showmanship: the cargo data itself
## changes the instant a pebble is collected.
@export var pour_rate: float = 220.0

@export var panel_color: Color = Color(0.08, 0.08, 0.1, 0.8)
@export var border_color: Color = Color(0.35, 0.35, 0.4)
## Border colour once the hold is completely full.
@export var full_color: Color = Color(1.0, 0.55, 0.2)
@export var tank_empty_color: Color = Color(0.05, 0.05, 0.07, 0.9)
@export var text_color: Color = Color(0.85, 0.86, 0.9)

# --- Internals ---------------------------------------------------------------
var _cargo: Cargo = null
var _canvas: Control = null

## material id -> the amount currently being DRAWN, which lags behind the real
## amount in _cargo while the pour animation catches up.
var _shown: Dictionary = {}


## Call once (the player does this) to attach this meter to a cargo hold.
func setup(cargo: Cargo) -> void:
	# Build the UI before taking the cargo, so _process() (which skips everything
	# while _cargo is null) can never run against a half-built widget.
	_build()
	# Start already filled, so a hold that begins with something in it doesn't
	# pour itself in on the first frame.
	for material_id in cargo.amounts:
		_shown[material_id] = cargo.amounts[material_id]
	_cargo = cargo
	_canvas.queue_redraw()


# ---------------------------------------------------------------------------
# Building the UI (runs once)
# ---------------------------------------------------------------------------

func _build() -> void:
	# A full-screen invisible Control gives us something to anchor to.
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# The widget itself. We draw every part of it by hand in _on_draw().
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_canvas)

	# Pin it to the bottom-left corner, `screen_margin` pixels in from both edges.
	# Anchors 0/1 mean "measure from the left edge / from the bottom edge", and the
	# offsets are pixels from those. Spelled out rather than using an anchor preset
	# so the panel can't end up half off the bottom of the screen.
	_canvas.anchor_left = 0.0
	_canvas.anchor_right = 0.0
	_canvas.anchor_top = 1.0
	_canvas.anchor_bottom = 1.0
	_canvas.offset_left = screen_margin
	_canvas.offset_right = screen_margin + panel_size.x
	_canvas.offset_top = -screen_margin - panel_size.y
	_canvas.offset_bottom = -screen_margin

	# Godot calls the `draw` signal when the Control needs repainting; drawing
	# from a handler works exactly like drawing in the node's own _draw().
	_canvas.draw.connect(_on_draw)


# ---------------------------------------------------------------------------
# The pour animation
# ---------------------------------------------------------------------------

# Every frame, walk the drawn amounts toward the real ones. move_toward moves at
# a fixed rate (not a fraction of the remaining distance), so a big load pours
# for longer than a small one instead of every pour taking the same time.
func _process(delta: float) -> void:
	if _cargo == null:
		return

	var step: float = pour_rate * delta
	var changed := false

	# Materials in the hold: rise toward their real amount.
	for material_id in _cargo.amounts:
		var target: float = _cargo.amounts[material_id]
		var current: float = _shown.get(material_id, 0.0)
		if not is_equal_approx(current, target):
			_shown[material_id] = move_toward(current, target, step)
			changed = true

	# Materials no longer in the hold: drain to nothing, then stop drawing them.
	for material_id in _shown.keys():
		if _cargo.amounts.has(material_id):
			continue
		var drained: float = move_toward(_shown[material_id], 0.0, step)
		changed = true
		if drained <= Cargo.MIN_UNITS:
			_shown.erase(material_id)
		else:
			_shown[material_id] = drained

	if changed:
		_canvas.queue_redraw()


# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _on_draw() -> void:
	if _cargo == null:
		return

	var font: Font = _canvas.get_theme_default_font()
	var font_size: int = _canvas.get_theme_default_font_size()
	var frame_color: Color = full_color if not _cargo.has_room() else border_color

	# Panel behind everything.
	var panel := Rect2(Vector2.ZERO, _canvas.size)
	_canvas.draw_rect(panel, panel_color)
	_canvas.draw_rect(panel, frame_color, false, 3.0)

	# Header: "CARGO   84 / 150".
	var header_baseline: float = padding + font.get_ascent(font_size)
	_canvas.draw_string(font, Vector2(padding, header_baseline), "CARGO",
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
	_canvas.draw_string(font, Vector2(padding, header_baseline),
		"%d / %d" % [roundi(_cargo.total()), roundi(_cargo.capacity)],
		HORIZONTAL_ALIGNMENT_RIGHT, _canvas.size.x - padding * 2.0, font_size, text_color)

	# The tank sits under the header and runs to the bottom of the panel.
	var top: float = padding + font.get_height(font_size) + 6.0
	var tank := Rect2(padding, top, tank_width, _canvas.size.y - top - padding)
	_draw_tank(tank, frame_color)
	_draw_legend(Vector2(tank.end.x + legend_gap, top), font, font_size)


# The tank: a dark well, the stacked material bands, then a frame on top so the
# bands look contained by it.
func _draw_tank(tank: Rect2, frame_color: Color) -> void:
	_canvas.draw_rect(tank, tank_empty_color)

	# Bands are drawn inside the frame, and stack upward from the tank floor.
	var inside: Rect2 = tank.grow(-2.0)
	var y: float = inside.end.y

	for material_id in _sorted_shown():
		var units: float = _shown[material_id]
		var height: float = inside.size.y * (units / _cargo.capacity) if _cargo.capacity > 0.0 else 0.0
		if height <= 0.0:
			continue
		y -= height
		_canvas.draw_rect(Rect2(inside.position.x, y, inside.size.x, height),
			MaterialTable.color(material_id))

	_canvas.draw_rect(tank, frame_color, false, 2.0)


# One line per material: a colour swatch matching its band, its name, and how
# much of it we hold. Listed top-down in the same order the bands stack upward,
# so the top line is the top band.
func _draw_legend(start: Vector2, font: Font, font_size: int) -> void:
	var order: Array = _sorted_shown()
	order.reverse()

	var swatch_size := 10.0
	var line := 0

	for material_id in order:
		var y: float = start.y + line * legend_line_height
		if y + legend_line_height > _canvas.size.y - padding:
			break  # ran out of panel; don't spill over the edge

		var swatch_y: float = y + (legend_line_height - swatch_size) / 2.0
		_canvas.draw_rect(Rect2(start.x, swatch_y, swatch_size, swatch_size),
			MaterialTable.color(material_id))

		var text_x: float = start.x + swatch_size + 6.0
		var baseline: float = y + font.get_ascent(font_size)
		_canvas.draw_string(font, Vector2(text_x, baseline),
			MaterialTable.display_name(material_id),
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
		_canvas.draw_string(font, Vector2(text_x, baseline),
			str(roundi(_cargo.amount_of(material_id))),
			HORIZONTAL_ALIGNMENT_RIGHT, _canvas.size.x - padding - text_x, font_size, text_color)

		line += 1


# The drawn materials in the hold's stable order (regolith first), plus any that
# are still draining away after being removed.
func _sorted_shown() -> Array:
	var order: Array = _cargo.sorted_materials()
	for material_id in _shown:
		if not order.has(material_id):
			order.append(material_id)
	return order
