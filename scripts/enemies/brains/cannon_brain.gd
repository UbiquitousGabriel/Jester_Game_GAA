class_name CannonBrain
extends EnemyBrain
## Siege cannon: rooted in place, lobs cannonballs in an arc at the Jester.
## Bat a ball back to make the cannon eat it.

var _cooldown: float = 1.2


func tick(enemy: Enemy, delta: float) -> void:
	enemy.velocity.x = move_toward(enemy.velocity.x, 0.0, 3000.0 * delta)
	_cooldown = maxf(_cooldown - delta, 0.0)
	var player := _find_player()
	match phase:
		Phase.WINDUP:
			if _advance(delta):
				_set_phase(Phase.RECOVER, 0.6)
				if player:
					_fire(enemy, player)
		Phase.RECOVER:
			if _advance(delta):
				_set_phase(Phase.NONE, 0.0)
				_cooldown = maxf(2.4 - 0.2 * tier, 1.3)
		_:
			if _sees(enemy, player, 1300.0, 700.0):
				_face(enemy, player.global_position)
				if _cooldown <= 0.0:
					_set_phase(Phase.WINDUP, 0.8)


func _fire(enemy: Enemy, player: Player) -> void:
	var from := enemy.global_position + Vector2(float(enemy.patrol_direction) * 50.0, -70.0)
	var to := player.global_position + Vector2(player.velocity.x * 0.3, -30.0)
	var g := 1500.0
	var t := clampf(absf(to.x - from.x) / 700.0, 0.6, 1.6)
	var v := Vector2((to.x - from.x) / t, (to.y - from.y - 0.5 * g * t * t) / t)
	_shoot(enemy, from, v, {"radius": 20.0, "gravity": g, "color": Color(0.55, 0.5, 0.6), "life": 4.0, "speed_cap": 2200.0, "kind": "ball", "damage": 1})
	Audio.sfx(&"cannon")
	GameFeel.shake(3.0)
	Vfx.cloud(enemy.get_parent(), from, 0.5)
