class_name EnemyBrain
extends Node
## Base behaviour for an Enemy while it is active (the GROUNDED state).
## The Enemy owns physics, damage and launches; a brain only decides movement
## and attacks. Visuals read `phase` and `phase_progress()`.

enum Phase { NONE, WINDUP, ACTIVE, RECOVER }

const PLAYER_MASK: int = 2

var phase: Phase = Phase.NONE
## Damage dealt by touching the enemy while it is active (0 = harmless).
var contact_damage: int = 1
## Area difficulty, 0..5. Brains speed up and hit harder with it.
var tier: int = 0
var _phase_time: float = 0.0
var _phase_length: float = 0.0


## Called every physics frame while the enemy is active. Set enemy.velocity.
func tick(_enemy: Enemy, _delta: float) -> void:
	pass


## True while hits should not interrupt the current move.
func has_armor() -> bool:
	return false


## Return true to shrug off a hit completely (shields).
func blocks(_enemy: Enemy, _hit: HitData) -> bool:
	return false


## Called after each active physics step: touching the Jester hurts.
func touch(enemy: Enemy) -> void:
	if contact_damage > 0:
		_hit_player(enemy, enemy.body_rect().grow(-6.0), contact_damage)


## A hit landed: abandon the current move.
func interrupt() -> void:
	_set_phase(Phase.NONE, 0.0)


func phase_progress() -> float:
	if _phase_length <= 0.0:
		return 1.0
	return clampf(_phase_time / _phase_length, 0.0, 1.0)


func _set_phase(new_phase: Phase, length: float) -> void:
	phase = new_phase
	_phase_time = 0.0
	_phase_length = length


## Advances the phase clock. Returns true when the current phase just ended.
func _advance(delta: float) -> bool:
	_phase_time += delta
	return _phase_time >= _phase_length


func _find_player() -> Player:
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player == null or player.is_dead():
		return null
	return player


## Damages the player if `rect` (world space) overlaps them.
func _hit_player(enemy: Enemy, rect: Rect2, damage: int) -> bool:
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, rect.get_center())
	params.collision_mask = PLAYER_MASK
	var results: Array[Dictionary] = enemy.get_world_2d().direct_space_state.intersect_shape(params, 4)
	for result: Dictionary in results:
		var player := result.get("collider") as Player
		if player != null:
			return player.take_damage(damage, enemy.global_position)
	return false


func _face(enemy: Enemy, target: Vector2) -> void:
	enemy.patrol_direction = 1 if target.x > enemy.global_position.x else -1


func _sees(enemy: Enemy, player: Player, range_x: float, range_y: float) -> bool:
	if player == null:
		return false
	var d := player.global_position - enemy.global_position
	return absf(d.x) < range_x and absf(d.y) < range_y


## Walk along the floor without stepping off ledges or into walls.
func _walk(enemy: Enemy, speed: float) -> void:
	if enemy.is_on_floor() and (enemy.is_on_wall() or not enemy.call(&"_has_floor_ahead")):
		enemy.velocity.x = 0.0
		return
	enemy.velocity.x = float(enemy.patrol_direction) * speed


func _patrol(enemy: Enemy, speed: float) -> void:
	if enemy.is_on_floor() and (enemy.is_on_wall() or not enemy.call(&"_has_floor_ahead")):
		enemy.patrol_direction = -enemy.patrol_direction
	enemy.velocity.x = float(enemy.patrol_direction) * speed


func _shoot(enemy: Enemy, from: Vector2, velocity: Vector2, spec: Dictionary = {}) -> Projectile:
	var p := Projectile.create(from, velocity, spec)
	enemy.get_parent().add_child(p)
	return p
