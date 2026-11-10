# Roadmap

Status key: done = implemented and validated in engine. written = code exists, not yet run. open = not started.

## Milestone 0: Project initialization

| Item | Status |
| --- | --- |
| Inspect environment | done |
| Read Development Bible | done |
| Godot project and folder structure | written |
| Local Git repository | done |
| GitHub remote | open (no repository designated) |
| Validate project startup | open (Godot could not be installed in the build session) |

## Milestone 1: Player movement

| Item | Status |
| --- | --- |
| Run, acceleration, deceleration | written |
| Variable jump, coyote time, jump buffer | written |
| Air control, momentum preservation | written |
| 8-way dash | written |
| Hammer pogo | written |
| Hammer vault | written |
| Camera look-ahead, bounds, dynamic zoom | written |
| Graybox playground | written |

## Milestone 2: Combat physics

| Item | Status |
| --- | --- |
| Directional, aerial, downward, charge attacks | written |
| Enemy damage and launch states | written |
| Enemy-to-enemy collisions | written |
| Combo tracking | written |
| Hit-stop and screen shake | written |
| Breakable props, hazards | written |

## Milestone 3: Vertical slice (open)

Carnival Gate level, court guards with attacks, Royal Arbalest, hazards, checkpoints, Executioner miniboss, basic UI and sound.

## Milestone 4: Art integration (open)

## Milestone 5: Expanded gameplay (open)

## Next actions

1. Run `tools/validate.sh` on Godot 4.7.2 and fix whatever it reports.
2. Human playtest against the prototype exit criteria; tune `jester_movement.tres` and the attack resources.
3. Designate the GitHub repository and push.
4. Only then start Milestone 3.
