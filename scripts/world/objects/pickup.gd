class_name Pickup
extends Area2D
## Collectibles: heart pieces, joke pages, bell caches and loose bells.
## Persistent pickups (everything but loose bells) remember their id.

enum Kind { HEART_PIECE, JOKE, BELL_CACHE, BELL }

const HEART: Texture2D = preload("res://assets/environments/pack/heart.png")
const BOOK: Texture2D = preload("res://assets/environments/pack/books.png")
const COIN: Texture2D = preload("res://assets/environments/pack/coin.png")

var kind: Kind = Kind.BELL
var id: String = ""
var value: int = 1
var velocity: Vector2 = Vector2.ZERO
var _sprite: Sprite2D
var _time: float = 0.0
var _age: float = 0.0
var _taken: bool = false


static func create(pickup_kind: Kind, at: Vector2, pickup_id: String = "", amount: int = 1) -> Pickup:
	var p := Pickup.new()
	p.kind = pickup_kind
	# Loose bells are spawned at world positions.
	p.top_level = pickup_kind == Kind.BELL
	p.position = at
	p.id = pickup_id
	p.value = amount
	return p


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := CircleShape2D.new()
	shape.radius = 34.0 if kind != Kind.BELL else 26.0
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	_sprite = Sprite2D.new()
	match kind:
		Kind.HEART_PIECE:
			_sprite.texture = HEART
			_sprite.scale = Vector2(0.42, 0.42)
			LevelArt.add_glow(self, Vector2.ZERO, Color(1.0, 0.4, 0.5), 0.5, 0.9)
		Kind.JOKE:
			_sprite.texture = BOOK
			_sprite.scale = Vector2(0.4, 0.4)
			LevelArt.add_glow(self, Vector2.ZERO, Color(1.0, 0.9, 0.5), 0.4, 0.8)
		Kind.BELL_CACHE:
			_sprite.texture = COIN
			_sprite.scale = Vector2(0.55, 0.55)
			LevelArt.add_glow(self, Vector2.ZERO, Color(1.0, 0.85, 0.3), 0.45, 0.9)
		Kind.BELL:
			_sprite.texture = COIN
			_sprite.scale = Vector2(0.24, 0.24)
	add_child(_sprite)
	body_entered.connect(_on_body_entered)
	_time = randf() * 6.0


func _physics_process(delta: float) -> void:
	_time += delta
	_age += delta
	if kind == Kind.BELL:
		# Loose bells pop out, fall, then home in on the Jester.
		var player := get_tree().get_first_node_in_group(&"player") as Node2D
		var magnet := 260.0 if GameState.has_charm(&"lucky_bell") else 140.0
		if player and _age > 0.35 and player.global_position.distance_to(global_position) < magnet:
			var to := (player.global_position + Vector2(0.0, -40.0) - global_position)
			velocity = velocity.lerp(to.normalized() * 900.0, minf(delta * 8.0, 1.0))
		else:
			velocity.y += 1800.0 * delta
			velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
			var space := get_world_2d().direct_space_state
			var q := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0.0, 20.0), 1)
			if velocity.y > 0.0 and not space.intersect_ray(q).is_empty():
				velocity.y = -velocity.y * 0.4 if velocity.y > 200.0 else 0.0
		position += velocity * delta
		if _age > 14.0:
			queue_free()
	else:
		_sprite.position.y = sin(_time * 2.5) * 6.0
		_sprite.rotation = sin(_time * 1.7) * 0.08


func _on_body_entered(body: Node2D) -> void:
	var player := body as Player
	if player == null or _taken or (kind == Kind.BELL and _age < 0.25):
		return
	_taken = true
	match kind:
		Kind.HEART_PIECE:
			GameState.pick(id)
			var whole := GameState.add_heart_piece()
			player.refresh_max_health()
			Audio.sfx(&"heart")
			Ui.item_popup("Heart Piece", "A new heart!" if whole else "%d of 4 pieces." % (GameState.heart_pieces % 4))
			if whole:
				player.heal_full()
		Kind.JOKE:
			GameState.pick(id)
			GameState.jokes[id] = true
			Audio.sfx(&"page")
			Ui.item_popup("Lost Joke %d / %d" % [GameState.jokes.size(), WorldData.JOKE_COUNT], Story.joke_for(id))
		Kind.BELL_CACHE:
			GameState.pick(id)
			Audio.sfx(&"bells")
			for i: int in 12:
				var bell := Pickup.create(Kind.BELL, global_position, "", 5)
				bell.velocity = Vector2(randf_range(-320.0, 320.0), randf_range(-720.0, -380.0))
				get_parent().call_deferred(&"add_child", bell)
		Kind.BELL:
			GameState.add_bells(value)
			Audio.sfx(&"bell", 0.15)
	Vfx.hit(get_parent(), global_position, Vector2.UP, 0.4 if kind == Kind.BELL else 0.8)
	queue_free()


## Scatter loose bells (enemy drops).
static func drop_bells(parent: Node, at: Vector2, total: int) -> void:
	if GameState.has_charm(&"lucky_bell"):
		total = int(ceil(float(total) * 1.5))
	var coins := clampi(total, 1, 8)
	var each := maxi(total / coins, 1)
	for i: int in coins:
		var bell := Pickup.create(Kind.BELL, at, "", each)
		bell.velocity = Vector2(randf_range(-260.0, 260.0), randf_range(-640.0, -320.0))
		parent.call_deferred(&"add_child", bell)
