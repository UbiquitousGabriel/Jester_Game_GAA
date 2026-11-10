class_name BouncePad
extends Area2D
## Carnival bounce pad. Launches the player and any enemy that lands on it.

const PLAYER_AND_ENEMY_MASK: int = 2 | 4

var size: Vector2 = Vector2(120.0, 24.0)
var bounce_speed: float = 1850.0
var color: Color = Color(0.98, 0.72, 0.2)

var _squash: float = 0.0


## `centre_top` is the middle of the pad's top surface.
static func create(centre_top: Vector2, speed: float = 1850.0) -> BouncePad:
	var pad := BouncePad.new()
	pad.position = centre_top
	pad.bounce_speed = speed
	return pad


func _ready() -> void:
	collision_layer = 0
	collision_mask = PLAYER_AND_ENEMY_MASK
	add_to_group(&"bounce_pad")
	var shape := RectangleShape2D.new()
	shape.size = size
	var collider := CollisionShape2D.new()
	collider.shape = shape
	collider.position = Vector2(0.0, -size.y * 0.5)
	add_child(collider)


func _physics_process(_delta: float) -> void:
	for body: Node2D in get_overlapping_bodies():
		var character := body as CharacterBody2D
		if character == null or character.velocity.y < 0.0:
			continue
		if body is Player:
			(body as Player).pogo_bounce(bounce_speed)
			_squash = 1.0
		elif body is Enemy:
			var enemy := body as Enemy
			if enemy.state != Enemy.State.DEFEATED:
				enemy.launch_with(Vector2(enemy.velocity.x, -bounce_speed * 0.8))
				_squash = 1.0


func _process(delta: float) -> void:
	if _squash > 0.0:
		_squash = maxf(_squash - delta * 4.0, 0.0)
		queue_redraw()


func _draw() -> void:
	var height := size.y * (1.0 - 0.5 * _squash)
	var rect := Rect2(Vector2(-size.x * 0.5, -height), Vector2(size.x, height))
	draw_rect(rect, color)
	draw_rect(Rect2(rect.position, Vector2(size.x, 6.0)), Color(0.86, 0.16, 0.3))
