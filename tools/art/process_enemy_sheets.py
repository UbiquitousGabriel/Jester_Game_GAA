#!/usr/bin/env python3
"""Turns enemy sprite sheets into aligned Godot frames. Config-driven.

Sheets sit on the generator's near-white checker (same keying and edge
un-blending as tools/art/process_jester_sheets.py). Rows may hold different
frame counts, so rows are found from horizontal gaps and frames are the large
islands in each row, sorted left to right; small islands (effects, debris,
alert marks) join the nearest frame.

Anchors:
  "feet"  ground units. Horizontal: head band centre (stable while weapons
          swing). Vertical: lowest body pixel after painted shadow lines
          (thin horizontal strokes) are removed.
  "skull" flyers. Centre of the pale skull (the bone-coloured region holding
          eye holes); the physics origin is the body centre.

Usage: python3 tools/art/process_enemy_sheets.py   (needs numpy, scipy, Pillow)
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

sys.path.insert(0, str(Path(__file__).resolve().parent))
import process_jester_sheets as base  # noqa: E402  (shared keying helpers)

ROOT = Path(__file__).resolve().parents[2]
PAD = 6

ENEMIES = {
    "mace_knight": {
        "sheet": "assets/source/enemies/mace_knight/mace_knight_sheet.png",
        "rows": [7, 8, 8, 5, 7],
        "row_names": ["idle", "walk", "attack", "hurt", "death"],
        "anchor": "feet",
        # Idle body height in output pixels (2x): about 112 px in game.
        "reference_height": 224.0,
        "animations": {
            "idle": ("idle", range(7), 8.0, True),
            "walk": ("walk", range(8), 11.0, True),
            "windup": ("attack", [0, 1, 2, 3], 0.0, False),
            "slam": ("attack", [4, 5, 6, 7], 0.0, False),
            "hurt": ("hurt", [1, 2, 3, 4], 14.0, False),
            "launched": ("hurt", [3], 1.0, False),
            "death": ("death", range(7), 10.0, False),
        },
    },
    "bat_knight": {
        "sheet": "assets/source/enemies/bat_knight/bat_knight_sheet.png",
        "rows": [6, 6, 6, 4, 6],
        "row_names": ["fly", "glide", "attack", "hurt", "death"],
        "anchor": "skull",
        # Idle wingspan in output pixels (2x): about 150 px in game.
        "reference_width": 300.0,
        "animations": {
            "fly": ("fly", range(6), 12.0, True),
            "glide": ("glide", range(6), 12.0, True),
            "swoop": ("attack", [0, 1, 2, 3, 4, 5], 0.0, False),
            "hurt": ("hurt", [1, 2, 3], 14.0, False),
            "launched": ("hurt", [2], 1.0, False),
            "death": ("death", range(6), 9.0, False),
        },
    },
}


def find_rows(opaque: np.ndarray, expected: int) -> list[tuple[int, int]]:
    filled = opaque.any(axis=1)
    bands, start = [], None
    for y, on in enumerate(filled):
        if on and start is None:
            start = y
        elif not on and start is not None:
            bands.append((start, y))
            start = None
    if start is not None:
        bands.append((start, len(filled)))
    # Merge bands separated by tiny gaps (effects floating above a frame).
    bands = [b for b in bands if b[1] - b[0] > 6]
    while len(bands) > expected:
        gaps = [bands[i + 1][0] - bands[i][1] for i in range(len(bands) - 1)]
        i = int(np.argmin(gaps))
        bands[i] = (bands[i][0], bands[i + 1][1])
        del bands[i + 1]
    if len(bands) != expected:
        raise SystemExit(f"found {len(bands)} rows, expected {expected}")
    return bands


def remove_shadow_lines(rgba: np.ndarray, mask: np.ndarray) -> np.ndarray:
    """Drops thin, dark, horizontal strokes (painted ground lines)."""
    dark = mask & (rgba[..., :3].max(axis=2) < 90)
    thick = ndimage.binary_opening(dark, structure=np.ones((5, 1)))
    thin_dark = dark & ~thick
    # Only strokes in the bottom band count as ground lines.
    ys = np.nonzero(mask.any(axis=1))[0]
    band = np.zeros_like(mask)
    band[int(ys.max() - (ys.max() - ys.min()) * 0.12):] = True
    return mask & ~(thin_dark & band)


def skull_centre(rgba: np.ndarray, body: np.ndarray) -> tuple[float, float]:
    r, g, b = rgba[..., 0], rgba[..., 1], rgba[..., 2]
    hi = np.maximum(np.maximum(r, g), b)
    lo = np.minimum(np.minimum(r, g), b)
    bone = body & (lo > 130) & (hi - lo < 60)
    labels, count = ndimage.label(bone)
    best, best_score = 0, 0.0
    for index, sl in enumerate(ndimage.find_objects(labels), 1):
        region = labels[sl] == index
        holes = ndimage.binary_fill_holes(region).sum() - region.sum()
        score = region.sum() + holes * 4.0
        if region.sum() > 80 and score > best_score:
            best, best_score = index, score
    if best == 0:
        ys, xs = np.nonzero(body)
        return float(xs.mean()), float(ys.mean())
    ys, xs = np.nonzero(ndimage.binary_fill_holes(labels == best))
    return float(xs.mean()), float(ys.mean())


def head_centre_x(body: np.ndarray) -> float:
    ys = np.nonzero(body.any(axis=1))[0]
    top, bottom = ys.min(), ys.max()
    band = body.copy()
    band[: int(top + (bottom - top) * 0.06)] = False
    band[int(top + (bottom - top) * 0.38):] = False
    band = ndimage.binary_opening(band, iterations=2)
    labels, n = ndimage.label(band)
    if n == 0:
        return float(np.nonzero(body)[1].mean())
    sizes = ndimage.sum(band, labels, range(1, n + 1))
    return float(np.nonzero(labels == int(np.argmax(sizes)) + 1)[1].mean())


def extract(cfg: dict) -> dict[str, list[dict]]:
    rgb = np.asarray(Image.open(ROOT / cfg["sheet"]).convert("RGB")).astype(np.float64)
    # Torn wings and armour gaps leave tiny checker holes: clear them too.
    rgba = base.unblend(rgb, base.key_background(rgb, min_hole=4))
    opaque = rgba[..., 3] > 8
    labels, count = ndimage.label(opaque, structure=np.ones((3, 3)))
    sizes = ndimage.sum(opaque, labels, range(1, count + 1))
    centres = ndimage.center_of_mass(opaque, labels, range(1, count + 1))
    rows = find_rows(opaque, len(cfg["rows"]))
    result = {}
    for row_index, (y0, y1) in enumerate(rows):
        members = [i for i in range(1, count + 1) if y0 <= centres[i - 1][0] < y1 and sizes[i - 1] >= 30]
        biggest = max(sizes[i - 1] for i in members)
        mains = sorted((i for i in members if sizes[i - 1] >= biggest * 0.25), key=lambda i: centres[i - 1][1])
        expected = cfg["rows"][row_index]
        if len(mains) != expected:
            raise SystemExit(f"{cfg['sheet']}: row {row_index} has {len(mains)} frames, expected {expected}")
        groups = {m: [m] for m in mains}
        for i in members:
            if i in groups:
                continue
            nearest = min(mains, key=lambda m: abs(centres[m - 1][1] - centres[i - 1][1]))
            groups[nearest].append(i)
        frames = []
        for main in mains:
            mask = np.isin(labels, groups[main])
            body = labels == main
            if cfg["anchor"] == "feet":
                mask = remove_shadow_lines(rgba, mask)
                body = body & mask
            ys, xs = np.nonzero(mask)
            fy0, fy1, fx0, fx1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
            crop = rgba[fy0:fy1, fx0:fx1].copy()
            crop[~mask[fy0:fy1, fx0:fx1]] = 0.0
            body_crop = body[fy0:fy1, fx0:fx1]
            if cfg["anchor"] == "skull":
                ax, ay = skull_centre(crop, body_crop)
            else:
                ax = head_centre_x(body_crop)
                ay = float(np.nonzero(body_crop.any(axis=1))[0].max())
            frames.append({"image": crop, "anchor_x": ax, "anchor_y": ay,
                           "size": (fx1 - fx0, fy1 - fy0), "source_box": [int(fx0), int(fy0), int(fx1), int(fy1)]})
        result[cfg["row_names"][row_index]] = frames
    return result


def build(name: str, cfg: dict) -> None:
    sheets = extract(cfg)
    first = sheets[cfg["row_names"][0]][0]
    if "reference_height" in cfg:
        k = cfg["reference_height"] / first["size"][1]
    else:
        k = cfg["reference_width"] / first["size"][0]

    left = right = up = down = 0.0
    for frames in sheets.values():
        for f in frames:
            w, h = f["size"]
            left = max(left, f["anchor_x"] * k)
            right = max(right, (w - f["anchor_x"]) * k)
            up = max(up, f["anchor_y"] * k)
            down = max(down, (h - f["anchor_y"]) * k)
    canvas = (int(np.ceil(left + right)) + 2 * PAD, int(np.ceil(up + down)) + 2 * PAD)
    anchor = (int(round(left)) + PAD, int(round(up)) + PAD)

    out = ROOT / "assets" / "characters" / name / "frames"
    out.mkdir(parents=True, exist_ok=True)
    for old in out.glob("*.png"):
        old.unlink()
    manifest = {"id": name, "canvas": list(canvas), "anchor": list(anchor), "scale": k,
                "anchor_mode": cfg["anchor"], "source": cfg["sheet"], "frames": {}}
    for row_name, frames in sheets.items():
        for i, f in enumerate(frames):
            img = Image.fromarray(np.clip(f["image"], 0, 255).astype(np.uint8), "RGBA")
            size = (max(1, round(img.width * k)), max(1, round(img.height * k)))
            small = img.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")
            frame = Image.new("RGBA", canvas, (0, 0, 0, 0))
            frame.alpha_composite(small, (anchor[0] - int(round(f["anchor_x"] * k)),
                                          anchor[1] - int(round(f["anchor_y"] * k))))
            path = out / f"{row_name}_{i:02d}.png"
            frame.save(path, optimize=True)
            manifest["frames"][path.name] = {"source_box": f["source_box"]}
    (out / "manifest.json").write_text(json.dumps(manifest, indent=1))

    class_name = "".join(part.title() for part in name.split("_")) + "SpriteLayout"
    layout = ROOT / "scripts" / "animation" / f"{name}_sprite_layout.gd"
    point = "feet" if cfg["anchor"] == "feet" else "body centre (skull)"
    layout.write_text(
        f"class_name {class_name}\n"
        "## Generated by tools/art/process_enemy_sheets.py. Do not edit.\n\n"
        f"## Canvas pixel on the character's {point}.\n"
        f"const ANCHOR := Vector2({anchor[0]}, {anchor[1]})\n"
        f"const CANVAS := Vector2({canvas[0]}, {canvas[1]})\n"
    )
    write_sprite_frames(name, cfg)
    write_review(name, sheets, out, canvas, anchor)
    for path in out.glob("*.png.import"):
        text = path.read_text()
        path.write_text(text.replace("mipmaps/generate=false", "mipmaps/generate=true"))
    print(f"{name}: canvas {canvas}, anchor {anchor}, scale {k:.3f}, "
          f"{sum(len(v) for v in sheets.values())} frames")


def write_sprite_frames(name: str, cfg: dict) -> None:
    res = f"res://assets/characters/{name}/frames"
    textures: list[str] = []
    for row, indices, _fps, _loop in cfg["animations"].values():
        for i in indices:
            path = f"{res}/{row}_{i:02d}.png"
            if path not in textures:
                textures.append(path)
    lines = [f'[gd_resource type="SpriteFrames" load_steps={len(textures) + 1} format=3]', ""]
    for n, path in enumerate(textures, 1):
        lines.append(f'[ext_resource type="Texture2D" path="{path}" id="{n}"]')
    blocks = []
    for anim, (row, indices, fps, loop) in cfg["animations"].items():
        frames = ", ".join('{"duration": 1.0, "texture": ExtResource("%d")}'
                           % (textures.index(f"{res}/{row}_{i:02d}.png") + 1) for i in indices)
        blocks.append("{\n" f'"frames": [{frames}],\n' f'"loop": {"true" if loop else "false"},\n'
                      f'"name": &"{anim}",\n' f'"speed": {fps}\n' "}")
    lines += ["", "[resource]", "animations = [" + ", ".join(blocks) + "]"]
    path = ROOT / "resources" / "animation" / f"{name}_frames.tres"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n")


def write_review(name: str, sheets: dict, out: Path, canvas: tuple, anchor: tuple) -> None:
    cols = max(len(v) for v in sheets.values())
    review = Image.new("RGB", (cols * canvas[0], len(sheets) * canvas[1]), (88, 66, 128))
    draw = ImageDraw.Draw(review)
    for r, (row_name, frames) in enumerate(sheets.items()):
        for i in range(len(frames)):
            img = Image.open(out / f"{row_name}_{i:02d}.png")
            ox, oy = i * canvas[0], r * canvas[1]
            draw.rectangle([ox, oy, ox + canvas[0] - 1, oy + canvas[1] - 1], outline=(60, 44, 90))
            review.paste(img, (ox, oy), img)
            ax, ay = ox + anchor[0], oy + anchor[1]
            draw.line([ax - 8, ay, ax + 8, ay], fill=(80, 255, 200), width=2)
            draw.line([ax, ay - 8, ax, ay + 8], fill=(80, 255, 200), width=2)
    path = ROOT / "docs" / "art" / f"{name}_alignment.png"
    review.save(path, optimize=True)


def main() -> None:
    for name, cfg in ENEMIES.items():
        build(name, cfg)


if __name__ == "__main__":
    main()
