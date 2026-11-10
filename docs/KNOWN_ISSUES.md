# Known Issues

## Blocking

1. **The project has never been opened or run in Godot.** The build session could not install the engine. Every script passes a syntax check (`gdparse`), which does not catch type errors, wrong engine API names, or scene-file mistakes. Expect to fix some errors on first open.
2. **The smoke test has never been executed.** `tests/smoke_test.gd` is written but its results are unknown.
3. **No GitHub remote.** Commits are local only.

## Unverified behaviour (needs engine run, then human playtest)

- All movement tuning values are first guesses calculated on paper. Feel is untested.
- Pogo hitbox reach versus spike collision: the bounce should trigger before the spikes do.
- One-way platforms with launched enemies passing up through them.
- Enemy ricochet and floor-bounce thresholds.
- Camera framing, look-ahead strength and dynamic zoom.
- Hit-stop interaction with input buffering.
- HUD label anchoring at different window sizes.
- Gamepad bindings.

## Design gaps in the prototype

- Guards only patrol. They do not attack and the Jester has no health.
- The Jester passes through enemies; there is no contact damage.
- No audio, pause menu, input remapping, or save system.
- The level is a graybox playground, not Carnival Gate.
- Bounce pads act on anything overlapping them that is not moving upward, including a player walking across.
- The gap's stepping-stone guard can be knocked off, after which the gap needs a dash or vault. The lower route and bounce pad are the fallback.

## Tooling

- `gdlint` reports one style warning (`max-returns` in `jester_visual.gd`). Cosmetic.
- The Development Bible PDF (48 MB) is not in the repository. Add it under Git LFS once a remote exists.
