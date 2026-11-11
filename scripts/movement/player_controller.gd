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
signal damaged(amount: int)
signal health_changed(health: int, max_health: int)
signal glide_started
signal wall_kicked(direction: int)
signal healed

const WORLD_MASK := 1
const SPECTRAL_MASK := 128
const ONE_WAY_MASK := 256

@export var config: MovementConfig
## Seconds the defeat animation plays before the player respawns.
@export var death_time: float = 0.9

@export_group("Health")
@export var max_health: int = 5
## Seconds of invulnerability after taking damage.
@export var invulnerable_time: float = 1.1
## Seconds of lost control while being knocked back.
@export var hurt_time: float = 0.32
@export var hurt_knockback: Vector2 = Vector2(460.0, -440.0)

@export_group("Air")
## Hammer twirl: second jump press in the air. Slows the fall, keeps speed.
@export var glide_fall_speed: float = 150.0
@export var glide_lift: float = 260.0
@export var glide_budget: float = 1.2
## While swinging in the air the Jester hangs: gravity scale and fall cap.
@export var air_hang_gravity: float = 0.22
@export var air_hang_fall_cap: float = 110.0

@export_group("Wall Bounce")
@export var wall_kick_speed: Vector2 = Vector2(540.0, 1050.0)
## Seconds after a kick before input can steer back toward the wall.
@export var wall_kick_lock: float = 0.14
@export var wall_slide_speed: float = 260.0

## When false (e.g. the movement playground), every ability is available and
## charms are ignored; the castle sets it true so GameState gates abilities.
var use_progression: bool = false

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
var health: int = 0
var _invulnerable_timer: float = 0.0
var _hurt_timer: float = 0.0
var _gliding: bool = false
var _glide_left: float = 0.0
var _air_hang: bool = false
var _full_death: bool = true
var _wall_kick_timer: float = 0.0
var _drop_timer: float = 0.0
var _ghosting: bool = false


func _ready() -> void:
	if config == null:
		config = MovementConfig.new()
	respawn_position = global_position
	_air_dashes_left = config.air_dashes
	_glide_left = glide_budget
	health = max_health
	collision_mask = WORLD_MASK | SPECTRAL_MASK | ONE_WAY_MASK
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
	_invulnerable_timer = maxf(_invulnerable_timer - delta, 0.0)

	if _hurt_timer > 0.0:
		# Knocked back: no control, just physics.
		_hurt_timer -= delta
		_update_timers(delta)
		velocity.y += config.fall_gravity() * delta
		velocity.x = move_toward(velocity.x, 0.0, config.air_deceleration * delta)
		var hurt_velocity := velocity
		move_and_slide()
		_post_move(hurt_velocity)
		return

	_update_timers(delta)
	_update_facing(input_x)

	_wall_kick_timer = maxf(_wall_kick_timer - delta, 0.0)
	_drop_timer = maxf(_drop_timer - delta, 0.0)
	if _drop_timer <= 0.0 and collision_mask & ONE_WAY_MASK == 0:
		collision_mask |= ONE_WAY_MASK
	if Input.is_action_just_pressed(&"jump"):
		if input_y > 0.5 and is_on_floor() and _standing_on_one_way():
			# Drop through a ledge instead of jumping.
			collision_mask &= ~ONE_WAY_MASK
			_drop_timer = 0.22
			position.y += 2.0
		elif not _try_wall_kick():
			_jump_buffer_timer = config.jump_buffer_time
			_try_start_glide()
	if _gliding:
		_glide_left -= delta
		if not Input.is_action_pressed(&"jump") or _glide_left <= 0.0 or is_on_floor():
			_gliding = false
	if Input.is_action_just_pressed(&"dash"):
		_try_dash(input_x, input_y)

	if is_dashing():
		_process_dash(delta)
	else:
		if _wall_kick_timer > 0.0:
			input_x = signf(velocity.x)
		_apply_horizontal(input_x, delta)
		_apply_gravity(delta)
		# Wall bounce owners slide slowly down walls they push into.
		if has_ability(&"wallkick") and is_on_wall_only() and velocity.y > wall_slide_speed \
				and absf(input_x) > 0.3 and signf(input_x) == -get_wall_normal().x:
			velocity.y = wall_slide_speed
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


## Abilities are gated by GameState in the castle and always on elsewhere.
func has_ability(id: StringName) -> bool:
	return not use_progression or GameState.has(id)


func has_charm(id: StringName) -> bool:
	return use_progression and GameState.has_charm(id)


func is_ghosting() -> bool:
	return _ghosting


func heal_full() -> void:
	health = max_health
	health_changed.emit(health, max_health)
	healed.emit()


func heal(amount: int) -> void:
	health = mini(health + amount, max_health)
	health_changed.emit(health, max_health)
	healed.emit()


## Re-reads the heart total from GameState (after a heart piece).
func refresh_max_health() -> void:
	if use_progression:
		max_health = GameState.max_hearts()
	health = mini(health, max_health)
	health_changed.emit(health, max_health)


func time_since_landing() -> float:
	return _time_since_landing


## Bounce upward off a pogo target. Restores the air dash and air control.
func pogo_bounce(speed: float) -> void:
	_end_dash()
	velocity.y = -speed * (1.1 if has_charm(&"rubber_nose") else 1.0)
	_jump_cut_available = false
	_coyote_timer = 0.0
	_air_dashes_left = config.air_dashes
	_glide_left = glide_budget
	_gliding = false
	pogoed.emit()


func is_gliding() -> bool:
	return _gliding


func is_hurt() -> bool:
	return _hurt_timer > 0.0


func is_invulnerable() -> bool:
	return _invulnerable_timer > 0.0


## The hammer sets this while swinging in the air: the Jester hangs in place.
func set_air_hang(hang: bool) -> void:
	_air_hang = hang and not is_on_floor()


## A connecting air hit bounces the Jester up and refreshes his air tools,
## so chaining hits keeps him airborne.
func air_hit_bounce(speed: float) -> void:
	if is_on_floor():
		return
	velocity.y = minf(velocity.y, -speed)
	_air_dashes_left = config.air_dashes
	_glide_left = glide_budget
	_jump_cut_available = false


## Enemy attacks. Returns true when the damage landed.
func take_damage(amount: int, source_position: Vector2) -> bool:
	if is_dead() or _invulnerable_timer > 0.0 or amount <= 0 or _ghosting:
		return false
	_apply_damage(amount)
	if health <= 0:
		_full_death = true
		die()
		return true
	_end_dash()
	_gliding = false
	var away := signf(global_position.x - source_position.x)
	if away == 0.0:
		away = -float(facing)
	velocity = Vector2(away * hurt_knockback.x, hurt_knockback.y)
	_hurt_timer = hurt_time
	_invulnerable_timer = invulnerable_time * (1.6 if has_charm(&"thick_skull") else 1.0)
	GameFeel.hitstop(0.07)
	GameFeel.shake(8.0)
	return true


## Spikes and the kill plane: lose a heart and go back to the checkpoint.
func hazard_hit() -> void:
	if is_dead():
		return
	_apply_damage(1)
	_full_death = health <= 0
	die()


func can_vault() -> bool:
	return has_ability(&"vault") and is_on_floor() and _vault_cooldown_timer <= 0.0 and not is_dashing()


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
	_hurt_timer = 0.0
	_gliding = false
	if _full_death or health <= 0:
		health = max_health
		health_changed.emit(health, max_health)
	_full_death = true
	_invulnerable_timer = invulnerable_time
	_end_dash()
	global_position = respawn_position
	velocity = Vector2.ZERO
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	respawned.emit()


# --- Internals ----------------------------------------------------------------


func _apply_damage(amount: int) -> void:
	health = maxi(health - amount, 0)
	damaged.emit(amount)
	health_changed.emit(health, max_health)


func _try_start_glide() -> void:
	# A second press in the air (not a buffered or coyote jump).
	if not has_ability(&"glide"):
		return
	if is_on_floor() or _coyote_timer > 0.0 or _gliding or _glide_left <= 0.1 or is_dashing():
		return
	_gliding = true
	velocity.y = minf(velocity.y, -glide_lift)
	_jump_cut_available = false
	glide_started.emit()


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
	if _air_hang:
		gravity *= air_hang_gravity
	velocity.y += gravity * delta
	if _air_hang:
		velocity.y = minf(velocity.y, air_hang_fall_cap)
	elif _gliding:
		velocity.y = minf(velocity.y, glide_fall_speed)


func _try_jump() -> void:
	if _jump_buffer_timer <= 0.0 or _coyote_timer <= 0.0:
		return
	# Jumping out of a dash keeps the dash's horizontal speed.
	if is_dashing():
		var dash_velocity_x := velocity.x
		_end_dash()
		velocity.x = dash_velocity_x
	velocity.y = -config.jump_velocity() * (1.058 if has_charm(&"spring_heels") else 1.0)
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
	_dash_timer = config.dash_duration * (1.35 if has_charm(&"cartwheel") else 1.0)
	if has_ability(&"ghost_dash"):
		_ghosting = true
		collision_mask &= ~SPECTRAL_MASK
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
	if _ghosting:
		_ghosting = false
		collision_mask |= SPECTRAL_MASK
		_eject_from_spectral()
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
		_glide_left = glide_budget
		_gliding = false
		_air_hang = false
		if not _was_on_floor:
			_time_since_landing = 0.0
			landed.emit(pre_move_velocity.y)
	_was_on_floor = on_floor


func _try_wall_kick() -> bool:
	if not has_ability(&"wallkick") or is_on_floor() or _coyote_timer > 0.0:
		return false
	var side := _wall_side()
	if side == 0:
		return false
	if is_dashing():
		_end_dash()
	_gliding = false
	velocity = Vector2(-float(side) * wall_kick_speed.x, -wall_kick_speed.y)
	facing = -side
	_wall_kick_timer = wall_kick_lock
	_air_dashes_left = config.air_dashes
	_jump_cut_available = true
	wall_kicked.emit(-side)
	return true


## -1 wall on the left, 1 on the right, 0 none (checks a few pixels out).
func _wall_side() -> int:
	for side: int in [1, -1]:
		if test_move(global_transform, Vector2(float(side) * 14.0, 0.0)):
			return side
	return 0


func _standing_on_one_way() -> bool:
	for i: int in get_slide_collision_count():
		var collider := get_slide_collision(i).get_collider() as Node
		if collider != null and collider.is_in_group(&"one_way"):
			return true
	return false


## After a phantom step ends inside a spectral barrier, push out along the dash.
func _eject_from_spectral() -> void:
	for i: int in 40:
		if not test_move(global_transform, Vector2.ZERO):
			return
		global_position += _dash_direction * 8.0 if _dash_direction != Vector2.ZERO else Vector2(float(facing) * 8.0, 0.0)
