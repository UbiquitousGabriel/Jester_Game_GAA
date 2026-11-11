# The Jester's Court

A vibrant, momentum-driven 2D hack-and-slash platformer. A murdered court jester returns as a small skeleton with an enormous clown hammer to humiliate the king who had him killed.

**Core promise:** Run fast. Bounce off the hammer. Launch enemies into other enemies. Turn the castle into your playground.

## Status

Feature-complete, pre-art. The whole castle is playable from the title screen to the ending: 6 areas, 131 rooms, 13 enemy types, 6 bosses, 5 earned abilities, 9 charms, collectibles, shops, shrines, saves, a map, synthesised music and sound, lighting and game feel. Characters without art yet are drawn as labelled shapes; `docs/ASSET_REQUESTS.pdf` lists every asset the art department needs.

Automated checks: every script compiles, the movement/combat smoke test (59 checks) and the world test (169 checks: all rooms, doors, pits, death, pickups, all six bosses, all menus). **No human has played it start to finish yet**, so pacing, difficulty and the ~10 hour length are unverified. See `docs/KNOWN_ISSUES.md`.

## Run it

1. Install **Godot 4.7.2 stable** (standard build, not .NET).
2. Open the Godot project manager, choose **Import**, select `project.godot`.
3. Press **F5**. The game opens on the title screen (`scenes/ui/title_screen.tscn`). Pick a save slot, or the **Training Yard** for the movement playground with every move unlocked.

Controls are in `docs/CONTROLS.md`.

## Validate

```bash
tools/validate.sh /path/to/godot   # import, compile check, smoke test, world test
tools/lint.sh                      # syntax only, needs: pip install gdtoolkit
```

## Layout

| Path | Contents |
| --- | --- |
| `scripts/movement` | Player controller, movement tuning resource |
| `scripts/combat` | Hammer, attack data, hit payload |
| `scripts/enemies` | Launchable enemy state machine |
| `scripts/physics` | Breakable props |
| `scripts/camera` | Follow camera |
| `scripts/levels` | Playground builder, hazards, bounce pads, checkpoints |
| `scripts/systems` | Autoloads: input, game feel, combo, GameState (saves), Audio; story text; feedback wiring |
| `scripts/game` | The castle run: rooms, doors, pits, deaths, bosses, area mood |
| `scripts/world` | Generated world data, room builder, entity spawner, pickups, interactables, gates |
| `scripts/bosses` | Boss base and the six bosses |
| `scripts/enemies/brains` | Behaviour for each enemy type |
| `scripts/animation`, `scripts/effects`, `scripts/ui` | Sprite visuals, VFX, telegraphs, HUD, the Ui autoload (menus, map, dialogue), title screen |
| `resources` | Tunable `.tres` data (movement, hammer moves) |
| `scenes` | Player, enemies, levels, UI |
| `tests`, `tools` | Tests; world generator (`tools/world`), audio synth (`tools/audio`), art pipelines, capture tools |
| `docs` | Design, architecture, roadmap, log, registry |

## Documentation

- [Game design](docs/GAME_DESIGN.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Roadmap](docs/ROADMAP.md)
- [Development log](docs/DEVELOPMENT_LOG.md)
- [Controls](docs/CONTROLS.md)
- [Character registry](docs/CHARACTER_REGISTRY.md)
- [Art pipeline](docs/ART_PIPELINE.md)
- [Known issues](docs/KNOWN_ISSUES.md)
- [Environment](docs/ENVIRONMENT.md)

The design source of truth is *The Jester's Court: Complete Development Bible*, Revision 2.0 (November 2026). It is not yet stored in this repository (48 MB; add through Git LFS).
