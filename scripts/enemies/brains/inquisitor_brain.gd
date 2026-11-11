class_name InquisitorBrain
extends EnemyBrain
## Inquisitor: blinks around the Jester, casts orb fans and calls down
## pillars of judgement on his position (telegraphed by a ring).

var _cooldown: float = 1.0
var _cast: int = 0
var _pillar_at: Vector2 = Vector2.ZERO
var _marker: Node2D


func tick(enemy: Enemy, delta: float) -> void:
	enemy.velocity.x = move_toward(enemy.velocity.x, 0.0, 2000.0 * delta)
	_cooldown = maxf(_cooldown - delta, 0.0)
	var player := _find_player()
	match phase:
		Phase.WINDUP:
			if _advance(delta):
				_set_phase(Phase.ACTIVE, 0.3)
				_release(enemy, player)
		Phase.ACTIVE:
			if _cast == 1:
				Combat.hurt_player_in(enemy, Rect2(_pillar_at + Vector2(-60.0, -420.0), Vector2(120.0, 420.0)), 1, _pillar_at)
			if _advance(delta):
				_set_phase(Phase.RECOVER, 0.6)
				if is_instance_valid(_marker):
					_marker.queue_free()
		Phase.RECOVER:
			if _advance(delta):
				_set_phase(Phase.NONE, 0.0)
				_cooldown = maxf(1.6 - 0.1 * tier, 0.9)
		_:
			if _sees(enemy, player, 900.0, 400.0):
				_face(enemy, player.global_position)
				if _cooldown <= 0.0:
					_cast = randi() % 3
					if _cast == 2:
						_blink(enemy, player)
						_cooldown = 0.6
						return
					if _cast == 1:
						_pillar_at = player.global_position
						_marker = _make_marker(enemy, _pillar_at)
					_set_phase(Phase.WINDUP, 0.8)
			else:
				_patrol(enemy, 50.0)


func _release(enemy: Enemy, player: Player) -> void:
	if _cast == 0 and player:
		var base := (player.global_position + Vector2(0.0, -40.0) - enemy.global_position).angle()
		for i: int in 3:
			var a := base + (float(i) - 1.0) * 0.28
			_shoot(enemy, enemy.global_position + Vector2(0.0, -70.0), Vector2.from_angle(a) * (420.0 + 30.0 * tier),
				{"radius": 13.0, "color": Color(1.0, 0.45, 0.75), "life": 3.0})
		Audio.sfx(&"cast")
	elif _cast == 1:
		Audio.sfx(&"pillar")
		GameFeel.shake(5.0)
		Vfx.burst(enemy.get_parent(), _pillar_at + Vector2(0.0, -200.0), Color(1.0, 0.6, 0.9), 16, 1.2)


func _blink(enemy: Enemy, player: Player) -> void:
	var side := -1.0 if randf() < 0.5 else 1.0
	var to := player.global_position + Vector2(side * 320.0, -10.0)
	var q := PhysicsRayQueryParameters2D.create(to + Vector2(0.0, -80.0), to + Vector2(0.0, 300.0), 1 | 256)
	var hit := enemy.get_world_2d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	var free := not enemy.test_move(Transform2D(0.0, hit["position"] + Vector2(0.0, -2.0)), Vector2.ZERO)
	if free:
		Vfx.burst(enemy.get_parent(), enemy.global_position + Vector2(0.0, -50.0), Color(1.0, 0.5, 0.85), 8, 0.6)
		enemy.global_position = hit["position"] + Vector2(0.0, -2.0)
		Vfx.burst(enemy.get_parent(), enemy.global_position + Vector2(0.0, -50.0), Color(1.0, 0.5, 0.85), 8, 0.6)
		Audio.sfx(&"blink")


func _make_marker(enemy: Enemy, at: Vector2) -> Node2D:
	var m := Telegraph.create(Rect2(at + Vector2(-60.0, -420.0), Vector2(120.0, 420.0)), Color(1.0, 0.45, 0.8), 0.8)
	enemy.get_parent().add_child(m)
	return m
