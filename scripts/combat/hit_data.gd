class_name HitData
extends RefCounted
## Payload passed to `take_hit(hit: HitData)` on anything that can be struck.

var attack_id: StringName = &""
var damage: int = 1
## Launch velocity before the target divides by its own mass.
var launch_velocity: Vector2 = Vector2.ZERO
## Who caused the hit: the player for hammer hits, an enemy for collisions.
var source: Node = null
## 0 for a direct hammer hit, +1 for each enemy-to-enemy transfer after it.
var chain_depth: int = 0
## 0..1 charge of a heavy swing (0 for everything else).
var charge: float = 0.0
