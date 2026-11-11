class_name King
extends Boss
## Throne Spire, the finale. Three acts: sceptre and crown, then the court
## joins in, then the King takes to the air and rains cards.


func _setup() -> void:
	boss_id = &"king"
	max_health = 120
	size = Vector2(110.0, 196.0)


func _style(v: LabelledShape) -> void:
	v.label = "The King"
	v.color = Color(0.55, 0.25, 0.75)
	v.accent = Color(1.0, 0.82, 0.25)
	v.kind = LabelledShape.Kind.TALL


func _on_phase(new_phase: int) -> void:
	if new_phase == 2:
		gravity_on = false
		velocity = Vector2(0.0, -600.0)


func _idle(delta: float) -> void:
	if gravity_on:
		super._idle(delta)
		return
	var want := Vector2(player.global_position.x + sin(Time.get_ticks_msec() / 700.0) * 300.0, arena.position.y + 480.0)
	velocity = velocity.move_toward((want - global_position) * 2.0, 900.0 * delta)
	face_player()


func _choose() -> StringName:
	match phase:
		0:
			return ([&"sceptre", &"crown", &"cards"] as Array[StringName]).pick_random()
		1:
			var options: Array[StringName] = [&"sceptre", &"crown", &"cards", &"blink"]
			if minion_count() < 2:
				options.append(&"court")
			return options.pick_random()
	return ([&"rain", &"cards", &"crown", &"swoop"] as Array[StringName]).pick_random()


func _run(attack: StringName, delta: float) -> bool:
	match attack:
		&"sceptre":
			if _step == 0:
				face_player()
				velocity.x = 0.0
				warn(_strike_rect(), 0.5, Color(1.0, 0.8, 0.3))
				_step = 1
			elif _step == 1 and _t >= 0.5:
				velocity.x = dir() * 700.0
				hurt(_strike_rect(), 1)
				Audio.sfx(&"swing_heavy")
				_step = 2
			elif _step == 2:
				velocity.x = move_toward(velocity.x, 0.0, 2600.0 * delta)
			return _t >= 1.0
		&"crown":
			if _step == 0:
				face_player()
				if _t >= 0.4:
					var to := (player.global_position + Vector2(0.0, -50.0) - centre()).normalized()
					shoot(centre() + Vector2(0.0, -80.0), to * 820.0, {"kind": "ring", "radius": 30.0, "color": Color(1.0, 0.82, 0.25), "life": 2.4, "boomerang": 1.1})
					Audio.sfx(&"throw")
					_step = 1
			return _t >= 1.6
		&"cards":
			face_player()
			if _step == 0 and _t >= 0.45:
				var n := 5 + 2 * phase
				var base := (player.global_position + Vector2(0.0, -40.0) - centre()).angle()
				for i: int in n:
					var a := base + (float(i) - float(n - 1) * 0.5) * 0.16
					shoot(centre(), Vector2.from_angle(a) * 560.0, {"kind": "card", "radius": 14.0, "color": Color(0.9, 0.2, 0.3), "life": 3.0})
				Audio.sfx(&"cards")
				_step = 1
			return _t >= 1.1
		&"blink":
			if _step == 0:
				Vfx.burst(get_parent(), centre(), Color(0.8, 0.5, 1.0), 14, 1.0)
				global_position.x = clampf(player.global_position.x - float(player.facing) * 220.0, arena.position.x + 200.0, arena.end.x - 200.0)
				Vfx.burst(get_parent(), centre(), Color(0.8, 0.5, 1.0), 14, 1.0)
				Audio.sfx(&"blink")
				_attack = &"sceptre"
				_t = 0.0
				_step = 0
			return false
		&"court":
			velocity.x = 0.0
			if _step == 0 and _t >= 0.5:
				Ui.toast("\"Guards! GUARDS!\"", Ui.GOLD)
				spawn_minion("guard", Vector2(arena.position.x + 260.0, floor_y()))
				spawn_minion("bulwark" if randf() < 0.5 else "arbalest", Vector2(arena.end.x - 260.0, floor_y()))
				_step = 1
			return _t >= 1.2
		&"rain":
			velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
			if _t >= 0.25 * _step and _step < 9:
				var x := randf_range(arena.position.x + 160.0, arena.end.x - 160.0)
				if _step % 3 == 0:
					x = player.global_position.x
				warn(Rect2(x - 30.0, arena.position.y + 128.0, 60.0, floor_y() - arena.position.y - 128.0), 0.6, Color(0.9, 0.3, 0.5))
				var spawn_x := x
				get_tree().create_timer(0.6, false).timeout.connect(func() -> void:
					if is_instance_valid(self) and _dying < 0.0:
						shoot(Vector2(spawn_x, arena.position.y + 150.0), Vector2(0.0, 1100.0), {"kind": "card", "radius": 16.0, "color": Color(0.9, 0.2, 0.3), "life": 2.0}))
				_step += 1
			return _t >= 3.0
		&"swoop":
			if _step == 0:
				face_player()
				velocity = Vector2.ZERO
				warn(Rect2(arena.position.x, player.global_position.y - 140.0, arena.size.x, 120.0), 0.7, Color(1.0, 0.5, 0.9))
				set_meta(&"swoop_y", player.global_position.y - 80.0)
				_step = 1
			elif _step == 1 and _t >= 0.7:
				global_position.y = float(get_meta(&"swoop_y")) + size.y * 0.5
				velocity = Vector2(dir() * 1500.0, 0.0)
				Audio.sfx(&"whoosh")
				_step = 2
			elif _step == 2:
				hurt(body_rect(), 1)
				if _t >= 1.7:
					velocity = Vector2.ZERO
					return true
			return false
	return true


func _strike_rect() -> Rect2:
	var x := global_position.x + (10.0 if dir() > 0.0 else -270.0)
	return Rect2(x, global_position.y - 150.0, 260.0, 110.0)
