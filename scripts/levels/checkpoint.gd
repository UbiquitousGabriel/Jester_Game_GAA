class_name Checkpoint
extends Area2D
## Sets the player's respawn point when touched, so a missed trick never
## restarts the whole room (Bible section 16 exit criteria).

const PLAYER_MASK: int = 2
const FLAG_ON: Texture2D = preload("res://assets/environments/carnival_gate/flag_on.png")
const FLAG_OFF: Texture2D = preload("res://assets/environments/carnival_gate/flag_off.png")

var is_active: bool = false:
	set(value):
		is_active = value
		_refresh()

var _sprite: Sprite2D
var _light: PointLight2D


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
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.scale = Vector2(0.5, 0.5)
	_sprite.position = Vector2(-13.0, -148.0)
	add_child(_sprite)
	_light = LevelArt.add_light(self, Vector2(20.0, -110.0), Color(1.0, 0.75, 0.4), 0.7, 0.7)
	_refresh()


func _refresh() -> void:
	if _sprite == null:
		return
	_sprite.texture = FLAG_ON if is_active else FLAG_OFF
	_light.visible = is_active


func _on_body_entered(body: Node2D) -> void:
	var player := body as Player
	if player == null:
		return
	for other: Node in get_tree().get_nodes_in_group(&"checkpoint"):
		var checkpoint := other as Checkpoint
		if checkpoint != null and checkpoint != self and checkpoint.is_active:
			checkpoint.is_active = false
	player.respawn_position = global_position + Vector2(0.0, -4.0)
	if not is_active:
		is_active = true
		GameFeel.shake(3.0)
