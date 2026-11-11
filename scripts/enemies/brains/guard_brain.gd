class_name GuardBrain
extends EnemyBrain
## Court guard: patrols, spots the Jester and lunges with its halberd.

var _cooldown: float = 0.8
var _hit_done: bool = false


func tick(enemy: Enemy, delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	var player := _find_player()
	match phase:
		Phase.WINDUP:
			enemy.velocity.x = move_toward(enemy.velocity.x, 0.0, 2000.0 * delta)
			if _advance(delta):
				_set_phase(Phase.ACTIVE, 0.22)
				_hit_done = false
				enemy.velocity.x = float(enemy.patrol_direction) * (480.0 + 40.0 * tier)
		Phase.ACTIVE:
			if not _hit_done:
				var dir := float(enemy.patrol_direction)
				_hit_done = _hit_player(enemy, Rect2(enemy.global_position + Vector2(dir * 40.0 - 50.0, -70.0), Vector2(100.0, 60.0)), 1)
			if _advance(delta):
				_set_phase(Phase.RECOVER, 0.45)
		Phase.RECOVER:
			enemy.velocity.x = move_toward(enemy.velocity.x, 0.0, 2400.0 * delta)
			if _advance(delta):
				_set_phase(Phase.NONE, 0.0)
				_cooldown = 1.0 - 0.1 * tier
		Phase.NONE:
			if enemy.is_on_floor() and _sees(enemy, player, 520.0, 120.0):
				_face(enemy, player.global_position)
				if absf(player.global_position.x - enemy.global_position.x) < 190.0 and _cooldown <= 0.0:
					_set_phase(Phase.WINDUP, maxf(0.42 - 0.03 * tier, 0.28))
					return
				_walk(enemy, 120.0 + 12.0 * tier)
			elif enemy.patrol_enabled:
				_patrol(enemy, 80.0)
			else:
				enemy.velocity.x = 0.0
