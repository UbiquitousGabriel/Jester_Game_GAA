class_name Hammer
extends Node2D
## The clown hammer: attack input, swing state machine and hit detection.
##
## Must be a child of Player. Runs after the player's own physics step
## (children process after their parent), so hitboxes use the moved position.
##
## Hit pipeline (Bible section 5):
##   hitbox overlap -> AttackData -> HitData -> target.take_hit()
##   -> hitstop / shake -> combo.
## Hit detection uses direct physics shape queries during active frames rather
## than Area2D signals: overlaps resolve on the same tick the swing is active,
## with no one-frame monitoring delay.

signal attack_started(attack: AttackData)
signal hit_landed(target: Node, hit: HitData)
signal charge_started
signal charge_released(ratio: float)

enum State { IDLE, CHARGING, STARTUP, ACTIVE, RECOVERY }

const MAX_QUERY_RESULTS: int = 16

@export_group("Moveset")
@export var light_side: AttackData
@export var light_up: AttackData
@export var air_down: AttackData
@export var heavy: AttackData
## Neutral light presses in the air chain through these in order.
@export var air_combo: Array[AttackData] = []
## Hitbox while the Jester twirls the hammer in a glide.
@export var glide_spin: AttackData

@export_group("Charge")
@export var max_charge_time: float = 0.8
## Launch multiplier at full charge (1.0 at a tap).
@export var charge_launch_multiplier: float = 1.9
@export var charge_damage_bonus: int = 2

@export_group("Tuning")
@export var input_buffer_time: float = 0.12
## Launch speeds are clamped to this for predictable trajectories.
@export var max_launch_speed: float = 2200.0
## enemy (3) + hazard (6) + prop (7)
@export_flags_2d_physics var hit_mask: int = 4 | 32 | 64
## Max air speed a lunge can push the Jester to.
@export var max_lunge_speed: float = 640.0
## Seconds between glide-spin hits on the same target.
@export var glide_rehit_time: float = 0.3

var state: State = State.IDLE
var current_attack: AttackData = null
## 0..1 while charging; kept after release so visuals can read it.
var charge_ratio: float = 0.0

var _player: Player = null
var _state_timer: float = 0.0
var _elapsed: float = 0.0
var _charge_time: float = 0.0
var _light_buffer: float = 0.0
var _power: float = 1.0
var _bonus_damage: int = 0
var _hit_ids: Array[int] = []
var _has_bounced: bool = false
## Index of the current or last air combo swing (-1 = none since landing).
var _air_step: int = -1
var _glide_cooldowns: Dictionary[int, float] = {}
## Air strings started since the last landing or connecting hit. Only the
## first ones hang in the air, so whiffing cannot hover forever.
var _air_strings: int = 0
const HANGING_STRINGS := 1


func _ready() -> void:
	_player = get_parent() as Player
	assert(_player != null, "Hammer must be a child of Player.")
	if light_side == null:
		light_side = AttackData.new()
	if light_up == null:
		light_up = light_side
	if air_down == null:
		air_down = light_side
	if heavy == null:
		heavy = light_side
	if air_combo.is_empty():
		for path: String in ["air_1", "air_2", "air_finisher"]:
			air_combo.append(load("res://resources/combat/%s.tres" % path) as AttackData)
	if glide_spin == null:
		glide_spin = load("res://resources/combat/glide_spin.tres") as AttackData
	_player.landed.connect(_on_player_landed)


func _physics_process(delta: float) -> void:
	var input_y := Input.get_axis(&"move_up", &"move_down")
	_light_buffer = maxf(_light_buffer - delta, 0.0)
	if Input.is_action_just_pressed(&"attack_light"):
		_light_buffer = input_buffer_time

	if _player.is_dead() or _player.is_hurt():
		_cancel()
		return

	_player.set_air_hang(
		is_attacking() and current_attack != null and current_attack.hang
		and _air_strings <= HANGING_STRINGS
	)
	_tick_glide_spin(delta)

	match state:
		State.IDLE:
			_process_idle(input_y)
		State.CHARGING:
			_process_charging(delta)
		State.STARTUP:
			_elapsed += delta
			_state_timer -= delta
			if _state_timer <= 0.0:
				state = State.ACTIVE
				_state_timer = current_attack.active
				_scan_hits()
		State.ACTIVE:
			_elapsed += delta
			_scan_hits()
			_state_timer -= delta
			if _state_timer <= 0.0:
				state = State.RECOVERY
				_state_timer = current_attack.recovery
				_player.facing_locked = false
		State.RECOVERY:
			_elapsed += delta
			_state_timer -= delta
			if _try_chain_air_combo():
				return
			if _state_timer <= 0.0:
				state = State.IDLE
				current_attack = null


## 0..1 progress through the current phase (startup, active or recovery).
func phase_progress() -> float:
	if current_attack == null:
		return 0.0
	var length := 0.0
	match state:
		State.STARTUP:
			length = current_attack.startup
		State.ACTIVE:
			length = current_attack.active
		State.RECOVERY:
			length = current_attack.recovery
		_:
			return 0.0
	if length <= 0.0:
		return 1.0
	return clampf(1.0 - _state_timer / length, 0.0, 1.0)


## 0..1 progress through the whole current swing, for visuals.
func attack_progress() -> float:
	if current_attack == null:
		return 0.0
	return clampf(_elapsed / maxf(current_attack.total_time(), 0.001), 0.0, 1.0)


func is_attacking() -> bool:
	return state == State.STARTUP or state == State.ACTIVE or state == State.RECOVERY


func _cancel() -> void:
	state = State.IDLE
	current_attack = null
	charge_ratio = 0.0
	_player.facing_locked = false


func _process_idle(input_y: float) -> void:
	if Input.is_action_just_pressed(&"attack_heavy"):
		if input_y > 0.5 and _player.can_vault():
			_player.hammer_vault(Input.get_axis(&"move_left", &"move_right"))
			GameFeel.shake(4.0)
			return
		state = State.CHARGING
		_charge_time = 0.0
		charge_ratio = 0.0
		charge_started.emit()
		return

	if _light_buffer > 0.0:
		_light_buffer = 0.0
		var airborne := not _player.is_on_floor()
		if input_y > 0.5 and airborne:
			_begin(air_down, 1.0, 0)
		elif airborne and input_y >= -0.5 and not air_combo.is_empty():
			# A new air string starts over; a press right after a string
			# continues it only through _try_chain_air_combo.
			_air_step = 0
			_air_strings += 1
			_begin(air_combo[0], 1.0, 0)
		elif input_y < -0.5:
			_begin(light_up, 1.0, 0)
		else:
			_begin(light_side, 1.0, 0)


func _process_charging(delta: float) -> void:
	_charge_time = minf(_charge_time + delta, max_charge_time)
	charge_ratio = _charge_time / maxf(max_charge_time, 0.001)
	if Input.is_action_pressed(&"attack_heavy"):
		return
	charge_released.emit(charge_ratio)
	var power := lerpf(1.0, charge_launch_multiplier, charge_ratio)
	var bonus := roundi(float(charge_damage_bonus) * charge_ratio)
	_begin(heavy, power, bonus)
	if charge_ratio >= 0.95 and _player.is_on_floor() and _player.has_ability(&"slam"):
		_shockwave()


func _try_chain_air_combo() -> bool:
	if _light_buffer <= 0.0 or _air_step < 0 or _player.is_on_floor():
		return false
	if not air_combo.has(current_attack) or _air_step >= air_combo.size() - 1:
		return false
	_light_buffer = 0.0
	_air_step += 1
	_begin(air_combo[_air_step], 1.0, 0)
	return true


func _begin(attack: AttackData, power: float, bonus_damage: int) -> void:
	current_attack = attack
	_power = power
	_bonus_damage = bonus_damage
	_hit_ids.clear()
	_has_bounced = false
	_elapsed = 0.0
	state = State.STARTUP
	_state_timer = attack.startup
	if not _player.is_on_floor():
		var dir := Input.get_axis(&"move_left", &"move_right")
		if absf(dir) > 0.3 and not _player.facing_locked:
			_player.facing = int(signf(dir))
		if attack.lunge > 0.0 and _air_strings <= HANGING_STRINGS:
			var push := float(_player.facing) * attack.lunge
			var vx := _player.velocity.x + push
			if absf(_player.velocity.x) < max_lunge_speed:
				_player.velocity.x = clampf(vx, -max_lunge_speed, max_lunge_speed)
		if attack.hang and _player.velocity.y > 0.0 and _air_strings <= HANGING_STRINGS:
			_player.velocity.y *= 0.25
	_player.facing_locked = true
	attack_started.emit(attack)


func _scan_hits() -> void:
	var shape := RectangleShape2D.new()
	shape.size = current_attack.hitbox_size
	var offset := Vector2(
		current_attack.hitbox_offset.x * float(_player.facing), current_attack.hitbox_offset.y
	)
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, _player.global_position + offset)
	params.collision_mask = hit_mask
	params.collide_with_areas = true
	params.collide_with_bodies = true

	var space := get_world_2d().direct_space_state
	var results: Array[Dictionary] = space.intersect_shape(params, MAX_QUERY_RESULTS)
	for result: Dictionary in results:
		var node := result.get("collider") as Node
		if node == null:
			continue
		var id := node.get_instance_id()
		if _hit_ids.has(id):
			continue
		var is_target := node.has_method(&"take_hit")
		var is_pogo_surface := node.is_in_group(&"pogoable")
		if not is_target and not is_pogo_surface:
			continue
		# One hit per target per swing.
		_hit_ids.append(id)
		if is_target:
			_apply_hit(node)
		if current_attack.bounces_attacker and not _has_bounced:
			_has_bounced = true
			var config := _player.config
			var is_enemy := node is Enemy
			_player.pogo_bounce(
				config.pogo_enemy_bounce_speed if is_enemy else config.pogo_bounce_speed
			)


func _apply_hit(target: Node) -> void:
	var hit := HitData.new()
	hit.attack_id = current_attack.id
	hit.damage = current_attack.damage + _bonus_damage
	if _player.has_charm(&"heavy_head") and (charge_ratio >= 0.7 and current_attack == heavy or current_attack.id == &"air_finisher"):
		hit.damage += 1
	hit.source = _player
	hit.chain_depth = 0
	hit.charge = charge_ratio if current_attack == heavy else 0.0
	var launch := Vector2(
		current_attack.launch_vector.x * float(_player.facing), current_attack.launch_vector.y
	)
	launch = launch * _power + _player.velocity * current_attack.inherit_velocity
	hit.launch_velocity = launch.limit_length(max_launch_speed)

	target.call(&"take_hit", hit)
	GameFeel.hitstop(current_attack.hitstop * _power)
	GameFeel.shake(current_attack.shake * _power)
	ComboTracker.register_hit()
	if current_attack.air_bounce > 0.0 and node_is_fighter(target):
		_player.air_hit_bounce(current_attack.air_bounce * (1.2 if _player.has_charm(&"juggler_gloves") else 1.0))
		_air_strings = 0
	hit_landed.emit(target, hit)


func _on_player_landed(_speed: float) -> void:
	_air_step = -1
	_air_strings = 0


## Enemies give air bounces; props and spikes do not.
func node_is_fighter(target: Node) -> bool:
	return target is Enemy


## Hammer twirl: while gliding, the spinning hammer hits anything it touches.
func _tick_glide_spin(delta: float) -> void:
	for id: int in _glide_cooldowns.keys():
		_glide_cooldowns[id] -= delta
		if _glide_cooldowns[id] <= 0.0:
			_glide_cooldowns.erase(id)
	if glide_spin == null or not _player.is_gliding() or is_attacking():
		return
	var shape := RectangleShape2D.new()
	shape.size = glide_spin.hitbox_size
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, _player.global_position + glide_spin.hitbox_offset)
	params.collision_mask = hit_mask
	params.collide_with_areas = true
	params.collide_with_bodies = true
	var results: Array[Dictionary] = get_world_2d().direct_space_state.intersect_shape(params, MAX_QUERY_RESULTS)
	for result: Dictionary in results:
		var node := result.get("collider") as Node
		if node == null or not node.has_method(&"take_hit") or not node is Enemy:
			continue
		var id := node.get_instance_id()
		if _glide_cooldowns.has(id):
			continue
		_glide_cooldowns[id] = glide_rehit_time
		var target := node as Node2D
		var away := signf(target.global_position.x - _player.global_position.x)
		var hit := HitData.new()
		hit.attack_id = glide_spin.id
		hit.damage = glide_spin.damage
		hit.source = _player
		hit.launch_velocity = Vector2(glide_spin.launch_vector.x * (away if away != 0.0 else 1.0),
			glide_spin.launch_vector.y) + _player.velocity * glide_spin.inherit_velocity
		node.call(&"take_hit", hit)
		GameFeel.hitstop(glide_spin.hitstop)
		GameFeel.shake(glide_spin.shake)
		ComboTracker.register_hit()
		_player.air_hit_bounce(glide_spin.air_bounce)
		hit_landed.emit(node, hit)


## Cracking Slam: a full charge on the ground sends a shockwave both ways.
func _shockwave() -> void:
	var at := _player.global_position
	GameFeel.shake(16.0)
	GameFeel.hitstop(0.06)
	Audio.sfx(&"slam")
	Vfx.dust(_player.get_parent(), at + Vector2(-120.0, 0.0), 1.8)
	Vfx.dust(_player.get_parent(), at + Vector2(120.0, 0.0), 1.8)
	Vfx.ring(_player.get_parent(), at + Vector2(0.0, -20.0), Color(1.0, 0.8, 0.45), 2.4)
	Combat.area_damage(self, Rect2(at + Vector2(-340.0, -110.0), Vector2(680.0, 120.0)), 2,
		Vector2(700.0, -900.0), _player)
