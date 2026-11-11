class_name Feedback
extends RefCounted
## Wires sound and extra juice to gameplay signals, so the moving parts stay
## free of audio code. Call bind_player once per player and bind_enemy once
## per enemy (EnemyFactory does it for spawned enemies).


static func bind_player(player: Player) -> void:
	player.jumped.connect(func() -> void: Audio.sfx(&"jump", 0.08, -4.0))
	player.landed.connect(func(speed: float) -> void:
		if speed > 900.0:
			Audio.sfx(&"land_heavy")
			GameFeel.shake(4.0)
		elif speed > 450.0:
			Audio.sfx(&"land", 0.1, -6.0))
	player.dashed.connect(func(_d: Vector2) -> void:
		Audio.sfx(&"phantom" if player.is_ghosting() else &"dash", 0.06))
	player.pogoed.connect(func() -> void: Audio.sfx(&"pogo", 0.08))
	player.vaulted.connect(func(perfect: bool) -> void:
		Audio.sfx(&"vault")
		if perfect:
			Audio.sfx(&"perfect", 0.0))
	player.damaged.connect(func(_a: int) -> void:
		Audio.sfx(&"hurt")
		_flash_screen(player, Color(1.0, 0.2, 0.25, 0.28)))
	player.glide_started.connect(func() -> void: Audio.sfx(&"twirl", 0.05))
	player.wall_kicked.connect(func(_d: int) -> void:
		Audio.sfx(&"wallkick", 0.08)
		Vfx.dust(player.get_parent(), player.global_position + Vector2(float(-_d) * 20.0, -30.0), 0.8))
	player.healed.connect(func() -> void: Audio.sfx(&"heal", 0.0))
	var hammer := player.get_node_or_null(^"Hammer") as Hammer
	if hammer == null:
		return
	hammer.attack_started.connect(func(attack: AttackData) -> void:
		if attack == hammer.heavy:
			Audio.sfx(&"swing_heavy")
		elif attack.id == &"air_finisher":
			Audio.sfx(&"swing_finisher")
		else:
			Audio.sfx(&"swing", 0.12, -3.0))
	hammer.charge_started.connect(func() -> void: Audio.sfx(&"charge", 0.0, -6.0))
	hammer.hit_landed.connect(func(target: Node, hit: HitData) -> void:
		if hit.damage >= 3 or hit.charge > 0.7:
			Audio.sfx(&"hit_heavy")
			var cam := player.get_viewport().get_camera_2d() as FollowCamera
			if cam:
				cam.punch(0.035)
		elif target is Enemy:
			Audio.sfx(&"hit", 0.12)
		else:
			Audio.sfx(&"thunk", 0.1))


static func bind_enemy(enemy: Enemy, bells: int) -> void:
	enemy.hit_taken.connect(func(_h: HitData) -> void: Audio.sfx(&"enemy_hurt", 0.1, -3.0))
	enemy.ricocheted.connect(func() -> void: Audio.sfx(&"ricochet", 0.1))
	enemy.collided_with_enemy.connect(func(_o: Enemy) -> void: Audio.sfx(&"chain_hit", 0.08))
	enemy.defeated.connect(func() -> void:
		Audio.sfx(&"enemy_defeat", 0.1)
		var parent := enemy.get_parent()
		if parent != null and bells > 0:
			Pickup.drop_bells(parent, enemy.global_position + Vector2(0.0, -30.0), bells)
		if parent != null:
			Vfx.burst(parent, enemy.global_position + Vector2(0.0, -30.0), Color(1.0, 0.85, 0.45), 10, 0.8))


## Full-screen colour flash (hurt, boss phase changes).
static func _flash_screen(context: Node, color: Color) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	var rect := ColorRect.new()
	rect.color = color
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	context.get_tree().root.add_child(layer)
	var tween := rect.create_tween()
	tween.tween_property(rect, "color:a", 0.0, 0.3)
	tween.tween_callback(layer.queue_free)


static func flash(context: Node, color: Color) -> void:
	_flash_screen(context, color)
