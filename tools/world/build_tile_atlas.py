#!/usr/bin/env python3
"""Packs the tileset pack's terrain tiles into one 128 px atlas for the
runtime TileSet (scripts/world/tiles.gd). Tiles are resampled to exactly
128 x 128 so the grid is exact; the game draws the TileMapLayer at 0.5.

Atlas columns: 0-6 top (surface) variants, 7-11 body variants, 12 cracked,
13 checker, 14 carpet, 15 metal.
Usage: python3 tools/world/build_tile_atlas.py
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PACK = ROOT / "assets" / "environments" / "pack"
ORDER = [
    "tile_stone_mossy_top", "tile_moss", "tile_moss_a", "tile_moss_b", "tile_moss_c",
    "tile_stone_mossy_top", "tile_moss_a",
    "tile_stone", "tile_stone_light", "tile_stone_cracked", "tile_stone_dark", "tile_stone",
    "tile_stone_cracked", "tile_checker", "tile_carpet", "tile_metal",
]
atlas = Image.new("RGBA", (128 * len(ORDER), 128), (0, 0, 0, 0))
for i, name in enumerate(ORDER):
    tile = Image.open(PACK / f"{name}.png").convert("RGBA").resize((128, 128), Image.LANCZOS)
    atlas.paste(tile, (i * 128, 0))
out = ROOT / "assets" / "environments" / "tiles"
out.mkdir(parents=True, exist_ok=True)
atlas.save(out / "terrain_atlas.png", optimize=True)
print("atlas", atlas.size)
