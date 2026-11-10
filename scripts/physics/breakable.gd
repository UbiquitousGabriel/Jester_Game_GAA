class_name Breakable
extends StaticBody2D
## Destructible graybox prop (crate). Solid until smashed by the hammer or by
## a launched enemy. Built in code via Breakable.create().

signal smashed(impact_velocity: Vector2)

const WORLD_LAYER: int = 1
const PROP_LAYER: int = 64

var size: Vector2 = Vector2(64.0, 64.0)
var color: Color = Color(0.72, 0.5, 0.28)

var _is_smashed: bool = false


## `feet_position` is the bottom-centre of the prop.
static func create(feet_position: Vector2, prop_size: Vector2 = Vector2(64.0, 64.0)) -> Breakable:
	var prop := Breakable.new()
	prop.size = prop_size
	prop.position = feet_position
	return prop


func _ready() -> void:
	collision_layer = WORLD_LAYER | PROP_LAYER
	collision_mask = 0
	add_to_group(&"breakable")
	add_to_group(&"pogoable")
	var shape := RectangleShape2D.new()
	shape.size = size
	var collider := CollisionShape2D.new()
	collider.shape = shape
	collider.position = Vector2(0.0, -size.y * 0.5)
	add_child(collider)


func _draw() -> void:
	var rect := Rect2(Vector2(-size.x * 0.5, -size.y), size)
	draw_rect(rect, color)
	draw_rect(rect, color.darkened(0.45), false, 4.0)
	draw_line(rect.position, rect.end, color.darkened(0.3), 4.0)
	draw_line(
		Vector2(rect.end.x, rect.position.y),
		Vector2(rect.position.x, rect.end.y),
		color.darkened(0.3),
		4.0
	)


## Hammer hits arrive here.
func take_hit(hit: HitData) -> void:
	smash(hit.launch_velocity)


func smash(impact_velocity: Vector2) -> void:
	if _is_smashed:
		return
	_is_smashed = true
	# Stop colliding immediately; the node itself is freed at end of frame.
	collision_layer = 0
	smashed.emit(impact_velocity)
	GameFeel.shake(4.0)
	var burst := DebrisBurst.create(
		global_position + Vector2(0.0, -size.y * 0.5), color, impact_velocity
	)
	get_parent().add_child(burst)
	queue_free()
