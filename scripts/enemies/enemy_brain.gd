class_name EnemyBrain
extends Node
## Base behaviour for an Enemy while it is active (the GROUNDED state).
## The Enemy owns physics, damage and launches; a brain only decides movement
## and attacks. Visuals read `phase` and `phase_progress()`.

enum Phase { NONE, WINDUP, ACTIVE, RECOVER }

const PLAYER_MASK: int = 2

var phase: Phase = Phase.NONE
var _phase_time: float = 0.0
var _phase_length: float = 0.0


## Called every physics frame while the enemy is active. Set enemy.velocity.
func tick(_enemy: Enemy, _delta: float) -> void:
	pass


## True while hits should not interrupt the current move.
func has_armor() -> bool:
	return false


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
