# Known Issues

## Blocking

None. The project imports and runs on Godot 4.7.2 with no script errors.

## Unverified (needs a human playtest)

- **Length.** The castle (131 rooms, 6 bosses, 24 heart pieces, 42 jokes, 9 charms) is built for about 10 hours, but nobody has played it start to finish. The automated tests build every room, walk through doors, fall into pits, die and respawn, collect pickups and defeat each boss with scripted damage; they cannot judge pacing or difficulty.
- **Gate tuning.** The world generator proves every room is reachable with the abilities in order, using movement numbers worked out on paper (jump 230 px, vault 563 px, glide chasm 960 px, wall-bounce climbs). A gate that is too tight or too loose in real play is a value change in `player_controller.gd` or `build_world.py`.
- **Boss difficulty.** Health, telegraph lengths and damage are first guesses.
- **Music and sound** are synthesised in code (`tools/audio/synth.py`). They are complete and loop cleanly but are placeholder quality next to a composed score.

- **Feel.** All tuning values are first guesses calculated on paper. The smoke test proves the mechanics function, not that they are fun.
- Camera framing, look-ahead strength and dynamic zoom.
- Hit-stop length and its interaction with input buffering (the smoke test runs with hit-stop off).
- Gamepad bindings.
- HUD layout at window sizes other than 1280x720.

## No automated coverage yet

Charge attack scaling, upswing, wall ricochet, floor bounce, coyote time, jump buffering, perfect-vault timing, checkpoints beyond the first, the kill plane.

## Feel (needs the creative director's playtest)

- Air speed can reach about 1500 after glide plus dash; the camera zooms out and the Jester gets small. Thrilling or chaotic: undecided.
- Air hang, bounce heights, glide length and enemy aggression are first-pass values.
- The on-screen controls text is cluttered and can overlap flying enemies.
- All characters except the Jester, the Court Guard, the mace knight and the bat knight are labelled shapes until their art arrives (see `docs/ASSET_REQUESTS.pdf`).

## Art

- **Scale check needed.** The Jester renders about 58 px tall at 1080p with the default camera (5.4% of screen height, inside the Bible's 5-9% but at the small end). Judge in playtest: raise `sprite_scale` on the Jester's Visual node or `base_zoom` on the camera.
- The Court Guard is played by the Community Aide stand-in; his sheets have no attack, hit or knocked-down frames, so the lying pose is the landing grimace rotated 90 degrees. Faint red fringing in his hair is in the source art.
- The aerial Jester sheet is drawn at half the resolution of his other sheets, so spin frames are softer.
- The tileset pack's parallax backgrounds are too small (465 px wide) to use full screen; generated backdrops stand in.
- Pack lanterns keep a faint dark glow from the sheet behind them.
- No painted frames exist yet for: dash (uses a run frame), wall contact, taking a non-fatal hit (the hurt frames play only on death).
- Upswing reuses the overhead slam windup; a dedicated upward swing would read better.
- The heavy attack launches enemies forward, but its painted swing is an overhead slam into the ground.

## Observations from the first engine run

- A held jump peaks at 239.6 px against a configured 230 px (fixed-step integration overshoot). Harmless; note it when tuning.
- A full jump from the start area lands on the one-way platform above. Intended, but it surprised the first version of the smoke test.

## Design gaps in the prototype

- Guards only patrol. They do not attack and the Jester has no health.
- The Jester passes through enemies; there is no contact damage.
- No audio, pause menu, input remapping, or save system.
- The level is a graybox playground, not Carnival Gate.
- Bounce pads act on anything overlapping them that is not moving upward, including a player walking across.
- The gap's stepping-stone guard can be knocked off, after which the gap needs a dash or vault. The lower route and bounce pad are the fallback.

## Tooling

- `gdlint` reports one style warning (`max-returns` in `jester_visual.gd`). Cosmetic.
- The Development Bible PDF (48 MB) is not in the repository. It needs Git LFS, which has not been tested against this remote.
