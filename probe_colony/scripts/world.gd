extends Node2D

## Reads three custom data layers you set up on the TileSet in the editor
## (Project > TileSet > select a tile > Custom Data tab):
##   "solid"        (bool)   - blocks movement
##   "minable"      (bool)   - can be mined at all
##   "drop_item_id" (String) - item id to spawn when mined
## Doing it this way means adding a new ore/wall type is a TileSet edit,
## not a code change.

@onready var tile_map: TileMapLayer = $Layer0
const DROPPED_ITEM_SCENE := preload("res://scenes/dropped_item.tscn")

func _ready() -> void:
	add_to_group("world")

func world_to_grid(world_pos: Vector2) -> Vector2i:
	return tile_map.local_to_map(tile_map.to_local(world_pos))

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return tile_map.to_global(tile_map.map_to_local(grid_pos))

func is_walkable(grid_pos: Vector2i) -> bool:
	var data: TileData = tile_map.get_cell_tile_data(grid_pos)
	if data == null:
		return true  # no tile placed = open space
	return not bool(data.get_custom_data("solid"))

func mine_tile(grid_pos: Vector2i) -> void:
	var data: TileData = tile_map.get_cell_tile_data(grid_pos)
	if data == null:
		return  # nothing there
	if not bool(data.get_custom_data("minable")):
		return
	var drop_id: String = str(data.get_custom_data("drop_item_id"))
	tile_map.erase_cell(grid_pos)
	_spawn_drop(grid_pos, drop_id)

func _spawn_drop(grid_pos: Vector2i, item_id: String) -> void:
	if item_id == "":
		return
	var drop = DROPPED_ITEM_SCENE.instantiate()
	add_child(drop)
	drop.global_position = grid_to_world(grid_pos)
	drop.item_id = item_id
