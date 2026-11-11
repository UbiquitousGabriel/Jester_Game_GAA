class_name KnightBrain
extends EnemyBrain
## Mace knight: heavy ground bruiser. Patrols, closes in on the Jester, then
## winds up an overhead mace slam. The windup is armoured (hits land but do
## not interrupt), so rushing in carelessly gets punished; attack from the
## air, from behind, or after the slam.

@export var sight_range: float = 560.0
@export var sight_height: float = 160.0
@export var patrol_speed: float = 60.0
@export var chase_speed: float = 125.0
@export var attack_range: float = 120.0
@export var windup_time: float = 0.62
@export var slam_time: float = 0.16
@export var recover_time: float = 0.7
@export var cooldown_time: float = 0.5
@export var damage: int = 2
## Slam hitbox, authored facing right, relative to the feet.
@export var slam_offset: Vector2 = Vector2(78.0, -46.0)
@export var slam_size: Vector2 = Vector2(150.0, 100.0)

var _cooldown: float = 0.0
var _slam_landed: bool = false


func has_armor() -> bool:
	return phase == Phase.WINDUP


func tick(enemy: Enemy, delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	match phase:
		Phase.WINDUP:
			enemy.velocity.x = move_toward(enemy.velocity.x, 0.0, 1800.0 * delta)
			if _advance(delta):
				_set_phase(Phase.ACTIVE, slam_time)
				_slam_landed = false
				GameFeel.shake(9.0)
				var dir := float(enemy.patrol_direction)
				Vfx.dust(enemy.get_parent(), enemy.global_position + Vector2(slam_offset.x * dir, 0.0), 1.4)
		Phase.ACTIVE:
			enemy.velocity.x = float(enemy.patrol_direction) * 60.0
			if not _slam_landed:
				var dir := float(enemy.patrol_direction)
				var centre := enemy.global_position + Vector2(slam_offset.x * dir, slam_offset.y)
				_slam_landed = _hit_player(enemy, Rect2(centre - slam_size * 0.5, slam_size), damage)
			if _advance(delta):
				_set_phase(Phase.RECOVER, recover_time)
		Phase.RECOVER:
			enemy.velocity.x = move_toward(enemy.velocity.x, 0.0, 1800.0 * delta)
			if _advance(delta):
				_set_phase(Phase.NONE, 0.0)
				_cooldown = cooldown_time
		Phase.NONE:
			_think(enemy)


func _think(enemy: Enemy) -> void:
	var player := _find_player()
	if player != null and enemy.is_on_floor():
		var offset := player.global_position - enemy.global_position
		if absf(offset.x) < sight_range and absf(offset.y) < sight_height:
			enemy.patrol_direction = 1 if offset.x > 0.0 else -1
			if absf(offset.x) < attack_range and _cooldown <= 0.0:
				_set_phase(Phase.WINDUP, windup_time)
				enemy.velocity.x = 0.0
				return
			if enemy.call(&"_has_floor_ahead") and not enemy.is_on_wall():
				enemy.velocity.x = float(enemy.patrol_direction) * chase_speed
			else:
				enemy.velocity.x = 0.0
			return
	# Patrol.
	if enemy.is_on_floor() and (enemy.is_on_wall() or not enemy.call(&"_has_floor_ahead")):
		enemy.patrol_direction = -enemy.patrol_direction
	enemy.velocity.x = float(enemy.patrol_direction) * patrol_speed if enemy.patrol_enabled else 0.0
