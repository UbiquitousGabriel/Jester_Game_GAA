class_name AcrobatTwins
extends Boss
## Grand Halls boss. Two acrobats sharing one health bar: the partner mirrors
## every move across the arena, so the room fills with tumbling and knives.

var partner: TwinPartner


func _setup() -> void:
	boss_id = &"acrobat_twins"
	max_health = 72
	size = Vector2(76.0, 140.0)


func _style(v: LabelledShape) -> void:
	v.label = "Pim"
	v.color = Color(0.25, 0.6, 0.85)
	v.accent = Color(1.0, 0.85, 0.3)
	v.kind = LabelledShape.Kind.CAPSULE


func activate(target: Player, lines: Array) -> void:
	partner = TwinPartner.new()
	partner.boss = self
	partner.add_to_group(&"boss_spawn")
	get_parent().add_child(partner)
	await super.activate(target, lines)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if partner != null and is_instance_valid(partner) and _dying < 0.0:
		partner.global_position = Vector2(arena.get_center().x * 2.0 - global_position.x, global_position.y)
		partner.facing = -patrol_direction if _attack != &"knives" else (1 if player.global_position.x > partner.global_position.x else -1)


func _choose() -> StringName:
	var options: Array[StringName] = [&"tumble", &"knives", &"dive"]
	if phase >= 2:
		options.append(&"tumble")
	return options.pick_random()


func _run(attack: StringName, delta: float) -> bool:
	match attack:
		&"tumble":
			if _step == 0:
				var target_x := arena.end.x - 260.0 if global_position.x < arena.get_center().x else arena.position.x + 260.0
				leap_to(target_x, 1.1, 380.0 + 80.0 * phase)
				Audio.sfx(&"whoosh")
				_step = 1
			elif _step == 1:
				visual.rotation += signf(velocity.x) * 12.0 * delta
				if _t > 0.3 and is_on_floor():
					visual.rotation = 0.0
					Vfx.dust(get_parent(), global_position, 1.0)
					_step = 2
					_t = 0.0
			elif _step == 2:
				velocity.x = 0.0
				return _t >= 0.3
			return _t > 3.0
		&"knives":
			face_player()
			velocity.x = 0.0
			var volleys := 2 + phase
			if _t >= 0.4 + 0.4 * _step and _step < volleys:
				for origin: Node2D in [self, partner]:
					if origin == null or not is_instance_valid(origin):
						continue
					var from := origin.global_position + Vector2(0.0, -90.0)
					var base := (player.global_position + Vector2(0.0, -40.0) - from).angle()
					for i: int in 3:
						shoot(from, Vector2.from_angle(base + (float(i) - 1.0) * 0.22) * 640.0,
							{"kind": "blade", "radius": 9.0, "color": Color(0.85, 0.9, 1.0), "life": 2.5})
				Audio.sfx(&"throw")
				_step += 1
			return _t >= 0.6 + 0.4 * volleys
		&"dive":
			if _step == 0:
				# Spring to the ceiling...
				velocity = Vector2(0.0, -1500.0)
				Audio.sfx(&"jump_big")
				_step = 1
			elif _step == 1:
				if global_position.y < arena.position.y + 480.0 or _t > 0.6:
					velocity = Vector2.ZERO
					gravity_on = false
					global_position.x = move_toward(global_position.x, player.global_position.x, 900.0 * delta)
					if _t > 0.6:
						warn(Rect2(global_position.x - 60.0, global_position.y, 120.0, floor_y() - global_position.y), 0.4)
						_step = 2
						_t = 0.0
			elif _step == 2:
				if _t >= 0.4:
					velocity = Vector2(0.0, 2000.0)
					_step = 3
			elif _step == 3:
				if global_position.y >= floor_y() - 2.0:
					global_position.y = floor_y()
					gravity_on = true
					velocity = Vector2.ZERO
					slam_impact(0.9)
					ground_wave(global_position.x, -1.0)
					ground_wave(global_position.x, 1.0)
					_step = 4
					_t = 0.0
			else:
				return _t >= 0.7
			return _t > 4.0
	return true


func _start_death() -> void:
	super._start_death()
	gravity_on = true


## The second twin: mirrors Pim, shares the health bar.
class TwinPartner extends Enemy:
	var boss: AcrobatTwins
	var facing: int = -1
	var _visual: LabelledShape

	func _ready() -> void:
		collision_layer = 4
		collision_mask = 0
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(60.0, 126.0)
		cs.shape = shape
		cs.position = Vector2(0.0, -63.0)
		add_child(cs)
		_visual = LabelledShape.new()
		_visual.label = "Pom"
		_visual.size = Vector2(76.0, 140.0)
		_visual.color = Color(0.85, 0.35, 0.6)
		_visual.accent = Color(1.0, 0.85, 0.3)
		add_child(_visual)
		super._ready()

	func _physics_process(_delta: float) -> void:
		time_since_hit += _delta
		if boss == null or not is_instance_valid(boss):
			queue_free()
			return
		_visual.facing = facing
		_visual.rotation = -boss.visual.rotation
		if boss.active and boss.player != null:
			Combat.hurt_player_in(self, body_rect().grow(-12.0), 1, global_position)

	func take_hit(hit: HitData) -> void:
		if boss == null or not boss.active:
			return
		_visual.hit_flash()
		boss.take_hit(hit)

	func defeat() -> void:
		Vfx.defeat(get_parent(), global_position + Vector2(0.0, -70.0), 1.5)
		queue_free()
