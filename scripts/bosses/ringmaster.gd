class_name Ringmaster
extends Boss
## Carnival Gate boss. Whip cracks, flaming hoops, cartwheel charges and a
## big-top leap; later calls in balloon clowns.


func _setup() -> void:
	boss_id = &"ringmaster"
	max_health = 46
	size = Vector2(96.0, 176.0)


func _style(v: LabelledShape) -> void:
	v.label = "The Ringmaster"
	v.color = Color(0.85, 0.2, 0.25)
	v.accent = Color(1.0, 0.82, 0.3)
	v.kind = LabelledShape.Kind.TALL


func _choose() -> StringName:
	var options: Array[StringName] = [&"whip", &"hoops", &"cartwheel"]
	if phase >= 1:
		options.append(&"leap")
	if phase >= 2 and minion_count() < 2:
		options.append(&"balloons")
	var dx := absf(player.global_position.x - global_position.x)
	if dx < 300.0:
		return &"whip" if randf() < 0.55 else options.pick_random()
	return options.pick_random()


func _run(attack: StringName, delta: float) -> bool:
	match attack:
		&"whip":
			if _step == 0:
				face_player()
				velocity.x = 0.0
				warn(_whip_rect(), 0.55, Color(1.0, 0.85, 0.3))
				_step = 1
			if _step == 1 and _t >= 0.55:
				Audio.sfx(&"whip")
				hurt(_whip_rect())
				Vfx.hit(get_parent(), global_position + Vector2(dir() * 240.0, -90.0), Vector2(dir(), 0.0), 0.8)
				_step = 2
			return _t >= 1.0
		&"hoops":
			face_player()
			velocity.x = 0.0
			var count := 3 if phase == 0 else 5
			if _t >= 0.45 + 0.28 * _step and _step < count:
				var to := player.global_position + Vector2(randf_range(-160.0, 160.0), -40.0)
				var from := centre() + Vector2(dir() * 40.0, -40.0)
				var t := 0.9
				var g := 900.0
				var v := Vector2((to.x - from.x) / t, (to.y - from.y - 0.5 * g * t * t) / t)
				shoot(from, v, {"kind": "ring", "radius": 26.0, "gravity": g, "color": Color(1.0, 0.55, 0.2), "life": 3.0})
				Audio.sfx(&"throw")
				_step += 1
			return _t >= 0.6 + 0.28 * count
		&"cartwheel":
			if _step == 0:
				face_player()
				velocity.x = 0.0
				visual.squash = 0.5
				if _t >= 0.5:
					_step = 1
					Audio.sfx(&"whoosh")
			elif _step == 1:
				velocity.x = dir() * (900.0 + 120.0 * phase)
				visual.rotation += dir() * 14.0 * delta
				if is_on_wall() or _t > 2.4:
					_step = 2
					_t = 0.0
					visual.rotation = 0.0
					slam_impact(0.6)
					velocity.x = -dir() * 260.0
			else:
				velocity.x = move_toward(velocity.x, 0.0, 1400.0 * delta)
				return _t >= 0.9
			return false
		&"leap":
			if _step == 0:
				leap_to(player.global_position.x, 0.9, 560.0)
				Audio.sfx(&"jump_big")
				_step = 1
			elif _step == 1 and _t > 0.2 and is_on_floor():
				slam_impact()
				ground_wave(global_position.x, -1.0)
				ground_wave(global_position.x, 1.0)
				_step = 2
				_t = 0.0
			elif _step == 2:
				velocity.x = 0.0
				return _t >= 0.6
			return _t > 3.0
		&"balloons":
			velocity.x = 0.0
			if _step == 0 and _t >= 0.4:
				for side: float in [-1.0, 1.0]:
					spawn_minion("balloon", Vector2(arena.get_center().x + side * 500.0, arena.position.y + 360.0))
				_step = 1
			return _t >= 1.0
	return true


func _whip_rect() -> Rect2:
	var x := global_position.x + (20.0 if dir() > 0.0 else -400.0)
	return Rect2(x, global_position.y - 120.0, 380.0, 70.0)
