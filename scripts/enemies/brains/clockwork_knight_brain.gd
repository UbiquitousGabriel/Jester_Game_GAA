class_name ClockworkKnightBrain
extends EnemyBrain
## Clockwork knight: wind-up automaton. Spins its blades toward the Jester
## (armoured while spinning), then has to wind its key, wide open.

var _cooldown: float = 0.8


func has_armor() -> bool:
	return phase == Phase.ACTIVE or phase == Phase.WINDUP


func tick(enemy: Enemy, delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	var player := _find_player()
	match phase:
		Phase.WINDUP:
			enemy.velocity.x = 0.0
			if _advance(delta):
				_set_phase(Phase.ACTIVE, 1.4)
				Audio.sfx(&"whirr")
		Phase.ACTIVE:
			if player:
				_face(enemy, player.global_position)
			_walk(enemy, 260.0 + 20.0 * tier)
			Combat.hurt_player_in(enemy, Rect2(enemy.global_position + Vector2(-95.0, -120.0), Vector2(190.0, 110.0)), 1 + tier / 4, enemy.global_position)
			if _advance(delta):
				_set_phase(Phase.RECOVER, 1.2)
				Audio.sfx(&"wind_down")
		Phase.RECOVER:
			enemy.velocity.x = move_toward(enemy.velocity.x, 0.0, 1500.0 * delta)
			if _advance(delta):
				_set_phase(Phase.NONE, 0.0)
				_cooldown = 1.0
		_:
			if _sees(enemy, player, 620.0, 150.0):
				_face(enemy, player.global_position)
				if _cooldown <= 0.0:
					_set_phase(Phase.WINDUP, 0.6)
					return
				_walk(enemy, 90.0)
			else:
				_patrol(enemy, 70.0)
