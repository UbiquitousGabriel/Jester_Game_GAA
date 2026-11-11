class_name MourningBell
extends Boss
## Royal Gardens boss. A floating bronze bell: tolling shockwave rings,
## crushing drops (then stuck in the soil, wide open), wisp summons and a
## pendulum swing.

var _hover_y: float = 0.0


func _setup() -> void:
	boss_id = &"mourning_bell"
	max_health = 64
	size = Vector2(190.0, 210.0)
	gravity_on = false


func _style(v: LabelledShape) -> void:
	v.label = "The Mourning Bell"
	v.color = Color(0.72, 0.52, 0.25)
	v.accent = Color(0.35, 0.25, 0.12)
	v.kind = LabelledShape.Kind.BELL
	v.bob = 6.0


func activate(target: Player, lines: Array) -> void:
	await super.activate(target, lines)
	_hover_y = arena.position.y + 560.0


func _idle(delta: float) -> void:
	var want := Vector2(player.global_position.x, _hover_y) - global_position
	velocity = velocity.move_toward(Vector2(clampf(want.x, -1.0, 1.0) * minf(absf(want.x), 220.0), want.y * 2.0), 600.0 * delta)


func _choose() -> StringName:
	var options: Array[StringName] = [&"toll", &"drop", &"drop"]
	if phase >= 1 and minion_count() < 3:
		options.append(&"wisps")
	if phase >= 2:
		options.append(&"pendulum")
	return options.pick_random()


func _run(attack: StringName, delta: float) -> bool:
	match attack:
		&"toll":
			velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
			var radius := 330.0 + 40.0 * phase
			if _step == 0:
				warn_circle(centre(), radius, 1.0, Color(1.0, 0.75, 0.35))
				_step = 1
			if _step == 1 and _t >= 1.0:
				Audio.sfx(&"toll")
				GameFeel.shake(10.0)
				Vfx.ring(get_parent(), centre(), Color(1.0, 0.8, 0.45), radius / 90.0)
				Combat.circle_hits_player(self, centre(), radius, 1)
				_step = 2
			return _t >= 1.5
		&"drop":
			if _step == 0:
				var want := Vector2(player.global_position.x, arena.position.y + 380.0) - global_position
				velocity = want * 3.0
				if _t >= 0.9:
					_step = 1
					_t = 0.0
					warn(Rect2(global_position.x - size.x * 0.5, global_position.y, size.x, floor_y() - global_position.y), 0.45)
			elif _step == 1:
				velocity = Vector2.ZERO
				if _t >= 0.45:
					_step = 2
			elif _step == 2:
				velocity = Vector2(0.0, 1900.0)
				hurt(body_rect(), 2)
				if global_position.y >= floor_y() - 2.0:
					global_position.y = floor_y()
					velocity = Vector2.ZERO
					slam_impact(1.4)
					Audio.sfx(&"toll")
					ground_wave(global_position.x, -1.0, 700.0)
					ground_wave(global_position.x, 1.0, 700.0)
					_step = 3
					_t = 0.0
			elif _step == 3:
				# Stuck in the soil: free hits.
				visual.squash = 0.2
				return _t >= 1.6 - 0.3 * phase
			return false
		&"wisps":
			velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
			if _step == 0 and _t >= 0.5:
				for side: float in [-1.0, 1.0]:
					spawn_minion("wisp", centre() + Vector2(side * 220.0, 0.0))
				_step = 1
			return _t >= 1.0
		&"pendulum":
			var cx := arena.get_center().x
			var swing := sin(_t * 2.2) * (arena.size.x * 0.5 - 260.0)
			var y := arena.position.y + 520.0 + absf(cos(_t * 2.2)) * 260.0
			velocity = (Vector2(cx + swing, y) - global_position) * 6.0
			return _t >= 4.0
	return true
