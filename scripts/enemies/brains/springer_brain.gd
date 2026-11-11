class_name SpringerBrain
extends EnemyBrain
## Jack-in-the-box: bounces toward the Jester in big arcs.

var _timer: float = 0.8


func tick(enemy: Enemy, delta: float) -> void:
	var player := _find_player()
	if not enemy.is_on_floor():
		phase = Phase.ACTIVE
		return
	if phase == Phase.ACTIVE:
		_set_phase(Phase.RECOVER, 0.25)
		Vfx.dust(enemy.get_parent(), enemy.global_position, 0.8)
		Audio.sfx(&"spring", 0.15, -6.0)
	enemy.velocity.x = move_toward(enemy.velocity.x, 0.0, 3000.0 * delta)
	_timer -= delta
	if phase == Phase.RECOVER and _advance(delta):
		_set_phase(Phase.NONE, 0.0)
	if _timer <= 0.35 and phase == Phase.NONE:
		_set_phase(Phase.WINDUP, 0.35)
	if phase == Phase.WINDUP and _advance(delta):
		_timer = maxf(1.1 - 0.08 * tier, 0.6)
		var dir := float(enemy.patrol_direction)
		var reach := 340.0
		if _sees(enemy, player, 800.0, 400.0):
			_face(enemy, player.global_position)
			dir = float(enemy.patrol_direction)
			reach = clampf(absf(player.global_position.x - enemy.global_position.x) * 0.9, 120.0, 460.0)
		elif enemy.is_on_wall() or not enemy.call(&"_has_floor_ahead"):
			enemy.patrol_direction = -enemy.patrol_direction
			dir = -dir
		enemy.velocity = Vector2(dir * reach, -980.0 - 40.0 * tier)
		_set_phase(Phase.ACTIVE, 1.0)
