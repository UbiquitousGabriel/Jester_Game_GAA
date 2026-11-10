# Architecture

Godot 4.7.2, typed GDScript, GL Compatibility renderer, 60 Hz fixed physics, 1920x1080 base viewport.

## Principles

- All gameplay simulation runs in `_physics_process`. `_process` is cosmetic only.
- One responsibility per script. Systems talk through signals and small public methods.
- Tuning lives in resources and exported properties, never in logic.
- Scripted, deterministic launches. No rigid-body enemy piles.

## Systems

| System | Script | Notes |
| --- | --- | --- |
| Input | `systems/input_setup.gd` (autoload) | Registers default actions in code; remap-ready |
| Movement | `movement/player_controller.gd` | `Player`, a `CharacterBody2D` |
| Movement tuning | `movement/movement_config.gd` | `MovementConfig` resource |
| Hammer | `combat/hammer.gd` | Child of Player; input, swing states, hit queries |
| Attack data | `combat/attack_data.gd` | One `.tres` per move in `resources/combat` |
| Hit payload | `combat/hit_data.gd` | Passed to `take_hit(hit)` |
| Enemy | `enemies/enemy.gd` | State machine and chain collisions |
| Props | `physics/breakable.gd` | Solid until smashed |
| Camera | `camera/follow_camera.gd` | Look-ahead, dead zone, bounds, zoom, shake |
| Game feel | `systems/game_feel.gd` (autoload) | Hit-stop and shake requests |
| Combo | `systems/combo_tracker.gd` (autoload) | Chain count and window |
| Level | `levels/movement_playground.gd` | Builds the graybox from data tables |
| Visuals | `animation/*.gd`, `effects/*.gd` | Procedural placeholders |
| UI | `ui/hud.gd` | Chain counter, speed, controls |

Audio and save/progression are not started.

## Collision layers

| Layer | Name | Used by |
| --- | --- | --- |
| 1 | world | Ground, walls, platforms, crates |
| 2 | player | Player body |
| 3 | enemy | Enemy bodies |
| 4 | player_hitbox | Reserved |
| 5 | enemy_hitbox | Reserved |
| 6 | hazard | Spike areas |
| 7 | prop | Breakable crates (also on world) |

Player and enemies collide with world only. They never body-block each other.

## Hit pipeline

`Hammer._scan_hits` (shape query) -> `AttackData` -> `HitData` -> `target.take_hit(hit)` -> hit-stop and shake -> `ComboTracker.register_hit`.

Anything with a `take_hit(hit: HitData)` method can be struck. Anything in the `pogoable` group bounces a downward strike.

## Enemy states

`GROUNDED` (patrol) -> `STAGGERED` (weak hit) or `LAUNCHED` (airborne, ricochets, chain collisions) -> `KNOCKED_DOWN` -> `RECOVER` -> `GROUNDED`. `DEFEATED` fades out and frees. An enemy at zero health keeps flying as a projectile until it lands.

## Decisions

1. **Repository layout follows the system prompt** (`project.godot` at root), not the Bible's `/game/` layout, because the prompt is the more recent instruction.
2. **Hit detection uses physics shape queries**, not `Area2D` signals as the Bible sketches. Queries resolve on the tick the swing is active, with no one-frame monitoring delay. `Area2D` is still used for hazards, pads and checkpoints.
3. **Enemies do not physically collide with each other.** The Bible suggests relaxing enemy collision during launches; the prototype removes it entirely and detects impacts by query. This prevents jitter. Revisit if crowds should block each other.
4. **Input actions are registered in code** so defaults are readable and remapping can overwrite them.
5. **Hit-stop uses `Engine.time_scale`.** Physics still steps at a fixed delta, so results stay deterministic.
6. **Graybox geometry is built from data tables**, not `TileMapLayer`. Move to tiles when art exists.
7. **Debris is cosmetic `Node2D` drawing**, not `RigidBody2D`.
