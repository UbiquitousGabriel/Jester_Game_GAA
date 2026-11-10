# Known Issues

## Blocking

None. The project imports and runs on Godot 4.7.2 with no script errors.

## Unverified (needs a human playtest)

- **Feel.** All tuning values are first guesses calculated on paper. The smoke test proves the mechanics function, not that they are fun.
- Camera framing, look-ahead strength and dynamic zoom.
- Hit-stop length and its interaction with input buffering (the smoke test runs with hit-stop off).
- Gamepad bindings.
- HUD layout at window sizes other than 1280x720.

## No automated coverage yet

Charge attack scaling, upswing, wall ricochet, floor bounce, coyote time, jump buffering, perfect-vault timing, checkpoints beyond the first, the kill plane.

## Observations from the first engine run

- A held jump peaks at 239.6 px against a configured 230 px (fixed-step integration overshoot). Harmless; note it when tuning.
- A full jump from the start area lands on the one-way platform above. Intended, but it surprised the first version of the smoke test.
- The Jester's resting hammer overlaps his hat in the placeholder art.

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
