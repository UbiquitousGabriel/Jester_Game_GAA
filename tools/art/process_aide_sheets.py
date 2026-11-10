#!/usr/bin/env python3
"""Turns the Community Aide sprite sheets into aligned Godot frames.

The Community Aide (sleepy, duck-print pyjamas, living human) stands in for the
Court Guard until guard art exists.

Input:  assets/source/community_aide/sheets/{idle,walk,jump}.png
Output: assets/characters/community_aide/frames/<anim>_<nn>.png
        resources/animation/community_aide_frames.tres
        scripts/animation/community_aide_sprite_layout.gd
        docs/art/community_aide_alignment.png

Differences from the Jester sheets:
  * idle.png already has a real alpha channel; walk.png and jump.png sit on
    pure black, the same value as parts of the ink outline. After keying the
    black, a 1-2 px ink line is rebuilt around the cutout so the outline is
    even everywhere.
  * Painted ground shadows touch the socks. They are removed by colour (grey
    with red >= blue, unlike the blue-heavy pyjamas) in the bottom band only.
  * jump.png has text captions under each frame; captions, dust and motion
    lines are detached islands and are dropped.

Usage: python3 tools/art/process_aide_sheets.py   (needs numpy, scipy, Pillow)
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "assets" / "source" / "community_aide" / "sheets"
OUT = ROOT / "assets" / "characters" / "community_aide" / "frames"
TRES = ROOT / "resources" / "animation" / "community_aide_frames.tres"
LAYOUT = ROOT / "scripts" / "animation" / "community_aide_sprite_layout.gd"
REVIEW = ROOT / "docs" / "art" / "community_aide_alignment.png"
RES_FRAMES = "res://assets/characters/community_aide/frames"

# Standing height of the reference pose (idle frame 0) in output pixels.
# Output is 2x display size; in game he stands about 104 px tall.
TARGET_HEIGHT = 208.0
PAD = 6
MIN_COMPONENT = 150
INK = (22, 12, 16)

# file, columns, rows, shared row baseline (off: per-frame foot contact keeps
# the walk planted; the generator's stride frames sit at uneven heights)
SHEETS = {
    "idle": ("idle.png", 4, 2, False),
    "walk": ("walk.png", 8, 1, False),
    "jump": ("jump.png", 8, 1, False),
}

# name: (sheet, frames, fps, loop). Speed 0 = picked by guard_visual.gd.
ANIMATIONS = {
    "idle": ("idle", range(8), 6.0, True),
    "walk": ("walk", range(8), 10.0, True),
    "crouch": ("jump", [1], 1.0, False),
    "airborne": ("jump", [3, 4, 5], 0.0, False),
    "impact": ("jump", [6], 1.0, False),
    "recover": ("jump", [6, 7], 6.0, False),
}


def load_rgba(path: Path) -> np.ndarray:
    """Float RGBA with the background keyed out."""
    img = Image.open(path)
    if img.mode == "RGBA":
        rgba = np.asarray(img).astype(np.float64)
        alpha = rgba[..., 3]
        # Near-zero alpha is generator noise; body pixels sit at 250-253.
        rgba[..., 3] = np.clip((alpha - 4.0) / (250.0 - 4.0), 0.0, 1.0) * 255.0
        return rgba

    rgb = np.asarray(img.convert("RGB")).astype(np.float64)
    black = rgb.max(axis=2) <= 2.0
    labels, count = ndimage.label(black)
    sizes = ndimage.sum(black, labels, range(1, count + 1))
    border = np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))
    keep = np.zeros(count + 1, dtype=bool)
    keep[border] = True
    # Enclosed gaps (between arm and body, between legs).
    keep[1:] |= sizes >= 120
    keep[0] = False
    background = keep[labels]
    alpha = np.where(background, 0.0, 255.0)
    return np.dstack([rgb, alpha])


def rebuild_outline(rgba: np.ndarray, width: float = 2.2) -> np.ndarray:
    """Trims the generator's noisy edge and draws a smooth ink line.

    The cutout is opened (drops stray hairs and thin motion lines), eroded by
    3 px (drops the generator's near-black noise band), then an anti-aliased outline of
    `width` px is drawn from a distance field.
    """
    solid = rgba[..., 3] > 128
    solid = ndimage.binary_opening(solid, structure=np.ones((3, 3)), iterations=1)
    solid = ndimage.binary_erosion(solid, iterations=3)
    labels, n = ndimage.label(solid, structure=np.ones((3, 3)))
    if n > 1:
        sizes = ndimage.sum(solid, labels, range(1, n + 1))
        solid = labels == (int(np.argmax(sizes)) + 1)
    dist = ndimage.distance_transform_edt(~solid)
    ink_alpha = np.clip(width + 0.5 - dist, 0.0, 1.0) * 255.0
    out = rgba.copy()
    out[~solid, 3] = 0.0
    ring = (~solid) & (ink_alpha > 0)
    out[ring, 0], out[ring, 1], out[ring, 2] = INK
    out[ring, 3] = ink_alpha[ring]
    return out


def remove_shadow(rgba: np.ndarray, mask: np.ndarray) -> np.ndarray:
    ys = np.nonzero(mask.any(axis=1))[0]
    top, bottom = ys.min(), ys.max()
    band = np.zeros_like(mask)
    band[int(bottom - (bottom - top) * 0.10):] = True
    r, g, b = rgba[..., 0], rgba[..., 1], rgba[..., 2]
    hi = np.maximum(np.maximum(r, g), b)
    lo = np.minimum(np.minimum(r, g), b)
    shadow = band & mask & (hi < 120) & (lo > 18) & (b - r < 8) & (hi - lo < 34)
    shadow = ndimage.binary_opening(shadow, iterations=1)
    shadow = ndimage.binary_dilation(shadow, iterations=1) & band & mask & (hi < 120)
    return mask & ~shadow


def extract(name: str) -> list[dict]:
    filename, cols, rows, row_baseline = SHEETS[name]
    rgba = load_rgba(SRC / filename)
    opaque = rgba[..., 3] > 20
    labels, count = ndimage.label(opaque, structure=np.ones((3, 3)))
    sizes = ndimage.sum(opaque, labels, range(1, count + 1))
    centres = ndimage.center_of_mass(opaque, labels, range(1, count + 1))
    cell_w = rgba.shape[1] / cols
    cell_h = rgba.shape[0] / rows

    best: dict[int, int] = {}
    for index in range(1, count + 1):
        if sizes[index - 1] < MIN_COMPONENT:
            continue
        cy, cx = centres[index - 1]
        cell = int(cy // cell_h) * cols + int(cx // cell_w)
        if cell not in best or sizes[index - 1] > sizes[best[cell] - 1]:
            best[cell] = index

    frames = []
    for cell in range(cols * rows):
        if cell not in best:
            raise SystemExit(f"{filename}: no character in cell {cell}")
        mask = labels == best[cell]
        mask = remove_shadow(rgba, mask)
        # The largest piece after shadow removal is the character.
        sub, n = ndimage.label(mask, structure=np.ones((3, 3)))
        if n > 1:
            s = ndimage.sum(mask, sub, range(1, n + 1))
            mask = sub == (int(np.argmax(s)) + 1)
        mask = ndimage.binary_fill_holes(mask) & (rgba[..., 3] > 0) | mask
        ys, xs = np.nonzero(mask)
        pad = 3
        y0, y1 = max(ys.min() - pad, 0), min(ys.max() + 1 + pad, rgba.shape[0])
        x0, x1 = max(xs.min() - pad, 0), min(xs.max() + 1 + pad, rgba.shape[1])
        crop = rgba[y0:y1, x0:x1].copy()
        crop[~mask[y0:y1, x0:x1]] = 0.0
        if Image.open(SRC / filename).mode != "RGBA":
            crop = rebuild_outline(crop)
        body = crop[..., 3] > 128
        rows_with = np.nonzero(body.any(axis=1))[0]
        top, foot = rows_with.min(), rows_with.max()
        head = body.copy()
        head[int(top + (foot - top) * 0.32):] = False
        frames.append(
            {
                "index": cell,
                "image": crop,
                "anchor_x": float(np.nonzero(head)[1].mean()),
                "foot_y": float(foot),
                "height": float(foot - top),
                "source_box": [int(x0), int(y0), int(x1), int(y1)],
            }
        )
    if row_baseline:
        base = max(f["foot_y"] + f["source_box"][1] for f in frames)
        for f in frames:
            f["foot_y"] = base - f["source_box"][1]
    return frames


def main() -> None:
    sheets = {name: extract(name) for name in SHEETS}
    # Every sheet starts with the same neutral standing pose: scale each sheet
    # so that pose matches TARGET_HEIGHT.
    scale = {name: TARGET_HEIGHT / frames[0]["height"] for name, frames in sheets.items()}

    left = right = up = down = 0.0
    for name, frames in sheets.items():
        k = scale[name]
        for f in frames:
            h, w = f["image"].shape[:2]
            left = max(left, f["anchor_x"] * k)
            right = max(right, (w - f["anchor_x"]) * k)
            up = max(up, f["foot_y"] * k)
            down = max(down, (h - f["foot_y"]) * k)
    canvas = (int(np.ceil(left + right)) + 2 * PAD, int(np.ceil(up + down)) + 2 * PAD)
    anchor = (int(round(left)) + PAD, int(round(up)) + PAD)

    OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.glob("*.png"):
        old.unlink()
    manifest = {
        "id": "community_aide",
        "canonical_species": "living human",
        "role": "stand-in for Court Guard",
        "canvas": list(canvas),
        "anchor": list(anchor),
        "display_scale": 0.5,
        "sheet_scale": scale,
        "frames": {},
    }
    for name, frames in sheets.items():
        k = scale[name]
        for f in frames:
            img = Image.fromarray(np.clip(f["image"], 0, 255).astype(np.uint8), "RGBA")
            size = (max(1, round(img.width * k)), max(1, round(img.height * k)))
            small = img.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")
            frame = Image.new("RGBA", canvas, (0, 0, 0, 0))
            frame.alpha_composite(
                small, (anchor[0] - int(round(f["anchor_x"] * k)), anchor[1] - int(round(f["foot_y"] * k)))
            )
            path = OUT / f"{name}_{f['index']:02d}.png"
            frame.save(path, optimize=True)
            manifest["frames"][path.name] = {"source": SHEETS[name][0], "source_box": f["source_box"]}
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=1))
    LAYOUT.write_text(
        "class_name CommunityAideSpriteLayout\n"
        "## Generated by tools/art/process_aide_sheets.py. Do not edit.\n\n"
        "## Canvas pixel that sits on the Aide's feet, under his head.\n"
        f"const ANCHOR := Vector2({anchor[0]}, {anchor[1]})\n"
        f"const CANVAS := Vector2({canvas[0]}, {canvas[1]})\n"
        f"## Standing height in canvas pixels (drawn at 0.5 scale).\n"
        f"const STANDING_HEIGHT := {TARGET_HEIGHT}\n"
    )
    write_sprite_frames()
    write_review(sheets, canvas, anchor)
    patched = 0
    for path in OUT.glob("*.png.import"):
        text = path.read_text()
        new = text.replace("mipmaps/generate=false", "mipmaps/generate=true").replace(
            "process/fix_alpha_border=false", "process/fix_alpha_border=true"
        )
        if new != text:
            path.write_text(new)
        patched += 1
    print(f"canvas {canvas}, anchor {anchor}, scale {({k: round(v, 3) for k, v in scale.items()})}, "
          f"{sum(len(v) for v in sheets.values())} frames, {patched} import files patched")


def write_sprite_frames() -> None:
    textures: list[str] = []
    for sheet, indices, _fps, _loop in ANIMATIONS.values():
        for i in indices:
            path = f"{RES_FRAMES}/{sheet}_{i:02d}.png"
            if path not in textures:
                textures.append(path)
    lines = [f'[gd_resource type="SpriteFrames" load_steps={len(textures) + 1} format=3]', ""]
    for n, path in enumerate(textures, 1):
        lines.append(f'[ext_resource type="Texture2D" path="{path}" id="{n}"]')
    blocks = []
    for name, (sheet, indices, fps, loop) in ANIMATIONS.items():
        frames = ", ".join(
            '{"duration": 1.0, "texture": ExtResource("%d")}'
            % (textures.index(f"{RES_FRAMES}/{sheet}_{i:02d}.png") + 1)
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
    lines += ["", "[resource]", "animations = [" + ", ".join(blocks) + "]"]
    TRES.parent.mkdir(parents=True, exist_ok=True)
    TRES.write_text("\n".join(lines) + "\n")


def write_review(sheets: dict, canvas: tuple, anchor: tuple) -> None:
    cols = max(len(v) for v in sheets.values())
    review = Image.new("RGB", (cols * canvas[0], len(sheets) * canvas[1]), (88, 66, 128))
    draw = ImageDraw.Draw(review)
    for r, (name, frames) in enumerate(sheets.items()):
        for f in frames:
            img = Image.open(OUT / f"{name}_{f['index']:02d}.png")
            ox, oy = f["index"] * canvas[0], r * canvas[1]
            draw.rectangle([ox, oy, ox + canvas[0] - 1, oy + canvas[1] - 1], outline=(60, 44, 90))
            review.paste(img, (ox, oy), img)
            ax, ay = ox + anchor[0], oy + anchor[1]
            draw.line([ax - 8, ay, ax + 8, ay], fill=(80, 255, 200), width=2)
            draw.line([ax, ay - 8, ax, ay + 8], fill=(80, 255, 200), width=2)
    REVIEW.parent.mkdir(parents=True, exist_ok=True)
    review.save(REVIEW, optimize=True)


if __name__ == "__main__":
    main()
