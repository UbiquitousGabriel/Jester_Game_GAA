class_name Colossus
extends Boss
## Clockworks boss. A towering automaton whose plating only cracks from
## above: stay airborne (pogo, air strings, glide spin) to hurt it, while it
## slams fists, vents steam columns and fires gears.


func _setup() -> void:
	boss_id = &"colossus"
	max_health = 90
	size = Vector2(230.0, 330.0)
	contact = 1


func _style(v: LabelledShape) -> void:
	v.label = "The Clockwork Colossus"
	v.color = Color(0.62, 0.45, 0.25)
	v.accent = Color(1.0, 0.55, 0.2)
	v.kind = LabelledShape.Kind.BOX


func _deflects(hit: HitData) -> bool:
	if hit.attack_id in [&"enemy_collision", &"parry", &"shockwave"]:
		return false
	var source := hit.source as Node2D
	if source == null:
		return false
	# Only hits from the upper body count.
	return source.global_position.y > global_position.y - size.y * 0.5


func _idle(delta: float) -> void:
	face_player()
	velocity.x = move_toward(velocity.x, signf(player.global_position.x - global_position.x) * 60.0, 400.0 * delta)


func _choose() -> StringName:
	var options: Array[StringName] = [&"fist", &"fist", &"steam", &"gears"]
	if phase >= 1:
		options.append(&"stomp")
	return options.pick_random()


func _run(attack: StringName, delta: float) -> bool:
	velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
	match attack:
		&"fist":
			if _step == 0:
				face_player()
				warn(_fist_rect(), 0.9 - 0.15 * phase, Color(1.0, 0.55, 0.25))
				_step = 1
			elif _step == 1 and _t >= 0.9 - 0.15 * phase:
				hurt(_fist_rect(), 2)
				slam_impact(1.2)
				Vfx.dust(get_parent(), Vector2(_fist_rect().get_center().x, global_position.y), 2.0)
				_step = 2
			return _t >= 1.6 - 0.2 * phase
		&"steam":
			if _step == 0:
				var columns := 3 + phase
				var xs: Array[float] = []
				for i: int in columns:
					xs.append(randf_range(arena.position.x + 200.0, arena.end.x - 200.0))
				xs.append(player.global_position.x)
				set_meta(&"columns", xs)
				for x: float in xs:
					warn(Rect2(x - 55.0, arena.position.y + 128.0, 110.0, floor_y() - arena.position.y - 128.0), 1.0, Color(1.0, 1.0, 1.0))
				Audio.sfx(&"hiss")
				_step = 1
			elif _step == 1 and _t >= 1.0:
				_step = 2
				Audio.sfx(&"steam")
			if _step == 2 and _t < 1.5:
				for x: float in get_meta(&"columns"):
					hurt(Rect2(x - 55.0, arena.position.y + 128.0, 110.0, floor_y() - arena.position.y - 128.0))
					if randf() < 0.3:
						Vfx.cloud(get_parent(), Vector2(x, randf_range(arena.position.y + 200.0, floor_y())), 0.6)
			return _t >= 1.7
		&"gears":
			face_player()
			var count := 3 + phase
			if _t >= 0.4 + 0.3 * _step and _step < count:
				var from := global_position + Vector2(dir() * size.x * 0.4, -size.y * 0.8)
				shoot(from, Vector2(dir() * randf_range(380.0, 760.0), -randf_range(500.0, 900.0)),
					{"kind": "gear", "radius": 22.0, "gravity": 1300.0, "color": Color(0.9, 0.65, 0.3), "life": 4.0})
				Audio.sfx(&"clank")
				_step += 1
			return _t >= 0.6 + 0.3 * count
		&"stomp":
			if _step == 0:
				velocity.y = -900.0
				_step = 1
			elif _step == 1 and _t > 0.2 and is_on_floor():
				slam_impact(1.6)
				ground_wave(global_position.x - size.x * 0.5, -1.0, 820.0)
				ground_wave(global_position.x + size.x * 0.5, 1.0, 820.0)
				_step = 2
				_t = 0.0
			elif _step == 2:
				return _t >= 0.8
			return _t > 3.0
	return true


func _fist_rect() -> Rect2:
	var x := global_position.x + (size.x * 0.4 if dir() > 0.0 else -size.x * 0.4 - 300.0)
	return Rect2(x, global_position.y - 160.0, 300.0, 160.0)
