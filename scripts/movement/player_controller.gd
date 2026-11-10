class_name Player
extends CharacterBody2D
## The Jester's movement: run, variable jump, coyote time, jump buffering,
## air control, 8-way dash, and the movement half of hammer pogo and vault.
##
## Attack input and hit detection live in Hammer (scripts/combat/hammer.gd),
## which calls pogo_bounce() and hammer_vault() here. All simulation runs in
## _physics_process at the fixed physics tick.

signal jumped
signal landed(impact_speed: float)
signal dashed(direction: Vector2)
signal pogoed
signal vaulted(perfect: bool)
signal respawned
signal died

@export var config: MovementConfig
## Seconds the defeat animation plays before the player respawns.
@export var death_time: float = 0.9

## 1 = facing right, -1 = facing left.
var facing: int = 1
## Set by the hammer during swings so the attack direction cannot flip.
var facing_locked: bool = false
var respawn_position: Vector2 = Vector2.ZERO

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _jump_cut_available: bool = false
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _dash_direction: Vector2 = Vector2.RIGHT
var _dash_current_speed: float = 0.0
var _air_dashes_left: int = 0
var _vault_cooldown_timer: float = 0.0
var _time_since_landing: float = 999.0
var _was_on_floor: bool = false
var _death_timer: float = 0.0


func _ready() -> void:
	if config == null:
		config = MovementConfig.new()
	respawn_position = global_position
	_air_dashes_left = config.air_dashes
	add_to_group(&"player")


func _physics_process(delta: float) -> void:
	if _death_timer > 0.0:
		_death_timer -= delta
		velocity = Vector2.ZERO
		if _death_timer <= 0.0:
			respawn()
		return

	var input_x := Input.get_axis(&"move_left", &"move_right")
	var input_y := Input.get_axis(&"move_up", &"move_down")

	_update_timers(delta)
	_update_facing(input_x)

	if Input.is_action_just_pressed(&"jump"):
		_jump_buffer_timer = config.jump_buffer_time
	if Input.is_action_just_pressed(&"dash"):
		_try_dash(input_x, input_y)

	if is_dashing():
		_process_dash(delta)
	else:
		_apply_horizontal(input_x, delta)
		_apply_gravity(delta)
	_try_jump()
	_apply_jump_cut()

	velocity.x = clampf(velocity.x, -config.max_horizontal_speed, config.max_horizontal_speed)
	velocity.y = clampf(velocity.y, -config.max_rise_speed, config.max_fall_speed)

	var pre_move_velocity := velocity
	move_and_slide()
	_post_move(pre_move_velocity)


# --- Public API ---------------------------------------------------------------


func is_dashing() -> bool:
	return _dash_timer > 0.0


func time_since_landing() -> float:
	return _time_since_landing


## Bounce upward off a pogo target. Restores the air dash and air control.
func pogo_bounce(speed: float) -> void:
	_end_dash()
	velocity.y = -speed
	_jump_cut_available = false
	_coyote_timer = 0.0
	_air_dashes_left = config.air_dashes
	pogoed.emit()


func can_vault() -> bool:
	return is_on_floor() and _vault_cooldown_timer <= 0.0 and not is_dashing()


## Plant the hammer and launch. Neutral input goes straight up; holding a
## direction converts the plant into a forward leap that keeps run momentum.
## Returns true when the vault was within the perfect-timing window.
func hammer_vault(input_x: float) -> bool:
	var perfect := _time_since_landing <= config.vault_perfect_window
	var multiplier := config.vault_perfect_multiplier if perfect else 1.0
	if absf(input_x) > 0.3:
		var direction := signf(input_x)
		var carried := maxf(velocity.x * direction, 0.0)
		velocity.x = direction * (carried + config.vault_forward_boost * multiplier)
		velocity.y = -config.vault_forward_up_speed * multiplier
		if not facing_locked:
			facing = int(direction)
	else:
		velocity.y = -config.vault_up_speed * multiplier
	_vault_cooldown_timer = config.vault_cooldown
	_jump_cut_available = false
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	vaulted.emit(perfect)
	return perfect


func is_dead() -> bool:
	return _death_timer > 0.0


## Hazards and the kill plane call this: play the defeat beat, then respawn.
func die() -> void:
	if is_dead():
		return
	_end_dash()
	velocity = Vector2.ZERO
	_death_timer = maxf(death_time, 0.01)
	facing_locked = false
	GameFeel.shake(10.0)
	GameFeel.hitstop(0.08)
	ComboTracker.reset()
	died.emit()


func respawn() -> void:
	_death_timer = 0.0
	_end_dash()
	global_position = respawn_position
	velocity = Vector2.ZERO
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	respawned.emit()


# --- Internals ----------------------------------------------------------------


func _update_timers(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = config.coyote_time
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)
	_dash_cooldown_timer = maxf(_dash_cooldown_timer - delta, 0.0)
	_vault_cooldown_timer = maxf(_vault_cooldown_timer - delta, 0.0)
	_time_since_landing += delta


func _update_facing(input_x: float) -> void:
	if facing_locked or is_dashing():
		return
	if input_x > 0.1:
		facing = 1
	elif input_x < -0.1:
		facing = -1


func _apply_horizontal(input_x: float, delta: float) -> void:
	var on_floor := is_on_floor()
	var target := input_x * config.max_run_speed
	var speed := absf(velocity.x)
	var has_input := absf(input_x) > 0.01
	var pushing_forward := has_input and signf(input_x) == signf(velocity.x)

	# Momentum preservation: above run speed, bleed off slowly instead of
	# snapping back, as long as the player keeps pushing the same way.
	if speed > config.max_run_speed and pushing_forward:
		var drag := config.overspeed_ground_drag if on_floor else config.overspeed_air_drag
		velocity.x = move_toward(velocity.x, target, drag * delta)
		return

	var rate: float
	if not has_input:
		rate = config.ground_deceleration if on_floor else config.air_deceleration
	elif speed > 0.01 and not pushing_forward:
		rate = config.ground_turn_acceleration if on_floor else config.air_turn_acceleration
	else:
		rate = config.ground_acceleration if on_floor else config.air_acceleration
	velocity.x = move_toward(velocity.x, target, rate * delta)


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return
	var gravity := config.rise_gravity() if velocity.y < 0.0 else config.fall_gravity()
	velocity.y += gravity * delta


func _try_jump() -> void:
	if _jump_buffer_timer <= 0.0 or _coyote_timer <= 0.0:
		return
	# Jumping out of a dash keeps the dash's horizontal speed.
	if is_dashing():
		var dash_velocity_x := velocity.x
		_end_dash()
		velocity.x = dash_velocity_x
	velocity.y = -config.jump_velocity()
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	_jump_cut_available = true
	jumped.emit()


func _apply_jump_cut() -> void:
	if not _jump_cut_available:
		return
	if velocity.y >= 0.0:
		_jump_cut_available = false
	elif not Input.is_action_pressed(&"jump"):
		velocity.y *= config.jump_cut_multiplier
		_jump_cut_available = false


func _try_dash(input_x: float, input_y: float) -> void:
	if is_dashing() or _dash_cooldown_timer > 0.0:
		return
	var on_floor := is_on_floor()
	if not on_floor and _air_dashes_left <= 0:
		return

	var direction := Vector2(input_x, input_y)
	if direction.length() < 0.3:
		direction = Vector2(float(facing), 0.0)
	# Snap to 8 directions for predictable dashes.
	direction = Vector2.from_angle(snappedf(direction.angle(), PI / 4.0))
	if on_floor and direction.y > 0.1:
		var side := signf(direction.x) if absf(direction.x) > 0.1 else float(facing)
		direction = Vector2(side, 0.0)

	if not on_floor:
		_air_dashes_left -= 1
	var speed_along := maxf(velocity.dot(direction), 0.0)
	_dash_current_speed = maxf(config.dash_speed, speed_along + config.dash_momentum_bonus)
	_dash_direction = direction
	_dash_timer = config.dash_duration
	_dash_cooldown_timer = config.dash_cooldown
	_jump_cut_available = false
	velocity = direction * _dash_current_speed
	if absf(direction.x) > 0.1 and not facing_locked:
		facing = int(signf(direction.x))
	dashed.emit(direction)


func _process_dash(delta: float) -> void:
	velocity = _dash_direction * _dash_current_speed
	_dash_timer -= delta
	if _dash_timer <= 0.0:
		_end_dash()


func _end_dash() -> void:
	if _dash_timer <= 0.0 and _dash_current_speed <= 0.0:
		return
	_dash_timer = 0.0
	velocity.x = _dash_direction.x * _dash_current_speed * config.dash_exit_retain
	velocity.y = _dash_direction.y * _dash_current_speed * config.dash_exit_retain
	if velocity.y < 0.0:
		velocity.y *= 0.6
	_dash_current_speed = 0.0


func _post_move(pre_move_velocity: Vector2) -> void:
	var on_floor := is_on_floor()
	if on_floor:
		_air_dashes_left = config.air_dashes
		if not _was_on_floor:
			_time_since_landing = 0.0
			landed.emit(pre_move_velocity.y)
	_was_on_floor = on_floor
