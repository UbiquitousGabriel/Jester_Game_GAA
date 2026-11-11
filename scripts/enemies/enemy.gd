class_name Enemy
extends CharacterBody2D
## Launchable enemy base (Court Guard in the prototype).
##
## Launches are scripted and deterministic (Bible sections 5 and 17): a hit sets
## an explicit velocity, then this state machine integrates it with
## move_and_slide. Enemies never body-block each other; enemy-to-enemy impact is
## detected by a shape query while LAUNCHED, which avoids pile-up jitter.
##
## Loop protection for chain collisions:
##   * a mutual per-pair cooldown, so two bodies cannot ping-pong
##   * every transfer loses speed (momentum_transfer / self_retain < 1)
##   * collisions stop below min_collision_speed and above max_chain_depth

signal hit_taken(hit: HitData)
signal launched(launch_velocity: Vector2)
signal ricocheted
signal collided_with_enemy(other: Enemy)
signal defeated

enum State { GROUNDED, STAGGERED, LAUNCHED, KNOCKED_DOWN, RECOVER, DEFEATED }

const WORLD_MASK: int = 1
const ENEMY_MASK: int = 4

@export_group("Stats")
@export var max_health: int = 3
## Heavier enemies launch less far and hit others harder.
@export var mass: float = 1.0

@export_group("Flight")
## Flyers ignore gravity while active and recover in mid-air after a launch.
@export var flying: bool = false
## Seconds a launched flyer tumbles before it can catch itself.
@export var air_recover_time: float = 0.45
@export var air_recover_speed: float = 280.0

@export_group("Patrol")
@export var patrol_enabled: bool = true
@export var patrol_speed: float = 90.0
@export var ground_gravity: float = 3200.0

@export_group("Launch")
@export var launch_gravity: float = 2400.0
@export var max_launch_speed: float = 2200.0
## Hits slower than this only stagger.
@export var launch_threshold: float = 250.0
@export var ricochet_count: int = 2
@export var ricochet_min_speed: float = 450.0
@export_range(0.0, 1.0) var wall_restitution: float = 0.6
@export var floor_bounce_min_speed: float = 700.0
@export_range(0.0, 1.0) var floor_restitution: float = 0.45
@export var ground_friction: float = 2600.0

@export_group("Chain Collisions")
@export var min_collision_speed: float = 350.0
@export_range(0.0, 1.0) var momentum_transfer: float = 0.75
@export_range(0.0, 1.0) var self_retain: float = 0.45
@export var collision_damage: int = 1
@export var pair_cooldown: float = 0.45
@export var max_chain_depth: int = 6

@export_group("Timing")
@export var stagger_time: float = 0.25
@export var knockdown_time: float = 0.9
@export var recover_time: float = 0.35
@export var defeat_fade_time: float = 0.6

var state: State = State.GROUNDED
var health: int = 0
var patrol_direction: int = -1
## Seconds since the last hit, for visuals (hit flash).
var time_since_hit: float = 999.0

var _state_timer: float = 0.0
var _chain_depth: int = 0
var _ricochets_left: int = 0
var _floor_bounced: bool = false
var _pair_cooldowns: Dictionary[int, float] = {}
var _collision_shape: CollisionShape2D = null
## Optional behaviour child (EnemyBrain). Without one the enemy patrols.
var brain: EnemyBrain = null
var _launch_time: float = 0.0


func _ready() -> void:
	health = max_health
	add_to_group(&"enemy")
	for child: Node in get_children():
		if child is CollisionShape2D and _collision_shape == null:
			_collision_shape = child as CollisionShape2D
		elif child is EnemyBrain:
			brain = child as EnemyBrain


func _physics_process(delta: float) -> void:
	time_since_hit += delta
	_tick_pair_cooldowns(delta)
	match state:
		State.GROUNDED:
			_process_grounded(delta)
		State.STAGGERED:
			_process_resting(delta, State.GROUNDED, 0.0)
		State.LAUNCHED:
			_process_launched(delta)
		State.KNOCKED_DOWN:
			_process_resting(delta, State.RECOVER, recover_time)
		State.RECOVER:
			_process_resting(delta, State.GROUNDED, 0.0)
		State.DEFEATED:
			_process_defeated(delta)


# --- Public API ---------------------------------------------------------------


func is_alive() -> bool:
	return health > 0 and state != State.DEFEATED


## Entry point for every hit: hammer swings, enemy collisions, bounce pads.
func take_hit(hit: HitData) -> void:
	if state == State.DEFEATED:
		return
	health -= hit.damage
	time_since_hit = 0.0
	_chain_depth = hit.chain_depth
	hit_taken.emit(hit)

	# Armoured moves (a knight's windup) take damage without flinching.
	if brain != null and brain.has_armor() and health > 0:
		GameFeel.shake(3.0)
		return
	if brain != null:
		brain.interrupt()

	var launch := (hit.launch_velocity / maxf(mass, 0.1)).limit_length(max_launch_speed)
	if launch.length() < launch_threshold and health > 0:
		velocity.x = launch.x
		_enter(State.STAGGERED, stagger_time)
		return
	launch_with(launch)


## Put the enemy into the launched state with an explicit velocity.
func launch_with(launch_velocity: Vector2) -> void:
	if state == State.DEFEATED:
		return
	velocity = launch_velocity.limit_length(max_launch_speed)
	# Always leave the ground so floor snapping cannot cancel the launch.
	if is_on_floor() and velocity.y > -200.0:
		velocity.y = -200.0
	_ricochets_left = ricochet_count
	_floor_bounced = false
	_launch_time = 0.0
	_enter(State.LAUNCHED, 0.0)
	launched.emit(velocity)


## Instantly defeat (hazards, kill plane).
func defeat() -> void:
	if state == State.DEFEATED:
		return
	health = 0
	velocity = Vector2.ZERO
	_enter(State.DEFEATED, defeat_fade_time)
	defeated.emit()


# --- States -------------------------------------------------------------------


func _enter(new_state: State, duration: float) -> void:
	state = new_state
	_state_timer = duration


func _process_grounded(delta: float) -> void:
	if brain != null:
		if not flying and not is_on_floor():
			velocity.y += ground_gravity * delta
		brain.tick(self, delta)
		move_and_slide()
		return
	if not is_on_floor():
		velocity.y += ground_gravity * delta
	elif patrol_enabled:
		if is_on_wall() or not _has_floor_ahead():
			patrol_direction = -patrol_direction
		velocity.x = float(patrol_direction) * patrol_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)
	move_and_slide()


## Shared by STAGGERED, KNOCKED_DOWN and RECOVER: slide to a stop, then advance.
func _process_resting(delta: float, next_state: State, next_duration: float) -> void:
	if flying and state == State.STAGGERED:
		# Caught itself in the air: drift to a stop.
		velocity = velocity.move_toward(Vector2.ZERO, 3200.0 * delta)
	elif not is_on_floor():
		velocity.y += ground_gravity * delta
	velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)
	move_and_slide()
	_state_timer -= delta
	if _state_timer <= 0.0:
		_enter(next_state, next_duration)


func _process_launched(delta: float) -> void:
	_launch_time += delta
	velocity.y += launch_gravity * delta
	# Flyers catch themselves after a short tumble: sooner if slow, and
	# always by 1.8x air_recover_time so a launch never becomes a long fall.
	var caught := _launch_time >= air_recover_time and velocity.length() < air_recover_speed
	if flying and health > 0 and (caught or _launch_time >= air_recover_time * 1.8):
		_chain_depth = 0
		_enter(State.STAGGERED, stagger_time)
		return
	var pre_move_velocity := velocity
	move_and_slide()

	if _smash_breakables(pre_move_velocity):
		# Plough through the prop, losing a little speed.
		velocity = pre_move_velocity * 0.85
		return

	_collide_with_enemies()

	if is_on_wall() and absf(pre_move_velocity.x) >= ricochet_min_speed and _ricochets_left > 0:
		_ricochets_left -= 1
		velocity.x = -pre_move_velocity.x * wall_restitution
		GameFeel.shake(3.0)
		ricocheted.emit()

	if is_on_floor():
		if pre_move_velocity.y >= floor_bounce_min_speed and not _floor_bounced:
			_floor_bounced = true
			velocity.y = -pre_move_velocity.y * floor_restitution
			velocity.x = pre_move_velocity.x * 0.8
		elif pre_move_velocity.y >= 0.0:
			_land()


func _land() -> void:
	_chain_depth = 0
	if health <= 0:
		_enter(State.DEFEATED, defeat_fade_time)
		defeated.emit()
	else:
		_enter(State.KNOCKED_DOWN, knockdown_time)


func _process_defeated(delta: float) -> void:
	if not is_on_floor():
		velocity.y += ground_gravity * delta
	velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)
	move_and_slide()
	_state_timer -= delta
	# The death animation plays first; fade only in the last third.
	modulate.a = clampf(_state_timer / maxf(defeat_fade_time * 0.33, 0.001), 0.0, 1.0)
	if _state_timer <= 0.0:
		queue_free()


# --- Launch interactions --------------------------------------------------------


func _collide_with_enemies() -> void:
	if _collision_shape == null or _chain_depth >= max_chain_depth:
		return
	if velocity.length() < min_collision_speed:
		return

	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = _collision_shape.shape
	params.transform = _collision_shape.global_transform
	params.collision_mask = ENEMY_MASK
	var space := get_world_2d().direct_space_state
	var results: Array[Dictionary] = space.intersect_shape(params, 8)

	for result: Dictionary in results:
		var other := result.get("collider") as Enemy
		if other == null or other == self or other.state == State.DEFEATED:
			continue
		var other_id := other.get_instance_id()
		if _pair_cooldowns.has(other_id):
			continue
		# Mutual cooldown: neither body can re-hit the other until it expires.
		_pair_cooldowns[other_id] = pair_cooldown
		other._pair_cooldowns[get_instance_id()] = pair_cooldown

		var hit := HitData.new()
		hit.attack_id = &"enemy_collision"
		hit.damage = collision_damage
		hit.source = self
		hit.chain_depth = _chain_depth + 1
		# Multiply by our mass so the target's own mass division yields a
		# proper heavy-hits-light / light-hits-heavy exchange.
		hit.launch_velocity = velocity * momentum_transfer * mass + Vector2(0.0, -180.0)
		other.take_hit(hit)

		velocity *= self_retain
		GameFeel.hitstop(0.04)
		GameFeel.shake(5.0)
		ComboTracker.register_hit()
		collided_with_enemy.emit(other)
		if velocity.length() < min_collision_speed:
			break


## Returns true when a breakable prop was smashed this step.
func _smash_breakables(impact_velocity: Vector2) -> bool:
	var smashed := false
	for index: int in get_slide_collision_count():
		var collision := get_slide_collision(index)
		var collider := collision.get_collider() as Node
		if collider != null and collider.has_method(&"smash"):
			collider.call(&"smash", impact_velocity)
			smashed = true
	return smashed


func _has_floor_ahead() -> bool:
	var from := global_position + Vector2(float(patrol_direction) * 34.0, -6.0)
	var to := from + Vector2(0.0, 48.0)
	var query := PhysicsRayQueryParameters2D.create(from, to, WORLD_MASK)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return not hit.is_empty()


func _tick_pair_cooldowns(delta: float) -> void:
	if _pair_cooldowns.is_empty():
		return
	for id: int in _pair_cooldowns.keys():
		var remaining: float = _pair_cooldowns[id] - delta
		if remaining <= 0.0:
			_pair_cooldowns.erase(id)
		else:
			_pair_cooldowns[id] = remaining
