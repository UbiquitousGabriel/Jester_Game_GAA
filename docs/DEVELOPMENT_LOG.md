# Development Log

## 2026-11-10: Session 1

### Done

- Read the Development Bible 2.0 (17 pages) and the master system prompt.
- Inspected the environment (see `ENVIRONMENT.md`). Confirmed Godot 4.7.2 is the latest 4.7.x stable tag.
- Created the Godot project, folder structure, Git repository, `.gitignore`, LFS attributes.
- Wrote Milestone 1 and 2 systems: player movement, hammer, enemy launch and chain collisions, camera, game feel, combo, graybox playground, HUD, procedural placeholders.
- Wrote a scripted smoke test and validation scripts.
- Wrote all project documentation.

### Blocked

- **Godot could not be installed.** The official 4.7.2 release download was reachable, but the session's security policy blocked downloading and running an external binary. No workaround was attempted.
- **GitHub:** no repository is designated for this project, and the session's GitHub CLI token is invalid. Nothing was pushed.

### Test results

| Command | Result |
| --- | --- |
| `gdparse` on all 20 scripts | Pass (syntax only) |
| `gdlint scripts tests` | 1 style warning (`max-returns`) |
| `res://` reference check (all referenced files exist) | Pass |
| `godot --headless --import` | **Not run** |
| `tests/smoke_test.tscn` | **Not run** |
| Interactive playtest | **Not run** |

No claim is made that the game runs or feels good.

### Branch state

- `main`: repository scaffold only (ignore rules, LFS attributes, empty asset folders).
- `feature/movement-prototype`: all gameplay code, unvalidated. Merge to `main` only after `tools/validate.sh` passes.

### Next

1. Run `tools/validate.sh` on Godot 4.7.2; fix errors.
2. Playtest and tune.
3. Designate the GitHub repository; push.

## 2026-11-10: Session 1, continued

The creative director designated `UbiquitousGabriel/Jester_Game_GAA` and approved installing tools.

### Done

- Installed the official Godot 4.7.2 stable build (checksum verified).
- First engine run: import clean, no parser or runtime errors in any script or scene.
- Fixed one smoke-test bug (it measured the short hop from the wrong ground height after landing on a platform). No game code needed fixing.
- Extended the smoke test from 16 to 28 checks: vault, pogo off enemies, pogo off spikes, spike respawn, bounce pad, crate smashing, spike defeat.
- Moved the Jester's resting hammer pose off his head (placeholder art only).
- Rendered the smoke-test run under a virtual display and inspected frames: level, characters, HUD and chain counter draw correctly.

### Test results

| Command | Result |
| --- | --- |
| `godot --headless --path . --import` | Pass, exit 0 |
| `godot --headless --path . res://tests/smoke_test.tscn` | 28 passed, 0 failed |
| Same test rendered with `xvfb-run` and `--write-movie` | 28 passed; frames inspected |
| `gdparse` on all scripts | Pass |
| Interactive human playtest | **Not run** |

The earlier "Blocked" and "Not run" entries above are superseded by this section.

## 2026-11-10: Jester sprite integration (`art/jester-sprites`)

The creative director supplied seven generated sprite sheets (57 frames).

### Done

- `tools/art/process_jester_sheets.py`: background removal, edge un-blending, frame splitting, size normalisation across sheets, shared-anchor alignment, SpriteFrames generation. Rebuilds in about 5 seconds.
- `jester_visual.gd` rewritten: `AnimatedSprite2D` with state-driven animation, phase-locked attack frames, squash and stretch over the painted poses, dash and high-speed afterimages.
- Death beat: hazards and the kill plane now play the hurt and defeat animations for 0.9 s before respawn, and reset the chain.
- Mipmapped frame imports; project default canvas filter is now linear with mipmaps.
- `tools/capture/showcase.tscn`: scripted run through every animation, for recording footage.

### Test results

| Command | Result |
| --- | --- |
| `godot --headless --path . --import` | Pass |
| `tests/smoke_test.tscn` | 39 passed, 0 failed (11 new: sprite, animation and death-beat checks) |
| Showcase rendered at 1920x1080, frames inspected | All animations trigger; no halos; consistent scale |
| `tools/lint.sh` | Pass |
| Human playtest | Not run |

## 2026-11-10: Community Aide as stand-in guard

- `tools/art/process_aide_sheets.py`: alpha and black-key cutout, shadow and caption removal, outline rebuild, scale normalisation, SpriteFrames generation (24 frames).
- `guard_visual.gd` rewritten to drive his sprite from the Enemy state machine; hit flash, tumble and lying pose kept.
- Smoke test: 41 passed, 0 failed (2 new guard sprite checks). Showcase at 1080p inspected.
- Git: source sheets are now normal Git files (LFS uploads unreachable from build sessions). The earlier local commit on this branch still holds LFS pointers; pushing needs the creative director's decision (see conversation).
