class_name WispBrain
extends EnemyBrain
## Wisp: a drifting garden ghost. Floats toward the Jester and lobs slow
## homing orbs. Fragile, and great to juggle.

var _cooldown: float = 1.5
var _time: float = 0.0


func tick(enemy: Enemy, delta: float) -> void:
	_time += delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	var player := _find_player()
	var want := Vector2(sin(_time * 1.3) * 60.0, cos(_time * 1.7) * 40.0)
	if _sees(enemy, player, 900.0, 600.0):
		var target := player.global_position + Vector2(-float(signf(player.global_position.x - enemy.global_position.x)) * 260.0, -220.0)
		want += (target - enemy.global_position).limit_length(1.0) * (90.0 + 10.0 * tier)
		_face(enemy, player.global_position)
		if phase == Phase.NONE and _cooldown <= 0.0:
			_set_phase(Phase.WINDUP, 0.6)
	enemy.velocity = enemy.velocity.move_toward(want, 400.0 * delta)
	if phase == Phase.WINDUP and _advance(delta):
		_set_phase(Phase.RECOVER, 0.6)
		if player:
			var dir := (player.global_position + Vector2(0.0, -40.0) - enemy.global_position).normalized()
			_shoot(enemy, enemy.global_position, dir * 240.0,
				{"radius": 14.0, "homing": 1.4 + 0.2 * tier, "color": Color(0.6, 1.0, 0.95), "life": 4.0, "speed_cap": 320.0})
			Audio.sfx(&"wisp")
	elif phase == Phase.RECOVER and _advance(delta):
		_set_phase(Phase.NONE, 0.0)
		_cooldown = maxf(2.6 - 0.2 * tier, 1.4)
