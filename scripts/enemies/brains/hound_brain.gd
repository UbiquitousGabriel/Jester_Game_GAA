class_name HoundBrain
extends EnemyBrain
## Gargoyle hound: growls, then charges flat out. Slams into walls and
## stuns itself; jump the charge and punish.


func tick(enemy: Enemy, delta: float) -> void:
	var player := _find_player()
	match phase:
		Phase.WINDUP:
			enemy.velocity.x = move_toward(enemy.velocity.x, 0.0, 2000.0 * delta)
			if _advance(delta):
				_set_phase(Phase.ACTIVE, 0.75)
				Audio.sfx(&"bark", 0.1)
		Phase.ACTIVE:
			enemy.velocity.x = float(enemy.patrol_direction) * (820.0 + 40.0 * tier)
			if enemy.is_on_wall():
				_set_phase(Phase.RECOVER, 1.2)
				GameFeel.shake(4.0)
				Audio.sfx(&"clank")
				enemy.velocity.x = -float(enemy.patrol_direction) * 200.0
			elif not enemy.call(&"_has_floor_ahead") or _advance(delta):
				_set_phase(Phase.RECOVER, 0.5)
		Phase.RECOVER:
			enemy.velocity.x = move_toward(enemy.velocity.x, 0.0, 2600.0 * delta)
			if _advance(delta):
				_set_phase(Phase.NONE, 0.0)
		Phase.NONE:
			if enemy.is_on_floor() and _sees(enemy, player, 760.0, 110.0):
				_face(enemy, player.global_position)
				_set_phase(Phase.WINDUP, maxf(0.55 - 0.04 * tier, 0.32))
			else:
				_patrol(enemy, 140.0)
