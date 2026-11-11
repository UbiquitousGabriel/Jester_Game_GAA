class_name Telegraph
extends Node2D
## Flashing warning shape for an attack about to land. Frees itself after
## `time` seconds (or earlier if its owner frees it).

var rect: Rect2 = Rect2()
var circle_radius: float = 0.0
var color: Color = Color(1.0, 0.3, 0.3)
var time: float = 0.8
var _age: float = 0.0


static func create(area: Rect2, tint: Color, duration: float) -> Telegraph:
	var t := Telegraph.new()
	t.rect = area
	t.color = tint
	t.time = duration
	t.z_index = 3
	return t


static func circle(at: Vector2, radius: float, tint: Color, duration: float) -> Telegraph:
	var t := Telegraph.new()
	t.rect = Rect2(at, Vector2.ZERO)
	t.circle_radius = radius
	t.color = tint
	t.time = duration
	t.z_index = 3
	return t


func _process(delta: float) -> void:
	_age += delta
	if _age >= time:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _age / maxf(time, 0.01)
	var blink := 0.25 + 0.35 * (0.5 + 0.5 * sin(_age * (10.0 + 30.0 * k)))
	if circle_radius > 0.0:
		draw_circle(rect.position, circle_radius, Color(color, blink * 0.5))
		draw_arc(rect.position, circle_radius, 0.0, TAU, 48, Color(color, 0.9), 4.0)
		draw_arc(rect.position, circle_radius * k, 0.0, TAU, 48, Color(color, 0.6), 3.0)
	else:
		draw_rect(rect, Color(color, blink * 0.45))
		draw_rect(rect, Color(color, 0.9), false, 4.0)
		var fill := Rect2(rect.position + Vector2(0.0, rect.size.y * (1.0 - k)), Vector2(rect.size.x, rect.size.y * k))
		draw_rect(fill, Color(color, 0.25))
