#!/usr/bin/env python3
"""Slices the creative director's tileset presentation sheet into game assets.

Input:  assets/source/tileset/jesters_court_tileset_sheet.png (1536x1024)
Output: assets/environments/pack/<name>.png  (2x, transparent, inked)
        docs/art/tileset_slices.png             (review sheet)

The sheet is a presentation board: assets sit on a flat dark-purple field
whose colour matches the pack's own ink outlines. So, per asset:
  1. Crop the hand-measured rectangle (SLICES) and tighten it to content.
  2. Key out the field colour, flood-filled from the crop border (plus
     enclosed holes for open shapes such as arches and chains).
  3. Upscale 2x (Lanczos) to match the characters' 2x authoring.
  4. Trim the dark fringe and redraw an even ink outline from a distance
     field, in the pack's own outline colour.
Opaque terrain tiles are cropped tight and upscaled without keying.

Sheet pixels are world pixels: the 64 px crate tile is a 64 px world crate.

Usage: python3 tools/art/slice_tileset.py   (needs numpy, scipy, Pillow)
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / "assets" / "source" / "tileset" / "jesters_court_tileset_sheet.png"
OUT = ROOT / "assets" / "environments" / "pack"
REVIEW = ROOT / "docs" / "art" / "tileset_slices.png"

FIELD = np.array([31.0, 15.0, 42.0])
FIELD_TOLERANCE = 40.0
INK = (24, 10, 34)
UPSCALE = 2

# name: (x0, y0, x1, y1, mode). mode: "prop" keyed + inked, "hole" also clears
# enclosed field pockets, "glow:N" also clears the dark glow painted behind
# lights (pixels darker than N connected to the border; it can also eat dark
# metal, so it is used only where that is acceptable), "tile" opaque square, "raw" keyed without ink.
SLICES = {
    # Terrain tiles (opaque)
    "tile_stone_mossy_top": (183, 42, 249, 108, "tile"),
    "tile_stone_dark": (253, 42, 319, 108, "tile"),
    "tile_stone": (323, 42, 390, 108, "tile"),
    "tile_stone_cracked": (394, 42, 461, 108, "tile"),
    "tile_moss": (465, 42, 532, 108, "tile"),
    "tile_brick_red": (183, 112, 249, 179, "tile"),
    "tile_stone_light": (253, 112, 319, 179, "tile"),
    "tile_moss_a": (323, 112, 390, 179, "tile"),
    "tile_moss_b": (394, 112, 461, 179, "tile"),
    "tile_moss_c": (465, 112, 532, 179, "tile"),
    "tile_checker": (183, 185, 249, 253, "tile"),
    "tile_carpet": (253, 185, 319, 253, "tile"),
    "crate_large": (323, 185, 390, 253, "prop"),
    "crate_large_b": (394, 185, 461, 253, "prop"),
    "tile_metal": (465, 185, 532, 253, "tile"),
    # Platforms and ledges
    "ledge_wood": (876, 43, 1046, 92, "prop"),
    "ledge_stone": (876, 98, 986, 150, "prop"),
    "ledge_stone_small": (995, 98, 1072, 150, "prop"),
    "bridge_wood": (876, 153, 1093, 250, "hole"),
    "ledge_banner": (1106, 205, 1200, 275, "prop"),
    # Structures and doors
    "gate_golden": (558, 315, 668, 475, "hole"),
    "door_arched": (765, 322, 873, 475, "prop"),
    "portcullis": (678, 392, 757, 475, "hole"),
    "window_stained": (893, 318, 958, 398, "prop"),
    "window_stained_b": (962, 318, 1024, 398, "prop"),
    "arch_column": (8, 318, 148, 478, "hole"),
    "arch_vines": (430, 300, 550, 395, "hole"),
    # Lights
    "lantern_hanging": (1088, 318, 1133, 400, "prop"),
    "lantern_hanging_b": (1136, 318, 1182, 400, "prop"),
    "candelabra": (1040, 402, 1086, 475, "prop"),
    "brazier": (1097, 402, 1150, 475, "glow:125"),
    # Banners and drapery
    "banner_diamond": (1207, 318, 1266, 415, "prop"),
    "banner_crown": (1267, 318, 1324, 405, "prop"),
    "banner_crown_wide": (1327, 318, 1410, 405, "prop"),
    "banner_fleur": (1414, 318, 1466, 405, "prop"),
    "banner_red": (1470, 318, 1532, 408, "prop"),
    "drapery_swag": (1160, 402, 1460, 473, "hole"),
    # Props
    "tent": (0, 522, 173, 696, "prop"),
    "cart": (160, 527, 308, 620, "prop"),
    "barrel": (303, 556, 350, 615, "prop"),
    "crate_small": (352, 568, 410, 620, "prop"),
    "candle_table": (415, 500, 508, 610, "prop"),
    "throne": (508, 498, 585, 610, "prop"),
    "jester_bust": (252, 612, 314, 708, "prop"),
    "books": (314, 618, 375, 692, "prop"),
    "flower_pot": (374, 618, 445, 696, "prop"),
    "plant_pot": (502, 612, 570, 685, "prop"),
    "rubble": (442, 650, 530, 700, "prop"),
    "stone_block": (180, 620, 248, 672, "prop"),
    # Interactables
    "block_question": (604, 527, 660, 583, "prop"),
    "block_exclaim": (664, 527, 720, 583, "prop"),
    "lever": (862, 517, 925, 575, "prop"),
    "pressure_plate": (604, 598, 680, 636, "prop"),
    "spring": (692, 588, 761, 646, "prop"),
    "key": (780, 588, 832, 640, "prop"),
    "padlock": (842, 585, 893, 640, "prop"),
    "moving_platform": (604, 652, 720, 690, "prop"),
    "gem": (746, 642, 794, 696, "prop"),
    "coin": (797, 642, 853, 696, "prop"),
    "heart": (858, 642, 918, 696, "prop"),
    # Hazards
    "spike_block": (952, 527, 1040, 583, "prop"),
    "spike_platform": (1047, 527, 1130, 583, "prop"),
    "spikes_ceiling": (1137, 508, 1203, 570, "prop"),
    "fire": (958, 595, 1030, 688, "glow:125"),
    "spikes_floor": (1039, 627, 1138, 692, "prop"),
    "saw_blade": (1128, 585, 1213, 672, "prop"),
    "spiked_ball": (1210, 506, 1293, 633, "hole"),
    "goo": (1166, 652, 1290, 708, "prop"),
    # Effects
    "fx_burst": (1320, 530, 1408, 590, "raw"),
    "fx_swoosh": (1414, 524, 1533, 590, "raw"),
    "fx_smoke_small": (1318, 595, 1392, 636, "raw"),
    "fx_smoke_trail": (1416, 586, 1533, 634, "raw"),
    "fx_cloud": (1318, 640, 1424, 700, "raw"),
    "fx_smoke_dark": (1436, 636, 1530, 702, "raw"),
}


def tighten(rgb: np.ndarray, box: tuple) -> tuple:
    x0, y0, x1, y1 = box
    crop = rgb[y0:y1, x0:x1]
    fg = np.abs(crop - FIELD).sum(axis=2) > FIELD_TOLERANCE
    fg = ndimage.binary_opening(fg, iterations=1)
    labels, n = ndimage.label(fg, structure=np.ones((3, 3)))
    if n == 0:
        raise SystemExit(f"empty slice {box}")
    sizes = ndimage.sum(fg, labels, range(1, n + 1))
    keep = np.isin(labels, [i + 1 for i, s in enumerate(sizes) if s >= max(30, sizes.max() * 0.02)])
    ys, xs = np.nonzero(keep)
    return (x0 + xs.min(), y0 + ys.min(), x0 + xs.max() + 1, y0 + ys.max() + 1)


def key_field(crop: np.ndarray, holes: bool, glow: float = 0.0) -> np.ndarray:
    """Boolean foreground mask. `glow` > 0 also keys out border-connected
    pixels darker than that value (the dark glow painted behind lights)."""
    near = np.abs(crop - FIELD).sum(axis=2) <= FIELD_TOLERANCE
    if glow > 0.0:
        near |= crop.max(axis=2) < glow
    labels, n = ndimage.label(near)
    border = np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))
    keep = np.zeros(n + 1, dtype=bool)
    keep[border] = True
    if holes:
        sizes = ndimage.sum(near, labels, range(1, n + 1))
        keep[1:] |= sizes >= 25
    keep[0] = False
    fg = ~keep[labels]
    fg = ndimage.binary_opening(fg, iterations=1)
    labels, n = ndimage.label(fg, structure=np.ones((3, 3)))
    if n:
        sizes = ndimage.sum(fg, labels, range(1, n + 1))
        # Drop specks and fragments of neighbouring art: keep the main piece
        # plus pieces whose centre lies inside its (slightly grown) footprint.
        main = int(np.argmax(sizes)) + 1
        sl = ndimage.find_objects(labels)[main - 1]
        my, mx = (sl[0].stop - sl[0].start) * 0.08, (sl[1].stop - sl[1].start) * 0.08
        centres = ndimage.center_of_mass(fg, labels, range(1, n + 1))
        keep_ids = [main]
        for i, (cy, cx) in enumerate(centres, 1):
            if i == main or sizes[i - 1] < max(12, sizes.max() * 0.01):
                continue
            if sl[0].start - my <= cy <= sl[0].stop + my and sl[1].start - mx <= cx <= sl[1].stop + mx:
                keep_ids.append(i)
        fg = np.isin(labels, keep_ids)
    return fg


def upscale(img: Image.Image) -> Image.Image:
    return img.resize((img.width * UPSCALE, img.height * UPSCALE), Image.LANCZOS)


def ink(rgba: np.ndarray, width: float) -> np.ndarray:
    solid = rgba[..., 3] > 127
    solid = ndimage.binary_erosion(solid, iterations=1)
    dist = ndimage.distance_transform_edt(~solid)
    ink_alpha = np.clip(width + 0.5 - dist, 0.0, 1.0) * 255.0
    out = rgba.copy()
    out[~solid, 3] = 0.0
    ring = (~solid) & (ink_alpha > 0)
    out[ring, 0], out[ring, 1], out[ring, 2] = INK
    out[ring, 3] = ink_alpha[ring]
    return out


def slice_one(rgb: np.ndarray, name: str, spec: tuple) -> Image.Image:
    *box, mode = spec
    if mode == "tile":
        x0, y0, x1, y1 = tighten(rgb, tuple(box))
        tile = Image.fromarray(rgb[y0:y1, x0:x1].astype(np.uint8)).convert("RGBA")
        return upscale(tile)
    pad = 3
    x0, y0, x1, y1 = tighten(rgb, tuple(box))
    x0, y0 = max(x0 - pad, 0), max(y0 - pad, 0)
    x1, y1 = min(x1 + pad, rgb.shape[1]), min(y1 + pad, rgb.shape[0])
    crop = rgb[y0:y1, x0:x1]
    glow = float(mode.split(":")[1]) if mode.startswith("glow:") else 0.0
    fg = key_field(crop, holes=(mode == "hole"), glow=glow)
    rgba = np.dstack([crop, fg * 255.0]).astype(np.uint8)
    big = np.asarray(upscale(Image.fromarray(rgba, "RGBA").convert("RGBa")).convert("RGBA")).astype(np.float64)
    if mode != "raw":
        big = ink(big, 2.4)
    else:
        big[..., 3] = np.where(big[..., 3] > 127, 255.0, big[..., 3] * 1.6).clip(0, 255)
    img = Image.fromarray(big.clip(0, 255).astype(np.uint8), "RGBA")
    return img.crop(img.getbbox())


def main() -> None:
    rgb = np.asarray(Image.open(SHEET).convert("RGB")).astype(np.float64)
    OUT.mkdir(parents=True, exist_ok=True)
    images = {}
    for name, spec in SLICES.items():
        img = slice_one(rgb, name, spec)
        img.save(OUT / f"{name}.png", optimize=True)
        images[name] = img
    write_review(images)
    print(f"Sliced {len(images)} assets into {OUT.relative_to(ROOT)}")


def write_review(images: dict) -> None:
    cell_w, cell_h, cols = 260, 230, 9
    rows = (len(images) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * cell_w, rows * cell_h), (96, 74, 136))
    draw = ImageDraw.Draw(sheet)
    for i, (name, img) in enumerate(images.items()):
        cx, cy = (i % cols) * cell_w, (i // cols) * cell_h
        thumb = img.copy()
        thumb.thumbnail((cell_w - 10, cell_h - 26))
        sheet.paste(thumb, (cx + 5, cy + 5), thumb)
        draw.text((cx + 5, cy + cell_h - 18), name, fill=(255, 255, 255))
    REVIEW.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(REVIEW, optimize=True)


if __name__ == "__main__":
    main()
