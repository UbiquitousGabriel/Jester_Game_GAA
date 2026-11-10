# Roadmap

Status key: done = finished. tested = runs in Godot 4.7.2 and is covered by the passing smoke test; feel not yet judged by a human. untested = runs without errors but has no automated check. open = not started.

## Milestone 0: Project initialization

| Item | Status |
| --- | --- |
| Inspect environment | done |
| Read Development Bible | done |
| Godot project and folder structure | done |
| Local Git repository | done |
| GitHub remote | done (`UbiquitousGabriel/Jester_Game_GAA`) |
| Validate project startup | done (headless import, smoke test, rendered run) |

## Milestone 1: Player movement

| Item | Status |
| --- | --- |
| Run, acceleration, deceleration | tested |
| Variable jump, coyote time, jump buffer | tested |
| Air control, momentum preservation | untested |
| 8-way dash | tested |
| Hammer pogo | tested |
| Hammer vault | tested |
| Camera look-ahead, bounds, dynamic zoom | untested |
| Graybox playground | tested |

## Milestone 2: Combat physics

| Item | Status |
| --- | --- |
| Directional, aerial, downward, charge attacks | untested |
| Enemy damage and launch states | tested |
| Enemy-to-enemy collisions | tested |
| Combo tracking | tested |
| Hit-stop and screen shake | untested |
| Breakable props, hazards | tested |

## Milestone 3: Vertical slice (open)

Carnival Gate level, court guards with attacks, Royal Arbalest, hazards, checkpoints, Executioner miniboss, basic UI and sound.

## Milestone 4: Art integration (started)

| Item | Status |
| --- | --- |
| Jester sprite pipeline and animation states | tested |
| Court Guard sprites | open |
| Painted environment, lighting, parallax | open |
| Visual effects (dust, impacts, trails) | partly: Jester afterimages, painted swooshes |

## Milestone 5: Expanded gameplay (open)

## Next actions

1. Human playtest against the prototype exit criteria; tune `jester_movement.tres` and the attack resources.
2. Add smoke-test coverage for the untested items (charge attack, upswing, ricochet, coyote time, jump buffer, camera).
3. Review and merge `feature/movement-prototype` into `main`.
4. Then start Milestone 3.
