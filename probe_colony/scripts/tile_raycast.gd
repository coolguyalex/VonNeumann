class_name TileRaycast
extends RefCounted
## TileRaycast: "what is the first tile I'd hit if I shot a line from A toward B?"
##
## This is a helper with one function and no state, so you never create one.
## Call it directly from anywhere:
##     var cell = TileRaycast.first_tile(tile_map, from_pos, to_pos, max_reach)
##
## Used by the player to decide which tile the mouse is "pointing at".
## Anything hidden behind that first tile can't be targeted.

## Returned when the line reaches max_reach without hitting any tile.
## (A huge coordinate that will never be a real tile.)
const NO_TARGET := Vector2i(2147483647, 2147483647)


## Walks a straight line from `from` toward `to` (world coordinates) for at most
## `max_reach` pixels. Returns the grid cell of the first occupied tile it enters,
## or NO_TARGET if there is none.
##
## HOW IT WORKS (the "DDA" grid walk):
## The obvious way is to check a point every few pixels along the line, but that
## can jump right over a tile's corner (the line slips between two tiles that only
## touch diagonally). Instead we step from grid line to grid line, always moving
## into whichever neighbouring cell the ray reaches next. That visits EVERY cell
## the line passes through, so nothing gets skipped.
##
## Assumes square tiles.
static func first_tile(tile_map: TileMapLayer, from: Vector2, to: Vector2, max_reach: float) -> Vector2i:
	var tile_size: float = tile_map.tile_set.tile_size.x

	# Work in "tile units" (1.0 = one tile wide) to make the math simple.
	# to_local() converts a world position into the tile map's own coordinates.
	var origin: Vector2 = tile_map.to_local(from) / tile_size
	var dir: Vector2 = tile_map.to_local(to) / tile_size - origin

	# If the mouse is exactly on the player there is no direction to shoot in.
	if dir.is_zero_approx():
		return NO_TARGET
	dir = dir.normalized()  # length 1, so "distance along the ray" is honest
	var max_t: float = max_reach / tile_size  # reach, also in tile units

	# The cell the ray starts in.
	var cell := Vector2i(floori(origin.x), floori(origin.y))

	# Which way we move on each axis: +1 (right/down) or -1 (left/up).
	var step := Vector2i(1 if dir.x > 0.0 else -1, 1 if dir.y > 0.0 else -1)

	# t_delta: how far ALONG THE RAY we travel to cross one whole cell, per axis.
	# A ray heading straight up never crosses a vertical grid line, so that axis is
	# INF (infinity = "never").
	var t_delta := Vector2(
		absf(1.0 / dir.x) if dir.x != 0.0 else INF,
		absf(1.0 / dir.y) if dir.y != 0.0 else INF)

	# t_max: how far along the ray until we hit the NEXT vertical / horizontal grid
	# line. Whichever is smaller is the boundary we cross next.
	var t_max := Vector2(
		((cell.x + 1 - origin.x) if step.x > 0 else (origin.x - cell.x)) * t_delta.x if dir.x != 0.0 else INF,
		((cell.y + 1 - origin.y) if step.y > 0 else (origin.y - cell.y)) * t_delta.y if dir.y != 0.0 else INF)

	# t = how far along the ray we were when we entered the current cell.
	var t: float = 0.0
	while t <= max_t:
		# 1. Is the cell we're standing in a tile? Then that's our target.
		if _is_occupied(tile_map, cell):
			return cell

		# 2. Otherwise step into the next cell.
		if is_equal_approx(t_max.x, t_max.y):
			# Special case: the ray passes EXACTLY through a corner where four
			# tiles meet. Look at both cells beside the corner first. Without this
			# check the ray could squeeze between two diagonal tiles.
			var side_x := Vector2i(cell.x + step.x, cell.y)
			var side_y := Vector2i(cell.x, cell.y + step.y)
			if _is_occupied(tile_map, side_x):
				return side_x
			if _is_occupied(tile_map, side_y):
				return side_y
			# Both sides empty, so it's safe to move diagonally.
			t = t_max.x
			t_max += t_delta
			cell += step
		elif t_max.x < t_max.y:
			# We cross a VERTICAL grid line first: move one cell left/right.
			t = t_max.x
			t_max.x += t_delta.x
			cell.x += step.x
		else:
			# We cross a HORIZONTAL grid line first: move one cell up/down.
			t = t_max.y
			t_max.y += t_delta.y
			cell.y += step.y

	return NO_TARGET  # ran out of reach without hitting anything


## True if any tile is painted in this cell (solid or not).
static func _is_occupied(tile_map: TileMapLayer, cell: Vector2i) -> bool:
	return tile_map.get_cell_tile_data(cell) != null
