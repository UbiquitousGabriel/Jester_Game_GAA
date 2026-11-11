class_name Executioner
extends Boss
## Outer Walls boss. A slow giant with a huge axe: telegraphed chops, an
## armoured whirlwind, crushing leaps and (later) a returning axe throw.


func _setup() -> void:
	boss_id = &"executioner"
	max_health = 62
	size = Vector2(130.0, 210.0)
	contact = 1


func _style(v: LabelledShape) -> void:
	v.label = "The Executioner"
	v.color = Color(0.25, 0.22, 0.28)
	v.accent = Color(0.75, 0.15, 0.2)
	v.kind = LabelledShape.Kind.BOX


func _deflects(hit: HitData) -> bool:
	return _attack == &"whirl" and _step == 1 and hit.attack_id != &"enemy_collision" and hit.attack_id != &"parry"


func _choose() -> StringName:
	var options: Array[StringName] = [&"chop", &"chop", &"whirl", &"leap"]
	if phase >= 2:
		options.append(&"throw")
	return options.pick_random()


func _run(attack: StringName, delta: float) -> bool:
	match attack:
		&"chop":
			if _step == 0:
				face_player()
				var dx := player.global_position.x - global_position.x
				velocity.x = signf(dx) * 300.0
				if absf(dx) < 200.0 or _t > 1.4:
					velocity.x = 0.0
					warn(_chop_rect(), 0.8)
					_step = 1
					_t = 0.0
			elif _step == 1:
				visual.squash = 0.6 * (_t / 0.8)
				if _t >= 0.8:
					hurt(_chop_rect(), 2)
					slam_impact()
					if phase >= 1:
						ground_wave(global_position.x + dir() * 160.0, dir(), 820.0)
					_step = 2
					_t = 0.0
			else:
				return _t >= 0.9
			return false
		&"whirl":
			if _step == 0:
				velocity.x = 0.0
				visual.squash = 0.4
				if _t >= 0.6:
					_step = 1
					_t = 0.0
					Audio.sfx(&"whirr")
			elif _step == 1:
				face_player()
				velocity.x = move_toward(velocity.x, dir() * (300.0 + 80.0 * phase), 900.0 * delta)
				visual.rotation = sin(_t * 30.0) * 0.25
				hurt(Rect2(global_position + Vector2(-150.0, -200.0), Vector2(300.0, 180.0)))
				if _t >= 2.0:
					_step = 2
					_t = 0.0
					visual.rotation = 0.0
			else:
				velocity.x = move_toward(velocity.x, 0.0, 1500.0 * delta)
				visual.squash = -0.2
				return _t >= 1.2
			return false
		&"leap":
			if _step == 0:
				visual.squash = 0.5
				velocity.x = 0.0
				if _t >= 0.45:
					leap_to(player.global_position.x, 1.0, 620.0)
					_step = 1
			elif _step == 1 and _t > 0.7 and is_on_floor():
				slam_impact(1.3)
				hurt(Rect2(global_position + Vector2(-200.0, -60.0), Vector2(400.0, 60.0)), 2)
				ground_wave(global_position.x, -1.0)
				ground_wave(global_position.x, 1.0)
				_step = 2
				_t = 0.0
			elif _step == 2:
				velocity.x = 0.0
				return _t >= 1.0
			return _t > 4.0
		&"throw":
			if _step == 0:
				face_player()
				velocity.x = 0.0
				if _t >= 0.5:
					shoot(centre(), Vector2(dir() * 900.0, 0.0), {"kind": "blade", "radius": 22.0, "color": Color(0.85, 0.85, 0.9), "life": 2.2, "boomerang": 1.0, "reflectable": true, "damage": 1})
					Audio.sfx(&"throw")
					_step = 1
			return _t >= 1.8
	return true


func _chop_rect() -> Rect2:
	var x := global_position.x + (30.0 if dir() > 0.0 else -280.0)
	return Rect2(x, global_position.y - 220.0, 250.0, 220.0)
