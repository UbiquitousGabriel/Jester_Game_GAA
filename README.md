# The Jester's Court

A vibrant, momentum-driven 2D hack-and-slash platformer. A murdered court jester returns as a small skeleton with an enormous clown hammer to humiliate the king who had him killed.

**Core promise:** Run fast. Bounce off the hammer. Launch enemies into other enemies. Turn the castle into your playground.

## Status

Prototype, Milestones 0-2. The project imports cleanly on Godot 4.7.2 and the scripted smoke test passes (28 checks). **No human has playtested it yet**, so feel and tuning are unverified. See `docs/DEVELOPMENT_LOG.md` and `docs/KNOWN_ISSUES.md`.

## Run it

1. Install **Godot 4.7.2 stable** (standard build, not .NET).
2. Open the Godot project manager, choose **Import**, select `project.godot`.
3. Press **F5**. The main scene is `scenes/levels/movement_playground.tscn`.

Controls are in `docs/CONTROLS.md`.

## Validate

```bash
tools/validate.sh /path/to/godot   # import + scripted smoke test
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
| `scripts/systems` | Autoloads: input, game feel, combo |
| `scripts/animation`, `scripts/effects`, `scripts/ui` | Placeholder visuals, debris, HUD |
| `resources` | Tunable `.tres` data (movement, hammer moves) |
| `scenes` | Player, enemies, levels, UI |
| `tests`, `tools` | Smoke test and validation scripts |
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
