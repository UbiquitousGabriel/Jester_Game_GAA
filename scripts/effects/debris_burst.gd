class_name DebrisBurst
extends Node2D
## Cosmetic one-shot burst of square chips. No gameplay effect.

const PIECES: int = 8
const LIFETIME: float = 0.6
const GRAVITY: float = 2400.0

var color: Color = Color.WHITE
var impact_velocity: Vector2 = Vector2.ZERO

var _positions: PackedVector2Array = PackedVector2Array()
var _velocities: PackedVector2Array = PackedVector2Array()
var _age: float = 0.0


static func create(at: Vector2, burst_color: Color, velocity: Vector2) -> DebrisBurst:
	var burst := DebrisBurst.new()
	burst.position = at
	burst.color = burst_color
	burst.impact_velocity = velocity
	return burst


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i: int in PIECES:
		_positions.append(Vector2(rng.randf_range(-20.0, 20.0), rng.randf_range(-20.0, 20.0)))
		var spread := Vector2(rng.randf_range(-420.0, 420.0), rng.randf_range(-700.0, -150.0))
		_velocities.append(spread + impact_velocity * 0.25)


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	for i: int in _positions.size():
		_velocities[i] += Vector2(0.0, GRAVITY * delta)
		_positions[i] += _velocities[i] * delta
	queue_redraw()


func _draw() -> void:
	var faded := color
	faded.a = 1.0 - _age / LIFETIME
	for piece: Vector2 in _positions:
		draw_rect(Rect2(piece - Vector2(7.0, 7.0), Vector2(14.0, 14.0)), faded)
