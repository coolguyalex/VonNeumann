class_name ItemIcons
extends RefCounted
## ItemIcons: works out which picture to show for each item id.
##
## For now an item's icon is just the picture of the tile that drops it: the
## tile with drop_item_id "raw_copper" gives the "raw_copper" icon. That means
## new ores get icons automatically. When you draw real icons later, change
## build() to load them instead (or override specific ids after the loop).


## Scans every tile in the TileSet and returns a Dictionary of
## { item_id (String) : icon (Texture2D) }.
static func build(tile_set: TileSet) -> Dictionary:
	var icons := {}

	# A TileSet can have several "sources" (atlas images). Check each one.
	for source_index in tile_set.get_source_count():
		var source_id: int = tile_set.get_source_id(source_index)
		var source := tile_set.get_source(source_id) as TileSetAtlasSource
		if source == null:
			continue  # not an atlas image; skip it

		# Then every tile painted in that atlas.
		for tile_index in source.get_tiles_count():
			var coords: Vector2i = source.get_tile_id(tile_index)
			var data: TileData = source.get_tile_data(coords, 0)

			# Which item does this tile drop? Skip tiles that drop nothing, and
			# ids we already have (many tiles can drop the same item).
			var item_id: String = str(data.get_custom_data("drop_item_id"))
			if item_id == "" or icons.has(item_id):
				continue

			# Cut this tile's rectangle out of the atlas image.
			var icon := AtlasTexture.new()
			icon.atlas = source.texture
			icon.region = source.get_tile_texture_region(coords)
			icons[item_id] = icon

	# Tools aren't dropped by any tile, so they get placeholder squares.
	# REPLACE THESE with real icons when you draw them, e.g.
	#     icons["drill"] = load("res://assets/icon_drill.png")
	icons["drill"] = _placeholder(Color(0.55, 0.65, 0.8))
	icons["magnet"] = _placeholder(Color(0.85, 0.25, 0.25))

	return icons


## A stand-in icon: a 16x16 square of one colour with a lighter square inside,
## so it reads as "an item" and not just an empty coloured box.
static func _placeholder(color: Color) -> Texture2D:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(color)
	image.fill_rect(Rect2i(4, 4, 8, 8), color.lightened(0.4))
	return ImageTexture.create_from_image(image)
