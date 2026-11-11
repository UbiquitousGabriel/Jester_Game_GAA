class_name TerrainTiles
extends RefCounted
## Runtime TileSet over the packed terrain atlas
## (tools/world/build_tile_atlas.py). Visual only: collision is built from
## merged rectangles by RoomBuilder, which is cheaper and more robust.

const ATLAS: Texture2D = preload("res://assets/environments/tiles/terrain_atlas.png")
const SIZE := 128
const TOP_VARIANTS := 7
const BODY_START := 7
const BODY_VARIANTS := 5
const CRACKED := 12
const CHECKER := 13
const CARPET := 14
const METAL := 15

static var _tileset: TileSet = null


static func tileset() -> TileSet:
	if _tileset != null:
		return _tileset
	var ts := TileSet.new()
	ts.tile_size = Vector2i(SIZE, SIZE)
	var source := TileSetAtlasSource.new()
	source.texture = ATLAS
	source.texture_region_size = Vector2i(SIZE, SIZE)
	for i: int in ATLAS.get_width() / SIZE:
		source.create_tile(Vector2i(i, 0))
	ts.add_source(source, 0)
	_tileset = ts
	return ts
