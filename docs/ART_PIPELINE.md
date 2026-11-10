# Art Pipeline

## Current state

| Character | Status |
| --- | --- |
| The Jester | Painted sprite frames in game (57 frames, 17 animations) |
| Court Guard | Played by the Community Aide stand-in (24 frames) |
| Level, props | Procedural placeholders drawn with `_draw()` |

## Jester sprite pipeline

Source sheets (as generated, untouched) live in `assets/source/jester/sheets/`. One command rebuilds everything from them:

```bash
python3 tools/art/process_jester_sheets.py     # needs numpy, scipy, Pillow
godot --headless --path . --import             # picks up new or changed frames
```

The script:

1. Keys out the near-white checker background (flood fill from the border, plus enclosed checker holes such as gaps between arm and handle).
2. Un-blends the anti-aliased edge band against white, so outlines stay soft without a halo.
3. Splits each sheet's grid and assigns every painted island to the cell holding its centre, so effects that cross a cell edge stay whole.
4. Drops specks and the painted ground shadow. On looping sheets (idle, run) it also drops detached effects, so emote marks do not flash every loop.
5. Normalises size across sheets. The generator drew the Jester 3-15% smaller on some sheets; `SHEET_SCALE` corrects this, measured from hat-bell width and skull width.
6. Aligns every frame on one anchor: skull centre horizontally, lowest body pixel vertically (the run cycle uses a per-row baseline so its bob survives).
7. Downscales with premultiplied Lanczos onto one shared 293x276 canvas and writes `resources/animation/jester_frames.tres`, `scripts/animation/jester_sprite_layout.gd` (anchor constant), a manifest and the review sheet `docs/art/jester_alignment.png`.

Frames are authored at 2x and drawn at 0.5 with mipmaps (the script switches mipmaps on in the `.import` files; brand-new frames need one import first, then a rerun).

### Animation map

| Godot animation | Source frames | Driven by |
| --- | --- | --- |
| idle | idle 0-7 | 9 fps loop |
| run | run 0-7 | 15 fps loop, speed scales with run speed |
| dash | run 3 | held; magenta afterimages |
| jump_rise, jump_apex, jump_fall, land | jump 2-4, 5, 6, 7-8 | vertical velocity |
| attack_side | attack 0-7 | hammer phase: startup 0-3, active 4-5, recovery 6-7 |
| attack_up | slam 0,1,2,3,3,2,1 | hammer phase |
| charge, slam | slam 1-2, slam 0-7 | charge ratio, then hammer phase |
| pogo_strike, pogo_bounce, vault | pogo 1-3, 4-7, 4-6 | hammer phase, then bounce signal |
| hurt, defeat | damage 1-3, 4-7 | death beat before respawn |

Attack frames are chosen from the hammer's phase progress, not a frame rate, so the impact pose is on screen exactly while the hitbox is live, whatever the tuning.

## Community Aide pipeline (Court Guard stand-in)

`python3 tools/art/process_aide_sheets.py` builds `assets/characters/community_aide/frames/` from `assets/source/community_aide/sheets/`. Differences from the Jester pipeline:

- `idle.png` has a real alpha channel and is used as is.
- `walk.png` and `jump.png` sit on pure black, the same value as parts of the ink. After keying, the edge is trimmed 3 px (the generator's noise band) and a smooth 2 px ink outline is redrawn from a distance field.
- Painted ground shadows are removed by colour (grey with red >= blue, unlike the blue-heavy pyjamas); captions, dust and motion lines are dropped as detached islands.
- Size is normalised so every sheet's opening standing pose is 208 px (104 px in game).

| Enemy state | Pose |
| --- | --- |
| Patrol | walk (speed follows patrol speed); idle when standing |
| Staggered | landing grimace |
| Launched | rising, wide-eyed apex, falling (by vertical speed), with tumble |
| Knocked down, defeated | lying flat |
| Recover | crouch |

### Unused source frames

jump 0 (standing), pogo 0 (airborne hold), damage 0 (standing). Kept in the source sheets for later use.

Blender, Krita and Inkscape were not installed in the build session.

## Target

Stylized 2.5D: dimensional, hand-painted characters for a side-scrolling game. Bold chibi silhouettes, thick outlines, jewel tones, controlled cel shading. High-resolution painted or cutout sprites, not low-resolution pixel art.

Palette: crimson, purple, gold and cream for the court; teal and cyan for spirits; pink and gold for Seraphine's magic.

## Conventions (apply from the first real sprite)

| Property | Value |
| --- | --- |
| Pivot | Bottom-centre (feet) |
| Facing | Authored facing right; mirrored in engine |
| Jester height | About 92 px hat-tip to boot in world units (frames are 2x: about 185 px) |
| Court Guard height | 80 px |
| Frame size | Constant per character, power-of-two friendly, padded |
| Export | Transparent PNG sequence or atlas with JSON metadata |

Sprites should be authored at 3x to 4x these sizes and scaled down in engine.

## Workflow (Bible section 12)

1. Brief: registry entry, reference art, palette, dimensions, animation list.
2. Concept: generated or painted. Concept images are references, not sprites.
3. Normalize in Krita: redraw, separate limbs, fix anatomy.
4. Animate: idle, run, jump, fall, attack, hit, defeat.
5. Export with consistent pivot, scale, naming, padding.
6. Validate with Python and Pillow: alpha, dimensions, names, frame counts, pivots, duplicates.
7. Integrate into `AnimatedSprite2D` or `AnimationPlayer`.
8. Review in engine at gameplay camera scale.

Workflow A (3D to 2D) versus Workflow B (hand-painted 2D) is undecided. Decide at Milestone 4 with a test on the Jester.

## Asset manifest

Per asset: `id, display_name, canonical_species, role, reference_images, source_file, export_path, frame_size, pivot, animation_names, frame_rates, palette_id, revision, license, approval_status`. The Jester's manifest is `assets/characters/jester/frames/manifest.json` (source sheet, source box and scale correction per frame). Provenance: generated by the creative director, 2026-11-10; usage rights to be recorded by him.

## Licensing

Record provenance and commercial usage terms for every generated or third-party asset before it enters the repository.
