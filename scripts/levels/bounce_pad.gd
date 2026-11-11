class_name BouncePad
extends Area2D
## Carnival bounce pad. Launches the player and any enemy that lands on it.

const PLAYER_AND_ENEMY_MASK: int = 2 | 4

const SPRING: Texture2D = preload("res://assets/environments/pack/spring.png")

## Trigger matches the spring art: 84 px wide, cushion top 58 px up.
var size: Vector2 = Vector2(84.0, 58.0)
var bounce_speed: float = 1850.0
var color: Color = Color(0.98, 0.72, 0.2)

var _squash: float = 0.0
var _sprite: Sprite2D


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
	_sprite = Sprite2D.new()
	_sprite.texture = SPRING
	_sprite.centered = true
	_sprite.offset = Vector2(0.0, -SPRING.get_height() * 0.5)
	_sprite.scale = Vector2(size.x / SPRING.get_width(), size.x / SPRING.get_width())
	add_child(_sprite)


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
			# Flying enemies only bounce while tumbling from a launch.
			var flying_free := enemy.flying and enemy.state != Enemy.State.LAUNCHED
			if enemy.state != Enemy.State.DEFEATED and not flying_free:
				enemy.launch_with(Vector2(enemy.velocity.x, -bounce_speed * 0.8))
				_squash = 1.0


func _process(delta: float) -> void:
	if _squash <= 0.0:
		return
	_squash = maxf(_squash - delta * 4.0, 0.0)
	var k := size.x / SPRING.get_width()
	# Compress, then spring back past rest.
	var t := 1.0 - _squash
	var stretch := 1.0 - 0.35 * _squash + 0.12 * sin(t * PI) * (1.0 - t)
	_sprite.scale = Vector2(k * (1.0 + 0.15 * _squash), k * stretch)
