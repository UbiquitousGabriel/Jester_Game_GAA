class_name AttackData
extends Resource
## One authored hammer move. Units: pixels and seconds.
## Offsets and launch vectors are authored facing right; x is mirrored by facing.

@export var id: StringName = &"attack"
@export var damage: int = 1

@export_group("Timing")
@export var startup: float = 0.05
@export var active: float = 0.10
@export var recovery: float = 0.12

@export_group("Hitbox")
## Centre of the hitbox relative to the attacker's feet.
@export var hitbox_offset: Vector2 = Vector2(70.0, -36.0)
@export var hitbox_size: Vector2 = Vector2(120.0, 90.0)

@export_group("Launch")
@export var launch_vector: Vector2 = Vector2(900.0, -500.0)
## Fraction of the attacker's velocity added to the launch.
@export_range(0.0, 1.5) var inherit_velocity: float = 0.5
## When true, connecting with a target or pogo surface bounces the attacker.
@export var bounces_attacker: bool = false

@export_group("Air")
## Upward speed given to the attacker when this move connects in the air
## (0 = none). Chaining air hits keeps the Jester airborne.
@export var air_bounce: float = 0.0
## Forward speed added at the start of the move when airborne.
@export var lunge: float = 0.0
## The attacker hangs in the air while this move plays.
@export var hang: bool = false

@export_group("Feedback")
@export var hitstop: float = 0.06
@export var shake: float = 6.0


func total_time() -> float:
	return startup + active + recovery
