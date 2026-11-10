# Controls

Defaults are registered in `scripts/systems/input_setup.gd`. In-game remapping is not built yet.

| Action | Keyboard | Gamepad |
| --- | --- | --- |
| Move | A / D or arrow keys | Left stick or D-pad |
| Aim up / down | W / S or arrow keys | Left stick or D-pad |
| Jump | Space | South button (A) |
| Light attack | J | West button (X) |
| Heavy hammer | K | East button (B) |
| Dash | Shift | Right shoulder |
| Special (reserved) | L | Left shoulder |
| Pause (reserved) | Esc | Start |
| Restart room (debug) | R | Back |

## Moves

- **Jump:** hold for full height, tap for a short hop.
- **Dash:** 8 directions; one air dash, restored on landing or pogo. Jump during a ground dash to keep its speed.
- **Side swing:** Light.
- **Upswing:** hold Up + Light.
- **Pogo:** in the air, hold Down + Light. Bounces off enemies, crates and spikes.
- **Heavy:** tap Heavy, or hold to charge and release.
- **Vault:** on the ground, hold Down + Heavy. Add Left or Right for a forward vault. Vault just after landing for a perfect vault.

The Bible lists Special on a trigger; it is on the left shoulder for now because no special exists yet.
