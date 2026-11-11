class_name BalloonBrain
extends EnemyBrain
## Balloon clown: drifts back and forth and drops spiked juggling balls on
## anyone below. A perfect pogo target.

var home: Vector2 = Vector2.ZERO
var _home_set: bool = false
var _time: float = 0.0
var _cooldown: float = 1.0


func tick(enemy: Enemy, delta: float) -> void:
	if not _home_set:
		home = enemy.global_position
		_home_set = true
	_time += delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	var target := home + Vector2(sin(_time * 0.6) * 220.0, sin(_time * 1.4) * 24.0)
	enemy.velocity = enemy.velocity.move_toward((target - enemy.global_position) * 2.0, 600.0 * delta)
	var player := _find_player()
	if phase == Phase.NONE and _cooldown <= 0.0 and player != null:
		var d := player.global_position - enemy.global_position
		if absf(d.x) < 140.0 and d.y > 40.0 and d.y < 900.0:
			_set_phase(Phase.WINDUP, 0.35)
	if phase == Phase.WINDUP and _advance(delta):
		_set_phase(Phase.RECOVER, 0.4)
		_shoot(enemy, enemy.global_position + Vector2(0.0, 40.0), Vector2(0.0, 120.0),
			{"radius": 16.0, "gravity": 1400.0, "color": Color(0.95, 0.4, 0.5), "life": 3.0, "kind": "orb"})
		Audio.sfx(&"drop")
	elif phase == Phase.RECOVER and _advance(delta):
		_set_phase(Phase.NONE, 0.0)
		_cooldown = maxf(1.4 - 0.1 * tier, 0.8)
