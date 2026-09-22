extends Node2D
## World: owns the tile map and everything that happens to tiles.
##
## Other scripts (player, drops) ask the world questions like "is this cell
## walkable?" or tell it to "mine this cell". Nothing else touches the tile map
## directly, so if the map ever changes (chunks, a second layer) only this file
## needs updating.
##
## TILE PROPERTIES
## Each tile in the TileSet carries three custom data values. Set them in the
## editor: select the TileSet > pick a tile > Custom Data.
##   "solid"        (bool)   - blocks movement
##   "minable"      (bool)   - can be mined at all
##   "drop_item_id" (String) - id of the item it drops when mined
## Because of this, adding a new ore is a TileSet edit, not a code change.

## The tile map that holds every tile in the level.
@onready var tile_map: TileMapLayer = $Layer0

## The little item that pops out of a mined tile.
const DROPPED_ITEM_SCENE := preload("res://scenes/dropped_item.tscn")

## Returned by raycast_tile() when nothing is in reach (defined in tile_raycast.gd,
## re-exported here so other scripts can write world.NO_TARGET).
const NO_TARGET := TileRaycast.NO_TARGET

## Master switch for drops. Turn off to make mining just delete tiles.
@export var drops_enabled: bool = true

## Drops appear up to this many pixels from the mined tile's centre, on each axis.
## The randomness stops a column of mined tiles from stacking all its drops on
## one spot, so you can see roughly how many there are.
@export var drop_spread: float = 14.0


## item id -> icon picture, built once at startup (see item_icons.gd).
var _item_icons: Dictionary = {}


func _ready() -> void:
	# Other scripts find the world with get_first_node_in_group("world").
	add_to_group("world")
	_item_icons = ItemIcons.build(tile_map.tile_set)


# ---------------------------------------------------------------------------
# Coordinate helpers
# "World position" = pixels in the game world. "Grid position" = which tile
# cell (column, row) a spot is in. These two functions convert between them.
# ---------------------------------------------------------------------------

## World position (pixels) -> the grid cell containing it.
func world_to_grid(world_pos: Vector2) -> Vector2i:
	return tile_map.local_to_map(tile_map.to_local(world_pos))


## Grid cell -> world position of that cell's CENTRE.
func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return tile_map.to_global(tile_map.map_to_local(grid_pos))


## Width/height of one tile in pixels (currently 40).
func cell_size() -> float:
	return tile_map.tile_set.tile_size.x  # assumes square tiles


# ---------------------------------------------------------------------------
# Questions about a tile
# ---------------------------------------------------------------------------

## Can something stand or move through this cell?
## An empty cell (no tile painted) counts as open space.
func is_walkable(grid_pos: Vector2i) -> bool:
	var data: TileData = tile_map.get_cell_tile_data(grid_pos)
	if data == null:
		return true  # no tile placed = open space
	return not bool(data.get_custom_data("solid"))


## Is there a tile here that the player is allowed to mine?
func is_minable(grid_pos: Vector2i) -> bool:
	var data: TileData = tile_map.get_cell_tile_data(grid_pos)
	return data != null and bool(data.get_custom_data("minable"))


## First tile hit by a line from `from` toward `to`, up to `max_reach` pixels.
## Returns NO_TARGET if nothing is hit. The real work is in tile_raycast.gd.
func raycast_tile(from: Vector2, to: Vector2, max_reach: float) -> Vector2i:
	return TileRaycast.first_tile(tile_map, from, to, max_reach)


## The picture for an item id (used by the hotbar). Null if we don't know it.
func item_icon(item_id: String) -> Texture2D:
	return _item_icons.get(item_id)


# ---------------------------------------------------------------------------
# Mining
# ---------------------------------------------------------------------------

## Breaks the tile at `grid_pos` and (if drops are on) spawns its drop.
## Does nothing if there's no tile or it isn't minable, so it's safe to call
## without checking first.
func mine_tile(grid_pos: Vector2i) -> void:
	var data: TileData = tile_map.get_cell_tile_data(grid_pos)
	if data == null:
		return  # nothing there
	if not bool(data.get_custom_data("minable")):
		return

	var drop_id: String = str(data.get_custom_data("drop_item_id"))

	# Grab the tile's picture BEFORE erasing it; once it's gone we can't read it.
	var drop_texture: Texture2D = _tile_texture(grid_pos)

	tile_map.erase_cell(grid_pos)
	if drops_enabled:
		_spawn_drop(grid_pos, drop_id, drop_texture)


## Cuts the tile's picture out of the TileSet's big image (the "atlas"), so the
## drop can wear a shrunken copy of the tile it came from. This is why you never
## need to draw separate art for each drop.
func _tile_texture(grid_pos: Vector2i) -> Texture2D:
	# Which atlas image is this tile from? (We only have one source right now.)
	var source := tile_map.tile_set.get_source(tile_map.get_cell_source_id(grid_pos)) as TileSetAtlasSource
	if source == null:
		return null
	# AtlasTexture = "just this rectangle of that big image".
	var tex := AtlasTexture.new()
	tex.atlas = source.texture
	tex.region = source.get_tile_texture_region(tile_map.get_cell_atlas_coords(grid_pos))
	return tex


## Called when a tile is mined: makes its drop at the cell, nudged randomly.
func _spawn_drop(grid_pos: Vector2i, item_id: String, texture: Texture2D) -> void:
	# Start at the cell centre, then jiggle by a random amount on each axis.
	var pos: Vector2 = grid_to_world(grid_pos) + Vector2(
		randf_range(-drop_spread, drop_spread),
		randf_range(-drop_spread, drop_spread))
	spawn_drop(pos, item_id, texture)


## Creates one drop in the world. Used both for mined tiles (above) and for items
## the player throws.
##   world_pos     - where it appears (pixels)
##   velocity      - starting speed in px/s; zero = just falls
##   pickup_delay  - seconds before it can be picked up or magnetised
func spawn_drop(world_pos: Vector2, item_id: String, texture: Texture2D,
		velocity: Vector2 = Vector2.ZERO, pickup_delay: float = 0.0) -> void:
	if item_id == "":
		return  # this tile doesn't drop anything

	var drop = DROPPED_ITEM_SCENE.instantiate()
	drop.item_id = item_id
	# Set these BEFORE add_child: the drop reads its texture in its own _ready(),
	# which runs the moment it enters the scene.
	drop.texture = texture
	drop.velocity = velocity
	drop.pickup_delay = pickup_delay
	add_child(drop)
	drop.global_position = world_pos
