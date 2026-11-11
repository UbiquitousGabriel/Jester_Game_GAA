class_name BossBarrier
extends StaticBody2D
## Iron bars that drop over a door while a boss fight runs.

var size: Vector2 = Vector2(128.0, 320.0)
var _open: float = 0.0
var _opening: bool = false


static func create(rect: Rect2) -> BossBarrier:
	var barrier := BossBarrier.new()
	barrier.position = rect.position
	barrier.size = rect.size
	return barrier


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = size
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = size * 0.5
	add_child(cs)
	z_index = 2
	Audio.sfx(&"gate_slam")
	GameFeel.shake(6.0)


func open() -> void:
	_opening = true
	collision_layer = 0
	Audio.sfx(&"gate_open")


func _process(delta: float) -> void:
	if _opening:
		_open = minf(_open + delta * 2.0, 1.0)
		modulate.a = 1.0 - _open
		if _open >= 1.0:
			queue_free()
	queue_redraw()


func _draw() -> void:
	var lift := size.y * _open
	var bars := maxi(int(size.x / 22.0), 2)
	for i: int in bars:
		var x := (float(i) + 0.5) * size.x / float(bars)
		draw_line(Vector2(x, -lift), Vector2(x, size.y - lift), Color(0.18, 0.12, 0.22), 9.0)
		draw_line(Vector2(x, -lift), Vector2(x, size.y - lift), Color(0.62, 0.58, 0.7), 5.0)
	draw_rect(Rect2(0.0, -lift, size.x, 14.0), Color(0.75, 0.55, 0.2))
	draw_rect(Rect2(0.0, size.y - 14.0 - lift, size.x, 14.0), Color(0.75, 0.55, 0.2))
