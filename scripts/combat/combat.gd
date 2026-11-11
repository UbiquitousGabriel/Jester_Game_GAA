class_name Combat
extends RefCounted
## Shared combat helpers: area damage, projectiles, enemy contact damage.

const ENEMY_MASK := 4
const PLAYER_MASK := 2


## Damages every enemy overlapping `rect` (world). Launch x points away from
## the rect's centre. Used by slam shockwaves and the Pratfall charm.
static func area_damage(context: Node2D, rect: Rect2, damage: int, launch: Vector2, source: Node) -> int:
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, rect.get_center())
	params.collision_mask = ENEMY_MASK | 64
	params.collide_with_areas = true
	var count := 0
	var seen: Dictionary[int, bool] = {}
	for result: Dictionary in context.get_world_2d().direct_space_state.intersect_shape(params, 24):
		var node := result.get("collider") as Node2D
		if node == null or seen.has(node.get_instance_id()) or not node.has_method(&"take_hit"):
			continue
		seen[node.get_instance_id()] = true
		var side := signf(node.global_position.x - rect.get_center().x)
		var hit := HitData.new()
		hit.attack_id = &"shockwave"
		hit.damage = damage
		hit.source = source
		hit.charge = 1.0
		hit.launch_velocity = Vector2(launch.x * (side if side != 0.0 else 1.0), launch.y)
		node.call(&"take_hit", hit)
		count += 1
	if count > 0:
		ComboTracker.register_hit(count)
	return count


## Damages the player when `rect` overlaps them. Returns true on a hit.
static func hurt_player_in(context: Node2D, rect: Rect2, damage: int, from: Vector2) -> bool:
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, rect.get_center())
	params.collision_mask = PLAYER_MASK
	for result: Dictionary in context.get_world_2d().direct_space_state.intersect_shape(params, 4):
		var player := result.get("collider") as Player
		if player != null:
			return player.take_damage(damage, from)
	return false


static func circle_hits_player(context: Node2D, at: Vector2, radius: float, damage: int) -> bool:
	var shape := CircleShape2D.new()
	shape.radius = radius
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, at)
	params.collision_mask = PLAYER_MASK
	for result: Dictionary in context.get_world_2d().direct_space_state.intersect_shape(params, 4):
		var player := result.get("collider") as Player
		if player != null:
			return player.take_damage(damage, at)
	return false
