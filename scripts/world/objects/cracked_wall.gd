class_name CrackedWall
extends StaticBody2D
## Cracked stone. Only a fully charged heavy swing with Cracking Slam breaks
## it; the whole connected patch shatters together.

const TEXTURE: Texture2D = preload("res://assets/environments/pack/tile_stone_cracked.png")
const WORLD_AND_PROP := 1 | 64
const MIN_CHARGE := 0.7

static var _hinted: bool = false
var _broken: bool = false


static func create(top_left: Vector2) -> CrackedWall:
	var wall := CrackedWall.new()
	wall.position = top_left
	return wall


func _ready() -> void:
	collision_layer = WORLD_AND_PROP
	collision_mask = 0
	add_to_group(&"cracked")
	var shape := RectangleShape2D.new()
	shape.size = Vector2(64.0, 64.0)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = Vector2(32.0, 32.0)
	add_child(cs)
	var sprite := Sprite2D.new()
	sprite.texture = TEXTURE
	sprite.centered = false
	sprite.scale = Vector2(64.0, 64.0) / TEXTURE.get_size()
	sprite.modulate = Color(1.05, 0.92, 0.82)
	add_child(sprite)


func take_hit(hit: HitData) -> void:
	if _broken:
		return
	if GameState.has(&"slam") and hit.charge >= MIN_CHARGE:
		_shatter_patch()
		return
	Audio.sfx(&"clank")
	GameFeel.shake(2.0)
	Vfx.hit(get_parent(), global_position + Vector2(32.0, 32.0), Vector2.UP, 0.5)
	if not _hinted:
		_hinted = true
		Ui.toast("Cracked stone. A mightier, fully charged blow might shatter it.")


func _shatter_patch() -> void:
	# Flood-fill neighbouring cracked tiles so the whole wall goes at once.
	var queue: Array[CrackedWall] = [self]
	var all: Array[CrackedWall] = []
	for node: Node in get_tree().get_nodes_in_group(&"cracked"):
		all.append(node as CrackedWall)
	while not queue.is_empty():
		var wall: CrackedWall = queue.pop_back()
		if wall._broken:
			continue
		wall._broken = true
		wall._break_one()
		for other: CrackedWall in all:
			if not other._broken and other.global_position.distance_to(wall.global_position) < 70.0:
				queue.append(other)
	Audio.sfx(&"shatter")
	GameFeel.shake(12.0)
	GameFeel.hitstop(0.1)


func _break_one() -> void:
	collision_layer = 0
	Vfx.cloud(get_parent(), global_position + Vector2(32.0, 32.0), 0.9)
	var burst := DebrisBurst.create(global_position + Vector2(32.0, 32.0), Color(0.6, 0.5, 0.65), Vector2(0.0, -300.0))
	get_parent().add_child(burst)
	queue_free()
