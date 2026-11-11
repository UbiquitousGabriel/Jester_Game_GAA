class_name BatBrain
extends EnemyBrain
## Bat knight: aerial harrier. Bobs around its roost, stalks to a perch
## above and ahead of the Jester, then dives claws-first and climbs away.
## Light and fragile: perfect air-combo fodder and a launchable projectile.

@export var sight_range: float = 640.0
@export var leash_range: float = 900.0
@export var hover_speed: float = 150.0
@export var stalk_speed: float = 260.0
@export var perch_offset: Vector2 = Vector2(190.0, -190.0)
@export var windup_time: float = 0.3
@export var dive_speed: float = 680.0
@export var dive_time: float = 0.5
@export var climb_time: float = 0.55
@export var cooldown_time: float = 1.1
@export var damage: int = 1
@export var claw_size: Vector2 = Vector2(80.0, 70.0)

var home: Vector2 = Vector2.ZERO
var _home_set: bool = false
var _cooldown: float = 0.6
var _dive_direction: Vector2 = Vector2.ZERO
var _clawed: bool = false
var _time: float = 0.0


func tick(enemy: Enemy, delta: float) -> void:
	if not _home_set:
		home = enemy.global_position
		_home_set = true
	_time += delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	match phase:
		Phase.WINDUP:
			# Rear back before the dive.
			enemy.velocity = enemy.velocity.move_toward(-_dive_direction * 90.0, 1600.0 * delta)
			if _advance(delta):
				_set_phase(Phase.ACTIVE, dive_time)
				_clawed = false
		Phase.ACTIVE:
			enemy.velocity = _dive_direction * dive_speed
			if not _clawed:
				var centre := enemy.global_position + _dive_direction * 30.0
				_clawed = _hit_player(enemy, Rect2(centre - claw_size * 0.5, claw_size), damage)
			if _advance(delta) or enemy.is_on_floor() or enemy.is_on_wall():
				_set_phase(Phase.RECOVER, climb_time)
		Phase.RECOVER:
			var climb := Vector2(-_dive_direction.x * 0.4, -1.0).normalized() * 320.0
			enemy.velocity = enemy.velocity.move_toward(climb, 1800.0 * delta)
			if _advance(delta):
				_set_phase(Phase.NONE, 0.0)
				_cooldown = cooldown_time
		Phase.NONE:
			_think(enemy, delta)


func _think(enemy: Enemy, delta: float) -> void:
	var player := _find_player()
	var target := home + Vector2(sin(_time * 0.9) * 60.0, sin(_time * 2.3) * 22.0)
	var speed := hover_speed
	if player != null:
		var offset := player.global_position - enemy.global_position
		var from_home := player.global_position - home
		if offset.length() < sight_range and from_home.length() < leash_range:
			var side := -1.0 if offset.x > 0.0 else 1.0
			target = player.global_position + Vector2(perch_offset.x * side, perch_offset.y)
			target.y += sin(_time * 3.0) * 14.0
			speed = stalk_speed
			enemy.patrol_direction = 1 if offset.x > 0.0 else -1
			var at_perch := enemy.global_position.distance_to(target) < 70.0
			if at_perch and _cooldown <= 0.0:
				# Aim a little ahead of a moving Jester.
				var aim := player.global_position + Vector2(0.0, -40.0) + player.velocity * 0.18
				_dive_direction = (aim - enemy.global_position).normalized()
				_set_phase(Phase.WINDUP, windup_time)
				return
	var to_target := target - enemy.global_position
	var desired := to_target.limit_length(speed) if to_target.length() > 8.0 else Vector2.ZERO
	enemy.velocity = enemy.velocity.move_toward(desired, 900.0 * delta)
	if absf(enemy.velocity.x) > 20.0 and phase == Phase.NONE and player == null:
		enemy.patrol_direction = 1 if enemy.velocity.x > 0.0 else -1
	# Take off again after being knocked to the ground.
	if enemy.is_on_floor():
		enemy.velocity.y = -260.0
