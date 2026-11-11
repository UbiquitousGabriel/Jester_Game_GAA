class_name PorcelainBrain
extends EnemyBrain
## Porcelain courtier: ticks forward in stiff little steps, then pirouettes
## with arms out. Shatters at a touch.

var _step: float = 0.0
var _cooldown: float = 0.6


func tick(enemy: Enemy, delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	var player := _find_player()
	match phase:
		Phase.WINDUP:
			enemy.velocity.x = 0.0
			if _advance(delta):
				_set_phase(Phase.ACTIVE, 0.7)
				Audio.sfx(&"spin")
		Phase.ACTIVE:
			_walk(enemy, 200.0)
			Combat.hurt_player_in(enemy, Rect2(enemy.global_position + Vector2(-80.0, -90.0), Vector2(160.0, 80.0)), 1, enemy.global_position)
			if _advance(delta):
				_set_phase(Phase.RECOVER, 0.5)
		Phase.RECOVER:
			enemy.velocity.x = 0.0
			if _advance(delta):
				_set_phase(Phase.NONE, 0.0)
				_cooldown = 1.0
		_:
			_step += delta
			var moving := fmod(_step, 0.5) < 0.18
			if _sees(enemy, player, 560.0, 140.0):
				_face(enemy, player.global_position)
				if absf(player.global_position.x - enemy.global_position.x) < 200.0 and _cooldown <= 0.0:
					_set_phase(Phase.WINDUP, 0.4)
					return
				if moving:
					_walk(enemy, 260.0 + 20.0 * tier)
				else:
					enemy.velocity.x = 0.0
			elif moving:
				_patrol(enemy, 160.0)
			else:
				enemy.velocity.x = 0.0
