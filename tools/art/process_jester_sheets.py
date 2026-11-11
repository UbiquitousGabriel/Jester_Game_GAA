#!/usr/bin/env python3
"""Turns the generated Jester sprite sheets into clean, aligned Godot frames.

Input:  assets/source/jester/sheets/*.png   (RGB, near-white checker background)
Output: assets/characters/jester/frames/<anim>_<nn>.png   (RGBA, uniform canvas)
        resources/animation/jester_frames.tres           (SpriteFrames)
        assets/characters/jester/frames/manifest.json     (anchor, scale, sources)
        docs/art/jester_alignment.png                     (review sheet)

Pipeline per sheet:
  1. Key out the background: near-neutral pixels brighter than BG_MIN, flood
     filled from the border, plus enclosed checker holes (gaps between arm and
     hammer handle, between legs).
  2. Un-blend the anti-aliased edge band against white, so outlines keep soft
     edges without a white halo.
  3. Split into grid cells; every opaque component is assigned to the cell
     containing its centroid (effects that cross a cell edge stay whole).
  4. Drop specks and the painted ground shadow. On looping sheets (idle, run)
     drop detached effects too, so emote marks do not flash every loop.
  5. Align: horizontal anchor = skull centre, vertical anchor = lowest body
     pixel (per frame, or per sheet row for run so the stride bob survives).
  6. Downscale with premultiplied Lanczos and paste onto one shared canvas so
     a single AnimatedSprite2D offset works for every animation.

Usage: python3 tools/art/process_jester_sheets.py   (needs numpy, scipy, Pillow)
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "assets" / "source" / "jester" / "sheets"
OUT = ROOT / "assets" / "characters" / "jester" / "frames"
TRES = ROOT / "resources" / "animation" / "jester_frames.tres"
LAYOUT = ROOT / "scripts" / "animation" / "jester_sprite_layout.gd"
REVIEW = ROOT / "docs" / "art" / "jester_alignment.png"

# Output frames are authored at 2x display size; the game draws them at 0.5.
SCALE = 0.5
BG_MIN = 238  # background luminance floor
BG_SPREAD = 8  # max channel spread for a background pixel
MIN_COMPONENT = 80  # source pixels; smaller islands are noise
PAD = 6

# The generator drew the character at slightly different sizes per sheet.
# Correction relative to idle, averaged from two rigid rulers measured across
# all frames: hat-bell width and skull width (see docs/ART_PIPELINE.md).
SHEET_SCALE = {
    "idle": 1.0,
    "run": 0.975,
    "jump": 1.105,
    "attack": 1.07,
    "slam": 1.15,
    "pogo": 1.15,
    "damage": 1.04,
    # Drawn at half resolution: upright recovery poses are 175 px tall
    # against 350 px on the idle sheet, and skull widths agree.
    "aerial": 2.0,
}

# Sheets whose poses spin through the air: anchored on the skull centre
# (found as the cream region with eye-socket holes) rather than on the feet.
# The skull is placed at its idle height above the feet so the physics
# origin stays consistent between ground and air animations.
SKULL_ANCHORED = {"aerial"}

# sheet file, grid (cols, rows), loop-sheet (drop detached effects), row-baseline
SHEETS = {
    "idle": ("jester_idle_8frames.png", (4, 2), True, False),
    "run": ("jester_run_8frames.png", (4, 2), True, True),
    "jump": ("jester_jump_fall_9frames.png", (3, 3), False, False),
    "attack": ("jester_hammer_attack_8frames.png", (4, 2), False, False),
    "slam": ("jester_ground_slam_8frames.png", (4, 2), False, False),
    "pogo": ("jester_pogo_8frames.png", (4, 2), False, False),
    "damage": ("jester_damage_defeat_8frames.png", (4, 2), False, False),
    "aerial": ("jester_aerial_combo_24frames.png", (8, 3), False, False),
}

# Godot animations built from the frames. Phase-driven animations (attacks,
# charge) have speed 0: jester_visual.gd picks their frames from gameplay time.
# name: (sheet, frame indices, fps, loop)
ANIMATIONS = {
    "idle": ("idle", range(8), 9.0, True),
    "run": ("run", range(8), 15.0, True),
    "dash": ("run", [3], 1.0, False),
    "jump_anticipate": ("jump", [1], 1.0, False),
    "jump_rise": ("jump", [2, 3, 4], 12.0, False),
    "jump_apex": ("jump", [5], 1.0, False),
    "jump_fall": ("jump", [6], 1.0, False),
    "land": ("jump", [7, 8], 14.0, False),
    "attack_side": ("attack", range(8), 0.0, False),
    "attack_up": ("slam", [0, 1, 2, 3, 3, 2, 1], 0.0, False),
    "slam": ("slam", range(8), 0.0, False),
    "charge": ("slam", [1, 2], 0.0, False),
    "pogo_strike": ("pogo", [1, 2, 3], 0.0, False),
    "pogo_bounce": ("pogo", [4, 5, 6, 7], 16.0, False),
    "vault": ("pogo", [4, 5, 6], 16.0, False),
    "hurt": ("damage", [1, 2, 3], 14.0, False),
    "defeat": ("damage", [4, 5, 6, 7], 7.0, False),
    # Aerial combo (phase-driven) and the hammer twirl glide.
    "air_swing_1": ("aerial", [0, 1, 8, 9, 10], 0.0, False),
    "air_swing_2": ("aerial", [1, 2, 13, 14, 15], 0.0, False),
    "air_finisher": ("aerial", [3, 4, 5, 6, 7, 11, 12, 16, 17], 0.0, False),
    "air_spin": ("aerial", [3, 4, 5, 6, 7, 11, 12], 22.0, True),
    "air_ready": ("aerial", [18, 19, 20, 21, 22, 23], 12.0, True),
}


def key_background(rgb: np.ndarray, min_hole: int = 60) -> np.ndarray:
    """Returns a boolean mask of background pixels. Enclosed holes of at
    least `min_hole` pixels count as background (tiny ones need no checker
    texture test: they are too small to show the pattern)."""
    lo = rgb.min(axis=2)
    spread = rgb.max(axis=2) - lo
    candidate = (lo >= BG_MIN) & (spread <= BG_SPREAD)
    labels, count = ndimage.label(candidate)
    sizes = ndimage.sum(candidate, labels, range(1, count + 1))
    border = np.unique(
        np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]])
    )
    keep = np.zeros(count + 1, dtype=bool)
    keep[border] = True
    # Enclosed checker holes: large enough and genuinely checker-textured.
    for index in range(1, count + 1):
        if keep[index] or sizes[index - 1] < min_hole:
            continue
        if sizes[index - 1] < 60:
            keep[index] = True
            continue
        values = lo[labels == index]
        if values.max() - values.min() >= 3:
            keep[index] = True
    keep[0] = False
    return keep[labels]


def unblend(rgb: np.ndarray, background: np.ndarray) -> np.ndarray:
    """RGBA float image; the 2 px band next to the background is un-blended."""
    band = ndimage.binary_dilation(background, iterations=2) & ~background
    alpha = np.where(background, 0.0, 1.0)
    out_rgb = rgb.copy()
    bg_value = 252.0
    c = rgb[band]
    a = np.clip(((bg_value - c) / bg_value).max(axis=1) * 1.15, 0.0, 1.0)
    safe = np.maximum(a, 1e-3)[:, None]
    out_rgb[band] = np.clip((c - (1.0 - a)[:, None] * bg_value) / safe, 0, 255)
    alpha[band] = a
    return np.dstack([out_rgb, alpha * 255.0])


def is_shadow(rgba: np.ndarray, mask: np.ndarray) -> bool:
    ys, xs = np.nonzero(mask)
    height = ys.max() - ys.min() + 1
    width = xs.max() - xs.min() + 1
    pixels = rgba[mask][:, :3]
    spread = (pixels.max(axis=1) - pixels.min(axis=1)).mean()
    luminance = pixels.mean()
    return width > 4 * height and spread < 30 and 40 < luminance < 170


def skull_centre_x(rgba: np.ndarray, body: np.ndarray) -> float:
    """X centre of the skull: the largest cream region in the upper body."""
    r, g, b = rgba[..., 0], rgba[..., 1], rgba[..., 2]
    cream = body & (r > 215) & (g > 195) & (b > 165) & (r - b > 8) & (r - b < 70)
    ys = np.nonzero(body.any(axis=1))[0]
    top, bottom = ys.min(), ys.max()
    # Ignore the ruff and gloves: look in the top 70% only.
    cream[int(top + (bottom - top) * 0.7):] = False
    labels, count = ndimage.label(cream)
    if count == 0:
        return float(np.nonzero(body)[1].mean())
    sizes = ndimage.sum(cream, labels, range(1, count + 1))
    biggest = labels == (int(np.argmax(sizes)) + 1)
    return float(np.nonzero(biggest)[1].mean())


def skull_centre(rgba: np.ndarray, body: np.ndarray) -> tuple[float, float] | None:
    """Centre of the skull: the cream region enclosing eye-socket holes."""
    r, g, b = rgba[..., 0], rgba[..., 1], rgba[..., 2]
    cream = body & (r > 215) & (g > 195) & (b > 165) & (r - b > 8) & (r - b < 70)
    labels, count = ndimage.label(cream)
    best, best_holes = 0, 0
    for index, sl in enumerate(ndimage.find_objects(labels), 1):
        region = labels[sl] == index
        holes = int(ndimage.binary_fill_holes(region).sum() - region.sum())
        if region.sum() > 300 and holes > best_holes:
            best, best_holes = index, holes
    if best == 0:
        return None
    ys, xs = np.nonzero(ndimage.binary_fill_holes(labels == best))
    return float(xs.mean()), float(ys.mean())


IDLE_SKULL_HEIGHT = 0.0  # set in main(): skull centre height above feet on idle


def extract_sheet(name: str, spec: tuple) -> list[dict]:
    filename, (cols, rows), drop_detached, _row_baseline = spec
    rgb = np.asarray(Image.open(SRC / filename).convert("RGB")).astype(np.float64)
    background = key_background(rgb)
    rgba = unblend(rgb, background)
    opaque = rgba[..., 3] > 8
    labels, count = ndimage.label(opaque, structure=np.ones((3, 3)))
    sizes = ndimage.sum(opaque, labels, range(1, count + 1))
    centres = ndimage.center_of_mass(opaque, labels, range(1, count + 1))
    cell_w = rgb.shape[1] / cols
    cell_h = rgb.shape[0] / rows

    cells: dict[int, list[int]] = {}
    for index in range(1, count + 1):
        if sizes[index - 1] < MIN_COMPONENT:
            continue
        cy, cx = centres[index - 1]
        cell = int(cy // cell_h) * cols + int(cx // cell_w)
        cells.setdefault(cell, []).append(index)

    frames = []
    for cell in range(cols * rows):
        members = cells.get(cell, [])
        if not members:
            raise SystemExit(f"{filename}: cell {cell} is empty")
        main = max(members, key=lambda i: sizes[i - 1])
        keep = []
        for index in members:
            mask = labels == index
            if index != main and drop_detached:
                continue
            if index != main and is_shadow(rgba, mask):
                continue
            keep.append(index)
        mask = np.isin(labels, keep)
        body = labels == main
        ys, xs = np.nonzero(mask)
        y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
        crop = rgba[y0:y1, x0:x1].copy()
        crop[~mask[y0:y1, x0:x1]] = 0.0
        body_crop = body[y0:y1, x0:x1]
        frames.append(
            {
                "sheet": name,
                "index": cell,
                "row": cell // cols,
                "image": crop,
                "anchor_x": skull_centre_x(crop, body_crop),
                "foot_y": float(np.nonzero(body_crop.any(axis=1))[0].max()),
                "source_box": [int(x0), int(y0), int(x1), int(y1)],
            }
        )

    if name in SKULL_ANCHORED:
        lift = IDLE_SKULL_HEIGHT / SHEET_SCALE[name]
        for f in frames:
            body = f["image"][..., 3] > 128
            centre = skull_centre(f["image"], body)
            if centre is None:
                ys, xs = np.nonzero(body)
                centre = (float(xs.mean()), float(ys.mean()))
            f["anchor_x"] = centre[0]
            f["foot_y"] = centre[1] + lift

    if spec[3]:  # shared baseline per row keeps the run cycle's bob
        for row in {f["row"] for f in frames}:
            row_frames = [f for f in frames if f["row"] == row]
            base = max(f["foot_y"] + f["source_box"][1] for f in row_frames)
            for f in row_frames:
                f["foot_y"] = base - f["source_box"][1]
    return frames


def to_image(rgba: np.ndarray) -> Image.Image:
    return Image.fromarray(np.clip(rgba, 0, 255).astype(np.uint8), "RGBA")


def downscale(img: Image.Image, factor: float) -> Image.Image:
    w = max(1, round(img.width * factor))
    h = max(1, round(img.height * factor))
    return img.convert("RGBa").resize((w, h), Image.LANCZOS).convert("RGBA")


def main() -> None:
    global IDLE_SKULL_HEIGHT
    idle = extract_sheet("idle", SHEETS["idle"])
    heights = []
    for f in idle:
        centre = skull_centre(f["image"], f["image"][..., 3] > 128)
        if centre is not None:
            heights.append(f["foot_y"] - centre[1])
    IDLE_SKULL_HEIGHT = float(np.median(heights))
    all_frames = {name: extract_sheet(name, spec) for name, spec in SHEETS.items()}

    # Shared canvas: union of every frame's extent around its anchor.
    left = right = up = down = 0.0
    for name, frames in all_frames.items():
        k = SCALE * SHEET_SCALE[name]
        for f in frames:
            h, w = f["image"].shape[:2]
            left = max(left, f["anchor_x"] * k)
            right = max(right, (w - f["anchor_x"]) * k)
            up = max(up, f["foot_y"] * k)
            down = max(down, (h - f["foot_y"]) * k)
    canvas_w = int(np.ceil(left + right)) + PAD * 2
    canvas_h = int(np.ceil(up + down)) + PAD * 2
    anchor = (int(round(left)) + PAD, int(round(up)) + PAD)

    OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.glob("*.png"):
        old.unlink()
    manifest = {
        "id": "jester",
        "canonical_species": "undead skeleton",
        "canvas": [canvas_w, canvas_h],
        "anchor": list(anchor),
        "display_scale": SCALE,
        "frames": {},
    }
    for name, frames in all_frames.items():
        k = SCALE * SHEET_SCALE[name]
        for f in frames:
            small = downscale(to_image(f["image"]), k)
            canvas = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
            x = anchor[0] - int(round(f["anchor_x"] * k))
            y = anchor[1] - int(round(f["foot_y"] * k))
            canvas.alpha_composite(small, (x, y))
            path = OUT / f"{name}_{f['index']:02d}.png"
            canvas.save(path, optimize=True)
            manifest["frames"][path.name] = {
                "source": SHEETS[name][0],
                "sheet_scale": SHEET_SCALE[name],
                "source_box": f["source_box"],
            }
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=1))
    LAYOUT.write_text(
        "class_name JesterSpriteLayout\n"
        "## Generated by tools/art/process_jester_sheets.py. Do not edit.\n\n"
        "## Canvas pixel that sits on the Jester's feet, under his skull.\n"
        f"const ANCHOR := Vector2({anchor[0]}, {anchor[1]})\n"
        f"const CANVAS := Vector2({canvas_w}, {canvas_h})\n"
    )
    write_sprite_frames()
    write_review(all_frames, canvas_w, canvas_h, anchor)
    patched = enable_mipmaps()
    print(f"canvas {canvas_w}x{canvas_h}, anchor {anchor}, "
          f"{sum(len(v) for v in all_frames.values())} frames, "
          f"mipmaps enabled on {patched} existing .import files")


def enable_mipmaps() -> int:
    """Frames are drawn at half size and further zoomed out, so they need
    mipmaps. Godot writes .import files on first import; brand-new frames need
    one `godot --headless --import`, then a rerun of this script and another
    import."""
    count = 0
    for path in OUT.glob("*.png.import"):
        text = path.read_text()
        new = text.replace("mipmaps/generate=false", "mipmaps/generate=true")
        new = new.replace("process/fix_alpha_border=false", "process/fix_alpha_border=true")
        if new != text:
            path.write_text(new)
        count += 1
    return count


def write_sprite_frames() -> None:
    textures: list[str] = []
    for sheet, indices, _fps, _loop in ANIMATIONS.values():
        for i in indices:
            path = f"res://assets/characters/jester/frames/{sheet}_{i:02d}.png"
            if path not in textures:
                textures.append(path)
    lines = [
        f'[gd_resource type="SpriteFrames" load_steps={len(textures) + 1} format=3]',
        "",
    ]
    for n, path in enumerate(textures, 1):
        lines.append(f'[ext_resource type="Texture2D" path="{path}" id="{n}"]')
    lines += ["", "[resource]", "animations = ["]
    blocks = []
    for name, (sheet, indices, fps, loop) in ANIMATIONS.items():
        frames = ", ".join(
            '{"duration": 1.0, "texture": ExtResource("%d")}'
            % (textures.index(f"res://assets/characters/jester/frames/{sheet}_{i:02d}.png") + 1)
            for i in indices
        )
        blocks.append(
            "{\n"
            f'"frames": [{frames}],\n'
            f'"loop": {"true" if loop else "false"},\n'
            f'"name": &"{name}",\n'
            f'"speed": {fps}\n'
            "}"
        )
    lines.append(", ".join(blocks) + "]")
    TRES.parent.mkdir(parents=True, exist_ok=True)
    TRES.write_text("\n".join(lines) + "\n")


def write_review(all_frames: dict, canvas_w: int, canvas_h: int, anchor: tuple) -> None:
    """One row per sheet on a mid-tone backdrop, with the anchor cross drawn."""
    cols = max(len(v) for v in all_frames.values())
    sheet = Image.new("RGB", (cols * canvas_w, len(all_frames) * canvas_h), (88, 66, 128))
    draw = ImageDraw.Draw(sheet)
    for r, (name, frames) in enumerate(all_frames.items()):
        for f in frames:
            img = Image.open(OUT / f"{name}_{f['index']:02d}.png")
            ox, oy = f["index"] * canvas_w, r * canvas_h
            draw.rectangle([ox, oy, ox + canvas_w - 1, oy + canvas_h - 1], outline=(60, 44, 90))
            sheet.paste(img, (ox, oy), img)
            ax, ay = ox + anchor[0], oy + anchor[1]
            draw.line([ax - 8, ay, ax + 8, ay], fill=(80, 255, 200), width=2)
            draw.line([ax, ay - 8, ax, ay + 8], fill=(80, 255, 200), width=2)
    REVIEW.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(REVIEW, optimize=True)


if __name__ == "__main__":
    main()
