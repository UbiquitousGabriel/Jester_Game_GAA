class_name Boss
extends Enemy
## Base for the six bosses. A boss is an Enemy (so hammer bounces, pogos and
## launched enemies all work on it) with its own attack loop instead of the
## launch state machine. Subclasses implement _choose() and _run().
##
## Attack loop: pick an attack, run it frame by frame (_t is the time inside
## it, _step a free counter) until _run returns true, rest, repeat. Health
## thresholds move it into later phases, which subclasses read via `phase`.

signal boss_health_changed(ratio: float)
signal boss_defeated

const ARENA_MARGIN := 140.0

var boss_id: StringName = &""
var active: bool = false
var player: Player = null
## 0, 1, 2 as health drops past `thresholds`.
var phase: int = 0
var thresholds: Array[float] = [0.66, 0.33]
var contact: int = 1
var gravity_on: bool = true
var gravity: float = 2600.0
var size: Vector2 = Vector2(120.0, 180.0)
var visual: LabelledShape
var arena: Rect2 = Rect2()

var _attack: StringName = &""
var _t: float = 0.0
var _step: int = 0
var _rest: float = 1.4
var _dying: float = -1.0
var _armor_time: float = 0.0
var _lines: Array = []
var _last_attack: StringName = &""


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 256
	add_to_group(&"boss")
	_setup()
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(size.x * 0.8, size.y * 0.9)
	cs.shape = shape
	cs.position = Vector2(0.0, -size.y * 0.45)
	add_child(cs)
	visual = LabelledShape.new()
	visual.size = size
	_style(visual)
	add_child(visual)
	super._ready()
	health = max_health


## Subclasses set max_health, size, thresholds, boss_id here.
func _setup() -> void:
	pass


## Subclasses set the placeholder look here.
func _style(_v: LabelledShape) -> void:
	pass


## Pick the next attack.
func _choose() -> StringName:
	return &""


## Run one frame of `attack`. Return true when it is finished.
func _run(_attack_name: StringName, _delta: float) -> bool:
	return true


## Seconds of rest after an attack.
func _rest_time() -> float:
	return [1.1, 0.8, 0.55][phase]


## Hook for when health crosses into a new phase.
func _on_phase(_new_phase: int) -> void:
	pass


## True when this hit should clank off (e.g. armour).
func _deflects(_hit: HitData) -> bool:
	return _armor_time > 0.0


func activate(target: Player, lines: Array) -> void:
	player = target
	var room := get_parent() as Room
	arena = room.rect if room != null else Rect2(global_position - Vector2(1200.0, 900.0), Vector2(2400.0, 1000.0))
	_lines = lines
	if not lines.is_empty():
		Ui.dialog(lines, String(GameState.BOSSES.get(boss_id, "")))
		await Ui.closed
	active = true
	_rest = 0.6
	Audio.sfx(&"boss_roar")


func _physics_process(delta: float) -> void:
	time_since_hit += delta
	_armor_time = maxf(_armor_time - delta, 0.0)
	if _dying >= 0.0:
		_process_death(delta)
		return
	if gravity_on and not is_on_floor():
		velocity.y += gravity * delta
	if not active or player == null or not is_instance_valid(player):
		velocity.x = move_toward(velocity.x, 0.0, 2000.0 * delta)
		move_and_slide()
		return
	if _attack == &"":
		_idle(delta)
		_rest -= delta
		if _rest <= 0.0 and not player.is_dead():
			_attack = _choose()
			if _attack == _last_attack:
				_attack = _choose()
			_last_attack = _attack
			_t = 0.0
			_step = 0
	else:
		_t += delta
		if _run(_attack, delta):
			_attack = &""
			_rest = _rest_time()
	move_and_slide()
	_keep_in_arena()
	if contact > 0 and not player.is_dead():
		Combat.hurt_player_in(self, body_rect().grow(-12.0), contact, global_position)
	if visual:
		visual.facing = patrol_direction


## Between attacks: drift toward a comfortable distance.
func _idle(delta: float) -> void:
	face_player()
	if gravity_on:
		var dx := player.global_position.x - global_position.x
		var want := 0.0
		if absf(dx) > 520.0:
			want = signf(dx) * 160.0
		elif absf(dx) < 220.0:
			want = -signf(dx) * 120.0
		velocity.x = move_toward(velocity.x, want, 1200.0 * delta)


func take_hit(hit: HitData) -> void:
	if _dying >= 0.0 or not active:
		return
	if _deflects(hit):
		time_since_hit = 0.0
		Audio.sfx(&"clank")
		GameFeel.shake(2.0)
		Vfx.hit(get_parent(), global_position + Vector2(0.0, -size.y * 0.5), Vector2.UP, 0.5)
		blocked.emit(hit)
		return
	health -= hit.damage
	time_since_hit = 0.0
	hit_taken.emit(hit)
	visual.hit_flash()
	boss_health_changed.emit(float(maxi(health, 0)) / float(max_health))
	# A little stagger sells the hit without breaking the fight.
	velocity.x += signf(hit.launch_velocity.x) * 60.0
	var ratio := float(health) / float(max_health)
	while phase < thresholds.size() and ratio <= thresholds[phase]:
		phase += 1
		_phase_change()
	if health <= 0:
		_start_death()


func _phase_change() -> void:
	Audio.sfx(&"boss_roar")
	GameFeel.shake(12.0)
	GameFeel.hitstop(0.12)
	Feedback.flash(self, Color(1.0, 0.9, 0.7, 0.35))
	Vfx.burst(get_parent(), global_position + Vector2(0.0, -size.y * 0.5), Color(1.0, 0.7, 0.4), 24, 1.6)
	_on_phase(phase)
	if _lines.size() > phase - 1 and phase - 1 >= 0:
		Ui.toast("\"%s\"" % String(_lines[mini(phase, _lines.size() - 1)]), Ui.GOLD)


func _start_death() -> void:
	_dying = 0.0
	active = false
	velocity = Vector2.ZERO
	for node: Node in get_tree().get_nodes_in_group(&"boss_spawn"):
		if node is Enemy:
			(node as Enemy).defeat()
		else:
			node.queue_free()
	for node: Node in get_tree().get_nodes_in_group(&"telegraph"):
		node.queue_free()
	ComboTracker.register_hit(5)


func _process_death(delta: float) -> void:
	var before := _dying
	_dying += delta
	velocity.x = 0.0
	if gravity_on and not is_on_floor():
		velocity.y += gravity * delta
	move_and_slide()
	visual.position = Vector2(randf_range(-6.0, 6.0), randf_range(-4.0, 4.0))
	# A string of pops, then the big one.
	if floorf(before * 6.0) != floorf(_dying * 6.0) and _dying < 1.6:
		var at := global_position + Vector2(randf_range(-size.x, size.x) * 0.5, -randf_range(0.0, size.y))
		Vfx.hit(get_parent(), at, Vector2.from_angle(randf() * TAU), 1.2)
		Audio.sfx(&"hit_heavy", 0.2)
		GameFeel.shake(5.0)
	if before < 1.6 and _dying >= 1.6:
		Vfx.defeat(get_parent(), global_position + Vector2(0.0, -size.y * 0.5), 3.0)
		Vfx.ring(get_parent(), global_position + Vector2(0.0, -size.y * 0.5), Color(1.0, 0.85, 0.5), 5.0)
		GameFeel.shake(24.0)
		Pickup.drop_bells(get_parent(), global_position + Vector2(0.0, -size.y * 0.5), 60 + 20 * phase)
		boss_defeated.emit()
		defeated.emit()
	if _dying >= 1.6:
		modulate.a = maxf(1.0 - (_dying - 1.6) * 2.0, 0.0)
	if _dying >= 2.2:
		queue_free()


# --- Helpers for subclasses ---------------------------------------------------------------


func face_player() -> void:
	if player != null:
		patrol_direction = 1 if player.global_position.x > global_position.x else -1


func dir() -> float:
	return float(patrol_direction)


func floor_y() -> float:
	return arena.end.y - 3.0 * 64.0


func centre() -> Vector2:
	return global_position + Vector2(0.0, -size.y * 0.5)


func warn(rect: Rect2, time: float, tint: Color = Color(1.0, 0.3, 0.3)) -> Telegraph:
	var t := Telegraph.create(rect, tint, time)
	t.add_to_group(&"telegraph")
	get_parent().add_child(t)
	t.global_position = Vector2.ZERO
	return t


func warn_circle(at: Vector2, radius: float, time: float, tint: Color = Color(1.0, 0.3, 0.3)) -> Telegraph:
	var t := Telegraph.circle(at, radius, tint, time)
	t.add_to_group(&"telegraph")
	get_parent().add_child(t)
	t.global_position = Vector2.ZERO
	return t


func hurt(rect: Rect2, damage: int = 1) -> bool:
	return Combat.hurt_player_in(self, rect, damage, global_position)


func shoot(at: Vector2, vel: Vector2, spec: Dictionary = {}) -> Projectile:
	var p := Projectile.create(at, vel, spec)
	p.add_to_group(&"boss_spawn")
	get_parent().add_child(p)
	return p


## A wave that runs along the floor.
func ground_wave(from_x: float, direction: float, speed: float = 760.0) -> void:
	shoot(Vector2(from_x, floor_y() - 26.0), Vector2(direction * speed, 0.0),
		{"radius": 24.0, "color": Color(1.0, 0.75, 0.4), "life": 3.0, "reflectable": false, "kind": "ring", "through_walls": false})


func minion_count() -> int:
	var n := 0
	for node: Node in get_tree().get_nodes_in_group(&"boss_spawn"):
		if node is Enemy and (node as Enemy).is_alive():
			n += 1
	return n


func spawn_minion(kind: String, at: Vector2) -> void:
	var e := EnemyFactory.create(kind, 1)
	if e == null:
		return
	e.position = at - get_parent().global_position
	e.add_to_group(&"boss_spawn")
	get_parent().add_child(e)
	Vfx.burst(get_parent(), at, Color(0.9, 0.6, 1.0), 10, 0.7)
	Audio.sfx(&"summon")


## Jump so the feet land at `target_x` after `time` seconds.
func leap_to(target_x: float, time: float, height: float = 520.0) -> void:
	var g := gravity
	var vy := -sqrt(2.0 * g * height)
	velocity = Vector2((target_x - global_position.x) / time, vy)


func slam_impact(power: float = 1.0) -> void:
	GameFeel.shake(14.0 * power)
	Audio.sfx(&"slam")
	Vfx.dust(get_parent(), global_position, 2.0 * power)
	Vfx.ring(get_parent(), global_position + Vector2(0.0, -20.0), Color(1.0, 0.8, 0.5), 2.5 * power)


func _keep_in_arena() -> void:
	if arena.size == Vector2.ZERO:
		return
	global_position.x = clampf(global_position.x, arena.position.x + ARENA_MARGIN, arena.end.x - ARENA_MARGIN)
	if not gravity_on:
		global_position.y = clampf(global_position.y, arena.position.y + 200.0 + size.y, floor_y())
