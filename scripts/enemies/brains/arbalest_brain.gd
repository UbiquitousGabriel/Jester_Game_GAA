class_name ArbalestBrain
extends EnemyBrain
## Crossbowman: keeps its distance, aims (a visible windup), then fires a
## bolt the Jester can bat straight back.

var _cooldown: float = 1.0


func tick(enemy: Enemy, delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	var player := _find_player()
	match phase:
		Phase.WINDUP:
			enemy.velocity.x = 0.0
			if player:
				_face(enemy, player.global_position)
			if _advance(delta):
				_set_phase(Phase.ACTIVE, 0.1)
				var dir := float(enemy.patrol_direction)
				_shoot(enemy, enemy.global_position + Vector2(dir * 40.0, -52.0), Vector2(dir * (880.0 + 50.0 * tier), 0.0),
					{"kind": "bolt", "radius": 10.0, "color": Color(1.0, 0.75, 0.4), "life": 3.0})
				Audio.sfx(&"crossbow")
		Phase.ACTIVE:
			if _advance(delta):
				_set_phase(Phase.RECOVER, 0.5)
		Phase.RECOVER:
			if _advance(delta):
				_set_phase(Phase.NONE, 0.0)
				_cooldown = maxf(1.8 - 0.15 * tier, 1.0)
		Phase.NONE:
			if _sees(enemy, player, 980.0, 140.0):
				_face(enemy, player.global_position)
				var dx := absf(player.global_position.x - enemy.global_position.x)
				if dx < 260.0:
					# Back away.
					enemy.patrol_direction = -enemy.patrol_direction
					_walk(enemy, 150.0)
					enemy.patrol_direction = -enemy.patrol_direction
				else:
					enemy.velocity.x = 0.0
				if _cooldown <= 0.0:
					_set_phase(Phase.WINDUP, 0.7)
			else:
				_patrol(enemy, 60.0)
