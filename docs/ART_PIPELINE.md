# Art Pipeline

## Current state

Everything on screen is a procedural placeholder drawn with `_draw()` primitives (`scripts/animation`). No image assets exist. This is deliberate: movement feel comes first.

Blender, Krita and Inkscape were not installed in the build session.

## Target

Stylized 2.5D: dimensional, hand-painted characters for a side-scrolling game. Bold chibi silhouettes, thick outlines, jewel tones, controlled cel shading. High-resolution painted or cutout sprites, not low-resolution pixel art.

Palette: crimson, purple, gold and cream for the court; teal and cyan for spirits; pink and gold for Seraphine's magic.

## Conventions (apply from the first real sprite)

| Property | Value |
| --- | --- |
| Pivot | Bottom-centre (feet) |
| Facing | Authored facing right; mirrored in engine |
| Jester height | 72 px at zoom 1.0 on a 1080 px viewport (about 6.7% of screen height) |
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

Per asset: `id, display_name, canonical_species, role, reference_images, source_file, export_path, frame_size, pivot, animation_names, frame_rates, palette_id, revision, license, approval_status`. No manifest file exists yet because there are no assets.

## Licensing

Record provenance and commercial usage terms for every generated or third-party asset before it enters the repository.
