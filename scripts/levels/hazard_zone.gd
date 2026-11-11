class_name HazardZone
extends Area2D
## Spike strip. Sends the player back to the last checkpoint and defeats any
## enemy knocked into it. In the "pogoable" group, so a downward hammer strike
## bounces off it instead.

const HAZARD_LAYER: int = 32
const SPIKES: Texture2D = preload("res://assets/environments/pack/spikes_floor.png")
## World height of the spike art (slightly taller than the hurt zone).
const ART_HEIGHT: float = 50.0
const PLAYER_AND_ENEMY_MASK: int = 2 | 4

var size: Vector2 = Vector2(200.0, 40.0)
var color: Color = Color(0.93, 0.9, 0.82)


## `top_left` is the top-left corner of the strip.
static func create(top_left: Vector2, zone_size: Vector2) -> HazardZone:
	var zone := HazardZone.new()
	zone.position = top_left
	zone.size = zone_size
	return zone


func _ready() -> void:
	collision_layer = HAZARD_LAYER
	collision_mask = PLAYER_AND_ENEMY_MASK
	add_to_group(&"hazard")
	add_to_group(&"pogoable")
	var shape := RectangleShape2D.new()
	# Slightly inset so grazing the edge is forgiving.
	shape.size = Vector2(maxf(size.x - 12.0, 4.0), size.y * 0.6)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	collider.position = Vector2(size.x * 0.5, size.y * 0.7)
	add_child(collider)
	body_entered.connect(_on_body_entered)
	_build_art()


func _build_art() -> void:
	var k := ART_HEIGHT / SPIKES.get_height()
	var piece := SPIKES.get_width() * k
	var count := maxi(1, roundi(size.x / piece))
	var piece_w := size.x / float(count)
	for i: int in count:
		var sprite := Sprite2D.new()
		sprite.texture = SPIKES
		sprite.centered = false
		sprite.scale = Vector2(piece_w / SPIKES.get_width(), k)
		sprite.position = Vector2(float(i) * piece_w, size.y - ART_HEIGHT + 4.0)
		add_child(sprite)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		(body as Player).hazard_hit()
	elif body is Enemy:
		(body as Enemy).defeat()
