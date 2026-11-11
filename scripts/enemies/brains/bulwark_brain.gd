class_name BulwarkBrain
extends EnemyBrain
## Shield bearer: blocks anything from the front at its own height. Hit it
## from above (pogo), from behind, or launch something into it.

var _cooldown: float = 0.5
var _hit_done: bool = false


func blocks(enemy: Enemy, hit: HitData) -> bool:
	if hit.attack_id == &"enemy_collision" or hit.attack_id == &"shockwave" or hit.attack_id == &"parry":
		return false
	var source := hit.source as Node2D
	if source == null:
		return false
	var d := source.global_position - enemy.global_position
	var in_front := signf(d.x) == float(enemy.patrol_direction)
	var level := d.y > -90.0
	if in_front and level and phase != Phase.RECOVER:
		Audio.sfx(&"clank")
		GameFeel.shake(3.0)
		Vfx.hit(enemy.get_parent(), enemy.global_position + Vector2(float(enemy.patrol_direction) * 34.0, -50.0), Vector2(-d.x, 0.0).normalized(), 0.6)
		var player := source as Player
		if player:
			player.velocity.x = signf(d.x) * 520.0
		return true
	return false


func tick(enemy: Enemy, delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	var player := _find_player()
	match phase:
		Phase.WINDUP:
			enemy.velocity.x = 0.0
			if _advance(delta):
				_set_phase(Phase.ACTIVE, 0.25)
				_hit_done = false
				enemy.velocity.x = float(enemy.patrol_direction) * 620.0
		Phase.ACTIVE:
			if not _hit_done:
				var dir := float(enemy.patrol_direction)
				_hit_done = _hit_player(enemy, Rect2(enemy.global_position + Vector2(dir * 30.0 - 40.0, -100.0), Vector2(80.0, 100.0)), 1 + tier / 3)
			if _advance(delta):
				_set_phase(Phase.RECOVER, 0.7)
		Phase.RECOVER:
			enemy.velocity.x = move_toward(enemy.velocity.x, 0.0, 2600.0 * delta)
			if _advance(delta):
				_set_phase(Phase.NONE, 0.0)
				_cooldown = 1.2
		Phase.NONE:
			if _sees(enemy, player, 600.0, 140.0):
				_face(enemy, player.global_position)
				if absf(player.global_position.x - enemy.global_position.x) < 220.0 and _cooldown <= 0.0:
					_set_phase(Phase.WINDUP, 0.5)
					return
				_walk(enemy, 70.0)
			else:
				_patrol(enemy, 50.0)
