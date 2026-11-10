class_name MovementConfig
extends Resource
## All player movement tuning in one resource. Units: pixels and seconds.
## Edit resources/movement/jester_movement.tres in the inspector to tune feel.

@export_group("Run")
@export var max_run_speed: float = 520.0
@export var ground_acceleration: float = 4200.0
@export var ground_deceleration: float = 5200.0
@export var ground_turn_acceleration: float = 7500.0
@export var air_acceleration: float = 2600.0
@export var air_deceleration: float = 500.0
@export var air_turn_acceleration: float = 3600.0

@export_group("Momentum")
## How quickly speed above max_run_speed bleeds off while the player keeps
## pushing in the travel direction. Low values preserve launch momentum.
@export var overspeed_ground_drag: float = 700.0
@export var overspeed_air_drag: float = 120.0
## Hard cap that keeps collisions reliable at any speed.
@export var max_horizontal_speed: float = 1800.0
@export var max_rise_speed: float = 2200.0

@export_group("Jump")
@export var jump_height: float = 230.0
@export var jump_time_to_peak: float = 0.40
@export var jump_time_to_fall: float = 0.32
## Upward speed is multiplied by this when jump is released early.
@export_range(0.0, 1.0) var jump_cut_multiplier: float = 0.45
@export var max_fall_speed: float = 1500.0
@export var coyote_time: float = 0.10
@export var jump_buffer_time: float = 0.12

@export_group("Dash")
@export var dash_speed: float = 1100.0
@export var dash_duration: float = 0.16
@export var dash_cooldown: float = 0.35
## Added on top of existing speed along the dash direction when already fast.
@export var dash_momentum_bonus: float = 200.0
@export_range(0.0, 1.0) var dash_exit_retain: float = 0.7
@export var air_dashes: int = 1

@export_group("Hammer Pogo")
@export var pogo_bounce_speed: float = 1150.0
@export var pogo_enemy_bounce_speed: float = 1280.0

@export_group("Hammer Vault")
@export var vault_up_speed: float = 1300.0
@export var vault_forward_up_speed: float = 900.0
@export var vault_forward_boost: float = 620.0
## Vaulting within this many seconds of landing counts as a perfect vault.
@export var vault_perfect_window: float = 0.12
@export var vault_perfect_multiplier: float = 1.25
@export var vault_cooldown: float = 0.4


func jump_velocity() -> float:
	return 2.0 * jump_height / jump_time_to_peak


func rise_gravity() -> float:
	return 2.0 * jump_height / (jump_time_to_peak * jump_time_to_peak)


func fall_gravity() -> float:
	return 2.0 * jump_height / (jump_time_to_fall * jump_time_to_fall)
