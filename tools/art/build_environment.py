#!/usr/bin/env python3
"""Builds the Carnival Gate art the tileset pack does not cover: sky,
parallax backdrops, lamp posts, checkpoint flags, the gate sign and effect
textures. Terrain, platforms and most props come from the pack
(tools/art/slice_tileset.py).

Painterly look without hand painting: shapes are authored as SVG (gradients,
ink outlines on gameplay-layer art only), rasterised with cairosvg, then given
a brush-grain pass (multi-octave value noise) in numpy. Backdrops get no ink
and an atmospheric haze ramp so the outlined characters stay readable on top
(Bible section 6: contrasting value planes).

Gameplay-layer art is authored at 2x and drawn at 0.5 with mipmaps, like the
characters. Backdrops are authored at 1x world scale.

Usage: python3 tools/art/build_environment.py   (needs cairosvg, numpy, Pillow)
"""
import io
import math
import random
from pathlib import Path

import cairosvg
import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "environments" / "carnival_gate"
FX = ROOT / "assets" / "effects"
SVG_OUT = ROOT / "assets" / "source" / "environment_svg"

INK = "#1c0f24"
CRIMSON, CRIMSON_D, CRIMSON_L = "#cf2744", "#8f1730", "#ee5a6f"
PURPLE, PURPLE_D, PURPLE_L = "#7040a8", "#46246e", "#9a6fd0"
GOLD, GOLD_D, GOLD_L = "#f7c23c", "#c98a1c", "#ffe58a"
CREAM, CREAM_D = "#f8efdc", "#d6c3a6"
WOOD, WOOD_D, WOOD_L = "#a8683a", "#6e3f22", "#d0965e"
STEEL, STEEL_D, STEEL_L = "#b8bfd4", "#6f7691", "#eef2fb"

SK = f'stroke="{INK}" stroke-linejoin="round" stroke-linecap="round"'


# --------------------------------------------------------------------------- helpers


def svg_image(w: int, h: int, body: str, name: str | None = None) -> Image.Image:
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{body}</svg>'
    if name:
        SVG_OUT.mkdir(parents=True, exist_ok=True)
        (SVG_OUT / f"{name}.svg").write_text(svg)
    png = cairosvg.svg2png(bytestring=svg.encode())
    return Image.open(io.BytesIO(png)).convert("RGBA")


def value_noise(w: int, h: int, seed: int, octaves: int = 4, base: int = 8, wrap: bool = True) -> np.ndarray:
    """Seamless (when wrap) multi-octave value noise in [-1, 1]."""
    rng = np.random.default_rng(seed)
    total = np.zeros((h, w))
    amp, norm = 1.0, 0.0
    for o in range(octaves):
        cells = base * (2 ** o)
        gw, gh = max(2, cells), max(2, int(cells * h / w))
        grid = rng.random((gh, gw))
        if wrap:
            grid = np.pad(grid, ((0, 1), (0, 1)), mode="wrap")
            img = Image.fromarray((grid * 255).astype(np.uint8)).resize(
                (w + w // gw, h + h // gh), Image.BICUBIC
            )
            layer = np.asarray(img).astype(np.float64)[:h, :w] / 255.0
        else:
            img = Image.fromarray((grid * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
            layer = np.asarray(img).astype(np.float64) / 255.0
        total += layer * amp
        norm += amp
        amp *= 0.5
    return (total / norm) * 2.0 - 1.0


def grain(img: Image.Image, strength: float, seed: int, wrap: bool = True, base: int = 10) -> Image.Image:
    """Painterly brush grain: modulates value, keeps alpha."""
    a = np.asarray(img).astype(np.float64)
    n = value_noise(img.width, img.height, seed, octaves=5, base=base, wrap=wrap)
    fine = np.random.default_rng(seed + 1).normal(0.0, 1.0, (img.height, img.width))
    mod = 1.0 + strength * n + strength * 0.25 * fine
    a[..., :3] = np.clip(a[..., :3] * mod[..., None], 0, 255)
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def save(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, optimize=True)


def hexc(c: str) -> tuple[int, int, int]:
    c = c.lstrip("#")
    return tuple(int(c[i:i + 2], 16) for i in (0, 2, 4))


def lerp_color(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def star_points(cx, cy, outer, inner, points=5, rot=-90):
    pts = []
    for i in range(points * 2):
        r = outer if i % 2 == 0 else inner
        ang = math.radians(rot + i * 180 / points)
        pts.append(f"{cx + r * math.cos(ang):.1f},{cy + r * math.sin(ang):.1f}")
    return " ".join(pts)


def crown_path(x, y, w, h):
    return (f"M{x} {y + h} L{x - w * .08} {y + h * .25} L{x + w * .25} {y + h * .6} L{x + w * .5} {y} "
            f"L{x + w * .75} {y + h * .6} L{x + w * 1.08} {y + h * .25} L{x + w} {y + h} Z")


def glow_layer(size, points, seed=0) -> Image.Image:
    """Soft additive glows: points = [(x, y, radius, (r,g,b), strength)]."""
    w, h = size
    yy, xx = np.mgrid[0:h, 0:w]
    out = np.zeros((h, w, 3))
    for x, y, r, col, s in points:
        x0, x1 = max(0, int(x - r * 2)), min(w, int(x + r * 2))
        y0, y1 = max(0, int(y - r * 2)), min(h, int(y + r * 2))
        if x0 >= x1 or y0 >= y1:
            continue
        d2 = ((xx[y0:y1, x0:x1] - x) ** 2 + (yy[y0:y1, x0:x1] - y) ** 2) / (r * r)
        g = np.exp(-d2 * 2.2) * s
        out[y0:y1, x0:x1] += g[..., None] * np.array(col)
    return out


def add_glow(img: Image.Image, points) -> Image.Image:
    a = np.asarray(img).astype(np.float64)
    g = glow_layer(img.size, points)
    a[..., :3] = np.clip(a[..., :3] + g, 0, 255)
    lum = g.max(axis=2) / 255.0
    a[..., 3] = np.clip(np.maximum(a[..., 3], lum * 255.0), 0, 255)
    return Image.fromarray(a.astype(np.uint8), "RGBA")


# --------------------------------------------------------------------------- sky


def build_sky() -> None:
    w, h = 2048, 1152
    stops = [(0.0, "#120a2b"), (0.32, "#2f1757"), (0.55, "#6a2a78"), (0.74, "#bf4d7e"),
             (0.88, "#f08a6e"), (1.0, "#ffc58a")]
    y = np.linspace(0, 1, h)
    col = np.zeros((h, 3))
    for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
        m = (y >= t0) & (y <= t1)
        k = ((y[m] - t0) / (t1 - t0))[:, None]
        col[m] = np.array(hexc(c0)) * (1 - k) + np.array(hexc(c1)) * k
    sky = np.repeat(col[:, None, :], w, axis=1)
    # Large soft colour drifts so it is not a flat ramp.
    drift = value_noise(w, h, 3, octaves=3, base=3, wrap=False)
    sky *= (1.0 + 0.06 * drift)[..., None]

    rnd = random.Random(42)
    stars = Image.new("L", (w, h), 0)
    px = stars.load()
    for _ in range(900):
        sx, sy = rnd.randrange(w), int(rnd.random() ** 1.7 * h * 0.62)
        px[sx, sy] = min(255, int(rnd.uniform(90, 255) * (1 - sy / (h * 0.62))))
    star_arr = np.asarray(stars.filter(ImageFilter.GaussianBlur(0.6))).astype(np.float64) * 2.2
    sky += star_arr[..., None] * np.array([1.0, 0.95, 0.9])
    glints = []
    for _ in range(14):
        glints.append((rnd.randrange(w), rnd.randrange(int(h * 0.4)), rnd.uniform(4, 9), (255, 240, 220), 0.9))

    img = Image.fromarray(np.clip(sky, 0, 255).astype(np.uint8)).convert("RGBA")

    # Clouds: layered soft ellipses, lit warm from below.
    clouds = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    cl = Image.new("L", (w, h), 0)
    from PIL import ImageDraw
    d = ImageDraw.Draw(cl)
    for band_y, count in ((0.60, 9), (0.70, 12), (0.80, 10)):
        for _ in range(count):
            cx = rnd.randrange(-200, w + 200)
            cy = int(h * band_y + rnd.uniform(-40, 40))
            for _k in range(rnd.randint(3, 6)):
                ex, ey = cx + rnd.uniform(-160, 160), cy + rnd.uniform(-18, 18)
                rx, ry = rnd.uniform(90, 240), rnd.uniform(16, 38)
                d.ellipse([ex - rx, ey - ry, ex + rx, ey + ry], fill=rnd.randint(110, 200))
    cl = cl.filter(ImageFilter.GaussianBlur(14))
    cmask = np.asarray(cl).astype(np.float64) / 255.0
    yy = np.linspace(0, 1, h)[:, None]
    cloud_col = np.where(yy < 0.72, 1, 0) * np.array(hexc("#d97a9a")) + np.where(yy >= 0.72, 1, 0) * np.array(hexc("#ffb38a"))
    cloud_col = np.broadcast_to(cloud_col[:, None, :] if cloud_col.ndim == 2 else cloud_col, (h, w, 3))
    base = np.asarray(img).astype(np.float64)
    base[..., :3] = base[..., :3] * (1 - cmask[..., None] * 0.55) + cloud_col * cmask[..., None] * 0.55
    img = Image.fromarray(np.clip(base, 0, 255).astype(np.uint8), "RGBA")

    # Moon with halo.
    moon = svg_image(w, h, f"""
<defs><radialGradient id="m" cx="0.42" cy="0.4" r="0.7"><stop offset="0" stop-color="#fffaf0"/>
<stop offset="0.7" stop-color="#ffe7c2"/><stop offset="1" stop-color="#f5c9a0"/></radialGradient></defs>
<circle cx="1530" cy="250" r="96" fill="url(#m)"/>
<circle cx="1500" cy="225" r="16" fill="#f0cfa8" opacity="0.55"/>
<circle cx="1565" cy="280" r="22" fill="#f0cfa8" opacity="0.45"/>
<circle cx="1548" cy="214" r="9" fill="#f0cfa8" opacity="0.5"/>""")
    img = add_glow(img, [(1530, 250, 420, (255, 190, 170), 0.35), (1530, 250, 170, (255, 230, 200), 0.5)] + glints)
    img.alpha_composite(moon)
    a = np.asarray(img).astype(np.float64)
    a[..., :3] += np.random.default_rng(7).normal(0, 1.4, (h, w, 1))  # dither: no banding
    a[..., 3] = 255
    save(Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA"), OUT / "sky.png")


# --------------------------------------------------------------------------- backdrops


def haze(img: Image.Image, top_col: str, bottom_col: str, amount_top: float, amount_bottom: float) -> Image.Image:
    """Atmospheric perspective: blend toward haze colour, stronger low down."""
    a = np.asarray(img).astype(np.float64)
    h = img.height
    t = np.linspace(0, 1, h)[:, None]
    hc = np.array(hexc(top_col)) * (1 - t) + np.array(hexc(bottom_col)) * t
    amt = amount_top * (1 - t) + amount_bottom * t
    a[..., :3] = a[..., :3] * (1 - amt[..., None]) + hc[:, None, :] * amt[..., None]
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")


def build_castle() -> None:
    """Far layer: the castle on its hill, hazy violet, lit windows.
    3200 px wide so it spans the screen over the whole level without tiling
    (it scrolls at 0.1, about 430 px across the level)."""
    w, h = 3200, 1100
    rnd = random.Random(11)
    wall, shade, roof, roof_d = "#6a55a2", "#594690", "#8a62ad", "#74529c"
    parts = [f'<path d="M0 {h} L0 800 C700 700 1100 610 1600 590 C2100 610 2500 700 3200 800 L3200 {h} Z" fill="#6c55a6"/>',
             f'<path d="M0 {h} L0 880 C800 820 1200 790 1600 795 C2000 800 2400 840 3200 890 L3200 {h} Z" fill="#5e4896"/>']
    windows = []
    parts.append(f'<rect x="620" y="470" width="1160" height="170" fill="{wall}"/>')
    for i in range(29):
        parts.append(f'<rect x="{620 + i * 40}" y="452" width="22" height="22" fill="{wall}"/>')
    towers = [(560, 380, 100), (720, 280, 120), (880, 170, 150), (1090, 90, 190), (1320, 190, 150), (1500, 290, 116), (1660, 380, 100)]
    for x, top, tw in towers:
        parts.append(f'<rect x="{x}" y="{top}" width="{tw}" height="{640 - top}" fill="{wall}"/>')
        parts.append(f'<rect x="{x + tw * 0.62:.0f}" y="{top}" width="{tw * 0.38:.0f}" height="{640 - top}" fill="{shade}"/>')
        peak = top - tw * 1.15
        parts.append(f'<path d="M{x - 14} {top} L{x + tw / 2} {peak:.0f} L{x + tw + 14} {top} Z" fill="{roof}"/>')
        parts.append(f'<path d="M{x + tw / 2} {peak:.0f} L{x + tw + 14} {top} L{x + tw / 2 + 6} {top} Z" fill="{roof_d}"/>')
        parts.append(f'<path d="M{x + tw / 2} {peak:.0f} v-46" stroke="#5b4790" stroke-width="4"/>')
        parts.append(f'<path d="M{x + tw / 2} {peak - 46:.0f} l40 12 l-40 12 Z" fill="#e65c86"/>')
        for wy in range(top + 50, 600, 74):
            for fx in (0.3, 0.62):
                if rnd.random() < 0.32:
                    wx = x + tw * fx
                    parts.append(f'<rect x="{wx:.0f}" y="{wy}" width="14" height="28" rx="7" fill="#ffd690"/>')
                    windows.append((wx + 7, wy + 14, 26, (255, 190, 110), 0.55))
    for i in range(0, 14, 3):
        wx = 680 + i * 80
        parts.append(f'<rect x="{wx}" y="540" width="16" height="30" rx="8" fill="#ffd690"/>')
        windows.append((wx + 8, 555, 30, (255, 180, 100), 0.5))
    # Castle drawn small and hazy so it reads as distant, not towering.
    hills = parts[:2]
    castle = parts[2:]
    body = ("".join(hills[:1]) + '<g transform="translate(1080 470) scale(0.44)">' + "".join(castle) + "</g>"
            + hills[1])
    windows = [(1080 + x * 0.44, 470 + y * 0.44, r * 0.44, c, s) for x, y, r, c, s in windows]
    img = svg_image(w, h, body, "castle_far")
    img = add_glow(img, windows)
    img = haze(img, "#8a6ab4", "#c06f92", 0.3, 0.5)
    img = grain(img, 0.05, 31, wrap=False)
    save(img, OUT / "castle_far.png")


def tent_svg(x, base, w, h, a, b, light=None, ink=False):
    """Big-top tent. a/b: stripe colours. Returns svg string."""
    top = base - h
    roof_h = h * 0.45
    peak = (x + w / 2, top)
    stroke = f' {SK} stroke-width="6"' if ink else ""
    s = []
    n = 8
    for i in range(n):
        x0 = x + w * i / n
        x1 = x + w * (i + 1) / n
        s.append(f'<path d="M{peak[0]:.0f} {peak[1]:.0f} L{x0:.0f} {top + roof_h:.0f} L{x1:.0f} {top + roof_h:.0f} Z" fill="{a if i % 2 == 0 else b}"/>')
    body_x, body_w = x + w * 0.08, w * 0.84
    for i in range(n):
        bx = body_x + body_w * i / n
        s.append(f'<rect x="{bx:.0f}" y="{top + roof_h:.0f}" width="{body_w / n + 1:.0f}" height="{h - roof_h:.0f}" fill="{b if i % 2 == 0 else a}"/>')
    s.append(f'<rect x="{body_x:.0f}" y="{top + roof_h:.0f}" width="{body_w:.0f}" height="{h - roof_h:.0f}" fill="#000" opacity="0.18"/>')
    door_w = w * 0.18
    s.append(f'<path d="M{x + w / 2 - door_w / 2:.0f} {base} V{base - h * 0.28:.0f} a{door_w / 2:.0f} {door_w / 1.6:.0f} 0 0 1 {door_w:.0f} 0 V{base} Z" fill="{light or "#1a0f2a"}"/>')
    s.append(f'<path d="M{peak[0]:.0f} {peak[1]:.0f} L{x:.0f} {top + roof_h:.0f} L{x + w:.0f} {top + roof_h:.0f} Z" fill="none"{stroke}/>')
    for i in range(n):
        sx = x + w * i / n
        s.append(f'<path d="M{sx:.0f} {top + roof_h:.0f} h{w / n:.0f} v8 a{w / n / 2:.0f} {w / n / 2.4:.0f} 0 0 1 -{w / n:.0f} 0 Z" fill="{b if i % 2 == 0 else a}"/>')
    s.append(f'<path d="M{peak[0]:.0f} {peak[1]:.0f} v-38" stroke="#2a1838" stroke-width="5"/>')
    s.append(f'<path d="M{peak[0]:.0f} {peak[1] - 38:.0f} l34 10 l-34 10 Z" fill="{GOLD}"/>')
    return "".join(s)


def build_far_carnival() -> None:
    """Mid-far layer: tents, Ferris wheel, string lights. Seamless horizontally."""
    w, h = 2400, 900
    rnd = random.Random(5)
    ground = 640
    body = [f'<rect x="0" y="{ground}" width="{w}" height="{h - ground}" fill="#3a2662"/>',
            f'<path d="M0 {ground + 8} C400 {ground - 20} 800 {ground + 16} 1200 {ground - 6} C1600 {ground - 24} 2000 {ground + 10} 2400 {ground + 8} L2400 {h} L0 {h} Z" fill="#3a2662"/>']
    glows = []
    cx, cy, r = 1720, 300, 230
    body.append(f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="#4d3480" stroke-width="12"/>')
    body.append(f'<circle cx="{cx}" cy="{cy}" r="{r * 0.6:.0f}" fill="none" stroke="#4d3480" stroke-width="6"/>')
    body.append(f'<path d="M{cx} {cy} L{cx - 110} {ground} M{cx} {cy} L{cx + 110} {ground}" stroke="#4d3480" stroke-width="16"/>')
    bulb_cols = [(255, 200, 90), (255, 110, 150), (170, 140, 255), (120, 230, 220)]
    for i in range(16):
        ang = math.radians(i * 22.5)
        px, py = cx + r * math.cos(ang), cy + r * math.sin(ang)
        body.append(f'<path d="M{cx} {cy} L{px:.0f} {py:.0f}" stroke="#4d3480" stroke-width="5"/>')
        body.append(f'<rect x="{px - 18:.0f}" y="{py - 2:.0f}" width="36" height="28" rx="9" fill="#5b3f92"/>')
    for i in range(48):
        ang = math.radians(i * 7.5)
        px, py = cx + r * math.cos(ang), cy + r * math.sin(ang)
        col = bulb_cols[i % 4]
        body.append(f'<circle cx="{px:.0f}" cy="{py:.0f}" r="5" fill="rgb{col}"/>')
        glows.append((px, py, 18, col, 0.55))
    body.append(f'<circle cx="{cx}" cy="{cy}" r="22" fill="{GOLD}"/>')
    tents = [(40, 300, 220), (420, 380, 300), (900, 260, 200), (1180, 330, 250), (2050, 290, 230)]
    tent_cols = [("#5a3880", "#6d4a92"), ("#6a3270", "#7c4a84"), ("#4e3a86", "#64529a")]
    for i, (tx, tw, th) in enumerate(tents):
        a, b = tent_cols[i % 3]
        body.append(tent_svg(tx, ground + 10, tw, th, a, b, light="#ffbe78"))
        glows.append((tx + tw / 2, ground - th * 0.15, 60, (255, 170, 90), 0.5))
    # String lights between poles (wraps at the tile edge).
    poles = [0, 380, 860, 1160, 1460, 2000, 2400]
    for p in poles:
        body.append(f'<rect x="{p - 4}" y="{ground - 240}" width="8" height="250" fill="#2e1d4f"/>')
    for p0, p1 in zip(poles, poles[1:]):
        sag = 60
        ys = ground - 236
        body.append(f'<path d="M{p0} {ys} Q{(p0 + p1) / 2} {ys + sag * 2} {p1} {ys}" fill="none" stroke="#2e1d4f" stroke-width="3"/>')
        for k in range(1, 9):
            t = k / 9
            bx = (1 - t) ** 2 * p0 + 2 * (1 - t) * t * (p0 + p1) / 2 + t * t * p1
            by = (1 - t) ** 2 * ys + 2 * (1 - t) * t * (ys + sag * 2) + t * t * ys
            col = bulb_cols[(k + p0) % 4]
            body.append(f'<circle cx="{bx:.0f}" cy="{by + 6:.0f}" r="5" fill="rgb{col}"/>')
            glows.append((bx, by + 6, 16, col, 0.5))
    img = svg_image(w, h, "".join(body), "carnival_far")
    img = add_glow(img, glows)
    img = haze(img, "#7b5aa8", "#a2628e", 0.12, 0.35)
    img = grain(img, 0.05, 41, wrap=True)
    save(img, OUT / "carnival_far.png")


def build_near_carnival() -> None:
    """Near layer: darker, closer tents, bunting, lamp posts. Seamless."""
    w, h = 2400, 900
    ground = 700
    body = [f'<rect x="0" y="{ground}" width="{w}" height="{h - ground}" fill="#24163c"/>']
    glows = []
    tent_specs = [(-120, 520, 420, CRIMSON_D, "#5c2042"), (700, 440, 360, "#4b2a7a", "#2f1a52"),
                  (1450, 560, 460, "#8a2a52", "#4a1a3a"), (2280, 520, 420, CRIMSON_D, "#5c2042")]
    for tx, tw, th, a, b in tent_specs:
        body.append(tent_svg(tx, ground + 6, tw, th, a, b, light="#ffb26a"))
        glows.append((tx + tw / 2, ground - th * 0.12, 90, (255, 160, 80), 0.6))
    # Fence
    for i in range(0, w, 36):
        body.append(f'<rect x="{i}" y="{ground - 58}" width="18" height="64" rx="4" fill="#1d1131"/>')
    body.append(f'<rect x="0" y="{ground - 46}" width="{w}" height="10" fill="#1d1131"/>')
    # Bunting
    flag_cols = [CRIMSON, GOLD, PURPLE_L, CREAM]
    for row, (y0, sag) in enumerate(((190, 70),)):
        for seg in range(4):
            x0, x1 = seg * 600, seg * 600 + 600
            body.append(f'<path d="M{x0} {y0} Q{x0 + 300} {y0 + sag * 2} {x1} {y0}" fill="none" stroke="#1d1131" stroke-width="3"/>')
            for k in range(12):
                t = (k + 0.5) / 12
                bx = (1 - t) ** 2 * x0 + 2 * (1 - t) * t * (x0 + 300) + t * t * x1
                by = (1 - t) ** 2 * y0 + 2 * (1 - t) * t * (y0 + sag * 2) + t * t * y0
                col = flag_cols[(k + row + seg) % 4]
                body.append(f'<path d="M{bx - 16:.0f} {by:.0f} L{bx + 16:.0f} {by:.0f} L{bx:.0f} {by + 34:.0f} Z" fill="{col}" opacity="0.6"/>')
    # Lamp posts
    for lx in (380, 1240, 2050):
        body.append(f'<rect x="{lx - 6}" y="{ground - 330}" width="12" height="336" fill="#1d1131"/>')
        body.append(f'<path d="M{lx - 30} {ground - 330} h60 l-10 -46 h-40 Z" fill="#1d1131"/>')
        body.append(f'<rect x="{lx - 16}" y="{ground - 372}" width="32" height="40" rx="8" fill="#ffd38a"/>')
        glows.append((lx, ground - 352, 120, (255, 170, 90), 0.75))
        glows.append((lx, ground - 352, 40, (255, 230, 170), 0.9))
    img = svg_image(w, h, "".join(body), "carnival_near")
    img = add_glow(img, glows)
    img = haze(img, "#4a3070", "#6a3a6e", 0.1, 0.22)
    img = grain(img, 0.06, 51, wrap=True)
    save(img, OUT / "carnival_near.png")


# --------------------------------------------------------------------------- props (2x)


def build_props() -> None:
    def flag(active):
        cloth, trim, knob = (CRIMSON, GOLD, GOLD) if active else ("#6d6187", "#a59bbd", "#a59bbd")
        return svg_image(140, 300, f"""
<rect x="20" y="24" width="12" height="272" rx="6" fill="{WOOD}" {SK} stroke-width="4"/>
<circle cx="26" cy="18" r="13" fill="{knob}" {SK} stroke-width="5"/>
<path d="M32 40 C60 34 96 52 128 58 L98 82 L128 106 C96 112 60 120 32 116 Z" fill="{cloth}" {SK} stroke-width="5"/>
<path d="M32 40 C60 34 96 52 128 58 L118 66 C90 60 60 48 32 52 Z" fill="{trim}"/>
<polygon points="{star_points(62, 82, 16, 7)}" fill="{trim}" {SK} stroke-width="3"/>
<ellipse cx="26" cy="294" rx="26" ry="6" fill="{INK}" opacity="0.35"/>""", "flag_on" if active else "flag_off")
    save(grain(flag(True), 0.05, 121, wrap=False), OUT / "flag_on.png")
    save(grain(flag(False), 0.05, 122, wrap=False), OUT / "flag_off.png")

    post = svg_image(110, 420, f"""
<defs><radialGradient id="l" cx="0.5" cy="0.45" r="0.6"><stop offset="0" stop-color="#fffbe0"/>
<stop offset="0.55" stop-color="{GOLD}"/><stop offset="1" stop-color="#ef8a2c"/></radialGradient></defs>
<rect x="47" y="96" width="16" height="314" rx="6" fill="#3a2a52" {SK} stroke-width="4"/>
<rect x="30" y="396" width="50" height="20" rx="6" fill="#3a2a52" {SK} stroke-width="4"/>
<path d="M55 96 C55 70 90 70 90 46" fill="none" stroke="#3a2a52" stroke-width="9"/>
<path d="M55 96 C55 70 90 70 90 46" fill="none" {SK} stroke-width="3"/>
<rect x="74" y="20" width="32" height="10" rx="4" fill="{CRIMSON_D}" {SK} stroke-width="3"/>
<ellipse cx="90" cy="62" rx="22" ry="30" fill="url(#l)" {SK} stroke-width="5"/>
<path d="M90 34 v56 M78 38 C70 54 70 70 78 86 M102 38 C110 54 110 70 102 86" fill="none" stroke="#e5862a" stroke-width="3" opacity="0.7"/>
<rect x="78" y="90" width="24" height="9" rx="4" fill="{CRIMSON_D}" {SK} stroke-width="3"/>""", "lamp_post")
    save(grain(post, 0.05, 141, wrap=False), OUT / "lamp_post.png")

    gate = svg_image(780, 640, f"""
<path d="M130 290 C130 70 650 70 650 290 L566 290 C566 170 214 170 214 290 Z" fill="{GOLD}" {SK} stroke-width="8"/>
<path d="M160 270 C172 112 608 112 620 270" fill="none" stroke="{GOLD_L}" stroke-width="9" stroke-linecap="round"/>
{''.join(f'<path d="M{200 + i * 48} 176 l24 -28 l24 28 l-24 28 Z" fill="{PURPLE if i % 2 == 0 else CRIMSON}" {SK} stroke-width="4"/>' for i in range(8))}
{''.join(f'<rect x="{x}" y="{200 + i * 46}" width="116" height="46" fill="{CRIMSON if i % 2 == 0 else CREAM}"/>' for x in (64, 600) for i in range(9))}
<rect x="64" y="200" width="116" height="414" fill="none" {SK} stroke-width="8"/>
<rect x="600" y="200" width="116" height="414" fill="none" {SK} stroke-width="8"/>
<rect x="64" y="200" width="30" height="414" fill="{INK}" opacity="0.22"/><rect x="600" y="200" width="30" height="414" fill="{INK}" opacity="0.22"/>
{''.join(f'<path d="M{x - 16} 202 L{x + 58} 98 L{x + 132} 202 Z" fill="{PURPLE}" {SK} stroke-width="8"/><circle cx="{x + 58}" cy="92" r="15" fill="{GOLD}" {SK} stroke-width="5"/><rect x="{x - 14}" y="192" width="144" height="22" rx="9" fill="{GOLD}" {SK} stroke-width="5"/>' for x in (64, 600))}
<circle cx="390" cy="74" r="56" fill="{CRIMSON}" {SK} stroke-width="8"/>
<polygon points="{star_points(390, 76, 42, 18)}" fill="{GOLD}" {SK} stroke-width="5"/>
<rect x="214" y="224" width="352" height="56" rx="12" fill="{CREAM}" {SK} stroke-width="6"/>
<text x="390" y="262" font-family="DejaVu Serif, serif" font-size="26" font-weight="bold" letter-spacing="2" text-anchor="middle" fill="{CRIMSON_D}">CARNIVAL GATE</text>""", "gate")
    save(grain(gate, 0.05, 151, wrap=False), OUT / "gate.png")


# --------------------------------------------------------------------------- effects


def build_effects() -> None:
    FX.mkdir(parents=True, exist_ok=True)
    size = 512
    yy, xx = np.mgrid[0:size, 0:size]
    d = np.sqrt((xx - size / 2) ** 2 + (yy - size / 2) ** 2) / (size / 2)
    a = np.clip(1 - d, 0, 1) ** 2.2
    light = np.dstack([np.full_like(a, 255)] * 3 + [a * 255]).astype(np.uint8)
    save(Image.fromarray(light, "RGBA"), FX / "light.png")

    s = 128
    yy, xx = np.mgrid[0:s, 0:s]
    d = np.sqrt((xx - s / 2) ** 2 + (yy - s / 2) ** 2) / (s / 2)
    soft = np.clip(1 - d, 0, 1) ** 1.5
    save(Image.fromarray(np.dstack([np.full_like(soft, 255)] * 3 + [soft * 255]).astype(np.uint8), "RGBA"), FX / "soft_circle.png")

    save(svg_image(64, 64, f'<polygon points="{star_points(32, 32, 28, 12)}" fill="{GOLD}" {SK} stroke-width="4"/>'
                   f'<polygon points="{star_points(30, 30, 12, 5)}" fill="{GOLD_L}"/>'), FX / "star.png")
    save(svg_image(64, 64, f'<polygon points="{star_points(32, 32, 31, 5, points=4)}" fill="#ffffff"/>'), FX / "spark.png")
    puff = svg_image(128, 128, """
<g fill="#f3e6ff"><circle cx="46" cy="76" r="30"/><circle cx="78" cy="68" r="34"/><circle cx="64" cy="48" r="26"/><circle cx="92" cy="86" r="22"/></g>
<g fill="#c9b6e6"><circle cx="54" cy="90" r="20"/><circle cx="86" cy="94" r="16"/></g>""")
    save(puff, FX / "dust.png")
    save(svg_image(256, 256, '<circle cx="128" cy="128" r="110" fill="none" stroke="#ffffff" stroke-width="16"/>'), FX / "ring.png")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    build_sky()
    build_castle()
    build_far_carnival()
    build_near_carnival()
    build_props()
    build_effects()
    print("Built:", ", ".join(sorted(p.name for p in OUT.glob("*.png"))))


if __name__ == "__main__":
    main()
