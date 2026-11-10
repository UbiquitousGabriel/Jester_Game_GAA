class_name Checkpoint
extends Area2D
## Sets the player's respawn point when touched, so a missed trick never
## restarts the whole room (Bible section 16 exit criteria).

const PLAYER_MASK: int = 2

var is_active: bool = false


## `feet_position` is where the player will respawn (on the ground).
static func create(feet_position: Vector2) -> Checkpoint:
	var checkpoint := Checkpoint.new()
	checkpoint.position = feet_position
	return checkpoint


func _ready() -> void:
	collision_layer = 0
	collision_mask = PLAYER_MASK
	add_to_group(&"checkpoint")
	var shape := RectangleShape2D.new()
	shape.size = Vector2(80.0, 160.0)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	collider.position = Vector2(0.0, -80.0)
	add_child(collider)
	body_entered.connect(_on_body_entered)


func _draw() -> void:
	var flag_color := Color(0.98, 0.78, 0.25) if is_active else Color(0.55, 0.5, 0.62)
	draw_line(Vector2(0.0, 0.0), Vector2(0.0, -130.0), Color(0.3, 0.22, 0.36), 6.0)
	draw_colored_polygon(
		PackedVector2Array([Vector2(3.0, -130.0), Vector2(63.0, -110.0), Vector2(3.0, -90.0)]),
		flag_color
	)


func _on_body_entered(body: Node2D) -> void:
	var player := body as Player
	if player == null:
		return
	for other: Node in get_tree().get_nodes_in_group(&"checkpoint"):
		var checkpoint := other as Checkpoint
		if checkpoint != null and checkpoint != self and checkpoint.is_active:
			checkpoint.is_active = false
			checkpoint.queue_redraw()
	player.respawn_position = global_position + Vector2(0.0, -4.0)
	is_active = true
	queue_redraw()
